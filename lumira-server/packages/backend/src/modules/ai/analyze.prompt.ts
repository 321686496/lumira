// lumira-server/packages/backend/src/modules/ai/analyze.prompt.ts
// 识别提示词构造（Task 5）：DB 分类树文本 + 全部枚举 key/中文标签 + 输出 JSON 契约 + 硬约束
// 设计文档：docs/specs/2026-09-09-ai-template-one-click-creation-design.md 第四节/第五节

import {
  LUTS,
  LUT_LABELS,
  OVERLAY_TYPES,
  OVERLAY_TYPE_LABELS,
  ASPECT_RATIOS,
  ASPECT_RATIO_LABELS,
  ISO_MODES,
  ISO_MODE_LABELS,
  WHITE_BALANCES,
  WHITE_BALANCE_LABELS,
  FLASH_MODES,
  FLASH_MODE_LABELS,
  FOCUS_MODES,
  FOCUS_MODE_LABELS,
  LENS_SUGGESTIONS,
  LENS_SUGGESTION_LABELS,
  SEASONS,
  SEASON_LABELS,
  WEATHERS,
  WEATHER_LABELS,
  TIME_TONES,
  TIME_TONE_LABELS,
} from './enums';
import type { CategoryNode } from './normalize';

/** 枚举行文本：`key（中文标签）、key（中文标签）…`；无标签的 key 原样输出 */
function enumLine(keys: readonly string[], labels: Record<string, string>): string {
  return keys.map((k) => (labels[k] ? `${k}（${labels[k]}）` : k)).join('、');
}

/**
 * 分类树按层级缩进文本化。
 * 兄弟节点按 key 排序保证提示词确定性；父链断裂的孤儿节点（父分类被停用）整枝丢弃，
 * 与 normalizeDraft 的逐级父子校验口径一致。
 */
function renderCategoryTree(categories: CategoryNode[]): string {
  const byParent = new Map<string | null, CategoryNode[]>();
  for (const c of categories) {
    const list = byParent.get(c.parentKey);
    if (list) {
      list.push(c);
    } else {
      byParent.set(c.parentKey, [c]);
    }
  }

  const lines: string[] = [];
  // seen 记录当前分支路径上已展开的 key，用于切断 parentKey 回环
  // （seed 005 中 food/style overhead 下存在 method 也叫 overhead，key===parentKey，会形成自环导致无限递归）
  const walk = (parentKey: string | null, depth: number, seen: ReadonlySet<string>): void => {
    const children = (byParent.get(parentKey) || [])
      .slice()
      .sort((a, b) => a.key.localeCompare(b.key));
    for (const child of children) {
      lines.push(`${'  '.repeat(depth)}- ${child.key} ${child.name}`);
      if (seen.has(child.key)) continue; // 环：仅渲染当前层，不再向下展开，避免堆栈溢出
      const next = new Set(seen);
      next.add(child.key);
      walk(child.key, depth + 1, next);
    }
  };
  walk(null, 0, new Set());
  return lines.join('\n');
}

/** 输出 JSON 契约示例（设计文档第四节草稿 JSON，jsonc 注释保留作字段说明） */
const DRAFT_JSON_EXAMPLE = `{
  "meta": {
    "name": "晴空田园少女人像侧拍",          // 场景+主体+风格+角度，12~30字（硬约束）
    "category": "portrait",                 // 必须命中分类树一级 key
    "shortDesc": "把夏天拍进眼睛里",          // 情绪化文案，≤20字
    "description": "…结构化长描述（光线/氛围/主体/背景）…",
    "tags": ["日系", "田园", "清新"],
    "ambience": { "seasons": ["summer"], "weathers": ["sunny"], "timeTones": ["day"] },
    "classification": { "type": "portrait", "majorStyle": "…", "style": "…", "method": "" }
  },
  "composition": { "overlayType": "rule_of_thirds", "aspectRatio": "3:4", "opacity": 0.5,
    "description": "…", "subjectFrame": { "x": 0.3, "y": 0.2, "w": 0.4, "h": 0.6 } },
  "pose": [{ "name": "侧身回眸", "description": "身体微侧45度，下巴略抬…",
    "position": { "x": 0.5, "y": 0.45 }, "scale": 1.0, "rotation": 0 }],  // 数组可含多个姿势（数量规则见硬约束/用户消息）
  "camera": { "exposureCompensation": 0.3, "isoMode": "manual", "iso": 200,
    "shutterSpeed": "1/400", "whiteBalance": "daylight", "whiteBalanceK": 5500,
    "flashMode": "off", "focusMode": "auto", "lensType": "85mm f/1.8",
    "lensSuggestion": "telephoto" },
  "sceneGuide": { "lightDirection": "侧逆光", "shootingDistance": "2-3米",
    "background": "田野与天空", "props": ["草帽"], "bestTime": "午后4-6点",
    "tips": ["对焦眼睛", "避免正午顶光"] },
  "postProcess": { "cropRatio": "3:4",
    "color": { "brightness": 5, "contrast": 8, "saturation": -10, "temperature": 10,
      "tint": 3, "highlights": -5, "shadows": 8 },
    "smoothStrength": 15, "sharpen": 10, "vignette": 12, "grain": 18,
    "lut": "japanese_fresh" }
}`;

/** 系统提示词公共主体：分类树 + 枚举表 + 输出 JSON 契约 + 硬约束（视觉/纯文字版共用） */
function buildSystemPromptBody(categories: CategoryNode[]): string {
  return `## 分类树（meta.category 取一级 key；meta.classification.majorStyle/style/method 按层级逐级选择，只能从下列 key 中选择，禁止编造 key）
${renderCategoryTree(categories)}

## 枚举值（只能使用下列 key，括号内中文标签仅供理解；不确定的字段直接省略，不要编造）
- composition.overlayType（构图叠加层）：${enumLine(OVERLAY_TYPES, OVERLAY_TYPE_LABELS)}
- composition.aspectRatio / postProcess.cropRatio（画幅/裁剪比例）：${enumLine(ASPECT_RATIOS, ASPECT_RATIO_LABELS)}
- camera.isoMode（ISO 模式）：${enumLine(ISO_MODES, ISO_MODE_LABELS)}
- camera.whiteBalance（白平衡）：${enumLine(WHITE_BALANCES, WHITE_BALANCE_LABELS)}
- camera.flashMode（闪光灯）：${enumLine(FLASH_MODES, FLASH_MODE_LABELS)}
- camera.focusMode（对焦模式）：${enumLine(FOCUS_MODES, FOCUS_MODE_LABELS)}
- camera.lensSuggestion（镜头建议）：${enumLine(LENS_SUGGESTIONS, LENS_SUGGESTION_LABELS)}
- postProcess.lut（滤镜 LUT）：${enumLine(LUTS, LUT_LABELS)}
- meta.ambience.seasons（季节）：${enumLine(SEASONS, SEASON_LABELS)}
- meta.ambience.weathers（天气）：${enumLine(WEATHERS, WEATHER_LABELS)}
- meta.ambience.timeTones（时段）：${enumLine(TIME_TONES, TIME_TONE_LABELS)}

## 输出 JSON 契约（完整字段结构示例）
\`\`\`jsonc
${DRAFT_JSON_EXAMPLE}
\`\`\`

## 硬约束
- 只输出 JSON，不要任何解释，markdown 代码块标记也尽量省略；
- meta.name 具体化（场景+主体+风格+角度，12~30 字），禁止只写风格名；
- meta.shortDesc 是情绪化文案，≤20 字，不是长描述的缩写；
- pose 数组数量规则见用户消息；用户未要求时输出 1 个姿势；
- 未知枚举字段直接省略，不要编造；
- meta.classification 从分类树逐级选择，非人像题材允许 style/method 留空；
- 相机参数是「复现该风格的建议参数」，给出合理估算值；
- 不输出 price / silhouette / author / sortOrder / isActive 字段。`;
}

/** 视觉识别版系统提示词（现状行为不变，仅结构拆分） */
export function buildAnalyzeSystemPrompt(categories: CategoryNode[]): string {
  return `你是资深人像摄影模板编辑，分析用户上传的示例图，产出可直接上线的摄影模板表单数据。\n\n${buildSystemPromptBody(categories)}`;
}

/** 纯文字构思版系统提示词（无示例图，基于文字描述构思模板） */
export function buildTextOnlySystemPrompt(categories: CategoryNode[]): string {
  return `你是资深人像摄影模板编辑。用户将提供一段风格描述或创作要求（没有示例图），请据此构思一个可直接上线的摄影模板，产出模板表单数据。描述未提及的字段，给出符合该风格的合理建议值（相机参数为复现该风格的估算值）。\n\n${buildSystemPromptBody(categories)}`;
}

/** 识别用户提示词附加输入：Step1 文字描述 / 创作要求 / 姿势个数（均可选） */
export interface AnalyzeUserPromptInput {
  /** 文字描述：对模板的补充描述（如「三连拍姿势」） */
  textDesc?: string | null;
  /** 创作要求：对 AI 的额外创作指令 */
  creationReq?: string | null;
  /** 姿势个数：1~6 固定指定；空/undefined = AI 自动判断 */
  poseCount?: number | null;
}

/** 构造姿势数量指令行（vision / text-only 共用） */
function poseCountLine(poseCount: number | null | undefined): string {
  if (typeof poseCount === 'number' && Number.isInteger(poseCount) && poseCount >= 1 && poseCount <= 6) {
    return `pose 数组必须恰好输出 ${poseCount} 个姿势，每个姿势有独立的 name / description / position。`;
  }
  return (
    '请根据用户文字描述与创作要求（包括示例图中可见的文字要求，如「三连拍」等）判断需要多少个姿势，' +
    '在 1~6 个范围内输出，每个姿势有独立的 name / description / position；无明确要求时输出 1 个。'
  );
}

/** 构造附加输入行（textDesc / creationReq，vision / text-only 共用） */
function extrasLines(input: AnalyzeUserPromptInput): string[] {
  const lines: string[] = [];
  const textDesc = typeof input.textDesc === 'string' ? input.textDesc.trim() : '';
  if (textDesc) lines.push(`用户文字描述：${textDesc}`);
  const creationReq = typeof input.creationReq === 'string' ? input.creationReq.trim() : '';
  if (creationReq) lines.push(`创作要求：${creationReq}（识别/构思结果需向该要求倾斜）`);
  return lines;
}

/** 视觉识别版用户提示词（图片随 message 一并发送，文本注入文字描述 / 创作要求 / 姿势数量指令） */
export function buildAnalyzeUserPrompt(input: AnalyzeUserPromptInput = {}): string {
  const lines: string[] = ['请分析这张示例图，按系统提示给出的输出 JSON 契约返回模板草稿。'];
  lines.push(...extrasLines(input));
  lines.push(poseCountLine(input.poseCount));
  return lines.join('\n');
}

/** 纯文字版用户提示词 */
export function buildTextOnlyUserPrompt(input: AnalyzeUserPromptInput = {}): string {
  const textDesc = typeof input.textDesc === 'string' ? input.textDesc.trim() : '';
  const lines: string[] = [
    '请基于以下文字描述，按系统提示给出的输出 JSON 契约构思并返回模板草稿：',
    textDesc || '（用户未提供具体描述，请按创作要求构思）',
  ];
  lines.push(...extrasLines(input));
  lines.push(poseCountLine(input.poseCount));
  return lines.join('\n');
}
