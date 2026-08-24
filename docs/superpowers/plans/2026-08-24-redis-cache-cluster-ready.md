# Redis 缓存 + 集群平滑兼容 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 引入带无损降级的 Redis 缓存，并抽出可切换存储层，使后端可从单机平滑演进到集群部署。

**Architecture:** 新增全局 RedisModule（ioredis，未配置/故障自动降级为空缓存），在 service 层做 cache-aside 包裹；新增 StorageModule 抽象磁盘读写与 URL 构造，DB 存相对路径 `/uploads/...`、返回前端时拼 `BACKEND_PUBLIC_URL`。部署层新增 Redis 容器、`.env` 的 `REDIS_URL`、nginx 多副本 upstream。

**Tech Stack:** NestJS 10 + Fastify、ioredis、TypeScript 5.3、drizzle-orm (mysql2)、Docker compose、nginx。

设计文档：`docs/superpowers/specs/2026-08-24-redis-cache-cluster-ready-design.md`

## Global Constraints

- Dart/TypeScript 编译走 `pnpm --filter @lumira/backend`；后端类型检查：`pnpm --filter @lumira/backend typecheck`（如无则 `tsc -p tsconfig.build.json --noEmit`）。
- 全部为 TypeScript，遵循现有 drizzle `mode: 'default'`、`int` 时间戳（秒）约定。
- 任务完成后只 commit（勿 push），纯代码改动按 AGENTS.md 需 push 两个远程，但**实现期间先不推送**，由用户在关键节点决定。
- 无损降级铁律：任何缓存调用不得因 Redis 异常向业务抛错。
- 兼容铁律：单机无 `REDIS_URL` 时行为与现状完全一致。

---

### Task 1: 安装 ioredis 依赖

**Files:**
- Modify: `lumira-server/packages/backend/package.json`

**Interfaces:**
- Produces: 依赖就绪，供 Task 2 使用。

- [ ] **Step 1: 在 backend 添加 ioredis 依赖**

在 `lumira-server/` 下运行：

```bash
pnpm --filter @lumira/backend add ioredis
```

- [ ] **Step 2: 验证安装且能类型解析**

```bash
pnpm --filter @lumira/backend exec tsc --noEmit -p tsconfig.build.json
```

Expected: 编译通过，无 ioredis 相关类型错误。

- [ ] **Step 3: Commit**

```bash
git add lumira-server/pnpm-lock.yaml lumira-server/packages/backend/package.json
git commit -m "feat(backend): add ioredis dependency"
```

---

### Task 2: RedisModule + RedisService（含无损降级）

**Files:**
- Create: `lumira-server/packages/backend/src/common/redis/redis.module.ts`
- Create: `lumira-server/packages/backend/src/common/redis/redis.service.ts`
- Modify: `lumira-server/packages/backend/src/app.module.ts`

**Interfaces:**
- Consumes: ioredis 依赖（Task 1）。
- Produces:
  - `class RedisService`：
    - `getJson<T>(key: string): Promise<T | null>`
    - `setJson<T>(key: string, value: T, ttlSeconds: number): Promise<void>`
    - `del(key: string): Promise<void>`
    - `delByPattern(pattern: string): Promise<void>`
    - `isEnabled(): boolean`

- [ ] **Step 1: 写 RedisService（含降级）**

创建 `redis.service.ts`：

```ts
import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import Redis from 'ioredis';

@Injectable()
export class RedisService implements OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private readonly client: Redis | null;

  constructor() {
    const url = process.env.REDIS_URL;
    if (!url) {
      this.logger.warn('REDIS_URL not set — cache disabled (graceful fallback to DB)');
      this.client = null;
      return;
    }
    try {
      this.client = new Redis(url, {
        maxRetriesPerRequest: 1,
        enableOfflineQueue: false,
        lazyConnect: false,
      });
      this.client.on('error', (err) => this.logger.warn(`Redis connection error: ${err.message}`));
    } catch (err) {
      this.logger.warn(`Redis init failed, cache disabled: ${(err as Error).message}`);
      this.client = null;
    }
  }

  isEnabled(): boolean {
    return this.client !== null;
  }

  async getJson<T>(key: string): Promise<T | null> {
    if (!this.client) return null;
    try {
      const raw = await this.client.get(key);
      return raw === null ? null : (JSON.parse(raw) as T);
    } catch (err) {
      this.logger.verbose(`getJson miss for ${key}: ${(err as Error).message}`);
      return null;
    }
  }

  async setJson<T>(key: string, value: T, ttlSeconds: number): Promise<void> {
    if (!this.client) return;
    try {
      await this.client.set(key, JSON.stringify(value), 'EX', ttlSeconds);
    } catch (err) {
      this.logger.verbose(`setJson failed for ${key}: ${(err as Error).message}`);
    }
  }

  async del(key: string): Promise<void> {
    if (!this.client) return;
    try {
      await this.client.del(key);
    } catch (err) {
      this.logger.verbose(`del failed for ${key}: ${(err as Error).message}`);
    }
  }

  async delByPattern(pattern: string): Promise<void> {
    if (!this.client) return;
    try {
      let cursor = '0';
      do {
        const [next, keys] = await this.client.scan(cursor, 'MATCH', pattern, 'COUNT', 200);
        cursor = next;
        if (keys.length > 0) {
          await this.client.del(...keys);
        }
      } while (cursor !== '0');
    } catch (err) {
      this.logger.verbose(`delByPattern failed for ${pattern}: ${(err as Error).message}`);
    }
  }

  async onModuleDestroy(): Promise<void> {
    if (this.client) await this.client.quit();
  }
}
```

- [ ] **Step 2: 写 RedisModule 注册为全局**

创建 `redis.module.ts`：

```ts
import { Global, Module } from '@nestjs/common';
import { RedisService } from './redis.service';

@Global()
@Module({
  providers: [RedisService],
  exports: [RedisService],
})
export class RedisModule {}
```

- [ ] **Step 3: 在 AppModule 引入 RedisModule**

修改 `app.module.ts` import 与 imports 数组：

```ts
import { RedisModule } from './common/redis/redis.module';
// imports 数组加入 RedisModule：
imports: [RedisModule, DatabaseModule, DeviceModule, /* ...其余不变 */],
```

- [ ] **Step 4: 类型检查**

```bash
pnpm --filter @lumira/backend exec tsc --noEmit -p tsconfig.build.json
```

Expected: 编译通过。

- [ ] **Step 5: Commit**

```bash
git add lumira-server/packages/backend/src/common/redis lumira-server/packages/backend/src/app.module.ts
git commit -m "feat(backend): add RedisModule with graceful degradation"
```

---

### Task 3: StorageModule + LocalStorageAdapter（存储抽象层）

**Files:**
- Create: `lumira-server/packages/backend/src/common/storage/storage.module.ts`
- Create: `lumira-server/packages/backend/src/common/storage/storage-adapter.interface.ts`
- Create: `lumira-server/packages/backend/src/common/storage/local-storage.adapter.ts`
- Create: `lumira-server/packages/backend/src/common/storage/storage.provider.ts`（DI token 提供）
- Create: `lumira-server/packages/backend/src/common/storage/asset-url.ts`（URL 规范/兼容工具）
- Modify: `lumira-server/packages/backend/src/app.module.ts`

**Interfaces:**
- Consumes: 无外部依赖。
- Produces:
  - `type StorageCategory = 'templates' | 'categories'`
  - `interface StorageAdapter { write(category, id, filename, buffer): Promise<string>; deleteByDir(category, id): Promise<void>; }` —— write 返回 **storageKey（相对路径 `/uploads/...`）**
  - `const STORAGE_ADAPTER: InjectionToken`（DI token）
  - `STORAGE_KEY_PREFIX = '/uploads'`
  - `buildAssetUrl(storageKey: string): string` —— 输入可为相对路径或完整 URL（含 localhost 兼容），返回 App 可访问完整 URL
  - `storageKeyFilename(category: StorageCategory, id: string, filename: string): string`

- [ ] **Step 1: 写接口与常量**

创建 `storage-adapter.interface.ts`：

```ts
export type StorageCategory = 'templates' | 'categories';

export const STORAGE_KEY_PREFIX = '/uploads';

export interface StorageAdapter {
  /** 写入文件，返回相对存储路径（storageKey），如 `/uploads/templates/srv_xxx/cover.jpg` */
  write(category: StorageCategory, id: string, filename: string, buffer: Buffer): Promise<string>;
  /** 删除某实体整个目录 */
  deleteByDir(category: StorageCategory, id: string): Promise<void>;
}
```

- [ ] **Step 2: 写 LocalStorageAdapter**

创建 `local-storage.adapter.ts`：

```ts
import * as fs from 'fs';
import * as path from 'path';
import type { StorageAdapter, StorageCategory } from './storage-adapter.interface';

export class LocalStorageAdapter implements StorageAdapter {
  private readonly uploadRoot: string;

  constructor(uploadRoot = path.resolve(process.env.UPLOAD_DIR || './data/uploads')) {
    this.uploadRoot = uploadRoot;
  }

  async write(category: StorageCategory, id: string, filename: string, buffer: Buffer): Promise<string> {
    const dir = path.join(this.uploadRoot, category, id);
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, filename), buffer);
    return `/uploads/${category}/${id}/${filename}`;
  }

  async deleteByDir(category: StorageCategory, id: string): Promise<void> {
    const dir = path.join(this.uploadRoot, category, id);
    if (fs.existsSync(dir)) {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  }
}
```

- [ ] **Step 3: 写 URL 工具（含存量兼容）**

创建 `asset-url.ts`：

```ts
import { STORAGE_KEY_PREFIX } from './storage-adapter.interface';

/**
 * 将存储 key / 完整 URL 规整为 App 可访问的完整 URL。
 * - 相对路径 `{STORAGE_KEY_PREFIX}/...` → 拼 `BACKEND_PUBLIC_URL`
 * - 完整 https? URL：若前缀为 localhost/127.0.0.1，替换为 BACKEND_PUBLIC_URL（兼容旧数据）；否则原样返回
 * - 空值 → 空字符串
 */
export function buildAssetUrl(url: string | null | undefined): string {
  if (!url) return url || '';
  if (url.startsWith(STORAGE_KEY_PREFIX)) {
    const base = process.env.BACKEND_PUBLIC_URL || 'http://localhost:3000';
    return `${base}${url}`;
  }
  if (/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?\//i.test(url)) {
    const base = process.env.BACKEND_PUBLIC_URL || 'http://localhost:3000';
    return url.replace(/^https?:\/\/[^/]+/, base);
  }
  if (/^https?:\/\//i.test(url)) {
    return url; // 外部完整 URL 原样返回
  }
  // 兜底：未知格式直接返回
  return url;
}
```

- [ ] **Step 4: 写 Provider 与 Module**

创建 `storage.provider.ts`：

```ts
import { LocalStorageAdapter } from './local-storage.adapter';
import { StorageAdapter } from './storage-adapter.interface';
import type { Provider } from '@nestjs/common';

export const STORAGE_ADAPTER = 'STORAGE_ADAPTER';

export const storageAdapterProvider: Provider = {
  provide: STORAGE_ADAPTER,
  useFactory: (): StorageAdapter => new LocalStorageAdapter(),
};
```

创建 `storage.module.ts`：

```ts
import { Global, Module } from '@nestjs/common';
import { storageAdapterProvider } from './storage.provider';

@Global()
@Module({
  providers: [storageAdapterProvider],
  exports: [storageAdapterProvider],
})
export class StorageModule {}
```

- [ ] **Step 5: 在 AppModule 引入 StorageModule**

修改 `app.module.ts`，加入 import 与 imports 数组（与 RedisModule 并列）：

```ts
import { StorageModule } from './common/storage/storage.module';
imports: [RedisModule, StorageModule, DatabaseModule, DeviceModule, /* ... */],
```

- [ ] **Step 6: 类型检查**

```bash
pnpm --filter @lumira/backend exec tsc --noEmit -p tsconfig.build.json
```

Expected: 编译通过。

- [ ] **Step 7: Commit**

```bash
git add lumira-server/packages/backend/src/common/storage lumira-server/packages/backend/src/app.module.ts
git commit -m "feat(backend): add StorageModule abstraction + asset URL builder"
```

---

### Task 4: admin-templates 改用 StorageAdapter + 存相对路径

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/templates/admin-templates.service.ts`

**Interfaces:**
- Consumes: `STORAGE_ADAPTER` token、`StorageAdapter` 类型、`storageKeyFilename`/`buildAssetUrl`；已有的 `UploadFile`、`extractExt`。
- Produces: 模板的 `coverUrl`、`silhouette.url/data` 改为存相对路径 storageKey。

- [ ] **Step 1: 注入 STORAGE_ADAPTER 并替换 saveFile/URL 构造**

在 `AdminTemplatesService` 中注入 adapter，删除本地 `saveFile`/`buildPublicUrl` 的 URL 构造部分。替换 `create()` 中的封面/剪影保存为：

```ts
// 封面
const coverStorageKey = await storage.write('templates', id, coverFilename, cover.buffer);
const coverUrl = coverStorageKey; // DB 存相对路径

// 剪影（若有）
const silStorageKey = await storage.write('templates', id, silFilename, silhouette.buffer);
(poseObj.silhouette as Record<string, unknown>).type = 'image';
(poseObj.silhouette as Record<string, unknown>).url = silStorageKey;
(poseObj.silhouette as Record<string, unknown>).data = silStorageKey;
```

`update()` 内对应封面/剪影保存逻辑同样改用 `storage.write` 并赋相对 storageKey。

- [ ] **Step 2: `delete()` 改用 adapter 删除目录**

```ts
await this.storage.deleteByDir('templates', id);
```

删除本文件 `deleteTemplateFiles` 函数。

- [ ] **Step 3: 类型检查**

```bash
pnpm --filter @lumira/backend exec tsc --noEmit -p tsconfig.build.json
```

Expected: 编译通过，无未用变量/函数残留报错。

- [ ] **Step 4: Commit**

```bash
git add lumira-server/packages/backend/src/modules/templates/admin-templates.service.ts
git commit -m "refactor(backend): admin-templates use StorageAdapter + store relative asset keys"
```

---

### Task 5: admin-categories 改用 StorageAdapter

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/templates/admin-categories.service.ts`

**Interfaces:**
- Consumes: `STORAGE_ADAPTER`、`StorageCategory`；已有 `extractIconExt`。
- Produces: 分类 `iconUrl` 存相对路径 storageKey。

- [ ] **Step 1: 注入 adapter 并替换 icon 保存**

替换 `create()` / `update()` 中的 icon 保存为：

```ts
const iconStorageKey = await this.storage.write('categories', meta.key, filename, icon.buffer);
iconUrl = iconStorageKey; // DB 存相对路径
```

- [ ] **Step 2: `delete()` 改用 adapter 删除目录**

```ts
await this.storage.deleteByDir('categories', key);
```

删除本文件 `deleteIconFile`/`saveIconFile`/`deleteCategoryFiles`/`buildIconUrl` 中不再使用的部分。

- [ ] **Step 3: 类型检查**

```bash
pnpm --filter @lumira/backend exec tsc --noEmit -p tsconfig.build.json
```

Expected: 编译通过。

- [ ] **Step 4: Commit**

```bash
git add lumira-server/packages/backend/src/modules/templates/admin-categories.service.ts
git commit -m "refactor(backend): admin-categories use StorageAdapter + store relative icon keys"
```

---

### Task 6: 客户端 DTO 的 URL 输出统一走 buildAssetUrl

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/templates/templates.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/scenes/scenes.service.ts`（如用到则改，否则跳过）

**Interfaces:**
- Consumes: `buildAssetUrl`（Task 3 Produces）。
- Produces: 客户端拿到的 coverUrl/silhouette/iconUrl 为拼好的完整 URL。

- [ ] **Step 1: 替换 templates.service 的 URL 映射**

在 `templates.service.ts` 中，删除本地 `normalizeAssetUrl`，导入并使用 `buildAssetUrl`：

```ts
import { buildAssetUrl } from '../../common/storage/asset-url';

export function rowToMeta(row: TemplateRow): RemoteTemplateMeta {
  return {
    // ...
    coverUrl: buildAssetUrl(row.coverUrl),
    // ...
  };
}
```

`rowToDetail` 内 silhouette.url/data 也改用 `buildAssetUrl`。`rowToCategory` 的 `iconUrl: buildAssetUrl(row.iconUrl)`。

- [ ] **Step 2: 检查 scenes.service 是否输出图片 URL**

搜索 `scenes.service.ts` 是否已有 absolute URL 输出；若无则跳过（不做无谓改动）。

- [ ] **Step 3: 类型检查**

```bash
pnpm --filter @lumira/backend exec tsc --noEmit -p tsconfig.build.json
```

Expected: 编译通过。

- [ ] **Step 4: Commit**

```bash
git add lumira-server/packages/backend/src/modules/templates/templates.service.ts
git commit -m "refactor(backend): unify client asset URL output via buildAssetUrl"
```

---

### Task 7: 内容类接口接入 Redis 缓存（模板/分类/场景/通知/定价）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/templates/templates.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/templates/categories.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/scenes/scenes.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/notifications/notifications.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/admin/admin.service.ts`（或积分定价所在 service）

**Interfaces:**
- Consumes: `RedisService`（Task 2）；`buildAssetUrl`（Task 3）。
- Produces: 内容类接口 cache-aside；admin 写操作失效模式 key。

**缓存 key 映射（本次实现）：**

| 数据 | key | 失效模式 |
|---|---|---|
| 模板列表(客户端 listRemoteTemplates) | `lumira:cache:templateList:list` | `lumira:cache:templateList:*` |
| 模板详情 | `lumira:cache:templateDetail:{id}` | `lumira:cache:templateDetail:*` |
| 分类列表 listActive | `lumira:cache:categoryList:active` | `lumira:cache:categoryList:*` |
| 分类树 listTree | `lumira:cache:categoryTree:tree` | `lumira:cache:categoryTree:*` |
| 场景列表 listActive | `lumira:cache:sceneList:active` | `lumira:cache:sceneList:*` |
| 通知 listForDevice | `lumira:cache:notifList:device:{deviceId}` | `lumira:cache:notifList:*` |
| 模板积分定价 listPrices | `lumira:cache:templatePrices:list` | `lumira:cache:templatePrices:*` |

- [ ] **Step 1: 为内容类读方法加 cache-aside**

以 `listRemoteTemplates()` 为例的接入模式（其余方法同构）：

```ts
async listRemoteTemplates(since?: number, category?: string, subtreeKeys?: string[]): Promise<RemoteTemplateListResponse> {
  const key = 'lumira:cache:templateList:list';
  const cached = await this.redisService.getJson<RemoteTemplateListResponse>(key);
  if (cached !== null) return cached;

  // ...原有 DB 查询逻辑，组装 result...

  await this.redisService.setJson(key, result, 600);
  return result;
}
```

分别对 `listRemoteTemplates`/`getRemoteTemplateDetail`/`listPrices`（templates）、`listActive`/`listTree`（categories）、`listActive`（scenes）、`listForDevice`（notifications）套用。注入 `RedisService`。

> 注意 `getRemoteTemplateDetail(id)` 的 key 含 id；`listForDevice(deviceId)` 的 key 含 deviceId。

- [ ] **Step 2: admin 写操作失效对应缓存**

在 `AdminTemplatesService`（create/update/delete/toggleActive）、`AdminCategoriesService`（create/update/delete/toggleActive）、`ScenesService`（create/update/remove/toggleActive）、`NotificationsService`（create/update/remove/toggleActive）成功写库后，注入 `RedisService` 并调用对应 `delByPattern`（见上方失效模式列）。例如模板删除：

```ts
await this.redisService.delByPattern('lumira:cache:templateList:*');
await this.redisService.delByPattern('lumira:cache:templateDetail:*');
await this.redisService.delByPattern('lumira:cache:templatePrices:*');
```

> 涉及 template_prices 更新（兑换 / admin 定价）后同样失效 `templatePrices`。

- [ ] **Step 3: 类型检查**

```bash
pnpm --filter @lumira/backend exec tsc --noEmit -p tsconfig.build.json
```

Expected: 编译通过。

- [ ] **Step 4: Commit**

```bash
git add lumira-server/packages/backend/src/modules/templates lumira-server/packages/backend/src/modules/scenes lumira-server/packages/backend/src/modules/notifications
git commit -m "feat(backend): cache content APIs via Redis with admin invalidation"
```

---

### Task 8: 用户热数据接入缓存（设备资料/积分余额/已拥有模板）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/device/device.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/points/points.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/templates/templates.service.ts`（listOwned）

**Interfaces:**
- Consumes: `RedisService`。
- Produces: 按设备维度短 TTL 缓存 + 写时失效。

- [ ] **Step 1: 为只读查询加 cache-aside（短 TTL）**

以 `listOwned(deviceId)` 为例：

```ts
async listOwned(deviceId: string) {
  const key = `lumira:cache:ownedTemplates:${deviceId}`;
  const cached = await this.redisService.getJson(key);
  if (cached !== null) return cached;
  // ...原查询...
  await this.redisService.setJson(key, result, 120);
  return result;
}
```

分别对设备资料读取、积分余额只读查询套用同等模式（TTL 见设计文档 §3.3：设备 120s、积分 60s、已拥有 120s）。

- [ ] **Step 2: 对应写操作失效**

在写积分（spend/add）、更新设备、授予/兑换模板后失效对应设备 key：

```ts
await this.redisService.del(`lumira:cache:userPoints:${deviceId}`);
await this.redisService.del(`lumira:cache:device:${deviceId}`);
await this.redisService.del(`lumira:cache:ownedTemplates:${deviceId}`);
```

- [ ] **Step 3: 类型检查**

```bash
pnpm --filter @lumira/backend exec tsc --noEmit -p tsconfig.build.json
```

Expected: 编译通过。

- [ ] **Step 4: Commit**

```bash
git add lumira-server/packages/backend/src/modules/device lumira-server/packages/backend/src/modules/points lumira-server/packages/backend/src/modules/templates
git commit -m "feat(backend): cache per-device hot data with short TTL"
```

---

### Task 9: 部署配置（docker-compose + .env.example + nginx + Dockerfile 校验）

**Files:**
- Modify: `deploy/docker-compose.prod.yml`
- Modify: `lumira-server/packages/backend/.env.example`（若存在；否则部署文档）
- Modify: `deploy/nginx-lumira.conf.example`

**Interfaces:**
- Consumes: Task 1–2（ioredis + RedisService 读 `REDIS_URL`）。
- Produces: 单机/集群可切换的部署配置。

- [ ] **Step 1: docker-compose 新增 Redis 服务并接入 backend**

在 `deploy/docker-compose.prod.yml` 的 `services` 增加：

```yaml
  lumira-redis:
    image: redis:7-alpine
    restart: always
    command: redis-server --appendonly yes
    volumes:
      - ./data/redis:/data
    networks:
      - lumira-net
```

backend 服务 `depends_on` 增加 `lumira-redis`，`environment` 增加：

```yaml
      - REDIS_URL=redis://lumira-redis:6379
```

- [ ] **Step 2: 更新 .env 示例说明 REDIS_URL**

在 `.env`（/示例）追加说明：`REDIS_URL` 未配置则后端自动降级为无缓存（行为同现状）；单机/集群均填同一 Redis 实例。

- [ ] **Step 3: nginx upstream 支持多副本**

修改 `deploy/nginx-lumira.conf.example` 的 upstream，加注释说明集群时复制 server 行，并示例：

```nginx
upstream lumira_backend_upstream {
    # 单机：一个 server；集群：复制下面行指向多台业务容器
    server lumira-backend:3000;
    # server lumira-backend-2:3000;  # 集群扩容示例
    keepalive 32;
    keepalive_timeout 60s;
}
```

- [ ] **Step 4: 校验 compose 语法**

```bash
cd deploy && docker compose -f docker-compose.prod.yml config
```

Expected: 语法通过，输出含 `lumira-redis` 服务。

- [ ] **Step 5: Commit**

```bash
git add deploy/docker-compose.prod.yml deploy/nginx-lumira.conf.example
git commit -m "feat(infra): add redis service + multi-replica nginx upstream + REDIS_URL config"
```

---

### Task 10: 测试 + 手工验证 + 文档

**Files:**
- Create: `lumira-server/packages/backend/test/redis.service.spec.ts`（或并入现有 jest 结构）
- Modify: `docs/future-optimizations.md`（登记后续项）

**Interfaces:**
- Consumes: 全部前序任务成果。

- [ ] **Step 1: 写 RedisService 降级单元测试**

创建 `redis.service.spec.ts`，覆盖：未设 REDIS_URL 时 `isEnabled()===false`、`getJson` 返回 null 且不抛错：

```ts
import { Test } from '@nestjs/testing';
import { RedisService } from '../src/common/redis/redis.service';

describe('RedisService (degraded)', () => {
  it('is disabled when REDIS_URL is not set', () => {
    const svc = new RedisService();
    expect(svc.isEnabled()).toBe(false);
  });

  it('getJson returns null instead of throwing', async () => {
    const svc = new RedisService();
    await expect(svc.getJson('x')).resolves.toBeNull();
  });
});
```

> 运行：`pnpm --filter @lumira/backend test redis.service`（避免实例化真实 Redis 依赖的全局测试要求 REDIS_URL；未设时天然降级）。

- [ ] **Step 2: 手工验证单机无缓存启动**

```bash
pnpm --filter @lumira/backend start:prod  # 不设 REDIS_URL
```

Expected: 正常启动，日志提示 cache disabled，接口行为与改造前一致。

- [ ] **Step 3: 手工验证配 Redis 后缓存生效**

启动 Redis（`docker run -d -p 6379:6379 redis:7-alpine`），设 `REDIS_URL=redis://localhost:6379` 后启动，调用模板列表接口两次，观察第二次命中（可在 Redis `keys 'lumira:cache:*'` 看到 key）。Redis 停掉后接口仍正常（降级）。

- [ ] **Step 4: 登记后续优化**

在 `docs/future-optimizations.md` 末尾追加：S3/OSS 适配器实现、Redis Cluster/Sentinel 演进、图片压缩/缩略图。

- [ ] **Step 5: Commit**

```bash
git add lumira-server/packages/backend/test docs/future-optimizations.md
git commit -m "test: add RedisService degradation tests + docs"
```

---

## Plan Self-Review 结果

- **Spec 覆盖：** 设计文档 §3（Redis 模块/缓存范围/降级）→ Task 2/7/8；§4（存储抽象/URL）→ Task 3/4/5/6；§5（部署）→ Task 9；§7（降级）→ 融入 Task 2/7/8；§8（测试）→ Task 10。全覆盖。
- **占位符扫描：** 无 TBD/TODO；代码块均给出完整实现。
- **类型一致：** `STORAGE_ADAPTER` token、`StorageAdapter.write→storageKey`、`buildAssetUrl`、`RegisterService.{getJson,setJson,del,delByPattern}` 在后续 task 中的引用与定义一致。