# 探店足迹模块 UI 优化（精致手帐风）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Flutter「探店足迹（checkin）」的详情/列表/编辑三个页面重构为统一「精致手帐风」，以详情页为重点；配色全部随主题与 UI 风格自动切换。

**Architecture:** 仅改动 Flutter checkin 特性三个页面文件 + 复用既有共享组件（`NeuCard`/`LumiraNav`/`LumiraToast`/`FadeUp`/`LumiraButton`/`LumiraProgress`）。详情页改为「沉浸式大封面 + 缩略图带 + 浮层信息卡」，列表页加渐变背景与精细化统计卡，编辑页做视觉一致性并修复正文乱码。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6，flutter_riverpod 2.3.6，go_router 6.5.7。**不可用 Dart 3 records 语法。**

## Global Constraints

- 颜色、阴影、字体一律来自 `ThemeTokens`（`appThemeProvider.tokens`）+ `uiStyleProvider`，**禁止硬编码主题色**。
- 唯一例外：覆盖层黑色渐变遮罩用 `Colors.black.withOpacity(...)`（全主题通用）。
- 复用既有共享组件，不新建无关抽象；DRY、YAGNI、TDD、频繁提交。
- 现有 `checkin_detail_page_test.dart` / `checkin_list_page_test.dart` 必须保持通过，且下列 finders 必须仍然成立：
  - 详情页：`find.text('Manner Coffee'|'武康路'|'咖啡'|'燕麦拿铁很香')` 各 findsOneWidget；`find.byIcon(Icons.star)` findsNWidgets(5)；`find.byIcon(Icons.delete_outline)`；`find.text('足迹不存在或已删除')`。
  - 列表页：统计文案 `足迹总数/好评店铺/平均评分/今年新增`、`find.text('1')` findsWidgets、`按时间`、`按评分`、`全部`、`find.text('咖啡')` findsNWidgets(4)、`值得一去`、空态 `还没有探店足迹` / `记录第一笔`。
- 运行目录：`d:\app\projects\photo_post\lumira_app_flutter`（命令 `cwd` 指向该目录）。
- 项目用户的 UI 偏好：标题不居中、莫兰迪柔和配色、渐变背景、大圆角大留白、iPhone 美学。

---

### Task 1: 重构详情页为沉浸式大封面（checkin_detail_page.dart）

**Files:**
- Modify: `lib/features/checkin/pages/checkin_detail_page.dart`（整体重写）
- Test: `test/features/checkin/checkin_detail_page_test.dart`（不改内容，仅回归）

**Interfaces:**
- Consumes: `CheckinDetail{record, photos}`、`CheckinRecord{name,place,category,rating,note,visitedAt}`、`checkinCategoryOf(String)`、`CheckinRatingStars`、`CheckinCategoryTag`、`CheckinPhotoImage`、`formatCheckinDate`、`tokens`(ThemeTokens)、`RouteNames.build(RouteNames.checkinEdit,{paramCheckinId:id})`。
- Produces: `CheckinDetailPage(checkinId: String?)`（保持构造签名不变；由 `ConsumerWidget` 改为 `ConsumerStatefulWidget`，供缩略图切换封面封顶图状态）。

- [ ] **Step 1: 整体重写详情页**

用以下内容替换 `checkin_detail_page.dart` 全文：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../data/checkin_categories.dart';
import '../data/checkin_models.dart';
import '../data/checkin_providers.dart';
import '../widgets/checkin_common.dart';

/// 探店足迹详情页（精致手帐风）
///
/// - 沉浸式大封面：首张照片铺满顶部约 57% 屏高，店名/评分/分类/日期叠放于底部渐变遮罩上
/// - 缩略图带：首图之外的照片横向小图，点击切换封面
/// - 浮层信息卡：地点/心得，圆角 20，与封面重叠产生「浮上来」手帐感
class CheckinDetailPage extends ConsumerStatefulWidget {
  const CheckinDetailPage({super.key, this.checkinId});

  final String? checkinId;

  @override
  ConsumerState<CheckinDetailPage> createState() => _CheckinDetailPageState();
}

class _CheckinDetailPageState extends ConsumerState<CheckinDetailPage> {
  int _coverIndex = 0;

  void _goEdit(String id) {
    GoRouter.of(context).push(RouteNames.build(
      RouteNames.checkinEdit,
      {RouteNames.paramCheckinId: id},
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final id = checkinId;
    final detailAsync = id == null
        ? const AsyncValue<CheckinDetail?>.data(null)
        : ref.watch(checkinDetailProvider(id));
    final hasDetail = detailAsync.valueOrNull != null;

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: Stack(
        children: [
          detailAsync.when(
            loading: () => Center(child: LumiraProgress.circular()),
            error: (e, _) => Center(
              child: Text('加载失败：$e', style: TextStyle(color: tokens.textSecondary)),
            ),
            data: (detail) {
              if (detail == null) return _MissingState(tokens: tokens);
              return _DetailContent(
                tokens: tokens,
                detail: detail,
                coverIndex: _coverIndex,
                hasDetail: true,
                onThumbTap: (i) => setState(() => _coverIndex = i),
              );
            },
          ),
          // 顶部叠层：返回 + 编辑/删除（白色毛玻璃胶囊）
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(
                children: [
                  _FrostedIconButton(
                    icon: Icons.chevron_left,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  if (hasDetail && id != null) ...[
                    _FrostedIconButton(
                      icon: Icons.edit_outlined,
                      onTap: () => _goEdit(id),
                    ),
                    const SizedBox(width: 10),
                    _FrostedIconButton(
                      icon: Icons.delete_outline,
                      onTap: () => _onDelete(context),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDelete(BuildContext context) async {
    final id = checkinId;
    if (id == null) return;
    final tokens = ref.read(themeTokensProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '删除足迹',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: tokens.textPrimary),
        ),
        content: Text(
          '确定删除这条探店足迹吗？此操作不可撤销。',
          style: TextStyle(fontSize: 14, color: tokens.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('取消', style: TextStyle(color: tokens.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('删除', style: TextStyle(color: tokens.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final dao = await ref.read(checkinDaoProvider.future);
      await dao.delete(id);
      ref.invalidate(checkinsProvider);
      ref.invalidate(checkinTotalCountProvider);
      ref.invalidate(checkinDetailProvider(id));
      if (!context.mounted) return;
      LumiraToast.show(context, '已删除', duration: const Duration(milliseconds: 1000));
      context.pop();
    } catch (e) {
      if (!context.mounted) return;
      LumiraToast.show(context, '删除失败：$e', duration: const Duration(seconds: 2));
    }
  }
}

/// 详情正文：封面 + 缩略图 + 浮层信息卡
class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.tokens,
    required this.detail,
    required this.coverIndex,
    required this.hasDetail,
    required this.onThumbTap,
  });

  final ThemeTokens tokens;
  final CheckinDetail detail;
  final int coverIndex;
  final bool hasDetail;
  final ValueChanged<int> onThumbTap;

  @override
  Widget build(BuildContext context) {
    final record = detail.record;
    final category = checkinCategoryOf(record.category);
    final photoUrls = detail.photos
        .map((p) => p.dataUrl ?? p.filePath)
        .where((u) => u != null && u.isNotEmpty)
        .toList();
    final screenH = MediaQuery.of(context).size.height;
    final coverH = screenH * 0.57;
    final active = photoUrls.isEmpty ? 0 : (coverIndex >= photoUrls.length ? 0 : coverIndex);
    final infoOverlap = 28.0;
    final hasInfo = record.place.isNotEmpty || record.note.isNotEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 基础流：先占满封面高度 + 尾部留白区，供浮层卡被 Stack 定位
          SizedBox(
            width: double.infinity,
            height: coverH + 40, // 预留缩略图带空间
            child: _CoverHeader(
              tokens: tokens,
              category: category,
              photoUrls: photoUrls,
              active: active,
              record: record,
              onThumbTap: onThumbTap,
            ),
          ),
          // 浮层信息卡：与封面重叠 infoOverlap
          if (hasInfo)
            Positioned(
              left: 24,
              right: 24,
              top: coverH + 40 - infoOverlap,
              child: _InfoCard(tokens: tokens, record: record),
            ),
          if (!hasInfo)
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

/// 沉浸式封面部（含缩略图带）
class _CoverHeader extends StatelessWidget {
  const _CoverHeader({
    required this.tokens,
    required this.category,
    required this.photoUrls,
    required this.active,
    required this.record,
    required this.onThumbTap,
  });

  final ThemeTokens tokens;
  final CheckinCategory category;
  final List<String> photoUrls;
  final int active;
  final CheckinRecord record;
  final ValueChanged<int> onThumbTap;

  @override
  Widget build(BuildContext context) {
    final showThumbs = photoUrls.length > 1;
    return SizedBox(
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 大封面（首张 或 缩略图选中项）
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            child: photoUrls.isEmpty
                ? Container(
                    color: category.iconBgColor,
                    alignment: Alignment.center,
                    child: Icon(category.icon, size: 96, color: category.iconColor),
                  )
                : CheckinPhotoImage(url: photoUrls[active], tokens: tokens, fit: BoxFit.cover),
          ),
          // 上下渐变遮罩
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.45),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.55),
                  ],
                  stops: const [0.0, 0.35, 0.6, 1.0],
                ),
              ),
            ),
          ),
          // 底部信息区 + 缩略图带
          Positioned(left: 0, right: 0, bottom: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showThumbs) ...[
                  _ThumbStrip(
                    tokens: tokens,
                    photoUrls: photoUrls,
                    active: active,
                    onTap: onThumbTap,
                  ),
                  const SizedBox(height: 12),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (record.rating > 0) ...[
                            CheckinRatingStars(rating: record.rating, tokens: tokens, size: 18),
                            const SizedBox(width: 10),
                          ],
                          CheckinCategoryTag(category: category, tokens: tokens),
                          if (record.rating >= 4) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.22),
                                borderRadius: BorderRadius.circular(1000),
                                border: Border.all(color: Colors.white.withOpacity(0.35), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.thumb_up_alt_outlined, size: 11, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    '值得一去',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 13, color: Colors.white.withOpacity(0.85)),
                          const SizedBox(width: 6),
                          Text(
                            formatCheckinDate(record.visitedAt),
                            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 横向缩略图带
class _ThumbStrip extends StatelessWidget {
  const _ThumbStrip({
    required this.tokens,
    required this.photoUrls,
    required this.active,
    required this.onTap,
  });

  final ThemeTokens tokens;
  final List<String> photoUrls;
  final int active;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: photoUrls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final selected = i == active;
          return GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CheckinPhotoImage(url: photoUrls[i], tokens: tokens, width: 60, height: 60, fit: BoxFit.cover),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 浮层信息卡（地点/心得）
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.tokens, required this.record});

  final ThemeTokens tokens;
  final CheckinRecord record;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (record.place.isNotEmpty) ...[
            _InfoRow(
              tokens: tokens,
              icon: Icons.place_outlined,
              label: '地点',
              value: record.place,
            ),
            if (record.note.isNotEmpty) Divider(height: 20, color: tokens.divider),
          ],
          if (record.note.isNotEmpty)
            _InfoRow(
              tokens: tokens,
              icon: Icons.notes_outlined,
              label: '心得',
              value: record.note,
              multiline: true,
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.tokens,
    required this.icon,
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final ThemeTokens tokens;
  final IconData icon;
  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: tokens.brandSubtle,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: tokens.brand),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: tokens.textTertiary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: tokens.textPrimary,
                height: multiline ? 1.5 : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 白色毛玻璃胶囊按钮（叠层专用；遮罩上白图标，依赖黑色遮罩保证对比）
class _FrostedIconButton extends StatelessWidget {
  const _FrostedIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.22),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}

class _MissingState extends StatelessWidget {
  const _MissingState({required this.tokens});

  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.place_outlined, size: 48, color: tokens.textTertiary),
          const SizedBox(height: 12),
          Text(
            '足迹不存在或已删除',
            style: TextStyle(fontSize: 13, color: tokens.textSecondary),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 运行静态检查与详情页回归测试**

运行（`cwd = lumira_app_flutter`）：

```bash
flutter analyze lib/features/checkin/pages/checkin_detail_page.dart
flutter test test/features/checkin/checkin_detail_page_test.dart
```

Expected: `flutter analyze` 无 error；`checkin_detail_page_test.dart` 3 个用例全 PASS（含删除流程）。

- [ ] **Step 3: Commit**

```bash
git add lumira_app_flutter/lib/features/checkin/pages/checkin_detail_page.dart
git commit -m "feat(checkin): 详情页重构为沉浸式大封面精致手帐风"
```

---

### Task 2: 打磨列表页（渐变背景 + 统计卡图标 + 卡片精细化）

**Files:**
- Modify: `lib/features/checkin/pages/checkin_list_page.dart`
- Test: `test/features/checkin/checkin_list_page_test.dart`（不改内容，仅回归）

**Interfaces:**
- Consumes: `CheckinStats{total,highRated,avgRating,thisYear}`、`CheckinListItem{record,coverPhotoUrl}`、`checkinsProvider`、`checkinStatsProvider`、`checkinCategoriesProvider`；沿用 `_StatsCard/_CategoryPills/_SortToggle/_CheckinCard/_EmptyState` 内部组件结构与既有 finders。
- Produces: 仅内部视觉改动，对外无新符号。

- [ ] **Step 1: 给 Scaffold 加渐变背景叠层**

在 `_CheckinListPageState.build` 的 `Scaffold` 中，把 body 包装为 `Stack`，底部加径向渐变背景（复用「详情手帐」同款思路，色源全部用 tokens）：

```dart
    return Scaffold(
      backgroundColor: tokens.canvas,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.7, -0.8),
                    radius: 1.3,
                    colors: [
                      tokens.brandSubtle.withOpacity(0.5),
                      tokens.canvas.withOpacity(0),
                    ],
                    stops: const [0.0, 0.62],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              // ……原 SafeArea(child: Column(...)) 的全部内容保持不变……
            ),
          ),
        ],
      ),
    );
```

- [ ] **Step 2: 统计卡精细化（指标加图标）**

替换 `_StatsCard` 的 `_statCell`，改为「图标 + 数字 + 标签」，并为 4 项指标注入图标。把 `_StatsCard.build` 中 4 个 `_statCell(...)` 调用改为带图标数组：

```dart
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statCell('${stats?.total ?? 0}', '足迹总数', Icons.place_outlined),
            _statCell('${stats?.highRated ?? 0}', '好评店铺', Icons.thumb_up_alt_outlined),
            _statCell(avg > 0 ? avg.toStringAsFixed(1) : '-', '平均评分', Icons.star_outline),
            _statCell('${stats?.thisYear ?? 0}', '今年新增', Icons.local_fire_department_outlined),
          ],
        ),
      ),
```

并把 `_statCell(String num, String label)` 签名与实现改为 `_statCell(String num, String label, IconData icon)`：

```dart
  Widget _statCell(String num, String label, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: tokens.brandSubtle,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 17, color: tokens.brand),
        ),
        const SizedBox(height: 6),
        Text(
          num,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
            fontFamily: 'Courier New',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: tokens.textTertiary),
        ),
      ],
    );
  }
```

- [ ] **Step 3: 卡片封面更圆润 + 日期胶囊**

`_CheckinCard` 封面 `ClipRRect` 圆角 12 → 16，封面尺寸 80 → 84；日期文本改为色块胶囊：

```dart
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 84,
              height: 84,
              child: _cover(item, tokens),
            ),
          ),
```

日期行（原 `_CheckinCard` 第三行 Row 末尾的 `Text(formatCheckinDate(...))`）替换为胶囊：

```dart
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: tokens.surfaceAlt,
                          borderRadius: BorderRadius.circular(1000),
                        ),
                        child: Text(
                          formatCheckinDate(record.visitedAt),
                          style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                        ),
                      ),
```

- [ ] **Step 4: 静态检查 + 列表页回归测试**

运行（`cwd = lumira_app_flutter`）：

```bash
flutter analyze lib/features/checkin/pages/checkin_list_page.dart
flutter test test/features/checkin/checkin_list_page_test.dart
```

Expected: analyze 无 error；`checkin_list_page_test.dart` 全部 PASS（统计文案/排序/分类/值得一去/空态均维持）。

- [ ] **Step 5: Commit**

```bash
git add lumira_app_flutter/lib/features/checkin/pages/checkin_list_page.dart
git commit -m "feat(checkin): 列表页渐变背景与统计卡、卡片精细化"
```

---

### Task 3: 编辑页视觉一致性 + 修复乱码

**Files:**
- Modify: `lib/features/checkin/pages/checkin_edit_page.dart`
- Test: 无专门测试；跑 `flutter analyze` 全量校验。

**Interfaces:**
- Consumes: 现有 `_LabelField/_RatingSelector/_CategorySelector/_CheckinPhotosSection` 结构不变。
- Produces: 无对外新符号。

- [ ] **Step 1: 修复照片区正文字符乱码（`??` → 正确中文）**

编辑页照片相关文案已损坏为 `??`（编码丢失）。逐个替换为正确中文（下列为编辑前后的精确字符串，用 Edit 精确替换）：

| 现在（乱码） | 改为 |
|---|---|
| `'??',\n                style: TextStyle(\n                  fontSize: 14,\n                  fontWeight: FontWeight.w600,\n                  color: tokens.textPrimary,\n                ),`（照片区 Header 标题） | `'照片',` 后的同一 style |
| `'${photoIds.length}/9'` | 保持 |
| 添加按钮文案 `'??',`（在 `Icon(Icons.add)` 之后的 Text） | `'添加',` |
| 底部提示 `'???????????'` | `'第一张作为封面'` |
| 空态大按钮主文案 `'????',`（`Text('????',`，在 add_photo_alternate 图标后） | `'添加照片',` |
| 空态副文案 `'??????',` | `'从相册选择，最多 9 张'` |
| 网格加号 `'??',`（`_AddPhotoCell` 内） | `'添加',` |
| 封面角标 `'??',`（`Icons.star_rounded` 后的 Text） | `'封面',` |
| 选择器防爆 toast `'???? 9 ???',` | `'最多选择 9 张照片',` |
| 选择 sheet 标题 `'????',`（`Icons.photo_library_outlined` 后大标题 Text） | `'选择照片',` |
| 已选计数 `'?? ${_selected.length} / ${widget.maxCount}',` | `'已选 ${_selected.length} / ${widget.maxCount}',` |
| 确认按钮 `'??',`（白字 Text） | `'确定',` |
| 空态 `'????????',`（选择 sheet 内） | `'相册还没有照片',` |
| 注释 `/// ????3 ? grid????????? 9 ?` | `/// 照片区：3 列网格，最多 9 张` |

- [ ] **Step 2: 视觉一致性微调**

- 将 `_CheckinPhotosSection` 的照片网格圆角 10 → 12（`_AddPhotoCell`、`_PhotoEditCell`、GridView 内 `ClipRRect` 的 `BorderRadius.circular(10)` 均改为 12），并统一首张封面角标位置。
- 提交前自行核对这些字符串不再出现 `??`。
- 说明：本任务不改动既有表单字段、日期选择、评分、分类单选与保存逻辑。

- [ ] **Step 3: 静态检查**

运行（`cwd = lumira_app_flutter`）：

```bash
flutter analyze lib/features/checkin/pages/checkin_edit_page.dart
```

Expected: 无 error、无 warning。若 analyze 提示 unused import，删除对应 import。

- [ ] **Step 4: Commit**

```bash
git add lumira_app_flutter/lib/features/checkin/pages/checkin_edit_page.dart
git commit -m "fix(checkin): 编辑页照片区乱码修复与视觉一致性"
```

---

### Task 4: 全量校验 + 人工视觉核对

**Files:** 无源码改动。

- [ ] **Step 1: 全模块回归**

运行（`cwd = lumira_app_flutter`）：

```bash
flutter test test/features/checkin/
```

Expected: checkin 全部测试 PASS。

- [ ] **Step 2: 人工核对（建议真机或模拟器）**

运行 `flutter run --dart-define=API_BASE_URL=http://<局域网IP>:3000/api/v1`（或现有调试方式），进入「探店足迹」模块核对：
1. 详情页：大封面沉浸、店名叠在图上、页面无 `??` 乱码、地点/心得浮层卡片与封面重叠；有 ≥2 张照片时缩略图可切换封面。
2. 列表页：顶部渐变背景、统计卡带图标、卡片封面更圆润、日期胶囊。
3. 切换 2-3 套主题与淡出 UI 风格，确认三页配色随主题自动切换、无硬编码色导致的花色错乱。

- [ ] **Step 3: 说明与交付**

向用户汇报：三页改造完成、测试通过、待真机人工核对列表。