# Qwen 联网搜索双通道：官方百炼 / 三方 MaaS 分离

> **目标**：把「AI 一键生图」联网搜索里混在一处的 Qwen 拆成两套**互斥可选、独立配置**的通道：
> **Qwen 官方百炼**（`enable_search`，响应走顶层 `search_info.search_results[]`）与
> **Qwen 三方 MaaS**（网关把引用放到顶层 `sources[]` 或 `tool_calls`）。
>
> **状态**：设计已确认（2026-09-25），待实现
> **背景**：现有 `web-search-qwen.ts` 一个适配器同时兼容两种响应形态，端点/Key/模型只有一组，
> 导致官方与三方无法并存、也无法各自独立配置；官方端点实测拿不到结构化引用（落到正文兜底，丢失 title/url）。
> **参考**：<https://docs.bailian.console.aliyun.com/zh/model-studio/web-search>

---

## 一、现状（代码实证）

| 环节 | 现状（文件） | 问题 |
| --- | --- | --- |
| 搜索方式 | `ai-config.service.ts:getSearchConfig()` 仅 `searchProvider='qwen'` 一条分支 | 官方与三方共用一组端点字段，无法并存 |
| 配置存储 | 迁移 `041_ai_config_search_qwen.sql` 三列 `search_qwen_*` | 一组字段被两种平台共用 |
| 适配器 | `trend-research/web-search-qwen.ts` | 请求带 `response_format: json_object`；解析分支无顶层 `search_info.search_results[]`（仅 `sources[]` / `tool_calls` / content 块 / content JSON） |
| 后台 | `ai-config-form.tsx` 搜索方式三选一（`qwen/searxng/off`） | 无法区分官方/三方 |
| 分发 | `web-search.provider.ts` `case 'qwen'` | 单一 provider 名 |

官方文档要点：OpenAI 兼容 Chat Completions 顶层传 `enable_search: true`；**执行了搜索时响应带 `search_info` 字段**
（`search_info.search_results[]`，含 `index/title/url/site_name`），`usage.plugins` 记录检索次数；
`search_options` 可配 `forced_search` / `enable_source`；支持联网的模型含 `qwen-plus` 等。

## 二、分工（互斥四选一）

后台「搜索方式」收敛为四选一：**Qwen 官方百炼 / Qwen 三方 MaaS / SearXNG 自建 / 关闭**。

| 项 | Qwen 官方百炼（新） | Qwen 三方 MaaS（现有） |
| --- | --- | --- |
| provider 名 | `qwen-official` | `qwen`（不变） |
| 配置列 | 新增 `search_qwen_official_base_url` / `_api_key` / `_model` | 沿用 `search_qwen_base_url` / `_api_key` / `_model` |
| 适配器 | 新文件 `web-search-qwen-official.ts` | `web-search-qwen.ts`（运行行为不变） |
| 端点示例 | `https://{WorkspaceId}.cn-beijing.maas.aliyuncs.com/compatible-mode/v1` | 三方中转站自定 base |

规则：
- 两套通道**互斥**，一次只启用一种；不做并联多源。
- 缺端点或 Key → `sources: []`（研究跑 0 条，trace 透传 `sourceErrors`，**绝不误写 `skip-research`**）。
- 现有 `qwen` 字段语义与线上数据**零迁移**。

## 三、后端改动

### 3.1 官方适配器 `web-search-qwen-official.ts`
复用 `WebSearchProvider` 接口，provider 名 `qwen-official`。

请求：`POST {base}/chat/completions`，`Authorization: Bearer <key>`，body：

```json
{
  "model": "<qwenOfficialModel，缺省 qwen-plus>",
  "messages": [{"role":"system","content":"<系统提示词，含当天日期+来源要求>"},{"role":"user","content":"<主题>"}],
  "enable_search": true,
  "search_options": { "forced_search": true, "enable_source": true },
  "temperature": 0.3,
  "max_tokens": 4096
}
```

三处与三方适配器的差异及理由：
1. 加 `search_options.forced_search` / `enable_source`：官方文档说明模型可能自行判断不检索；研究管线每次都要真实检索且需要来源列表。
2. **去掉 `response_format: json_object`**：官方联网返回「正文 + `search_info`」，强 JSON 会丢掉带链接的正文综述。
3. 解析以**顶层 `search_info.search_results[]`** 为主（映射 `title` / `url`（回退 `site_name`）/ 摘要），
   正文「联网综述」兜底（沿用 2000 字上限），两者皆空 → 抛错，由上层 `allSettled` 收进 `sourceErrors`，不编造 URL。

### 3.2 公共工具抽取 `qwen-shared.ts`
把 `extractJson / firstStr / tokenize / clean / summarizeItem`（`toResearchItem` 映射）从 `web-search-qwen.ts`
抽到 `trend-research/qwen-shared.ts`，两个适配器共用，避免复制约 50 行纯函数；不改变现有 `qwen` 的运行行为。

### 3.3 配置接线 `ai-config.service.ts` + DTO + 迁移
- 迁移 `043_ai_config_search_qwen_official.sql`：三列可空新增（`search_qwen_official_base_url/_api_key/_model`）。
- `update-ai-config.dto.ts`：`searchProvider` @IsIn 加 `'qwen-official'`；`searchSources` 白名单加 `'qwen-official'`；
  新增 `searchQwenOfficialBaseUrl` / `searchQwenOfficialApiKey` / `searchQwenOfficialModel` 三个可选字段（沿用 MaxLength 规则）。
- `getSearchConfig()`：新增 `searchProvider === 'qwen-official'` 分支 → `[{ name:'qwen-official', provider:'qwen-official', baseUrl, apiKey, model }]`；缺端点/Key → `[]`。
- `getActiveConfig().search.provider` union 与 `parseSearchSources` 白名单同步加 `'qwen-official'`。
- `web-search.provider.ts`：`case 'qwen-official'` → 官方适配器。

### 3.4 后台 `ai-config-form.tsx` + `types/admin.ts`
- 搜索方式四选一；选官方 → 显示「Qwen 官方端点（Base URL）」（placeholder 官方 compatible-mode）/「API Key」/「模型（缺省 qwen-plus）」。
- 选三方 → 沿用现有三字段，文案标注为「Qwen 三方 MaaS」。
- 校验与保存：`payload.searchProvider='qwen-official'`、`payload.searchSources=['qwen-official']`，官方端点/Key 首次必填。
- `types/admin.ts`：`searchProvider` union 加 `'qwen-official'`；新增三个字段。

## 四、错误处理

沿用既有链路：请求超时用 `AbortSignal.timeout`；HTTP 非 2xx、无引用、非法 JSON → 抛可读中文错误；
`trend-research` 的 `allSettled` 聚合并把失败写入 `sourceErrors`；识别/生图主流程不因搜索失败而中断。

## 五、测试

- 新增 `web-search-qwen-official.spec.ts`：① `search_info.search_results` → 带 url 的 `ResearchItem[]`（`source='qwen-official'`）；
  ② 仅正文 → 「联网综述」兜底；③ 空响应 → 抛错；④ HTTP 非 200 → 抛错。
- `ai-config.service.spec.ts` 补：`qwen-official` 映射 sources；缺 Key → `sources: []`；两种 Qwen 互斥不串字段。
- 现有 `web-search-qwen.spec.ts` 保持通过（回归证明三方链路未被改坏）。

## 六、不做

不做 Responses API / Anthropic 兼容 / 多模态流式（多模态需 `multimodal-generation` + 流式）；
不让两套 Qwen 并联；不改评分与细化闭环；不改动主对话端点。

## 七、落地顺序

P1 迁移 + DTO + `getSearchConfig` 分支 + `parseSearchSources` 白名单 → P2 公共工具抽取 + 官方适配器 + 单测
→ P3 后台表单与 types → P4 全量 typecheck/单测 → P5 commit + push（gitee + github 双远程）。
