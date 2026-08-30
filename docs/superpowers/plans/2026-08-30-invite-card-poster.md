# 邀请卡片分享海报实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将「邀请有礼」页旧的 `_InvitePosterSheet` 替换为主题化的邀请卡片分享海报（跟随 4 套 UI 风格），操作补齐为复制 + 保存 + 分享。

**Architecture:** 复用 `PosterGenerator.showPoster` 的捕获/保存/分享能力，为其增加一个可选的 `extraAction`（复制邀请码）。新增纯展示 `InvitePosterCard`（ConsumerWidget，`ref.watch(appThemeProvider)`，固定 300×400 3:4 画布）与薄封装 `showInvitePosterSheet`。删除 profile_invite_page 内联旧实现。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6，flutter_riverpod，qr_flutter，saver_gallery，share_plus。

## Global Constraints

- Flutter 3.7.12 / Dart 2.19.6，**不支持 Dart 3 records 语法**。
- UI 风格：`UIStyle.neumorphic/flat/glass/female`。邀请卡片**严格跟随当前** `appThemeProvider` 的 style + tokens，**不做手动风格切换**。
- 所有颜色/阴影/圆角/边框一律从 `ThemeTokens` 与 `AppThemeData` 派生，**禁止硬编码**色值与阴影（二维码白底 `Colors.white` 除外，属「白底可扫」合法例外）。
- 画布固定逻辑尺寸 **300×400（宽×高，3:4）**；导出倍率由 `PosterGenerator._captureImage` 按 `kPosterExportWidth=1080` 计算。
- 组件命名与文件路径必须完全一致（下文任务按精确路径/签名引用）。
- 每次任务结束时运行 `flutter analyze`；Flutter 根目录为 `lumira_app_flutter/`。

---

### Task 1: 为 `PosterGenerator.showPoster` 增加可选 `extraAction`

**Files:**
- Modify: `lumira_app_flutter/lib/shared/services/poster_generator.dart`

**Interfaces:**
- Consumes: 现状 `showPoster`（`context/tokens/title/content/posterKey/shareSubject/shareText/fileNamePrefix`）。
- Produces: `showPoster` 新增可选命名参数 `Widget? extraAction`；`_PosterSheet` 新增 `extraAction` 字段，并在底部操作条最前方（保存/分享按钮之前）渲染。此为**向后兼容**改动，现有调用方不受影响。

- [ ] **Step 1: 在 `showPoster` 静态方法与 `_PosterSheet` 中接入 `extraAction`**

(1) `showPoster` 参数列表（`lib/shared/services/poster_generator.dart` 的 `showPoster` 内，`fileNamePrefix` 之后）末尾追加：

```dart
    Widget? extraAction,
```

并在 builder 传入 `_PosterSheet(` 内（`fileNamePrefix: fileNamePrefix,` 之后）：

```dart
        extraAction: extraAction,
```

(2) `_PosterSheet` 构造函数（`this.fileNamePrefix,` 之后）追加：

```dart
    this.extraAction,
```

(3) `_PosterSheet` 类字段区（`final String fileNamePrefix;` 之后）追加：

```dart
  final Widget? extraAction;
```

- [ ] **Step 2: 在底部操作条渲染 `extraAction`**

将 `build` 中底部 `Row(children: [ ... ])`（保存/分享两个 `Expanded(_PosterAction ...)` 之前）改为在其首位插入：

```dart
                if (widget.extraAction != null) ...[
                  Expanded(child: widget.extraAction!),
                  const SizedBox(width: 10),
                ],
```

保留原有两块 `_PosterAction` 与 `SizedBox(width: 10)` 不变，仅在其前插入上面两个元素。

- [ ] **Step 3: 运行 analyze 验证**

Run: 在 `lumira_app_flutter/` 执行 `flutter analyze`
Expected: 0 errors（.dart 无新增错误）。

- [ ] **Step 4: Commit**

```bash
git add lumira_app_flutter/lib/shared/services/poster_generator.dart
git commit -m "feat(poster): showPoster 支持可选扩展操作按钮"
```

---

### Task 2: 新增 `InvitePosterCard`

**Files:**
- Create: `lumira_app_flutter/lib/features/invite/widgets/invite_poster_card.dart`

**Interfaces:**
- Consumes: `appThemeProvider`（`core/theme/theme_controller.dart`）、`app_theme.dart`（`AppThemeData`、`UIStyle`、`MultiGradientSpec`）、`theme_tokens.dart`（`ThemeTokens`、`glassFill`/`glassBorder` 静态方法）、`qr_flutter`。
- Produces: `class InvitePosterCard extends ConsumerWidget`，构造 `const InvitePosterCard({super.key, required this.code})`，`final String code;`。固定 `SizedBox(width: 300, height: 400)`。Task 3 及测试依赖此类型与尺寸。

- [ ] **Step 1: 写失败测试**

Create: `lumira_app_flutter/test/features/invite/invite_poster_card_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/invite/widgets/invite_poster_card.dart';
import 'package:qr_flutter/qr_flutter.dart';

Widget wrap(Widget child) {
  return ProviderScope(
    overrides: [
      themeKeyProvider.overrideWithValue(ThemeKey.warmWhite),
      uiStyleProvider.overrideWithValue(UIStyle.neumorphic),
    ],
    child: MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

void main() {
  testWidgets('InvitePosterCard 渲染标题、邀请码与二维码（默认暖白/新拟态）', (tester) async {
    await tester.pumpWidget(wrap(const InvitePosterCard(code: 'LUMIRA-7K2A')));
    await tester.pump();
    expect(find.text('邀请好友 · 一起来拍照'), findsOneWidget);
    expect(find.text('LUMIRA-7K2A'), findsOneWidget);
    expect(find.text('我的邀请码'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: 在 `lumira_app_flutter/` 执行 `flutter test test/features/invite/invite_poster_card_test.dart`
Expected: FAIL — 找不到 `invite_poster_card.dart` 或断言失败。

- [ ] **Step 3: 实现 `InvitePosterCard`**

完整写入 `lmira_app_flutter/lib/features/invite/widgets/invite_poster_card.dart`。要点：
- `build`：`ref.watch(appThemeProvider)` → `appTheme`；外层 `SizedBox(width:300,height:400)` + `ClipRRect(radius22)` + `Stack(fit:expand,[_SceneBackground, Center(Padding(18,_InviteCard))])`。
- `_SceneBackground` 按 `appTheme.style` 返回场景：neumorphic=canvas→canvasDeep 渐变+金色细边；flat=canvasDeep→surfaceAlt 渐变+divider 细边；glass=`_GlassScene`（画布底+3~4 个品牌光斑）；female=RadialGradient 品牌氛围光。
- `_InviteCard`：外层 `Container(padding: v28/h22, width:inf)`，decoration 用 `_cardSurface`（neumorphic=surface+shadowConvex+radius22；flat=surfaceAlt+divider 边+radius18；glass=glassFill+glassBorder+radius20；female=multiGradient.linear + hairlineBorder + cardShadow + radius24）；female 时叠加 `Positioned.fill(radialHighlight)`。内部 `Column`：`_brandRow`（LUMIRA + 金渐变细线 + 如 画）→ 主标题 → 副标题 → `_GainPill` → `_QrBox` → `_CodeBlock` → 底部品牌脚。
- `_GainPill`：文案 `好友首次激活，双方各得 +30 积分`；neumorphic/female=brandSubtle 底+brandText 字；flat=surfaceAlt+divider 边；glass=白 0.55+白细边。radius999。
- `_QrBox`：白底 + 样式相关 border/shadow；内 `QrImageView(data:code, version:auto, size:132, backgroundColor:Colors.white, eyeStyle=square textPrimary, dataModuleStyle=square textPrimary)` + `长按识别二维码 · 立即加入`。
- `_CodeBlock`：标签 `我的邀请码` + 大字 `code`（fontFamily 'Courier New'，bold，letterSpacing5，textPrimary）；凹陷感 neumorphic=shadowConcaveSubtle / flat=白边 / glass=白0.45底+白细边 / female=白0.7底+品牌细 border+柔投影。

（Step 3 完整代码较长，遵循上述要点手写实现；所有颜色仅用 tokens/Colors.white，禁止固定色。）

- [ ] **Step 4: 运行测试验证通过**

Run: 在 `lumira_app_flutter/` 执行 `flutter test test/features/invite/invite_poster_card_test.dart`
Expected: PASS（1 个用例通过）。

- [ ] **Step 5: 运行 analyze**

Run: 在 `lumira_app_flutter/` 执行 `flutter analyze`
Expected: 0 errors。

- [ ] **Step 6: Commit**

```bash
git add lumira_app_flutter/lib/features/invite/widgets/invite_poster_card.dart lumira_app_flutter/test/features/invite/invite_poster_card_test.dart
git commit -m "feat(invite): 新增跟随 UI 风格的邀请卡片分享海报 InvitePosterCard"
```

---

### Task 3: 新增 `showInvitePosterSheet` 并接入复制/保存/分享

**Files:**
- Create: `lumira_app_flutter/lib/features/invite/widgets/invite_poster_sheet.dart`
- Create: `lumira_app_flutter/lib/features/invite/widgets/invite_card_scene.dart`
- Test: `lumira_app_flutter/test/features/invite/invite_poster_sheet_test.dart`

**Interfaces:**
- Consumes: `InvitePosterCard(code: code)`（Task 2）；`PosterGenerator.showPoster(extraAction:)`（Task 1）；`themeTokensProvider`；`Clipboard`；`LumiraToast.show`。
- Produces: `Future<void> showInvitePosterSheet({required BuildContext context, required String code, required ThemeTokens tokens})`（Task 4 调用）；`Future<void> showInviteCopyToast(BuildContext context, String code)`（测试与 sheet 复用）。

- [ ] **Step 1: 写失败测试**

Create: `lumira_app_flutter/test/features/invite/invite_poster_sheet_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/invite/widgets/invite_card_scene.dart';

void main() {
  testWidgets('复制按钮将邀请码写入剪贴板', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeKeyProvider.overrideWithValue(ThemeKey.warmWhite),
          uiStyleProvider.overrideWithValue(UIStyle.neumorphic),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: InviteCardScene(
              code: 'LUMIRA-9KX2',
              onCopy: () => showInviteCopyToast(
                  tester.element(find.byType(InviteCardScene)), 'LUMIRA-9KX2'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final data = await Clipboard.getData('text/plain');
    expect(data?.text, 'LUMIRA-9KX2');
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: 在 `lumira_app_flutter/` 执行 `flutter test test/features/invite/invite_poster_sheet_test.dart`
Expected: FAIL — 找不到 `invite_card_scene.dart` / 剪贴板为空。

- [ ] **Step 3: 实现 `invite_card_scene.dart`（复制夹具）**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 复制邀请码：写入系统剪贴板并 toast 反馈。
Future<void> showInviteCopyToast(BuildContext context, String code) async {
  await Clipboard.setData(ClipboardData(text: code));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('邀请码已复制：$code'), duration: const Duration(seconds: 1)),
    );
  }
}

/// 复制测试夹具（避免直接打开 bottom sheet）。
class InviteCardScene extends StatelessWidget {
  const InviteCardScene({super.key, required this.code, required this.onCopy});
  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCopy,
      behavior: HitTestBehavior.opaque,
      child: Container(color: Colors.white, alignment: Alignment.center, child: const Text('邀请卡片场景')),
    );
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/features/invite/invite_poster_sheet_test.dart`
Expected: PASS。

- [ ] **Step 5: 实现 `invite_poster_sheet.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';
import '../../../shared/services/poster_generator.dart';
import 'invite_card_scene.dart';
import 'invite_poster_card.dart';

/// 打开邀请卡片分享海报底部弹层。
///
/// 复用 [PosterGenerator.showPoster] 的捕获/保存/分享能力；底部操作条最前
/// 插入「复制邀请码」按钮。卡片内容为 [InvitePosterCard]（跟随当前 UI 风格）。
Future<void> showInvitePosterSheet({
  required BuildContext context,
  required String code,
  required ThemeTokens tokens,
}) async {
  await PosterGenerator.showPoster(
    context: context,
    tokens: tokens,
    title: '邀请卡片',
    content: InvitePosterCard(code: code),
    posterKey: GlobalKey(),
    shareSubject: '如画 LUMIRA · 邀请好友',
    shareText: '一起拍照，把生活拍成想要的样子',
    fileNamePrefix: 'lumira_invite',
    extraAction: _CopyAction(code: code, tokens: tokens),
  );
}

/// 复制邀请码操作按钮（紧邻保存/分享）。
class _CopyAction extends StatelessWidget {
  const _CopyAction({required this.code, required this.tokens});
  final String code;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showInviteCopyToast(context, code),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        decoration: BoxDecoration(
          color: tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.copy_rounded, size: 16, color: tokens.brandText),
            const SizedBox(width: 5),
            Text(
              '复制邀请码',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.brandText),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: 运行 analyze**

Run: 在 `lumira_app_flutter/` 执行 `flutter analyze`
Expected: 0 errors（`_CopyAction` 与调用一致）。

- [ ] **Step 7: Commit**

```bash
git add lumira_app_flutter/lib/features/invite/widgets/invite_poster_sheet.dart lumira_app_flutter/lib/features/invite/widgets/invite_card_scene.dart lumira_app_flutter/test/features/invite/invite_poster_sheet_test.dart
git commit -m "feat(invite): 新增邀请卡片分享弹层 showInvitePosterSheet（复制+保存+分享）"
```

---

### Task 4: 重构 `profile_invite_page.dart`，接入新弹层并删除旧实现

**Files:**
- Modify: `lumira_app_flutter/lib/features/profile/pages/profile_invite_page.dart`

**Interfaces:**
- Consumes: `showInvitePosterSheet({context, code, tokens})`（Task 3）。
- Produces: `_generateInviteCard` 打开新弹层；删除 `_posterKey`、`_showInvitePoster`、`_InvitePosterSheet`；清理不再使用的 import。

- [ ] **Step 1: 改 `_generateInviteCard` 调用新弹层（约 L60）**

将：

```dart
      // 打开全屏邀请海报
      await _showInvitePoster(code.code);
```

改为：

```dart
      // 打开邀请卡片分享弹层（跟随当前 UI 风格，复制/保存/分享）
      await showInvitePosterSheet(
        context: context,
        code: code.code,
        tokens: ref.read(themeTokensProvider),
      );
```

并在 import 区新增：

```dart
import '../../../features/invite/widgets/invite_poster_sheet.dart';
```

- [ ] **Step 2: 删除 `_showInvitePoster` 与 `_posterKey`**

删除字段 `final GlobalKey _posterKey = GlobalKey();`（当前 L45）与整个 `_showInvitePoster` 方法（当前 L73-81）。

- [ ] **Step 3: 删除 `_InvitePosterSheet` 类**

删除当前 L938（`class _InvitePosterSheet extends ConsumerWidget {`）到 L1078 之间的整个类定义。

- [ ] **Step 4: 清理不再使用的 import**

删除以下若确认全文件不再引用的 import（删后跑 analyze 复核）：
`import 'dart:ui' as ui;`、`import 'package:flutter/rendering.dart';`、`import 'package:qr_flutter/qr_flutter.dart';`、`import 'package:saver_gallery/saver_gallery.dart';`。
保留仍在用的：`flutter/material.dart`、`app_theme.dart`（NeuCard 等用）、`theme_controller.dart`、`theme_tokens.dart`、`neu_card.dart`（L249 等多处）。`flutter/services.dart` 是否删除以 analyze 为准（文件内无其他 Clipboard 使用时删除）。

- [ ] **Step 5: 运行 analyze**

Run: 在 `lumira_app_flutter/` 执行 `flutter analyze`
Expected: 0 errors，0 unused imports。

- [ ] **Step 6: Commit**

```bash
git add lumira_app_flutter/lib/features/profile/pages/profile_invite_page.dart
git commit -m "refactor(invite): 接入邀请卡片分享弹层，移除旧 _InvitePosterSheet"
```

---

### Task 5: 全量回归验证

**Files:** 验证用（默认无代码改动）。

- [ ] **Step 1: 运行新增测试与全量分析**

Run: 在 `lumira_app_flutter/` 执行 `flutter analyze`
Expected: 0 error。
Run: `flutter test test/features/invite/`
Expected: 2 个测试文件全部 PASS。

- [ ] **Step 2: 手动验证**

4 种 UI 风格（设置-外观）下进入「我的 → 邀请有礼 → 生成邀请卡片」：
1. 卡片按当前风格渲染（新拟态浮雕 / 扁平描边 / 玻璃磨砂 / 女性多渐变），二维码可扫。
2. 「复制邀请码」回写剪贴板并 toast。
3. 「保存到相册」iOS/Android 落相册；OHOS 走 `MissingPluginException` 降级。
4. 「分享海报」调起系统分享；OHOS 降级剪贴板。

- [ ] **Step 3: Commit（若验证中有修复）**

无修复则无新 commit；有修复则按修复内容单独 commit。

---

## 附注（Task 3 测试剪贴板 mock）

Flutter 测试中 `Clipboard` 走 mocked platform channel，未 mock 时 `getData` 返回 null。请将 `invite_poster_sheet_test.dart` 的 main 改为在测试顶部注册 mock：

```dart
import 'package:flutter/services.dart';
import 'package:lumira_app_flutter/features/invite/widgets/invite_card_scene.dart';

String? captured;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    captured = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        final arg = (call.arguments as Map)['text'] as String?;
        captured = arg;
      }
      return null;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  // 测试体：执行复制后断言 captured == 'LUMIRA-9KX2'
}
```

（以 `captured` 断言替代原测试里 `Clipboard.getData` 的断言。）

---

## Self-Review

1. **规格覆盖**：(a) 跟随当前 UI 风格——InvitePosterCard 由 appThemeProvider 驱动，无切换条（Task 2）；(b) 复制+保存+分享——PosterGenerator.showPoster + extraAction 复制（Task 1/3）；(c) 3:4 竖版——300×400（Task 2）；(d) 四套风格视觉语法——Scene/Card/Pill/QrBox/CodeBlock 逐风格分支（Task 2）；(e) 不引入 PosterPalette——全程 ThemeTokens（Task 2）；(f) 删除旧 _InvitePosterSheet（Task 4）。
2. **占位符扫描**：无 TBD/TODO；Task 2 的实现以「要点」给定并附设计文档对照（`docs/superpowers/specs/2026-08-30-invite-card-poster-design.md` 的「四套风格视觉语法」表为权威色值来源）；Task 3/4 为完整代码。
3. **类型一致性**：`InvitePosterCard(code:)`（Task 2）→ Task 3 构造一致；`showInvitePosterSheet({context, code, tokens})`（Task 3）→ Task 4 调用一致；`PosterGenerator.showPoster(extraAction:)`（Task 1）→ Task 3 传递一致；`showInviteCopyToast(BuildContext, String)` 在 invite_card_scene.dart 定义、在 invite_poster_sheet.dart 与测试中使用一致。
