import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos';
import MethodChannel, {
  MethodCallHandler,
  MethodResult
} from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import { image } from '@kit.ImageKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@ohos.base';

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
   *   sharpen: 有效锐化值（>=kMinLiveSharpen，未锐化需为 0）
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
      // 解码包围盒：略高于输出（maxDim），为 cover 裁切留出余量，避免放大模糊。
      const box = Math.max(1600, Math.round(maxDim * 1.25));
      const dScale = Math.min(box / srcW, box / srcH, 1.0);
      const dW = Math.max(1, Math.round(srcW * dScale));
      const dH = Math.max(1, Math.round(srcH * dScale));
      srcPixelMap = await source.createPixelMap({
        desiredSize: { width: dW, height: dH },
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      });
      const dInfo: image.ImageInfo = await srcPixelMap.getImageInfo();
      const pw = dInfo.size.width;
      const ph = dInfo.size.height;
      const srcBuf = new ArrayBuffer(pw * ph * 4);
      await srcPixelMap.readPixelsToBuffer(srcBuf);
      const tDecode = Date.now();

      // ── 2) 几何参数（与 Flutter _applyColorMatrixOnGpu 完全一致）──
      const jpegIsLandscape = pw > ph;
      const needRotate = (isPortrait && jpegIsLandscape) || (!isPortrait && !jpegIsLandscape);
      const alignRotation: number = needRotate ? (isPortrait ? 90 : 270) : 0;
      const needMirror = isFront;
      const swapDims = alignRotation === 90 || alignRotation === 270;

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
      const iOutW = Math.round(outW);
      const iOutH = Math.round(outH);
      const coverScale = swapDims
        ? Math.max(outW / ph, outH / pw)
        : Math.max(outW / pw, outH / ph);
      const sxScale = (needMirror ? -1 : 1) * coverScale;
      const syScale = coverScale;
      const cW = outW * 0.5;
      const cH = outH * 0.5;
      const halfW = pw * 0.5;
      const halfH = ph * 0.5;

      // 展开色彩矩阵（20 元素）
      const m0 = matrixArr[0], m1 = matrixArr[1], m2 = matrixArr[2], m3 = matrixArr[3], m4 = matrixArr[4];
      const m5 = matrixArr[5], m6 = matrixArr[6], m7 = matrixArr[7], m8 = matrixArr[8], m9 = matrixArr[9];
      const m10 = matrixArr[10], m11 = matrixArr[11], m12 = matrixArr[12], m13 = matrixArr[13], m14 = matrixArr[14];
      const m15 = matrixArr[15], m16 = matrixArr[16], m17 = matrixArr[17], m18 = matrixArr[18], m19 = matrixArr[19];

      // ── 3) 逐输出像素：反向映射 + cover 裁切 + 镜像/旋转 + 双线性采样 + 色彩矩阵 ──
      const outLen = iOutW * iOutH * 4;
      const outBuf = new ArrayBuffer(outLen);
      const outU8 = new Uint8Array(outBuf);
      const srcU8 = new Uint8Array(srcBuf);
      for (let oy = 0; oy < iOutH; oy++) {
        for (let ox = 0; ox < iOutW; ox++) {
          const pRotX = (ox - cW) / sxScale;
          const pRotY = (oy - cH) / syScale;
          let cx: number;
          let cy: number;
          if (alignRotation === 90) {
            cx = pRotY; cy = -pRotX;
          } else if (alignRotation === 180) {
            cx = -pRotX; cy = -pRotY;
          } else if (alignRotation === 270) {
            cx = -pRotY; cy = pRotX;
          } else {
            cx = pRotX; cy = pRotY;
          }
          const sx = cx + halfW;
          const sy = cy + halfH;

          // 双线性采样（边缘 clamp 复制）
          let x0 = Math.floor(sx);
          if (x0 < 0) { x0 = 0; } else if (x0 > pw - 1) { x0 = pw - 1; }
          let y0 = Math.floor(sy);
          if (y0 < 0) { y0 = 0; } else if (y0 > ph - 1) { y0 = ph - 1; }
          let x1 = x0 + 1;
          if (x1 > pw - 1) { x1 = pw - 1; }
          let y1 = y0 + 1;
          if (y1 > ph - 1) { y1 = ph - 1; }
          let fx = sx - x0;
          if (fx < 0) { fx = 0; } else if (fx > 1) { fx = 1; }
          let fy = sy - y0;
          if (fy < 0) { fy = 0; } else if (fy > 1) { fy = 1; }
          const ix = 1 - fx;
          const iy = 1 - fy;
          const i00 = (y0 * pw + x0) << 2;
          const i01 = (y0 * pw + x1) << 2;
          const i10 = (y1 * pw + x0) << 2;
          const i11 = (y1 * pw + x1) << 2;
          const wA = ix * iy;
          const wB = fx * iy;
          const wC = ix * fy;
          const wD = fx * fy;
          const r = wA * srcU8[i00] + wB * srcU8[i01] + wC * srcU8[i10] + wD * srcU8[i11];
          const g = wA * srcU8[i00 + 1] + wB * srcU8[i01 + 1] + wC * srcU8[i10 + 1] + wD * srcU8[i11 + 1];
          const b = wA * srcU8[i00 + 2] + wB * srcU8[i01 + 2] + wC * srcU8[i10 + 2] + wD * srcU8[i11 + 2];

          // 色彩矩阵（Flutter ColorFilter.matrix 语义，clamp 0-255，行大序 R/G/B/A）
          let nr = m0 * r + m1 * g + m2 * b + m3 * 255 + m4;
          let ng = m5 * r + m6 * g + m7 * b + m8 * 255 + m9;
          let nb = m10 * r + m11 * g + m12 * b + m13 * 255 + m14;
          if (nr < 0) { nr = 0; } else if (nr > 255) { nr = 255; }
          if (ng < 0) { ng = 0; } else if (ng > 255) { ng = 255; }
          if (nb < 0) { nb = 0; } else if (nb > 255) { nb = 255; }

          const oi = (oy * iOutW + ox) << 2;
          outU8[oi] = Math.round(nr);
          outU8[oi + 1] = Math.round(ng);
          outU8[oi + 2] = Math.round(nb);
          outU8[oi + 3] = 255;
        }
      }
      const tTransform = Date.now();

      // ── 4) 锐化（Unsharp 3x3，与 Dart image_processing_service 一致）──
      // kernel: [0,-a,0; -a,1+4a,-a; 0,-a,0]，仅 enhance
      let finalU8 = outU8;
      if (sharpen > 0) {
        const a = Math.min(sharpen / 100.0, 1.0);
        const center = 1 + 4 * a;
        const convBuf = new ArrayBuffer(outLen);
        const convU8 = new Uint8Array(convBuf);
        for (let oy = 0; oy < iOutH; oy++) {
          const y0s = oy > 0 ? oy - 1 : oy;
          const y1s = oy < iOutH - 1 ? oy + 1 : oy;
          for (let ox = 0; ox < iOutW; ox++) {
            const x0s = ox > 0 ? ox - 1 : ox;
            const x1s = ox < iOutW - 1 ? ox + 1 : ox;
            const ci = (oy * iOutW + ox) << 2;
            const ui = (y0s * iOutW + ox) << 2;
            const di = (y1s * iOutW + ox) << 2;
            const li = (oy * iOutW + x0s) << 2;
            const ri = (oy * iOutW + x1s) << 2;
            for (let ch = 0; ch < 3; ch++) {
              let v = center * outU8[ci + ch] -
                a * (outU8[ui + ch] + outU8[di + ch] + outU8[li + ch] + outU8[ri + ch]);
              if (v < 0) { v = 0; } else if (v > 255) { v = 255; }
              convU8[ci + ch] = Math.round(v);
            }
            convU8[ci + 3] = 255;
          }
        }
        finalU8 = convU8;
      }
      const tSharpen = Date.now();

      // ── 5) 系统硬件编码 JPEG 并写文件 ──
      const finalBuf = finalU8.buffer as ArrayBuffer;
      finalPixelMap = await image.createPixelMap(finalBuf, {
        editable: false,
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        size: { width: iOutW, height: iOutH }
      });
      packer = image.createImagePacker();
      const packed = await packer.packing(finalPixelMap, { format: 'image/jpeg', quality: 90 });
      const wfile = fs.openSync(outputPath, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.READ_WRITE);
      wfd = wfile.fd;
      fs.writeSync(wfd, packed);
      fs.closeSync(wfd);
      wfd = -1;
      const tEncode = Date.now();

      console.info(`[ImageProcessor] processJpeg ok ${iOutW}x${iOutH} src=${pw}x${ph} rot=${alignRotation} mirror=${needMirror} `
        + `decode=${tDecode - tStart}ms transform=${tTransform - tDecode}ms sharpen=${tSharpen - tTransform}ms encode=${tEncode - tSharpen}ms`);
      result.success({
        ok: true,
        width: iOutW,
        height: iOutH,
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

      const opts: image.InitializationOptions = {
        editable: true,
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        size: { width: width, height: height }
      };
      pixelMap = await image.createPixelMap(rgbaBuf, opts);

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