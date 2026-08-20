# 模板季节/天气/时段（ambience）元数据 + 短简介 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `templates` 表新增季节/天气/时段（ambience）结构化元数据列与短简介列，贯通共享类型、后端读写、Admin 后台表单，为后续季节/天气智能推荐提供数据基础。

**Architecture:** 后端 `templates` 表新增 `ambience_json`（存 `{seasons,weathers,timeTones}`）与 `short_desc` 两列，通过现有版本化 SQL 迁移执行器落地；共享类型 `@lumira/shared` 扩展 `TemplateAmbience`/`shortDesc`；`rowToMeta` 解析下发；Admin 表单新增短简介输入与三组多选，提交/回填同步。

**Tech Stack:** NestJS + Fastify + Drizzle ORM + MySQL 8；Next.js Admin + react-hook-form + zod + shadcn；pnpm monorepo（`@lumira/shared` / `@lumira/admin` / `@lumira/backend `）。

## Global Constraints

- 迁移采用 `src/database/migrations/NNN_xxx.sql` 版本化文件（`DatabaseService.runMigrations()` 启动时按文件名去重执行，幂等）。
- `ambience` 枚举值：seasons = `spring|summer|autumn|winter`；weathers = `sunny|cloudy|overcast|rain|snow|fog`；timeTones = `goldenHour|day|night|warm|cool`。展示中文在 Admin 本地映射。
- `shortDesc` 后端 DTO 校验 `@MaxLength(10)`（字符），超长由 controller 返回 400。
- 本轮**不**改动 Flutter 端（模板模型/展示/推荐算法），只保证字段随 `GET /api/v1/templates/list`、`/:id` 下发。
- 完成本计划所有后端+后台改动后，必须 `git commit` 并**同时 push 到 `origin`(gitee) 与 `github`** 两个远程的 `master`。
- 迁移文件按三/四位数前缀升序命名（现有最大 `014_`），`015_` 紧随其后，由执行器按文件名排序执行。
- Admin `npm run build` 会经 `vercel.json` 先构建 shared，改 shared 后需重新构建 admin，typecheck 以 build 通过为准。

---

### Task 1: 数据库迁移（新增两列）

**Files:**
- Create: `lumira-server/packages/backend/src/database/migrations/015_template_ambience_short_desc.sql`

**Interfaces:**
- Consumes: 现有 `templates` 表（`003_templates.sql` 已建）。
- Produces: `templates` 表新增 `ambience_json LONGTEXT`（默认 `'{}'`）与 `short_desc TEXT`（默认 `''`）两列；`DatabaseService.runMigrations()` 编辑排序按文件名，`015_` 在 `014_` 之后执行。

- [ ] **Step 1: 创建迁移文件**

```sql
-- lumira-server/packages/backend/src/database/migrations/015_template_ambience_short_desc.sql
-- 模板季节/天气/时段元数据 + 短简介（spec 2026-08-20-template-ambience-metadata-design）
-- 迁移执行器按文件名去重，编辑该文件前需确认 015_ 未被 _migrations 记录
ALTER TABLE templates
  ADD COLUMN ambience_json LONGTEXT NOT NULL DEFAULT '{}',
  ADD COLUMN short_desc TEXT NOT NULL DEFAULT '';
```

- [ ] **Step 2: 自检** —— 确认 `migrations/` 目录中最大编号为 `014_usage_occurred_at_bigint.sql`，`015_` 排在其后；SQL 用 `ALTER TABLE`（表已存在，不能用 `CREATE TABLE IF NOT EXISTS`，否则不会给旧表加列）。

- [ ] **Step 3: 提交**

```bash
git add lumira-server/packages/backend/src/database/migrations/015_template_ambience_short_desc.sql
git commit -m "feat(backend): templates 表新增 ambience_json 与 short_desc 迁移"
```

---

### Task 2: schema.ts 表列定义

**Files:**
- Modify: `lumira-server/packages/backend/src/database/schema.ts:180-202`（`templates` 表）

**Interfaces:**
- Consumes: Task 1 的列名（`ambience_json` / `short_desc`）。
- Produces: `templates.ambienceJson`（`longtext`）、`templates.shortDesc`（`text`）；供 Task 5 的 `rowToMeta`/`create`/`update` 引用，类型为 `string`。

- [ ] **Step 1: 在 `templates` 表 `postProcessJson` 字段之后、`createdAt` 之前添加两列**

```ts
  postProcessJson: longtext('post_process_json').notNull().default('{}'),
  // 季节/天气/时段元数据（spec 2026-08-20）：{ seasons:[], weathers:[], timeTones:[] }
  ambienceJson: longtext('ambience_json').notNull().default('{}'),
  // 短简介（≤10字，banner/模板卡片展示用）
  shortDesc: text('short_desc').notNull().default(''),
  createdAt: int('created_at').notNull(),
```

- [ ] **Step 2: 提交**

```bash
git add lumira-server/packages/backend/src/database/schema.ts
git commit -m "feat(backend): schema 定义 ambience_json 与 short_desc"
```

---

### Task 3: 共享类型扩展（@lumira/shared）

**Files:**
- Modify: `lumira-server/packages/shared/src/types/template.ts`

**Interfaces:**
- Consumes: 无（纯新增类型）。
- Produces: `TemplateAmbience` 接口；`RemoteTemplateMeta`/`RemoteTemplateDetail`/`AdminTemplateListItem`/`AdminTemplateDetail`/`CreateTemplateRequest`/`UpdateTemplateRequest` 新增 `ambience` 与 `shortDesc`。`ambience` 为必需字段（由 `rowToMeta` 保证始终返回空结构）；`shortDesc` 为字符串（可空串）。

- [ ] **Step 1: 新增 `TemplateAmbience` 接口（放在 `RemoteTemplateMeta` 定义之前）**

```ts
/** 模板适用的季节/天气/时段色调（后续季节/天气推荐使用） */
export interface TemplateAmbience {
  /** 适用季节：spring / summer / autumn / winter，空数组=不限 */
  seasons: ('spring' | 'summer' | 'autumn' | 'winter')[];
  /** 适用天气：sunny / cloudy / overcast / rain / snow / fog（对齐 WeatherService 中文描述） */
  weathers: ('sunny' | 'cloudy' | 'overcast' | 'rain' | 'snow' | 'fog')[];
  /** 时段/色调倾向：goldenHour / day / night / warm / cool */
  timeTones: ('goldenHour' | 'day' | 'night' | 'warm' | 'cool')[];
}
```

- [ ] **Step 2: 在 `RemoteTemplateMeta` 增加两个字段**

```ts
  classification: { type: string; majorStyle: string; subStyle: string; method: string };
  /** 季节/天气/时段元数据 */
  ambience: TemplateAmbience;
  /** 短简介（≤10字） */
  shortDesc: string;
  sortOrder: number;
```

- [ ] **Step 3: 在 `AdminTemplateDetail` 的 5 段字段之后增加两字段**

```ts
  sceneGuide: Record<string, unknown>;
  postProcess: Record<string, unknown>;
  /** 季节/天气/时段元数据 */
  ambience: TemplateAmbience;
  /** 短简介（≤10字） */
  shortDesc: string;
}
```

- [ ] **Step 4: 在 `CreateTemplateRequest`/`UpdateTemplateRequest` 增加可选字段**

`ambience` 与 `shortDesc` 均为可选（创建/更新时允许缺省）：

```ts
  classification?: { type: string; majorStyle: string; subStyle: string; method: string };
  /** 季节/天气/时段元数据（可选，缺省按空结构存储） */
  ambience?: TemplateAmbience;
  /** 短简介（≤10字，可选） */
  shortDesc?: string;
  sortOrder?: number;
```

- [ ] **Step 5: 提交**

```bash
git add lumira-server/packages/shared/src/types/template.ts
git commit -m "feat(shared): 模板增加 ambience 元数据与 shortDesc 类型"
```

---

### Task 4: 后端 DTO（create / update）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/templates/dto/create-template.dto.ts`
- Modify: `lumira-server/packages/backend/src/modules/templates/dto/update-template.dto.ts`

**Interfaces:**
- Consumes: `TemplateAmbience`（来自 `@lumira/shared`）。
- Produces: `CreateTemplateDto.ambience?` / `.shortDesc?`；`UpdateTemplateDto.ambience?` / `.shortDesc?`。`shortDesc` 经 `@MaxLength(10)` 校验（controller 手动 `validate` 后返回 400）。

- [ ] **Step 1: create-template.dto.ts**

在 `description` 字段之后新增（保持 import 已有 `MaxLength`）：

```ts
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;

  @IsOptional()
  @IsString()
  @MaxLength(10)
  shortDesc?: string;

  @IsOptional()
  ambience?: {
    seasons?: string[];
    weathers?: string[];
    timeTones?: string[];
  };
```

- [ ] **Step 2: update-template.dto.ts**

在 `description` 字段之后新增（与 create 完全一致的片段，字段全部可选）：

```ts
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;

  @IsOptional()
  @IsString()
  @MaxLength(10)
  shortDesc?: string;

  @IsOptional()
  ambience?: {
    seasons?: string[];
    weathers?: string[];
    timeTones?: string[];
  };
```

- [ ] **Step 3: 提交**

```bash
git add lumira-server/packages/backend/src/modules/templates/dto/create-template.dto.ts lumira-server/packages/backend/src/modules/templates/dto/update-template.dto.ts
git commit -m "feat(backend): 模板 DTO 增加 ambience 与 shortDesc（含≤10字校验）"
```

---

### Task 5: 后端 service 读写映射

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/templates/templates.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/templates/admin-templates.service.ts`

**Interfaces:**
- Consumes: `templates.ambienceJson`/`templates.shortDesc`（Task 2）；`CreateTemplateDto.ambience?`/`.shortDesc?`（Task 4）。
- Produces: 导出的 `parseAmbience(json)` / `sanitizeAmbience(input)`（`{seasons,weathers,timeTones}` 三数组），供 `rowToMeta` 与 `admin-templates.service` 的 create/update 复用。

- [ ] **Step 1: templates.service.ts —— `rowToMeta` 增加两个字段**

```ts
    classification: safeParseClassification(row.classificationJson),
    ambience: parseAmbience(row.ambienceJson),
    shortDesc: row.shortDesc ?? '',
    sortOrder: row.sortOrder,
```

（`rowToDetail` 通过 `...rowToMeta(row)` 自动携带 `ambience`/`shortDesc`，无需改动。）

- [ ] **Step 2: templates.service.ts —— 新增 `sanitizeAmbience` + `parseAmbience`（放在 `safeParseObject` 定义之后）**

```ts
/** 清洗入口 ambience 输入为标准三数组结构（非法值丢弃） */
export function sanitizeAmbience(input: unknown): { seasons: string[]; weathers: string[]; timeTones: string[] } {
  const obj =
    input && typeof input === 'object' && !Array.isArray(input)
      ? (input as Record<string, unknown>)
      : {};
  const strArr = (v: unknown): string[] =>
    Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : [];
  return {
    seasons: strArr(obj['seasons']),
    weathers: strArr(obj['weathers']),
    timeTones: strArr(obj['timeTones']),
  };
}

/** 解析 ambience_json 列（失败回退空结构） */
export function parseAmbience(json: string): { seasons: string[]; weathers: string[]; timeTones: string[] } {
  try {
    const v = JSON.parse(json);
    if (v && typeof v === 'object' && !Array.isArray(v)) return sanitizeAmbience(v);
  } catch {
    /* 非法 JSON 回退空结构 */
  }
  return { seasons: [], weathers: [], timeTones: [] };
}
```

- [ ] **Step 3: admin-templates.service.ts —— import 新函数**

在现有 `import { rowToDetail } from './templates.service';` 之后追加：

```ts
import { rowToDetail, parseAmbience, sanitizeAmbience } from './templates.service';
```

- [ ] **Step 4: admin-templates.service.ts —— `create` 的 INSERT values 增加两列**

在 `postProcessJson: JSON.stringify(postProcess),` 之后、`createdAt` 之前：

```ts
      ambienceJson: JSON.stringify(sanitizeAmbience(meta.ambience)),
      shortDesc: meta.shortDesc ?? '',
      createdAt: now,
```

- [ ] **Step 5: admin-templates.service.ts —— `update` 的 updateData 增加两列（仅当有值）**

在 `postProcessJson: JSON.stringify(postProcess),` 之后追加：

```ts
    if (meta.ambience !== undefined) updateData.ambienceJson = JSON.stringify(sanitizeAmbience(meta.ambience));
    if (meta.shortDesc !== undefined) updateData.shortDesc = meta.shortDesc;
```

- [ ] **Step 6: 后端 typecheck**

Run（在 `lumira-server/packages/backend`）: `pnpm typecheck`
Expected: 通过，无新错误。

- [ ] **Step 7: 提交**

```bash
git add lumira-server/packages/backend/src/modules/templates/templates.service.ts lumira-server/packages/backend/src/modules/templates/admin-templates.service.ts
git commit -m "feat(backend): 模板 ambience/shortDesc 读写映射"
```

---

### Task 6: Admin 本地类型

**Files:**
- Modify: `lumira-server/packages/admin/src/types/admin.ts`

**Interfaces:**
- Consumes: 后端返回的 `ambience`/`shortDesc`（Task 5）。
- Produces: 本地 `TemplateAmbience` 类型；`AdminTemplateDetail` 增加 `ambience`/`shortDesc`；`CreateTemplateRequest` 增加可选 `ambience`/`shortDesc`。

- [ ] **Step 1: 新增 `TemplateAmbience` 并给 `AdminTemplateDetail` 加字段**

在 `AdminTemplateDetail` 定义之前插入：

```ts
export interface TemplateAmbience {
  seasons: string[];
  weathers: string[];
  timeTones: string[];
}
```

在 `AdminTemplateDetail` 的 `postProcess` 之后增加：

```ts
  postProcess: Record<string, unknown>;
  ambience: TemplateAmbience;
  shortDesc: string;
}
```

- [ ] **Step 2: `CreateTemplateRequest` 增加可选字段**

```ts
  classification?: { type: string; style: string; method: string };
  ambience?: TemplateAmbience;
  shortDesc?: string;
  sortOrder?: number;
```

- [ ] **Step 3: 提交**

```bash
git add lumira-server/packages/admin/src/types/admin.ts
git commit -m "feat(admin): 模板本地类型增加 ambience 与 shortDesc"
```

---

### Task 7: Admin 表单新增短简介 + 时节氛围多选

**Files:**
- Modify: `lumira-server/packages/admin/src/components/template-form.tsx`

**Interfaces:**
- Consumes: `AdminTemplateDetail.ambience/shortDesc`（Task 6）。
- Produces: 表单字段 `shortDesc`、`ambienceSeasons`、`ambienceWeathers`、`ambienceTimeTones`；`onSubmit` 的 `meta` 增加 `shortDesc` 与 `ambience:{seasons,weathers,timeTones}`。

- [ ] **Step 1: 新增下拉/多选常量（放在 `const NONE_VALUE...` 相关区域，靠近 `STEPS` 之前）**

```ts
const SEASONS_OPTIONS = [
  { value: 'spring', label: '春' },
  { value: 'summer', label: '夏' },
  { value: 'autumn', label: '秋' },
  { value: 'winter', label: '冬' },
];

const WEATHERS_OPTIONS = [
  { value: 'sunny', label: '晴' },
  { value: 'cloudy', label: '多云' },
  { value: 'overcast', label: '阴' },
  { value: 'rain', label: '雨' },
  { value: 'snow', label: '雪' },
  { value: 'fog', label: '雾' },
];

const TIME_TONES_OPTIONS = [
  { value: 'goldenHour', label: '黄金小时' },
  { value: 'day', label: '白天' },
  { value: 'night', label: '夜晚' },
  { value: 'warm', label: '暖调' },
  { value: 'cool', label: '冷调' },
];

/** 通用多选渲染：可逆的 checkbox chips */
function AmbienceChecklist({
  id,
  label,
  options,
  value,
  onChange,
}: {
  id: string;
  label: string;
  options: { value: string; label: string }[];
  value: string[];
  onChange: (next: string[]) => void;
}) {
  return (
    <div className="space-y-2">
      <Label htmlFor={id}>{label}</Label>
      <div className="flex flex-wrap gap-2">
        {options.map((opt) => {
          const active = value.includes(opt.value);
          return (
            <button
              key={opt.value}
              type="button"
              onClick={() =>
                onChange(
                  active ? value.filter((v) => v !== opt.value) : [...value, opt.value],
                )
              }
              className={`rounded-full border px-3 py-1 text-sm transition-colors ${
                active
                  ? 'border-primary bg-primary text-primary-foreground'
                  : 'border-input text-muted-foreground hover:bg-accent'
              }`}
            >
              {opt.label}
            </button>
          );
        })}
      </div>
    </div>
  );
}
```

- [ ] **Step 2: schema（zod）增加 4 个字段**

在 `description: z.string().optional().default(''),` 之后追加：

```ts
  shortDesc: z.string().max(10, '短简介最多 10 字').optional().default(''),
```

在 `author: z.string().optional().default('Lumira'),` 附近（任意处）追加：

```ts
  ambienceSeasons: z.array(z.string()).optional().default([]),
  ambienceWeathers: z.array(z.string()).optional().default([]),
  ambienceTimeTones: z.array(z.string()).optional().default([]),
```

- [ ] **Step 3: buildDefaults 默认值（新增模板分支）**

在 `description: '',`（create 分支 `buildDefaults` 内）之后追加：

```ts
        shortDesc: '',
        ambienceSeasons: [],
        ambienceWeathers: [],
        ambienceTimeTones: [],
```

- [ ] **Step 4: 回填（编辑分支）——在 `description: initial.description ?? '',` 之后追加**

```ts
      shortDesc: initial.shortDesc ?? '',
      ambienceSeasons: initial.ambience?.seasons ?? [],
      ambienceWeathers: initial.ambience?.weathers ?? [],
      ambienceTimeTones: initial.ambience?.timeTones ?? [],
```

- [ ] **Step 5: onSubmit 组装 meta —— 在 `description: data.description ?? '',` 之后追加**

```ts
      shortDesc: (data.shortDesc ?? '').trim(),
      ambience: {
        seasons: data.ambienceSeasons ?? [],
        weathers: data.ambienceWeathers ?? [],
        timeTones: data.ambienceTimeTones ?? [],
      },
```

- [ ] **Step 6: 基本信息 step 的表单 UI —— 在「描述」Textarea 与「参考来源」之间插入控件**

在 `description` Textarea 的 JSX 之后插入短简介输入与时节多选（用 `Controller` 驱动，沿用现有 import）：

```tsx
                <Label htmlFor="shortDesc">短简介（≤10字）</Label>
                <div className="relative">
                  <Input
                    id="shortDesc"
                    maxLength={10}
                    placeholder="一句话亮点（≤10字）"
                    {...register('shortDesc')}
                  />
                  <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-muted-foreground">
                    {(watch('shortDesc') || '').length}/10
                  </span>
                </div>

                <Controller
                  control={control}
                  name="ambienceSeasons"
                  render={({ field }) => (
                    <AmbienceChecklist
                      id="ambienceSeasons"
                      label="适用季节（不选=不限）"
                      options={SEASONS_OPTIONS}
                      value={field.value}
                      onChange={field.onChange}
                    />
                  )}
                />
                <Controller
                  control={control}
                  name="ambienceWeathers"
                  render={({ field }) => (
                    <AmbienceChecklist
                      id="ambienceWeathers"
                      label="适用天气（不选=不限）"
                      options={WEATHERS_OPTIONS}
                      value={field.value}
                      onChange={field.onChange}
                    />
                  )}
                />
                <Controller
                  control={control}
                  name="ambienceTimeTones"
                  render={({ field }) => (
                    <AmbienceChecklist
                      id="ambienceTimeTones"
                      label="时段/色调（不选=不限）"
                      options={TIME_TONES_OPTIONS}
                      value={field.value}
                      onChange={field.onChange}
                    />
                  )}
                />
```

（说明：`onSubmit` 已在 `watch('shortDesc')` 可访问范围内使用 `watch`，Step 6 直接复用现有 `watch`。）

- [ ] **Step 7: Admin 构建验证**

Run（在 `lumira-server`）: `pnpm --filter @lumira/admin build`
Expected: 构建成功，无类型错误。若报 `shortDesc`/`ambience` 不存在，确认已先完成 Task 3 并重新构建 `@lumira/shared`（`pnpm --filter @lumira/shared build`）。

- [ ] **Step 8: 提交**

```bash
git add lumira-server/packages/admin/src/components/template-form.tsx
git commit -m "feat(admin): 模板表单新增短简介与时节氛围多选"
```

---

### Task 8: 后端 + 后台全量验证与推送

**Files:**
- 验证：无新增文件。

**Interfaces:**
- Consumes: 全部历史 Task 产物。

- [ ] **Step 1: 后端 typecheck + admin 构建（二次确认无回归）**

Run（在 `lumira-server/packages/backend`）: `pnpm typecheck`
Expected: 通过。
Run（在 `lumira-server`）: `pnpm --filter @lumira/admin build`
Expected: 通过。

- [ ] **Step 2: 运行后端既有测试确认无回归（若有 e2e 覆盖 templates）**

Run（在 `lumira-server/packages/backend`）: `pnpm test`
Expected: 全部通过；若有与 templates 相关的用例因新增必填字段而失败，按 Task 5 产出字段补齐 `fixtures`（本计划不含预置 fixture，若无则直接通过）。

- [ ] **Step 3: 本地冒烟（可选，连库时）**

Run（后端开发服务）：启动后日志应含 `[migrate] applied 015_template_ambience_short_desc.sql`。

- [ ] **Step 4: 提交剩余改动 + 推送双远程（仅本计划文件，绝不用 `git add -A`）**

工作区可能有其它会话的未提交 Flutter 改动（theme/neu_card/scene 等），**严禁 `git add -A`**，只暂存本计划涉及的文件：

```bash
git add docs/superpowers/specs/2026-08-20-template-ambience-metadata-design.md
git commit -m "docs: 模板季节/天气/时段元数据设计规格"
git push origin master
git push github master
```

`git push` 前先 `git status` 确认暂存区仅含计划内文件；本计划的代码（迁移/schema/shared/dto/service/admin）已在各自 Task 提交，Task 8 只需补交设计规格文档并推送。若某次 push 因远端有并行会话提交而失败，先 `git pull --rebase` 再重试 push。

Expected: 两处 push 均成功、推送内容即为本计划全部提交；触发 `.github/workflows/backend-deploy.yml`（改动命中 `backend/**`）与 admin 部署（Vercel 监听 shared/admin）。

---

## Self-Review

**1. Spec 覆盖**：数据结构（§2）→ Task 1/2；共享类型（§2.2）→ Task 3；取值范围/校验（§2.3-2.4）→ Task 4（@MaxLength10）+ Task 5（sanitize）；数据流后端读写（§3）→ Task 5；Admin 表单（§4）→ Task 6/7。全部覆盖。

**2. 占位符扫描**：无 TBD/TODO；所有代码步骤已给出完整代码。

**3. 类型一致性**：`sanitizeAmbience` / `parseAmbience` 在 Task 5 定义并导出，Task 5 Step 3 导入一致；`ambience:{seasons,weathers,timeTones}` 在 Task 5、Task 7 Step 5、Task 7 Step 4 读/写命名一致；`shortDesc` 全程一致；`TemplateAmbience` 在 shared（Task 3）与 admin 本地（Task 6）命名一致。