# AI 模板：多人物 / 去噪写实 / 搜索落地姿势图（期1）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 AI 一键生成模板支持 1/2/3+ 人物场景、彻底去掉生图提示词中的噪点/颗粒/瑕疵要求（转高清干净写实）、并把联网检索的结构化趋势结论透传到姿势图生成，同时把检索来源站点限定到小红书等社交平台。

**Architecture:** 全部改动集中在 `lumira-server/packages/backend/src/modules/ai`（提示词构造 + 数据流）+ `lumira-server/packages/admin`（类型与 Step1 控件）。核心手法：(1) 新增草稿字段 `meta.subjectCount` 贯穿「识别契约 → 归一化白名单 → 生图提示词」；(2) 三处请求噪点的提示词源全部改写；(3) `ResearchBrief` 从识别任务结果经状态接口 → admin → 生图请求全链路透传，由 composer 渲染为【趋势要点】区块。

**Tech Stack:** NestJS + Fastify + Drizzle ORM（后端）、Next.js App Router + shadcn/ui（admin）、Jest（后端单测，spec 与实现同目录）、pnpm workspace。

## Global Constraints

- 改动范围：`lumira-server/packages/backend/**` 与 `lumira-server/packages/admin/**`；**不触碰** `lumira_app_flutter/**` 与 `lumira-app/**`。
- LLM 调用超时 300s（生图提示词组织器）；`llm-client` 对 5xx 有 800ms 退避；`GENERATE_RETRY_LIMIT=4`。
- 后端单测文件与实现同目录（`*.spec.ts`），Jest。
- 每个 Task 结束必须 commit，并按 `AGENTS.md` 硬规则同时 push：`git push origin master` 与 `git push github master`。
- 提示词一律「高清干净写实」：不得新增 `颗粒` / `噪点` / `grain` / `sensor noise` 等要求（负面清单中「禁止颗粒与噪点」除外）。
- 所有新增提示词文案为中文（`image-client.ts` 的英文锚点除外）。
- 空草稿兜底 `FALLBACK_PROMPT` 行为不变。

---

## 文件结构（改动映射）

| 文件 | 责任 | 涉及 Task |
|------|------|-----------|
| `backend/src/modules/ai/normalize.ts` | 草稿归一化白名单，放行 `meta.subjectCount` | 1 |
| `backend/src/modules/ai/normalize.spec.ts` | 夹具补 `subjectCount`，新增归一化用例 | 1 |
| `backend/src/modules/ai/analyze.prompt.ts` | 识别契约加 `subjectCount`；系统提示按人数分档；用户提示加人数指令；`inferSubjectCountHint` | 2 |
| `backend/src/modules/ai/ai-analyze.service.ts` | 校验并传递 `subjectCount`；结果补 `brief` | 2 / 6 |
| `backend/src/modules/ai/ai-templates.controller.ts` | multipart 增 `subjectCount`；状态接口回传 `researchBrief` | 2 / 6 |
| `backend/src/modules/ai/ai-analyze-task.service.ts` | 任务结果类型补 `brief` | 6 |
| `backend/src/modules/ai/image-prompt.builder.ts` | `describeSubjectCount` / `subjectCountOfDraft`；删 grain；瑕疵句改写 | 3 / 5 |
| `backend/src/modules/ai/image-prompt.composer.ts` | 主体人数行 / 系统角色派生 / 一致性分档；删 grain 与强制噪点；瑕疵句改写；【趋势要点】区块 | 3 / 5 / 8 |
| `backend/src/modules/ai/image-client.ts` | 英文写实锚点去噪 | 4 |
| `backend/src/modules/ai/ai-generate-image.service.ts` | `hardenPhotoRealism` 文案；解析 `{items,brief}` 并透传 | 5 / 8 |
| `backend/src/modules/ai/ai-config.service.ts` | searxng 默认来源集（社交平台站点限定） | 9 |
| `backend/src/modules/ai/trend-research/trend-research.service.ts` | `reorganizeQuery` 追加平台语感词 | 9 |
| `admin/src/types/admin.ts` | `AiAnalyzeStatusResult.researchBrief` + `AiResearchBrief` | 7 |
| `admin/src/lib/ai-task.ts` | `research` 改传 `{items, brief}` | 7 |
| `admin/src/components/ai-create/wizard.tsx` | Step1 高级区新增「人物数量」选择 | 10 |

**执行顺序提示**：`image-prompt.composer.ts` 被 Task 3 / 5 / 8 依次修改（改的是不同区域）。三个 Task 必须按编号顺序执行，不要并行。

---

## Task 1: `meta.subjectCount` 归一化字段

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/normalize.ts:281-287`（meta 的 shortDesc/description 之后）
- Test: `lumira-server/packages/backend/src/modules/ai/normalize.spec.ts`

**Interfaces:**
- Consumes: 无
- Produces: 归一化后草稿的 `meta.subjectCount: number`（整数 1~8，缺省 1）

- [ ] **Step 1: 夹具补字段（先让既有用例与新契约一致）**

打开 `lumira-server/packages/backend/src/modules/ai/normalize.spec.ts`，在 `baseDraft()` 的 `meta` 对象里、`category` 之后插入一行：

```ts
      category: 'portrait',
      subjectCount: 1,
      shortDesc: '把夏天拍进眼睛里',
```

- [ ] **Step 2: 写失败用例**

在 `normalize.spec.ts` 末尾追加（`describe` 块内）：

```ts
  it('meta.subjectCount：缺失回落 1 并记 warning', () => {
    const draft: any = baseDraft();
    delete draft.meta.subjectCount;
    const { draft: out, warnings } = normalizeDraft(draft, CATEGORIES);
    expect((out.meta as any).subjectCount).toBe(1);
    expect(warnings.some((w) => w.includes('meta.subjectCount'))).toBe(true);
  });

  it('meta.subjectCount：合法值原样保留', () => {
    const draft: any = baseDraft();
    draft.meta.subjectCount = 3;
    const { draft: out, warnings } = normalizeDraft(draft, CATEGORIES);
    expect((out.meta as any).subjectCount).toBe(3);
    expect(warnings.some((w) => w.includes('meta.subjectCount'))).toBe(false);
  });

  it('meta.subjectCount：超范围夹取到 1~8 并记 warning', () => {
    const draft: any = baseDraft();
    draft.meta.subjectCount = 99;
    const { draft: out, warnings } = normalizeDraft(draft, CATEGORIES);
    expect((out.meta as any).subjectCount).toBe(8);
    expect(warnings.some((w) => w.includes('meta.subjectCount'))).toBe(true);
  });

  it('meta.subjectCount：非数字回落 1 并记 warning', () => {
    const draft: any = baseDraft();
    draft.meta.subjectCount = '3';
    const { draft: out, warnings } = normalizeDraft(draft, CATEGORIES);
    expect((out.meta as any).subjectCount).toBe(1);
    expect(warnings.some((w) => w.includes('meta.subjectCount'))).toBe(true);
  });
```

- [ ] **Step 3: 运行用例确认失败**

Run: `pnpm --filter @lumira/backend exec jest normalize.spec.ts`
Expected: FAIL —— `subjectCount` 为 `undefined`（用例 1/3/4 失败）。

- [ ] **Step 4: 实现**

在 `normalize.ts` 中，紧跟 `const description = toStr(rawMeta.description); if (description !== undefined) meta.description = description;`（约 L281-282）之后插入：

```ts
  // subjectCount：画面主体人数（1~8 整数，缺省 1）。缺省不是中性值而是「单人」的明确断言，
  // 因此模型未给出时必须记 warning，避免情侣/全家福场景被静默降级成单人模板。
  const rawSubjectCount = rawMeta.subjectCount;
  if (typeof rawSubjectCount === 'number' && Number.isFinite(rawSubjectCount)) {
    const rounded = Math.round(rawSubjectCount);
    const clamped = Math.min(8, Math.max(1, rounded));
    if (clamped !== rawSubjectCount) {
      warnings.push(`meta.subjectCount ${rawSubjectCount} 不在 1~8 范围内，已夹取为 ${clamped}`);
    }
    meta.subjectCount = clamped;
  } else {
    warnings.push('未提供 meta.subjectCount，已按 1 人处理');
    meta.subjectCount = 1;
  }
```

- [ ] **Step 5: 运行用例确认通过**

Run: `pnpm --filter @lumira/backend exec jest normalize.spec.ts`
Expected: PASS（全部用例）。

- [ ] **Step 6: 全量后端测试（确认无其他用例断言 warnings 为空）**

Run: `pnpm --filter @lumira/backend test`
Expected: PASS。若有用例因新增 warning 失败，检查该用例的夹具草稿，补 `meta.subjectCount: 1`（不要删断言）。

- [ ] **Step 7: 提交并双远程推送**

```bash
git add lumira-server/packages/backend/src/modules/ai/normalize.ts lumira-server/packages/backend/src/modules/ai/normalize.spec.ts
git commit -m "feat(ai): 草稿归一化新增 meta.subjectCount 主体人数字段"
git push origin master
git push github master
```

---

## Task 2: 识别侧多人物支持（提示词 + 接口字段）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/analyze.prompt.ts`（L117-211 契约与硬约束、L215-222 系统提示、L224-291 用户提示）
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-analyze.service.ts:58-72, 151-185`
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-templates.controller.ts:29-36, 169-190`
- Test: `lumira-server/packages/backend/src/modules/ai/analyze.prompt.spec.ts`

**Interfaces:**
- Consumes: `meta.subjectCount` 契约（Task 1 已放行归一化）
- Produces:
  - `export function inferSubjectCountHint(...texts: Array<string | null | undefined>): number`
  - `export function buildAnalyzeSystemPrompt(categories: CategoryNode[], styleProfile?: StyleProfile, subjectCountHint?: number): string`
  - `export function buildTextOnlySystemPrompt(categories: CategoryNode[], styleProfile?: StyleProfile, subjectCountHint?: number): string`
  - `AnalyzeUserPromptInput.subjectCount?: number | null`
  - `AiAnalyzeService.analyze(image, text, extra)` 的 `extra` 新增 `subjectCount?: string | null`（1~8 整数字符串）

- [ ] **Step 1: 写失败用例**

在 `analyze.prompt.spec.ts` 追加（若已有 import，补上 `inferSubjectCountHint`）：

```ts
import {
  buildAnalyzeSystemPrompt,
  buildAnalyzeUserPrompt,
  inferSubjectCountHint,
} from './analyze.prompt';

const CATEGORIES = [{ key: 'portrait', name: '人像', parentKey: null, level: 1 }];
const PORTRAIT_PROFILE = { category: 'portrait' } as any;

describe('多人物支持', () => {
  it('inferSubjectCountHint：命中多人关键词返回 2，否则 1', () => {
    expect(inferSubjectCountHint('帮朋友拍一组情侣照')).toBe(2);
    expect(inferSubjectCountHint('一家人的全家福')).toBe(2);
    expect(inferSubjectCountHint('一个人的街拍')).toBe(1);
    expect(inferSubjectCountHint(undefined, null, '')).toBe(1);
  });

  it('系统提示：多人提示档要求保持人物数量与互动关系', () => {
    const single = buildAnalyzeSystemPrompt(CATEGORIES, PORTRAIT_PROFILE, 1);
    const multi = buildAnalyzeSystemPrompt(CATEGORIES, PORTRAIT_PROFILE, 2);
    expect(single).toContain('不得改变人物长相');
    expect(multi).toContain('同一组人物');
    expect(multi).toContain('不得改变人物数量');
    expect(multi).not.toContain('体型、场景、道具、光线或整体风格。仅当用户明确要求');
  });

  it('系统提示：契约示例含 meta.subjectCount', () => {
    expect(buildAnalyzeSystemPrompt(CATEGORIES)).toContain('"subjectCount"');
  });

  it('用户提示：显式指定人数输出硬约束', () => {
    expect(buildAnalyzeUserPrompt({ subjectCount: 2 })).toContain('meta.subjectCount 必须为 2');
  });

  it('用户提示：未指定人数时输出推断口径', () => {
    expect(buildAnalyzeUserPrompt({})).toContain('请根据用户描述与示例图中实际可见的人物数量给出 meta.subjectCount');
  });
});
```

- [ ] **Step 2: 运行确认失败**

Run: `pnpm --filter @lumira/backend exec jest analyze.prompt.spec.ts`
Expected: FAIL —— `inferSubjectCountHint is not a function`。

- [ ] **Step 3: 契约示例与硬约束（`analyze.prompt.ts`）**

3a. 在 `DRAFT_JSON_EXAMPLE` 的 `meta` 中，`"category": "portrait",` 之后插入：

```ts
    "subjectCount": 1,                      // 画面主体人数：1=单人；2=情侣/双人；3+=全家福/合影/聚餐；按参考图与用户描述推断
```

3b. 把硬约束里的这一行（L197-198）：

```ts
- pose 数组中的每个 description 必须是单张单人可独立生成的姿势，
  不要把多个姿势合并到同一个 description 里；
```

替换为：

```ts
- pose 数组中的每个 description 必须是「单张画面内可独立生成」的姿势，不要把多个姿势合并到同一个 description 里；
- meta.subjectCount 必须给出 1~8 的整数：按用户描述与参考图中实际可见的人物数量填写；出现「情侣 / 结婚 / 婚纱 / 闺蜜 / 全家福 / 合影 / 多人 / 聚餐 / 聚会」等场景时不得写 1；
```

3c. 在 `DRAFT_JSON_EXAMPLE` 之前新增关键词与推断函数：

```ts
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
```

- [ ] **Step 4: 系统提示按人数分档（`analyze.prompt.ts`）**

4a. 把 `buildSystemPromptBody` 里现有的 `const poseConsistencyLine = portrait ? ... : ...;`（L157-164）整段替换为一次函数调用：

```ts
  const poseConsistencyLine = poseConsistencyLineOf(portrait, subjectCountHint);
```

4b. 在 `buildSystemPromptBody` 之前新增该函数：

```ts
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
```

4c. `buildSystemPromptBody` 签名改为：

```ts
function buildSystemPromptBody(categories: CategoryNode[], styleProfile?: StyleProfile, subjectCountHint = 1): string {
```

4d. 两个导出函数签名与传参改为：

```ts
export function buildAnalyzeSystemPrompt(categories: CategoryNode[], styleProfile?: StyleProfile, subjectCountHint = 1): string {
  return `你是资深摄影/视觉模板编辑（按风格档案作业），分析用户上传的示例图，产出可直接上线的摄影模板表单数据。\n\n${buildSystemPromptBody(categories, styleProfile, subjectCountHint)}`;
}

export function buildTextOnlySystemPrompt(categories: CategoryNode[], styleProfile?: StyleProfile, subjectCountHint = 1): string {
  return `你是资深摄影/视觉模板编辑（按风格档案作业）。用户将提供一段风格描述或创作要求（没有示例图），请据此构思一个可直接上线的摄影模板，产出模板表单数据。描述未提及的字段，给出符合该风格的合理建议值（相机参数为复现该风格的估算值）。\n\n${buildSystemPromptBody(categories, styleProfile, subjectCountHint)}`;
}
```

- [ ] **Step 5: 用户提示加人数指令（`analyze.prompt.ts`）**

5a. `AnalyzeUserPromptInput` 增加字段：

```ts
  /** 主体人数：1~8 显式指定；空/undefined = AI 自动推断 */
  subjectCount?: number | null;
```

5b. 在 `poseCountLine` 之后新增：

```ts
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
```

5c. `buildAnalyzeUserPrompt` 与 `buildTextOnlyUserPrompt` 中，各在 `lines.push(poseCountLine(input.poseCount));` 之前插入：

```ts
  lines.push(subjectCountLine(input.subjectCount));
```

- [ ] **Step 6: 服务层校验与传递（`ai-analyze.service.ts`）**

6a. import 补 `inferSubjectCountHint`：

```ts
import {
  buildAnalyzeSystemPrompt,
  buildAnalyzeUserPrompt,
  buildTextOnlySystemPrompt,
  buildTextOnlyUserPrompt,
  inferSubjectCountHint,
} from './analyze.prompt';
```

6b. `analyze(...)` 的 `extra` 类型加字段：

```ts
    extra: { textDesc?: string | null; creationReq?: string | null; poseCount?: string | null; subjectCount?: string | null } = {},
```

6c. 在 poseCount 解析之后（`poseCount = n;` 所在 `if` 块之后）插入：

```ts
    // 0.5 主体人数：'1'~'8' 整数字符串合法；其余（空/非法）= AI 自动推断
    let subjectCount: number | null = null;
    if (extra.subjectCount !== null && extra.subjectCount !== undefined && extra.subjectCount !== '') {
      const n = Number(extra.subjectCount);
      if (!Number.isInteger(n) || n < 1 || n > 8) {
        throw new BadRequestException('subjectCount 必须是 1~8 的整数（留空则由 AI 自动推断）');
      }
      subjectCount = n;
    }
    // 系统提示的措辞分档：显式指定优先，否则从用户输入预判（情侣/全家福等关键词）
    const subjectCountHint = subjectCount ?? inferSubjectCountHint(extra.creationReq, extra.textDesc, trimmedText);
```

> 注意：`trimmedText` 在第 1 步（L74）已定义；若此处作用域不可见，请把该插入位置下移到 `const trimmedText = ...` 之后。

6d. 视觉分支调用改为：

```ts
            systemPrompt: buildAnalyzeSystemPrompt(categories, styleProfile, subjectCountHint),
```

并在同一次 `buildAnalyzeUserPrompt({...})` 入参中补 `subjectCount,`：

```ts
            userText: buildAnalyzeUserPrompt({
              textDesc: extra.textDesc?.trim() || trimmedText || undefined,
              creationReq: extra.creationReq,
              poseCount,
              subjectCount,
              researchDigest,
              researchUnavailable,
            }),
```

6e. 纯文字分支调用同样改为：

```ts
            systemPrompt: buildTextOnlySystemPrompt(categories, styleProfile, subjectCountHint),
```

并补 `subjectCount,`：

```ts
            userText: buildTextOnlyUserPrompt({
              textDesc: trimmedText,
              creationReq: extra.creationReq,
              poseCount,
              subjectCount,
              researchDigest,
              researchUnavailable,
            }),
```

- [ ] **Step 7: 接口字段（`ai-templates.controller.ts`）**

7a. 在 `analyze` 端点解构与传参中补 `subjectCount`：

```ts
    const { image, text, textDesc, creationReq, poseCount, subjectCount } = await parseAiMultipart(req);
    return this.aiAnalyzeTaskService.submit(image, text ?? textDesc ?? undefined, {
      textDesc,
      creationReq,
      poseCount,
      subjectCount,
    });
```

7b. `TEXT_FIELDS` 数组补 `'subjectCount'`：

```ts
const TEXT_FIELDS = ['meta', 'text', 'textDesc', 'creationReq', 'poseCount', 'subjectCount', 'extraPrompt', 'research'] as const;
```

7c. `ParsedAiMultipart` 接口补字段，并在解析函数的结果初始化对象里补 `subjectCount: null`：

```ts
  subjectCount: string | null;
```

```ts
  const result: ParsedAiMultipart = { meta: null, textDesc: null, creationReq: null, poseCount: null, subjectCount: null, extraPrompt: null, research: null };
```

- [ ] **Step 8: 运行用例确认通过**

Run: `pnpm --filter @lumira/backend exec jest analyze.prompt.spec.ts`
Expected: PASS。

- [ ] **Step 9: 类型检查 + 全量测试**

Run: `pnpm --filter @lumira/backend exec tsc --noEmit`
Expected: 无错误（`ai-analyze-task.service.ts` 的 `submit` 入参类型若为显式接口，需补 `subjectCount?: string | null`）。

Run: `pnpm --filter @lumira/backend test`
Expected: PASS。

- [ ] **Step 10: 提交并双远程推送**

```bash
git add lumira-server/packages/backend/src/modules/ai/analyze.prompt.ts lumira-server/packages/backend/src/modules/ai/analyze.prompt.spec.ts lumira-server/packages/backend/src/modules/ai/ai-analyze.service.ts lumira-server/packages/backend/src/modules/ai/ai-templates.controller.ts lumira-server/packages/backend/src/modules/ai/ai-analyze-task.service.ts
git commit -m "feat(ai): 识别侧支持多人物推断与显式指定主体人数"
git push origin master
git push github master
```

---

## Task 3: 生图侧多人物（builder + composer）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/image-prompt.builder.ts:231-238`
- Modify: `lumira-server/packages/backend/src/modules/ai/image-prompt.composer.ts:27-51, 226-240, 352-362, 378-389`
- Test: `lumira-server/packages/backend/src/modules/ai/image-prompt.builder.spec.ts`、`image-prompt.composer.spec.ts`

**Interfaces:**
- Consumes: 草稿 `meta.subjectCount`（Task 1）
- Produces:
  - `export function subjectCountOfDraft(draft: unknown): number`（1~8，缺省 1）—— `image-prompt.builder.ts`
  - `export function describeSubjectCount(n: number): string` —— `image-prompt.builder.ts`
  - `export function buildComposeSystemPrompt(categoryKey?: string): string`（签名新增可选参数）

- [ ] **Step 1: 写失败用例（builder）**

在 `image-prompt.builder.spec.ts` 追加：

```ts
import { buildImagePrompt, describeSubjectCount, subjectCountOfDraft } from './image-prompt.builder';

describe('多人物', () => {
  it('describeSubjectCount：三档措辞', () => {
    expect(describeSubjectCount(1)).toBe('画面中只有一位人物');
    expect(describeSubjectCount(2)).toContain('两位人物');
    expect(describeSubjectCount(4)).toContain('4 位人物');
  });

  it('subjectCountOfDraft：缺省 1，超范围夹取', () => {
    expect(subjectCountOfDraft({})).toBe(1);
    expect(subjectCountOfDraft({ meta: { subjectCount: 3 } })).toBe(3);
    expect(subjectCountOfDraft({ meta: { subjectCount: 99 } })).toBe(8);
  });

  it('单姿势人像：双人草稿不再写「只有一个人物」', () => {
    const draft = fullDraft();
    (draft.meta as any).subjectCount = 2;
    draft.singlePose = true;
    const prompt = buildImagePrompt(draft);
    expect(prompt).toContain('画面中有两位人物');
    expect(prompt).not.toContain('画面中只有一个人物');
  });
});
```

- [ ] **Step 2: 运行确认失败**

Run: `pnpm --filter @lumira/backend exec jest image-prompt.builder.spec.ts`
Expected: FAIL —— `describeSubjectCount is not a function`。

- [ ] **Step 3: builder 实现**

3a. 在 `image-prompt.builder.ts` 的 `retouchLevelOfDraft` 之后新增：

```ts
/** 画面主体人数（1~8，缺省 1）：从草稿 meta.subjectCount 读取，缺失/非法回退 1 */
export function subjectCountOfDraft(draft: unknown): number {
  if (!isPlainObject(draft)) return 1;
  const meta = isPlainObject(draft.meta) ? draft.meta : {};
  const n = toNum(meta.subjectCount);
  if (n === undefined) return 1;
  const rounded = Math.round(n);
  return rounded < 1 ? 1 : rounded > 8 ? 8 : rounded;
}

/** 主体人数描述（生图硬约束行；builder 与 composer 共用同一口径） */
export function describeSubjectCount(n: number): string {
  if (n <= 1) return '画面中只有一位人物';
  if (n === 2) return '画面中有两位人物（如情侣 / 同伴），注意两人之间的距离与互动关系';
  return `画面中有 ${n} 位人物（如全家福 / 朋友合影），注意人物之间的站位层次与相互呼应`;
}
```

3b. 把 L231-238 的 `if (isSinglePose) { ... }` 整块替换为：

```ts
  if (isSinglePose) {
    const subjectCount = describeSubjectCount(subjectCountOfDraft(draft));
    segments.push(
      posePhrase ? `${subjectCount}，只呈现姿势${posePhrase}` : `${subjectCount}，只呈现一个姿势`,
    );
    segments.push('不要合并多个姿势，不要生成连拍、多宫格或姿势对比图');
  }
```

- [ ] **Step 4: 写失败用例（composer）**

在 `image-prompt.composer.spec.ts` 追加（沿用该文件已有的 `buildPromptMaterial` / `buildComposeSystemPrompt` import）：

```ts
describe('多人物与系统角色', () => {
  it('素材含主体人数行', () => {
    const material = buildPromptMaterial({ draft: { meta: { subjectCount: 2, category: 'portrait' } }, research: [] });
    expect(material).toContain('画面主体人数：2');
  });

  it('双人单姿势不再写「只有一个人物」', () => {
    const material = buildPromptMaterial({
      draft: { meta: { subjectCount: 2, category: 'portrait' }, singlePose: true, pose: { name: '并肩', description: '并肩站立' } },
      research: [],
    });
    expect(material).toContain('画面中有两位人物');
    expect(material).not.toContain('画面中只有一个人物');
  });

  it('系统角色按大类派生，人像保持默认', () => {
    expect(buildComposeSystemPrompt('portrait')).toContain('顶级人像摄影艺术指导');
    expect(buildComposeSystemPrompt('landscape')).toContain('顶级风景摄影艺术指导');
    expect(buildComposeSystemPrompt(undefined)).toContain('顶级人像摄影艺术指导');
  });
});
```

- [ ] **Step 5: 运行确认失败**

Run: `pnpm --filter @lumira/backend exec jest image-prompt.composer.spec.ts`
Expected: FAIL —— 素材不含「画面主体人数」。

- [ ] **Step 6: composer 实现**

6a. import 补：

```ts
import { isSelfieDraft, subjectCountOfDraft, describeSubjectCount } from './image-prompt.builder';
```

6b. 把 `COMPOSE_SYSTEM_PROMPT` 的定义拆出角色前缀（保持字符串内容完全不变，仅做变量拆分）：

```ts
const COMPOSE_ROLE_DEFAULT = '你是顶级人像摄影艺术指导兼生图提示词工程师。';

const COMPOSE_SYSTEM_PROMPT = `${COMPOSE_ROLE_DEFAULT}用户将提供一份结构化素材（模板基本信息 / 构图与机位 / 本张姿势 / 网络趋势参考 / 照片参数 / 生图要求），请把它们整理成一段高质量的中文生图提示词，最终喂给文生图模型。
```

（其余规则文本原样保留；只把首句抽出为模板变量。）

6c. `buildComposeSystemPrompt` 改为：

```ts
/** 供测试与调用方读取最终系统提示词（角色按一级大类派生；人像/未知保持默认） */
export function buildComposeSystemPrompt(categoryKey?: string): string {
  const subject = categoryKey !== undefined ? CATEGORY_SUBJECT_LABELS[categoryKey] : undefined;
  if (!subject || subject === '人像') return COMPOSE_SYSTEM_PROMPT;
  return COMPOSE_SYSTEM_PROMPT.replace(
    COMPOSE_ROLE_DEFAULT,
    `你是顶级${subject}摄影艺术指导兼生图提示词工程师。`,
  );
}
```

6d. `buildPromptMaterial` 的【模板基本信息】区（L226-240）插入主体人数行，放在 `- 主体类型：` 之后：

```ts
  if (subject) infoLines.push(`- 主体类型：${subject}`);
  const subjectCount = subjectCountOfDraft(draft);
  infoLines.push(`- 画面主体人数：${subjectCount}`);
```

6e. 在 `buildPromptMaterial` 顶部（`const isSinglePose = draft.singlePose === true;` 附近）无需新增变量（`subjectCount` 已在 6d 定义于 ① 区，作用域覆盖后续 ⑥ 区）。

6f. 把 L352-362 的 `if (isSinglePose) { ... }` 整块替换为：

```ts
  if (isSinglePose) {
    reqLines.push(`- ${describeSubjectCount(subjectCount)}，只呈现上述「本张姿势」；不要合并多个姿势，不要生成连拍、多宫格或姿势对比图`);
    const allowInconsistent = consistency.mode === 'loose';
    if (!allowInconsistent) {
      reqLines.push(
        subjectCount >= 2
          ? '- 参考图是同一组人物的同一套模板：严格复用参考图中每位人物的长相、服装、发型，以及人物之间的相对位置与互动关系，还有场景、道具、光线和摄影风格；本张只改变姿势'
          : consistency.anchor === 'first'
            ? '- 参考图是同一套模板的第一张姿势图：严格复用参考图中的同一人物长相、服装、发型、体型，以及场景、道具、光线和摄影风格；本张只改变姿势'
            : '- 同一套模板的连续拍摄：保持同一人物的长相、服装、发型、体型，以及场景、道具、光线和摄影风格一致；本张只改变姿势',
      );
    }
  }
```

6g. `composeImagePrompt` 里把系统提示改为按大类派生：

```ts
export async function composeImagePrompt(
  textEndpoint: LlmEndpoint,
  input: PromptComposeInput,
  fallbackPrompt: string,
): Promise<ComposeResult> {
  try {
    const meta = isPlainObject(input.draft.meta) ? input.draft.meta : {};
    const classification = isPlainObject(meta.classification) ? meta.classification : {};
    const categoryKey = toStr(classification.type) ?? toStr(meta.category);
    const out = await textChat(textEndpoint, {
      systemPrompt: buildComposeSystemPrompt(categoryKey),
      userText: buildPromptMaterial(input),
      temperature: 0.4,
      timeoutMs: 300_000,
    });
    const trimmed = out.trim();
    if (!trimmed) return { prompt: fallbackPrompt, composed: false };
    return { prompt: trimmed, composed: true };
  } catch {
    return { prompt: fallbackPrompt, composed: false };
  }
}
```

- [ ] **Step 7: 运行确认通过**

Run: `pnpm --filter @lumira/backend exec jest image-prompt.builder.spec.ts image-prompt.composer.spec.ts`
Expected: PASS。

- [ ] **Step 8: 提交并双远程推送**

```bash
git add lumira-server/packages/backend/src/modules/ai/image-prompt.builder.ts lumira-server/packages/backend/src/modules/ai/image-prompt.builder.spec.ts lumira-server/packages/backend/src/modules/ai/image-prompt.composer.ts lumira-server/packages/backend/src/modules/ai/image-prompt.composer.spec.ts
git commit -m "feat(ai): 生图提示词支持多人物并按一级大类派生系统角色"
git push origin master
git push github master
```

---

## Task 4: 英文写实锚点去噪（`image-client.ts`）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/image-client.ts:162-167`
- Test: `lumira-server/packages/backend/src/modules/ai/image-client.spec.ts`

**Interfaces:**
- Consumes: 无
- Produces: `ENGLISH_PHOTOREAL_ANCHOR` 新文案（无噪点/瑕疵词）；`withEnglishPhotorealism` 签名不变

- [ ] **Step 1: 写失败用例**

在 `image-client.spec.ts` 追加（若未导出 `withEnglishPhotorealism`，请在本 Task 一并从 `image-client.ts` 保持其既有导出）：

```ts
import { withEnglishPhotorealism } from './image-client';

describe('英文写实锚点', () => {
  it('不含噪点与瑕疵要求', () => {
    const anchor = withEnglishPhotorealism('一段中文提示词');
    expect(anchor).toContain('一段中文提示词');
    expect(anchor.toLowerCase()).not.toContain('sensor noise');
    expect(anchor.toLowerCase()).not.toContain('noise');
    expect(anchor.toLowerCase()).not.toContain('uneven skin tone');
    expect(anchor).not.toContain('candid imperfect framing');
  });

  it('保留高清细节要求', () => {
    const anchor = withEnglishPhotorealism('x');
    expect(anchor).toContain('visible pores');
    expect(anchor).toContain('fabric fibers');
  });
});
```

- [ ] **Step 2: 运行确认失败**

Run: `pnpm --filter @lumira/backend exec jest image-client.spec.ts`
Expected: FAIL —— 命中 `sensor noise`。

- [ ] **Step 3: 实现**

把 `image-client.ts` L162-163 的 `ENGLISH_PHOTOREAL_ANCHOR` 常量值替换为：

```ts
const ENGLISH_PHOTOREAL_ANCHOR =
  'Photorealistic photograph taken with a real camera: highly detailed realistic skin texture with visible pores and fine vellus hair in sharp focus; distinguishable fabric fibers and weave; individual strands of hair; directional natural light with realistic falloff and layered shadow transitions; clean and crisp image with controlled noise and no grain. Strictly not anime, not illustration, not painting, not 3D render, not AI-retouched; no airbrushed or plastic skin.';
```

- [ ] **Step 4: 运行确认通过**

Run: `pnpm --filter @lumira/backend exec jest image-client.spec.ts`
Expected: PASS。

> 若既有用例断言 `ENGLISH_PHOTOREAL_ANCHOR` 旧文案（含 `slight sensor noise`），请把该断言更新为新文案的等价关键词（`highly detailed realistic skin texture`），不要放宽断言。

- [ ] **Step 5: 提交并双远程推送**

```bash
git add lumira-server/packages/backend/src/modules/ai/image-client.ts lumira-server/packages/backend/src/modules/ai/image-client.spec.ts
git commit -m "fix(ai): 英文写实锚点去除 sensor noise 与瑕疵描述，改为高清细节要求"
git push origin master
git push github master
```

---

## Task 5: 提示词构建器去噪写实（builder / composer / harden）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/image-prompt.builder.ts:38-39, 217-220, 265-277`
- Modify: `lumira-server/packages/backend/src/modules/ai/image-prompt.composer.ts:305-308, 342-346, 347-351`
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.ts:81-93`
- Test: 上述三个模块的既有 spec

**Interfaces:**
- Consumes: 无
- Produces: 无新增导出（仅文案）；`GRAIN_STRONG_THRESHOLD` 从 builder 删除

- [ ] **Step 1: 写失败用例**

在 `image-prompt.builder.spec.ts` 追加：

```ts
describe('去噪写实', () => {
  it('草稿带 grain 也不再输出颗粒感', () => {
    const draft = fullDraft();
    (draft as any).postProcess = { grain: 40, lut: 'none' };
    const prompt = buildImagePrompt(draft);
    expect(prompt).not.toContain('颗粒感');
    expect(prompt).not.toContain('噪点');
  });

  it('人像不再写缺陷集合，改为细节分辨力', () => {
    const prompt = buildImagePrompt(fullDraft());
    expect(prompt).not.toContain('肤色不均匀');
    expect(prompt).not.toContain('T 区微泛油光');
    expect(prompt).not.toContain('碎发');
    expect(prompt).toContain('皮肤纹理清晰不糊');
  });
});
```

在 `image-prompt.composer.spec.ts` 追加：

```ts
describe('去噪写实', () => {
  it('带 grain 也不再输出颗粒感', () => {
    const material = buildPromptMaterial({
      draft: { meta: { category: 'portrait' }, singlePose: true, pose: { name: 'a', description: 'b' }, postProcess: { grain: 40 } },
      research: [],
    });
    expect(material).not.toContain('颗粒感');
  });

  it('不再强制写「画面带自然噪点」', () => {
    const material = buildPromptMaterial({ draft: { meta: { category: 'portrait' } }, research: [] });
    expect(material).not.toContain('画面带自然噪点');
    expect(material).toContain('噪点受控');
  });
});
```

在 `ai-generate-image.service.spec.ts` 追加（沿用该文件已有的 `hardenPhotoRealism` import）：

```ts
describe('hardenPhotoRealism 去噪', () => {
  it('不引入颗粒/噪点要求，且声明禁止噪点', () => {
    const out = hardenPhotoRealism('一段提示词', {});
    expect(out).not.toContain('自然噪点');
    expect(out).toContain('高清干净');
    expect(out).toContain('禁止颗粒与噪点');
  });
});
```

- [ ] **Step 2: 运行确认失败**

Run: `pnpm --filter @lumira/backend exec jest image-prompt.builder.spec.ts image-prompt.composer.spec.ts ai-generate-image.service.spec.ts`
Expected: FAIL（颗粒感 / 缺陷词 / `画面带自然噪点` 仍存在）。

- [ ] **Step 3: builder 去噪**

3a. 删除 L38-39 常量：

```ts
/** 颗粒感强度分界：grain ≥ 30 描述为「明显」，否则「轻微」 */
const GRAIN_STRONG_THRESHOLD = 30;
```

3b. 删除 L217-220 的 grain 段：

```ts
  const grain = postProcess.grain;
  if (typeof grain === 'number' && Number.isFinite(grain) && grain > 0) {
    segments.push(`带${grain >= GRAIN_STRONG_THRESHOLD ? '明显' : '轻微'}颗粒感`);
  }
```

（同时把 ⑥ 的注释从「LUT 中文标签（none/未知 key 跳过）+ 颗粒感」改为「LUT 中文标签（none/未知 key 跳过）；grain 仅作 App 后期参数，不写入生图提示词」。）

3c. 把 L265-277 的 portrait 段替换为：

```ts
    if (subject === 'portrait') {
      segments.push(
        '人物皮肤纹理清晰不糊：毛孔与细小绒毛可辨、肤色过渡自然，不做美颜磨皮，无塑料质感',
      );
      segments.push(
        '头发发丝根根分明、有自然蓬松与层次；衣物布料纤维与褶皱纹理可辨',
      );
      segments.push(
        '光影有明确方向与衰减层次：面部明暗过渡自然可信、有受光面与暗部的层次，避免平光无层次',
      );
      segments.push(
        '五官、头发、衣服纹理与手部细节贴合真实人体结构，无肢体或手指畸变；姿势是经过设计的：身体朝向与重心明确、肩胯有错位、双手落点具体，画面水平',
      );
      segments.push(
        '避免典型 AI 感：不过度磨皮、不完美对称脸、不锥子脸卡通化、不镜面质感、不影棚式浮夸打光、不精致摆拍',
      );
    } else if (subject) {
      segments.push('画面像随手抓拍的实拍照片而非精修广告图，颜色与光线自然不夸张，无塑料或镜面质感');
    }
```

- [ ] **Step 4: composer 去噪**

4a. 删除 L305-308 的 grain 段：

```ts
  const grain = postProcess.grain;
  if (typeof grain === 'number' && Number.isFinite(grain) && grain > 0) {
    paramLines.push(`- 颗粒感：${grain >= 30 ? '明显' : '轻微'}`);
  }
```

4b. 把 L342-346 的两条强制参数行替换为：

```ts
  reqLines.push(
    selfie
      ? '- 必须写入具体摄影参数：前置摄像头等效焦距与光圈、快门与感光度、白平衡轻微偏移；弱光场景下要求画面干净、细节不糊、噪点受控'
      : '- 必须写入具体摄影参数：镜头与光圈（如 85mm f/1.8 浅景深或手机主摄直出）、快门与感光度、白平衡轻微偏移；弱光场景下要求画面干净、细节不糊、噪点受控',
  );
```

4c. 把 L347-351 的 portrait 段替换为：

```ts
  if (categoryKey === 'portrait') {
    reqLines.push('- 人物皮肤纹理清晰：毛孔与细小绒毛可辨、肤色过渡自然，不做美颜磨皮，无塑料或镜面质感');
    reqLines.push('- 头发发丝分明有层次，衣物布料纤维与褶皱纹理可辨；光影有明确方向与衰减层次，明暗过渡自然');
    reqLines.push('- 表情松弛自然像被抓拍的瞬间；五官头发手部贴合真实人体结构无畸变；构图讲究：主体落位与留白经设计、肢体线条舒展有延伸感');
    reqLines.push('- 禁止：动漫、二次元、漫画、插画、CG、3D 渲染；禁止磨皮过度均匀、塑料或镜面质感、完美对称脸、锥子脸、高饱和炫彩、精致摆拍；禁止无源光、不可能透视与姿势、肢体与面部畸变');
  }
```

4d. 同步检查 `COMPOSE_SYSTEM_PROMPT` 规则 4c（L40）里的「肤色不均匀、T 区微泛油光而脸颊哑光…头发有几缕没梳好的碎发」，替换为：

```ts
   c. 人物的质感写成高清写实的细节：皮肤纹理清晰不糊（毛孔与绒毛可辨、肤色过渡自然、不做美颜磨皮），发丝分明有层次，衣物布料纤维与褶皱纹理可辨；
```

- [ ] **Step 5: hardenPhotoRealism 去噪**

把 `ai-generate-image.service.ts` 的 `PHOTO_REALISM_BASELINE_SUFFIX` 替换为：

```ts
export const PHOTO_REALISM_BASELINE_SUFFIX =
  '真实照片媒介，不是动漫、二次元、漫画、插画、赛璐璐、厚涂、CG、3D 渲染、油画或游戏立绘；' +
  '真实人体结构与解剖，无肢体、手指与面部畸变；可实拍复现，无无源光、无不可能透视与姿势；' +
  '高清干净、细节清晰（皮肤纹理与布料纤维可辨），真实材质，环境光有方向与衰减层次、阴影过渡自然。' +
  '禁止：动漫、二次元、漫画、插画；禁止无源光与不可能透视；禁止肢体与面部畸变；禁止颗粒与噪点；禁止磨皮过度均匀。';
```

并把 `RETOUCH_REALISM_SUFFIX.none` 改为：

```ts
  none: '自然环境光与生活化瞬间感，保留真实的环境明暗关系，画面干净无颗粒。',
```

- [ ] **Step 6: 运行确认通过**

Run: `pnpm --filter @lumira/backend exec jest image-prompt.builder.spec.ts image-prompt.composer.spec.ts ai-generate-image.service.spec.ts`
Expected: PASS。

- [ ] **Step 7: 全量后端测试**

Run: `pnpm --filter @lumira/backend test`
Expected: PASS（既有断言若比对旧瑕疵文案，更新为新文案等价关键词）。

- [ ] **Step 8: 提交并双远程推送**

```bash
git add lumira-server/packages/backend/src/modules/ai/image-prompt.builder.ts lumira-server/packages/backend/src/modules/ai/image-prompt.composer.ts lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.ts lumira-server/packages/backend/src/modules/ai/image-prompt.builder.spec.ts lumira-server/packages/backend/src/modules/ai/image-prompt.composer.spec.ts lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.spec.ts
git commit -m "fix(ai): 提示词全面去噪转高清写实，移除颗粒与瑕疵要求"
git push origin master
git push github master
```

---

## Task 6: `ResearchBrief` 后端透传（任务结果 + 状态接口）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-analyze.service.ts:32-41, 119-141, 201-214`
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-analyze-task.service.ts`（任务结果类型）
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-templates.controller.ts:48-61`
- Test: `lumira-server/packages/backend/src/modules/ai/ai-analyze.service.spec.ts`

**Interfaces:**
- Consumes: `TrendResearchService.research()` 已返回的 `brief`（`ResearchBrief | null`）
- Produces:
  - `AiAnalyzeResult.brief?: ResearchBrief | null`
  - 状态接口响应新增 `researchBrief: ResearchBrief | null`

- [ ] **Step 1: 写失败用例**

在 `ai-analyze.service.spec.ts` 中，找到 mock `trendResearch.research` 的用例（当前形如 `{ items: [], brief: null, sourceErrors: [] }`），新增一条断言 `brief` 被回传的用例：

```ts
  it('识别结果透传结构化趋势结论 brief', async () => {
    const svc = makeService(); // 沿用本文件既有构造 helper
    (svc as any).trendResearch.research = jest.fn().mockResolvedValue({
      items: [{ source: 'searxng', title: 't', snippet: 's', keywords: [] }],
      brief: { summary: '暖调为主流', themes: ['秋季人像'], styles: [], colorLight: [], visualElements: [], seasons: [], poseIdeas: ['侧身回眸'], sources: [] },
      sourceErrors: [],
    });
    const r = await svc.analyze(undefined, '秋日人像模板', {});
    expect(r.brief?.poseIdeas).toEqual(['侧身回眸']);
  });
```

> 若本文件没有 `makeService()` helper，请照抄同文件其他用例的构造方式（`new AiAnalyzeService(...)` 或 `Test.createTestingModule`），保持 mock 结构一致。

- [ ] **Step 2: 运行确认失败**

Run: `pnpm --filter @lumira/backend exec jest ai-analyze.service.spec.ts`
Expected: FAIL —— `r.brief` 为 `undefined`。

- [ ] **Step 3: 实现**

3a. `ai-analyze.service.ts` import 补类型：

```ts
import type { ResearchBrief } from './trend-research/research-brief';
```

3b. `AiAnalyzeResult` 增加字段：

```ts
  /** 趋势研究二次整理后的结构化结论（供生图阶段复用）；未启用/未命中 → null */
  brief?: ResearchBrief | null;
```

3c. 在 `let research: ResearchItem[] = [];` 之后新增：

```ts
    let researchBrief: ResearchBrief | null = null;
```

3d. 在 `research = r.items;` 附近把 brief 存下：

```ts
          research = r.items;
          researchBrief = r.brief ?? null;
          const brief = r.brief ?? null;
          researchDigest = brief ? renderResearchBrief(brief) : buildResearchDigest(r.items);
```

3e. 两条返回路径补 `brief`：

```ts
      return { draft: r.draft, warnings: r.warnings, trace: r.trace, raw: json, research: r.research ?? [], brief: researchBrief };
```

```ts
    return { ...normalized, trace: [], raw: json, research, brief: researchBrief };
```

3f. `ai-analyze-task.service.ts`：找到存放 `AiAnalyzeResult` 的任务结果类型（`result?: AiAnalyzeResult` 或等价），确认其直接复用 `AiAnalyzeResult`；若为显式独立接口，则补 `brief?: ResearchBrief | null`。

3g. `ai-templates.controller.ts` 的 `getAnalyzeTask` 返回体增加一行：

```ts
      researchBrief: task.result?.brief ?? null,
```

（放在 `research: task.result?.research ?? [],` 之后。）

- [ ] **Step 4: 运行确认通过**

Run: `pnpm --filter @lumira/backend exec jest ai-analyze.service.spec.ts ai-analyze-task.service.spec.ts`
Expected: PASS。

- [ ] **Step 5: 提交并双远程推送**

```bash
git add lumira-server/packages/backend/src/modules/ai/ai-analyze.service.ts lumira-server/packages/backend/src/modules/ai/ai-analyze.service.spec.ts lumira-server/packages/backend/src/modules/ai/ai-analyze-task.service.ts lumira-server/packages/backend/src/modules/ai/ai-templates.controller.ts
git commit -m "feat(ai): 识别任务结果与状态接口透传结构化趋势结论 brief"
git push origin master
git push github master
```

---

## Task 7: admin 透传 `researchBrief` 到生图请求

**Files:**
- Modify: `lumira-server/packages/admin/src/types/admin.ts:691-708`
- Modify: `lumira-server/packages/admin/src/lib/ai-task.ts:59-84`
- Modify: `lumira-server/packages/admin/src/components/ai-create/wizard.tsx`（调用 `generateAiPoseImages` 的入参处）
- Modify: `lumira-server/packages/admin/src/components/ai-create/step-cover.tsx`（若其独立调用生图）

**Interfaces:**
- Consumes: 状态接口 `researchBrief`（Task 6）
- Produces:
  - `AiResearchBrief` 类型（与后端 `ResearchBrief` 对齐）
  - `generateAiPoseImages({ ..., researchBrief })`：`research` 表单字段改传 `JSON.stringify({ items: research, brief: researchBrief })`

- [ ] **Step 1: 类型定义（`admin/src/types/admin.ts`）**

在 `AiAnalyzeStatusResult` 之前新增：

```ts
/** 趋势研究二次整理后的结构化结论（与后端 ResearchBrief 对齐） */
export interface AiResearchBrief {
  summary: string;
  themes: string[];
  styles: string[];
  colorLight: string[];
  visualElements: string[];
  seasons: string[];
  poseIdeas: string[];
  sources: { title: string; url?: string }[];
}
```

在 `AiAnalyzeStatusResult` 中、`research?: AiResearchRef[];` 之后新增：

```ts
  /** 趋势研究结构化结论（生图阶段复用；旧后端/未启用时缺省） */
  researchBrief?: AiResearchBrief | null;
```

- [ ] **Step 2: `ai-task.ts` 改造**

2a. import 补 `AiResearchBrief`。

2b. `generateAiPoseImages` 的 options 增加字段：

```ts
  /** 趋势研究结构化结论（与 items 同源，透传给后端生图提示词组织器） */
  researchBrief?: AiResearchBrief | null;
```

2c. 解构补 `researchBrief`：

```ts
  const { draft, referenceFile, extraPrompt, research, researchBrief, signal, onResult, onProgress, onEvents } = options;
```

2d. 改写 research 表单字段：

```ts
    if ((research && research.length > 0) || researchBrief) {
      fd.set('research', JSON.stringify({ items: research ?? [], brief: researchBrief ?? null }));
    }
```

- [ ] **Step 3: 调用点接线（`wizard.tsx` / `step-cover.tsx`）**

在调用 `generateAiPoseImages` 的地方，把识别任务返回的 `researchBrief` 一并传入。识别结果来自 `pollAiAnalyzeTask` 的返回值，形如：

```ts
  const researchBrief = analyzeResult.researchBrief ?? null;
```

并在调用处补参数：

```ts
      research: analyzeResult.research ?? [],
      researchBrief,
```

> 若 `analyzeResult` 在该作用域已被解构为 `research`，请以实际变量名为准接线；关键是让 `researchBrief` 与 `research` 同源（同一次识别任务）。

- [ ] **Step 4: 构建校验**

Run: `pnpm --filter @lumira/admin build`
Expected: 构建成功（无类型错误）。

- [ ] **Step 5: 提交并双远程推送**

```bash
git add lumira-server/packages/admin/src/types/admin.ts lumira-server/packages/admin/src/lib/ai-task.ts lumira-server/packages/admin/src/components/ai-create/wizard.tsx lumira-server/packages/admin/src/components/ai-create/step-cover.tsx
git commit -m "feat(admin): 生图请求透传识别阶段的结构化趋势结论"
git push origin master
git push github master
```

---

## Task 8: composer 消费 `brief`（后端解析 + 趋势要点区块）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.ts:145-163`
- Modify: `lumira-server/packages/backend/src/modules/ai/image-prompt.composer.ts:27-46, 53-60, 284-290`
- Test: `lumira-server/packages/backend/src/modules/ai/image-prompt.composer.spec.ts`、`ai-generate-image.service.spec.ts`

**Interfaces:**
- Consumes: `{ items, brief }` 形态的 `research` 表单字段（Task 7）；`ResearchBrief`（`renderResearchBrief`）
- Produces: `PromptComposeInput.brief?: ResearchBrief | null`

- [ ] **Step 1: 写失败用例（composer）**

在 `image-prompt.composer.spec.ts` 追加：

```ts
describe('趋势要点落地', () => {
  it('brief 非空时输出【趋势要点】区块', () => {
    const material = buildPromptMaterial({
      draft: { meta: { category: 'portrait' } },
      research: [],
      brief: { summary: '', themes: [], styles: [], colorLight: ['暖调侧逆光'], visualElements: [], seasons: [], poseIdeas: ['侧身回眸，手扶帽檐'], sources: [] },
    });
    expect(material).toContain('【趋势要点（结构化）】');
    expect(material).toContain('侧身回眸，手扶帽檐');
    expect(material).toContain('暖调侧逆光');
  });

  it('brief 为空时不输出该区块', () => {
    const material = buildPromptMaterial({ draft: { meta: { category: 'portrait' } }, research: [] });
    expect(material).not.toContain('【趋势要点（结构化）】');
  });

  it('系统规则要求姿势灵感逐条落实', () => {
    expect(buildComposeSystemPrompt()).toContain('姿势灵感');
  });
});
```

- [ ] **Step 2: 运行确认失败**

Run: `pnpm --filter @lumira/backend exec jest image-prompt.composer.spec.ts`
Expected: FAIL —— 素材不含【趋势要点（结构化）】。

- [ ] **Step 3: composer 实现**

3a. import 补：

```ts
import { renderResearchBrief } from './trend-research/research-brief';
import type { ResearchBrief } from './trend-research/research-brief';
```

3b. `PromptComposeInput` 增加：

```ts
  /** 趋势研究结构化结论（识别阶段透传；姿势灵感/视觉元素须落实到画面） */
  brief?: ResearchBrief | null;
```

3c. `buildPromptMaterial` 解构补 `brief`：

```ts
  const { draft, extraPrompt } = input;
  const brief = input.brief ?? null;
  const research = Array.isArray(input.research) ? input.research : [];
```

（删除原有的 `const research = Array.isArray(input.research) ? input.research : [];` 重复行。）

3d. 在【网络趋势参考】区块（现 L284-290）之后插入：

```ts
  // ④.5 趋势要点（结构化）：二次整理结论，姿势灵感与视觉元素必须落到本张画面
  if (brief) {
    const briefText = renderResearchBrief(brief);
    if (briefText) {
      sections.push(
        `【趋势要点（结构化）】（识别阶段联网检索的二次整理结论；姿势灵感必须逐条落实为本张姿势，视觉元素落到服装/道具/场景）\n${briefText}`,
      );
    }
  }
```

3e. 把 `COMPOSE_SYSTEM_PROMPT` 的规则 6 整条替换为：

```ts
6. 网络趋势参考与【趋势要点】中的有效信息要转化为具体可见的画面描述融入提示词，让画面贴合当下审美：【趋势要点】的「姿势灵感」必须逐条落实为本张姿势可见的身体朝向、重心、手部落点与视线；「视觉元素」落实为服装 / 道具 / 场景的可见细节；与创作要求冲突、明显无效或只是排版残留（标题符号 / 表格 / 来源域名）的忽略。
```

- [ ] **Step 4: 写失败用例（后端解析）**

在 `ai-generate-image.service.spec.ts` 追加：

```ts
describe('research 两种形态解析', () => {
  it('对象形态 {items, brief} 时 brief 透传到组织器', async () => {
    const svc = makeService(); // 沿用本文件既有构造 helper
    const composeSpy = jest.spyOn(composerModule, 'composeImagePrompt');
    await svc.generate(undefined, JSON.stringify({ meta: { category: 'portrait' } }), null, JSON.stringify({
      items: [{ source: 'searxng', title: 't', snippet: 's', keywords: [] }],
      brief: { summary: '', themes: [], styles: [], colorLight: [], visualElements: [], seasons: [], poseIdeas: ['p'], sources: [] },
    }));
    expect(composeSpy.mock.calls[0][1]).toMatchObject({ brief: { poseIdeas: ['p'] } });
  });

  it('数组形态（旧前端）兼容为 items 且 brief 为 null', async () => {
    const svc = makeService();
    const composeSpy = jest.spyOn(composerModule, 'composeImagePrompt');
    await svc.generate(undefined, JSON.stringify({ meta: { category: 'portrait' } }), null, JSON.stringify([{ source: 'x', title: 't', snippet: 's', keywords: [] }]));
    expect(composeSpy.mock.calls[0][1]).toMatchObject({ brief: null });
  });
});
```

> 若该文件未直接 mock `composeImagePrompt`，请按同文件既有 spy/mock 方式编写（例如注入 mock 的 `aiConfigService` + 对 `composeImagePrompt` 所在模块 `jest.mock`）。

- [ ] **Step 5: 运行确认失败**

Run: `pnpm --filter @lumira/backend exec jest ai-generate-image.service.spec.ts`
Expected: FAIL —— `brief` 未透传。

- [ ] **Step 6: 服务实现（`ai-generate-image.service.ts`）**

把 L145-163 的解析与调用替换为：

```ts
    // 2.5 解析研究结果 JSON：兼容旧前端（数组）与新前端（{ items, brief }）；非法静默降级，不阻断生图
    let research: ResearchItem[] = [];
    let researchBrief: ResearchBrief | null = null;
    if (researchJson) {
      try {
        const parsed: unknown = JSON.parse(researchJson);
        if (Array.isArray(parsed)) {
          research = parsed as ResearchItem[];
        } else if (isPlainObject(parsed)) {
          if (Array.isArray(parsed.items)) research = parsed.items as ResearchItem[];
          researchBrief = (parsed.brief ?? null) as ResearchBrief | null;
        }
      } catch {
        // 非法 JSON → 无研究参考，走纯草稿素材
      }
    }

    // 3. 机械拼接 prompt 作为兜底；结构化素材交文本模型整理为最终生图提示词（失败回退拼接值）
    const fallbackPrompt = buildImagePrompt(draft, extraPrompt);
    const { prompt } = await composeImagePrompt(
      cfg.text,
      { draft, research, brief: researchBrief, extraPrompt },
      fallbackPrompt,
    );
```

并在该文件补 import：

```ts
import type { ResearchBrief } from './trend-research/research-brief';
```

- [ ] **Step 7: 运行确认通过**

Run: `pnpm --filter @lumira/backend exec jest image-prompt.composer.spec.ts ai-generate-image.service.spec.ts`
Expected: PASS。

- [ ] **Step 8: 全量后端测试 + 类型检查**

Run: `pnpm --filter @lumira/backend test`
Run: `pnpm --filter @lumira/backend exec tsc --noEmit`
Expected: 全部通过。

- [ ] **Step 9: 提交并双远程推送**

```bash
git add lumira-server/packages/backend/src/modules/ai/image-prompt.composer.ts lumira-server/packages/backend/src/modules/ai/image-prompt.composer.spec.ts lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.ts lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.spec.ts
git commit -m "feat(ai): 生图提示词消费结构化趋势结论，姿势灵感落实为本张姿势"
git push origin master
git push github master
```

---

## Task 9: 社交平台站点限定检索

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-config.service.ts:488-495`
- Modify: `lumira-server/packages/backend/src/modules/ai/trend-research/trend-research.service.ts:88-125`
- Modify: `lumira-server/packages/admin/src/components/ai-config-form.tsx:986-999`（站点限定输入框的说明文案）
- Test: `lumira-server/packages/backend/src/modules/ai/ai-config.service.spec.ts`、`trend-research` 既有 spec

**Interfaces:**
- Consumes: `SearchSourceConfig.site`（已存在）
- Produces: searxng 模式下、`searchSite` 为空时返回的多来源数组（name 分别为 `searxng-xhs` / `searxng-douyin` / `searxng-weibo` / `searxng-zhihu` / `searxng-all`）

- [ ] **Step 1: 写失败用例**

在 `ai-config.service.spec.ts` 追加（按本文件既有 db mock 方式）：

```ts
  it('searxng 且站点限定为空：返回社交平台默认来源集 + 全站兜底', async () => {
    // 按本文件既有方式构造 row：searchEnabled=1, searchProvider='searxng', searchSite=null
    const cfg = await svc.getSearchConfig();
    const names = (cfg?.sources ?? []).map((s) => s.name);
    expect(names).toContain('searxng-xhs');
    expect(names).toContain('searxng-all');
    const xhs = (cfg?.sources ?? []).find((s) => s.name === 'searxng-xhs');
    expect(xhs?.site).toBe('xiaohongshu.com');
  });

  it('searxng 且显式填了站点限定：只返回单来源（向后兼容）', async () => {
    // row.searchSite = 'zhihu.com'
    const cfg = await svc.getSearchConfig();
    expect((cfg?.sources ?? []).length).toBe(1);
    expect((cfg?.sources ?? [])[0].site).toBe('zhihu.com');
  });
```

在 `trend-research` 的 spec（`trend-research.service.spec.ts`，若无则新建于 `src/modules/ai/trend-research/trend-research.service.spec.ts`）追加：

```ts
  it('reorganizeQuery 提示词要求补充社交平台语感词', async () => {
    // 按本文件既有的 textChat mock 方式捕获 systemPrompt
    await svc.reorganizeQuery('秋天的情侣照');
    const systemPrompt = capturedSystemPrompt();
    expect(systemPrompt).toContain('小红书');
    expect(systemPrompt).toContain('出片');
  });
```

> 若 `trend-research.service.spec.ts` 不存在，请新建并只写这一个用例（mock `aiConfigService.getActiveConfig` 返回 `{ text: { provider: 'x', baseUrl: 'http://x', apiKey: 'k', model: 'm' } }`，mock `textChat` 捕获入参并返回 `'{"query":"秋日 情侣照 出片"}'`）。

- [ ] **Step 2: 运行确认失败**

Run: `pnpm --filter @lumira/backend exec jest ai-config.service.spec.ts`
Expected: FAIL —— 当前只返回单来源 `searxng`。

- [ ] **Step 3: `ai-config.service.ts` 实现**

把 L488-495 的 searxng 分支替换为：

```ts
      } else if (name === 'searxng') {
        const baseUrl = row.searchBaseUrl ?? undefined;
        const apiKey = row.searchApiKey ?? undefined;
        const explicitSite = row.searchSite?.trim();
        if (explicitSite) {
          // 显式指定站点：保持单来源（向后兼容旧配置）
          sources.push({ name, provider: 'searxng', baseUrl, apiKey, site: explicitSite });
        } else {
          // 未指定站点：默认走社交平台来源集（小红书为主，抖音/微博/知乎补充）+ 全站兜底，并行检索、单源失败降级
          const platforms: { name: string; site: string }[] = [
            { name: 'searxng-xhs', site: 'xiaohongshu.com' },
            { name: 'searxng-douyin', site: 'douyin.com' },
            { name: 'searxng-weibo', site: 'weibo.com' },
            { name: 'searxng-zhihu', site: 'zhihu.com' },
          ];
          for (const p of platforms) {
            sources.push({ name: p.name, provider: 'searxng', baseUrl, apiKey, site: p.site });
          }
          sources.push({ name: 'searxng-all', provider: 'searxng', baseUrl, apiKey });
        }
      }
```

- [ ] **Step 4: `reorganizeQuery` 追加平台语感词**

把 `trend-research.service.ts` L102-103 的规则 1 整行替换为：

```ts
              '1. 提取可检索的核心名词短语：风格、场景、光线、机位、姿势、氛围、模特类型等，最多 6 个关键词组；'
                + '并补充社交平台（小红书 / 抖音）常见语感词（如「穿搭」「拍照姿势」「出片」「氛围感」「怎么拍」），提高在平台图文内容中的命中率。',
```

- [ ] **Step 5: admin 表单说明文案**

把 `ai-config-form.tsx` 中「站点限定（可选）」输入框下方的说明改为（若无说明行则在输入框后新增一行 `<p>`）：

```tsx
                  <p className="text-xs text-muted-foreground">
                    留空则默认检索小红书、抖音、微博、知乎等社交平台（小红书为主）并辅以全站兜底；填写后仅检索该站点。
                  </p>
```

- [ ] **Step 6: 运行确认通过**

Run: `pnpm --filter @lumira/backend exec jest ai-config.service.spec.ts`
Expected: PASS。

- [ ] **Step 7: admin 构建**

Run: `pnpm --filter @lumira/admin build`
Expected: 构建成功。

- [ ] **Step 8: 提交并双远程推送**

```bash
git add lumira-server/packages/backend/src/modules/ai/ai-config.service.ts lumira-server/packages/backend/src/modules/ai/ai-config.service.spec.ts lumira-server/packages/backend/src/modules/ai/trend-research/trend-research.service.ts lumira-server/packages/backend/src/modules/ai/trend-research/trend-research.service.spec.ts lumira-server/packages/admin/src/components/ai-config-form.tsx
git commit -m "feat(ai): 检索来源默认限定到小红书等社交平台并补充平台语感词"
git push origin master
git push github master
```

---

## Task 10: admin Step1 人物数量控件

**Files:**
- Modify: `lumira-server/packages/admin/src/components/ai-create/wizard.tsx:107, 144, 224-232, 660-700`

**Interfaces:**
- Consumes: 后端 `ai-analyze` 端点接受 `subjectCount`（Task 2）
- Produces: analyze 请求的 `subjectCount` 表单字段（`'1'`~`'8'`；`'auto'` 不传，由 AI 推断）

- [ ] **Step 1: 发现现有高级输入区结构**

打开 `wizard.tsx`，定位三个位置并记录实际行号：
- `const [poseCount, setPoseCount] = useState('auto');`（约 L107）
- `const advancedFilledCount = ...`（约 L144）
- analyze 的 `FormData` 写入处 `if (poseCount !== 'auto') fd.set('poseCount', poseCount);`（约 L230）
- `poseCount` 的 `<Select>` 渲染处（约 L683）

- [ ] **Step 2: 新增状态**

在 `poseCount` 状态声明之后插入：

```tsx
  const [subjectCount, setSubjectCount] = useState('auto');
```

- [ ] **Step 3: 计入已填高级项**

把 `advancedFilledCount` 表达式改为：

```tsx
  const advancedFilledCount =
    (creationReq.trim() !== '' ? 1 : 0) + (poseCount !== 'auto' ? 1 : 0) + (subjectCount !== 'auto' ? 1 : 0);
```

- [ ] **Step 4: 写入 analyze 请求**

在 `if (poseCount !== 'auto') fd.set('poseCount', poseCount);` 之后插入：

```tsx
    if (subjectCount !== 'auto') fd.set('subjectCount', subjectCount);
```

- [ ] **Step 5: 渲染控件**

在 `poseCount` 的 `<Select>` 同级位置，照抄其结构新增一个「人物数量」选择器：

```tsx
                    <div className="space-y-1.5">
                      <label className="text-sm font-medium">人物数量</label>
                      <Select value={subjectCount} onValueChange={setSubjectCount} disabled={busy}>
                        <SelectTrigger>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="auto">自动判断</SelectItem>
                          <SelectItem value="1">1 人</SelectItem>
                          <SelectItem value="2">2 人（情侣 / 双人）</SelectItem>
                          <SelectItem value="3">3 人以上（全家福 / 合影）</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
```

> 外层容器、间距与标签样式请与相邻 `poseCount` 控件保持一致（如已有 `Label` 组件，用 `Label` 替代原生 `label`）。选项 `3` 代表「3 人及以上」，归一口径为 3。

- [ ] **Step 6: 构建校验**

Run: `pnpm --filter @lumira/admin build`
Expected: 构建成功（无类型错误）。

- [ ] **Step 7: 手工验证（可选但推荐）**

本地同时启动后端与 admin，进入 AI 一键生成模板，Step1 选择「2 人」，提交后确认：
- 网络请求 `ai-analyze` 的 multipart 含 `subjectCount=2`；
- 识别结果草稿 `meta.subjectCount === 2`。

- [ ] **Step 8: 提交并双远程推送**

```bash
git add lumira-server/packages/admin/src/components/ai-create/wizard.tsx
git commit -m "feat(admin): AI 一键生成 Step1 新增人物数量选择"
git push origin master
git push github master
```

---

## 收尾

- [ ] **全量验证**

Run: `pnpm --filter @lumira/backend test`
Run: `pnpm --filter @lumira/backend exec tsc --noEmit`
Run: `pnpm --filter @lumira/admin build`
Expected: 全部通过。

- [ ] **登记后续优化**

若实现过程中出现「先这样、后续再优化」的项（例如「高清写实为全局取向，部分胶片/复古风格档案的颗粒观感被一并去掉，后续按风格档案分档重新引入」），按 `AGENTS.md` 规则追加到 `docs/future-optimizations.md`（优先级 / 模块 / 优化点 / 背景动机 / 目标状态 / 状态标记），并 commit。

- [ ] **期2 说明**

期2（平台图片 → 视觉识别转文字 → 反哺姿势图 + 临时图片必删）不在本计划范围，待期1 验证后单独出 spec/plan。
