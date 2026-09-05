import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos';
import MethodChannel, {
  MethodCallHandler,
  MethodResult
} from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import { image } from '@kit.ImageKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@ohos.base';
// 原生 C++ 像素处理模块：把「色彩矩阵 + 镜像 + R/B 复原 + 边缘锐化」的 ArkTS 逐像素
// 循环下沉到 C++（170 万像素由 ~5s 降到 ~10-30ms），解码/编码仍走系统硬管线。
import nativeProcessor from 'libphoto_processor.so';

/**
 * OHOS 原生图像处理插件（MethodChannel "lumira/image_processor"）
 *
 * 触发背景：flutter_ohos 引擎 dart:ui 的 JPEG 软件解码极慢（1200x1600 实测 ~6s），
 * 导致 OHOS 拍照后处理严重超时。本插件把「JPEG 解码 → RGBA」交给 OHOS 系统
 * image.ImageSource（系统/硬件解码），由 Flutter 侧用 ImageDescriptor.raw 建图，
 * 从而绕开 dart:ui 的慢速 JPEG 解码瓶颈。
 */
export default class ImageProcessorPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;

  getUniqueClassName(): string {
    return 'ImageProcessorPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'lumira/image_processor');
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'decodeJpegToRgba':
        this.decodeJpegToRgba(call, result);
        break;
      case 'encodeJpegFromRgba':
        this.encodeJpegFromRgba(call, result);
        break;
      case 'processJpeg':
        // 完整走法见异步方法
        this.processJpeg(call, result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  /**
   * OHOS 单次原生拍照后处理管线（唯一目的是把 Dart 主 isolate 的
   * 「解码→几何变换→色彩矩阵→锐化→JPEG编码」整合进系统原生硬管线，绕开
   * dart:ui 慢解码 + GPU toByteData 读回 + isolate 逐像素循环 + 软件编码，
   * 以达成 ≤800ms 的成片后处理目标）。
   *
   * 参数:
   *   inputPath, outputPath: 输入输出 JPEG 绝对路径
   *   targetRatio: 输出宽高比（正向像素，竖屏 <1，横屏 >1）
   *   isPortrait / isFront: 是否竖屏 / 是否前置（需镜像）
   *   matrix: 20 元素 ColorMatrix（由 Dart composePostProcessMatrix 产出，保证颜色与
   *           取景器/编辑页完全一致）
   *   sharpen: 锐化值（0 表示不锐化；严格用用户/模板真实值，应用层不做强制下限）
   *   clarity: 清晰度 -100..100（0=关闭，负值柔化；矩阵内对比度折叠外另有独立中频 pass，与 Dart 慢管线一致）
   *   smooth: 磨皮强度 0-100（0 表示不磨皮；原生 C++ 全分辨率肤色掩膜平滑，非皮肤保留）
   *   maxDim: 输出最大边（默认 1280）
   *
   * 返回: { ok: true, width, height, timing: {...} } 或 { ok: false, error }
   */
  private async processJpeg(call: MethodCall, result: MethodResult): Promise<void> {
    let fd: number = -1;
    let wfd: number = -1;
    let source: image.ImageSource | null = null;
    let srcPixelMap: image.PixelMap | null = null;
    let packer: image.ImagePacker | null = null;
    let finalPixelMap: image.PixelMap | null = null;
    try {
      const inputPath: string = call.argument('inputPath');
      const outputPath: string = call.argument('outputPath');
      if (!inputPath || !outputPath) {
        result.success({ ok: false, error: 'path empty' });
        return;
      }
      const targetRatio: number = call.argument('targetRatio');
      const isPortrait: boolean = call.argument('isPortrait');
      const isFront: boolean = call.argument('isFront');
      const matrixArr = call.argument('matrix') as number[];
      const sharpen: number = call.argument('sharpen') ?? 0;
      const smooth: number = call.argument('smooth') ?? 0;
      const vignette: number = call.argument('vignette') ?? 0;
      const grain: number = call.argument('grain') ?? 0;
      const clarity: number = call.argument('clarity') ?? 0;
      const maxDim: number = call.argument('maxDim') ?? 1280;
      if (!matrixArr || matrixArr.length < 20) {
        result.success({ ok: false, error: 'matrix invalid (need 20)' });
        return;
      }
      const tStart = Date.now();

      // ── 1) 系统硬件解码 JPEG → RGBA ──
      const file = fs.openSync(inputPath, fs.OpenMode.READ_ONLY);
      fd = file.fd;
      source = image.createImageSource(fd);
      const info: image.ImageInfo = await source.getImageInfo();
      const srcW = info.size.width;
      const srcH = info.size.height;
      // ── 1) 目标输出尺寸（仅依赖 maxDim / targetRatio / isPortrait）──
      let outW: number;
      let outH: number;
      if (isPortrait) {
        outH = maxDim;
        outW = maxDim * targetRatio;
        if (outW > maxDim) {
          outW = maxDim;
          outH = maxDim / targetRatio;
        }
      } else {
        outW = maxDim;
        outH = maxDim / targetRatio;
        if (outH > maxDim) {
          outH = maxDim;
          outW = maxDim * targetRatio;
        }
      }
      // ── 防放大糊 ──
      // 源图太小（如 1:1 方形图窄边 < maxDim，或设备源图档位较低）时，若直接按
      // desiredSize 输出，系统会对源图做拉伸放大 → 成片发糊且锐化救不回
      //（死区锐化只提边缘、补不了缺失像素）。缩放到能完整落在源图内（保持比例），
      // 让每个输出像素都取自真实源像素，绝不放大。
      if (outW > srcW || outH > srcH) {
        const fit = Math.min(1, srcW / outW, srcH / outH);
        outW = Math.round(outW * fit);
        outH = Math.round(outH * fit);
      }
      const iOutW = Math.max(1, Math.round(outW));
      const iOutH = Math.max(1, Math.round(outH));

      // ── 2) 系统原生几何变换：高质「cover 居中裁切」──
      // 关键：不用 createPixelMap 的 desiredRegion+desiredSize 做"裁剪+缩放"（该路径的
      // 缩放滤镜偏软，成片发糊且死区锐化提不回）。改为：
      //   ① 整图用 desiredSize 做 DCT 高质量下采样解码（解码器 DCT 缩放，锐度远高于
      //      后续任意像素缩放器）；
      //   ② 在 RGBA 缓冲区里做纯像素中心裁剪（无缩放、无插值，绝对锐利）；
      //   ③ 裁剪结果直接进 C++ 做色彩/锐化/磨皮/暗角/颗粒。
      // 源与目标纵横比不同时，居中裁窗天然等价于旋转；前置镜像仍在颜色阶段处理。
      const coverScale = Math.max(outW / srcW, outH / srcH);
      const decodeW = Math.max(1, Math.round(srcW * coverScale));
      const decodeH = Math.max(1, Math.round(srcH * coverScale));
      srcPixelMap = await source.createPixelMap({
        desiredSize: { width: decodeW, height: decodeH },
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      });
      const gdInfo: image.ImageInfo = await srcPixelMap.getImageInfo();
      const aDecW = gdInfo.size.width;
      const aDecH = gdInfo.size.height;
      const decBuf = new ArrayBuffer(aDecW * aDecH * 4);
      await srcPixelMap.readPixelsToBuffer(decBuf);
      // 输出尺寸 = cover 裁窗经 coverScale 映射后的精确大小（即使缩放比例来自 max 也会收敛到 iOutW×iOutH）
      const pw = iOutW;
      const ph = iOutH;
      // 中心裁窗：在解码缓冲区中截取 iOutW×iOutH；因解码尺寸按 coverScale 生成，裁窗恰好等于输出边长（纯裁剪，无再采样）。
      const cropX = Math.max(0, Math.round((aDecW - pw) / 2));
      const cropY = Math.max(0, Math.round((aDecH - ph) / 2));
      let cropBuf: ArrayBuffer;
      if (cropX === 0 && cropY === 0 && aDecW === pw && aDecH === ph) {
        cropBuf = decBuf; // 已精确等于输出，直接复用，零拷贝
      } else {
        cropBuf = new ArrayBuffer(pw * ph * 4);
        const srcU8 = new Uint8Array(decBuf);
        const cropU8 = new Uint8Array(cropBuf);
        const rowBytes = pw * 4;
        for (let y = 0; y < ph; y++) {
          const srcOff = ((y + cropY) * aDecW + cropX) * 4;
          cropU8.set(srcU8.subarray(srcOff, srcOff + rowBytes), y * rowBytes);
        }
      }
      const tDecode = Date.now();

      // ── 3+4) 色彩矩阵 + 前置镜像 + R/B 复原 + 磨皮 + 边缘自适应锐化 —— 下沉 C++ NAPI ──
      // ArkTS 逐像素循环在 170 万像素下实测 ~5s（JIT/AOT 无法进 800ms 目标），改在
      // 原生 C++ 里一次性完成（~10-30ms）。颜色/磨皮/锐化语义与旧实现逐位一致：
      //   - 矩阵：Flutter ColorFilter.matrix，clamp 0-255；
      //   - R/B 复原：补偿 createPixelMap(RGBA_8888)+ImagePacker 的红蓝对调怪癖；
      //   - 磨皮：肤色掩膜 + 边缘保护，全分辨率仅平滑皮肤像素，非皮肤/强边缘保留原值
      //     （不降采样/放大，杜绝"一开磨皮整张照片都糊"）；
      //   - 锐化：Unsharp 死区版（仅锐化超阈值的边缘，平坦区不放大颗粒）。
      const matrixF64 = new Float64Array(20);
      for (let i = 0; i < 20; i++) { matrixF64[i] = matrixArr[i]; }
      const finBuf = nativeProcessor.processRgba(
        new Uint8Array(cropBuf), pw, ph, matrixF64, Math.max(0, sharpen), isFront, Math.max(0, smooth),
        Math.max(0, vignette), Math.max(0, grain), clarity) as ArrayBuffer;
      if (!finBuf) {
        result.success({ ok: false, error: 'native processRgba failed' });
        return;
      }
      const tTransform = Date.now();
      const tSharpen = tTransform;

      // ── 5) 系统硬件编码 JPEG 并写文件 ──
      const finalBuf = finBuf as ArrayBuffer;
      finalPixelMap = await image.createPixelMap(finalBuf, {
        editable: false,
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        size: { width: pw, height: ph }
      });
      packer = image.createImagePacker();
      const packed = await packer.packing(finalPixelMap, { format: 'image/jpeg', quality: 92 });
      const wfile = fs.openSync(outputPath, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.READ_WRITE);
      wfd = wfile.fd;
      fs.writeSync(wfd, packed);
      fs.closeSync(wfd);
      wfd = -1;
      const tEncode = Date.now();

      // 2026-09-05 补 sharpen/grain 入日志：真机反馈「锐化拉满无感」，需验证参数链
      // Dart→ETS→C++ processRgba 是否透传正确（smooth/sharp/grain 三合一排查）。
      console.info(`[ImageProcessor] processJpeg ok ${pw}x${ph} src=${srcW}x${srcH} dec=${aDecW}x${aDecH} crop=${cropX},${cropY} mirror=${isFront} ` +
        `params smooth=${smooth} sharpen=${sharpen} grain=${grain} vignette=${vignette} clarity=${clarity} ` +
        `decode=${tDecode - tStart}ms transform=${tTransform - tDecode}ms sharpen=${tSharpen - tTransform}ms encode=${tEncode - tSharpen}ms`);
      result.success({
        ok: true,
        width: pw,
        height: ph,
        srcW: srcW,
        srcH: srcH,
        timing: {
          decode: tDecode - tStart,
          transform: tTransform - tDecode,
          sharpen: tSharpen - tTransform,
          encode: tEncode - tSharpen
        }
      });
    } catch (e) {
      const err = e as BusinessError;
      console.error(`[ImageProcessor] processJpeg failed: ${err.code} ${err.message}`);
      result.success({ ok: false, error: err.message || String(e) });
    } finally {
      try { packer?.release(); } catch (e) { console.error('[ImageProcessor] release packer failed', e); }
      try { finalPixelMap?.release(); } catch (e) { console.error('[ImageProcessor] release finalPixelMap failed', e); }
      try { srcPixelMap?.release(); } catch (e) { console.error('[ImageProcessor] release srcPixelMap failed', e); }
      try { source?.release(); } catch (e4) { console.error('[ImageProcessor] release source failed', e4); }
      if (fd !== -1) {
        try { fs.closeSync(fd); } catch (e) { console.error('[ImageProcessor] close fd failed', e); }
      }
      if (wfd !== -1) {
        try { fs.closeSync(wfd); } catch (e) { console.error('[ImageProcessor] close wfd failed', e); }
      }
    }
  }

  /**
   * 把 RGBA_8888 字节编码为 JPEG（系统硬件编码，替代 Dart 软件 img.encodeJpg）。
   * 参数: { rgba: ArrayBuffer, width, height, quality }
   * 返回: { jpeg: ArrayBuffer } 或 { error }
   */
  private async encodeJpegFromRgba(call: MethodCall, result: MethodResult): Promise<void> {
    let pixelMap: image.PixelMap | null = null;
    let packer: image.ImagePacker | null = null;
    try {
      const width: number = call.argument('width') as number;
      const height: number = call.argument('height') as number;
      const quality: number = (call.argument('quality') as number) ?? 90;
      const rgbaArg: Object = call.argument('rgba');
      if (!rgbaArg || !width || !height || width <= 0 || height <= 0) {
        result.success({ error: 'invalid rgba args (no rgba/width/height)' });
        return;
      }
      // flutter_ohos 端 Dart Uint8List 经 StandardMethodCodec 传过来是 ArrayBuffer；
      // 兼容 Uint8Array / ArrayBuffer 两种形态。
      let rgbaBuf: ArrayBuffer;
      if (rgbaArg instanceof Uint8Array) {
        rgbaBuf = rgbaArg.buffer as ArrayBuffer;
      } else {
        rgbaBuf = rgbaArg as ArrayBuffer;
      }
      if (rgbaBuf.byteLength < width * height * 4) {
        result.success({ error: `rgba buffer too small: ${rgbaBuf.byteLength} < ${width * height * 4}` });
        return;
      }

      // OHOS createPixelMap(… RGBA_8888 …) + ImagePacker 编码 JPEG 时把缓冲区
      // R/B 解释对调（实测红变蓝），故先对调 R/B 再编码，保证水印成品颜色正确。
      // 用 Uint32 位运算按像素交换 R/B 字节：小端 RGBA uint32= A<<24|B<<16|G<<8|R，
      // 交换后=R<<16|G<<8|B，即字节序变为 BGRA（R/B 对调）。比逐字节拷贝快数倍。
      const swpBuf = new ArrayBuffer(rgbaBuf.byteLength);
      const srcU32 = new Uint32Array(rgbaBuf);
      const dstU32 = new Uint32Array(swpBuf);
      const nPix = width * height;
      for (let i = 0; i < nPix; i++) {
        const v = srcU32[i];
        dstU32[i] = (v & 0xFF00FF00) | ((v & 0x000000FF) << 16) | ((v & 0x00FF0000) >> 16);
      }

      const opts: image.InitializationOptions = {
        editable: true,
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        size: { width: width, height: height }
      };
      pixelMap = await image.createPixelMap(swpBuf, opts);

      packer = image.createImagePacker();
      const packOpts: image.PackingOption = { format: 'image/jpeg', quality: quality };
      const packed = await packer.packing(pixelMap, packOpts);
      result.success({ jpeg: packed });
    } catch (e) {
      const err = e as BusinessError;
      console.error(`[ImageProcessor] encodeJpegFromRgba failed: ${err.code} ${err.message}`);
      result.success({ error: err.message || String(e) });
    } finally {
      try {
        packer?.release();
      } catch (e) {
        console.error('[ImageProcessor] release packer failed', e);
      }
      try {
        pixelMap?.release();
      } catch (e) {
        console.error('[ImageProcessor] release pixelMap failed', e);
      }
    }
  }

  private async decodeJpegToRgba(call: MethodCall, result: MethodResult): Promise<void> {
    let fd: number = -1;
    let source: image.ImageSource | null = null;
    let pixelMap: image.PixelMap | null = null;
    try {
      const path: string = call.argument('path');
      const targetWidth: number = call.argument('targetWidth') ?? 1600;
      const targetHeight: number = call.argument('targetHeight') ?? 1600;
      if (!path) {
        result.success({ error: 'path empty' });
        return;
      }

      const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      fd = file.fd;
      source = image.createImageSource(fd);
      const info: image.ImageInfo = await source.getImageInfo();
      const srcW = info.size.width;
      const srcH = info.size.height;

      // 等比 fit 到 targetWidth/targetHeight 包围盒内（不放大、不拉伸）
      let decodeW = srcW;
      let decodeH = srcH;
      if (targetWidth > 0 && targetHeight > 0) {
        const scale = Math.min(targetWidth / srcW, targetHeight / srcH);
        if (scale < 1) {
          decodeW = Math.max(1, Math.round(srcW * scale));
          decodeH = Math.max(1, Math.round(srcH * scale));
        }
      }

      const decodeOpts: image.DecodingOptions = {
        desiredSize: { width: decodeW, height: decodeH },
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      };
      pixelMap = await source.createPixelMap(decodeOpts);
      const pixInfo: image.ImageInfo = await pixelMap.getImageInfo();
      const outW = pixInfo.size.width;
      const outH = pixInfo.size.height;

      const buf = new ArrayBuffer(outW * outH * 4);
      await pixelMap.readPixelsToBuffer(buf);
      const rgba = new Uint8Array(buf);

      result.success({
        width: outW,
        height: outH,
        rgba: rgba
      });
    } catch (e) {
      const err = e as BusinessError;
      console.error(`[ImageProcessor] decodeJpegToRgba failed: ${err.code} ${err.message}`);
      result.success({ error: err.message || String(e) });
    } finally {
      try {
        pixelMap?.release();
      } catch (e) {
        console.error('[ImageProcessor] release pixelMap failed', e);
      }
      try {
        source?.release();
      } catch (e) {
        console.error('[ImageProcessor] release source failed', e);
      }
      if (fd !== -1) {
        try {
          fs.closeSync(fd);
        } catch (e) {
          console.error('[ImageProcessor] close fd failed', e);
        }
      }
    }
  }
}