// lumira-server/packages/backend/scripts/fetch-rmbg-model.mjs
// RMBG-1.4 量化版抠图模型下载脚本（Task 8）：生成 ~44MB 的本地 ONNX 文件，
// 供 src/modules/ai/silhouette.pipeline.ts 的 getRmbgSession() 加载。
// 设计文档：docs/specs/2026-09-09-ai-template-one-click-creation-design.md 第五节
//
// 用法（在 packages/backend 目录下执行）：
//   node scripts/fetch-rmbg-model.mjs
//
// 下载源依次尝试：hf-mirror.com（国内可达优先）→ huggingface.co（官方兜底），
// 均失败时提示手动放置路径后退出码 1。
// 下载后校验 size > 40MB（防网关错误页/半截文件落盘），不合格删除重试下一源。

import { createWriteStream } from 'node:fs';
import { mkdir, stat, unlink } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';

const MODEL_RELATIVE_PATH = 'assets/models/rmbg-1.4.quant.onnx';
const MIN_MODEL_BYTES = 40 * 1024 * 1024; // 完整量化模型 ~44MB；HTML 错误页/断流残片远小于此
const DOWNLOAD_SOURCES = [
  'https://hf-mirror.com/briaai/RMBG-1.4/resolve/main/onnx/model_quantized.onnx',
  'https://huggingface.co/briaai/RMBG-1.4/resolve/main/onnx/model_quantized.onnx',
];

const scriptDir = dirname(fileURLToPath(import.meta.url));
const modelPath = resolve(scriptDir, '..', MODEL_RELATIVE_PATH);

function mb(bytes) {
  return `${(bytes / 1024 / 1024).toFixed(1)}MB`;
}

// 已存在且足够大 → 幂等跳过；过小（历史残片）→ 删除后重新下载
try {
  const existing = await stat(modelPath);
  if (existing.size > MIN_MODEL_BYTES) {
    console.log(`模型已存在，跳过下载：${modelPath}（${mb(existing.size)}）`);
    process.exit(0);
  }
  console.warn(`本地文件过小（${mb(existing.size)}），删除后重新下载`);
  await unlink(modelPath);
} catch {
  // 文件不存在 → 正常进入下载流程
}

await mkdir(dirname(modelPath), { recursive: true });

for (const url of DOWNLOAD_SOURCES) {
  try {
    console.log(`下载中：${url}`);
    const res = await fetch(url, { redirect: 'follow' });
    if (!res.ok || !res.body) throw new Error(`HTTP ${res.status}`);
    // 流式落盘（Readable.fromWeb 桥接 WHATWG stream → Node stream）
    await pipeline(Readable.fromWeb(res.body), createWriteStream(modelPath));

    const { size } = await stat(modelPath);
    if (size <= MIN_MODEL_BYTES) {
      await unlink(modelPath);
      throw new Error(`文件过小（${mb(size)}），疑似不完整`);
    }
    console.log(`下载完成：${modelPath}（${mb(size)}）`);
    process.exit(0);
  } catch (err) {
    console.error(`源失败：${url}（${err instanceof Error ? err.message : err}）`);
  }
}

console.error(`全部下载源不可达。请手动下载以下任一 URL，放到 ${modelPath}：`);
for (const url of DOWNLOAD_SOURCES) console.error(`  ${url}`);
process.exit(1);
