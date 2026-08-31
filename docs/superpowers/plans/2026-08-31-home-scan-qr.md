# 首页「扫一扫」实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在首页右上角新增「扫一扫」入口，进入统一扫码页后可扫描 App 内所有种类的码（模板分享码 / 模板离线链接 / 模板在线 token / 恢复码 / 邀请码）并执行对应操作。

**Architecture:** 复用现有 `qr_code_scanner`（相机扫码）与 `zxing2`（相册识别）。新增纯逻辑 `ScanCodeDispatcher` 负责分类 + 分发；模板三类码复用 `TemplateImportSheet` 现有导入管线（新增 `importScannedText` 静态入口，不重复实现）；恢复码/邀请码跳转对应页面预填，由用户确认。首页新增 `_NavAction` 图标入口。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（HarmonyOS 兼容）、flutter_riverpod、go_router、qr_code_scanner（本地化 fork）、zxing2、image、file_picker（FilePickerService 封装）。

## Global Constraints

- **Dart 2.19.6，禁止 Dart 3 records 语法**：不用 `(a, b)` 元组、不用 `case ... when`/pattern matching、不用 `...?` spread-null-aware。项目硬约束（AGENTS.md）。
- 所有 UI 颜色 / 阴影 / 圆角一律从 `themeTokensProvider`（`ThemeTokens`）+ `uiStyleProvider` 派生，**禁止硬编码主题色**（`Colors.xxx` / `Color(0xFF...)`），照片上的黑白半透明遮罩除外。
- 复用既有共享组件：`LumiraNav`、`NeuCard`、`LumiraButton`、`LumiraToast`（`package:.../lumira.dart`）。
- 不改动现有 `TemplateQrScannerPage`（`lib/features/templates/widgets/template_qr_scanner_page.dart`）与恢复页 `_ScannerPage`（`recover_account_page.dart` 内私有类）的内部实现。
- 恢复码 / 邀请码**不直接执行**（安全策略），跳转页面预填、由用户确认后触发。
- 平台支持：原生相机扫码 android / iOS / ohos；web 走主题化引导卡 + 相册识别。
- 本计划仅改 Flutter 端（`lumira_app_flutter/`），不新增后端接口，不 push 远程（仅 commit，AGENTS.md 的 push 要求仅针对 backend/admin）。

---

### Task 1: 恢复码 / 邀请码预填支持（路由参数接线）

**Files:**
- Modify: `lumira_app_flutter/lib/core/router/route_names.dart:110`（`paramScope` 之后新增两个查询参数常量）
- Modify: `lumira_app_flutter/lib/features/account/pages/recover_account_page.dart:31-36`（构造函数）+ `:47-54`（initState）
- Modify: `lumira_app_flutter/lib/features/profile/pages/profile_invite_page.dart:31-46`（构造函数 + initState）
- Modify: `lumira_app_flutter/lib/app/router.dart:504-508`、`533-537`、`686-690`（三个路由 builder 透传查询参数）

**Interfaces:**
- Produces:
  - `RouteNames.paramSecret = 'secret'`
  - `RouteNames.paramInviteCode = 'code'`
  - `RecoverAccountPage({this.presetSecret})`（`String? presetSecret`）
  - `ProfileInvitePage({this.presetCode})`（`String? presetCode`）
- 后续 Task 3 依赖：`ScanCodeDispatcher` 用 `RouteNames.build(RouteNames.accountRecover, {RouteNames.paramSecret: ...})` / `RouteNames.build(RouteNames.profileInvite, {RouteNames.paramInviteCode: ...})` 跳转。

- [x] **Step 1: 先改 `route_names.dart`，新增两个查询参数常量**

在 `paramScope`（第 110 行）之后追加：

```dart
static const String paramScope = 'scope';
// 首页「扫一扫」跳转预填用：恢复码 secret、邀请码 code
static const String paramSecret = 'secret';
static const String paramInviteCode = 'code';
```

- [x] **Step 2: `RecoverAccountPage` 支持 `presetSecret` 预填**

`recover_account_page.dart` 构造函数（31-36 行）改为：

```dart
class RecoverAccountPage extends ConsumerStatefulWidget {
  const RecoverAccountPage({super.key, this.presetSecret});

  /// 外部（如首页「扫一扫」）扫码到恢复码后预填的 secret；由用户确认后再触发找回。
  final String? presetSecret;

  @override
  ConsumerState<RecoverAccountPage> createState() => _RecoverAccountPageState();
}
```

`initState`（47-54 行）改为（在现有 `Future.microtask` 之前预填输入框）：

```dart
@override
void initState() {
  super.initState();
  final preset = widget.presetSecret;
  if (preset != null && preset.isNotEmpty) {
    _secretCtrl.text = preset;
  }
  Future.microtask(() async {
    final api = AccountApi(await ref.read(apiClientProvider.future));
    if (mounted) setState(() => _api = api);
  });
}
```

- [x] **Step 3: `ProfileInvitePage` 支持 `presetCode` 预填**

`profile_invite_page.dart` 构造函数（33-37 行）改为：

```dart
class ProfileInvitePage extends ConsumerStatefulWidget {
  const ProfileInvitePage({super.key, this.presetCode});

  /// 外部（如首页「扫一扫」）扫码到邀请码后预填的邀请码；由用户确认后再激活。
  final String? presetCode;

  @override
  ConsumerState<ProfileInvitePage> createState() => _ProfileInvitePageState();
}
```

新增 `initState`（在 `dispose` 之前插入）：

```dart
@override
void initState() {
  super.initState();
  final preset = widget.presetCode;
  if (preset != null && preset.isNotEmpty) {
    _codeController.text = preset;
  }
}
```

- [x] **Step 4: `router.dart` 三个路由 builder 透传查询参数**

`accountRecover`（504-508 行）改为：

```dart
GoRoute(
  path: RouteNames.accountRecover,
  name: 'accountRecover',
  builder: (context, state) =>
      RecoverAccountPage(presetSecret: state.queryParams['secret']),
),
```

`profileInvite`（533-537 行）改为：

```dart
GoRoute(
  path: RouteNames.profileInvite,
  name: 'profileInvite',
  builder: (context, state) =>
      ProfileInvitePage(presetCode: state.queryParams['code']),
),
```

`invite`（686-690 行）改为：

```dart
GoRoute(
  path: RouteNames.invite,
  name: 'invite',
  builder: (context, state) =>
      ProfileInvitePage(presetCode: state.queryParams['code']),
),
```

- [x] **Step 5: 运行现有相关测试确认无回归**

Run（在 `lumira_app_flutter/` 目录）：
```
flutter test test/core/router/router_test.dart test/features/profile/profile_invite_page_test.dart test/features/account/account_api_test.dart
```
Expected: 全部通过（本任务未改变既有行为，仅新增可选参数与透传）。

- [x] **Step 6: Commit**

```bash
git add lumira_app_flutter/lib/core/router/route_names.dart lumira_app_flutter/lib/features/account/pages/recover_account_page.dart lumira_app_flutter/lib/features/profile/pages/profile_invite_page.dart lumira_app_flutter/lib/app/router.dart
git commit -m "feat(home-scan): 恢复码/邀请码页面支持路由参数预填"
```

---

### Task 2: TemplateImportSheet 复用导入入口

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/widgets/template_import_sheet.dart`
  - 类体新增 `static Future<void> importScannedText(...)`
  - `_handleQrImport`（308-352 行）抽取分类逻辑到新私有方法 `_dispatchImportText`
  - `_handleShareCodeImport`（382-440）、`_importOfflineTemplate`（237-264）、`_importParsedJson`（267-306）、`_handleTokenImport`（443-520）增加 `bool popWhenDone = true` 参数，并包裹各自内部所有 `navigator.pop()` 调用。

**Interfaces:**
- Produces: `static Future<void> TemplateImportSheet.importScannedText(BuildContext context, WidgetRef ref, String text, {void Function(String newTemplateId)? onImported})` —— 复用「扫码导入」全部分类/导入逻辑，但**不关闭任何 BottomSheet**（外部入口无 BottomSheet）。
- Consumes: 既有 `TemplateShareCode.parseCode` / `parseLink`、`TemplateShareService.parseTokenFromScannedText`、`TemplateImportService.importJson`（无需改动）。
- Task 3 依赖此方法执行模板三类码导入。

- [x] **Step 1: 抽取分类逻辑 `_dispatchImportText`，并让 `_handleQrImport` 复用**

将 `_handleQrImport`（308-352 行）替换为：

```dart
// ===== 扫码导入（相机扫码 → 分发；手动输入兜底）=====
Future<void> _handleQrImport(BuildContext context, WidgetRef ref) async {
  final navigator = Navigator.of(context);
  debugPrint('[TemplateImport] code-version: v3-qr-scanner');
  final scanned = await Navigator.of(context).push<String>(MaterialPageRoute(
    builder: (_) => const TemplateQrScannerPage(),
  ));

  // 用户取消扫码（返回 null，含不支持平台的「返回」）→ 直接关闭面板
  // ignore: use_build_context_synchronously
  if (!context.mounted) return;
  if (scanned == null) {
    if (context.mounted) navigator.pop();
    return;
  }

  await _dispatchImportText(context, ref, scanned.trim());
}

/// 按文本分类分发导入（分享码 / 离线 tpl / 在线 token）。
///
/// [popWhenDone] 为 true 时（BottomSheet 内扫码导入）在结束时关闭 BottomSheet；
/// 外部入口（首页「扫一扫」）传 false，由调用方管理导航栈，不 pop。
Future<void> _dispatchImportText(
  BuildContext context,
  WidgetRef ref,
  String text, {
  bool popWhenDone = true,
}) async {
  if (text.startsWith('LUMIRA-')) {
    await _handleShareCodeImport(context, ref, text, popWhenDone: popWhenDone);
    return;
  }

  // 其它文本用 TemplateShareService 分类：
  //  - 返回 token → imp 在线拉取；null → 离线 tpl；'' → 无效
  final token = TemplateShareService.parseTokenFromScannedText(text);
  if (token == null) {
    await _importOfflineTemplate(context, ref, text, popWhenDone: popWhenDone);
    return;
  }
  if (token.isEmpty) {
    if (text.isNotEmpty && context.mounted) {
      _showToast(context, '未能识别有效的分享内容，请手动输入或改用「从链接导入」');
    }
    if (popWhenDone && context.mounted) {
      await _handleManualImport(context, ref);
    }
    return;
  }
  await _handleTokenImport(context, ref, token, popWhenDone: popWhenDone);
}
```

- [x] **Step 2: 新增公开静态入口 `importScannedText`**

在 `_dispatchImportText` 之前插入（类体内）：

```dart
/// 用已有扫码/粘贴文本直接导入模板（供首页「扫一扫」等外部入口复用）。
///
/// 与「扫码导入」走完全相同的分发逻辑（分享码 / 离线链接 / 在线 token），
/// 但**不关闭 BottomSheet**（外部入口没有 BottomSheet，由调用方管理导航栈）。
static Future<void> importScannedText(
  BuildContext context,
  WidgetRef ref,
  String text, {
  void Function(String newTemplateId)? onImported,
}) async {
  final instance = TemplateImportSheet(onImported: onImported ?? (_) {});
  await instance._dispatchImportText(context, ref, text.trim(), popWhenDone: false);
}
```

- [x] **Step 3: 给四个私有导入方法加 `popWhenDone` 参数并包裹 pop**

每个方法签名末尾加 `{bool popWhenDone = true}`，并把方法体内**每一处** `navigator.pop();` 改为 `if (popWhenDone) navigator.pop();`（保持其它逻辑/顺序不变）。

`_handleShareCodeImport`（签名在 382-386 行）：
```dart
Future<void> _handleShareCodeImport(
  BuildContext context,
  WidgetRef ref,
  String code, {
  bool popWhenDone = true,
}) async {
```
该方法内 pop 位置：无效分享码（约 391 行）、成功（约 430 行）、失败 catch（约 436 行）。三处 `navigator.pop();` 均改为 `if (popWhenDone) navigator.pop();`。

`_importOfflineTemplate`（签名在 237-241 行）：
```dart
Future<void> _importOfflineTemplate(
  BuildContext context,
  WidgetRef ref,
  String rawLink, {
  bool popWhenDone = true,
}) async {
```
该方法内 pop 位置：链接格式无效（约 246 行）、轻量形式不支持（约 257 行）。两处均包裹。

`_importParsedJson`（签名在 267-271 行）：
```dart
Future<void> _importParsedJson(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> parsed, {
  bool popWhenDone = true,
}) async {
```
该方法内 pop 位置：导入失败（约 284 行）、成功（约 295 行）、catch（约 301 行）。三处均包裹。

`_handleTokenImport`（签名在 443-447 行）：
```dart
Future<void> _handleTokenImport(
  BuildContext context,
  WidgetRef ref,
  String token, {
  bool popWhenDone = true,
}) async {
```
该方法内 pop 位置：未注册（约 463 行）、分享过期（约 472 行）、网络异常（约 478 行）、其它 ApiException（约 484 行）、payload 非字符串（约 494 行）、decoded 非 Map（约 503 行）、catch（约 516 行）。七处均包裹。

- [x] **Step 4: 运行现有模板导入相关测试确认无回归**

Run（在 `lumira_app_flutter/` 目录）：
```
flutter test test/template_import_test.dart test/features/templates/templates_page_test.dart test/features/templates/templates_all_page_test.dart test/features/profile/profile_my_templates_page_test.dart
```
Expected: 全部通过（默认 `popWhenDone: true`，BottomSheet 内行为与改动前完全一致）。

- [x] **Step 5: Commit**

```bash
git add lumira_app_flutter/lib/features/templates/widgets/template_import_sheet.dart
git commit -m "feat(home-scan): TemplateImportSheet 提供 importScannedText 复用导入入口"
```

---

### Task 3: ScanCodeDispatcher 分发器 + 单测

**Files:**
- Create: `lumira_app_flutter/lib/features/home/services/scan_code_dispatcher.dart`
- Create: `lumira_app_flutter/test/features/home/scan_code_dispatcher_test.dart`（目录不存在则新建）

**Interfaces:**
- Consumes: `RouteNames.paramSecret` / `RouteNames.paramInviteCode`（Task 1）、`TemplateImportSheet.importScannedText`（Task 2）、`TemplateShareService.parseTokenFromScannedText`、`LumiraToast`。
- Produces:
  - `enum ScanCodeType { templateShareCode, templateOfflineLink, templateOnlineToken, recoveryCode, inviteCode, unknown }`
  - `class ScanCodeResult { final ScanCodeType type; final String rawText; final String? payload; const ScanCodeResult(this.type, this.rawText, {this.payload}); }`
  - `static ScanCodeResult ScanCodeDispatcher.classify(String raw)`
  - `static Future<void> ScanCodeDispatcher.execute(BuildContext context, WidgetRef ref, ScanCodeResult result)`
- Task 5 依赖 `classify` + `execute`。

- [x] **Step 1: 写失败测试**

创建 `test/features/home/scan_code_dispatcher_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/features/home/services/scan_code_dispatcher.dart';

void main() {
  group('ScanCodeDispatcher.classify', () {
    test('模板分享码 LUMIRA- 前缀', () {
      final r = ScanCodeDispatcher.classify('LUMIRA-food-红烧肉');
      expect(r.type, ScanCodeType.templateShareCode);
      expect(r.payload, 'LUMIRA-food-红烧肉');
    });

    test('模板离线链接 lumira://tpl 与 https://lumira.app/tpl', () {
      expect(
        ScanCodeDispatcher.classify('lumira://tpl/aGVsbG8').type,
        ScanCodeType.templateOfflineLink,
      );
      expect(
        ScanCodeDispatcher.classify('https://lumira.app/tpl?name=x&category=food').type,
        ScanCodeType.templateOfflineLink,
      );
    });

    test('模板在线 token lumira://imp 与 https://lumira.app/imp', () {
      final r = ScanCodeDispatcher.classify('lumira://imp/abc123');
      expect(r.type, ScanCodeType.templateOnlineToken);
      expect(r.payload, 'abc123');
      expect(
        ScanCodeDispatcher.classify('https://lumira.app/imp/xyz').type,
        ScanCodeType.templateOnlineToken,
      );
    });

    test('恢复码 account-recover / secret=', () {
      final r1 = ScanCodeDispatcher.classify('lumira://account-recover?v=1&secret=mySecret');
      expect(r1.type, ScanCodeType.recoveryCode);
      expect(r1.payload, 'mySecret');
      expect(
        ScanCodeDispatcher.classify('https://x.app/account-recover?secret=abc').type,
        ScanCodeType.recoveryCode,
      );
      expect(
        ScanCodeDispatcher.classify('some?secret=zzz').type,
        ScanCodeType.recoveryCode,
      );
    });

    test('邀请码 6 位安全字母表（含小写归一化）', () {
      final r = ScanCodeDispatcher.classify('a3b9ck');
      expect(r.type, ScanCodeType.inviteCode);
      expect(r.payload, 'A3B9CK');
      expect(
        ScanCodeDispatcher.classify('A3B9CK').type,
        ScanCodeType.inviteCode,
      );
    });

    test('未知：普通文本 / 过短 / 空串', () {
      expect(ScanCodeDispatcher.classify('hello world').type, ScanCodeType.unknown);
      expect(ScanCodeDispatcher.classify('12').type, ScanCodeType.unknown);
      expect(ScanCodeDispatcher.classify('').type, ScanCodeType.unknown);
      expect(ScanCodeDispatcher.classify('   ').type, ScanCodeType.unknown);
    });

    test('规则顺序：LUMIRA- 优先于邀请码；tpl 优先于 imp', () {
      expect(
        ScanCodeDispatcher.classify('LUMIRA-ABC123').type,
        ScanCodeType.templateShareCode,
      );
      expect(
        ScanCodeDispatcher.classify('https://lumira.app/tpl?u=https://lumira.app/imp/y').type,
        ScanCodeType.templateOfflineLink,
      );
    });
  });
}
```

- [x] **Step 2: 运行测试确认失败**

Run（在 `lumira_app_flutter/` 目录）：
```
flutter test test/features/home/scan_code_dispatcher_test.dart
```
Expected: FAIL（`ScanCodeDispatcher` / `ScanCodeType` 未定义）。

- [x] **Step 3: 实现 `ScanCodeDispatcher`**

创建 `lib/features/home/services/scan_code_dispatcher.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../shared/widgets/lumira/lumira.dart' as lumira;
import '../../templates/services/template_share_service.dart';
import '../../templates/widgets/template_import_sheet.dart';

/// 扫码识别结果类型。
enum ScanCodeType {
  /// `LUMIRA-{分类}-{名称}` 模板分享码
  templateShareCode,

  /// `lumira://tpl/...` / `https://lumira.app/tpl?...` 模板离线链接
  templateOfflineLink,

  /// `lumira://imp/{token}` / `https://lumira.app/imp/{token}` 模板在线 token
  templateOnlineToken,

  /// `...account-recover?...secret=xxx` 恢复码
  recoveryCode,

  /// 6 位安全字母表邀请码
  inviteCode,

  /// 无法识别
  unknown,
}

/// 分类结果：类型 + 原始文本 + 附加数据（token / secret / 邀请码等）。
class ScanCodeResult {
  const ScanCodeResult(this.type, this.rawText, {this.payload});

  final ScanCodeType type;
  final String rawText;
  final String? payload;
}

/// 首页「扫一扫」分发器：按格式分类扫描文本并执行对应操作。
///
/// 分类规则（按顺序匹配）与 `docs/specs/2026-08-31-home-scan-qr-design.md` 一致：
/// 1. LUMIRA- 前缀 → 模板分享码
/// 2. 含 lumira://tpl / https://lumira.app/tpl → 模板离线链接
/// 3. 含 lumira://imp / https://lumira.app/imp → 模板在线 token
/// 4. 含 account-recover / secret= → 恢复码
/// 5. 6 位安全字母表（排除 O/0/I/1）→ 邀请码
/// 6. 其它 → 未知
class ScanCodeDispatcher {
  ScanCodeDispatcher._();

  /// 邀请码字母表：与后端 `invite-code.generator.ts` 一致（排除易混淆 O/0/I/1）。
  static final RegExp _inviteRe = RegExp(r'^[A-HJ-NP-Z2-9]{6}$');

  static ScanCodeResult classify(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return const ScanCodeResult(ScanCodeType.unknown, '');
    }

    // 1. 模板分享码
    if (text.startsWith('LUMIRA-')) {
      return ScanCodeResult(ScanCodeType.templateShareCode, text, payload: text);
    }

    // 2. 模板离线链接
    if (text.contains('lumira://tpl') || text.contains('https://lumira.app/tpl')) {
      return ScanCodeResult(ScanCodeType.templateOfflineLink, text, payload: text);
    }

    // 3. 模板在线 token
    if (text.contains('lumira://imp') || text.contains('https://lumira.app/imp')) {
      final token = TemplateShareService.parseTokenFromScannedText(text);
      return ScanCodeResult(ScanCodeType.templateOnlineToken, text, payload: token);
    }

    // 4. 恢复码
    if (text.contains('account-recover') || text.contains('secret=')) {
      return ScanCodeResult(
        ScanCodeType.recoveryCode,
        text,
        payload: _extractSecret(text) ?? text,
      );
    }

    // 5. 邀请码
    if (_inviteRe.hasMatch(text)) {
      return ScanCodeResult(
        ScanCodeType.inviteCode,
        text,
        payload: text.toUpperCase(),
      );
    }

    // 6. 未知
    return ScanCodeResult(ScanCodeType.unknown, text);
  }

  /// 从恢复码文本提取 secret：兼容 `scheme://...account-recover?...&secret=xxx`
  /// 与裸 `secret=xxx` 两种形式；提取失败返回 null。
  static String? _extractSecret(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri != null) {
      final s = uri.queryParameters['secret'];
      if (s != null && s.isNotEmpty) return s;
    }
    final m = RegExp(r'[?&]secret=([^&#]+)').firstMatch(raw);
    if (m != null) return Uri.decodeComponent(m.group(1)!);
    return null;
  }

  /// 执行分类结果对应的操作。
  ///
  /// - 模板三类码：复用 [TemplateImportSheet.importScannedText] 导入（与「扫码导入」一致）。
  /// - 恢复码 / 邀请码：跳转对应页面并预填，由用户确认后触发（不直接执行，避免误操作）。
  /// - 未知：Toast 提示。
  static Future<void> execute(
    BuildContext context,
    WidgetRef ref,
    ScanCodeResult result,
  ) async {
    switch (result.type) {
      case ScanCodeType.templateShareCode:
      case ScanCodeType.templateOfflineLink:
      case ScanCodeType.templateOnlineToken:
        await TemplateImportSheet.importScannedText(
          context,
          ref,
          result.rawText,
        );
        break;
      case ScanCodeType.recoveryCode:
        GoRouter.of(context).push(RouteNames.build(
          RouteNames.accountRecover,
          {RouteNames.paramSecret: result.payload ?? ''},
        ));
        break;
      case ScanCodeType.inviteCode:
        GoRouter.of(context).push(RouteNames.build(
          RouteNames.profileInvite,
          {RouteNames.paramInviteCode: result.payload ?? ''},
        ));
        break;
      case ScanCodeType.unknown:
        lumira.LumiraToast.show(context, '无法识别的码');
        break;
    }
  }
}
```

- [x] **Step 4: 运行测试确认通过**

Run：
```
flutter test test/features/home/scan_code_dispatcher_test.dart
```
Expected: 全部 PASS。

- [x] **Step 5: Commit**

```bash
git add lumira_app_flutter/lib/features/home/services/scan_code_dispatcher.dart lumira_app_flutter/test/features/home/scan_code_dispatcher_test.dart
git commit -m "feat(home-scan): ScanCodeDispatcher 扫码文本分类与分发"
```

---

### Task 4: ScanQrPage 统一扫码页

**Files:**
- Create: `lumira_app_flutter/lib/features/home/widgets/scan_qr_page.dart`

**Interfaces:**
- Consumes: `FilePickerService.pickSingleImage` / `ensureFullBytes`、`zxing2`（`RGBLuminanceSource` / `HybridBinarizer` / `QRCodeReader`）、`qr_code_scanner`、`themeTokensProvider`、`NeuCard` / `LumiraButton` / `LumiraNav`。
- Produces: `ScanQrPage` —— 全屏页，`Navigator.pop(context, String? text)` 返回原始识别文本（取消返回 null）。Task 5 依赖。
- UI 建模参考：恢复页 `_ScannerPage`（相机扫码 + 底部「从相册选择二维码」按钮 + zxing2 解码），以及 `TemplateQrScannerPage` 的 `_canScanNative` 平台判断。

- [x] **Step 1: 实现 `ScanQrPage`**

创建 `lib/features/home/widgets/scan_qr_page.dart`：

```dart
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:zxing2/qrcode.dart';

import '../../../core/services/file_picker_service.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';

/// 首页「扫一扫」全屏扫码页。
///
/// - 原生相机扫码在 android / iOS / ohos（HarmonyOS）可用：本地化的
///   `qr_code_scanner` 已合并 CPF-Flutter 鸿蒙适配（OhosView 原生扫码）；
///   其余平台（含 web）展示主题化引导卡，提示使用相册识别。
/// - 底部固定「从相册选择二维码」按钮：调起系统相册选图，用纯 Dart `zxing2`
///   解码（全平台可用，web 也能识别海报 / 截图中的二维码）。
///
/// 返回约定（经 [Navigator.pop] 回传）：
/// - 扫到 / 识别到有效文本 → pop 原始识别文本（[String]）
/// - 用户取消 / 系统返回 → pop null
class ScanQrPage extends ConsumerStatefulWidget {
  const ScanQrPage({super.key});

  @override
  ConsumerState<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends ConsumerState<ScanQrPage> {
  final _key = GlobalKey();
  QRViewController? _controller;
  bool _picking = false;

  /// 支持原生相机扫码的平台：android / iOS / ohos；其余（含 web）走主题化回退。
  bool get _canScanNative {
    if (kIsWeb) return false;
    final p = defaultTargetPlatform;
    return p == TargetPlatform.android ||
        p == TargetPlatform.iOS ||
        // 标准 Flutter SDK 没有 TargetPlatform.ohos，用名称判断保持双 SDK 兼容
        p.name == 'ohos';
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// 从相册选择图片并尝试识别二维码，成功则 pop 回传识别文本。
  Future<void> _pickFromGallery() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final file = await FilePickerService.pickSingleImage();
      if (file == null) return; // 用户取消选择
      final full = await FilePickerService.ensureFullBytes(file);
      final bytes = full.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) LumiraToast.show(context, '读取图片失败，请重试');
        return;
      }
      final text = _decodeQrFromBytes(bytes);
      if (!mounted) return;
      if (text != null && text.isNotEmpty) {
        Navigator.of(context).pop(text);
      } else {
        LumiraToast.show(context, '未识别到二维码，请选择清晰的二维码图片');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// 从图片字节解码二维码文本，未识别到返回 null。
  String? _decodeQrFromBytes(List<int> bytes) {
    final image = img.decodeImage(Uint8List.fromList(bytes));
    if (image == null) return null;
    try {
      final pixels = image
          .convert(numChannels: 4)
          .getBytes(order: img.ChannelOrder.rgba);
      final source =
          RGBLuminanceSource(image.width, image.height, pixels.buffer.asInt32List());
      final bitmap = BinaryBitmap(HybridBinarizer(source));
      final result = QRCodeReader().decode(bitmap);
      final text = result.text;
      return text.isNotEmpty ? text : null;
    } catch (_) {
      // 图片中无二维码，或解码失败
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '扫一扫',
        transparent: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6),
            radius: 1.2,
            colors: [
              tokens.brandSubtle.withOpacity(0.35),
              tokens.canvas.withOpacity(0.0),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _canScanNative
                    ? QRView(
                        key: _key,
                        overlay: QrScannerOverlayShape(
                          overlayColor: Colors.black26,
                          borderColor: tokens.brand,
                          borderLength: 30,
                          borderWidth: 5,
                        ),
                        onQRViewCreated: (c) {
                          _controller = c;
                          c.scannedDataStream.listen((barcode) {
                            final code = barcode.code;
                            if (code != null && code.isNotEmpty) {
                              Navigator.of(context).pop(code);
                            }
                          });
                        },
                      )
                    : _UnsupportedScanGuide(tokens: tokens),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: LumiraButton(
                  variant: ButtonVariant.secondary,
                  onPressed: _picking ? null : _pickFromGallery,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _picking
                            ? Icons.hourglass_top
                            : Icons.photo_library_outlined,
                      ),
                      const SizedBox(width: 8),
                      Text(_picking ? '识别中…' : '从相册选择二维码'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 读取不到原生相机扫码能力时的引导卡片（主题一致，不崩溃）。
///
/// 不 pop（与模板扫码页不同，扫一扫没有「手动输入」兜底），引导用户改用
/// 下方「从相册选择二维码」按钮识别海报 / 截图中的二维码。
class _UnsupportedScanGuide extends StatelessWidget {
  const _UnsupportedScanGuide({required this.tokens});

  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: NeuCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: tokens.brandSubtle,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.qr_code_scanner,
                  size: 32,
                  color: tokens.brand,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '当前设备暂不支持摄像头扫码',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '请使用下方「从相册选择二维码」按钮，识别海报或截图中的二维码。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [x] **Step 2: 验证编译**

Run（在 `lumira_app_flutter/` 目录）：
```
flutter analyze lib/features/home/widgets/scan_qr_page.dart
```
Expected: No issues found（`FilePickerService.pickSingleImage` / `ensureFullBytes` 签名与恢复页用法一致；若 `full.bytes` 类型不同，参照 `recover_account_page.dart:456-457` 的 `ensureFullBytes(file)` 用法调整）。

- [x] **Step 3: Commit**

```bash
git add lumira_app_flutter/lib/features/home/widgets/scan_qr_page.dart
git commit -m "feat(home-scan): 新增 ScanQrPage 统一扫码页（相机 + 相册识别）"
```

---

### Task 5: 首页扫一扫入口

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/pages/home_page.dart`
  - import：`scan_qr_page.dart`、`scan_code_dispatcher.dart`
  - `actions`（117-129 行）在通知图标之前插入扫一扫 `_NavAction`
  - `_HomePageState` 新增 `_onScanTap()` 方法

**Interfaces:**
- Consumes: `ScanCodeDispatcher.classify` / `execute`（Task 3）、`ScanQrPage`（Task 4）。
- Produces: 首页右上角「扫一扫」入口（push `ScanQrPage`，扫码后分发）。

- [x] **Step 1: 加 import**

`home_page.dart` 顶部 import 区（`route_names.dart` 之后）新增：

```dart
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../features/notification/notification_providers.dart';
import '../services/scan_code_dispatcher.dart';
import '../widgets/scan_qr_page.dart';
```

（`_HomePageState` 内即可用 `ref`，无需额外 Riverpod import。）

- [x] **Step 2: 新增 `_onScanTap` 方法**

在 `_HomePageState` 的 `_goSceneGuide` 方法之后（约 97 行）插入：

```dart
/// 首页「扫一扫」：push 全屏扫码页，拿到文本后按类型分发执行。
Future<void> _onScanTap() async {
  final text = await Navigator.of(context).push<String>(MaterialPageRoute(
    builder: (_) => const ScanQrPage(),
  ));
  if (!mounted || text == null || text.trim().isEmpty) return;
  await ScanCodeDispatcher.execute(
    context,
    ref,
    ScanCodeDispatcher.classify(text),
  );
}
```

- [x] **Step 3: actions 中插入扫一扫图标（通知之前）**

`build` 的 `actions`（117-129 行）改为：

```dart
actions: [
  _NavAction(
    icon: Icons.qr_code_scanner,
    tokens: tokens,
    onTap: _onScanTap,
  ),
  _NavAction(
    icon: Icons.notifications_outlined,
    tokens: tokens,
    badgeCount: unreadCount,
    onTap: () => GoRouter.of(context).push(RouteNames.profileNotifications),
  ),
  _NavAction(
    icon: Icons.card_giftcard_outlined,
    tokens: tokens,
    onTap: () => GoRouter.of(context).push(RouteNames.profileShareCode),
  ),
],
```

（`_NavAction` 的 `onTap` 是 `VoidCallback`，`_onScanTap` 是 `Future<void>`，直接传引用即可——异步体由回调触发，不阻塞 UI。）

- [x] **Step 4: 验证编译**

Run：
```
flutter analyze lib/features/home/pages/home_page.dart
```
Expected: No issues found。

- [x] **Step 5: Commit**

```bash
git add lumira_app_flutter/lib/features/home/pages/home_page.dart
git commit -m "feat(home-scan): 首页右上角新增扫一扫入口"
```

---

### Task 6: 全量验证与收尾

**Files:** 无新增/修改（仅验证）。

- [x] **Step 1: 全量 analyze**

Run（在 `lumira_app_flutter/` 目录）：
```
flutter analyze
```
Expected: No issues found（或仅既有存量 warning，无新增）。

- [x] **Step 2: 运行新增 + 相关回归测试**

Run：
```
flutter test test/features/home/scan_code_dispatcher_test.dart test/template_import_test.dart test/template_share_code_test.dart test/features/templates/templates_page_test.dart test/core/router/router_test.dart test/features/profile/profile_invite_page_test.dart
```
Expected: 全部 PASS。

- [x] **Step 3: 手动冒烟（真机/模拟器）**

在 android/iOS/ohos 真机（或模拟器）验证：
1. 首页右上角出现扫一扫图标，样式与通知/礼盒一致。
2. 点击进入 `ScanQrPage`，相机取景 + 金色扫码框。
3. 扫描「模板分享海报」二维码 → 导入模板成功（Toast「已导入模板」）。
4. 扫描「自定义模板二维码分享」二维码（`lumira://imp/...`）→ 在线拉取导入。
5. 扫描「恢复账号二维码」（`lumira://account-recover?...&secret=...`）→ 跳转找回账号页，恢复码输入框已预填，需用户点按钮确认。
6. 扫描「邀请海报」二维码（当前为占位 `_MockupQr`，内容为邀请码文本）→ 跳转邀请有礼页，邀请码输入框已预填。
7. 点击「从相册选择二维码」→ 选一张含二维码的截图 → 识别成功执行对应操作。
8. 扫描无法识别的码（如普通文字）→ Toast「无法识别的码」。
9. 底部返回/取消 → 回到首页，无异常 pop（首页不被误关）。

- [x] **Step 4: 登记后续优化（如有）**

若出现「当前先这样实现、后续再优化」的内容，追加到 `docs/future-optimizations.md` 末尾（遵循既有格式）。

- [x] **Step 5: 最终 commit（如有改动）**

```bash
git add -u
git commit -m "chore(home-scan): 收尾调整"
```

---

## Self-Review

**1. Spec 覆盖**
- 首页入口：Task 5 ✓
- 统一扫码页（相机 + 相册识别 + web 引导卡）：Task 4 ✓
- 扫码分发器 6 类规则：Task 3 ✓
- 模板三类码复用现有导入：Task 2 + Task 3 ✓
- 恢复码/邀请码跳转预填（安全策略，不直接执行）：Task 1 + Task 3 ✓
- 测试要求（6 分支 + 边界 + 现有测试保持通过 + analyze 无新增错误）：Task 3 单测 + Task 6 ✓
- 非目标遵守：不改 `TemplateQrScannerPage` / `_ScannerPage`，不新增后端接口，web 不真实扫码，邀请海报二维码不改造 ✓

**2. 占位符扫描**：全部步骤含实际代码与命令，无 TBD/TODO/「适当处理」类占位。

**3. 类型一致性**：`ScanCodeResult.type/payload`、`ScanCodeType` 枚举名、`RouteNames.paramSecret/paramInviteCode`、`importScannedText(context, ref, text)`、`RecoverAccountPage(presetSecret:)`、`ProfileInvitePage(presetCode:)` 在 Task 间命名一致。`state.queryParams` 与 router.dart 既有 `state.queryParams[...]` 用法一致；`navigator.pop()` 包裹统一用 `if (popWhenDone)`。
