// lumira-server/packages/backend/src/modules/ai/silhouette.pipeline.ts
// 剪影本地管线（Task 8）：RMBG-1.4 人像抠图 → sharp 合成线稿/实心剪影 → 可选 alpha 包围盒裁剪。
// 设计文档：docs/specs/2026-09-09-ai-template-one-click-creation-design.md 第五节
//
// 纯本地计算（无网络/无 DB）：Task 9 的 silhouette 端点把上传的效果图/参考图喂给
// generateSilhouettePng，产出透明底 PNG。模型文件由 scripts/fetch-rmbg-model.mjs 下载
// （assets/models/rmbg-1.4.quant.onnx，不入 git），缺失时 503 引导运营执行脚本。
//
// 原生模块加载策略：sharp 顶层静态 import（纯图像库，无外部状态）；
// onnxruntime-node 用动态 import + InferenceSession 单例懒加载，避免进程启动/未用剪影时
// 就加载 42MB 原生推理库（jest 纯函数用例也因此不受影响）。

import * as fs from 'fs';
import * as path from 'path';
import { Logger, ServiceUnavailableException } from '@nestjs/common';
import sharp, { type Sharp } from 'sharp';
import type { InferenceSession } from 'onnxruntime-node';

const logger = new Logger('SilhouettePipeline');

export interface SilhouetteOptions {
  mode: 'sketch' | 'solid'; // 线稿剪影 | 实心剪影
  crop: boolean;            // 是否按 alpha 包围盒裁剪掉全透明边距
}

export interface Bbox {
  left: number;
  top: number;
  width: number;
  height: number;
}

/**
 * onnxruntime-node backend 层 session handler 的最小结构（InferenceSession.handler 私有属性）。
 * run() 返回 native binding 原样输出：{type, data, dims}，data 为 Float32Array。
 */
interface SessionHandlerLike {
  handler: SessionHandlerLike;
  run(
    feeds: Record<string, unknown>,
    fetches: Record<string, null>,
    options: Record<string, never>,
  ): Promise<Record<string, { type: string; data: Float32Array; dims: number[] }>>;
}

// RMBG-1.4 输入规格：1024x1024 RGB，ImageNet mean/std 归一化
const RMBG_INPUT_SIZE = 1024;
const IMAGENET_MEAN = [0.485, 0.456, 0.406];
const IMAGENET_STD = [0.229, 0.224, 0.225];

// computeAlphaBbox 默认参数：alpha >= 0.3 视为前景；四周留 bbox 尺寸 5% 余量
const DEFAULT_BBOX_THRESHOLD = 0.3;
const DEFAULT_BBOX_PAD_RATIO = 0.05;

// 素描线稿的反向模糊半径（colour-dodge 素描算法）
const SKETCH_BLUR_SIGMA = 4;

// ===== 模型会话（单例懒加载） =====

/**
 * 模型文件路径：优先 RMBG_MODEL_PATH 环境变量（服务器自定义部署位），
 * 否则取包内默认位置。dev：src/modules/ai 上溯 3 级 = packages/backend；
 * dist：dist/modules/ai 上溯 3 级同样命中（assets 不随 tsc 输出，两处布局一致）。
 */
export function resolveModelPath(): string {
  return process.env.RMBG_MODEL_PATH
    || path.join(__dirname, '../../../assets/models/rmbg-1.4.quant.onnx');
}

/** 进程内共享的 session 创建 promise（并发调用合并为一次 load） */
let sessionPromise: Promise<InferenceSession> | null = null;

async function createSession(): Promise<InferenceSession> {
  const modelPath = resolveModelPath();
  if (!fs.existsSync(modelPath)) {
    throw new ServiceUnavailableException('剪影模型未安装，请在服务器执行 scripts/fetch-rmbg-model.mjs');
  }
  const ort = await import('onnxruntime-node');
  return ort.InferenceSession.create(modelPath);
}

/**
 * RMBG-1.4 推理会话（单例懒加载，进程内只 load 一次）。
 * 失败不缓存：模型中途补装后无需重启进程即可恢复。
 */
export async function getRmbgSession(): Promise<InferenceSession> {
  if (sessionPromise === null) {
    sessionPromise = createSession().catch((err) => {
      sessionPromise = null;
      throw err;
    });
  }
  return sessionPromise;
}

// ===== 纯函数：alpha 包围盒 =====

/**
 * alpha 通道前景包围盒（crop 裁剪依据）。
 * threshold 语义统一为 0..1：Float32Array 直接比较，Uint8Array（如 sharp raw 输出）按 /255 归一化后比较。
 * 无前景（没有任何像素达标）返回 null；padRatio 按 bbox 自身宽高向外扩，并 clamp 到图像边界。
 */
export function computeAlphaBbox(
  alpha: Uint8Array | Float32Array,
  width: number,
  height: number,
  threshold = DEFAULT_BBOX_THRESHOLD,
  padRatio = DEFAULT_BBOX_PAD_RATIO,
): Bbox | null {
  const isFloat = alpha instanceof Float32Array;
  let minX = width;
  let minY = height;
  let maxX = -1;
  let maxY = -1;
  for (let y = 0; y < height; y++) {
    const row = y * width;
    for (let x = 0; x < width; x++) {
      const v = isFloat ? alpha[row + x] : alpha[row + x] / 255;
      if (v >= threshold) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < 0) return null; // 无前景

  const padX = Math.round((maxX - minX + 1) * padRatio);
  const padY = Math.round((maxY - minY + 1) * padRatio);
  const left = Math.max(0, minX - padX);
  const top = Math.max(0, minY - padY);
  const right = Math.min(width - 1, maxX + padX);
  const bottom = Math.min(height - 1, maxY + padY);
  return { left, top, width: right - left + 1, height: bottom - top + 1 };
}

// ===== RMBG 推理 =====

/**
 * RMBG-1.4 matting：输入原图 → 1024x1024 matte（前景概率 0..1，量化为单通道 0..255 raw）。
 * 预处理：resize(fill 拉伸) → 去 alpha → raw RGB → ImageNet mean/std 归一化 → NCHW float32。
 */
async function runRmbg(input: Buffer): Promise<Buffer> {
  const session = await getRmbgSession();
  const ort = await import('onnxruntime-node');

  const { data } = await sharp(input)
    .resize(RMBG_INPUT_SIZE, RMBG_INPUT_SIZE, { fit: 'fill' })
    .removeAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });

  // HWC → NCHW + ImageNet 归一化（RMBG-1.4 训练口径）
  const plane = RMBG_INPUT_SIZE * RMBG_INPUT_SIZE;
  const floatData = new Float32Array(3 * plane);
  for (let i = 0; i < plane; i++) {
    floatData[i] = (data[i * 3] / 255 - IMAGENET_MEAN[0]) / IMAGENET_STD[0];
    floatData[plane + i] = (data[i * 3 + 1] / 255 - IMAGENET_MEAN[1]) / IMAGENET_STD[1];
    floatData[2 * plane + i] = (data[i * 3 + 2] / 255 - IMAGENET_MEAN[2]) / IMAGENET_STD[2];
  }
  const tensor = new ort.Tensor('float32', floatData, [1, 3, RMBG_INPUT_SIZE, RMBG_INPUT_SIZE]);

  // 不走 session.run 而直调底层 handler.run：公共 run 会对 native 输出做
  // new Tensor(type, data, dims) 复制构造，其中的 Float32Array instanceof 检查在
  // jest 的 vm 环境下因 typed array 构造器跨 realm 必然误判（真实 node 进程同 realm
  // 无此问题）。handler.run（onnxruntime-node backend 层）原样返回 native 结果
  // {type, data, dims}，TypedArray 按索引读数值与 realm 无关。依赖版本已锁定
  // onnxruntime-node ^1.20，该内部结构稳定，集成测试守护此假设。
  const fetches: Record<string, null> = {};
  for (const name of session.outputNames) fetches[name] = null;
  const handler = (session as unknown as SessionHandlerLike).handler;
  const results = await handler.run({ [session.inputNames[0]]: tensor }, fetches, {});

  // 输出 [1,1,1024,1024] 前景概率 → clamp 0..1 → 单通道 0..255 raw（供 sharp resize）
  const matte = results[session.outputNames[0]].data;
  const matteRaw = Buffer.allocUnsafe(plane);
  for (let i = 0; i < plane; i++) {
    const v = Math.min(1, Math.max(0, matte[i]));
    matteRaw[i] = Math.round(v * 255);
  }
  return matteRaw;
}

// ===== 合成 =====

/**
 * 剪影合成主流程：RMBG 抠图 → alpha 缩回原尺寸 →
 * solid：黑色实心人物（黑底 + 人物 alpha，背景透明）；
 * sketch：colour-dodge 素描线稿（灰度底 + 反向模糊 dodge 出轮廓线，再补人物 alpha）→
 * 可选按 alpha 包围盒裁剪。返回透明底 PNG buffer。
 */
export async function generateSilhouettePng(input: Buffer, opts: SilhouetteOptions): Promise<Buffer> {
  const t0 = Date.now();
  // 先确认模型可用（缺失 → 503；此时无需解码输入，运营只需补装模型）
  // 首次调用含模型加载（42MB 原生推理库 + ONNX 会话），单独计时便于区分"冷启动慢"与"推理慢"
  const tSession = Date.now();
  await getRmbgSession();
  const sessionMs = Date.now() - tSession;

  const meta = await sharp(input).metadata();
  const origW = meta.width ?? 0;
  const origH = meta.height ?? 0;

  // ① RMBG 推理（1024² matte）→ ② 缩回原尺寸单通道 alpha（人物前景遮罩）
  const tRmbg = Date.now();
  const matteRaw = await runRmbg(input);
  const alphaRaw = await sharp(matteRaw, { raw: { width: RMBG_INPUT_SIZE, height: RMBG_INPUT_SIZE, channels: 1 } })
    .resize(origW, origH, { fit: 'fill' })
    .raw()
    .toBuffer();
  const rmbgMs = Date.now() - tRmbg;
  const alphaJoinOpts = { raw: { width: origW, height: origH, channels: 1 as const } };

  // ③ 按模式合成结果图（base 尺寸 = 原尺寸，与 alphaRaw 严格一致才能 joinChannel）
  let result: Sharp;
  if (opts.mode === 'solid') {
    // 实心剪影：纯黑 RGB + 人物 alpha
    result = sharp({
      create: { width: origW, height: origH, channels: 3, background: { r: 0, g: 0, b: 0 } },
    }).joinChannel(alphaRaw, alphaJoinOpts);
  } else {
    // 线稿剪影（colour-dodge 素描）：
    //   gray = 原图灰度（srgb 3band）；inv = gray 反相 + 高斯模糊；
    //   dodge(gray, inv)：均匀区域 → 白（底/人物内部），轮廓过渡带 → 深色线；
    //   最后 joinChannel alphaRaw 把原图背景抹成透明，只保留人物线稿。
    //   注意：composite 与 joinChannel 需分两步（链式混用会触发
    //   "images do not have same numbers of bands"，composite 完成后再起新 sharp 实例接 alpha）。
    //   另：composite 结果自带全 255 alpha 通道（4ch），若不 removeAlpha 直接 joinChannel，
    //   会把人物 alpha 追加成第 5 通道，PNG 编码静默丢弃 → 输出全不透明。故先剥掉再拼接。
    const gray = await sharp(input).removeAlpha().grayscale().toColourspace('srgb').png().toBuffer();
    const inv = await sharp(gray).negate().blur(SKETCH_BLUR_SIGMA).png().toBuffer();
    const dodge = await sharp(gray).composite([{ input: inv, blend: 'colour-dodge' }]).removeAlpha().png().toBuffer();
    result = sharp(dodge).joinChannel(alphaRaw, alphaJoinOpts);
  }

  // ④ 合成输出；可选按 alpha 包围盒裁掉全透明边距（无前景时保留原尺寸）。
  // 注意：extract 链在 joinChannel 之后会被 sharp 静默忽略，需先合成出图、
  // 再起新实例裁剪（PNG 无损，中间多一次编解码在 256-1024 图幅上可忽略）。
  const tCompose = Date.now();
  let out = await result.png().toBuffer();
  if (opts.crop) {
    const bbox = computeAlphaBbox(alphaRaw, origW, origH);
    if (bbox) {
      out = await sharp(out)
        .extract({ left: bbox.left, top: bbox.top, width: bbox.width, height: bbox.height })
        .png()
        .toBuffer();
    }
  }
  // 阶段耗时日志（对齐工程惯例 stage time breakdown）：定位慢在模型加载 / 推理 / 合成
  logger.log(
    `silhouette done in ${Date.now() - t0}ms ${origW}x${origH} mode=${opts.mode} ` +
    `(session=${sessionMs}ms rmbg=${rmbgMs}ms compose=${Date.now() - tCompose}ms)`,
  );
  return out;
}
