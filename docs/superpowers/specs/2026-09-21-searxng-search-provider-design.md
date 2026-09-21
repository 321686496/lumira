# SearXNG 自建搜索接入：替换已退役的 Bing 搜索适配器

> **目标**：把「三方搜索引擎」从**已退役的 Microsoft Bing Search API**（2025-08 退役）替换为**自建 SearXNG 元搜索**，实现**免费、无 API Key、无限量**的网络搜索，用于研究管线（trend-research）的一键生成模板趋势研究。
>
> **状态**：设计（已完成需求澄清与方案确认，待写实现计划）
> **配套**：后端 `trend-research` 搜索栈 + `ai-config` 配置 + 后台 `ai-config-form.tsx` + `deploy/docker-compose.prod.yml`

---

## 一、现状（代码实证）

| 环节 | 现状（文件） | 缺陷 |
| --- | --- | --- |
| 搜索分发 | `trend-research/web-search.provider.ts` `createWebSearchProvider` 按名分发 `bing/qwen/baidu/vendor` | bing 指向 `api.bing.microsoft.com`，微软已于 2025-08 退役该 API，实际不可用 |
| 三方搜索 | `web-search-bing.ts` → `{baseUrl}/v7.0/search` + Bearer Key | 死链路；且需 Key |
| 配置读取 | `ai-config.service.ts` `parseSearchSources` 白名单 `['bing','vendor','baidu','qwen']`；`getSearchConfig()` L435 bing 分支用 `searchBaseUrl+searchApiKey` | 白名单与分支均含已死的 bing |
| 后台表单 | `ai-config-form.tsx` `SEARCH_MODE_OPTIONS = ['qwen','bing','off']`，bing 模式显示「通用搜索 Base URL / API Key」 | bing 选项失效，误导用户 |
| 校验 | `dto/update-ai-config.dto.ts` L119 `@IsIn(['bing','vendor','baidu','qwen'])` | 需增 searxng |
| 部署 | `deploy/docker-compose.prod.yml` 三服务（mysql/backend/redis），nginx 反代，后端不暴露端口 | 无搜索服务 |

## 二、目标体验（后台）

「研究管线」搜索方式单选收敛为：

- **模型自带搜索（Qwen）**：不变（`sources=[qwen]`）
- **SearXNG 自建搜索（免费）**：显示「SearXNG Base URL」（必填，预填 `http://lumira-searxng:8080`）+「SearXNG API Key」（可选，带 token 的自建实例用）；`sources=[searxng]`
- **关闭**：不变

规则：
- 选择 SearXNG 时 Base URL 必填，缺省 → 视为未启用并在 trace 透传 `sourceErrors`（沿用既有失败透传机制）。
- 与既有 `search_*` 字段**向后兼容**：存量 `search_sources=['bing']` 读取时自动归一化为 `searxng`，无需重填后台。
- `qwen` 选项保留（可正常工作，独立付费模型）。

## 三、后端改动

### 3.1 新适配器 `web-search-searxng.ts`（删除 `web-search-bing.ts`）

复用 `WebSearchProvider` 接口（`{ name, search(query, limit): Promise<ResearchItem[]> }`）。

- **请求**：`GET {base}/search?q={query}&format=json&language=zh-CN`（去尾斜杠），无鉴权头；若配置了 apiKey 则带 `Authorization: Bearer <apiKey>`（SearXNG 的 token 鉴权）。
- **超时**：`AbortSignal.timeout(8000)`；失败抛可读错误（超时/连接/HTTP 非 200），上层 `allSettled` 降级跳过。
- **解析**：`data.results[]`（`{ title, url, content }`）→ `ResearchItem{ source:'searxng', title, snippet: content, url, keywords: 分词前 12 }`；`data.unresponsive_engines` 或空数组 → 返回 `[]`（不抛）。
- **Provider 名**：`searxng`，并入 `createWebSearchProvider` 分发；`trend-research/index.ts` re-export 同步；删除 `web-search-bing.ts` 与 `createBingSearchProvider`。

### 3.2 配置接线 `ai-config.service.ts`

- `parseSearchSources` 白名单 → `['vendor','baidu','qwen','searxng']`；对存量 `'bing'` 归一化为 `'searxng'`（向后兼容，老数据直接生效）。
- `getSearchConfig()` bing 分支 → searxng 分支：`sources.push({ name:'searxng', provider:'searxng', baseUrl: searchBaseUrl || 'http://lumira-searxng:8080', apiKey: searchApiKey ?? undefined })`。
- `getActiveConfig()` `search.sources` 走同一 `parseSearchSources`，自动同步。

### 3.3 DTO 校验

`dto/update-ai-config.dto.ts` L119 `@IsIn` → `['vendor','baidu','qwen','searxng']`。

### 3.4 触发路径

沿用 `trend-research.service.ts`（allSettled 降级、source+title 去重、`{ items, sourceErrors }`）与 `ai-orchestrator`，不改评分/细化闭环。

## 四、部署改动

### 4.1 `deploy/docker-compose.prod.yml` 新增服务

```yaml
lumira-searxng:
  image: searxng/searxng:latest
  restart: always
  environment:
    - SEARXNG_SECRET=${SEARXNG_SECRET}
  volumes:
    - ./repo/deploy/searxng/settings.yml:/etc/searxng/settings.yml:ro
  networks:
    - lumira-net
  # 不暴露端口：后端通过内部网络访问 http://lumira-searxng:8080
```

- 卷挂载用相对路径 `./repo/deploy/searxng/settings.yml`（compose 运行目录为 `$DEPLOY_PATH`，repo 克隆于其下），**CI 的 compose 同步逻辑无需改动**。
- 服务器 `.env` 新增 `SEARXNG_SECRET=$(openssl rand -hex 32)`（AGENTS.md 部署章节补充说明）。

### 4.2 新增 `deploy/searxng/settings.yml`

- `search.formats: [json]`（SearXNG 默认不开启，必须显式启用）。
- 引擎配**国内可访问集**（bing / duckduckgo / qwant / baidu 等，排除被墙的 google），避免请求超时拖慢研究。
- `search.safe_search: 0`；关闭 public limiter（内部专用，无公网暴露）。
- `server.secret_key` 由 `SEARXNG_SECRET` 注入。

## 五、错误处理与测试

- **错误处理**：SearXNG 请求超时/连接失败/HTTP 非 200 → 抛可读错误（上层 allSettled 收集为 `sourceErrors`）；无结果 → 返回 `[]` 不抛。
- **测试（TDD）**：
  - `web-search.spec.ts`：bing 适配器用例 → searxng 用例（请求形状 `?q=&format=json`、解析 `results[]`、空结果、超时、HTTP 错误、可选 apiKey 请求头）。
  - `ai-config.service.spec.ts`：老数据 `sources=['bing']` → 归一化 `searxng` 的兼容用例更新。
  - `trend-research.service.spec.ts` / `ai-orchestrator.service.spec.ts` 中 `'bing'` 仅作来源标签（fixture），无需改动。

## 六、边界与不做

- **不做**：baidu 适配器（仍 throw 降级）；SearXNG 图片/新闻分类搜索（`categories=images/news`）本次不做，`ResearchItem.imgUrl` 字段保留给后续；SearXNG 独立服务器部署形态不做（本期同服务器容器）。
- **不换**：`qwen` 模型自带搜索保持可用；研究管线编排、评分、细化闭环不动。
- **依赖外部**：服务器需能拉取 `searxng/searxng` 镜像（国内网络由服务器侧处理，与后端镜像一致）。

## 七、落地顺序

P1 后端 `web-search-searxng.ts` + 删除 bing + 工厂/白名单/DTO/索引接线 + 单测 → P2 `ai-config.service` searxng 分支与 bing 归一化 + 单测 → P3 后台表单与 types（bing→searxng）+ 构建 → P4 部署：`settings.yml` + `docker-compose.prod.yml` + AGENTS.md 部署章节 → P5 commit + push 双远程。
