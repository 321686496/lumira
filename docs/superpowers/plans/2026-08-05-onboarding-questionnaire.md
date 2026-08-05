# 新用户问卷页 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为新用户添加 7 题偏好问卷页（Flutter 多步向导），数据落本地 sqflite + 上报 NestJS 后端，影响首页推荐 slot 1，并在 admin 后台提供查看页。

**Architecture:** 方案 A（双端独立表）：Flutter 端 sqflite 新建 `questionnaire` 单行表（v11→v12 迁移），离线优先；后端 Drizzle 新建 `questionnaire_records` 表（每次提交 insert 保留历史）；RecommendationService slot 1 读取本地问卷偏好替换"新手友好场景" banner；admin Next.js 增加列表/详情/统计 3 个页面。

**Tech Stack:**
- Flutter 3.7.12 / Dart 2.19.6（**不支持 Dart 3 records 语法**）
- flutter_riverpod 2.3.6 + sqflite + dio + go_router 6.5.7
- NestJS + Fastify + Drizzle ORM + better-sqlite3 + class-validator
- Next.js (App Router) + Tailwind + shadcn/ui + phosphor-icons

## Global Constraints

- **Dart 版本**：Flutter 3.7.12 / Dart 2.19.6，禁止使用 Dart 3 records 语法（如 `(int, String)` 记录类型）
- **离线优先**：Flutter 端所有业务数据本地 sqflite 落库，推荐联动不依赖网络
- **后端响应格式**：成功直接返回业务对象，错误统一 `{code, message}`
- **DTO 严格模式**：`forbidNonWhitelisted: true`，DTO 必须显式声明所有字段
- **国际化**：项目无 i18n 框架，中文文案硬编码
- **uni-app 项目已废弃**：仅作原型参考，本次改动不涉及 `lumira-app/` 目录
- **数据库迁移**：后端沿用"只跑 001_init.sql"模式，新表 DDL 追加到该文件末尾；Flutter 端走 v11→v12 迁移
- **样式风格**：warmWhite + neumorphic，NeuCard + LumiraButton + FadeUp，选项选中态用 `brandSubtle` 背景 + `brand` 边框
- **分类 key 一致性**：模板分类字符串用连字符 `'still-life'`（与现有 `recommendation_service.dart` 第 36 行一致），**不是**下划线
- **后端模块注册**：`app.module.ts` 实际还注册了 `WeatherModule`（探索报告未提及），新增 `QuestionnaireModule` 时保留现有导入
- **ApiClient 调用模式**：Flutter 端 `ApiClient.post<T>` 要求传 `fromJson` 回调，不能直接返回 response.data
- **Admin 路由**：admin 控制器全部加 `@UseGuards(AdminAuthGuard)` 类级守卫，新增方法无需再加方法级守卫
- **后端时间戳**：全部用秒级 `Math.floor(Date.now() / 1000)`

---

## File Structure

### Flutter 端（`lumira_app_flutter/`）

| 操作 | 文件 | 职责 |
|---|---|---|
| 新增 | `lib/features/onboarding/data/questionnaire_data.dart` | 题目与选项静态定义（中文文案集中） |
| 新增 | `lib/features/onboarding/data/questionnaire_answers.dart` | Dart 不可变模型 `QuestionnaireAnswers` |
| 新增 | `lib/features/onboarding/data/questionnaire_dao.dart` | sqflite DAO |
| 新增 | `lib/features/onboarding/data/questionnaire_providers.dart` | Riverpod providers |
| 新增 | `lib/features/onboarding/services/questionnaire_sync_service.dart` | 上报后端 |
| 新增 | `lib/features/onboarding/pages/questionnaire_page.dart` | 多步向导主页面 |
| 新增 | `lib/features/onboarding/pages/widgets/question_step.dart` | 单题步骤通用骨架 |
| 新增 | `lib/features/onboarding/pages/widgets/progress_indicator.dart` | 顶部进度条 |
| 修改 | `lib/core/router/route_names.dart` | 加 `onboarding` 常量 |
| 修改 | `lib/app/router.dart` | 加 GoRoute |
| 修改 | `lib/core/db/tables.dart` | 加 questionnaire 表/列常量 |
| 修改 | `lib/core/db/database_provider.dart` | v11→v12 迁移 + DAO provider |
| 修改 | `lib/features/splash/pages/splash_page.dart` | 新设备分流 |
| 修改 | `lib/features/profile/pages/profile_settings_page.dart` | 加入口 |
| 修改 | `lib/features/home/services/recommendation_service.dart` | slot 1 联动 |
| 修改 | `lib/features/home/providers/banner_recommendation_provider.dart` | 注入 questionnaireDao |

### 后端（`lumira-server/packages/backend/`）

| 操作 | 文件 | 职责 |
|---|---|---|
| 新增 | `src/modules/questionnaire/questionnaire.module.ts` | 模块定义 |
| 新增 | `src/modules/questionnaire/questionnaire.controller.ts` | 设备端提交接口 |
| 新增 | `src/modules/questionnaire/questionnaire.service.ts` | 业务逻辑 |
| 新增 | `src/modules/questionnaire/dto/submit-questionnaire.dto.ts` | DTO 校验 |
| 修改 | `src/database/schema.ts` | 加 `questionnaireRecords` 表 |
| 修改 | `src/database/migrations/001_init.sql` | 追加 CREATE TABLE |
| 修改 | `src/modules/admin/admin.controller.ts` | 3 个 admin 接口 |
| 修改 | `src/modules/admin/admin.service.ts` | 问卷查询/统计方法 |
| 修改 | `src/app.module.ts` | 注册 QuestionnaireModule |

### 共享类型（`lumira-server/packages/shared/`）

| 操作 | 文件 | 职责 |
|---|---|---|
| 新增 | `src/types/questionnaire.ts` | TS 类型定义 |
| 修改 | `src/index.ts` | 导出 questionnaire 类型 |

### Admin 前端（`lumira-server/packages/admin/`）

| 操作 | 文件 | 职责 |
|---|---|---|
| 新增 | `src/app/dashboard/questionnaire/page.tsx` | 列表页 |
| 新增 | `src/app/dashboard/questionnaire/[deviceId]/page.tsx` | 单设备历史详情 |
| 新增 | `src/app/dashboard/questionnaire/stats/page.tsx` | 统计面板 |
| 新增 | `src/components/questionnaire-table.tsx` | 列表表格组件 |
| 修改 | `src/components/sidebar.tsx` | 加导航项 |
| 修改 | `src/components/dashboard-shell.tsx` | 加 titleMap 条目 |
| 修改 | `src/lib/api.ts` | 加 questionnaire 方法 |
| 修改 | `src/types/admin.ts` | 加类型 |

---

## Task 1: 共享类型（shared/types/questionnaire.ts）

**Files:**
- Create: `lumira-server/packages/shared/src/types/questionnaire.ts`
- Modify: `lumira-server/packages/shared/src/index.ts`

**Interfaces:**
- Produces: `QuestionId`, `QuestionnaireAnswers`, `SubmitQuestionnaireRequest`, `SubmitQuestionnaireResponse`, `QuestionnaireRecord`, `QuestionnaireListResponse`, `QuestionnaireStats`

- [ ] **Step 1: 创建 questionnaire 类型文件**

Create `lumira-server/packages/shared/src/types/questionnaire.ts`:

```ts
export type QuestionId =
  | 'source' | 'favorite_categories' | 'pain_points' | 'skill_level'
  | 'expectations' | 'common_scenes' | 'shoot_frequency';

export interface QuestionnaireAnswers {
  source: string | null;
  favorite_categories: string[];
  pain_points: string[];
  skill_level: string | null;
  expectations: string[];
  common_scenes: string[];
  shoot_frequency: string | null;
}

export interface SubmitQuestionnaireRequest {
  answers: QuestionnaireAnswers;
  submittedAt: number;
}

export interface SubmitQuestionnaireResponse {
  success: boolean;
  receivedAt: number;
}

export interface QuestionnaireRecord {
  id: number;
  deviceId: string;
  answersJson: string;
  submittedAt: number;
  clientIp: string | null;
}

export interface QuestionnaireListItem extends QuestionnaireRecord {
  deviceAlias: string | null;
}

export interface QuestionnaireListResponse {
  data: QuestionnaireListItem[];
  total: number;
  page: number;
  pageSize: number;
}

export interface QuestionnaireHistoryResponse {
  data: QuestionnaireRecord[];
  total: number;
}

export interface QuestionnaireStats {
  totalRespondents: number;
  source: Record<string, number>;
  favorite_categories: Record<string, number>;
  pain_points: Record<string, number>;
  skill_level: Record<string, number>;
  expectations: Record<string, number>;
  common_scenes: Record<string, number>;
  shoot_frequency: Record<string, number>;
}
```

> 注：为与现有 admin 接口风格一致（`InviteListResponse.data` 而非 `items`），列表响应用 `data` 字段名。

- [ ] **Step 2: 在 shared/index.ts 导出**

Modify `lumira-server/packages/shared/src/index.ts`，在末尾追加一行：

```ts
export * from './types/device';
export * from './types/invite';
export * from './types/redeem';
export * from './types/rewards';
export * from './types/questionnaire';
```

- [ ] **Step 3: 验证类型编译**

Run: `cd lumira-server && pnpm --filter @lumira/shared build`
Expected: 编译成功无错误

- [ ] **Step 4: Commit**

```bash
git add lumira-server/packages/shared/src/types/questionnaire.ts lumira-server/packages/shared/src/index.ts
git commit -m "feat(shared): add questionnaire types"
```

---

## Task 2: 后端数据库 schema + 迁移

**Files:**
- Modify: `lumira-server/packages/backend/src/database/schema.ts`
- Modify: `lumira-server/packages/backend/src/database/migrations/001_init.sql`

**Interfaces:**
- Consumes: 无
- Produces: `questionnaireRecords` Drizzle 表定义（供 Task 3/4 使用）

- [ ] **Step 1: 在 schema.ts 追加 questionnaireRecords 表**

Modify `lumira-server/packages/backend/src/database/schema.ts`，在文件末尾追加：

```ts
export const questionnaireRecords = sqliteTable('questionnaire_records', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  deviceId: text('device_id').notNull(),
  answersJson: text('answers_json').notNull(),
  submittedAt: integer('submitted_at').notNull(),
  clientIp: text('client_ip'),
});
```

- [ ] **Step 2: 在 001_init.sql 末尾追加 CREATE TABLE**

Modify `lumira-server/packages/backend/src/database/migrations/001_init.sql`，在文件末尾追加：

```sql

CREATE TABLE IF NOT EXISTS questionnaire_records (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id     TEXT NOT NULL,
  answers_json  TEXT NOT NULL,
  submitted_at  INTEGER NOT NULL,
  client_ip     TEXT
);
CREATE INDEX IF NOT EXISTS idx_questionnaire_records_device ON questionnaire_records(device_id);
CREATE INDEX IF NOT EXISTS idx_questionnaire_records_submitted ON questionnaire_records(submitted_at DESC);
```

- [ ] **Step 3: 验证 schema 编译**

Run: `cd lumira-server && pnpm --filter @lumira/backend run build`
Expected: 编译成功

- [ ] **Step 4: Commit**

```bash
git add lumira-server/packages/backend/src/database/schema.ts lumira-server/packages/backend/src/database/migrations/001_init.sql
git commit -m "feat(db): add questionnaire_records table"
```

---

## Task 3: 后端 questionnaire 模块（设备端提交接口）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/questionnaire/dto/submit-questionnaire.dto.ts`
- Create: `lumira-server/packages/backend/src/modules/questionnaire/questionnaire.service.ts`
- Create: `lumira-server/packages/backend/src/modules/questionnaire/questionnaire.controller.ts`
- Create: `lumira-server/packages/backend/src/modules/questionnaire/questionnaire.module.ts`
- Modify: `lumira-server/packages/backend/src/app.module.ts`

**Interfaces:**
- Consumes: `questionnaireRecords` from schema, `DatabaseService`, `DeviceAuthGuard`, `DeviceId`, `ClientIp`
- Produces: `POST /api/v1/questionnaire/submit` 接口

- [ ] **Step 1: 创建 DTO**

Create `lumira-server/packages/backend/src/modules/questionnaire/dto/submit-questionnaire.dto.ts`:

```ts
import {
  IsString, IsOptional, IsIn, IsArray, ArrayUnique,
  IsInt, Min, ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class QuestionnaireAnswersDto {
  @IsOptional()
  @IsString()
  @IsIn(['app_store', 'social_media', 'friend', 'search', 'article', 'other'])
  source?: string | null;

  @IsArray()
  @ArrayUnique()
  @IsString({ each: true })
  @IsIn(
    ['portrait', 'landscape', 'food', 'street', 'night', 'macro', 'still-life'],
    { each: true },
  )
  favorite_categories: string[] = [];

  @IsArray()
  @ArrayUnique()
  @IsString({ each: true })
  @IsIn(
    ['composition', 'lighting', 'posing', 'camera_settings', 'post_processing', 'no_subject', 'no_time'],
    { each: true },
  )
  pain_points: string[] = [];

  @IsOptional()
  @IsString()
  @IsIn(['beginner', 'intermediate', 'advanced', 'pro'])
  skill_level?: string | null;

  @IsArray()
  @ArrayUnique()
  @IsString({ each: true })
  @IsIn(
    ['learn_photo', 'inspiration', 'better_composition', 'master_camera', 'share_works', 'record_life'],
    { each: true },
  )
  expectations: string[] = [];

  @IsArray()
  @ArrayUnique()
  @IsString({ each: true })
  @IsIn(
    ['indoor_home', 'cafe', 'outdoor_park', 'street', 'travel', 'office', 'studio'],
    { each: true },
  )
  common_scenes: string[] = [];

  @IsOptional()
  @IsString()
  @IsIn(['rarely', 'monthly', 'weekly', 'daily'])
  shoot_frequency?: string | null;
}

export class SubmitQuestionnaireDto {
  @ValidateNested()
  @Type(() => QuestionnaireAnswersDto)
  answers!: QuestionnaireAnswersDto;

  @IsInt()
  @Min(0)
  submittedAt!: number;
}
```

- [ ] **Step 2: 创建 service**

Create `lumira-server/packages/backend/src/modules/questionnaire/questionnaire.service.ts`:

```ts
import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { questionnaireRecords } from '../../database/schema';
import { SubmitQuestionnaireDto } from './dto/submit-questionnaire.dto';

@Injectable()
export class QuestionnaireService {
  constructor(private readonly dbService: DatabaseService) {}

  async submit(deviceId: string, dto: SubmitQuestionnaireDto, ip: string) {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);
    await db.insert(questionnaireRecords).values({
      deviceId,
      answersJson: JSON.stringify(dto.answers),
      submittedAt: dto.submittedAt,
      clientIp: ip,
    });
    return { success: true, receivedAt: now };
  }
}
```

- [ ] **Step 3: 创建 controller**

Create `lumira-server/packages/backend/src/modules/questionnaire/questionnaire.controller.ts`:

```ts
import { Controller, Post, Body, UseGuards } from '@nestjs/common';
import { QuestionnaireService } from './questionnaire.service';
import { SubmitQuestionnaireDto } from './dto/submit-questionnaire.dto';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { DeviceId, ClientIp } from '../../common/decorators';

@Controller('questionnaire')
@UseGuards(DeviceAuthGuard)
export class QuestionnaireController {
  constructor(private readonly questionnaireService: QuestionnaireService) {}

  @Post('submit')
  async submit(
    @DeviceId() deviceId: string,
    @Body() dto: SubmitQuestionnaireDto,
    @ClientIp() ip: string,
  ) {
    return this.questionnaireService.submit(deviceId, dto, ip);
  }
}
```

- [ ] **Step 4: 创建 module**

Create `lumira-server/packages/backend/src/modules/questionnaire/questionnaire.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../../database/database.module';
import { QuestionnaireController } from './questionnaire.controller';
import { QuestionnaireService } from './questionnaire.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({
      secret: process.env.JWT_SECRET || 'dev-secret-change-me',
      signOptions: { expiresIn: '30d' },
    }),
  ],
  controllers: [QuestionnaireController],
  providers: [QuestionnaireService],
  exports: [QuestionnaireService],
})
export class QuestionnaireModule {}
```

- [ ] **Step 5: 注册到 AppModule**

Modify `lumira-server/packages/backend/src/app.module.ts`，在 imports 数组中增加 `QuestionnaireModule`：

```ts
import { Module } from '@nestjs/common';
import { APP_FILTER, APP_PIPE } from '@nestjs/core';
import { DatabaseModule } from './database/database.module';
import { DeviceModule } from './modules/device/device.module';
import { InviteModule } from './modules/invite/invite.module';
import { RedeemModule } from './modules/redeem/redeem.module';
import { RewardsModule } from './modules/rewards/rewards.module';
import { AdminModule } from './modules/admin/admin.module';
import { WeatherModule } from './modules/weather/weather.module';
import { QuestionnaireModule } from './modules/questionnaire/questionnaire.module';
import { HealthController } from './health.controller';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { GlobalValidationPipe } from './common/pipes/global-validation.pipe';

@Module({
  imports: [DatabaseModule, DeviceModule, InviteModule, RedeemModule, RewardsModule, AdminModule, WeatherModule, QuestionnaireModule],
  controllers: [HealthController],
  providers: [
    { provide: APP_FILTER, useClass: HttpExceptionFilter },
    { provide: APP_PIPE, useValue: GlobalValidationPipe },
  ],
})
export class AppModule {}
```

- [ ] **Step 6: 验证编译**

Run: `cd lumira-server && pnpm --filter @lumira/backend run build`
Expected: 编译成功

- [ ] **Step 7: 手动测试接口**

启动后端：`cd lumira-server && pnpm --filter @lumira/backend run start:dev`

获取 token（先注册设备）：
```bash
curl -X POST http://localhost:3000/api/v1/device/register -H "Content-Type: application/json" -d '{"deviceId":"test-questionnaire-001"}'
```
记下返回的 token。

提交问卷：
```bash
curl -X POST http://localhost:3000/api/v1/questionnaire/submit \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"answers":{"source":"friend","favorite_categories":["portrait","food"],"pain_points":["composition"],"skill_level":"beginner","expectations":["learn_photo"],"common_scenes":["cafe"],"shoot_frequency":"weekly"},"submittedAt":1700000000}'
```
Expected: `{"success":true,"receivedAt":<秒级时间戳>}`

- [ ] **Step 8: Commit**

```bash
git add lumira-server/packages/backend/src/modules/questionnaire/ lumira-server/packages/backend/src/app.module.ts
git commit -m "feat(backend): add questionnaire submit endpoint"
```

---

## Task 4: 后端 admin 问卷查询接口

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/admin/admin.controller.ts`
- Modify: `lumira-server/packages/backend/src/modules/admin/admin.service.ts`

**Interfaces:**
- Consumes: `questionnaireRecords`, `devices` from schema
- Produces: `GET /admin/questionnaire`, `GET /admin/questionnaire/:deviceId`, `GET /admin/questionnaire/stats`

- [ ] **Step 1: 在 admin.service.ts 增加问卷查询方法**

Modify `lumira-server/packages/backend/src/modules/admin/admin.service.ts`，在文件顶部 import 区追加：

```ts
import { eq, count, desc, sql } from 'drizzle-orm';
import {
  devices,
  inviteRecords,
  rewardUnlocks,
  redemptionCodeBatches,
  redemptionCodes,
  redemptionRecords,
  questionnaireRecords,
} from '../../database/schema';
```

> 注：原文件已有部分 import，这里只追加 `questionnaireRecords` 和 `sql`。

然后在 `AdminService` 类末尾（最后一个方法后）追加 3 个方法：

```ts
  // 问卷列表（每设备最新一条）
  async getQuestionnaireList(page: number = 1, pageSize: number = 20, deviceId?: string) {
    const db = this.dbService.getDb();

    // 子查询：每设备最新一条记录的 id
    const latestSubquery = db
      .select({
        id: sql<number>`MAX(${questionnaireRecords.id})`.as('max_id'),
      })
      .from(questionnaireRecords)
      .groupBy(questionnaireRecords.deviceId)
      .as('latest');

    const offset = (page - 1) * pageSize;

    // 主查询：JOIN devices 取 alias，JOIN 子查询取每设备最新
    const rows = await db
      .select({
        id: questionnaireRecords.id,
        deviceId: questionnaireRecords.deviceId,
        answersJson: questionnaireRecords.answersJson,
        submittedAt: questionnaireRecords.submittedAt,
        clientIp: questionnaireRecords.clientIp,
        deviceAlias: devices.alias,
      })
      .from(questionnaireRecords)
      .innerJoin(latest, eq(questionnaireRecords.id, latest.id))
      .leftJoin(devices, eq(questionnaireRecords.deviceId, devices.deviceId))
      .where(deviceId ? eq(questionnaireRecords.deviceId, deviceId) : undefined)
      .orderBy(desc(questionnaireRecords.submittedAt))
      .limit(pageSize)
      .offset(offset);

    const totalCount = deviceId
      ? await db.select({ value: count() }).from(questionnaireRecords).where(eq(questionnaireRecords.deviceId, deviceId))
      : await db.select({ value: sql<number>`COUNT(DISTINCT ${questionnaireRecords.deviceId})` }).from(questionnaireRecords);

    return {
      data: rows,
      total: totalCount[0]?.value || 0,
      page,
      pageSize,
    };
  }

  // 单设备问卷历史
  async getQuestionnaireHistory(deviceId: string) {
    const db = this.dbService.getDb();
    const rows = await db
      .select()
      .from(questionnaireRecords)
      .where(eq(questionnaireRecords.deviceId, deviceId))
      .orderBy(desc(questionnaireRecords.submittedAt));

    return {
      data: rows,
      total: rows.length,
    };
  }

  // 问卷聚合统计（基于每设备最新一条）
  async getQuestionnaireStats() {
    const db = this.dbService.getDb();

    const latestSubquery = db
      .select({
        id: sql<number>`MAX(${questionnaireRecords.id})`.as('max_id'),
      })
      .from(questionnaireRecords)
      .groupBy(questionnaireRecords.deviceId)
      .as('latest');

    const rows = await db
      .select({
        answersJson: questionnaireRecords.answersJson,
      })
      .from(questionnaireRecords)
      .innerJoin(latest, eq(questionnaireRecords.id, latest.id));

    const stats = {
      totalRespondents: rows.length,
      source: {} as Record<string, number>,
      favorite_categories: {} as Record<string, number>,
      pain_points: {} as Record<string, number>,
      skill_level: {} as Record<string, number>,
      expectations: {} as Record<string, number>,
      common_scenes: {} as Record<string, number>,
      shoot_frequency: {} as Record<string, number>,
    };

    for (const row of rows) {
      try {
        const answers = JSON.parse(row.answersJson) as Record<string, unknown>;
        for (const [key, value] of Object.entries(answers)) {
          if (!stats.hasOwnProperty(key)) continue;
          if (value === null) continue;
          if (Array.isArray(value)) {
            for (const v of value as string[]) {
              stats[key as keyof typeof stats][v] = (stats[key as keyof typeof stats][v] || 0) + 1;
            }
          } else {
            const v = value as string;
            stats[key as keyof typeof stats][v] = (stats[key as keyof typeof stats][v] || 0) + 1;
          }
        }
      } catch {
        // 跳过无法解析的记录
      }
    }

    return stats;
  }
```

- [ ] **Step 2: 在 admin.controller.ts 增加 3 个路由**

Modify `lumira-server/packages/backend/src/modules/admin/admin.controller.ts`，在类末尾（最后一个方法 `getRewardUnlocks` 后）追加：

```ts
  @Get('questionnaire')
  async getQuestionnaireList(
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
    @Query('deviceId') deviceId?: string,
  ) {
    return this.adminService.getQuestionnaireList(
      page ? parseInt(page) : 1,
      pageSize ? parseInt(pageSize) : 20,
      deviceId,
    );
  }

  @Get('questionnaire/stats')
  async getQuestionnaireStats() {
    return this.adminService.getQuestionnaireStats();
  }

  @Get('questionnaire/:deviceId')
  async getQuestionnaireHistory(@Param('deviceId') deviceId: string) {
    return this.adminService.getQuestionnaireHistory(deviceId);
  }
```

> 注：`questionnaire/stats` 必须放在 `questionnaire/:deviceId` 之前，否则 `stats` 会被当作 `:deviceId` 参数匹配。

- [ ] **Step 3: 验证编译**

Run: `cd lumira-server && pnpm --filter @lumira/backend run build`
Expected: 编译成功

- [ ] **Step 4: 手动测试 admin 接口**

启动后端，使用 admin token（环境变量 `ADMIN_TOKEN`）测试：

```bash
# 列表
curl http://localhost:3000/api/v1/admin/questionnaire -H "Authorization: Bearer <ADMIN_TOKEN>"
# 统计
curl http://localhost:3000/api/v1/admin/questionnaire/stats -H "Authorization: Bearer <ADMIN_TOKEN>"
# 单设备历史
curl http://localhost:3000/api/v1/admin/questionnaire/test-questionnaire-001 -H "Authorization: Bearer <ADMIN_TOKEN>"
```
Expected: 列表返回 `{data:[...], total, page, pageSize}`；统计返回 `{totalRespondents, source, ...}`；历史返回 `{data:[...], total}`

- [ ] **Step 5: Commit**

```bash
git add lumira-server/packages/backend/src/modules/admin/admin.controller.ts lumira-server/packages/backend/src/modules/admin/admin.service.ts
git commit -m "feat(admin): add questionnaire query endpoints"
```

---

## Task 5: Flutter 端 tables.dart + DB 迁移 v11→v12

**Files:**
- Modify: `lumira_app_flutter/lib/core/db/tables.dart`
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart`

**Interfaces:**
- Consumes: 现有 `_kDbVersion = 11` + `_onUpgrade` 迁移模式
- Produces: `questionnaire` 表常量 + v12 迁移逻辑（供 Task 6/7 使用）

- [ ] **Step 1: 在 tables.dart 增加 questionnaire 表常量**

Modify `lumira_app_flutter/lib/core/db/tables.dart`，在 `collection_photos` 段之后（class `Tables` 闭合 `}` 之前）追加：

```dart
  // === questionnaire 表（v12 迁移新增，单行表 id=1） ===
  static const String questionnaire = 'questionnaire';
  static const String colAnswersJson = 'answers_json';
  static const String colSubmittedAt = 'submitted_at';
  static const String colSyncedAt = 'synced_at';
```

- [ ] **Step 2: 在 database_provider.dart 升级版本号**

Modify `lumira_app_flutter/lib/core/db/database_provider.dart` 第 19 行：

```dart
const int _kDbVersion = 12;
```

- [ ] **Step 3: 在 _onUpgrade 增加 v12 迁移块**

在 `database_provider.dart` 的 `_onUpgrade` 函数末尾（`if (oldVersion < 11) {...}` 块之后）追加：

```dart
  if (oldVersion < 12) {
    try {
      // v12: 新增 questionnaire 表（新用户偏好问卷）
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${Tables.questionnaire} (
          ${Tables.colId} INTEGER PRIMARY KEY DEFAULT 1,
          ${Tables.colAnswersJson} TEXT NOT NULL DEFAULT '{}',
          ${Tables.colSubmittedAt} INTEGER,
          ${Tables.colSyncedAt} INTEGER
        )
      ''');
    } catch (e) {
      debugPrint('v12 migration failed (silent fallback): $e');
    }
  }
```

- [ ] **Step 4: 在 _onCreate 也增加 questionnaire 表创建（fresh install）**

在 `_onCreate` 函数中，`// === 种子化预置数据` 注释之前（约第 280 行）追加：

```dart
  // === v12: questionnaire 表 ===
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.questionnaire} (
      ${Tables.colId} INTEGER PRIMARY KEY DEFAULT 1,
      ${Tables.colAnswersJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colSubmittedAt} INTEGER,
      ${Tables.colSyncedAt} INTEGER
    )
  ''');
```

- [ ] **Step 5: 验证编译**

Run: `cd lumira_app_flutter && flutter analyze lib/core/db/`
Expected: 无错误

- [ ] **Step 6: Commit**

```bash
git add lumira_app_flutter/lib/core/db/tables.dart lumira_app_flutter/lib/core/db/database_provider.dart
git commit -m "feat(db): add questionnaire table v12 migration"
```

---

## Task 6: Flutter 端 questionnaire 数据模型 + DAO + providers

**Files:**
- Create: `lumira_app_flutter/lib/features/onboarding/data/questionnaire_answers.dart`
- Create: `lumira_app_flutter/lib/features/onboarding/data/questionnaire_data.dart`
- Create: `lumira_app_flutter/lib/features/onboarding/data/questionnaire_dao.dart`
- Create: `lumira_app_flutter/lib/features/onboarding/data/questionnaire_providers.dart`
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart`

**Interfaces:**
- Consumes: `Tables.questionnaire` 等常量, `databaseProvider`
- Produces: `QuestionnaireAnswers` 模型, `QuestionnaireDao`, `questionnaireDaoProvider`

- [ ] **Step 1: 创建 QuestionnaireAnswers 模型**

Create `lumira_app_flutter/lib/features/onboarding/data/questionnaire_answers.dart`:

```dart
import 'dart:convert';

/// 问卷答案不可变模型
///
/// 字段名与后端 JSON key 一致（snake_case），便于直接序列化。
/// 单选题跳过为 null，多选题跳过为空数组。
class QuestionnaireAnswers {
  final String? source;
  final List<String> favoriteCategories;
  final List<String> painPoints;
  final String? skillLevel;
  final List<String> expectations;
  final List<String> commonScenes;
  final String? shootFrequency;

  const QuestionnaireAnswers({
    this.source,
    required this.favoriteCategories,
    required this.painPoints,
    this.skillLevel,
    required this.expectations,
    required this.commonScenes,
    this.shootFrequency,
  });

  /// 全空答案（整体跳过时使用）
  factory QuestionnaireAnswers.empty() => const QuestionnaireAnswers(
        source: null,
        favoriteCategories: [],
        painPoints: [],
        skillLevel: null,
        expectations: [],
        commonScenes: [],
        shootFrequency: null,
      );

  factory QuestionnaireAnswers.fromJson(Map<String, dynamic> json) {
    return QuestionnaireAnswers(
      source: json['source'] as String?,
      favoriteCategories:
          (json['favorite_categories'] as List<dynamic>?)?.cast<String>() ?? [],
      painPoints: (json['pain_points'] as List<dynamic>?)?.cast<String>() ?? [],
      skillLevel: json['skill_level'] as String?,
      expectations:
          (json['expectations'] as List<dynamic>?)?.cast<String>() ?? [],
      commonScenes:
          (json['common_scenes'] as List<dynamic>?)?.cast<String>() ?? [],
      shootFrequency: json['shoot_frequency'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'source': source,
        'favorite_categories': favoriteCategories,
        'pain_points': painPoints,
        'skill_level': skillLevel,
        'expectations': expectations,
        'common_scenes': commonScenes,
        'shoot_frequency': shootFrequency,
      };

  String toJsonString() => jsonEncode(toJson());

  /// 是否完全未填写（所有题都跳过）
  bool get isAllSkipped =>
      source == null &&
      favoriteCategories.isEmpty &&
      painPoints.isEmpty &&
      skillLevel == null &&
      expectations.isEmpty &&
      commonScenes.isEmpty &&
      shootFrequency == null;
}
```

- [ ] **Step 2: 创建 questionnaire_data.dart 题目定义**

Create `lumira_app_flutter/lib/features/onboarding/data/questionnaire_data.dart`:

```dart
/// 问卷题型
enum QuestionType { single, multi }

/// 问卷选项
class QuestionOption {
  final String key;
  final String label;
  const QuestionOption(this.key, this.label);
}

/// 问卷题目定义
class QuestionDef {
  final String id;
  final String title;
  final String? subtitle;
  final QuestionType type;
  final List<QuestionOption> options;

  const QuestionDef({
    required this.id,
    required this.title,
    this.subtitle,
    required this.type,
    required this.options,
  });
}

/// 7 道问卷题目（文案集中此文件，便于未来抽 i18n）
const List<QuestionDef> kQuestionnaireQuestions = [
  QuestionDef(
    id: 'source',
    title: '你从哪里知道 Lumira？',
    type: QuestionType.single,
    options: [
      QuestionOption('app_store', '应用商店'),
      QuestionOption('social_media', '社交媒体'),
      QuestionOption('friend', '朋友推荐'),
      QuestionOption('search', '搜索引擎'),
      QuestionOption('article', '文章博客'),
      QuestionOption('other', '其他'),
    ],
  ),
  QuestionDef(
    id: 'favorite_categories',
    title: '你喜欢拍什么？',
    subtitle: '可多选',
    type: QuestionType.multi,
    options: [
      QuestionOption('portrait', '人像'),
      QuestionOption('landscape', '风光'),
      QuestionOption('food', '美食'),
      QuestionOption('street', '街拍'),
      QuestionOption('night', '夜景'),
      QuestionOption('macro', '微距'),
      QuestionOption('still-life', '静物'),
    ],
  ),
  QuestionDef(
    id: 'pain_points',
    title: '拍摄中你有哪些烦恼？',
    subtitle: '可多选',
    type: QuestionType.multi,
    options: [
      QuestionOption('composition', '构图困难'),
      QuestionOption('lighting', '光线处理'),
      QuestionOption('posing', '摆姿不自然'),
      QuestionOption('camera_settings', '参数设置'),
      QuestionOption('post_processing', '后期修图'),
      QuestionOption('no_subject', '找不到拍摄对象'),
      QuestionOption('no_time', '没时间拍'),
    ],
  ),
  QuestionDef(
    id: 'skill_level',
    title: '你的摄影水平？',
    type: QuestionType.single,
    options: [
      QuestionOption('beginner', '新手'),
      QuestionOption('intermediate', '进阶'),
      QuestionOption('advanced', '高级'),
      QuestionOption('pro', '专业'),
    ],
  ),
  QuestionDef(
    id: 'expectations',
    title: '你希望从 Lumira 获得？',
    subtitle: '可多选',
    type: QuestionType.multi,
    options: [
      QuestionOption('learn_photo', '学摄影'),
      QuestionOption('inspiration', '找灵感'),
      QuestionOption('better_composition', '提升构图'),
      QuestionOption('master_camera', '玩转相机'),
      QuestionOption('share_works', '分享作品'),
      QuestionOption('record_life', '记录生活'),
    ],
  ),
  QuestionDef(
    id: 'common_scenes',
    title: '你常在哪些场景拍摄？',
    subtitle: '可多选',
    type: QuestionType.multi,
    options: [
      QuestionOption('indoor_home', '家中'),
      QuestionOption('cafe', '咖啡馆'),
      QuestionOption('outdoor_park', '户外公园'),
      QuestionOption('street', '街头'),
      QuestionOption('travel', '旅行'),
      QuestionOption('office', '办公室'),
      QuestionOption('studio', '影棚'),
    ],
  ),
  QuestionDef(
    id: 'shoot_frequency',
    title: '你的拍摄频率？',
    type: QuestionType.single,
    options: [
      QuestionOption('rarely', '偶尔'),
      QuestionOption('monthly', '每月'),
      QuestionOption('weekly', '每周'),
      QuestionOption('daily', '每天'),
    ],
  ),
];
```

- [ ] **Step 3: 创建 QuestionnaireDao**

Create `lumira_app_flutter/lib/features/onboarding/data/questionnaire_dao.dart`:

```dart
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/db/tables.dart';
import 'questionnaire_answers.dart';

/// 问卷 DAO（单行表 questionnaire，id=1）
class QuestionnaireDao {
  QuestionnaireDao(this._db);

  final Database _db;

  /// 读取答案（未填过返回 null）
  Future<QuestionnaireAnswers?> getAnswers() async {
    final rows = await _db.query(
      Tables.questionnaire,
      where: '${Tables.colId} = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return null;
    final raw = rows.first[Tables.colAnswersJson] as String?;
    if (raw == null || raw.isEmpty || raw == '{}') return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return QuestionnaireAnswers.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// 写入答案（重填覆盖）
  Future<void> upsert(QuestionnaireAnswers answers, int submittedAt) async {
    await _db.insert(
      Tables.questionnaire,
      {
        Tables.colId: 1,
        Tables.colAnswersJson: answers.toJsonString(),
        Tables.colSubmittedAt: submittedAt,
        Tables.colSyncedAt: null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 标记已同步
  Future<void> markSynced(int syncedAt) async {
    await _db.update(
      Tables.questionnaire,
      {Tables.colSyncedAt: syncedAt},
      where: '${Tables.colId} = ?',
      whereArgs: [1],
    );
  }

  /// 是否已填过问卷
  Future<bool> isCompleted() async {
    final rows = await _db.query(
      Tables.questionnaire,
      columns: [Tables.colSubmittedAt],
      where: '${Tables.colId} = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return false;
    return rows.first[Tables.colSubmittedAt] != null;
  }

  /// 是否有未同步的提交
  Future<bool> hasUnsynced() async {
    final rows = await _db.query(
      Tables.questionnaire,
      columns: [Tables.colSubmittedAt, Tables.colSyncedAt],
      where: '${Tables.colId} = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return false;
    final submitted = rows.first[Tables.colSubmittedAt];
    final synced = rows.first[Tables.colSyncedAt];
    return submitted != null && synced == null;
  }
}
```

- [ ] **Step 4: 在 database_provider.dart 增加 questionnaireDaoProvider**

Modify `lumira_app_flutter/lib/core/db/database_provider.dart`，在顶部 import 区追加：

```dart
import '../../features/onboarding/data/questionnaire_dao.dart';
```

然后在 `settingsDaoProvider` 之后追加：

```dart
final questionnaireDaoProvider = FutureProvider<QuestionnaireDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return QuestionnaireDao(db);
});
```

- [ ] **Step 5: 创建 questionnaire_providers.dart**

Create `lumira_app_flutter/lib/features/onboarding/data/questionnaire_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import 'questionnaire_answers.dart';
import 'questionnaire_dao.dart';

export 'questionnaire_answers.dart';
export 'questionnaire_data.dart';

/// 问卷答案 Provider（读取本地最新答案）
final questionnaireAnswersProvider =
    FutureProvider<QuestionnaireAnswers?>((ref) async {
  final dao = await ref.watch(questionnaireDaoProvider.future);
  return dao.getAnswers();
});

/// 是否已填过问卷
final questionnaireCompletedProvider = FutureProvider<bool>((ref) async {
  final dao = await ref.watch(questionnaireDaoProvider.future);
  return dao.isCompleted();
});
```

- [ ] **Step 6: 验证编译**

Run: `cd lumira_app_flutter && flutter analyze lib/features/onboarding/ lib/core/db/`
Expected: 无错误

- [ ] **Step 7: Commit**

```bash
git add lumira_app_flutter/lib/features/onboarding/data/ lumira_app_flutter/lib/core/db/database_provider.dart
git commit -m "feat(onboarding): add questionnaire model, dao, providers"
```

---

## Task 7: Flutter 端 sync service（上报后端）

**Files:**
- Create: `lumira_app_flutter/lib/features/onboarding/services/questionnaire_sync_service.dart`
- Create: `lumira_app_flutter/lib/features/onboarding/services/questionnaire_sync_providers.dart`

**Interfaces:**
- Consumes: `QuestionnaireDao`, `ApiClient`, `QuestionnaireAnswers`
- Produces: `QuestionnaireSyncService.submit()`, `questionnaireSyncServiceProvider`

- [ ] **Step 1: 创建 sync service**

Create `lumira_app_flutter/lib/features/onboarding/services/questionnaire_sync_service.dart`:

```dart
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../data/questionnaire_answers.dart';
import '../data/questionnaire_dao.dart';

/// 问卷提交结果
class SubmitResult {
  final bool success;
  final String? error;
  const SubmitResult({required this.success, this.error});
}

/// 问卷同步服务
///
/// 离线优先：先落本地 sqflite，再上报后端；网络失败不阻塞，标记未同步。
class QuestionnaireSyncService {
  QuestionnaireSyncService({
    required QuestionnaireDao dao,
    required ApiClient apiClient,
  })  : _dao = dao,
        _apiClient = apiClient;

  final QuestionnaireDao _dao;
  final ApiClient _apiClient;

  /// 提交问卷答案
  ///
  /// 1. 本地落库（立即生效，推荐可用）
  /// 2. 上报后端（失败不阻塞，标记未同步）
  Future<SubmitResult> submit(QuestionnaireAnswers answers) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // 1. 本地落库
    await _dao.upsert(answers, now);

    // 2. 上报后端
    try {
      await _apiClient.post(
        '/questionnaire/submit',
        body: {
          'answers': answers.toJson(),
          'submittedAt': now,
        },
        fromJson: (json) => json,
      );
      await _dao.markSynced(now);
      return const SubmitResult(success: true);
    } on ApiException catch (e) {
      return SubmitResult(success: false, error: e.message);
    } catch (e) {
      return SubmitResult(success: false, error: e.toString());
    }
  }

  /// 补传未同步的提交（App 启动时调用）
  ///
  /// 最小实现：只重试一次，失败则等下次启动。
  Future<void> syncPendingIfNeeded() async {
    final hasUnsynced = await _dao.hasUnsynced();
    if (!hasUnsynced) return;

    final answers = await _dao.getAnswers();
    if (answers == null) return;

    try {
      await _apiClient.post(
        '/questionnaire/submit',
        body: {
          'answers': answers.toJson(),
          'submittedAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        },
        fromJson: (json) => json,
      );
      await _dao.markSynced(DateTime.now().millisecondsSinceEpoch ~/ 1000);
    } catch (_) {
      // 静默失败，下次启动再试
    }
  }
}
```

- [ ] **Step 2: 创建 sync providers**

Create `lumira_app_flutter/lib/features/onboarding/services/questionnaire_sync_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/network/api_client.dart';
import 'questionnaire_sync_service.dart';

final questionnaireSyncServiceProvider =
    FutureProvider<QuestionnaireSyncService>((ref) async {
  final dao = await ref.watch(questionnaireDaoProvider.future);
  final apiClient = await ref.watch(apiClientProvider.future);
  return QuestionnaireSyncService(dao: dao, apiClient: apiClient);
});
```

- [ ] **Step 3: 验证编译**

Run: `cd lumira_app_flutter && flutter analyze lib/features/onboarding/`
Expected: 无错误

- [ ] **Step 4: Commit**

```bash
git add lumira_app_flutter/lib/features/onboarding/services/
git commit -m "feat(onboarding): add questionnaire sync service"
```

---

## Task 8: Flutter 端路由 + 触发分流

**Files:**
- Modify: `lumira_app_flutter/lib/core/router/route_names.dart`
- Modify: `lumira_app_flutter/lib/app/router.dart`
- Modify: `lumira_app_flutter/lib/features/splash/pages/splash_page.dart`

**Interfaces:**
- Consumes: `questionnaireDaoProvider`, `AuthState.isNewDevice`
- Produces: `/onboarding` 路由，新设备首次注册后分流

- [ ] **Step 1: 在 route_names.dart 增加 onboarding 常量**

Modify `lumira_app_flutter/lib/core/router/route_names.dart`，在 `splash` 常量之后追加：

```dart
  static const String onboarding = '/onboarding';
```

并在参数键名区追加：

```dart
  static const String paramFrom = 'from';
```

- [ ] **Step 2: 在 router.dart 增加 GoRoute**

Modify `lumira_app_flutter/lib/app/router.dart`，在顶部 import 区追加：

```dart
import '../features/onboarding/pages/questionnaire_page.dart';
```

在 splash 路由之后追加 onboarding 路由：

```dart
      GoRoute(
        path: RouteNames.onboarding,
        name: 'onboarding',
        builder: (context, state) => QuestionnairePage(
          fromSettings: state.queryParams[RouteNames.paramFrom] == 'settings',
        ),
      ),
```

> 注：`QuestionnairePage` 将在 Task 9 创建。本任务的步骤 2 先添加 import 和路由，编译会因 `QuestionnairePage` 不存在而失败——这是预期行为，Task 9 完成后编译通过。可先跳过步骤 3 的验证，Task 9 完成后一起验证。

- [ ] **Step 3: 修改 splash_page.dart 分流逻辑**

Modify `lumira_app_flutter/lib/features/splash/pages/splash_page.dart`，在顶部 import 区追加：

```dart
import '../../../core/db/database_provider.dart';
```

修改 `_maybeNavigate` 方法（原第 65-72 行）：

```dart
  void _maybeNavigate() {
    if (_navigated || !mounted) return;
    final auth = ref.read(authControllerProvider);
    // failed 时不跳转，留在 splash 显示重试按钮
    if (auth.status == AuthStatus.failed) return;
    _navigated = true;
    // 新设备首次注册且未填问卷 → 跳问卷页；否则跳首页
    _routeAfterSplash(auth.isNewDevice);
  }

  Future<void> _routeAfterSplash(bool isNewDevice) async {
    if (isNewDevice) {
      try {
        final dao = await ref.read(questionnaireDaoProvider.future);
        final isCompleted = await dao.isCompleted();
        if (!isCompleted) {
          context.go(RouteNames.onboarding);
          return;
        }
      } catch (_) {
        // DAO 失败不阻塞，回退到 home
      }
    }
    context.go(RouteNames.home);
  }
```

- [ ] **Step 4: 暂不验证编译（等 Task 9 完成）**

> Task 8 步骤 2 引用了尚未创建的 `QuestionnairePage`，编译会失败。这是预期的，Task 9 完成后一起验证。

- [ ] **Step 5: Commit（可与 Task 9 合并提交，或先提交路由部分）**

暂不提交，等 Task 9 完成后一起提交。

---

## Task 9: Flutter 端问卷页 UI（多步向导）

**Files:**
- Create: `lumira_app_flutter/lib/features/onboarding/pages/widgets/progress_indicator.dart`
- Create: `lumira_app_flutter/lib/features/onboarding/pages/widgets/question_step.dart`
- Create: `lumira_app_flutter/lib/features/onboarding/pages/questionnaire_page.dart`

**Interfaces:**
- Consumes: `kQuestionnaireQuestions`, `QuestionnaireAnswers`, `QuestionnaireSyncService`, `RouteNames`, `LumiraNav`, `NeuCard`, `LumiraButton`, `FadeUp`, `themeTokensProvider`
- Produces: `QuestionnairePage` widget

- [ ] **Step 1: 创建进度条组件**

Create `lumira_app_flutter/lib/features/onboarding/pages/widgets/progress_indicator.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/theme_tokens.dart';

/// 问卷顶部进度条
class QuestionnaireProgress extends StatelessWidget {
  final int current;
  final int total;
  final ThemeTokens tokens;

  const QuestionnaireProgress({
    super.key,
    required this.current,
    required this.total,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (current + 1) / total;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: tokens.divider,
                valueColor: AlwaysStoppedAnimation<Color>(tokens.brand),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${current + 1}/$total',
            style: TextStyle(
              fontSize: 12,
              color: tokens.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 创建单题步骤骨架**

Create `lumira_app_flutter/lib/features/onboarding/pages/widgets/question_step.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/theme_tokens.dart';
import '../../../../shared/widgets/cards/neu_card.dart';
import '../../data/questionnaire_data.dart';

/// 单题步骤通用骨架
///
/// 渲染题目标题 + 选项列表；选项选中态用 brandSubtle 背景 + brand 边框。
/// 单选/多选的差异由 [onToggle] 调用方控制。
class QuestionStep extends StatelessWidget {
  final QuestionDef question;
  final Set<String> selectedKeys;
  final void Function(String key) onToggle;
  final ThemeTokens tokens;

  const QuestionStep({
    super.key,
    required this.question,
    required this.selectedKeys,
    required this.onToggle,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            question.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
              height: 1.3,
            ),
          ),
          if (question.subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              question.subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: tokens.textTertiary,
              ),
            ),
          ],
          const SizedBox(height: 28),
          ...question.options.map((opt) {
            final isSelected = selectedKeys.contains(opt.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => onToggle(opt.key),
                behavior: HitTestBehavior.opaque,
                child: _OptionCard(
                  label: opt.label,
                  selected: isSelected,
                  tokens: tokens,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String label;
  final bool selected;
  final ThemeTokens tokens;

  const _OptionCard({
    required this.label,
    required this.selected,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: selected ? tokens.brandSubtle : tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? tokens.brand : tokens.divider,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? tokens.brand : tokens.textPrimary,
              ),
            ),
          ),
          if (selected)
            Icon(
              PhosphorIconsRegular.checkCircle,
              size: 20,
              color: tokens.brand,
            ),
        ],
      ),
    );
  }
}
```

> 注：项目使用 `phosphor_flutter` 包，图标用 `PhosphorIconsRegular.xxx`。若项目实际用 `PhosphorIcons.xxx`，按现有代码风格调整。需先确认项目中的 phosphor 用法。

- [ ] **Step 3: 确认 phosphor 图标用法**

Run: `cd lumira_app_flutter && grep -r "PhosphorIcons" lib/ --include="*.dart" | head -5`

确认项目用的是 `PhosphorIconsRegular.checkCircle` 还是 `PhosphorIcons.checkCircle`，按结果调整 Task 9 步骤 2 的代码。

> 如果项目中已有 phosphor 用法示例，参考其写法。若项目未使用 phosphor，改用 `Icons.check_circle`。

- [ ] **Step 4: 创建 QuestionnairePage 主页面**

Create `lumira_app_flutter/lib/features/onboarding/pages/questionnaire_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../data/questionnaire_answers.dart';
import '../data/questionnaire_data.dart';
import '../services/questionnaire_sync_providers.dart';
import 'widgets/progress_indicator.dart';
import 'widgets/question_step.dart';

/// 新用户问卷页（多步向导）
///
/// 7 题分步展示，每题可跳过，整体可跳过。
/// 从 splash 进入：提交后跳 home
/// 从设置页进入：提交后 pop 返回设置页
class QuestionnairePage extends ConsumerStatefulWidget {
  final bool fromSettings;

  const QuestionnairePage({super.key, this.fromSettings = false});

  @override
  ConsumerState<QuestionnairePage> createState() => _QuestionnairePageState();
}

class _QuestionnairePageState extends ConsumerState<QuestionnairePage> {
  int _currentStep = 0;
  final Map<String, Set<String>> _answers = {
    for (final q in kQuestionnaireQuestions) q.id: <String>{}
  };
  bool _submitting = false;

  bool get _isLast => _currentStep == kQuestionnaireQuestions.length - 1;

  QuestionDef get _currentQuestion => kQuestionnaireQuestions[_currentStep];

  void _toggleOption(String key) {
    setState(() {
      final selected = _answers[_currentQuestion.id]!;
      if (_currentQuestion.type == QuestionType.single) {
        selected
          ..clear()
          ..add(key);
      } else {
        if (selected.contains(key)) {
          selected.remove(key);
        } else {
          selected.add(key);
        }
      }
    });
    // 单选题：选中后自动进入下一题（带延迟）
    if (_currentQuestion.type == QuestionType.single) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _next();
      });
    }
  }

  void _next() {
    if (_isLast) {
      _submit();
    } else {
      setState(() => _currentStep++);
    }
  }

  void _prev() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _skipAll() {
    _submit();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final answers = QuestionnaireAnswers(
      source: _answers['source']?.isEmpty == true
          ? null
          : _answers['source']?.first,
      favoriteCategories: _answers['favorite_categories']?.toList() ?? [],
      painPoints: _answers['pain_points']?.toList() ?? [],
      skillLevel: _answers['skill_level']?.isEmpty == true
          ? null
          : _answers['skill_level']?.first,
      expectations: _answers['expectations']?.toList() ?? [],
      commonScenes: _answers['common_scenes']?.toList() ?? [],
      shootFrequency: _answers['shoot_frequency']?.isEmpty == true
          ? null
          : _answers['shoot_frequency']?.first,
    );

    try {
      final syncService =
          await ref.read(questionnaireSyncServiceProvider.future);
      await syncService.submit(answers);
    } catch (_) {
      // 同步失败不阻塞跳转（本地已落库）
    }

    if (!mounted) return;
    if (widget.fromSettings) {
      context.pop();
    } else {
      context.go(RouteNames.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(appThemeProvider).tokens;

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '关于你',
        transparent: true,
        leading: TextButton(
          onPressed: _submitting ? null : _skipAll,
          child: Text(
            '跳过',
            style: TextStyle(fontSize: 14, color: tokens.textTertiary),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6),
            radius: 1.2,
            colors: [
              tokens.brandSubtle.withOpacity(0.3),
              tokens.canvas.withOpacity(0),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              QuestionnaireProgress(
                current: _currentStep,
                total: kQuestionnaireQuestions.length,
                tokens: tokens,
              ),
              Expanded(
                child: FadeUp(
                  key: ValueKey(_currentStep),
                  child: QuestionStep(
                    question: _currentQuestion,
                    selectedKeys: _answers[_currentQuestion.id]!,
                    onToggle: _toggleOption,
                    tokens: tokens,
                  ),
                ),
              ),
              _buildBottomBar(tokens),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(tokens) {
    final isMulti = _currentQuestion.type == QuestionType.multi;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _prev,
              child: Text(
                '上一题',
                style: TextStyle(fontSize: 14, color: tokens.textSecondary),
              ),
            )
          else
            const SizedBox(width: 64),
          const Spacer(),
          if (isMulti)
            LumiraButton(
              variant: ButtonVariant.primary,
              onPressed: _submitting ? null : _next,
              child: Text(_isLast ? '完成' : '下一题'),
            )
          else if (_isLast)
            LumiraButton(
              variant: ButtonVariant.primary,
              onPressed: _submitting ? null : _next,
              child: const Text('完成'),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: 验证编译**

Run: `cd lumira_app_flutter && flutter analyze lib/`
Expected: 无错误（Task 8 的路由引用现在能解析了）

- [ ] **Step 6: 手动验证 UI**

Run: `cd lumira_app_flutter && flutter run`

临时把 initialLocation 改为 `/onboarding` 测试（测完改回），或在地址栏输入路由。验证：
- 进度条显示 1/7 → 7/7
- 单选点击自动进下一题
- 多选需点"下一题"
- 左上角"跳过"直接完成
- 完成后跳首页

- [ ] **Step 7: Commit**

```bash
git add lumira_app_flutter/lib/features/onboarding/pages/ lumira_app_flutter/lib/core/router/route_names.dart lumira_app_flutter/lib/app/router.dart lumira_app_flutter/lib/features/splash/pages/splash_page.dart
git commit -m "feat(onboarding): add questionnaire wizard page with splash routing"
```

---

## Task 10: Flutter 端设置页入口

**Files:**
- Modify: `lumira_app_flutter/lib/features/profile/pages/profile_settings_page.dart`

**Interfaces:**
- Consumes: `questionnaireCompletedProvider`, `RouteNames.onboarding`
- Produces: 设置页"偏好问卷"入口项

- [ ] **Step 1: 在 profile_settings_page.dart 顶部增加 import**

```dart
import '../../../features/onboarding/data/questionnaire_providers.dart';
```

- [ ] **Step 2: 在"通用"分组增加问卷入口**

在 profile_settings_page.dart 的"通用"分组 `NeuCard` 内，"语言"项之后增加"偏好问卷"项。

找到现有的"语言" `_SettingItem`（约第 198-204 行），将其 `isLast: true` 去掉，并在其后追加新的 `_SettingItem`：

```dart
                      _SettingItem(
                        icon: Icons.assignment_outlined,
                        label: '偏好问卷',
                        value: questionnaireCompleted ? '已填' : '未填',
                        onTap: () => GoRouter.of(context)
                            .push('${RouteNames.onboarding}?from=settings'),
                        tokens: tokens,
                        isLast: true,
                      ),
```

> 注：`questionnaireCompleted` 变量需要在 build 方法中从 provider 读取，见步骤 3。

- [ ] **Step 3: 在 build 方法读取问卷完成状态**

在 `ProfileSettingsPage` 的 build 方法中（读取 `themeLabel`、`styleLabel` 附近），增加：

```dart
    final questionnaireCompleted =
        ref.watch(questionnaireCompletedProvider).valueOrNull ?? false;
```

> 注：`valueOrNull` 在 riverpod 2.x 可用。若项目版本不支持，用 `ref.watch(questionnaireCompletedProvider).when(data: (v) => v, loading: () => false, error: (_, __) => false)`。

- [ ] **Step 4: 确认 route_names 已导入**

确保 profile_settings_page.dart 顶部已有：
```dart
import '../../../core/router/route_names.dart';
```
若没有则追加。

- [ ] **Step 5: 验证编译**

Run: `cd lumira_app_flutter && flutter analyze lib/features/profile/`
Expected: 无错误

- [ ] **Step 6: 手动验证**

Run app，进入设置页，确认"通用"分组下出现"偏好问卷 未填"，点击进入问卷页，填完返回显示"已填"。

- [ ] **Step 7: Commit**

```bash
git add lumira_app_flutter/lib/features/profile/pages/profile_settings_page.dart
git commit -m "feat(profile): add questionnaire entry in settings"
```

---

## Task 11: Flutter 端推荐联动（slot 1）

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/services/recommendation_service.dart`
- Modify: `lumira_app_flutter/lib/features/home/providers/banner_recommendation_provider.dart`

**Interfaces:**
- Consumes: `QuestionnaireDao`, `QuestionnaireAnswers.favoriteCategories`
- Produces: slot 1 根据问卷偏好替换 newUserGuide banner

- [ ] **Step 1: 修改 RecommendationService 构造函数注入 QuestionnaireDao**

Modify `lumira_app_flutter/lib/features/home/services/recommendation_service.dart`，在顶部 import 区追加：

```dart
import '../../onboarding/data/questionnaire_dao.dart';
```

修改 `RecommendationService` 类的构造函数和字段（约第 60-77 行）：

```dart
class RecommendationService {
  RecommendationService({
    required GalleryDao galleryDao,
    required ScenesDao scenesDao,
    required TemplatesDao templatesDao,
    required CompositionKitsDao kitsDao,
    required GrowthDao growthDao,
    required QuestionnaireDao questionnaireDao,
  })  : _galleryDao = galleryDao,
        _scenesDao = scenesDao,
        _templatesDao = templatesDao,
        _kitsDao = kitsDao,
        _growthDao = growthDao,
        _questionnaireDao = questionnaireDao;

  final GalleryDao _galleryDao;
  final ScenesDao _scenesDao;
  final TemplatesDao _templatesDao;
  final CompositionKitsDao _kitsDao;
  final GrowthDao _growthDao;
  final QuestionnaireDao _questionnaireDao;
```

- [ ] **Step 2: 修改 slot 1 逻辑**

在 `buildBanners` 方法中，替换原 slot 1 块（约第 104-116 行）：

原代码：
```dart
    // === 槽位 1：新老用户分层 ===
    if (isNewUser) {
      banners.add(const HomeBannerItem(
        id: 'banner_new_user_guide',
        title: '新手友好场景',
        subtitle: '从咖啡馆开始你的拍摄之旅',
        imageSeed: 'banner-new-user-cafe',
        tag: '新手友好',
        route: '/capture/scene-guide?scene=preset_cafe',
      ));
      usedSceneIds.add('preset_cafe');
    }
```

替换为：
```dart
    // === 槽位 1：新老用户分层 ===
    if (isNewUser) {
      // 优先读问卷偏好，推用户首选分类的推荐模板
      final questionnaire = await _questionnaireDao.getAnswers();
      final favCats = questionnaire?.favoriteCategories ?? [];
      HomeBannerItem? questionnaireBanner;
      if (favCats.isNotEmpty) {
        final topCat = favCats.first;
        final tpls = await _templatesDao.getBuiltin(
          category: topCat,
          isRecommended: true,
        );
        if (tpls.isNotEmpty) {
          final tpl = tpls.first;
          usedTemplateIds.add(tpl.id);
          usedCategories.add(topCat);
          final label = _categoryLabelMap[topCat] ?? '推荐';
          questionnaireBanner = HomeBannerItem(
            id: 'banner_questionnaire_pick',
            title: '从$label开始',
            subtitle: '根据你的偏好推荐',
            imageSeed: 'banner-questionnaire-$topCat',
            tag: '为你推荐',
            route: '/templates/detail?templateId=${tpl.id}',
          );
        }
      }
      banners.add(questionnaireBanner ??
          const HomeBannerItem(
            id: 'banner_new_user_guide',
            title: '新手友好场景',
            subtitle: '从咖啡馆开始你的拍摄之旅',
            imageSeed: 'banner-new-user-cafe',
            tag: '新手友好',
            route: '/capture/scene-guide?scene=preset_cafe',
          ));
      if (questionnaireBanner == null) {
        usedSceneIds.add('preset_cafe');
      }
    }
```

- [ ] **Step 3: 修改 banner_recommendation_provider.dart 注入 questionnaireDao**

Modify `lumira_app_flutter/lib/features/home/providers/banner_recommendation_provider.dart`，在顶部 import 区追加：

```dart
import '../../../core/db/database_provider.dart';
```

修改 provider 构造（约第 15-21 行）：

```dart
  final service = RecommendationService(
    galleryDao: await ref.watch(galleryDaoProvider.future),
    scenesDao: await ref.watch(scenesDaoProvider.future),
    templatesDao: await ref.watch(templatesDaoProvider.future),
    kitsDao: await ref.watch(compositionKitsDaoProvider.future),
    growthDao: await ref.watch(growthDaoProvider.future),
    questionnaireDao: await ref.watch(questionnaireDaoProvider.future),
  );
```

- [ ] **Step 4: 验证编译**

Run: `cd lumira_app_flutter && flutter analyze lib/features/home/`
Expected: 无错误

- [ ] **Step 5: 手动验证**

1. 先填问卷，选择"人像"作为偏好
2. 删除 gallery 所有照片（确保 isNewUser = totalPhotos < 3）
3. 重启 app，进首页
4. 确认 banner 1 显示"从人像开始"而非"新手友好场景"

- [ ] **Step 6: Commit**

```bash
git add lumira_app_flutter/lib/features/home/services/recommendation_service.dart lumira_app_flutter/lib/features/home/providers/banner_recommendation_provider.dart
git commit -m "feat(home): use questionnaire preference for slot 1 banner"
```

---

## Task 12: Flutter 端启动时补传未同步问卷

**Files:**
- Modify: `lumira_app_flutter/lib/main.dart`

**Interfaces:**
- Consumes: `questionnaireSyncServiceProvider`
- Produces: App 启动时调用 `syncPendingIfNeeded()`

- [ ] **Step 1: 查看 main.dart 当前结构**

Read `lumira_app_flutter/lib/main.dart` 找到 `main()` 函数和 `UncontrolledProviderScope` 初始化位置。

- [ ] **Step 2: 在 app 启动后触发补传**

在 main.dart 中 `runApp` 调用之后，或在 `SplashPage` 的 `initState` 中（推荐后者，因为 splash 已有 ref）增加补传逻辑。

推荐方式：在 `splash_page.dart` 的 `initState` 中，`ref.listenManual` 之后追加：

```dart
    // 启动时补传未同步的问卷（fire-and-forget）
    ref.read(questionnaireSyncServiceProvider.future).then((service) {
      service.syncPendingIfNeeded();
    }).catchError((_) {});
```

并在 splash_page.dart 顶部追加 import：

```dart
import '../../features/onboarding/services/questionnaire_sync_providers.dart';
```

- [ ] **Step 3: 验证编译**

Run: `cd lumira_app_flutter && flutter analyze lib/features/splash/`
Expected: 无错误

- [ ] **Step 4: Commit**

```bash
git add lumira_app_flutter/lib/features/splash/pages/splash_page.dart
git commit -m "feat(splash): sync pending questionnaire on startup"
```

---

## Task 13: Admin 前端 - 类型 + API 方法

**Files:**
- Modify: `lumira-server/packages/admin/src/types/admin.ts`
- Modify: `lumira-server/packages/admin/src/lib/api.ts`

**Interfaces:**
- Consumes: `@lumira/shared` 的问卷类型
- Produces: admin 端 `QuestionnaireListResponse`, `QuestionnaireHistoryResponse`, `QuestionnaireStats` 类型 + api 方法

- [ ] **Step 1: 在 admin types 追加问卷类型**

Modify `lumira-server/packages/admin/src/types/admin.ts`，在文件末尾追加：

```ts
// 问卷数据类型（与 @lumira/shared 一致，admin 端单独定义避免跨包依赖）
export interface QuestionnaireRecord {
  id: number;
  deviceId: string;
  answersJson: string;
  submittedAt: number;
  clientIp: string | null;
}

export interface QuestionnaireListItem extends QuestionnaireRecord {
  deviceAlias: string | null;
}

export interface QuestionnaireListResponse {
  data: QuestionnaireListItem[];
  total: number;
  page: number;
  pageSize: number;
}

export interface QuestionnaireHistoryResponse {
  data: QuestionnaireRecord[];
  total: number;
}

export interface QuestionnaireStats {
  totalRespondents: number;
  source: Record<string, number>;
  favorite_categories: Record<string, number>;
  pain_points: Record<string, number>;
  skill_level: Record<string, number>;
  expectations: Record<string, number>;
  common_scenes: Record<string, number>;
  shoot_frequency: Record<string, number>;
}
```

- [ ] **Step 2: 在 lib/api.ts 追加 questionnaire 方法**

Modify `lumira-server/packages/admin/src/lib/api.ts`，在顶部 import 的 type 列表中追加：

```ts
import type {
  StatsResponse,
  InviteListResponse,
  Batch,
  BatchDetail,
  CreateBatchResponse,
  CreateBatchInput,
  RewardListResponse,
  QuestionnaireListResponse,
  QuestionnaireHistoryResponse,
  QuestionnaireStats,
} from '@/types/admin';
```

在 `api` 对象末尾（`getRewards` 之后）追加：

```ts
  getQuestionnaire: (params: { page?: number; pageSize?: number; deviceId?: string } = {}) => {
    const search = new URLSearchParams();
    if (params.page) search.set('page', String(params.page));
    if (params.pageSize) search.set('pageSize', String(params.pageSize));
    if (params.deviceId) search.set('deviceId', params.deviceId);
    const qs = search.toString();
    return adminFetch<QuestionnaireListResponse>(`/questionnaire${qs ? `?${qs}` : ''}`);
  },

  getQuestionnaireHistory: (deviceId: string) =>
    adminFetch<QuestionnaireHistoryResponse>(`/questionnaire/${deviceId}`),

  getQuestionnaireStats: () =>
    adminFetch<QuestionnaireStats>('/questionnaire/stats'),
```

- [ ] **Step 3: 验证编译**

Run: `cd lumira-server && pnpm --filter @lumira/admin build`
Expected: 编译成功

- [ ] **Step 4: Commit**

```bash
git add lumira-server/packages/admin/src/types/admin.ts lumira-server/packages/admin/src/lib/api.ts
git commit -m "feat(admin): add questionnaire types and api methods"
```

---

## Task 14: Admin 前端 - 侧边栏 + titleMap

**Files:**
- Modify: `lumira-server/packages/admin/src/components/sidebar.tsx`
- Modify: `lumira-server/packages/admin/src/components/dashboard-shell.tsx`

**Interfaces:**
- Consumes: 无
- Produces: 侧边栏"问卷数据"导航项 + titleMap 条目

- [ ] **Step 1: 在 sidebar.tsx 增加导航项**

Modify `lumira-server/packages/admin/src/components/sidebar.tsx`，在 import 追加 `ClipboardText`：

```ts
import { ChartLineUp, Users, Ticket, Gift, ClipboardText } from '@phosphor-icons/react/dist/ssr';
```

在 `navItems` 数组追加：

```ts
const navItems = [
  { href: '/dashboard', label: '概览', icon: ChartLineUp },
  { href: '/dashboard/invites', label: '邀请记录', icon: Users },
  { href: '/dashboard/redeem-batches', label: '兑换码', icon: Ticket },
  { href: '/dashboard/rewards', label: '奖励明细', icon: Gift },
  { href: '/dashboard/questionnaire', label: '问卷数据', icon: ClipboardText },
];
```

- [ ] **Step 2: 在 dashboard-shell.tsx 增加 titleMap**

Modify `lumira-server/packages/admin/src/components/dashboard-shell.tsx`，在 `titleMap` 追加：

```ts
const titleMap: Record<string, string> = {
  '/dashboard': '概览',
  '/dashboard/invites': '邀请记录',
  '/dashboard/redeem-batches': '兑换码批次',
  '/dashboard/rewards': '奖励明细',
  '/dashboard/questionnaire': '问卷数据',
  '/dashboard/questionnaire/stats': '问卷统计',
};
```

并在 `resolveTitle` 函数中增加动态匹配（在现有 `redeem-batches` 匹配之后）：

```ts
function resolveTitle(pathname: string): string {
  if (titleMap[pathname]) return titleMap[pathname];
  if (pathname === '/dashboard/redeem-batches/new') return '创建批次';
  if (pathname.match(/\/dashboard\/redeem-batches\/\d+/)) return '批次详情';
  if (pathname.match(/\/dashboard\/questionnaire\/[^/]+$/)) return '设备问卷历史';
  return 'Lumira 运营后台';
}
```

- [ ] **Step 3: 验证编译**

Run: `cd lumira-server && pnpm --filter @lumira/admin build`
Expected: 编译成功

- [ ] **Step 4: Commit**

```bash
git add lumira-server/packages/admin/src/components/sidebar.tsx lumira-server/packages/admin/src/components/dashboard-shell.tsx
git commit -m "feat(admin): add questionnaire nav item"
```

---

## Task 15: Admin 前端 - 问卷表格组件 + 列表页

**Files:**
- Create: `lumira-server/packages/admin/src/components/questionnaire-table.tsx`
- Create: `lumira-server/packages/admin/src/app/dashboard/questionnaire/page.tsx`

**Interfaces:**
- Consumes: `api.getQuestionnaire`, `QuestionnaireListResponse`, `Pagination`, `truncateDeviceId`, `formatUnixTime`
- Produces: `/dashboard/questionnaire` 列表页

- [ ] **Step 1: 创建 questionnaire-table 组件**

Create `lumira-server/packages/admin/src/components/questionnaire-table.tsx`:

```tsx
// src/components/questionnaire-table.tsx
import Link from 'next/link';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { truncateDeviceId, formatUnixTime } from '@/lib/utils';
import type { QuestionnaireListResponse } from '@/types/admin';

const sourceLabels: Record<string, string> = {
  app_store: '应用商店',
  social_media: '社交媒体',
  friend: '朋友推荐',
  search: '搜索引擎',
  article: '文章博客',
  other: '其他',
};

const skillLabels: Record<string, string> = {
  beginner: '新手',
  intermediate: '进阶',
  advanced: '高级',
  pro: '专业',
};

const categoryLabels: Record<string, string> = {
  portrait: '人像',
  landscape: '风光',
  food: '美食',
  street: '街拍',
  night: '夜景',
  macro: '微距',
  'still-life': '静物',
};

function parseAnswers(json: string): Record<string, unknown> | null {
  try {
    return JSON.parse(json) as Record<string, unknown>;
  } catch {
    return null;
  }
}

export function QuestionnaireTable({ data }: { data: QuestionnaireListResponse }) {
  return (
    <div className="rounded-md border border-border bg-card">
      <Table>
        <TableHeader>
          <TableRow className="bg-muted/30 hover:bg-muted/30">
            <TableHead className="w-16">ID</TableHead>
            <TableHead>设备</TableHead>
            <TableHead>别名</TableHead>
            <TableHead>提交时间</TableHead>
            <TableHead>渠道</TableHead>
            <TableHead>偏好分类</TableHead>
            <TableHead>摄影水平</TableHead>
            <TableHead>IP</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {data.data.length === 0 ? (
            <TableRow>
              <TableCell colSpan={8} className="text-center text-muted-foreground py-8">
                无问卷记录
              </TableCell>
            </TableRow>
          ) : (
            data.data.map((row) => {
              const answers = parseAnswers(row.answersJson);
              const source = answers?.source as string | null;
              const favCats = (answers?.favorite_categories as string[]) || [];
              const skillLevel = answers?.skill_level as string | null;
              return (
                <TableRow key={row.id}>
                  <TableCell className="text-muted-foreground">{row.id}</TableCell>
                  <TableCell>
                    <Link
                      href={`/dashboard/questionnaire/${row.deviceId}`}
                      className="font-mono text-xs text-primary hover:underline"
                    >
                      {truncateDeviceId(row.deviceId)}
                    </Link>
                  </TableCell>
                  <TableCell className="text-sm">{row.deviceAlias || '—'}</TableCell>
                  <TableCell className="text-sm">{formatUnixTime(row.submittedAt)}</TableCell>
                  <TableCell>
                    {source ? (
                      <Badge variant="secondary">{sourceLabels[source] || source}</Badge>
                    ) : (
                      <span className="text-muted-foreground text-xs">跳过</span>
                    )}
                  </TableCell>
                  <TableCell className="text-xs">
                    {favCats.length > 0
                      ? favCats.map((c) => categoryLabels[c] || c).join('、')
                      : '—'}
                  </TableCell>
                  <TableCell>
                    {skillLevel ? (
                      <Badge variant="outline">{skillLabels[skillLevel] || skillLevel}</Badge>
                    ) : (
                      <span className="text-muted-foreground text-xs">跳过</span>
                    )}
                  </TableCell>
                  <TableCell className="text-xs text-muted-foreground">{row.clientIp || '—'}</TableCell>
                </TableRow>
              );
            })
          )}
        </TableBody>
      </Table>
    </div>
  );
}
```

- [ ] **Step 2: 创建列表页**

Create `lumira-server/packages/admin/src/app/dashboard/questionnaire/page.tsx`:

```tsx
// src/app/dashboard/questionnaire/page.tsx
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { MagnifyingGlass, ChartBar } from '@phosphor-icons/react/dist/ssr';
import { QuestionnaireTable } from '@/components/questionnaire-table';
import { Pagination } from '@/components/pagination';

export default async function QuestionnairePage({
  searchParams,
}: {
  searchParams: { page?: string; pageSize?: string; deviceId?: string };
}) {
  const page = Number(searchParams.page) || 1;
  const pageSize = Number(searchParams.pageSize) || 20;
  const deviceId = searchParams.deviceId;

  let data;
  try {
    data = await api.getQuestionnaire({ page, pageSize, deviceId });
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <form className="flex gap-2 items-end">
          <div className="flex-1 max-w-xs">
            <label className="text-sm text-muted-foreground mb-1 block">按设备 ID 筛选</label>
            <Input
              name="deviceId"
              defaultValue={deviceId}
              placeholder="输入完整 device_id"
            />
          </div>
          <Button type="submit" size="sm">
            <MagnifyingGlass size={14} className="mr-1" /> 搜索
          </Button>
        </form>
        <Button asChild variant="outline" size="sm">
          <Link href="/dashboard/questionnaire/stats">
            <ChartBar size={14} className="mr-1" /> 查看统计
          </Link>
        </Button>
      </div>

      <QuestionnaireTable data={data} />

      <Pagination
        page={page}
        pageSize={pageSize}
        total={data.total}
        basePath="/dashboard/questionnaire"
        searchParams={searchParams}
      />
    </div>
  );
}
```

- [ ] **Step 3: 验证编译**

Run: `cd lumira-server && pnpm --filter @lumira/admin build`
Expected: 编译成功

- [ ] **Step 4: 手动验证**

启动 admin：`cd lumira-server && pnpm --filter @lumira/admin dev`
访问 `http://localhost:3001/dashboard/questionnaire`，确认表格渲染，点击设备 ID 跳详情（Task 16 实现后会生效）。

- [ ] **Step 5: Commit**

```bash
git add lumira-server/packages/admin/src/components/questionnaire-table.tsx lumira-server/packages/admin/src/app/dashboard/questionnaire/page.tsx
git commit -m "feat(admin): add questionnaire list page"
```

---

## Task 16: Admin 前端 - 单设备历史详情页

**Files:**
- Create: `lumira-server/packages/admin/src/app/dashboard/questionnaire/[deviceId]/page.tsx`

**Interfaces:**
- Consumes: `api.getQuestionnaireHistory`, `QuestionnaireHistoryResponse`
- Produces: `/dashboard/questionnaire/:deviceId` 详情页

- [ ] **Step 1: 创建详情页**

Create `lumira-server/packages/admin/src/app/dashboard/questionnaire/[deviceId]/page.tsx`:

```tsx
// src/app/dashboard/questionnaire/[deviceId]/page.tsx
import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { Badge } from '@/components/ui/badge';
import { formatUnixTime } from '@/lib/utils';
import Link from 'next/link';
import { ArrowLeft } from '@phosphor-icons/react/dist/ssr';
import type { QuestionnaireAnswers } from '@/types/admin';

const labelMaps: Record<string, Record<string, string>> = {
  source: {
    app_store: '应用商店', social_media: '社交媒体', friend: '朋友推荐',
    search: '搜索引擎', article: '文章博客', other: '其他',
  },
  favorite_categories: {
    portrait: '人像', landscape: '风光', food: '美食', street: '街拍',
    night: '夜景', macro: '微距', 'still-life': '静物',
  },
  pain_points: {
    composition: '构图困难', lighting: '光线处理', posing: '摆姿不自然',
    camera_settings: '参数设置', post_processing: '后期修图',
    no_subject: '找不到拍摄对象', no_time: '没时间拍',
  },
  skill_level: {
    beginner: '新手', intermediate: '进阶', advanced: '高级', pro: '专业',
  },
  expectations: {
    learn_photo: '学摄影', inspiration: '找灵感', better_composition: '提升构图',
    master_camera: '玩转相机', share_works: '分享作品', record_life: '记录生活',
  },
  common_scenes: {
    indoor_home: '家中', cafe: '咖啡馆', outdoor_park: '户外公园',
    street: '街头', travel: '旅行', office: '办公室', studio: '影棚',
  },
  shoot_frequency: {
    rarely: '偶尔', monthly: '每月', weekly: '每周', daily: '每天',
  },
};

const questionTitles: Record<string, string> = {
  source: '了解渠道',
  favorite_categories: '喜欢拍什么',
  pain_points: '拍摄烦恼',
  skill_level: '摄影水平',
  expectations: '期望收获',
  common_scenes: '常用场景',
  shoot_frequency: '拍摄频率',
};

function renderValue(field: string, value: unknown): React.ReactNode {
  if (value === null || value === undefined) {
    return <span className="text-muted-foreground text-xs">跳过</span>;
  }
  const map = labelMaps[field];
  if (Array.isArray(value)) {
    if (value.length === 0) {
      return <span className="text-muted-foreground text-xs">跳过</span>;
    }
    return (
      <div className="flex flex-wrap gap-1">
        {value.map((v) => (
          <Badge key={v} variant="secondary">
            {map?.[v] || v}
          </Badge>
        ))}
      </div>
    );
  }
  return <Badge variant="outline">{map?.[value as string] || (value as string)}</Badge>;
}

export default async function QuestionnaireDetailPage({
  params,
}: {
  params: { deviceId: string };
}) {
  let data;
  try {
    data = await api.getQuestionnaireHistory(params.deviceId);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }

  return (
    <div className="space-y-4">
      <Link
        href="/dashboard/questionnaire"
        className="inline-flex items-center text-sm text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft size={14} className="mr-1" /> 返回列表
      </Link>

      <div className="text-sm text-muted-foreground">
        设备 ID: <span className="font-mono">{params.deviceId}</span> · 共 {data.total} 次提交
      </div>

      {data.data.length === 0 ? (
        <div className="text-center text-muted-foreground py-8">该设备无问卷记录</div>
      ) : (
        <div className="space-y-6">
          {data.data.map((record, idx) => {
            let answers: QuestionnaireAnswers | null = null;
            try {
              answers = JSON.parse(record.answersJson) as QuestionnaireAnswers;
            } catch {
              // 忽略解析失败
            }
            return (
              <div key={record.id} className="rounded-md border border-border bg-card p-4">
                <div className="flex justify-between items-center mb-4">
                  <h3 className="text-sm font-semibold">
                    第 {data.total - idx} 次提交
                    {idx === 0 && (
                      <Badge variant="default" className="ml-2">最新</Badge>
                    )}
                  </h3>
                  <span className="text-xs text-muted-foreground">
                    {formatUnixTime(record.submittedAt)} · IP: {record.clientIp || '—'}
                  </span>
                </div>
                {answers ? (
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {Object.entries(questionTitles).map(([field, title]) => (
                      <div key={field} className="space-y-1">
                        <div className="text-xs text-muted-foreground">{title}</div>
                        <div>
                          {renderValue(field, (answers as Record<string, unknown>)[field])}
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="text-destructive text-sm">答案解析失败</div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 2: 验证编译**

Run: `cd lumira-server && pnpm --filter @lumira/admin build`
Expected: 编译成功

- [ ] **Step 3: 手动验证**

访问 `/dashboard/questionnaire/test-questionnaire-001`（前提是 Task 3 步骤 7 已提交过测试数据），确认历史记录展示。

- [ ] **Step 4: Commit**

```bash
git add lumira-server/packages/admin/src/app/dashboard/questionnaire/[deviceId]/page.tsx
git commit -m "feat(admin): add questionnaire device history page"
```

---

## Task 17: Admin 前端 - 统计面板页

**Files:**
- Create: `lumira-server/packages/admin/src/app/dashboard/questionnaire/stats/page.tsx`

**Interfaces:**
- Consumes: `api.getQuestionnaireStats`, `QuestionnaireStats`
- Produces: `/dashboard/questionnaire/stats` 统计页

- [ ] **Step 1: 创建统计页**

Create `lumira-server/packages/admin/src/app/dashboard/questionnaire/stats/page.tsx`:

```tsx
// src/app/dashboard/questionnaire/stats/page.tsx
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { ArrowLeft } from '@phosphor-icons/react/dist/ssr';
import type { QuestionnaireStats } from '@/types/admin';

const questionConfig: Array<{
  field: keyof Omit<QuestionnaireStats, 'totalRespondents'>;
  title: string;
  labels: Record<string, string>;
}> = [
  {
    field: 'source',
    title: '了解渠道',
    labels: {
      app_store: '应用商店', social_media: '社交媒体', friend: '朋友推荐',
      search: '搜索引擎', article: '文章博客', other: '其他',
    },
  },
  {
    field: 'favorite_categories',
    title: '喜欢拍什么',
    labels: {
      portrait: '人像', landscape: '风光', food: '美食', street: '街拍',
      night: '夜景', macro: '微距', 'still-life': '静物',
    },
  },
  {
    field: 'pain_points',
    title: '拍摄烦恼',
    labels: {
      composition: '构图困难', lighting: '光线处理', posing: '摆姿不自然',
      camera_settings: '参数设置', post_processing: '后期修图',
      no_subject: '找不到拍摄对象', no_time: '没时间拍',
    },
  },
  {
    field: 'skill_level',
    title: '摄影水平',
    labels: {
      beginner: '新手', intermediate: '进阶', advanced: '高级', pro: '专业',
    },
  },
  {
    field: 'expectations',
    title: '期望收获',
    labels: {
      learn_photo: '学摄影', inspiration: '找灵感', better_composition: '提升构图',
      master_camera: '玩转相机', share_works: '分享作品', record_life: '记录生活',
    },
  },
  {
    field: 'common_scenes',
    title: '常用场景',
    labels: {
      indoor_home: '家中', cafe: '咖啡馆', outdoor_park: '户外公园',
      street: '街头', travel: '旅行', office: '办公室', studio: '影棚',
    },
  },
  {
    field: 'shoot_frequency',
    title: '拍摄频率',
    labels: {
      rarely: '偶尔', monthly: '每月', weekly: '每周', daily: '每天',
    },
  },
];

function DistributionCard({
  title,
  distribution,
  labels,
  totalRespondents,
}: {
  title: string;
  distribution: Record<string, number>;
  labels: Record<string, string>;
  totalRespondents: number;
}) {
  const entries = Object.entries(distribution).sort((a, b) => b[1] - a[1]);
  const max = entries.length > 0 ? entries[0][1] : 1;

  return (
    <div className="rounded-md border border-border bg-card p-4">
      <h3 className="text-sm font-semibold mb-3">{title}</h3>
      {entries.length === 0 ? (
        <div className="text-muted-foreground text-xs">暂无数据</div>
      ) : (
        <div className="space-y-2">
          {entries.map(([key, count]) => {
            const pct = totalRespondents > 0 ? (count / totalRespondents) * 100 : 0;
            const barWidth = max > 0 ? (count / max) * 100 : 0;
            return (
              <div key={key} className="flex items-center gap-2">
                <div className="w-20 text-xs text-muted-foreground shrink-0">
                  {labels[key] || key}
                </div>
                <div className="flex-1 h-5 bg-muted rounded relative overflow-hidden">
                  <div
                    className="h-full bg-primary/30 transition-all"
                    style={{ width: `${barWidth}%` }}
                  />
                </div>
                <div className="w-16 text-xs text-right shrink-0">
                  {count} ({pct.toFixed(1)}%)
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

export default async function QuestionnaireStatsPage() {
  let stats: QuestionnaireStats;
  try {
    stats = await api.getQuestionnaireStats();
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }

  return (
    <div className="space-y-4">
      <Link
        href="/dashboard/questionnaire"
        className="inline-flex items-center text-sm text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft size={14} className="mr-1" /> 返回列表
      </Link>

      <div className="rounded-md border border-border bg-card p-6">
        <div className="text-sm text-muted-foreground mb-1">总响应人数</div>
        <div className="text-3xl font-bold">{stats.totalRespondents}</div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {questionConfig.map((config) => (
          <DistributionCard
            key={config.field}
            title={config.title}
            distribution={stats[config.field]}
            labels={config.labels}
            totalRespondents={stats.totalRespondents}
          />
        ))}
      </div>
    </div>
  );
}
```

- [ ] **Step 2: 验证编译**

Run: `cd lumira-server && pnpm --filter @lumira/admin build`
Expected: 编译成功

- [ ] **Step 3: 手动验证**

访问 `/dashboard/questionnaire/stats`，确认 7 个分布卡片渲染，数据正确。

- [ ] **Step 4: Commit**

```bash
git add lumira-server/packages/admin/src/app/dashboard/questionnaire/stats/page.tsx
git commit -m "feat(admin): add questionnaire stats page"
```

---

## Task 18: 端到端集成验证

**Files:** 无（仅验证）

- [ ] **Step 1: 启动后端 + admin**

```bash
cd lumira-server
pnpm --filter @lumira/backend run start:dev &
pnpm --filter @lumira/admin dev &
```

- [ ] **Step 2: 启动 Flutter app**

```bash
cd lumira_app_flutter
flutter run
```

> 测试新设备场景：先清除 app 数据或用新 deviceId，确保 `AuthState.isNewDevice = true`。

- [ ] **Step 3: 验证新用户流程**

1. App 首次启动 → splash → 自动跳转到问卷页（不是 home）
2. 逐题填写，单选自动推进，多选点"下一题"
3. 完成提交 → 跳转 home
4. 首页 banner 1 显示"从XX开始"（XX 为问卷首选分类）

- [ ] **Step 4: 验证跳过流程**

清除 app 数据重试，问卷页左上角点"跳过"→ 直接跳 home → 首页 banner 1 显示"新手友好场景"（fallback）

- [ ] **Step 5: 验证设置页重填**

1. 进入 设置 → 通用 → 偏好问卷（显示"已填"）
2. 点击进入，重填，改变首选分类
3. 返回设置页，确认仍显示"已填"
4. 回首页，banner 1 应更新为新分类（若仍为新用户）

- [ ] **Step 6: 验证 admin 数据**

1. 访问 `http://localhost:3001/dashboard/questionnaire`
2. 确认列表显示刚才提交的记录
3. 点击设备 ID → 历史详情页显示所有提交（重填会有多条）
4. 点击"查看统计" → 7 个分布卡片数据正确

- [ ] **Step 7: 验证离线场景**

1. 关闭后端
2. Flutter app 清除数据重启，填问卷
3. 确认提交成功（本地落库），跳 home，推荐生效
4. 重启后端
5. 重启 Flutter app，确认补传成功（admin 列表出现记录）

- [ ] **Step 8: 最终 commit（如有遗漏修复）**

```bash
git add -A
git commit -m "test: e2e verification of questionnaire flow"
```

---

## Self-Review

**Spec coverage:**
- ✅ 7 题问卷定义 → Task 6 (questionnaire_data.dart)
- ✅ Flutter sqflite 表 v11→v12 → Task 5
- ✅ 后端 Drizzle 表 + 迁移 → Task 2
- ✅ 共享类型 → Task 1
- ✅ 后端提交接口 → Task 3
- ✅ 后端 admin 3 接口 → Task 4
- ✅ Flutter 多步向导 UI → Task 9
- ✅ 路由 + splash 分流 → Task 8
- ✅ 设置页入口 → Task 10
- ✅ 推荐联动 slot 1 → Task 11
- ✅ 启动补传 → Task 12
- ✅ Admin 类型 + API → Task 13
- ✅ Admin 侧边栏 → Task 14
- ✅ Admin 列表页 → Task 15
- ✅ Admin 详情页 → Task 16
- ✅ Admin 统计页 → Task 17
- ✅ 端到端验证 → Task 18

**Placeholder scan:** 无 TODO/TBD，所有代码步骤含完整代码。

**Type consistency:**
- `QuestionnaireAnswers` 字段名：Flutter 用 camelCase (`favoriteCategories`)，JSON 用 snake_case (`favorite_categories`)，与 shared 类型一致 ✅
- `still-life` 连字符：Task 1/3/6/15/16/17 全部统一为 `still-life` ✅
- `QuestionnaireListResponse.data`：与现有 `InviteListResponse.data` 风格一致 ✅
- `QuestionnaireDao` 方法名：`getAnswers`/`upsert`/`markSynced`/`isCompleted`/`hasUnsynced`，在 Task 6/7/11/12 引用一致 ✅
- `questionnaireDaoProvider`：Task 6 定义，Task 8/11/12 引用一致 ✅
- `questionnaireSyncServiceProvider`：Task 7 定义，Task 9/12 引用一致 ✅

**Scope check:** 单一计划覆盖 Flutter + 后端 + Admin 三端，但因围绕同一功能且共享类型，作为一个计划保持一致性更好。18 个任务可在单次迭代完成。
