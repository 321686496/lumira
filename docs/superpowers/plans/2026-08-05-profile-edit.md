# 个人信息修改功能实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为「我的」页新增用户名+头像编辑能力：用户资料随设备 ID 存后端，首次注册自动分配默认资料，可编辑用户名/头像（内置 picsum 头像池 + 中文诗意昵称池），离线优先双写同步。

**Architecture:** 后端新增 `user_profiles` 表与 `ProfileModule`（GET/PATCH /profile），`POST /device/register` 响应扩展返回 profile；Flutter 端新增本地单行表 `user_profile`（v15 迁移）+ DAO + Repository + SyncService（仿问卷功能模式），「我的」页 HeroCard 接入真实资料并可点击进入编辑页。

**Tech Stack:** NestJS + Fastify + Drizzle ORM + SQLite（后端）；Flutter 3.7.12 / Dart 2.19.6 + Riverpod + sqflite（客户端）。

## Global Constraints

- Dart 2.19.6：**不支持 records 语法**（`({String a})`），用简单类代替
- 所有 UI 颜色只用 `ThemeTokens`（`tokens.brand/brandSubtle/brandLight/textPrimary/textSecondary/textTertiary/surface/surfaceAlt/divider/canvas`），**不新增自定义色值**（HeroCard 金色角标除外，沿用现有硬编码 `0xFFC9A96E→0xFFA88550` 渐变）
- 所有 UI 组件走 4 风格分支：使用 `NeuCard` / `LumiraTextField` / `LumiraButton` / `LumiraNav` / `GlassBackground`，通过 `appThemeProvider` 渲染
- 头像 URL 固定格式：`https://picsum.photos/seed/{seed}/200/200`
- 昵称池与头像池：前后端各维护一份**完全一致**的列表（常量），24 个昵称 + 8 个 seed
- 数据库迁移必须幂等（`CREATE TABLE IF NOT EXISTS` + `_addColumnIfNotExists`）
- 每个任务 commit 时只 `git add` 本任务涉及的文件（工作区可能有其他会话的未提交改动）
- 后端表名/列名与 shared 类型字段命名遵循现有 snake_case（列）/ camelCase（TS 接口）约定

---

### Task 1: 后端共享类型 + user_profiles 表 + 常量池 + register 返回 profile

**Files:**
- Modify: `lumira-server/packages/shared/src/types/device.ts`
- Modify: `lumira-server/packages/backend/src/database/schema.ts`
- Create: `lumira-server/packages/backend/src/modules/profile/profile-constants.ts`
- Modify: `lumira-server/packages/backend/src/modules/device/device.service.ts`
- Modify: `lumira-server/packages/backend/test/device.e2e-spec.ts`

**Interfaces:**
- Produces: shared `UserProfile` 接口 `{ username: string; avatarSeed: string }`；`RegisterDeviceResponse` 增加 `profile: UserProfile`；`userProfiles` 表（`deviceId/username/avatarSeed/updatedAt`）；常量池 `BUILTIN_AVATAR_SEEDS`(8) / `BUILTIN_USERNAMES`(24) / `randomPick<T>(arr)`——Task 2 的 ProfileModule 与后续 Flutter 端依赖
- 注意：Task 1 中 DeviceService 直接内联 `getOrCreateProfile` 私有方法（不依赖 ProfileModule，避免 Task 2 完成前引用不存在模块）；Task 2 完成后 ProfileService 提供同逻辑供复用

- [ ] **Step 1: 更新共享类型 `device.ts`**

```ts
export interface UserProfile {
  username: string;
  avatarSeed: string;
}

export interface RegisterDeviceResponse {
  token: string;
  isNewDevice: boolean;
  profile: UserProfile;
}
```

- [ ] **Step 2: 更新 `schema.ts` 新增 user_profiles 表**

在 `devices` 表定义之后追加：

```ts
export const userProfiles = sqliteTable('user_profiles', {
  deviceId: text('device_id').primaryKey().references(() => devices.deviceId),
  username: text('username').notNull(),
  avatarSeed: text('avatar_seed').notNull(),
  updatedAt: integer('updated_at').notNull(),
});
```

并确认 `database.service.ts` 的 drizzle schema 注册对象中包含 `userProfiles`（查看该文件中 `drizzle(db, { schema })` 的 schema 对象，若为逐字段列举则补充）。

- [ ] **Step 3: 新建常量池 `profile-constants.ts`**

```ts
// lumira-server/packages/backend/src/modules/profile/profile-constants.ts
// 内置头像 seed 池（与 Flutter 端 builtin_profiles.dart 保持一致，8 个）
export const BUILTIN_AVATAR_SEEDS = [
  'lumira-avatar-01', 'lumira-avatar-02', 'lumira-avatar-03', 'lumira-avatar-04',
  'lumira-avatar-05', 'lumira-avatar-06', 'lumira-avatar-07', 'lumira-avatar-08',
];

// 内置昵称池（与 Flutter 端 builtin_profiles.dart 保持一致，24 个）
export const BUILTIN_USERNAMES = [
  '追光的小鹿', '胶片旅人', '云边记录者', '晚风摄影师',
  '拾光少女', '光影漫游者', '春日快门', '银河捕手',
  '晨雾漫游', '暮色收藏家', '窗边诗人', '胶片收藏家',
  '星野旅人', '海盐汽水', '青柠快门', '山间清风',
  '雨后晴天', '微光日记', '星河漫游者', '温柔捕光者',
  '麦田守望者', '旧巷拾影', '月亮邮差', '森林呼吸',
];

export function randomPick<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}
```

- [ ] **Step 4: 扩展 `device.service.ts` 返回 profile**

```ts
import { eq } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { devices, userProfiles } from '../../database/schema';
import { BUILTIN_AVATAR_SEEDS, BUILTIN_USERNAMES, randomPick } from '../profile/profile-constants';

// registerDevice 内：
if (existing) {
  await db.update(devices).set({ lastSeenAt: now }).where(eq(devices.deviceId, deviceId));
  const token = this.jwtService.sign({ deviceId });
  const profile = await this.getOrCreateProfile(deviceId);
  return { token, isNewDevice: false, profile };
}

await db.insert(devices).values({ deviceId, alias: alias || null, firstSeenAt: now, lastSeenAt: now, ipRegion: ip });
const token = this.jwtService.sign({ deviceId });
const profile = await this.getOrCreateProfile(deviceId);
return { token, isNewDevice: true, profile };

// 新增私有方法：
private async getOrCreateProfile(deviceId: string) {
  const db = this.dbService.getDb();
  const existing = await db.query.userProfiles.findFirst({ where: eq(userProfiles.deviceId, deviceId) });
  if (existing) return { username: existing.username, avatarSeed: existing.avatarSeed };
  const username = randomPick(BUILTIN_USERNAMES);
  const avatarSeed = randomPick(BUILTIN_AVATAR_SEEDS);
  await db.insert(userProfiles).values({
    deviceId, username, avatarSeed, updatedAt: Math.floor(Date.now() / 1000),
  });
  return { username, avatarSeed };
}
```

- [ ] **Step 5: 更新 `device.e2e-spec.ts` 断言 profile**

在 `POST /api/v1/device/register — should register a new device` 测试中追加：

```ts
expect(res.body.profile).toBeDefined();
expect(res.body.profile.username).toBeTruthy();
expect(res.body.profile.avatarSeed).toBeTruthy();
```

在 re-registration 测试中追加 `expect(res.body.profile).toBeDefined();`。

- [ ] **Step 6: 运行 e2e 验证**

Run: `cd lumira-server && pnpm --filter backend test:e2e -- device.e2e-spec`
Expected: device e2e 全部 PASS

- [ ] **Step 7: Commit**

```bash
git add lumira-server/packages/shared/src/types/device.ts lumira-server/packages/backend/src/database/schema.ts lumira-server/packages/backend/src/modules/profile/profile-constants.ts lumira-server/packages/backend/src/modules/device/device.service.ts lumira-server/packages/backend/test/device.e2e-spec.ts
git commit -m "feat(backend): add user_profiles table and return profile on device register"
```

---

### Task 2: 后端 ProfileModule（GET/PATCH /profile）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/profile/profile.module.ts`
- Create: `lumira-server/packages/backend/src/modules/profile/profile.controller.ts`
- Create: `lumira-server/packages/backend/src/modules/profile/profile.service.ts`
- Create: `lumira-server/packages/backend/src/modules/profile/dto/update-profile.dto.ts`
- Modify: `lumira-server/packages/backend/src/app.module.ts`
- Modify: `lumira-server/packages/backend/src/modules/device/device.module.ts`
- Modify: `lumira-server/packages/backend/src/modules/device/device.service.ts`（改用 ProfileService）
- Create: `lumira-server/packages/backend/test/profile.e2e-spec.ts`

**Interfaces:**
- Consumes: Task 1 的 `userProfiles` 表、`BUILTIN_USERNAMES`/`BUILTIN_AVATAR_SEEDS`/`randomPick`、shared `UserProfile`
- Produces: `ProfileService.getOrCreateProfile(deviceId): Promise<{username, avatarSeed}>`、`ProfileService.updateProfile(deviceId, patch)`；`ProfileModule`（exports ProfileService）——Task 1 的 DeviceService 改造为注入 `ProfileService`

- [ ] **Step 1: 先写 e2e 测试 `profile.e2e-spec.ts`**（仿 `device.e2e-spec.ts` 结构：`DB_PATH=':memory:'`、`JWT_SECRET='test-secret'`、`app.setGlobalPrefix('api/v1')`）

```ts
import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import request from 'supertest';

describe('ProfileController (e2e)', () => {
  let app: NestFastifyApplication;
  const testDeviceId = 'profile-e2e-device-0001';

  beforeAll(async () => {
    process.env.DB_PATH = ':memory:';
    process.env.JWT_SECRET = 'test-secret';
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication<NestFastifyApplication>(new FastifyAdapter());
    app.setGlobalPrefix('api/v1');
    await app.init();
    await app.getHttpAdapter().getInstance().ready();
  });

  afterAll(async () => app.close());

  const register = () => request(app.getHttpServer())
    .post('/api/v1/device/register')
    .send({ deviceId: testDeviceId });

  it('GET /api/v1/profile returns default profile after register', async () => {
    const reg = await register().expect(201);
    const token = reg.body.token as string;
    const res = await request(app.getHttpServer())
      .get('/api/v1/profile')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(res.body.username).toBe(reg.body.profile.username);
    expect(res.body.avatarSeed).toBe(reg.body.profile.avatarSeed);
  });

  it('GET /api/v1/profile rejects without token', async () => {
    await request(app.getHttpServer()).get('/api/v1/profile').expect(401);
  });

  it('PATCH /api/v1/profile updates username and avatarSeed', async () => {
    const reg = await register().expect(201);
    const token = reg.body.token as string;
    const res = await request(app.getHttpServer())
      .patch('/api/v1/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({ username: '新昵称', avatarSeed: 'lumira-avatar-03' })
      .expect(200);
    expect(res.body.username).toBe('新昵称');
    expect(res.body.avatarSeed).toBe('lumira-avatar-03');
  });

  it('PATCH /api/v1/profile rejects empty username', async () => {
    const reg = await register().expect(201);
    const token = reg.body.token as string;
    await request(app.getHttpServer())
      .patch('/api/v1/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({ username: '' })
      .expect(400);
  });

  it('PATCH /api/v1/profile rejects username longer than 20 chars', async () => {
    const reg = await register().expect(201);
    const token = reg.body.token as string;
    await request(app.getHttpServer())
      .patch('/api/v1/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({ username: '啊'.repeat(21) })
      .expect(400);
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd lumira-server && pnpm --filter backend test:e2e -- profile.e2e-spec`
Expected: FAIL（模块不存在 / 404）

- [ ] **Step 3: 实现 ProfileService**

```ts
// profile.service.ts
import { Injectable } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { userProfiles } from '../../database/schema';
import { BUILTIN_AVATAR_SEEDS, BUILTIN_USERNAMES, randomPick } from './profile-constants';

@Injectable()
export class ProfileService {
  constructor(private readonly dbService: DatabaseService) {}

  async getOrCreateProfile(deviceId: string) {
    const db = this.dbService.getDb();
    const existing = await db.query.userProfiles.findFirst({ where: eq(userProfiles.deviceId, deviceId) });
    if (existing) return { username: existing.username, avatarSeed: existing.avatarSeed };
    const username = randomPick(BUILTIN_USERNAMES);
    const avatarSeed = randomPick(BUILTIN_AVATAR_SEEDS);
    await db.insert(userProfiles).values({ deviceId, username, avatarSeed, updatedAt: Math.floor(Date.now() / 1000) });
    return { username, avatarSeed };
  }

  async updateProfile(deviceId: string, patch: { username?: string; avatarSeed?: string }) {
    const db = this.dbService.getDb();
    await this.getOrCreateProfile(deviceId);
    const rows = await db.select().from(userProfiles).where(eq(userProfiles.deviceId, deviceId));
    const updated = {
      username: patch.username ?? rows[0].username,
      avatarSeed: patch.avatarSeed ?? rows[0].avatarSeed,
      updatedAt: Math.floor(Date.now() / 1000),
    };
    await db.update(userProfiles).set(updated).where(eq(userProfiles.deviceId, deviceId));
    return { username: updated.username, avatarSeed: updated.avatarSeed };
  }
}
```

- [ ] **Step 4: 实现 DTO / Controller / Module**

```ts
// dto/update-profile.dto.ts
import { IsOptional, IsString, MinLength, MaxLength } from 'class-validator';

export class UpdateProfileDto {
  @IsOptional() @IsString() @MinLength(1) @MaxLength(20)
  username?: string;

  @IsOptional() @IsString() @MinLength(1) @MaxLength(64)
  avatarSeed?: string;
}
```

```ts
// profile.controller.ts
import { Controller, Get, Patch, Body, UseGuards } from '@nestjs/common';
import { ProfileService } from './profile.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { DeviceId } from '../../common/decorators';

@Controller('profile')
@UseGuards(DeviceAuthGuard)
export class ProfileController {
  constructor(private readonly profileService: ProfileService) {}

  @Get()
  async get(@DeviceId() deviceId: string) {
    return this.profileService.getOrCreateProfile(deviceId);
  }

  @Patch()
  async update(@DeviceId() deviceId: string, @Body() dto: UpdateProfileDto) {
    return this.profileService.updateProfile(deviceId, dto);
  }
}
```

```ts
// profile.module.ts
import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { ProfileController } from './profile.controller';
import { ProfileService } from './profile.service';

@Module({
  imports: [DatabaseModule],
  controllers: [ProfileController],
  providers: [ProfileService],
  exports: [ProfileService],
})
export class ProfileModule {}
```

- [ ] **Step 5: 注册模块 + 改造 DeviceService 复用 ProfileService**

`app.module.ts`：imports 数组追加 `ProfileModule`。

`device.module.ts`：imports 追加 `ProfileModule`。

`device.service.ts` 改造：构造函数注入 `ProfileService`，删除 Task 1 的私有 `getOrCreateProfile`，`registerDevice` 中调用 `this.profileService.getOrCreateProfile(deviceId)`（同时移除不再使用的 `userProfiles`、`BUILTIN_*`、`randomPick` import，保留 `devices`/`eq`）。

- [ ] **Step 6: 运行 e2e 验证**

Run: `cd lumira-server && pnpm --filter backend test:e2e`
Expected: 全部 PASS（profile + device e2e）

- [ ] **Step 7: Commit**

```bash
git add lumira-server/packages/backend/src/modules/profile lumira-server/packages/backend/src/app.module.ts lumira-server/packages/backend/src/modules/device/device.module.ts lumira-server/packages/backend/src/modules/device/device.service.ts lumira-server/packages/backend/test/profile.e2e-spec.ts
git commit -m "feat(backend): add profile module with GET/PATCH /profile endpoints"
```

---

### Task 3: Flutter 数据层（表/迁移/模型/常量池/DAO）

**Files:**
- Modify: `lumira_app_flutter/lib/core/db/tables.dart`
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart`
- Create: `lumira_app_flutter/lib/features/profile/data/profile_models.dart`
- Create: `lumira_app_flutter/lib/features/profile/data/builtin_profiles.dart`
- Create: `lumira_app_flutter/lib/features/profile/data/profile_dao.dart`
- Create: `lumira_app_flutter/test/core/db/profile_dao_test.dart`
- Create: `lumira_app_flutter/test/core/db/migration_v15_test.dart`

**Interfaces:**
- Produces: `ProfileData { username, avatarSeed, syncedAt? }`（`fromJson/toJson`，Dart 2.19 简单类）；`BuiltinProfiles.avatarSeeds`(8)/`BuiltinProfiles.usernames`(24)/`BuiltinProfiles.avatarUrl(seed)`；`UserProfileDao.get()/upsert(ProfileData, int updatedAt)/markSynced(int)/hasUnsynced()`；`Tables.userProfile/colUsername/colAvatarSeed/colSyncedAt`；`profileDaoProvider`——Task 4/5/6 依赖
- 注意：`updated_at` 复用现有 `Tables.colUpdatedAt`

- [ ] **Step 1: `tables.dart` 增加 user_profile 表常量**

在 questionnaire 段后追加：

```dart
// === user_profile 表（v15 迁移新增，单行表 id=1） ===
static const String userProfile = 'user_profile';
static const String colUsername = 'username';
static const String colAvatarSeed = 'avatar_seed';
static const String colSyncedAt = 'synced_at';
```

- [ ] **Step 2: `database_provider.dart` v15 迁移**

- `_kDbVersion = 15`
- `_onCreate` 末尾（questionnaire 建表后）追加：

```dart
// === v15: user_profile 表（单行表 id=1，个人资料本地副本） ===
await db.execute('''
  CREATE TABLE IF NOT EXISTS ${Tables.userProfile} (
    ${Tables.colId} INTEGER PRIMARY KEY DEFAULT 1,
    ${Tables.colUsername} TEXT NOT NULL,
    ${Tables.colAvatarSeed} TEXT NOT NULL,
    ${Tables.colUpdatedAt} INTEGER NOT NULL,
    ${Tables.colSyncedAt} INTEGER
  )
''');
```

- `_onUpgrade` 追加分支（questionnaire v12 分支后）：

```dart
if (oldVersion < 15) {
  try {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.userProfile} (
        ${Tables.colId} INTEGER PRIMARY KEY DEFAULT 1,
        ${Tables.colUsername} TEXT NOT NULL,
        ${Tables.colAvatarSeed} TEXT NOT NULL,
        ${Tables.colUpdatedAt} INTEGER NOT NULL,
        ${Tables.colSyncedAt} INTEGER
      )
    ''');
  } catch (e) {
    debugPrint('v15 migration failed (silent fallback): $e');
  }
}
```

- 新增 Provider（文件末尾）：

```dart
final userProfileDaoProvider = FutureProvider<UserProfileDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return UserProfileDao(db);
});
```

- [ ] **Step 3: 新建 `profile_models.dart`**

```dart
import 'package:flutter/foundation.dart';

/// 个人资料（用户名 + 头像 seed，随设备存储）
@immutable
class ProfileData {
  final String username;
  final String avatarSeed;

  /// 上次成功同步时间戳（秒），null 表示待同步
  final int? syncedAt;

  const ProfileData({
    required this.username,
    required this.avatarSeed,
    this.syncedAt,
  });

  factory ProfileData.fromJson(Map<String, dynamic> j) {
    return ProfileData(
      username: (j['username'] as String?) ?? '',
      avatarSeed: (j['avatarSeed'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        'avatarSeed': avatarSeed,
      };

  ProfileData copyWith({String? username, String? avatarSeed, int? syncedAt}) {
    return ProfileData(
      username: username ?? this.username,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}
```

- [ ] **Step 4: 新建 `builtin_profiles.dart`**（与后端 profile-constants.ts 完全一致）

```dart
/// 系统内置头像池与昵称池（与后端 profile-constants.ts 保持一致）
class BuiltinProfiles {
  BuiltinProfiles._();

  /// 内置头像 seed 池（8 个）
  static const List<String> avatarSeeds = [
    'lumira-avatar-01', 'lumira-avatar-02', 'lumira-avatar-03', 'lumira-avatar-04',
    'lumira-avatar-05', 'lumira-avatar-06', 'lumira-avatar-07', 'lumira-avatar-08',
  ];

  /// 内置昵称池（24 个中文诗意昵称）
  static const List<String> usernames = [
    '追光的小鹿', '胶片旅人', '云边记录者', '晚风摄影师',
    '拾光少女', '光影漫游者', '春日快门', '银河捕手',
    '晨雾漫游', '暮色收藏家', '窗边诗人', '胶片收藏家',
    '星野旅人', '海盐汽水', '青柠快门', '山间清风',
    '雨后晴天', '微光日记', '星河漫游者', '温柔捕光者',
    '麦田守望者', '旧巷拾影', '月亮邮差', '森林呼吸',
  ];

  /// 根据 seed 拼出头像 URL
  static String avatarUrl(String seed) =>
      'https://picsum.photos/seed/$seed/200/200';
}
```

- [ ] **Step 5: 新建 `profile_dao.dart`**（仿 QuestionnaireDao）

```dart
import 'package:sqflite/sqflite.dart';

import '../../../core/db/tables.dart';
import 'profile_models.dart';

/// 个人资料 DAO（单行表 user_profile，id=1）
class UserProfileDao {
  UserProfileDao(this._db);

  final Database _db;

  /// 读取本地资料（无记录返回 null）
  Future<ProfileData?> get() async {
    final rows = await _db.query(
      Tables.userProfile,
      where: '${Tables.colId} = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final username = row[Tables.colUsername] as String? ?? '';
    final avatarSeed = row[Tables.colAvatarSeed] as String? ?? '';
    if (username.isEmpty && avatarSeed.isEmpty) return null;
    return ProfileData(
      username: username,
      avatarSeed: avatarSeed,
      syncedAt: row[Tables.colSyncedAt] as int?,
    );
  }

  /// 写入资料（覆盖单行）
  Future<void> upsert(ProfileData profile, int updatedAt) async {
    await _db.insert(
      Tables.userProfile,
      {
        Tables.colId: 1,
        Tables.colUsername: profile.username,
        Tables.colAvatarSeed: profile.avatarSeed,
        Tables.colUpdatedAt: updatedAt,
        Tables.colSyncedAt: null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 标记已同步
  Future<void> markSynced(int syncedAt) async {
    await _db.update(
      Tables.userProfile,
      {Tables.colSyncedAt: syncedAt},
      where: '${Tables.colId} = ?',
      whereArgs: [1],
    );
  }

  /// 是否有待同步的本地修改（无记录返回 false）
  Future<bool> hasUnsynced() async {
    final rows = await _db.query(
      Tables.userProfile,
      columns: [Tables.colSyncedAt],
      where: '${Tables.colId} = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return false;
    return rows.first[Tables.colSyncedAt] == null;
  }
}
```

- [ ] **Step 6: 新建 `profile_dao_test.dart`**（用 sqflite_common_ffi，参照 dao_test.dart 的 `sqfliteFfiInit(); databaseFactory = databaseFactoryFfi;` 与 `inMemoryDatabasePath`）

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:lumira_app_flutter/features/profile/data/profile_dao.dart';
import 'package:lumira_app_flutter/features/profile/data/profile_models.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late UserProfileDao dao;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE user_profile (
            id INTEGER PRIMARY KEY DEFAULT 1,
            username TEXT NOT NULL,
            avatar_seed TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            synced_at INTEGER
          )
        ''');
      },
    );
    dao = UserProfileDao(db);
  });

  tearDown(() async => db.close());

  const profile = ProfileData(username: '测试昵称', avatarSeed: 'lumira-avatar-01');

  test('get returns null when no record', () async {
    expect(await dao.get(), isNull);
  });

  test('upsert then get returns profile', () async {
    await dao.upsert(profile, 1700000000);
    final loaded = await dao.get();
    expect(loaded, isNotNull);
    expect(loaded!.username, '测试昵称');
    expect(loaded.avatarSeed, 'lumira-avatar-01');
    expect(loaded.syncedAt, isNull);
  });

  test('upsert overwrites existing row (single row)', () async {
    await dao.upsert(profile, 1700000000);
    await dao.upsert(const ProfileData(username: '新昵称', avatarSeed: 'lumira-avatar-02'), 1700000001);
    final rows = await db.query('user_profile');
    expect(rows.length, 1);
    final loaded = await dao.get();
    expect(loaded!.username, '新昵称');
    expect(loaded.avatarSeed, 'lumira-avatar-02');
  });

  test('hasUnsynced is false after markSynced', () async {
    await dao.upsert(profile, 1700000000);
    expect(await dao.hasUnsynced(), isTrue);
    await dao.markSynced(1700000100);
    expect(await dao.hasUnsynced(), isFalse);
    expect((await dao.get())!.syncedAt, 1700000100);
  });
}
```

- [ ] **Step 7: 新建 `migration_v15_test.dart`**（仿 migration_v5_test.dart：手写 onCreate + onUpgrade 只含 v15 分支，验证幂等与列结构）

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 15,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  });

  tearDown(() async => db.close());

  test('v15 migration creates user_profile table', () async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='user_profile'",
    );
    expect(tables.length, 1);

    final cols = await db.rawQuery('PRAGMA table_info(user_profile)');
    final colNames = cols.map((c) => c['name'] as String).toSet();
    expect(colNames, containsAll(['id', 'username', 'avatar_seed', 'updated_at', 'synced_at']));
  });

  test('user_profile table stores single row by id=1', () async {
    await db.insert('user_profile', {
      'id': 1,
      'username': '默认昵称',
      'avatar_seed': 'lumira-avatar-01',
      'updated_at': 1700000000,
      'synced_at': null,
    });
    final rows = await db.query('user_profile');
    expect(rows.length, 1);
    expect(rows.first['username'], '默认昵称');
  });
}

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS user_profile (
      id INTEGER PRIMARY KEY DEFAULT 1,
      username TEXT NOT NULL,
      avatar_seed TEXT NOT NULL,
      updated_at INTEGER NOT NULL,
      synced_at INTEGER
    )
  ''');
}

Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 15) {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile (
        id INTEGER PRIMARY KEY DEFAULT 1,
        username TEXT NOT NULL,
        avatar_seed TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        synced_at INTEGER
      )
    ''');
  }
}
```

- [ ] **Step 8: 运行测试**

Run: `cd lumira_app_flutter && flutter test test/core/db/profile_dao_test.dart test/core/db/migration_v15_test.dart`
Expected: 全部 PASS

- [ ] **Step 9: Commit**

```bash
git add lumira_app_flutter/lib/core/db/tables.dart lumira_app_flutter/lib/core/db/database_provider.dart lumira_app_flutter/lib/features/profile/data/profile_models.dart lumira_app_flutter/lib/features/profile/data/builtin_profiles.dart lumira_app_flutter/lib/features/profile/data/profile_dao.dart lumira_app_flutter/test/core/db/profile_dao_test.dart lumira_app_flutter/test/core/db/migration_v15_test.dart
git commit -m "feat(flutter): add local user_profile table, models and dao with v15 migration"
```

---

### Task 4: Flutter 网络层 + 同步服务 + providers

**Files:**
- Create: `lumira_app_flutter/lib/features/profile/data/profile_repository.dart`
- Create: `lumira_app_flutter/lib/features/profile/services/profile_sync_service.dart`
- Create: `lumira_app_flutter/lib/features/profile/providers/profile_providers.dart`
- Create: `lumira_app_flutter/test/features/profile/profile_sync_service_test.dart`

**Interfaces:**
- Consumes: Task 3 的 `ProfileData`/`UserProfileDao`/`BuiltinProfiles`；`ApiClient`（`core/network/api_client.dart`，需确认 `get`/`patch` 方法签名）
- Produces: `ProfileRepository`（抽象）`fetch()/update()` + `RemoteProfileRepository`；`ProfileSyncService.save(ProfileData)`/`syncPendingIfNeeded()`/`ensureLoadedIfMissing()`；`profileDaoProvider`/`profileRepositoryProvider`/`profileSyncServiceProvider`/`profileDataProvider`（FutureProvider<ProfileData?>）——Task 5 的 userProfileProvider/AuthController/main.dart 与 Task 6 编辑页依赖
- 注意：`profileRepositoryProvider` 声明放在 `profile_providers.dart`（勿在 `profile_repository.dart` 重复声明）

- [ ] **Step 1: 确认 `ApiClient` 的 `get`/`patch` 方法签名**

查看 `lumira_app_flutter/lib/core/network/api_client.dart` 中 `get`/`patch`（或 `request`）方法签名与 `ApiException` 定义，确保 Step 2/3 的调用方式匹配（如 `get(path, {fromJson})` / `patch(path, {body, fromJson})`；若为统一 `request` 方法则按实际签名调整）。

- [ ] **Step 2: 新建 `profile_repository.dart`**

```dart
import '../../../core/network/api_client.dart';
import 'profile_models.dart';

/// 个人资料 Repository 抽象
abstract class ProfileRepository {
  /// GET /profile，返回当前设备资料（后端无记录时懒创建默认）
  Future<ProfileData> fetch();

  /// PATCH /profile，更新资料并返回更新后结果
  Future<ProfileData> update({
    required String? username,
    required String? avatarSeed,
  });
}

/// 远程实现
class RemoteProfileRepository implements ProfileRepository {
  RemoteProfileRepository(this._api);

  final ApiClient _api;

  @override
  Future<ProfileData> fetch() {
    return _api.get(
      '/profile',
      fromJson: (j) => ProfileData.fromJson(j as Map<String, dynamic>),
    );
  }

  @override
  Future<ProfileData> update({
    required String? username,
    required String? avatarSeed,
  }) {
    return _api.patch(
      '/profile',
      body: {
        if (username != null) 'username': username,
        if (avatarSeed != null) 'avatarSeed': avatarSeed,
      },
      fromJson: (j) => ProfileData.fromJson(j as Map<String, dynamic>),
    );
  }
}
```

- [ ] **Step 3: 新建 `profile_sync_service.dart`**（仿 QuestionnaireSyncService）

```dart
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../data/profile_dao.dart';
import '../data/profile_models.dart';
import '../data/profile_repository.dart';

/// 资料保存结果
class ProfileSaveResult {
  final bool success;
  final bool synced;
  final String? error;
  const ProfileSaveResult({required this.success, required this.synced, this.error});
}

/// 个人资料同步服务
///
/// 离线优先：本地 sqflite 立即生效，再上报后端；网络失败不阻塞，标记待同步。
class ProfileSyncService {
  ProfileSyncService({
    required UserProfileDao dao,
    required ProfileRepository repository,
  })  : _dao = dao,
        _repo = repository;

  final UserProfileDao _dao;
  final ProfileRepository _repo;

  /// 保存资料：本地落库 → 上报后端
  Future<ProfileSaveResult> save(ProfileData profile) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _dao.upsert(profile, now);
    try {
      await _repo.update(username: profile.username, avatarSeed: profile.avatarSeed);
      await _dao.markSynced(now);
      return const ProfileSaveResult(success: true, synced: true);
    } on ApiException catch (e) {
      return ProfileSaveResult(success: true, synced: false, error: e.message);
    } catch (e) {
      return ProfileSaveResult(success: true, synced: false, error: e.toString());
    }
  }

  /// 首次拉取：本地无资料时从后端获取并落库（兼容已注册老设备）
  Future<void> ensureLoadedIfMissing() async {
    final local = await _dao.get();
    if (local != null) return;
    try {
      final remote = await _repo.fetch();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _dao.upsert(remote, now);
      await _dao.markSynced(now);
    } catch (_) {
      // 静默失败（如未注册无 token），下次启动再试
    }
  }

  /// 补传未同步的资料（App 启动时调用）
  Future<void> syncPendingIfNeeded() async {
    final hasUnsynced = await _dao.hasUnsynced();
    if (!hasUnsynced) return;
    final local = await _dao.get();
    if (local == null) return;
    try {
      await _repo.update(username: local.username, avatarSeed: local.avatarSeed);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _dao.markSynced(now);
    } catch (_) {
      // 静默失败，下次启动再试
    }
  }
}
```

- [ ] **Step 4: 新建 `profile_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/network/api_client.dart';
import '../data/profile_dao.dart';
import '../data/profile_models.dart';
import '../data/profile_repository.dart';
import '../services/profile_sync_service.dart';

final profileDaoProvider = FutureProvider<UserProfileDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return UserProfileDao(db);
});

final profileRepositoryProvider = FutureProvider<ProfileRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return RemoteProfileRepository(api);
});

final profileSyncServiceProvider = FutureProvider<ProfileSyncService>((ref) async {
  final dao = await ref.watch(profileDaoProvider.future);
  final repo = await ref.watch(profileRepositoryProvider.future);
  return ProfileSyncService(dao: dao, repository: repo);
});

/// 当前本地资料（null 表示尚未分配）
/// UI 通过 ref.watch 获取；保存/拉取后 ref.invalidate 刷新
final profileDataProvider = FutureProvider<ProfileData?>((ref) async {
  final dao = await ref.watch(profileDaoProvider.future);
  return dao.get();
});
```

- [ ] **Step 5: 新建 `profile_sync_service_test.dart`**（真 sqflite ffi DAO + FakeProfileRepository）

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:lumira_app_flutter/core/network/api_error.dart';
import 'package:lumira_app_flutter/features/profile/data/profile_dao.dart';
import 'package:lumira_app_flutter/features/profile/data/profile_models.dart';
import 'package:lumira_app_flutter/features/profile/data/profile_repository.dart';
import 'package:lumira_app_flutter/features/profile/services/profile_sync_service.dart';

class FakeProfileRepository implements ProfileRepository {
  ProfileData? remote;
  bool failUpdate = false;
  int updateCalls = 0;

  @override
  Future<ProfileData> fetch() async =>
      remote ?? const ProfileData(username: '远程默认', avatarSeed: 'lumira-avatar-01');

  @override
  Future<ProfileData> update({required String? username, required String? avatarSeed}) async {
    updateCalls++;
    if (failUpdate) throw const ApiException(message: 'network error');
    remote = ProfileData(
      username: username ?? remote!.username,
      avatarSeed: avatarSeed ?? remote!.avatarSeed,
    );
    return remote!;
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late UserProfileDao dao;
  late FakeProfileRepository repo;
  late ProfileSyncService sync;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE user_profile (
            id INTEGER PRIMARY KEY DEFAULT 1,
            username TEXT NOT NULL,
            avatar_seed TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            synced_at INTEGER
          )
        ''');
      },
    );
    dao = UserProfileDao(db);
    repo = FakeProfileRepository();
    sync = ProfileSyncService(dao: dao, repository: repo);
  });

  tearDown(() async => db.close());

  test('save persists locally and syncs to backend', () async {
    final result = await sync.save(const ProfileData(username: '新昵称', avatarSeed: 'lumira-avatar-02'));
    expect(result.success, isTrue);
    expect(result.synced, isTrue);
    expect(repo.updateCalls, 1);
    expect(repo.remote!.username, '新昵称');
    expect((await dao.get())!.syncedAt, isNotNull);
  });

  test('save keeps local when backend fails and marks unsynced', () async {
    repo.failUpdate = true;
    final result = await sync.save(const ProfileData(username: '离线昵称', avatarSeed: 'lumira-avatar-03'));
    expect(result.success, isTrue);
    expect(result.synced, isFalse);
    expect((await dao.get())!.username, '离线昵称');
    expect(await dao.hasUnsynced(), isTrue);
  });

  test('ensureLoadedIfMissing fetches from backend when local empty', () async {
    await sync.ensureLoadedIfMissing();
    final loaded = await dao.get();
    expect(loaded!.username, '远程默认');
    expect(await dao.hasUnsynced(), isFalse);
  });

  test('ensureLoadedIfMissing skips when local exists', () async {
    await dao.upsert(const ProfileData(username: '本地昵称', avatarSeed: 'lumira-avatar-01'), 1700000000);
    await sync.ensureLoadedIfMissing();
    expect((await dao.get())!.username, '本地昵称');
  });

  test('syncPendingIfNeeded retries unsynced changes', () async {
    repo.failUpdate = true;
    await sync.save(const ProfileData(username: '待同步', avatarSeed: 'lumira-avatar-04'));
    expect(await dao.hasUnsynced(), isTrue);
    repo.failUpdate = false;
    await sync.syncPendingIfNeeded();
    expect(await dao.hasUnsynced(), isFalse);
    expect(repo.remote!.username, '待同步');
  });
}
```

- [ ] **Step 6: 运行测试**

Run: `cd lumira_app_flutter && flutter test test/features/profile/profile_sync_service_test.dart`
Expected: 全部 PASS

- [ ] **Step 7: Commit**

```bash
git add lumira_app_flutter/lib/features/profile/data/profile_repository.dart lumira_app_flutter/lib/features/profile/services/profile_sync_service.dart lumira_app_flutter/lib/features/profile/providers/profile_providers.dart lumira_app_flutter/test/features/profile/profile_sync_service_test.dart
git commit -m "feat(flutter): add profile repository, offline-first sync service and providers"
```

---

### Task 5: Flutter 现有代码接入（注册响应/启动/聚合/路由）

**Files:**
- Modify: `lumira_app_flutter/lib/features/device/data/device_models.dart`
- Modify: `lumira_app_flutter/lib/core/auth/auth_controller.dart`
- Modify: `lumira_app_flutter/lib/main.dart`
- Modify: `lumira_app_flutter/lib/features/profile/providers/growth_providers.dart`
- Modify: `lumira_app_flutter/lib/core/router/route_names.dart`
- Modify: `lumira_app_flutter/lib/app/router.dart`

**Interfaces:**
- Consumes: Task 3 的 `ProfileData`/`UserProfileDao`、Task 4 的 `profileDataProvider`/`profileSyncServiceProvider`
- Produces: `RegisterDeviceResponse.profile`（`ProfileData?`）；`AuthController` 构造新增可选 `onRegistered` 回调；`userProfileProvider` 读真实资料；`RouteNames.profileEdit = '/profile/edit'`

- [ ] **Step 1: `device_models.dart` 扩展 RegisterDeviceResponse**

```dart
import '../../profile/data/profile_models.dart';

class RegisterDeviceResponse {
  final String token;
  final bool isNewDevice;
  final ProfileData? profile;

  const RegisterDeviceResponse({
    required this.token,
    required this.isNewDevice,
    this.profile,
  });

  factory RegisterDeviceResponse.fromJson(Map<String, dynamic> j) {
    final profileJson = j['profile'];
    return RegisterDeviceResponse(
      token: j['token'] as String,
      isNewDevice: j['isNewDevice'] as bool,
      profile: profileJson is Map<String, dynamic>
          ? ProfileData.fromJson(profileJson)
          : null,
    );
  }
}
```

- [ ] **Step 2: `auth_controller.dart` 增加 onRegistered 回调**

`RegisterResult` 增加 profile 字段：

```dart
class RegisterResult {
  final String token;
  final bool isNewDevice;
  final ProfileData? profile;

  const RegisterResult({required this.token, required this.isNewDevice, this.profile});
}
```

`AuthController` 构造新增可选参数（在现有命名参数之后追加）：

```dart
final Future<void> Function(RegisterResult result)? _onRegistered;

// 构造参数新增：
Future<void> Function(RegisterResult result)? onRegistered,
// 构造函数体赋值：
_onRegistered = onRegistered,
```

`registerIfNeeded` 成功分支（`await _dao.save(record);` 之后）追加：

```dart
try {
  await _onRegistered?.call(resp);
} catch (_) {
  // 资料落库失败不阻塞注册流程
}
```

- [ ] **Step 3: `main.dart` 接入**

- 新增导入：

```dart
import 'features/profile/data/profile_dao.dart';
import 'features/profile/data/profile_models.dart';
import 'features/profile/providers/profile_providers.dart';
import 'features/profile/services/profile_sync_service.dart';
```

- `_createAuthDao` 改为同时获取 profile dao（Dart 2.19 无 records，用私有类）：

```dart
class _BootstrapDaos {
  final AuthDao authDao;
  final UserProfileDao profileDao;
  const _BootstrapDaos({required this.authDao, required this.profileDao});
}

Future<_BootstrapDaos> _createBootstrapDaos() async {
  final container = ProviderContainer();
  await container.read(databaseProvider.future);
  final authDao = await container.read(authDaoProvider.future);
  final profileDao = await container.read(profileDaoProvider.future);
  return _BootstrapDaos(authDao: authDao, profileDao: profileDao);
}
```

- `main()` 相应修改（原 `_createAuthDao()` 调用点替换）：

```dart
final daos = await _createBootstrapDaos();

final authController = AuthController(
  dao: daos.authDao,
  resolveDeviceId: () => defaultResolveDeviceId(daos.authDao),
  resolveOs: defaultResolveOs,
  doRegister: _doRegister,
  onRegistered: (result) async {
    final profile = result.profile;
    if (profile == null) return;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await daos.profileDao.upsert(profile, now);
  },
);
```

- 创建 ProviderContainer 后（`runApp` 之前）追加 fire-and-forget 初始化：

```dart
// 初始化个人资料：拉取/补传（不阻塞启动）
container.read(profileSyncServiceProvider.future).then((sync) async {
  await sync.ensureLoadedIfMissing();
  await sync.syncPendingIfNeeded();
});
```

注意：确认现有 `main.dart` 中 `ProviderContainer` 的创建位置与变量名，并让 `authDaoProvider`/`profileDaoProvider` 的 import 路径正确（`core/auth/auth_dao.dart`、`core/db/database_provider.dart`）。

- [ ] **Step 4: `growth_providers.dart` 接入真实资料**

`userProfileProvider` 开头读取本地资料：

```dart
final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  final profile = await ref.watch(profileDataProvider.future);
  final db = await ref.watch(databaseProvider.future);
  final growthDao = GrowthDao(db);
  final galleryDao = GalleryDao(db);
  final templatesDao = TemplatesDao(db);
  final levelCfg = LevelConfig();
  final user = await ref.watch(userGrowthProvider.future);
  // ... 原有聚合逻辑保持不变 ...
  return UserProfile(
    name: profile?.username ?? '如画用户',
    avatarSeed: profile?.avatarSeed ?? 'lumira-user-001',
    // ... 其余字段沿用原有逻辑 ...
  );
});
```

（以现有文件实际结构为准：保留原有统计聚合，仅替换 `name` 与 `avatarSeed` 两个字段的来源。）

- [ ] **Step 5: 路由注册**

`route_names.dart` 增加：

```dart
static const String profileEdit = '/profile/edit';
```

`router.dart` 的 profile 路由附近追加：

```dart
GoRoute(
  path: RouteNames.profileEdit,
  name: 'profileEdit',
  builder: (context, state) => const ProfileEditPage(),
),
```

并添加 import `package:lumira_app_flutter/features/profile/pages/profile_edit_page.dart`（页面文件在 Task 6 创建，若分析报错，先在 Task 6 完成页面后再于本任务验证——提交顺序可调整为本任务不提交，与 Task 6 一并提交）。

- [ ] **Step 6: 运行分析验证**

Run: `cd lumira_app_flutter && flutter analyze`
Expected: 无 error（若 ProfileEditPage 缺失导致 import 报错，则跳过该 import 与路由，待 Task 6 完成后再补充并验证）

- [ ] **Step 7: Commit**

```bash
git add lumira_app_flutter/lib/features/device/data/device_models.dart lumira_app_flutter/lib/core/auth/auth_controller.dart lumira_app_flutter/lib/main.dart lumira_app_flutter/lib/features/profile/providers/growth_providers.dart lumira_app_flutter/lib/core/router/route_names.dart
git commit -m "feat(flutter): wire profile into register flow, startup sync and profile aggregation"
```

---

### Task 6: Flutter UI（ProfileEditPage + HeroCard 编辑入口）

**Files:**
- Create: `lumira_app_flutter/lib/features/profile/pages/profile_edit_page.dart`
- Modify: `lumira_app_flutter/lib/features/profile/pages/profile_page.dart`
- Modify: `lumira_app_flutter/lib/app/router.dart`（补全 Task 5 中暂缓的 import 与路由）

**Interfaces:**
- Consumes: Task 3 的 `ProfileData`/`BuiltinProfiles`、Task 4 的 `profileDataProvider`/`profileSyncServiceProvider`；`NeuCard`/`LumiraTextField`/`LumiraButton`/`LumiraNav`/`GlassBackground`/`appThemeProvider`（theme_tokens）

- [ ] **Step 1: 实现 `profile_edit_page.dart`**

结构（ConsumerStatefulWidget）：

```dart
class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});
  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  final _usernameController = TextEditingController();
  String? _selectedSeed;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  Future<void> _loadInitial() async {
    final profile = await ref.read(profileDataProvider.future);
    if (!mounted) return;
    setState(() {
      _usernameController.text = profile?.username ?? '';
      _selectedSeed = profile?.avatarSeed ?? BuiltinProfiles.avatarSeeds.first;
    });
  }

  void _randomUsername() {
    final current = _usernameController.text.trim();
    final pool = BuiltinProfiles.usernames.where((n) => n != current).toList();
    if (pool.isEmpty) return;
    setState(() => _usernameController.text = pool[Random().nextInt(pool.length)]);
  }

  bool get _dirty {
    final username = _usernameController.text.trim();
    return _selectedSeed != null && username.isNotEmpty;
  }

  Future<void> _save() async {
    if (!_dirty || _saving) return;
    setState(() => _saving = true);
    final username = _usernameController.text.trim();
    final profile = ProfileData(username: username, avatarSeed: _selectedSeed!);
    final sync = await ref.read(profileSyncServiceProvider.future);
    final result = await sync.save(profile);
    if (!mounted) return;
    ref.invalidate(profileDataProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.synced ? '已保存' : '已保存到本地，稍后自动同步')),
    );
    Navigator.of(context).pop();
  }

  // build：
  // 1) 从 ref.watch(appThemeProvider) 取 theme 与 tokens
  // 2) GlassBackground(variant: profile) + 径向渐变 + SafeArea
  // 3) LumiraNav(title: '编辑资料')
  // 4) 「选择头像」小节：Wrap/GridView 2列×4，每项 GestureDetector + NeuCard
  //    头像 = Image.network(BuiltinProfiles.avatarUrl(seed), 88dp 圆形)
  //    选中态：边框 tokens.brand（female 1.2，其余 2）+ 右下角金色对勾角标
  // 5) 「用户名」小节：LumiraTextField(maxLength: 20) + LumiraButton(secondary, '随机换一个', onPressed: _randomUsername)
  // 6) 底部 LumiraButton(primary, '保存', onPressed: _dirty && !_saving ? _save : null)
}
```

具体实现细节（在现有页面中找可复用的原子组件）：
- 头像网格项用 `NeuCard` 包 `ClipOval(Image.network(...))`，参考 `profile_page.dart` 中头像的渲染方式（`Image.network(url, fit: BoxFit.cover)`）
- 金色对勾角标沿用 HeroCard 角标样式（`Container` 圆形渐变 `0xFFC9A96E→0xFFA88550` + 白色 `check` 图标 14dp）
- 选中描边：`Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: tokens.brand, width: female ? 1.2 : 2)))`，female 判定 `appTheme.style == UIStyle.female`
- 布局间距沿用现有页面规范（24rpx≈对应 dp 由现有常量决定，遵循页面现有 padding 体系）

- [ ] **Step 2: `profile_page.dart` HeroCard 增加编辑入口**

- 头像区域右上角角标：将现有 22dp 金色圆形内图标由 `keyboard_arrow_up` 替换为 `edit`（16dp 白色铅笔）
- 将头像 Stack 与名字行包进 `GestureDetector`（或仅头像 Stack），`onTap: () => context.push(RouteNames.profileEdit)`（确认现有路由跳转方式，可能是 `context.go`/`Navigator`，沿用 profile_page 现有跳转模式）

- [ ] **Step 3: `router.dart` 补全 Task 5 暂缓内容**

若 Task 5 未提交 import 与路由，在此补上（import `profile_edit_page.dart` + `GoRoute(profileEdit)`）。

- [ ] **Step 4: 运行分析验证**

Run: `cd lumira_app_flutter && flutter analyze`
Expected: 无 error；随后 `flutter test test/core/db/profile_dao_test.dart test/core/db/migration_v15_test.dart test/features/profile/profile_sync_service_test.dart` 全部 PASS

- [ ] **Step 5: Commit**

```bash
git add lumira_app_flutter/lib/features/profile/pages/profile_edit_page.dart lumira_app_flutter/lib/features/profile/pages/profile_page.dart lumira_app_flutter/lib/app/router.dart
git commit -m "feat(flutter): add profile edit page and hero card edit entry"
```

---

### Task 7: 全量回归验证

**Files:**
- 无代码变更，仅验证

**Steps:**
- [ ] **Step 1: 后端全量 e2e**

Run: `cd lumira-server && pnpm --filter backend test:e2e`
Expected: 全部 PASS

- [ ] **Step 2: Flutter 全量测试**

Run: `cd lumira_app_flutter && flutter analyze && flutter test`
Expected: analyze 无 error，测试全部 PASS

- [ ] **Step 3: 记录回归结果**

将两端测试结果记录到 `docs/superpowers/plans/2026-08-05-profile-edit.md` 末尾「回归结果」小节（若无需变更代码，则不产生 commit）。
