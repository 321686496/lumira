# 后端架构改造：Redis 缓存 + 单机/集群平滑兼容 设计文档

- 日期：2026-08-24
- 状态：待评审
- 涉及项目：`lumira-server/packages/backend/`、`deploy/`

## 1. 背景与目标

当前后端单机部署（MySQL 8 本地卷 + backend + nginx 外部网络，见 `deploy/docker-compose.prod.yml`），无任何缓存，接口全部实时查 MySQL，瓶颈在 4C4G 上「业务 + DB 抢同一台机器」。

目标：
1. **引入 Redis 缓存**，降低重复 DB 查询，提升 QPS 与高并发能力。
2. **架构可单机、可集群平滑切换**：前期单机低请求够用；后期用户量上来做集群部署时，数据迁移更顺畅。

约束（用户已确认，2026-08-24）：
- 缓存范围：**内容类 + 部分用户热数据**
- 存储抽象：**本次一并抽象成可切换存储层**（集群平滑迁移的关键）
- Redis 形态：**单实例 + 无损降级**（Redis 挂了/未配 → 自动回退 DB，不影响业务）
- URL 存量处理：**新数据存相对路径**，存量数据靠兼容逻辑，不改库
- 落地范围：**一次性全部接入**（所有读多写少内容接口 + 存储抽象全部改造完）

## 2. 总体架构

```
                 ┌─────────────── 可选：集群(2+N 副本) ───────────────┐
  用户 → nginx ──►│  lumira-backend*N      (无状态, 可水平扩容)      │
    (2C2G 备案/转发) │    ├─ Redis  (共享缓存, 唯一共享状态)            │
                 │    ├─ MySQL 8 (外部化部署 / 主从可选)          │
                 │    └─ Storage (本地盘 / 未来 S3/OSS)          │
                 └────────────────────────────────────────────────┘
```

设计要点：
- **backend 保持无状态**；Redis 是唯一共享状态 → 多副本只需配 nginx，无需状态同步。
- **所有新增能力无损降级**：Redis 未配置或连接失败 → 退化为无缓存直查 DB，单机零 Redis 也能跑。
- **MySQL 本地卷→外部化**：通过 `DB_HOST` 已支持外部；部署层面拆出主从。

## 3. 核心模块 1：Redis 缓存（带无损降级）

### 3.1 依赖
新增 `ioredis`（workspace `packages/backend/`）。

### 3.2 RedisModule / RedisService（全局模块）
- 读环境变量 `REDIS_URL`；**未配置或连接失败 → `enabled=false` 降级为空缓存**。
- 封装方法：
  - `getJson<T>(key): Promise<T | null>`
  - `setJson(key, value, ttlSeconds)`
  - `del(key)` / `delByPattern(pattern)`
  - Redis 异常一律 catch 并视为 miss，不向业务抛错。
- 提供 `isEnabled()` 供业务判断（一般不判断，缓存层自动回退）。

### 3.3 缓存范围与 TTL

| 类别 | 数据 | TTL | 缓存策略 |
|---|---|---|---|
| 内容类（全量） | 模板列表/详情 | 600s | 全量 + admin 写操作失效对应 key |
| 内容类 | 分类树 / 分类列表 | 600s | 同上 |
| 内容类 | 内置场景列表 | 300s | 同上 |
| 内容类 | 通知列表 | 60s | admin 写操作失效 |
| 内容类 | 内置模板/场景注册表 | 600s | 写操作失效 |
| 内容类 | 模板积分定价 | 300s | 写操作失效 |
| 用户热数据 | 设备资料 | 120s | 按设备维度，写操作清 |
| 用户热数据 | 用户积分余额 | 60s | 按设备维度，写操作清 |
| 用户热数据 | 已拥有模板列表 | 120s | 按设备维度，写操作清 |

> 用户热数据用短 TTL + 写时失效，避免脏数据；内容类 TTL 较长且 admin 操作主动失效。

### 3.4 缓存 key 规范
- `lumira:cache:{module}:{id}`（单对象，如 `lumira:cache:templateDetail:srv_xxx`）
- `lumira:cache:{module}:list:{stableHash}`（列表，如分类树、场景）
- 列表 key 需保证参数稳定可预期，便于 admin 写操作按 module 模式批量失效（`delByPattern('lumira:cache:templateDetail:*')`）。

### 3.5 接入点
在 service 层做「先查缓存 → miss 查库 → 回填缓存」的包裹（`cache-aside`），可抽独立的 `CacheAsideHelper` 或各 service 内聚实现。admin 写操作（create/update/delete/toggle）成功后失效相关模式。

## 4. 核心模块 2：存储抽象层（集群迁移关键）

### 4.1 StorageModule / Storage 接口
新建 `StorageModule`，定义抽象，默认 `LocalStorageAdapter`（沿用现有 `fs` 逻辑，行为不变），预留 `S3/OssAdapter` 挂载点（本轮不实现）。

```
interface StorageAdapter {
  write(category, id, filename, buffer): Promise<{ storageKey }>;
  deleteByDir(category, id): Promise<void>;
  resolvePublicUrl(category, id, filename): string;  // 拼当前 BACKEND_PUBLIC_URL
}
```

- category ∈ `'templates' | 'categories'`。
- **storageKey 统一为相对路径** `/uploads/{category}/{id}/{filename}`。
- 现有实现点（文件落盘/dir 删除/URL 构造）从 `admin-templates.service.ts`、`admin-categories.service.ts` 抽取进 Adapter。

### 4.2 URL 改造（关键）
- **DB 存相对路径**：新写入的 `coverUrl` / `silhouette.url` / `silhouette.data` / `iconUrl` 一律存 `/uploads/...`（storageKey），不再存完整域名。
- **返回前端时拼域名**：`rowToMeta` / `rowToDetail` / `rowToCategory` 里的 `normalizeAssetUrl` 改造为「接收存储 key + 拼当前 `BACKEND_PUBLIC_URL`」，返回完整可访问 URL。
- 对存量数据：保留现有「localhost/127.0.0.1 前缀替换为 BACKEND_PUBLIC_URL」的兼容逻辑，新相对路径直接拼域名。**不改库**。

### 4.3 静态服务
`main.ts` 的 `@fastify/static` 挂 `/uploads/*` 保持现状，相对路径天然可被访问。

## 5. 部署形态改造（单机 ⇄ 集群）

### 5.1 docker-compose.prod.yml
- 新增 `lumira-redis` 服务：`redis:7-alpine`，`restart: always`，`command: redis-server --appendonly yes`，volume 持久化 `./data/redis:/data`，加入 `lumira-net`。
- backend 增加环境变量 `REDIS_URL=redis://lumira-redis:6379`。
- MySQL 保留本地 volume 为默认；集群时 `DB_HOST` 指向外部/主从，无需改代码。

### 5.2 .env / .env.example
新增 `REDIS_URL`（默认 `redis://localhost:6379`，单机/集群均填同一 Redis）。示例模板同步更新并注明「未配置则无缓存，自动降级」。

### 5.3 nginx
- `deploy/nginx-lumira.conf.example` 的 `upstream lumira_backend_upstream` 由单 server 改为可加多 server（集群时复制 server 行），配合 `keepalive` 与 `proxy_next_upstream` 容错。
- 单机阶段行为不变（一个 server）。

### 5.4 Dockerfile
依赖新增 `ioredis`，无特殊处理（hoisted node-linker 已扁平）。

## 6. 数据迁移顺畅性落地

1. **缓存不承载持久数据** → 集群迁移时缓存天然无负担（重建即可）。
2. **URL 相对路径化** → 切域名/对象存储不用改写 DB 数据。
3. **backend 无状态** → 加副本只需配 nginx，无状态同步。
4. **本地盘文件** → 目录结构规整，配合 Storage 接口，迁 S3 用 Adapter 重写即可。

## 7. 错误处理与降级

| 场景 | 行为 |
|---|---|
| `REDIS_URL` 未配置 | 缓存禁用，直查 DB（现状行为） |
| Redis 连接失败/超时 | 捕获异常视为 miss，直查 DB；不抛错、不熔断业务 |
| 缓存写入失败 | 忽略，下次 miss 重查 |
| Redis 恢复 | 自动重连（ioredis 自带），缓存恢复生效 |
| DB 正常 / Redis 正常 | cache-aside 正常回填 |

## 8. 测试

- 单元：`RedisService` 降级（未配/关闭/miss）、`StorageProvider` 的 storageKey 与 URL 构造。
- Service：模板/分类/场景的缓存命中与 admin 写后失效。
- e2e：保留现有测试；新增 Redis 关闭时接口仍正常（回归保障）。
- 手工验证：单机无 REDIS_URL 启动正常；配 REDIS_URL 后接口响应含缓存 / 命中后 DB 查询数下降。

## 9. 明确不做（YAGNI / 后续）
- 不在本期实现 S3/OssAdapter 的具体代码（只留接口与挂载点）。
- 不引入 Redis Cluster/Sentinel（单实例 + 降级即可，后续按需演进）。
- 不改动用户业务强一致数据的缓存（积分扣减、兑换等仍实时事务读库，避免脏数据）。

## 10. 后续优化登记
- 存储 S3/OSS 适配器实现、图片压缩/缩略图，登记到 `docs/future-optimizations.md`。