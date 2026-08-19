'use client';

/**
 * 模板后期处理效果 —— 与 Flutter 端 filter_recipe.dart / photo_post_processor.dart
 * 逐行对齐的颜色矩阵与效果算法移植。
 *
 * 参考 Flutter 实现：
 * - composePostProcessMatrix: lumira_app_flutter/lib/features/capture/domain/filter_recipe.dart
 * - 导出流程（矩阵 → 暗角 → 平滑 → 锐化 → 颗粒）:
 *   lumira_app_flutter/lib/features/capture/services/photo_post_processor.dart
 */

export interface PostProcessColor {
  brightness: number;
  contrast: number;
  saturation: number;
  temperature: number;
  tint: number;
}

export interface PreviewEffects {
  color: PostProcessColor;
  lut: string;
  smoothStrength: number;
  sharpen: number;
  vignette: number;
  grain: number;
}

const IDENTITY: number[] = [
  1, 0, 0, 0, 0,
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
];

function clamp255(v: number): number {
  return Math.max(0, Math.min(255, v));
}

/** 4x5 矩阵乘法（5x5 扩展后相乘再截取 4x5）。左乘：result = a · b */
function multiplyMatrices(a: number[], b: number[]): number[] {
  const aExt = [...a, 0, 0, 0, 0, 1];
  const bExt = [...b, 0, 0, 0, 0, 1];
  const result = new Array(25).fill(0);
  for (let i = 0; i < 5; i++) {
    for (let j = 0; j < 5; j++) {
      let sum = 0;
      for (let k = 0; k < 5; k++) {
        sum += aExt[i * 5 + k] * bExt[k * 5 + j];
      }
      result[i * 5 + j] = sum;
    }
  }
  return result.slice(0, 20);
}

/** 亮度矩阵：factor = 1 + v/100，对角缩放 */
function brightnessMatrix(v: number): number[] {
  const factor = 1 + v / 100;
  return [
    factor, 0, 0, 0, 0,
    0, factor, 0, 0, 0,
    0, 0, factor, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/** 对比度矩阵：c = 1 + v/100，t = (1-c)/2，offset = t*255 */
function contrastMatrix(v: number): number[] {
  const c = 1 + v / 100;
  const t = (1 - c) / 2;
  const offset = t * 255;
  return [
    c, 0, 0, 0, offset,
    0, c, 0, 0, offset,
    0, 0, c, 0, offset,
    0, 0, 0, 1, 0,
  ];
}

/** 饱和度矩阵：Rec.709 亮度权重 */
function saturationMatrix(v: number): number[] {
  const lumR = 0.2126;
  const lumG = 0.7152;
  const lumB = 0.0722;
  const s = 1 + v / 100;
  const inv = 1 - s;
  return [
    inv * lumR + s, inv * lumG, inv * lumB, 0, 0,
    inv * lumR, inv * lumG + s, inv * lumB, 0, 0,
    inv * lumR, inv * lumG, inv * lumB + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/** 色温矩阵：正值加 R 减 B，负值相反 */
function temperatureMatrix(v: number): number[] {
  const t = v / 100;
  if (t >= 0) {
    const rBoost = t * 0.2;
    const bReduce = t * 0.1;
    return [
      1 + rBoost, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1 - bReduce, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }
  const rReduce = -t * 0.1;
  const bBoost = -t * 0.2;
  return [
    1 - rReduce, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1 + bBoost, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/** 色调矩阵：hue-rotate 近似（与 filter_recipe.dart _tintMatrix 逐字一致） */
function tintMatrix(v: number): number[] {
  if (v === 0) return [...IDENTITY];
  const angle = v * 0.9 * (3.14159 / 180);
  const cosA = Math.cos(angle);
  const sinA = Math.sin(angle);
  return [
    0.213 + cosA * 0.787 - sinA * 0.213, 0.715 - cosA * 0.715 - sinA * 0.715, 0.072 - cosA * 0.072 + sinA * 0.928, 0, 0,
    0.213 - cosA * 0.213 + sinA * 0.143, 0.715 + cosA * 0.285 + sinA * 0.140, 0.072 - cosA * 0.072 - sinA * 0.283, 0, 0,
    0.213 - cosA * 0.213 - sinA * 0.787, 0.715 - cosA * 0.715 + sinA * 0.715, 0.072 + cosA * 0.928 + sinA * 0.072, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/** 灰度矩阵：NTSC 权重 */
function grayscaleMatrix(): number[] {
  return [
    0.3086, 0.6094, 0.082, 0, 0,
    0.3086, 0.6094, 0.082, 0, 0,
    0.3086, 0.6094, 0.082, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/** 棕褐矩阵 sepia(t)：在单位矩阵与 sepia 之间按 t 插值（0~1） */
function sepiaMatrix(t: number): number[] {
  const sepia = [
    0.393, 0.769, 0.189, 0, 0,
    0.349, 0.686, 0.168, 0, 0,
    0.272, 0.534, 0.131, 0, 0,
    0, 0, 0, 1, 0,
  ];
  return sepia.map((v, i) => IDENTITY[i] * (1 - t) + v * t);
}

/** 统一滤镜库名称（与 filter_recipe.dart unifiedFilters 一致） */
const LUT_NAMES = [
  'none', 'cinematic', 'vintage', 'warm_film', 'cool_film', 'pastel', 'fuji',
  'portrait', 'japanese', 'japanese_fresh', 'cream', 'cyberpunk', 'night_cyber',
  'hk_neon', 'sepia_classic', 'mist', 'rouge', 'twilight', 'cyan',
  'noir', 'fine_art_bw', 'silver', 'morandi', 'muted_gray', 'heavy_film',
];

/** LUT 预设矩阵（与 filter_recipe.dart composeLutMatrix 逐字一致） */
function composeLutMatrix(lutName: string): number[] | null {
  switch (lutName) {
    case 'none':
      return null;
    case 'cinematic':
      // contrast(1.15) saturate(0.9) hue-rotate(-8deg) brightness(0.97) → B·Tint·S·C
      return multiplyMatrices(
        brightnessMatrix(-3),
        multiplyMatrices(
          tintMatrix(-8.8),
          multiplyMatrices(saturationMatrix(-10), contrastMatrix(15)),
        ),
      );
    case 'vintage':
      // sepia(0.35) contrast(1.1) brightness(1.05) saturate(0.85) → Sat·B·C·Sepia
      return multiplyMatrices(
        saturationMatrix(-15),
        multiplyMatrices(
          brightnessMatrix(5),
          multiplyMatrices(contrastMatrix(10), sepiaMatrix(0.35)),
        ),
      );
    case 'bw':
      // grayscale(1) contrast(1.1) → C·Grayscale
      return multiplyMatrices(contrastMatrix(10), grayscaleMatrix());
    case 'warm_film':
      // sepia(0.2) saturate(1.15) brightness(1.03) hue-rotate(-5deg) → Tint·B·S·Sepia
      return multiplyMatrices(
        tintMatrix(-5.5),
        multiplyMatrices(
          brightnessMatrix(3),
          multiplyMatrices(saturationMatrix(15), sepiaMatrix(0.2)),
        ),
      );
    case 'cool_film':
      // saturate(0.9) brightness(0.98) hue-rotate(8deg) → Tint·B·S
      return multiplyMatrices(
        tintMatrix(8.8),
        multiplyMatrices(brightnessMatrix(-2), saturationMatrix(-10)),
      );
    case 'pastel':
      // contrast(0.92) saturate(0.85) brightness(1.08) → B·S·C
      return multiplyMatrices(
        brightnessMatrix(8),
        multiplyMatrices(saturationMatrix(-15), contrastMatrix(-8)),
      );
    case 'fuji':
      // saturate(1.2) contrast(1.05) hue-rotate(-3deg) brightness(1.02) → B·Tint·C·S
      return multiplyMatrices(
        brightnessMatrix(2),
        multiplyMatrices(
          tintMatrix(-3.3),
          multiplyMatrices(contrastMatrix(5), saturationMatrix(20)),
        ),
      );
    case 'portrait':
      // saturate(1.05) contrast(1.05) brightness(1.03) sepia(0.05) → Sepia·B·C·S
      return multiplyMatrices(
        sepiaMatrix(0.05),
        multiplyMatrices(
          brightnessMatrix(3),
          multiplyMatrices(contrastMatrix(5), saturationMatrix(5)),
        ),
      );
    case 'japanese':
      // saturate(0.85) contrast(0.92) brightness(1.1) hue-rotate(3deg) → Tint·B·C·S
      return multiplyMatrices(
        tintMatrix(3.3),
        multiplyMatrices(
          brightnessMatrix(10),
          multiplyMatrices(contrastMatrix(-8), saturationMatrix(-15)),
        ),
      );
    case 'cyberpunk':
      // saturate(1.4) contrast(1.2) hue-rotate(-15deg) brightness(0.95) → B·Tint·C·S
      return multiplyMatrices(
        brightnessMatrix(-5),
        multiplyMatrices(
          tintMatrix(-16.5),
          multiplyMatrices(contrastMatrix(20), saturationMatrix(40)),
        ),
      );
    case 'sepia_classic':
      // sepia(0.7) contrast(1.05) brightness(1.02) → B·C·Sepia
      return multiplyMatrices(
        brightnessMatrix(2),
        multiplyMatrices(contrastMatrix(5), sepiaMatrix(0.7)),
      );
    case 'mist':
      // contrast(0.88) brightness(1.12) saturate(0.9) → S·B·C
      return multiplyMatrices(
        saturationMatrix(-10),
        multiplyMatrices(brightnessMatrix(12), contrastMatrix(-12)),
      );
    case 'rouge':
      // sepia(0.2) saturate(1.1) hue-rotate(-10deg) brightness(1.02) → B·Tint·S·Sepia
      return multiplyMatrices(
        brightnessMatrix(2),
        multiplyMatrices(
          tintMatrix(-11),
          multiplyMatrices(saturationMatrix(10), sepiaMatrix(0.2)),
        ),
      );
    case 'twilight':
      // saturate(1.15) hue-rotate(15deg) contrast(1.05) brightness(0.95) → B·C·Tint·S
      return multiplyMatrices(
        brightnessMatrix(-5),
        multiplyMatrices(
          contrastMatrix(5),
          multiplyMatrices(tintMatrix(16.5), saturationMatrix(15)),
        ),
      );
    case 'cyan':
      // saturate(1.1) hue-rotate(20deg) contrast(1.05) brightness(1.02) → B·C·Tint·S
      return multiplyMatrices(
        brightnessMatrix(2),
        multiplyMatrices(
          contrastMatrix(5),
          multiplyMatrices(tintMatrix(22), saturationMatrix(10)),
        ),
      );
    // ─── 统一滤镜库新增（去重合并系统滤镜 + 新增风格，与 filter_recipe.dart 逐字一致）───
    // 黑白类（由 mono / bw 合并）
    case 'noir':
      return multiplyMatrices(
        brightnessMatrix(-5),
        multiplyMatrices(contrastMatrix(30), grayscaleMatrix()),
      );
    case 'fine_art_bw':
      return multiplyMatrices(
        brightnessMatrix(5),
        multiplyMatrices(contrastMatrix(35), grayscaleMatrix()),
      );
    case 'silver':
      return multiplyMatrices(
        brightnessMatrix(8),
        multiplyMatrices(
          contrastMatrix(-5),
          multiplyMatrices(sepiaMatrix(0.2), grayscaleMatrix()),
        ),
      );
    // 日系清新
    case 'japanese_fresh':
      return multiplyMatrices(
        tintMatrix(4.4),
        multiplyMatrices(
          brightnessMatrix(15),
          multiplyMatrices(contrastMatrix(-12), saturationMatrix(-18)),
        ),
      );
    // 奶油感
    case 'cream':
      return multiplyMatrices(
        tintMatrix(-5.5),
        multiplyMatrices(
          brightnessMatrix(12),
          multiplyMatrices(
            contrastMatrix(-6),
            multiplyMatrices(saturationMatrix(-5), sepiaMatrix(0.1)),
          ),
        ),
      );
    // 夜景赛博
    case 'night_cyber':
      return multiplyMatrices(
        brightnessMatrix(-15),
        multiplyMatrices(
          tintMatrix(33),
          multiplyMatrices(contrastMatrix(15), saturationMatrix(35)),
        ),
      );
    // 港风霓虹
    case 'hk_neon':
      return multiplyMatrices(
        brightnessMatrix(5),
        multiplyMatrices(
          tintMatrix(-60.5),
          multiplyMatrices(contrastMatrix(10), saturationMatrix(30)),
        ),
      );
    // 莫兰迪
    case 'morandi':
      return multiplyMatrices(
        brightnessMatrix(8),
        multiplyMatrices(
          contrastMatrix(10),
          multiplyMatrices(sepiaMatrix(0.08), saturationMatrix(-35)),
        ),
      );
    // 低饱和高级灰
    case 'muted_gray':
      return multiplyMatrices(
        brightnessMatrix(4),
        multiplyMatrices(
          contrastMatrix(15),
          multiplyMatrices(sepiaMatrix(0.1), saturationMatrix(-60)),
        ),
      );
    // 浓厚胶片
    case 'heavy_film':
      return multiplyMatrices(
        tintMatrix(-8.8),
        multiplyMatrices(
          brightnessMatrix(-2),
          multiplyMatrices(
            saturationMatrix(-10),
            multiplyMatrices(contrastMatrix(25), sepiaMatrix(0.45)),
          ),
        ),
      );
    default:
      return null;
  }
}

/**
 * 合成最终 4x5 颜色矩阵（顺序与 Flutter 一致）：
 * brightness → contrast → saturation → temperature → tint → LUT
 * （每步左乘，后应用的在最左）
 */
export function composePostProcessMatrix(effects: PreviewEffects): number[] {
  const { color } = effects;
  let matrix = brightnessMatrix(color.brightness);
  matrix = multiplyMatrices(contrastMatrix(color.contrast), matrix);
  matrix = multiplyMatrices(saturationMatrix(color.saturation), matrix);
  matrix = multiplyMatrices(temperatureMatrix(color.temperature), matrix);
  matrix = multiplyMatrices(tintMatrix(color.tint), matrix);
  const lut = composeLutMatrix(effects.lut);
  if (lut) {
    matrix = multiplyMatrices(lut, matrix);
  }
  return matrix;
}

/** 判断矩阵是否为单位矩阵 */
function isIdentity(m: number[]): boolean {
  for (let i = 0; i < 4; i++) {
    for (let j = 0; j < 4; j++) {
      const expected = i === j ? 1 : 0;
      if (Math.abs(m[i * 5 + j] - expected) > 0.001) return false;
    }
    if (Math.abs(m[i * 5 + 4]) > 0.001) return false;
  }
  return true;
}

/** 逐像素应用 4x5 颜色矩阵 */
export function applyColorMatrix(
  data: Uint8ClampedArray,
  matrix: number[],
): void {
  for (let i = 0; i < data.length; i += 4) {
    const r = data[i];
    const g = data[i + 1];
    const b = data[i + 2];
    const a = data[i + 3];
    data[i] = clamp255(matrix[0] * r + matrix[1] * g + matrix[2] * b + matrix[3] * a + matrix[4]);
    data[i + 1] = clamp255(matrix[5] * r + matrix[6] * g + matrix[7] * b + matrix[8] * a + matrix[9]);
    data[i + 2] = clamp255(matrix[10] * r + matrix[11] * g + matrix[12] * b + matrix[13] * a + matrix[14]);
  }
}

/**
 * 锐化卷积（与 Flutter img.convolution 相同核）：
 * filter = [0, -a, 0, -a, 1+4a, -a, 0, -a, 0]，a = sharpen/100
 */
export function applySharpen(
  data: Uint8ClampedArray,
  width: number,
  height: number,
  sharpen: number,
): void {
  const a = Math.min(1, Math.max(0, sharpen / 100));
  if (a <= 0) return;
  const k = [0, -a, 0, -a, 1 + 4 * a, -a, 0, -a, 0];
  const src = new Uint8ClampedArray(data);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const outIdx = (y * width + x) * 4;
      for (let c = 0; c < 3; c++) {
        let sum = 0;
        for (let ky = -1; ky <= 1; ky++) {
          for (let kx = -1; kx <= 1; kx++) {
            const px = Math.min(width - 1, Math.max(0, x + kx));
            const py = Math.min(height - 1, Math.max(0, y + ky));
            const idx = (py * width + px) * 4 + c;
            sum += src[idx] * k[(ky + 1) * 3 + (kx + 1)];
          }
        }
        data[outIdx + c] = clamp255(sum);
      }
    }
  }
}

/** 颗粒噪声（强度公式与 Flutter 一致：noise = (rand*2-1) * intensity * 64） */
export function applyGrain(
  data: Uint8ClampedArray,
  grain: number,
): void {
  const intensity = Math.min(1, Math.max(0, grain / 100)) * 0.25;
  if (intensity <= 0) return;
  for (let i = 0; i < data.length; i += 4) {
    const noise = (Math.random() * 2 - 1) * intensity * 64;
    data[i] = clamp255(data[i] + noise);
    data[i + 1] = clamp255(data[i + 1] + noise);
    data[i + 2] = clamp255(data[i + 2] + noise);
  }
}

export interface RenderTarget {
  width: number;
  height: number;
  effects: PreviewEffects;
}

/**
 * 渲染模板效果到 canvas。
 * 顺序与 Flutter 导出流程一致：颜色矩阵 → 暗角 → 平滑 → 锐化 → 颗粒。
 * 任一步失败时回退为仅绘制原图（保证预览可用）。
 */
export function renderTemplateImage(
  canvas: HTMLCanvasElement,
  image: HTMLImageElement,
  target: RenderTarget,
): void {
  const ctx = canvas.getContext('2d');
  if (!ctx) return;
  const { width, height, effects } = target;
  canvas.width = width;
  canvas.height = height;
  ctx.clearRect(0, 0, width, height);

  // 1. 绘制封面（cover 裁剪铺满）
  const imgW = image.naturalWidth;
  const imgH = image.naturalHeight;
  const scale = Math.max(width / imgW, height / imgH);
  const dw = imgW * scale;
  const dh = imgH * scale;
  ctx.drawImage(image, (width - dw) / 2, (height - dh) / 2, dw, dh);

  try {
    // 2. 颜色矩阵
    const matrix = composePostProcessMatrix(effects);
    if (!isIdentity(matrix)) {
      const imageData = ctx.getImageData(0, 0, width, height);
      applyColorMatrix(imageData.data, matrix);
      ctx.putImageData(imageData, 0, 0);
    }

    // 3. 暗角（radial 渐变，与 Flutter Gradient.radial 一致）
    if (effects.vignette > 0) {
      const alpha = (effects.vignette / 100) * 0.5;
      const cx = width / 2;
      const cy = height / 2;
      const radius = Math.sqrt(cx * cx + cy * cy);
      const grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, radius);
      grad.addColorStop(0, 'rgba(0,0,0,0)');
      grad.addColorStop(0.5, 'rgba(0,0,0,0)');
      grad.addColorStop(1, `rgba(0,0,0,${alpha})`);
      ctx.fillStyle = grad;
      ctx.fillRect(0, 0, width, height);
    }

    // 4. 平滑（磨皮近似：轻微高斯模糊。Flutter 为双边滤波，此处用模糊近似预览）
    if (effects.smoothStrength > 0) {
      const radius = (effects.smoothStrength / 100) * 1.2;
      const tmp = document.createElement('canvas');
      tmp.width = width;
      tmp.height = height;
      const tmpCtx = tmp.getContext('2d');
      if (tmpCtx) {
        tmpCtx.drawImage(canvas, 0, 0);
        ctx.clearRect(0, 0, width, height);
        ctx.filter = `blur(${radius}px)`;
        ctx.drawImage(tmp, 0, 0);
        ctx.filter = 'none';
      }
    }

    // 5. 锐化 + 颗粒
    if (effects.sharpen > 0 || effects.grain > 0) {
      const imageData = ctx.getImageData(0, 0, width, height);
      if (effects.sharpen > 0) {
        applySharpen(imageData.data, width, height, effects.sharpen);
      }
      if (effects.grain > 0) {
        applyGrain(imageData.data, effects.grain);
      }
      ctx.putImageData(imageData, 0, 0);
    }
  } catch {
    // 图像跨域导致 canvas 被污染时，跳过像素级效果，仅保留原图
  }
}

export { LUT_NAMES };
