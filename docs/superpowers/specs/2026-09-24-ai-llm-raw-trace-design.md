# AI 全链路 LLM 调用原始数据实时可见（设计）

日期：2026-09-24
状态：已确认，待实现
上游文档：`docs/superpowers/specs/2026-09-24-ai-create-process-trace-design.md`（实时过程溯源首版）

## 1. 背景与问题

后台「AI 一键生成」页已具备实时过程面板（`GenerateProgressPanel`，Tab 切换「风格识别 / 姿势图生成」），
数据来自后端 `llm-trace.ts`（识别流程）与 `ai-image-task.service.ts` 的批次事件流。

用户新需求（原话）：
> 对于每一个请求大模型提示词的详情，我都要能够在实时过程中看到，包括大模型响应出来的原始数据。

当前实现有四个缺口：

1. **记录的不是「原始数据」**：`llm-client.ts` 的 `chatRequest` 只取 `choices[0].message.content`，
   `traceLlmCall` 的 `done(content)` 记的是**提取后的字符串**。上游原始响应体
   （`choices/message/tool_calls`、`sources`、`usage`、`finish_reason`）全部丢弃。
2. **有 LLM 调用完全未埋点**：
   - `trend-research/web-search-qwen.ts` 直连 `chat/completions` + `enable_search`，
     带完整 system/user 提示词，零 trace（「研究」阶段真正的大模型调用）。
   - `llm-client.ts` 的 `toolChat` 未挂 trace。
3. **生图链路的 LLM 调用被静默丢弃**：批量姿势图走 `ai-image-task.service.ts` 的 `run()`，
   内部 `composeImagePrompt` → `textChat`（把结构化素材整理成生图提示词）**没有采集上下文**
   （`runWithTrace` 只用于识别任务），这些请求的提示词与响应一个都看不到。
4. **前端可见性不足**：`CallCard` 提示词默认折叠、响应仅 <600 字才默认展开、
   `<pre>` 限高 `max-h-56`；单字段 20,000 字截断。

## 2. 目标

1. 识别流程与批量姿势图生成过程中，**每一次 LLM 调用**都能看到：
   - 该次请求的提示词详情（system / user，含完整素材）
   - 大模型返回的**原始响应体全文**（JSON）
2. 前端默认展开、可复制，排查问题时无需再点开折叠。

非目标：
- 不采集生图厂商 `images/generations` 的原始响应（返回体是图片 base64，展示无意义）。
- 单张手动生图（`submit()` 路径）不新增事件流（UI 无实时面板，无展示入口）。
- 不改动识别/生图业务逻辑本身。

## 3. 设计

### 3.1 后端：`llm-trace.ts` 事件结构扩展

`AiTraceEvent` 新增：

| 字段 | 说明 |
| --- | --- |
| `rawResponse?: string` | 上游**原始响应体全文**（LLM 为原始 JSON 文本；检索为原始返回） |
| `attempts?: number` | 实际发出的请求次数（含 jsonMode 降级 / 5xx 重试） |

- `TraceCallHandle.done(response?, extra?)` 的 `extra` 增加 `rawResponse` / `attempts`。
- `TRACE_TEXT_CAP` 由 `20_000` 提升到 `50_000`，仍保留「…（已截断，原长 N 字）」标注，不静默丢内容。
- `response` 字段语义保持「提取后的模型输出文本」，与 `rawResponse` 并列展示（互不替代）。

### 3.2 后端：`llm-client.ts` 记录原始响应体

- `rawChatMessage` 改为先 `res.text()` 取原文、再 `JSON.parse`，返回 `{ message, rawText, attempts }`；
  重试时 `attempts` 累加，`rawText` 为最终成功那次的原文。
- `chatRequest` 返回 `{ content, raw }`。
- `visionChat` / `textChat`：`handle?.done(content, { rawResponse: raw, attempts })`。
- **`toolChat` 补埋点**：`traceLlmCall({ model, systemPrompt, userPrompt, title: '工具调用 · LLM' })`，
  `resultBrief` 记调用的工具名列表，`done` 时 `rawResponse` = 该轮 assistant 消息 JSON（含 `tool_calls`）。
  无采集上下文时 `handle` 为 null，行为不变。

### 3.3 后端：`web-search-qwen.ts` 补埋点

provider 内部：

```ts
const handle = traceLlmCall({
  model,
  systemPrompt: buildSystemPrompt(),
  userPrompt: q.query,
  title: '千问联网搜索 · 大模型调用',
});
```

- 成功：`handle?.done(msgContentOrSummary, { rawResponse: rawText, resultBrief: `${items.length} 条` })`
  （`rawText` 为上游原始响应体原文）。
- 失败：`handle?.fail(err)` 后照原逻辑抛错。

外层 `cacheableSearch` 的检索事件保留，二者互补：外层 = 「检索词 + 解析出几条」，内层 = 「原始请求与原始返回」。

### 3.4 后端：批量姿势图链路接入采集上下文

`ai-image-task.service.ts`：

- `run()` 内用 `runWithTrace(sink, ...)` 包裹 `generateWithRetry(...)`；sink 把扁平 `AiTraceEvent`
  转成带 `index` 的批次事件（复用 `emitBatchEvent` 分配 seq/ts）。
- `AiBatchImageTraceEvent` 扩展（`kind` 缺省 = `'pose'`，向后兼容）：

| 字段 | 说明 |
| --- | --- |
| `kind?: 'pose' \| 'llm' \| 'search'` | 事件种类；缺省 `'pose'` |
| `systemPrompt?` / `userPrompt?` | LLM 调用的提示词详情 |
| `response?` / `rawResponse?` | 提取输出 / 上游原始响应体 |

- 效果：每张姿势图的 `composeImagePrompt` → `textChat` 调用（完整素材提示词 + 原始响应）
  挂到该张图下实时流出；`generateWithRetry` 的重试过程同样可见。
- `MAX_TRACE_EVENTS`（1000）与 `RESULT_TTL_MS` 保持不变。

### 3.5 前端（admin）

- **新增共享组件** `src/components/ai-create/trace-call-card.tsx`：`TraceCallCard`
  - 分区：请求（system 提示词 / user 提示词）、模型输出（提取）、上游原始响应（JSON）。
  - **默认全部展开**，`<pre>` 限高内部滚动。
  - 每块右上角「复制」按钮（`navigator.clipboard.writeText`，不可用时降级提示）。
- `analyze-trace-stream.tsx`：`CallCard` 替换为共享 `TraceCallCard`。
- `pose-trace-stream.tsx`：PoseRow 内嵌渲染 `kind === 'llm' | 'search'` 的子事件（同一卡片）；
  最终生图提示词同样默认展开。
- `types/admin.ts`：与 3.1 / 3.4 字段对齐。

## 4. 测试

后端 jest：

- `llm-trace.spec.ts`：`rawResponse` / `attempts` 透传；cap 提升后超长文本标注。
- `llm-client.spec.ts`：mock fetch，断言 `visionChat`/`textChat`/`toolChat` 产生的事件含 `rawResponse`。
- `web-search-qwen.spec.ts`：有采集上下文时产生 LLM 事件；无上下文时 no-op 且行为不变。
- `ai-image-task.service.spec.ts`：批次事件含 `kind: 'llm'` 且 `index` 归属正确。

前端：`pnpm --filter @lumira/admin build` 通过。

## 5. 风险

- 事件体积增大（rawResponse 全文 × 每次调用）：已由 `TRACE_TEXT_CAP = 50_000` 与批次事件上限约束。
- `web-search-qwen` 是逐查询循环调用，会产生多条事件：符合「每一次都要看到」的诉求。