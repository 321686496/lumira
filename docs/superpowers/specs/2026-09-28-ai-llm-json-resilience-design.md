# AI 识别链路 JSON 容错与重试稳定性改造

> 日期：2026-09-28
> 状态：已确认方案，待实现
> 关联设计：docs/specs/2026-09-09-ai-template-one-click-creation-design.md、docs/superpowers/specs/2026-09-21-ai-template-trend-orchestrator-design.md、docs/superpowers/specs/2026-09-24-ai-llm-raw-trace-design.md

## 背景与痛点

用户反馈 AI 一键生成模板的「风格识别」链路两个问题：

1. **JSON 解析失败被静默跳过**：`示例图识别`（编排 `describe` 阶段）中 `extractJson` 失败直接 throw，被编排 `wrapStep` 吞掉后用占位 `desc` 继续，等于该步骤被静默降级，用户感知「识别不准」且无感知。
2. **流程动不动就超时**：单步硬编码超时（describe/poseRefSheet/imageScore/draftRefine 120s、styleProfile 60s），编排最多 3 轮「参数校准+评分+细化」，前端轮询总预算 600s，很容易顶穿 → 前端报「识别超时」。

**根因分析（已定位代码）**：

- [llm-client.ts](../lumira-server/packages/backend/src/modules/ai/llm-client.ts) `MAX_TOKENS = 4096`，而穷尽式识别（九宫格逐格 + 全字段 schema）要求的 JSON 极大 → **输出被截断是「无法解析 JSON」的高度可疑主因**。
- `extractJson`（normalize.ts）已有「直解 → 剥 ``` 围栏 → 首 `{` 到末 `}` 截取」，但对**截断 / 多余尾字符**无补救。
- 现有重试只覆盖「jsonMode 400/404 降级」和「5xx 重试一次」，**不含解析失败**，且次数不可配。

## 目标

- 示例图识别及其余全部 JSON 识别步骤：解析失败不再静默跳过，先结构补救，再自动重试（次数后台可配，默认 2 次）。
- 单步超时后台可配（默认 180s），超时自动重试；前端识别轮询总预算放宽到 900s。
- 输出上限提升到 8192 且后台可配，消除截断型解析失败。
- 全程保留实时过程可见性（每次尝试的提示词 / 原始响应 / 次数 / 失败原因）。

## 非目标

- 不改生图 / 剪影链路的超时与重试（生图/剪影前端轮询预算维持 600s）。
- 不臆造 JSON 内容：修复层只做结构性闭合，不猜字段。
- 不改变各步骤「解析失败后的业务降级语义」（评分仍回退 retry、细化仍回退 null），只是先重试再降级。

## 方案

### 1. 配置层（后台可配）

`ai_provider_config` 新增 3 列，迁移 `047_ai_config_llm_stability.sql`，全部 `NOT NULL DEFAULT`（存量行自动拿默认值，零数据迁移）：

| 列 | 默认 | 范围 | 语义 |
|---|---|---|---|
| `llm_retry_count` | 2 | 0~3 | 失败后额外重试次数；0=不重试，总调用次数 ≤ 次数+1 |
| `llm_timeout_ms` | 180000 | 10000~600000 | 单次 LLM 调用超时 |
| `llm_max_tokens` | 8192 | 1024~16384 | 单次输出上限（从 4096 提升） |

- `schema.ts` 补 3 列；`AiConfigView` / `getActiveConfig()` 增加 `runtime: { retryCount, timeoutMs, maxTokens }` 字段；`save()` / `get()` 透传。
- `UpdateAiConfigDto` 补 3 个可选整数/字符串字段（`IsInt + Min/Max` 校验），缺省 / `undefined` = 沿用原值；DTO 从 multipart 表单进入，字段可能是字符串，`save()` 用现有 `toIntOrNull` 风格做数值归一。
- 后台 `ai-config-form.tsx` 新增「识别稳定性」分区：重试次数（0~3，默认 2）、单次超时（秒，默认 180）、输出上限（默认 8192）。

### 2. JSON 容错层（normalize.ts `extractJson` 增强）

在现有「直解 → 剥围栏 → 首 `{` 到末 `}`」之后追加两道补救（纯结构性，不猜内容）：

1. **去尾随逗号 + 括号栈闭合**：把候选文本中的尾随逗号去掉，用括号栈补齐未闭合的 `}`/`]`（治截断）。
2. **平衡子串回退**：从末个 `}` 向前回退，截取最后一个**括号平衡**的 `{...}` 子串。

仍失败 → 返回 `null`（语义不变，交给重试层）。新增纯函数，供 `normalize.spec` 单测。

### 3. 重试层（新共享封装 `llm-json.ts`）

```ts
// 签名（保留原 trace 采集，重试天然产生多次 llm 事件）
export async function visionChatJson(cfg, input): Promise<Record<string, unknown>>
export async function textChatJson(cfg, input): Promise<Record<string, unknown>>
```

- 内部循环调用现有 `visionChat` / `textChat` → `extractJson`。
- **可重试原因**：JSON 解析失败 / 超时（AbortError/TimeoutError）/ 5xx / 空输出（返回内容为空）。
- **不可重试**：401/403/400/404 等 → 直接抛（上层已有语义）。
- 重试前给 `userText` 追加纠正指令：「上次不是合法 JSON，可能被截断；只输出完整可解析的单个 JSON 对象」。
- 重试间短退避 800ms（复用 llm-client 的 sleep 风格）。
- 用尽后抛含「已重试 N 次」的错误；每次失败在 trace 里留 `traceNote`（「第 N 次解析失败 → 正在第 x/y 次重试」），实时过程面板全可见。
- 次数 / 超时 / maxTokens 由调用方在 `getActiveConfig()` 之后以 `runtime` 显式传入（保持封装为纯函数、易单测，不在封装内部依赖 `AiConfigService`）。

### 4. 接线范围（全部 JSON 识别步骤）

| 服务 | 原调用 | 改为 |
|---|---|---|
| image-describe.service（示例图识别） | visionChat + extractJson | visionChatJson |
| ai-analyze.service（识图生成草稿） | visionChat + extractJson | visionChatJson |
| ai-analyze.service（文字构思草稿） | textChat + extractJson | textChatJson |
| pose-ref-sheet.service | textChat + extractJson | textChatJson |
| image-score.service | textChat + extractJson | textChatJson（失败仍回退 retry） |
| draft-refine.service | textChat + extractJson | textChatJson（失败仍回退 null） |

### 5. 超时治理

- 各步骤硬编码 `timeoutMs: 120_000 / 60_000` 改为取配置 `cfg.runtime.timeoutMs`（默认 180s）。
- `llm-client.ts` `MAX_TOKENS` 常量改为参数，默认取 `cfg.runtime.maxTokens`（8192）。
- 前端 `ai-task.ts` `pollAiAnalyzeTask` 默认总预算 600s → **900s**（给重试留时间）；生图/剪影保持 600s 不动。

### 6. 测试

- `normalize.spec`：截断闭合、尾随逗号、平衡子串回退、仍失败返回 null。
- 新增 `llm-json.spec`：解析失败→重试成功、超时→重试、5xx→重试、用尽抛错含「已重试 N 次」、不可重试原因不重试、次数取自配置。
- `ai-config.service.spec`：新字段 view/get/save 透传与默认值。
- 各服务 spec 适配新封装（mock 层从 visionChat 换到 visionChatJson 即可）。

## 边界与风险

- 重试有界（默认共 ≤3 次调用），只对可重试原因触发；成本/耗时增加被前端 900s 预算兜住。
- 修复层只做括号闭合，不臆造字段；修复后仍非法即重试。
- 属后端改动 → 完成后按项目规则 commit 并 push origin + github（触发 backend-deploy.yml 自动部署）。
- `max_tokens` 提升到 8192 可能小幅增加单次成本，但能显著降低截断型失败，收益大于成本。

## 交付清单

1. 迁移 `047_ai_config_llm_stability.sql` + `schema.ts` 3 列
2. `UpdateAiConfigDto` 3 字段
3. `AiConfigService` view/get/save 透传 `runtime`
4. `normalize.ts` `extractJson` 补救 + `normalize.spec`
5. 新 `llm-json.ts`（visionChatJson / textChatJson）+ `llm-json.spec`
6. 六处接线（image-describe / ai-analyze ×2 / pose-ref-sheet / image-score / draft-refine）
7. `llm-client.ts` `MAX_TOKENS` 参数化
8. 各步骤超时取配置
9. 前端 `ai-task.ts` 900s + `ai-config-form.tsx` 识别稳定性分区 + admin 类型
10. 后端 typecheck + 单测全绿；commit + 双远程 push
