# 首页 Banner 运营化重构设计

> 日期：2026-09-08
> 范围：Flutter 端（`lumira_app_flutter/`）首页 Banner 槽位
> 后端：**零新增基础设施**（复用现有 `usage_events` + `recordBatch` 埋点链路；运营位走 App 端配置）

## 目标

把首页 Banner 从「100% 个性化模板推荐」重构为「**运营位 + 个性化位**」的混合结构，让首页最高曝光的头图同时承担**运营发声与商业转化**，并补齐**运营数据闭环**：

1. **加运营位**：slot 0 固定承载运营目标（邀请/积分/上新），点击指向真实功能页；
2. **精简避免重复**：从 5 条压到 4 条，砍掉与下方「模板推荐区」重复的纯系统推荐槽位；
3. **文案钩子提升**：把「继续拍人像/为你精选」这类功能描述，升级为带社会证明/场景/情绪价值的运营文案；
4. **曝光/点击埋点**：给每条 Banner 加 `banner_id` + 曝光/点击上报，形成单槽位点击率闭环。

## 非目标 / 范围界定

- **不做**后端运营 Banner 下发系统 / 后台运营位管理页（属大工程，先不做；后续单独立项可复用本文 `BannerType` + 运营条目模型）。
- **不做** A/B 实验、时段定向、人群定向的复杂投放引擎。
- **不新增**本地 SQLite 表（无持久化字段需求，运营条目为静态配置，埋点复用现有 usage 通道）。
- 运营位内容**只指向真实存在的功能**（邀请、积分、模板解锁/上新），绝不指向虚构能力。

## 术语与现状

- 现状：`HomeBanner`（[home_banner.dart](lib/features/home/widgets/home_banner.dart)）150 高度无限轮播（5s），数据源 `bannerRecommendationProvider` → `RecommendationService.buildBanners()`（[recommendation_service.dart](lib/features/home/services/recommendation_service.dart)）生成 5 条。
- 现有 5 槽位：①新老用户分层(引导/问卷) ②最近常拍分类 ③收藏场景/常用套件 ④系统推荐模板 ⑤探索新鲜感（老用户补一条）。
- `HomeBannerItem`（[home_mock_data.dart](lib/features/home/data/home_mock_data.dart)）：`id / title / subtitle / imageSeed / tag / route / cover / coverData`。
- 埋点现状：后端 `usage_events`（`item_type / item_id / event_type`），幂等 `recordBatch`；App 端 `UsageEventType`（已有 `useShoot` / `openDetail` / `sceneSelect`），启动经 `usageSyncService.runSync()` 同步。
- 运营目标真实路由：邀请 `RouteNames.invite`(`/invite`) / `/profile/invite`；积分 `RouteNames.pointsWallet`(`/points/wallet`)；解锁 `RouteNames.templatesUnlock`(`/templates/unlock`)。

---

## 一、数据模型：Banner 增加「类型」与「埋点 id」

在 `HomeBannerItem` 上扩展（自 `home_mock_data.dart`）：

```dart
enum BannerType { operation, recommend }

class HomeBannerItem {
  final BannerType type;        // 默认 recommend；运营位为 operation
  final String bannerId;        // 埋点标识，= 现有 id（模板类附加来源信息）
}
```

- `bannerId` 用于曝光/点击上报 `item_id`，`type` 用于渲染标签与后续差异展示（运营位不打个性化标签）。

## 二、运营位：客户端运营条目配置（slot 0）

### 关键决策：运营位机制选型

后端当前**无**运营下发能力；因项目为 **offline-first**（本地 SQLite 种子驱动的形态），采用 **App 端运营条目静态配置**实现运营位。该条目模型与 `BannerType` 对齐，**未来**若接入后台下发，仅需把「配置源」从本地静态 swap 成远端拉取，无需改渲染层与埋点层。

### 运营条目配置（新增 `lib/features/home/data/operation_banners.dart`）

```dart
/// 首页运营 Banner 条目：指向真实功能，条件满足才参与 slot 0
class OperationBanner {
  final String id;
  final String title;
  final String subtitle;
  final String tag;        // 如「邀请有礼」「积分乐园」「上新」
  final String route;      // 真实路由
  final String? imageSeed; // 品牌渐变背景（运营位统一用品牌渐变，便于识别）
  final OperationCondition condition; // 展示条件
  final String copyKey;    // 文案钩子样式（见第三节）
}

enum OperationCondition {
  nonNewUserNotInvited,   // 老用户 & 未绑定过邀请码 → 邀请
  pointsReady,            // 有积分余额 → 引导去积分中心
  hasLockedTemplate,      // 存在未解锁付费模板 → 模板上新/解锁
}
```

运营条目目录（初始 3 条，均指向真实页面；条件由推荐服务注入当前用户状态判定，**满足者最多取 1 条**置于 slot 0）：

| 条目 | title | tag | route | condition |
|---|---|---|---|---|
| 邀请好友 | 「邀请好友 · 双方各+30分」 | 邀请有礼 | `/invite` | `nonNewUserNotInvited` |
| 积分中心 | 「积分当钱花 · 解锁模板」 | 积分乐园 | `/points/wallet` | `pointsReady` |
| 模板上新/解锁 | 「尊享上新 · 一键解锁」 | 上新 | `/templates/unlock` | `hasLockedTemplate` |

- 无任何运营条目满足条件时，**slot 0 让出给个性化推荐**，页面不空白。

## 三、槽位精简：5 → 4

槽位最终顺序与构成：

```
slot 0  运营位（满足条件则占；否则由个性化补位）
slot 1  最近常拍分类（模板）
slot 2  收藏场景 / 常用套件（场景）
slot 3  探索新鲜感（用户少拍类型，渲染进一个模板）
```

- **移除**原「槽位 4 系统推荐模板」——它与首页下方 `_TemplateRecoSection`（模板推荐区）重复最严重。
- 新用户引导/问卷偏好并入 slot 1 的前置判断（新用户仍可拿到引导 Banner），不再单列。
- 老用户「补一条探索」改为：当 slot 0 无运营条目时补；slot 0 有运营条目则不补，维持总量 4 条。

## 四、文案钩子提升

新增文案派生（按 `BannerType` + 上下文），替换「继续拍人像/为你精选」类功能描述：

| 类型/场景 | 文案范式 | 示例 |
|---|---|---|
| 探索新鲜感 | 社会证明（基于热度/「最近都在拍」） | 「大家都在拍人像」 |
| 最近常拍 | 场景延续 + 情绪价值（结合模板 shortDesc 情境化） | 「雷阵雨后的街头光影」 |
| 运营位 | 运营条目自带话术 | 「邀请好友 · 双方各+30分」 |

- 原则：贴合品牌调性，不夸张、不虚构，**不得指向不存在功能**；运营位文案由运营条目显式配置，不走自动生成。

## 五、曝光/点击埋点

- **曝光**：Banner 进入可视区（`_isInViewport` 判定）即上报 `event_type=expose`；**点击**：`onTap` 上报 `event_type=click`。均 `item_type='banner'`、`item_id=banner.bannerId`。
- **通道**：复用现有 `UsageEventType` 上报（`UsageDao` 本地计数 + 启动 `usageSyncService.runSync()` 经 `recordBatch` 幂等落库），不新建埋点基础设施。
- **效果**：后台 `usage_events` 可按 `item_type='banner'` 聚合出「每条素材曝光 / 点击 / 点击率」，支撑运营迭代。
- **防御**：埋点失败静默降级，不影响 Banner 渲染与跳转。

---

## 影响面（文件清单）

| 文件 | 改动 |
|---|---|
| `lib/features/home/data/home_mock_data.dart` | `HomeBannerItem` 加 `type` / `bannerId`；新增 `BannerType` |
| `lib/features/home/data/operation_banners.dart` | **新增**：运营条目配置 + `OperationBanner`/`OperationCondition` |
| `lib/features/home/services/recommendation_service.dart` | 接运营位(slot 0)、5→4 槽位、删系统推荐槽、文案派生、注入埋点 id |
| `lib/features/home/widgets/home_banner.dart` | 曝光埋点（进可视区时）、点击埋点 |
| 埋点依赖 | 复用 `UsageDao`（`UsageEventType` 新增 `bannerExpose`/`bannerClick` 常量） |

## 测试 / 验证

- `flutter analyze` 零错误；
- 现有 banner 相关测试（如有）同步更新到 4 槽位语义；
- 手动验证：新用户/老用户、有无运营条目满足、有无封面四类组合下 Banner 正常渲染、跳转指向真实页面、埋点上报不报错。

## 需登记后续优化项

> 将以下项登记到 `docs/future-optimizations.md`：后端运营 Banner 下发系统 + 后台运营位管理页、运营位 A/B/人群定向投放引擎。