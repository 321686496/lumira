// lumira-server/packages/backend/src/modules/ai/image-prompt.composer.ts
// 生图提示词组织器：不再由程序生硬拼接 prompt，而是把结构化素材（模板基本信息 /
// 本张姿势 / 网络趋势参考 / 照片参数 / 生图要求）交给文本模型，由它整理成最终生图提示词。
// 文本模型失败/超时/空白输出 → 静默回退到调用方传入的机械拼接 prompt（不阻塞生图）。

import { textChat } from './llm-client';
import type { LlmEndpoint } from './llm-client';
import type { ResearchItem } from './trend-research/research-item';
import { buildResearchLines } from './trend-research/research-digest';
import {
  LUT_LABELS,
  OVERLAY_TYPE_LABELS,
  ISO_MODE_LABELS,
  WHITE_BALANCE_LABELS,
  FLASH_MODE_LABELS,
  FOCUS_MODE_LABELS,
  LENS_SUGGESTION_LABELS,
} from './enums';

const COMPOSE_SYSTEM_PROMPT = `你是顶级人像摄影艺术指导兼生图提示词工程师。用户将提供一份结构化素材（模板基本信息 / 构图与机位 / 本张姿势 / 网络趋势参考 / 照片参数 / 生图要求），请把它们整理成一段高质量的中文生图提示词，最终喂给文生图模型。

## 整理规则
1. 输出一段连贯的中文描述（约 200~350 字），按「主体与形象 → 姿势 → 构图与机位 → 光线 → 背景与道具 → 相机参数 → 色调质感 → 情绪」的顺序组织，以下信息必须写到可照做：
   - 构图：构图法则（三等分 / 居中 / 对角线 / 引导线 / 框架式…）、主体在画面中的位置与占比、留白方向、前景 / 中景 / 背景的层次；
   - 机位与景别：机位高度与角度（平视 / 略仰 / 略俯）、拍摄距离与景别（全身 / 七分身 / 半身 / 特写）；
   - 姿势：身体朝向与转动角度、重心与支撑腿、肩胯错位、下巴高低与视线方向、左右手各自的具体动作与落点；
   - 相机：镜头焦段与光圈、快门、ISO、白平衡、曝光补偿（用素材给出的数值，不要另编）。
2. 构图、机位、景别、姿势线条与相机参数必须呈现专业摄影水准的美感：画面是经过设计的——水平线水平、主体落位与留白讲究、肢体线条舒展有延伸感、景深与光比服务于主体。
3. 「随拍感」只作用于质感与瞬间感——真实皮肤材质、自然松弛的表情、生活化的光线与场景，让人看不出 AI 痕迹；它绝不作用于画面水平与构图精度。严禁把「随手抓拍」写成构图随意：不要主体偏离平衡位置、不要水平线倾斜、不要主体顶天立地或被画面边缘随意裁切、不要四肢与躯干粘连重叠、不要正面僵直的站姿。
4. 真实材质细节必须写成具体可见的东西而非口号：
   a. 开头用实拍语境定调：一张真实相机直出的生活照（不是精修写真，也不是插画）；
   b. 紧跟素材给出的摄影参数：镜头焦段与光圈（如 85mm f/1.8 浅景深虚化，或手机主摄直出）、快门与感光度（弱光夜景写高 ISO 带来的自然噪点）、白平衡，让画面落在「真实照片」的分布上；
   c. 人物写成街上随处可见的普通年轻人：肤色不均匀、T 区微泛油光而脸颊哑光、皮肤保留毛孔与细小绒毛、可有淡痕或淡淡黑眼圈，头发有几缕没梳好的碎发，衣物有自然褶皱；
   d. 用负面清单收尾：不是插画、CG、油画、网红精修写真或影楼布光大片，皮肤不磨皮不过度均匀，避免完美对称脸、塑料质感、镜面高光、锥子脸、高饱和炫彩和精致摆拍。
5. 风格词必须转译后再用：「新中式」「氛围感」「少女」「千金风」等高风格化标签要落成具体的穿着、场景、人物特征（如「穿着新中式盘扣上衣的二十多岁普通女孩」），不得直接堆砌风格词，防止画面滑向唯美插画风。
6. 网络趋势参考中的有效信息（当下流行题材、风格、视觉元素）要转化为具体可见的画面描述融入提示词，让画面贴合当下审美；与创作要求冲突、明显无效或只是排版残留（标题符号 / 表格 / 来源域名）的忽略。
7. 严格保留素材中的硬约束：画幅比例、单姿势要求、人物一致性要求、用户额外要求（权重最高，置于提示词末尾附近强调）。
8. 只使用素材中出现的信息组织画面，不新增素材没有的元素；不输出任何解释，只输出整理后的提示词本身。`;

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

/** 有限数字提取 */
function toNum(v: unknown): number | undefined {
  return typeof v === 'number' && Number.isFinite(v) ? v : undefined;
}

/** 归一化横坐标 → 画面左右位置（三分位口径，与 overlayType 的三等分语义一致） */
function horizontalLabel(x: number): string {
  if (x < 0.38) return '左侧';
  if (x > 0.62) return '右侧';
  return '中部';
}

/** 归一化纵坐标 → 画面上下位置 */
function verticalLabel(y: number): string {
  if (y < 0.38) return '偏上';
  if (y > 0.62) return '偏下';
  return '纵向居中';
}

/** composition.subjectFrame（主体外框左上角 + 宽高，均归一化 0~1）→「主体落位与占比」描述 */
function describeSubjectFrame(v: unknown): string | undefined {
  if (!isPlainObject(v)) return undefined;
  const x = toNum(v.x);
  const y = toNum(v.y);
  const w = toNum(v.w);
  const h = toNum(v.h);
  if (x === undefined || y === undefined || w === undefined || h === undefined) return undefined;
  const pct = (n: number): string => `${Math.round(n * 100)}%`;
  return `主体位于画面${horizontalLabel(x + w / 2)}${verticalLabel(y + h / 2)}，横向占画幅约 ${pct(w)}、纵向约占 ${pct(h)}`;
}

/** pose.position（{x,y} 归一化中心点）→ 人物落位描述 */
function describePosePosition(v: unknown): string | undefined {
  if (!isPlainObject(v)) return undefined;
  const x = toNum(v.x);
  const y = toNum(v.y);
  if (x === undefined || y === undefined) return undefined;
  return `人物位于画面${horizontalLabel(x)}${verticalLabel(y)}`;
}

/** pose.scale（0.1~3）→ 人物在画面中的大小描述 */
function describePoseScale(v: unknown): string | undefined {
  const scale = toNum(v);
  if (scale === undefined) return undefined;
  if (scale < 0.85) return '人物在画面中偏小（环境人像式，留出较多环境空间）';
  if (scale > 1.25) return '人物在画面中较大（接近半身或特写）';
  return '人物在画面中占比适中（半身到七分身）';
}

/** pose.rotation（度；0 表示正立）→ 人物倾斜描述，非零才输出并强调地平线仍须水平 */
function describePoseRotation(v: unknown): string | undefined {
  const rotation = toNum(v);
  if (rotation === undefined || Math.abs(rotation) < 1) return undefined;
  return `人物身体可整体倾斜约 ${Math.round(Math.abs(rotation))} 度（地平线仍须保持水平）`;
}

/** 姿势落位/大小/倾斜合成（兼容旧数据：position 为纯文本时直接沿用） */
function describePosePlacement(pose: Record<string, unknown>): string | undefined {
  const parts = [
    toStr(pose.position) ?? describePosePosition(pose.position),
    describePoseScale(pose.scale),
    describePoseRotation(pose.rotation),
  ].filter((s): s is string => s !== undefined);
  return parts.length ? parts.join('，') : undefined;
}

/** camera 段（镜头 / 快门 / 感光度 / 白平衡 / 曝光补偿 / 对焦 / 闪光灯）→ 素材行 */
function describeCamera(camera: Record<string, unknown>): string[] {
  const lines: string[] = [];
  const lensType = toStr(camera.lensType);
  const lensKey = toStr(camera.lensSuggestion);
  const lensLabel = lensKey !== undefined ? LENS_SUGGESTION_LABELS[lensKey] : undefined;
  const lensParts = [lensType, lensLabel !== undefined ? `建议${lensLabel}` : undefined].filter(Boolean);
  if (lensParts.length) lines.push(`- 镜头：${lensParts.join('，')}`);

  const shutterSpeed = toStr(camera.shutterSpeed);
  if (shutterSpeed) lines.push(`- 快门：${shutterSpeed}`);

  const iso = toNum(camera.iso);
  const isoModeKey = toStr(camera.isoMode);
  const isoModeLabel = isoModeKey !== undefined ? ISO_MODE_LABELS[isoModeKey] : undefined;
  if (iso !== undefined || isoModeLabel !== undefined) {
    const isoText = iso !== undefined ? `ISO ${Math.round(iso)}` : 'ISO';
    lines.push(`- 感光度：${isoModeLabel !== undefined ? `${isoText}（${isoModeLabel}）` : isoText}`);
  }

  const wbKey = toStr(camera.whiteBalance);
  const wbLabel = wbKey !== undefined ? WHITE_BALANCE_LABELS[wbKey] : undefined;
  const wbK = toNum(camera.whiteBalanceK);
  const wbParts = [wbLabel, wbK !== undefined ? `${Math.round(wbK)}K` : undefined].filter(Boolean);
  if (wbParts.length) lines.push(`- 白平衡：${wbParts.join(' ')}`);

  const exposure = toNum(camera.exposureCompensation);
  if (exposure !== undefined) {
    lines.push(`- 曝光补偿：${exposure > 0 ? '+' : ''}${exposure}EV`);
  }

  const focusKey = toStr(camera.focusMode);
  const focusLabel = focusKey !== undefined ? FOCUS_MODE_LABELS[focusKey] : undefined;
  if (focusLabel) lines.push(`- 对焦：${focusLabel}`);

  const flashKey = toStr(camera.flashMode);
  const flashLabel = flashKey !== undefined ? FLASH_MODE_LABELS[flashKey] : undefined;
  if (flashLabel && flashKey !== 'off') lines.push(`- 闪光灯：${flashLabel}`);

  return lines;
}

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

  // ② 构图与机位：构图法则 / 主体落位与占比 / 拍摄距离与景别 / 光线方向 / 拍摄要领
  //    （原先只在非单姿势时给一句构图描述、单姿势模式下完全不下发，是「没有构图、没有取景位置」的根因）
  const compLines: string[] = [];
  const overlayKey = toStr(composition.overlayType);
  const overlayLabel =
    overlayKey !== undefined && overlayKey !== 'none' ? OVERLAY_TYPE_LABELS[overlayKey] : undefined;
  if (overlayLabel) compLines.push(`- 构图类型：${overlayLabel}`);
  const compDesc = toStr(composition.description);
  if (compDesc) compLines.push(`- 构图说明：${compDesc}`);
  const frameDesc = describeSubjectFrame(composition.subjectFrame);
  if (frameDesc) compLines.push(`- 主体落位：${frameDesc}`);
  const shootingDistance = toStr(sceneGuide.shootingDistance);
  if (shootingDistance) compLines.push(`- 拍摄距离与景别：${shootingDistance}`);
  const lightDirection = toStr(sceneGuide.lightDirection);
  const bestTime = toStr(sceneGuide.bestTime);
  if (lightDirection || bestTime) {
    compLines.push(`- 光线方向：${[bestTime, lightDirection].filter(Boolean).join('的')}`);
  }
  const tips = toStrArray(sceneGuide.tips);
  if (tips.length) compLines.push(`- 拍摄要领：${tips.map((t, i) => `${i + 1}) ${t}`).join('；')}`);
  if (compLines.length) {
    sections.push(`【构图与机位】（构图 / 机位 / 景别须达到专业摄影水准，不得随手乱拍）\n${compLines.join('\n')}`);
  }

  // ③ 本张姿势（单姿势模式给本张姿势 + 人物落位与大小；非单姿势模式下构图已在上一节给出）
  if (isSinglePose && rawPose) {
    const poseLines: string[] = [];
    const poseName = toStr(rawPose.name);
    if (poseName) poseLines.push(`- 姿势名：${poseName}`);
    const poseDesc = toStr(rawPose.description);
    if (poseDesc) poseLines.push(`- 姿势描述：${poseDesc}`);
    const placement = describePosePlacement(rawPose);
    if (placement) poseLines.push(`- 人物落位与大小：${placement}`);
    if (poseLines.length) sections.push(`【本张姿势】（本张只生成这一个姿势）\n${poseLines.join('\n')}`);
  }

  // ④ 网络趋势参考（识别阶段实时搜索命中；与研究摘要共用挑选规则：有摘要条目排前）
  if (research.length) {
    const trendLines = buildResearchLines(research).map((l) => `- ${l}`);
    if (trendLines.length) {
      sections.push(`【网络趋势参考】（识别阶段实时搜索命中的当下流行素材，提炼为可见的视觉元素）\n${trendLines.join('\n')}`);
    }
  }

  // ⑤ 照片参数：画幅 + 相机参数（原先整段相机参数都没下发，是「没有参数优化」的根因）+ 背景道具后期
  const camera = isPlainObject(draft.camera) ? draft.camera : {};
  const paramLines: string[] = [];
  const ratio = toStr(composition.aspectRatio);
  if (ratio) paramLines.push(`- 画幅比例：${ratio}`);
  paramLines.push(...describeCamera(camera));
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

  // ⑥ 生图要求（构图/机位保真 + 真实感去 AI 味 / 一致性 / 单姿势 / 用户附加，全部为硬约束）
  const reqLines: string[] = [];
  reqLines.push('- 构图、机位、景别与姿势线条必须呈现专业摄影水准的美感：画面水平、主体落位与留白经设计、肢体线条舒展，不得出现水平线倾斜、主体顶天立地或被画面边缘随意裁切、四肢与躯干粘连重叠');
  reqLines.push('- 「随拍感」只用于质感与瞬间感（真实材质、自然表情、生活化场景），不得用来合理化随意构图或歪斜的机位');
  reqLines.push('- 构图 / 机位 / 相机参数以【构图与机位】【照片参数】给出的值为准，不得自行改动或降级');
  reqLines.push('- 真实相机直出、朋友随手抓拍的生活照，而非插画、3D 建模渲染、AI 合成、影楼写真或精修广告片');
  reqLines.push('- 必须写入具体摄影参数：镜头与光圈（如 85mm f/1.8 浅景深或手机主摄直出）、快门与感光度与噪点（弱光场景用高 ISO，画面带自然噪点）、白平衡轻微偏移');
  if (categoryKey === 'portrait') {
    reqLines.push('- 人物是街上随处可见的普通年轻人：肤色不均匀、T 区微泛油光而脸颊哑光、皮肤保留毛孔与细小绒毛及淡痕，头发有几缕碎发，衣服有自然褶皱');
    reqLines.push('- 表情松弛自然像被抓拍的瞬间；五官头发手部贴合真实人体结构无畸变；构图讲究：主体落位与留白经设计、肢体线条舒展有延伸感');
    reqLines.push('- 禁止：磨皮、过度均匀的皮肤、完美对称脸、塑料或镜面质感、影棚式布光、锥子脸、高饱和炫彩、精致摆拍');
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
