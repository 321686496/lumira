// lumira-server/packages/backend/src/modules/ai/render-approx.service.ts
// RenderApproxService：用 sharp 在服务端近似复刻 App 端 PostProcess 渲染，供 P4 实拍闭环做「App 实拍 ≈ 期望」的校准参考。
//
// 处理顺序（与 App filterRecipe/bakeCanvas 语义一致）：
//   亮度/对比度 → 白平衡色罩 → 色温 → 饱和 → 磨皮(近似) → 暗角 → 颗粒 → LUT(simulated) → fillLight 色罩叠加
//
// 说明：真实 3D LUT / 皮肤磨皮不在 sharp 能力内，本实现用「色阶曲线 + 模糊/锐化 + 复合矩阵」近似，
// 不追求逐像素一致（登记到 docs/future-optimizations.md）。
import sharp from 'sharp';
import type { Sharp, Metadata, Matrix3x3 } from 'sharp';

export interface RenderApproxOptions {
  postProcess: Record<string, unknown>;
  fillLight?: { enabled: boolean; color: string; intensity: number };
}

// 亮度转灰系数（Rec.709）
const LUMINANCE: Matrix3x3 = [
  [0.2126, 0.7152, 0.0722],
  [0.2126, 0.7152, 0.0722],
  [0.2126, 0.7152, 0.0722],
];

const IDENTITY: Matrix3x3 = [
  [1, 0, 0],
  [0, 1, 0],
  [0, 0, 1],
];

/** 把 mix 系数 m∈[0,1] 的矩阵 a 与 b 线性混合 */
function mix(a: Matrix3x3, b: Matrix3x3, m: number): Matrix3x3 {
  return a.map((row, r) => row.map((v, c) => v + (b[r][c] - v) * m)) as Matrix3x3;
}

/** clamp 到 [lo,hi]；非有限数 → 回退 fallback */
function clampNum(v: unknown, lo: number, hi: number, fallback = 0): number {
  const n = typeof v === 'number' && Number.isFinite(v) ? v : fallback;
  return Math.max(lo, Math.min(hi, n));
}

/** 取对象字段数值，缺失/非法 → fallback */
function numOf(obj: Record<string, unknown> | undefined, key: string, fallback: number): number {
  if (!obj || typeof obj[key] === 'undefined') return fallback;
  const n = obj[key];
  if (typeof n !== 'number' || !Number.isFinite(n)) return fallback;
  return n;
}

/** 十六进制/已知名字 → [r,g,b]；未知 → null */
function parseColor(color: string): [number, number, number] | null {
  const names: Record<string, [number, number, number]> = {
    warm: [255, 170, 102],
    cool: [122, 168, 255],
    white: [255, 255, 255],
    blue: [110, 160, 255],
    orange: [255, 150, 70],
    purple: [170, 130, 255],
  };
  const key = (color ?? '').trim().toLowerCase();
  if (names[key]) return names[key];
  const m = /^#?([0-9a-f]{6}|[0-9a-f]{3})$/i.exec(key);
  if (m) {
    let hex = m[1];
    if (hex.length === 3) {
      hex = hex
        .split('')
        .map((ch) => ch + ch)
        .join('');
    }
    const int = parseInt(hex, 16);
    return [(int >> 16) & 255, (int >> 8) & 255, int & 255];
  }
  return null;
}

// LUT 预设 → 用 recomb/grayscale/tint/modulate/linear 近似 App 的复合 filter 链。
// 顺序：先做颜色分区矩阵，再叠加亮度/饱和度调整。
function applyLut(p: Sharp, lut: string): Sharp {
  switch (lut.toLowerCase()) {
    case 'cinematic':
      // contrast(1.15) saturate(0.9) hue-rotate(-8deg) brightness(0.97)
      return p.recomb(mix(LUMINANCE, IDENTITY, 0.15)).modulate({ saturation: 0.9, brightness: 0.97 }).linear(1.15, -(1.15 - 1) * 128);
    case 'vintage':
      // sepia(0.35) contrast(1.1) brightness(1.05) saturate(0.85)
      return p.tint({ r: 244, g: 226, b: 193 }).linear(1.1, -(1.1 - 1) * 128).modulate({ saturation: 0.85, brightness: 1.05 });
    case 'bw':
      // grayscale(1) contrast(1.1)
      return p.recomb(LUMINANCE).linear(1.1, -(1.1 - 1) * 128);
    case 'warm_film':
      // sepia(0.2) saturate(1.15) brightness(1.03) hue-rotate(-5deg)
      return p.tint({ r: 252, g: 244, b: 229 }).modulate({ saturation: 1.15, brightness: 1.03 }).recomb(hueRotate(-5));
    case 'cool_film':
      // saturate(0.9) brightness(0.98) hue-rotate(8deg)
      return p.modulate({ saturation: 0.9, brightness: 0.98 }).recomb(hueRotate(8));
    case 'pastel':
      // contrast(0.92) saturate(0.85) brightness(1.08)
      return p.linear(0.92, (0.92 - 1) * 128).modulate({ saturation: 0.85, brightness: 1.08 });
    case 'fuji':
      // saturate(1.2) contrast(1.05) hue-rotate(-3deg) brightness(1.02)
      return p.modulate({ saturation: 1.2, brightness: 1.02 }).linear(1.05, -(1.05 - 1) * 128).recomb(hueRotate(-3));
    case 'portrait':
      // saturate(1.05) contrast(1.05) brightness(1.03) sepia(0.05)
      return p.modulate({ saturation: 1.05, brightness: 1.03 }).linear(1.05, -(1.05 - 1) * 128).tint({ r: 250, g: 244, b: 236 });
    case 'japanese':
      // saturate(0.85) contrast(0.92) brightness(1.1) hue-rotate(3deg)
      return p.modulate({ saturation: 0.85, brightness: 1.1 }).linear(0.92, (0.92 - 1) * 128).recomb(hueRotate(3));
    case 'cyberpunk':
      // saturate(1.4) contrast(1.2) hue-rotate(-15deg) brightness(0.95)
      return p.modulate({ saturation: 1.4, brightness: 0.95 }).linear(1.2, -(1.2 - 1) * 128).recomb(hueRotate(-15));
    case 'sepia_classic':
      // sepia(0.7) contrast(1.05) brightness(1.02)
      return p.tint({ r: 240, g: 214, b: 168 }).linear(1.05, -(1.05 - 1) * 128).modulate({ brightness: 1.02 });
    case 'mist':
      // contrast(0.88) brightness(1.12) saturate(0.9)
      return p.linear(0.88, (0.88 - 1) * 128).modulate({ saturation: 0.9, brightness: 1.12 });
    case 'rouge':
      // sepia(0.2) saturate(1.1) hue-rotate(-10deg) brightness(1.02)
      return p.tint({ r: 252, g: 238, b: 222 }).modulate({ saturation: 1.1, brightness: 1.02 }).recomb(hueRotate(-10));
    case 'twilight':
      // saturate(1.15) hue-rotate(15deg) contrast(1.05) brightness(0.95)
      return p.modulate({ saturation: 1.15, brightness: 0.95 }).linear(1.05, -(1.05 - 1) * 128).recomb(hueRotate(15));
    case 'cyan':
      // saturate(1.1) hue-rotate(20deg) contrast(1.05) brightness(1.02)
      return p.modulate({ saturation: 1.1, brightness: 1.02 }).linear(1.05, -(1.05 - 1) * 128).recomb(hueRotate(20));
    default:
      return p;
  }
}

/** 相对色相旋转（度）的颜色矩阵 */
function hueRotate(deg: number): Matrix3x3 {
  const a = (deg * Math.PI) / 180;
  const cos = Math.cos(a);
  const sin = Math.sin(a);
  return [
    [0.213 + cos * 0.787 - sin * 0.213, 0.715 - cos * 0.715 - sin * 0.715, 0.072 - cos * 0.072 + sin * 0.928],
    [0.213 - cos * 0.213 + sin * 0.143, 0.715 + cos * 0.285 + sin * 0.14, 0.072 - cos * 0.072 - sin * 0.283],
    [0.213 - cos * 0.213 - sin * 0.787, 0.715 - cos * 0.715 + sin * 0.715, 0.072 + cos * 0.928 + sin * 0.072],
  ];
}

/**
 * sharp 近似渲染管线：按顺序应用 bright/contrast → WB → 色温 → 饱和 → 磨皮 → 暗角 → 颗粒 → LUT → fillLight。
 * 所有参数做 clamp 兜底，异常一律返回输入（不 throw）。
 */
export class RenderApproxService {
  async apply(input: Buffer, opts: RenderApproxOptions): Promise<Buffer> {
    try {
      const post = opts?.postProcess ?? {};
      const color =
        typeof post.color === 'object' && post.color !== null && !Array.isArray(post.color)
          ? (post.color as Record<string, unknown>)
          : {};

      // 1) 亮度 + 对比度（brightness -100~100 → 线性缩放；contrast -100~100 → 斜率）
      const brightness = clampNum(numOf(color, 'brightness', 0), -100, 100);
      const contrast = clampNum(numOf(color, 'contrast', 0), -100, 100);
      // 合进一条 linear：y = k·x + offset，shadow/midtone 之母保持近似（体感接近 brightness/contrast）
      const k = 1 + contrast / 100;
      const bMul = 1 + brightness / 100;
      let pipe = sharp(input).linear(k, (bMul - k) * 255);

      // 白平衡色罩（tint -100~100：绿/品轴微调，近似用 R/B 通道微偏）
      const tintCustom = clampNum(numOf(color, 'tint', 0), -100, 100);
      if (tintCustom !== 0) {
        // tint>0 偏绿、tint<0 偏品 → 用 recomb 对 R/B 做窄幅缩放近似
        const rb = 1 + tintCustom / 400;
        pipe = pipe.recomb([
          [rb, 0, 0],
          [0, 1, 0],
          [0, 0, rb],
        ]);
      }

      // 色温 temperature -100~100（暖 + 冷）+ 饱和度
      const temp = clampNum(numOf(color, 'temperature', 0), -100, 100);
      if (temp !== 0) {
        const warmness = temp > 0 ? Math.min(1, temp / 100) : -Math.min(1, -temp / 100);
        const tintStr = warmness > 0 ? { r: 255, g: 244, b: 224 } : { r: 224, g: 244, b: 255 };
        const tintAlpha = Math.abs(warmness) * 40;
        const tintColor = {
          r: Math.round(128 + (tintStr.r - 128) * (tintAlpha / 128)),
          g: Math.round(128 + (tintStr.g - 128) * (tintAlpha / 128)),
          b: Math.round(128 + (tintStr.b - 128) * (tintAlpha / 128)),
        };
        pipe = pipe.tint(tintColor).modulate({ saturation: 1 + warmness * 0.1 });
      }
      const saturation = clampNum(numOf(color, 'saturation', 0), -100, 100);
      if (saturation !== 0) {
        pipe = pipe.modulate({ saturation: 1 + saturation / 100 });
      }

      // 磨皮 近似（smoothStrength 0~100 → 局部轻微模糊；low 值几乎无感。sharp blur sigma 下限 0.3）
      const smooth = clampNum(numOf(post, 'smoothStrength', 0), 0, 100);
      if (smooth > 0) {
        pipe = pipe.blur(Math.max(0.3, 0.3 + smooth / 400));
      }
      // 锐化（sharpen 0~100，独立于磨皮）
      const sharpen = clampNum(numOf(post, 'sharpen', 0), 0, 100);
      if (sharpen > 0) {
        pipe = pipe.sharpen({ sigma: 0.6 + (sharpen / 100) * 1.5 });
      }

      // 暗角 vignette 0~100 → 四角压暗（近似：径向灰 overlay，blend multiply）
      const vignette = clampNum(numOf(post, 'vignette', 0), 0, 100);
      if (vignette > 0) {
        pipe = pipe.composite([
          {
            input: await buildVignetteOverlay(await sharp(input).metadata()),
            blend: 'multiply',
          },
        ]);
      }

      // 颗粒 grain 0~100 → 近似：轻微力度对比/亮度提升（sharp 无 per-pixel 噪点，非真实颗粒）
      const grain = clampNum(numOf(post, 'grain', 0), 0, 100);
      if (grain > 0) {
        pipe = pipe.linear(1 + grain / 600, -(grain / 1200) * 255).modulate({ brightness: 1 + grain / 1500 });
      }

      // LUT（simulated）
      const lut = typeof post.lut === 'string' ? post.lut : 'none';
      pipe = applyLut(pipe, lut);
      // 系统内置滤镜 systemFilter —— 近似并入 LUT 层
      const sys = typeof post.systemFilter === 'string' ? post.systemFilter : 'none';
      pipe = applySystemFilter(pipe, sys);

      // 先落一次 PNG，得到 flatten 后 RGB；fillLight 在这之后叠加
      let rendered = await pipe.png().toBuffer();

      // fillLight 色罩叠加
      const fl = opts?.fillLight;
      if (fl && fl.enabled === true) {
        const intensity = clampNum(fl.intensity, 0, 1, 0);
        const shade = intensity > 0 ? parseColor(fl.color) ?? parseColor('warm')! : null;
        if (intensity > 0 && shade) {
          rendered = await this.overlayColor(rendered, shade, intensity);
        }
      }

      return rendered;
    } catch (err) {
      // 极端异常（含损坏输入）：兜底返回原图，绝不让渲染失败阻断上层
      if (process.env.RENDER_DEBUG) {
        // eslint-disable-next-line no-console
        console.error('[RenderApprox] apply error:', (err as Error).message);
      }
      return Buffer.isBuffer(input) ? input : input;
    }
  }

  private async overlayColor(img: Buffer, shade: [number, number, number], intensity: number): Promise<Buffer> {
    const meta = await sharp(img).metadata();
    const w = meta.width ?? 1;
    const h = meta.height ?? 1;
    const big = Math.max(1, w * h);
    const rgb = Buffer.alloc(big * 4);
    for (let i = 0; i < big; i++) {
      rgb[i * 4] = shade[0];
      rgb[i * 4 + 1] = shade[1];
      rgb[i * 4 + 2] = shade[2];
      rgb[i * 4 + 3] = Math.round(255 * intensity);
    }
    return sharp(img)
      .composite([
        {
          input: await sharp(rgb, { raw: { width: w, height: h, channels: 4 } }).png().toBuffer(),
        },
      ])
      .png()
      .toBuffer();
  }
}

/** 生成暗角 overlay：中心透明、四角随强度压暗的灰 overlay（blend: multiply 近似压暗） */
async function buildVignetteOverlay(meta: Metadata): Promise<Buffer> {
  const w = meta.width ?? 1;
  const h = meta.height ?? 1;
  const cx = w / 2;
  const cy = h / 2;
  const maxR = Math.hypot(w, h) / 2;
  const px = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const d = Math.hypot(x - cx, y - cy) / maxR;
      // 亮度：中心 1，边上降到 0.78（≈ vingette 强开时的「四角压暗」）
      const lum = 1 - 0.22 * Math.min(1, Math.max(0, d));
      const i = (y * w + x) * 4;
      const v = Math.round(255 * lum);
      px[i] = v;
      px[i + 1] = v;
      px[i + 2] = v;
      px[i + 3] = 255;
    }
  }
  return sharp(px, { raw: { width: w, height: h, channels: 4 } }).png().toBuffer();
}

/** 系统滤镜近似（对应 SYSTEM_FILTERS） */
function applySystemFilter(p: Sharp, sys: string): Sharp {
  switch (sys.toLowerCase()) {
    case 'vivid':
      return p.linear(1.1, -(1.1 - 1) * 128).modulate({ saturation: 1.25, brightness: 1.02 });
    case 'vivid_warm':
      return p.tint({ r: 250, g: 241, b: 225 }).modulate({ saturation: 1.2, brightness: 1.03 }).linear(1.08, -(1.08 - 1) * 128);
    case 'vivid_cool':
      return p.modulate({ saturation: 1.15, brightness: 1.02 }).recomb(hueRotate(8)).linear(1.08, -(1.08 - 1) * 128);
    case 'mono':
      return p.recomb(LUMINANCE);
    case 'silver':
      return p.recomb(LUMINANCE).linear(0.95, 0.03 * 255).modulate({ brightness: 1.08 });
    case 'noir':
      return p.recomb(LUMINANCE).linear(1.3, -0.05 * 255).modulate({ brightness: 0.95 });
    default:
      return p;
  }
}