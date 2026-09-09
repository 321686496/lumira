# 后台运营 Banner 下发系统实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地 P1 登记项《运营位下发系统》——后端 `operation_banners` 表 + Admin CRUD/下发接口 + 后台可视化管理页 + App 拉取（远端 → 离线缓存 → 静态配置三级兜底）。

**Architecture:** 条件评估留在客户端（App 持有用户状态快照），后端只存配置并做白名单校验（condition 3 枚举 + route 3 路由，防指向不存在的功能）。App 端 `matchOperationBanner` 数据源从静态 `kOperationBanners` 换成可注入列表，渲染层与埋点层零改动。缓存复用 `user_settings` 单行表 JSON 列模式（对齐 `free_mode_camera` 先例）。

**Tech Stack:** NestJS + Fastify + Drizzle ORM + MySQL 8（后端）；Next.js App Router + shadcn/ui（后台）；Flutter Riverpod + sqflite（App）。

## Global Constraints

- 后端每次修改后必须 commit 并 push 双远程（origin=gitee, github），触发 backend-deploy CI
- Admin 每次修改后必须 commit 并 push 双远程（Vercel 自动部署）
- 后端时间戳一律 INT 秒（`Math.floor(Date.now()/1000)`），布尔用 INT 0/1，命名 snake_case
- Flutter DB 版本从 55 → 56；新列必须同时进 `_onCreate` 的 CREATE TABLE 与 `_onUpgrade` v56 迁移
- 运营位只指向真实功能：route 白名单 `['/invite', '/points/wallet', '/templates/unlock']`
- condition 白名单与 App `OperationCondition` 枚举一一对应：`nonNewUserNotInvited / pointsReady / hasLockedTemplate`
- MySQL `condition` 是保留字：所有原生 SQL 必须反引号；服务层只用 Drizzle builder（自动转义）
- App 端解析下发数据时 route/condition 非法 → 丢弃该条（fail-safe，防旧版 App 崩溃）
- 空列表 `[]` 是合法下发状态（后台全部停用），与「拉取失败」严格区分

---

### Task 1: 后端 banners 模块（表 + 迁移 + 双端 API + 单测）

**Files:**
- Modify: `lumira-server/packages/backend/src/database/schema.ts`（notifications 表后新增 operationBanners）
- Create: `lumira-server/packages/backend/src/database/migrations/028_operation_banners.sql`
- Create: `lumira-server/packages/backend/src/modules/banners/operation-banner.rules.ts`
- Create: `lumira-server/packages/backend/src/modules/banners/dto/create-banner.dto.ts`
- Create: `lumira-server/packages/backend/src/modules/banners/dto/update-banner.dto.ts`
- Create: `lumira-server/packages/backend/src/modules/banners/banners.service.ts`
- Create: `lumira-server/packages/backend/src/modules/banners/banners.controller.ts`
- Create: `lumira-server/packages/backend/src/modules/banners/admin-banners.controller.ts`
- Create: `lumira-server/packages/backend/src/modules/banners/banners.module.ts`
- Modify: `lumira-server/packages/backend/src/app.module.ts`（注册 BannersModule）
- Test: `lumira-server/packages/backend/src/modules/banners/banners.service.spec.ts`

**Interfaces:**
- Produces（App 依赖）: `GET /api/v1/banners`（DeviceAuthGuard）→ `{ banners: [{ id, title, subtitle, tag, route, condition }] }`，isActive=1 按 sort_order asc, created_at asc
- Produces（Admin 依赖）: `GET /api/v1/admin/banners` 全量行；`POST` / `PATCH :id` / `DELETE :id` / `POST :id/toggle`

- [ ] **Step 1: schema.ts 新增表定义**

```ts
// ===== 首页运营 Banner（后台下发，2026-09-09 运营位管理）=====
export const operationBanners = mysqlTable('operation_banners', {
  id: varchar('id', { length: 64 }).primaryKey(),
  title: varchar('title', { length: 128 }).notNull(),
  subtitle: varchar('subtitle', { length: 255 }).notNull(),
  tag: varchar('tag', { length: 32 }).notNull(),
  route: varchar('route', { length: 128 }).notNull(),
  condition: varchar('condition', { length: 64 }).notNull(),
  isActive: int('is_active').notNull().default(1),
  sortOrder: int('sort_order').notNull().default(0),
  createdAt: int('created_at').notNull(),
  updatedAt: int('updated_at').notNull(),
});
```

同时把 `operationBanners` 加进文件末尾导出给 `drizzle({ schema })` 的 schema 对象。

- [ ] **Step 2: 迁移 028（建表 + 初始 3 条，与 App 静态目录一致）**

```sql
-- lumira-server/packages/backend/src/database/migrations/028_operation_banners.sql
-- 首页运营 Banner 配置表（后台下发）。初始 3 条对齐 App 静态 kOperationBanners，
-- 使后台开箱即可编辑现有运营位；App 端拉取成功后以本表为准。
CREATE TABLE IF NOT EXISTS `operation_banners` (
  `id` VARCHAR(64) NOT NULL,
  `title` VARCHAR(128) NOT NULL,
  `subtitle` VARCHAR(255) NOT NULL,
  `tag` VARCHAR(32) NOT NULL,
  `route` VARCHAR(128) NOT NULL,
  `condition` VARCHAR(64) NOT NULL,
  `is_active` INT NOT NULL DEFAULT 1,
  `sort_order` INT NOT NULL DEFAULT 0,
  `created_at` INT NOT NULL,
  `updated_at` INT NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `operation_banners`
  (`id`, `title`, `subtitle`, `tag`, `route`, `condition`, `is_active`, `sort_order`, `created_at`, `updated_at`)
VALUES
  ('op_invite', '邀请好友 · 双方各+30分', '绑定邀请码完成首拍，双方各得 30 积分', '邀请有礼', '/invite', 'nonNewUserNotInvited', 1, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
  ('op_points', '积分当钱花 · 解锁模板', '拍摄攒积分，攒够就兑换心仪模板', '积分乐园', '/points/wallet', 'pointsReady', 1, 2, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
  ('op_unlock', '尊享上新 · 一键解锁', '用积分或邀请奖励，解锁付费模板', '上新', '/templates/unlock', 'hasLockedTemplate', 1, 3, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());
```

- [ ] **Step 3: 白名单常量 + DTO**

`operation-banner.rules.ts`：

```ts
// lumira-server/packages/backend/src/modules/banners/operation-banner.rules.ts
/** 运营位展示条件白名单（与 App OperationCondition 枚举一一对应） */
export const OPERATION_BANNER_CONDITIONS = [
  'nonNewUserNotInvited',
  'pointsReady',
  'hasLockedTemplate',
] as const;

/** 运营位路由白名单（运营位只指向真实存在的功能页，防脏配置导致 App 跳转失败） */
export const OPERATION_BANNER_ROUTES = [
  '/invite',
  '/points/wallet',
  '/templates/unlock',
] as const;
```

`dto/create-banner.dto.ts`：

```ts
import { IsBoolean, IsIn, IsInt, IsNotEmpty, IsOptional, IsString, Matches, MaxLength } from 'class-validator';
import { OPERATION_BANNER_CONDITIONS, OPERATION_BANNER_ROUTES } from '../operation-banner.rules';

export class CreateBannerDto {
  /** 稳定 id（App 埋点 trackingId），省略时自动生成
   */
  @IsOptional()
  @IsString()
  @Matches(/^[a-z0-9_-]{2,64}$/)
  id?: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(128)
  title!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  subtitle!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(32)
  tag!: string;

  @IsIn(OPERATION_BANNER_ROUTES)
  route!: string;

  @IsIn(OPERATION_BANNER_CONDITIONS)
  condition!: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsInt()
  sortOrder?: number;
}
```

`dto/update-banner.dto.ts`：同字段全部 `@IsOptional()`（id 不可改，title/subtitle/tag 加 `@MinLength(1)`），route/condition 保持 `@IsIn`。

- [ ] **Step 4: banners.service.ts（照 notifications.service 模式，App 列表 60s Redis 缓存 + 写后失效）**

```ts
// lumira-server/packages/backend/src/modules/banners/banners.service.ts
import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { asc, eq } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { RedisService } from '../../common/redis/redis.service';
import { operationBanners } from '../../database/schema';
import { CreateBannerDto } from './dto/create-banner.dto';
import { UpdateBannerDto } from './dto/update-banner.dto';

/** App 端列表缓存 TTL：写操作即时失效，正常最多延迟 60s 生效 */
const LIST_CACHE_TTL = 60;
const LIST_CACHE_KEY = 'lumira:cache:bannerList';

@Injectable()
export class BannersService {
  constructor(
    private readonly dbService: DatabaseService,
    private readonly redisService: RedisService,
  ) {}

  private async invalidateListCache(): Promise<void> {
    await this.redisService.delByPattern('lumira:cache:bannerList*');
  }

  /** App 端：启用中的运营条目（顺序即优先级），只暴露渲染所需字段 */
  async listForApp() {
    const cached = await this.redisService.getJson<{ banners: unknown[] }>(LIST_CACHE_KEY);
    if (cached !== null) return cached;

    const db = this.dbService.getDb();
    const rows = await db.select()
      .from(operationBanners)
      .where(eq(operationBanners.isActive, 1))
      .orderBy(asc(operationBanners.sortOrder), asc(operationBanners.createdAt));
    const result = {
      banners: rows.map((r) => ({
        id: r.id,
        title: r.title,
        subtitle: r.subtitle,
        tag: r.tag,
        route: r.route,
        condition: r.condition,
      })),
    };
    await this.redisService.setJson(LIST_CACHE_KEY, result, LIST_CACHE_TTL);
    return result;
  }

  // ===== 后台 Admin CRUD =====

  /** 后台：全部条目（含停用与审计字段） */
  async listAdmin() {
    const db = this.dbService.getDb();
    return db.select()
      .from(operationBanners)
      .orderBy(asc(operationBanners.sortOrder), asc(operationBanners.createdAt));
  }

  async create(dto: CreateBannerDto) {
    const db = this.dbService.getDb();
    const id = dto.id || `op-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    if (dto.id) {
      const existing = await db.select().from(operationBanners).where(eq(operationBanners.id, id)).limit(1);
      if (existing.length > 0) throw new ConflictException(`Banner id already exists: ${id}`);
    }
    const now = Math.floor(Date.now() / 1000);
    await db.insert(operationBanners).values({
      id,
      title: dto.title,
      subtitle: dto.subtitle,
      tag: dto.tag,
      route: dto.route,
      condition: dto.condition,
      isActive: dto.isActive === false ? 0 : 1,
      sortOrder: dto.sortOrder ?? 0,
      createdAt: now,
      updatedAt: now,
    });
    await this.invalidateListCache();
    return (await this.getById(id))!;
  }

  async update(id: string, dto: UpdateBannerDto) {
    const db = this.dbService.getDb();
    await this.requireExists(id);
    const patch: Record<string, unknown> = { updatedAt: Math.floor(Date.now() / 1000) };
    if (dto.title !== undefined) patch.title = dto.title;
    if (dto.subtitle !== undefined) patch.subtitle = dto.subtitle;
    if (dto.tag !== undefined) patch.tag = dto.tag;
    if (dto.route !== undefined) patch.route = dto.route;
    if (dto.condition !== undefined) patch.condition = dto.condition;
    if (dto.isActive !== undefined) patch.isActive = dto.isActive ? 1 : 0;
    if (dto.sortOrder !== undefined) patch.sortOrder = dto.sortOrder;
    await db.update(operationBanners).set(patch).where(eq(operationBanners.id, id));
    await this.invalidateListCache();
    return (await this.getById(id))!;
  }

  async remove(id: string): Promise<{ success: true }> {
    const db = this.dbService.getDb();
    await this.requireExists(id);
    await db.delete(operationBanners).where(eq(operationBanners.id, id));
    await this.invalidateListCache();
    return { success: true };
  }

  async toggleActive(id: string): Promise<{ id: string; isActive: boolean }> {
    const db = this.dbService.getDb();
    const row = await this.requireExists(id);
    const next = row.isActive ? 0 : 1;
    await db.update(operationBanners)
      .set({ isActive: next, updatedAt: Math.floor(Date.now() / 1000) })
      .where(eq(operationBanners.id, id));
    await this.invalidateListCache();
    return { id, isActive: next === 1 };
  }

  private async getById(id: string) {
    const db = this.dbService.getDb();
    const rows = await db.select().from(operationBanners).where(eq(operationBanners.id, id)).limit(1);
    return rows.length > 0 ? rows[0] : null;
  }

  private async requireExists(id: string) {
    const row = await this.getById(id);
    if (!row) throw new NotFoundException(`Banner not found: ${id}`);
    return row;
  }
}
```

- [ ] **Step 5: 双 Controller + Module + app.module 注册**

`banners.controller.ts`（App 端，DeviceAuthGuard + JwtModule）：

```ts
// lumira-server/packages/backend/src/modules/banners/banners.controller.ts
import { Controller, Get, UseGuards } from '@nestjs/common';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { BannersService } from './banners.service';

@Controller('banners')
@UseGuards(DeviceAuthGuard)
export class BannersController {
  constructor(private readonly bannersService: BannersService) {}

  /** GET /api/v1/banners → { banners: [...] }（App 首页运营位下发） */
  @Get()
  list() {
    return this.bannersService.listForApp();
  }
}
```

`admin-banners.controller.ts`（照 admin-notifications 模式）：

```ts
// lumira-server/packages/backend/src/modules/banners/admin-banners.controller.ts
import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { BannersService } from './banners.service';
import { CreateBannerDto } from './dto/create-banner.dto';
import { UpdateBannerDto } from './dto/update-banner.dto';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';

@Controller('admin/banners')
@UseGuards(AdminAuthGuard)
export class AdminBannersController {
  constructor(private readonly bannersService: BannersService) {}

  @Get()
  list() {
    return this.bannersService.listAdmin();
  }

  @Post()
  create(@Body() dto: CreateBannerDto) {
    return this.bannersService.create(dto);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateBannerDto) {
    return this.bannersService.update(id, dto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.bannersService.remove(id);
  }

  @Post(':id/toggle')
  toggle(@Param('id') id: string) {
    return this.bannersService.toggleActive(id);
  }
}
```

`banners.module.ts`（照 notifications.module，DeviceAuthGuard 依赖 JwtModule）：

```ts
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../../database/database.module';
import { BannersController } from './banners.controller';
import { AdminBannersController } from './admin-banners.controller';
import { BannersService } from './banners.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({
      secret: process.env.JWT_SECRET || 'dev-secret-change-me',
      signOptions: { expiresIn: '30d' },
    }),
  ],
  controllers: [BannersController, AdminBannersController],
  providers: [BannersService],
})
export class BannersModule {}
```

`app.module.ts`：import + imports 数组追加 `BannersModule`。

- [ ] **Step 6: 单测 banners.service.spec.ts（可 await 的 drizzle 链 mock）**

```ts
// lumira-server/packages/backend/src/modules/banners/banners.service.spec.ts
import { ConflictException } from '@nestjs/common';
import { BannersService } from './banners.service';
import { DatabaseService } from '../../database/database.service';
import { RedisService } from '../../common/redis/redis.service';
import type { CreateBannerDto } from './dto/create-banner.dto';

/** 可 await 的 drizzle 查询链 mock：from/where/orderBy/limit 链式后 resolve 出 rows */
function chainable(rows: unknown) {
  const promise = Promise.resolve(rows);
  const chain: Record<string, unknown> = {
    from: () => chain,
    where: () => chain,
    orderBy: () => chain,
    limit: () => chain,
    then: promise.then.bind(promise),
    catch: promise.catch.bind(promise),
  };
  return chain as never;
}

function buildService(opts: { selectRows?: unknown[]; cached?: unknown } = {}) {
  const select = jest.fn(() => chainable(opts.selectRows ?? []));
  const insertValues = jest.fn(async () => undefined);
  const insert = jest.fn(() => ({ values: insertValues }));
  const updateWhere = jest.fn(async () => undefined);
  const updateSet = jest.fn(() => ({ where: updateWhere }));
  const update = jest.fn(() => ({ set: updateSet }));
  const deleteWhere = jest.fn(async () => undefined);
  const del = jest.fn(() => ({ where: deleteWhere }));
  const db = { select, insert, update, delete: del };
  const dbService = { getDb: () => db } as unknown as DatabaseService;
  const redis = {
    getJson: jest.fn(async () => opts.cached ?? null),
    setJson: jest.fn(async () => undefined),
    delByPattern: jest.fn(async () => undefined),
  } as unknown as RedisService;
  return { service: new BannersService(dbService, redis), select, insertValues, updateSet, redis };
}

const ROW = {
  id: 'op_invite', title: 'T', subtitle: 'S', tag: '邀请有礼',
  route: '/invite', condition: 'nonNewUserNotInvited',
  isActive: 1, sortOrder: 1, createdAt: 1, updatedAt: 1,
};

const CREATE_DTO: CreateBannerDto = {
  title: 'T', subtitle: 'S', tag: '邀请有礼',
  route: '/invite', condition: 'nonNewUserNotInvited',
};

describe('BannersService', () => {
  it('listForApp 只暴露渲染字段并写入 60s 缓存', async () => {
    const { service, redis } = buildService({ selectRows: [ROW] });
    const res = await service.listForApp();
    expect(res.banners).toEqual([{
      id: 'op_invite', title: 'T', subtitle: 'S', tag: '邀请有礼',
      route: '/invite', condition: 'nonNewUserNotInvited',
    }]);
    expect(redis.setJson).toHaveBeenCalledWith('lumira:cache:bannerList', expect.anything(), 60);
  });

  it('listForApp 命中缓存时不再打 DB', async () => {
    const cached = { banners: [] };
    const { service, select } = buildService({ cached });
    expect(await service.listForApp()).toEqual(cached);
    expect(select).not.toHaveBeenCalled();
  });

  it('create 指定已存在 id 时抛 ConflictException', async () => {
    const { service } = buildService({ selectRows: [ROW] });
    await expect(service.create({ ...CREATE_DTO, id: 'op_invite' })).rejects.toThrow(ConflictException);
  });

  it('create 未指定 id 时自动生成并默认 isActive=1/sortOrder=0', async () => {
    const { service, insertValues } = buildService();
    await service.create(CREATE_DTO);
    expect(insertValues).toHaveBeenCalledTimes(1);
    const row = insertValues.mock.calls[0][0];
    expect(row.id).toMatch(/^op-/);
    expect(row.isActive).toBe(1);
    expect(row.sortOrder).toBe(0);
  });

  it('toggleActive 将 1 翻为 0 并失效缓存', async () => {
    const { service, updateSet, redis } = buildService({ selectRows: [ROW] });
    const res = await service.toggleActive('op_invite');
    expect(res.isActive).toBe(false);
    expect(updateSet).toHaveBeenCalledWith(expect.objectContaining({ isActive: 0 }));
    expect(redis.delByPattern).toHaveBeenCalled();
  });

  it('update 只 patch 提供的字段', async () => {
    const { service, updateSet } = buildService({ selectRows: [ROW] });
    await service.update('op_invite', { title: '新标题' });
    const patch = updateSet.mock.calls[0][0];
    expect(patch.title).toBe('新标题');
    expect(patch.subtitle).toBeUndefined();
    expect(patch.updatedAt).toEqual(expect.any(Number));
  });
});
```

- [ ] **Step 7: 验证 + 提交 + 推送双远程**

```bash
pnpm --filter @lumira/backend build   # tsc 类型检查，期望无错误
pnpm --filter @lumira/backend test    # jest 全部通过（含新增 6 条）
git add lumira-server/packages/backend/src/ lumira-server/packages/backend/src/database/migrations/028_operation_banners.sql
git commit -m "feat(banners): 运营 Banner 配置表与双端 API（App 下发 + Admin CRUD）"
git push origin master && git push github master
```

---

### Task 2: Admin 后台「Banner 运营」管理页

**Files:**
- Modify: `lumira-server/packages/admin/src/types/admin.ts`（新增 BannerAdminItem / BannerPayload）
- Modify: `lumira-server/packages/admin/src/lib/api.ts`（banner CRUD 方法）
- Create: `lumira-server/packages/admin/src/actions/banners.ts`
- Create: `lumira-server/packages/admin/src/components/banner-manager.tsx`
- Create: `lumira-server/packages/admin/src/app/dashboard/banners/page.tsx`
- Modify: `lumira-server/packages/admin/src/components/sidebar.tsx`（导航入口）

**Interfaces:**
- Consumes: Task 1 的 `/api/v1/admin/banners` 系列接口
- Produces: `api.listBanners()` 等 5 个方法；`saveBanner/removeBanner/setBannerActive` 3 个 server action

- [ ] **Step 1: types + api.ts + actions**

types/admin.ts 追加：

```ts
// ===== 运营 Banner =====
export interface BannerAdminItem {
  id: string;
  title: string;
  subtitle: string;
  tag: string;
  route: string;
  condition: string;
  isActive: number;
  sortOrder: number;
  createdAt: number;
  updatedAt: number;
}

export interface BannerPayload {
  id?: string;
  title?: string;
  subtitle?: string;
  tag?: string;
  route?: string;
  condition?: string;
  isActive?: boolean;
  sortOrder?: number;
}
```

lib/api.ts `api` 对象追加：

```ts
  // ===== 运营 Banner 管理 =====
  listBanners: () => adminFetch<BannerAdminItem[]>('/banners'),

  createBanner: (payload: BannerPayload) =>
    adminFetch<BannerAdminItem>('/banners', {
      method: 'POST',
      body: JSON.stringify(payload),
    }),

  updateBanner: (id: string, payload: BannerPayload) =>
    adminFetch<BannerAdminItem>(`/banners/${encodeURIComponent(id)}`, {
      method: 'PATCH',
      body: JSON.stringify(payload),
    }),

  deleteBanner: (id: string) =>
    adminFetch<{ success: boolean }>(`/banners/${encodeURIComponent(id)}`, {
      method: 'DELETE',
    }),

  toggleBanner: (id: string) =>
    adminFetch<{ id: string; isActive: boolean }>(
      `/banners/${encodeURIComponent(id)}/toggle`,
      { method: 'POST' },
    ),
```

actions/banners.ts（照 notifications action 模式）：

```ts
// src/actions/banners.ts
'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { api } from '../lib/api';
import { UnauthenticatedError } from '../lib/auth';
import type { BannerPayload } from '../types/admin';

export async function saveBanner(id: string | null, payload: BannerPayload) {
  try {
    if (id) await api.updateBanner(id, payload);
    else await api.createBanner(payload);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
  revalidatePath('/dashboard/banners');
  return { success: true };
}

export async function removeBanner(id: string) {
  try {
    await api.deleteBanner(id);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
  revalidatePath('/dashboard/banners');
  return { success: true };
}

export async function setBannerActive(id: string) {
  try {
    const result = await api.toggleBanner(id);
    revalidatePath('/dashboard/banners');
    return { success: true, isActive: result.isActive };
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}
```

- [ ] **Step 2: banner-manager.tsx（客户端组件：表格 + 新建/编辑 Dialog + 删除确认 + 启用开关）**

照 notification-manager 模式。表单字段：id（新建可填/编辑只读）、title、subtitle、tag、route 下拉、condition 下拉、sortOrder、isActive。下拉选项：

```ts
const ROUTE_OPTIONS = [
  { value: '/invite', label: '邀请页（/invite）' },
  { value: '/points/wallet', label: '积分钱包（/points/wallet）' },
  { value: '/templates/unlock', label: '模板解锁（/templates/unlock）' },
];
const CONDITION_OPTIONS = [
  { value: 'nonNewUserNotInvited', label: '老用户未绑定邀请码' },
  { value: 'pointsReady', label: '积分余额 > 0' },
  { value: 'hasLockedTemplate', label: '存在未解锁付费模板' },
];
```

表格列：ID、标题（title 主行 + subtitle 次行）、标签（Badge）、路由、展示条件、排序、启用（Switch 调 setBannerActive）、操作（编辑/删除）。删除需确认 Dialog。

- [ ] **Step 3: page.tsx + sidebar 入口**

page.tsx（server component，照 notifications page）：

```tsx
import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { BannerManager } from '@/components/banner-manager';

export default async function BannersPage() {
  let banners;
  try {
    banners = await api.listBanners();
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }
  return (
    <div className="space-y-4">
      <BannerManager banners={banners} />
    </div>
  );
}
```

sidebar.tsx：import `Images` 图标，navItems 在「通知公告」后追加 `{ href: '/dashboard/banners', label: 'Banner 运营', icon: Images }`。

- [ ] **Step 4: 验证 + 提交 + 推送双远程**

```bash
pnpm --filter @lumira/admin build   # next build 通过
git add lumira-server/packages/admin/
git commit -m "feat(admin): Banner 运营管理页（可视化编辑条目/条件/文案/启停/排序）"
git push origin master && git push github master
```

---

### Task 3: Flutter 端接入（远端拉取 + 离线缓存 + 三级兜底）

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/data/operation_banners.dart`（fromJson + banners 参数）
- Create: `lumira_app_flutter/lib/features/home/data/operation_banners_repository.dart`
- Modify: `lumira_app_flutter/lib/features/home/services/recommendation_service.dart`（operationBanners 参数透传）
- Modify: `lumira_app_flutter/lib/features/home/providers/banner_recommendation_provider.dart`（三级兜底加载）
- Modify: `lumira_app_flutter/lib/core/db/tables.dart`（新列常量）
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart`（v56 + onCreate 双处；顺带修复 capture_appearance 列缺失于 CREATE TABLE 的 fresh-install 缺陷）
- Modify: `lumira_app_flutter/lib/core/db/dao/settings_dao.dart`（缓存读写）
- Test: `lumira_app_flutter/test/features/home/operation_banners_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `GET /api/v1/banners` → `{ banners: [{id,title,subtitle,tag,route,condition}] }`
- Produces: `OperationBannersRepository.list() → Future<List<OperationBanner>>`；`SettingsDao.getOperationBannersCache() → Future<List<OperationBanner>?>`；`matchOperationBanner(banners: ...)` / `buildBanners(operationBanners: ...)`

- [ ] **Step 1: operation_banners.dart 模型扩展（先写测试）**

测试新增（追加到 operation_banners_test.dart）：

```dart
group('operationBannerFromJson（后端下发解析）', () {
  test('合法条目解析成功', () {
    final b = operationBannerFromJson({
      'id': 'op_invite', 'title': 't', 'subtitle': 's', 'tag': '邀请有礼',
      'route': '/invite', 'condition': 'nonNewUserNotInvited',
    });
    expect(b, isNotNull);
    expect(b!.id, 'op_invite');
    expect(b.condition, OperationCondition.nonNewUserNotInvited);
  });

  test('route 不在白名单 → 丢弃', () {
    expect(operationBannerFromJson({
      'id': 'x', 'title': 't', 'subtitle': 's', 'tag': 'tag',
      'route': '/nonexistent', 'condition': 'pointsReady',
    }), isNull);
  });

  test('condition 非法 → 丢弃', () {
    expect(operationBannerFromJson({
      'id': 'x', 'title': 't', 'subtitle': 's', 'tag': 'tag',
      'route': '/invite', 'condition': 'whatever',
    }), isNull);
  });

  test('字段缺失 → 丢弃', () {
    expect(operationBannerFromJson({'id': 'x'}), isNull);
  });
});

test('matchOperationBanner 支持远端下发列表', () {
  const custom = [
    OperationBanner(
      id: 'op_x', title: 'x', subtitle: 'x', tag: 'x',
      route: '/invite', condition: OperationCondition.nonNewUserNotInvited,
    ),
  ];
  final m = matchOperationBanner(
    isNewUser: false,
    banners: custom,
    inputs: const OperationUserInputs(hasBoundInviter: false),
  );
  expect(m?.id, 'op_x');
});

test('远端列表为空 → 不出运营位（后台全部停用语义）', () {
  expect(
    matchOperationBanner(
      isNewUser: false,
      banners: const [],
      inputs: const OperationUserInputs(hasBoundInviter: false),
    ),
    isNull,
  );
});
```

运行 `flutter test test/features/home/operation_banners_test.dart` 期望编译失败（函数不存在），然后实现：

```dart
/// 运营位路由白名单（与后端 OPERATION_BANNER_ROUTES 一致）。
/// 远端下发数据 route 不在名单内时整条丢弃（fail-safe，防旧版 App 跳转崩溃）。
const List<String> kOperationBannerRoutes = [
  '/invite',
  '/points/wallet',
  '/templates/unlock',
];

/// 后端下发条目 → 运营位模型；字段缺失/route 越白名单/condition 无法识别 → null（丢弃）。
OperationBanner? operationBannerFromJson(Map<String, dynamic> json) {
  final id = json['id'];
  final title = json['title'];
  final subtitle = json['subtitle'];
  final tag = json['tag'];
  final route = json['route'];
  if (id is! String || title is! String || subtitle is! String || tag is! String || route is! String) {
    return null;
  }
  if (!kOperationBannerRoutes.contains(route)) return null;
  OperationCondition? condition;
  for (final c in OperationCondition.values) {
    if (c.name == json['condition']) condition = c;
  }
  if (condition == null) return null;
  return OperationBanner(
    id: id, title: title, subtitle: subtitle, tag: tag,
    route: route, condition: condition,
  );
}
```

`matchOperationBanner` 签名加 `List<OperationBanner> banners = kOperationBanners`，遍历改为 `for (final banner in banners)`。

- [ ] **Step 2: repository + DB 缓存列 + DAO 读写**

operation_banners_repository.dart：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'operation_banners.dart';

/// 运营 Banner Repository 抽象
abstract class OperationBannersRepository {
  /// GET /banners → 启用中的运营条目（顺序即优先级）。
  /// 空列表是合法状态（后台全部停用）；网络/解析失败抛异常（由调用方走兜底）。
  Future<List<OperationBanner>> list();
}

class RemoteOperationBannersRepository implements OperationBannersRepository {
  final ApiClient _api;

  RemoteOperationBannersRepository(this._api);

  @override
  Future<List<OperationBanner>> list() async {
    final resp = await _api.get('/banners', fromJson: (j) => j as Map<String, dynamic>);
    final rawList = resp['banners'] as List?;
    if (rawList == null) return const [];
    return rawList
        .map((e) => e is Map<String, dynamic> ? operationBannerFromJson(e) : null)
        .whereType<OperationBanner>()
        .toList();
  }
}

final operationBannersRepositoryProvider =
    FutureProvider<OperationBannersRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return RemoteOperationBannersRepository(api);
});
```

tables.dart（colCaptureAppearance 附近）：

```dart
  static const String colOperationBannersCache = 'operation_banners_cache';
```

database_provider.dart：
1. `_kDbVersion = 56`
2. `_onCreate` 的 user_settings CREATE TABLE 加两列（v55 遗漏的 capture_appearance 修复 + 本任务新列）：
   `${Tables.colCaptureAppearance} TEXT NOT NULL DEFAULT 'immersive',`
   `${Tables.colOperationBannersCache} TEXT,`
3. `_onUpgrade` 末尾追加 v56 块（照 v55 模式）：

```dart
  if (oldVersion < 56) {
    try {
      // v56: user_settings 新增 operation_banners_cache 列
      // （后端下发的运营 Banner 离线缓存；capture_appearance 为 v55 列，
      //  此处幂等补齐，防个别升级路径遗漏）
      await _addColumnIfNotExists(
        db,
        Tables.userSettings,
        Tables.colOperationBannersCache,
        'TEXT',
      );
      await _addColumnIfNotExists(
        db,
        Tables.userSettings,
        Tables.colCaptureAppearance,
        "TEXT NOT NULL DEFAULT 'immersive'",
      );
    } catch (e) {
      debugPrint('v56 migration failed (silent fallback): $e');
    }
  }
```

settings_dao.dart 追加（import operation_banners.dart）：

```dart
  /// 读取运营 Banner 离线缓存（后端下发条目）。
  /// null = 无可用缓存（首次安装/从未成功拉取/解析失败）→ 调用方回退静态配置。
  /// 空列表是合法状态（后台全部停用），原样返回。
  Future<List<OperationBanner>?> getOperationBannersCache() async {
    final rows = await _db.query(
      Tables.userSettings,
      columns: [Tables.colOperationBannersCache],
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return null;
    final raw = rows.first[Tables.colOperationBannersCache] as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => e is Map<String, dynamic> ? operationBannerFromJson(e) : null)
          .whereType<OperationBanner>()
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// 写入运营 Banner 离线缓存（远端拉取成功后调用）
  Future<void> setOperationBannersCache(List<OperationBanner> banners) async {
    await _db.update(
      Tables.userSettings,
      {
        Tables.colOperationBannersCache: jsonEncode([
          for (final b in banners)
            {
              'id': b.id,
              'title': b.title,
              'subtitle': b.subtitle,
              'tag': b.tag,
              'route': b.route,
              'condition': b.condition.name,
            },
        ]),
        Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }
```

- [ ] **Step 3: provider 三级兜底 + service 透传**

recommendation_service.dart `buildBanners`：

```dart
  Future<List<HomeBannerItem>> buildBanners({
    OperationUserInputs operationInputs = const OperationUserInputs(),
    List<OperationBanner> operationBanners = kOperationBanners,
  }) async {
```

slot 0 调用处改为 `matchOperationBanner(isNewUser: isNewUser, banners: operationBanners, inputs: operationInputs)`；文档注释补一行：`[operationBanners] 为运营条目目录（默认静态；远端拉取成功后注入后台下发列表）`。

banner_recommendation_provider.dart：

```dart
  final operationInputs = await _loadOperationInputs(ref);
  final operationBanners = await _loadOperationBanners(ref);
  return service.buildBanners(
    operationInputs: operationInputs,
    operationBanners: operationBanners,
  );
```

新增（imports：operation_banners_repository.dart；settingsDaoProvider 已由 database_provider.dart 导出）：

```dart
/// 运营条目三级兜底：远端（成功则写离线缓存）→ 本地缓存 → 静态 kOperationBanners。
/// 空列表 [] 视为合法下发状态（后台全部停用），不触发兜底。
Future<List<OperationBanner>> _loadOperationBanners(Ref ref) async {
  try {
    final repo = await ref.watch(operationBannersRepositoryProvider.future);
    final banners = await repo.list();
    try {
      final dao = await ref.watch(settingsDaoProvider.future);
      await dao.setOperationBannersCache(banners);
    } catch (_) {/* 缓存写入失败不影响本次渲染 */}
    return banners;
  } catch (_) {
    try {
      final dao = await ref.watch(settingsDaoProvider.future);
      final cached = await dao.getOperationBannersCache();
      if (cached != null) return cached;
    } catch (_) {/* 缓存读取失败走静态目录 */}
    return kOperationBanners;
  }
}
```

- [ ] **Step 4: 验证 + 提交**

```bash
flutter analyze   # 无新增 error
flutter test test/features/home/operation_banners_test.dart test/features/home/recommendation_service_test.dart
git add lumira_app_flutter/lib/features/home/ lumira_app_flutter/lib/core/db/ lumira_app_flutter/test/features/home/
git commit -m "feat(home): 运营 Banner 接入后端下发（远端→离线缓存→静态三级兜底）"
```

---

### Task 4: 全局验证与收尾

- [ ] **Step 1: 三端验证命令**

```bash
pnpm --filter @lumira/backend build && pnpm --filter @lumira/backend test
pnpm --filter @lumira/admin build
flutter analyze
flutter test test/features/home/ test/features/usage/
```

存量已知失败（home_page_test 5 条 databaseFactory、scene_reco 1 条 ResizeImage）与本功能无关，基线一致即通过。

- [ ] **Step 2: 更新 docs/future-optimizations.md**

P1「运营位下发系统」状态改 `✅ 已实现`，补一行实现说明（接口路径 + 三级兜底）。

- [ ] **Step 3: 收尾提交 + 推送双远程**

```bash
git add docs/future-optimizations.md docs/superpowers/plans/2026-09-09-banner-admin-delivery.md
git commit -m "docs: 运营位下发系统落地收尾（P1 已实现 + 实施计划归档）"
git push origin master && git push github master
```

- [ ] **Step 4: 输出手动验证清单**

（后台改文案 → App 冷启动 60s 内生效；断网 → 上次缓存；首次安装断网 → 静态 3 条；后台全停用 → 无运营位；埋点 item_id 仍为 banner.id）

---

## Self-Review 结论

- 覆盖 P1 目标三要素：后端 CRUD+下发（Task 1）、后台管理页（Task 2）、App 拉取+离线缓存兜底（Task 3）✓
- 无占位符；类型/签名跨任务一致（BannerAdminItem ↔ admin 返回行；banners 列表注入点 3 处同名）✓
- 已知风险点：MySQL `condition` 保留字（全程 Drizzle builder + 反引号规避）；fresh install CREATE TABLE 双列补齐 ✓
