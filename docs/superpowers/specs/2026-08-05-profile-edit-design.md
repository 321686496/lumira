# 个人信息修改功能设计

> 日期：2026-08-05
> 范围：Flutter 客户端（lumira_app_flutter）+ 后端（lumira-server）+ 共享类型（shared）

## 1. 目标

为「我的」页新增个人信息修改能力：用户名 + 头像。用户资料随设备 ID 存储到后端；首次注册时系统从内置昵称池/头像池随机分配默认资料；用户可在「我的」页点击头像/名字进入编辑页，修改用户名与头像（头像从系统内置 picsum 头像池选择，用户名可输入或从昵称池随机换）。所有新增 UI 遵循现有 4 种 UI 风格（新拟态/扁平/玻璃/女性美学）与 8 套主题。

## 2. 需求要点

| 需求 | 方案 |
|---|---|
| 资料随设备 ID 存后端 | 后端新建 `user_profiles` 表，`device_id` 主键关联 `devices` |
| 首次注册分配默认资料 | `POST /device/register` 新设备时随机生成并写入，响应返回 |
| 修改入口 | 「我的」页 HeroCard 头像/名字区域点击（含编辑角标）→ 编辑页 |
| 内置头像 | 8 个 picsum seed 头像池，前后端各维护一份相同列表 |
| 随机用户名 | 24 个中文诗意昵称池，前后端各维护一份相同列表 |
| 同步策略 | 离线优先双写（本地 sqflite 立即生效 + 后端同步，失败标记待同步补传） |
| UI 一致性 | 全部通过 `appThemeProvider` 渲染，4 风格 × 8 主题自动适配 |

## 3. 数据模型

### 3.1 后端新表 `user_profiles`

```sql
CREATE TABLE user_profiles (
  device_id   TEXT PRIMARY KEY REFERENCES devices(device_id),
  username    TEXT NOT NULL,
  avatar_seed TEXT NOT NULL,
  updated_at  INTEGER NOT NULL
);
```

- 与 `user_points`、`questionnaire_records` 的现有表模式一致
- `avatar_seed` 存 picsum seed（如 `lumira-avatar-03`），客户端据此拼 `https://picsum.photos/seed/{seed}/200/200`

### 3.2 Flutter 本地表 `user_profile`（单行表 id=1）

```sql
CREATE TABLE user_profile (
  id          INTEGER PRIMARY KEY DEFAULT 1,
  username    TEXT NOT NULL,
  avatar_seed TEXT NOT NULL,
  updated_at  INTEGER NOT NULL,
  synced_at   INTEGER
);
```

- 参照 `user_settings` / `questionnaire` 单行表模式
- `synced_at` 为 NULL 表示待同步（离线优先双写标记）

### 3.3 数据库迁移

- `_kDbVersion` 14 → 15（`core/db/database_provider.dart`）
- `_onCreate` 增加建表语句
- `_onUpgrade` 增加 `oldVersion < 14` 分支（`CREATE TABLE IF NOT EXISTS`，幂等）

## 4. 内置资源池

### 4.1 头像池（8 个，前后端各维护一份相同列表）

| id | seed | 说明 |
|---|---|---|
| `avatar-01` ~ `avatar-08` | `lumira-avatar-01` ~ `lumira-avatar-08` | picsum 固定 seed，URL：`https://picsum.photos/seed/{seed}/200/200` |

### 4.2 昵称池（24 个中文诗意昵称，前后端各维护一份相同列表）

示例：「追光的小鹿」「胶片旅人」「云边记录者」「晚风摄影师」「拾光少女」「光影漫游者」「春日快门」「银河捕手」「晨雾漫游」「暮色收藏家」「窗边诗人」「胶片收藏家」「星野旅人」「海盐汽水」「青柠快门」「山间清风」「雨后晴天」「微光日记」「星河漫游者」「温柔捕光者」「麦田守望者」「旧巷拾影」「月亮邮差」「森林呼吸」

- 后端：注册时随机分配默认用户名
- 前端：编辑页「随机换一个」按钮从池中随机取（排除当前值）

## 5. 后端 API

### 5.1 `POST /device/register`（响应扩展）

- 新设备：从昵称池随机取 username + 头像池随机取 avatarSeed，写入 `user_profiles`（`updated_at=now`）
- 老设备：返回已存资料（若无记录则懒创建默认资料，兼容旧数据）
- 响应结构变更：

```ts
// packages/shared/src/types/device.ts 新增
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

- Flutter 端 `RegisterDeviceResponse` 模型同步扩展，`AuthController` 注册完成后将 profile 写入本地 `user_profile` 表

### 5.2 `GET /profile`（DeviceAuthGuard）

- 返回当前设备 `{ username, avatarSeed }`
- 无记录时懒创建默认资料并返回（兜底旧客户端/首次拉取）
- 响应结构：`{ username, avatarSeed }`

### 5.3 `PATCH /profile`（DeviceAuthGuard）

- 请求体：`{ username?, avatarSeed? }`（至少一项）
- 校验：`username` 1-20 字符（`@IsString @MinLength(1) @MaxLength(20)`）；`avatarSeed` 非空 ≤64 字符
- 更新 `user_profiles` 对应字段 + `updated_at=now`，返回更新后 `{ username, avatarSeed }`
- 新建 `modules/profile/` 模块（controller/service/dto/module），`app.module.ts` 注册

## 6. Flutter 端架构

### 6.1 新增文件

```
lib/features/profile/
├── data/
│   ├── profile_models.dart          # ProfileData { username, avatarSeed, syncedAt? }
│   ├── builtin_profiles.dart        # BuiltinProfiles: avatarPool(8) + usernamePool(24)
│   └── profile_dao.dart             # UserProfileDao（sqflite 单行表）
├── services/
│   └── profile_sync_service.dart    # ProfileSyncService（离线优先双写）
├── providers/
│   └── profile_providers.dart       # profileDaoProvider / profileRepositoryProvider
│                                   # profileSyncServiceProvider / profileDataProvider
└── pages/
    └── profile_edit_page.dart       # ProfileEditPage（路由 /profile/edit）
```

### 6.2 数据层职责

- **`ProfileData`**：`{ username, avatarSeed, syncedAt? }`，含 `toJson/fromJson`（Dart 2.19 无 records，用简单类）
- **`UserProfileDao`**：`get / upsert / markSynced / hasUnsynced`（复用 QuestionnaireDao 模式）
- **`ProfileRepository`**：`fetch()` → GET /profile；`update(username, avatarSeed)` → PATCH /profile
- **`ProfileSyncService`**：
  - `save()`：本地 upsert 立即生效 → PATCH 后端 → 成功 `markSynced`；失败标记待同步（toast 提示，不阻塞）
  - `syncPendingIfNeeded()`：启动时若有未同步资料则重试 PATCH
  - `ensureLoaded()`：本地无资料时 GET /profile 填充（兼容已注册老设备）

### 6.3 Provider 设计

- `profileDaoProvider`（FutureProvider，同 `questionnaireDaoProvider`）
- `profileRepositoryProvider`（FutureProvider，依赖 `apiClientProvider`，同 `deviceRepositoryProvider`）
- `profileSyncServiceProvider`（FutureProvider，组合 DAO + Repository）
- `profileDataProvider`（StateNotifierProvider，保存当前 `ProfileData`，加载/保存后更新）

### 6.4 现有代码接入

- **`userProfileProvider`**（`features/profile/providers/growth_providers.dart`）：`name` / `avatarSeed` 改为读取 `profileDataProvider`（优先本地资料，无资料回退现有硬编码 `'如画用户'` / `'lumira-user-001'`），其余统计聚合逻辑不变 → 「我的」页 HeroCard 自动展示真实资料
- **`AuthController`**（`core/auth/auth_controller.dart`）：注册响应解析 `profile`，注册成功后调用 `UserProfileDao.upsert`
- **启动流程**：main.dart bootstrap 后（或 splash 页）调用 `ProfileSyncService.ensureLoaded()` + `syncPendingIfNeeded()`（参照问卷接入方式）
- **路由**：`RouteNames` 增加 `profileEdit = '/profile/edit'`，router.dart 注册

## 7. UI 设计（4 风格 × 8 主题）

### 7.1 「我的」页 HeroCard 改造（profile_page.dart `_HeroCard`）

- 头像区域右上角：复用现有 22dp 金色圆形角标，图标由 `keyboard_arrow_up` 改为 `edit`（16dp 白色铅笔，`tokens` 不适用处沿用硬编码金色渐变 `#C9A96E→#A88550`）
- 头像 + 名字区域外包 `GestureDetector`，点击 `push('/profile/edit')`
- 数据来源：`userProfileProvider`（已接入真实资料），无需其他改动

### 7.2 ProfileEditPage（新页面）

布局（沿用现有页面结构：`LumiraNav` + `GlassBackground` + 径向渐变 + 底部安全区）：

1. **头像选择区**：标题「选择头像」+ 2 行 × 4 列网格
   - 每项：`NeuCard` 包裹 88dp 圆形 picsum 头像（`Image.network('https://picsum.photos/seed/{seed}/200/200')`）
   - 选中态：`tokens.brand` 描边（female 风格 1.2dp / 其余 2dp）+ 右下角金色对勾角标
2. **用户名编辑区**：标题「用户名」+ `LumiraTextField`（maxLength 20）+「随机换一个」`LumiraButton`（secondary variant，点击从昵称池随机取并填入，排除当前值）
3. **保存按钮**：`LumiraButton` primary variant 全宽「保存」，disabled 当无改动
4. **保存行为**：本地 upsert → PATCH 后端 → 成功 toast「已保存」+ pop；失败 toast「已保存到本地，稍后自动同步」+ pop（待同步）

风格适配：页面/卡片/输入框/按钮全部使用 `NeuCard`/`LumiraTextField`/`LumiraButton`（4 风格视觉已内置）；颜色只用 tokens，不新增自定义色值。

## 8. 默认资料分配流程

```
首次启动 → 设备注册 POST /device/register
  → 后端：新设备 → 随机 username + avatarSeed 写入 user_profiles → 响应带 profile
  → AuthController：token 入库后，profile 写入本地 user_profile 表
  → 「我的」页展示默认资料

老设备 / 本地无资料兜底：
  启动时 ensureLoaded() → GET /profile → 写入本地

资料修改：
  编辑页保存 → 本地 upsert（立即生效）→ PATCH /profile
    → 成功 markSynced；失败标记 synced_at=NULL，下次启动补传
```

## 9. 测试

### 9.1 后端 e2e（`packages/backend/test/profile.e2e-spec.ts`）

- register：新设备响应含 `profile`，字段非空；重复注册返回已存资料
- GET /profile：有 token 返回 200 + 资料；无 token 401
- PATCH /profile：正常更新返回新值；username 超长/为空 → 400；空 body → 400；avatarSeed 超长 → 400

### 9.2 Flutter 单测

- `profile_dao_test.dart`：get（空/有值）、upsert（覆盖）、markSynced、hasUnsynced
- `migration_v15_test.dart`：`user_profile` 表创建、单行表初始化、幂等（参照 migration_v4/v5 测试）

## 10. 文件清单

### 后端（lumira-server）

| 文件 | 变更 |
|---|---|
| `packages/backend/src/database/schema.ts` | 新增 `user_profiles` 表 |
| `packages/backend/src/modules/device/device.service.ts` | register 时创建/返回 profile |
| `packages/backend/src/modules/profile/profile.module.ts` | 新模块 |
| `packages/backend/src/modules/profile/profile.controller.ts` | GET/PATCH /profile |
| `packages/backend/src/modules/profile/profile.service.ts` | 查询/懒创建/更新 |
| `packages/backend/src/modules/profile/dto/update-profile.dto.ts` | 更新 DTO |
| `packages/backend/src/modules/profile/profile-constants.ts` | 昵称池 + 头像 seed 池 |
| `packages/backend/src/app.module.ts` | 注册 ProfileModule |
| `packages/shared/src/types/device.ts` | 新增 `UserProfile` 接口 |
| `packages/backend/test/profile.e2e-spec.ts` | 新增 e2e |

### Flutter（lumira_app_flutter）

| 文件 | 变更 |
|---|---|
| `lib/core/db/tables.dart` | `user_profile` 表常量 |
| `lib/core/db/database_provider.dart` | v15 迁移 |
| `lib/core/router/route_names.dart` | `profileEdit` 路由名 |
| `lib/app/router.dart` | 注册 `/profile/edit` |
| `lib/core/auth/auth_controller.dart` | 解析并落地注册响应的 profile |
| `lib/features/device/data/device_models.dart` | `RegisterDeviceResponse` 增加 `profile` 字段 |
| `lib/features/profile/data/profile_models.dart` | 新文件 |
| `lib/features/profile/data/builtin_profiles.dart` | 新文件 |
| `lib/features/profile/data/profile_dao.dart` | 新文件 |
| `lib/features/profile/services/profile_sync_service.dart` | 新文件 |
| `lib/features/profile/providers/profile_providers.dart` | 新文件 |
| `lib/features/profile/providers/growth_providers.dart` | userProfileProvider 接入真实资料 |
| `lib/features/profile/pages/profile_page.dart` | HeroCard 编辑角标 + 点击跳转 |
| `lib/features/profile/pages/profile_edit_page.dart` | 新页面 |
| `lib/main.dart` | 启动 ensureLoaded + 补传 |
| `test/core/db/profile_dao_test.dart` | 新测试 |
| `test/core/db/migration_v15_test.dart` | 新测试 |

## 11. 非目标（YAGNI）

- 不支持自定义上传头像（仅系统内置 picsum 头像池）
- 不做头像/昵称池的后端下发接口（前后端各维护一份常量池，保持一致即可）
- admin 后台本期不展示用户资料（后续按需扩展）
- 不做多设备资料同步冲突处理（单设备场景，以后端最后写入为准）
