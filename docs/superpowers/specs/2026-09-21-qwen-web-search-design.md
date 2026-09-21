# 千问(Qwen)模型自带联网搜索 + 后台「模型自带 / 三方搜索」切换

> **目标**：把「模型自带搜索」从「让模型凭记忆编 JSON 数组」升级为**真正调用千问联网搜索（enable_search）**，并在后台提供清晰的「搜索方式」三选一切换：**模型自带(Qwen) / 三方(Bing) / 关闭**。
>
> **状态**：设计（已完成需求澄清与方案确认，待写实现计划）
> **配套**：后端 `trend-research` 搜索栈 + `ai-config` 配置 + 后台 `ai-config-form.tsx`

---

## 一、现状（代码实证）

| 环节 | 现状（文件） | 缺陷 |
| --- | --- | --- |
| 搜索分发 | `trend-research/web-search.provider.ts` `createWebSearchProvider` 按 `provider` 名分发 `bing/baidu/vendor` | vendor 未真正联网 |
| 三方搜索 | `web-search-bing.ts` → `{baseUrl}/v7.0/search` + `Ocp-Apim-Subscription-Key` | 缺 key 即 403；baidu 适配器未接（`case 'baidu'` 直接 throw） |
| 「模型自带搜索」 | `web-search-vendor.ts` 调 `textChat` 让模型凭记忆输出 JSON 数组 | **未触发模型联网**；之前现场即「不返回结果」 |
| 配置读取 | `ai-config.service.ts:getSearchConfig()`（L378-409）把 vendor 映射为文本端点、bing 映射为搜索 API 端点 | 无独立 Qwen 搜索端点 |
| 后台表单 | `ai-config-form.tsx`（L801-891）：服务商 single(`general/vendor/off`) + 来源 multi(`bing/vendor/baidu`) + 通用 BaseURL/Key | 「服务商+来源多选」语义混乱，用户难以表达「用模型自带还是三方」 |

## 二、目标体验（后台）

「研究管线（Agentic 趋势研究）」配置区收敛为一个**搜索方式**单选：

- **模型自带搜索（Qwen）**：显示「Qwen 搜索端点」「Qwen 搜索 API Key」；sources 固定为 `[qwen]`
- **三方搜索引擎（Bing）**：显示「通用搜索 Base URL」「通用搜索 API Key」；sources 固定为 `[bing]`
- **关闭**：研究停用（等效现在 `search_enabled=false`）

规则：
- 选择**模型自带**时 Qwen 端点/Key 必填，缺一 → 视为未启用并在 trace 透传 `sourceErrors`（沿用既有失败透传机制，绝不误写成 `skip-research`）。
- 与既有 `search_*` 字段**向后兼容**：新字段只增不改；老数据（服务商/来源）仍可正常读出。

## 三、后端改动

### 3.1 新适配器 `web-search-qwen.ts`（实现千问真联网）
复用 `WebSearchProvider` 接口（`{ name, search(query, limit): Promise<ResearchItem[]> }`）。

- **请求**：向「Qwen 搜索端点」POST `{endpoint}/chat/completions`（去掉尾斜杠），`Authorization: Bearer <qwenApiKey>`，body：
  ```json
  {
    "model": "<qwenModel>",       // 新增配置项，默认 qwen-plus
    "messages": [{"role":"system","content":"你是资深摄影/时尚编辑，请基于联网检索结果输出对主题的发现。"},{"role":"user","content":"<topic>"}],
    "enable_search": true,         // 千问联网开关（顶层参数）
    "temperature": 0.3,
    "max_tokens": 4096,
    "response_format": {"type":"json_object"}   // 见 3.3 结构化兜底
  }
  ```
- **解析（宽松、多形态）**，从响应中按顺序尝试取引用 → 映射 `ResearchItem{ source, title, snippet, keywords[], url }`：
  1. `message.tool_calls` 中 function.name 为 `web_search` 的 `arguments` 内 `search_info.search_results[]`（`{ title, url/caption? , site }`）
  2. `message.content` 为数组时的引用内容块（`type: 'search_result'/'reference'` 类）
  3. 结构化兜底：`enable_search` 作者回答文本 → `extractJson` 解析出 `{ results:[{title,url,content}] }`
  - 以上均无 → 返回 `[]`（空命中），并在 sourceErrors 带「未取到引用」提示，**不编造 URL**。
- `provider` 名用 `qwen`，并入 `createWebSearchProvider` 分发。

### 3.2 配置接线 `ai-config.service.ts`
- 新增读取字段：`searchQwenBaseUrl`、`searchQwenApiKey`、`searchQwenModel`。
- `getSearchConfig()` 依**当前搜索方式**返回 `sources`：
  - 方式=qwen 且端点+Key 齐全 → `[{ name:'qwen', provider:'qwen', baseUrl, apiKey, vendorEndpoint:{ model } }]`
  - 方式=bing 且端点+Key 齐全 → `[{ name:'bing', provider:'bing', baseUrl, apiKey }]`
  - 否则整体 `enabled=false`（研究关闭）。
- 老字段映射保留：兼容既有 `search_provider=general/vendor`、`search_sources` 读取逻辑；当检测到新的「搜索方式」设置时以新设置优先。

### 3.3 触发路径
沿用现有 `trend-research.service.ts`（allSettled 降级、source+title 去重、`{ items, sourceErrors }` 返回）与 `ai-orchestrator`（`research-0`/来源失败透传），**不改评分/细化闭环**。

## 四、后台改动 `ai-config-form.tsx` + types
- 表单：搜索方式单选（模型自带 Qwen / 三方 Bing / 关闭）；按选择显示对应字段组。
- 保存负载 `UpdateAiConfigPayload` 增 `searchQwenBaseUrl/searchQwenApiKey/searchQwenModel`。
- 回显：进入页面按 `getSearchConfig`/DB 现职回填当前方式与字段。
- Key 输入用 password 类型，提交不回显明文（沿用现有 Key 处理方式）。

## 五、错误处理与测试
- **错误处理**：Qwen 请求失败/非 JSON/无引用 → 不抛，返回空 + sourceErrors（沿用 allSettled 降级）；超时用 `AbortSignal.timeout`。
- **测试（TDD）**：
  - `web-search-qwen.spec.ts`：mock fetch 返回 `tool_calls.web_search.search_info.search_results` → 解析成 `ResearchItem[]`；返回无引用 → `[]` + 提示；返回非法 JSON → `[]` 不抛。
  - `ai-config.service` 相关：按「方式」映射 sources；Qwen 缺端点/Key → enabled=false。
  - 后台表单单元/构建：保存与回显 Qwen 字段正常。

## 六、边界与不做
- 不做：baidu 适配器（仍 throw 降级）；多模态模型需 `multimodal-generation`+流式，本次仅支持 Chat Completions（text）模型。
- 不绕过：主对话端点不动，Qwen 搜索用独立端点+Key。
- 唯一待验证项：千问 citations 的确切字段（文档示例仅示 `message.content` 文本），按 3.1 宽松多形态解析兜底，真机验证后若有出入仅微调解析层。

## 七、落地顺序
P1 后端 `web-search-qwen.ts` + 适配器分发 + 单测 → P2 `ai-config` 配置字段与 `getSearchConfig` 映射 + 单测 → P3 后台表单与 types + 构建 → P4 commit + push 双远程。