// lumira-server/packages/backend/src/modules/ai/image-prompt.composer.ts
// 生图提示词组织器：不再由程序生硬拼接 prompt，而是把结构化素材（模板基本信息 /
// 本张姿势 / 网络趋势参考 / 照片参数 / 生图要求）交给文本模型，由它整理成最终生图提示词。
// 文本模型失败/超时/空白输出 → 静默回退到调用方传入的机械拼接 prompt（不阻塞生图）。

import { textChat } from './llm-client';
import type { LlmEndpoint } from './llm-client';
import type { ResearchItem } from './trend-research/research-item';
import { buildResearchLines } from './trend-research/research-digest';
import { LUT_LABELS } from './enums';

const COMPOSE_SYSTEM_PROMPT = `你是顶级人像摄影艺术指导兼生图提示词工程师。用户将提供一份结构化素材（模板基本信息 / 本张姿势 / 网络趋势参考 / 照片参数 / 生图要求），请把它们整理成一段高质量的中文生图提示词，最终喂给文生图模型。

## 整理规则
1. 输出一段连贯的中文描述（约 150~300 字），必须涵盖：人物形象与主体、姿势、构图与画幅、光线、背景与道具、色调质感、情绪氛围。
2. 网络趋势参考中的有效信息（当下流行题材、风格、视觉元素）要转化为具体可见的画面描述融入提示词，让画面贴合当下审美；与创作要求冲突或明显无效的忽略。
3. 严格保留素材中的硬约束：画幅比例、单姿势要求、人物一致性要求、用户额外要求（权重最高，置于提示词末尾附近强调）。
4. 必须体现真实感与去 AI 味：真实相机直出、随手抓拍的实拍质感；人是活生生的真实普通人——皮肤保留毛孔、纹理与轻微瑕疵，不生硬、不过度精致、不做美颜磨皮、绝不塑料感；光影来自真实环境自然光、明暗过渡自然可信；五官头发手部贴合真实人体结构无畸变；避免典型 AI 感（过度磨皮、锥子脸卡通化、高饱和炫彩、镜面质感、浮夸打光、精致摆拍）。
5. 只使用素材中出现的信息组织画面，不新增素材没有的元素；不输出任何解释，只输出整理后的提示词本身。`;

/** 组织器输入：草稿 + 本张姿势已并入 draft（singlePose 模式）+ 研究结果 + 用户附加提示词 */
export interface PromptComposeInput {
  draft: Record<string, unknown>;
  research: ResearchItem[];
  extraPrompt?: string | null;
}

export interface ComposeResult {
  prompt: string;
  composed: boolean;
}

// ===== 基础工具（模块私有） =====

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

function toStr(v: unknown): string | undefined {
  if (typeof v === 'string') {
    const s = v.trim();
    return s !== '' ? s : undefined;
  }
  return undefined;
}

function toStrArray(v: unknown): string[] {
  if (!Array.isArray(v)) return [];
  return v.filter((t): t is string => typeof t === 'string' && t.trim() !== '').map((t) => t.trim());
}

/** 一级分类 key → 中文主体类型（与 image-prompt.builder 对齐） */
const CATEGORY_SUBJECT_LABELS: Record<string, string> = {
  portrait: '人像',
  landscape: '风景',
  food: '美食',
  street: '街拍',
  night: '夜景',
  macro: '微距',
  'still-life': '静物',
};

/** 把结构化素材组织成「带分节标签的素材文本」，交给文本模型整理 */
export function buildPromptMaterial(input: PromptComposeInput): string {
  const { draft, research, extraPrompt } = input;
  const meta = isPlainObject(draft.meta) ? draft.meta : {};
  const composition = isPlainObject(draft.composition) ? draft.composition : {};
  const sceneGuide = isPlainObject(draft.sceneGuide) ? draft.sceneGuide : {};
  const postProcess = isPlainObject(draft.postProcess) ? draft.postProcess : {};
  const classification = isPlainObject(meta.classification) ? meta.classification : {};
  const isSinglePose = draft.singlePose === true;
  const consistency = isPlainObject(draft.consistency) ? draft.consistency : {};
  const rawPose = Array.isArray(draft.pose)
    ? (isPlainObject(draft.pose[0]) ? draft.pose[0] : undefined)
    : isPlainObject(draft.pose)
      ? draft.pose
      : undefined;

  const sections: string[] = [];

  // ① 模板基本信息
  const infoLines: string[] = [];
  const categoryKey = toStr(classification.type) ?? toStr(meta.category);
  const subject = categoryKey !== undefined ? CATEGORY_SUBJECT_LABELS[categoryKey] : undefined;
  if (subject) infoLines.push(`- 主体类型：${subject}`);
  const name = toStr(meta.name);
  if (name) infoLines.push(`- 模板名称：${name}`);
  const tags = toStrArray(meta.tags);
  if (tags.length) infoLines.push(`- 风格标签：${tags.join('、')}`);
  const shortDesc = toStr(meta.shortDesc);
  if (shortDesc) infoLines.push(`- 短描述（情绪价值）：${shortDesc}`);
  const description = toStr(meta.description);
  if (description) infoLines.push(`- 完整描述：${description}`);
  if (infoLines.length) sections.push(`【模板基本信息】\n${infoLines.join('\n')}`);

  // ② 本张姿势（单姿势模式给本张；否则给整体构图描述）
  if (isSinglePose && rawPose) {
    const poseLines: string[] = [];
    const poseName = toStr(rawPose.name);
    if (poseName) poseLines.push(`- 姿势名：${poseName}`);
    const poseDesc = toStr(rawPose.description);
    if (poseDesc) poseLines.push(`- 姿势描述：${poseDesc}`);
    const position = toStr(rawPose.position);
    if (position) poseLines.push(`- 位置/机位：${position}`);
    if (poseLines.length) sections.push(`【本张姿势】（本张只生成这一个姿势）\n${poseLines.join('\n')}`);
  } else {
    const compDesc = toStr(composition.description);
    if (compDesc) sections.push(`【构图描述】\n- ${compDesc}`);
  }

  // ③ 网络趋势参考（识别阶段实时搜索命中；与研究摘要共用挑选规则：有摘要条目排前）
  if (research.length) {
    const trendLines = buildResearchLines(research).map((l) => `- ${l}`);
    if (trendLines.length) {
      sections.push(`【网络趋势参考】（识别阶段实时搜索命中的当下流行素材，提炼为可见的视觉元素）\n${trendLines.join('\n')}`);
    }
  }

  // ④ 照片参数
  const paramLines: string[] = [];
  const ratio = toStr(composition.aspectRatio);
  if (ratio) paramLines.push(`- 画幅比例：${ratio}`);
  const lightDirection = toStr(sceneGuide.lightDirection);
  const bestTime = toStr(sceneGuide.bestTime);
  if (lightDirection || bestTime) {
    paramLines.push(`- 光线：${[bestTime, lightDirection].filter(Boolean).join('的')}`);
  }
  const background = toStr(sceneGuide.background);
  if (background) paramLines.push(`- 背景：${background}`);
  const props = toStrArray(sceneGuide.props);
  if (props.length) paramLines.push(`- 道具：${props.join('、')}`);
  const lut = toStr(postProcess.lut);
  const lutLabel = lut !== undefined && lut !== 'none' ? LUT_LABELS[lut] : undefined;
  if (lutLabel) paramLines.push(`- 色调：${lutLabel}`);
  const grain = postProcess.grain;
  if (typeof grain === 'number' && Number.isFinite(grain) && grain > 0) {
    paramLines.push(`- 颗粒感：${grain >= 30 ? '明显' : '轻微'}`);
  }
  if (paramLines.length) sections.push(`【照片参数】\n${paramLines.join('\n')}`);

  // ⑤ 生图要求（真实感 / 去 AI 味 / 一致性 / 单姿势 / 用户附加，全部为硬约束）
  const reqLines: string[] = [];
  reqLines.push('- 真实相机直出的摄影质感，画面像随手抓拍的实拍照片，而非插画、3D 建模渲染、AI 合成或精修广告片');
  if (categoryKey === 'portrait') {
    reqLines.push('- 人物是活生生的真实普通人：皮肤保留真实毛孔、纹理与轻微瑕疵，表情松弛自然不做作，不生硬、不过度精致、不做美颜磨皮');
    reqLines.push('- 光影来自真实环境与自然光，明暗过渡自然可信；五官头发衣服手部贴合真实人体结构，无肢体或手指畸变');
  }
  if (isSinglePose) {
    reqLines.push('- 画面中只有一个人物，只呈现上述「本张姿势」；不要合并多个姿势，不要生成连拍、多宫格或姿势对比图');
    const allowInconsistent = consistency.mode === 'loose';
    if (!allowInconsistent) {
      reqLines.push(
        consistency.anchor === 'first'
          ? '- 参考图是同一套模板的第一张姿势图：严格复用参考图中的同一人物长相、服装、发型、体型，以及场景、道具、光线和摄影风格；本张只改变姿势'
          : '- 同一套模板的连续拍摄：保持同一人物的长相、服装、发型、体型，以及场景、道具、光线和摄影风格一致；本张只改变姿势',
      );
    }
  }
  const extra = typeof extraPrompt === 'string' ? extraPrompt.trim() : '';
  if (extra) reqLines.push(`- 用户额外要求（权重最高，必须满足）：${extra}`);
  sections.push(`【生图要求】\n${reqLines.join('\n')}`);

  return `请把以下结构化素材整理成一段生图提示词：\n\n${sections.join('\n\n')}`;
}

/**
 * 组织生图提示词：结构化素材 → 文本模型整理。永不抛错：
 * 失败/超时/空白输出 → 返回调用方传入的 fallbackPrompt（机械拼接结果）。
 */
export async function composeImagePrompt(
  textEndpoint: LlmEndpoint,
  input: PromptComposeInput,
  fallbackPrompt: string,
): Promise<ComposeResult> {
  try {
    const out = await textChat(textEndpoint, {
      systemPrompt: COMPOSE_SYSTEM_PROMPT,
      userText: buildPromptMaterial(input),
      temperature: 0.4,
      timeoutMs: 60_000,
    });
    const trimmed = out.trim();
    if (!trimmed) return { prompt: fallbackPrompt, composed: false };
    return { prompt: trimmed, composed: true };
  } catch {
    return { prompt: fallbackPrompt, composed: false };
  }
}
