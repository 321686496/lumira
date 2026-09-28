# AI 一键生成模板：风格档案分流 + 全链路提示词美学改造 + 美学评审闸门 · 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为「AI 一键生成模板」链路引入意图识别（风格档案 StyleProfile），让姿势图提示词同时具备构图/参数/姿势线条/穿搭/表情/光线美感，并保证「真实」为不可突破的底线。

**Architecture:** 在 analyze 之前做一次风格定位（新增 `StyleProfileService`，失败降级），产出 `StyleProfile` 后分发给 analyze 提示词、image-describe、pose-ref-sheet、image-score 评审、draft-refine、生图前的 composer 与硬加固。姿态审评从「单总分」改为「总分 + 美学分项 + 真实分项」三段闸门，并取消「无参考图跳过评审」。

**Tech Stack:** NestJS 10 + Fastify + Drizzle ORM + TypeScript 5.3；Jest 29 + ts-jest；后端包 `@lumira/backend`。

## Global Constraints

- 后端包路径：`lumira-server/packages/backend/`，包名 `@lumira/backend`。
- 运行单测：`pnpm --filter @lumira/backend exec jest src/modules/ai/<file>.spec.ts`
- 运行模块全量测试：`pnpm --filter @lumira/backend exec jest src/modules/ai`
- 类型检查：`pnpm --filter @lumira/backend exec tsc -p tsconfig.build.json --noEmit`
- LLM 调用统一走 `llm-client.ts` 的 `textChat` / `visionChat`，`LlmEndpoint { provider, baseUrl, apiKey, model }`，`TextChatInput { systemPrompt, userText, temperature?, jsonMode?, timeoutMs? }`，`DEFAULT_TIMEOUT_MS = 300_000`。
- 默认 LLM 端点：`cfg.text`（`getActiveConfig()` 返回值），不新增 provider。
- **真实底线（不可违反）**：真实照片媒介（非动漫/插画/漫画/赛璐璐/厚涂/CG/3D 渲染/油画/游戏立绘）、真实人体结构与解剖（无肢体/手指/面部畸变）、可实拍复现（无无源光、无不可能透视与姿势）、真实材质（皮肤毛孔与绒毛、布料纹理、环境光衰减与阴影过渡）。
- **确定性文案禁令**：改造后全链路提示词**不得再出现**子串 `轻微噪点`、`禁止影楼写真`、`网红精修风`；`动漫、二次元、漫画、插画` 负面清单必须保留。
- **类型兼容原则**：所有新增字段（`styleProfile`、`people[].expression`、`people[].styling`、`global.styleRead`、`subjectPose` 字段级契约、`shared.styling`、`shared.expressionMood`）均为**可选**，既有测试夹具必须仍可编译。
- 不修改 `lumira-app/`；不改 App 端模板数据结构与展示；不改 admin 前端与 Vercel 配置。
- 不新增 npm 依赖。
- 每个 Task 结束后：跑该 Task 全部相关单测 + `tsc --noEmit` → `git add` 指定文件 → commit → **push 到 `origin`(gitee) 与 `github` 两个远程的 `master`**（工作区规则强制）。
  ```bash
  git push origin master
  git push github master
  ```

## File Structure

**新增**

| 文件 | 职责 |
| --- | --- |
| `src/modules/ai/style-profile.presets.ts` | 档案枚举、`StyleProfile` 契约、7 条内置档案、底线文案、归一化与渲染（零依赖，禁止 import 本模块其它文件，避免循环依赖） |
| `src/modules/ai/style-profile.presets.spec.ts` | presets 单测 |
| `src/modules/ai/style-profile.service.ts` | 风格定位 LLM 调用 + 解析 + 降级（`resolve()`） |
| `src/modules/ai/style-profile.service.spec.ts` | 风格定位单测 |
| `src/modules/ai/draft-refine.service.spec.ts` | 逐项整改口径单测（原文件无 spec） |

**修改**

| 文件 | 改动要点 |
| --- | --- |
| `src/modules/ai/analyze.prompt.ts` | 按 `category` 分流的质量要求 + 档案注入 + 表情/穿搭硬要求 |
| `src/modules/ai/ai-analyze.service.ts` | 第 5 可选参数 `styleProfile`，第 3.5 步 resolve 一次，注入 prompt 且透传 orchestrator |
| `src/modules/ai/normalize.ts` | 白名单放行顶层 `styleProfile` |
| `src/modules/ai/ai.module.ts` | 注册 `StyleProfileService` |
| `src/modules/ai/image-describe.prompt.ts` | `people[].expression/styling`、`global.styleRead` 指引 |
| `src/modules/ai/image-describe.service.ts` | 契约扩展 + 兜底 |
| `src/modules/ai/pose-ref-sheet.service.ts` | `subjectPose` 字段级契约、`shared` 扩 2 项、注入档案 |
| `src/modules/ai/image-prompt.composer.ts` | 规则 9 改为「档案内可补审美」、新增【风格档案】素材段 |
| `src/modules/ai/image-prompt.builder.ts` | 按 `retouchLevel` 分档质感结尾句 + 档案审美短语 |
| `src/modules/ai/ai-generate-image.service.ts` | `hardenPhotoRealism(prompt, opts)` 分档 |
| `src/modules/ai/image-score.service.ts` | 分项 rubric + 三段闸门 + 无图放宽 |
| `src/modules/ai/ai-orchestrator.service.ts` | `styleProfile` 步骤、删除无图 break、评审/整改接线、定稿写入 |
| `src/modules/ai/draft-refine.service.ts` | 逐项整改口径 + 档案注入 |
| `docs/future-optimizations.md` | 登记 2 条后续优化 |

---

### Task 1: 风格档案预设 `style-profile.presets.ts`

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/style-profile.presets.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/style-profile.presets.spec.ts`

**Interfaces:**
- Consumes: 无（零依赖模块，**不得 import 本模块内其它文件**，避免与 `normalize.ts` 形成循环依赖）
- Produces:
  - `type StyleCategory = 'portrait' | 'landscape' | 'food' | 'street' | 'night' | 'macro' | 'still-life'`
  - `type StyleArchetype`（7 值）、`type RetouchLevel = 'none' | 'light' | 'polished'`
  - `interface StyleProfile { category; archetype; aestheticTarget; subjectStyling; expressionMood; poseLanguage; lightingSignature; compositionBias; paletteHint; retouchLevel; extraNotes }`
  - `interface StyleArchetypePreset extends Omit<StyleProfile, 'extraNotes'> { forbidden: string }`
  - `const STYLE_CATEGORIES / STYLE_ARCHETYPES / RETOUCH_LEVELS`（`as const` 数组）
  - `const STYLE_CATEGORY_LABELS / STYLE_ARCHETYPE_LABELS / RETOUCH_LEVEL_LABELS: Record<..., string>`
  - `const REALISM_BASELINE: string`
  - `const STYLE_ARCHETYPE_PRESETS: Record<StyleArchetype, StyleArchetypePreset>`
  - `function normalizeStyleProfile(raw: unknown, fallbackArchetype?: StyleArchetype): StyleProfile`
  - `function defaultStyleProfile(): StyleProfile`
  - `function styleProfileOfDraft(draft: unknown): StyleProfile | undefined`
  - `function renderStyleProfileBlock(profile: StyleProfile): string`

- [ ] **Step 1: Write the failing test**

```ts
// lumira-server/packages/backend/src/modules/ai/style-profile.presets.spec.ts
import {
  STYLE_ARCHETYPES,
  STYLE_ARCHETYPE_PRESETS,
  REALISM_BASELINE,
  normalizeStyleProfile,
  defaultStyleProfile,
  styleProfileOfDraft,
  renderStyleProfileBlock,
} from './style-profile.presets';

describe('style-profile.presets', () => {
  it('7 条档案齐全，且均带底线外的档案级禁忌', () => {
    expect(STYLE_ARCHETYPES).toHaveLength(7);
    for (const a of STYLE_ARCHETYPES) {
      const p = STYLE_ARCHETYPE_PRESETS[a];
      expect(p.archetype).toBe(a);
      expect(p.lightingSignature.length).toBeGreaterThan(0);
      expect(p.compositionBias.length).toBeGreaterThan(0);
      expect(p.poseLanguage.length).toBeGreaterThan(0);
      expect(p.forbidden.length).toBeGreaterThan(0);
    }
  });

  it('defaultStyleProfile 为 candid_lifestyle + portrait + none', () => {
    const d = defaultStyleProfile();
    expect(d.archetype).toBe('candid_lifestyle');
    expect(d.category).toBe('portrait');
    expect(d.retouchLevel).toBe('none');
  });

  it('normalizeStyleProfile：枚举越界兜底；合法时保留档案默认的 retouchLevel', () => {
    const bad = normalizeStyleProfile({ category: '动画', archetype: 'anime' });
    expect(bad.category).toBe('portrait');
    expect(bad.archetype).toBe('candid_lifestyle');
    expect(bad.retouchLevel).toBe('none');

    const ok = normalizeStyleProfile({ category: 'landscape', archetype: 'landscape_fine_art', aestheticTarget: '层峦叠嶂的空气感' });
    expect(ok.category).toBe('landscape');
    expect(ok.archetype).toBe('landscape_fine_art');
    expect(ok.retouchLevel).toBe('light'); // 档案默认
    expect(ok.aestheticTarget).toBe('层峦叠嶂的空气感');
    expect(ok.lightingSignature).toBe(STYLE_ARCHETYPE_PRESETS.landscape_fine_art.lightingSignature);
  });

  it('normalizeStyleProfile：非法 retouchLevel 取档案默认，不取 none', () => {
    const p = normalizeStyleProfile({ archetype: 'fashion_editorial', retouchLevel: 'ultra' });
    expect(p.retouchLevel).toBe('polished');
  });

  it('normalizeStyleProfile：extraNotes 不覆盖底线（底线只在渲染时单独注入，不写入 extraNotes）', () => {
    const p = normalizeStyleProfile({ archetype: 'fashion_editorial', extraNotes: '禁用真实肤色' });
    expect(p.extraNotes).toBe('禁用真实肤色');
    const block = renderStyleProfileBlock(p);
    expect(block).toContain(REALISM_BASELINE);
    expect(block.indexOf(REALISM_BASELINE)).toBeGreaterThan(block.indexOf('禁用真实肤色'));
  });

  it('styleProfileOfDraft：非对象/缺 archetype 返回 undefined；合法对象返回归一化档案', () => {
    expect(styleProfileOfDraft(null)).toBeUndefined();
    expect(styleProfileOfDraft({})).toBeUndefined();
    expect(styleProfileOfDraft({ styleProfile: { archetype: 123 } })).toBeUndefined();
    const p = styleProfileOfDraft({ styleProfile: { category: 'food', archetype: 'food_lifestyle' } });
    expect(p?.category).toBe('food');
  });

  it('renderStyleProfileBlock 含中文标签、精修档、现场补充与底线优先声明', () => {
    const block = renderStyleProfileBlock(defaultStyleProfile());
    expect(block).toContain('本次风格档案');
    expect(block).toContain('随拍松弛');
    expect(block).toContain('无精修');
    expect(block).toContain('底线');
    expect(block).toContain('优先级高于');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/style-profile.presets.spec.ts`
Expected: FAIL — `Cannot find module './style-profile.presets'`

- [ ] **Step 3: Write minimal implementation**

```ts
// lumira-server/packages/backend/src/modules/ai/style-profile.presets.ts
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
    poseLanguage: '',
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
    poseLanguage: '',
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/style-profile.presets.spec.ts`
Expected: PASS（7 个用例全绿）

- [ ] **Step 5: Commit & push**

```bash
git add lumira-server/packages/backend/src/modules/ai/style-profile.presets.ts lumira-server/packages/backend/src/modules/ai/style-profile.presets.spec.ts
git commit -m "feat(ai): 新增风格档案预设（StyleProfile 契约 + 7 条内置档案 + 真实底线）"
git push origin master
git push github master
```

---

### Task 2: 风格定位服务 `style-profile.service.ts`

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/style-profile.service.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/style-profile.service.spec.ts`

**Interfaces:**
- Consumes（Task 1）：`normalizeStyleProfile`、`defaultStyleProfile`、`renderStyleProfileBlock`、`StyleProfile`、`StyleArchetype`；`llm-client.ts` 的 `textChat`、`extractJson`（来自 `normalize.ts`）、`AiConfigService.getActiveConfig()` 返回的 `{ text: LlmEndpoint }`
- Produces:
  - `interface StyleProfileInput { text?: string; creationReq?: string; desc?: unknown }`
  - `interface StyleProfileResolveResult { profile: StyleProfile; source: 'llm' | 'fallback'; note: string }`
  - `class StyleProfileService { constructor(aiConfigService: AiConfigService); resolve(input: StyleProfileInput): Promise<StyleProfileResolveResult> }`

- [ ] **Step 1: Write the failing test**

```ts
// lumira-server/packages/backend/src/modules/ai/style-profile.service.spec.ts
import { StyleProfileService } from './style-profile.service';
import { textChat } from './llm-client';
import type { LlmEndpoint } from './llm-client';
import type { AiConfigService } from './ai-config.service';

jest.mock('./llm-client', () => ({ textChat: jest.fn() }));

const textChatMock = textChat as jest.MockedFunction<typeof textChat>;

const TEXT: LlmEndpoint = { provider: 'qwen', baseUrl: 'https://x.example/v1', apiKey: 'sk', model: 'qwen-plus' };

function buildService() {
  const aiConfigService = { getActiveConfig: async () => ({ text: TEXT }) } as unknown as AiConfigService;
  return new StyleProfileService(aiConfigService);
}

describe('StyleProfileService.resolve', () => {
  beforeEach(() => textChatMock.mockReset());

  it('正常解析：返回 llm 档案，含模型给出的穿搭与表情', async () => {
    textChatMock.mockResolvedValueOnce(
      JSON.stringify({
        category: 'portrait',
        archetype: 'fashion_editorial',
        aestheticTarget: '秋冬杂志大片',
        subjectStyling: '驼色大衣 + 硬挺皮革手套',
        expressionMood: '冷峻直视镜头',
        retouchLevel: 'polished',
        extraNotes: '背景留出大面积灰墙负空间',
      }),
    );
    const res = await buildService().resolve({ creationReq: '秋冬时尚大片人像' });

    expect(res.source).toBe('llm');
    expect(res.profile.archetype).toBe('fashion_editorial');
    expect(res.profile.retouchLevel).toBe('polished');
    expect(res.profile.subjectStyling).toBe('驼色大衣 + 硬挺皮革手套');
    expect(res.profile.compositionBias).toBe(STYLE_PRESET_BIAS); // 缺字段回填档案默认
    const [cfg, input] = textChatMock.mock.calls[0];
    expect(cfg).toEqual(TEXT);
    expect(input.jsonMode).toBe(true);
    expect(input.temperature).toBe(0.3);
    expect(input.timeoutMs).toBe(60_000);
    expect(String(input.userText)).toContain('秋冬时尚大片人像');
  });

  it('枚举越界 → 归一化兜底 candid_lifestyle + portrait', async () => {
    textChatMock.mockResolvedValueOnce(JSON.stringify({ category: 'anime', archetype: '二次元' }));
    const res = await buildService().resolve({ text: '随便' });
    expect(res.profile.archetype).toBe('candid_lifestyle');
    expect(res.profile.category).toBe('portrait');
    expect(res.profile.retouchLevel).toBe('none');
  });

  it('retouchLevel 非法 → 取档案默认（polished）', async () => {
    textChatMock.mockResolvedValueOnce(JSON.stringify({ archetype: 'photo_portrait', retouchLevel: 'ultra' }));
    const res = await buildService().resolve({ text: '写真' });
    expect(res.profile.retouchLevel).toBe('light');
  });

  it('调用失败 → 降级 fallback，不抛错，note 含原因', async () => {
    textChatMock.mockRejectedValueOnce(new Error('ECONNRESET'));
    const res = await buildService().resolve({ text: '夜景' });
    expect(res.source).toBe('fallback');
    expect(res.profile.archetype).toBe('candid_lifestyle');
    expect(res.note).toContain('ECONNRESET');
  });

  it('JSON 非法 → 降级 fallback，不抛错', async () => {
    textChatMock.mockResolvedValueOnce('我觉得这是一组很美的照片');
    const res = await buildService().resolve({ text: '海边' });
    expect(res.source).toBe('fallback');
    expect(res.note.length).toBeGreaterThan(0);
  });

  it('无输入 → 不调用模型，直接 fallback', async () => {
    const res = await buildService().resolve({});
    expect(textChatMock).not.toHaveBeenCalled();
    expect(res.source).toBe('fallback');
  });
});
```

> 测试中 `STYLE_PRESET_BIAS` 在文件顶部定义：
> `const STYLE_PRESET_BIAS = STYLE_ARCHETYPE_PRESETS.fashion_editorial.compositionBias;`
> （从 `./style-profile.presets` import）

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/style-profile.service.spec.ts`
Expected: FAIL — `Cannot find module './style-profile.service'`

- [ ] **Step 3: Write minimal implementation**

```ts
// lumira-server/packages/backend/src/modules/ai/style-profile.service.ts
// 风格定位：判定本次创作的大类与风格取向档案（只判定一次，供全链路分流使用）。

import { Injectable } from '@nestjs/common';
import { AiConfigService } from './ai-config.service';
import { textChat } from './llm-client';
import { extractJson } from './normalize';
import {
  defaultStyleProfile,
  normalizeStyleProfile,
  STYLE_ARCHETYPE_LABELS,
  type StyleProfile,
} from './style-profile.presets';

export interface StyleProfileInput {
  /** 用户文字描述（无参考图时的主输入） */
  text?: string;
  /** 创作要求（优先级高于 text） */
  creationReq?: string;
  /** 有参考图时的图像识别结果（可选，用于辅助风格判定） */
  desc?: unknown;
}

export interface StyleProfileResolveResult {
  profile: StyleProfile;
  source: 'llm' | 'fallback';
  /** 用于 trace 的一句话说明 */
  note: string;
}

const STYLE_RESOLVE_SYSTEM_PROMPT = `你是资深摄影/视觉总监，负责在创作开始前做一次「风格定位」。
你要判断本次创作属于哪个大类（category），以及应当采用哪一套风格取向档案（archetype）。

## category 取值（只能选一个）
portrait（人像）/ landscape（风景）/ food（美食）/ street（街拍）/ night（夜景）/ macro（微距）/ still-life（静物）

## archetype 取值（只能选一个）
fashion_editorial（时尚大片）/ photo_portrait（摄影写真）/ candid_lifestyle（随拍松弛）/
social_media_trendy（网感网红）/ documentary_street（纪实街拍）/ landscape_fine_art（风景意境）/ food_lifestyle（美食生活）

## retouchLevel 取值（只能选一个）
none（不做精修、自然随拍）/ light（轻精修、干净通透）/ polished（精致精修、大片调性）

## 判定原则
1. 以用户创作要求与文字描述为准；有图像识别结果时可参考其风格线索，但不得违背文字要求。
2. 不得为了「好看」而选择用户未要求的取向；用户没有明确取向时，选最贴近日常审美的一套。
3. 无论选哪一套，真实都是底线：不得输出反真实、反物理、反解剖的取向。

## 输出（严格 JSON，不要任何多余文字）
{
  "category": "portrait",
  "archetype": "fashion_editorial",
  "aestheticTarget": "一句话美学目标",
  "subjectStyling": "穿搭/妆造/材质/配饰要点（非人像可为空字符串）",
  "expressionMood": "表情与情绪（非人像可为空字符串）",
  "poseLanguage": "姿势语言（非人像可为空字符串）",
  "lightingSignature": "光比与光线特征",
  "compositionBias": "构图偏好",
  "paletteHint": "色调倾向",
  "retouchLevel": "polished",
  "extraNotes": "现场补充的个性细节，没有就空字符串"
}`;

@Injectable()
export class StyleProfileService {
  constructor(private readonly aiConfigService: AiConfigService) {}

  async resolve(input: StyleProfileInput): Promise<StyleProfileResolveResult> {
    const request = (input.creationReq || '').trim() || (input.text || '').trim();
    const descBrief = input.desc ? JSON.stringify(input.desc).slice(0, 1500) : '';
    if (!request && !descBrief) {
      return {
        profile: defaultStyleProfile(),
        source: 'fallback',
        note: 'fail: 无创作要求与文字描述，使用默认档案（随拍松弛/人像）',
      };
    }

    const userText = [
      `创作要求：${(input.creationReq || '').trim() || '（未填写）'}`,
      `文字描述：${(input.text || '').trim() || '（未填写）'}`,
      descBrief ? `参考图识别结果（节选）：${descBrief}` : '',
    ]
      .filter(Boolean)
      .join('\n');

    try {
      const cfg = await this.aiConfigService.getActiveConfig();
      if (!cfg?.text) {
        return {
          profile: defaultStyleProfile(),
          source: 'fallback',
          note: 'fail: 未配置文本模型，使用默认档案（随拍松弛/人像）',
        };
      }
      const raw = await textChat(cfg.text, {
        systemPrompt: STYLE_RESOLVE_SYSTEM_PROMPT,
        userText,
        temperature: 0.3,
        jsonMode: true,
        timeoutMs: 60_000,
      });
      const json = extractJson(raw);
      const profile = normalizeStyleProfile(json);
      return {
        profile,
        source: 'llm',
        note: `${STYLE_ARCHETYPE_LABELS[profile.archetype]}/${profile.category}/${profile.retouchLevel}`,
      };
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return {
        profile: defaultStyleProfile(),
        source: 'fallback',
        note: `fail: 风格定位失败（${msg.slice(0, 120)}），使用默认档案（随拍松弛/人像）`,
      };
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/style-profile.service.spec.ts`
Expected: PASS

- [ ] **Step 5: Commit & push**

```bash
git add lumira-server/packages/backend/src/modules/ai/style-profile.service.ts lumira-server/packages/backend/src/modules/ai/style-profile.service.spec.ts
git commit -m "feat(ai): 新增风格定位服务 StyleProfileService（失败降级不阻断链路）"
git push origin master
git push github master
```

---

### Task 3: `analyze.prompt.ts` 按大类分流 + 档案注入

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/analyze.prompt.ts`（全文契约改造）
- Test: `lumira-server/packages/backend/src/modules/ai/analyze.prompt.spec.ts`（追加用例）

**Interfaces:**
- Consumes（Task 1）：`StyleProfile`、`renderStyleProfileBlock`、`STYLE_CATEGORY_LABELS`
- Produces:
  - `function buildAnalyzeSystemPrompt(categories: CategoryNode[], styleProfile?: StyleProfile): string`
  - `function buildTextOnlySystemPrompt(categories: CategoryNode[], styleProfile?: StyleProfile): string`
  - `const PORTRAIT_POSE_REQUIREMENT: string` / `const NON_PORTRAIT_POSE_REQUIREMENT: string`
  - `function qualityRequirements(category: StyleProfile['category']): string`
  - `function isPortraitCategory(category: StyleProfile['category']): boolean`（`category === 'portrait'`）

- [ ] **Step 1: Write the failing test（追加到现有 spec 末尾，保留原有用例）**

```ts
// 追加到 lumira-server/packages/backend/src/modules/ai/analyze.prompt.spec.ts
import { buildAnalyzeSystemPrompt, buildTextOnlySystemPrompt } from './analyze.prompt';
import { STYLE_ARCHETYPE_PRESETS, type StyleProfile } from './style-profile.presets';

const PORTRAIT_PROFILE: StyleProfile = {
  category: 'portrait',
  archetype: 'fashion_editorial',
  aestheticTarget: '秋冬杂志大片',
  subjectStyling: '驼色大衣 + 皮革手套',
  expressionMood: '冷峻直视镜头',
  poseLanguage: '线条有张力',
  lightingSignature: '硬光高光比',
  compositionBias: '对角线构图',
  paletteHint: '高级灰',
  retouchLevel: 'polished',
  extraNotes: '灰墙负空间',
};

const LANDSCAPE_PROFILE: StyleProfile = {
  ...PORTRAIT_PROFILE,
  category: 'landscape',
  archetype: 'landscape_fine_art',
  aestheticTarget: '层峦空气感',
  subjectStyling: '',
  expressionMood: '',
  poseLanguage: '',
};

describe('analyze.prompt 风格档案分流', () => {
  it('注入档案：两种系统提示词都含档案段落与档案字段值', () => {
    const vision = buildAnalyzeSystemPrompt(CATS, PORTRAIT_PROFILE);
    const textOnly = buildTextOnlySystemPrompt(CATS, PORTRAIT_PROFILE);
    for (const p of [vision, textOnly]) {
      expect(p).toContain('本次风格档案');
      expect(p).toContain('时尚大片');
      expect(p).toContain('驼色大衣 + 皮革手套');
      expect(p).toContain('冷峻直视镜头');
      expect(p).toContain('对角线与框架式构图');
      expect(p).toContain('真实照片媒介');
    }
  });

  it('不传档案时不得出现档案段落（向后兼容）', () => {
    const p = buildAnalyzeSystemPrompt(CATS);
    expect(p).not.toContain('本次风格档案');
    expect(p).toContain('重心与支撑腿');
  });

  it('人像档案：要求含表情与穿搭，并含人类专属姿势术语', () => {
    const p = buildAnalyzeSystemPrompt(CATS, PORTRAIT_PROFILE);
    expect(p).toContain('表情');
    expect(p).toContain('穿搭');
    expect(p).toContain('重心与支撑腿');
    expect(p).toContain('手部落点');
  });

  it('非人像档案：不得出现「重心与支撑腿」「手部落点」，改为该大类术语', () => {
    const p = buildAnalyzeSystemPrompt(CATS, LANDSCAPE_PROFILE);
    expect(p).not.toContain('重心与支撑腿');
    expect(p).not.toContain('手部落点');
    expect(p).toContain('层次');
    expect(p).toContain('光时窗');
  });

  it('自拍第一人称契约仍保留（回归）', () => {
    const p = buildAnalyzeSystemPrompt(CATS, PORTRAIT_PROFILE);
    expect(p).toContain('第一人称');
    expect(p).toContain('一臂');
    expect(p).toContain('不出现手机');
  });
});
```

> `CATS` 沿用 spec 内既有分类树夹具；若既有 spec 用的是内联变量，请在追加用例前提取为文件级常量 `CATS`。

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/analyze.prompt.spec.ts`
Expected: FAIL — 新用例 `buildAnalyzeSystemPrompt` 第二参数不被支持 / 断言文案不存在

- [ ] **Step 3: Write minimal implementation**

改造规则（**必须先 `Read` 现有 `analyze.prompt.ts`，逐段替换**）：

1. 顶部新增 import：
```ts
import { renderStyleProfileBlock, STYLE_CATEGORY_LABELS, type StyleProfile } from './style-profile.presets';
```

2. 新增档案段落拼接辅助：
```ts
/** 档案段落（无档案时返回空串，保证向后兼容） */
function styleProfileBlock(styleProfile?: StyleProfile): string {
  if (!styleProfile) return '';
  return `\n\n${renderStyleProfileBlock(styleProfile)}\n\n以上档案是本模板的美学基准，所有字段（meta / camera / pose / sceneGuide / composition / postProcess）都必须与它一致。\n`;
}
```

3. 新增**按大类分流**的质量要求：
```ts
export const PORTRAIT_POSE_REQUIREMENT =
  '姿势要有设计感的线条：避免正面僵直、双手对称、关节正对镜头、手臂紧贴身体。每个姿势必须写清「重心与支撑腿」「肩胯错位」「手部分落点（左右手分别写明动作与落点）」「视线方向」「表情（眼神强度与方向、嘴角、下颌与颈部线的松紧）」「穿搭（颜色、材质、廓形、配饰与褶皱状态，与风格档案的穿搭要求一致）」。';

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

/** 按大类分流的「创作质量要求」第 1/2/4 条 */
export function qualityRequirements(category: StyleProfile['category']): string {
  const pose = isPortraitCategory(category) ? PORTRAIT_POSE_REQUIREMENT : NON_PORTRAIT_POSE_REQUIREMENT;
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
```

4. `buildSystemPromptBody(categories, styleProfile?)`：
   - 身份句改为：`你是资深摄影/视觉模板编辑（按风格档案作业），为人像/风景/美食/街拍/夜景/微距/静物等题材产出可直接生图的模板草稿。`
   - 「创作质量要求」4 条整段替换为 `qualityRequirements(styleProfile?.category ?? 'portrait')`
   - 末尾（硬约束之后）追加 `styleProfileBlock(styleProfile)`

5. `buildAnalyzeSystemPrompt(categories, styleProfile?)` / `buildTextOnlySystemPrompt(categories, styleProfile?)` 均加第 2 可选参数并透传给 `buildSystemPromptBody`。

6. **保留**现有自拍第一人称规则段落原文（含 `第一人称` / `一臂` / `不出现手机` 三个子串），避免回归失败。

- [ ] **Step 4: Run test to verify it passes**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/analyze.prompt.spec.ts`
Expected: PASS（原有 + 新增用例全绿）

- [ ] **Step 5: Commit & push**

```bash
git add lumira-server/packages/backend/src/modules/ai/analyze.prompt.ts lumira-server/packages/backend/src/modules/ai/analyze.prompt.spec.ts
git commit -m "feat(ai): 草稿提示词按风格档案与大类分流（构图/参数/姿势线条/穿搭/表情）"
git push origin master
git push github master
```

---

### Task 4: 接线 —— `normalize.ts` / `ai.module.ts` / `ai-analyze.service.ts`

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/normalize.ts`（放行顶层 `styleProfile`）
- Modify: `lumira-server/packages/backend/src/modules/ai/ai.module.ts`（注册 provider）
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-analyze.service.ts`（第 5 可选参数 + 3.5 步）
- Test: `lumira-server/packages/backend/src/modules/ai/ai-analyze.service.spec.ts`（追加用例）

**Interfaces:**
- Consumes（Task 1/2）：`StyleProfileService`、`StyleProfileResolveResult`、`normalizeStyleProfile`、`renderStyleProfileBlock`
- Produces：`AiAnalyzeService` 构造器第 5 可选参数 `styleProfileService?: StyleProfileService`；`orchestrator.run(input, opts)` 的 `opts` 新增 `styleProfile?: StyleProfileResolveResult`（Task 11 消费）

- [ ] **Step 1: Write the failing test（追加到 `ai-analyze.service.spec.ts` 末尾）**

```ts
// 追加：mock styleProfileService 为可选第 5 参
it('注入 styleProfileService：档案段落进入系统提示词，且透传给 orchestrator', async () => {
  textChatMock.mockResolvedValueOnce(RAW_DRAFT);
  const styleProfileService = {
    resolve: jest.fn().mockResolvedValue({
      profile: {
        category: 'portrait', archetype: 'fashion_editorial', aestheticTarget: '杂志大片',
        subjectStyling: '驼色大衣', expressionMood: '冷峻', poseLanguage: '张力',
        lightingSignature: '硬光', compositionBias: '对角线', paletteHint: '高级灰',
        retouchLevel: 'polished', extraNotes: '灰墙',
      },
      source: 'llm',
      note: '时尚大片/portrait/polished',
    }),
  };
  const orchestrator = { run: jest.fn().mockResolvedValue({ draft: RAW_DRAFT, trace: [], warnings: [], research: [] }) };
  const svc = new AiAnalyzeService(dbService, aiConfigService, trendResearch, orchestrator as never, styleProfileService as never);

  await svc.analyze({ text: '秋冬时尚大片人像', poseCount: 1 } as never);

  expect(styleProfileService.resolve).toHaveBeenCalledTimes(1);
  const systemPrompt = String(textChatMock.mock.calls[0][1].systemPrompt);
  expect(systemPrompt).toContain('本次风格档案');
  expect(systemPrompt).toContain('驼色大衣');
  expect(orchestrator.run).toHaveBeenCalledWith(
    expect.anything(),
    expect.objectContaining({ styleProfile: expect.objectContaining({ source: 'llm' }) }),
  );
});

it('未注入 styleProfileService 时链路不报错（向后兼容）', async () => {
  textChatMock.mockResolvedValueOnce(RAW_DRAFT);
  const svc = new AiAnalyzeService(dbService, aiConfigService, trendResearch);
  await expect(svc.analyze({ text: '奶油风人像', poseCount: 1 } as never)).resolves.toBeDefined();
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/ai-analyze.service.spec.ts`
Expected: FAIL — 构造器不接受第 5 参数 / 系统提示词不含档案段落

- [ ] **Step 3: Write minimal implementation**

**3a. `normalize.ts`** — 在末尾 `if (isPlainObject(src.poseRefSheet)) draft.poseRefSheet = src.poseRefSheet;` 之后追加：

```ts
  // 风格档案：形状校验（必须有合法 archetype 字符串），非法时丢弃
  if (isPlainObject(src.styleProfile) && typeof (src.styleProfile as Record<string, unknown>).archetype === 'string') {
    draft.styleProfile = { ...(src.styleProfile as Record<string, unknown>) };
  }
```

**3b. `ai.module.ts`** — `providers` 数组新增 `StyleProfileService`，并在文件顶部 import。

**3c. `ai-analyze.service.ts`**：

1. import：`import { StyleProfileService, type StyleProfileResolveResult } from './style-profile.service';`
2. 构造器追加第 5 可选参数（放在 `orchestrator?` 之后）：
```ts
    @Optional() private readonly styleProfileService?: StyleProfileService,
```
3. 在「(3.5) research」之前插入风格定位，产出 `styleResolve`：
```ts
    // (3.5) 风格定位：只判定一次，供草稿生成 / 编排 / 评审 / 生图分流
    let styleResolve: StyleProfileResolveResult | undefined;
    if (this.styleProfileService) {
      styleResolve = await this.styleProfileService.resolve({
        text: input.text,
        creationReq: input.creationReq,
      });
      this.logger?.log?.(`风格定位：${styleResolve.note}`);
    }
    const styleProfile = styleResolve?.profile;
```
4. 草稿生成两处调用改为传档案：
   - 有图：`buildAnalyzeSystemPrompt(categories, styleProfile)`
   - 无图：`buildTextOnlySystemPrompt(categories, styleProfile)`
5. orchestrator 调用处改为：
```ts
      result = await this.orchestrator.run(input, { categories, draft: json, research, styleProfile: styleResolve });
```
   （若 `styleResolve` 为 `undefined`，`opts.styleProfile` 即为 undefined，Task 11 会自行兜底）
6. 单次路径（无 orchestrator）时，若 `styleResolve` 存在则把档案写入草稿：`json.styleProfile = styleResolve.profile;`（放在 `normalizeDraft` 之前或之后均可，`normalize.ts` 已放行）

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
pnpm --filter @lumira/backend exec jest src/modules/ai/ai-analyze.service.spec.ts src/modules/ai/normalize.spec.ts src/modules/ai/analyze.prompt.spec.ts
pnpm --filter @lumira/backend exec tsc -p tsconfig.build.json --noEmit
```
Expected: PASS + 无类型错误

- [ ] **Step 5: Commit & push**

```bash
git add lumira-server/packages/backend/src/modules/ai/normalize.ts lumira-server/packages/backend/src/modules/ai/ai.module.ts lumira-server/packages/backend/src/modules/ai/ai-analyze.service.ts lumira-server/packages/backend/src/modules/ai/ai-analyze.service.spec.ts
git commit -m "feat(ai): 风格定位接入草稿生成链路并放行 styleProfile 归一化"
git push origin master
git push github master
```

---

### Task 5: `image-describe` 补充表情/穿搭/风格线索

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/image-describe.prompt.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/image-describe.service.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/image-describe.service.spec.ts`（追加用例）

**Interfaces:**
- Consumes：无
- Produces：`ImageGlobal.styleRead?: string`；`Person.expression?: string`；`Person.styling?: string`（**全部可选**，缺失时下游按空串处理）

- [ ] **Step 1: Write the failing test（追加）**

```ts
it('新契约：people[].expression/styling 与 global.styleRead 可解析，缺失时不崩', async () => {
  visionChatMock.mockResolvedValueOnce(
    JSON.stringify({
      ...LEGAL_DESC,
      global: { ...LEGAL_DESC.global, styleRead: '小红书网感、轻精修' },
      people: [{ ...LEGAL_DESC.people[0], expression: '嘴角微松、眼神看侧前方', styling: '米色针织开衫 + 细金链' }],
    }),
  );
  const desc = await buildService().describe({ base64: 'aGk=', mime: 'image/jpeg' });
  expect(desc.global.styleRead).toBe('小红书网感、轻精修');
  expect(desc.people[0].expression).toBe('嘴角微松、眼神看侧前方');
  expect(desc.people[0].styling).toBe('米色针织开衫 + 细金链');
});

it('新契约缺失：styleRead 非字符串 → 空串兜底，不抛错', async () => {
  visionChatMock.mockResolvedValueOnce(JSON.stringify(LEGAL_DESC));
  const desc = await buildService().describe({ base64: 'aGk=', mime: 'image/png' });
  expect(typeof desc.global.styleRead).toBe('string');
  expect(typeof desc.people[0].expression).toBe('string');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/image-describe.service.spec.ts`
Expected: FAIL — `desc.global.styleRead` 为 `undefined`

- [ ] **Step 3: Write minimal implementation**

**3a. `image-describe.prompt.ts`** — 在系统提示词的字段清单中补三条要求（追加到 `people[]` 与 `global` 的字段说明里）：

```ts
// people[] 字段说明追加：
'- expression：该人物的表情与眼神（眼睑开合、视线方向、嘴角状态、下颌与颈部松紧），看不清写 unknown',
'- styling：该人物的妆造与穿搭质感（颜色、材质、廓形、配饰、褶皱状态），看不清写 unknown',
// global 字段说明追加：
'- styleRead：从图中读到的整体风格取向（如「时尚大片」「小红书网感」「随拍松弛」「纪实街拍」「风景意境」「美食生活」）与精修程度（如「无精修/轻精修/精致精修」），读不出写 unknown',
```

**3b. `image-describe.service.ts`** — 在 `ImageGlobal` / `Person` 接口中新增可选字段，并在 `normalizeImageDescription` 中兜底：

```ts
// ImageGlobal 接口内追加（可选）
  styleRead?: string;
// Person 接口内追加（可选）
  expression?: string;
  styling?: string;
```
```ts
// normalizeImageDescription 内：
//   global 归一化处补 styleRead: str(g.styleRead)
//   people.map 内补 expression: str(p.expression), styling: str(p.styling)
```

> `str()` 为现有本地兜底函数（非字符串返回 `'unknown'`），直接复用即可。

- [ ] **Step 4: Run test to verify it passes**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/image-describe.service.spec.ts`
Expected: PASS

- [ ] **Step 5: Commit & push**

```bash
git add lumira-server/packages/backend/src/modules/ai/image-describe.prompt.ts lumira-server/packages/backend/src/modules/ai/image-describe.service.ts lumira-server/packages/backend/src/modules/ai/image-describe.service.spec.ts
git commit -m "feat(ai): 图像识别补充表情、穿搭与风格线索字段"
git push origin master
git push github master
```

---

### Task 6: `pose-ref-sheet.service.ts` 姿势面片字段级契约

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/pose-ref-sheet.service.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/pose-ref-sheet.service.spec.ts`（追加用例）

**Interfaces:**
- Consumes（Task 1）：`StyleProfile`、`renderStyleProfileBlock`
- Produces:
  - `interface SubjectPose { headFraming: string; torsoTwist: string; shoulderHipOffset: string; armAndHand: string; legStance: string; expression: string }`
  - `interface PosePerPose { name: string; differentiationNote: string; subjectPose?: Partial<SubjectPose> }`
  - `const SUBJECT_POSE_KEYS: (keyof SubjectPose)[]`
  - `const SHARED_KEYS` 扩为 8 项（原 6 项 + `styling`、`expressionMood`）
  - `function normalizeSubjectPose(raw: unknown): Partial<SubjectPose>`
  - `generate(desc: unknown, poseCount: number, userReq?: string, styleProfile?: StyleProfile): Promise<PoseRefSheet>`

- [ ] **Step 1: Write the failing test（追加）**

```ts
it('subjectPose 字段级契约：缺失键被补齐为指定默认值', async () => {
  textChatMock.mockResolvedValueOnce(
    JSON.stringify({
      shared: { outfit: '米色针织', scene: '飘窗', light: '窗光', aspectRatio: '3:4', mood: '清冷', palette: '暖棕', styling: '针织开衫 + 细金链', expressionMood: '平静微松' },
      perPose: [{ name: '坐姿侧靠', differentiationNote: '侧靠偏左', subjectPose: { headFraming: '下巴略收、视窗外', armAndHand: '左手扶窗台、右手搭膝' } }],
    }),
  );
  const sheet = await svc.generate({}, 1, '秋冬清冷感人像');

  expect(sheet.shared.styling).toBe('针织开衫 + 细金链');
  expect(sheet.shared.expressionMood).toBe('平静微松');
  const sp = sheet.perPose[0].subjectPose as Record<string, string>;
  expect(sp.headFraming).toBe('下巴略收、视窗外');
  expect(sp.armAndHand).toBe('左手扶窗台、右手搭膝');
  // 缺失键补齐默认
  expect(typeof sp.torsoTwist).toBe('string');
  expect(sp.torsoTwist.length).toBeGreaterThan(0);
  expect(sp.legStance.length).toBeGreaterThan(0);
  expect(sp.expression.length).toBeGreaterThan(0);
  // 每张姿势都必须有 subjectPose
  expect(sheet.perPose[0].subjectPose).toBeDefined();
});

it('注入 styleProfile：系统提示词含档案段落与姿势线条要求', async () => {
  textChatMock.mockResolvedValueOnce(JSON.stringify({ shared: {}, perPose: [{ name: 'A', differentiationNote: 'x' }] }));
  await svc.generate({}, 1, '时尚大片', PROFILE);

  const systemPrompt = String(textChatMock.mock.calls[0][1].systemPrompt);
  expect(systemPrompt).toContain('本次风格档案');
  expect(systemPrompt).toContain('时尚大片');
  expect(systemPrompt).toContain('双手对称');
  expect(systemPrompt).toContain('关节正对镜头');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/pose-ref-sheet.service.spec.ts`
Expected: FAIL — `sheet.shared.styling` 为 undefined / `subjectPose` 缺键

- [ ] **Step 3: Write minimal implementation**

1. 顶部 import：`import { renderStyleProfileBlock, type StyleProfile } from './style-profile.presets';`

2. 新增契约与默认值：
```ts
export interface SubjectPose {
  /** 下巴高低与视线方向 */
  headFraming: string;
  /** 躯干朝向与转动角度 */
  torsoTwist: string;
  /** 肩胯错位 */
  shoulderHipOffset: string;
  /** 左右手分别的动作与落点 */
  armAndHand: string;
  /** 重心与支撑腿 */
  legStance: string;
  /** 本张表情 */
  expression: string;
}

export const SUBJECT_POSE_KEYS: (keyof SubjectPose)[] = [
  'headFraming',
  'torsoTwist',
  'shoulderHipOffset',
  'armAndHand',
  'legStance',
  'expression',
];

const SUBJECT_POSE_FALLBACK: SubjectPose = {
  headFraming: '下巴略收，视线看向侧前方，颈部线舒展',
  torsoTwist: '躯干侧转约 1/4 朝向镜头',
  shoulderHipOffset: '肩线与胯线错开，靠近镜头一侧肩略低',
  armAndHand: '左手自然下垂或轻搭身侧，右手抬起有明确落点',
  legStance: '重心落在后侧腿，前腿放松伸出',
  expression: '表情放松自然，嘴角微松，眼神有明确落点',
};

/** 归一化单张姿势：缺失键补齐默认值 */
export function normalizeSubjectPose(raw: unknown): Partial<SubjectPose> {
  const isObj = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);
  const src = isObj(raw) ? raw : {};
  const out: Partial<SubjectPose> = {};
  for (const key of SUBJECT_POSE_KEYS) {
    const v = src[key];
    out[key] = typeof v === 'string' && v.trim() ? v.trim() : SUBJECT_POSE_FALLBACK[key];
  }
  return out;
}
```

3. `PosePerPose` 的 `subjectPose` 类型改为 `Partial<SubjectPose>`；`SHARED_KEYS` 扩为：
```ts
const SHARED_KEYS = ['outfit', 'scene', 'light', 'aspectRatio', 'mood', 'palette', 'styling', 'expressionMood'] as const;
```

4. `normalizePoseRefSheet`：`perPose.map` 中对每张姿势设 `subjectPose: normalizeSubjectPose(p.subjectPose)`（**无论原值有无都必须设值**）。

5. `generate()` 签名追加第 4 可选参数 `styleProfile?: StyleProfile`；内联 systemPrompt 中：
   - 追加 `renderStyleProfileBlock(styleProfile)`（有档案时）
   - 追加要求段落：
```ts
'姿势必须"有设计感的线条"：避免正面僵直、双手对称、关节正对镜头、手臂紧贴身体。' +
'每个姿势的 subjectPose 必须逐项写全 headFraming（下巴高低/视线方向）、torsoTwist（躯干朝向与转动角度）、' +
'shoulderHipOffset（肩胯错位）、armAndHand（左右手分别的动作与落点）、legStance（重心与支撑腿）、expression（本张表情）。' +
'shared 中的 styling 与 expressionMood 用于保证跨姿势一致。'
```
   - 输出 JSON 示例中 `subjectPose` 展示全部 6 个键。
   - `timeoutMs` 维持 `120_000`。

- [ ] **Step 4: Run test to verify it passes**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/pose-ref-sheet.service.spec.ts src/modules/ai/ai-orchestrator.service.spec.ts`
Expected: PASS（orchestrator spec 中 `POSE_SHEET` 缺新字段仍可编译通过，因为全部可选）

- [ ] **Step 5: Commit & push**

```bash
git add lumira-server/packages/backend/src/modules/ai/pose-ref-sheet.service.ts lumira-server/packages/backend/src/modules/ai/pose-ref-sheet.service.spec.ts
git commit -m "feat(ai): 姿势面片升级为字段级契约并注入风格档案"
git push origin master
git push github master
```

---

### Task 7: `image-prompt.composer.ts` 允许补审美 + 档案素材段

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/image-prompt.composer.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/image-prompt.composer.spec.ts`（追加用例）

**Interfaces:**
- Consumes（Task 1）：`styleProfileOfDraft`、`renderStyleProfileBlock`、`StyleProfile`、`RETOUCH_LEVEL_LABELS`、`STYLE_ARCHETYPE_LABELS`
- Produces：`PromptComposeInput.styleProfile?: StyleProfile`（缺省时从 `draft.styleProfile` 兜底读取）

- [ ] **Step 1: Write the failing test（追加）**

```ts
it('规则 9 新表述：允许在档案范围内补足审美细节，并禁止档案外风格', async () => {
  const prompt = buildComposeSystemPrompt();
  expect(prompt).toContain('档案允许范围内补足审美细节');
  expect(prompt).not.toContain('不新增素材没有的元素');
});

it('素材下发【风格档案】段落（archetype 中文名 / 穿搭 / 表情 / 姿势语言 / 光线 / 构图 / 色调 / 精修档）', async () => {
  textChatMock.mockResolvedValueOnce('最终提示词');
  await composeImagePrompt(TEXT, { draft: { styleProfile: PROFILE } }, '兜底');

  const material = String(textChatMock.mock.calls[0][1].userText);
  expect(material).toContain('【风格档案】');
  expect(material).toContain('时尚大片');
  expect(material).toContain('驼色大衣 + 皮革手套');
  expect(material).toContain('冷峻直视镜头');
  expect(material).toContain('精致精修');
});

it('无档案时不出现【风格档案】段落', async () => {
  textChatMock.mockResolvedValueOnce('最终提示词');
  await composeImagePrompt(TEXT, { draft: {} }, '兜底');
  expect(String(textChatMock.mock.calls[0][1].userText)).not.toContain('【风格档案】');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/image-prompt.composer.spec.ts`
Expected: FAIL — 新表述不存在 / 素材缺档案段

- [ ] **Step 3: Write minimal implementation**

1. 顶部 import：`import { styleProfileOfDraft, STYLE_ARCHETYPE_LABELS, RETOUCH_LEVEL_LABELS, type StyleProfile } from './style-profile.presets';`

2. `PromptComposeInput` 增加 `styleProfile?: StyleProfile;`

3. **规则 9 整行替换**（原为「只使用素材中出现的信息组织画面，不新增素材没有的元素；」）：
```ts
  9. 可在【风格档案】允许范围内补足审美细节（表情、穿搭与褶皱、肢体线条、光线层次、前景层次、色调统一），使画面更好看；
     但不得引入与档案冲突的风格取向（例如档案为随拍松弛时不得写成影棚布光大‌片），也不得新增现实中拍不出来的元素；
```

4. **规则 4a / 4d 改写**：删除「一张真实相机直出的生活照（不是精修写真，也不是插画）」与「网红精修写真或影楼布光大片」这类**把写真/大片当贬义**的表述，改为按 `retouchLevel` 表述：
```ts
  4a. 媒介真实：输出的是真实照片（不是插画、动漫、CG、3D 渲染），皮肤、布料、道具均为真实材质纹理。
  4d. 精修档与档案一致：none → 不过度修饰、保留环境真实感；light → 干净通透、光比克制、皮肤保留毛孔与绒毛；polished → 布光与质感考究、调色讲究，但材质仍真实。
```

5. **`buildPromptMaterial` 新增 ⑥ 之前插入【风格档案】段落**（`styleProfile` 由 `input.styleProfile ?? styleProfileOfDraft(input.draft)` 取得）：
```ts
  if (profile) {
    lines.push(
      `【风格档案】取向：${STYLE_ARCHETYPE_LABELS[profile.archetype]}｜精修档：${RETOUCH_LEVEL_LABELS[profile.retouchLevel]}`,
      `【风格档案】美学目标：${profile.aestheticTarget}`,
      profile.subjectStyling ? `【风格档案】穿搭/妆造：${profile.subjectStyling}` : '',
      profile.expressionMood ? `【风格档案】表情与情绪：${profile.expressionMood}` : '',
      profile.poseLanguage ? `【风格档案】姿势语言：${profile.poseLanguage}` : '',
      `【风格档案】光线：${profile.lightingSignature}`,
      `【风格档案】构图偏好：${profile.compositionBias}`,
      `【风格档案】色调：${profile.paletteHint}`,
      profile.extraNotes ? `【风格档案】现场补充：${profile.extraNotes}` : '',
    );
  }
```
> 空串项由既有 `lines.filter(Boolean)` 过滤，无需额外处理。

6. ⑥ 段中原有的「随手抓拍的生活照…影楼写真或精修广告片」与「禁止：磨皮…影棚式布光」两句**改写**为分档表述，且**不得**再出现子串 `影楼写真` / `网红精修风`：
```ts
  '⑥ 质感与真实底线：按【风格档案】的精修档控制修饰程度（none/light/polished 三档），' +
  '但皮肤毛孔与绒毛、布料纹理、道具材质、环境光衰减与阴影过渡必须真实；' +
  '禁止：动漫、二次元、漫画、插画、CG、3D 渲染；禁止无源光、不可能透视与姿势、肢体与面部畸变。',
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/image-prompt.composer.spec.ts src/modules/ai/ai-generate-image.service.spec.ts`
Expected: PASS

- [ ] **Step 5: Commit & push**

```bash
git add lumira-server/packages/backend/src/modules/ai/image-prompt.composer.ts lumira-server/packages/backend/src/modules/ai/image-prompt.composer.spec.ts
git commit -m "feat(ai): 提示词组装允许按风格档案补足审美细节"
git push origin master
git push github master
```

---

### Task 8: `image-prompt.builder.ts` 机械兜底按精修档分档

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/image-prompt.builder.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/image-prompt.builder.spec.ts`（追加用例）

**Interfaces:**
- Consumes（Task 1）：`styleProfileOfDraft`、`STYLE_ARCHETYPE_LABELS`、`RETOUCH_LEVELS`、`RetouchLevel`
- Produces:
  - `const RETOUCH_TEXTURE_LINES: Record<RetouchLevel, string>`
  - `function retouchLevelOfDraft(draft: unknown): RetouchLevel`
  - `buildImagePrompt(draft, extraPrompt?)` 签名不变

- [ ] **Step 1: Write the failing test（追加）**

```ts
it('三种 retouchLevel 产出不同质感结尾句，且均不含「轻微噪点」', () => {
  const none = buildImagePrompt({ styleProfile: { archetype: 'candid_lifestyle', retouchLevel: 'none' } });
  const light = buildImagePrompt({ styleProfile: { archetype: 'photo_portrait', retouchLevel: 'light' } });
  const polished = buildImagePrompt({ styleProfile: { archetype: 'fashion_editorial', retouchLevel: 'polished' } });

  expect(none).toContain(RETOUCH_TEXTURE_LINES.none);
  expect(light).toContain(RETOUCH_TEXTURE_LINES.light);
  expect(polished).toContain(RETOUCH_TEXTURE_LINES.polished);
  expect(light).not.toContain(RETOUCH_TEXTURE_LINES.none);
  for (const p of [none, light, polished]) {
    expect(p).not.toContain('轻微噪点');
    expect(p).not.toContain('禁止影楼写真');
    expect(p).not.toContain('网红精修风');
  }
});

it('无档案时回落 none 档结尾句', () => {
  const p = buildImagePrompt({});
  expect(p).toContain(RETOUCH_TEXTURE_LINES.none);
});

it('有档案时补入审美短语（穿搭 / 表情 / 姿势语言）', () => {
  const p = buildImagePrompt({ styleProfile: { archetype: 'fashion_editorial', subjectStyling: '驼色大衣', expressionMood: '冷峻直视', poseLanguage: '线条有张力' } });
  expect(p).toContain('驼色大衣');
  expect(p).toContain('冷峻直视');
  expect(p).toContain('线条有张力');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/image-prompt.builder.spec.ts`
Expected: FAIL — `RETOUCH_TEXTURE_LINES` 未导出

- [ ] **Step 3: Write minimal implementation**

1. 顶部 import：`import { styleProfileOfDraft, STYLE_ARCHETYPE_LABELS, RETOUCH_LEVELS, type RetouchLevel, type StyleProfile } from './style-profile.presets';`

2. 新增分档质感文案：
```ts
/** 三档真实质感结尾句（替代原写死的「画面带自然噪点与轻微白平衡偏移」） */
export const RETOUCH_TEXTURE_LINES: Record<RetouchLevel, string> = {
  none: '质感：自然环境光与生活化瞬间感，保留真实的环境明暗与轻微白平衡偏移，不做修饰性调色。',
  light: '质感：干净通透，光比克制，皮肤保留真实毛孔与绒毛（不磨皮），布料保留真实纹理与褶皱。',
  polished: '质感：布光精致考究、调色讲究、明暗层次分明，但皮肤、布料与道具仍为真实材质纹理。',
};

export function retouchLevelOfDraft(draft: unknown): RetouchLevel {
  const p: StyleProfile | undefined = styleProfileOfDraft(draft);
  const level = p?.retouchLevel;
  return level && (RETOUCH_LEVELS as readonly string[]).includes(level) ? level : 'none';
}
```

3. 将 ①~⑨ 段中原**写死**的 L226「画面像随手抓拍的实拍照片」与 L228「画面带自然噪点与轻微白平衡偏移」两句**删除**，改为在结尾追加 `RETOUCH_TEXTURE_LINES[retouchLevelOfDraft(draft)]`。

4. 在段列表中追加档案审美短语（有档案时）：
```ts
  const profile = styleProfileOfDraft(draft);
  ... // 已有段落变量之后
  profile ? `风格取向：${STYLE_ARCHETYPE_LABELS[profile.archetype]}。` : '',
  profile?.subjectStyling ? `穿搭/妆造：${profile.subjectStyling}。` : '',
  profile?.expressionMood ? `表情与情绪：${profile.expressionMood}。` : '',
  profile?.poseLanguage ? `姿势语言：${profile.poseLanguage}。` : '',
  profile?.lightingSignature ? `光线特征：${profile.lightingSignature}。` : '',
  profile?.compositionBias ? `构图偏好：${profile.compositionBias}。` : '',
  profile?.paletteHint ? `色调倾向：${profile.paletteHint}。` : '',
```

5. `isSelfieDraft` 导出保持不变。

- [ ] **Step 4: Run test to verify it passes**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/image-prompt.builder.spec.ts`
Expected: PASS（原有断言中若依赖「轻微噪点」须同步删除该断言）

- [ ] **Step 5: Commit & push**

```bash
git add lumira-server/packages/backend/src/modules/ai/image-prompt.builder.ts lumira-server/packages/backend/src/modules/ai/image-prompt.builder.spec.ts
git commit -m "feat(ai): 机械兜底提示词按精修档分档并补入档案审美短语"
git push origin master
git push github master
```

---

### Task 9: `hardenPhotoRealism` 出口加固分档

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.spec.ts`（改 1 处 + 追加）

**Interfaces:**
- Consumes（Task 1/8）：`RetouchLevel`、`retouchLevelOfDraft`
- Produces:
  - `interface HardenOptions { selfie?: boolean; retouchLevel?: RetouchLevel }`
  - `const PHOTO_REALISM_BASELINE_SUFFIX: string`
  - `const RETOUCH_REALISM_SUFFIX: Record<RetouchLevel, string>`
  - `function hardenPhotoRealism(prompt: string, opts?: HardenOptions): string`

- [ ] **Step 1: 修改既有断言 + 追加新用例**

把手写参数调用改为对象（L207）：
```ts
// 原：hardenPhotoRealism('提示词', true)
const out = hardenPhotoRealism('提示词', { selfie: true });
```
追加：
```ts
it('分档加固：三档结尾句不同；确定性不含「轻微噪点」「禁止影楼写真」「网红精修风」', () => {
  const none = hardenPhotoRealism('P', { retouchLevel: 'none' });
  const light = hardenPhotoRealism('P', { retouchLevel: 'light' });
  const polished = hardenPhotoRealism('P', { retouchLevel: 'polished' });

  expect(none).toContain(RETOUCH_REALISM_SUFFIX.none);
  expect(light).toContain(RETOUCH_REALISM_SUFFIX.light);
  expect(polished).toContain(RETOUCH_REALISM_SUFFIX.polished);
  for (const p of [none, light, polished]) {
    expect(p).not.toContain('轻微噪点');
    expect(p).not.toContain('禁止影楼写真');
    expect(p).not.toContain('网红精修风');
    expect(p).toContain('禁止：动漫、二次元、漫画、插画');
    expect(p).toContain(PHOTO_REALISM_BASELINE_SUFFIX);
  }
});

it('不传 opts：默认 none 档，且与旧调用兼容（返回包含原 prompt）', () => {
  const out = hardenPhotoRealism('原提示词');
  expect(out).toContain('原提示词');
  expect(out).toContain(RETOUCH_REALISM_SUFFIX.none);
});

it('generate()：从 draft.styleProfile 读取 retouchLevel 传给加固', async () => {
  textChatMock.mockResolvedValueOnce('润色后的提示词');
  generateImageMock.mockResolvedValueOnce({ b64: 'x', mime: 'image/png' });
  const svc = buildService();
  await svc.generate({ draft: { styleProfile: { archetype: 'fashion_editorial', retouchLevel: 'polished' } } } as never);
  const arg = String(generateImageMock.mock.calls[0][0].prompt);
  expect(arg).toContain(RETOUCH_REALISM_SUFFIX.polished);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/ai-generate-image.service.spec.ts`
Expected: FAIL — `RETOUCH_REALISM_SUFFIX` 未导出 / 仍含「轻微噪点」

- [ ] **Step 3: Write minimal implementation**

1. 顶部 import：`import { retouchLevelOfDraft } from './image-prompt.builder';` 与 `import { type RetouchLevel } from './style-profile.presets';`

2. 新增常量与签名：
```ts
export interface HardenOptions {
  selfie?: boolean;
  retouchLevel?: RetouchLevel;
}

/** 恒定保留的真实底线（与风格档案无关） */
export const PHOTO_REALISM_BASELINE_SUFFIX =
  '真实照片媒介，不是动漫、二次元、漫画、插画、赛璐璐、厚涂、CG、3D 渲染、油画或游戏立绘；' +
  '真实人体结构与解剖，无肢体、手指与面部畸变；可实拍复现，无无源光、无不可能透视与姿势；' +
  '真实材质，皮肤有毛孔与绒毛、布料有纹理、环境光有衰减与阴影过渡。' +
  '禁止：动漫、二次元、漫画、插画；禁止无源光与不可能透视；禁止肢体与面部畸变。';

/** 按精修档追加的质感句 */
export const RETOUCH_REALISM_SUFFIX: Record<RetouchLevel, string> = {
  none: '自然环境光与生活化瞬间感，保留真实的环境明暗关系。',
  light: '干净通透，光比克制，皮肤保留真实毛孔与绒毛，不磨皮。',
  polished: '布光精致考究、调色讲究、明暗层次分明，但皮肤、布料与道具仍是真实材质纹理。',
};
```

3. `hardenPhotoRealism` 重写：
```ts
export function hardenPhotoRealism(prompt: string, opts: HardenOptions = {}): string {
  const { selfie = false, retouchLevel = 'none' } = opts;
  const parts = [PHOTO_REALISM_PREFIX + prompt, RETOUCH_REALISM_SUFFIX[retouchLevel], PHOTO_REALISM_BASELINE_SUFFIX];
  if (selfie) parts.push(SELFIE_DEVICE_SUFFIX);
  return parts.join(' ');
}
```
> `PHOTO_REALISM_PREFIX`（`'一张真实相机直出的实拍照片：'`）与 `SELFIE_DEVICE_SUFFIX` 保留不变。**删除**原 `PHOTO_REALISM_SUFFIX` 中「画面带轻微噪点与白平衡偏差，像随手抓拍的实拍照片」与「禁止：影楼写真、网红精修风」两句。

4. `generate()` 中调用改为：
```ts
      hardening = hardenPhotoRealism(prompt, { selfie: isSelfieDraft(draft), retouchLevel: retouchLevelOfDraft(draft) });
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/ai-generate-image.service.spec.ts`
Expected: PASS

- [ ] **Step 5: Commit & push**

```bash
git add lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.ts lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.spec.ts
git commit -m "feat(ai): 生图出口加固按精修档分档，移除与美感互斥的随手抓拍口径"
git push origin master
git push github master
```

---

### Task 10: `image-score.service.ts` 美学评审闸门

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/image-score.service.ts`（全文重写核心）
- Test: `lumira-server/packages/backend/src/modules/ai/image-score.service.spec.ts`（改 1 处 + 追加）

**Interfaces:**
- Consumes（Task 1）：`StyleProfile`、`renderStyleProfileBlock`
- Produces:
  - `interface AestheticsScores { composition: number; pose: number; styling: number; expression: number; lighting: number; styleHit: number }`
  - `interface RealismScores { anatomy: number; material: number; physical: number }`
  - `interface ScoreResult { score: number; verdict: 'pass' | 'retry'; reasons: string[]; suggests: string[]; aesthetics?: AestheticsScores; realism?: RealismScores }`
  - `interface ScoreInput { draft: unknown; desc?: unknown; styleProfile?: StyleProfile; textOnly?: boolean }`（在既有输入上**追加**两个可选字段）
  - `const AESTHETICS_KEYS / REALISM_KEYS`
  - `function parseScoreGroup(raw: unknown, keys: readonly string[]): Record<string, number> | undefined`
  - `function evaluateGate(input: { score: number; aesthetics?: ...; realism?: ...; textOnly?: boolean }): { pass: boolean; fails: string[] }`
  - `const SCORE_PASS_THRESHOLD = 0.85`（保留不变）

- [ ] **Step 1: 修改既有断言 + 追加新用例**

**修改**（原 L80-93：高分 0.9 但无分项 → 新闸门会 retry，必须补分项）：
```ts
it('总分与分项全达标 → pass', async () => {
  textChatMock.mockResolvedValueOnce(
    JSON.stringify({
      aesthetics: { composition: 0.9, pose: 0.88, styling: 0.9, expression: 0.86, lighting: 0.9, styleHit: 0.92 },
      realism: { anatomy: 0.95, material: 0.9, physical: 0.92 },
      consistency: 0.9, params: 0.9, metadata: 0.9,
      score: 0.9, reasons: [], suggests: [],
    }),
  );
  const res = await scoreService.score({ draft: {} } as never);
  expect(res.verdict).toBe('pass');
  expect(res.score).toBeCloseTo(0.9, 5);
});
```
**追加四种闸门用例**：
```ts
it('总分够但审美分项不够（composition 0.6）→ retry，reasons 指明维度', ...);
it('审美够但真实分项不够（anatomy 0.6）→ retry，reasons 指明真实底线', ...);
it('分项缺失 → 保守 retry', ...);
it('无参考图（textOnly）→ 阈值放宽：aesthetics min 0.70 / score 0.8 即可 pass，realism min 0.85 照旧', ...);
it('suggests 必须落到具体字段与补法（断言含 pose[0].description 与补：）', ...);
it('trace 分项：返回 result 含 aesthetics/realism 结构化分项', ...);
it('SCORE_PASS_THRESHOLD 仍为 0.85（回归）', ...);
```
> 上述六条须写成完整 `it(...)` 块，mock 值与断言一一对应；`textOnly` 用例中 `realism.anatomy = 0.8` 必须仍然 retry。

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/image-score.service.spec.ts`
Expected: FAIL — 分项闸门未实现（高分无分项仍 pass）/ 类型缺字段

- [ ] **Step 3: Write minimal implementation**

1. 顶部 import：`import { renderStyleProfileBlock, type StyleProfile } from './style-profile.presets';`

2. 新增类型与解析：
```ts
export interface AestheticsScores {
  composition: number; // 构图
  pose: number; // 姿势线条与设计感
  styling: number; // 穿搭/妆造
  expression: number; // 表情与情绪
  lighting: number; // 光线层次
  styleHit: number; // 是否命中风格档案取向
}

export interface RealismScores {
  anatomy: number; // 人体/结构解剖
  material: number; // 材质（皮肤/布料/道具）
  physical: number; // 物理合理性（光/透视/可实拍）
}

export const AESTHETICS_KEYS: (keyof AestheticsScores)[] = ['composition', 'pose', 'styling', 'expression', 'lighting', 'styleHit'];
export const REALISM_KEYS: (keyof RealismScores)[] = ['anatomy', 'material', 'physical'];

/** 解析分项：任一键缺失/非数值 → undefined（视为未达标，保守 retry） */
export function parseScoreGroup<T extends string>(raw: unknown, keys: readonly T[]): Record<T, number> | undefined {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return undefined;
  const src = raw as Record<string, unknown>;
  const out = {} as Record<T, number>;
  for (const k of keys) {
    const v = src[k];
    if (typeof v !== 'number' || !Number.isFinite(v)) return undefined;
    out[k] = Math.max(0, Math.min(1, v));
  }
  return out;
}
```

3. 闸门函数：
```ts
export interface GateInput {
  score: number;
  aesthetics?: AestheticsScores;
  realism?: RealismScores;
  textOnly?: boolean;
}

/** 三段闸门：总分 + 审美分项 + 真实分项；无图路径放宽审美与总分，真实底线不变 */
export function evaluateGate(input: GateInput): { pass: boolean; fails: string[] } {
  const fails: string[] = [];
  const scoreThreshold = input.textOnly ? 0.8 : SCORE_PASS_THRESHOLD;
  const aestheticsMin = input.textOnly ? 0.7 : 0.75;
  const realismMin = 0.85;

  if (input.score < scoreThreshold) fails.push(`总分 ${input.score.toFixed(2)} < ${scoreThreshold}`);
  if (!input.aesthetics) fails.push('审美分项缺失');
  else {
    for (const k of AESTHETICS_KEYS) {
      if (input.aesthetics[k] < aestheticsMin) fails.push(`审美维度 ${k}=${input.aesthetics[k].toFixed(2)} < ${aestheticsMin}`);
    }
  }
  if (!input.realism) fails.push('真实分项缺失');
  else {
    for (const k of REALISM_KEYS) {
      if (input.realism[k] < realismMin) fails.push(`真实底线 ${k}=${input.realism[k].toFixed(2)} < ${realismMin}`);
    }
  }
  return { pass: fails.length === 0, fails };
}
```

4. `buildScoreSystemPrompt(styleProfile?)`：
   - 输出 JSON 示例改为闸门结构（aesthetics / realism / consistency / params / metadata / score / reasons / suggests）
   - 追加硬要求：
```ts
'`suggests` 必须落到具体字段与具体补法，例如「pose[0].description 缺表情与左手落点，补：嘴角放松上提、左手扶帽檐」；禁止「提升美感」「优化构图」这类空话。',
'审查时按【风格档案】核对 styleHit：画面是否命中该档案取向；retouchLevel=none 时若出现影棚布光感，styleHit 记不达标。',
'真实底线分项（anatomy/material/physical）不因任何风格取向放宽。',
```
   - 有档案时追加 `renderStyleProfileBlock(styleProfile)`

5. `score(input)`：
   - 从 `extractJson(raw)` 取 `aesthetics` / `realism` 用 `parseScoreGroup` 解析
   - `verdict = evaluateGate({ score, aesthetics, realism, textOnly: input.textOnly }).pass ? 'pass' : 'retry'`
   - `reasons` 合并 LLM 给出的 `reasons` + 闸门 `fails`
   - 返回结果带上 `aesthetics` / `realism`（供 trace 与后台时间线展示）
   - 解析失败（`评分为空`）路径保持原样 `{ score: 0, verdict: 'retry', reasons: ['评分为空'], suggests: [] }`

- [ ] **Step 4: Run test to verify it passes**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/image-score.service.spec.ts`
Expected: PASS

- [ ] **Step 5: Commit & push**

```bash
git add lumira-server/packages/backend/src/modules/ai/image-score.service.ts lumira-server/packages/backend/src/modules/ai/image-score.service.spec.ts
git commit -m "feat(ai): 评审升级为总分+审美分项+真实分项三段闸门，无图路径放宽但不豁免真实底线"
git push origin master
git push github master
```

---

### Task 11: `ai-orchestrator.service.ts` + `draft-refine.service.ts` 接线

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-orchestrator.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/draft-refine.service.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/ai-orchestrator.service.spec.ts`（**替换** L215-224 无图跳过用例 + 追加）
- Test: Create: `lumira-server/packages/backend/src/modules/ai/draft-refine.service.spec.ts`

**Interfaces:**
- Consumes（Task 1/2/6/10）：`StyleProfileResolveResult`、`StyleProfile`、`renderStyleProfileBlock`、`score(input)` 新增的 `styleProfile`/`textOnly`、`poseRefSheet.generate(desc, count, userReq, styleProfile)`
- Produces:
  - `STEP_TITLES.styleProfile = '风格定位'`
  - `OrchestratorRunOptions.styleProfile?: StyleProfileResolveResult`
  - `DraftRefineInput.styleProfile?: StyleProfile`
  - 定稿 `workingDraft = { ...bestDraft, poseRefSheet: poseSheet, styleProfile: profile }`

- [ ] **Step 1: Write the failing tests**

**11a. 替换** `ai-orchestrator.service.spec.ts` 中「仅文字（无图）→ 跳过 describe」用例中关于跳过评审的断言，改为：
```ts
it('无图路径不再跳过评审：describe 不调用，poseRefSheet 与 imageScore 仍执行', async () => {
  const { service, describe, poseRefSheet, score, optsRun } = build();

  const res = await service.run({ text: '奶油风人像', poseCount: 1 }, optsRun);

  expect(describe.describe).not.toHaveBeenCalled();
  expect(poseRefSheet.generate).toHaveBeenCalled();
  expect(score.score).toHaveBeenCalledTimes(1);
  expect(score.score).toHaveBeenCalledWith(expect.objectContaining({ textOnly: true }));
  expect(res.trace.map((t) => t.step)).toContain('imageScore');
});
```
**11b. 追加** Orchestrator 用例：
```ts
it('消费调用方传入的 styleProfile：trace 含 styleProfile 步骤，且透传给 poseRefSheet / score', async () => {
  const { service, poseRefSheet, score, optsRun } = build();
  const styleProfile = {
    profile: { category: 'portrait', archetype: 'fashion_editorial', retouchLevel: 'polished', aestheticTarget: 'x', subjectStyling: '', expressionMood: '', poseLanguage: '', lightingSignature: '', compositionBias: '', paletteHint: '', extraNotes: '' },
    source: 'llm' as const,
    note: '时尚大片/portrait/polished',
  };

  const res = await service.run(
    { imageBase64: 'aGk=', imageMime: 'image/jpeg', creationReq: '秋冬大片', poseCount: 1 },
    { ...optsRun, styleProfile },
  );

  expect(res.trace.map((t) => t.step)).toContain('styleProfile');
  expect(poseRefSheet.generate).toHaveBeenCalledWith(expect.anything(), expect.anything(), expect.anything(), styleProfile.profile);
  expect(score.score).toHaveBeenCalledWith(expect.objectContaining({ styleProfile: styleProfile.profile }));
  expect(res.draft.styleProfile).toMatchObject({ archetype: 'fashion_editorial' });
});

it('调用方未传 styleProfile → 编排内自行兜底解析一次', async () => {
  const { service, optsRun } = build();
  const res = await service.run({ imageBase64: 'aGk=', imageMime: 'image/jpeg', poseCount: 1 }, optsRun);
  expect(res.trace.map((t) => t.step)).toContain('styleProfile');
  expect(res.draft.styleProfile).toBeDefined();
});
```
> `build()` 需注入 mock `StyleProfileService`（`resolve` 返回 `{ profile: DEFAULT_PROFILE, source: 'fallback', note: 'fallback' }`），并把 `new AiOrchestratorService(...)` 增加第 8 个参数。

**11c. 新建** `draft-refine.service.spec.ts`：
```ts
import { DraftRefineService } from './draft-refine.service';
import { textChat } from './llm-client';
import type { LlmEndpoint } from './llm-client';

jest.mock('./llm-client', () => ({ textChat: jest.fn() }));
const textChatMock = textChat as jest.MockedFunction<typeof textChat>;
const TEXT: LlmEndpoint = { provider: 'qwen', baseUrl: 'x', apiKey: 'sk', model: 'qwen-plus' };

describe('DraftRefineService.refine', () => {
  beforeEach(() => textChatMock.mockReset());

  it('按未达标维度逐项整改：提示词含逐项整改要求与 styleProfile 段落', async () => {
    textChatMock.mockResolvedValueOnce(JSON.stringify({ meta: { name: '改进稿' } }));
    const svc = new DraftRefineService();
    const out = await svc.refine({
      draft: { meta: { name: '原稿' } },
      suggests: ['pose[0].description 缺表情与左手落点，补：嘴角放松上提、左手扶帽檐'],
      text: 'model',
    } as never, TEXT);

    expect(out).toMatchObject({ meta: { name: '改进稿' } });
    const systemPrompt = String(textChatMock.mock.calls[0][1].systemPrompt);
    expect(systemPrompt).toContain('逐项整改');
    expect(systemPrompt).toContain('不得破坏真实底线');
    expect(systemPrompt).toContain('styleProfile');
  });
});
```
> 该 spec 的 `refine()` 调用签名请以实际文件为准（读 `draft-refine.service.ts` 后按真实签名调用）。

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/ai-orchestrator.service.spec.ts src/modules/ai/draft-refine.service.spec.ts`
Expected: FAIL — 无图路径仍跳过评审 / styleProfile 步骤缺失 / draft-refine spec 不存在

- [ ] **Step 3: Write minimal implementation**

**11a. `draft-refine.service.ts`**：
- import `renderStyleProfileBlock, type StyleProfile`；`DraftRefineInput` 追加 `styleProfile?: StyleProfile;`
- 系统提示词追加：
```ts
'按评审未达标的维度逐项整改，只改相关字段（pose[] / sceneGuide / composition / postProcess / camera），不要无关地改写整份草稿。',
'整改必须落到具体字段与具体写法，例如「pose[0].description 缺表情与左手落点」就补上嘴角与左手落点。',
'不得破坏真实底线（真实照片媒介、真实解剖、可实拍、真实材质），也不得改变风格档案取向。',
'输出仍是完整的草稿 JSON。',
```
- 有 `styleProfile` 时把 `renderStyleProfileBlock(styleProfile)` 拼在系统提示词末尾

**11b. `ai-orchestrator.service.ts`**：

1. import：`import { StyleProfileService, type StyleProfileResolveResult } from './style-profile.service';` 和 `import { defaultStyleProfile, type StyleProfile } from './style-profile.presets';`
2. `STEP_TITLES` 增加 `styleProfile: '风格定位',`
3. `OrchestratorRunOptions` 增加 `styleProfile?: StyleProfileResolveResult;`
4. 构造器末尾追加第 8 参数 `private readonly styleProfileService?: StyleProfileService,`（`@Optional()`）
5. run() 内**第一步**（在 research 之前）：
```ts
    const profile: StyleProfile =
      options.styleProfile?.profile ??
      (this.styleProfileService
        ? (await this.styleProfileService.resolve({ text: input.text, creationReq: input.creationReq })).profile
        : defaultStyleProfile());
    traceNote('styleProfile', STEP_TITLES.styleProfile,
      options.styleProfile?.note ?? `兜底：${profile.archetype}/${profile.category}/${profile.retouchLevel}`);
```
> 必须使用 `llm-trace.ts` 导出的 `traceNote(step, title, resultBrief?)` 采集，勿手工 push trace 对象。
6. `poseRefSheet.generate(...)` 追加第 4 参数 `profile`
7. 评审输入：`{ draft: workingDraft, desc, styleProfile: profile, textOnly: !input.imageBase64 }`（评审 call site 按实际参数名调整）
8. **删除** L170-186 的「无参考图 → `result = { score: 1, verdict: 'pass' }; break;`」整块；无图时改为对草稿做纯文本评审（`textOnly: true`）
9. `draftRefine.refine(...)` 输入追加 `styleProfile: profile`
10. 定稿：`workingDraft = { ...bestDraft, poseRefSheet: poseSheet, styleProfile: profile };`
11. score 的 trace 记录中带上 `aesthetics` / `realism` 分项

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
pnpm --filter @lumira/backend exec jest src/modules/ai
pnpm --filter @lumira/backend exec tsc -p tsconfig.build.json --noEmit
```
Expected: PASS（模块内全部单测）；无类型错误

- [ ] **Step 5: Commit & push**

```bash
git add lumira-server/packages/backend/src/modules/ai/ai-orchestrator.service.ts lumira-server/packages/backend/src/modules/ai/ai-orchestrator.service.spec.ts lumira-server/packages/backend/src/modules/ai/draft-refine.service.ts lumira-server/packages/backend/src/modules/ai/draft-refine.service.spec.ts
git commit -m "feat(ai): 编排接入风格定位、无图不再跳过美学评审、按维度逐项整改"
git push origin master
git push github master
```

---

### Task 12: 登记后续优化 + 全量验证 + 收尾推送

**Files:**
- Modify: `docs/future-optimizations.md`（末尾追加 2 条）

- [ ] **Step 1: 全量验证**

```bash
pnpm --filter @lumira/backend exec jest src/modules/ai
pnpm --filter @lumira/backend exec tsc -p tsconfig.build.json --noEmit
```
Expected: 全绿 + 无类型错误

- [ ] **Step 2: 追加到 `docs/future-optimizations.md` 末尾**

```markdown
### P1 · AI 生成图视觉评审 + 不达标重生成闭环

- **模块**：后端 AI 一键生成模板（`lumira-server/packages/backend/src/modules/ai/`）
- **根因/优化点**：当前美学评审只评「提示词草稿」（生图前），不评「生成出来的图」，因此提示词达标但成图仍可能不好看，且无法自动重生成。
- **目标状态**：对每张生成图用视觉模型打分（构图/姿势/穿搭/表情/光线/真实底线），不达标时限次重生成（带失败原因改写提示词），并在后台时间线展示每张图的分项与重生成次数。
- **状态**：⏳ 待实现（成本与耗时较高，本次未做）

### P2 · 风格档案改由后台维护（DB 配置 + 管理界面）

- **模块**：后端 AI 配置（`lumira-server/packages/backend/src/modules/ai/`）+ 后台（`lumira-server/packages/admin/`）
- **根因/优化点**：当前 7 套风格档案 `STYLE_ARCHETYPE_PRESETS` 为代码内置固定档案，运营无法自定义取向与禁忌。
- **目标状态**：档案迁移到 DB（`ai_style_profiles` 表），后台提供增删改与启用开关，支持导入导出，链路运行时按启用档案渲染。
- **状态**：⏳ 待实现（本次为代码内置固定档案）

### P2 · 清理已下线链路的 `prompt-polisher.ts`

- **模块**：后端 AI（`lumira-server/packages/backend/src/modules/ai/prompt-polisher.ts`）
- **根因/优化点**：`prompt-polisher.ts` 已不在生图链路上被调用（`ai-generate-image.service` 走 `composeImagePrompt`），仅残留死代码与单测。
- **目标状态**：确认无引用后删除文件与 `prompt-polisher.spec.ts`。
- **状态**：⏳ 待实现（本次为降低风险未删除）
```

- [ ] **Step 3: Commit & push**

```bash
git add docs/future-optimizations.md
git commit -m "docs(ai): 登记生成图视觉评审闭环与风格档案后台化等后续优化项"
git push origin master
git push github master
```

- [ ] **Step 4: 确认工作区干净且两端远程同步**

```bash
git status
git log --oneline -14
```
Expected: `nothing to commit, working tree clean`；最近 14 条为本次各 Task 的 commit

---

## Self-Review

**1. Spec 覆盖检查**

| Spec 章节 | 对应 Task |
| --- | --- |
| §4.1 StyleProfile 契约 | Task 1 |
| §4.2 档案表 + 底线 + 现场补充规则 | Task 1（`STYLE_ARCHETYPE_PRESETS` / `REALISM_BASELINE` / 渲染块末句优先声明） |
| §4.3 草稿透传 + normalize 放行 | Task 4、Task 11（定稿写入） |
| §5.1 style-profile.service | Task 2、Task 11（STEP_TITLES + trace 消费） |
| §5.2 analyze.prompt | Task 3 |
| §5.3 image-describe | Task 5 |
| §5.4 pose-ref-sheet | Task 6 |
| §5.5 composer | Task 7 |
| §5.6 builder | Task 8 |
| §5.7 hardenPhotoRealism | Task 9 |
| §5.8 美学评审闸门 + 无图放宽 | Task 10、Task 11（删除 break） |
| §5.9 draft-refine | Task 11 |
| §5.10 param-validate | 无改动（spec 明确「仅补一处…保持现状」，现有裁剪已覆盖） |
| §5.11 不动的部分 | 全程未触碰 `prompt-polisher.ts` / `ai-image-task.service.ts` |
| §6 降级 | Task 2（fail → 默认档案）、Task 10（解析失败保守 retry）、Task 4（styleProfileService 可选） |
| §7 测试计划 1~9 | Task 1~3、5~11 的 spec 覆盖 |
| §8.1 admin 回传确认 | 已确认 admin 端 `{...draft}` 原样回传，无需改动 |
| §9 后续优化登记 | Task 12 |

**2. Placeholder 扫描**：无 TBD / TODO / 「类似 Task N」；所有新增代码步骤均给出完整实现；纯修改步骤给出精确替换目标与替换后代码。

**3. 类型一致性**：`StyleProfile` / `RetouchLevel` / `StyleArchetype` 全部只在 Task 1 定义并导出；`normalizeStyleProfile`、`styleProfileOfDraft`、`renderStyleProfileBlock`、`retouchLevelOfDraft`、`RETOUCH_TEXTURE_LINES`、`RETOUCH_REALISM_SUFFIX`、`PHOTO_REALISM_BASELINE_SUFFIX`、`parseScoreGroup`、`evaluateGate`、`normalizeSubjectPose`、`SUBJECT_POSE_KEYS` 的命名在定义与消费处一致；`hardenPhotoRealism` 第二参数在 Task 9 改为可选对象 `HardenOptions`，Task 9 的 spec 已同步改 L207 调用。