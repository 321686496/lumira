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
    "description": "午后四点的斜阳从右后方照进田野，女孩侧身站在没过膝盖的草丛里回头，浅金色逆光在发梢勾出轮廓光；三分法构图，人物落在左三分线上，右侧留出大片天空作呼吸空间，前景草叶虚化、远景田野层叠。",
    "tags": ["日系", "田园", "清新"],
    "ambience": { "seasons": ["summer"], "weathers": ["sunny"], "timeTones": ["day"] },
    "classification": { "type": "portrait", "majorStyle": "…", "style": "…", "method": "" }
  },
  "composition": { "overlayType": "rule_of_thirds", "aspectRatio": "3:4", "opacity": 0.5,
    "description": "三分法构图：人物主体落在左侧三分线上、视线朝向右侧留白；前景为虚化的草叶，中景是人物，远景是层叠的田野与天空，形成前中后三层景深。",
    "subjectFrame": { "x": 0.3, "y": 0.2, "w": 0.4, "h": 0.6 } },
  "pose": [{ "name": "侧身回眸", "description": "身体侧转45度、右脚为重心微微后撤，肩线右低左高；左手轻扶草帽帽檐、右手自然垂在身侧微屈，下巴略抬，视线越过右肩看向镜头斜上方，露出颈部线条。",
    "position": { "x": 0.5, "y": 0.45 }, "scale": 1.0, "rotation": 0 }],  // 数组可含多个姿势（数量规则见硬约束/用户消息）
  "camera": { "exposureCompensation": 0.3, "isoMode": "manual", "iso": 200,
    "shutterSpeed": "1/400", "whiteBalance": "daylight", "whiteBalanceK": 5500,
    "flashMode": "off", "focusMode": "auto", "lensType": "85mm f/1.8",
    "lensSuggestion": "telephoto" },  // 各参数须互洽：85mm 人像压缩感 + f/1.8 浅景深 + 1/400 抓拍 + ISO 200 明亮日景 + 日光白平衡
  "sceneGuide": { "lightDirection": "右后方侧逆光，发梢有轮廓光", "shootingDistance": "2-3米（七分身）",
    "background": "层叠的田野与天空，远处有低矮树林", "props": ["草帽"], "bestTime": "午后4-6点",
    "tips": ["机位降到胸口高度略仰拍，避免俯拍压缩身高", "先对焦眼睛再构图：人物左三分落位、视线侧留白",
      "逆光时在正面用反光板或白纸补一点光，避免脸部死黑"] },
  "postProcess": { "cropRatio": "3:4",
    "color": { "brightness": 5, "contrast": 8, "saturation": -10, "temperature": 10,
      "tint": 3, "highlights": -5, "shadows": 8 },
    "smoothStrength": 15, "sharpen": 10, "vignette": 12, "grain": 18,
    "lut": "japanese_fresh",
    "fillLight": { "enabled": true, "color": "warm", "intensity": 0.6 },  // App 补光：暗部/夜景/室内开启（Task9）
    "legStretch": 40  // 拉腿比例 0~100（App 整数值，满档 100）；仅全身/半身姿势使用（Task9）
  },
  "poseRefSheet": { "shared": { "outfit": "米色针织", "scene": "飘窗" },
    "perPose": [{ "name": "侧身回眸", "differentiationNote": "身体右转45度。" }] }  // 姿势参考面片（Task9）
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

## 创作质量要求（模板合格线：用户照着拍能得到一张「有构图、有机位、有参数、有姿势细节」的好照片）
只堆氛围词、没有可执行信息的模板视为不合格。以下四块必须写足：

1. 构图（composition.description + overlayType + subjectFrame）
   - 写明构图法则（三分法 / 中心对称 / 对角线 / 引导线 / 框架式 / 大面积留白…）以及这么构图的原因；
   - 写明主体在画面中的位置（左/右/中、上/中/下）与占比（约占画幅几分之几），并给出与之完全一致的 overlayType 与 subjectFrame 归一化坐标（x/y/w/h，0~1）；
   - 写明留白方向与前景 / 中景 / 背景的层次关系；视线或动作朝向的一侧要留出空间；
   - 禁止「主体顶天立地、水平线歪斜、背景线条穿过人物头部、主体被边缘随意裁切」这类无设计感的画面。
2. 姿势（pose[].description + position/scale/rotation）
   - 必须写到可直接照做：身体朝向（正/侧/背，转动多少度）、重心与支撑腿、肩线与胯线是否错位、下巴高低、视线看向何处；
   - 手部要分别写明左右手的具体动作与落点（扶帽檐 / 托腮 / 插兜 / 撩发 / 拎包…），不要写「手自然摆放」这类空话；
   - 必须是有美感的肢体线条：四肢不与躯干轮廓重叠粘连，不出现正面僵直站姿、双手对称、关节正对镜头、手臂紧贴身体；
   - 同时给出与姿势匹配的 position（归一化中心坐标）、scale（人物大小）、rotation（画面旋转，通常 0）。
3. 相机参数（camera）—— 必须是「互洽、能实现上述观感」的一组值，而不是各自孤立的数字
   - lensType 与 lensSuggestion 要和景别、透视一致（人像 85mm/50mm 压缩感，环境人像 24~35mm，手机主摄等效 26mm）；
   - 光圈与景深、快门与动作/焦距、ISO 与光线亮度、白平衡与画面冷暖、曝光补偿与明暗意图各自对应得上；
   - 禁止自相矛盾的组合（明亮日景给 ISO 6400、要浅景深却给 f/16、抓拍动态却给 1/30）；
   - 参数必须是「真实可复现该观感」的估算值，不要浮夸的电影感或影棚数值。
4. 取景与机位（sceneGuide）
   - lightDirection 写清方向与性质（右后方侧逆光、顺光、顶光、窗光、路灯…），shootingDistance 与景别一致并带上景别（全身 / 七分身 / 半身 / 特写）；
   - tips 至少 2 条，必须是可以照做的拍摄要领（机位高度与角度、对焦与构图顺序、如何用前景或反光板解决光线问题…），禁止写「注意光线」这类空话；
   - background / props 要服务于构图与氛围（例如背景线条的走向、前景虚化物），不要只是罗列名词。

## 硬约束
- 只输出 JSON，不要任何解释，markdown 代码块标记也尽量省略；
- meta.name 具体化（场景+主体+风格+角度，12~30 字），禁止只写风格名；
- meta.shortDesc 只描述整体氛围与情绪（≤20 字），不得包含「N张」「N个姿势」「连拍」「多宫格」「不同姿势」等数量或多图指令；
- meta.description 概述光线 / 氛围 / 主体 / 背景 / 构图；composition.description 专写构图（构图法则 + 主体位置与占比 + 留白与层次），
  两者都不包含数量或多图指令；
- pose 数组中的每个 description 必须是单张单人可独立生成的姿势，
  不要把多个姿势合并到同一个 description 里；
- 多姿势模板默认视为同一套连续拍摄：每个 pose.description 只描述动作、身体角度、重心、手部和视线差异，
  但每一个姿势都要独立满足上述「姿势质量」要求（线条、重心、手部落点、视线），不能因为是第 2、3 张就写得更粗略；
  不得改变人物长相、服装、发型、体型、场景、道具、光线或整体风格。仅当用户明确要求不同场景 / 人物 /
  造型时，才允许对应要素变化；
- 未知枚举字段直接省略，不要编造；
- meta.classification 从分类树逐级选择，非人像题材允许 style/method 留空；
- 相机参数是「复现该风格的建议参数」，给出合理估算值，并按「创作质量要求」保证各参数互洽；
- 环境信息（光线、背景、道具、时段、天气）必须与参考图或文字描述中实际可见的内容一致，禁止美化或凭空编造；
- 「还原参考图」与「构图 / 姿势 / 参数的质量要求」并不冲突：参考图给的是光线、色调、场景与人物这些客观事实，
  构图落位、机位、参数与姿势细节由你按专业摄影水准补足；参考图本身构图不佳时，不要照抄它的缺点，
  而是在保持光线与风格一致的前提下给出更好的构图与机位建议；
- 相机参数要给「真正能复现参考图观感」的数值：白平衡 / 曝光必须匹配参考图的明暗冷暖——图中偏暖偏亮就给偏暖色温与正常偏亮曝光，图中暗部柔和就相应降低曝光补正，不要给浮夸的电影感或影棚数值；
- 光线方向、最佳时段、拍摄距离要与参考图中的真实光影走向一致，文字描述的光线不能与图中阴影方向冲突，确保用户按此模板实拍能复现参考图的光影效果；
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
  /** 趋势研究摘要（识别前已搜索命中；结构化数据构思时贴合当下流行趋势） */
  researchDigest?: string | null;
  /** 已开启联网搜索但本次未取到任何来源/摘要 → 提示词显式声明，禁止凭训练知识编造时效信息 */
  researchUnavailable?: boolean;
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

/** 构造附加输入行（textDesc / creationReq / researchDigest，vision / text-only 共用） */
function extrasLines(input: AnalyzeUserPromptInput): string[] {
  const lines: string[] = [];
  const textDesc = typeof input.textDesc === 'string' ? input.textDesc.trim() : '';
  if (textDesc) lines.push(`用户文字描述：${textDesc}`);
  const creationReq = typeof input.creationReq === 'string' ? input.creationReq.trim() : '';
  if (creationReq) lines.push(`创作要求：${creationReq}（识别/构思结果需向该要求倾斜）`);
  const digest = typeof input.researchDigest === 'string' ? input.researchDigest.trim() : '';
  if (digest) {
    lines.push(
      '网络趋势参考（已由模型对当前实时联网检索结果做二次整理后的结论，按维度分节给出；' +
        '构思模板的主题、风格、场景、节日、姿势时优先贴合其中的有效信息，与创作要求冲突时以创作要求为准）：',
      digest,
    );
  } else if (input.researchUnavailable) {
    lines.push(
      '联网检索状态：本次未取到任何联网来源（无参考素材）。',
      '因此涉及时效信息时：只能使用用户输入中明确写出的时间/节日/季节信息，禁止凭训练记忆编造节日名称、节日日期、',
      '"最近/最新"类趋势结论；确实无法确定时用泛化的季节/氛围表述，不要写具体节日名与日期。',
    );
  }
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
