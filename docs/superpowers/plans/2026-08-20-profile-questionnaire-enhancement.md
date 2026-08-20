# 个人中心完善 + 问卷性别/首次引导 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完善个人中心页，为问卷新增"性别"题并仅在首次使用展示，让性别+6项偏好+自定义头像在个人中心可编辑并全部同步到后端数据库，同时保留问卷表用作数据分析。

**Architecture:** 后端把 `user_profiles` 扩展为"当前可编辑个人资料"单一数据源（新增 gender、6 项偏好 JSON、avatar_url），`PATCH /profile` 部分更新，新增 `POST /profile/avatar` 自定义头像上传。问卷提交仍写 `questionnaire_records`（只追加，供分析），提交时后端同步一份偏好到 `user_profiles`；个人中心后续编辑只改 `user_profiles`，不回改问卷。Flutter 端扩展 `ProfileData`/DAO/Repository/Sync 并做本地库 v27 迁移，扩展编辑资料页承载全部可编辑项，主页新增偏好摘要卡片，并从设置移除问卷入口。

**Tech Stack:** NestJS + Fastify + Drizzle ORM + MySQL（后端）；Flutter 3.7.12 / Dart 2.19.6（客户端；不用 Dart 3 records）；riverpod + sqflite v11（离线优先）。

## Global Constraints

- Flutter 端 Dart 2.19.6，**禁止 Dart 3 records / patterns 语法**（类、named constructor、`copyWith` 用法保持一致）。
- 后端改动后（`lumira-server/packages/backend/`）**每次任务完成即 commit 并 push 到 `origin`(gitee) 与 `github` 两个远程**。
- Flutter 端（`lumira_app_flutter/`）不强制推送（可随批次），但须本地 `git commit`。
- 问卷表 `questionnaire_records` **只追加不修改**；个人资料偏好只写 `user_profiles`。
- 头像：`avatar_url` 有值用后端图，否则用 picsum seed（`avatar_seed`）。
- 下拉/单选取值白名单必须与后端 DTO `@IsIn` 一致：
  - gender：`male`/`female`/`prefer_not`
  - skill_level：`beginner`/`intermediate`/`advanced`/`pro`
  - shoot_frequency：`rarely`/`monthly`/`weekly`/`daily`
- 个人资料 PATCH body 用模块既有 **camelCase** 约定（如 `favoriteCategories`）；问卷 answers 用 **snake_case**（既有约定）。
- 迁移：后端用 `src/database/migrations/NNN_*.sql`（版本化执行器自动跑）；Flutter 端 `_kDbVersion` 从 26 升到 27。
- 复用现有 DeviceAuthGuard / multipart（fastify `req.parts()`）/ `/uploads/` 静态服务。

---

### Task 1: 后端 — user_profiles 加列（迁移 SQL + schema + DTO + service）

**Files:**
- Create: `lumira-server/packages/backend/src/database/migrations/012_profile_preferences.sql`
- Modify: `lumira-server/packages/backend/src/database/schema.ts:24`
- Modify: `lumira-server/packages/backend/src/modules/profile/dto/update-profile.dto.ts`
- Modify: `lumira-server/packages/backend/src/modules/profile/profile.service.ts`
- Create: `lumira-server/packages/backend/src/modules/profile/dto/update-profile.dto.spec.ts`

**Interfaces:**
- Produces（供 Task 3 复用）：`ProfileService.mergeQuestionnairePrefs(deviceId: string, prefs: { gender?: string|null; favorite_categories?: string[]; pain_points?: string[]; skill_level?: string|null; expectations?: string[]; common_scenes?: string[]; shoot_frequency?: string|null }): Promise<void>` —— 只写这 6 项 + gender，不覆盖 username/avatar_seed/avatar_url。
- Produces：`UpdateProfileDto` 新增可选字段 `gender`、`favoriteCategories`、`painPoints`、`skillLevel`、`expectations`、`commonScenes`、`shootFrequency`、`avatarUrl`。

- [ ] **Step 1: 写失败测试（DTO 校验）**

创建 `src/modules/profile/dto/update-profile.dto.spec.ts`：

```ts
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { UpdateProfileDto } from './update-profile.dto';

describe('UpdateProfileDto', () => {
  it('接受合法的新增偏好字段', async () => {
    const dto = plainToInstance(UpdateProfileDto, {
      gender: 'male',
      skillLevel: 'intermediate',
      shootFrequency: 'weekly',
      favoriteCategories: ['portrait', 'food'],
      painPoints: ['composition'],
      expectations: ['share_works'],
      commonScenes: ['cafe'],
      avatarUrl: 'https://example.com/uploads/users/x/avatar.png',
    });
    const errors = await validate(dto);
    expect(errors).toHaveLength(0);
  });

  it('拒绝不在白名单的单选项', async () => {
    const dto = plainToInstance(UpdateProfileDto, { gender: 'robot' });
    const errors = await validate(dto);
    expect(errors.length).toBeGreaterThan(0);
  });

  it('拒绝多选中的非法枚举值', async () => {
    const dto = plainToInstance(UpdateProfileDto, { favoriteCategories: ['hiking'] });
    const errors = await validate(dto);
    expect(errors.length).toBeGreaterThan(0);
  });
});
```

- [ ] **Step 2: 运行测试验证失败**

Run: `pnpm --filter @lumira/backend test -- update-profile.dto`（若后端无 vitest 配置，则以 `pnpm --filter @lumira/backend typecheck` 为准，并在 PR 中说明；DTO 在 Step 4 完成后用 typecheck 覆盖）。
Expected: 失败——`UpdateProfileDto` 尚无这些字段描述（`@IsIn` 未定义）。

- [ ] **Step 3: 写迁移 SQL**

创建 `src/database/migrations/012_profile_preferences.sql`：

```sql
-- lumira-server/packages/backend/src/database/migrations/012_profile_preferences.sql
-- 个人中心偏好 + 自定义头像（spec 2026-08-20-profile-questionnaire-enhancement-design §2.2）

ALTER TABLE user_profiles
  ADD COLUMN gender VARCHAR(20) NULL,
  ADD COLUMN favorite_categories_json TEXT NULL,
  ADD COLUMN pain_points_json TEXT NULL,
  ADD COLUMN skill_level VARCHAR(20) NULL,
  ADD COLUMN expectations_json TEXT NULL,
  ADD COLUMN common_scenes_json TEXT NULL,
  ADD COLUMN shoot_frequency VARCHAR(20) NULL,
  ADD COLUMN avatar_url VARCHAR(255) NULL;
```

- [ ] **Step 4: 改 schema.ts 的 userProfiles**

把 `src/database/schema.ts` 中 `userProfiles`（约 24-29 行）改为：

```ts
export const userProfiles = mysqlTable('user_profiles', {
  deviceId: text('device_id').primaryKey().references(() => devices.deviceId),
  username: text('username').notNull(),
  avatarSeed: text('avatar_seed').notNull(),
  gender: text('gender'),
  favoriteCategoriesJson: text('favorite_categories_json'),
  painPointsJson: text('pain_points_json'),
  skillLevel: text('skill_level'),
  expectationsJson: text('expectations_json'),
  commonScenesJson: text('common_scenes_json'),
  shootFrequency: text('shoot_frequency'),
  avatarUrl: text('avatar_url'),
  updatedAt: int('updated_at').notNull(),
});
```

- [ ] **Step 5: 扩展 UpdateProfileDto**

替换 `update-profile.dto.ts` 全文为：

```ts
// lumira-server/packages/backend/src/modules/profile/dto/update-profile.dto.ts

import {
  IsOptional, IsString, MinLength, MaxLength,
  IsIn, IsArray, ArrayUnique,
} from 'class-validator';

const FAVORITE_CATEGORIES = ['portrait', 'landscape', 'food', 'street', 'night', 'macro', 'still-life'];
const PAIN_POINTS = ['composition', 'lighting', 'posing', 'camera_settings', 'post_processing', 'no_subject', 'no_time'];
const EXPECTATIONS = ['learn_photo', 'inspiration', 'better_composition', 'master_camera', 'share_works', 'record_life'];
const COMMON_SCENES = ['indoor_home', 'cafe', 'outdoor_park', 'street', 'travel', 'office', 'studio'];

export class UpdateProfileDto {
  @IsOptional() @IsString() @MinLength(1) @MaxLength(20)
  username?: string;

  @IsOptional() @IsString() @MinLength(1) @MaxLength(64)
  avatarSeed?: string;

  @IsOptional() @IsString() @IsIn(['male', 'female', 'prefer_not'])
  gender?: string;

  @IsOptional() @IsArray() @ArrayUnique() @IsString({ each: true }) @IsIn(FAVORITE_CATEGORIES, { each: true })
  favoriteCategories?: string[];

  @IsOptional() @IsArray() @ArrayUnique() @IsString({ each: true }) @IsIn(PAIN_POINTS, { each: true })
  painPoints?: string[];

  @IsOptional() @IsString() @IsIn(['beginner', 'intermediate', 'advanced', 'pro'])
  skillLevel?: string;

  @IsOptional() @IsArray() @ArrayUnique() @IsString({ each: true }) @IsIn(EXPECTATIONS, { each: true })
  expectations?: string[];

  @IsOptional() @IsArray() @ArrayUnique() @IsString({ each: true }) @IsIn(COMMON_SCENES, { each: true })
  commonScenes?: string[];

  @IsOptional() @IsString() @IsIn(['rarely', 'monthly', 'weekly', 'daily'])
  shootFrequency?: string;

  @IsOptional() @IsString() @MaxLength(255)
  avatarUrl?: string;
}
```

- [ ] **Step 6: 改 profile.service.ts（读/写新字段 + mergeQuestionnairePrefs）**

读取 24-34 行现状后，将 profile.service.ts 扩展为：

```ts
// lumira-server/packages/backend/src/modules/profile/profile.service.ts
import { Injectable } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { userProfiles } from '../../database/schema';
import { BUILTIN_AVATAR_SEEDS, BUILTIN_USERNAMES, randomPick } from './profile-constants';
import { UpdateProfileDto } from './dto/update-profile.dto';

export interface ProfileView {
  username: string;
  avatarSeed: string;
  gender: string | null;
  favoriteCategories: string[];
  painPoints: string[];
  skillLevel: string | null;
  expectations: string[];
  commonScenes: string[];
  shootFrequency: string | null;
  avatarUrl: string | null;
  updatedAt: number;
}

function parseArr(raw: string | null): string[] {
  if (!raw) return [];
  try {
    const v = JSON.parse(raw);
    return Array.isArray(v) ? v.filter((x) => typeof x === 'string') : [];
  } catch {
    return [];
  }
}

function toProfileView(row: typeof userProfiles.$inferSelect): ProfileView {
  return {
    username: row.username,
    avatarSeed: row.avatarSeed,
    gender: row.gender,
    favoriteCategories: parseArr(row.favoriteCategoriesJson),
    painPoints: parseArr(row.painPointsJson),
    skillLevel: row.skillLevel,
    expectations: parseArr(row.expectationsJson),
    commonScenes: parseArr(row.commonScenesJson),
    shootFrequency: row.shootFrequency,
    avatarUrl: row.avatarUrl,
    updatedAt: row.updatedAt,
  };
}

@Injectable()
export class ProfileService {
  constructor(private readonly db: DatabaseService) {}

  async getOrCreateProfile(deviceId: string): Promise<ProfileView> {
    const existing = await this.db.db
      .select()
      .from(userProfiles)
      .where(eq(userProfiles.deviceId, deviceId))
      .limit(1);
    if (existing.length > 0) return toProfileView(existing[0]);

    const now = Math.floor(Date.now() / 1000);
    await this.db.db.insert(userProfiles).values({
      deviceId,
      username: randomPick(BUILTIN_USERNAMES),
      avatarSeed: randomPick(BUILTIN_AVATAR_SEEDS),
      updatedAt: now,
    });
    return this.getOrCreateProfile(deviceId);
  }

  async updateProfile(deviceId: string, dto: UpdateProfileDto): Promise<ProfileView> {
    await this.getOrCreateProfile(deviceId);
    const now = Math.floor(Date.now() / 1000);
    const fields: Partial<typeof userProfiles.$inferInsert> = { updatedAt: now };
    if (dto.username !== undefined) fields.username = dto.username;
    if (dto.avatarSeed !== undefined) fields.avatarSeed = dto.avatarSeed;
    if (dto.gender !== undefined) fields.gender = dto.gender;
    if (dto.skillLevel !== undefined) fields.skillLevel = dto.skillLevel;
    if (dto.shootFrequency !== undefined) fields.shootFrequency = dto.shootFrequency;
    if (dto.avatarUrl !== undefined) fields.avatarUrl = dto.avatarUrl;
    if (dto.favoriteCategories !== undefined) fields.favoriteCategoriesJson = JSON.stringify(dto.favoriteCategories);
    if (dto.painPoints !== undefined) fields.painPointsJson = JSON.stringify(dto.painPoints);
    if (dto.expectations !== undefined) fields.expectationsJson = JSON.stringify(dto.expectations);
    if (dto.commonScenes !== undefined) fields.commonScenesJson = JSON.stringify(dto.commonScenes);
    await this.db.db.update(userProfiles).set(fields).where(eq(userProfiles.deviceId, deviceId));
    const updated = await this.getOrCreateProfile(deviceId);
    return updated;
  }

  /** 问卷提交时同步 6 项偏好 + 性别到 user_profiles（只写偏好字段，不覆盖 username/avatar）。 */
  async mergeQuestionnairePrefs(deviceId: string, prefs: {
    gender?: string | null;
    favorite_categories?: string[];
    pain_points?: string[];
    skill_level?: string | null;
    expectations?: string[];
    common_scenes?: string[];
    shoot_frequency?: string | null;
  }): Promise<void> {
    await this.getOrCreateProfile(deviceId);
    const now = Math.floor(Date.now() / 1000);
    const fields: Partial<typeof userProfiles.$inferInsert> = { updatedAt: now };
    if (prefs.gender !== undefined && prefs.gender !== null) fields.gender = prefs.gender;
    if (prefs.favorite_categories?.length) fields.favoriteCategoriesJson = JSON.stringify(prefs.favorite_categories);
    if (prefs.pain_points?.length) fields.painPointsJson = JSON.stringify(prefs.pain_points);
    if (prefs.skill_level !== undefined && prefs.skill_level !== null) fields.skillLevel = prefs.skill_level;
    if (prefs.expectations?.length) fields.expectationsJson = JSON.stringify(prefs.expectations);
    if (prefs.common_scenes?.length) fields.commonScenesJson = JSON.stringify(prefs.common_scenes);
    if (prefs.shoot_frequency !== undefined && prefs.shoot_frequency !== null) fields.shootFrequency = prefs.shoot_frequency;
    if (Object.keys(fields).length > 1) {
      await this.db.db.update(userProfiles).set(fields).where(eq(userProfiles.deviceId, deviceId));
    }
  }
}
```

> 说明：`DatabaseService` 暴露 `this.db`（drizzle 实例）。若实际字段名不同，以 `database.service.ts` 现有暴露名 `this.db.db` 为准对齐（Task 1 实现时确认）。

- [ ] **Step 7: 确认测试通过 + 类型检查**

Run: `pnpm --filter @lumira/backend test -- update-profile.dto` 与 `pnpm --filter @lumira/backend typecheck`
Expected: 三个 DTO 用例全部 PASS；typecheck 无错误。

- [ ] **Step 8: 提交并双推**

```bash
git add lumira-server/packages/backend/src/database/migrations/012_profile_preferences.sql
git add lumira-server/packages/backend/src/database/schema.ts
git add lumira-server/packages/backend/src/modules/profile/dto/update-profile.dto.ts
git add lumira-server/packages/backend/src/modules/profile/dto/update-profile.dto.spec.ts
git add lumira-server/packages/backend/src/modules/profile/profile.service.ts
git commit -m "feat(backend): user_profiles 新增性别/偏好/自定义头像字段"
git push origin master
git push github master
```

---

### Task 2: 后端 — POST /profile/avatar 自定义头像上传

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/profile/profile.controller.ts`
- Modify: `lumira-server/packages/backend/src/modules/feedback/../profile/profile.service.ts`（新增 `saveAvatar` 方法）

**Interfaces:**
- Consumes：Task 1 的 `ProfileService.getOrCreateProfile`、`updateProfile(deviceId, { avatarUrl })`。
- Produces：`ProfileController` 新增 `@Post('avatar')`，接收 multipart 单文件，返回 `{ avatarUrl: string }`；`ProfileService.saveAvatar(deviceId, file): Promise<{ avatarUrl: string }>`。

- [ ] **Step 1: 在 profile.controller.ts 增加上传接口**

读取后端 `feedback.controller.ts`（multipart 解析范式），在 `profile.controller.ts` 新增：

```ts
// 追加到 profile.controller.ts
import { Post, Req, BadRequestException } from '@nestjs/common';
import type { FastifyRequest } from 'fastify';

const ALLOWED_AVATAR_MIME = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/gif']);
const MAX_AVATAR_BYTES = 10 * 1024 * 1024; // 10MB

async function parseAvatarMultipart(req: FastifyRequest): Promise<{ buffer: Buffer; ext: string }> {
  const reqAny = req as any;
  if (typeof reqAny.parts !== 'function') {
    throw new BadRequestException('Multipart not enabled on this request');
  }
  let buffer: Buffer | null = null;
  let filename = '';
  let mimetype = '';
  for await (const part of reqAny.parts()) {
    if (part.type === 'file' && part.fieldname === 'avatar') {
      const buf = await part.toBuffer();
      buffer = buf;
      filename = part.filename || '';
      mimetype = part.mimetype || '';
      break;
    }
  }
  if (!buffer) throw new BadRequestException('缺少头像文件（字段名 avatar）');
  if (!ALLOWED_AVATAR_MIME.has(mimetype)) throw new BadRequestException('仅支持 jpg/png/webp/gif');
  if (buffer.length > MAX_AVATAR_BYTES) throw new BadRequestException('头像大小不能超过 10MB');
  const dot = filename.lastIndexOf('.');
  const rawExt = dot >= 0 ? filename.slice(dot + 1).toLowerCase() : '';
  const ext = /^[a-z0-9]+$/.test(rawExt) ? rawExt : 'png';
  return { buffer, ext };
}
```

- [ ] **Step 2: 在 controller 类内加 handler**

```ts
  @Post('avatar')
  async uploadAvatar(@Req() req: FastifyRequest, @DeviceId() deviceId: string) {
    const file = await parseAvatarMultipart(req);
    return this.profileService.saveAvatar(deviceId, file.buffer, file.ext);
  }
```

- [ ] **Step 3: profile.service.ts 新增 saveAvatar**

```ts
// 追加 import
import * as fs from 'fs';
import * as path from 'path';

  /** 保存自定义头像到 {UPLOAD_DIR}/users/{deviceId}/avatar.{ext}，删除旧文件，写 avatar_url。 */
  async saveAvatar(deviceId: string, buffer: Buffer, ext: string): Promise<{ avatarUrl: string }> {
    await this.getOrCreateProfile(deviceId);
    const uploadDir = process.env.UPLOAD_DIR || path.resolve('./data/uploads');
    const dir = path.join(uploadDir, 'users', deviceId);
    fs.mkdirSync(dir, { recursive: true });

    // 删除旧头像
    const oldRow = await this.db.db
      .select({ url: userProfiles.avatarUrl })
      .from(userProfiles)
      .where(eq(userProfiles.deviceId, deviceId))
      .limit(1);
    const oldUrl = oldRow[0]?.url;
    if (oldUrl) {
      const oldName = oldUrl.split('/').pop();
      if (oldName) fs.rmSync(path.join(dir, oldName), { force: true });
    }

    const filename = `avatar.${ext}`;
    fs.writeFileSync(path.join(dir, filename), buffer);

    const base = process.env.BACKEND_PUBLIC_URL || 'http://localhost:3000';
    const avatarUrl = `${base}/uploads/users/${deviceId}/${filename}`;
    await this.updateProfile(deviceId, { avatarUrl });
    return { avatarUrl };
  }
```

- [ ] **Step 4: 后端类型检查通过**

Run: `pnpm --filter @lumira/backend typecheck`
Expected: 无错误。

- [ ] **Step 5: 提交并双推**

```bash
git add lumira-server/packages/backend/src/modules/profile/profile.controller.ts
git add lumira-server/packages/backend/src/modules/profile/profile.service.ts
git commit -m "feat(backend): 新增 POST /profile/avatar 自定义头像上传"
git push origin master
git push github master
```

---

### Task 3: 后端 — 问卷新增 gender + 提交同步偏好

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/questionnaire/dto/submit-questionnaire.dto.ts`
- Modify: `lumira-server/packages/backend/src/modules/questionnaire/questionnaire.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/questionnaire/questionnaire.module.ts`（注入 ProfileService，若未导出）
- Modify: `lumira-server/packages/shared/src/types/questionnaire.ts`

**Interfaces:**
- Consumes：Task 1 的 `ProfileService.mergeQuestionnairePrefs`。
- Produces：`QuestionnaireAnswersDto` 新增 `gender?: string | null`（`@IsIn(['male','female','prefer_not'])`）；问卷提交后调用 `mergeQuestionnairePrefs`。共享类型 `Gender = 'male' | 'female' | 'prefer_not'`、`QuestionnaireAnswers` 增加 `gender?: Gender | null`。

- [ ] **Step 1: 共享类型加 gender**

`packages/shared/src/types/questionnaire.ts` 的 `QuestionnaireAnswers` 增加 `gender?: 'male' | 'female' | 'prefer_not' | null;`（并导出 `Gender` 类型）。`toDto`/`fromDto` 若有映射同步补 `gender`。

- [ ] **Step 2: DTO 加 gender**

`submit-questionnaire.dto.ts` 的 `QuestionnaireAnswersDto` 顶部新增：

```ts
  @IsOptional()
  @IsString()
  @IsIn(['male', 'female', 'prefer_not'])
  gender?: string | null;
```

- [ ] **Step 3: questionnaire.service.submit 同步偏好**

读取现问卷服务（约 10-20 行，写 `questionnaire_records`）后，构造器注入 `ProfileService`，在写记录后调用同步。示例改动：

```ts
import { ProfileService } from '../profile/profile.service';
// 构造器新增 private readonly profileService: ProfileService

// 在写入 questionnaire_records 之后：
await this.profileService.mergeQuestionnairePrefs(deviceId, {
  gender: dto.answers.gender,
  favorite_categories: dto.answers.favorite_categories,
  pain_points: dto.answers.pain_points,
  skill_level: dto.answers.skill_level,
  expectations: dto.answers.expectations,
  common_scenes: dto.answers.common_scenes,
  shoot_frequency: dto.answers.shoot_frequency,
});
```

- [ ] **Step 4: 注册 ProfileModule/Service**

确认 `questionnaire.module.ts` 的 `providers`/`imports` 能让 `ProfileService` 被注入（若 `ProfileModule` 未导出 `ProfileService`，则在 `.module.ts` 中 `exports: [ProfileService]` 或把 `ProfileService` 加入本模块 providers）。

- [ ] **Step 5: 类型检查 + 提交双推**

Run: `pnpm --filter @lumira/backend typecheck`
Expected: 无错误。

```bash
git add lumira-server/packages/shared/src/types/questionnaire.ts
git add lumira-server/packages/backend/src/modules/questionnaire
git commit -m "feat(backend): 问卷新增性别字段并同步偏好到 user_profiles"
git push origin master
git push github master
```

---

### Task 4: Flutter — 资料模型/DAO/仓库/同步扩展 + 本地库 v27 迁移

**Files:**
- Modify: `lumira_app_flutter/lib/core/db/tables.dart`
- Modify: `lumira_app_flutter/lib/features/profile/data/profile_models.dart`
- Modify: `lumira_app_flutter/lib/features/profile/data/builtin_profiles.dart`
- Modify: `lumira_app_flutter/lib/features/profile/data/profile_dao.dart`
- Modify: `lumira_app_flutter/lib/features/profile/data/profile_repository.dart`
- Modify: `lumira_app_flutter/lib/features/profile/services/profile_sync_service.dart`
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart`（v27 迁移）
- Modify: `lumira_app_flutter/test/features/profile/profile_sync_service_test.dart`
- Modify: `lumira_app_flutter/test/core/db/profile_dao_test.dart`

**Interfaces:**
- Produces：`ProfileData` 新增字段；`ProfileRepository.update({...})` 参数扩展；`ProfileRepository.uploadAvatarBytes(Uint8List bytes, String filename): Future<String>`；`ProfileSyncService.save(...)` 透传；`BuiltinProfiles.avatarUrl(seed, {String? customUrl})`。

- [ ] **Step 1: 先读现有测试与实现，确认契约**

读取 `profile_models.dart`、`profile_repository.dart`、`builtin_profiles.dart`、`profile_sync_service_test.dart`、`profile_dao_test.dart`，记录当前 `copyWith`/`fromJson`/`update` 签名，确保 Step 4-8 改动不破坏既有测试。

- [ ] **Step 2: tables.dart 增加列常量**

在 `user_profile` 段（184-188 行附近）追加：

```dart
  static const String colGender = 'gender';
  static const String colFavoriteCategoriesJson = 'favorite_categories_json';
  static const String colPainPointsJson = 'pain_points_json';
  static const String colSkillLevel = 'skill_level';
  static const String colExpectationsJson = 'expectations_json';
  static const String colCommonScenesJson = 'common_scenes_json';
  static const String colShootFrequency = 'shoot_frequency';
  static const String colAvatarUrl = 'avatar_url';
```

- [ ] **Step 3: 数据库 v27 迁移**

`database_provider.dart` 把 `_kDbVersion = 26` 改为 `27`；`_onCreate` 中 `user_profile` 建表 SQL 追加新列（与 Task 4 DAO 一致），并追加：

```dart
if (oldVersion < 27) {
  try {
    await _addColumnIfNotExists(db, Tables.userProfile, Tables.colGender, 'TEXT');
    await _addColumnIfNotExists(db, Tables.userProfile, Tables.colFavoriteCategoriesJson, 'TEXT');
    await _addColumnIfNotExists(db, Tables.userProfile, Tables.colPainPointsJson, 'TEXT');
    await _addColumnIfNotExists(db, Tables.userProfile, Tables.colSkillLevel, 'TEXT');
    await _addColumnIfNotExists(db, Tables.userProfile, Tables.colExpectationsJson, 'TEXT');
    await _addColumnIfNotExists(db, Tables.userProfile, Tables.colCommonScenesJson, 'TEXT');
    await _addColumnIfNotExists(db, Tables.userProfile, Tables.colShootFrequency, 'TEXT');
    await _addColumnIfNotExists(db, Tables.userProfile, Tables.colAvatarUrl, 'TEXT');
  } catch (e) {
    debugPrint('v27 migration failed (silent fallback): $e');
  }
}
```

（`_onCreate` 中 `user_profile` 建表 SQL 同样加这 8 列，保持新装一致。）

- [ ] **Step 4: 扩展 ProfileData 模型**

`profile_models.dart` 增加字段、构造可选参、`copyWith`、`fromJson`/`toJson`（用 `const` 与命名参数，无 records）。示例新增字段与序列化：

```dart
  final String? gender;
  final List<String> favoriteCategories;
  final List<String> painPoints;
  final String? skillLevel;
  final List<String> expectations;
  final List<String> commonScenes;
  final String? shootFrequency;
  final String? avatarUrl;
```

（`toJson`/`fromJson` 用与 JSON key：`gender`、`favoriteCategories`、`painPoints`、`skillLevel`、`expectations`、`commonScenes`、`shootFrequency`、`avatarUrl`。）

- [ ] **Step 5: BuiltinProfiles 头像解析**

`builtin_profiles.dart` 增加/改 `avatarUrl(seed, {String? customUrl})`：`customUrl` 非空返回 `customUrl`，否则返回既有 picsum seed URL。

- [ ] **Step 6: ProfileDao 读写新列**

`profile_dao.dart` 改为使用上述新列常量，`get()` 读取（缺失/空字符串→null/空数组），`upsert()` 写入；单行 ID 仍为 1。

- [ ] **Step 7: ProfileRepository + uploadAvatar**

`profile_repository.dart`：
- `update(...)` 参数扩展为可选 `username, avatarSeed, gender, favoriteCategories, painPoints, skillLevel, expectations, commonScenes, shootFrequency, avatarUrl`，构造 PATCH body（仅包含非 null 项，沿用 camelCase key）。
- 新增 `Future<String> uploadAvatarBytes(Uint8List bytes, String filename)`：`multipartPost('/profile/avatar', fieldName: 'avatar', bytes, filename)`，解析 `{ avatarUrl }`。

> 若 `RemoteProfileRepository` 走自定义 `ApiClient`，先读 `ApiClient` 是否有 multipart 上传方法；没有则参照反馈上传实现新增泛型 `multipartPost`。

- [ ] **Step 8: ProfileSyncService 透传**

`profile_sync_service.dart` 的 `save(...)` 与 `syncPendingIfNeeded()` 补传逻辑透传全部新字段，并加入 `uploadAvatar(...)` 透传。

- [ ] **Step 9: 更新/新增单测**

在 `profile_sync_service_test.dart`、`profile_dao_test.dart` 各新增用例：序列化往返、新字段透传、`avatarUrl` 优先解析、v27 旧库迁移不崩（用 sqflite 内存库 `onConfigure`/`onUpgrade` 模拟）。

- [ ] **Step 10: Flutter 测试通过**

Run: `cd lumira_app_flutter && flutter test`
Expected: 全部单测 PASS。

- [ ] **Step 11: 提交**

```bash
git add lumira_app_flutter/lib/core/db/tables.dart
git add lumira_app_flutter/lib/core/db/database_provider.dart
git add lumira_app_flutter/lib/features/profile
git add lumira_app_flutter/test/features/profile/profile_sync_service_test.dart
git add lumira_app_flutter/test/core/db/profile_dao_test.dart
git commit -m "feat(flutter): 资料模型/DAO/仓库/同步扩展性别·偏好·自定义头像"
```

---

### Task 5: Flutter — 问卷新增性别 + 提交联动个人资料

**Files:**
- Modify: `lumira_app_flutter/lib/features/onboarding/data/questionnaire_answers.dart`
- Modify: `lumira_app_flutter/lib/features/onboarding/data/questionnaire_data.dart`
- Modify: `lumira_app_flutter/lib/features/onboarding/pages/questionnaire_page.dart`
- Modify: `lumira_app_flutter/lib/features/onboarding/services/questionnaire_sync_providers.dart`
- Test: `lumira_app_flutter/test/features/onboarding/questionnaire_answers_test.dart`（若有）

**Interfaces:**
- Consumes：Task 1/4 的 `ProfileData` 新字段与 `ProfileSyncService.save(...)`。
- Produces：`QuestionnaireAnswers.gender`；问卷定义首问加"性别"；提交时把 gender+6 项偏好合并进本地 `ProfileData` 并 `save`。

- [ ] **Step 1: QuestionnaireAnswers 加 gender**

`questionnaire_answers.dart`：字段 `String? gender`；构造、`empty()`、`fromJson`(`json['gender']`)、`toJson`(`'gender': gender`)、`toJsonString` 不变；`isAllSkipped` 增加 `gender == null &&` 判断。

- [ ] **Step 2: 问卷定义加性别首问**

`questionnaire_data.dart` 的 `QuestionDef` 列表开头插入性别题（`key: 'gender'`，单选，选项 `male/female/prefer_not`，沿用现有 QuestionDef 结构与样式字段）。确认 `source` 题仍保留（仅用于问卷分析）。

- [ ] **Step 3: 提交时映射并联动资料**

`questionnaire_page.dart` 组装 `QuestionnaireAnswers` 处加入 `gender`；在 `submit` 成功（或本地落库）后，读取当前 `profileDataProvider`，`copyWith(gender: ans.gender, favoriteCategories: ans.favoriteCategories, painPoints: ans.painPoints, skillLevel: ans.skillLevel, expectations: ans.expectations, commonScenes: ans.commonScenes, shootFrequency: ans.shootFrequency)`，调用 `profileSyncService.save(updated)`（触发本地写入 + PATCH 补传）。

- [ ] **Step 4: providers 导出新增**

`questionnaire_sync_providers.dart` 若需新增 provider 访问 `profileSyncServiceProvider`，直接在页面 `ConsumerWidget` 中 `ref.read(profileSyncServiceProvider.future)`。

- [ ] **Step 5: Flutter 测试通过**

Run: `flutter test`
Expected: 新增/既有用例 PASS（gender 序列化、提交联动资料）。

- [ ] **Step 6: 提交**

```bash
git add lumira_app_flutter/lib/features/onboarding
git commit -m "feat(flutter): 问卷新增性别首问并提交后同步个人偏好"
```

---

### Task 6: Flutter — 编辑资料页扩展（性别 + 6 项偏好 + 自定义头像）

**Files:**
- Modify: `lumira_app_flutter/lib/features/profile/pages/profile_edit_page.dart`
- Create（若需）：`lumira_app_flutter/lib/features/profile/widgets/pref_selector.dart`
- Modify: `lumira_app_flutter/test/features/profile/profile_edit_page_test.dart`（若有）

**Interfaces:**
- Consumes：Task 4 的 `ProfileData`/`ProfileSyncService.save`/`uploadAvatarBytes`；现有头像 seed 选择逻辑。
- Produces：`PrefSelector` widget（复用）支持单选/多选，`optionKey`→中文 label 映射；`ProfileEditPage` 保存调用 `save(updatedProfile)`。

- [ ] **Step 1: 读现有编辑页**

读取 `profile_edit_page.dart`，记录当前头像 seed 选择 + 用户名 + 保存逻辑与 provider 用法，尽量复用样式。

- [ ] **Step 2: 新增偏好选择组件与文案映射**

新增 `pref_selector.dart`，包含 `Map<String,String>` label 常量（gender、favoriteCategories、painPoints、skillLevel、expectations、commonScenes、shootFrequency）与单选/多选组件（沿用问卷 pill/卡片的主题样式）。

- [ ] **Step 3: 编辑页接入字段**

在编辑页加入：性别单选、6 项偏好（多选/单选按字段类型）、头像区增加"上传自定义头像"入口（`uploadAvatarBytes`，上传中 loading，成功后 `copyWith(avatarUrl: url)` 并 `save`）与"恢复内置头像"（`copyWith(avatarUrl: null)`）。所有提交统一走 `ProfileSyncService.save(updated)`。

- [ ] **Step 4: 保存刷新**

保存成功后 `ref.invalidate(profileDataProvider)`，使主页/摘要立即刷新。

- [ ] **Step 5: Flutter 测试通过**

Run: `flutter test`
Expected: PASS。

- [ ] **Step 6: 提交**

```bash
git add lumira_app_flutter/lib/features/profile
git commit -m "feat(flutter): 编辑资料页新增性别/6项偏好/自定义头像"
```

---

### Task 7: Flutter — 个人中心完善 + 移除设置问卷入口

**Files:**
- Modify: `lumira_app_flutter/lib/features/profile/pages/profile_page.dart`（HeroCard/头像预览/偏好摘要卡）
- Modify: `lumira_app_flutter/lib/features/profile/pages/profile_settings_page.dart`（移除"偏好问卷"入口）
- Modify: `lumira_app_flutter/test/features/profile/profile_page_test.dart`
- Modify: `lumira_app_flutter/test/features/profile/profile_settings_page_test.dart`

**Interfaces:**
- Consumes：Task 4 的 `ProfileData` 新字段与 `BuiltinProfiles.avatarUrl(seed, customUrl:)`；既有 profile 相关 widget 结构。

- [ ] **Step 1: 头像显示与预览**

`profile_page.dart` 头像改用 `BuiltinProfiles.avatarUrl(seed, customUrl: profile.avatarUrl)`；点击头像打开大图预览（`showDialog`/`Navigator` 展示原图），点击旁入口进入编辑页。

- [ ] **Step 2: 新增偏好摘要卡片**

在主页新增"摄影偏好"摘要卡：性别、摄影水平、常用场景、拍摄频率等已填项（用 `profile_pref_options` 中文 label 映射）；未填项显示引导文案"前往完善摄影偏好"；点击进入编辑资料页。复用既有 `ContentCard`/`MenuCard` 卡片样式保持统一。

- [ ] **Step 3: 移除设置页问卷入口**

`profile_settings_page.dart` 删除"偏好问卷/问卷调查"相关的 `_SettingItem`（及 `fromSettings` 跳转调用）。

- [ ] **Step 4: 更新测试**

同步 `profile_page_test.dart`/`profile_settings_page_test.dart` 断言（头像 customUrl 分支、偏好摘要卡片条件显示、设置页无问卷入口）。

- [ ] **Step 5: Flutter 测试通过 + 手动验证清单**

Run: `flutter test`
Expected: PASS。手动：新设备首启见问卷（含性别首问）→ 提交后主页显示偏好；编辑页改偏好只改 user_profiles；上传/恢复内置头像；设置页无"偏好问卷"入口；主页头像大图预览。

- [ ] **Step 6: 提交**

```bash
git add lumira_app_flutter/lib/features/profile
git add lumira_app_flutter/test/features/profile
git commit -m "feat(flutter): 个人中心展示性别/偏好摘要与头像预览，移除设置问卷入口"
```

---

## 计划自审结论

- **Spec 覆盖**：性别入问卷(Task3/5)、问卷仅首次使用且在设置移除(Task7)、个人中心可改性别+6项偏好(Task6/7)、头像上传后端保存+自定义(Task2/6/7)、名称/性别等同步数据库(Task1/2/4)、偏好摘要展示(Task7) —— 均有对应任务。
- **数据隔离**：问卷只写 `questionnaire_records`；偏好只写 `user_profiles`；问卷提交时单向同步到 profile（Task3/5），个人中心编辑不回改问卷（Task1 updateProfile 与 mergeQuestionnairePrefs 分离）。
- **无占位符**：每个可执行步骤均给出文件路径与代码/命令。
- **类型一致性**：profile 模块 camelCase、问卷 snake_case 两套约定已分别标注；`Gender`、6 项偏好 key 在 task 间保持一致。