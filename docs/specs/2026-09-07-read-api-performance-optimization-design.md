# 读接口性能优化 — 设计文档

> 日期：2026-09-07
> 状态：已实现（代码提交于 2026-09-07，迁移 026 随容器启动自动执行）

## 1. 背景与目标

移动端核心读接口在负载测试下出现三类问题：**接口延迟偏高、瓶颈接口 QPS 上不去、无效请求打爆 MySQL / Redis**。排查确认瓶颈集中在以下 5 个读接口：

| 接口 | 路径 | 主要问题 |
|---|---|---|
| 模板列表 | `GET /api/v1/templates/list` | 缓存 key 含 `since` 时间戳 → **键爆炸**；subtree 用 `JSON_EXTRACT` **无法走索引**；`db.select()` 全列拉取 longtext |
| 模板搜索 | `GET /api/v1/templates/search` | base 过期重建做全表热度聚合；限流 `get+set` **非原子** |
| 场景列表 | `GET /api/v1/scenes` | 依赖 usage_events 全表 GROUP BY（无索引、无缓存） |
| 分类图标缩略图 | `GET /api/v1/thumbs/category-icon` | **先打 DB 后查磁盘缓存**，命中缓存的请求仍浪费一次 DB 查询 |
| 使用量统计 | `GET /api/v1/usage/stats` | 无任何缓存，每次全表聚合，可被反复刷 |

本方案目标（已与用户确认）：
1. 降低接口延迟（特别是 P95）。
2. 提高吞吐 / QPS。
3. 减少 DB 压力（热点聚合 / 全列扫描下移）。
4. 降低缓存键爆炸风险（键数量从"无界"收敛到"有限"）。

## 2. 技术决策（已与用户确认）

- 优化范围 = **代码级优化 + 数据库索引优化 + 缓存策略重构** 三者全部实施。
- 实施顺序：**阶段一（代码级低风险）→ 阶段二（迁移 026 索引）→ 阶段三（缓存策略重构）**；一次设计文档覆盖全部。
- 原则：所有改动保持**接口响应结构不变**（移动端无需发版即可受益）；仅 `list` 接口的 `serverUpdatedAt` 语义按 3.5 说明修正（对新客户端更正确）。
- 缓存失效沿用现有机制：admin 写模板 / 分类后按 pattern 全量失效，本方案的**新缓存 key 已被现有失效 pattern 覆盖**（`templateList:*` / `templateSearch:*` / `templateDetail:*`），无需改动 admin 端失效逻辑。
- Redis 不可用时保持"无损降级"（当前已具备，本次不引入失效级联）。

## 3. 优化方案

### 3.1 阶段一：代码级优化（低风险）

#### 3.1.1 thumbs：磁盘缓存命中优先（改动最大收益比）

文件：`src/modules/templates/thumbs.service.ts` `categoryIcon`（L58-86）

**现状**：先 `findIconFile(key)` 打 DB 查 `icon_url`（L60-61），再检查磁盘缩略图（L66）。已生成缓存的请求 **每次仍消耗一次 DB 查询**，且 DB 查询只为了拿一个上传文件名。

**改为**：

```
categoryIcon(key, rawWidth):
  1. clamp width → 计算 thumbFile 路径
  2. 磁盘命中 thumbFile → 直接返回（零 DB）
  3. 未命中 → findIconFile(key)（DB）→ Jimp 生成写盘 → 返回；jimp 不支持格式回退原图（现状保留）
```

配合阶段三的"上传预生成"，命中率将接近 100%，DB 与 CPU 开销同时消失。

#### 3.1.2 templates：SQL 列裁剪（不拉 longtext）

文件：`src/modules/templates/templates.service.ts`

**现状**：`listRemoteTemplates`（L390-392）与 `getSearchBase`（L119-121）都执行 `db.select()` 全列，把 `composition_json / pose_json / camera_json / scene_guide_json / post_process_json` 5 段 longtext 一并从 MySQL 拉回内存再丢弃。

**改为**：定义 `TEMPLATE_META_SELECT` 常量，meta 类查询只投影 `rowToMeta` 所需的列：

```ts
const TEMPLATE_META_SELECT = {
  id: templates.id,
  name: templates.name,
  author: templates.author,
  version: templates.version,
  category: templates.category,
  price: templates.price,
  coverUrl: templates.coverUrl,
  description: templates.description,
  referenceSource: templates.referenceSource,
  tagsJson: templates.tagsJson,
  tagIdsJson: templates.tagIdsJson,
  classificationJson: templates.classificationJson,
  ambienceJson: templates.ambienceJson,
  imagesJson: templates.imagesJson,
  shortDesc: templates.shortDesc,
  sortOrder: templates.sortOrder,
  updatedAt: templates.updatedAt,
} as const;
```

- `listRemoteTemplates` / `getSearchBase` 改用 `db.select(TEMPLATE_META_SELECT)`。
- `rowToMeta` 入参类型由 `TemplateRow` 放宽为 `Pick<TemplateRow, keyof typeof TEMPLATE_META_SELECT>`（定义 `TemplateMetaRow`），`rowToDetail` 仍接收全行（detail 有 600s 缓存，保持全列）。
- `scenes.listActive`：表无 longtext 大列（仅 filter_json），列裁剪收益低，**本轮不做**。

#### 3.1.3 search 限流原子化（消除竞态）

文件：`src/modules/templates/templates.service.ts` `checkSearchRateLimit`（L152-161）

**现状**：`getJson` + `setJson` 两步操作非原子，并发请求可绕过 60/分钟限制。

**改为**：`RedisService` 新增原子方法，限流逻辑单命令完成：

```ts
// redis.service.ts
async incrEx(key: string, seconds: number): Promise<number> {
  if (!this.client) return 0;
  const cnt = await this.client.incr(key);
  if (cnt === 1) await this.client.expire(key, seconds);
  return cnt;
}

// templates.service.ts checkSearchRateLimit 改为
if (!this.redisService.isEnabled()) return;            // 降级放行（现状行为）
const cnt = await this.redisService.incrEx(rk, windowSec);
if (cnt > limit) throw new HttpException('rate_limited', HttpStatus.TOO_MANY_REQUESTS);
```

语义一致：第 61 次起返回 429。

#### 3.1.4 usage/stats 接口加缓存

文件：`src/modules/usage/usage.service.ts` `stats`（L31-50）

**现状**：`GET /usage/stats` 与 search base / scenes 共享同一聚合逻辑，每次调用都全表 GROUP BY。

**改为**：`stats()` 方法内部加短 TTL 缓存（这一处改动同时让 **search、scenes、usage/stats 接口三方受益**）：

```ts
async stats(itemType?: UsageItemType): Promise<UsageStatsResponse> {
  const key = `lumira:cache:usageStats:${itemType ?? 'all'}`;
  const cached = await this.redisService.getJson<UsageStatsResponse>(key);
  if (cached !== null) return cached;
  // ... 原有聚合逻辑不变 ...
  await this.redisService.setJson(key, result, STATS_CACHE_TTL);  // 30s
  return result;
}
```

`UsageService` 需注入 `RedisService`。热度值最多延迟 30s 更新，可接受（运营侧无实时需求）。

### 3.2 阶段二：数据库索引迁移（026）

文件：新建 `src/database/migrations/026_read_api_performance_indexes.sql`

```sql
-- lumira-server/packages/backend/src/database/migrations/026_read_api_performance_indexes.sql
-- 1) usage_events 热度聚合索引：让 GROUP BY item_id,item_type,event_type（WHERE item_type=?）
--    从全表扫描变为索引扫描（loose index scan），是热度口径所有读接口的根治项
CREATE INDEX `idx_usage_stats` ON `usage_events` (`item_type`(191), `item_id`(191), `event_type`(191));

-- 2) templates 列表主排序索引：WHERE is_active=1 ORDER BY sort_order ASC, updated_at DESC
CREATE INDEX `idx_templates_active_sort` ON `templates` (`is_active`, `sort_order`, `updated_at`);

-- 3) templates 增量拉取索引：WHERE is_active=1 AND updated_at > ?
CREATE INDEX `idx_templates_active_updated` ON `templates` (`is_active`, `updated_at`);
```

要点：
- `item_type / item_id / event_type` 为 `text` 列，建索引必须带**前缀长度**；utf8mb4 下 191 字符 × 4B × 3 列 = 2292B < 3072B（InnoDB 行内索引键上限），合法。
- MySQL 8 ONLINE DDL（`ALGORITHM=INPLACE`），建索引不阻塞读写。
- 明细可加下可选索引 `CREATE INDEX idx_templates_category ON templates (category(191), is_active);`（仅当"按分类直查"重建缓存时的 DB 查询成为瓶颈再启用，**本轮暂不加**，避免过度索引）。
- 迁移沿用现有手写 SQL 机制：`database.service.ts` `runMigrations()` 在容器启动时自动执行，`_migrations` 表追踪文件名。

### 3.3 阶段三：缓存策略重构

#### 3.3.1 templateList 缓存 key 去 since 化（根治键爆炸）

文件：`src/modules/templates/templates.service.ts` `listRemoteTemplates`（L356-402）

**现状**：key = `lumira:cache:templateList:list:${since}:${category}:${subtreeKeys}`，`since` 是毫秒时间戳 → 每次客户端增量拉取都生成新 key，**键数量无界、几乎不命中**。

**改为**：缓存键移除时间戳维度，按筛选维度分 key：

```ts
const scopeKey = `${category ?? ''}:${subtreeKeys ? [...subtreeKeys].sort().join('|') : ''}`;
const key = `lumira:cache:templateList:list:${scopeKey}`;
const result = await this.redisService.getJson<RemoteTemplateListResponse>(key);
if (result !== null) {
  // 命中：since 在内存过滤（缓存存的是全量筛选结果）
  let templates = result.templates;
  if (since !== undefined && !Number.isNaN(since)) {
    templates = templates.filter((m) => m.updatedAt > since);
  }
  return { templates, serverUpdatedAt: result.serverUpdatedAt };
}
// 未命中：DB 查询构建整份筛选列表（条件不变），并计算
//   serverUpdatedAt = 列表内 max(updatedAt)（源列表最大值，不代表 since 过滤后的子集）
// 注意 subtreeKeys 计算 key 前先 sort()，消除客户端顺序不稳定导致的 key 漂移
```

关键语义变更（对客户端更正确）：
- `templateList` 缓存按 **category × subtree** 两个维度分 key，键数量从"无界"降为"有限组合数"。
- `serverUpdatedAt` 固定为**缓存构建时源列表的 max(updatedAt)**，而不是过滤后子集的 max —— 否则增量拉取会用 `since` 个位步进或漏数据。
- subtree 的 `JSON_EXTRACT` 过滤仍保留在 DB 查询中，但**只在缓存重建时执行一次**（不再每次请求执行），配合索引扫描重建成本可控。
- 失效仍由现有 `delByPattern('lumira:cache:templateList:*')` 覆盖。

> 备注：若未来模板总量超过约 2000 条 / 单 key JSON 超过约 2MB，再评估"全量快照单 key + 内存筛选"的方案（键数量进一步收敛到 1，但每次 GET 传输变大），本轮不采用。

#### 3.3.2 搜索 base 与热度缓存拆分

文件：`src/modules/templates/templates.service.ts` `getSearchBase`（L113-149）

**现状**：base 缓存（TTL 120s）内含每项 hotScore；重建时执行 `db.select()` 全列 + `usageService.stats('template')` **全表聚合**。

**改为**：热度与 base 分离，两级缓存：
- 热度独立缓存：`lumira:cache:usageStats:template`（TTL 30s，由 3.1.4 实现）—— base 重建时的 `stats('template')` 命中它，**不再触发全表聚合**。
- base 缓存保持合并结构（meta + hotScore），TTL 从 120s 提升到 **300s**（重建成本已大幅下降，提高 TTL 进一步降低重建频率）。
- 重建路径：`db.select(TEMPLATE_META_SELECT)`（列裁剪，见 3.1.2）+ `stats('template')`（30s 缓存命中）。

`searchTemplates` 调用路径无需改动（仍从 base 读到 hotScore）。

#### 3.3.3 分类图标上传时预生成缩略图

文件：`src/modules/templates/admin-categories.service.ts` + `src/modules/templates/thumbs.service.ts`

**现状**：缩略图在**读请求链路**用纯 JS 的 Jimp 生成（CPU 阻塞），且 DB 查询先于磁盘判断（见 3.1.1）。第一次被 App 请求时才生成，首访延迟高。

**改为**：把生成成本从**读链路挪到写链路**。
- `ThumbsService` 新增方法 `preGenerate(key: string, widths: number[] = [200, 400, 800])`：内部复用 `findIconFile` + Jimp，按各宽度生成 `{UPLOAD_DIR}/thumbs/categories/{key}/w{width}.jpg`；jimp 不支持的源格式（webp 等）静默跳过。
- `admin-categories.service.ts`：
  - `create`：icon 上传成功（写入 `storage.write('categories', ...)`）后调用 `preGenerate(key)`。
  - `update`：icon 变更成功上传后，先删除 `thumbs/categories/{key}/` 目录（避免旧宽度缓存残留），再调用 `preGenerate(key)`。
  - `delete`：现 `storage.deleteByDir('categories', key)` 之外，同步删除 `thumbs/categories/{key}/`。
- 读链路兜底保留：`categoryIcon` 磁盘未命中时仍懒生成（覆盖旧分类、迁移前数据），保证兼容。

### 3.4 涉及文件清单

| 文件 | 改动 |
|---|---|
| `src/modules/templates/thumbs.service.ts` | 磁盘命中优先（3.1.1）；新增 `preGenerate`（3.3.3） |
| `src/modules/templates/templates.service.ts` | 列裁剪 + `TemplateMetaRow` 类型（3.1.2）；限流原子化（3.1.3）；list key 去 since（3.3.1）；base TTL 300（3.3.2） |
| `src/modules/usage/usage.service.ts` | `stats()` 加 30s 缓存 + 注入 RedisService（3.1.4） |
| `src/common/redis/redis.service.ts` | 新增 `incrEx`（3.1.3） |
| `src/modules/templates/admin-categories.service.ts` | create/update/delete 的 thumbs 预生成与清理钩子（3.3.3） |
| `src/database/schema.ts` | `usage_events`、`templates` 增加表级索引声明（与迁移同步，纯声明，不做 DDL 用途） |
| `src/database/migrations/026_read_api_performance_indexes.sql` | 新建，3 个索引（3.2） |

## 4. 测试计划

### 4.1 回归测试（后端）

- `pnpm --filter @lumira/backend build`（typecheck）通过；后端 e2e 全绿（CI `backend-ci.yml` 的 typecheck + e2e）。
- 接口契约回归（响应结构不变）：
  - `GET /templates/list`：无 since / 带 since / 带 category+subtree / 组合参数的返回字段与排序不变；`serverUpdatedAt` 在带 since 时 ≥ 过滤子集 max（语义修正点）。
  - `GET /templates/search`：五档排序、分页、关键词、分类过滤结果与改动前一致（与旧实现抽样对比）。
  - `GET /scenes`、`GET /usage/stats`：结构不变。
  - 分类图标缩略图：宽各档（200/400/600/800）正常返回；已有磁盘缓存的请求不打 DB（可观察 MySQL 慢日志 / 查询计数）。
- 缓存行为：
  - list 命中后 Redis 内存不增长（连续不同 since 请求只复用同一 key）。
  - 限流第 61 次并发请求返回 429（并发 10 脚本验证原子性）。
  - admin 改模板 / 改分类 icon 后，旧缓存键按 pattern 失效、缩略图目录被清理并预生成新图。

### 4.2 压测复测（k6）

用原负载测试脚本对 5 个接口复测，对比优化前后：
- 单接口：`templates/list`（含 since 场景）、`search`、`scenes`、`usage/stats`、`thumbs/category-icon`。
- 指标：P50 / P95 延迟、QPS、MySQL 慢查询数、Redis keyspace 数量（验证键爆炸收敛）。

## 5. 部署

- 改动集中在 `lumira-server/packages/backend/**`（migrations + service）+ `docs/specs/`（本文档）。
- 迁移 `026_read_api_performance_indexes.sql` 随容器启动自动执行（`database.service.ts` runMigrations）；**建议在低峰发布**，3 个 CREATE INDEX 在 MySQL 8 为 ONLINE DDL。
- 后端提交后 push `origin`(gitee) 与 `github`，触发 `backend-deploy.yml` → 服务器 `git reset --hard` + `docker build` + `up -d`。
- 本文档属 `docs/**`，不触发部署；移动端无需发版（接口结构不变）。

## 6. 范围与不做

- **不做**：`templateList` 全量快照单 key 方案（模板量超阈值再评估，见 3.3.1 备注）。
- **不做**：缓存重建互斥锁（多实例并发重建时用 SETNX 防惊群）；当前 TTL 池化 + 低重建成本下收益有限，列为后续优化登记。
- **不做**：`GET /usage/stats` 按设备限流（DevAuthGuard 已有身份，且加缓存后压力可控；如压测仍高可补限流）。
- **不做**：`scenes.listActive` 列裁剪（无 longtext 大列，收益低）。