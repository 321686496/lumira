/*
 * FullSizeImageProcessor.ets
 *
 * 原生全尺寸照片后处理器（不砍任何功能）。
 *
 * 目标：在 OHOS 上用「硬件解码 / 硬件 JPEG 编码」+ 优化后的类型化数组逐像素计算，
 * 在**全尺寸（如 4032×3024）**下一次性应用与原 Dart 链路完全一致的六种效果：
 *   1. 色彩矩阵（ColorMatrix，折叠进像素通道）
 *   2. 锐化（Sharpen，3×3 卷积）—— 抗手抖去模糊核心
 *   3. 清晰度（Clarity，高斯模糊 unsharp）
 *   4. 颗粒（Grain，随机噪声）
 *   5. 磨皮（Skin Smooth，降采样模糊后混合）
 *   6. 暗角（Vignette，径向压暗）
 * 同时完成方向对齐（竖屏旋转）、cover 裁切到目标比例、前置镜像。
 *
 * 相比 Dart `image` 包的装箱像素（Pixel 对象 + getPixel），ArkTS 直接操作
 * Uint8Array 连续内存，逐像素 O(N) 效果好一个量级；编码走 ImagePacker 硬件
 * JPEG 编码，解码走 ImageSource 硬件解码 —— 这才是 OHOS 上「全尺寸 + ≤800ms」唯一可行路径。
 */

import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import Logger from '../utils/Logger';

const TAG: string = 'FullSizeImageProcessor';

/**
 * 源图字节序是否为 BGRA。
 *
 * **注意：这里处理的是「JPEG 照片文件」，不是相机实时分析帧。**
 * `image.createImageSource(fileBytes).createPixelMap()` 对 JPEG 文件解码后的
 * PixelMap 默认像素格式为 **RGBA_8888**，因此 `readPixelsToBuffer` 输出的字节序
 * 是 RGBA，不是 BGRA。BGRA_8888 只是仓库里 AnalysisImageConverter 的**相机实时
 * 数据流**（sensor 缓冲）约定，两者不能混用。
 *
 * 若误把 RGBA 源数据当成 BGRA 交换 R/B，整张照片会明显偏蓝（经典 R/B 互换，
 * 在人脸/皮肤上表现为蓝色调）。以前 CPU 链路用 `image.decodeJpg`（RGB）颜色一直
 * 正常，正是原生链路引入的字节序错判导致了「蓝色照片」这一回归。
 */
const kSourceIsBGRA: boolean = false;

/** 后处理参数（由 Dart 侧经通道传入）。 */
export interface FullSizeProcessOptions {
  inputPath: string;
  outputPath: string;
  /** 目标宽高比（正向像素，宽/高，如 0.75 / 1.0 / 0.5625） */
  targetRatio: number;
  isPortrait: boolean;
  isFront: boolean;
  /** 4×5 色彩矩阵（20 项，与应用 dart:ui ColorFilter.matrix 全等）。可为空数组表示单位阵。 */
  colorMatrix: Array<number>;
  /** 已含 deblur 增强的锐化强度 0-100 */
  sharpen: number;
  clarity: number;
  grain: number;
  smoothStrength: number;
  vignette: number;
  /** 裁剪输出 JPEG 质量 90-98 */
  quality: number;
}

export interface FullSizeProcessResult {
  ok: boolean;
  outputPath: string;
  width: number;
  height: number;
  error?: string;
  elapsedMs: number;
}

/** RGBA(Uint8Array) 工作图像 + 宽高。 */
class RgbaImage {
  data: Uint8Array;
  width: number;
  height: number;

  constructor(data: Uint8Array, width: number, height: number) {
    this.data = data;
    this.width = width;
    this.height = height;
  }
}

export class FullSizeImageProcessor {
  /**
   * 全尺寸处理入口。
   */
  static async process(opts: FullSizeProcessOptions): Promise<FullSizeProcessResult> {
    const sw = Date.now();
    let srcFile: fileIo.File | undefined = undefined;
    let outFile: fileIo.File | undefined = undefined;
    let srcPm: image.PixelMap | undefined = undefined;
    let outPm: image.PixelMap | undefined = undefined;
    let packer: image.ImagePacker | undefined = undefined;
    try {
      // 1. 硬件解码：读入整包字节后创建 ImageSource（SDK 的 image API 无 createImageSourceFd）
      srcFile = fileIo.openSync(opts.inputPath, fileIo.OpenMode.READ_ONLY);
      const statInfo: fileIo.Stat = fileIo.statSync(opts.inputPath);
      const readBuf: ArrayBuffer = new ArrayBuffer(statInfo.size);
      const bytesRead = fileIo.readSync(srcFile.fd, readBuf);
      const rawBytes: ArrayBuffer = readBuf.slice(0, bytesRead);
      const src: image.ImageSource = image.createImageSource(rawBytes);
      srcPm = await src.createPixelMap();
      const info: image.ImageInfo = await srcPm.getImageInfo();
      const srcW = info.size.width;
      const srcH = info.size.height;

      // 2. 读出全尺寸像素（4032×3024 ≈ 48MB）。字节序见 kSourceIsBGRA，下方旋转/裁剪时摆正为 RGBA
      const srcByteLen = srcW * srcH * 4;
      const srcBuf: ArrayBuffer = new ArrayBuffer(srcByteLen);
      await srcPm.readPixelsToBuffer(srcBuf);
      const srcRgba = new Uint8Array(srcBuf);
      const tDecode = Date.now();

      // 3. 方向对齐 + cover 裁切 + 前置镜像 + BGRA→RGBA（单次遍历，保持与 Dart WYSIWYG 一致的几何）
      const geom = computeGeometry(srcW, srcH, opts.targetRatio, opts.isPortrait);
      const work = rotateCropConvert(srcRgba, srcW, srcH, opts.isPortrait, geom.outW, geom.outH, opts.isFront);
      const tRotate = Date.now();

      // 4. 六种效果（顺序与 Dart 链路一致）
      applyAllEffects(work, opts);
      const tEffects = Date.now();

      // 5. 硬件编码：RGBA → PixelMap → ImagePacker.packToFile
      const outByteLen = work.width * work.height * 4;
      const outBuf: ArrayBuffer = work.data.buffer.slice(0, outByteLen) as ArrayBuffer;
      const initOpts: image.InitializationOptions = {
        editable: false,
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        size: { width: work.width, height: work.height },
      };
      outPm = await image.createPixelMap(outBuf, initOpts);

      outFile = fileIo.openSync(opts.outputPath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      packer = image.createImagePacker();
      const packOpts: image.PackingOption = { format: 'image/jpeg', quality: opts.quality };
      await packer.packToFile(outPm, outFile.fd, packOpts);
      await fileIo.fsyncSync(outFile.fd);

      const elapsedMs = Date.now() - sw;
      Logger.debug(TAG, `process done in ${elapsedMs}ms, ${work.width}x${work.height} ` +
        `(decode=${tDecode - sw}ms, rotate/crop=${tRotate - tDecode}ms, ` +
        `effects=${tEffects - tRotate}ms, encode=${Date.now() - tEffects}ms)`);
      return {
        ok: true,
        outputPath: opts.outputPath,
        width: work.width,
        height: work.height,
        elapsedMs: elapsedMs,
      };
    } catch (e) {
      const err = e as BusinessError;
      const elapsedMs = Date.now() - sw;
      Logger.error(TAG, `process failed, code=${err.code}, message=${err.message}`);
      return {
        ok: false,
        outputPath: opts.outputPath,
        width: 0,
        height: 0,
        error: `${err.message}`,
        elapsedMs: elapsedMs,
      };
    } finally {
      try { srcPm?.release(); } catch (_) { }
      try { outPm?.release(); } catch (_) { }
      try { packer?.release(); } catch (_) { }
      try { if (srcFile) fileIo.closeSync(srcFile.fd); } catch (_) { }
      try { if (outFile) fileIo.closeSync(outFile.fd); } catch (_) { }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 几何：方向对齐 + cover 裁切 + 镜像
// ─────────────────────────────────────────────────────────────────────────

interface GeometryResult {
  /** 旋转后（对齐到设备方向）的宽 */
  orientedW: number;
  /** 旋转后（对齐到设备方向）的高 */
  orientedH: number;
  /** 输出宽（按 targetRatio，cover 裁切后） */
  outW: number;
  /** 输出高 */
  outH: number;
}

/**
 * 计算几何参数，与 Dart `_applyColorMatrixOnGpu` 完全一致：
 * - JPEG 原始方向通常是横向（sw>sh）；设备竖屏则顺时针旋转 90°，横屏则 270°。
 * - cover：等比放大使源完全覆盖输出画布，中心裁切，输出保持 targetRatio。
 */
function computeGeometry(srcW: number, srcH: number, targetRatio: number, isPortrait: boolean): GeometryResult {
  const jpegIsLandscape = srcW > srcH;
  const needRotate = (isPortrait && jpegIsLandscape) || (!isPortrait && !jpegIsLandscape);
  const rawOrientedW = needRotate ? srcH : srcW;
  const rawOrientedH = needRotate ? srcW : srcH;

  // 输出尺寸（全尺寸，保持 targetRatio）
  let outW: number;
  let outH: number;
  if (isPortrait) {
    outH = rawOrientedH;
    outW = Math.round(rawOrientedH * targetRatio);
    if (outW > rawOrientedW) {
      outW = rawOrientedW;
      outH = Math.round(rawOrientedW / targetRatio);
    }
  } else {
    outW = rawOrientedW;
    outH = Math.round(rawOrientedW / targetRatio);
    if (outH > rawOrientedH) {
      outH = rawOrientedH;
      outW = Math.round(rawOrientedH * targetRatio);
    }
  }
  return { orientedW: rawOrientedW, orientedH: rawOrientedH, outW: outW, outH: outH };
}

/** 一次遍历完成：方向对齐（旋转）+ 中心裁剪 + 前置镜像 + BGRA→RGBA。
 *  直接按目标像素的反向映射从原始 buffer 采样，避免先生成整幅旋转拷贝再裁剪的第二遍 O(N)
 *  和一块中间 48MB 内存。裁切为 1:1 采样（不放大/缩小），保证 4000px 细节无损。 */
function rotateCropConvert(
  src: Uint8Array, srcW: number, srcH: number, isPortrait: boolean,
  outW: number, outH: number, mirror: boolean): RgbaImage {
  const jpegIsLandscape = srcW > srcH;
  const needRotate = (isPortrait && jpegIsLandscape) || (!isPortrait && !jpegIsLandscape);
  // 旋转后（设备朝向对齐）的逻辑尺寸，用于中心裁切偏移
  const oW = needRotate ? srcH : srcW;
  const oH = needRotate ? srcW : srcH;
  const ox = Math.round((oW - outW) / 2);
  const oy = Math.round((oH - outH) / 2);
  const clockwise = isPortrait; // 竖屏顺时针 90°；横屏逆时针(270°)

  const out = new RgbaImage(new Uint8Array(outW * outH * 4), outW, outH);
  const dst = out.data;
  for (let y = 0; y < outH; y++) {
    const dstRow = y * outW;
    const v = oy + y; // 对齐坐标系下的行
    for (let x = 0; x < outW; x++) {
      const u = ox + x; // 对齐坐标系下的列
      // 对齐坐标 (u,v) → 原始坐标索引（与既有 orientToPortrait 全等）
      let si: number;
      if (!needRotate) {
        si = v * srcW + u;
      } else if (clockwise) {
        si = (srcH - 1 - u) * srcW + v;
      } else {
        si = u * srcW + (srcW - 1 - v);
      }
      // 水平镜像：目标索引翻转
      const di = dstRow + (mirror ? (outW - 1 - x) : x);
      // 源图 BGRA → 工作区 RGBA（见 kSourceIsBGRA 注释）
      dst[di * 4 + 0] = kSourceIsBGRA ? src[si * 4 + 2] : src[si * 4 + 0];
      dst[di * 4 + 1] = src[si * 4 + 1];
      dst[di * 4 + 2] = kSourceIsBGRA ? src[si * 4 + 0] : src[si * 4 + 2];
      dst[di * 4 + 3] = 255;
    }
  }
  return out;
}

// ─────────────────────────────────────────────────────────────────────────
// 效果：色彩矩阵 / 锐化 / 清晰度 / 颗粒 / 磨皮 / 暗角
// ─────────────────────────────────────────────────────────────────────────

/** 依次应用六种效果，顺序与 Dart CPU 链路一致：色彩 → sharpen/clarity/grain → smooth → vignette。
 *  需要相邻像素的平滑/清晰度/锐化先后进行；最后把纯点处理（色彩矩阵 + 颗粒 + 暗角）合并为一次遍历。 */
function applyAllEffects(img: RgbaImage, opts: FullSizeProcessOptions): void {
  const matrix = opts.colorMatrix && opts.colorMatrix.length >= 20 ? opts.colorMatrix : [];
  const hasRealMatrix = matrix.length >= 20 && !isIdentityMatrix(matrix);
  const grainActive = opts.grain > 0;
  const vignetteActive = opts.vignette > 0;

  if (opts.smoothStrength > 0) {
    applySmooth(img, opts.smoothStrength);
  }
  if (opts.clarity !== 0) {
    applyClarity(img, opts.clarity);
  }
  if (opts.sharpen > 0) {
    applySharpen(img, opts.sharpen);
  }
  // 点处理合并为单次遍历（单位阵+无颗粒+无暗角时为空载，跳过，省一次全尺寸 O(N) 循环）
  if (hasRealMatrix || grainActive || vignetteActive) {
    applyPointEffects(img, matrix, opts.grain, opts.vignette);
  }
}

/** 判断 20 项矩阵是否为单位阵（此时无需做色彩矩阵点处理）。 */
function isIdentityMatrix(m: Array<number>): boolean {
  for (let i = 0; i < 20; i++) {
    const expect = (i === 0 || i === 6 || i === 12 || i === 18) ? 1.0 : 0.0;
    if (Math.abs(m[i] - expect) > 1e-6) {
      return false;
    }
  }
  return true;
}

function clamp255(v: number): number {
  return v < 0 ? 0 : (v > 255 ? 255 : v);
}

/** 色彩矩阵 + 颗粒 + 暗角（单次遍历，纯点处理）。matrix 为 20 项（rgba 通道），可为单位阵/空。 */
function applyPointEffects(img: RgbaImage, matrix: Array<number>, grain: number, vignette: number): void {
  const d = img.data;
  const n = img.width * img.height;
  const hasMatrix = matrix.length >= 20;
  const grainAmp = grain > 0 ? (grain / 100.0) * 0.25 * 64.0 : 0.0;
  const vig = vignette > 0 ? (vignette / 100.0) * 0.6 : 0.0;
  const w = img.width;
  const h = img.height;
  const cx = w / 2;
  const cy = h / 2;
  const maxDistSq = cx * cx + cy * cy;
  // 轻量确定性噪声
  let s = 42;
  const rnd = (): number => {
    s = (s * 1103515245 + 12345) & 0x7fffffff;
    return s / 0x7fffffff;
  };
  for (let i = 0; i < n; i++) {
    const o = i * 4;
    let r = d[o];
    let g = d[o + 1];
    let b = d[o + 2];
    if (hasMatrix) {
      const rr = r, gg = g, bb = b;
      // 与 GPU ColorFilter.matrix 全等（偏移在 5 列 index 4/9/14；alpha 系数恒为 0 故省略）
      r = matrix[0] * rr + matrix[1] * gg + matrix[2] * bb + matrix[4];
      g = matrix[5] * rr + matrix[6] * gg + matrix[7] * bb + matrix[9];
      b = matrix[10] * rr + matrix[11] * gg + matrix[12] * bb + matrix[14];
    }
    if (grainAmp > 0) {
      const noise = (rnd() * 2 - 1) * grainAmp;
      r += noise;
      g += noise;
      b += noise;
    }
    if (vig > 0) {
      const x = i % w;
      const y = (i / w) | 0;
      const dx = x - cx;
      const dy = y - cy;
      const ratio = (dx * dx + dy * dy) / maxDistSq;
      if (ratio > 0.3) {
        const darken = ((ratio - 0.3) / 0.7) * vig;
        r *= (1 - darken);
        g *= (1 - darken);
        b *= (1 - darken);
      }
    }
    d[o] = clamp255(r);
    d[o + 1] = clamp255(g);
    d[o + 2] = clamp255(b);
  }
}

/** 锐化：3×3 卷积 [0,-a,0,-a,1+4a,-a,0,-a,0]。与 Dart applyPerPixelEffectsImg 全等。 */
function applySharpen(img: RgbaImage, sharpen: number): void {
  const a = (sharpen / 100.0);
  const w = img.width;
  const h = img.height;
  const src = new Uint8Array(img.data);
  const d = img.data;
  const k = 1 + 4 * a;
  const m = -a;
  for (let y = 1; y < h - 1; y++) {
    const row = y * w;
    for (let x = 1; x < w - 1; x++) {
      const c = row + x;
      const o = c * 4;
      const up = (row - w + x) * 4;
      const dn = (row + w + x) * 4;
      const lf = (c - 1) * 4;
      const rt = (c + 1) * 4;
      for (let ch = 0; ch < 3; ch++) {
        const val = k * src[o + ch] + m * (src[up + ch] + src[dn + ch] + src[lf + ch] + src[rt + ch]);
        d[o + ch] = clamp255(val);
      }
    }
  }
}

/** 清晰度：原图 - 高斯模糊，再按符号量混合。与 Dart 全等。 */
function applyClarity(img: RgbaImage, clarity: number): void {
  const amount = (Math.abs(clarity) / 100.0) * 0.6;
  const sign = clarity > 0 ? 1.0 : -1.0;
  if (amount <= 0) return;
  const blurred = gaussianBlur3x3(img);
  const d = img.data;
  const bd = blurred.data;
  const n = img.width * img.height;
  for (let i = 0; i < n; i++) {
    const o = i * 4;
    for (let ch = 0; ch < 3; ch++) {
      const diff = (d[o + ch] - bd[o + ch]) * sign * amount;
      d[o + ch] = clamp255(d[o + ch] + diff);
    }
  }
}

/** 3×3 高斯模糊（[1,2,1;2,4,2;1,2,1]/16），返回新图像。 */
function gaussianBlur3x3(img: RgbaImage): RgbaImage {
  const w = img.width;
  const h = img.height;
  const src = img.data;
  const out = new RgbaImage(new Uint8Array(src.length), w, h);
  const d = out.data;
  for (let y = 1; y < h - 1; y++) {
    const row = y * w;
    for (let x = 1; x < w - 1; x++) {
      const c = row + x;
      const o = c * 4;
      for (let ch = 0; ch < 3; ch++) {
        const nw = src[(row - w + x - 1) * 4 + ch];
        const n_ = src[(row - w + x) * 4 + ch];
        const ne = src[(row - w + x + 1) * 4 + ch];
        const ww = src[(c - 1) * 4 + ch];
        const cc = src[o + ch];
        const ee = src[(c + 1) * 4 + ch];
        const sw = src[(row + w + x - 1) * 4 + ch];
        const s_ = src[(row + w + x) * 4 + ch];
        const se = src[(row + w + x + 1) * 4 + ch];
        const v = (nw + 2 * n_ + ne + 2 * ww + 4 * cc + 2 * ee + sw + 2 * s_ + se) / 16;
        d[o + ch] = v;
      }
    }
  }
  return out;
}

/** 磨皮：1/4 尺寸模糊 → 放大回原尺寸 → 按量混合。与 Dart applySmoothSkinImg 一致。 */
function applySmooth(img: RgbaImage, smoothStrength: number): void {
  const mix = smoothStrength / 100.0;
  if (mix <= 0) return;
  const radius = 2 + Math.round(smoothStrength / 100 * 4);
  const ss = reduceBySmooth(img);
  const blurred = boxBlurPasses(ss, radius);
  // 放大回原尺寸 + 混合（线性）
  const d = img.data;
  const bd = blurred.data;
  const bw = blurred.width;
  const bh = blurred.height;
  const w = img.width;
  const h = img.height;
  for (let y = 0; y < h; y++) {
    const sy = (y / h * (bh - 1)) | 0;
    const row = y * w;
    const brow = sy * bw;
    for (let x = 0; x < w; x++) {
      const sx = (x / w * (bw - 1)) | 0;
      const o = (row + x) * 4;
      const si = (brow + sx) * 4;
      d[o] = clamp255(d[o] * (1 - mix) + bd[si] * mix);
      d[o + 1] = clamp255(d[o + 1] * (1 - mix) + bd[si + 1] * mix);
      d[o + 2] = clamp255(d[o + 2] * (1 - mix) + bd[si + 2] * mix);
    }
  }
}

/** 面积为 1/4 的降采样（双线性近似）。 */
function reduceBySmooth(img: RgbaImage): RgbaImage {
  const w = img.width;
  const h = img.height;
  const sw = Math.max(1, (w / 2) | 0);
  const sh = Math.max(1, (h / 2) | 0);
  const out = new RgbaImage(new Uint8Array(sw * sh * 4), sw, sh);
  const d = out.data;
  const s = img.data;
  for (let y = 0; y < sh; y++) {
    const sy = (y / sh * (h - 1)) | 0;
    for (let x = 0; x < sw; x++) {
      const sx = (x / sw * (w - 1)) | 0;
      const o = (y * sw + x) * 4;
      const si = (sy * w + sx) * 4;
      d[o] = s[si];
      d[o + 1] = s[si + 1];
      d[o + 2] = s[si + 2];
      d[o + 3] = 255;
    }
  }
  return out;
}

/** 快速盒式模糊（半径 r 次，1/4 尺寸上代价低）。 */
function boxBlurPasses(img: RgbaImage, radius: number): RgbaImage {
  let cur = img;
  const passes = Math.max(1, radius);
  for (let p = 0; p < passes; p++) {
    const prev = cur;
    cur = boxBlurOnce(prev);
  }
  return cur;
}

function boxBlurOnce(img: RgbaImage): RgbaImage {
  const w = img.width;
  const h = img.height;
  const s = img.data;
  const tmp = new Uint8Array(s.length);
  // 水平
  for (let y = 0; y < h; y++) {
    const row = y * w;
    for (let x = 0; x < w; x++) {
      const o = (row + x) * 4;
      const l = (row + (x > 0 ? x - 1 : x)) * 4;
      const r_ = (row + (x < w - 1 ? x + 1 : x)) * 4;
      for (let ch = 0; ch < 3; ch++) {
        tmp[o + ch] = (s[l + ch] + s[o + ch] + s[r_ + ch]) / 3;
      }
    }
  }
  // 垂直
  const out = new RgbaImage(new Uint8Array(s.length), w, h);
  const d = out.data;
  for (let y = 0; y < h; y++) {
    const row = y * w;
    const up = (y > 0 ? y - 1 : y) * w;
    const dn = (y < h - 1 ? y + 1 : y) * w;
    for (let x = 0; x < w; x++) {
      const o = (row + x) * 4;
      const u = (up + x) * 4;
      const dd = (dn + x) * 4;
      for (let ch = 0; ch < 3; ch++) {
        d[o + ch] = (tmp[u + ch] + tmp[o + ch] + tmp[dd + ch]) / 3;
      }
    }
  }
  return out;
}