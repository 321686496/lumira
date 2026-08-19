# 摄影美学院收藏功能完善 — 设计

日期：2026-08-19
范围：**纯 Flutter 本地（lumira_app_flutter），不涉及后端**
对象：课程 + 知识卡片
技术栈：Flutter 3.7.12 / Dart 2.19.6（不支持 Dart 3 records）、flutter_riverpod 2.3.6、sqflite v11

## 背景与现状

摄影美学院（academy）现有收藏功能存在三类问题：

1. **课程收藏是"假收藏"**：课程详情页 [academy_detail_page.dart](lib/features/academy/pages/academy_detail_page.dart) 的 AppBar 收藏按钮用本地 `_bookmarked` 变量 + `setState` 翻转，只弹 SnackBar，**不落库**，退出页面即丢失。
2. **两个入口图标不统一**：课程详情页用 `Icons.bookmark`，知识卡片页用 `Icons.favorite`。
3. **缺总览入口**：没有一处能统一查看已收藏的课程 + 知识卡片。

知识卡片收藏已完整落库（`academy_knowledge_favorite` 表），可复用其模式。

## 目标

1. 让课程收藏真正持久化（退出再进仍保留）。
2. 新增「我的收藏」总览页，单页双分区展示已收藏课程 + 已收藏知识卡片。
3. 统一收藏图标为爱心（heart），与知识卡片一致。

## 方案选型

采用**方案 A：独立课程收藏表 + 单页双分区总览页**。

- 新增 `academy_course_favorite` 表，与现有 `academy_knowledge_favorite` 结构完全镜像（一张内容类型一张收藏表）。
- 完全沿用现有 DAO / repository / provider 模式，改动最小、最不易出错。
- 数据库升级轻量，仅新增一张表。

（备选：统一收藏表 / 复用卡片表+前缀 ID，均因数据结构不统一、易出 bug 而不采用。）

## 详细设计

### 1. 数据模型

新增表 `academy_course_favorite`（课程收藏）：

```sql
CREATE TABLE IF NOT EXISTS academy_course_favorite (
  course_id    TEXT PRIMARY KEY,
  favorited_at INTEGER NOT NULL
)
```

现有 `academy_knowledge_favorite`（`card_id` + `favorited_at`）保持不变。

数据库版本号 `_kDbVersion` 由 `24` 提升到 `25`；建表 SQL 同时写入 `_onCreate` 与 `_onUpgrade(oldVersion < 25)`（幂等）。

### 2. DAO 层（academy_dao.dart）

`AcademyTables` 增加课程收藏表常量（表名、course_id、favorited_at、CreateSql），与卡片收藏镜像。

`AcademyDao` 新增 4 个课程收藏方法（与卡片收藏镜像）：

- `Future<bool> isCourseFavorited(String courseId)`
- `Future<Set<String>> getFavoriteCourseIds()`
- `Future<void> addCourseFavorite(String courseId, int timestamp)`
- `Future<void> removeCourseFavorite(String courseId)`

### 3. 仓储层（academy_repository.dart）

`AcademyRepository` 接口 + `LocalAcademyRepository` 实现新增 3 个方法：

- `Future<bool> isCourseFavorited(String courseId)`
- `Future<void> toggleCourseFavorite(String courseId)`（查询当前态后增删）
- `Future<Set<String>> getFavoriteCourseIds()`

时间戳用 `_now().millisecondsSinceEpoch`（沿用现有模式）。

### 4. Provider 层（academy_providers.dart）

- 新增 `favoriteCourseIdsProvider`（`FutureProvider<Set<String>>`），读 `repo.getFavoriteCourseIds()`。
- `AcademyActionNotifier` 新增 `toggleCourseFavorite(String courseId)`，调用 `repo.toggleCourseFavorite` 后 `_refresh()`。
- `_refresh()` 中补 `_ref.invalidate(favoriteCourseIdsProvider)`（课程收藏态变更后各页面可见）。知识卡片收藏的相关失效（`favoriteCardIdsProvider`）已存在，保留。

### 5. 课程详情页改造（academy_detail_page.dart）

- 删除本地状态 `_bookmarked` 与 `_toggleBookmark()`。
- 在 `build` 中 `ref.watch(favoriteCourseIdsProvider)`，取当前课程 `courseId` 是否已收藏。
- AppBar actions 按钮：
  - 图标统一为爱心：未收藏 `Icons.favorite_border`，已收藏 `Icons.favorite`（高亮红色）。
  - 点击调用 `ref.read(academyActionsProvider.notifier).toggleCourseFavorite(courseId)`，并弹轻提示（已收藏/已取消收藏）。
- 需要 `courseId` 存在才可用收藏按钮（`widget.academyId` 为空时禁用，与现有逻辑一致）。

### 6. 学院首页入口（academy_page.dart）

- AppBar `LumiraNav` 增加 `actions`：爱心收藏图标（`Icons.favorite_border`）→ `GoRouter` 打开 `academyFavorites` 路由。

### 7. 新总览页（新文件 academy_favorites_page.dart）

页面标题「我的收藏」，`ConsumerWidget`，读取两个 provider：

- `favoriteCourseIdsProvider`
- `favoriteCardIdsProvider`

从 `AcademyContent` 拿到课程与知识卡片的完整数据，过滤出已收藏项。单页双分区：

- **上区：已收藏课程** — 复用课程条目的缩略展示（封面 + 标题 + meta），点击进课程详情；带取消收藏爱心按钮。
- **下区：已收藏知识卡** — 复用知识卡片条目（封面 + 标题 + 副标题 + 主题标签），点击进知识卡详情；带取消收藏爱心按钮。

交互：

- 取消收藏后对应条目立即消失（依赖 provider 失效刷新）。
- 空态：无任何收藏时显示引导文案 + 返回摄影美学院按钮。
- 加载中 / 错误态沿用现有 `LumiraProgress` 和错误重试模式。

视觉风格沿用现有 academy 页面：`LumiraNav` + `GlassBackground(profile)` + `NeuCard`/`FadeUp` + theme tokens。

### 8. 路由

- `RouteNames` 新增 `static const String academyFavorites = '/academy/favorites';`
- [router.dart](lib/app/router.dart) 的 academy 区块新增 `GoRoute(path: /academy/favorites, builder: const AcademyFavoritesPage())`。

## 错误处理与一致性

- 收藏读取走 `FutureProvider`，加载中/错误态由页面按需处理。
- 所有收藏/取消都经 `AcademyActionNotifier` 统一入口，操作后 invalidate 相关 provider，保证课程详情 / 学院首页 / 总览页三处状态同步。
- 全部为本地 sqflite，无网络，无并发冲突顾虑。

## 测试

- 运行 `flutter analyze`（或项目 CI 的 analyze 命令）确认无静态错误。
- 手工验证路径：
  1. 课程详情收藏 → 图标变红心 → 退出再进仍为已收藏。
  2. 学院首页爱心入口 → 「我的收藏」页 → 课程区与知识卡区都显示已收藏项。
  3. 总览页取消收藏课程 → 该条目消失 → 详情页图标已复原。
  4. 知识卡片从总览页取消 → 知识卡区条目消失，首页卡片同步复原。