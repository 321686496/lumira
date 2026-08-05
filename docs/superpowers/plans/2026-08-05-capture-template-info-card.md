# 拍摄页套用模板后顶部可折叠模板信息卡 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 套用模板后，拍摄页上方区域显示可折叠的模板信息卡（简介 + 拍摄注意点），默认展开，全屏隐藏，切换模板重置为展开。

**Architecture:** 新增独立组件 `TemplateInfoCard`（ConsumerStatefulWidget，本地 `_expanded` 状态，视觉复用 `ChallengeOverlayBar` 的浮层风格）。`CapturePage` 将顶部 3 个独立 Positioned 浮层合并为一个 Column，卡片插在最上方，下方浮层随卡片高度自然流动。

**Tech Stack:** Flutter, Riverpod (ConsumerStatefulWidget / StateProvider), flutter_test

## Global Constraints

- Flutter 3.7.12 / Dart 2.19.6（**不支持 Dart 3 records 语法**）
- 视觉与 `challenge_overlay_bar.dart` 保持一致（深色半透明浮层 `Color(0xF0171512)` + 品牌色描边 + AnimatedSize）
- 颜色使用 `themeTokensProvider` 的 `tokens.brand` 或既有浮层色值（白色 78%/85% 透明度等），**不新增自定义色**
- 使用 Riverpod 的 `ref.watch` / `ref.read` 模式
- 数据源：`CaptureState.originalTemplateProvider`（已支持系统 + 自定义模板，`TemplateMapper` 已映射 description/tips，无需改动）
- 静态检查：`cd lumira_app_flutter && flutter analyze`
- 测试命令：`cd lumira_app_flutter && flutter test`

---

### Task 1: 新增 TemplateInfoCard 组件（TDD）

**Files:**
- Create: `lumira_app_flutter/lib/features/capture/widgets/template_info_card.dart`
- Test: `lumira_app_flutter/test/features/capture/template_info_card_test.dart`

**Interfaces:**
- Consumes: `PhotoTemplate`（`lumira_app_flutter/lib/features/capture/domain/photo_template.dart`），`themeTokensProvider`（`lumira_app_flutter/lib/core/theme/theme_controller.dart`）
- Produces: `TemplateInfoCard`（`ConsumerStatefulWidget`，构造参数 `required PhotoTemplate template`）
- 测试用模板常量：`softPortraitTemplate`（id `soft_portrait`，名"柔光人像"，简介含"柔光环境下的半身人像"，tips 含"避免顶光直射造成眼窝阴影"），`hkNoirPortraitTemplate`（id `hk_noir_portrait`，名"港风夜景人像"，简介含"王家卫式港风夜景"）

- [ ] **Step 1: Write the failing test**

Create `lumira_app_flutter/test/features/capture/template_info_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/features/capture/data/templates/hk_noir_portrait.dart';
import 'package:lumira_app_flutter/features/capture/data/templates/soft_portrait.dart';
import 'package:lumira_app_flutter/features/capture/widgets/template_info_card.dart';

void main() {
  Widget wrap(Widget child) => ProviderScope(
        overrides: [
          themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        ],
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      );

  testWidgets('默认展开：显示模板名、简介与注意点', (tester) async {
    await tester.pumpWidget(wrap(TemplateInfoCard(template: softPortraitTemplate)));

    // 模板名
    expect(find.text('柔光人像'), findsOneWidget);
    // 简介（meta.description）
    expect(find.textContaining('柔光环境下的半身人像'), findsOneWidget);
    // 注意点（sceneGuide.tips）
    expect(find.textContaining('避免顶光直射造成眼窝阴影'), findsOneWidget);
  });

  testWidgets('点击折叠后隐藏内容，再点展开恢复', (tester) async {
    await tester.pumpWidget(wrap(TemplateInfoCard(template: softPortraitTemplate)));

    // 点击标题行折叠
    await tester.tap(find.text('柔光人像'));
    await tester.pumpAndSettle();
    expect(find.textContaining('柔光环境下的半身人像'), findsNothing);

    // 再点展开
    await tester.tap(find.text('柔光人像'));
    await tester.pumpAndSettle();
    expect(find.textContaining('柔光环境下的半身人像'), findsOneWidget);
  });

  testWidgets('切换模板（不同 id）后重置为展开', (tester) async {
    await tester.pumpWidget(wrap(TemplateInfoCard(template: softPortraitTemplate)));

    // 先折叠
    await tester.tap(find.text('柔光人像'));
    await tester.pumpAndSettle();
    expect(find.textContaining('柔光环境下的半身人像'), findsNothing);

    // 切换到另一模板
    await tester.pumpWidget(
        wrap(TemplateInfoCard(template: hkNoirPortraitTemplate)));
    await tester.pumpAndSettle();

    expect(find.text('港风夜景人像'), findsOneWidget);
    expect(find.textContaining('王家卫式港风夜景'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd lumira_app_flutter && flutter test test/features/capture/template_info_card_test.dart`
Expected: FAIL with `Error: Could not resolve imported library ... template_info_card.dart`（文件不存在）

- [ ] **Step 3: Implement TemplateInfoCard**

Create `lumira_app_flutter/lib/features/capture/widgets/template_info_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../domain/photo_template.dart';

/// 拍摄页套用模板后的可折叠模板信息卡。
///
/// - 折叠态：图标 + 模板名 + 展开箭头
/// - 展开态：简介（meta.description）+ 拍摄注意点列表（sceneGuide.tips）
/// - 套用模板默认展开；切换模板（id 变化）时重置为展开
/// - 视觉与 ChallengeOverlayBar 保持一致（深色半透明浮层 + 品牌色描边）
class TemplateInfoCard extends ConsumerStatefulWidget {
  const TemplateInfoCard({super.key, required this.template});

  final PhotoTemplate template;

  @override
  ConsumerState<TemplateInfoCard> createState() => _TemplateInfoCardState();
}

class _TemplateInfoCardState extends ConsumerState<TemplateInfoCard> {
  /// 默认展开，让用户第一时间看到拍摄要点
  bool _expanded = true;

  @override
  void didUpdateWidget(covariant TemplateInfoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切换模板（id 变化）时重置为展开
    if (oldWidget.template.meta.id != widget.template.meta.id) {
      setState(() => _expanded = true);
    }
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final template = widget.template;
    final tips = template.sceneGuide.tips;
    // 无简介且无注意点时仅渲染标题条
    final hasContent =
        template.meta.description.isNotEmpty || tips.isNotEmpty;

    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: Colors.transparent,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: _expanded ? 12 : 10,
              ),
              decoration: BoxDecoration(
                color: const Color(0xF0171512).withOpacity(0.92),
                borderRadius: BorderRadius.circular(_expanded ? 14 : 24),
                border: Border.all(
                  color: tokens.brand.withOpacity(0.35),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.30),
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题行：图标 + 模板名 + 箭头（折叠/展开共用）
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: tokens.brand),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          template.meta.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  // 展开态：简介 + 注意点
                  if (_expanded && hasContent) ...[
                    const SizedBox(height: 10),
                    Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.12),
                    ),
                    if (template.meta.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        template.meta.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.78),
                          height: 1.5,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (tips.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ...tips.map(
                        (tip) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Icon(
                                  Icons.check_circle_outline,
                                  size: 13,
                                  color: tokens.brand,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  tip,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.85),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd lumira_app_flutter && flutter test test/features/capture/template_info_card_test.dart`
Expected: PASS（3 个测试全绿）

- [ ] **Step 5: Commit**

```bash
git add lumira_app_flutter/lib/features/capture/widgets/template_info_card.dart lumira_app_flutter/test/features/capture/template_info_card_test.dart
git commit -m "feat(capture): add collapsible TemplateInfoCard showing template description and tips"
```

---

### Task 2: 拍摄页顶部布局整合

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/pages/capture_page.dart`（顶部浮层 + import）
- Test: 无新测试（复用既有 `test/features/capture/capture_page_test.dart` 验证无回归）

**Interfaces:**
- Consumes: `TemplateInfoCard`（Task 1），`CaptureState.originalTemplateProvider`（`Provider<PhotoTemplate?>`，已存在）
- Produces: 修改后的 `CapturePage.build` 顶部浮层组

- [ ] **Step 1: 添加 TemplateInfoCard import**

在 `lumira_app_flutter/lib/features/capture/pages/capture_page.dart` 的 import 区（现有 `import '../widgets/template_strip.dart';` 之后）添加：

```dart
import '../widgets/template_info_card.dart';
```

- [ ] **Step 2: 在 build 中 watch 当前模板**

在 `build` 方法开头（`final isFullscreen = ref.watch(...)` 附近，即 `_CapturePageState.build` 内、`final facing = ...` 之前）添加：

```dart
    // 当前套用的模板（null = 自由模式）。用于顶部模板信息卡显示。
    final template = ref.watch(CaptureState.originalTemplateProvider);
```

- [ ] **Step 3: 将顶部 3 个独立 Positioned 替换为一个 Column**

删除现有这 3 段代码（约 676-704 行）：

```dart
          // 2.5 比例切换器（导航栏下方居中）
          Positioned(
            top: MediaQuery.of(context).padding.top + 64,
            left: 0,
            right: 0,
            child: const Center(child: AspectRatioSelector()),
          ),

          // 2.6 挑战悬浮条（仅挑战拍摄模式显示，位于比例切换器下方）
          if (isChallengeMode && !isFullscreen)
            Positioned(
              top: MediaQuery.of(context).padding.top + 104,
              left: 0,
              right: 0,
              child: ChallengeOverlayBar(
                challengeId: widget.challengeId!,
                captureInProgress: captureInProgress,
              ),
            ),

          // 3. 顶部参数 pill 栏（全屏模式下隐藏；挑战模式下下移避开悬浮条）
          if (!isFullscreen)
            Positioned(
              top: MediaQuery.of(context).padding.top +
                  (isChallengeMode ? 168 : 112),
              left: 12,
              right: 12,
              child: const ParamPillBar(),
            ),
```

替换为（保持原位置插入，即原 2.5 的位置）：

```dart
          // 2.5 顶部浮层组：模板信息卡（可折叠）→ 比例切换器 → 挑战悬浮条 → 参数 pill 栏
          //    模板信息卡高度动态变化，用 Column 让下方元素随卡片自然流动
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 套用模板时显示可折叠模板信息卡（全屏隐藏，与参数 pill 栏一致）
                if (template != null && !isFullscreen)
                  TemplateInfoCard(template: template),
                const SizedBox(height: 8),
                // 比例切换器（导航栏下方居中，全屏也显示，行为不变）
                const Center(child: AspectRatioSelector()),
                // 挑战悬浮条（仅挑战拍摄模式显示）
                if (isChallengeMode && !isFullscreen)
                  ChallengeOverlayBar(
                    challengeId: widget.challengeId!,
                    captureInProgress: captureInProgress,
                  ),
                // 参数 pill 栏（全屏模式隐藏）
                if (!isFullscreen)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: ParamPillBar(),
                  ),
              ],
            ),
          ),
```

- [ ] **Step 4: 静态检查**

Run: `cd lumira_app_flutter && flutter analyze`
Expected: 无新增 error/warning（仅项目既有的预存 info 级提示，如有）

- [ ] **Step 5: 运行既有拍摄页测试验证无回归**

Run: `cd lumira_app_flutter && flutter test test/features/capture/`
Expected: All PASS

- [ ] **Step 6: 手动验证（可选）**

`flutter run` 后验证：套用模板 → 卡片出现且展开；点击折叠/展开，下方浮层平滑跟随；全屏隐藏、退出恢复；切换模板重置展开；自由模式无卡片。

- [ ] **Step 7: Commit**

```bash
git add lumira_app_flutter/lib/features/capture/pages/capture_page.dart
git commit -m "feat(capture): integrate collapsible template info card into capture page top area"
```

---

## Self-Review Notes

### Spec coverage check

| Spec requirement | Task |
|---|---|
| 新增 TemplateInfoCard 组件（折叠/展开、默认展开） | Task 1 |
| 简介 + 注意点展示（description + tips） | Task 1（build 中 hasContent 分支） |
| 切换模板重置为展开 | Task 1（didUpdateWidget 按 id 比较） |
| 无内容兜底仅标题条 | Task 1（hasContent 为空时展开区为空） |
| 顶部 Column 整合 + 卡片插最上方 | Task 2（Step 3） |
| 全屏隐藏 | Task 2（`template != null && !isFullscreen`） |
| 自由模式无卡片、布局与原一致 | Task 2（无模板时 Column 仅 SizedBox+selector+pills，+56+8=原 +64） |
| 挑战模式顺序堆叠 | Task 2（ChallengeOverlayBar 保留条件不变） |
| 数据流无新增 Provider/DAO | 全部（复用 originalTemplateProvider） |

### 类型/签名一致性检查

- `TemplateInfoCard(template: template)` — Task 1 定义构造 `required PhotoTemplate template`，Task 2 传入 `ref.watch(CaptureState.originalTemplateProvider)`（类型 `PhotoTemplate?`），外层已做 `template != null` 判断后收缩为非空，类型匹配。
- `_expanded` 仅在 Task 1 内使用，无跨任务引用。
- 测试引用的常量名（`softPortraitTemplate` / `hkNoirPortraitTemplate`）与 `lib/features/capture/data/templates/` 下实际导出名一致（见 `template_registry.dart` 引用）。
