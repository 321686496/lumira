# AI 一键模板录入 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 运营上传一张示例图，后端调用视觉大模型自动识别风格/类型/相机与后期参数，生成与 `.pptpl` 导入格式完全一致的模板草稿，回填现有 TemplateForm；可选生图模型生成封面效果图、本地 ONNX 管线生成剪影，最终人工确认或一键全自动上架。

**Architecture:** 后端新增 NestJS `ai` 模块（`src/modules/ai/`），四个能力：ai-config（DB 单行配置 CRUD + 连通性测试）、ai-analyze（vision chat → 草稿 JSON）、ai-generate-image（按厂商适配生图）、ai-generate-silhouette（本地 RMBG-1.4 + sharp 管线，不走厂商 API）。草稿 JSON 顶层结构与 `.pptpl` 一致，admin 前端向导页通过给 `TemplateForm` 注入 `aiInjection` props 复用全部表单/提交链路。规格文档：`docs/specs/2026-09-09-ai-template-one-click-creation-design.md`。

**Tech Stack:** NestJS + Fastify（现有）、OpenAI 兼容 Chat Completions（原生 fetch，不加 axios）、`onnxruntime-node` + `sharp`（剪影管线，新增依赖）、Next.js App Router + shadcn/ui + Phosphor Icons（现有）、Drizzle ORM + MySQL 迁移（现有版本化迁移执行器）。

## Global Constraints

- Flutter 端零改动；产出模板与现有线上模板完全同构（走现有 `createTemplate` 链路）。
- 不引入 Dify/Coze；不做视觉模型微调；不做批量上传（一次一张）。
- 全自动模式只生成 1 个姿势。
- 四厂商 `provider` 枚举：`qwen | doubao | zhipu | openai`，全部走 OpenAI 兼容 chat completions；豆包模型名为自由输入（接入点 ep-xxx），不校验枚举。
- `ai_provider_config` 单行 upsert，id 恒为 1；apiKey 存 DB，GET 脱敏返回（`sk-****ab` 风格），PUT 留空 = 不修改原值。
- 全部后端接口挂 `/api/v1/admin` 前缀，`AdminAuthGuard` 保护。
- 草稿 JSON 顶层键：`meta / composition / pose / camera / sceneGuide / postProcess`（与 `.pptpl` 一致）。
- AI 不填：`price`（默认 0）、`silhouette`、`author/sortOrder/isActive`、封面。
- 剪影管线不依赖任何厂商 API、不依赖 ai-config 是否启用（仅 AdminAuthGuard）。
- 响应包裹：识别返回 `{ draft, warnings: string[] }`。
- 图片校验与现有封面一致：jpg/png/webp、≤ `MAX_IMAGE_BYTES`（8MB，复用 `admin-templates.service.ts` 的常量语义）。
- 无新增环境变量（配置全在 DB）。RMBG 模型路径可用 `RMBG_MODEL_PATH` 覆盖（本地开发用，非部署必需）。
- 时间戳遵循代码库约定用 INT 秒（schema.ts 全库如此），不采用设计文档 SQL 里的 DATETIME。
- 后端改动完成后必须 commit 并 push 双远程（origin=gitee、github）。本计划在 Task 10（后端完成）与 Task 17（全部完成）两个检查点各推送一次——中途半成品推 master 会触发 backend-deploy 生产部署，故不逐任务推送。
- Dart/Flutter 端（`lumira_app_flutter/`）与 uni-app（`lumira-app/`）不得改动。
- 数据库迁移走版本化执行器：新文件放 `src/database/migrations/`，由 `_migrations` 表保证幂等，命名顺延（最新为 027，新迁移为 028）。

---

### Task 1: 数据库迁移 028 + Drizzle schema（ai_provider_config 表）

**Files:**
- Create: `lumira-server/packages/backend/src/database/migrations/028_ai_provider_config.sql`
- Modify: `lumira-server/packages/backend/src/database/schema.ts`（文件末尾追加表定义）

**Interfaces:**
- Consumes: 现有迁移执行器（`database.service.ts` 的 `runMigrations`，自动执行新 SQL 文件）。
- Produces: drizzle 表对象 `aiProviderConfig`，后续 Task 4 的 service 通过 `db.query.aiProviderConfig` 查询。

**Steps:**

- [ ] 创建迁移文件 `028_ai_provider_config.sql`：

```sql
-- lumira-server/packages/backend/src/database/migrations/028_ai_provider_config.sql
-- AI 一键模板录入（spec 2026-09-09-ai-template-one-click-creation-design）
-- 单行配置表：id 恒为 1，由 ai-config service upsert。
-- provider 为厂商预设标识（qwen/doubao/zhipu/openai），为将来接入 dify/coze 工作流预留扩展位。
CREATE TABLE IF NOT EXISTS `ai_provider_config` (
  `id`           INT PRIMARY KEY,
  `provider`     VARCHAR(32)  NOT NULL,
  `base_url`     VARCHAR(255) NOT NULL,
  `api_key`      VARCHAR(255) NOT NULL,
  `vision_model` VARCHAR(64)  NOT NULL,
  `image_model`  VARCHAR(64)  NOT NULL,
  `enabled`      INT NOT NULL DEFAULT 0,
  `created_at`   INT NOT NULL,
  `updated_at`   INT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [ ] 在 `schema.ts` 末尾（`templates` 表相关定义之后）追加：

```ts
// ===== AI 一键模板录入（spec 2026-09-09）：厂商配置，单行 upsert（id 恒为 1）=====
export const aiProviderConfig = mysqlTable('ai_provider_config', {
  id: int('id').primaryKey(),
  provider: varchar('provider', { length: 32 }).notNull(),
  baseUrl: varchar('base_url', { length: 255 }).notNull(),
  apiKey: varchar('api_key', { length: 255 }).notNull(),
  visionModel: varchar('vision_model', { length: 64 }).notNull(),
  imageModel: varchar('image_model', { length: 64 }).notNull(),
  enabled: int('enabled').notNull().default(0),
  createdAt: int('created_at').notNull(),
  updatedAt: int('updated_at').notNull(),
});
```

- [ ] 验证：`pnpm --filter @lumira/backend build` 通过（tsc 校验 schema 类型）。
- [ ] Commit: `feat(backend): add ai_provider_config table (migration 028 + drizzle schema)`

---

### Task 2: normalize.ts 归一化纯函数（TDD）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/normalize.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/normalize.spec.ts`

**Interfaces:**
- Consumes: 无（纯函数）。
- Produces（Task 5/7 依赖）:

```ts
export interface CategoryNode { key: string; name: string; parentKey: string | null; level: number; }
export interface NormalizeResult { draft: Record<string, unknown>; warnings: string[]; }

/** LLM 输出容错提取：剥 code fence → 首个 { 到末个 } 截取 → JSON.parse；失败返回 null */
export function extractJson(text: string): Record<string, unknown> | null;

/** 枚举校验：精确 key 命中 → 中文标签反查命中 → 否则 undefined（调用方记 warning） */
export function mapEnumValue(raw: unknown, allowed: readonly string[], labels: Record<string, string>): string | undefined;

/** 数值夹取：非数值返回 undefined，否则 clamp 到 [min, max] */
export function clampNumber(raw: unknown, min: number, max: number): number | undefined;

/** 草稿归一化主入口：枚举校验、分类链校验、数值夹取，非法值丢弃并收集 warnings */
export function normalizeDraft(raw: unknown, categories: CategoryNode[]): NormalizeResult;
```

**Steps:**

- [ ] **先写失败测试** `normalize.spec.ts`，覆盖以下用例（jest 配置已有，`pnpm --filter @lumira/backend test` 跑 `src/**/*.spec.ts`）：

```ts
// normalize.spec.ts 关键用例（写成多个 it）：
// extractJson：
//   1. '{"a":1}' → {a:1}
//   2. '```json\n{"a":1}\n```' → {a:1}
//   3. '前置废话 {"a":{"b":2}} 后置废话' → {a:{b:2}}
//   4. '完全不是 JSON' → null
// mapEnumValue：
//   5. allowed=['rule_of_thirds','center'], labels={rule_of_thirds:'三等分',center:'居中'}
//      输入 'rule_of_thirds' → 'rule_of_thirds'（精确 key）
//   6. 输入 '三等分' → 'rule_of_thirds'（中文标签反查）
//   7. 输入 '对角线' → undefined（非法丢弃）
// clampNumber：
//   8. 1.5, 0, 1 → 1；-3, 0, 1 → 0；'abc' → undefined；0.5 → 0.5
// normalizeDraft（构造 4 节点分类树 portrait→fresh_healing→japanese→method_x）：
//   9. 完整合法草稿 → draft 保留全部字段，warnings=[]
//   10. meta.category 不在树 → category 丢默认 'portrait' + warning
//   11. classification 链断裂（majorStyle 合法但 style 的 parent 不是 majorStyle）→ 截断到合法层 + warning
//   12. pose.position.x=1.7 → 夹到 1；postProcess.color.saturation=200 → 夹到 100
//   13. camera.whiteBalance='日光' → 白平衡标签反查 'daylight'
//   14. postProcess.lut='日系清新' → 'japanese_fresh'；lut='不存在' → 丢弃 + warning
//   15. pose 为对象（非数组）→ 包装成 [pose]；pose 为空 → 默认单姿势骨架
```

- [ ] 运行测试确认失败（文件不存在）。
- [ ] 实现 `normalize.ts`。实现要点：

```ts
// 枚举表：从 admin/src/components/template-form.tsx 头部常量逐一拷贝 key + 中文标签
// （LUTS/LUT_LABELS/OVERLAY_TYPES/WHITE_BALANCES/ISO_MODES/FLASH_MODES/FOCUS_MODES/
//  LENS_SUGGESTIONS/SEASONS/WEATHERS/TIME_TONES/ASPECT_RATIOS 等）。
// 后端本地维护一份（ai 模块 enums.ts 将在 Task 4 创建；本任务先在 normalize.ts 内定义并导出，
// Task 4 的 enums.ts 直接 re-export 或合并）。
export const LUT_LABELS: Record<string, string> = { japanese_fresh: '日系清新', /* …共 24 项，从 template-form.tsx 拷贝… */ };

// normalizeDraft 结构（伪代码级规格）：
// - 非 object 输入 → throw（调用方转 400）
// - meta：name（string，trim，长度 12~30 之外仅 warning 不丢弃）、category（必须在 categories level=1 key 集合，
//   非法 → 'portrait' + warning）、shortDesc/description（string）、tags（string[] 过滤非 string）、
//   ambience（seasons/weathers/timeTones 各自 mapEnumValue 过滤）、
//   classification（category 用 meta.category；majorStyle 必须是 category 的 level=2 子节点；
//   style 必须是 majorStyle 的 level=3 子节点；method 必须是 style 的 level=4 子节点；
//   任一层断裂 → 该层及以下全部丢弃 + warning）
// - composition：overlayType mapEnum、aspectRatio mapEnum(ASPECT_RATIOS)、opacity clamp(0,1)、
//   description string、subjectFrame x/y/w/h 各 clamp(0,1)
// - pose：非数组包装成数组；空 → [{name:'',description:'',position:{x:0.5,y:0.5},scale:1,rotation:0}]；
//   每项 name/description string 化、position clamp(0,1)、scale clamp(0.1,3)、rotation clamp(-180,180)；
//   全部剔除 silhouette 字段（AI 不填剪影）
// - camera：exposureCompensation clamp(-5,5)、isoMode/whiteBalance/flashMode/focusMode/lensSuggestion
//   各 mapEnum、iso clamp(50,25600)、whiteBalanceK clamp(2000,10000)、shutterSpeed/lensType string 化
// - sceneGuide：lightDirection/shootingDistance/background/bestTime string 化、props/tips 过滤 string[]
// - postProcess：cropRatio mapEnum、color 七项各 clamp(-100,100)、smoothStrength/sharpen/vignette/grain
//   clamp(0,100)、lut mapEnum(LUT_LABELS)
// - AI 不填字段强制不写入：price/silhouette/author/sortOrder/isActive
// - 未知顶层键忽略
```

- [ ] 运行 `pnpm --filter @lumira/backend test`，全部通过。
- [ ] Commit: `feat(backend-ai): draft normalization with enum mapping, category chain validation and clamping (TDD)`

---

### Task 3: LLM 客户端 llm-client.ts（OpenAI 兼容 vision chat）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/llm-client.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/llm-client.spec.ts`

**Interfaces:**
- Consumes: Node 20 原生 `fetch`（不加 axios）、`AbortController`。
- Produces（Task 4/5 依赖）:

```ts
export interface LlmConfig {
  provider: string;   // qwen | doubao | zhipu | openai
  baseUrl: string;    // 形如 https://dashscope.aliyuncs.com/compatible-mode/v1（无尾斜杠）
  apiKey: string;
  visionModel: string;
}

export interface VisionChatInput {
  systemPrompt: string;
  userText: string;
  imageBase64: string;      // 不含 data: 前缀
  imageMime: string;        // image/jpeg | image/png | image/webp
  temperature?: number;     // 默认 0.3
  jsonMode?: boolean;       // 默认 false；true 时带 response_format json_object，400 时自动降级重试一次
  timeoutMs?: number;       // 默认 90_000
}

/** 成功返回模型文本输出；失败抛 Error，message 面向运营可读 */
export async function visionChat(cfg: LlmConfig, input: VisionChatInput): Promise<string>;
```

**Steps:**

- [ ] **先写失败测试** `llm-client.spec.ts`（`jest.spyOn(global, 'fetch')` mock）：

```ts
// 关键用例：
// 1. 请求形状：URL = `${baseUrl}/chat/completions`；Authorization: Bearer ${apiKey}；
//    body.messages = [{role:'system',content:systemPrompt},
//                     {role:'user',content:[{type:'text',text:userText},
//                                           {type:'image_url',image_url:{url:`data:${mime};base64,${b64}`}}]}]
// 2. 返回 choices[0].message.content
// 3. jsonMode=true：body 含 response_format:{type:'json_object'}；首次 400 → 自动去掉 response_format 重试一次成功
// 4. 401/403 → Error message 含「apiKey 无效或无权限，请到 AI 设置检查」
// 5. 超时（mock never-resolving fetch + timeoutMs:10）→ Error message 含「超时」
// 6. 上游 500 + body {error:{message:'x'}} → Error message 透传 'x'
```

- [ ] 确认测试失败后实现 `llm-client.ts`。要点：

```ts
export async function visionChat(cfg: LlmConfig, input: VisionChatInput): Promise<string> {
  const url = `${cfg.baseUrl.replace(/\/+$/, '')}/chat/completions`;
  const messages = [
    { role: 'system', content: input.systemPrompt },
    { role: 'user', content: [
      { type: 'text', text: input.userText },
      { type: 'image_url', image_url: { url: `data:${input.imageMime};base64,${input.imageBase64}` } },
    ] },
  ];
  const doFetch = async (jsonMode: boolean) => {
    const body: Record<string, unknown> = {
      model: cfg.visionModel, temperature: input.temperature ?? 0.3, max_tokens: 4096, messages,
    };
    if (jsonMode) body.response_format = { type: 'json_object' };
    return fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${cfg.apiKey}` },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(input.timeoutMs ?? 90_000),
    });
  };
  let res = await doFetch(input.jsonMode ?? false).catch(mapNetworkError);
  // jsonMode 降级：部分厂商不认识 response_format，400/404 时去掉重试一次
  if (!res.ok && input.jsonMode && (res.status === 400 || res.status === 404)) {
    res = await doFetch(false).catch(mapNetworkError);
  }
  if (res.status === 401 || res.status === 403) throw new Error('AI 服务认证失败（apiKey 无效或无权限/欠费），请到后台「AI 设置」检查');
  if (!res.ok) throw new Error(await upstreamError(res));
  const data = await res.json();
  const content = data?.choices?.[0]?.message?.content;
  if (typeof content !== 'string' || !content) throw new Error('AI 服务返回内容为空');
  return content;
}
// mapNetworkError: AbortError/TimeoutError → 'AI 请求超时，请稍后重试'；其他网络错误 → 'AI 服务无法连接，请检查 baseUrl'
// upstreamError: 解析 body.error.message / body.message，拼接 status
```

- [ ] `pnpm --filter @lumira/backend test` 通过。
- [ ] Commit: `feat(backend-ai): OpenAI-compatible vision chat client with json_mode fallback and error mapping (TDD)`

---

### Task 4: ai 模块骨架 + ai-config 配置 CRUD/脱敏/连通性测试

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/ai.module.ts`
- Create: `lumira-server/packages/backend/src/modules/ai/enums.ts`
- Create: `lumira-server/packages/backend/src/modules/ai/ai-config.service.ts`
- Create: `lumira-server/packages/backend/src/modules/ai/ai-config.controller.ts`
- Create: `lumira-server/packages/backend/src/modules/ai/dto/update-ai-config.dto.ts`
- Modify: `lumira-server/packages/backend/src/app.module.ts`（imports 加 `AiModule`）
- Test: `lumira-server/packages/backend/test/ai-config.e2e-spec.ts`

**Interfaces:**
- Consumes: Task 1 的 `aiProviderConfig` 表、Task 3 的 `visionChat`。
- Produces:

```ts
// enums.ts：导出 normalize.ts 所需的全部枚举 + 中文标签（normalize.spec 已拷贝的部分迁到这里统一维护）
export const LUT_LABELS: Record<string, string>;
export const OVERLAY_TYPE_LABELS: Record<string, string>;
export const WHITE_BALANCE_LABELS: Record<string, string>;
export const ISO_MODE_LABELS / FLASH_MODE_LABELS / FOCUS_MODE_LABELS / LENS_SUGGESTION_LABELS: Record<string, string>;
export const SEASON_LABELS / WEATHER_LABELS / TIME_TONE_LABELS / ASPECT_RATIO_LABELS: Record<string, string>;
export const PROVIDERS = ['qwen', 'doubao', 'zhipu', 'openai'] as const;

// ai-config.service.ts
export interface AiConfigView {
  configured: true; provider: string; baseUrl: string; apiKeyMasked: string;
  visionModel: string; imageModel: string; enabled: boolean;
}
@Injectable() export class AiConfigService {
  /** 无配置返回 { configured: false }（200，前端显示空态） */
  get(): Promise<AiConfigView | { configured: false }>;
  /** upsert id=1；apiKey 空串/缺省 = 保留原值；首次保存必须给 apiKey */
  save(dto: UpdateAiConfigDto): Promise<AiConfigView>;
  /** 最小 vision 请求（1px PNG + 'ping'）连通性测试 */
  test(): Promise<{ vision: { ok: boolean; latencyMs?: number; error?: string }; note: string }>;
  /** 未配置/未启用 → ServiceUnavailableException(503, 'AI 未配置或未启用，请先在后台「AI 设置」中完成配置并启用') */
  getActiveConfig(): Promise<{ provider; baseUrl; apiKey; visionModel; imageModel }>;
}

// HTTP（/api/v1/admin/ai-config，AdminAuthGuard）
GET  /admin/ai-config        → AiConfigView | {configured:false}
PUT  /admin/ai-config        → AiConfigView        body: UpdateAiConfigDto
POST /admin/ai-config/test   → test() 结果
```

```ts
// dto/update-ai-config.dto.ts
import { IsIn, IsOptional, IsString, IsBoolean, MaxLength } from 'class-validator';
export class UpdateAiConfigDto {
  @IsIn(PROVIDERS) provider: string;
  @IsString() @MaxLength(255) baseUrl: string;
  @IsOptional() @IsString() @MaxLength(255) apiKey?: string;   // 空串/缺省 = 不修改
  @IsString() @MaxLength(64) visionModel: string;
  @IsString() @MaxLength(64) imageModel: string;
  @IsBoolean() enabled: boolean;
}
```

**Steps:**

- [ ] 创建 `enums.ts`：把 Task 2 中 normalize.ts 内定义的枚举标签表迁到 `enums.ts`，`normalize.ts` 改为从 `./enums` 导入（跑一遍单测确认仍绿）。
- [ ] 创建 `ai-config.service.ts`。实现要点：

```ts
// 注入 DatabaseService（同 admin-templates.service.ts 模式：constructor(private dbService: DatabaseService)）
// get(): db.query.aiProviderConfig.findFirst() → 无则 {configured:false}；有则脱敏：
//   maskKey = k.length <= 8 ? '****' : `${k.slice(0,3)}****${k.slice(-2)}`
// save(): const now = Math.floor(Date.now()/1000)
//   existing = findFirst()
//   不存在：!dto.apiKey → BadRequestException('首次配置必须填写 API Key')
//     db.insert(aiProviderConfig).values({ id:1, ...dto, apiKey: dto.apiKey, createdAt: now, updatedAt: now })
//   存在：db.update(aiProviderConfig).set({
//     provider, baseUrl, visionModel, imageModel, enabled,
//     apiKey: dto.apiKey ? dto.apiKey : existing.apiKey,   // 留空 = 不改
//     updatedAt: now }).where(eq(aiProviderConfig.id, 1))
//   返回 get() 结果
// test(): cfg = getActiveConfig()（503 逻辑复用）
//   t0 = Date.now(); try { await visionChat(
//     { provider, baseUrl, apiKey, visionModel },
//     { systemPrompt: 'You are a connectivity test.', userText: 'ping',
//       imageBase64: TINY_1PX_PNG_B64, imageMime: 'image/png', temperature: 0, timeoutMs: 30_000 });
//     return { vision: { ok: true, latencyMs: Date.now() - t0 },
//              note: '生图模型与视觉模型使用同一 apiKey，可用性以首次生图为准' } }
//   catch (e) { return { vision: { ok: false, error: (e as Error).message }, note: '…同上…' } }
//   TINY_1PX_PNG_B64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
// getActiveConfig(): row = findFirst()；!row || !row.enabled → throw new ServiceUnavailableException(...)
```

- [ ] 创建 `ai-config.controller.ts`：

```ts
@Controller('admin/ai-config')
@UseGuards(AdminAuthGuard)
export class AiConfigController {
  constructor(private readonly aiConfigService: AiConfigService) {}
  @Get() get() { return this.aiConfigService.get(); }
  @Put() save(@Body() dto: UpdateAiConfigDto) { return this.aiConfigService.save(dto); }
  @Post('test') test() { return this.aiConfigService.test(); }
}
```

- [ ] 创建 `ai.module.ts`（AdminAuthGuard 若依赖 JwtService，则照抄 templates.module.ts 的 JwtModule.register 注册）：

```ts
@Module({
  imports: [DatabaseModule, JwtModule.register({ secret: process.env.JWT_SECRET || 'dev-secret-change-me', signOptions: { expiresIn: '30d' } })],
  controllers: [AiConfigController],
  providers: [AiConfigService],
})
export class AiModule {}
```

- [ ] `app.module.ts`：imports 数组加 `AiModule`。
- [ ] **e2e 测试** `test/ai-config.e2e-spec.ts`——照抄 `templates.e2e-spec.ts` 的启动骨架（resetTestDatabase + AppModule + FastifyAdapter + setGlobalPrefix('api/v1')），admin token 生成方式参考 `admin.e2e-spec.ts`（若该文件用 ADMIN_TOKEN 环境变量则用同法）。用例：

```ts
// 1. 初始 GET → { configured: false }
// 2. PUT 保存完整配置（provider:'qwen', baseUrl, apiKey:'sk-test-123456789', visionModel, imageModel, enabled:true）
//    → GET 返回 configured:true 且 apiKeyMasked === 'sk-****89'（前3+****+后2）
// 3. PUT 更新时 apiKey 传空串 → GET 后 apiKeyMasked 不变（'sk-****89'）
// 4. POST /test 未启用（enabled:false 更新后）→ 503，message 含「AI 设置」
//    （注意：enabled:true 时 test() 会发真实网络请求，e2e 里保持 enabled:false 或未配置来测 503 分支；
//     真实连通性走手动验收）
// 5. PUT 非法 provider 'dify' → 400（GlobalValidationPipe forbidNonWhitelisted/whitelist）
```

- [ ] `pnpm --filter @lumira/backend build` + `pnpm --filter @lumira/backend test` + `pnpm --filter @lumira/backend test:e2e -- test/ai-config.e2e-spec.ts` 全绿。
- [ ] Commit: `feat(backend-ai): ai module skeleton + ai-config CRUD with key masking and connectivity test (e2e)`

---

### Task 5: 识别提示词 + ai-analyze 服务与端点

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/analyze.prompt.ts`
- Create: `lumira-server/packages/backend/src/modules/ai/ai-analyze.service.ts`
- Create: `lumira-server/packages/backend/src/modules/ai/ai-templates.controller.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/ai.module.ts`（注册新 controller/provider）
- Test: `lumira-server/packages/backend/src/modules/ai/ai-analyze.service.spec.ts`
- Test: `lumira-server/packages/backend/test/ai-analyze.e2e-spec.ts`

**Interfaces:**
- Consumes: Task 2 `extractJson/normalizeDraft`、Task 3 `visionChat`、Task 4 `AiConfigService.getActiveConfig`、`admin-templates.service.ts` 的 `MAX_IMAGE_BYTES` 与 `UploadFile` 类型。
- Produces:

```ts
// analyze.prompt.ts
/** 系统提示词：注入 DB 分类树文本 + 全部枚举 key/中文标签 + 输出 JSON 契约 + 硬约束 */
export function buildAnalyzeSystemPrompt(categories: CategoryNode[]): string;
export function buildAnalyzeUserPrompt(): string;

// ai-analyze.service.ts
@Injectable() export class AiAnalyzeService {
  async analyze(image: UploadFile): Promise<{ draft: Record<string, unknown>; warnings: string[] }>;
}

// HTTP：POST /api/v1/admin/templates/ai-analyze（multipart: image 字段）
// → { draft, warnings }；未配置 503；缺 image 400；图片超限/类型非法 400；模型输出非法 JSON 400「模型输出无法解析为 JSON，请重试识别」
```

**Steps:**

- [ ] 实现 `analyze.prompt.ts`。系统提示词必须包含（中文撰写）：

```
角色：你是资深人像摄影模板编辑，分析用户上传的示例图，产出可直接上线的摄影模板表单数据。
动态注入（代码拼接）：
  1. 分类树：按层级缩进文本化，例：
     - portrait 人像
       - fresh_healing 清新治愈
         - japanese 日系
     只能从中选择，禁止编造 key。
  2. 全部枚举与中文标签（overlayType/白平衡/ISO 模式/闪光灯/对焦/镜头建议/LUT 24 项/季节/天气/时段/画幅）。
  3. 输出 JSON 契约：完整字段结构示例（照设计文档 §四 的草稿 JSON 示例内嵌）。
硬约束：
  - 只输出 JSON，不要任何解释、markdown 代码块标记也尽量省略；
  - meta.name 具体化（场景+主体+风格+角度，12~30 字），禁止只写风格名；
  - meta.shortDesc 情绪化文案 ≤20 字，不是长描述的缩写；
  - 未知枚举字段直接省略，不要编造；
  - meta.classification 从分类树逐级选择，非人像题材允许 style/method 留空；
  - 相机参数是「复现该风格的建议参数」，给出合理估算值；
  - AI 不输出 price/silhouette/author/sortOrder/isActive 字段。
```

- [ ] 实现 `ai-analyze.service.ts`：

```ts
// analyze(image) 编排：
// 1. 校验：mimetype ∈ ['image/jpeg','image/png','image/webp']，否则 400 '仅支持 jpg/png/webp 图片'；
//    buffer.byteLength > MAX_IMAGE_BYTES(8MB) → 400（文案同 admin-templates 的 assertFileSize 风格）
// 2. categories = db.select from template_categories where is_active=1（转 CategoryNode[]）
// 3. cfg = aiConfigService.getActiveConfig()（未配置/未启用 → 503）
// 4. content = await visionChat(cfg, { systemPrompt: buildAnalyzeSystemPrompt(categories),
//      userText: buildAnalyzeUserPrompt(), imageBase64: image.buffer.toString('base64'),
//      imageMime: image.mimetype, temperature: 0.3, jsonMode: true })
// 5. json = extractJson(content)；!json → BadRequestException('模型输出无法解析为 JSON，请重试识别')
// 6. return normalizeDraft(json, categories)
```

- [ ] 创建 `ai-templates.controller.ts`（本任务先实现 ai-analyze 一个端点，Task 7/9 再往里加）：

```ts
@Controller('admin/templates')
@UseGuards(AdminAuthGuard)
export class AiTemplatesController {
  constructor(
    private readonly aiAnalyzeService: AiAnalyzeService,
    /* 后续任务注入 image/silhouette service */
  ) {}

  @Post('ai-analyze')
  async analyze(@Req() req: FastifyRequest) {
    const { image } = await parseAiMultipart(req);
    if (!image) throw new BadRequestException('Missing "image" file');
    return this.aiAnalyzeService.analyze(image);
  }
}

// 模块内小型 multipart 助手（不复用 admin-templates.controller 的专用解析器，
// 后者字段名固定 cover/silhouette/pptpl/icon/images）：
// 解析字段：meta（文本）+ image / reference（文件）；参照 admin-templates.controller.ts
// 的 parseMultipart 实现（request.parts() 异步迭代 + part.toBuffer()）。
export async function parseAiMultipart(req: FastifyRequest): Promise<{ meta: string | null; image?: UploadFile; reference?: UploadFile }>
```

- [ ] `ai.module.ts` 注册 `AiTemplatesController`、`AiAnalyzeService`。
- [ ] **单测** `ai-analyze.service.spec.ts`（`jest.mock('./llm-client')`，`DatabaseService`/`AiConfigService` 用手工 stub 对象注入）：验证编排顺序、图片校验 400、未配置 503 透传、模型输出经 normalize 后 warnings 透传、extractJson null → 400「模型输出无法解析」。
- [ ] **e2e** `test/ai-analyze.e2e-spec.ts`（骨架同 Task 4，请求用 supertest `.field('meta','x')` / `.attach('image', buffer, 'a.jpg')` 模拟 multipart，参考 templates.e2e-spec 里对 multipart 的用法，若无则用 supertest 原生 attach）：
  - 未配置（不保存 ai-config）→ POST `/api/v1/admin/templates/ai-analyze` → 503，message 含「AI 设置」
  - 缺 image 文件 → 400
  - 非法 mimetype（attach 一个 text/plain）→ 400
- [ ] `pnpm --filter @lumira/backend build` + 单测 + 新 e2e 全绿。
- [ ] Commit: `feat(backend-ai): vision analyze endpoint with prompt builder and draft normalization`

---

### Task 6: 生图提示词 builder（TDD）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/image-prompt.builder.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/image-prompt.builder.spec.ts`

**Interfaces:**
- Consumes: 草稿 JSON（Task 5 输出的 draft 结构）。
- Produces（Task 7 依赖）:

```ts
/** 从草稿合成生图 prompt（中文，一段式描述）。前端不拼 prompt。 */
export function buildImagePrompt(draft: Record<string, unknown>): string;
```

**Steps:**

- [ ] **先写失败测试**：给定设计文档 §四 的完整草稿，断言输出包含：画幅（"3:4"）、分类链中文名（人像/清新治愈）、tags（"日系"）、场景背景（"田野与天空"）、光线（"侧逆光"）、最佳时段（"午后4-6点"）、LUT 中文标签（"日系清新"）、氛围关键词；空草稿 → 返回非空兜底串（"一张 3:4 竖构图的人像摄影作品…"）。
- [ ] 实现：按 `meta.classification（用分类树名或 tags 兜底）→ meta.tags → composition.aspectRatio/description → sceneGuide.background/lightDirection/bestTime/props → postProcess.lut 标签/grain → meta.shortDesc/description` 顺序拼成自然中文段落，格式固定为「一张{画幅}{主体类型}摄影作品，风格{…}，{光线}，背景{…}，{氛围/后期}」。字段缺失跳过，空草稿走兜底模板。
- [ ] 单测通过。
- [ ] Commit: `feat(backend-ai): image generation prompt builder from template draft (TDD)`

---

### Task 7: 生图客户端（四厂商适配）+ ai-generate-image 端点

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/image-client.ts`
- Create: `lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-templates.controller.ts`（加 `@Post('ai-generate-image')`）
- Modify: `lumira-server/packages/backend/src/modules/ai/ai.module.ts`（注册 service）
- Test: `lumira-server/packages/backend/src/modules/ai/image-client.spec.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.spec.ts`

**Interfaces:**
- Consumes: Task 6 `buildImagePrompt`、Task 4 `getActiveConfig`。
- Produces:

```ts
// image-client.ts
export interface GenerateImageInput {
  prompt: string;
  size: string;                 // 形如 '1024x1024'（厂商格式）
  referenceBase64?: string;     // 有参考图时优先图生图（仅 doubao/openai 真正支持）
  referenceMime?: string;
}
export interface GenerateImageResult { base64: string; mimeType: string; }

/** 按厂商分发：doubao/zhipu/openai 同步 /images/generations（或 edits），qwen wanx 异步任务轮询 */
export async function generateImage(cfg: ActiveAiConfig, input: GenerateImageInput): Promise<GenerateImageResult>;

/** 画幅映射：'3:4' 等草稿 ratio → 各厂商最接近的支持尺寸（'1024*1024' 等） */
export function mapSize(provider: string, aspectRatio: string | undefined): string;

// ai-generate-image.service.ts
@Injectable() export class AiGenerateImageService {
  /** reference 可选；meta 为草稿 JSON 字符串 */
  async generate(reference: UploadFile | undefined, metaJson: string | null): Promise<GenerateImageResult>;
}

// HTTP：POST /api/v1/admin/templates/ai-generate-image（multipart: 可选 reference 文件 + meta 文本）
// → { image: base64, mimeType: 'image/png' }
```

**Steps:**

- [ ] **先写 image-client 单测**（mock global.fetch），按厂商分组：

```ts
// doubao：POST `${baseUrl}/images/generations`，body {model, prompt, size, ...(ref ? {image: `data:${refMime};base64,${ref}`} : {})}
//   → resp.data[0].b64_json；若返回 url 字段则 fetch url 转 base64
// zhipu：POST `${baseUrl}/images/generations`，body {model, prompt, size}（纯文生图，忽略参考图）
//   → data[0].b64_json（或 url 兜底）
// openai：无参考图 → POST `${baseUrl}/images/generations` {model, prompt, size, response_format:'b64_json'}
//   有参考图 → POST `${baseUrl}/images/edits`（FormData: image 文件 + prompt + model + size）
//   → data[0].b64_json
// qwen：POST `${origin}/api/v1/services/aigc/text2image/image-synthesis`（origin = baseUrl 去掉路径），
//   headers {Authorization: Bearer, 'X-DashScope-Async': 'enable'}，
//   body {model, input:{prompt}, parameters:{size, n:1}}
//   → output.task_id → GET `${origin}/api/v1/tasks/${task_id}` 轮询（间隔 2s，上限 60s）
//   → task_status==='SUCCEEDED' → results[0].url → fetch 该 url → base64
// mapSize 用例：doubao '3:4'→'864x1152'、'1:1'→'1024x1024'、'9:16'→'720x1440'；
//   zhipu '3:4'→'864x1152'、'9:16'→'768x1344'；openai '3:4'→'1024x1536'、'16:9'→'1536x1024'；
//   qwen '3:4'→'720*1280'、'1:1'→'1024*1024'；未知 ratio 兜底 1:1
```

尺寸映射表以「各厂商文档为准微调」为注释写在 mapSize 上方（实现时如与文档冲突，以厂商文档修正并在测试同步改）。

- [ ] 实现 `image-client.ts`。通用错误处理同 llm-client（401/403 → 认证错误文案；超时 AbortSignal.timeout(120_000)；wanx 轮询超时 → '生图任务超时'）。
- [ ] 实现 `ai-generate-image.service.ts`：

```ts
// generate(reference, metaJson):
// 1. cfg = aiConfigService.getActiveConfig()（503）
// 2. meta = metaJson ? JSON.parse : {}（解析失败 400）
// 3. prompt = buildImagePrompt(meta)；size = mapSize(cfg.provider, meta?.composition?.aspectRatio)
// 4. return generateImage(cfg, { prompt, size,
//      referenceBase64: reference?.buffer.toString('base64'), referenceMime: reference?.mimetype })
//    （qwen/zhipu 内部忽略参考图走文生图，由 image-client 分支处理）
```

- [ ] controller 加端点：

```ts
@Post('ai-generate-image')
async generateImage(@Req() req: FastifyRequest) {
  const { meta, reference } = await parseAiMultipart(req);
  return this.aiGenerateImageService.generate(reference, meta);
}
```

- [ ] service 单测（mock image-client + AiConfigService stub）：未配置 503、meta 非法 JSON 400、prompt/size 正确传递、参考图 base64 透传。
- [ ] `pnpm --filter @lumira/backend build` + 单测全绿。
- [ ] Commit: `feat(backend-ai): per-provider image generation client (qwen async task, doubao/zhipu/openai sync) + endpoint`

---

### Task 8: 剪影本地管线（sharp + RMBG-1.4）

**Files:**
- Create: `lumira-server/packages/backend/scripts/fetch-rmbg-model.mjs`
- Create: `lumira-server/packages/backend/assets/models/.gitkeep`
- Create: `lumira-server/packages/backend/src/modules/ai/silhouette.pipeline.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/silhouette.pipeline.spec.ts`
- Modify: `lumira-server/packages/backend/package.json`（dependencies 加 `sharp`、`onnxruntime-node`）
- Modify: `lumira-server/packages/backend/.gitignore` 或仓库根 `.gitignore`（忽略 `assets/models/*.onnx`）
- Modify: `lumira-server/pnpm-lock.yaml`（由安装命令自动更新）

**Interfaces:**
- Consumes: 新依赖 `sharp`（^0.33）、`onnxruntime-node`（^1.20）；模型文件 `assets/models/rmbg-1.4.quant.onnx`（~44MB，脚本下载，不进 git）。
- Produces（Task 9 依赖）:

```ts
export interface SilhouetteOptions { mode: 'sketch' | 'solid'; crop: boolean; }

/** 纯函数：alpha 通道包围盒。threshold=0.3，padRatio=0.05；无前景返回 null */
export function computeAlphaBbox(alpha: Uint8Array | Float32Array, width: number, height: number,
  threshold?: number, padRatio?: number): { left: number; top: number; width: number; height: number } | null;

/** 本地管线：抠图 → 线稿/实心 → 可选裁剪 → 透明底 PNG buffer。模型缺失抛 ServiceUnavailableException */
export async function generateSilhouettePng(input: Buffer, opts: SilhouetteOptions): Promise<Buffer>;

/** 单例 session 懒加载（进程内只 load 一次）；动态 import('onnxruntime-node') 避免启动时加载原生模块 */
export async function getRmbgSession(): Promise<InferenceSession>;
```

**Steps:**

- [ ] 安装依赖：`pnpm --filter @lumira/backend add sharp onnxruntime-node`（lockfile 会更新，随本任务 commit）。
- [ ] 创建模型下载脚本 `scripts/fetch-rmbg-model.mjs`：

```js
// 依次尝试 hf-mirror.com / huggingface.co 下载：
//   {host}/briaai/RMBG-1.4/resolve/main/onnx/model_quantized.onnx
// 写入 packages/backend/assets/models/rmbg-1.4.quant.onnx；已存在且 >40MB 则跳过；
// 下载后校验 size > 40 * 1024 * 1024，否则删除并报错。
```

- [ ] 本地跑一次脚本下载模型（开发机验证管线可用）。
- [ ] `.gitignore` 加 `lumira-server/packages/backend/assets/models/*.onnx`。
- [ ] **先写单测** `silhouette.pipeline.spec.ts`：
  - `computeAlphaBbox`（纯函数，无需模型）：全零 alpha → null；中心方块 → bbox 含方块 + padding；clamp 到图像边界。
  - 管线集成（describe.skip 若模型文件不存在：`const modelPath = resolveModelPath(); const has = fs.existsSync(modelPath); (has ? describe : describe.skip)(...)`）：
    - 用 sharp 合成 64x64 测试图（红底 + 中央黑色圆），solid 模式 → 输出 PNG 有 alpha 通道、尺寸 64x64；crop=true → 输出为 bbox 裁剪后尺寸（宽高 < 64）。
    - sketch 模式 → 输出 PNG 成功，且多数像素为透明/浅色、存在深色线稿像素（统计 raw alpha/亮度分布，阈值断言宽松）。
- [ ] 实现 `silhouette.pipeline.ts`：

```ts
// resolveModelPath(): process.env.RMBG_MODEL_PATH
//   || path.join(__dirname, '../../../assets/models/rmbg-1.4.quant.onnx')
//   （dev：src/modules/ai → 上溯 3 级 = packages/backend；dist：dist/modules/ai → 同样 3 级）
// getRmbgSession(): 单例；文件不存在 → ServiceUnavailableException('剪影模型未安装，请在服务器执行 scripts/fetch-rmbg-model.mjs')
//   const ort = await import('onnxruntime-node'); session = await ort.InferenceSession.create(modelPath)
// generateSilhouettePng(input, opts):
// ① matte = await runRmbg(input)
//    sharp(input).resize(1024,1024,{fit:'fill'}).removeAlpha().raw().toBuffer({resolveWithObject:true})
//    → 按 ImageNet mean/std(0.485/0.456/0.406, 0.229/0.224/0.225) 归一化 → NCHW Float32Array
//    → new ort.Tensor('float32', data, [1,3,1024,1024]) → session.run({[session.inputNames[0]]: tensor})
//    → 输出 [1,1,1024,1024]（session.outputNames[0]），clamp 0..1
// ② 原尺寸 alpha：matte(1024²) → sharp(raw 1024x1024 1ch).resize(origW, origH).raw()
// ③ cutout = sharp(input).joinChannel(alphaRaw, {raw:{width:origW,height:origH,channels:1}}).png()
// ④ solid：sharp({create:{width,height,channels:3,background:{r:0,g:0,b:0}}})
//        .joinChannel(alphaRaw,{raw:{...}}).png()
//    sketch：gray = cutout 灰度；inv = gray.negate().blur(4)；
//        sharp(gray).composite([{input: inv, blend: 'colour-dodge'}]) → 线稿
//        再 joinChannel alphaRaw 恢复人物 alpha（背景透明）
//        （blend 结果以集成测试目测校准：若线稿/背景相反，交换 base 与 source）
// ⑤ crop：computeAlphaBbox(alphaRaw, origW, origH) → sharp(结果图).extract(bbox)
// ⑥ 返回 png buffer
```

- [ ] `pnpm --filter @lumira/backend test` 全绿（本机有模型时集成用例执行，无模型时 skip）。
- [ ] Commit: `feat(backend-ai): local silhouette pipeline with RMBG-1.4 matting + sharp sketch/solid modes`

---

### Task 9: 剪影端点 ai-generate-silhouette

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/ai-generate-silhouette.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-templates.controller.ts`（加 `@Post('ai-generate-silhouette')`）
- Modify: `lumira-server/packages/backend/src/modules/ai/ai.module.ts`（注册 service）
- Test: `lumira-server/packages/backend/test/ai-silhouette.e2e-spec.ts`

**Interfaces:**
- Consumes: Task 8 `generateSilhouettePng`、`parseAiMultipart`（Task 5）。
- Produces:

```ts
// HTTP：POST /api/v1/admin/templates/ai-generate-silhouette
// multipart: image 文件 + meta 文本（JSON: { mode: 'sketch'|'solid', crop: boolean }）
// → { image: base64, mimeType: 'image/png' }
// 注意：本端点不依赖 ai-config 是否配置/启用（纯本地计算），仅 AdminAuthGuard。
```

**Steps:**

- [ ] service 实现：校验 image（jpg/png/webp、≤8MB）；meta 解析（缺省 `{mode:'sketch', crop:true}`；mode 非法 → 400）；调 `generateSilhouettePng` → `{ image: buf.toString('base64'), mimeType: 'image/png' }`。
- [ ] controller：

```ts
@Post('ai-generate-silhouette')
async generateSilhouette(@Req() req: FastifyRequest) {
  const { image, meta } = await parseAiMultipart(req);
  if (!image) throw new BadRequestException('Missing "image" file');
  return this.aiSilhouetteService.generate(image, meta);
}
```

- [ ] e2e（模型缺失时返回 503 的分支在 CI 无模型环境也可测）：
  - 缺 image → 400
  - meta.mode='invalid' → 400
  - 合法请求 + 本机无模型 → 503「剪影模型未安装」（若本机已下载模型则跳过此断言，改为断言 200 + base64 非空，用 `fs.existsSync(resolveModelPath())` 分支）
- [ ] `pnpm --filter @lumira/backend build` + 全部单测/e2e 绿。
- [ ] Commit: `feat(backend-ai): silhouette generation endpoint (local pipeline, provider-independent)`

---

### Task 10: 后端检查点 — 全量验证 + 双远程推送

**Files:** 无新文件（验证任务）

**Steps:**

- [ ] `pnpm --filter @lumira/shared build && pnpm --filter @lumira/backend build`
- [ ] `pnpm --filter @lumira/backend test`（全部单测）
- [ ] `pnpm --filter @lumira/backend test:e2e`（需本地 MySQL，环境变量同既有 e2e）
- [ ] 确认 git status 无遗漏文件（migrations/028、modules/ai/*、scripts/fetch-rmbg-model.mjs、pnpm-lock.yaml 已全部纳入）。
- [ ] Push 双远程（这是后端半成品可部署的检查点——迁移只建新表、新端点不影响现有链路）：
  - `git push origin master`（gitee）
  - `git push github master`（github，将触发 backend-deploy 生产部署，属预期）
- [ ] 观察一次 GitHub Actions backend-deploy 成功（gh run watch 或网页确认），失败则修复后再推送。

---

### Task 11: admin API 客户端 + AI server actions

**Files:**
- Modify: `lumira-server/packages/admin/src/lib/api.ts`（api 对象追加 6 个方法）
- Modify: `lumira-server/packages/admin/src/types/admin.ts`（追加 AI 类型）
- Create: `lumira-server/packages/admin/src/actions/ai.ts`

**Interfaces:**
- Consumes: 现有 `adminFetch`（自动带 Authorization + `/api/v1/admin` 前缀 + FormData 支持）。
- Produces:

```ts
// types/admin.ts
export interface AiProviderConfigView {
  configured: boolean; provider: string; baseUrl: string; apiKeyMasked: string;
  visionModel: string; imageModel: string; enabled: boolean;
}
export interface AiConfigTestResult { vision: { ok: boolean; latencyMs?: number; error?: string }; note: string }
export interface AiAnalyzeResult { draft: Record<string, unknown>; warnings: string[] }
export interface AiImageResult { image: string; mimeType: string }  // image = base64

// api 对象新增（全部经 adminFetch）
getAiConfig: () => adminFetch<AiProviderConfigView>('/ai-config'),
saveAiConfig: (payload: UpdateAiConfigPayload) => adminFetch<AiProviderConfigView>('/ai-config', { method: 'PUT', body: JSON.stringify(payload) }),
testAiConfig: () => adminFetch<AiConfigTestResult>('/ai-config/test', { method: 'POST' }),
aiAnalyze: (formData: FormData) => adminFetch<AiAnalyzeResult>('/templates/ai-analyze', { method: 'POST', body: formData }),
aiGenerateImage: (formData: FormData) => adminFetch<AiImageResult>('/templates/ai-generate-image', { method: 'POST', body: formData }),
aiGenerateSilhouette: (formData: FormData) => adminFetch<AiImageResult>('/templates/ai-generate-silhouette', { method: 'POST', body: formData }),

// actions/ai.ts（'use server'，供客户端组件调用；错误处理照抄 actions/templates.ts 模式：
// UnauthenticatedError → redirect('/login')，其他抛出/返回由调用方 toast）
export async function getAiConfigAction(): Promise<AiProviderConfigView>
export async function saveAiConfigAction(payload): Promise<{ ok: true; config } | { error: string }>
export async function testAiConfigAction(): Promise<AiConfigTestResult | { error: string }>
export async function aiAnalyzeAction(formData: FormData): Promise<AiAnalyzeResult | { error: string }>
export async function aiGenerateImageAction(formData: FormData): Promise<AiImageResult | { error: string }>
export async function aiGenerateSilhouetteAction(formData: FormData): Promise<AiImageResult | { error: string }>
```

**Steps:**

- [ ] types/admin.ts 追加类型（放文件末尾 AI 分区注释下）。
- [ ] api.ts 的 api 对象追加 6 个方法（放通知管理之后，新分区注释 `// ===== AI 一键模板录入 =====`）。
- [ ] 创建 actions/ai.ts，逐一实现（server action 薄封装：调 api → 错误转 `{ error: message }`，成功原样返回；不 revalidatePath，AI 生成过程不涉及列表页缓存）。
- [ ] `pnpm --filter @lumira/admin build` 通过。
- [ ] Commit: `feat(admin): AI api client methods and server actions`

---

### Task 12: AI 设置页 + sidebar 入口

**Files:**
- Create: `lumira-server/packages/admin/src/app/dashboard/ai-config/page.tsx`（server 组件）
- Create: `lumira-server/packages/admin/src/components/ai-config-form.tsx`（client 组件）
- Modify: `lumira-server/packages/admin/src/components/sidebar.tsx`（加「AI 设置」导航项）

**Interfaces:**
- Consumes: Task 11 的 actions；shadcn/ui（Card/Input/Button/Switch/RadioGroup/Label/Alert 等现有组件）；Phosphor Icons（`@phosphor-icons/react` 的 `Brain`）。
- Produces: 路由 `/dashboard/ai-config`。

**Steps:**

- [ ] `page.tsx`：server 组件调 `getAiConfigAction()` 传初始值给 `<AiConfigForm initial={...} />`（try/catch，UnauthenticatedError → redirect('/login')）。
- [ ] `ai-config-form.tsx`（client）：

```tsx
// 厂商预设（前端本地常量，仅供默认值填充，均可手改）：
const PROVIDER_PRESETS = {
  qwen:    { baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1', visionModel: 'qwen-vl-max', imageModel: 'wanx2.1-t2i-turbo' },
  doubao:  { baseUrl: 'https://ark.cn-beijing.volces.com/api/v3', visionModel: 'doubao-1.5-vision-pro-32k', imageModel: 'doubao-Seedream-4-0-250828' },
  zhipu:   { baseUrl: 'https://open.bigmodel.cn/api/paas/v4', visionModel: 'glm-4v-plus', imageModel: 'cogview-4' },
  openai:  { baseUrl: 'https://api.openai.com/v1', visionModel: 'gpt-4o', imageModel: 'gpt-image-1' },
} as const;
// UI 结构：
// 1. 厂商四卡（RadioGroup + Card）：选中 → 自动填充 baseUrl/visionModel/imageModel（仅当用户未手动改过时覆盖）
// 2. 表单字段：baseUrl（Input）、apiKey（type=password，placeholder 显示脱敏值「留空 = 不修改」）、
//    visionModel（Input，豆包提示可填接入点 ep-xxx）、imageModel（Input）、enabled（Switch「启用 AI 功能」）
// 3. 按钮行：「保存」（saveAiConfigAction，成功 toast「已保存，新请求将使用新配置」）
//    「测试连接」（testAiConfigAction，按钮 loading；结果 Alert 显示 vision.ok/latencyMs/error + note）
// 4. 顶部信息条：未配置时提示「AI 未配置，向导页的识别/生图功能将不可用」
// 视觉遵循现有 admin 页面（shadcn 默认样式，参照 categories 或 scenes 管理页布局），不引入新配色。
```

- [ ] sidebar.tsx：navItems 模板管理分组加 `{ href: '/dashboard/ai-config', label: 'AI 设置', icon: Brain }`（import Brain from '@phosphor-icons/react'，分组归属与「模板管理」同组）。
- [ ] `pnpm --filter @lumira/admin build` 通过；本地 `pnpm --filter @lumira/admin dev` 手动过一遍：四卡切换预填、保存、脱敏回显、留空不改。
- [ ] Commit: `feat(admin): AI provider config page with presets, masking and connectivity test`

---

### Task 13: TemplateForm 提取 applyTemplateJson + AI 注入 props

**Files:**
- Modify: `lumira-server/packages/admin/src/components/template-form.tsx`

**Interfaces:**
- Consumes: 现有 `handlePptplUpload`（约 542-699 行）。
- Produces（Task 14 依赖）:

```ts
export interface TemplateFormAiInjection {
  stamp: number;                        // 每次注入递增；变化触发应用
  json?: Record<string, unknown>;       // 草稿，走 applyTemplateJson 回填
  images?: File[];                      // 效果图列表
  replaceImages?: boolean;              // true=替换 imageFiles；false=追加
  silhouette?: File | null;             // 应用到当前姿势（poseIndex）
  isActive?: boolean;                   // Step5 决策回填
  autoSubmit?: boolean;                 // true=应用后立即提交（全自动模式，isActive 需同时给 true）
}

interface TemplateFormProps {
  categories: TemplateCategory[];
  initial?: AdminTemplateDetail;
  templateId?: string;
  backendUrl?: string;
  /** AI 向导注入（详见 TemplateFormAiInjection） */
  aiInjection?: TemplateFormAiInjection | null;
  /** 向导模式：底部提交区渲染「上架 / 保存为未上架」双按钮 */
  wizardMode?: boolean;
}
```

**Steps:**

- [ ] **纯重构第一步**：把 `handlePptplUpload` 中 `JSON.parse` 之后、`setPptplFile(file)`/toast 之前的表单回填逻辑（约 559-685 行）提取为组件内函数：

```ts
const applyTemplateJson = (json: Record<string, unknown>) => {
  // 原样搬移：meta/composition/pose/camera/sceneGuide/postProcess 全部 setValue/setPoses/
  // setPoseIndex/setCropRatioLinked 逻辑，一行不改
};
// handlePptplUpload 变为：读文件 → JSON.parse → applyTemplateJson(json) → setPptplFile(file) → toast
```

- [ ] 跑 `pnpm --filter @lumira/admin build` 确认重构无破坏（此步单独提交也可，并入本任务提交）。
- [ ] **扩展 props**：TemplateFormProps 加 `aiInjection` / `wizardMode`（均可选，缺省行为完全不变）。
- [ ] 新增 useEffect（放在现有 hooks 之后）：

```tsx
useEffect(() => {
  if (!aiInjection || !aiInjection.stamp) return;
  if (aiInjection.json) applyTemplateJson(aiInjection.json);
  if (aiInjection.images && aiInjection.images.length > 0) {
    if (aiInjection.replaceImages) {
      setImageFiles(aiInjection.images);
      setImagePreviews(aiInjection.images.map((f) => URL.createObjectURL(f)));
    } else {
      setImageFiles((prev) => [...prev, ...aiInjection.images!]);
      setImagePreviews((prev) => [...prev, ...aiInjection.images!.map((f) => URL.createObjectURL(f))]);
    }
  }
  if (aiInjection.silhouette) {
    const file = aiInjection.silhouette;
    setPoses((prev) => prev.map((p, i) => i === poseIndex
      ? { ...p, silhouetteType: 'image' as const, silhouetteFile: file, silhouetteUrl: URL.createObjectURL(file) }
      : p));
  }
  if (typeof aiInjection.isActive === 'boolean') setValue('isActive', aiInjection.isActive);
  if (aiInjection.autoSubmit) submitRef.current?.();  // 见下一步
  // eslint-disable-next-line react-hooks/exhaustive-deps
}, [aiInjection?.stamp]);
```

- [ ] 确认 FormValues 是否已有 `isActive` 字段（检索 `setValue('isActive'` / schema 的 isActive）：无则在 defaultValues 加 `isActive: true` 并确认 onSubmit 的 meta 里包含它；有则跳过。
- [ ] 提交入口：现有提交按钮 onClick/submit handler 提为可复用（如 `const doSubmit = (active: boolean) => { setValue('isActive', active); /* 触发现有 handleSubmit 流程 */ }`；RHF 下用 `handleSubmit(onSubmit)()`）。存 `submitRef.current = () => doSubmit(true)` 供 autoSubmit。**wizardMode 为 true 时**底部提交区渲染：

```tsx
{wizardMode ? (
  <>
    <Button type="button" disabled={isPending} onClick={() => doSubmit(true)}>上架</Button>
    <Button type="button" variant="outline" disabled={isPending} onClick={() => doSubmit(false)}>保存为未上架</Button>
  </>
) : (
  /* 现有提交按钮原样保留 */
)}
```

- [ ] 回归验证：`pnpm --filter @lumira/admin build`；dev 环境手动走一遍**原有**新建/编辑/`.pptpl` 导入流程无回归。
- [ ] Commit: `refactor(admin): extract applyTemplateJson; add aiInjection/wizardMode props to TemplateForm`

---

### Task 14: AI 一键建模向导页

**Files:**
- Create: `lumira-server/packages/admin/src/app/dashboard/templates/ai-create/page.tsx`（server）
- Create: `lumira-server/packages/admin/src/components/ai-create/wizard.tsx`（client，主状态机 + Step1/2/5 面板）
- Create: `lumira-server/packages/admin/src/components/ai-create/step-cover.tsx`（client，Step3 封面决策）
- Create: `lumira-server/packages/admin/src/components/ai-create/step-silhouette.tsx`（client，Step4 剪影决策）

**Interfaces:**
- Consumes: Task 11 actions、Task 13 `TemplateFormProps.aiInjection/wizardMode`、现有 `compressImage` 工具（template-form.tsx 内 handleImagePick 所用，检索其 import 来源复用）、shadcn 组件。
- Produces: 路由 `/dashboard/templates/ai-create`。

**Steps:**

- [ ] `page.tsx`（server）：

```tsx
// 照抄 templates/page.tsx 骨架：api.listCategories() + UnauthenticatedError redirect
// 返回 <AiCreateWizard categories={categories} backendUrl={BACKEND_URL} />
```

- [ ] `wizard.tsx`（client）核心状态机：

```tsx
// 状态：
// step: 1|2|3|4|5（向导级步骤；TemplateForm 从 step>=2 起常驻渲染在决策面板下方）
// exampleFile: File | null（示例图，上传时经 compressImage({maxDim:1280, quality:0.8}) 压缩——
//   Vercel Serverless 请求体 4.5MB 限制，压缩后仍 >3MB 则二次 maxDim:1024）
// draft / warnings：识别结果
// coverCandidates: { id: string; file: File; url: string; source: 'example' | 'ai' }[]
// silhouetteFile: File | null
// injection: TemplateFormAiInjection | null（stamp 自增触发 TemplateForm 应用）
// autoState: { running: boolean; stage: 'analyzing'|'generating-image'|'generating-silhouette'|'submitting'; error?: string }
//
// 顶部 stepper（1 上传示例图 → 2 风格识别 → 3 封面决策 → 4 剪影决策 → 5 提交）
//
// Step1 面板：拖拽/选择上传（校验 jpg/png/webp；≤8MB 原图限制提示）+ 预览图
//   按钮：「开始识别」→ aiAnalyzeAction(fd) →
//     成功：setDraft/setWarnings；injection={stamp+1, json:draft, images:[exampleFile], replaceImages:true}；step=2
//     失败：toast error（503 文案含「AI 设置」引导，附 Link）
//   按钮：「全自动生成并上架」→ runAutoAll()：
//     ① analyze → 注入草稿（stage: analyzing）
//     ② aiGenerateImageAction(ref=example + meta=draft) → base64 转 File（new File([Blob], 'ai-cover-1.png', {type:'image/png'})）
//        → candidates=[aiImg] → 注入 images replace（stage: generating-image）
//        失败：停 step=3，error=生图失败信息，candidates 保底=[example]，草稿保留（转人工）
//     ③ aiGenerateSilhouetteAction(image=封面图, meta={mode:'sketch', crop:true}) → 转 File（stage: generating-silhouette）
//        失败：停 step=4，剪影留空转人工
//     ④ injection={stamp+1, autoSubmit:true, isActive:true}（stage: submitting；提交由 TemplateForm 完成，成功后其内部 redirect 到模板列表）
//   全自动期间顶部显示进度条/阶段文案；running 时禁用所有按钮
//
// Step2 面板：warnings 非空 → 黄色 Alert 列表（「AI 修正了以下内容，请重点复核」）；
//   提示「草稿已回填到下方表单，全部字段可修改」+「下一步：选择封面」
//   下方渲染 <TemplateForm categories backendUrl wizardMode aiInjection={injection} />
//
// Step3 面板（step-cover.tsx）：
//   props: { exampleFile, draft, candidates, setCandidates, onApply(files: File[]): void }
//   选项：「用示例图」（默认勾选）——将 example 置顶候选
//   「生成效果图」按钮 → aiGenerateImageAction(ref=example, meta=draft)（可多次点击重 roll，可换不同结果）
//   候选缩略图网格：单选封面标记（点击置顶）、左右移排序、删除；首图=封面徽标
//   「应用为封面」→ onApply(orderedFiles) → wizard 注入 {stamp+1, images: orderedFiles, replaceImages:true} → step=4
//
// Step4 面板（step-silhouette.tsx）：
//   props: { coverFile, exampleFile, onApply(file: File | null): void }
//   源图选择（RadioGroup）：封面图（默认）/ 示例图
//   模式：线稿 sketch（默认）/ 实心 solid；自动裁剪 Switch（默认开）
//   「生成剪影」→ aiGenerateSilhouetteAction → base64 → 预览（透明棋盘格：CSS
//     background-image 线性渐变网格 + img 叠放）
//   「应用到姿势」→ onApply(file) → wizard 注入 {stamp+1, silhouette: file} → step=5
//   「跳过剪影」→ onApply(null) → step=5
//
// Step5 面板：说明文案「确认无误后，在下方表单底部点击『上架』或『保存为未上架』完成提交」
//   （提交按钮即 TemplateForm wizardMode 底部双按钮，走现有 createTemplate action + redirect）
//
// base64→File 助手（wizard.tsx 导出，两个 step 复用）：
// export function base64ToFile(b64: string, mime: string, name: string): File
```

- [ ] 实现三个文件；视觉遵循现有 admin 设计语言（Card 分区、现有字号间距），决策面板宽度与表单一致。
- [ ] `pnpm --filter @lumira/admin build` 通过。
- [ ] 本地 dev 全链路手动验证（配好真实 apiKey）：
  - 手动路径：上传 → 识别（warnings 黄条）→ 表单已回填 → 生成效果图重 roll → 应用封面 → 线稿剪影预览 → 应用 → 保存为未上架 → 模板列表出现（未上架）→ 编辑上架。
  - 全自动路径：上传 → 一键 → 自动落在模板列表（已上架）。
  - 失败路径：改错 apiKey → 识别报 401 文案引导设置页；生图失败停在 Step3 且草稿/示例图仍在。
- [ ] Commit: `feat(admin): AI one-click template creation wizard (5 steps + full-auto mode)`

---

### Task 15: 模板列表「AI 创建」入口

**Files:**
- Modify: `lumira-server/packages/admin/src/components/template-card-grid.tsx`（新建按钮旁加「AI 创建」）
- Modify: `lumira-server/packages/admin/src/components/sidebar.tsx`（模板管理分组加「AI 创建模板」）

**Interfaces:**
- Consumes: 现有「新建模板」按钮区（template-card-grid.tsx 顶部操作区）；Phosphor `MagicWand` 图标。
- Produces: 到 `/dashboard/templates/ai-create` 的导航入口 ×2。

**Steps:**

- [ ] template-card-grid.tsx：在「新建模板」按钮旁加 `<Link href="/dashboard/templates/ai-create">` 按钮（variant 区分，如 outline + MagicWand 图标，文案「AI 创建」）。
- [ ] sidebar.tsx：模板管理分组加 `{ href: '/dashboard/templates/ai-create', label: 'AI 创建模板', icon: MagicWand }`（置于「模板管理」之后、「AI 设置」之前）。
- [ ] `pnpm --filter @lumira/admin build` 通过。
- [ ] Commit: `feat(admin): add AI create entry to template list and sidebar`

---

### Task 16: Dockerfile 与部署适配

**Files:**
- Modify: `lumira-server/packages/backend/Dockerfile`
- Modify: `lumira-server/packages/backend/scripts/fetch-rmbg-model.mjs`（若 Task 8 版本未考虑镜像回退则完善）
- Modify: `.github/DEPLOY.md`（部署注意附录，可选——仅当有新增服务器侧步骤时）

**Interfaces:**
- Consumes: Task 8 的模型下载脚本、新增依赖（sharp/onnxruntime-node 已在 lockfile）。
- Produces: 包含模型与原生依赖的生产镜像；无新增环境变量、无 compose 变更。

**Steps:**

- [ ] **基础镜像切换**（关键：`onnxruntime-node` 官方预编译产物面向 glibc，Alpine/musl 无法加载）：

```dockerfile
# base 与 runner 两个 stage 的 FROM node:20-alpine → node:20-slim
# 原 alpine 镜像源 sed 段替换为 Debian 源（bookworm）：
RUN sed -i 's|deb.debian.org|mirrors.aliyun.com|g' /etc/apt/sources.list.d/debian.sources || true \
 && sed -i 's|deb.debian.org|mirrors.aliyun.com|g' /etc/apt/sources.list || true \
 && apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl libstdc++6 \
 && rm -rf /var/lib/apt/lists/*
# （pnpm 安装与 registry 配置段保持不变；libc6-compat 相关 apk 行删除）
```

- [ ] builder stage（`pnpm install` 之后、build 之前）加模型下载：

```dockerfile
# RMBG-1.4 剪影模型（~44MB）：优先 hf-mirror，失败回退 huggingface（脚本内部处理）
RUN node packages/backend/scripts/fetch-rmbg-model.mjs
```

- [ ] runner stage 追加（dist 拷贝之后）：

```dockerfile
# 剪影模型资产
COPY --from=builder /app/packages/backend/assets/models/ packages/backend/assets/models/
```

- [ ] 本地验证镜像构建：`docker build -f lumira-server/packages/backend/Dockerfile -t lumira-backend-ai-test lumira-server/`（在 monorepo 根上下文执行，与 CI 的 build 路径一致；确认模型下载成功、镜像内 `node -e "require('onnxruntime-node')"` 可加载——可在 builder 里临时 RUN 验证后删除该行）。
- [ ] `.github/DEPLOY.md` 追加一行注意：镜像基础已切 Debian slim（体积增大约 150MB，含剪影模型 44MB）；无需改服务器 `.env`。
- [ ] Commit: `build(backend): switch docker base to node:20-slim, bundle RMBG-1.4 model and native deps`

---

### Task 17: 收尾 — 全量验证、手动验收清单、双远程推送

**Files:** 无新文件（验证 + 推送）。

**Steps:**

- [ ] 后端：`pnpm --filter @lumira/backend build && pnpm --filter @lumira/backend test && pnpm --filter @lumira/backend test:e2e`
- [ ] admin：`pnpm --filter @lumira/admin build`
- [ ] 核对 `docs/future-optimizations.md`：确认「Dify/Coze 工作流接入」与「全自动多姿势」两项已登记（设计文档声明已登记，仅核对，不重复添加；若缺失则按文档格式补登）。
- [ ] 手动验收清单（生产/预发，四厂商至少一家真实 key 冒烟）：
  1. AI 设置：四卡切换预填 → 保存 → apiKey 脱敏回显 → 留空保存不覆盖 → 测试连接显示延迟/错误
  2. 向导手动路径：上传 → 识别 → warnings 黄条 → 草稿回填（名称/分类四级/相机/后期/LUT 均有值）→ 生成效果图可重 roll 可排序 → 线稿剪影透明底预览 → 应用 → 上架 → App 端模板列表可见（Flutter 零改动验证）
  3. 全自动路径：一键 → 三阶段进度 → 模板自动上架出现
  4. 失败路径：错误 apiKey → 401 文案 + 引导；生图失败停在 Step3 草稿保留；未配置 → 503 引导
  5. 剪影本地性：关闭 AI 设置 enabled → 剪影生成仍可用（不依赖厂商）
  6. 旧功能回归：手工新建/编辑模板、`.pptpl` 导入、分类管理无回归
- [ ] Commit（如有零星修正）：`chore: final verification fixes for AI template creation`
- [ ] Push 双远程：
  - `git push origin master`
  - `git push github master`
- [ ] 确认 GitHub Actions：backend-deploy（新镜像含模型构建成功）与 admin Vercel 部署均成功；App 连生产后端冒烟一次 AI 识别。

---

## 任务依赖图

```
Task 1 (迁移/schema)
  → Task 4 (ai-config, 依赖表 + Task 3 client)
Task 2 (normalize) ─→ Task 5 (analyze, 依赖 2/3/4)
Task 3 (llm-client) ─→ Task 4/5
Task 6 (image prompt) → Task 7 (generate-image, 依赖 4/6)
Task 8 (silhouette pipeline, 独立) → Task 9 (silhouette endpoint)
Task 4+5+7+9 → Task 10 (后端检查点 push)
Task 10 → Task 11 (admin api/actions) → Task 12 (AI 设置页)
                                    → Task 13 (TemplateForm 扩展) → Task 14 (向导) → Task 15 (入口)
Task 8/16 (Dockerfile, 依赖模型脚本)
全部 → Task 17 (收尾 push)
```

## 风险与备注

- **厂商 API 形状漂移**：doubao/zhipu/openai 的 images 接口参数以各家文档为准，Task 7 的 mapSize/请求体如与文档冲突以文档为准（测试同步调整）；wanx 轮询间隔与超时同理。
- **Vercel 4.5MB 限制**：向导所有上传（示例图/参考图）必须先经 `compressImage` 压缩；生成结果走 JSON base64 响应不受限。
- **onnxruntime-node + Alpine 不兼容**：Task 16 基础镜像切换是硬前提，不可省略。
- **e2e 数据库**：ai-config/ai-analyze e2e 需要本地 MySQL（环境变量同既有 e2e 体系），CI 的 backend-ci.yml 已具备。
- **模型文件不入 git**（44MB），本地开发须先跑 `scripts/fetch-rmbg-model.mjs`；无模型时剪影端点 503、管线测试 skip，属预期降级。
