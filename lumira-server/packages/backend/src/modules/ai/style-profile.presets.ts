// 风格档案内置预设：零依赖模块（禁止 import 本目录其它文件），供 service / analyze.prompt /
// pose-ref-sheet / image-prompt.composer / image-prompt.builder / image-score 复用。

export const STYLE_CATEGORIES = [
  'portrait',
  'landscape',
  'food',
  'street',
  'night',
  'macro',
  'still-life',
] as const;
export type StyleCategory = (typeof STYLE_CATEGORIES)[number];

export const STYLE_ARCHETYPES = [
  'fashion_editorial', // 时尚大片：强设计感、戏剧光比、大片调性
  'photo_portrait', // 摄影写真：干净通透、柔和布光、精致妆造
  'candid_lifestyle', // 随拍松弛：生活化光线、松弛瞬间感
  'social_media_trendy', // 网感网红：小红书/抖音审美、明亮干净、强穿搭感
  'documentary_street', // 纪实街拍：环境叙事、真实光比、抓拍瞬间
  'landscape_fine_art', // 风景意境：层次、留白、光时窗
  'food_lifestyle', // 美食生活：质感、器皿、暖调氛围
] as const;
export type StyleArchetype = (typeof STYLE_ARCHETYPES)[number];

export const RETOUCH_LEVELS = ['none', 'light', 'polished'] as const;
export type RetouchLevel = (typeof RETOUCH_LEVELS)[number];

export interface StyleProfile {
  category: StyleCategory;
  archetype: StyleArchetype;
  /** 一句话美学目标 */
  aestheticTarget: string;
  /** 穿搭/妆造/材质/配饰要点（非人像可为空） */
  subjectStyling: string;
  /** 表情与情绪（非人像可为空） */
  expressionMood: string;
  /** 姿势语言：张力/舒展/松弛/戏剧 */
  poseLanguage: string;
  /** 光比与光线特征 */
  lightingSignature: string;
  /** 构图偏好 */
  compositionBias: string;
  /** 色调倾向 */
  paletteHint: string;
  retouchLevel: RetouchLevel;
  /** 现场补充的个性细节（不得改写档案底线） */
  extraNotes: string;
}

export interface StyleArchetypePreset extends Omit<StyleProfile, 'extraNotes'> {
  /** 仅本档案级禁忌（底线之外的补充禁忌） */
  forbidden: string;
}

export const STYLE_CATEGORY_LABELS: Record<StyleCategory, string> = {
  portrait: '人像',
  landscape: '风景',
  food: '美食',
  street: '街拍',
  night: '夜景',
  macro: '微距',
  'still-life': '静物',
};

export const STYLE_ARCHETYPE_LABELS: Record<StyleArchetype, string> = {
  fashion_editorial: '时尚大片',
  photo_portrait: '摄影写真',
  candid_lifestyle: '随拍松弛',
  social_media_trendy: '网感网红',
  documentary_street: '纪实街拍',
  landscape_fine_art: '风景意境',
  food_lifestyle: '美食生活',
};

export const RETOUCH_LEVEL_LABELS: Record<RetouchLevel, string> = {
  none: '无精修（自然随拍）',
  light: '轻精修（干净通透）',
  polished: '精致精修（大片调性）',
};

/** 所有档案共享的真实底线，恒定注入，不随档案变化 */
export const REALISM_BASELINE =
  '真实照片媒介（非动漫/插画/漫画/赛璐璐/厚涂/CG/3D 渲染/油画/游戏立绘）；' +
  '真实人体结构与解剖（无肢体、手指、面部畸变）；' +
  '可实拍复现（无无源光、无不可能透视与姿势）；' +
  '真实材质（皮肤毛孔与绒毛、布料纹理、环境光衰减与阴影过渡）。';

export const STYLE_ARCHETYPE_PRESETS: Record<StyleArchetype, StyleArchetypePreset> = {
  fashion_editorial: {
    archetype: 'fashion_editorial',
    category: 'portrait',
    retouchLevel: 'polished',
    aestheticTarget: '杂志时尚大片：强设计感、戏剧性光比、克制的冷峻高级感',
    subjectStyling: '廓形明确的时装造型，材质对比强烈（挺括与垂坠并置），配饰大而有设计感，妆面干净有力、颧骨与下颌线立体',
    expressionMood: '眼神直视镜头、情绪冷峻克制，嘴角平直不下垂，下颌微收拉出颈部线条',
    poseLanguage: '身体线条有张力与方向性，肩胯错位明显，手部有明确造型（扶腰、插袋、抚颈）',
    lightingSignature: '硬光或高光比，主光侧向低位，轮廓光勾边压暗背景',
    compositionBias: '对角线、框架式构图，主体偏离中心，大面积留白或负空间',
    paletteHint: '低饱和高级灰、冷调或单色系，暗部厚重',
    forbidden: '忌生活化杂乱、忌平光无层次、忌糖果色',
  },
  photo_portrait: {
    archetype: 'photo_portrait',
    category: 'portrait',
    retouchLevel: 'light',
    aestheticTarget: '干净通透的摄影写真：柔和布光、精致妆造、皮肤真实但整洁',
    subjectStyling: '简洁耐看的日常精致穿搭，同色系或邻近色组合，面料柔软有垂感，配饰小而精，妆面轻薄水光',
    expressionMood: '表情放松自然，眼神有落点（看镜头或看侧前方），嘴角微松或浅笑，下颌与颈部线舒展',
    poseLanguage: '线条舒展柔和，避免正面僵直，肩线一高一低，双手动作不对称',
    lightingSignature: '柔和窗光或柔光箱，光比克制（1:2 以内），皮肤过渡平滑不留硬阴影',
    compositionBias: '三分法或居中构图，浅景深柔化背景，主体清晰通透',
    paletteHint: '低饱和暖白或奶油调，整体明亮干净',
    forbidden: '忌脏乱背景、忌过度磨皮失纹理、忌浓重色偏',
  },
  candid_lifestyle: {
    archetype: 'candid_lifestyle',
    category: 'portrait',
    retouchLevel: 'none',
    aestheticTarget: '生活化的松弛随拍：真实环境光、自然瞬间感、不做作',
    subjectStyling: '舒适日常衣物，自然褶皱与轻微不规则，配饰随意（手表、帆布袋、眼镜），妆面接近素颜',
    expressionMood: '情绪自然松弛，可专注做事、可低头一笑，不刻意看镜头，眼神有真实注视对象',
    poseLanguage: '动作来自真实行为（走、坐、倚、拿、递），重心自然落在一条腿上，双手有具体落点',
    lightingSignature: '自然环境光或室内混合光，光比自然，保留环境明暗关系',
    compositionBias: '三分法环境人像，带环境信息与生活道具，允许轻微不完美构图',
    paletteHint: '真实环境色，轻微白平衡偏移，不刻意统一色调',
    forbidden: '忌刻意摆拍痕迹、忌影棚式布光、忌塑料感妆容',
  },
  social_media_trendy: {
    archetype: 'social_media_trendy',
    category: 'portrait',
    retouchLevel: 'light',
    aestheticTarget: '小红书/抖音网感：明亮干净、穿搭感强、一眼好看的高信息量画面',
    subjectStyling: '当季流行单品与鲜明配色，穿搭层次清楚（外套/内搭/配饰三层可读），材质干净无褶皱瑕疵',
    expressionMood: '表情生动有亲和力，眼神明亮，嘴角上扬，可俏皮或元气，眼周与苹果肌有真实高光',
    poseLanguage: '姿势有明确视觉引导（抬手下压、侧身回望、手托脸颊），手脚关系清楚、不重叠遮挡',
    lightingSignature: '明亮通透的顺光或窗光，面部无阴影死角，背景明亮不发灰',
    compositionBias: '居中或对称、九宫格对齐，主体占比大，背景干净或有统一装饰',
    paletteHint: '明亮高调、低饱和奶油色或清透多巴胺色，白平衡偏中性',
    forbidden: '忌脏乱背景、忌暗调沉闷、忌过度锐化的塑料皮',
  },
  documentary_street: {
    archetype: 'documentary_street',
    category: 'street',
    retouchLevel: 'none',
    aestheticTarget: '纪实现场：环境叙事、抓拍瞬间、真实光比',
    subjectStyling: '符合场景身份的真实衣着，不做造型设计，允许磨损与使用痕迹',
    expressionMood: '被摄者处于真实状态，表情不做表演，视线与动作由所处情境决定',
    poseLanguage: '动作是行进中或行为中的一瞬，重心不稳感真实，四肢处于自然运动相位',
    lightingSignature: '现场光，允许高光比与逆光，保留环境光斑与阴影遮挡',
    compositionBias: '引导线、框架式、多层前后景关系，主体嵌入环境中而非独立于环境',
    paletteHint: '环境真实色偏，冷暖并存，不做统一调色',
    forbidden: '忌摆拍造型、忌影棚光、忌完美对称的表演性构图',
  },
  landscape_fine_art: {
    archetype: 'landscape_fine_art',
    category: 'landscape',
    retouchLevel: 'light',
    aestheticTarget: '有意境的风景：层次递进、留给呼吸的留白、光时窗把握',
    subjectStyling: '',
    expressionMood: '',
    poseLanguage: '主体自然形态的走向与动势（山脊线、树形、水流方向）决定画面张力，避免正中死板的静态对称',
    lightingSignature: '黄金时刻或蓝调时刻的低角度光，光向与阴影拉出体积，雾气/水汽增加空气透视',
    compositionBias: '大面积留白、前景—中景—远景层叠，地平线按三分法安置，避免居中切割',
    paletteHint: '同色系低饱和，冷暖分区明确，暗部保留细节',
    forbidden: '忌杂乱前景、忌平淡顶光、忌 HDR 脏灰过度处理',
  },
  food_lifestyle: {
    archetype: 'food_lifestyle',
    category: 'food',
    retouchLevel: 'light',
    aestheticTarget: '有食欲的生活美食：质感清晰、器皿搭配讲究、暖调氛围',
    subjectStyling: '器皿与布景材质有真实质感（陶、木、亚麻、石材），道具摆放有疏密节奏，食物保留蒸汽/油光/碎屑等真实细节',
    expressionMood: '',
    poseLanguage: '食物的摆放形态与动势（堆叠、切割面朝向、汁液流动方向）配合器皿与餐具朝向形成视觉引导，避免摊平堆叠',
    lightingSignature: '侧逆光或柔光侧照，塑造食物表面高光与轮廓，阴影通透不过黑',
    compositionBias: '俯拍或 45° 视角，器皿间留出呼吸间距，主体食物为绝对视觉中心',
    paletteHint: '暖调低饱和，木色/米白/焦糖色为主，绿植点缀',
    forbidden: '忌冷调阴森、忌塑料假食物质感、忌满画面堆叠',
  },
};

const isObj = (v: unknown): v is Record<string, unknown> =>
  typeof v === 'object' && v !== null && !Array.isArray(v);

const str = (v: unknown): string => (typeof v === 'string' ? v.trim() : '');

const pickEnum = <T extends string>(v: unknown, allowed: readonly T[], fallback: T): T =>
  allowed.includes(v as T) ? (v as T) : fallback;

/** 以档案为基底归一化一份 StyleProfile：枚举越界兜底，文本字段缺失时回填档案默认 */
export function normalizeStyleProfile(raw: unknown, fallbackArchetype: StyleArchetype = 'candid_lifestyle'): StyleProfile {
  const src = isObj(raw) ? raw : {};
  const archetype = pickEnum(src.archetype, STYLE_ARCHETYPES, fallbackArchetype);
  const preset = STYLE_ARCHETYPE_PRESETS[archetype];
  return {
    category: pickEnum(src.category, STYLE_CATEGORIES, preset.category),
    archetype,
    aestheticTarget: str(src.aestheticTarget) || preset.aestheticTarget,
    subjectStyling: str(src.subjectStyling) || preset.subjectStyling,
    expressionMood: str(src.expressionMood) || preset.expressionMood,
    poseLanguage: str(src.poseLanguage) || preset.poseLanguage,
    lightingSignature: str(src.lightingSignature) || preset.lightingSignature,
    compositionBias: str(src.compositionBias) || preset.compositionBias,
    paletteHint: str(src.paletteHint) || preset.paletteHint,
    retouchLevel: pickEnum(src.retouchLevel, RETOUCH_LEVELS, preset.retouchLevel),
    extraNotes: str(src.extraNotes),
  };
}

export function defaultStyleProfile(): StyleProfile {
  return normalizeStyleProfile({ archetype: 'candid_lifestyle', category: 'portrait' });
}

/** 从草稿顶层读取 styleProfile（非法/缺失返回 undefined，不抛错） */
export function styleProfileOfDraft(draft: unknown): StyleProfile | undefined {
  if (!isObj(draft)) return undefined;
  const raw = draft.styleProfile;
  if (!isObj(raw) || typeof raw.archetype !== 'string') return undefined;
  return normalizeStyleProfile(raw);
}

/** 渲染为可注入系统提示词的档案约束块 */
export function renderStyleProfileBlock(profile: StyleProfile): string {
  const lines = [
    '## 本次风格档案（必须遵守）',
    `- 大类：${STYLE_CATEGORY_LABELS[profile.category]}（category=${profile.category}）`,
    `- 风格取向：${STYLE_ARCHETYPE_LABELS[profile.archetype]}（archetype=${profile.archetype}）`,
    `- 精修档：${RETOUCH_LEVEL_LABELS[profile.retouchLevel]}（retouchLevel=${profile.retouchLevel}）`,
    `- 美学目标：${profile.aestheticTarget}`,
    `- 穿搭/妆造：${profile.subjectStyling || '（本档案不涉及）'}`,
    `- 表情与情绪：${profile.expressionMood || '（本档案不涉及）'}`,
    `- 姿势语言：${profile.poseLanguage || '（本档案不涉及）'}`,
    `- 光线特征：${profile.lightingSignature}`,
    `- 构图偏好：${profile.compositionBias}`,
    `- 色调倾向：${profile.paletteHint}`,
    `- 本档案禁忌：${STYLE_ARCHETYPE_PRESETS[profile.archetype].forbidden}`,
    `- 现场补充细节：${profile.extraNotes || '无'}`,
    `- 底线（真实不可突破）：${REALISM_BASELINE}`,
    '现场补充细节只允许在本档案允许范围内补个性，若与上述底线冲突，以底线为准，底线优先级高于以上任何一项。',
  ];
  return lines.join('\n');
}