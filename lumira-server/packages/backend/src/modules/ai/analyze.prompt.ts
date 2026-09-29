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
import { renderStyleProfileBlock, STYLE_CATEGORY_LABELS, type StyleProfile } from './style-profile.presets';

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

/**
 * 人像姿势硬要求：线条设计感 + 表情 + 穿搭 + 左右手落点。
 */
export const PORTRAIT_POSE_REQUIREMENT =
  '姿势要有设计感的线条：避免正面僵直、双手对称、关节正对镜头、手臂紧贴身体。每个姿势必须写清「重心与支撑腿」「肩胯错位」「手部分落点（左右手分别写明动作与落点）」「视线方向」「表情（眼神强度与方向、嘴角、下颌与颈部线的松紧）」「穿搭（颜色、材质、廓形、配饰与褶皱状态，与风格档案的穿搭要求一致）」。';

/**
 * 人像姿势硬要求（有示例图版）：以示例图中真实可见的动作为基准还原，而非另起炉灶。
 * 术语必须与 PORTRAIT_POSE_REQUIREMENT 对齐（含「重心与支撑腿」「手部落点」），保持既有断言与口径一致。
 */
export const PORTRAIT_POSE_FROM_EXAMPLE_REQUIREMENT =
  '姿势必须以示例图中真实可见的动作为基准，不要另起炉灶：每个姿势都要写清「该姿势在参考图中的真实姿态——身体朝向、重心与支撑腿、肩胯错位、手部落点（左右手分别写明动作与落点）、视线方向、表情（眼神强度与方向、嘴角、下颌与颈部线的松紧）」，以及穿搭（颜色、材质、廓形、配饰与褶皱状态，与参考图和风格档案一致）；禁止用「自然站立」「微笑看镜头」这类空泛描述，也禁止把参考图中不同的姿势改写成同一个姿势。';

/**
 * 非人像大类的拍摄方案硬要求：不套用人像姿势用语。
 */
export const NON_PORTRAIT_POSE_REQUIREMENT =
  '画面要有可执行的拍摄方案：写清主体在画面中的位置与占比、视线/引导线如何进入画面、主体与环境的层次关系（前景—中景—远景）、光线方向与明暗过渡、以及器材与参数（焦段、光圈、快门、ISO）如何服务这一构图。不要套用人像的姿势用语。';

const NON_PORTRAIT_TERMS: Record<Exclude<StyleProfile['category'], 'portrait'>, string> = {
  landscape: '层次（前景引导—中景主体—远景空气透视）、光时窗（黄金时刻/蓝调时刻）、留白与地平线位置',
  food: '器皿与道具的摆放逻辑、食物质感的可控高光（蒸汽/油光/碎屑）、俯拍或 45° 视角的取舍',
  street: '环境叙事要素、抓拍时机与运动相位、现场光比与遮挡关系',
  night: '光源列表（每个光源的位置/色温/强度）、高光控制与暗部细节、噪点与快门取舍',
  macro: '放大倍率与最近对焦距离、景深范围（合焦面位置）、背景虚化形态与补光',
  'still-life': '静物的构图关系（大小/朝向/疏密）、材质对比、背景与台面的色温关系',
};

export function isPortraitCategory(category: StyleProfile['category']): boolean {
  return category === 'portrait';
}

/** 按大类分流的「创作质量要求」第 1/2/4 条；hasExample=true（有示例图）时人像姿势以示例图真实可见姿势为基准 */
export function qualityRequirements(category: StyleProfile['category'], hasExample = false): string {
  const pose = isPortraitCategory(category)
    ? hasExample
      ? PORTRAIT_POSE_FROM_EXAMPLE_REQUIREMENT
      : PORTRAIT_POSE_REQUIREMENT
    : NON_PORTRAIT_POSE_REQUIREMENT;
  const term = isPortraitCategory(category)
    ? '人像：构图（三分法/居中/框架式/对角线）+ 浅景深虚化形态 + 主体与背景的分离方式 + 情绪表达'
    : `${STYLE_CATEGORY_LABELS[category]}：${NON_PORTRAIT_TERMS[category]}`;
  return [
    `1. 每张图都必须有明确构图意图：${term}。`,
    `2. ${pose}`,
    '3. 摄影参数必须互洽：光圈、快门、ISO、焦段与画面景深、噪点、运动模糊一致，不得相互矛盾。',
    '4. 画面必须有美感落点：光线有方向与层次，色调有统一倾向，主体有视觉引导；不得出现「平平无奇的中性记录」。',
  ].join('\n');
}

/** 档案段落（无档案时返回空串，保证向后兼容） */
function styleProfileBlock(styleProfile?: StyleProfile): string {
  if (!styleProfile) return '';
  return `\n\n${renderStyleProfileBlock(styleProfile)}\n\n以上档案是本模板的美学基准，所有字段（meta / camera / pose / sceneGuide / composition / postProcess）都必须与它一致。\n`;
}

/** 多人场景关键词（仅用于系统提示词的措辞分档，不写入草稿） */
const MULTI_SUBJECT_PATTERN =
  /(情侣|恋人|夫妻|结婚|婚纱|婚礼|双人|两人|二人|一对|闺蜜|姐妹|兄弟|全家福|一家人|家庭|合影|合照|团体|多人|三五好友|朋友|聚餐|聚会|亲子|母子|母女|父子|父女|毕业照)/;

/** 从用户输入预判主体人数档位：命中多人关键词 → 2，否则 1。仅用于提示词措辞分档，最终值以模型输出为准。 */
export function inferSubjectCountHint(...texts: Array<string | null | undefined>): number {
  for (const t of texts) {
    if (typeof t === 'string' && MULTI_SUBJECT_PATTERN.test(t)) return 2;
  }
  return 1;
}

/** 输出 JSON 契约示例（设计文档第四节草稿 JSON，jsonc 注释保留作字段说明） */
const DRAFT_JSON_EXAMPLE = `{
  "meta": {
    "name": "晴空田园少女人像侧拍",          // 场景+主体+风格+角度，12~30字（硬约束）
    "category": "portrait",                 // 必须命中分类树一级 key
    "subjectCount": 1,                      // 画面主体人数：1=单人；2=情侣/双人；3+=全家福/合影/聚餐；按参考图与用户描述推断
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
    "position": { "x": 0.5, "y": 0.45 }, "scale": 1.0, "rotation": 0, "cameraDirection": "back" }],  // cameraDirection：front=前置摄像头自拍（第一人称视角）/ back=后置他人拍摄（第三人称视角）；数组可含多个姿势（数量规则见硬约束/用户消息）
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

/** 多姿势一致性硬约束：非人像 / 人像单人 / 人像多人三档措辞 */
function poseConsistencyLineOf(portrait: boolean, subjectCountHint: number): string {
  if (!portrait) {
    return '多姿势模板默认视为同一套连续拍摄：每个 pose.description 只描述机位 / 取景 / 参数差异，\n' +
      '  但每一个画面都要独立满足上述「拍摄方案」要求（构图落位、层次、光线、参数），不能因为是第 2、3 张就写得更粗略；\n' +
      '  不得改变主体、场景、道具、光线或整体风格。仅当用户明确要求不同场景 / 主体 / 造型时，才允许对应要素变化；';
  }
  if (subjectCountHint >= 2) {
    return '多姿势模板默认视为同一组人物的同一套连续拍摄：每个 pose.description 只描述动作、身体角度、重心、手部、视线，\n' +
      '  以及人物之间的相对位置与互动关系差异；但每一个姿势都要独立满足上述「姿势质量」要求（线条、重心、手部落点、视线），\n' +
      '  不能因为是第 2、3 张就写得更粗略；不得改变每位人物的长相、服装、发型，也不得改变人物数量、身高差与互动关系。\n' +
      '  仅当用户明确要求不同场景 / 人物 / 造型时，才允许对应要素变化；';
  }
  return '多姿势模板默认视为同一套连续拍摄：每个 pose.description 只描述动作、身体角度、重心、手部和视线差异，\n' +
    '  但每一个姿势都要独立满足上述「姿势质量」要求（线条、重心、手部落点、视线），不能因为是第 2、3 张就写得更粗略；\n' +
    '  不得改变人物长相、服装、发型、体型、场景、道具、光线或整体风格。仅当用户明确要求不同场景 / 人物 /\n' +
    '  造型时，才允许对应要素变化；';
}

/** 系统提示词公共主体：分类树 + 枚举表 + 输出 JSON 契约 + 硬约束（视觉/纯文字版共用；hasExample 区分是否给了示例图） */
function buildSystemPromptBody(
  categories: CategoryNode[],
  styleProfile?: StyleProfile,
  subjectCountHint = 1,
  hasExample = false,
): string {
  const category = styleProfile?.category ?? 'portrait';
  const portrait = isPortraitCategory(category);
  const poseConsistencyLine = poseConsistencyLineOf(portrait, subjectCountHint);
  // 示例图是姿势的权威来源（用户投诉「识别结果完全不参照示例图」）；无图时姿势与构图交给模型按专业水准发挥
  const referenceLine = hasExample
    ? '- 参考图是本模板的最高优先级依据，姿势尤其如此：参考图中真实可见的姿势就是本模板的姿势库，\n' +
      '  pose 数组的每个 description 都必须对着参考图中的一个真实姿势来写（参考图是多格拼图 / 多姿势合集时，每一格就是一种可复用姿势），\n' +
      '  逐一还原该姿势的动作、身体朝向、重心与支撑、肩胯关系、手部分落点（左右手分别写明动作与落点）、视线方向、表情，\n' +
      '  以及人物之间的相对位置与互动、穿搭、所在场景与道具；用户要求的姿势数量少于参考图可见姿势数时，从中挑选最清晰、最具代表性的逐一还原，未选中的不必输出；\n' +
      '  禁止把参考图中不同的姿势改写成同一个姿势，禁止编造参考图中不存在的新姿势；\n' +
      '  仅当参考图中某姿势被遮挡或画面过小而无法辨认时，才按专业摄影水准补齐该处细节；\n' +
      '  相机参数按「复现参考图观感」估算，可比参考图原拍摄手法更专业，但不得改变参考图中的画面主体、姿势与场景；'
    : '- 构图落位、机位、参数与姿势细节由你按专业摄影水准设计，并与文字描述的光线、色调、场景保持一致；\n' +
      '  环境信息只能来自用户描述与创作要求，不得凭空编造描述中未提及的时段、天气或道具；';
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

## 创作质量要求（模板合格线：用户照着拍能得到一张「有构图、有机位、有参数、有细节」的好照片）
只堆氛围词、没有可执行信息的模板视为不合格。以下四条必须写足：

${qualityRequirements(category, hasExample)}

## 硬约束
- 只输出 JSON，不要任何解释，markdown 代码块标记也尽量省略；
- meta.name 具体化（场景+主体+风格+角度，12~30 字），禁止只写风格名；
- meta.shortDesc 只描述整体氛围与情绪（≤20 字），不得包含「N张」「N个姿势」「连拍」「多宫格」「不同姿势」等数量或多图指令；
- meta.description 概述光线 / 氛围 / 主体 / 背景 / 构图；composition.description 专写构图（构图法则 + 主体位置与占比 + 留白与层次），
  两者都不包含数量或多图指令；
- pose 数组中的每个 description 必须是「单张画面内可独立生成」的姿势，不要把多个姿势合并到同一个 description 里；
- meta.subjectCount 必须给出 1~8 的整数：按用户描述与参考图中实际可见的人物数量填写；出现「情侣 / 结婚 / 婚纱 / 闺蜜 / 全家福 / 合影 / 多人 / 聚餐 / 聚会」等场景时不得写 1；
- ${poseConsistencyLine}
- 自拍模板（cameraDirection="front"）的 composition.description、sceneGuide.shootingDistance、tips 也必须按第一人称自拍口径写：
  机位在面部一臂之内、景别为近景 / 半身 / 特写，画面中不出现手机、相机、三脚架、自拍杆等拍摄设备与举着设备的手臂；
- 未知枚举字段直接省略，不要编造；
- meta.classification 从分类树逐级选择，非人像题材允许 style/method 留空；
- 相机参数是「复现该风格的建议参数」，给出合理估算值，并按「创作质量要求」保证各参数互洽；
- 环境信息（光线、背景、道具、时段、天气）必须与参考图或文字描述中实际可见的内容一致，禁止美化或凭空编造；
${referenceLine}
- 相机参数要给「真正能复现参考图观感」的数值：白平衡 / 曝光必须匹配参考图的明暗冷暖——图中偏暖偏亮就给偏暖色温与正常偏亮曝光，图中暗部柔和就相应降低曝光补正，不要给浮夸的电影感或影棚数值；
- 光线方向、最佳时段、拍摄距离要与参考图中的真实光影走向一致，文字描述的光线不能与图中阴影方向冲突，确保用户按此模板实拍能复现参考图的光影效果；
- 不输出 price / silhouette / author / sortOrder / isActive 字段。${styleProfileBlock(styleProfile)}`;
}

/**
 * 视觉识别版系统提示词：示例图是姿势、场景与光线的基准，识别结果必须忠实还原图中真实可见的内容，
 * 不得脱离示例图另起炉灶（姿势尤其）。
 */
export function buildAnalyzeSystemPrompt(categories: CategoryNode[], styleProfile?: StyleProfile, subjectCountHint = 1): string {
  return `你是资深摄影/视觉模板编辑（按风格档案作业），分析用户上传的示例图，产出可直接上线的摄影模板表单数据。\n示例图是本模板的最高优先级依据：图中真实可见的姿势、人物互动、穿搭、场景与光线都必须忠实还原，不得脱离示例图另起炉灶。\n\n${buildSystemPromptBody(categories, styleProfile, subjectCountHint, true)}`;
}

/** 纯文字构思版系统提示词（无示例图，基于文字描述构思模板） */
export function buildTextOnlySystemPrompt(categories: CategoryNode[], styleProfile?: StyleProfile, subjectCountHint = 1): string {
  return `你是资深摄影/视觉模板编辑（按风格档案作业）。用户将提供一段风格描述或创作要求（没有示例图），请据此构思一个可直接上线的摄影模板，产出模板表单数据。描述未提及的字段，给出符合该风格的合理建议值（相机参数为复现该风格的估算值）。\n\n${buildSystemPromptBody(categories, styleProfile, subjectCountHint, false)}`;
}

/** 识别用户提示词附加输入：Step1 文字描述 / 创作要求 / 姿势个数（均可选） */
export interface AnalyzeUserPromptInput {
  /** 文字描述：对模板的补充描述（如「三连拍姿势」） */
  textDesc?: string | null;
  /** 创作要求：对 AI 的额外创作指令 */
  creationReq?: string | null;
  /** 姿势个数：1~9 固定指定；空/undefined = AI 自动判断 */
  poseCount?: number | null;
  /** 主体人数：1~8 显式指定；空/undefined = AI 自动推断 */
  subjectCount?: number | null;
  /** 趋势研究摘要（识别前已搜索命中；结构化数据构思时贴合当下流行趋势） */
  researchDigest?: string | null;
  /** 已开启联网搜索但本次未取到任何来源/摘要 → 提示词显式声明，禁止凭训练知识编造时效信息 */
  researchUnavailable?: boolean;
}

/** 构造姿势数量指令行（vision / text-only 共用） */
function poseCountLine(poseCount: number | null | undefined): string {
  if (typeof poseCount === 'number' && Number.isInteger(poseCount) && poseCount >= 1 && poseCount <= 9) {
    return `pose 数组必须恰好输出 ${poseCount} 个姿势，每个姿势有独立的 name / description / position / cameraDirection。`;
  }
  return (
    '请根据用户文字描述与创作要求（包括示例图中可见的文字要求，如「三连拍」等）判断需要多少个姿势，' +
    '在 1~9 个范围内输出，每个姿势有独立的 name / description / position / cameraDirection；无明确要求时输出 1 个。'
  );
}

/** 构造主体人数指令行（vision / text-only 共用） */
function subjectCountLine(subjectCount: number | null | undefined): string {
  if (typeof subjectCount === 'number' && Number.isInteger(subjectCount) && subjectCount >= 1 && subjectCount <= 8) {
    return `meta.subjectCount 必须为 ${subjectCount}：画面中要有 ${subjectCount} 位人物，姿势描述需体现人物之间的相对位置与互动关系。`;
  }
  return (
    '请根据用户描述与示例图中实际可见的人物数量给出 meta.subjectCount（1~8 整数）：' +
    '单人写 1；情侣 / 双人 / 闺蜜写 2；全家福 / 合影 / 多人聚餐写 3 及以上；无明确线索时写 1。'
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
  lines.push(subjectCountLine(input.subjectCount));
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
  lines.push(subjectCountLine(input.subjectCount));
  lines.push(poseCountLine(input.poseCount));
  return lines.join('\n');
}
