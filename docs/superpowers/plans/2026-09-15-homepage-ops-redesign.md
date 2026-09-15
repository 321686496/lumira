# 首页运营视角重构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重构首页信息层级：搜索胶囊入口、成长条上移精简、HeroCard 压缩、场景沉浸卡、继续创作 2 列网格、Banner 运营位轮播间隔自适应。

**Architecture:** 全部改动在 `lumira_app_flutter/lib/features/home/` 内完成，不触碰后端与埋点通道。页面结构调整集中在 `home_page.dart` 的 CustomScrollView sliver 顺序；各 section 组件（HeroCard/GrowthStrip/SceneRecoCard/RecentShotCard/HomeBanner）独立修改，互不耦合；新增 `search_capsule.dart` 作为搜索入口组件。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（不用 Dart 3 records 语法）、flutter_riverpod 2.3.6、GoRouter 6.5.7。

## Global Constraints

- Dart 版本锁定 2.19.6：**禁止** records / patterns / `switch` 表达式（Dart 3 语法）。
- 4 套 UI 风格（neumorphic/flat/glass/female）× 8+1 主题色：所有颜色/阴影/边框/圆角必须从 `appThemeProvider`（`AppThemeData`）派生，**禁止**新增硬编码 `Colors.xxx` / `Color(0xFF...)` / `BoxShadow` / `BorderRadius`（叠在照片上的黑/白半透明遮罩是唯一合法例外）。
- 禁止跨风格混搭（如 neumorphic 里出现 BackdropFilter 玻璃）。
- 组件叠在照片上时：neumorphic=实心 surface+细边（无阴影无模糊）、flat=半透明+细边、glass=玻璃、female=渐变/柔和阴影。
- 图片缩略图统一走 `TemplateCoverImage` / `LumiraImage`（自动降采样），避免全尺寸解码。
- 验证命令：`flutter analyze`（锁定 3.7.12）在 `lumira_app_flutter/` 下执行；测试 `flutter test test/features/home/`。
- 每次任务完成需 commit（纯 Flutter 端改动，按 AGENTS.md 规则：不涉及后端/后台，无需 push 双远程）。

---

### Task 1: 新增搜索胶囊组件 SearchCapsule

**Files:**
- Create: `lumira_app_flutter/lib/features/home/widgets/search_capsule.dart`
- Test: `lumira_app_flutter/test/features/home/search_capsule_test.dart`

**Interfaces:**
- Consumes: `RouteNames.search`（`/search`）、`SearchScope.all`（`lib/shared/searchengine/search_scope.dart`）
- Produces: `SearchCapsule` widget（无参，点击自导航到 `/search`），供 Task 6 在 `home_page.dart` 挂载

- [ ] **Step 1: 写失败测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/features/home/widgets/search_capsule.dart';

void main() {
  testWidgets('SearchCapsule 显示占位文案，点击跳转 /search', (tester) async {
    final router = GoRouter(
      initialLocation: RouteNames.home,
      routes: [
        GoRoute(
          path: RouteNames.home,
          name: 'home',
          builder: (context, state) => const Scaffold(body: SearchCapsule()),
        ),
        GoRoute(
          path: RouteNames.search,
          name: 'search',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('SEARCH_PAGE'))),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    expect(find.text('搜索模板 / 场景 / 拍摄教程'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);

    await tester.tap(find.text('搜索模板 / 场景 / 拍摄教程'));
    await tester.pumpAndSettle();

    expect(find.text('SEARCH_PAGE'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/home/search_capsule_test.dart`
Expected: FAIL（`SearchCapsule` 未定义）

- [ ] **Step 3: 实现 SearchCapsule**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/searchengine/search_scope.dart';

/// 首页搜索胶囊：导航栏下方圆角胶囊，点击进入全局搜索页（all scope）。
class SearchCapsule extends ConsumerWidget {
  const SearchCapsule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    return GestureDetector(
      onTap: () => context.push(
        RouteNames.withScope(RouteNames.search, SearchScope.all.name),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40,
        margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tokens.divider, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: tokens.textTertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '搜索模板 / 场景 / 拍摄教程',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.textTertiary,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/home/search_capsule_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lumira_app_flutter/lib/features/home/widgets/search_capsule.dart lumira_app_flutter/test/features/home/search_capsule_test.dart
git commit -m "feat(flutter): 首页新增搜索胶囊组件"
```

---

### Task 2: HeroCard 压缩（内容不变，排版 + 样式）

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/widgets/hero_card.dart`（整文件 _buildContent 方法重排）
- Test: `lumira_app_flutter/test/features/home/home_page_test.dart`（已有断言确认内容仍在）

**Interfaces:**
- Consumes: 现有 `HeroInspiration`、`appThemeProvider`
- Produces: 压缩后的 HeroCard（高度 ~210，字段：title/dateText/description/recommendedTemplateId/weatherText 全部保留）

- [ ] **Step 1: 先跑既有测试确认基线**

Run: `flutter test test/features/home/home_page_test.dart`
Expected: PASS（改造前基线）

- [ ] **Step 2: 重写 _buildContent（压缩排版）**

在 `hero_card.dart` 中替换 `_buildContent` 的 Stack 部分：

```dart
  Widget _buildContent(
    ThemeTokens tokens,
    UIStyle style,
    HeroInspiration inspiration, {
    bool dim = false,
  }) {
    final isNeumorphic = style == UIStyle.neumorphic;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 内容层（压缩：垂直 padding 28 → 16）
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          child: Opacity(
            opacity: dim ? 0.5 : 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Text(
                  inspiration.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                    letterSpacing: -0.01 * 20,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                // 日期 + 天气 合并一行
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        inspiration.dateText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (inspiration.weatherText.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: tokens.textTertiary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            inspiration.weatherText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: tokens.textTertiary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                // 描述（1 行）
                Text(
                  inspiration.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: tokens.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                // 推荐模板卡（缩略图 72x96 → 56x72）
                if (inspiration.recommendedTemplateId.isNotEmpty) ...[
                  Builder(
                    builder: (context) => _recommendCard(
                      tokens: tokens,
                      style: style,
                      inspiration: inspiration,
                      onTap: () => GoRouter.of(context).push(RouteNames.build(
                        RouteNames.capture,
                        {RouteNames.paramTemplateId: inspiration.recommendedTemplateId},
                      )),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // CTA 按钮（padding 垂直 12 → 10）
                Builder(builder: (context) {
                  final hasRec = inspiration.recommendedTemplateId.isNotEmpty;
                  return GestureDetector(
                    onTap: () {
                      if (hasRec) {
                        GoRouter.of(context).push(RouteNames.build(
                          RouteNames.capture,
                          {RouteNames.paramTemplateId: inspiration.recommendedTemplateId},
                        ));
                      } else {
                        widget.onCapture();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isNeumorphic ? tokens.brand : null,
                        gradient: isNeumorphic
                            ? null
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [tokens.brand, tokens.brandDeep],
                              ),
                        boxShadow: isNeumorphic ? tokens.shadowConvex : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.camera_alt_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hasRec ? '套用模板拍摄' : '开始拍摄',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
```

同时修改 `_recommendCard`：
- 缩略图 `SizedBox(width: 72, height: 96)` → `SizedBox(width: 56, height: 72)`
- 移除外层 Container 的 `boxShadow: isNeu ? tokens.shadowConvex : null`（叠在卡片内的子卡，保持扁平），保留 `color: tokens.surface`、`borderRadius: 12`、flat 细边逻辑

- [ ] **Step 3: 删除 hero-deco 装饰圆**

在 `_buildContent` 中删除 `Positioned(top: -30, right: -30, child: Container(width: 140, height: 140, ...))` 整段。

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/home/home_page_test.dart`
Expected: PASS（`今日灵感`、`捕捉每一束光，让日常成为习惯`、`开始拍摄` 断言仍成立）

- [ ] **Step 5: Commit**

```bash
git add lumira_app_flutter/lib/features/home/widgets/hero_card.dart
git commit -m "feat(flutter): 压缩首页 HeroCard 排版，日期天气合并、移除装饰圆"
```

---

### Task 3: GrowthStrip 精简为 3 项并突出连续天数

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/widgets/growth_strip.dart`
- Test: `lumira_app_flutter/test/features/home/home_page_test.dart`

**Interfaces:**
- Consumes: `homeStreakProvider`、`homeStatsProvider`
- Produces: GrowthStrip 3 项：连续天数（放大突出）/ 作品 / 经验；移除收藏项

- [ ] **Step 1: 重写 GrowthStrip build**

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final streak =
        ref.watch(homeStreakProvider).valueOrNull ?? HomeStreakStatus.empty;
    final stats = ref.watch(homeStatsProvider).valueOrNull ?? HomeStats.empty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: NeuCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // 连续天数：主视觉，数字放大 + 强调色
            _GrowthItem(
              icon: Icons.local_fire_department_outlined,
              value: '${streak.streakDays}',
              label: '连续天',
              color: tokens.danger,
              tokens: tokens,
              valueFontSize: 20,
            ),
            _GrowthDivider(tokens: tokens),
            _GrowthItem(
              icon: Icons.photo_library_outlined,
              value: '${stats.totalPhotos}',
              label: '作品',
              color: tokens.brand,
              tokens: tokens,
            ),
            _GrowthDivider(tokens: tokens),
            _GrowthItem(
              icon: Icons.show_chart,
              value: '${stats.totalXp}',
              label: '经验',
              color: tokens.success,
              tokens: tokens,
            ),
          ],
        ),
      ),
    );
  }
```

`_GrowthItem` 增加 `valueFontSize` 参数（默认 16，连续天传 20）：将 `Text` 的 `fontSize: 16` 改为 `fontSize: valueFontSize`。

- [ ] **Step 2: 运行测试确认通过（移除收藏断言）**

Run: `flutter test test/features/home/home_page_test.dart`
Expected: PASS。若 `expect(find.text('收藏'), findsOneWidget)` 失败，删除该行（收藏项已移除）。

- [ ] **Step 3: Commit**

```bash
git add lumira_app_flutter/lib/features/home/widgets/growth_strip.dart lumira_app_flutter/test/features/home/home_page_test.dart
git commit -m "feat(flutter): 成长条精简为连续天/作品/经验，突出连续天数"
```

---

### Task 4: HomeBanner 轮播间隔按类型自适应

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/widgets/home_banner.dart`
- Test: `lumira_app_flutter/test/features/home/home_banner_focus_render_test.dart`

**Interfaces:**
- Consumes: `HomeBannerItem.type`（`BannerType.operation` / `recommend`）
- Produces: 运营位停留 10s、个性化位 5s 的轮播

- [ ] **Step 1: 写失败测试（轮播间隔按类型）**

在 `home_banner_focus_render_test.dart` 追加：

```dart
  testWidgets('operation banner 自动轮播间隔为 10s，recommend 为 5s',
      (tester) async {
    final banners = <HomeBannerItem>[
      HomeBannerItem(
        id: 'op',
        title: 'Op',
        subtitle: 's',
        imageSeed: 'op',
        tag: 'op',
        route: '/invite',
        type: BannerType.operation,
        bannerId: 'op',
      ),
      HomeBannerItem(
        id: 'rec',
        title: 'Rec',
        subtitle: 's',
        imageSeed: 'rec',
        tag: 'rec',
        route: '/templates',
        type: BannerType.recommend,
        bannerId: 'rec',
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
          uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
          bannerRecommendationProvider.overrideWith((ref) async => banners),
          usageEventRecorderProvider
              .overrideWith((ref) async => throw Exception('unused')),
        ],
        child: const MaterialApp(home: Scaffold(body: HomeBanner())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // 初始在 op（operation）：10s 内不应切页
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Op'), findsOneWidget);

    // 到 10s 边界应切到 Rec
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Rec'), findsOneWidget);
  });
```

> 注：PageView 自动轮播依赖 `animateToPage`，测试中需 `pumpAndSettle` 或手动 pump 动画时长；若计时断言不稳，改为暴露静态方法 `Duration intervalFor(BannerType type)` 并直接单测该方法（见 Step 3 实现说明）。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/home/home_banner_focus_render_test.dart`
Expected: FAIL（当前固定 5s，5s 时就已切页）

- [ ] **Step 3: 实现类型自适应间隔**

在 `home_banner.dart` 顶部（`_HomeBannerState` 外）新增：

```dart
/// 自动轮播间隔：运营位 10s（曝光提效），个性化位 5s
Duration bannerIntervalFor(BannerType type) {
  return type == BannerType.operation
      ? const Duration(seconds: 10)
      : const Duration(seconds: 5);
}
```

修改 `_restartTimer`（将固定 5s 改为按当前页类型选择；`_current` 在 `onPageChanged` 已更新）：

```dart
  void _restartTimer(int count) {
    _timer?.cancel();
    _timer = null;
    if (count <= 1) return;
    if (!TickerMode.of(context)) return;
    final banners = _banners;
    final type = (banners != null && banners.isNotEmpty)
        ? banners[_current % banners.length].type
        : BannerType.recommend;
    final interval = bannerIntervalFor(type);
    _timer = Timer.periodic(interval, (_) {
      final c = _controller;
      if (c == null || !c.hasClients || !mounted) return;
      if (!_isInViewport()) return;
      c.animateToPage(
        _current + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }
```

新增 `List<HomeBannerItem>? _banners` 字段；在 `_buildCarousel(banners, tokens)` 开头赋值 `_banners = banners;`。

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/home/home_banner_focus_render_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lumira_app_flutter/lib/features/home/widgets/home_banner.dart lumira_app_flutter/test/features/home/home_banner_focus_render_test.dart
git commit -m "feat(flutter): Banner 运营位轮播间隔自适应 10s/个性化 5s"
```

---

### Task 5: 场景推荐卡片改为沉浸式封面卡

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/widgets/scene_reco_card.dart`
- Modify: `lumira_app_flutter/lib/features/home/pages/home_page.dart`（`_SceneRecoGridSliver` 卡片尺寸 130 → 150）
- Test: `lumira_app_flutter/test/features/home/scene_reco_card_asset_test.dart` + `home_page_test.dart`

**Interfaces:**
- Consumes: `SceneReco`（现有字段）、`appThemeProvider`
- Produces: 沉浸式卡片：封面铺满整卡、场景名/氛围叠在图上（下方渐变遮罩）、左上角标签保留；`showPhotoCount` 语义保留

- [ ] **Step 1: 写失败测试（沉浸式布局）**

在 `scene_reco_card_asset_test.dart` 追加：

```dart
  testWidgets('沉浸式形态：文字叠在封面图上', (tester) async {
    await tester.pumpWidget(harness(const SceneReco(
      id: 'scene-imm',
      name: '沉浸场景',
      vibe: '氛围文案',
      imageSeed: 's',
      badgeText: '推荐',
      badgeBrand: false,
      photoCount: 0,
      coverUrl: 'data:image/png;base64,$tinyPng',
    )));
    await tester.pump();
    // 场景名与氛围文字仍渲染（叠在图上）
    expect(find.text('沉浸场景'), findsOneWidget);
    expect(find.text('氛围文案'), findsOneWidget);
    // 存在黑色渐变遮罩层（叠照片遮罩合法例外）
    final gradientFound = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).any(
      (w) => w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).gradient != null,
    );
    expect(gradientFound, isTrue);
  });
```

> 注：`tinyPng` 已在文件顶部定义；若沉浸式形态在 320x520 容器下文字溢出错位，需调整测试容器或卡片内边距。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/home/scene_reco_card_asset_test.dart`
Expected: FAIL（当前是 3:4 图 + 下方文字区，无叠图渐变）

- [ ] **Step 3: 重写 SceneRecoCard 为沉浸式**

替换 `SceneRecoCard` 的 build 主体（保留 `_buildCoverImage` 原逻辑）：

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          // 叠照片遮罩（半透明黑）为跨风格合法例外
          color: Colors.black.withOpacity(0.0),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCoverImage(tokens),
            // 底部渐变遮罩：压暗保证文字可读
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.55),
                  ],
                ),
              ),
            ),
            // 左上角标签
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scene.badgeBrand
                      ? tokens.brand
                      : Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(1000),
                ),
                child: Text(
                  scene.badgeText,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    letterSpacing: 0.04 * 10,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            // 左下角：场景名 + 氛围
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    scene.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    scene.vibe,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.85),
                      height: 1.3,
                    ),
                  ),
                  if (showPhotoCount) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.photo_library_outlined,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${scene.photoCount}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
```

> 注：`footer` 参数保留但沉浸式形态下不再渲染 footer（home 页不传 footer，无影响）。删除原 Column 卡片体。`isGlass`/`isNeumorphic` 本地变量若不再使用需删除，避免 analyze 告警。

- [ ] **Step 4: 更新 home_page 场景卡片尺寸**

在 `home_page.dart` 的 `_SceneRecoGridSliver` 中：
- `SizedBox(height: 248)` → `SizedBox(height: 200)`
- `SizedBox(width: 130, child: SceneRecoCard(...))` → `SizedBox(width: 150, child: SceneRecoCard(...))`
- 注释 `align with RecommendedTemplate card` 更新为沉浸式卡片尺寸说明

- [ ] **Step 5: 运行测试确认通过**

Run: `flutter test test/features/home/scene_reco_card_asset_test.dart test/features/home/home_page_test.dart`
Expected: PASS（home_page_test 中 `咖啡馆`/`街头` 等场景名断言仍成立）

- [ ] **Step 6: Commit**

```bash
git add lumira_app_flutter/lib/features/home/widgets/scene_reco_card.dart lumira_app_flutter/lib/features/home/pages/home_page.dart lumira_app_flutter/test/features/home/scene_reco_card_asset_test.dart
git commit -m "feat(flutter): 场景推荐卡片改为沉浸式封面卡"
```

---

### Task 6: 继续创作改为 2 列照片网格

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/pages/home_page.dart`（`_RecentShotsGridSliver` 从横向 ListView 改为 SliverGrid）
- Modify: `lumira_app_flutter/lib/features/home/widgets/recent_shot_card.dart`（尺寸适配：移除 130 宽度假设，文字区保持）
- Test: `lumira_app_flutter/test/features/home/home_page_test.dart`

**Interfaces:**
- Consumes: `homeRecentShotsProvider`、`RecentShot`、`_goPhotoDetail`/`_goRetake`
- Produces: 2 列 GridView（懒加载），空态与 loading 骨架保留

- [ ] **Step 1: 写失败测试（继续创作为 2 列网格）**

在 `home_page_test.dart` 追加：

```dart
  testWidgets('HomePage 继续创作为 2 列网格', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 5500);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(_wrapWithRouter());
    await tester.pumpAndSettle();

    // 继续创作区域使用 GridView（scrollDirection 非 horizontal）
    final grids = find.byType(GridView);
    expect(grids, findsWidgets);

    // 场景推荐仍为横向 ListView
    final horizontalRails = find.byWidgetPredicate(
      (widget) => widget is ListView && widget.scrollDirection == Axis.horizontal,
    );
    expect(horizontalRails, findsWidgets);
    // 最近作品仍在
    expect(find.text('自然光人像'), findsOneWidget);
  });
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/home/home_page_test.dart --plain-name "HomePage 继续创作为 2 列网格"`
Expected: FAIL（当前 `_RecentShotsGridSliver` 是横向 ListView，无 GridView）

- [ ] **Step 3: 改造 _RecentShotsGridSliver 为 2 列网格**

替换 data 分支（保留 loading/error/empty 逻辑，把横向 ListView 换成 SliverGrid）：

```dart
      data: (recents) {
        if (recents.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildEmpty(tokens),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72, // 3:4 竖图 + 下方文字区
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final recent = recents[i];
                return RepaintBoundary(
                  child: RecentShotCard(
                    recent: recent,
                    onTap: () => onPhotoTap(recent),
                    onRetake: () => onRetake(recent),
                  ),
                );
              },
              childCount: recents.length,
            ),
          ),
        );
      },
```

同时更新 `_buildSkeleton()`：从横向 ListView 改为同样的 SliverGrid（`childAspectRatio: 0.72`，childCount = mocks.length）。

- [ ] **Step 4: 调整 RecentShotCard 网格适配**

`recent_shot_card.dart` 不改结构（3:4 图 + 文字区天然适配 2 列网格）。仅确认 GridView 单元格内无 130 宽度硬编码（当前无）。

- [ ] **Step 5: 运行全部 home 测试确认通过**

Run: `flutter test test/features/home/`
Expected: PASS（注意 `home_page_test.dart` 中 `horizontalRails findsNWidgets(2)` 断言需改为 `findsWidgets`，因继续创作已非横向）

- [ ] **Step 6: Commit**

```bash
git add lumira_app_flutter/lib/features/home/pages/home_page.dart lumira_app_flutter/lib/features/home/widgets/recent_shot_card.dart lumira_app_flutter/test/features/home/home_page_test.dart
git commit -m "feat(flutter): 继续创作改为 2 列照片网格"
```

---

### Task 7: 首页页面结构调整（搜索胶囊 + 成长条上移 + 模块换位）

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/pages/home_page.dart`
- Test: `lumira_app_flutter/test/features/home/home_page_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `SearchCapsule`、Task 3 的 `GrowthStrip`、现有 slivers
- Produces: 最终顺序 = SearchCapsule → HomeBanner → QuickActions → GrowthStrip → HeroCard → RecentTemplateStrip → 场景推荐 → 继续创作

- [ ] **Step 1: 写失败测试（新顺序）**

在 `home_page_test.dart` 追加：

```dart
  testWidgets('HomePage 结构：搜索胶囊在 Banner 前、成长条在入口后', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 5500);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(_wrapWithRouter());
    await tester.pumpAndSettle();

    // 搜索胶囊存在
    expect(find.text('搜索模板 / 场景 / 拍摄教程'), findsOneWidget);

    // 成长条 3 项
    expect(find.text('连续天'), findsOneWidget);
    expect(find.text('作品'), findsOneWidget);
    expect(find.text('经验'), findsOneWidget);
    expect(find.text('收藏'), findsNothing);

    // 顺序：搜索胶囊 y < Banner y < QuickActions y < GrowthStrip y
    final searchY = tester.getTopLeft(find.text('搜索模板 / 场景 / 拍摄教程')).dy;
    final quickY = tester.getTopLeft(find.text('拍摄').first).dy;
    final growthY = tester.getTopLeft(find.text('连续天')).dy;
    expect(searchY, lessThan(quickY));
    expect(quickY, lessThan(growthY));
  });
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/home/home_page_test.dart --plain-name "HomePage 结构"`
Expected: FAIL（搜索胶囊不存在 / 成长条仍在页底）

- [ ] **Step 3: 调整 home_page.dart sliver 顺序**

将 `build` 中 slivers 调整为：

```
SliverPadding(0,12,0,0) SliverList:
  - SearchCapsule()                    // 新增，最前
  - SizedBox(height: 8)
  - HomeBanner()                       // 原 Section 0
  - SizedBox(height: 20)
  - QuickActions()                     // 原 Section 1
  - SizedBox(height: 20)
  - GrowthStrip()                      // 从页底上移至此（原 Section 7 内容）
  - SizedBox(height: 20)
  - HeroCard(onCapture: _goCapture)    // 原 Section 2
  - SizedBox(height: 20)
  - RecentTemplateStrip()              // 原 Section 3
  - 场景推荐 _SectionTitle（原样保留）
_SceneRecoGridSliver (原样)
继续创作 _SectionTitle（原样保留）
_RecentShotsGridSliver (原样)
```

删除原页底 GrowthStrip 的 `SliverPadding(0,20,0,100)` 块。原 `SizedBox(height: 20)` 保留在 HeroCard 与模板流之间。

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/home/`
Expected: PASS

- [ ] **Step 5: 验证全量 analyze**

Run: `flutter analyze`
Expected: No issues found（或仅既存告警）

- [ ] **Step 6: Commit**

```bash
git add lumira_app_flutter/lib/features/home/pages/home_page.dart lumira_app_flutter/test/features/home/home_page_test.dart
git commit -m "feat(flutter): 首页结构调整：搜索胶囊置顶、成长条上移、转化模块前置"
```

---

### Task 8: 全量回归验证

**Files:**
- Test: 全部 `lumira_app_flutter/test/`（重点 `test/features/home/`）

**Interfaces:**
- 无新接口，纯验证

- [ ] **Step 1: 全量 analyze**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 2: 全量测试**

Run: `flutter test`
Expected: 全部 PASS（若历史测试因结构变化失败，仅更新断言不改实现；若属真实回归，回退到对应 Task 修复）

- [ ] **Step 3: 手动回归清单（真机/模拟器）**

- 4 风格 × 8 主题：首页渲染无溢出、无硬编码色
- 搜索胶囊 → `/search` 可跳转
- Banner：运营位停留 10s、个性化 5s，手动滑动后计时重置
- HeroCard：压缩后内容完整、4 风格不变形
- 场景沉浸卡：文字可读、点击进场景详情
- 继续创作 2 列网格：点击进详情、再拍正常
- 成长条：连续天数突出、无收藏项

- [ ] **Step 4: 追加后续优化登记**

在 `docs/future-optimizations.md` 追加：搜索胶囊占位文案静态 → 运营热词配置（参照文件内既有格式）。

- [ ] **Step 5: Commit**

```bash
git add docs/future-optimizations.md
git commit -m "docs: 登记搜索胶囊运营热词配置优化项"
```
