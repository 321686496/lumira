# Flutter 完善计划 Plan C: 分享功能 + 学院学习轨迹

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `FragmentPosterGenerator` 重构为通用 `PosterGenerator` 三件套（生成/导出/分享），接入碎片海报、拍摄成品分享、成就分享三处入口；扩展 `AcademyDao` 维护学习轨迹表，课程列表按规则排序并显示「已学完」徽章，新增学习轨迹时间线页。

**Architecture:** `PosterGenerator`（`lib/shared/services/poster_generator.dart`）以 `showPoster(...)` 静态方法弹出底部 Sheet，内部 `RepaintBoundary` 包裹调用方传入的 `content` Widget，底部三个按钮分别执行预览确认 / `saver_gallery` 保存到相册（HarmonyOS 降级 `MethodChannel('lumira/photo_saver')`）/ `share_plus.shareXFiles` 分享。`AcademyDao` 新增 `isCourseFullyCompleted` / `getMaxTrajectorySequence` / `upsertTrajectory` / `getTrajectory` / `getAllTrajectory` 五个方法操作 `academy_learning_trajectory` 表（Plan A v4 迁移已创建），`AcademyRepository.markCompleted` 在状态写入后自动检查并 upsert 轨迹，`submitAssignment` 在 `photoPath != null` 时触发 `markCompleted` 重新校验。学院首页新增 `sortedCoursesProvider`（async，按 level ASC + 未完成在前 lastViewedAt DESC + 已完成沉底 completedAt ASC）与 `courseFullyCompletedProvider`，`AcademyCourseCard` 接受 `isFullyCompleted` 参数显示绿色「已学完」徽章。新增 `/academy/trajectory` 路由与 `AcademyTrajectoryPage` 时间线竖向布局页。

**Tech Stack:** Flutter 3.7+, Dart 2.19, flutter_riverpod 2.3.6, sqflite, go_router 6.5.7, share_plus 7.2.2, saver_gallery 3.0.6, path_provider

## Global Constraints

- 必须兼容 iOS / Android / HarmonyOS 三平台
- Dart SDK: >=2.19.6 <3.0.0（不支持 Dart 3）
- 不引入新依赖
- 学院完成判定：status=completed AND 作业有 status IN ('submitted','reviewed') AND photo_path != null
- trajectory 自动维护：markCompleted 内部检查 isCourseFullyCompleted，满足则 upsertTrajectory
- 已完成课程在列表中沉底（按 completedAt ASC）+ 显示绿色「已学完」徽章
- 海报三件套：生成（预览）/ 导出（saver_gallery 保存到相册，HarmonyOS 降级 MethodChannel）/ 分享（share_plus.shareXFiles）
- 所有新增 Provider 用 flutter_riverpod 2.3.6 API
- 文件命名用 snake_case，类名用 PascalCase
- 主题 tokens 通过 `ref.watch(themeTokensProvider)` 获取
- 提交信息使用 Conventional Commits 格式：`feat(scope): description`
- 每个任务结束必须运行 `flutter analyze` 与对应测试确认通过
- Plan A 已完成：`academy_learning_trajectory` 表 schema 已在 v4 迁移中创建（`AcademyLearningTrajectoryTable.createSql`），`tables.dart` 已有 `Tables.academyLearningTrajectory` / `Tables.colCourseId` / `Tables.colCompletedAt` / `Tables.colSequence` 常量；`growth_dao.dart` + `growth_providers.dart` + `profile_growth_page.dart` 已接入真实数据，`AchievementRecord` 模型已存在于 `lib/features/profile/data/growth_models.dart`

## File Structure

### 新增文件
- `lib/shared/services/poster_generator.dart` — 通用海报生成器（生成/导出/分享三件套底部 Sheet）
- `lib/features/academy/data/academy_trajectory_models.dart` — `AcademyTrajectoryRecord` 数据类
- `lib/features/academy/pages/academy_trajectory_page.dart` — 学习轨迹时间线页
- `test/shared/services/poster_generator_test.dart` — PosterGenerator 组件测试
- `test/features/academy/academy_repository_test.dart` — Repository 轨迹维护测试
- `test/features/academy/academy_trajectory_page_test.dart` — 轨迹页组件测试

### 修改文件
- `lib/features/profile/widgets/fragment_poster_generator.dart` — 改为 deprecated wrapper 委托 PosterGenerator，保留 `_PhotoGrid` 与 `_PosterContent` 作为 `FragmentPosterContent` 公开 widget
- `lib/features/profile/pages/profile_fragment_detail_page.dart:82-89` — onSharePoster 改用 `PosterGenerator.showPoster(...)`
- `lib/features/capture/pages/capture_preview_page.dart:408-440` — nav 右侧新增分享按钮 + `_onShare` 底部 Sheet
- `lib/features/profile/pages/profile_growth_page.dart` — `_AchievementCell` 新增分享按钮 + `_AchievementPosterContent`
- `lib/features/academy/data/academy_dao.dart` — 新增轨迹表常量段 + 5 个方法
- `lib/features/academy/data/academy_repository.dart:17,147-158,192-194` — 接口新增 `isCourseFullyCompleted`/`getAllTrajectory`；`markCompleted` 维护轨迹；`submitAssignment` 触发 `markCompleted`
- `lib/features/academy/providers/academy_providers.dart` — 新增 `courseFullyCompletedProvider` / `sortedCoursesProvider` / `academyTrajectoryProvider`；`AcademyActionNotifier.submitAssignment` 触发 `markCompleted`
- `lib/features/academy/pages/academy_page.dart:172-210` — `_CourseGrid` 改用 `sortedCoursesProvider` + `courseFullyCompletedProvider`
- `lib/features/academy/widgets/academy_course_card.dart` — 新增 `isFullyCompleted` 参数 + 绿色「已学完」徽章
- `lib/features/academy/widgets/academy_overview_card.dart` — 新增「我的学习轨迹」入口按钮
- `lib/core/router/route_names.dart` — 新增 `academyTrajectory = '/academy/trajectory'` 常量
- `lib/app/router.dart` — 注册 `/academy/trajectory` 路由
- `test/features/academy/academy_dao_test.dart` — 修改 `_onCreate` 加轨迹表 + 新增 4 个测试组

---

## Task 1: 通用 PosterGenerator 重构

**Files:**
- Create: `lib/shared/services/poster_generator.dart`
- Test: `test/shared/services/poster_generator_test.dart`

**Interfaces:**
- Consumes: `ThemeTokens`（`ref.watch(themeTokensProvider)`）、`saver_gallery` 3.0.6（`SaverGallery.saveImage`）、`share_plus` 7.2.2（`Share.shareXFiles`）、`path_provider`（`getTemporaryDirectory`）、Flutter `RepaintBoundary` / `toImage` / `toByteData`
- Produces: `PosterGenerator.showPoster({required BuildContext context, required ThemeTokens tokens, required String title, required Widget content, required GlobalKey posterKey, required String shareSubject, required String shareText, required String fileNamePrefix})` → `Future<void>`

- [ ] **Step 1: 写失败测试 — 验证 PosterGenerator 底部 Sheet 显示三按钮**

Create `test/shared/services/poster_generator_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/shared/services/poster_generator.dart';

void main() {
  testWidgets('PosterGenerator.showPoster displays sheet with three buttons',
      (tester) async {
    final posterKey = GlobalKey();
    final tokens = ThemeTokens.light();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => PosterGenerator.showPoster(
                  context: context,
                  tokens: tokens,
                  title: '测试海报',
                  content: Container(
                    key: posterKey,
                    width: 100,
                    height: 100,
                    color: tokens.brand,
                  ),
                  posterKey: posterKey,
                  shareSubject: '测试主题',
                  shareText: '测试文本',
                  fileNamePrefix: 'test_poster',
                ),
                child: const Text('打开海报'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开海报'));
    await tester.pumpAndSettle();

    // 验证底部 Sheet 出现
    expect(find.text('测试海报'), findsOneWidget);
    // 验证三个按钮都出现
    expect(find.text('生成海报'), findsOneWidget);
    expect(find.text('导出海报'), findsOneWidget);
    expect(find.text('分享海报'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/shared/services/poster_generator_test.dart -v`
Expected: FAIL with `poster_generator.dart: Target of URI doesn't exist` / `PosterGenerator` 未定义的编译错误

- [ ] **Step 3: 创建 poster_generator.dart**

Create `lib/shared/services/poster_generator.dart`:

```dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/theme_tokens.dart';

/// 通用海报生成器
///
/// 提供统一的「生成海报 / 导出海报 / 分享海报」三件套底部 Sheet。
/// 调用方传入 [content] Widget 作为海报内容，内部用 [RepaintBoundary]
/// 包裹并在导出/分享时通过 [toImage] 捕获为 PNG。
///
/// 平台兼容：
/// - 导出（保存到相册）：iOS/Android 用 `SaverGallery.saveImage`；
///   HarmonyOS 降级到 `MethodChannel('lumira/photo_saver')` 调用原生 photoAccessHelper。
/// - 分享：`Share.shareXFiles` 三平台均支持。
class PosterGenerator {
  PosterGenerator._();

  /// 弹出海报预览底部 Sheet
  ///
  /// [content] 是海报正文 Widget，会被 [RepaintBoundary] 包裹。
  /// [posterKey] 必须由调用方创建并传入，用于捕获图片。
  /// [fileNamePrefix] 用于导出/分享时的文件名前缀。
  static Future<void> showPoster({
    required BuildContext context,
    required ThemeTokens tokens,
    required String title,
    required Widget content,
    required GlobalKey posterKey,
    required String shareSubject,
    required String shareText,
    required String fileNamePrefix,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PosterSheet(
        tokens: tokens,
        title: title,
        content: content,
        posterKey: posterKey,
        shareSubject: shareSubject,
        shareText: shareText,
        fileNamePrefix: fileNamePrefix,
      ),
    );
  }
}

class _PosterSheet extends StatefulWidget {
  const _PosterSheet({
    required this.tokens,
    required this.title,
    required this.content,
    required this.posterKey,
    required this.shareSubject,
    required this.shareText,
    required this.fileNamePrefix,
  });

  final ThemeTokens tokens;
  final String title;
  final Widget content;
  final GlobalKey posterKey;
  final String shareSubject;
  final String shareText;
  final String fileNamePrefix;

  @override
  State<_PosterSheet> createState() => _PosterSheetState();
}

class _PosterSheetState extends State<_PosterSheet> {
  bool _exporting = false;
  bool _sharing = false;

  Future<ui.Image?> _captureImage() async {
    final boundary = widget.posterKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    return boundary.toImage(pixelRatio: 2.0);
  }

  Future<List<int>?> _captureBytes() async {
    final image = await _captureImage();
    if (image == null) return null;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    return byteData.buffer.asUint8List().toList();
  }

  Future<File> _writeTempFile(List<int> bytes) async {
    final tempDir = await getTemporaryDirectory();
    final fileName =
        '${widget.fileNamePrefix}_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// 导出海报到系统相册
  /// iOS/Android: SaverGallery.saveImage
  /// HarmonyOS: MethodChannel('lumira/photo_saver') saveToAlbum
  Future<void> _onExport() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await _captureBytes();
      if (bytes == null) {
        _toast('海报生成失败');
        return;
      }
      final fileName =
          '${widget.fileNamePrefix}_${DateTime.now().millisecondsSinceEpoch}.png';
      try {
        // 尝试 saver_gallery（iOS/Android）
        await SaverGallery.saveImage(
          Uint8List.fromList(bytes),
          fileName: fileName,
          skipIfExists: false,
        );
        _toast('已保存到相册');
      } on MissingPluginException {
        // HarmonyOS 降级：写入临时文件后调用原生通道
        final file = await _writeTempFile(bytes);
        const channel = MethodChannel('lumira/photo_saver');
        final result = await channel.invokeMethod('saveToAlbum', {
          'path': file.path,
        });
        final success = result != null && result['success'] == true;
        if (success) {
          _toast('已保存到相册');
        } else {
          _toast('保存失败：${result?['error'] ?? "未知错误"}');
        }
      }
    } catch (e) {
      _toast('导出失败：$e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// 分享海报到系统
  Future<void> _onShare() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final bytes = await _captureBytes();
      if (bytes == null) {
        _toast('海报生成失败');
        return;
      }
      final file = await _writeTempFile(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: widget.shareSubject,
        text: widget.shareText,
      );
    } catch (e) {
      _toast('分享失败：$e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      decoration: BoxDecoration(
        color: t.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部拖把
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: t.surfaceAlt,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 标题行
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(Icons.close, size: 20, color: t.textTertiary),
                ),
              ],
            ),
          ),
          // 海报内容
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: RepaintBoundary(
                key: widget.posterKey,
                child: widget.content,
              ),
            ),
          ),
          // 底部三按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Row(
              children: [
                Expanded(
                  child: _PosterButton(
                    tokens: t,
                    icon: Icons.visibility_outlined,
                    label: '生成海报',
                    color: t.surfaceAlt,
                    textColor: t.textPrimary,
                    onTap: () => _toast('海报已生成'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PosterButton(
                    tokens: t,
                    icon: _exporting
                        ? null
                        : Icons.save_alt_outlined,
                    label: _exporting ? '导出中...' : '导出海报',
                    color: t.brandSubtle,
                    textColor: t.brandText,
                    loading: _exporting,
                    onTap: _exporting ? null : _onExport,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PosterButton(
                    tokens: t,
                    icon: _sharing ? null : Icons.ios_share_outlined,
                    label: _sharing ? '分享中...' : '分享海报',
                    color: t.brand,
                    textColor: Colors.white,
                    loading: _sharing,
                    onTap: _sharing ? null : _onShare,
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

class _PosterButton extends StatelessWidget {
  const _PosterButton({
    required this.tokens,
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    this.loading = false,
    this.onTap,
  });

  final ThemeTokens tokens;
  final IconData? icon;
  final String label;
  final Color color;
  final Color textColor;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: textColor,
                ),
              )
            else if (icon != null)
              Icon(icon, size: 18, color: textColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/shared/services/poster_generator_test.dart -v`
Expected: PASS — 底部 Sheet 出现，三个按钮文字可见

- [ ] **Step 5: 提交**

```bash
git add lib/shared/services/poster_generator.dart test/shared/services/poster_generator_test.dart
git commit -m "feat(share): 新增通用 PosterGenerator 支持生成/导出/分享三件套"
```

---

## Task 2: 碎片海报接入 PosterGenerator

**Files:**
- Modify: `lib/features/profile/widgets/fragment_poster_generator.dart:1-415`
- Modify: `lib/features/profile/pages/profile_fragment_detail_page.dart:12,82-89`
- Test: `test/features/profile/profile_fragment_detail_page_test.dart`

**Interfaces:**
- Consumes: `PosterGenerator.showPoster(...)`（Task 1 产出）、`FragmentItem`（`profile_mock_data.dart`）、`ThemeTokens`
- Produces: `FragmentPosterContent`（公开 widget，渲染碎片海报正文）、`FragmentPosterGenerator.showPoster(...)`（deprecated wrapper，委托 PosterGenerator）

- [ ] **Step 1: 写失败测试 — 验证碎片详情页分享按钮触发 PosterGenerator**

Create `test/features/profile/profile_fragment_detail_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/profile/pages/profile_fragment_detail_page.dart';

void main() {
  testWidgets(
      'tapping share button on fragment card opens PosterGenerator sheet',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProfileFragmentDetailPage()),
    );
    await tester.pumpAndSettle();

    // 找到第一个「生成海报」按钮并点击
    final shareButtons = find.text('生成海报');
    expect(shareButtons, findsWidgets);

    await tester.tap(shareButtons.first);
    await tester.pumpAndSettle();

    // 验证 PosterGenerator 底部 Sheet 出现（包含「导出海报」和「分享海报」按钮）
    expect(find.text('导出海报'), findsOneWidget);
    expect(find.text('分享海报'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/features/profile/profile_fragment_detail_page_test.dart -v`
Expected: FAIL — 点击「生成海报」后找不到「导出海报」（现有 FragmentPosterGenerator 只有「分享海报」单按钮）

- [ ] **Step 3: 重构 fragment_poster_generator.dart 为 deprecated wrapper + 公开 FragmentPosterContent**

Replace `lib/features/profile/widgets/fragment_poster_generator.dart` 全文:

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';
import '../../../shared/services/poster_generator.dart';
import '../data/profile_mock_data.dart';

/// 碎片海报内容 Widget（公开，供 PosterGenerator 包裹渲染）
///
/// 渲染碎片图标、名称、进度环、图片九宫格、进度文字、品牌水印。
class FragmentPosterContent extends StatelessWidget {
  const FragmentPosterContent({
    super.key,
    required this.tokens,
    required this.fragment,
  });

  final ThemeTokens tokens;
  final FragmentItem fragment;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final fragment = this.fragment;
    final done = fragment.current >= fragment.max;
    final percent = fragment.percent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.brandSubtle, t.canvas],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.camera_alt_outlined, size: 18, color: t.brand),
              const SizedBox(width: 6),
              Text(
                'LUMIRA · 如画',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: t.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [t.brand, t.brandDeep]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(fragment.icon, size: 28, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '碎片收集',
                      style: TextStyle(
                        fontSize: 12,
                        color: t.textTertiary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fragment.name,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Noto Serif SC',
                        color: t.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: percent / 100.0,
                      strokeWidth: 4,
                      backgroundColor: t.brandSubtle,
                      valueColor: AlwaysStoppedAnimation<Color>(t.brand),
                    ),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (fragment.photoUrls.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _PhotoGrid(tokens: t, urls: fragment.photoUrls),
            ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: done ? t.successSubtle : t.brand.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  done
                      ? Icons.check_circle
                      : Icons.local_fire_department_outlined,
                  size: 16,
                  color: done ? t.success : t.brand,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    done
                        ? '已集齐 ${fragment.max} 枚「${fragment.name}」碎片！'
                        : '已收集 ${fragment.current}/${fragment.max}，再收集 ${fragment.max - fragment.current} 枚即可集齐',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: done ? t.success : t.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: Text(
              '如画 LUMIRA · 记录每一帧光影',
              style: TextStyle(
                fontSize: 10,
                color: t.textTertiary,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 图片九宫格（自适应 2-9 张）
class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.tokens, required this.urls});
  final ThemeTokens tokens;
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final count = urls.length;
    int crossCount;
    if (count <= 1) {
      crossCount = 1;
    } else if (count <= 4) {
      crossCount = 2;
    } else {
      crossCount = 3;
    }

    final rows = (count / crossCount).ceil();
    final cellHeight = crossCount == 1 ? 200.0 : 110.0;

    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < crossCount; c++)
                Expanded(
                  child: (r * crossCount + c) < count
                      ? Container(
                          height: cellHeight,
                          margin: EdgeInsets.only(
                            right: c < crossCount - 1 ? 3 : 0,
                            bottom: r < rows - 1 ? 3 : 0,
                          ),
                          child: Image.network(
                            urls[r * crossCount + c],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: tokens.brandSubtle,
                              child: Icon(Icons.image_outlined,
                                  size: 24, color: tokens.brand),
                            ),
                          ),
                        )
                      : SizedBox(height: cellHeight),
                ),
            ],
          ),
      ],
    );
  }
}

/// Deprecated: 请直接使用 PosterGenerator.showPoster + FragmentPosterContent
@Deprecated('Use PosterGenerator.showPoster with FragmentPosterContent instead')
class FragmentPosterGenerator {
  FragmentPosterGenerator._();

  static Future<void> showPoster(
    BuildContext context, {
    required ThemeTokens tokens,
    required FragmentItem fragment,
    required GlobalKey posterKey,
  }) async {
    await PosterGenerator.showPoster(
      context: context,
      tokens: tokens,
      title: '海报预览',
      content: FragmentPosterContent(tokens: tokens, fragment: fragment),
      posterKey: posterKey,
      shareSubject: '如画 · 碎片收集：${fragment.name}',
      shareText:
          '我在如画收集了「${fragment.name}」碎片 ${fragment.current}/${fragment.max}，快来一起收集吧！',
      fileNamePrefix: 'lumira_fragment_${fragment.name}',
    );
  }
}
```

- [ ] **Step 3b: 修改 profile_fragment_detail_page.dart 改用 PosterGenerator.showPoster**

Modify `lib/features/profile/pages/profile_fragment_detail_page.dart`:

在 import 段（line 12）替换:
```dart
import '../widgets/fragment_poster_generator.dart';
```
为:
```dart
import '../../../shared/services/poster_generator.dart';
import '../widgets/fragment_poster_generator.dart' show FragmentPosterContent;
```

在 `_ProfileFragmentDetailPageState.build` 中（line 82-89）替换 `onSharePoster` 回调:
```dart
                        onSharePoster: () {
                          FragmentPosterGenerator.showPoster(
                            context,
                            tokens: tokens,
                            fragment: entry.value,
                            posterKey: _keyFor(entry.key),
                          );
                        },
```
为:
```dart
                        onSharePoster: () {
                          PosterGenerator.showPoster(
                            context: context,
                            tokens: tokens,
                            title: '海报预览',
                            content: FragmentPosterContent(
                              tokens: tokens,
                              fragment: entry.value,
                            ),
                            posterKey: _keyFor(entry.key),
                            shareSubject: '如画 · 碎片收集：${entry.value.name}',
                            shareText:
                                '我在如画收集了「${entry.value.name}」碎片 ${entry.value.current}/${entry.value.max}，快来一起收集吧！',
                            fileNamePrefix:
                                'lumira_fragment_${entry.value.name}',
                          );
                        },
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/features/profile/profile_fragment_detail_page_test.dart -v`
Expected: PASS — 点击「生成海报」后底部 Sheet 出现「导出海报」和「分享海报」按钮

- [ ] **Step 5: 提交**

```bash
git add lib/features/profile/widgets/fragment_poster_generator.dart lib/features/profile/pages/profile_fragment_detail_page.dart test/features/profile/profile_fragment_detail_page_test.dart
git commit -m "feat(share): 碎片海报接入通用 PosterGenerator 三件套"
```

---

## Task 3: 拍摄成品分享

**Files:**
- Modify: `lib/features/capture/pages/capture_preview_page.dart:17,408-440`
- Test: `test/features/capture/capture_preview_share_test.dart`

**Interfaces:**
- Consumes: `PosterGenerator.showPoster(...)`（Task 1）、`ExifCardGenerator.generate(...)`（已存在）、`Share.shareXFiles`（share_plus）、`MethodChannel('lumira/photo_saver')`（已存在）
- Produces: `_CapturePreviewPageState._onShare()` 弹出底部 Sheet（保存到相册 / 分享到系统 / 生成 EXIF 海报 / 取消）

- [ ] **Step 1: 写失败测试 — 验证拍摄预览页分享按钮弹出底部 Sheet**

Create `test/features/capture/capture_preview_share_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/features/capture/pages/capture_preview_page.dart';

void main() {
  testWidgets('CapturePreviewPage nav has share button that opens sheet',
      (tester) async {
    final router = GoRouter(
      initialLocation:
          '${RouteNames.capturePreview}?photoUrl=https://example.com/test.jpg',
      routes: [
        GoRoute(
          path: RouteNames.capturePreview,
          name: 'capturePreview',
          builder: (context, state) => CapturePreviewPage(
            photoUrl: state.queryParams['photoUrl'],
            photoId: state.queryParams['photoId'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    // 验证分享按钮存在
    final shareIcon = find.byIcon(Icons.ios_share_outlined);
    expect(shareIcon, findsOneWidget);

    // 点击分享按钮
    await tester.tap(shareIcon);
    await tester.pumpAndSettle();

    // 验证底部 Sheet 出现三个选项
    expect(find.text('保存到相册'), findsOneWidget);
    expect(find.text('分享到系统'), findsOneWidget);
    expect(find.text('生成 EXIF 海报'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/features/capture/capture_preview_share_test.dart -v`
Expected: FAIL — `Finder found no matching widget for icon Icons.ios_share_outlined`（分享按钮尚未添加）

- [ ] **Step 3: 修改 capture_preview_page.dart 添加分享按钮与底部 Sheet**

Modify `lib/features/capture/pages/capture_preview_page.dart`:

在 import 段（line 17 后）追加:
```dart
import 'package:share_plus/share_plus.dart';
import '../../../shared/services/poster_generator.dart';
```

在 `_CapturePreviewPageState` 类内（`_onExifCard` 方法之后，约 line 192）新增 `_onShare` / `_onShareSystem` / `_onExifPoster` 方法:
```dart
  /// 顶部 nav 分享按钮：弹出底部 Sheet
  Future<void> _onShare() async {
    final tokens = ref.watch(themeTokensProvider);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E0D8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _ShareOption(
              icon: Icons.save_alt_outlined,
              text: '保存到相册',
              onTap: () {
                Navigator.of(ctx).pop();
                _onSave();
              },
            ),
            _ShareOption(
              icon: Icons.ios_share_outlined,
              text: '分享到系统',
              onTap: () {
                Navigator.of(ctx).pop();
                _onShareSystem();
              },
            ),
            _ShareOption(
              icon: Icons.content_paste_outlined,
              text: '生成 EXIF 海报',
              onTap: () {
                Navigator.of(ctx).pop();
                _onExifPoster();
              },
            ),
            const SizedBox(height: 8),
            _ShareOption(
              icon: Icons.close,
              text: '取消',
              onTap: () => Navigator.of(ctx).pop(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 分享原始照片到系统
  Future<void> _onShareSystem() async {
    if (_photoUrl.isEmpty) return;
    try {
      if (_photoUrl.startsWith('http')) {
        await Share.share(_photoUrl, subject: '如画 LUMIRA · 拍摄作品');
      } else {
        await Share.shareXFiles(
          [XFile(_photoUrl)],
          subject: '如画 LUMIRA · 拍摄作品',
          text: '我用如画拍了一张照片，快来看看吧！',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分享失败：$e')),
      );
    }
  }

  /// 生成 EXIF 海报并弹出 PosterGenerator 预览
  Future<void> _onExifPoster() async {
    if (_photoUrl.isEmpty || _photoUrl.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('网络图片无法生成 EXIF 海报')),
      );
      return;
    }

    try {
      final templateId = ref.read(CaptureState.currentTemplateIdProvider);
      final sceneId = ref.read(CaptureState.activeScenePresetIdProvider);
      final exif = await PhotoExifReader.read(
        _photoUrl,
        sceneName: sceneId,
        template: templateId,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      final outputPath =
          '${_photoUrl}_exif_${DateTime.now().millisecondsSinceEpoch}.png';
      await ExifCardGenerator.generate(
        photoPath: _photoUrl,
        outputPath: outputPath,
        exif: exif,
      );
      if (!mounted) return;

      final tokens = ref.watch(themeTokensProvider);
      final posterKey = GlobalKey();
      await PosterGenerator.showPoster(
        context: context,
        tokens: tokens,
        title: 'EXIF 海报预览',
        content: Container(
          key: posterKey,
          color: const Color(0xFF1C1A17),
          child: Image.file(
            File(outputPath),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              height: 200,
              color: tokens.surfaceAlt,
              child: Icon(Icons.image_outlined, color: tokens.textTertiary),
            ),
          ),
        ),
        posterKey: posterKey,
        shareSubject: '如画 LUMIRA · EXIF 海报',
        shareText: '我用如画拍了这张照片，附带了完整的 EXIF 信息！',
        fileNamePrefix: 'lumira_exif',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成失败：$e')),
      );
    }
  }
```

在文件末尾（`_SaveButton` 类之后）新增 `_ShareOption` widget:
```dart
class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22, color: const Color(0xFF1A1A1A)),
      title: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1A1A1A),
        ),
      ),
      onTap: onTap,
    );
  }
}
```

修改 `_PreviewNav` 类（line 408-440）添加 `onShare` 参数和分享按钮。替换整个 `_PreviewNav`:
```dart
class _PreviewNav extends StatelessWidget {
  const _PreviewNav({
    required this.tokens,
    required this.onBack,
    required this.onPressStart,
    required this.onPressEnd,
    required this.onShare,
  });

  final ThemeTokens tokens;
  final VoidCallback onBack;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      // 硬编码颜色，与 uni-app 一致 (preview-nav bg rgba(28,26,23,0.9))
      color: const Color.fromRGBO(28, 26, 23, 0.9),
      child: LumiraNav(
        title: '照片预览',
        transparent: true,
        leading: _NavBackButton(onTap: onBack),
        actions: [
          _CompareLink(
            onTap: () {},
            onPressStart: onPressStart,
            onPressEnd: onPressEnd,
          ),
          GestureDetector(
            onTap: onShare,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(
                Icons.ios_share_outlined,
                size: 22,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

修改 `_CapturePreviewPageState.build` 中 `_PreviewNav` 调用（约 line 339-344），添加 `onShare: _onShare`:
```dart
                _PreviewNav(
                  tokens: tokens,
                  onBack: _back,
                  onPressStart: _onCompareStart,
                  onPressEnd: _onCompareEnd,
                  onShare: _onShare,
                ),
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/features/capture/capture_preview_share_test.dart -v`
Expected: PASS — 分享按钮存在，点击后底部 Sheet 出现三个选项

- [ ] **Step 5: 提交**

```bash
git add lib/features/capture/pages/capture_preview_page.dart test/features/capture/capture_preview_share_test.dart
git commit -m "feat(share): 拍摄预览页新增分享按钮支持保存/分享/EXIF海报"
```

---

## Task 4: 成就分享

**Files:**
- Modify: `lib/features/profile/pages/profile_growth_page.dart` — `_AchievementCell` 新增分享按钮 + `_AchievementPosterContent`
- Test: `test/features/profile/profile_growth_share_test.dart`

**Interfaces:**
- Consumes: `PosterGenerator.showPoster(...)`（Task 1）、`AchievementRecord`（`growth_models.dart`，Plan A 产出）、`GrowthSummary`（`growth_models.dart`，Plan A 产出）、`growthLevelProvider`（Plan A 产出）
- Produces: `_AchievementCell` 新增 `onShare` 回调；`_AchievementPosterContent` widget

- [ ] **Step 1: 写失败测试 — 验证成就分享按钮触发 PosterGenerator**

Create `test/features/profile/profile_growth_share_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/profile/data/growth_models.dart';
import 'package:lumira_app_flutter/features/profile/pages/profile_growth_page.dart';
import 'package:lumira_app_flutter/features/profile/providers/growth_providers.dart';

void main() {
  testWidgets(
      'tapping share on unlocked achievement opens PosterGenerator sheet',
      (tester) async {
    final unlockedAchievements = <AchievementRecord>[
      const AchievementRecord(
        id: 'ach_first_photo',
        name: '初次拍摄',
        description: '完成第一次拍摄',
        iconKey: 'camera',
        unlocked: true,
        unlockedAt: 1700000000000,
      ),
      const AchievementRecord(
        id: 'ach_streak_7',
        name: '连续7天',
        description: '连续打卡 7 天',
        iconKey: 'flame',
        unlocked: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          growthAchievementsProvider.overrideWith(
            (ref) async => unlockedAchievements,
          ),
          growthLevelProvider.overrideWith(
            (ref) async => GrowthSummary(
              level: 3,
              currentXp: 1200,
              xpToNextLevel: 300,
              levelName: '进阶',
            ),
          ),
          growthTrajectoryProvider.overrideWith((ref) async => const []),
          growthHeatmapProvider.overrideWith((ref) async => const {}),
        ],
        child: const MaterialApp(home: ProfileGrowthPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 验证已解锁成就上有分享按钮
    final shareIcons = find.byIcon(Icons.ios_share_outlined);
    expect(shareIcons, findsOneWidget);

    // 点击分享按钮
    await tester.tap(shareIcons);
    await tester.pumpAndSettle();

    // 验证 PosterGenerator 底部 Sheet 出现
    expect(find.text('导出海报'), findsOneWidget);
    expect(find.text('分享海报'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/features/profile/profile_growth_share_test.dart -v`
Expected: FAIL — `Finder found no matching widget for icon Icons.ios_share_outlined`（成就卡片尚无分享按钮）

- [ ] **Step 3: 修改 profile_growth_page.dart 添加成就分享功能**

Modify `lib/features/profile/pages/profile_growth_page.dart`:

在 import 段追加（如果尚未存在）:
```dart
import '../../../shared/services/poster_generator.dart';
import '../data/growth_models.dart';
import '../providers/growth_providers.dart';
```

找到 `_AchievementCell` 类（Plan A 版本，使用 `AchievementRecord`），替换为含分享按钮的版本:
```dart
class _AchievementCell extends StatelessWidget {
  const _AchievementCell({
    required this.item,
    required this.tokens,
    this.levelName = '',
  });

  final AchievementRecord item;
  final ThemeTokens tokens;
  final String levelName;

  IconData _iconForKey(String key) {
    switch (key) {
      case 'camera':
        return Icons.camera_alt;
      case 'flame':
        return Icons.local_fire_department;
      case 'layers':
        return Icons.layers;
      case 'trophy':
        return Icons.emoji_events;
      case 'star':
        return Icons.star;
      default:
        return Icons.emoji_events;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cell = Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.divider, width: 1),
      ),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _iconForKey(item.iconKey),
                size: 36,
                color: item.unlocked ? tokens.textPrimary : tokens.textTertiary,
              ),
              const SizedBox(height: 4),
              Text(
                item.name,
                style: TextStyle(
                  fontSize: 11,
                  color: item.unlocked
                      ? tokens.textPrimary
                      : tokens.textTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          // 已解锁成就右上角分享按钮
          if (item.unlocked)
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  final posterKey = GlobalKey();
                  PosterGenerator.showPoster(
                    context: context,
                    tokens: tokens,
                    title: '成就海报预览',
                    content: _AchievementPosterContent(
                      tokens: tokens,
                      achievement: item,
                      levelName: levelName,
                    ),
                    posterKey: posterKey,
                    shareSubject: '如画 · 成就解锁：${item.name}',
                    shareText: '我在如画解锁了「${item.name}」成就！快来一起挑战吧！',
                    fileNamePrefix: 'lumira_achievement_${item.id}',
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.ios_share_outlined,
                    size: 14,
                    color: tokens.brand,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (item.unlocked) return cell;
    return Opacity(opacity: 0.5, child: cell);
  }
}
```

在文件末尾追加 `_AchievementPosterContent` widget:
```dart
/// 成就海报内容 Widget
class _AchievementPosterContent extends StatelessWidget {
  const _AchievementPosterContent({
    required this.tokens,
    required this.achievement,
    required this.levelName,
  });

  final ThemeTokens tokens;
  final AchievementRecord achievement;
  final String levelName;

  IconData _iconForKey(String key) {
    switch (key) {
      case 'camera':
        return Icons.camera_alt;
      case 'flame':
        return Icons.local_fire_department;
      case 'layers':
        return Icons.layers;
      case 'trophy':
        return Icons.emoji_events;
      case 'star':
        return Icons.star;
      default:
        return Icons.emoji_events;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.brandSubtle, t.canvas],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.camera_alt_outlined, size: 18, color: t.brand),
              const SizedBox(width: 6),
              Text(
                'LUMIRA · 如画',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: t.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [t.brand, t.brandDeep]),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconForKey(achievement.iconKey),
                size: 40,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '成就解锁',
              style: TextStyle(
                fontSize: 12,
                color: t.textTertiary,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              achievement.name,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                fontFamily: 'Noto Serif SC',
                color: t.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              achievement.description,
              style: TextStyle(
                fontSize: 14,
                color: t.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: t.brand.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, size: 16, color: t.brand),
                const SizedBox(width: 8),
                Text(
                  levelName.isNotEmpty
                      ? '当前等级：$levelName'
                      : '继续探索更多成就',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: t.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: Text(
              '如画 LUMIRA · 记录每一帧光影',
              style: TextStyle(
                fontSize: 10,
                color: t.textTertiary,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

修改 `_AchievementCard` 中构建 `_AchievementCell` 的调用，传入 `levelName`。找到 `_AchievementCell(item: a, tokens: tokens)` 调用（在 `_AchievementCard.build` 内），替换为:
```dart
_AchievementCell(item: a, tokens: tokens, levelName: '')
```

> 注意：`levelName` 需要从 `growthLevelProvider` 获取。修改 `_AchievementCard` 为 `ConsumerWidget` 以读取等级名称。如果 `_AchievementCard` 已经是 `ConsumerWidget`（Plan A 可能已改），则直接在 `build` 中 `ref.watch(growthLevelProvider)`。如果仍是 `StatelessWidget`，改为 `ConsumerWidget`:

```dart
class _AchievementCard extends ConsumerWidget {
  const _AchievementCard({required this.tokens, required this.achievements});
  final ThemeTokens tokens;
  final List<AchievementRecord> achievements;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlockedCount = achievements.where((a) => a.unlocked).length;
    final levelAsync = ref.watch(growthLevelProvider);
    final levelName = levelAsync.maybeWhen(
      data: (s) => s.levelName,
      orElse: () => '',
    );
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '成就',
                style: TextStyle(
                  fontFamily: 'Noto Serif SC',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '$unlockedCount / ${achievements.length}',
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.textTertiary,
                  fontFamily: 'Courier New',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.0,
            children: achievements
                .map((a) => _AchievementCell(
                      item: a,
                      tokens: tokens,
                      levelName: levelName,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/features/profile/profile_growth_share_test.dart -v`
Expected: PASS — 已解锁成就上有分享按钮，点击后 PosterGenerator 底部 Sheet 出现

- [ ] **Step 5: 提交**

```bash
git add lib/features/profile/pages/profile_growth_page.dart test/features/profile/profile_growth_share_test.dart
git commit -m "feat(share): 成就卡片新增分享按钮生成成就海报"
```

---

## Task 5: AcademyDao 扩展 + 轨迹 DAO

**Files:**
- Create: `lib/features/academy/data/academy_trajectory_models.dart`
- Modify: `lib/features/academy/data/academy_dao.dart:5-68,71-247`
- Modify: `lib/features/academy/data/academy_repository.dart:5-31`
- Modify: `test/features/academy/academy_dao_test.dart:4,164-167`

**Interfaces:**
- Consumes: `academy_learning_trajectory` 表（Plan A v4 迁移创建，`Tables.academyLearningTrajectory` / `Tables.colCourseId` / `Tables.colCompletedAt` / `Tables.colSequence`）、`AcademyLearningTrajectoryTable.createSql`（Plan A 产出，在 `tables.dart`）
- Produces:
  - `AcademyTrajectoryRecord` 类（`courseId: String`, `completedAt: int`, `sequence: int`）
  - `AcademyDao.isCourseFullyCompleted(String courseId)` → `Future<bool>`
  - `AcademyDao.getMaxTrajectorySequence()` → `Future<int>`
  - `AcademyDao.upsertTrajectory(String courseId, {required int completedAt, required int sequence})` → `Future<void>`
  - `AcademyDao.getTrajectory(String courseId)` → `Future<AcademyTrajectoryRecord?>`
  - `AcademyDao.getAllTrajectory()` → `Future<List<AcademyTrajectoryRecord>>`
  - `AcademyRepository.isCourseFullyCompleted(String courseId)` → `Future<bool>`（接口）
  - `AcademyRepository.getAllTrajectory()` → `Future<List<AcademyTrajectoryRecord>>`（接口）

- [ ] **Step 1: 写失败测试 — 验证轨迹 DAO 方法**

Modify `test/features/academy/academy_dao_test.dart`:

在 import 段（line 4 后）追加:
```dart
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/academy/data/academy_trajectory_models.dart';
```

修改文件末尾的 `_onCreate` 函数（line 164-167），添加轨迹表创建:
```dart
Future<void> _onCreate(Database db, int version) async {
  await db.execute(AcademyTables.cpCreateSql);
  await db.execute(AcademyTables.asCreateSql);
  await db.execute(AcademyTables.kfCreateSql);
  await db.execute(AcademyLearningTrajectoryTable.createSql);
}
```

在 `main()` 函数内 `tearDown` 之后、`group('CourseProgress'` 之前，追加新测试组:
```dart
  group('Trajectory', () {
    test('getTrajectory returns null for non-existent course', () async {
      final traj = await dao.getTrajectory('non_existent');
      expect(traj, isNull);
    });

    test('getMaxTrajectorySequence returns 0 when empty', () async {
      expect(await dao.getMaxTrajectorySequence(), 0);
    });

    test('upsertTrajectory inserts record', () async {
      await dao.upsertTrajectory('c1', completedAt: 1000, sequence: 1);
      final traj = await dao.getTrajectory('c1');
      expect(traj, isNotNull);
      expect(traj!.courseId, 'c1');
      expect(traj.completedAt, 1000);
      expect(traj.sequence, 1);
    });

    test('getMaxTrajectorySequence returns max sequence', () async {
      await dao.upsertTrajectory('c1', completedAt: 1000, sequence: 1);
      await dao.upsertTrajectory('c2', completedAt: 2000, sequence: 3);
      await dao.upsertTrajectory('c3', completedAt: 3000, sequence: 2);
      expect(await dao.getMaxTrajectorySequence(), 3);
    });

    test('getAllTrajectory returns all sorted by sequence ASC', () async {
      await dao.upsertTrajectory('c3', completedAt: 3000, sequence: 3);
      await dao.upsertTrajectory('c1', completedAt: 1000, sequence: 1);
      await dao.upsertTrajectory('c2', completedAt: 2000, sequence: 2);
      final all = await dao.getAllTrajectory();
      expect(all.length, 3);
      expect(all[0].courseId, 'c1');
      expect(all[1].courseId, 'c2');
      expect(all[2].courseId, 'c3');
    });

    test('upsertTrajectory replaces existing (idempotent on courseId)', () async {
      await dao.upsertTrajectory('c1', completedAt: 1000, sequence: 1);
      await dao.upsertTrajectory('c1', completedAt: 2000, sequence: 5);
      final traj = await dao.getTrajectory('c1');
      expect(traj!.completedAt, 2000);
      expect(traj.sequence, 5);
    });
  });

  group('isCourseFullyCompleted', () {
    test('returns false when no progress record', () async {
      expect(await dao.isCourseFullyCompleted('c1'), isFalse);
    });

    test('returns false when status is not completed', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.upsertProgress('c1', CourseStatus.inProgress, 50,
          startedAt: now, lastViewedAt: now);
      expect(await dao.isCourseFullyCompleted('c1'), isFalse);
    });

    test('returns false when completed but no submission', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.upsertProgress('c1', CourseStatus.completed, 100,
          startedAt: now, completedAt: now, lastViewedAt: now);
      expect(await dao.isCourseFullyCompleted('c1'), isFalse);
    });

    test('returns false when completed but submission has no photo', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.upsertProgress('c1', CourseStatus.completed, 100,
          startedAt: now, completedAt: now, lastViewedAt: now);
      await dao.upsertSubmission(AssignmentSubmission(
        id: 's1',
        assignmentId: 'a1',
        courseId: 'c1',
        photoPath: null,
        status: AssignmentStatus.submitted,
        submittedAt: now,
      ));
      expect(await dao.isCourseFullyCompleted('c1'), isFalse);
    });

    test('returns true when completed and submission has photo', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.upsertProgress('c1', CourseStatus.completed, 100,
          startedAt: now, completedAt: now, lastViewedAt: now);
      await dao.upsertSubmission(AssignmentSubmission(
        id: 's1',
        assignmentId: 'a1',
        courseId: 'c1',
        photoPath: '/path/to/photo.jpg',
        status: AssignmentStatus.submitted,
        submittedAt: now,
      ));
      expect(await dao.isCourseFullyCompleted('c1'), isTrue);
    });

    test('returns true when completed and submission is reviewed with photo',
        () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.upsertProgress('c1', CourseStatus.completed, 100,
          startedAt: now, completedAt: now, lastViewedAt: now);
      await dao.upsertSubmission(AssignmentSubmission(
        id: 's1',
        assignmentId: 'a1',
        courseId: 'c1',
        photoPath: '/path/to/photo.jpg',
        status: AssignmentStatus.reviewed,
        submittedAt: now,
      ));
      expect(await dao.isCourseFullyCompleted('c1'), isTrue);
    });
  });
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/features/academy/academy_dao_test.dart -v`
Expected: FAIL with `AcademyTrajectoryRecord` 未定义 / `AcademyLearningTrajectoryTable` 未定义 / `dao.getTrajectory` / `dao.isCourseFullyCompleted` 方法不存在

- [ ] **Step 3a: 创建 academy_trajectory_models.dart**

Create `lib/features/academy/data/academy_trajectory_models.dart`:

```dart
/// 学院学习轨迹记录（持久化）
///
/// 记录用户完成的课程及其完成顺序。
/// 当 [AcademyRepository.markCompleted] 检测到课程完全完成
/// （status=completed 且作业有 photoPath）时自动 upsert。
class AcademyTrajectoryRecord {
  final String courseId;
  final int completedAt;
  final int sequence;

  const AcademyTrajectoryRecord({
    required this.courseId,
    required this.completedAt,
    required this.sequence,
  });
}
```

- [ ] **Step 3b: 修改 academy_dao.dart 添加轨迹表常量与 5 个方法**

Modify `lib/features/academy/data/academy_dao.dart`:

在 import 段（line 1-3）追加:
```dart
import '../../../core/db/tables.dart';
import 'academy_trajectory_models.dart';
```

在 `AcademyTables` 类内 `kfCreateSql` 之后（约 line 67，类的闭合 `}` 之前）追加轨迹表常量:
```dart
  // === academy_learning_trajectory ===
  // 注：表名与列名常量在 Tables 类中定义（Plan A v4 迁移添加）
  // 这里仅引用，不重复声明
```

在 `AcademyDao` 类内 `_assignmentStatusToString` 方法之后（文件末尾，类的闭合 `}` 之前）追加 5 个方法:
```dart
  // === 学习轨迹 ===

  /// 检查课程是否完全完成：
  /// 1. status = completed
  /// 2. 该课程有至少一条作业提交，且 status IN (submitted, reviewed) AND photoPath != null
  Future<bool> isCourseFullyCompleted(String courseId) async {
    final progress = await getProgress(courseId);
    if (progress?.status != CourseStatus.completed) return false;
    final submissions = await getCourseSubmissions(courseId);
    return submissions.any((s) =>
        s.status != AssignmentStatus.notSubmitted && s.photoPath != null);
  }

  /// 获取当前最大 sequence（无记录时返回 0）
  Future<int> getMaxTrajectorySequence() async {
    final rows = await _db.rawQuery(
      'SELECT MAX(${Tables.colSequence}) AS max_seq FROM ${Tables.academyLearningTrajectory}',
    );
    return (rows.first['max_seq'] as int?) ?? 0;
  }

  /// 插入或更新轨迹记录（按 courseId 主键 replace）
  Future<void> upsertTrajectory(String courseId,
      {required int completedAt, required int sequence}) async {
    await _db.insert(
      Tables.academyLearningTrajectory,
      {
        Tables.colCourseId: courseId,
        Tables.colCompletedAt: completedAt,
        Tables.colSequence: sequence,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取单条轨迹记录
  Future<AcademyTrajectoryRecord?> getTrajectory(String courseId) async {
    final rows = await _db.query(
      Tables.academyLearningTrajectory,
      where: '${Tables.colCourseId} = ?',
      whereArgs: [courseId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToTrajectory(rows.first);
  }

  /// 获取所有轨迹记录（按 sequence ASC 排序）
  Future<List<AcademyTrajectoryRecord>> getAllTrajectory() async {
    final rows = await _db.query(
      Tables.academyLearningTrajectory,
      orderBy: '${Tables.colSequence} ASC',
    );
    return rows.map(_rowToTrajectory).toList();
  }

  AcademyTrajectoryRecord _rowToTrajectory(Map<String, Object?> row) {
    return AcademyTrajectoryRecord(
      courseId: row[Tables.colCourseId] as String,
      completedAt: row[Tables.colCompletedAt] as int,
      sequence: row[Tables.colSequence] as int,
    );
  }
```

- [ ] **Step 3c: 修改 academy_repository.dart 接口新增方法声明**

Modify `lib/features/academy/data/academy_repository.dart`:

在 import 段（line 3 后）追加:
```dart
import 'academy_trajectory_models.dart';
```

在 `AcademyRepository` 抽象类内 `getFavoriteCardIds()` 之前（约 line 28）追加:
```dart
  // 学习轨迹
  Future<bool> isCourseFullyCompleted(String courseId);
  Future<List<AcademyTrajectoryRecord>> getAllTrajectory();
```

在 `LocalAcademyRepository` 类内 `getFavoriteCardIds()` 方法之前（约 line 224）追加简单委托:
```dart
  // === 学习轨迹 ===

  @override
  Future<bool> isCourseFullyCompleted(String courseId) =>
      _dao.isCourseFullyCompleted(courseId);

  @override
  Future<List<AcademyTrajectoryRecord>> getAllTrajectory() =>
      _dao.getAllTrajectory();
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/features/academy/academy_dao_test.dart -v`
Expected: PASS — 全部 11 个新测试用例通过

- [ ] **Step 5: 提交**

```bash
git add lib/features/academy/data/academy_trajectory_models.dart lib/features/academy/data/academy_dao.dart lib/features/academy/data/academy_repository.dart test/features/academy/academy_dao_test.dart
git commit -m "feat(academy): AcademyDao 新增轨迹表操作与 isCourseFullyCompleted 方法"
```

---

## Task 6: AcademyRepository.markCompleted 维护轨迹

**Files:**
- Modify: `lib/features/academy/data/academy_repository.dart:147-158,192-194`
- Modify: `lib/features/academy/providers/academy_providers.dart:93-97`
- Test: `test/features/academy/academy_repository_test.dart`

**Interfaces:**
- Consumes: `AcademyDao.isCourseFullyCompleted` / `getMaxTrajectorySequence` / `upsertTrajectory` / `getTrajectory`（Task 5 产出）
- Produces: `LocalAcademyRepository.markCompleted` 自动维护轨迹；`LocalAcademyRepository.submitAssignment` 在 `photoPath != null` 时触发 `markCompleted`；`AcademyActionNotifier.submitAssignment` 调用 repo 的 `submitAssignment`

- [ ] **Step 1: 写失败测试 — 验证 markCompleted 自动维护轨迹**

Create `test/features/academy/academy_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/academy/data/academy_dao.dart';
import 'package:lumira_app_flutter/features/academy/data/academy_models.dart';
import 'package:lumira_app_flutter/features/academy/data/academy_repository.dart';

void main() {
  late Database db;
  late AcademyDao dao;
  late LocalAcademyRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    dao = AcademyDao(db);
    repo = LocalAcademyRepository(
      dao: dao,
      now: () => DateTime.fromMillisecondsSinceEpoch(5000),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('markCompleted trajectory maintenance', () {
    test('does not create trajectory when not fully completed (no submission)',
        () async {
      await repo.markCompleted('c1');
      expect(await dao.getTrajectory('c1'), isNull);
    });

    test('creates trajectory when fully completed', () async {
      // 先提交带照片的作业
      await dao.upsertSubmission(AssignmentSubmission(
        id: 's1',
        assignmentId: 'a1',
        courseId: 'c1',
        photoPath: '/photo.jpg',
        status: AssignmentStatus.submitted,
        submittedAt: 1000,
      ));
      // 标记完成
      await repo.markCompleted('c1');

      final traj = await dao.getTrajectory('c1');
      expect(traj, isNotNull);
      expect(traj!.courseId, 'c1');
      expect(traj.sequence, 1);
      expect(traj.completedAt, 5000);
    });

    test('does not duplicate trajectory on repeated markCompleted', () async {
      await dao.upsertSubmission(AssignmentSubmission(
        id: 's1',
        assignmentId: 'a1',
        courseId: 'c1',
        photoPath: '/photo.jpg',
        status: AssignmentStatus.submitted,
        submittedAt: 1000,
      ));
      await repo.markCompleted('c1');
      await repo.markCompleted('c1');

      final all = await dao.getAllTrajectory();
      expect(all.length, 1);
      expect(all.first.sequence, 1);
      // completedAt 应保持首次值
      expect(all.first.completedAt, 5000);
    });

    test('assigns incrementing sequence across courses', () async {
      // 课程 c1
      await dao.upsertSubmission(AssignmentSubmission(
        id: 's1',
        assignmentId: 'a1',
        courseId: 'c1',
        photoPath: '/photo1.jpg',
        status: AssignmentStatus.submitted,
        submittedAt: 1000,
      ));
      await repo.markCompleted('c1');

      // 课程 c2
      await dao.upsertSubmission(AssignmentSubmission(
        id: 's2',
        assignmentId: 'a2',
        courseId: 'c2',
        photoPath: '/photo2.jpg',
        status: AssignmentStatus.submitted,
        submittedAt: 2000,
      ));
      await repo.markCompleted('c2');

      final all = await dao.getAllTrajectory();
      expect(all.length, 2);
      expect(all[0].courseId, 'c1');
      expect(all[0].sequence, 1);
      expect(all[1].courseId, 'c2');
      expect(all[1].sequence, 2);
    });
  });

  group('submitAssignment triggers markCompleted', () {
    test('submitAssignment with photoPath creates trajectory', () async {
      await repo.submitAssignment(AssignmentSubmission(
        id: 's1',
        assignmentId: 'a1',
        courseId: 'c1',
        photoPath: '/photo.jpg',
        status: AssignmentStatus.reviewed,
        submittedAt: 1000,
      ));

      final traj = await dao.getTrajectory('c1');
      expect(traj, isNotNull);
      expect(traj!.sequence, 1);

      // 验证课程进度也被标记为 completed
      final progress = await dao.getProgress('c1');
      expect(progress?.status, CourseStatus.completed);
    });

    test('submitAssignment without photoPath does not create trajectory',
        () async {
      await repo.submitAssignment(AssignmentSubmission(
        id: 's1',
        assignmentId: 'a1',
        courseId: 'c1',
        photoPath: null,
        status: AssignmentStatus.submitted,
        submittedAt: 1000,
      ));

      expect(await dao.getTrajectory('c1'), isNull);
    });
  });
}

Future<void> _onCreate(Database db, int version) async {
  await db.execute(AcademyTables.cpCreateSql);
  await db.execute(AcademyTables.asCreateSql);
  await db.execute(AcademyTables.kfCreateSql);
  await db.execute(AcademyLearningTrajectoryTable.createSql);
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/features/academy/academy_repository_test.dart -v`
Expected: FAIL — `dao.getTrajectory('c1')` 返回 null（markCompleted 尚未维护轨迹）

- [ ] **Step 3: 修改 academy_repository.dart 的 markCompleted 与 submitAssignment**

Modify `lib/features/academy/data/academy_repository.dart`:

替换 `markCompleted` 方法（line 147-158）:
```dart
  @override
  Future<void> markCompleted(String courseId) async {
    final now = _now().millisecondsSinceEpoch;
    final existing = await _dao.getProgress(courseId);
    final completedAt = existing?.completedAt ?? now;
    await _dao.upsertProgress(
      courseId,
      CourseStatus.completed,
      100,
      startedAt: existing?.startedAt ?? now,
      completedAt: completedAt,
      lastViewedAt: now,
    );

    // 维护学习轨迹：仅在完全完成且尚未有轨迹记录时插入
    if (await _dao.isCourseFullyCompleted(courseId)) {
      final existingTraj = await _dao.getTrajectory(courseId);
      if (existingTraj == null) {
        final maxSeq = await _dao.getMaxTrajectorySequence();
        await _dao.upsertTrajectory(
          courseId,
          completedAt: completedAt,
          sequence: maxSeq + 1,
        );
      }
    }
  }
```

替换 `submitAssignment` 方法（line 192-194）:
```dart
  @override
  Future<void> submitAssignment(AssignmentSubmission submission) async {
    await _dao.upsertSubmission(submission);
    // 作业含照片时触发 markCompleted 重新校验是否完全完成
    if (submission.photoPath != null) {
      await markCompleted(submission.courseId);
    }
  }
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/features/academy/academy_repository_test.dart -v`
Expected: PASS — 全部 6 个测试用例通过

- [ ] **Step 5: 提交**

```bash
git add lib/features/academy/data/academy_repository.dart test/features/academy/academy_repository_test.dart
git commit -m "feat(academy): markCompleted 自动维护学习轨迹，作业提交触发重新校验"
```

---

## Task 7: 学院课程列表排序 + 已学完徽章

**Files:**
- Modify: `lib/features/academy/providers/academy_providers.dart` — 新增 `courseFullyCompletedProvider` + `sortedCoursesProvider`
- Modify: `lib/features/academy/pages/academy_page.dart:172-210` — `_CourseGrid` 改用 `sortedCoursesProvider` + `courseFullyCompletedProvider`
- Modify: `lib/features/academy/widgets/academy_course_card.dart` — 新增 `isFullyCompleted` 参数
- Test: `test/features/academy/academy_page_sort_test.dart`

**Interfaces:**
- Consumes: `AcademyRepository.isCourseFullyCompleted`（Task 5）、`AcademyRepository.getProgress`（已存在）、`coursesProvider`（已存在）、`courseProgressProvider`（已存在）
- Produces:
  - `courseFullyCompletedProvider`（`FutureProvider.family<bool, String>`）
  - `sortedCoursesProvider`（`FutureProvider.family<List<AcademyCourse>, AcademyLevel?>`）
  - `AcademyCourseCard` 新增 `isFullyCompleted` 参数（bool，默认 false）

- [ ] **Step 1: 写失败测试 — 验证课程排序与徽章显示**

Create `test/features/academy/academy_page_sort_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/academy/data/academy_models.dart';
import 'package:lumira_app_flutter/features/academy/widgets/academy_course_card.dart';

void main() {
  testWidgets(
      'AcademyCourseCard shows 已学完 badge when isFullyCompleted is true',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AcademyCourseCard(
              course: const AcademyCourse(
                id: 'c1',
                lessonNumber: 1,
                title: '测试课程',
                level: AcademyLevel.beginner,
                topic: AcademyTopic.portrait,
                coverImage: '',
                meta: '5分钟',
              ),
              status: CourseStatus.completed,
              isFullyCompleted: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('已学完'), findsOneWidget);
  });

  testWidgets(
      'AcademyCourseCard does not show 已学完 when isFullyCompleted is false',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AcademyCourseCard(
              course: const AcademyCourse(
                id: 'c1',
                lessonNumber: 1,
                title: '测试课程',
                level: AcademyLevel.beginner,
                topic: AcademyTopic.portrait,
                coverImage: '',
                meta: '5分钟',
              ),
              status: CourseStatus.inProgress,
              isFullyCompleted: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('已学完'), findsNothing);
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/features/academy/academy_page_sort_test.dart -v`
Expected: FAIL with `AcademyCourseCard` 不接受 `isFullyCompleted` 参数的编译错误

- [ ] **Step 3a: 修改 academy_providers.dart 新增两个 Provider**

Modify `lib/features/academy/providers/academy_providers.dart`:

在 `courseProgressProvider` 之后（约 line 42）追加:
```dart
/// 课程是否完全完成（status=completed 且作业有 photoPath）
final courseFullyCompletedProvider =
    FutureProvider.family<bool, String>((ref, courseId) async {
  final repo = await ref.watch(academyRepositoryProvider.future);
  return repo.isCourseFullyCompleted(courseId);
});

/// 排序后的课程列表
/// 规则：
/// 1. 先按 level 升序（beginner → intermediate → advanced）
/// 2. 同 level 内：未完全完成的在前（按 lastViewedAt DESC），
///    已完全完成的沉底（按 completedAt ASC）
final sortedCoursesProvider = FutureProvider.family<List<AcademyCourse>, AcademyLevel?>(
    (ref, level) async {
  final repo = await ref.watch(academyRepositoryProvider.future);
  final allCourses = AcademyMockData.courses
      .where((c) => level == null || c.level == level)
      .toList();

  // 获取每门课的进度和完全完成状态
  final courseData = <_CourseSortData>[];
  for (final course in allCourses) {
    final progress = await repo.getProgress(course.id);
    final isFullyCompleted = await repo.isCourseFullyCompleted(course.id);
    courseData.add(_CourseSortData(
      course: course,
      progress: progress,
      isFullyCompleted: isFullyCompleted,
    ));
  }

  // 排序
  courseData.sort((a, b) {
    // 1. level 升序
    final levelCompare = a.course.level.index.compareTo(b.course.level.index);
    if (levelCompare != 0) return levelCompare;

    // 2. 同 level 内：未完成在前，已完成沉底
    if (a.isFullyCompleted != b.isFullyCompleted) {
      return a.isFullyCompleted ? 1 : -1;
    }

    if (a.isFullyCompleted) {
      // 都已完成：按 completedAt ASC
      final aCompletedAt = a.progress?.completedAt ?? 0;
      final bCompletedAt = b.progress?.completedAt ?? 0;
      return aCompletedAt.compareTo(bCompletedAt);
    } else {
      // 都未完成：按 lastViewedAt DESC
      final aLastViewed = a.progress?.lastViewedAt ?? 0;
      final bLastViewed = b.progress?.lastViewedAt ?? 0;
      return bLastViewed.compareTo(aLastViewed);
    }
  });

  return courseData.map((d) => d.course).toList();
});

class _CourseSortData {
  final AcademyCourse course;
  final CourseProgress? progress;
  final bool isFullyCompleted;

  const _CourseSortData({
    required this.course,
    required this.progress,
    required this.isFullyCompleted,
  });
}
```

- [ ] **Step 3b: 修改 academy_course_card.dart 新增 isFullyCompleted 参数与绿色徽章**

Modify `lib/features/academy/widgets/academy_course_card.dart`:

替换 `AcademyCourseCard` 类全文:
```dart
/// 课程卡片（用于课程网格）
class AcademyCourseCard extends ConsumerWidget {
  const AcademyCourseCard({
    super.key,
    required this.course,
    required this.status,
    required this.onTap,
    this.isFullyCompleted = false,
  });

  final AcademyCourse course;
  final CourseStatus status;
  final VoidCallback onTap;
  final bool isFullyCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    return GestureDetector(
      onTap: onTap,
      child: NeuCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 封面图
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Image.network(
                      course.coverImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: tokens.surfaceAlt,
                        child: Icon(Icons.image_outlined, color: tokens.textTertiary),
                      ),
                    ),
                  ),
                ),
                // 已学完徽章（完全完成时显示绿色徽章）
                if (isFullyCompleted)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tokens.success,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.check_circle,
                            size: 12,
                            color: Colors.white,
                          ),
                          SizedBox(width: 3),
                          Text(
                            '已学完',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                // 学习中徽章（未完全完成但已开始学习）
                else if (status != CourseStatus.notStarted)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tokens.brand,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_circle_outline,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '学习中',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // 课号角标
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      '第${course.lessonNumber}课',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            // 标题与 meta
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    style: TextStyle(
                      fontFamily: 'Noto Serif SC',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    course.meta,
                    style: TextStyle(fontSize: 11, color: tokens.textTertiary),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: course.tags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tokens.brandSubtle,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(fontSize: 10, color: tokens.brandText),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3c: 修改 academy_page.dart 的 _CourseGrid 使用 sortedCoursesProvider**

Modify `lib/features/academy/pages/academy_page.dart`:

在 import 段追加（如果尚未存在）:
```dart
import '../data/academy_models.dart';
```

替换 `_CourseGrid` 类（line 172-210）:
```dart
/// 课程网格（2 列，排序后）
class _CourseGrid extends ConsumerWidget {
  const _CourseGrid(
      {required this.level, required this.actionVersion, required this.onTap});

  final AcademyLevel? level;
  final int actionVersion;
  final void Function(String courseId) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // watch actionVersion to trigger rebuild after status changes
    ref.watch(academyActionsProvider);
    final coursesAsync = ref.watch(sortedCoursesProvider(level));

    return coursesAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox(height: 200),
      data: (courses) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: courses.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.52,
        ),
        itemBuilder: (context, index) {
          final course = courses[index];
          final progressAsync = ref.watch(courseProgressProvider(course.id));
          final fullyCompletedAsync =
              ref.watch(courseFullyCompletedProvider(course.id));
          final status = progressAsync.maybeWhen(
            data: (p) => p?.status ?? CourseStatus.notStarted,
            orElse: () => CourseStatus.notStarted,
          );
          final isFullyCompleted = fullyCompletedAsync.maybeWhen(
            data: (v) => v,
            orElse: () => false,
          );
          return AcademyCourseCard(
            course: course,
            status: status,
            isFullyCompleted: isFullyCompleted,
            onTap: () => onTap(course.id),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/features/academy/academy_page_sort_test.dart -v`
Expected: PASS — 两个测试用例通过

- [ ] **Step 5: 提交**

```bash
git add lib/features/academy/providers/academy_providers.dart lib/features/academy/widgets/academy_course_card.dart lib/features/academy/pages/academy_page.dart test/features/academy/academy_page_sort_test.dart
git commit -m "feat(academy): 课程列表按规则排序，已完成课程显示绿色已学完徽章"
```

---

## Task 8: 学习轨迹页

**Files:**
- Create: `lib/features/academy/pages/academy_trajectory_page.dart`
- Modify: `lib/core/router/route_names.dart:47` — 新增 `academyTrajectory` 常量
- Modify: `lib/app/router.dart:326` — 注册路由
- Modify: `lib/features/academy/widgets/academy_overview_card.dart` — 新增「我的学习轨迹」入口
- Modify: `lib/features/academy/providers/academy_providers.dart` — 新增 `academyTrajectoryProvider`
- Test: `test/features/academy/academy_trajectory_page_test.dart`

**Interfaces:**
- Consumes: `AcademyRepository.getAllTrajectory`（Task 5）、`AcademyMockData.getCourse`（已存在）、`ThemeTokens`、`route_names.dart`
- Produces:
  - `RouteNames.academyTrajectory = '/academy/trajectory'`
  - `academyTrajectoryProvider`（`FutureProvider<List<AcademyTrajectoryRecord>>`）
  - `AcademyTrajectoryPage` widget

- [ ] **Step 1: 写失败测试 — 验证轨迹页时间线渲染**

Create `test/features/academy/academy_trajectory_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/academy/data/academy_trajectory_models.dart';
import 'package:lumira_app_flutter/features/academy/pages/academy_trajectory_page.dart';
import 'package:lumira_app_flutter/features/academy/providers/academy_providers.dart';

void main() {
  testWidgets('AcademyTrajectoryPage shows empty state when no trajectory',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          academyTrajectoryProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: AcademyTrajectoryPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('开始你的第一节课程吧'), findsOneWidget);
  });

  testWidgets('AcademyTrajectoryPage shows timeline with trajectory records',
      (tester) async {
    final trajectories = <AcademyTrajectoryRecord>[
      const AcademyTrajectoryRecord(
        courseId: 'academy_01',
        completedAt: 1700000000000,
        sequence: 1,
      ),
      const AcademyTrajectoryRecord(
        courseId: 'academy_02',
        completedAt: 1700100000000,
        sequence: 2,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          academyTrajectoryProvider.overrideWith((ref) async => trajectories),
        ],
        child: const MaterialApp(home: AcademyTrajectoryPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 验证顶部统计卡显示
    expect(find.text('已完成 2 / 12 课'), findsOneWidget);
    // 验证总学习时长显示（按 sections.paragraphs.length * 30秒 估算）
    expect(find.textContaining('总学习时长约'), findsOneWidget);
    // 验证时间线节点标签
    expect(find.text('第 1 个完成'), findsOneWidget);
    expect(find.text('第 2 个完成'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/features/academy/academy_trajectory_page_test.dart -v`
Expected: FAIL with `AcademyTrajectoryPage` 未定义 / `academyTrajectoryProvider` 未定义的编译错误

- [ ] **Step 3a: 修改 route_names.dart 新增路由常量**

Modify `lib/core/router/route_names.dart`:

在 `shootkitEditor = '/shootkit/editor'` 之后（约 line 47）追加:
```dart
  static const String academyTrajectory = '/academy/trajectory';
```

- [ ] **Step 3b: 修改 academy_providers.dart 新增 trajectory provider**

Modify `lib/features/academy/providers/academy_providers.dart`:

在 `courseFullyCompletedProvider` 之后（Task 7 新增的位置之后）追加:
```dart
/// 学习轨迹列表（按 sequence ASC）
final academyTrajectoryProvider =
    FutureProvider<List<AcademyTrajectoryRecord>>((ref) async {
  final repo = await ref.watch(academyRepositoryProvider.future);
  return repo.getAllTrajectory();
});
```

在 import 段追加:
```dart
import '../data/academy_trajectory_models.dart';
```

- [ ] **Step 3c: 修改 router.dart 注册路由**

Modify `lib/app/router.dart`:

在 import 段（约 line 25 后）追加:
```dart
import '../features/academy/pages/academy_trajectory_page.dart';
```

在 `profileAcademyKnowledge` 路由之后（约 line 285 后）追加:
```dart
      GoRoute(
        path: RouteNames.academyTrajectory,
        name: 'academyTrajectory',
        builder: (context, state) => const AcademyTrajectoryPage(),
      ),
```

- [ ] **Step 3d: 修改 academy_overview_card.dart 新增学习轨迹入口**

Modify `lib/features/academy/widgets/academy_overview_card.dart`:

在 `_AcademyOverviewCard` build 方法内 `nextCourseTitle` 区块之后（约 line 105，`],` 闭合前）追加:
```dart
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    GoRouter.of(context).push(RouteNames.academyTrajectory);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: tokens.brandSubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timeline, size: 16, color: tokens.brandText),
                        const SizedBox(width: 6),
                        Text(
                          '我的学习轨迹',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: tokens.brandText,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 16, color: tokens.brandText),
                      ],
                    ),
                  ),
                ),
```

- [ ] **Step 3e: 创建 academy_trajectory_page.dart**

Create `lib/features/academy/pages/academy_trajectory_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/academy_mock_data.dart';
import '../data/academy_models.dart';
import '../data/academy_trajectory_models.dart';
import '../providers/academy_providers.dart';

/// 学习轨迹页
///
/// 时间线竖向布局，展示用户已完全完成的课程列表。
/// 每节点：圆形序号 + 课程封面 + 课程名 + 完成时间 + "第 N 个完成"标签
/// 节点间用虚线连接。
class AcademyTrajectoryPage extends ConsumerWidget {
  const AcademyTrajectoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final trajectoryAsync = ref.watch(academyTrajectoryProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '学习轨迹',
        transparent: true,
        leading: _BackButton(tokens: tokens),
      ),
      body: SafeArea(
        child: trajectoryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (_, __) => Center(
            child: Text('加载失败', style: TextStyle(color: tokens.textTertiary)),
          ),
          data: (trajectory) {
            if (trajectory.isEmpty) {
              return _EmptyState(tokens: tokens);
            }
            // 估算总学习时长：每段 paragraphs 折算 30 秒
            int totalDurationSeconds = 0;
            for (final record in trajectory) {
              final detail = AcademyMockData.getCourseDetail(record.courseId);
              if (detail != null) {
                final paragraphCount = detail.sections.fold<int>(
                    0, (sum, s) => sum + s.paragraphs.length);
                totalDurationSeconds += paragraphCount * 30;
              }
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeUp(
                    child: _StatsCard(
                      tokens: tokens,
                      completedCount: trajectory.length,
                      totalCount: AcademyMockData.courses.length,
                      totalDurationSeconds: totalDurationSeconds,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeUp(
                    delay: const Duration(milliseconds: 80),
                    child: _Timeline(
                      tokens: tokens,
                      trajectory: trajectory,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          GoRouter.of(context).go(RouteNames.profileAcademy);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.arrow_back_ios_new, size: 20, color: tokens.textPrimary),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.tokens,
    required this.completedCount,
    required this.totalCount,
    required this.totalDurationSeconds,
  });

  final ThemeTokens tokens;
  final int completedCount;
  final int totalCount;
  final int totalDurationSeconds;

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0 分钟';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes 分钟';
    final hours = minutes ~/ 60;
    final remMinutes = minutes % 60;
    return remMinutes > 0 ? '$hours 小时 $remMinutes 分钟' : '$hours 小时';
  }

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, size: 22, color: tokens.brand),
              const SizedBox(width: 8),
              Text(
                '学习轨迹',
                style: TextStyle(
                  fontFamily: 'Noto Serif SC',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '已完成 $completedCount / $totalCount 课',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: tokens.brand.withOpacity(0.18)),
                  FractionallySizedBox(
                    widthFactor: totalCount > 0
                        ? completedCount / totalCount
                        : 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [tokens.brand, tokens.brandLight],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: tokens.textTertiary),
              const SizedBox(width: 6),
              Text(
                '总学习时长约 ${_formatDuration(totalDurationSeconds)}',
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.tokens, required this.trajectory});

  final ThemeTokens tokens;
  final List<AcademyTrajectoryRecord> trajectory;

  String _formatDate(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < trajectory.length; i++)
          _TimelineNode(
            tokens: tokens,
            record: trajectory[i],
            isLast: i == trajectory.length - 1,
            formatDate: _formatDate,
          ),
      ],
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.tokens,
    required this.record,
    required this.isLast,
    required this.formatDate,
  });

  final ThemeTokens tokens;
  final AcademyTrajectoryRecord record;
  final bool isLast;
  final String Function(int) formatDate;

  @override
  Widget build(BuildContext context) {
    final course = AcademyMockData.getCourse(record.courseId);
    final courseTitle = course?.title ?? '未知课程';
    final coverImage = course?.coverImage ?? '';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧：圆形序号 + 虚线
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [tokens.brand, tokens.brandDeep],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${record.sequence}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final dashHeight = constraints.maxHeight;
                          final dashCount = (dashHeight / 6).floor();
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(
                              dashCount,
                              (_) => Container(
                                width: 2,
                                height: 3,
                                color: tokens.divider,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 右侧：课程卡片
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: NeuCard(
                child: Row(
                  children: [
                    // 课程封面
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: coverImage.isNotEmpty
                            ? Image.network(
                                coverImage,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: tokens.surfaceAlt,
                                  child: Icon(Icons.image_outlined,
                                      size: 20, color: tokens.textTertiary),
                                ),
                              )
                            : Container(
                                color: tokens.surfaceAlt,
                                child: Icon(Icons.school,
                                    size: 20, color: tokens.brand),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 课程信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            courseTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatDate(record.completedAt),
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Courier New',
                              color: tokens.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: tokens.successSubtle,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '第 ${record.sequence} 个完成',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: tokens.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 64,
              color: tokens.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              '开始你的第一节课程吧',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '完成课程并提交作业后，\n你的学习轨迹将出现在这里',
              style: TextStyle(
                fontSize: 13,
                color: tokens.textTertiary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  GoRouter.of(context).go(RouteNames.profileAcademy);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.brand,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: const Text('去学习'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/features/academy/academy_trajectory_page_test.dart -v`
Expected: PASS — 空状态显示「开始你的第一节课程吧」，有数据时显示统计卡与时间线节点

- [ ] **Step 5: 提交**

```bash
git add lib/features/academy/pages/academy_trajectory_page.dart lib/core/router/route_names.dart lib/app/router.dart lib/features/academy/widgets/academy_overview_card.dart lib/features/academy/providers/academy_providers.dart test/features/academy/academy_trajectory_page_test.dart
git commit -m "feat(academy): 新增学习轨迹时间线页与路由入口"
```
