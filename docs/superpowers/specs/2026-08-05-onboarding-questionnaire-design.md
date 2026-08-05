# 新用户问卷页设计文档

- **日期**：2026-08-05
- **主题**：为新用户添加问卷填写页，用于调查偏好并做个性化推荐
- **方案**：方案 A（Flutter 端独立 sqflite 表 + 后端独立 Drizzle 表，双端离线/在线协作）
- **范围**：Flutter 客户端 + NestJS 后端 + Admin 查看页 + 共享类型

---

## 1. 决策汇总

| 决策项 | 选择 |
|---|---|
| 呈现形式 | 多步向导（一题一步，顶部进度条） |
| 可跳过性 | 每题可跳过，整体可跳过 |
| 题目数量 | 7 题详细版 |
| 数据用途 | 本地推荐联动 + 后端数据分析 |
| 触发时机 | 新设备首次注册时 + 设置页入口（老用户可主动填） |
| 后续重填 | 可重填覆盖（本地 update 单行；后端 insert 保留历史，以最新为准） |
| Admin 展示 | 增加查看页（列表 + 单设备历史 + 聚合统计） |
| 推荐联动 | 仅影响 RecommendationService slot 1（新用户 banner） |
| 数据存储 | 方案 A：Flutter 独立 `questionnaire` 表 + 后端 `questionnaire_records` 表 |
| 项目范围 | uni-app 项目已废弃，仅作原型参考；改动只在 Flutter + 后端 |

---

## 2. 数据模型

### 2.1 问卷题目定义

7 道题，每题 `questionId` + 题型 + 选项列表。选项用稳定字符串 key，便于后端聚合统计。

| # | questionId | 题干 | 题型 | 选项 key（label） |
|---|---|---|---|---|
| 1 | `source` | 你从哪里知道 Lumira？ | 单选 | `app_store`（应用商店）/ `social_media`（社交媒体）/ `friend`（朋友推荐）/ `search`（搜索引擎）/ `article`（文章博客）/ `other`（其他） |
| 2 | `favorite_categories` | 你喜欢拍什么？（可多选） | 多选 | `portrait` / `landscape` / `food` / `street` / `night` / `macro` / `still_life`（对应现有 7 大模板分类） |
| 3 | `pain_points` | 拍摄中你有哪些烦恼？（可多选） | 多选 | `composition`（构图）/ `lighting`（光线）/ `posing`（摆姿）/ `camera_settings`（参数设置）/ `post_processing`（后期）/ `no_subject`（找不到拍摄对象）/ `no_time`（没时间拍） |
| 4 | `skill_level` | 你的摄影水平？ | 单选 | `beginner`（新手）/ `intermediate`（进阶）/ `advanced`（高级）/ `pro`（专业） |
| 5 | `expectations` | 你希望从 Lumira 获得？（可多选） | 多选 | `learn_photo`（学摄影）/ `inspiration`（找灵感）/ `better_composition`（提升构图）/ `master_camera`（玩转相机）/ `share_works`（分享作品）/ `record_life`（记录生活） |
| 6 | `common_scenes` | 你常在哪些场景拍摄？（可多选） | 多选 | `indoor_home`（家中）/ `cafe`（咖啡馆）/ `outdoor_park`（户外公园）/ `street`（街头）/ `travel`（旅行）/ `office`（办公室）/ `studio`（影棚） |
| 7 | `shoot_frequency` | 你的拍摄频率？ | 单选 | `rarely`（偶尔）/ `monthly`（每月）/ `weekly`（每周）/ `daily`（每天） |

**跳过规则**：
- 单选题跳过：答案为 `null`
- 多选题跳过：答案为空数组 `[]`
- 整体跳过：所有题均为 `null`/`[]`，但仍记录 `submitted_at`（标记"已展示过问卷"）

### 2.2 Flutter 端 sqflite 表（v11 → v12 迁移）

新建独立表 `questionnaire`（单行设计，id 固定为 1）：

```sql
CREATE TABLE IF NOT EXISTS questionnaire (
  id INTEGER PRIMARY KEY DEFAULT 1,
  answers_json TEXT NOT NULL DEFAULT '{}',
  submitted_at INTEGER,
  synced_at INTEGER
);
```

字段说明：
- `answers_json`：完整答案 JSON，结构与上报后端 payload 一致
- `submitted_at`：秒级时间戳，`null` 表示未填过
- `synced_at`：上报后端成功时间，`null` 表示未同步（用于补传）

**`answers_json` 结构**：

```json
{
  "source": "friend",
  "favorite_categories": ["portrait", "food"],
  "pain_points": ["composition", "lighting"],
  "skill_level": "beginner",
  "expectations": ["learn_photo", "better_composition"],
  "common_scenes": ["cafe", "outdoor_park"],
  "shoot_frequency": "weekly"
}
```

跳过的题：单选为 `null`，多选为 `[]`。

**v12 迁移**：在 `database_provider.dart` 的 `_migrate` switch 增加 `case 11:`，执行 `db.execute('CREATE TABLE IF NOT EXISTS questionnaire (...)')`，然后 `UPDATE user_settings SET value = '12' WHERE key = 'version'`。

### 2.3 后端 Drizzle 表

在 `schema.ts` 追加：

```ts
export const questionnaireRecords = sqliteTable('questionnaire_records', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  deviceId: text('device_id').notNull(),
  answersJson: text('answers_json').notNull(),
  submittedAt: integer('submitted_at').notNull(),
  clientIp: text('client_ip'),
});
```

在 `001_init.sql` 末尾追加（沿用"迁移只跑 001_init.sql"模式，不新建迁移文件）：

```sql
CREATE TABLE IF NOT EXISTS questionnaire_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL,
  answers_json TEXT NOT NULL,
  submitted_at INTEGER NOT NULL,
  client_ip TEXT
);
```

**幂等策略**：每次提交 **insert 一条新记录**（不 upsert），保留历史轨迹。admin 查询时取每设备最新一条为准。不设外键约束到 `devices` 表（与现有 `invite_records` 等表风格一致）。

### 2.4 共享类型

`packages/shared/src/types/questionnaire.ts`：

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

export interface QuestionnaireListResponse {
  items: (QuestionnaireRecord & { deviceAlias?: string | null })[];
  total: number;
  page: number;
  pageSize: number;
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

Flutter 端用 Dart 类镜像（手写不可变类，与现有 `AuthState` 风格一致；项目未引入 freezed）。

---

## 3. 后端 API

### 3.1 模块结构

```
packages/backend/src/modules/questionnaire/
├── questionnaire.module.ts
├── questionnaire.controller.ts
├── questionnaire.service.ts
└── dto/
    └── submit-questionnaire.dto.ts
```

### 3.2 提交接口（设备端）

**`POST /api/v1/questionnaire/submit`**

- **鉴权**：`@UseGuards(DeviceAuthGuard)` + `@DeviceId()` 装饰器获取 deviceId
- **请求 DTO**（`submit-questionnaire.dto.ts`）：

```ts
class QuestionnaireAnswersDto {
  @IsString() @IsOptional() @IsIn(['app_store','social_media','friend','search','article','other'])
  source?: string | null;

  @IsArray() @ArrayUnique() @IsString({ each: true })
  @IsIn(['portrait','landscape','food','street','night','macro','still_life'], { each: true })
  favorite_categories: string[] = [];

  @IsArray() @ArrayUnique() @IsString({ each: true })
  @IsIn(['composition','lighting','posing','camera_settings','post_processing','no_subject','no_time'], { each: true })
  pain_points: string[] = [];

  @IsString() @IsOptional() @IsIn(['beginner','intermediate','advanced','pro'])
  skill_level?: string | null;

  @IsArray() @ArrayUnique() @IsString({ each: true })
  @IsIn(['learn_photo','inspiration','better_composition','master_camera','share_works','record_life'], { each: true })
  expectations: string[] = [];

  @IsArray() @ArrayUnique() @IsString({ each: true })
  @IsIn(['indoor_home','cafe','outdoor_park','street','travel','office','studio'], { each: true })
  common_scenes: string[] = [];

  @IsString() @IsOptional() @IsIn(['rarely','monthly','weekly','daily'])
  shoot_frequency?: string | null;
}

class SubmitQuestionnaireDto {
  @ValidateNested() @Type(() => QuestionnaireAnswersDto)
  answers: QuestionnaireAnswersDto;

  @IsInt() @Min(0)
  submittedAt: number;
}
```

- **响应**（直接返回业务对象，不封装）：

```ts
{ success: true, receivedAt: 1700000000 }
```

- **Service 逻辑**：

```ts
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
```

### 3.3 Admin 接口

在 `AdminController` 增加 3 个方法，全部用 `AdminAuthGuard`。

**`GET /api/v1/admin/questionnaire`** — 列表（每设备最新一条）
- **查询参数**：`page`（默认 1）、`pageSize`（默认 20）、可选 `deviceId` 过滤
- **逻辑**：SQL 用 `ROW_NUMBER() OVER (PARTITION BY device_id ORDER BY submitted_at DESC)` 取每设备最新一条；LEFT JOIN `devices` 表带出 `deviceAlias`
- **响应**：`QuestionnaireListResponse`

**`GET /api/v1/admin/questionnaire/:deviceId`** — 单设备历史
- **响应**：`{ items: QuestionnaireRecord[], total }`（按 `submittedAt` 倒序）

**`GET /api/v1/admin/questionnaire/stats`** — 聚合统计
- **逻辑**：取每设备最新一条记录，在 service 层用 JS 聚合
- **响应**：`QuestionnaireStats`

### 3.4 模块注册

- `QuestionnaireModule` 导入 `DatabaseModule`，导出 `QuestionnaireService`
- `AppModule` 的 `imports` 增加 `QuestionnaireModule`
- `AdminController` 注入 `QuestionnaireService`，新增 3 个方法

### 3.5 错误处理

沿用现有 `HttpExceptionFilter`：
- 400：DTO 校验失败
- 401：未携带/无效 token
- 500：数据库异常

---

## 4. Flutter 前端

### 4.1 feature 目录结构

```
lib/features/onboarding/
├── data/
│   ├── questionnaire_data.dart         # 题目与选项静态定义（中文文案集中）
│   ├── questionnaire_dao.dart          # sqflite DAO
│   ├── questionnaire_answers.dart      # Dart 不可变模型
│   └── questionnaire_providers.dart    # Riverpod providers
├── services/
│   └── questionnaire_sync_service.dart # 上报后端
└── pages/
    ├── questionnaire_page.dart         # 多步向导主页面
    └── widgets/
        ├── question_step.dart          # 单题步骤通用骨架
        ├── single_choice_step.dart     # 单选题
        ├── multi_choice_step.dart      # 多选题
        └── progress_indicator.dart     # 顶部进度条
```

### 4.2 题目数据定义（`questionnaire_data.dart`）

```dart
enum QuestionType { single, multi }

class QuestionOption {
  final String key;
  final String label;
  final String? icon; // Phosphor 图标名
  const QuestionOption(this.key, this.label, {this.icon});
}

class QuestionDef {
  final String id;
  final String title;
  final String? subtitle;
  final QuestionType type;
  final List<QuestionOption> options;
  const QuestionDef({...});
}

const List<QuestionDef> kQuestionnaireQuestions = [
  QuestionDef(id: 'source', title: '你从哪里知道 Lumira？', type: QuestionType.single, options: [
    QuestionOption('app_store', '应用商店', icon: 'store'),
    QuestionOption('social_media', '社交媒体', icon: 'instagram-logo'),
    QuestionOption('friend', '朋友推荐', icon: 'users'),
    QuestionOption('search', '搜索引擎', icon: 'magnifying-glass'),
    QuestionOption('article', '文章博客', icon: 'article'),
    QuestionOption('other', '其他', icon: 'dots-three'),
  ]),
  // ... 其余 6 题
];
```

文案集中此文件，便于未来抽 i18n。

### 4.3 路由

`route_names.dart` 增加：

```dart
static const String onboarding = '/onboarding';
```

`router.dart` 增加普通 `GoRoute`（无鉴权、无参数）：

```dart
GoRoute(
  path: RouteNames.onboarding,
  builder: (context, state) => QuestionnairePage(
    fromSettings: state.queryParams['from'] == 'settings',
  ),
),
```

### 4.4 触发逻辑（splash 分流）

修改 `splash_page.dart` 的 `_maybeNavigate()`：

```dart
if (auth.status == AuthStatus.registered) {
  final questionnaireDao = await ref.read(questionnaireDaoProvider.future);
  final isCompleted = await questionnaireDao.isCompleted();
  // 新设备 且 未填过问卷 → 跳问卷页
  if (auth.isNewDevice && !isCompleted) {
    context.go(RouteNames.onboarding);
  } else {
    context.go(RouteNames.home);
  }
}
```

- 用 `isNewDevice` 作为首次触发条件，避免老用户更新后被打扰
- `isCompleted` 作为幂等保护

### 4.5 问卷页 UI（多步向导）

**整体结构**（参考 `profile_settings_page.dart` 风格）：

```dart
Scaffold(
  backgroundColor: tokens.canvas,
  extendBodyBehindAppBar: true,
  appBar: LumiraNav(
    title: '关于你',           // 左对齐
    transparent: true,
    leading: _SkipButton(...), // 左上角跳过
    trailing: _StepCounter(),  // 右上角 "3/7"
  ),
  body: Container(
    decoration: BoxDecoration(gradient: RadialGradient(...)),
    child: SafeArea(
      child: Column(
        children: [
          _ProgressIndicator(current: _currentStep, total: 7),
          Expanded(
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              child: _buildCurrentStep(),
            ),
          ),
          _BottomBar(
            onBack: _prev,
            onNext: _next,
            canSkip: true,
            isLast: _currentStep == 6,
            onSubmit: _submit,
          ),
        ],
      ),
    ),
  ),
)
```

**单题步骤骨架**（`question_step.dart`）：用 `NeuCard` 包裹题目与选项。

**选项交互**（参考 `_buildHomeWordmarkSection` 选中态高亮卡片）：
- 单选：点击即选中并自动进入下一题（带 200ms 延迟让用户看到选中态）
- 多选：点击切换选中，需点底部"下一题"手动推进

选中态样式：`brandSubtle` 背景 + `brand` 边框 + check icon。

**底部栏**：
- 非首题显示"上一题"（左）
- 单选题：无"下一题"按钮（自动推进）
- 多选题：显示"下一题"按钮
- 最后一题：显示"完成"按钮
- 全程左上角"跳过"按钮（跳过整份问卷，所有题留 null/[]）

### 4.6 提交流程（`questionnaire_sync_service.dart`）

```dart
class QuestionnaireSyncService {
  Future<SubmitResult> submit(QuestionnaireAnswers answers) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // 1. 本地落库（离线优先，立即生效）
    await questionnaireDao.upsert(answers, now);

    // 2. 上报后端（失败不阻塞，标记未同步）
    try {
      final res = await apiClient.post('/questionnaire/submit', data: {
        'answers': answers.toJson(),
        'submittedAt': now,
      });
      await questionnaireDao.markSynced(now);
      return SubmitResult(success: true);
    } catch (e) {
      return SubmitResult(success: false, error: e.toString());
    }
  }
}
```

**补传机制**（最小实现）：App 启动时检查 `submitted_at != null && synced_at == null`，若有则后台重试上报一次。不做复杂重试队列。

### 4.7 提交后跳转

- 从 splash 进入（新用户）：提交成功后 `context.go(RouteNames.home)`
- 从设置页进入（重填）：提交成功后 `context.pop()` 返回设置页

通过 `QuestionnairePage(fromSettings: bool)` 构造参数区分。

### 4.8 设置页入口

在 `profile_settings_page.dart` 的"通用"分组下增加一项：

```
偏好问卷  >  （已填 / 未填）
```

点击跳 `/onboarding?from=settings`。已填/未填状态读 `questionnaireDao.isCompleted()`。

### 4.9 Riverpod Providers

```dart
final questionnaireDaoProvider = FutureProvider<QuestionnaireDao>((ref) async {
  final db = await ref.read(databaseProvider.future);
  return QuestionnaireDao(db);
});

final questionnaireAnswersProvider = FutureProvider<QuestionnaireAnswers?>((ref) async {
  final dao = await ref.read(questionnaireDaoProvider.future);
  return dao.getAnswers();
});

final questionnaireSyncProvider = Provider<QuestionnaireSyncService>((ref) {
  // 注入 dao 与 apiClient
});
```

### 4.10 DAO 方法

`QuestionnaireDao` 提供：
- `Future<QuestionnaireAnswers?> getAnswers()` — 读取并解析
- `Future<void> upsert(QuestionnaireAnswers answers, int submittedAt)` — 写入（重填覆盖）
- `Future<void> markSynced(int syncedAt)` — 上报成功后更新 `synced_at`
- `Future<bool> isCompleted()` — `submitted_at != null`

---

## 5. 推荐联动

### 5.1 RecommendationService 改动

**slot 1（newUserGuide banner）改造**：

现状：`isNewUser = totalPhotos < 3` 时推"新手友好场景"。

改造后逻辑：

```dart
if (isNewUser) {
  final questionnaire = await questionnaireDao.getAnswers();

  if (questionnaire != null && questionnaire.favoriteCategories.isNotEmpty()) {
    // 有问卷偏好：推用户首选分类的 isRecommended 模板
    final topCategory = questionnaire.favoriteCategories.first;
    final templates = templatesDao.getBuiltinByCategory(topCategory, isRecommended: true);
    if (templates.isNotEmpty) {
      banners.add(/* 基于 topCategory 的 banner */);
      return;
    }
  }
  // 无问卷偏好或无匹配模板：保持现状推"新手友好场景"
  banners.add(/* newUserGuide banner */);
}
```

### 5.2 影响范围

- **仅 slot 1** 受问卷影响，slot 2-5 保持现有行为不变
- 老用户（totalPhotos >= 3）推荐不受问卷影响（仍按行为推断）
- 问卷偏好作为新用户冷启动信号，一旦用户有拍摄行为，行为数据优先

### 5.3 后续可扩展（不在本次范围）

- 根据 `skill_level` 调整推荐模板难度
- 根据 `pain_points` 推针对性学院课程
- 根据 `expectations` 调整首页 banner 文案

---

## 6. Admin 查看页

### 6.1 后端接口

复用第 3 节的 3 个 admin 接口：
- `GET /api/v1/admin/questionnaire`
- `GET /api/v1/admin/questionnaire/:deviceId`
- `GET /api/v1/admin/questionnaire/stats`

### 6.2 Admin 前端

**新增文件**：

```
packages/admin/src/app/dashboard/questionnaire/
├── page.tsx              # 列表页（带分页、设备筛选）
├── [deviceId]/
│   └── page.tsx          # 单设备历史详情
└── stats/
    └── page.tsx          # 统计面板
```

**侧边栏增加**（`sidebar.tsx`）：

```ts
{ href: '/dashboard/questionnaire', label: '问卷数据', icon: ClipboardText },
```

**列表页内容**：
- 表格：设备 ID（截断显示）/ 别名 / 提交时间 / 渠道 / 偏好分类 / 摄影水平
- 点击行进入单设备历史详情
- 顶部 tab 切换"列表 / 统计"

**统计页内容**：
- 7 个卡片，每题一个，展示选项分布（用 shadcn Progress 或简单 bar）
- 总响应人数大数字展示

**lib/api.ts 扩展**：

```ts
questionnaire: {
  list: (params) => adminFetch('/admin/questionnaire?' + qs(params)),
  history: (deviceId) => adminFetch(`/admin/questionnaire/${deviceId}`),
  stats: () => adminFetch('/admin/questionnaire/stats'),
}
```

**types/admin.ts 扩展**：增加 `QuestionnaireRecord`、`QuestionnaireListResponse`、`QuestionnaireStats` 类型（从 shared 复用）。

---

## 7. 文件改动清单

### Flutter 端（`lumira_app_flutter/`）

| 操作 | 文件 |
|---|---|
| 新增 | `lib/features/onboarding/data/questionnaire_data.dart` |
| 新增 | `lib/features/onboarding/data/questionnaire_answers.dart` |
| 新增 | `lib/features/onboarding/data/questionnaire_dao.dart` |
| 新增 | `lib/features/onboarding/data/questionnaire_providers.dart` |
| 新增 | `lib/features/onboarding/services/questionnaire_sync_service.dart` |
| 新增 | `lib/features/onboarding/pages/questionnaire_page.dart` |
| 新增 | `lib/features/onboarding/pages/widgets/question_step.dart` |
| 新增 | `lib/features/onboarding/pages/widgets/single_choice_step.dart` |
| 新增 | `lib/features/onboarding/pages/widgets/multi_choice_step.dart` |
| 新增 | `lib/features/onboarding/pages/widgets/progress_indicator.dart` |
| 修改 | `lib/core/router/route_names.dart`（加 `onboarding` 常量） |
| 修改 | `lib/app/router.dart`（加 GoRoute） |
| 修改 | `lib/core/db/database_provider.dart`（v11→v12 迁移，建 questionnaire 表） |
| 修改 | `lib/core/db/tables.dart`（加 questionnaire 表/列常量） |
| 修改 | `lib/features/splash/pages/splash_page.dart`（新设备分流） |
| 修改 | `lib/features/profile/pages/profile_settings_page.dart`（加入口） |
| 修改 | `lib/features/home/services/recommendation_service.dart`（slot 1 联动） |
| 修改 | `lib/core/network/api_client.dart`（如需补传逻辑） |

### 后端（`lumira-server/packages/backend/`）

| 操作 | 文件 |
|---|---|
| 新增 | `src/modules/questionnaire/questionnaire.module.ts` |
| 新增 | `src/modules/questionnaire/questionnaire.controller.ts` |
| 新增 | `src/modules/questionnaire/questionnaire.service.ts` |
| 新增 | `src/modules/questionnaire/dto/submit-questionnaire.dto.ts` |
| 修改 | `src/database/schema.ts`（加 `questionnaireRecords` 表） |
| 修改 | `src/database/migrations/001_init.sql`（追加 CREATE TABLE） |
| 修改 | `src/modules/admin/admin.controller.ts`（3 个 admin 接口） |
| 修改 | `src/modules/admin/admin.service.ts`（问卷查询/统计方法） |
| 修改 | `src/app.module.ts`（注册 QuestionnaireModule） |

### 共享类型（`lumira-server/packages/shared/`）

| 操作 | 文件 |
|---|---|
| 新增 | `src/types/questionnaire.ts` |
| 修改 | `src/index.ts`（导出 questionnaire 类型） |

### Admin 前端（`lumira-server/packages/admin/`）

| 操作 | 文件 |
|---|---|
| 新增 | `src/app/dashboard/questionnaire/page.tsx` |
| 新增 | `src/app/dashboard/questionnaire/[deviceId]/page.tsx` |
| 新增 | `src/app/dashboard/questionnaire/stats/page.tsx` |
| 修改 | `src/components/sidebar.tsx`（加导航项） |
| 修改 | `src/lib/api.ts`（加 questionnaire 方法） |
| 修改 | `src/types/admin.ts`（加类型） |

---

## 8. 技术约束与注意事项

1. **Flutter 环境限制**：HarmonyOS 兼容 Flutter 3.7.12 / Dart 2.19.6，**不支持 Dart 3 records 语法**，所有代码避开 records。
2. **离线优先**：Flutter 端所有业务数据本地 sqflite 落库，推荐联动不依赖网络。
3. **后端响应格式**：成功直接返回业务对象，错误统一 `{code, message}`。
4. **DTO 严格模式**：`forbidNonWhitelisted: true`，DTO 必须显式声明所有字段。
5. **国际化**：项目无 i18n 框架，中文文案硬编码，集中在 `questionnaire_data.dart`。
6. **uni-app 项目已废弃**：仅作原型参考，本次改动不涉及 `lumira-app/` 目录。
7. **数据库迁移**：后端沿用"只跑 001_init.sql"模式，新表 DDL 追加到该文件末尾；Flutter 端走 v11→v12 迁移。
8. **标题栏对齐**：LumiraNav 标题左对齐（符合用户偏好）。
9. **样式风格**：warmWhite + neumorphic，NeuCard + LumiraButton + FadeUp，选项选中态用 `brandSubtle` 背景 + `brand` 边框。
