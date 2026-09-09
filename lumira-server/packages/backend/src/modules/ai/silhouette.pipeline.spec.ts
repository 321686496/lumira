// lumira-server/packages/backend/src/modules/ai/silhouette.pipeline.spec.ts
// 剪影本地管线单测（Task 8，TDD）
// 分两层：
//   ① 纯函数层：computeAlphaBbox 包围盒 + 模型缺失 503 分支——无模型/无 onnxruntime 依赖，任何环境必跑；
//   ② 集成层：真实 RMBG 推理 + sharp 合成——模型文件存在才执行（本机跑过 fetch-rmbg-model.mjs），
//      否则 describe.skip（CI 无模型时自动跳过，保持全绿）。
// 集成测试图为程序合成的 256x256「噪声背景 + 居中人形」（RMBG 对纯色合成图会整图判前景，
// 噪声底 + 人形的宏观结构才能被正确抠图，实验见任务报告）；统计输出 raw 的 alpha/亮度分布
// 做宽松阈值断言：背景透明、人物保留、剪影可裁剪。

import * as fs from 'fs';
import * as path from 'path';
import sharp from 'sharp';
import { computeAlphaBbox, generateSilhouettePng, getRmbgSession } from './silhouette.pipeline';

/** 与 pipeline.resolveModelPath 同口径：src/modules/ai 上溯 3 级 = packages/backend */
const MODEL_PATH = process.env.RMBG_MODEL_PATH
  || path.join(__dirname, '../../../assets/models/rmbg-1.4.quant.onnx');
const describeIntegration = fs.existsSync(MODEL_PATH) ? describe : describe.skip;

/** RMBG CPU 推理 + 42MB 模型首次加载耗时较长，集成用例放宽超时 */
const INTEGRATION_TIMEOUT_MS = 180_000;

/** 确定性伪随机（LCG）：噪声背景可复现 */
function makeRand(seed: number): () => number {
  let s = seed;
  return () => {
    s = (s * 1103515245 + 12345) & 0x7fffffff;
    return (s >> 8) / 0x7fffff;
  };
}

/**
 * 256x256 测试图（PNG）：噪声背景 + 居中人形（圆形头 + 梯形躯干，「高对比竖向条纹衫」）。
 * - RMBG-1.4 训练于自然图像，对纯色块合成图（红底黑圆）会整图判前景；
 *   噪声底 + 显著居中人形的结构能被正确分割（背景 alpha≈0、人形保留）。
 * - colour-dodge 线稿需要人物内部存在明暗跳变才会留下深色线稿；低对比灰渐变主体
 *   几乎全被 dodge 成白色，实测深色像素 <10。故主体用 10px 周期的高对比竖条纹
 *   （20/165），结合背景噪声可稳定产出数百个深色线稿像素（实验值 ~794）。
 */
function buildTestImage(): Promise<Buffer> {
  const size = 256;
  const cx = 128;
  const headCy = 80;
  const headR = 32;
  const bodyTop = 117;
  const bodyBottom = 245;
  const rand = makeRand(42);
  const raw = Buffer.alloc(size * size * 3);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const i = (y * size + x) * 3;
      const n = rand();
      raw[i] = Math.round(140 + 50 * n); // 噪声背景（暖色杂讯）
      raw[i + 1] = Math.round(150 + 40 * n);
      raw[i + 2] = Math.round(120 + 50 * n);
      const dhx = x - cx;
      const dhy = y - headCy;
      const halfW = y >= bodyTop && y <= bodyBottom ? 21 + (y - bodyTop) * (59 - 21) / (bodyBottom - bodyTop) : -1;
      const inBody = halfW > 0 && Math.abs(x - cx) <= halfW;
      if (dhx * dhx + dhy * dhy <= headR * headR || inBody) {
        // 高对比竖向条纹（20px 暗条/165px 亮条 + 微噪声），供 sketch 线稿产生深色轮廓
        const g = Math.round((x % 10 < 4 ? 20 : 165) + 8 * n);
        raw[i] = g;
        raw[i + 1] = g - 5;
        raw[i + 2] = g - 10;
      }
    }
  }
  return sharp(raw, { raw: { width: size, height: size, channels: 3 } }).png().toBuffer();
}

interface PixelStats {
  total: number;        // 总像素数
  transparent: number;  // alpha < 10（背景区）
  lightOpaque: number;  // 非透明且亮度 >= 100（浅色区）
  darkOpaque: number;   // 非透明且亮度 < 100（深色线稿/实心区）
}

/** 输出 PNG 的像素分布统计（solid/sketch 均输出 RGBA 4ch，取末通道为 alpha） */
async function pixelStats(png: Buffer): Promise<PixelStats> {
  const { data, info } = await sharp(png).raw().toBuffer({ resolveWithObject: true });
  const ch = info.channels;
  const stats: PixelStats = { total: info.width * info.height, transparent: 0, lightOpaque: 0, darkOpaque: 0 };
  for (let i = 0; i < data.length; i += ch) {
    const alpha = data[i + ch - 1];
    if (alpha < 10) {
      stats.transparent++;
      continue;
    }
    const lum = ch === 2
      ? data[i]
      : 0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2];
    if (lum < 100) stats.darkOpaque++;
    else stats.lightOpaque++;
  }
  return stats;
}

// ===== 纯函数：computeAlphaBbox（无模型依赖） =====

describe('computeAlphaBbox（纯函数）', () => {
  it('全零 alpha → null（无前景）', () => {
    expect(computeAlphaBbox(new Float32Array(64 * 64), 64, 64)).toBeNull();
    expect(computeAlphaBbox(new Uint8Array(64 * 64), 64, 64)).toBeNull();
  });

  it('中心 32x32 方块（Float32 前景=1）→ bbox 含方块 + 5% padding', () => {
    const alpha = new Float32Array(64 * 64);
    for (let y = 16; y < 48; y++) {
      for (let x = 16; x < 48; x++) alpha[y * 64 + x] = 1;
    }
    // pad = round(32 * 0.05) = 2 → [14,49]，尺寸 36x36
    expect(computeAlphaBbox(alpha, 64, 64)).toEqual({ left: 14, top: 14, width: 36, height: 36 });
  });

  it('方块贴左上角 → padding clamp 到图像边界（不出负坐标/不越界）', () => {
    const alpha = new Float32Array(64 * 64);
    for (let y = 0; y < 32; y++) {
      for (let x = 0; x < 32; x++) alpha[y * 64 + x] = 1;
    }
    // pad=2：left/top 钳到 0，right/bottom = 33 → 34x34
    expect(computeAlphaBbox(alpha, 64, 64)).toEqual({ left: 0, top: 0, width: 34, height: 34 });
  });

  it('Uint8 输入按 0-255 归一化后比较：alpha=76（<0.3）不算前景，alpha=77 算', () => {
    expect(computeAlphaBbox(new Uint8Array([76]), 1, 1)).toBeNull();
    // pad = round(1 * 0.05) = 0 → 恰好整幅 1x1
    expect(computeAlphaBbox(new Uint8Array([77]), 1, 1)).toEqual({ left: 0, top: 0, width: 1, height: 1 });
  });

  it('自定义 threshold / padRatio：padRatio=0 → bbox 恰好贴合前景', () => {
    const alpha = new Float32Array(64 * 64);
    for (let y = 8; y < 20; y++) {
      for (let x = 30; x < 50; x++) alpha[y * 64 + x] = 0.6;
    }
    expect(computeAlphaBbox(alpha, 64, 64, 0.5, 0)).toEqual({ left: 30, top: 8, width: 20, height: 12 });
    // threshold=0.7 时 0.6 的前景全部低于阈值 → null
    expect(computeAlphaBbox(alpha, 64, 64, 0.7, 0)).toBeNull();
  });
});

// ===== 模型缺失分支（任何环境必跑：用假 RMBG_MODEL_PATH 构造缺失场景） =====

describe('getRmbgSession / generateSilhouettePng（模型缺失 → 503）', () => {
  const ENV_KEY = 'RMBG_MODEL_PATH';
  const savedValue = process.env[ENV_KEY];

  afterEach(() => {
    if (savedValue === undefined) delete process.env[ENV_KEY];
    else process.env[ENV_KEY] = savedValue;
  });

  it('getRmbgSession：模型文件不存在 → ServiceUnavailableException，message 引导执行下载脚本', async () => {
    process.env[ENV_KEY] = path.join(__dirname, 'no-such-model.onnx');
    await expect(getRmbgSession()).rejects.toMatchObject({
      status: 503,
      message: expect.stringContaining('fetch-rmbg-model'),
    });
  });

  it('generateSilhouettePng：模型缺失时同样抛 503（不触碰输入解码）', async () => {
    process.env[ENV_KEY] = path.join(__dirname, 'no-such-model.onnx');
    await expect(generateSilhouettePng(Buffer.from('not-an-image'), { mode: 'solid', crop: false }))
      .rejects.toMatchObject({ status: 503 });
  });
});

// ===== 集成：真实 RMBG 推理 + sharp 合成（模型存在才执行） =====

describeIntegration('generateSilhouettePng 集成（真实 RMBG-1.4 推理）', () => {
  it('solid 模式：输出 256x256 带 alpha 的 PNG，背景透明、人物为深色实心', async () => {
    const img = await buildTestImage();

    const out = await generateSilhouettePng(img, { mode: 'solid', crop: false });

    const meta = await sharp(out).metadata();
    expect(meta.format).toBe('png');
    expect(meta.width).toBe(256);
    expect(meta.height).toBe(256);
    expect(meta.hasAlpha).toBe(true);

    const stats = await pixelStats(out);
    // 噪声背景约 79% 像素 → RMBG 抠掉背景；阈值保守取 40%
    expect(stats.transparent).toBeGreaterThan(stats.total * 0.4);
    // 人形区域 → 黑色实心（alpha >= 10 即计入，边缘软化后远超 200）
    expect(stats.darkOpaque).toBeGreaterThan(200);
  }, INTEGRATION_TIMEOUT_MS);

  it('solid + crop=true：输出为 alpha bbox 裁剪后的尺寸（宽高均 < 256 且 > 10）', async () => {
    const img = await buildTestImage();

    const out = await generateSilhouettePng(img, { mode: 'solid', crop: true });

    const meta = await sharp(out).metadata();
    expect(meta.format).toBe('png');
    expect(meta.width).toBeLessThan(256);
    expect(meta.height).toBeLessThan(256);
    expect(meta.width).toBeGreaterThan(10);
    expect(meta.height).toBeGreaterThan(10);
  }, INTEGRATION_TIMEOUT_MS);

  it('sketch 模式：输出成功，多数像素透明/浅色，且存在深色线稿像素', async () => {
    const img = await buildTestImage();

    const out = await generateSilhouettePng(img, { mode: 'sketch', crop: false });

    const meta = await sharp(out).metadata();
    expect(meta.format).toBe('png');
    expect(meta.width).toBe(256);
    expect(meta.height).toBe(256);
    expect(meta.hasAlpha).toBe(true);

    const stats = await pixelStats(out);
    // 素描效果：背景透明、均匀区域为浅色 → 透明+浅色占多数
    expect(stats.transparent + stats.lightOpaque).toBeGreaterThan(stats.total * 0.5);
    // 人形轮廓留下深色线稿
    expect(stats.darkOpaque).toBeGreaterThan(50);
  }, INTEGRATION_TIMEOUT_MS);
});
