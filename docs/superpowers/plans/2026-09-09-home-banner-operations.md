# 首页 Banner 运营化重构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 首页 Banner 从「5 条纯个性化推荐」重构为「4 条 运营位 + 个性化位」混合结构，运营位指向真实功能页（邀请/积分/解锁），并为每条 Banner 补曝光/点击埋点闭环。

**Architecture:** 运营位为 App 端静态配置（`operation_banners.dart`，条件由 Provider 汇聚远端用户状态后注入 `RecommendationService`，离线 fail-safe 让位个性化）；槽位从 5 压到 4（砍掉与首页模板推荐区重复的系统推荐槽）；埋点复用现有 `usage_events` 本地队列 + `recordBatch` 同步链路，仅扩展枚举白名单（后端 DTO 当前 `@IsIn` 白名单不收 `banner`/`expose`/`click`，不扩展会导致整批埋点上报 400、阻塞全部同步）。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（riverpod 2.3.6、sqflite、go_router）；后端 NestJS + class-validator + Drizzle（pnpm monorepo）。

**Spec:** [docs/specs/2026-09-08-home-banner-operations-design.md](../../specs/2026-09-08-home-banner-operations-design.md)

## Global Constraints

- Dart 2.19.6：禁用 Dart 3 records、模式匹配等新语法。
- 运营位只指向真实存在的功能：邀请 `/invite`、积分 `/points/wallet`、解锁 `/templates/unlock`；文案不夸张、不虚构，运营文案显式配置不走自动生成。
- 埋点失败静默降级，不影响 Banner 渲染与跳转。
- offline-first：运营条件远端拉取失败 → 对应条件不成立 → slot 0 让位个性化推荐，页面不空白。
- 后端零新增基础设施：仅扩展现有枚举白名单与 SQL 过滤，无新表、无新接口。
- 遵循项目 UI 规范：本计划不改 `_BannerCard` 视觉样式（运营位无封面 → 复用现有品牌渐变背景，不新增硬编码主题色）。
- 后端改动完成后必须 commit 并 push 到两个远程（AGENTS.md 规则）：`git push origin master` + `git push github master`（会触发 backend-deploy CI 自动部署，为 App 端埋点上报先铺路）。
- 所有 shell 命令在仓库根 `d:\app\projects\photo_post` 执行（Flutter 命令需 `cd lumira_app_flutter` 或使用 `cwd` 参数）。

## File Structure

| 文件 | 动作 | 职责 |
|---|---|---|
| `lumira-server/packages/shared/src/types/usage.ts` | 修改 | `UsageItemType`/`UsageEventType` 联合类型扩展 |
| `lumira-server/packages/backend/src/modules/usage/dto/batch-events.dto.ts` | 修改 | `@IsIn` 白名单扩展 |
| `lumira-server/packages/backend/src/modules/usage/dto/batch-events.dto.spec.ts` | 新增 | DTO 校验测试 |
| `lumira-server/packages/backend/src/modules/usage/usage.service.ts` | 修改 | stats 聚合排除 expose/click 行（防污染） |
| `lumira_app_flutter/lib/core/db/dao/usage_dao.dart` | 修改 | 枚举 + `eventTypeName` 映射 |
| `lumira_app_flutter/lib/features/usage/usage_event_recorder.dart` | 修改 | `recordBanner()` |
| `lumira_app_flutter/lib/features/home/data/home_mock_data.dart` | 修改 | `BannerType` + `HomeBannerItem.type/bannerId/trackingId` |
| `lumira_app_flutter/lib/features/home/data/operation_banners.dart` | 新增 | 运营条目目录 + 条件匹配纯函数 |
| `lumira_app_flutter/lib/features/home/services/recommendation_service.dart` | 修改 | 4 槽位重构、文案钩子、bannerId 注入 |
| `lumira_app_flutter/lib/features/home/providers/banner_recommendation_provider.dart` | 修改 | 汇聚运营条件状态并注入 |
| `lumira_app_flutter/lib/features/home/widgets/home_banner.dart` | 修改 | 曝光/点击埋点 |
| `lumira_app_flutter/test/features/home/operation_banners_test.dart` | 新增 | 运营条目匹配测试 |
| `lumira_app_flutter/test/features/home/recommendation_service_test.dart` | 修改 | 4 槽位语义测试重建 |
| `lumira_app_flutter/test/features/usage/usage_event_recorder_test.dart` | 修改 | banner 埋点测试 |
| `docs/future-optimizations.md` | 修改 | 登记后续优化项 |

---

### Task 1: 后端 usage 上报白名单扩展（banner / expose / click）

**Files:**
- Modify: `lumira-server/packages/shared/src/types/usage.ts:2-3`
- Modify: `lumira-server/packages/backend/src/modules/usage/dto/batch-events.dto.ts:16-19`
- Modify: `lumira-server/packages/backend/src/modules/usage/usage.service.ts:46-51`
- Create: `lumira-server/packages/backend/src/modules/usage/dto/batch-events.dto.spec.ts`

**Interfaces:**
- Produces: 上报契约放宽为 `itemType ∈ ['template','scene','banner']`、`eventType ∈ ['open_detail','use_shoot','scene_select','expose','click']`。Flutter 端 Task 2 的 `enqueueEvent(itemType: banner, eventType: 'expose'|'click')` 依赖此白名单；不改则 banner 事件混入批次后整批 400，`markSynced` 永不执行，**全部**埋点同步被阻塞。
- `GET /usage/stats` 响应结构不变（expose/click 不计入 useShoot/openDetail/sceneSelect 聚合，banner 行由 SQL 过滤排除）。

- [ ] **Step 1: 写失败的 DTO 校验测试**

创建 `lumira-server/packages/backend/src/modules/usage/dto/batch-events.dto.spec.ts`：

```ts
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { BatchEventDto } from './batch-events.dto';

function buildEvent(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    clientEventId: 'e1',
    itemType: 'template',
    itemId: 't1',
    itemSource: 'builtin',
    eventType: 'open_detail',
    occurredAt: 1000,
    ...overrides,
  };
}

describe('BatchEventDto 校验', () => {
  it('接受 banner 曝光/点击事件', async () => {
    const dto = plainToInstance(BatchEventDto, {
      events: [
        buildEvent({ clientEventId: 'b1', itemType: 'banner', itemId: 'op_invite', itemSource: 'app', eventType: 'expose' }),
        buildEvent({ clientEventId: 'b2', itemType: 'banner', itemId: 'op_invite', itemSource: 'app', eventType: 'click' }),
      ],
    });
    const errors = await validate(dto);
    expect(errors).toHaveLength(0);
  });

  it('仍接受 template/scene 的既有三类事件', async () => {
    const dto = plainToInstance(BatchEventDto, {
      events: [
        buildEvent({ clientEventId: 'e1', itemType: 'template', eventType: 'open_detail' }),
        buildEvent({ clientEventId: 'e2', itemType: 'template', eventType: 'use_shoot' }),
        buildEvent({ clientEventId: 'e3', itemType: 'scene', itemSource: 'system', eventType: 'scene_select' }),
      ],
    });
    const errors = await validate(dto);
    expect(errors).toHaveLength(0);
  });

  it('拒绝未知 itemType / eventType', async () => {
    const dto = plainToInstance(BatchEventDto, {
      events: [buildEvent({ itemType: 'foo' }), buildEvent({ eventType: 'bar' })],
    });
    const errors = await validate(dto);
    expect(errors.length).toBeGreaterThan(0);
    const flat = JSON.stringify(errors);
    expect(flat).toContain('itemType');
    expect(flat).toContain('eventType');
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

```
cd lumira-server
pnpm --filter @lumira/backend test batch-events
```

预期：第一条「接受 banner 曝光/点击事件」FAIL（`itemType 'banner' 不在白名单`）。

- [ ] **Step 3: 扩展 shared 类型与 DTO 白名单**

`lumira-server/packages/shared/src/types/usage.ts` 前 3 行改为：

```ts
// lumira-server/packages/shared/src/types/usage.ts
export type UsageItemType = 'template' | 'scene' | 'banner';
export type UsageEventType = 'open_detail' | 'use_shoot' | 'scene_select' | 'expose' | 'click';
export type TemplateSource = 'builtin' | 'remote';
```

`lumira-server/packages/backend/src/modules/usage/dto/batch-events.dto.ts` 中 `EventInputDto` 两个白名单改为：

```ts
  @IsIn(['template', 'scene', 'banner']) itemType!: UsageItemType;
  @IsString() @IsNotEmpty() itemId!: string;
  @IsString() @IsNotEmpty() itemSource!: string;
  @IsIn(['open_detail', 'use_shoot', 'scene_select', 'expose', 'click']) eventType!: UsageEventType;
```

（`@IsString() @IsNotEmpty() clientEventId` 等其余行保持不变。）

- [ ] **Step 4: stats 聚合排除 expose/click 行**

`lumira-server/packages/backend/src/modules/usage/usage.service.ts` 的 `stats()` 查询（约 46-51 行）加一行 `event_type IN (...)` 过滤，防止无 itemType 调用时 banner 行以 0/0/0 计数污染响应：

```ts
    const rows = await db.execute(sql`
      SELECT item_id AS itemId, item_type AS itemType, event_type AS eventType, COUNT(*) AS cnt
      FROM ${usageEvents}
      WHERE ${itemType ? sql`item_type = ${itemType}` : sql`1=1`}
        AND event_type IN ('open_detail', 'use_shoot', 'scene_select')
      GROUP BY item_id, item_type, event_type
    `);
```

- [ ] **Step 5: 构建与测试通过**

```
cd lumira-server
pnpm --filter @lumira/shared build
pnpm --filter @lumira/backend build
pnpm --filter @lumira/backend test usage
```

预期：shared/backend 构建零报错；`batch-events.dto.spec.ts` 3 条全 PASS、既有 `usage.service.spec.ts` 全 PASS。

- [ ] **Step 6: commit 并推送双远程（触发后端自动部署）**

```bash
git add lumira-server/packages/shared/src/types/usage.ts lumira-server/packages/backend/src/modules/usage/dto/batch-events.dto.ts lumira-server/packages/backend/src/modules/usage/dto/batch-events.dto.spec.ts lumira-server/packages/backend/src/modules/usage/usage.service.ts
git commit -m "feat(backend): usage 上报白名单扩展 banner 类型与 expose/click 事件，stats 聚合排除非计数行"
git push origin master
git push github master
```

---

### Task 2: Flutter 埋点基础层（UsageDao 枚举 + Recorder.recordBanner）

**Files:**
- Modify: `lumira_app_flutter/lib/core/db/dao/usage_dao.dart:6-16`
- Modify: `lumira_app_flutter/lib/features/usage/usage_event_recorder.dart`
- Test: `lumira_app_flutter/test/features/usage/usage_event_recorder_test.dart`

**Interfaces:**
- Produces: `UsageItemType.banner`；`UsageEventType.bannerExpose` / `UsageEventType.bannerClick`（`eventTypeName` 映射为 `'expose'` / `'click'`，与 Task 1 后端契约对齐）；`UsageEventRecorder.recordBanner({required String bannerId, required UsageEventType event})`。本地 `usage_events.item_type` 为 TEXT 列（无 CHECK），无迁移。

- [ ] **Step 1: 写失败的测试**

在 `lumira_app_flutter/test/features/usage/usage_event_recorder_test.dart` 的 `main()` 内（`tearDown` 之后）追加：

```dart
  test('recordBanner 曝光事件写库：itemType=banner / eventType=expose', () async {
    await recorder.recordBanner(
      bannerId: 'op_invite',
      event: UsageEventType.bannerExpose,
    );
    final events = await dao.getUnsyncedEvents();
    expect(events, hasLength(1));
    expect(events.first[Tables.colItemType], 'banner');
    expect(events.first[Tables.colItemId], 'op_invite');
    expect(events.first[Tables.colItemSource], 'app');
    expect(events.first[Tables.colEventType], 'expose');
  });

  test('recordBanner 点击事件写库：eventType=click', () async {
    await recorder.recordBanner(
      bannerId: 'banner_recent_category:tpl_p2',
      event: UsageEventType.bannerClick,
    );
    final events = await dao.getUnsyncedEvents();
    expect(events, hasLength(1));
    expect(events.first[Tables.colEventType], 'click');
  });
```

- [ ] **Step 2: 运行测试确认失败**

```
cd lumira_app_flutter
flutter test test/features/usage/usage_event_recorder_test.dart
```

预期：编译 FAIL（`bannerExpose` / `recordBanner` 未定义）。

- [ ] **Step 3: 实现**

`lumira_app_flutter/lib/core/db/dao/usage_dao.dart` 头部枚举与映射改为：

```dart
/// 统计对象类型：模板 / 场景 / Banner
enum UsageItemType { template, scene, banner }

/// 统计事件类型
enum UsageEventType { openDetail, useShoot, sceneSelect, bannerExpose, bannerClick }

String eventTypeName(UsageEventType t) {
  if (t == UsageEventType.openDetail) return 'open_detail';
  if (t == UsageEventType.useShoot) return 'use_shoot';
  if (t == UsageEventType.bannerExpose) return 'expose';
  if (t == UsageEventType.bannerClick) return 'click';
  return 'scene_select';
}
```

`lumira_app_flutter/lib/features/usage/usage_event_recorder.dart` 在 `recordScene` 方法后追加：

```dart
  /// Banner 曝光/点击事件。item_type='banner'、itemSource 固定 'app'。
  Future<void> recordBanner({
    required String bannerId,
    required UsageEventType event,
  }) async {
    await _dao.enqueueEvent(
      clientEventId: _uuid(),
      itemType: UsageItemType.banner,
      itemId: bannerId,
      itemSource: 'app',
      eventType: event,
      occurredAt: DateTime.now().millisecondsSinceEpoch,
    );
  }
```

- [ ] **Step 4: 运行测试确认通过**

```
cd lumira_app_flutter
flutter test test/features/usage/usage_event_recorder_test.dart
```

预期：全 PASS（既有用例 + 新增 2 条）。

- [ ] **Step 5: Commit**

```bash
git add lumira_app_flutter/lib/core/db/dao/usage_dao.dart lumira_app_flutter/lib/features/usage/usage_event_recorder.dart lumira_app_flutter/test/features/usage/usage_event_recorder_test.dart
git commit -m "feat(usage): 本地埋点支持 banner 类型与 expose/click 事件"
```

---

### Task 3: BannerType 数据模型 + 运营条目配置

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/data/home_mock_data.dart:95-124`
- Create: `lumira_app_flutter/lib/features/home/data/operation_banners.dart`
- Test: `lumira_app_flutter/test/features/home/operation_banners_test.dart`

**Interfaces:**
- Produces:
  - `enum BannerType { operation, recommend }`
  - `HomeBannerItem` 新增 `final BannerType type`（默认 `recommend`）与 `final String bannerId`（默认 `''`）+ `String get trackingId => bannerId.isNotEmpty ? bannerId : id;` —— 现有构造点（mock 数据、service）零改动兼容。
  - `OperationBanner`（`id/title/subtitle/tag/route/condition`）、`enum OperationCondition { nonNewUserNotInvited, pointsReady, hasLockedTemplate }`、`class OperationUserInputs`（`hasBoundInviter/pointsBalance/hasLockedTemplate`，均可空，null=未知/拉取失败→条件不成立）。
  - `OperationBanner? matchOperationBanner({required bool isNewUser, OperationUserInputs inputs})` —— Task 4 的 service 调用它。
  - `HomeBannerItem operationBannerToItem(OperationBanner b)` —— 运营条目转 Banner（`type: operation`，无封面 → 渲染层品牌渐变背景）。
- Consumes: Task 2 无依赖；纯数据层。

- [ ] **Step 1: 写失败的测试**

创建 `lumira_app_flutter/test/features/home/operation_banners_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/home/data/home_mock_data.dart';
import 'package:lumira_app_flutter/features/home/data/operation_banners.dart';

void main() {
  group('matchOperationBanner', () {
    test('老用户未绑定邀请码 → 邀请运营位', () {
      final op = matchOperationBanner(
        isNewUser: false,
        inputs: const OperationUserInputs(hasBoundInviter: false),
      );
      expect(op, isNotNull);
      expect(op!.id, 'op_invite');
      expect(op.route, '/invite');
      expect(op.tag, '邀请有礼');
    });

    test('新用户不满足邀请条件（即使未绑定）', () {
      final op = matchOperationBanner(
        isNewUser: true,
        inputs: const OperationUserInputs(hasBoundInviter: false),
      );
      expect(op, isNull);
    });

    test('已绑定邀请 + 有积分余额 → 积分运营位', () {
      final op = matchOperationBanner(
        isNewUser: false,
        inputs: const OperationUserInputs(
          hasBoundInviter: true,
          pointsBalance: 30,
        ),
      );
      expect(op!.id, 'op_points');
      expect(op.route, '/points/wallet');
    });

    test('存在未解锁付费模板 → 上新运营位', () {
      final op = matchOperationBanner(
        isNewUser: false,
        inputs: const OperationUserInputs(hasLockedTemplate: true),
      );
      expect(op!.id, 'op_unlock');
      expect(op.route, '/templates/unlock');
    });

    test('多条件同时满足 → 按目录顺序取第一条（邀请优先）', () {
      final op = matchOperationBanner(
        isNewUser: false,
        inputs: const OperationUserInputs(
          hasBoundInviter: false,
          pointsBalance: 30,
          hasLockedTemplate: true,
        ),
      );
      expect(op!.id, 'op_invite');
    });

    test('状态未知（null，离线拉取失败）→ 全部条件不成立', () {
      final op = matchOperationBanner(
        isNewUser: false,
        inputs: const OperationUserInputs(),
      );
      expect(op, isNull);
    });
  });

  group('operationBannerToItem', () {
    test('转为 operation 类型 Banner，trackingId 与路由正确', () {
      final item = operationBannerToItem(kOperationBanners.first);
      expect(item.type, BannerType.operation);
      expect(item.trackingId, 'op_invite');
      expect(item.route, '/invite');
      expect(item.tag, '邀请有礼');
      expect(item.title, isNotEmpty);
      expect(item.subtitle, isNotEmpty);
      // 运营位统一品牌渐变背景：不带模板封面
      expect(item.hasCover, isFalse);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```
cd lumira_app_flutter
flutter test test/features/home/operation_banners_test.dart
```

预期：编译 FAIL（`operation_banners.dart` / `BannerType` 不存在）。

- [ ] **Step 3: 扩展 HomeBannerItem**

`lumira_app_flutter/lib/features/home/data/home_mock_data.dart` 中 `HomeBannerItem` 改为（`/// 首页 Banner 项` 注释处）：

```dart
/// Banner 类型：运营位（App 端静态运营配置）/ 个性化推荐
enum BannerType { operation, recommend }

/// 首页 Banner 项
class HomeBannerItem {
  const HomeBannerItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageSeed,
    required this.tag,
    required this.route,
    this.cover,
    this.coverData,
    this.type = BannerType.recommend,
    this.bannerId = '',
  });
  final String id;
  final String title;
  final String subtitle;
  final String imageSeed;
  final String tag;
  /// 点击跳转路由（带查询参数）
  final String route;
  /// 模板封面（assets 路径或 http URL），用于模板类 banner 背景图。
  /// 非空时与 [coverData] 一起传给 TemplateCoverImage 渲染背景。
  final String? cover;
  /// 模板封面 base64 data URL（自定义模板场景）。
  final String? coverData;

  /// Banner 类型：运营位不打个性化标签，渲染与后续差异展示用
  final BannerType type;

  /// 埋点标识（usage_events.item_id）；模板类 banner 附加来源模板 id
  /// （如 `banner_recent_category:tpl_xxx`）。为空时回退 [id]。
  final String bannerId;

  /// 埋点用最终 id：bannerId 优先，空则回退 id
  String get trackingId => bannerId.isNotEmpty ? bannerId : id;

  /// 是否有模板封面可用
  bool get hasCover =>
      (cover != null && cover!.isNotEmpty) ||
      (coverData != null && coverData!.isNotEmpty);
}
```

（`HomeMockData.banners` 三条静态数据不改 —— 默认 `type: recommend`、`trackingId` 回退 `id`。）

- [ ] **Step 4: 新建运营条目配置**

创建 `lumira_app_flutter/lib/features/home/data/operation_banners.dart`：

```dart
import 'home_mock_data.dart';

/// 运营位展示条件
enum OperationCondition {
  /// 老用户 & 未绑定过邀请码 → 邀请
  nonNewUserNotInvited,

  /// 有积分余额 → 引导去积分中心
  pointsReady,

  /// 存在未解锁付费模板 → 模板上新/解锁
  hasLockedTemplate,
}

/// 运营位条件所需的用户状态快照（由 Provider 汇聚远端数据后注入推荐服务）。
///
/// 各字段 null 表示「拉取失败/未知」，对应条件一律不成立（fail-safe 不出运营位，
/// slot 0 让位给个性化推荐）。
class OperationUserInputs {
  const OperationUserInputs({
    this.hasBoundInviter,
    this.pointsBalance,
    this.hasLockedTemplate,
  });

  /// 是否已绑定过邀请码（GET /invite/stats → myInviter != null）
  final bool? hasBoundInviter;

  /// 积分余额（GET /points/balance → balance）
  final int? pointsBalance;

  /// 是否存在未解锁付费模板（GET /templates/prices + /templates/owned）
  final bool? hasLockedTemplate;
}

/// 首页运营 Banner 条目：指向真实功能，条件满足才参与 slot 0。
/// 未来接入后台下发时，仅需把配置源从本地静态 swap 成远端拉取，
/// 渲染层与埋点层无需改动。
class OperationBanner {
  const OperationBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.route,
    required this.condition,
  });

  final String id;
  final String title;
  final String subtitle;

  /// 如「邀请有礼」「积分乐园」「上新」
  final String tag;

  /// 真实路由：/invite、/points/wallet、/templates/unlock
  final String route;

  /// 展示条件
  final OperationCondition condition;
}

/// 运营条目目录（顺序即优先级，满足者最多取 1 条置于 slot 0）
const List<OperationBanner> kOperationBanners = [
  OperationBanner(
    id: 'op_invite',
    title: '邀请好友 · 双方各+30分',
    subtitle: '绑定邀请码完成首拍，双方各得 30 积分',
    tag: '邀请有礼',
    route: '/invite',
    condition: OperationCondition.nonNewUserNotInvited,
  ),
  OperationBanner(
    id: 'op_points',
    title: '积分当钱花 · 解锁模板',
    subtitle: '拍摄攒积分，攒够就兑换心仪模板',
    tag: '积分乐园',
    route: '/points/wallet',
    condition: OperationCondition.pointsReady,
  ),
  OperationBanner(
    id: 'op_unlock',
    title: '尊享上新 · 一键解锁',
    subtitle: '用积分或邀请奖励，解锁付费模板',
    tag: '上新',
    route: '/templates/unlock',
    condition: OperationCondition.hasLockedTemplate,
  ),
];

/// 单条件是否满足（null 视为不满足）
bool _isConditionSatisfied(
  OperationCondition condition,
  bool isNewUser,
  OperationUserInputs inputs,
) {
  switch (condition) {
    case OperationCondition.nonNewUserNotInvited:
      return !isNewUser && inputs.hasBoundInviter == false;
    case OperationCondition.pointsReady:
      return (inputs.pointsBalance ?? 0) > 0;
    case OperationCondition.hasLockedTemplate:
      return inputs.hasLockedTemplate == true;
  }
}

/// 按目录顺序取第一条满足条件的运营条目；无则返回 null（slot 0 让位个性化）。
OperationBanner? matchOperationBanner({
  required bool isNewUser,
  OperationUserInputs inputs = const OperationUserInputs(),
}) {
  for (final banner in kOperationBanners) {
    if (_isConditionSatisfied(banner.condition, isNewUser, inputs)) {
      return banner;
    }
  }
  return null;
}

/// 运营条目转首页 Banner 项（type=operation，无封面 → 品牌渐变背景）
HomeBannerItem operationBannerToItem(OperationBanner banner) {
  return HomeBannerItem(
    id: banner.id,
    title: banner.title,
    subtitle: banner.subtitle,
    imageSeed: 'banner-op-${banner.id}',
    tag: banner.tag,
    route: banner.route,
    type: BannerType.operation,
    bannerId: banner.id,
  );
}
```

- [ ] **Step 5: 运行测试确认通过**

```
cd lumira_app_flutter
flutter test test/features/home/operation_banners_test.dart
```

预期：全 PASS。

- [ ] **Step 6: Commit**

```bash
git add lumira_app_flutter/lib/features/home/data/home_mock_data.dart lumira_app_flutter/lib/features/home/data/operation_banners.dart lumira_app_flutter/test/features/home/operation_banners_test.dart
git commit -m "feat(home): BannerType 数据模型与运营条目静态配置"
```

---

### Task 4: RecommendationService 4 槽位重构（运营位 slot 0 + 文案钩子 + bannerId）

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/services/recommendation_service.dart`
- Test: `lumira_app_flutter/test/features/home/recommendation_service_test.dart`

**Interfaces:**
- Consumes: Task 3 的 `matchOperationBanner` / `operationBannerToItem` / `OperationUserInputs` / `BannerType`。
- Produces: `Future<List<HomeBannerItem>> buildBanners({OperationUserInputs operationInputs = const OperationUserInputs()})` —— Task 5 的 provider 用新可选参数注入；不传时行为 = 无运营位（4 条纯个性化），既有测试兼容。

**新槽位结构（spec 第三节）：**

```
slot 0  运营位（条件满足则占；否则由个性化补位）
slot 1  新用户引导/问卷（新用户前置判断）或 最近常拍分类（老用户）
slot 2  收藏场景 / 常用套件
slot 3  探索新鲜感
老用户且 slot 0 无运营位 → 补一条探索（维持 4 条）；有运营位则不补
```

- [ ] **Step 1: 更新测试到 4 槽位语义（先改测试，红色）**

`lumira_app_flutter/test/features/home/recommendation_service_test.dart` 改动：

**1a. 文件头注释替换为：**

```dart
/// RecommendationService 单元测试
///
/// 覆盖场景（4 槽位语义）：
/// 1. 新用户无运营位：引导 + 收藏位 fallback + 探索（3 条）
/// 2. 老用户无运营位：常拍 + 收藏位 fallback + 2 条探索（4 条）
/// 3. 运营位 slot 0：各条件命中/优先级/新用户不满足
/// 4. 冷启动全 fallback / 去重 / 收藏场景 / 老用户判定自愈 / 字段完整性
/// 5. 文案钩子：探索位社会证明、常拍位情绪化标题
```

**1b. 导入追加（文件顶部 import 区）：**

```dart
import 'package:lumira_app_flutter/features/home/data/home_mock_data.dart';
import 'package:lumira_app_flutter/features/home/data/operation_banners.dart';
```

**1c. `_seedTemplate` 加 `shortDesc` 可选参数（seed 函数体替换）：**

```dart
/// Seed 一个内置模板（is_builtin=1）
Future<void> _seedTemplate(
  Database db, {
  required String id,
  required String name,
  required String category,
  required bool isRecommended,
  required String description,
  String shortDesc = '',
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.insert(Tables.customTemplates, {
    Tables.colId: id,
    Tables.colName: name,
    Tables.colCategory: category,
    Tables.colDescription: description,
    Tables.colShortDesc: shortDesc,
    Tables.colIsBuiltin: 1,
    Tables.colIsRecommended: isRecommended ? 1 : 0,
    Tables.colCreatedAt: now,
    Tables.colUpdatedAt: now,
  });
}
```

**1d. 将旧测试 1（'新用户槽位 1…'）整体替换为：**

```dart
    test('新用户：引导占 slot 1，探索文案为社会证明（3 条）', () async {
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '适合新手的自然光人像模板');
      await _seedTemplate(db, id: 'tpl_p2', name: '人像进阶', category: 'portrait', isRecommended: true, description: '进阶质感人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光摄影模板');
      await _seedTemplate(db, id: 'tpl_f1', name: '美食模板', category: 'food', isRecommended: true, description: '美食摄影模板');
      await _seedTemplate(db, id: 'tpl_s1', name: '街拍模板', category: 'street', isRecommended: true, description: '街拍模板');
      await _seedTemplate(db, id: 'tpl_n1', name: '夜景模板', category: 'night', isRecommended: true, description: '夜景模板');

      await _seedScene(db, id: 'scene_p1', name: '咖啡馆', category: 'cafe', relatedCategory: 'portrait', isFavorite: false);
      await _seedGalleryItem(db, id: 'g1', sceneId: 'scene_p1', templateId: 'tpl_p1');
      await _seedGalleryItem(db, id: 'g2', sceneId: 'scene_p1', templateId: 'tpl_p1');

      await db.update(Tables.userProgress, {Tables.colTotalPhotos: 2},
          where: '${Tables.colId} = ?', whereArgs: [1]);

      final banners = await service.buildBanners();

      // 4 槽位语义：新用户无运营位 → 引导 + 收藏位 fallback + 探索 = 3 条
      expect(banners.length, 3);

      // slot 1（新用户前置判断）：新用户引导
      expect(banners[0].id, 'banner_new_user_guide');
      expect(banners[0].tag, '新手友好');
      expect(banners[0].title, '新手友好场景');
      expect(banners[0].subtitle, '从咖啡馆开始你的拍摄之旅');
      expect(banners[0].route, '/capture/scene-detail?sceneId=preset_cafe');
      expect(banners[0].type, BannerType.recommend);

      // slot 2：无收藏/套件 → 系统推荐 fallback；bannerId 带来源模板 id，
      // 且排除最近用过的 tpl_p1（相册存在该模板照片）
      expect(banners[1].id, 'banner_favorite_scene_fallback');
      expect(banners[1].bannerId, startsWith('banner_favorite_scene_fallback:'));
      expect(banners[1].bannerId, isNot(contains('tpl_p1')));

      // slot 3：探索新鲜感，社会证明文案
      expect(banners[2].id, 'banner_exploration');
      expect(banners[2].title, '大家都在拍人像');
      expect(banners[2].bannerId, startsWith('banner_exploration:'));

      // 全部为个性化位
      expect(banners.every((b) => b.type == BannerType.recommend), isTrue);
    });
```

**1e. 将旧测试 2（'老用户槽位 5 重复…'）整体替换为：**

```dart
    test('老用户：无运营位 → 4 条，2 条探索补位', () async {
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光模板');
      await _seedTemplate(db, id: 'tpl_f1', name: '美食模板', category: 'food', isRecommended: true, description: '美食模板');
      await _seedTemplate(db, id: 'tpl_s1', name: '街拍模板', category: 'street', isRecommended: true, description: '街拍模板');
      await _seedTemplate(db, id: 'tpl_n1', name: '夜景模板', category: 'night', isRecommended: true, description: '夜景模板');

      await _seedScene(db, id: 'scene_p1', name: '咖啡馆', category: 'cafe', relatedCategory: 'portrait', isFavorite: false);
      for (var i = 0; i < 5; i++) {
        await _seedGalleryItem(db, id: 'g$i', sceneId: 'scene_p1', templateId: 'tpl_p1');
      }
      await db.update(Tables.userProgress, {Tables.colTotalPhotos: 5},
          where: '${Tables.colId} = ?', whereArgs: [1]);

      final banners = await service.buildBanners();

      // 4 条；首槽不再是新手引导
      expect(banners.length, 4);
      expect(banners.first.id, isNot('banner_new_user_guide'));

      // slot 1：常拍分类（无 shortDesc → 功能型标题回退），排除最近用过的 tpl_p1
      expect(banners[0].id, 'banner_recent_category');
      expect(banners[0].tag, '常拍分类');
      expect(banners[0].title, '继续拍人像');
      expect(banners[0].bannerId, 'banner_recent_category:tpl_p2');
      expect(banners[0].subtitle, '你最近常拍人像，试试这套模板');

      // 老用户无运营位 → 补一条探索，共 2 条
      final explorationBanners =
          banners.where((b) => b.id.startsWith('banner_exploration')).toList();
      expect(explorationBanners.length, 2);
      expect(explorationBanners.first.id != explorationBanners.last.id, isTrue);
      expect(explorationBanners.first.title != explorationBanners.last.title, isTrue);
    });
```

**1f. 将旧测试 3（'冷启动全 fallback…'）整体替换为：**

```dart
    test('冷启动全 fallback：新用户无任何数据 → 引导 + 2 条系统推荐', () async {
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '适合新手的自然光人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光摄影模板');
      await _seedTemplate(db, id: 'tpl_f1', name: '美食模板', category: 'food', isRecommended: true, description: '美食摄影模板');
      await _seedTemplate(db, id: 'tpl_s1', name: '街拍模板', category: 'street', isRecommended: true, description: '街拍模板');
      await _seedTemplate(db, id: 'tpl_n1', name: '夜景模板', category: 'night', isRecommended: true, description: '夜景模板');

      final banners = await service.buildBanners();

      // 新用户：引导 + 收藏位 fallback + 探索 = 3 条
      expect(banners.length, 3);
      expect(banners.first.id, 'banner_new_user_guide');
      expect(banners.first.route, '/capture/scene-detail?sceneId=preset_cafe');

      // 收藏位 fallback 与探索位均来自系统推荐模板
      final templateRoutes = banners
          .where((b) => b.route.startsWith('/templates/detail?templateId='))
          .toList();
      expect(templateRoutes.length, 2,
          reason: '收藏位 fallback + 探索位均为系统推荐模板');

      expect(banners[1].tag, '为你精选');
      expect(banners[2].tag, '探索新鲜');
    });
```

**1g. 将旧测试 4（'5 条 banner 去重…'）整体替换为：**

```dart
    test('4 条 banner 去重：templateId 不重复', () async {
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光模板');
      await _seedTemplate(db, id: 'tpl_f1', name: '美食模板', category: 'food', isRecommended: true, description: '美食模板');
      await _seedTemplate(db, id: 'tpl_s1', name: '街拍模板', category: 'street', isRecommended: true, description: '街拍模板');
      await _seedTemplate(db, id: 'tpl_n1', name: '夜景模板', category: 'night', isRecommended: true, description: '夜景模板');
      await _seedTemplate(db, id: 'tpl_m1', name: '微距模板', category: 'macro', isRecommended: true, description: '微距模板');

      await _seedScene(db, id: 'scene_p1', name: '咖啡馆', category: 'cafe', relatedCategory: 'portrait', isFavorite: false);
      for (var i = 0; i < 3; i++) {
        await _seedGalleryItem(db, id: 'g$i', sceneId: 'scene_p1', templateId: 'tpl_p1');
      }
      await db.update(Tables.userProgress, {Tables.colTotalPhotos: 3},
          where: '${Tables.colId} = ?', whereArgs: [1]);

      final banners = await service.buildBanners();

      // 老用户无运营位：4 条全部为模板类
      expect(banners.length, 4);
      final templateIds = banners
          .where((b) => b.route.contains('templateId='))
          .map((b) => b.route.split('templateId=').last)
          .toList();
      expect(templateIds.length, 4);
      expect(templateIds.toSet().length, templateIds.length,
          reason: 'templateId 在 4 条 banner 中应全部唯一');
    });
```

**1h. 将旧测试 6（'老用户判定自愈…'）中两处期望改为 4 条：**

```dart
      final banners = await service.buildBanners();

      // 应被判定为老用户：首槽不再是新手友好场景
      expect(banners.first.id, isNot('banner_new_user_guide'));
      // 4 条，且老用户无运营位时有 2 条探索
      expect(banners.length, 4);
      final exploration =
          banners.where((b) => b.id.startsWith('banner_exploration')).toList();
      expect(exploration.length, 2);
```

**1i. 将旧测试 7（'HomeBannerItem 字段完整性…'）替换为：**

```dart
    test('HomeBannerItem 字段完整性：每条 banner 字段非空', () async {
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光模板');
      await _seedTemplate(db, id: 'tpl_f1', name: '美食模板', category: 'food', isRecommended: true, description: '美食模板');
      await _seedTemplate(db, id: 'tpl_s1', name: '街拍模板', category: 'street', isRecommended: true, description: '街拍模板');
      await _seedTemplate(db, id: 'tpl_n1', name: '夜景模板', category: 'night', isRecommended: true, description: '夜景模板');

      final banners = await service.buildBanners();

      expect(banners.length, 3);
      for (final b in banners) {
        expect(b.id, isNotEmpty, reason: 'id 不能为空');
        expect(b.title, isNotEmpty, reason: 'title 不能为空');
        expect(b.subtitle, isNotEmpty, reason: 'subtitle 不能为空');
        expect(b.imageSeed, isNotEmpty, reason: 'imageSeed 不能为空');
        expect(b.tag, isNotEmpty, reason: 'tag 不能为空');
        expect(b.route, isNotEmpty, reason: 'route 不能为空');
        expect(b.route.startsWith('/'), isTrue,
            reason: 'route 应以 / 开头：${b.route}');
        expect(b.trackingId, isNotEmpty, reason: 'trackingId 不能为空');
        expect(b.type, BannerType.recommend);
      }
    });
```

（旧测试 5 '收藏场景' 仅把 `expect(banners.length, 5)` 改为 `expect(banners.length, 4)`，其余断言不变。）

**1j. 在 group 末尾追加运营位与文案钩子新测试：**

```dart
    test('运营位 slot 0：老用户未绑定邀请 → 邀请运营位占位且不补探索', () async {
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光模板');
      await _seedTemplate(db, id: 'tpl_f1', name: '美食模板', category: 'food', isRecommended: true, description: '美食模板');
      await _seedTemplate(db, id: 'tpl_s1', name: '街拍模板', category: 'street', isRecommended: true, description: '街拍模板');
      await _seedTemplate(db, id: 'tpl_n1', name: '夜景模板', category: 'night', isRecommended: true, description: '夜景模板');
      await _seedScene(db, id: 'scene_p1', name: '咖啡馆', category: 'cafe', relatedCategory: 'portrait', isFavorite: false);
      for (var i = 0; i < 5; i++) {
        await _seedGalleryItem(db, id: 'g$i', sceneId: 'scene_p1', templateId: 'tpl_p1');
      }
      await db.update(Tables.userProgress, {Tables.colTotalPhotos: 5},
          where: '${Tables.colId} = ?', whereArgs: [1]);

      final banners = await service.buildBanners(
        operationInputs: const OperationUserInputs(hasBoundInviter: false),
      );

      expect(banners.length, 4);
      // slot 0：运营位
      expect(banners.first.id, 'op_invite');
      expect(banners.first.type, BannerType.operation);
      expect(banners.first.bannerId, 'op_invite');
      expect(banners.first.tag, '邀请有礼');
      expect(banners.first.route, '/invite');
      // slot 0 有运营位 → 老用户不补探索，仅 1 条
      final exploration =
          banners.where((b) => b.id.startsWith('banner_exploration')).toList();
      expect(exploration.length, 1);
      // 其余槽位仍是个性化
      expect(banners[1].id, 'banner_recent_category');
      expect(banners[2].id, 'banner_favorite_scene_fallback');
    });

    test('运营位 slot 0：已绑定邀请但有积分 → 积分运营位', () async {
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光模板');
      await _seedScene(db, id: 'scene_p1', name: '咖啡馆', category: 'cafe', relatedCategory: 'portrait', isFavorite: false);
      for (var i = 0; i < 5; i++) {
        await _seedGalleryItem(db, id: 'g$i', sceneId: 'scene_p1', templateId: 'tpl_p1');
      }
      await db.update(Tables.userProgress, {Tables.colTotalPhotos: 5},
          where: '${Tables.colId} = ?', whereArgs: [1]);

      final banners = await service.buildBanners(
        operationInputs: const OperationUserInputs(
          hasBoundInviter: true,
          pointsBalance: 30,
        ),
      );

      expect(banners.first.id, 'op_points');
      expect(banners.first.type, BannerType.operation);
      expect(banners.first.route, '/points/wallet');
    });

    test('运营位 slot 0：存在未解锁付费模板 → 上新运营位', () async {
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光模板');
      await _seedScene(db, id: 'scene_p1', name: '咖啡馆', category: 'cafe', relatedCategory: 'portrait', isFavorite: false);
      for (var i = 0; i < 5; i++) {
        await _seedGalleryItem(db, id: 'g$i', sceneId: 'scene_p1', templateId: 'tpl_p1');
      }
      await db.update(Tables.userProgress, {Tables.colTotalPhotos: 5},
          where: '${Tables.colId} = ?', whereArgs: [1]);

      final banners = await service.buildBanners(
        operationInputs: const OperationUserInputs(hasLockedTemplate: true),
      );

      expect(banners.first.id, 'op_unlock');
      expect(banners.first.route, '/templates/unlock');
    });

    test('运营位 slot 0：多条件满足 → 目录顺序优先（邀请）', () async {
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光模板');
      await _seedScene(db, id: 'scene_p1', name: '咖啡馆', category: 'cafe', relatedCategory: 'portrait', isFavorite: false);
      for (var i = 0; i < 5; i++) {
        await _seedGalleryItem(db, id: 'g$i', sceneId: 'scene_p1', templateId: 'tpl_p1');
      }
      await db.update(Tables.userProgress, {Tables.colTotalPhotos: 5},
          where: '${Tables.colId} = ?', whereArgs: [1]);

      final banners = await service.buildBanners(
        operationInputs: const OperationUserInputs(
          hasBoundInviter: false,
          pointsBalance: 30,
          hasLockedTemplate: true,
        ),
      );

      expect(banners.first.id, 'op_invite');
    });

    test('新用户不满足邀请条件（即使未绑定）→ slot 0 让位引导', () async {
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光模板');
      await _seedScene(db, id: 'scene_p1', name: '咖啡馆', category: 'cafe', relatedCategory: 'portrait', isFavorite: false);
      await _seedGalleryItem(db, id: 'g1', sceneId: 'scene_p1', templateId: 'tpl_p1');
      await _seedGalleryItem(db, id: 'g2', sceneId: 'scene_p1', templateId: 'tpl_p1');
      await db.update(Tables.userProgress, {Tables.colTotalPhotos: 2},
          where: '${Tables.colId} = ?', whereArgs: [1]);

      final banners = await service.buildBanners(
        operationInputs: const OperationUserInputs(hasBoundInviter: false),
      );

      expect(banners.first.id, 'banner_new_user_guide');
      expect(banners.first.type, BannerType.recommend);
    });

    test('文案钩子：常拍模板有 shortDesc 时标题用它', () async {
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '人像模板');
      await _seedTemplate(db, id: 'tpl_p2', name: '人像进阶', category: 'portrait', isRecommended: true, description: '进阶质感人像模板', shortDesc: '雷阵雨后的街头光影');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光模板');
      await _seedScene(db, id: 'scene_p1', name: '咖啡馆', category: 'cafe', relatedCategory: 'portrait', isFavorite: false);
      for (var i = 0; i < 5; i++) {
        await _seedGalleryItem(db, id: 'g$i', sceneId: 'scene_p1', templateId: 'tpl_p1');
      }
      await db.update(Tables.userProgress, {Tables.colTotalPhotos: 5},
          where: '${Tables.colId} = ?', whereArgs: [1]);

      final banners = await service.buildBanners();

      // slot 1：排除最近用过的 tpl_p1 → tpl_p2，标题用其 shortDesc（情绪价值）
      expect(banners[0].id, 'banner_recent_category');
      expect(banners[0].title, '雷阵雨后的街头光影');
      expect(banners[0].subtitle, '你最近常拍人像，试试这套模板');
    });
```

- [ ] **Step 2: 运行测试确认失败**

```
cd lumira_app_flutter
flutter test test/features/home/recommendation_service_test.dart
```

预期：编译 FAIL（`operationInputs` 参数不存在）或断言 FAIL（5 槽位旧语义）。

- [ ] **Step 3: 重构 RecommendationService**

`lumira_app_flutter/lib/features/home/services/recommendation_service.dart`：

**3a. import 区追加：**

```dart
import '../data/operation_banners.dart';
```

**3b. 类头注释（`/// 首页 Banner 推荐服务` 块）替换为：**

```dart
/// 首页 Banner 推荐服务
///
/// 4 个固定槽位：
/// 0. 运营位（[OperationUserInputs] 条件满足则占，否则让位个性化补位）
/// 1. 新用户引导/问卷（新用户前置判断）或最近常拍分类（老用户）
/// 2. 基于收藏场景/常用套件
/// 3. 探索新鲜感（用户少拍的类型）；老用户且 slot 0 无运营位时补一条
```

**3c. `buildBanners()` 方法整体替换为：**

```dart
  /// 构建首页 Banner（4 槽位：运营位 + 个性化位）
  ///
  /// [operationInputs] 为运营位条件所需的用户状态快照（远端拉取，失败/离线
  /// 传空 → 不出运营位，slot 0 由个性化补位）。
  Future<List<HomeBannerItem>> buildBanners({
    OperationUserInputs operationInputs = const OperationUserInputs(),
  }) async {
    // 并行启动所有数据源查询（Future 创建即开始执行，await 顺序不影响并行性）
    final categoryCountsFuture = _galleryDao.countByCategory();
    final favoriteScenesFuture = _scenesDao.getFavorites();
    final totalPhotosFuture = _growthDao.getTotalPhotos();
    final allKitsFuture = _kitsDao.getAll();
    // 候选池 = 内置推荐位 ∪ 全部远程模板（后台实时下发的运营模板参与 Banner 推荐）
    final systemPicksFuture = _templatesDao.getRecommendedCandidatePool();
    final popularityFuture = _loadTemplatePopularity();

    final categoryCounts = await categoryCountsFuture;
    final favoriteScenes = await favoriteScenesFuture;
    final totalPhotos = await totalPhotosFuture;
    final allKits = await allKitsFuture;
    final systemPicks = await systemPicksFuture;
    final popularity = await popularityFuture;
    final interestById = await _loadTemplateInterest(systemPicks);
    // 最近用过的模板（用户已实际拍摄过/相册里存在的），推荐时优先排除，
    // 避免轮播重复推用户刚用过的同款内容（与主流推荐 app 一致）。
    final recentlyUsed = await _loadRecentlyUsedTemplateIds();

    // 客户端按 usage_count DESC 排序（DAO 未提供 orderByUsage 参数）
    final kitsByUsage = [...allKits]..sort((a, b) => b.usageCount.compareTo(a.usageCount));

    final isNewUser = totalPhotos < _kNewUserThreshold;

    final List<HomeBannerItem> banners = [];
    final Set<String> usedTemplateIds = {};
    final Set<String> usedSceneIds = {};
    final Set<String> usedCategories = {};

    // === slot 0：运营位（条件满足则占，否则让位给个性化补位） ===
    final operation = matchOperationBanner(
      isNewUser: isNewUser,
      inputs: operationInputs,
    );
    if (operation != null) {
      banners.add(operationBannerToItem(operation));
    }

    // === slot 1：新用户引导/问卷（前置判断）或最近常拍分类 ===
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
            bannerId: 'banner_questionnaire_pick:${tpl.id}',
            title: '从$label开始',
            subtitle: tpl.description.isNotEmpty
                ? _truncate(tpl.description, 30)
                : '根据你的偏好推荐',
            imageSeed: 'banner-questionnaire-$topCat',
            tag: '为你推荐',
            route: '/templates/detail?templateId=${tpl.id}',
            cover: tpl.cover.isNotEmpty ? tpl.cover : null,
            coverData: tpl.coverData,
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
            route: '/capture/scene-detail?sceneId=preset_cafe',
          ));
      if (questionnaireBanner == null) {
        usedSceneIds.add('preset_cafe');
      }
    } else {
      // 老用户：基于最近拍摄分类
      final topCategory = _pickTopCategory(categoryCounts);
      TemplateRecord? slot1Tpl;
      var slot1Tag = '为你精选'; // 冷启动 fallback 标签
      if (topCategory != null) {
        // 去重：排除已占用模板 + 最近用过模板
        final tpls = await _templatesDao.getBuiltin(
          category: topCategory,
          isRecommended: true,
        );
        final candidates = _rankCandidates(
          tpls,
          usedTemplateIds,
          recentlyUsed: recentlyUsed,
        );
        if (candidates.isNotEmpty) {
          slot1Tpl = _pickBest(candidates, popularity, interestById);
          slot1Tag = '常拍分类';
          usedCategories.add(topCategory);
        }
      }
      slot1Tpl ??= _pickUnusedSystemPick(
        systemPicks,
        usedTemplateIds,
        popularity,
        interestById,
        recentlyUsed,
      );
      if (slot1Tpl != null) {
        usedTemplateIds.add(slot1Tpl.id);
        final label = _categoryLabelMap[topCategory] ?? '推荐';
        final hasCategory = topCategory != null;
        // 文案钩子：有常拍分类时优先用模板 shortDesc 做情境化情绪标题
        // （如「雷阵雨后的街头光影」），无 shortDesc 回退「继续拍X」
        final title = hasCategory
            ? (slot1Tpl.shortDesc.isNotEmpty
                ? slot1Tpl.shortDesc
                : '继续拍$label')
            : slot1Tpl.name;
        final subtitle =
            hasCategory ? '你最近常拍$label，试试这套模板' : _bannerSubtitle(slot1Tpl);
        banners.add(HomeBannerItem(
          id: 'banner_recent_category',
          bannerId: 'banner_recent_category:${slot1Tpl.id}',
          title: title,
          subtitle: subtitle,
          imageSeed: 'banner-recent-${topCategory ?? slot1Tpl.id}',
          tag: slot1Tag,
          route: '/templates/detail?templateId=${slot1Tpl.id}',
          cover: slot1Tpl.cover.isNotEmpty ? slot1Tpl.cover : null,
          coverData: slot1Tpl.coverData,
        ));
      }
    }

    // === slot 2：基于收藏场景/常用套件 ===
    final favScene = favoriteScenes.isNotEmpty ? favoriteScenes.first : null;
    // 内置场景的收藏行 name 可能为空（仅标记位），需 fallback
    final hasValidFav = favScene != null && favScene.name.isNotEmpty;
    CompositionKit? fallbackKit;
    if (!hasValidFav && kitsByUsage.isNotEmpty) {
      fallbackKit = kitsByUsage.first;
    }
    if (hasValidFav) {
      final fav = favScene;
      final sceneId = fav.id;
      usedSceneIds.add(sceneId);
      banners.add(HomeBannerItem(
        id: 'banner_favorite_scene',
        title: '${fav.name}灵感',
        subtitle: '你收藏的场景，新的拍摄灵感',
        imageSeed: 'banner-fav-$sceneId',
        tag: '收藏场景',
        route: '/capture/scene-detail?sceneId=$sceneId',
      ));
    } else if (fallbackKit != null &&
        !usedSceneIds.contains(fallbackKit.sceneId)) {
      final sceneId = fallbackKit.sceneId;
      usedSceneIds.add(sceneId);
      banners.add(HomeBannerItem(
        id: 'banner_kit_scene',
        title: '${fallbackKit.name}灵感',
        subtitle: '你常用的套件，新的拍摄灵感',
        imageSeed: 'banner-kit-${fallbackKit.id}',
        tag: '收藏场景',
        route: '/capture/scene-detail?sceneId=$sceneId',
      ));
    } else {
      // 全空 fallback：系统推荐模板
      final tpl = _pickUnusedSystemPick(systemPicks, usedTemplateIds, popularity);
      if (tpl != null) {
        usedTemplateIds.add(tpl.id);
        banners.add(HomeBannerItem(
          id: 'banner_favorite_scene_fallback',
          bannerId: 'banner_favorite_scene_fallback:${tpl.id}',
          title: tpl.name,
          subtitle: _bannerSubtitle(tpl),
          imageSeed: 'banner-pick-${tpl.id}',
          tag: '为你精选',
          route: '/templates/detail?templateId=${tpl.id}',
          cover: tpl.cover.isNotEmpty ? tpl.cover : null,
          coverData: tpl.coverData,
        ));
      }
    }

    // === slot 3：探索新鲜感（用户少拍的类型） ===
    await _buildExplorationBanner(
      banners: banners,
      categoryCounts: categoryCounts,
      usedCategories: usedCategories,
      usedTemplateIds: usedTemplateIds,
      systemPicks: systemPicks,
      idSuffix: '',
      popularity: popularity,
      interestById: interestById,
      recentlyUsed: recentlyUsed,
    );

    // === 老用户补位：slot 0 无运营条目时再补一条探索，维持总量 4 条 ===
    if (operation == null && !isNewUser) {
      await _buildExplorationBanner(
        banners: banners,
        categoryCounts: categoryCounts,
        usedCategories: usedCategories,
        usedTemplateIds: usedTemplateIds,
        systemPicks: systemPicks,
        idSuffix: '_extra',
        popularity: popularity,
        interestById: interestById,
        recentlyUsed: recentlyUsed,
      );
    }

    // 防御性截断：固定 4 条
    return banners.take(4).toList();
  }
```

**3d. 删除原「槽位 4：系统推荐模板」代码块**（`final slot4Tpl = _pickUnusedSystemPick(...)` 到对应 `if` 结束，约原 268-282 行）。

**3e. `_buildExplorationBanner` 内两处 `banners.add(HomeBannerItem(...))` 改文案与 bannerId** —— 分类命中分支改为：

```dart
      if (tpl != null) {
        usedTemplateIds.add(tpl.id);
        final label = _categoryLabelMap[explorationCat] ?? explorationCat;
        banners.add(HomeBannerItem(
          id: 'banner_exploration$idSuffix',
          bannerId: 'banner_exploration$idSuffix:${tpl.id}',
          // 文案钩子：社会证明（基于分类热度/「最近都在拍」）
          title: '大家都在拍$label',
          subtitle: _bannerSubtitle(tpl),
          imageSeed: 'banner-explore-$explorationCat$idSuffix',
          tag: '探索新鲜',
          route: '/templates/detail?templateId=${tpl.id}',
          cover: tpl.cover.isNotEmpty ? tpl.cover : null,
          coverData: tpl.coverData,
        ));
      }
```

fallback 分支（无可用分类 → 系统推荐）改为：

```dart
      // 无可用分类时，fallback 到系统推荐
      final tpl = _pickUnusedSystemPick(systemPicks, usedTemplateIds, popularity,
          interestById, recentlyUsed);
      if (tpl != null) {
        usedTemplateIds.add(tpl.id);
        banners.add(HomeBannerItem(
          id: 'banner_exploration$idSuffix',
          bannerId: 'banner_exploration$idSuffix:${tpl.id}',
          title: tpl.name,
          subtitle: _bannerSubtitle(tpl),
          imageSeed: 'banner-pick-${tpl.id}$idSuffix',
          tag: '为你精选',
          route: '/templates/detail?templateId=${tpl.id}',
          cover: tpl.cover.isNotEmpty ? tpl.cover : null,
          coverData: tpl.coverData,
        ));
      }
```

（其余 helper 方法：`_bannerSubtitle`、`_pickTopCategory`、`_pickExplorationCategory`、`_rankCandidates`、`_pickBest`、`_pickUnusedSystemPick`、`_blendScore`、`_loadRecentlyUsedTemplateIds`、`_loadTemplateInterest`、`_loadTemplatePopularity`、`_truncate` 均不动。）

- [ ] **Step 4: 运行测试确认通过**

```
cd lumira_app_flutter
flutter test test/features/home/recommendation_service_test.dart
```

预期：全 PASS。若个别断言因模板选择 tie-break 失败，只放宽**非确定性**断言（不断言具体 fallback 模板 id），禁止改动断言语义。

- [ ] **Step 5: Commit**

```bash
git add lumira_app_flutter/lib/features/home/services/recommendation_service.dart lumira_app_flutter/test/features/home/recommendation_service_test.dart
git commit -m "feat(home): Banner 重构为运营位+个性化的 4 槽位结构，文案钩子与 bannerId 注入"
```

---

### Task 5: Provider 注入运营条件状态

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/providers/banner_recommendation_provider.dart`

**Interfaces:**
- Consumes: Task 3 `OperationUserInputs`；Task 4 `buildBanners(operationInputs:)`；现有 `inviteRepositoryProvider`（`lib/features/invite/data/invite_repository.dart`）、`pointsRepositoryProvider`（`lib/features/points/data/points_repository.dart`）、`ownedTemplatesRepositoryProvider`（`lib/features/templates/data/owned_templates_repository.dart`）。
- Produces: `bannerRecommendationProvider` 输出携带运营位的 4 条 Banner；离线/接口失败 → 条件为 null → 不出运营位。

- [ ] **Step 1: 重写 provider 文件**

`lumira_app_flutter/lib/features/home/providers/banner_recommendation_provider.dart` 全文替换为：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../features/profile/providers/growth_providers.dart';
import '../../invite/data/invite_repository.dart';
import '../../points/data/points_repository.dart';
import '../../templates/data/owned_templates_repository.dart';
import '../data/home_mock_data.dart';
import '../data/operation_banners.dart';
import '../services/recommendation_service.dart';

/// 首页 Banner 推荐 Provider
///
/// 通过 [RecommendationService] 基于用户真实拍摄历史生成 4 条 banner
/// （slot 0 运营位 + 3 个个性化位）。
/// FutureProvider 自动缓存，tab 切换不重新计算；
/// 拍摄完成保存到 gallery 后由 capture_page 调 `ref.invalidate` 触发刷新。
final bannerRecommendationProvider =
    FutureProvider<List<HomeBannerItem>>((ref) async {
  final service = RecommendationService(
    galleryDao: await ref.watch(galleryDaoProvider.future),
    scenesDao: await ref.watch(scenesDaoProvider.future),
    templatesDao: await ref.watch(templatesDaoProvider.future),
    kitsDao: await ref.watch(compositionKitsDaoProvider.future),
    growthDao: await ref.watch(growthDaoProvider.future),
    questionnaireDao: await ref.watch(questionnaireDaoProvider.future),
    usageDao: await ref.watch(usageDaoProvider.future),
    interestDao: await ref.watch(userInterestsDaoProvider.future),
  );
  final operationInputs = await _loadOperationInputs(ref);
  return service.buildBanners(operationInputs: operationInputs);
});

/// 汇聚运营位条件所需的用户状态（远端；离线/失败降级为 null → 不出运营位）。
///
/// 三个来源并行拉取、各自容错：
/// - 是否已绑定邀请码：GET /invite/stats → myInviter
/// - 积分余额：GET /points/balance → balance
/// - 是否存在未解锁付费模板：GET /templates/prices + GET /templates/owned
Future<OperationUserInputs> _loadOperationInputs(Ref ref) async {
  final hasBoundInviter = _tryLoad(() async {
    final repo = await ref.watch(inviteRepositoryProvider.future);
    final stats = await repo.stats();
    return stats.myInviter != null;
  });
  final pointsBalance = _tryLoad(() async {
    final repo = await ref.watch(pointsRepositoryProvider.future);
    return (await repo.getBalance()).balance;
  });
  final hasLockedTemplate = _tryLoad(() async {
    final repo = await ref.watch(ownedTemplatesRepositoryProvider.future);
    final prices = await repo.listPrices();
    final owned = await repo.listOwned();
    return prices.prices.any((p) =>
        p.isActive &&
        p.priceCredits > 0 &&
        !owned.templateIds.contains(p.templateId));
  });

  return OperationUserInputs(
    hasBoundInviter: await hasBoundInviter,
    pointsBalance: await pointsBalance,
    hasLockedTemplate: await hasLockedTemplate,
  );
}

/// 容错加载：失败（离线/接口异常）返回 null，不阻塞 Banner 主流程。
Future<T?> _tryLoad<T>(Future<T> Function() loader) async {
  try {
    return await loader();
  } catch (_) {
    return null;
  }
}
```

- [ ] **Step 2: 验证编译与既有测试**

```
cd lumira_app_flutter
flutter analyze
flutter test test/features/home/
```

预期：analyze 无新增错误（存量 `capture_preview_template_page.dart` 报错与本任务无关，需确认非本次改动引入）；测试全 PASS。

- [ ] **Step 3: Commit**

```bash
git add lumira_app_flutter/lib/features/home/providers/banner_recommendation_provider.dart
git commit -m "feat(home): Banner 推荐注入运营位条件状态（远端容错汇聚）"
```

---

### Task 6: HomeBanner 曝光/点击埋点

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/widgets/home_banner.dart`

**Interfaces:**
- Consumes: Task 2 `UsageEventRecorder.recordBanner` + `UsageEventType`；`usageEventRecorderProvider`（`lib/features/usage/usage_providers.dart`）；Task 3 `HomeBannerItem.trackingId`。
- 埋点契约：曝光 = banner 成为当前页（首帧后 + onPageChanged）且轮播处于外层可视区，按 `trackingId` 会话内去重；点击 = `onTap` 时上报。均 `item_type='banner'`，失败静默。

- [ ] **Step 1: 加 import 与曝光去重集合**

`home_banner.dart` import 区追加：

```dart
import '../../../core/db/dao/usage_dao.dart';
import '../../usage/usage_providers.dart';
```

`_HomeBannerState` 字段区（`int _bannerCount = 0;` 之后）追加：

```dart
  /// 会话内已上报曝光的 bannerId（去重：自动轮播/来回滑动不重复计曝光）
  final Set<String> _exposedBannerIds = {};
```

- [ ] **Step 2: 加埋点方法**

`_HomeBannerState` 内（`_onManualScroll` 方法之后）追加：

```dart
  /// Banner 埋点：曝光/点击写入本地 usage_events 队列
  /// （失败静默降级，不影响 Banner 渲染与跳转；启动时由 usageSyncService 统一上报）
  void _recordBannerEvent(String bannerId, UsageEventType event) {
    ref
        .read(usageEventRecorderProvider.future)
        .then((recorder) =>
            recorder.recordBanner(bannerId: bannerId, event: event))
        .catchError((_) {});
  }

  /// 曝光埋点：banner 成为当前页时上报一次（按 trackingId 会话内去重）
  void _reportExpose(List<HomeBannerItem> banners, int realIndex) {
    if (realIndex < 0 || realIndex >= banners.length) return;
    final banner = banners[realIndex];
    if (!_exposedBannerIds.add(banner.trackingId)) return;
    _recordBannerEvent(banner.trackingId, UsageEventType.bannerExpose);
  }
```

- [ ] **Step 3: 挂接曝光（首帧 + 翻页）与点击**

`_buildCarousel` 中 `SizedBox(height: 150, ...)` 的 `PageView.builder` 部分改为：

```dart
        SizedBox(
          height: 150,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onManualScroll,
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) {
                setState(() => _current = i);
                _reportExpose(banners, i % count);
              },
              // 无限模式：足够大的虚拟 itemCount，index%count 映射到真实 banner
              itemCount: count * _kRepeat,
              itemBuilder: (_, index) {
                final banner = banners[index % count];
                return _BannerCard(
                  banner: banner,
                  tokens: tokens,
                  onTap: () {
                    // 点击埋点：失败静默，不阻断跳转
                    _recordBannerEvent(
                        banner.trackingId, UsageEventType.bannerClick);
                    GoRouter.of(context).push(banner.route);
                  },
                );
              },
            ),
          ),
        ),
```

并在 `_buildCarousel` 的 `if (banners.isEmpty) return const SizedBox.shrink();` 与 `final count = banners.length;` 之后追加首屏曝光：

```dart
    // 首屏曝光：首帧渲染后上报当前页（仅当轮播处于外层可视区）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isInViewport()) _reportExpose(banners, _current % count);
    });
```

（每次 rebuild 都会调度一次 postFrame 回调，由 `_exposedBannerIds` 去重保证每条 banner 只报一次曝光，简单且防御性足够。）

- [ ] **Step 4: 验证编译与既有测试**

```
cd lumira_app_flutter
flutter analyze
flutter test test/features/home/
```

预期：analyze 无新增错误；测试全 PASS。

- [ ] **Step 5: Commit**

```bash
git add lumira_app_flutter/lib/features/home/widgets/home_banner.dart
git commit -m "feat(home): Banner 曝光/点击埋点（可视区判定 + 会话内去重）"
```

---

### Task 7: 收尾——后续优化登记 + 全量验证

**Files:**
- Modify: `docs/future-optimizations.md`

- [ ] **Step 1: 登记后续优化项**

在 `docs/future-optimizations.md` 文件**末尾**追加：

```markdown
---

## 首页 Banner 运营化（2026-09-09）

### P1 · 后端运营 Banner 下发系统 + 后台运营位管理页

- **模块**：首页 Banner（Flutter + NestJS 后端 + Next.js 后台）
- **优化点**：运营位当前为 App 端静态配置（`lumira_app_flutter/lib/features/home/data/operation_banners.dart`），条目/文案/条件改版需发版。后续建后端运营位下发系统与后台管理页。
- **背景/动机**：设计文档《首页 Banner 运营化重构》将此列为非目标、留待单独立项；当前静态配置已与 `BannerType` / 运营条目模型（`OperationBanner`/`OperationCondition`）对齐，未来接入远端下发仅需把配置源从本地静态 swap 成远端拉取，渲染层与埋点层无需改动。
- **目标状态**：后端提供运营位配置 CRUD + 下发接口；App 启动/进首页拉取运营条目（离线缓存兜底静态配置）；后台管理页可视化编辑条目/条件/文案。
- **状态**：⏳ 待优化

### P2 · 运营位 A/B 实验 / 时段定向 / 人群定向投放引擎

- **模块**：首页 Banner（后端）
- **优化点**：当前运营位仅按单一用户状态条件取目录中第一条满足的条目，无实验分流与定向投放能力。
- **背景/动机**：设计文档非目标项；依赖运营位下发系统先落地。曝光/点击埋点（`item_type='banner'`，`event_type='expose'/'click'`）已可按 `item_id` 聚合出单槽位点击率，为后续实验提供数据基础。
- **目标状态**：支持按设备分桶做 A/B 文案实验、按时段/人群定向投放，基于埋点闭环迭代。
- **状态**：⏳ 待优化
```

- [ ] **Step 2: 全量验证**

```
cd lumira_app_flutter
flutter analyze
flutter test test/features/home/ test/features/usage/
```

预期：analyze 无**本次改动引入**的错误；上述测试全 PASS。

- [ ] **Step 3: 手动验证清单（真机/模拟器，交付给用户确认）**

- 老用户未绑定邀请码：首条 Banner 为「邀请好友 · 双方各+30分」，点击进入 `/invite`；
- 积分余额 > 0（已绑邀请）：首条为「积分当钱花 · 解锁模板」→ `/points/wallet`；
- 存在未解锁付费模板：首条为「尊享上新 · 一键解锁」→ `/templates/unlock`；
- 断网启动（运营条件拉取失败）：slot 0 无运营位，4 条个性化不空白；
- 新用户（< 3 张照片）：首条为新用户引导/问卷偏好 Banner；
- 轮播总数 4 条；运营位为品牌渐变背景（无封面图）；
- 连续使用后查本地库 `usage_events`：`item_type='banner'` 有 expose/click 行（`flutter` 调试或 adb 查看），联网启动后 `synced` 置 1 且后端 `usage_events` 表可按 `item_type='banner'` 聚合曝光/点击。

- [ ] **Step 4: Commit**

```bash
git add docs/future-optimizations.md
git commit -m "docs: 登记首页 Banner 运营化后续优化项（运营位下发系统、A/B 定向投放）"
```

---

## Self-Review 结论

- **Spec 覆盖**：设计文档五节（数据模型 / 运营位 / 槽位精简 / 文案钩子 / 埋点）+ 影响面清单 + 后续优化登记均有对应 Task；「后端零新增基础设施」落地为 Task 1 的白名单扩展与 SQL 过滤（无新表无新接口），并在计划中说明不改后端会阻塞全部埋点同步的根因。
- **类型一致性**：`OperationUserInputs` 字段名在 Task 3（定义）/ Task 4（service 参数）/ Task 5（provider 汇聚）三处一致；`bannerId`/`trackingId` 语义（模板类附加 `:${tpl.id}`、其余回退 id）在 Task 3/4/6 一致；后端 `'expose'`/`'click'` 字符串契约与 Flutter `eventTypeName` 映射一致。
- **已知取舍**：新用户在无运营位时为 3 条（引导 + 收藏位 + 探索），有运营位时 4 条——符合设计文档槽位定义（新用户引导并入 slot 1 前置判断、补位规则仅限老用户）。
