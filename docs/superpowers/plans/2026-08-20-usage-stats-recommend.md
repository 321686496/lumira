# 使用次数统计 + 推荐增强 + 场景后台管理 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 后端记录用户对模板/系统场景的使用事件并开放全站汇总次数接口、提供系统内置场景后台管理；App 本地优先记录并在联网时同步后端次数以增强本地推荐/排序/Banner/搜索，离线不降级。

**Architecture:** 后端新增 `usage_events`（事件流水）与 `system_scenes`（系统内置场景）两表，提供批量上报 / 汇总统计 / 场景同步三个客户端接口与后台场景 CRUD。App 本地 sqflite 新增 `usage_events`（待同步队列）与 `usage_stats`（远程汇总缓存）两表；`UsageEventRecorder` 仅对内置/后台模板与系统场景埋点，`UsageSyncService` 联网时上报+拉取次数，本地推荐/搜索把远程次数作为流行度权重叠加（离线时权重为 0，功能不降级）。

**Tech Stack:** NestJS + Fastify + Drizzle ORM + MySQL8；Next.js(App Router)+Tailwind+shadcn/ui 后台；Flutter 3.7.12/Dart 2.19.6 + flutter_riverpod + sqflite。

## Global Constraints

- 客户端 Flutter 3.7.12 / Dart 2.19.6，**不支持 Dart 3 records 语法**；大对象一律用类。
- 本地表列名/表名集中定义在 `lib/core/db/tables.dart`，不得在 SQL 中散落硬编码字符串。
- sqflite 逐版本迁移在 `database_provider.dart` 的 `_onUpgrade` 用 `if (oldVersion < N)`，新增表用 `_addColumnIfNotExists`/`CREATE TABLE IF NOT EXISTS` 保证幂等。
- 后端迁移：`src/database/schema.ts`（Drizzle 表）+ `src/database/migrations/NNN_xxx.sql`（DDL），启动时由 `DatabaseService.runMigrations()` 按文件名顺序幂等应用。
- admin 后端 API 全部挂在 `/api/v1/admin/*`，用 `AdminAuthGuard`（Bearer `ADMIN_TOKEN`）；客户端接口用 `DeviceAuthGuard` + `@DeviceId()`。
- 事件口径：模板仅记录 `source ∈ {builtin, remote}`，用户自定义（`custom`）不记录；场景仅记录 `creator=system` 的系统内置场景。
- 统计口径：按事件累加（同一设备反复使用均计入）；去重仅靠 `client_event_id` 唯一索引做上报幂等。
- 推荐公式：`finalNote = score_local*(1-α) + score_pop*α`；离线/无缓存时 `α=0`。
- 后端/后台改动完成后必须 commit 并 push 到 origin(gitee) 与 github（见 AGENTS.md），不要积压。

---

### Task 1: 后端 shared 类型 + Drizzle schema + 迁移 SQL

**Files:**
- Create: `lumira-server/packages/shared/src/types/usage.ts`
- Modify: `lumira-server/packages/shared/src/index.ts`
- Modify: `lumira-server/packages/backend/src/database/schema.ts`
- Create: `lumira-server/packages/backend/src/database/migrations/005_usage_and_scenes.sql`

**Interfaces:**
- Produces: shared 类型 `UsageEventInput`, `UsageStatsResponse`, `SystemScene`, `SystemSceneListResponse`, `CreateSceneRequest`；Drizzle 表 `usageEvents`, `systemScenes`；迁移 `005_usage_and_scenes.sql`（建 `usage_events`、`system_scenes` 两表）。

- [ ] **Step 1: 新增 shared 类型文件**

```ts
// lumira-server/packages/shared/src/types/usage.ts
export type UsageItemType = 'template' | 'scene';
export type UsageEventType = 'open_detail' | 'use_shoot' | 'scene_select';
export type TemplateSource = 'builtin' | 'remote';

export interface UsageEventInput {
  /** App 生成的唯一 ID，用于上报幂等去重 */
  clientEventId: string;
  itemType: UsageItemType;
  itemId: string;
  /** 模板来源 builtin/remote；场景固定为 'system' */
  itemSource: string;
  eventType: UsageEventType;
  occurredAt: number;
}

export interface UsageStatsItem {
  itemId: string;
  itemType: UsageItemType;
  useShoot: number;
  openDetail: number;
  sceneSelect: number;
}

export interface UsageStatsResponse {
  items: UsageStatsItem[];
}

// ===== 系统内置场景 =====
export interface SystemScene {
  id: string;
  name: string;
  category: string; // light | outdoor | indoor | mood
  style: string;
  icon: string;
  vibe: string;
  description: string;
  filter: Record<string, unknown>;
  tips: string[];
  exampleImages: string[];
  whereToShoot: string;
  bestTime: string;
  relatedCategory: string;
  recommendedTagIds: string[];
  sortOrder: number;
  isActive: boolean;
  updatedAt: number;
}

export interface SystemSceneListResponse {
  scenes: SystemScene[];
}

export interface CreateSceneRequest {
  id: string;
  name: string;
  category: string;
  style?: string;
  icon?: string;
  vibe?: string;
  description?: string;
  filter?: Record<string, unknown>;
  tips?: string[];
  exampleImages?: string[];
  whereToShoot?: string;
  bestTime?: string;
  relatedCategory?: string;
  recommendedTagIds?: string[];
  sortOrder?: number;
  isActive?: boolean;
}

export interface UpdateSceneRequest extends Partial<Omit<CreateSceneRequest, 'id'>> {}
```

- [ ] **Step 2: 在 index.ts 导出**

```ts
// lumira-server/packages/shared/src/index.ts 末尾追加
export * from './types/usage';
```

- [ ] **Step 3: schema.ts 追加两表（文件末尾，遵守 mysqlTable 既有风格）**

```ts
// lumira-server/packages/backend/src/database/schema.ts 末尾追加
// ===== 使用次数统计（spec 2026-08-20-usage-stats-recommend-design）=====
export const usageEvents = mysqlTable('usage_events', {
  id: int('id').primaryKey().autoincrement(),
  deviceId: text('device_id').notNull().references(() => devices.deviceId),
  clientEventId: text('client_event_id').notNull(),
  itemType: text('item_type').notNull(),
  itemId: text('item_id').notNull(),
  itemSource: text('item_source').notNull(),
  eventType: text('event_type').notNull(),
  occurredAt: int('occurred_at').notNull(),
}, (table) => ({
  clientEventIdx: uniqueIndex('uq_usage_client_event').on(table.clientEventId),
}));

export const systemScenes = mysqlTable('system_scenes', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  category: text('category').notNull(),
  style: text('style').notNull().default(''),
  icon: text('icon').notNull().default(''),
  vibe: text('vibe').notNull().default(''),
  description: text('description').notNull().default(''),
  filterJson: longtext('filter_json').notNull().default('{}'),
  tipsJson: text('tips_json').notNull().default('[]'),
  exampleImagesJson: text('example_images_json').notNull().default('[]'),
  whereToShoot: text('where_to_shoot').notNull().default(''),
  bestTime: text('best_time').notNull().default(''),
  relatedCategory: text('related_category').notNull().default(''),
  recommendedTagIdsJson: text('recommended_tag_ids_json').notNull().default('[]'),
  sortOrder: int('sort_order').notNull().default(0),
  isActive: int('is_active').notNull().default(1),
  createdAt: int('created_at').notNull(),
  updatedAt: int('updated_at').notNull(),
}, (table) => ({
  activeIdx: index('idx_system_scenes_active').on(table.isActive),
}));
```

- [ ] **Step 4: 新增迁移 SQL**

```sql
-- lumira-server/packages/backend/src/database/migrations/005_usage_and_scenes.sql
CREATE TABLE IF NOT EXISTS `usage_events` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `device_id` TEXT NOT NULL,
  `client_event_id` TEXT NOT NULL,
  `item_type` TEXT NOT NULL,
  `item_id` TEXT NOT NULL,
  `item_source` TEXT NOT NULL,
  `event_type` TEXT NOT NULL,
  `occurred_at` INT NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_usage_client_event` (`client_event_id`(191))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `system_scenes` (
  `id` VARCHAR(128) NOT NULL,
  `name` TEXT NOT NULL,
  `category` TEXT NOT NULL,
  `style` TEXT NOT NULL DEFAULT '',
  `icon` TEXT NOT NULL DEFAULT '',
  `vibe` TEXT NOT NULL DEFAULT '',
  `description` TEXT NOT NULL DEFAULT '',
  `filter_json` LONGTEXT NOT NULL DEFAULT '{}',
  `tips_json` TEXT NOT NULL DEFAULT '[]',
  `example_images_json` TEXT NOT NULL DEFAULT '[]',
  `where_to_shoot` TEXT NOT NULL DEFAULT '',
  `best_time` TEXT NOT NULL DEFAULT '',
  `related_category` TEXT NOT NULL DEFAULT '',
  `recommended_tag_ids_json` TEXT NOT NULL DEFAULT '[]',
  `sort_order` INT NOT NULL DEFAULT 0,
  `is_active` INT NOT NULL DEFAULT 1,
  `created_at` INT NOT NULL,
  `updated_at` INT NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_system_scenes_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

> 说明：`schema.ts` 与迁移 SQL 需保持列一致。本作以 SQL 迁移为运行时真源（`runMigrations` 执行），schema.ts 供 Drizzle 服务查询用。

- [ ] **Step 5: 类型检查**

Run: `cd lumira-server/packages/backend && pnpm typecheck`
Expected: typecheck 通过，无 usage/scene 相关报错。

- [ ] **Step 6: Commit**

```bash
cd d:/app/projects/photo_post
git add lumira-server/packages/shared lumira-server/packages/backend/src/database
git commit -m "feat(shared/backend): 新增 usage_events/system_scenes 表与 shared 类型"
```

---

### Task 2: 后端 usage 模块（事件上报 + 汇总统计）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/usage/usage.controller.ts`
- Create: `lumira-server/packages/backend/src/modules/usage/usage.service.ts`
- Create: `lumira-server/packages/backend/src/modules/usage/usage.module.ts`
- Create: `lumira-server/packages/backend/src/modules/usage/dto/batch-events.dto.ts`

**Interfaces:**
- Produces: `POST /api/v1/usage/events`（批量 upsert，幂等）与 `GET /api/v1/usage/stats?itemType=template|scene`（全站汇总）。
- Consumes: Task 1 的 `usageEvents` 表、shared 类型 `UsageEventInput/UsageStatsResponse`。

- [ ] **Step 1: 写 DTO**

```ts
// lumira-server/packages/backend/src/modules/usage/dto/batch-events.dto.ts
import { Type } from 'class-transformer';
import { ArrayNotEmpty, IsArray, IsIn, IsInt, IsNotEmpty, IsString, Min, ValidateNested } from 'class-validator';
import type { UsageEventType, UsageItemType } from '@lumira/shared';

export class BatchEventDto {
  @Type(() => EventInputDto)
  @IsArray()
  @ArrayNotEmpty()
  @ValidateNested({ each: true })
  events!: EventInputDto[];
}

export class EventInputDto {
  @IsString() @IsNotEmpty() clientEventId!: string;
  @IsIn(['template', 'scene']) itemType!: UsageItemType;
  @IsString() @IsNotEmpty() itemId!: string;
  @IsString() @IsNotEmpty() itemSource!: string;
  @IsIn(['open_detail', 'use_shoot', 'scene_select']) eventType!: UsageEventType;
  @IsInt() @Min(0) occurredAt!: number;
}
```

- [ ] **Step 2: 写 service（含幂等 upsert 与聚合）**

```ts
// lumira-server/packages/backend/src/modules/usage/usage.service.ts
import { Injectable } from '@nestjs/common';
import { sql } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { usageEvents } from '../../database/schema';
import type { EventInputDto } from './dto/batch-events.dto';
import type { UsageStatsResponse, UsageItemType } from '@lumira/shared';

@Injectable()
export class UsageService {
  constructor(private readonly dbService: DatabaseService) {}

  /** 批量上报。用 INSERT ... ON DUPLICATE KEY UPDATE 保证 client_event_id 幂等。 */
  async recordBatch(deviceId: string, events: EventInputDto[]): Promise<{ inserted: number }> {
    if (events.length === 0) return { inserted: 0 };
    const db = this.dbService.getDb();
    // 逐条 ON DUPLICATE（client_event_id 唯一索引），重复上报不重复计数
    for (const e of events) {
      await db.execute(sql`
        INSERT INTO ${usageEvents}
          (${usageEvents.deviceId}, ${usageEvents.clientEventId}, ${usageEvents.itemType},
           ${usageEvents.itemId}, ${usageEvents.itemSource}, ${usageEvents.eventType}, ${usageEvents.occurredAt})
        VALUES (${deviceId}, ${e.clientEventId}, ${e.itemType}, ${e.itemId}, ${e.itemSource}, ${e.eventType}, ${e.occurredAt})
        ON DUPLICATE KEY UPDATE \`client_event_id\` = ${e.clientEventId}
      `);
    }
    return { inserted: events.length };
  }

  /** 全站按 itemType+itemId+eventType 累加汇总。 */
  async stats(itemType?: UsageItemType): Promise<UsageStatsResponse> {
    const db = this.dbService.getDb();
    const rows = await db.execute(sql`
      SELECT item_id AS itemId, item_type AS itemType, event_type AS eventType, COUNT(*) AS cnt
      FROM ${usageEvents}
      WHERE ${itemType ? sql`item_type = ${itemType}` : sql`1=1`}
      GROUP BY item_id, item_type, event_type
    `);
    const summary = new Map<string, { itemId: string; itemType: string; useShoot: number; openDetail: number; sceneSelect: number }>();
    for (const r of (rows[0] as Array<Record<string, unknown>>)) {
      const key = `${String(r.itemType)}:${String(r.itemId)}`;
      const item = summary.get(key) ?? { itemId: String(r.itemId), itemType: String(r.itemType), useShoot: 0, openDetail: 0, sceneSelect: 0 };
      const cnt = Number(r.cnt);
      if (r.eventType === 'use_shoot') item.useShoot += cnt;
      else if (r.eventType === 'open_detail') item.openDetail += cnt;
      else if (r.eventType === 'scene_select') item.sceneSelect += cnt;
      summary.set(key, item);
    }
    return { items: [...summary.values()] };
  }
}
```

- [ ] **Step 3: 写 controller（客户端路由 + 鉴权）**

```ts
// lumira-server/packages/backend/src/modules/usage/usage.controller.ts
import { Body, Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { UsageService } from './usage.service';
import { BatchEventDto } from './dto/batch-events.dto';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { DeviceId } from '../../common/decorators';

@Controller('usage')
@UseGuards(DeviceAuthGuard)
export class UsageController {
  constructor(private readonly usageService: UsageService) {}

  @Post('events')
  async batch(@DeviceId() deviceId: string, @Body() dto: BatchEventDto) {
    return this.usageService.recordBatch(deviceId, dto.events);
  }

  @Get('stats')
  async stats(@Query('itemType') itemType?: string) {
    return this.usageService.stats(
      itemType === 'scene' ? 'scene' : itemType === 'template' ? 'template' : undefined,
    );
  }
}
```

- [ ] **Step 4: 写 module 并在 app.module.ts 注册**

```ts
// lumira-server/packages/backend/src/modules/usage/usage.module.ts
import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { UsageController } from './usage.controller';
import { UsageService } from './usage.service';

@Module({
  imports: [DatabaseModule],
  controllers: [UsageController],
  providers: [UsageService],
})
export class UsageModule {}
```

`lumira-server/packages/backend/src/app.module.ts`：`import { UsageModule } from './modules/usage/usage.module';` 并在 `imports` 数组加入 `UsageModule`。

- [ ] **Step 5: 类型检查 + 单测（service 聚合逻辑）**

新增 `usrformance` 单测 `usage.service.spec.ts`，mock `DatabaseService`（`getDb()` 返回 fake db 使 `execute` 返回固定行），断言 `stats()` 的聚合返回正确。

Run: `cd lumira-server/packages/backend && pnpm typecheck && pnpm test -- usage`
Expected: typecheck 通过，usage.service.spec 通过。

- [ ] **Step 6: Commit**

```bash
cd d:/app/projects/photo_post
git add lumira-server/packages/backend/src/modules/usage lumira-server/packages/backend/src/app.module.ts
git commit -m "feat(backend): usage 模块 - 事件批量上报与全站汇总统计接口"
```

---

### Task 3: 后端 scenes 模块（客户端同步 + admin 场景 CRUD）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/scenes/scenes.controller.ts`
- Create: `lumira-server/packages/backend/src/modules/scenes/scenes.service.ts`
- Create: `lumira-server/packages/backend/src/modules/scenes/scenes.module.ts`
- Create: `lumira-server/packages/backend/src/modules/scenes/admin-scenes.controller.ts`
- Create: `lumira-server/packages/backend/src/modules/scenes/dto/create-scene.dto.ts`
- Create: `lumira-server/packages/backend/src/modules/scenes/dto/update-scene.dto.ts`

**Interfaces:**
- Produces: 客户端 `GET /api/v1/scenes`（启用场景，含使用次数）；admin `GET/POST/PATCH/DELETE /api/v1/admin/scenes*`。
- Consumes: Task 1 的 `systemScenes` 表、`usageEvents` 表；`UsageService.stats` 用于并列次数。

- [ ] **Step 1: 写 DTO**

```ts
// dto/create-scene.dto.ts
import { IsArray, IsBoolean, IsIn, IsInt, IsNotEmpty, IsObject, IsOptional, IsString } from 'class-validator';
export class CreateSceneDto {
  @IsString() @IsNotEmpty() id!: string;
  @IsString() @IsNotEmpty() name!: string;
  @IsIn(['light', 'outdoor', 'indoor', 'mood']) category!: string;
  @IsOptional() @IsString() style?: string;
  @IsOptional() @IsString() icon?: string;
  @IsOptional() @IsString() vibe?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsObject() filter?: Record<string, unknown>;
  @IsOptional() @IsArray() tips?: string[];
  @IsOptional() @IsArray() exampleImages?: string[];
  @IsOptional() @IsString() whereToShoot?: string;
  @IsOptional() @IsString() bestTime?: string;
  @IsOptional() @IsString() relatedCategory?: string;
  @IsOptional() @IsArray() recommendedTagIds?: string[];
  @IsOptional() @IsInt() sortOrder?: number;
  @IsOptional() @IsBoolean() isActive?: boolean;
}
```
```ts
// dto/update-scene.dto.ts
import { PartialType } from '@nestjs/mapped-types';
import { CreateSceneDto } from './create-scene.dto';
export class UpdateSceneDto extends PartialType(CreateSceneDto) {}
```

- [ ] **Step 2: 写 service（含客户端列表+次数、admin CRUD）**

```ts
// modules/scenes/scenes.service.ts
import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { asc, sql } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { systemScenes } from '../../database/schema';
import { UsageService } from '../usage/usage.service';
import { CreateSceneDto } from './dto/create-scene.dto';
import { UpdateSceneDto } from './dto/update-scene.dto';
import type { SystemScene } from '@lumira/shared';

@Injectable()
export class ScenesService {
  constructor(private readonly dbService: DatabaseService, private readonly usageService: UsageService) {}

  private toScene(row: Record<string, unknown>): SystemScene {
    return {
      id: String(row.id),
      name: String(row.name),
      category: String(row.category),
      style: String(row.style ?? ''),
      icon: String(row.icon ?? ''),
      vibe: String(row.vibe ?? ''),
      description: String(row.description ?? ''),
      filter: safeParse(row.filter_json),
      tips: safeJsonArray(row.tips_json),
      exampleImages: safeJsonArray(row.example_images_json),
      whereToShoot: String(row.where_to_shoot ?? ''),
      bestTime: String(row.best_time ?? ''),
      relatedCategory: String(row.related_category ?? ''),
      recommendedTagIds: safeJsonArray(row.recommended_tag_ids_json),
      sortOrder: Number(row.sort_order ?? 0),
      isActive: Number(row.is_active ?? 1) === 1,
      updatedAt: Number(row.updated_at ?? 0),
    };
  }

  /** 客户端：返回启用场景 + 对应使用次数 */
  async listActive(): Promise<{ scenes: Array<SystemScene & { usage: { useShoot: number; openDetail: number; sceneSelect: number } }> }> {
    const db = this.dbService.getDb();
    const rows = await db.select().from(systemScenes)
      .where(sql`${systemScenes.isActive} = 1`)
      .orderBy(asc(systemScenes.sortOrder));
    const stats = await this.usageService.stats('scene');
    const statsMap = new Map(stats.items.map((i) => [i.itemId, i]));
    return {
      scenes: rows.map((r) => {
        const u = statsMap.get(r.id);
        return { ...this.toScene(r), usage: { useShoot: u?.useShoot ?? 0, openDetail: u?.openDetail ?? 0, sceneSelect: u?.sceneSelect ?? 0 } };
      }),
    };
  }

  async listAdmin(): Promise<{ scenes: SystemScene[] }> {
    const db = this.dbService.getDb();
    const rows = await db.select().from(systemScenes).orderBy(asc(systemScenes.sortOrder));
    return { scenes: rows.map((r) => this.toScene(r)) };
  }

  async create(dto: CreateSceneDto): Promise<SystemScene> {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);
    const existing = await db.select().from(systemScenes).where(sql`${systemScenes.id} = ${dto.id}`).limit(1);
    if (existing.length > 0) throw new ConflictException(`Scene id already exists: ${dto.id}`);
    const row = { ...dto, filterJson: dto.filter ? JSON.stringify(dto.filter) : '{}' };
    await db.insert(systemScenes).values({
      id: dto.id,
      name: dto.name,
      category: dto.category,
      style: dto.style ?? '',
      icon: dto.icon ?? '',
      vibe: dto.vibe ?? '',
      description: dto.description ?? '',
      filterJson: row.filterJson,
      tipsJson: JSON.stringify(dto.tips ?? []),
      exampleImagesJson: JSON.stringify(dto.exampleImages ?? []),
      whereToShoot: dto.whereToShoot ?? '',
      bestTime: dto.bestTime ?? '',
      relatedCategory: dto.relatedCategory ?? '',
      recommendedTagIdsJson: JSON.stringify(dto.recommendedTagIds ?? []),
      sortOrder: dto.sortOrder ?? 0,
      isActive: dto.isActive === false ? 0 : 1,
      createdAt: now,
      updatedAt: now,
    });
    return (await this.getById(dto.id))!;
  }

  async update(id: string, dto: UpdateSceneDto): Promise<SystemScene> {
    const db = this.dbService.getDb();
    await this.requireExists(id);
    const now = Math.floor(Date.now() / 1000);
    const patch: Record<string, unknown> = { updatedAt: now };
    for (const k of ['name', 'category', 'style', 'icon', 'vibe', 'description', 'whereToShoot', 'bestTime', 'relatedCategory'] as const) {
      if (dto[k] !== undefined) patch[k] = dto[k];
    }
    if (dto.filter !== undefined) patch.filterJson = JSON.stringify(dto.filter);
    if (dto.tips !== undefined) patch.tipsJson = JSON.stringify(dto.tips);
    if (dto.exampleImages !== undefined) patch.exampleImagesJson = JSON.stringify(dto.exampleImages);
    if (dto.recommendedTagIds !== undefined) patch.recommendedTagIdsJson = JSON.stringify(dto.recommendedTagIds);
    if (dto.sortOrder !== undefined) patch.sortOrder = dto.sortOrder;
    if (dto.isActive !== undefined) patch.isActive = dto.isActive ? 1 : 0;
    await db.update(systemScenes).set(patch).where(sql`${systemScenes.id} = ${id}`);
    return (await this.getById(id))!;
  }

  async remove(id: string): Promise<{ success: true }> {
    const db = this.dbService.getDb();
    await this.requireExists(id);
    await db.delete(systemScenes).where(sql`${systemScenes.id} = ${id}`);
    return { success: true };
  }

  async toggleActive(id: string): Promise<{ id: string; isActive: boolean }> {
    const db = this.dbService.getDb();
    const scene = await this.requireExists(id);
    const next = scene.isActive ? 0 : 1;
    await db.update(systemScenes).set({ isActive: next, updatedAt: Math.floor(Date.now() / 1000) }).where(sql`${systemScenes.id} = ${id}`);
    return { id, isActive: next === 1 };
  }

  private async getById(id: string): Promise<SystemScene | null> {
    const db = this.dbService.getDb();
    const rows = await db.select().from(systemScenes).where(sql`${systemScenes.id} = ${id}`).limit(1);
    return rows.length > 0 ? this.toScene(rows[0]) : null;
  }
  private async requireExists(id: string): Promise<SystemScene> {
    const s = await this.getById(id);
    if (!s) throw new NotFoundException(`Scene not found: ${id}`);
    return s;
  }
}

function safeParse(json: unknown): Record<string, unknown> {
  if (typeof json !== 'string' || !json) return {};
  try { return JSON.parse(json); } catch { return {}; }
}
function safeJsonArray(json: unknown): string[] {
  if (typeof json !== 'string' || !json) return [];
  try { const v = JSON.parse(json); return Array.isArray(v) ? v.filter((x) => typeof x === 'string') : []; } catch { return []; }
}
```

- [ ] **Step 3: 写客户端 controller 与 admin controller**

```ts
// modules/scenes/scenes.controller.ts
import { Controller, Get, UseGuards } from '@nestjs/common';
import { ScenesService } from './scenes.service';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
@Controller('scenes')
@UseGuards(DeviceAuthGuard)
export class ScenesController {
  constructor(private readonly scenesService: ScenesService) {}
  @Get()
  list() { return this.scenesService.listActive(); }
}
```
```ts
// modules/scenes/admin-scenes.controller.ts
import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { ScenesService } from './scenes.service';
import { CreateSceneDto } from './dto/create-scene.dto';
import { UpdateSceneDto } from './dto/update-scene.dto';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
@Controller('admin/scenes')
@UseGuards(AdminAuthGuard)
export class AdminScenesController {
  constructor(private readonly scenesService: ScenesService) {}
  @Get() list() { return this.scenesService.listAdmin(); }
  @Post() create(@Body() dto: CreateSceneDto) { return this.scenesService.create(dto); }
  @Patch(':id') update(@Param('id') id: string, @Body() dto: UpdateSceneDto) { return this.scenesService.update(id, dto); }
  @Delete(':id') remove(@Param('id') id: string) { return this.scenesService.remove(id); }
  @Post(':id/toggle') toggle(@Param('id') id: string) { return this.scenesService.toggleActive(id); }
}
```

- [ ] **Step 4: module + app.module 注册**

```ts
// modules/scenes/scenes.module.ts
import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { UsageModule } from '../usage/usage.module';
import { ScenesController } from './scenes.controller';
import { AdminScenesController } from './admin-scenes.controller';
import { ScenesService } from './scenes.service';
@Module({
  imports: [DatabaseModule, UsageModule],
  controllers: [ScenesController, AdminScenesController],
  providers: [ScenesService],
  exports: [ScenesService],
})
export class ScenesModule {}
```
`app.module.ts`：`import { ScenesModule } from './modules/scenes/scenes.module';` 加入 `imports`。
注意：`UsageModule` 需要 `exports: [UsageService]`（在 Task 2 usage.module.ts 中补充 `exports: [UsageService]`）。

- [ ] **Step 5: 类型检查 + e2e/单测（service CRUD 与 listActive 逻辑）**

创建 `scenes.service.spec.ts`（mock db，断言 create/update/listActive）。另在既有 admin e2e 中补 admin scenes 增删改查冒烟用例（可选，至少 typecheck + unit）。

Run: `cd lumira-server/packages/backend && pnpm typecheck && pnpm test -- scenes`
Expected: typecheck 通过，scenes.service.spec 通过。

- [ ] **Step 6: Commit**

```bash
cd d:/app/projects/photo_post
git add lumira-server/packages/backend/src/modules/scenes lumira-server/packages/backend/src/app.module.ts lumira-server/packages/backend/src/modules/usage/usage.module.ts
git commit -m "feat(backend): scenes 模块 - 客户端场景同步与 admin 场景 CRUD"
```

---

### Task 4: 后台 admin 场景管理页 + 模板列表次数列

**Files:**
- Modify: `lumira-server/packages/admin/src/components/sidebar.tsx`
- Modify: `lumira-server/packages/admin/src/components/dashboard-shell.tsx`
- Modify: `lumira-server/packages/admin/src/lib/api.ts`
- Create: `lumira-server/packages/admin/src/actions/scenes.ts`
- Create: `lumira-server/packages/admin/src/components/scene-manager.tsx`
- Create: `lumira-server/packages/admin/src/app/dashboard/scenes/page.tsx`
- Modify: `lumira-server/packages/admin/src/components/template-card-grid.tsx`

**Interfaces:**
- Consumes: Task 3 的 `/api/v1/admin/scenes*`。
- Produces: 后台「场景管理」入口与页面、模板卡展示次数。

- [ ] **Step 1: api.ts 增加 admin scenes 与 usage 汇总读取**

在 `lumira-server/packages/admin/src/lib/api.ts` 末尾追加：

```ts
export interface AdminScene {
  id: string; name: string; category: string; icon: string; vibe: string;
  isActive: boolean; sortOrder: number; updatedAt: number;
}
export async function listScenes(): Promise<AdminScene[]> {
  const res = await adminFetch('/api/v1/admin/scenes', { next: { revalidate: 0 } });
  const data = await res.json();
  return data.scenes ?? [];
}
export async function createScene(payload: Record<string, unknown>) {
  return adminFetch('/api/v1/admin/scenes', { method: 'POST', body: JSON.stringify(payload) });
}
export async function updateScene(id: string, payload: Record<string, unknown>) {
  return adminFetch(`/api/v1/admin/scenes/${encodeURIComponent(id)}`, { method: 'PATCH', body: JSON.stringify(payload) });
}
export async function deleteScene(id: string) {
  return adminFetch(`/api/v1/admin/scenes/${encodeURIComponent(id)}`, { method: 'DELETE' });
}
export async function toggleScene(id: string) {
  return adminFetch(`/api/v1/admin/scenes/${encodeURIComponent(id)}/toggle`, { method: 'POST' });
}
```
> `adminFetch` 请复用 `lib/api.ts` 既有的统一 fetch 封装（自动注入 `BACKEND_URL` + admin auth cookie）。若返回 `{ scenes }` 结构，按实际对齐。

- [ ] **Step 2: 新建 server actions**

```ts
// lumira-server/packages/admin/src/actions/scenes.ts
'use server';
import { revalidatePath } from 'next/cache';
import { createScene, deleteScene, updateScene, toggleScene } from '../lib/api';
export async function saveScene(id: string | null, payload: Record<string, unknown>) {
  if (id) await updateScene(id, payload);
  else await createScene(payload);
  revalidatePath('/dashboard/scenes');
}
export async function removeScene(id: string) {
  await deleteScene(id); revalidatePath('/dashboard/scenes');
}
export async function setSceneActive(id: string) {
  await toggleScene(id); revalidatePath('/dashboard/scenes');
}
```

- [ ] **Step 3: 场景管理组件 + 页面 + 菜单**

- `scene-manager.tsx`：网格卡片（名/分类/图标/启停 badge/usage），表单支持新建/编辑/删除/启停（复用 `TemplateForm` 的 `Dialog/Form` 风格，字段：name、category select、style、icon、vibe、description、bestTime、sortOrder、isActive）。
- `app/dashboard/scenes/page.tsx`：服务端 `listScenes()` 后渲染 `SceneManager`。
- `sidebar.tsx`：在「分类管理」后加 `{ href: '/dashboard/scenes', label: '场景管理', icon: <CameraIcon/> }`。
- `dashboard-shell.tsx`：标题映射增加值 `/dashboard/scenes → '场景管理'`。
- `template-card-grid.tsx`：模板卡角落展示 `use_shoot`/`open_detail` 次数（若 admin 模板明细没带，则在 `templates/page.tsx` 额外 `GET /api/v1/usage/stats?itemType=template` 合并进去）。

- [ ] **Step 4: 构建校验**

Run: `cd lumira-server/packages/admin && pnpm build`
Expected: build 通过，无类型错误。

- [ ] **Step 5: Commit**

```bash
cd d:/app/projects/photo_post
git add lumira-server/packages/admin
git commit -m "feat(admin): 场景管理页 + 模板列表使用次数列"
```

---

### Task 5: Flutter 本地表迁移（usage_events / usage_stats）+ tables 常量

**Files:**
- Modify: `lumira_app_flutter/lib/core/db/tables.dart`
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart`
- Create: `lumira_app_flutter/lib/core/db/dao/usage_dao.dart`

**Interfaces:**
- Produces: `UsageDao`（`enqueueEvent`, `getUnsyncedEvents`, `markSynced`, `setStats`, `getStats`, `getStatsFor`）。
- Version: `_kDbVersion` 27 → 28。

- [ ] **Step 1: tables.dart 增加常量**

```ts
// tables.dart 末尾追加（usage 相关）
// === usage_events / usage_stats 表（v28 迁移新增，使用次数统计） ===
static const String usageEvents = 'usage_events';
static const String colClientEventId = 'client_event_id';
static const String colItemType = 'item_type';
static const String colItemId = 'item_id';
static const String colItemSource = 'item_source';
static const String colEventType = 'event_type';
static const String colOccurredAt = 'occurred_at';
static const String colSynced = 'synced';

static const String usageStats = 'usage_stats';
// colItemType / colItemId / colEventType 复用上面常量
static const String colCount = 'count';
static const String colUpdatedAt = 'updated_at';
```

- [ ] **Step 2: database_provider.dart：版本号 + onCreate + onUpgrade v28**

```dart
const int _kDbVersion = 28;
```
`_onCreate` 中（核心表创建区，尽量靠前）追加：
```dart
await _createUsageTables(batch);
```
并在文件底部新增辅助（幂等）：
```dart
Future<void> _createUsageTables(Batch batch) async {
  batch.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.usageEvents} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ${Tables.colClientEventId} TEXT NOT NULL UNIQUE,
      ${Tables.colItemType} TEXT NOT NULL,
      ${Tables.colItemId} TEXT NOT NULL,
      ${Tables.colItemSource} TEXT NOT NULL,
      ${Tables.colEventType} TEXT NOT NULL,
      ${Tables.colOccurredAt} INTEGER NOT NULL,
      ${Tables.colSynced} INTEGER NOT NULL DEFAULT 0
    )
  ''');
  batch.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.usageStats} (
      ${Tables.colItemType} TEXT NOT NULL,
      ${Tables.colItemId} TEXT NOT NULL,
      ${Tables.colEventType} TEXT NOT NULL,
      ${Tables.colCount} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colUpdatedAt} INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (${Tables.colItemType}, ${Tables.colItemId}, ${Tables.colEventType})
    )
  ''');
}
```
`_onUpgrade` 追加最新分支（放在文件末尾最后一段之后）：
```dart
if (oldVersion < 28) {
  try {
    await _createUsageTables(db);
  } catch (e) {
    debugPrint('v28 migration failed (silent fallback): $e');
  }
}
```
> `_createUsageTables` 需同时兼容 `Batch` 与 `Database`。写成泛型接受 `Database` 即可，onCreate 用 `batch.execute` 时改为循环 `execute`（或提供 `_createUsageTablesOnCreate`）。实现时把 `_createUsageTables` 参数改为 `Database db`，并在 `_onCreate` 中 `await _createUsageTables(db);`（onCreate 内已可 `await`）。

- [ ] **Step 3: 新建 UsageDao**

```dart
// lib/core/db/dao/usage_dao.dart
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../tables.dart';

enum UsageItemType { template, scene }
enum UsageEventType { openDetail, useShoot, sceneSelect }
String eventTypeName(UsageEventType t) =>
  t == UsageEventType.openDetail ? 'open_detail' : t == UsageEventType.useShoot ? 'use_shoot' : 'scene_select';

class UsageDao {
  UsageDao(this._db);
  final Database _db;

  /// 记录一条事件（未同步标记）。返回 false 表示应用层不应再入库（如自定义项）。
  Future<void> enqueueEvent({
    required String clientEventId,
    required UsageItemType itemType,
    required String itemId,
    required String itemSource,
    required UsageEventType eventType,
    required int occurredAt,
  }) async {
    await _db.insert(Tables.usageEvents, {
      Tables.colClientEventId: clientEventId,
      Tables.colItemType: itemType.name,
      Tables.colItemId: itemId,
      Tables.colItemSource: itemSource,
      Tables.colEventType: eventTypeName(eventType),
      Tables.colOccurredAt: occurredAt,
      Tables.colSynced: 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Map<String, Object?>>> getUnsyncedEvents() async {
    return _db.query(Tables.usageEvents, where: '${Tables.colSynced} = ?', whereArgs: [0]);
  }

  Future<void> markSynced(List<String> clientEventIds) async {
    if (clientEventIds.isEmpty) return;
    final idList = clientEventIds.map((e) => "'$e'").join(',');
    await _db.rawUpdate('UPDATE ${Tables.usageEvents} SET ${Tables.colSynced} = 1 WHERE ${Tables.colClientEventId} IN ($idList)');
  }

  Future<void> setStats(List<({String itemType, String itemId, String eventType, int count})> stats) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _db.batch();
    for (final s in stats) {
      batch.insert(Tables.usageStats, {
        Tables.colItemType: s.itemType,
        Tables.colItemId: s.itemId,
        Tables.colEventType: s.eventType,
        Tables.colCount: s.count,
        Tables.colUpdatedAt: now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// 取某个 item 的全部事件次数（远程优先，本地兜底）。
  Future<int> countFor(String itemId, String itemType, String eventType) async {
    final rows = await _db.query(Tables.usageStats,
      where: '${Tables.colItemId} = ? AND ${Tables.colItemType} = ? AND ${Tables.colEventType} = ?',
      whereArgs: [itemId, itemType, eventType], limit: 1);
    if (rows.isNotEmpty) return (rows.first[Tables.colCount] as num).toInt();
    return 0;
  }
}
```
> Dart 2.19.6 支持 record 语法编辑型 `({String itemType, ...})` 属 Dart 3。为兼容，改用类：
```dart
class UsageStat {
  UsageStat(this.itemType, this.itemId, this.eventType, this.count);
  final String itemType; final String itemId; final String eventType; final int count;
}
// setStats 改为 List<UsageStat>
```

- [ ] **Step 4: 注册 daoProvider**

`database_provider.dart` 顶部 `import 'dao/usage_dao.dart';` 并追加 provider：
```dart
final usageDaoProvider = FutureProvider<UsageDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return UsageDao(db);
});
```

- [ ] **Step 5: 测试 + analyze**

Run: `cd lumira_app_flutter && flutter analyze lib/core/db/dao/usage_dao.dart`
Expected: 无分析错误（record/类改法正确）。

- [ ] **Step 6: Commit**

```bash
cd d:/app/projects/photo_post
git add lumira_app_flutter/lib/core/db
git commit -m "feat(flutter): 本地 usage_events/usage_stats 表与 UsageDao"
```

---

### Task 6: Flutter UsageEventRecorder + 埋点

**Files:**
- Create: `lumira_app_flutter/lib/features/usage/usage_event_recorder.dart`
- Create: `lumira_app_flutter/lib/features/usage/usage_providers.dart`
- Modify: `lumira_app_flutter/lib/features/templates/pages/templates_detail_page.dart`
- Modify: `lumira_app_flutter/lib/features/scenes/pages/scenes_search_page.dart` / 场景选择面板落点
- Modify: 拍摄保存成片处（含 templateId/sceneId 的地方，如 capture 保存 service）

**Interfaces:**
- Consumes: `UsageDao`；`UsageEventRecorder.record(...)`。
- Produces: `usageEventRecorderProvider`；三处埋点调用。

- [ ] **Step 1: recorder 与 provider**

```dart
// lib/features/usage/usage_event_recorder.dart
import 'dart:math';
import '../../../core/db/dao/usage_dao.dart';

/// 记录模板/场景使用事件。仅内置/后台模板与系统内置场景写入，用户自定义跳过。
class UsageEventRecorder {
  UsageEventRecorder(this._dao);
  final UsageDao _dao;

  Future<void> recordTemplate({
    required String templateId,
    required String source, // 'builtin' | 'remote' | 'custom'
    required UsageEventType event,
  }) async {
    if (source != 'builtin' && source != 'remote') return; // 用户自定义不记录
    await _dao.enqueueEvent(
      clientEventId: _uuid(),
      itemType: UsageItemType.template,
      itemId: templateId,
      itemSource: source,
      eventType: event,
      occurredAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> recordScene({
    required String sceneId,
    required String creator, // 'system' | 'user'
    required UsageEventType event,
  }) async {
    if (creator != 'system') return; // 仅系统内置场景记录
    await _dao.enqueueEvent(
      clientEventId: _uuid(),
      itemType: UsageItemType.scene,
      itemId: sceneId,
      itemSource: 'system',
      eventType: event,
      occurredAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static String _uuid() {
    final r = Random();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    // RFC4122 v4
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0,8)}-${hex.substring(8,12)}-${hex.substring(12,16)}-${hex.substring(16,20)}-${hex.substring(20)}';
  }
}
```
```dart
// lib/features/usage/usage_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/database_provider.dart';
import 'usage_event_recorder.dart';

final usageEventRecorderProvider = FutureProvider<UsageEventRecorder>((ref) async {
  final dao = await ref.watch(usageDaoProvider.future);
  return UsageEventRecorder(dao);
});
```

- [ ] **Step 2: 埋点 - 模板详情页打开**

在 `templates_detail_page.dart` 的 `initState`（或首次加载其模板后）调用：
```dart
Future<void> _reportOpen() async {
  final rec = await ref.read(usageEventRecorderProvider.future);
  await rec.recordTemplate(templateId: <templateId 变量>, source: <source 变量>, event: UsageEventType.openDetail);
}
```
> 在能拿到 `template.source`（`builtin/custom/remote`）与 `id` 的地方调用；若详情页没有 source，从 `TemplatesDao`/`remote` 路由类型判断。跨页面路由统一改为在详情载荷构建点上报。

- [ ] **Step 3: 埋点 - 场景详情打开 与 场景选择**

- 场景详情页/`capture_scene_manage_page` 打开时：`recordScene(sceneId, creator: s.creator, event: UsageEventType.openDetail)`
- 场景选择面板（`scene_preset_strip.dart` 或选择回调）：用户选定预设时：`recordScene(sceneId, creator: 'system'/* 仅系统 */, event: UsageEventType.sceneSelect)`

- [ ] **Step 4: 埋点 - 拍摄保存**

在保存成片、写 gallery 的位置（含 `templateId`/`sceneId`）：若模板 `source ∈ {builtin,remote}` → `recordTemplate(..., useShoot)`；若场景 `creator==system` → `recordScene(..., useShoot)`。保存成功后调用 `UsageSyncService` 触发同步（见 Task 7）。

- [ ] **Step 5: analyze + 关键单测（recordTemplate 跳过 custom）**

Run: `cd lumira_app_flutter && flutter analyze lib/features/usage`
Expected: 无分析错误。

- [ ] **Step 6: Commit**

```bash
cd d:/app/projects/photo_post
git add lumira_app_flutter/lib/features/usage lumira_app_flutter/lib/features/templates/pages/templates_detail_page.dart lumira_app_flutter/lib/features/scenes lumira_app_flutter/lib/features/capture
git commit -m "feat(flutter): 模板/场景使用事件埋点 recorder"
```

---

### Task 7: Flutter UsageSyncService（上报 + 拉取次数）+ 全局同步

**Files:**
- Create: `lumira_app_flutter/lib/features/usage/usage_sync_service.dart`
- Create: `lumira_app_flutter/lib/features/usage/usage_stats_provider.dart`
- Modify: `lumira_app_flutter/lib/features/usage/usage_sync_service.dart`（含 provider）或统一在 `usage_providers.dart` 补充

**Interfaces:**
- Consumes: `UsageDao`, 客户端 API client（`POST /usage/events`, `GET /usage/stats`）。
- Produces: `runSyncExposure(force: false)` 幂等同步；`usageStatsProvider`（各 item 次数）供推荐/搜索读取。

- [ ] **Step 1: API 客户端复用确认**

查看现有远程调用（如 questionnaire/profile 同步、remote templates）的 client 封装，确认 baseUrl 与鉴权（`Authorization: Bearer <token>`）。`UsageSyncService` 复用同一 `ApiClient`/`http` 封装发起请求。

- [ ] **Step 2: 实现 UsageSyncService**

```dart
// lib/features/usage/usage_sync_service.dart
import 'dart:convert';
import '../../../core/db/dao/usage_dao.dart';
import '../../../core/config/app_config.dart';
// http 依赖按项目既有 client 调整（非 dev，改用注入的 client）

class UsageSyncService {
  UsageSyncService(this._dao);
  final UsageDao _dao;

  /// 上报未同步事件 + 拉取次数。返回 false 表示离线/失败。
  Future<bool> runSync() async {
    try {
      final unsynced = await _dao.getUnsyncedEvents();
      if (unsynced.isNotEmpty) {
        final events = unsynced.map((r) => {
          'clientEventId': r['client_event_id'] as String,
          'itemType': r['item_type'] as String,
          'itemId': r['item_id'] as String,
          'itemSource': r['item_source'] as String,
          'eventType': r['event_type'] as String,
          'occurredAt': r['occurred_at'] as int,
        }).toList();
        final pushed = await _post('/api/v1/usage/events', {'events': events});
        if (pushed) {
          await _dao.markSynced(events.map((e) => e['clientEventId']! as String).toList());
        }
      }
      // 拉取模板 + 场景次数
      await _pullStats('template');
      await _pullStats('scene');
      return true;
    } catch (_) {
      return false; // 离线/弱网，静默失败，下次再同步
    }
  }

  Future<bool> _post(String path, Map body) async {
    // 复用项目 ApiClient，POST json，带 auth；成功返回 true
  }
  Future<void> _pullStats(String itemType) async {
    final res = await _get('/api/v1/usage/stats?itemType=$itemType');
    if (res == null) return;
    final items = res['items'] as List<dynamic>;
    final stats = <UsageStat>[];
    for (final it in items) {
      final itemId = it['itemId'] as String;
      stats.add(UsageStat(itemType, itemId, 'use_shoot', (it['useShoot'] ?? 0) as int));
      stats.add(UsageStat(itemType, itemId, 'open_detail', (it['openDetail'] ?? 0) as int));
      stats.add(UsageStat(itemType, itemId, 'scene_select', (it['sceneSelect'] ?? 0) as int));
    }
    await _dao.setStats(stats);
  }
  Future<Map<String, dynamic>?> _get(String path) async { /* 复用 client GET */ }
}
```
> `_post/_get` 需要接入项目已有的 `ApiClient`（读取 `AppConfig.baseUrl`，注入 Bearer token）。实现时对齐既有 remote service 的写法，不要新造 http 依赖。

- [ ] **Step 3: provider 与触发**

- `usage_sync_provider.dart` 暴露 `usageSyncServiceProvider`；`usageStatsProvider`（从 `UsageDao.countFor` 封装查询，供推荐/搜索读取）。
- 触发点：拍摄保存成功后（Task 6 Step 4 处）调用 `await ref.read(usageSyncServiceProvider.future).then((s) => s.runSync());`（fire-and-forget）；App 启动时在主壳 `initState` 里触发一次。

- [ ] **Step 4: analyze + 单测（runSync 上报成功则 markSynced、离线返回 false）**

Run: `cd lumira_app_flutter && flutter analyze lib/features/usage`
Expected: 无分析错误；单测通过。

- [ ] **Step 5: Commit**

```bash
cd d:/app/projects/photo_post
git add lumira_app_flutter/lib/features/usage
git commit -m "feat(flutter): UsageSyncService 上报未同步事件并拉取全站次数"
```

---

### Task 8: 推荐/Banner/搜索排序 叠加远程次数增强

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/services/recommendation_service.dart`
- Modify: `lumira_app_flutter/lib/features/templates/recommend/recommendation_engine.dart`
- Modify: `lumira_app_flutter/lib/features/scenes/pages/scenes_search_page.dart`
- Modify: `lumira_app_flutter/lib/features/home/providers/banner_recommendation_provider.dart`

**Interfaces:**
- Consumes: `UsageDao.countFor`（远程优先、本地兜底）。
- Produces: 推荐/搜索/Banner 结果并入流行度排序；离线 `α=0` 不降级。

- [ ] **Step 1: 抽取 score_pop 计算工具**

`lib/features/usage/usage_popularity.dart`：
```dart
import '../../../core/db/dao/usage_dao.dart';
/// 归一化流行度分：use_shoot 权重最高。
Future<double> popularityScore(
  UsageDao dao, {
  required String itemType,
  required double useW, openW, selectW,
}) async {
  final useShoot = await dao.countFor(itemTypeId, itemType, 'use_shoot');
  final open = await dao.countFor(itemTypeId, itemType, 'open_detail');
  final select = await dao.countFor(itemTypeId, itemType, 'scene_select');
  // 全局最大用缓存/查询；先用本 item 归一化不可靠，改用“max over all items”。
  ...
}
```
> 简单先期实现：直接用次数本身参与排序（冷启动无次数=0），不做严格归一化。做法：对候选集 `items` 按 `score = w_use*use + w_open*open + w_select*select` 排序，并在与本地分合并时用 `α` 加权。实现时在引擎内读 `UsageDao.countFor`。

- [ ] **Step 2: template recommendation_engine 增强**

在模板推荐引擎打分入口处：读候选模板 id 的 `use_shoot/open_detail` 次数，计算 `score_pop`；若远程/本地次数合计 > 0 则 `α=0.3`（否则 0），`finalNote = score_local*(1-α)+score_pop*α`。保持原返回结构与默认排序。

- [ ] **Step 3: banner_recommendation_provider 增强**

`buildBanners()` 在候选挑选时，把对应模板/场景的 `use_shoot/open_detail` 次数作为额外排序因子（辅助 slots 选品），不改变 5 槽位结构。

- [ ] **Step 4: scenes_search_page 排序增强**

结果排序：若 `usage_stats` 有该场景次数，则 `score = use_shoot*0.55 + open_detail*0.25 + scene_select*0.20`（远程优先，回退 0）；`_keywordHits().sort(...)` 用此分降序。保留用户标签 AND 过滤逻辑。

- [ ] **Step 5: analyze + 测试**

Run: `cd lumira_app_flutter && flutter analyze`
Expected: 无分析错误；既有推荐/搜索单测仍通过（离线 α=0 不改变行为）。

- [ ] **Step 6: Commit**

```bash
cd d:/app/projects/photo_post
git add lumira_app_flutter/lib/features/home lumira_app_flutter/lib/features/templates/recommend lumira_app_flutter/lib/features/scenes lumira_app_flutter/lib/features/usage
git commit -m "feat(flutter): 推荐/Banner/搜索排序并入全站使用次数流行度"
```

---

### Task 9: 场景元数据后端同步（App 端 syncSystemScenes）

**Files:**
- Modify: `lumira_app_flutter/lib/core/db/dao/scenes_dao.dart`
- Create: `lumira_app_flutter/lib/features/scenes/scenes_sync_service.dart`
- Modify: `lumira_app_flutter/lib/features/scenes/pages/scenes_page.dart`（或触发点）

**Interfaces:**
- Consumes: `GET /api/v1/scenes`；`ScenesDao.upsert`。
- Produces: `ScenesDao.syncSystemScenes(List<...>)`；首启联网后覆盖本地系统场景缓存。

- [ ] **Step 1: ScenesDao 增加 syncSystemScenes**

```dart
/// 用后端系统场景列表覆盖本地系统场景（creator=system）。
/// 用户自定义场景不受影响。
Future<void> syncSystemScenes(List<Map<String, Object?>> scenes) async {
  final batch = _db.batch();
  for (final s in scenes) {
    batch.insert(Tables.scenes, s, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  await batch.commit(noResult: true);
}
```
> `scenes` 行的 key 需对齐 `SceneRecord.toRow()` 的列名（description/exampleImages/vibe 等，由 sync service 映射）。

- [ ] **Step 2: ScenesSyncService**

```dart
// lib/features/scenes/scenes_sync_service.dart
class ScenesSyncService {
  ScenesSyncService(this._dao, this._usageDao);
  final ScenesDao _dao; final UsageDao _usageDao;

  Future<bool> syncSystem() async {
    final remote = await GET('/api/v1/scenes'); // 复用 ApiClient
    if (remote == null) return false; // 离线
    final rows = <Map<String, Object?>>[];
    for (final s in remote['scenes'] as List<dynamic>) {
      final scene = s as Map<String, dynamic>;
      final now = DateTime.now().millisecondsSinceEpoch;
      final u = scene['usage'] as Map<String, dynamic>? ?? {};
      rows.add({
        Tables.colId: scene['id'] as String,
        Tables.colName: scene['name'] as String,
        Tables.colIcon: scene['icon'] ?? '',
        Tables.colCategory: scene['category'] as String,
        Tables.colStyle: scene['style'] ?? '',
        Tables.colFilterJson: jsonEncode(scene['filter'] ?? {}),
        Tables.colVibe: scene['vibe'] ?? '',
        Tables.colDescription: scene['description'] ?? '',
        Tables.colExampleImagesJson: jsonEncode(scene['exampleImages'] ?? []),
        Tables.colTipsJson: jsonEncode(scene['tips'] ?? []),
        Tables.colWhereToShoot: scene['whereToShoot'] ?? '',
        Tables.colBestTime: scene['bestTime'] ?? '',
        Tables.colRelatedCategory: scene['relatedCategory'] ?? '',
        Tables.colRecommendedTagIdsJson: jsonEncode(scene['recommendedTagIds'] ?? []),
        Tables.colTagIdsJson: jsonEncode(scene['recommendedTagIds'] ?? []),
        Tables.colCreator: 'system',
        Tables.colIsFavorite: 0,
        Tables.colCreatedAt: now,
        Tables.colUpdatedAt: scene['updatedAt'] ?? now,
      });
      // 场景次数写入 usage_stats
      final stats = <UsageStat>[
        UsageStat('scene', scene['id'] as String, 'use_shoot', (u['useShoot'] as num?)?.toInt() ?? 0),
        UsageStat('scene', scene['id'] as String, 'open_detail', (u['openDetail'] as num?)?.toInt() ?? 0),
        UsageStat('scene', scene['id'] as String, 'scene_select', (u['sceneSelect'] as num?)?.toInt() ?? 0),
      ];
      await _usageDao.setStats(stats);
    }
    await _dao.syncSystemScenes(rows);
    return true;
  }
}
```

- [ ] **Step 3: 触发与兜底校验**

- 场景页/首页加载时联网触发 `syncSystem()`；本地始终用 mock 种子兜底（冷启动白屏防护已在现有 seed 逻辑）。
- 校验：后端 `system_scenes` 有数据时，App 场景列表首次联网后被后端元数据覆盖；断网/无缓存时仍显示本地种子。

- [ ] **Step 4: analyze + 测试**

Run: `cd lumira_app_flutter && flutter analyze lib/features/scenes lib/core/db/dao/scenes_dao.dart`
Expected: 无分析错误。

- [ ] **Step 5: Commit + push（全后端/后台改动到双远端）**

```bash
cd d:/app/projects/photo_post
git add lumira_app_flutter/lib/features/scenes lumira_app_flutter/lib/core/db/dao/scenes_dao.dart
git commit -m "feat(flutter): 场景元数据后端同步 syncSystemScenes"
# 按 AGENTS.md：涉及后端/后台改动需 push 到 origin 与 github
git push origin master && git push github master
```

---

## 自检

**Spec 覆盖对照**
- 「记录所有用户使用模板/场景次数」→ Task 2/6；「内置+后台模板记录、自定义不记录」→ Task 6 Step 2 recorder 的 source/creator 过滤
- 「推荐算法」→ Task 8（score_pop + α 权重）
- 「banners 栏」→ Task 8 Step 3
- 「搜索页推荐信息/搜索结果排序」→ Task 8 Step 4（scenes_search_page）+ 模板搜索称
- 「场景只统计系统内置、后台管理」→ Task 3（admin scenes CRUD）+ Task 9
- 「离线可用不降级」→ Task 7/8/9 的 α=0 与本地兜底

**说明**：潜力最大值归一化（`maxCount`）在计划中以「候选集内排序」的轻量方式落地，避免过度设计；后续出现"过气热门"再引入时间衰减与严格归一化。

**执行提示**：Task 2 的 usage.module 需 `exports: [UsageService]`；Task 3 的 scenes.module imports UsageModule。所有 `_post/_get` 必须复用项目既有 `ApiClient`（勿新增 http 依赖）。Flutter record 语法（`({...})`）须替换为类（Dart 2.19.6 不支持 Dart 3）。