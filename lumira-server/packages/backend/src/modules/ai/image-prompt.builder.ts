// lumira-server/packages/backend/src/modules/ai/image-prompt.builder.ts
// 生图提示词纯函数：从模板草稿 JSON 合成中文一段式 prompt（Task 6，TDD）
// 设计文档：docs/specs/2026-09-09-ai-template-one-click-creation-design.md 第三节（生成效果图）
//
// Task 7（ai-generate-image.service）消费：prompt 由后端统一构建，前端不拼 prompt。
// 纯函数、无 DB 依赖：草稿 classification 链只有 key（拿不到 DB 分类树），
// 主体类型用一级 key → 中文名的小型内置映射（migration 003 预置 7 类），未知 key 跳过；tags 本身是中文直接用。

import { LUT_LABELS } from './enums';

/** 一级分类 key → 中文主体类型（migration 003 预置 7 类，与 Flutter 内置 7 类严格对齐） */
const CATEGORY_SUBJECT_LABELS: Record<string, string> = {
  portrait: '人像',
  landscape: '风景',
  food: '美食',
  street: '街拍',
  night: '夜景',
  macro: '微距',
  'still-life': '静物',
};

/** 画幅比例 → 构图取向词（fullscreen / 未知比例无取向词，仅保留比例值） */
const ASPECT_ORIENTATIONS: Record<string, string> = {
  '3:4': '竖构图',
  '9:16': '竖构图',
  '4:3': '横构图',
  '16:9': '横构图',
  '1:1': '方形构图',
};

/** 颗粒感强度分界：grain ≥ 30 描述为「明显」，否则「轻微」 */
const GRAIN_STRONG_THRESHOLD = 30;

/** 空草稿（无任何可用字段）兜底 prompt */
const FALLBACK_PROMPT = '一张 3:4 竖构图的人像摄影作品，自然光线，柔和氛围，画面干净通透';

// ===== 基础工具（与 normalize.ts 同款口径，模块私有） =====

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

/** 宽松 string 化：字符串 trim；有限数字转字符串；其余 undefined */
function toStr(v: unknown): string | undefined {
  if (typeof v === 'string') {
    const s = v.trim();
    return s !== '' ? s : undefined;
  }
  return undefined;
}

/** 字符串数组提取：非 string 项剔除，trim 后为空的项剔除 */
function toStrArray(v: unknown): string[] {
  if (!Array.isArray(v)) return [];
  return v.filter((t): t is string => typeof t === 'string' && t.trim() !== '').map((t) => t.trim());
}

/**
 * 从草稿合成生图 prompt（中文，一段式描述）。前端不拼 prompt。
 *
 * 拼接顺序：classification 主体类型 + aspectRatio 画幅 → tags 风格 → 构图描述 →
 * 光线（方向 + 最佳时段）→ 背景 + 道具 → 后期（LUT 标签 + 颗粒感）→ 氛围（shortDesc / description）→
 * 额外要求（extraPrompt，用户显式补充，置于末尾权重最高）。
 * 格式固定为「一张{画幅}{主体类型}摄影作品，风格{…}，{光线}，背景{…}，{氛围/后期}」，
 * 字段缺失跳过，空草稿走兜底模板。
 */
export function buildImagePrompt(draft: Record<string, unknown>, extraPrompt?: string | null): string {
  const meta = isPlainObject(draft.meta) ? draft.meta : {};
  const composition = isPlainObject(draft.composition) ? draft.composition : {};
  const sceneGuide = isPlainObject(draft.sceneGuide) ? draft.sceneGuide : {};
  const postProcess = isPlainObject(draft.postProcess) ? draft.postProcess : {};
  const classification = isPlainObject(meta.classification) ? meta.classification : {};

  // 主体类型：classification.type → meta.category 兜底，均未命中内置映射则跳过
  const subject =
    CATEGORY_SUBJECT_LABELS[toStr(classification.type) ?? ''] ??
    CATEGORY_SUBJECT_LABELS[toStr(meta.category) ?? ''];

  // 画幅短语：比例 + 取向词（如「3:4 竖构图」）；未知比例仅保留比例值
  const ratio = toStr(composition.aspectRatio);
  const orientation = ratio !== undefined ? ASPECT_ORIENTATIONS[ratio] : undefined;
  const aspectPhrase =
    ratio !== undefined ? (orientation !== undefined ? `${ratio} ${orientation}` : ratio) : undefined;

  const segments: string[] = [];

  // ① 开场：一张{画幅}{主体类型}摄影作品
  if (subject !== undefined && aspectPhrase !== undefined) {
    segments.push(`一张 ${aspectPhrase}的${subject}摄影作品`);
  } else if (subject !== undefined) {
    segments.push(`一张${subject}摄影作品`);
  } else if (aspectPhrase !== undefined) {
    segments.push(`一张 ${aspectPhrase}摄影作品`);
  }

  // ② 风格：tags（中文直接用）
  const tags = toStrArray(meta.tags);
  if (tags.length > 0) segments.push(`风格${tags.join('、')}`);

  // ③ 构图描述
  const compDescription = toStr(composition.description);
  if (compDescription !== undefined) segments.push(compDescription);

  // ④ 光线：最佳时段 + 方向（如「午后4-6点的侧逆光」）
  const lightDirection = toStr(sceneGuide.lightDirection);
  const bestTime = toStr(sceneGuide.bestTime);
  if (lightDirection !== undefined && bestTime !== undefined) {
    segments.push(`${bestTime}的${lightDirection}`);
  } else if (lightDirection !== undefined) {
    segments.push(lightDirection);
  } else if (bestTime !== undefined) {
    segments.push(`${bestTime}的光线`);
  }

  // ⑤ 背景 + 道具
  const background = toStr(sceneGuide.background);
  if (background !== undefined) segments.push(`背景为${background}`);
  const props = toStrArray(sceneGuide.props);
  if (props.length > 0) segments.push(`可搭配${props.join('、')}`);

  // ⑥ 后期：LUT 中文标签（none/未知 key 跳过）+ 颗粒感
  const lut = toStr(postProcess.lut);
  const lutLabel = lut !== undefined && lut !== 'none' ? LUT_LABELS[lut] : undefined;
  if (lutLabel !== undefined) segments.push(`整体呈${lutLabel}色调`);
  const grain = postProcess.grain;
  if (typeof grain === 'number' && Number.isFinite(grain) && grain > 0) {
    segments.push(`带${grain >= GRAIN_STRONG_THRESHOLD ? '明显' : '轻微'}颗粒感`);
  }

  // ⑦ 氛围：shortDesc 优先，缺失时回退 description
  const shortDesc = toStr(meta.shortDesc);
  const description = toStr(meta.description);
  if (shortDesc !== undefined) {
    segments.push(`传递「${shortDesc}」的情绪`);
  } else if (description !== undefined) {
    segments.push(description);
  }

  // ⑧ 额外要求：用户显式补充的附加提示词（Step3 输入），置于末尾权重最高
  const extra = typeof extraPrompt === 'string' ? extraPrompt.trim() : '';
  if (extra) segments.push(`额外要求：${extra}`);

  if (segments.length === 0) return FALLBACK_PROMPT;
  return `${segments.join('，')}。`;
}
