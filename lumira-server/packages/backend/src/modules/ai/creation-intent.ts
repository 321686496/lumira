// lumira-server/packages/backend/src/modules/ai/creation-intent.ts
// 创作意图解析：把「创作要求」话术解析成显式结构化意图（产出形态 / 张数 / 每张人数 / 跨图是否同一人物）。
// 设计文档：docs/superpowers/specs/2026-09-30-ai-creation-intent-design.md
//
// 为什么要显式解析：此前「九宫格参考图」被识别阶段按图中可见人物数推断成 8~9 人，
// 生图阶段却同时注入「不要生成多宫格」，两句自相矛盾，产出「一个人 7~8 个分身同框」。
// 现在创作要求是唯一权威：解析出的意图同时驱动识别提示词与生图提示词。
//
// 优先级：Step2 显式姿势数/人数 > 创作要求原话（LLM 解析） > 参考图形态/现有默认（fallback）。
// 只有 source==='llm' 的解析结果才作为强制值，避免兜底值把「模型自行判断姿势数」的既有能力写死。

import type { LlmEndpoint } from './llm-client';
import { textChatJson, type LlmJsonRuntime } from './llm-json';

export type CreationIntentMode = 'split-per-cell' | 'single' | 'multi-pose' | 'merge-group';

export interface CreationIntent {
  outputMode: CreationIntentMode;
  /** 期望产出张数 1~9 */
  imageCount: number;
  /** 每张画面内人数 1~9 */
  subjectPerImage: number;
  /** 跨图是否为同一人物（false = 每张是不同的人） */
  sameSubjectAcross: boolean;
  /** 判定依据（用户原话片段或 AI 建议理由），面板展示用 */
  reason: string;
  /** llm = 文本模型解析；fallback = 解析失败/无创作要求时的启发式兜底 */
  source: 'llm' | 'fallback';
}

/** 意图解析输入 */
export interface CreationIntentInput {
  /** 创作要求（Step1 补充创作要求） */
  creationReq?: string | null;
  /** 文字描述 */
  textDesc?: string | null;
  /** Step2 显式姿势个数（1~9；未指定为 null/undefined） */
  poseCount?: number | null;
  /** Step2 显式人物数量（1~9；未指定为 null/undefined） */
  subjectCount?: number | null;
}

const MODES: readonly CreationIntentMode[] = ['split-per-cell', 'single', 'multi-pose', 'merge-group'];

const MODE_LABELS: Record<CreationIntentMode, string> = {
  'split-per-cell': '逐格拆分',
  single: '单张',
  'multi-pose': '多姿势各一张',
  'merge-group': '合并多人合拍',
};

/** 有限整数提取（非有限数 / 小数 → undefined） */
function toInt(v: unknown): number | undefined {
  if (typeof v !== 'number' || !Number.isFinite(v)) return undefined;
  return Math.round(v);
}

function clampInt(v: unknown, min: number, max: number, fallback: number): number {
  const n = toInt(v);
  if (n === undefined) return fallback;
  return Math.min(max, Math.max(min, n));
}

function toStr(v: unknown): string {
  return typeof v === 'string' ? v.trim() : '';
}

/**
 * 规范化任意来源的意图对象（LLM 输出 / 草稿回读）：
 * 枚举校验 + 1~9 夹取 + Step2 显式值覆盖；非法一律回落安全默认。
 */
export function normalizeCreationIntent(raw: unknown, input: CreationIntentInput = {}, source: 'llm' | 'fallback' = 'llm'): CreationIntent {
  const src = typeof raw === 'object' && raw !== null && !Array.isArray(raw) ? (raw as Record<string, unknown>) : {};
  const rawMode = toStr(src.outputMode) as CreationIntentMode;
  let outputMode: CreationIntentMode = MODES.includes(rawMode) ? rawMode : 'single';
  let imageCount = clampInt(src.imageCount, 1, 9, 1);
  let subjectPerImage = clampInt(src.subjectPerImage, 1, 9, 1);
  const sameSubjectAcross = src.sameSubjectAcross !== false;

  // merge-group 只有一个产出画面，张数恒为 1
  if (outputMode === 'merge-group') imageCount = 1;

  // Step2 显式设置最高优先（覆盖意图）
  const pose = toInt(input.poseCount);
  const subj = toInt(input.subjectCount);
  if (pose !== undefined && outputMode !== 'merge-group') {
    imageCount = Math.min(9, Math.max(1, pose));
    if (imageCount === 1) outputMode = 'single';
  }
  if (subj !== undefined) subjectPerImage = Math.min(9, Math.max(1, subj));

  return {
    outputMode,
    imageCount,
    subjectPerImage,
    sameSubjectAcross,
    reason: toStr(src.reason),
    source,
  };
}

/** 解析失败 / 无创作要求时的启发式兜底：不强制数量（除非 Step2 显式给了），行为与改动前一致 */
export function fallbackCreationIntent(input: CreationIntentInput = {}): CreationIntent {
  const pose = toInt(input.poseCount);
  const subj = toInt(input.subjectCount);
  const base = { subjectPerImage: subj !== undefined ? Math.min(9, Math.max(1, subj)) : 1, sameSubjectAcross: true };
  if (pose === undefined) {
    return { outputMode: 'single', imageCount: 1, ...base, reason: '创作要求未指定产出形态，AI 建议单张（可在创作要求改写）', source: 'fallback' };
  }
  if (pose <= 1) {
    return { outputMode: 'single', imageCount: 1, ...base, reason: '按 Step2 显式设置 1 张', source: 'fallback' };
  }
  const n = Math.min(9, Math.max(1, pose));
  return { outputMode: 'multi-pose', imageCount: n, ...base, reason: `按 Step2 显式设置 ${n} 张`, source: 'fallback' };
}

/** 从草稿顶层读回意图（下游共用）；缺失/形状非法 → null */
export function creationIntentOfDraft(draft: unknown): CreationIntent | null {
  if (typeof draft !== 'object' || draft === null || Array.isArray(draft)) return null;
  const raw = (draft as Record<string, unknown>).creationIntent;
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return null;
  const mode = toStr((raw as Record<string, unknown>).outputMode) as CreationIntentMode;
  if (!MODES.includes(mode)) return null;
  const src = raw as Record<string, unknown>;
  const source = src.source === 'fallback' ? 'fallback' : 'llm';
  return normalizeCreationIntent(raw, {}, source);
}

/** 面板一行摘要：`逐格拆分 · 9 张 · 每张 1 人 · 跨图同一人物（按创作要求）` */
export function describeCreationIntent(intent: CreationIntent): string {
  const parts = [
    MODE_LABELS[intent.outputMode],
    `${intent.imageCount} 张`,
    `每张 ${intent.subjectPerImage} 人`,
    intent.sameSubjectAcross ? '跨图同一人物' : '每张不同人物',
  ];
  const tail = intent.source === 'llm' ? '（按创作要求）' : '（AI 建议，可在创作要求改写）';
  return `${parts.join(' · ')}${tail}`;
}

/** 注入识别提示词的创作意图块（最高优先级；可在创作要求中改写） */
export function renderCreationIntentLines(intent: CreationIntent): string[] {
  const lines = [
    '创作意图（由创作要求解析，最高优先级，必须严格照办；Step2 显式设置与之冲突时以显式设置为准）：',
    `- 产出形态：${MODE_LABELS[intent.outputMode]}`,
    `- 目标张数：${intent.imageCount} 张`,
    `- 每张画面人数：${intent.subjectPerImage} 位`,
  ];
  if (intent.outputMode === 'merge-group') {
    lines.push(
      `- 合并要求：把参考图各格中的人物合并到同一场景、同一光线下的真实合拍画面（共 ${intent.subjectPerImage} 位），不要输出九宫格、分屏或拼贴`,
    );
  } else if (intent.outputMode === 'split-per-cell') {
    lines.push('- 拆分要求：参考图的每一格对应一张独立姿势图，逐格还原该格的姿势与穿搭，不要把多格合成一张');
  }
  lines.push(`- 跨图人物关系：${intent.sameSubjectAcross ? '同一人物（长相/服装/发型/体型保持一致）' : '每张为不同人物（不必保持同一长相）'}`);
  if (intent.reason) lines.push(`- 判定依据：${intent.reason}`);
  lines.push('（该意图可在创作要求中改写；创作要求原话与本意图冲突时以创作要求原话为准）');
  return lines;
}

/** 意图解析提示词（system + user）：只要求一个严格 JSON 对象 */
export function buildCreationIntentParsePrompt(input: CreationIntentInput & { refImageCount?: number }): {
  systemPrompt: string;
  userText: string;
} {
  const systemPrompt = [
    '你是资深摄影模板策划。请判断用户的「创作要求 / 文字描述」要求的产出形态，只输出一个 JSON 对象，不要 markdown 代码块、不要解释。',
    '',
    '输出字段：',
    '{',
    '  "outputMode": "split-per-cell" | "single" | "multi-pose" | "merge-group",',
    '  "imageCount": 1~9 的整数,          // 期望产出几张图',
    '  "subjectPerImage": 1~9 的整数,     // 每一张画面里有几位人物',
    '  "sameSubjectAcross": true | false, // 多张图之间是否为同一个人',
    '  "reason": "一句话说明判定依据（引用用户原话关键片段）"',
    '}',
    '',
    '判定口径：',
    '- 要求「把参考图多个格子里的人合成一张 / 多人同框合拍 / 合并成一张合影」→ merge-group，imageCount=1，subjectPerImage=用户说的总人数（未说则 1），sameSubjectAcross=false；',
    '- 要求「按参考图每一格拆成一张 / 每格拆出一个姿势 / 九宫格拆成九张单独姿势图」→ split-per-cell，imageCount=格子数（用户说了就用该数），subjectPerImage=每格人数（通常 1），sameSubjectAcross=true；',
    '- 要求「N 种不同姿势 / N 连拍」等同一主体的多张 → multi-pose，imageCount=N，subjectPerImage=画面人数，sameSubjectAcross=true；',
    '- 要求「N 个人一起拍一张」→ single，imageCount=1，subjectPerImage=N，sameSubjectAcross=false；',
    '- 未提数量与形态 → single，imageCount=1，subjectPerImage=1，sameSubjectAcross=true。',
    '- 用户明确写出的数字（人数 / 张数 / 格数）必须原样采用，不得改写。',
  ].join('\n');

  const req = toStr(input.creationReq);
  const desc = toStr(input.textDesc);
  const lines = [
    `创作要求：${req || '（未提供）'}`,
    `文字描述：${desc || '（未提供）'}`,
    `Step2 显式设置：姿势个数=${input.poseCount ?? '未指定'}，人物数量=${input.subjectCount ?? '未指定'}`,
  ];
  if (input.refImageCount !== undefined) lines.push(`参考图张数：${input.refImageCount}`);
  lines.push('请只输出 JSON。');
  return { systemPrompt, userText: lines.join('\n') };
}

/**
 * 解析创作意图：无任何文本 → 直接用 fallback（零 LLM 调用）；
 * 有文本 → 单次文本模型调用（retryCount=0、超时上限 120s，避免解析步骤本身拖长流程），
 * 失败/异常一律降级为 fallback，不阻断识别。
 */
export async function parseCreationIntent(
  endpoint: LlmEndpoint,
  runtime: LlmJsonRuntime,
  input: CreationIntentInput & { refImageCount?: number } = {},
): Promise<CreationIntent> {
  const hasText = toStr(input.creationReq) !== '' || toStr(input.textDesc) !== '';
  if (!hasText) return fallbackCreationIntent(input);

  const prompt = buildCreationIntentParsePrompt(input);
  try {
    const raw = await textChatJson(
      endpoint,
      { ...prompt, temperature: 0 },
      { retryCount: 0, timeoutMs: Math.min(runtime.timeoutMs, 120_000), maxTokens: Math.min(runtime.maxTokens, 2000) },
    );
    return normalizeCreationIntent(raw, input, 'llm');
  } catch {
    return fallbackCreationIntent(input);
  }
}