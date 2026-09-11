# 合规检查弹窗（Splash 首启门控）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Flutter App 的 Splash 页实现合规检查弹窗——首次使用或协议版本更新时先征得同意，同意后才进行联网注册与数据初始化，不同意则退出应用。

**Architecture:** 在 `user_settings` 单行表新增 `compliance_agreed / compliance_version / compliance_agreed_at` 三列（DB 版本 56→57）。main() 开机读本地同意状态；未同意时跳过「设备注册 + 设备信息上报 + 后台同步」并注入 `complianceAwaitingProvider=true`；Splash 依据该标志弹窗，点「同意」才落库并触发 `runPostComplianceInit(container)`（从 main() 抽出的注册+同步链），点「不同意」则 `exit(0)`。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6、flutter_riverpod 2.3.6、go_router 6.5.7、sqflite（单行表 user_settings）。

## Global Constraints

- Dart 2.19.6 / Flutter 3.7.12 —— 禁用 Dart 3 records、records 解构语法；用简单类代替。
- DB 版本号 `_kDbVersion` 从 `56` 递增到 `57`；迁移用既有 `_addColumnIfNotExists`（幂等），不 DROP 表。
- 弹窗/文案/按钮样式一律从 `appThemeProvider`（tokens）+ `uiStyleProvider` 派生，禁止硬编码颜色；链接色用 `tokens.brandText`。
- 复用餐馆组件：`showLumiraDialog` / `LumiraDialogContainer` / `LumiraButton`（`ButtonVariant.primary`/`.secondary`），入口沿用现有 `RouteNames.profileCompliance*`。
- 合规当前版本常量 `complianceCurrentVersion = '2026-08-24'`，与 `compliance_content.dart` 三篇文档更新日期对齐；内容更新时递增并让已同意用户重新弹窗。
- 未同意前不得调用 `registerIfNeeded()`、不得上报设备信息、不得发任何后台同步请求。
- 退出用 `dart:io` 的 `exit(0)`。

---

### Task 1: 数据层 —— user_settings 新增合规列 + SettingsDao 方法

**Files:**
- Modify: `lumira_app_flutter/lib/core/db/tables.dart`（`userSettings` 段，约 line 159-175 之后追加列常量）
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart`（`_kDbVersion`、`_onCreate` user_settings 建表、`_onUpgrade` 尾部 v57 块）
- Modify: `lumira_app_flutter/lib/core/db/dao/settings_dao.dart`（新增读写方法）
- Test: `lumira_app_flutter/test/core/db/compliance_agreement_test.dart`（新建）

**Interfaces:**
- Produces（供 Task 2/4/5 使用）：
  - `SettingsDao.getComplianceVersion() → Future<String?>`（未同意或表无数据返回 `null`）
  - `SettingsDao.setComplianceAgreed(String version) → Future<void>`
  - 列常量 `Tables.colComplianceAgreed / colComplianceVersion / colComplianceAgreedAt`

- [ ] **Step 1: 写失败测试** `test/core/db/compliance_agreement_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:lumira_app_flutter/core/db/dao/settings_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';

void main() {
  late Database db;
  late SettingsDao dao;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE user_settings (
            id INTEGER PRIMARY KEY DEFAULT 1,
            compliance_agreed INTEGER NOT NULL DEFAULT 0,
            compliance_version TEXT,
            compliance_agreed_at INTEGER,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.insert('user_settings', {
          'id': 1,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });
      },
    );
    dao = SettingsDao(db);
  });

  tearDown(() async => db.close());

  test('getComplianceVersion returns null before agreement', () async {
    expect(await dao.getComplianceVersion(), isNull);
  });

  test('setComplianceAgreed persists version and agreed flag', () async {
    await dao.setComplianceAgreed('2026-08-24');
    expect(await dao.getComplianceVersion(), '2026-08-24');
    final rows = await db.query('user_settings', where: 'id = 1');
    expect(rows.first['compliance_agreed'], equals(1));
    expect(rows.first['compliance_version'], equals('2026-08-24'));
  });

  test('setComplianceAgreed overwrites previous version', () async {
    await dao.setComplianceAgreed('2026-08-24');
    await dao.setComplianceAgreed('2026-09-01');
    expect(await dao.getComplianceVersion(), '2026-09-01');
  });

  test('getComplianceVersion returns null when row missing', () async {
    await db.delete('user_settings', where: 'id = 1');
    expect(await dao.getComplianceVersion(), isNull);
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/core/db/compliance_agreement_test.dart`
Expected: 编译失败 —— `getComplianceVersion` / `setComplianceAgreed` / 列常量未定义。

- [ ] **Step 3: 实现 tables.dart 新增列常量**

在 `lib/core/db/tables.dart` 中 `userSettings` 段（`colThemeKeyLight` 之后，`auth 表` 之前）追加：

```dart
  // === user_settings 扩展列（v57 迁移新增，合规协议同意状态） ===
  // compliance_agreed: 1=已同意，0=未同意；compliance_version: 已同意时的文档版本（用于版本变更后重新弹出）
  static const String colComplianceAgreed = 'compliance_agreed';
  static const String colComplianceVersion = 'compliance_version';
  static const String colComplianceAgreedAt = 'compliance_agreed_at';
```

- [ ] **Step 4: 实现 database_provider.dart —— 版本号 + 建表 + 迁移**

将 `_kDbVersion` 从 `56` 改为 `57`（约 line 36）：

```dart
const int _kDbVersion = 57;
```

在 `_onCreate` 的 user_settings 建表语句里（`colOperationBannersCache TEXT,` 与 `updated_at` 之间）插入三列：

```
      ${Tables.colComplianceAgreed} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colComplianceVersion} TEXT,
      ${Tables.colComplianceAgreedAt} INTEGER,
```

在 `_onUpgrade` **末尾**（最后一个已有 `if (oldVersion < ...)` 块之后）追加 v57 迁移块：

```dart
  if (oldVersion < 57) {
    await _addColumnIfNotExists(
      db,
      Tables.userSettings,
      Tables.colComplianceAgreed,
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfNotExists(
      db,
      Tables.userSettings,
      Tables.colComplianceVersion,
      'TEXT',
    );
    await _addColumnIfNotExists(
      db,
      Tables.userSettings,
      Tables.colComplianceAgreedAt,
      'INTEGER',
    );
  }
```

- [ ] **Step 5: 实现 settings_dao.dart 读写方法**

在 `lib/core/db/dao/settings_dao.dart` 末尾（`}` 前）新增：

```dart
  /// 读取已同意的合规文档版本；未同意或未填时返回 null。
  ///
  /// 判定逻辑：`compliance_agreed` 未置 1，或 `compliance_version` 为空，均视为「需重新同意」。
  Future<String?> getComplianceVersion() async {
    final rows = await _db.query(
      Tables.userSettings,
      columns: [Tables.colComplianceAgreed, Tables.colComplianceVersion],
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return null;
    final agreed = rows.first[Tables.colComplianceAgreed];
    if (agreed != 1) return null;
    final raw = rows.first[Tables.colComplianceVersion] as String?;
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  /// 写入已同意标记与文档版本（记录同意时间戳）。
  Future<void> setComplianceAgreed(String version) async {
    await _db.update(
      Tables.userSettings,
      {
        Tables.colComplianceAgreed: 1,
        Tables.colComplianceVersion: version,
        Tables.colComplianceAgreedAt: DateTime.now().millisecondsSinceEpoch,
        Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }
```

- [ ] **Step 6: 运行测试验证通过**

Run: `flutter test test/core/db/compliance_agreement_test.dart`
Expected: 4 个测试全部 PASS。

- [ ] **Step 7: 提交**

```bash
git add lumira_app_flutter/lib/core/db/tables.dart lumira_app_flutter/lib/core/db/database_provider.dart lumira_app_flutter/lib/core/db/dao/settings_dao.dart lumira_app_flutter/test/core/db/compliance_agreement_test.dart
git commit -m "feat(db): user_settings 新增合规同意列 v57 (+SettingsDao 读写)"
```

---

### Task 2: 合规门控模块 —— 版本常量 + 等待态 Provider

**Files:**
- Create: `lumira_app_flutter/lib/core/compliance/compliance_gate.dart`
- Modify: 无

**Interfaces:**
- Produces（供 Task 3/5 使用）：
  - `const String complianceCurrentVersion = '2026-08-24'`
  - `final complianceAwaitingProvider = StateProvider<bool>((ref) => false)`

- [ ] **Step 1: 创建文件** `lib/core/compliance/compliance_gate.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 当前有效的合规文档版本。
///
/// 当《用户协议》《隐私政策》《个人信息清单与第三方SDK目录》任一内容更新时，
/// 递增此版本号（与 compliance_content.dart 最新 updateAt 对齐），
/// 使已同意用户在下一次启动时重新弹出并重新征得同意。
const String complianceCurrentVersion = '2026-08-24';

/// 是否处于「待合规同意」状态（true=需先同意再初始化/联网）。
///
/// 默认 false：由 main() 在启动时依据本地已同意版本与 [complianceCurrentVersion]
/// 是否一致来设置；Splash 依据它决定是否弹出合规窗。
final complianceAwaitingProvider = StateProvider<bool>((ref) => false);
```

- [ ] **Step 2: 校验**

Run: `flutter analyze lib/core/compliance/compliance_gate.dart`
Expected: No issues found.

- [ ] **Step 3: 提交**

```bash
git add lumira_app_flutter/lib/core/compliance/compliance_gate.dart
git commit -m "feat(compliance): 新增合规版本常量与等待态 Provider"
```

---

### Task 3: 启动初始化链重构 —— 抽出 runPostComplianceInit

**Files:**
- Create: `lumira_app_flutter/lib/core/startup/post_compliance_init.dart`
- Modify: `lumira_app_flutter/lib/main.dart`（移除 `_collectDeviceInfo`/`_reportDeviceInfo`，改用新模块；`_doRegister` 改用 `collectDeviceInfo`；boot 链收敛为 `runPostComplianceInit`；`_createBootstrapDaos` 增加 settingsDao；新增合规门控分支）

**Interfaces:**
- Consumes: `authControllerProvider`、`authController.registerIfNeeded()`、`auth.ensureRegistered()`、`defaultResolveOs`（均来自 `core/auth/auth_controller.dart`）、`apiClientProvider`、`profileSyncServiceProvider`、`usageSyncServiceProvider`、`builtinTemplateSyncServiceProvider`、`builtinSceneSyncServiceProvider`
- Produces（供 Task 5 使用）：
  - `Future<void> runPostComplianceInit(ProviderContainer container)` —— 触发注册（如需要）+ 设备信息上报 + 个人资料/使用次数/内置模板/内置场景同步
  - `Future<void> reportDeviceInfo(ProviderContainer container, String os)`
  - `Future<Map<String, dynamic>> collectDeviceInfo(String os)`

> 目标行为（与现有 main() 保持一致）：同意后或非首启时，注册完成拿到 token 后，再逐项执行后台同步。全部 fire-and-forget，不阻塞 UI。

- [ ] **Step 1: 创建文件** `lib/core/startup/post_compliance_init.dart`

```dart
import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../config/app_config.dart';
import '../db/database_provider.dart';
import '../network/api_client.dart';
import '../../features/profile/providers/profile_providers.dart';
import '../../features/usage/usage_providers.dart';

/// 同意合规后（或已同意直接进入）才执行的数据初始化链：
/// 触发注册 → 等 token → 补传设备信息 + 同步个人资料/使用次数/内置模板/内置场景。
///
/// 由 main()（非首启）与 Splash「同意后」共同调用，fire-and-forget，失败静默。
Future<void> runPostComplianceInit(ProviderContainer container) async {
  final auth = container.read(authControllerProvider);
  if (auth.state.needsRegistration) {
    // ignore: invalid_use_of_protected_member
    // ignore: unawaited_futures
    auth.registerIfNeeded();
  }
  final ok = await auth.ensureRegistered();
  if (!ok) return; // 注册失败静默，splash 会显示重试入口

  await reportDeviceInfo(container, defaultResolveOs());
  try {
    final profileSync =
        await container.read(profileSyncServiceProvider.future);
    await profileSync.ensureLoadedIfMissing();
    await profileSync.syncPendingIfNeeded();
  } catch (_) {
    // 网络/鉴权失败静默
  }
  try {
    final us = await container.read(usageSyncServiceProvider.future);
    await us.runSync();
  } catch (_) {
    // 网络/鉴权失败静默
  }
  try {
    final bts =
        await container.read(builtinTemplateSyncServiceProvider.future);
    await bts.syncBuiltinTemplates();
  } catch (_) {
    // 网络/鉴权失败静默
  }
  try {
    final bss = await container.read(builtinSceneSyncServiceProvider.future);
    await bss.syncBuiltinScenes();
  } catch (_) {
    // 网络/鉴权失败静默
  }
}

/// 已注册设备启动时补传设备信息（PATCH /device/info，JWT 鉴权，失败静默）
Future<void> reportDeviceInfo(ProviderContainer container, String os) async {
  try {
    final client = await container.read(apiClientProvider.future);
    final info = await collectDeviceInfo(os);
    await client.patch<bool>('/device/info', body: info, fromJson: (_) => true);
  } catch (_) {
    // 网络/鉴权失败不影响启动
  }
}

/// 采集设备信息（平台分支填充 osVersion / deviceModel，尽力采集、异常回退 os）
Future<Map<String, dynamic>> collectDeviceInfo(String os) async {
  final deviceInfo = DeviceInfoPlugin();
  final data = <String, dynamic>{
    'platform': os,
    'appVersion': '1.0.0',
  };
  try {
    final androidInfo = await deviceInfo.androidInfo;
    data['osVersion'] =
        '${androidInfo.version.release} (API ${androidInfo.version.sdkInt})';
    data['deviceModel'] = '${androidInfo.manufacturer} ${androidInfo.model}';
  } catch (_) {
    try {
      final iosInfo = await deviceInfo.iosInfo;
      data['osVersion'] = '${iosInfo.systemName} ${iosInfo.systemVersion}';
      data['deviceModel'] = iosInfo.utsname.machine;
    } catch (_) {
      data['osVersion'] = os;
    }
  }
  return data;
}
```

- [ ] **Step 2: 调整 main.dart —— 移除已挪走的函数**

删除 `main.dart` 中的 `_collectDeviceInfo` 与 `_reportDeviceInfo` 两个函数定义。

- [ ] **Step 3: 调整 main.dart —— `_doRegister` 改用 collectDeviceInfo**

在 `_doRegister` 中，将 `registerData = await _collectDeviceInfo(os);` 改为 `registerData = await collectDeviceInfo(os);`；并在顶部 import 区域加入：

```dart
import 'core/compliance/compliance_gate.dart';
import 'core/startup/post_compliance_init.dart';
```

同时确认 `dio` / `device_info_plus` 等依赖可用（`collectDeviceInfo` 已移出，无需再为 main 保留 `Dio` import 时可一并清理，但 `_doRegister` 仍需 `Dio/baseUrl`，保留 `dio` 与 `core/config/app_config.dart` import）。

- [ ] **Step 4: 调整 main.dart —— `_createBootstrapDaos` 增加 settingsDao**

将 `_BootstrapDaos` 扩为三成员，并在主函数读取 settingsDao；同时 import `dao/settings_dao.dart`：

```dart
import 'core/db/dao/settings_dao.dart';

class _BootstrapDaos {
  final AuthDao authDao;
  final UserProfileDao profileDao;
  final SettingsDao settingsDao;
  const _BootstrapDaos({
    required this.authDao,
    required this.profileDao,
    required this.settingsDao,
  });
}

Future<_BootstrapDaos> _createBootstrapDaos() async {
  final container = ProviderContainer();
  await container.read(databaseProvider.future);
  final authDao = await container.read(authDaoProvider.future);
  final profileDao = await container.read(userProfileDaoProvider.future);
  final settingsDao = await container.read(settingsDaoProvider.future);
  return _BootstrapDaos(
    authDao: authDao,
    profileDao: profileDao,
    settingsDao: settingsDao,
  );
}
```

- [ ] **Step 5: 调整 main.dart —— 合规门控分支 + 收敛同步链**

将 `main()` 中「bootstrap 之后、runApp 之前」的逻辑改为：

- 把原有「若未注册则后台触发」（`if (authController.state.needsRegistration) { authController.registerIfNeeded(); }`）整段**删除**。
- 替换为「合规判定」：
```dart
  // 合规门控：未同意当前版本协议前，不注册设备、不联网采集、不做后台同步，
  // 交由 Splash 弹出合规窗；同意后再由 runPostComplianceInit 触发初始化。
  final awaitingCompliance = await daos.settingsDao.getComplianceVersion() !=
      complianceCurrentVersion;
```
- 在 `runPostComplianceInit` 需要 container：把原来那段 `.then(...)` 同步链（device info / profile / usage / builtin template / builtin scene 五段 `authController.ensureRegistered().then(...)`）整段**删除**，替换为（放在容器创建完成、`runApp` 之前）：
```dart
  // 注入合规等待态，供 Splash 决定是否弹窗
  container.read(complianceAwaitingProvider.notifier).state = awaitingCompliance;
  if (!awaitingCompliance) {
    // 已同意：立即执行数据初始化（注册 + 同步），Splash 正常进入
    // ignore: unawaited_futures
    runPostComplianceInit(container);
  }
```
> 注意：`container` 需在调用 `runPostComplianceInit` / 设置 provider 前已创建（现有代码的 `ProviderContainer container = ProviderContainer(overrides: [...])` 保持在其上）；这几行放在 `restoreThemePreferences(container)` 附近、`DeepLinkService` 之后、`runApp` 之前均可。

- [ ] **Step 6: 校验**

Run: `flutter analyze lib/core/startup/post_compliance_init.dart lib/main.dart`
Run: `flutter test test/core/auth/auth_controller_test.dart test/features/usage/usage_sync_service_test.dart`
Expected: analyze “No issues found”；相关 auth/usage 测试仍通过（未破坏原初始化依赖）。

- [ ] **Step 7: 提交**

```bash
git add lumira_app_flutter/lib/core/startup/post_compliance_init.dart lumira_app_flutter/lib/main.dart
git commit -m "refactor(startup): 抽出 runPostComplianceInit 并加合规门控分支"
```

---

### Task 4: 合规弹窗组件 ComplianceDialog

**Files:**
- Create: `lumira_app_flutter/lib/features/splash/widgets/compliance_dialog.dart`
- Test: `lumira_app_flutter/test/features/splash/compliance_dialog_test.dart`（新建）

**Interfaces:**
- Consumes: `appThemeProvider`（tokens）、`RouteNames.profileComplianceAgreement/Privacy/Sdk`、`LumiraButton` / `ButtonVariant`（来自 `shared/widgets/lumira/lumira.dart`）
- Produces（供 Task 5 使用）：
  - `class ComplianceDialog extends ConsumerWidget`，构造参数 `{ required VoidCallback onAgree, required VoidCallback onDisagree }`

- [ ] **Step 1: 写失败测试** `test/features/splash/compliance_dialog_test.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/splash/widgets/compliance_dialog.dart';

Widget _wrap({required String route, required Widget child}) {
  return ProviderScope(
    overrides: [
      themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
      uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: route,
        routes: [
          GoRoute(path: route, name: route, builder: (_, __) => child),
          // 三个合规文档路由，仅用于校验点击链接能跳转
          GoRoute(
            path: RouteNames.profileComplianceAgreement,
            builder: (_, __) => const Scaffold(body: Text('AGREEMENT')),
          ),
          GoRoute(
            path: RouteNames.profileCompliancePrivacy,
            builder: (_, __) => const Scaffold(body: Text('PRIVACY')),
          ),
          GoRoute(
            path: RouteNames.profileComplianceSdk,
            builder: (_, __) => const Scaffold(body: Text('SDK')),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('renders title, links and two buttons', (tester) async {
    var agreed = false;
    var disagreed = false;
    await tester.pumpWidget(_wrap(
      route: '/x',
      child: Center(
        child: ComplianceDialog(
          onAgree: () => agreed = true,
          onDisagree: () => disagreed = true,
        ),
      ),
    ));

    expect(find.text('用户协议与隐私政策'), findsOneWidget);
    expect(find.text('同意并开始使用'), findsOneWidget);
    expect(find.text('不同意并退出'), findsOneWidget);
    expect(find.textContaining('《用户协议》'), findsOneWidget);
    expect(find.textContaining('《隐私政策》'), findsOneWidget);
    expect(find.textContaining('《个人信息清单与第三方SDK目录》'), findsOneWidget);
  });

  testWidgets('agree button fires onAgree', (tester) async {
    var agreed = false;
    await tester.pumpWidget(_wrap(
      route: '/x',
      child: Center(
        child: ComplianceDialog(
          onAgree: () => agreed = true,
          onDisagree: () {},
        ),
      ),
    ));
    await tester.tap(find.text('同意并开始使用'));
    expect(agreed, isTrue);
  });

  testWidgets('disagree button fires onDisagree', (tester) async {
    var disagreed = false;
    await tester.pumpWidget(_wrap(
      route: '/x',
      child: Center(
        child: ComplianceDialog(
          onAgree: () {},
          onDisagree: () => disagreed = true,
        ),
      ),
    ));
    await tester.tap(find.text('不同意并退出'));
    expect(disagreed, isTrue);
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/features/splash/compliance_dialog_test.dart`
Expected: 编译失败 —— `ComplianceDialog` 未定义。

- [ ] **Step 3: 实现组件** `lib/features/splash/widgets/compliance_dialog.dart`

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/lumira/lumira.dart';

/// 合规检查弹窗内容（链接式 + 同意/不同意）。
///
/// 由 Splash 通过 [showLumiraDialog] 承载；样式随 8 主题 × 4 风格经
/// `appThemeProvider` 派生，链接用 `tokens.brandText`。
class ComplianceDialog extends ConsumerWidget {
  const ComplianceDialog({
    super.key,
    required this.onAgree,
    required this.onDisagree,
  });

  final VoidCallback onAgree;
  final VoidCallback onDisagree;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final titleStyle = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      height: 1.35,
      color: tokens.textPrimary,
    );
    final bodyStyle = TextStyle(
      fontSize: 13,
      height: 1.6,
      color: tokens.textSecondary,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('用户协议与隐私政策', style: titleStyle),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            style: bodyStyle,
            children: [
              const TextSpan(text: '在使用前，请仔细阅读并充分理解'),
              _link(context, '《用户协议》', RouteNames.profileComplianceAgreement,
                  tokens),
              const TextSpan(text: '、'),
              _link(context, '《隐私政策》', RouteNames.profileCompliancePrivacy,
                  tokens),
              const TextSpan(text: '与'),
              _link(context, '《个人信息清单与第三方SDK目录》',
                  RouteNames.profileComplianceSdk, tokens),
              const TextSpan(
                  text: '。我们非常重视您的隐私。您点击「同意」即表示已阅读并同意上述协议，我们将在您同意后，再开始收集、处理您的个人信息并为您提供服务。'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: LumiraButton(
                variant: ButtonVariant.secondary,
                onPressed: onDisagree,
                child: const Text('不同意并退出'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LumiraButton(
                variant: ButtonVariant.primary,
                onPressed: onAgree,
                child: const Text('同意并开始使用'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  TextSpan _link(BuildContext context, String text, String route,
      ThemeTokens tokens) {
    return TextSpan(
      text: text,
      style: TextStyle(
        color: tokens.brandText,
        decoration: TextDecoration.underline,
        decorationColor: tokens.brandText,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () => context.push(route),
    );
  }
}
```

> 提示：`Row` 用两个 `Expanded` 平分宽度；主按钮 `primary`、退出按钮 `secondary`。若视觉上按钮不够宽，可改为各 `Expanded` + 内部紧凑 padding。

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/features/splash/compliance_dialog_test.dart`
Expected: 3 个测试全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add lumira_app_flutter/lib/features/splash/widgets/compliance_dialog.dart lumira_app_flutter/test/features/splash/compliance_dialog_test.dart
git commit -m "feat(splash): 合规弹窗组件 ComplianceDialog（链接式+同意/不同意）"
```

---

### Task 5: Splash 弹窗接线 —— 首启门控 + 同意触发初始化 / 不同意退出

**Files:**
- Modify: `lumira_app_flutter/lib/features/splash/pages/splash_page.dart`
- Test: `lumira_app_flutter/test/features/splash/splash_page_test.dart`（追加用例）

**Interfaces:**
- Consumes: `complianceAwaitingProvider`、`complianceCurrentVersion`、（来自 `core/compliance/compliance_gate.dart`）、`runPostComplianceInit`（来自 `core/startup/post_compliance_init.dart`）、`settingsDaoProvider`、`showLumiraDialog`（来自 `shared/widgets/lumira/lumira.dart`）
- Produces: Splash 首启时弹窗；同意 → 落库 + `complianceAwaitingProvider=false` + `runPostComplianceInit(ref.container)`；不同意 → `exit(0)`

- [ ] **Step 1: 写失败测试（追加到 `test/features/splash/splash_page_test.dart`）**

在顶部 import 追加 `compliance_gate.dart`：

```dart
import 'package:lumira_app_flutter/core/compliance/compliance_gate.dart';
```

在 `_wrapWithRouter` 末尾的 `overrides` 中，允许注入合规等待态：把 overrides 列表改为支持可选 `awaitingCompliance` 参数，如下（在原函数签名加 `bool awaitingCompliance = false,` 并在 overrides 中加入 `complianceAwaitingProvider.overrideWith((ref) => true)` 当其为真时）。为清晰起见，新增一个独立参数并**在 overrides 中始终 override**：

```dart
Widget _wrapWithRouter(
  Widget child, {
  ThemeKey theme = ThemeKey.warmWhite,
  AuthState? authState,
  _FakeAuthController? authController,
  bool awaitingCompliance = false,
}) {
  // ...原有 router 定义不变...
  return ProviderScope(
    overrides: [
      themeKeyProvider.overrideWith((ref) => theme),
      uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      authControllerProvider.overrideWith((ref) => controller),
      complianceAwaitingProvider.overrideWith((ref) => awaitingCompliance),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}
```

在 `main()` 中追加用例：

```dart
  testWidgets('未待同意时不弹合规窗', (tester) async {
    await tester.pumpWidget(_wrapWithRouter(const SplashPage()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('用户协议与隐私政策'), findsNothing);
  });

  testWidgets('待同意时弹出合规窗', (tester) async {
    await tester.pumpWidget(_wrapWithRouter(
      const SplashPage(),
      awaitingCompliance: true,
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('用户协议与隐私政策'), findsOneWidget);
    expect(find.text('同意并开始使用'), findsOneWidget);
    expect(find.text('不同意并退出'), findsOneWidget);
  });
```

- [ ] **Step 2: 实现 splash_page.dart 门控接线**

在 import 区追加：

```dart
import 'dart:io';
import '../../../core/compliance/compliance_gate.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/startup/post_compliance_init.dart';
```
（`core/db/database_provider.dart` 用于 `settingsDaoProvider`。）

在 `_SplashPageState` 中新增字段与方法：

```dart
  bool _complianceDialogShown = false;

  @override
  void initState() {
    super.initState();
    // ...原有 _redirectTimer / listenManual 不变...
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePresentCompliance());
  }

  /// 首次 build 后检查是否需弹合规窗（首启/版本变更时 waiting 为真）
  void _maybePresentCompliance() {
    if (_complianceDialogShown || !mounted) return;
    if (!ref.read(complianceAwaitingProvider)) return;
    _complianceDialogShown = true;
    _presentComplianceDialog();
  }

  Future<void> _presentComplianceDialog() async {
    await showLumiraDialog<void>(
      context: context,
      // 不允许点背景关闭，用户必须做出选择
      barrierDismissible: false,
      builder: (dialogCtx) => ComplianceDialog(
        onAgree: () async {
          await _agreeCompliance(dialogCtx);
        },
        onDisagree: _disagreeCompliance,
      ),
    );
  }

  Future<void> _agreeCompliance(BuildContext dialogCtx) async {
    // 1. 落库记录已同意版本（失败静默，仍继续，避免用户被卡死）
    try {
      final dao = await ref.read(settingsDaoProvider.future);
      await dao.setComplianceAgreed(complianceCurrentVersion);
    } catch (_) {}
    // 2. 关闭弹窗 + 清除等待态（Splash 不再弹）
    Navigator.of(dialogCtx).pop();
    ref.read(complianceAwaitingProvider.notifier).state = false;
    // 3. 触发数据初始化（注册 + 同步），由既有 auth listener 在 registered 后跳转
    // ignore: unawaited_futures
    runPostComplianceInit(ref.container);
  }

  void _disagreeCompliance() {
    // 未同意则退出应用（iOS/Android/OHOS 通用）
    exit(0);
  }
```

顶部 import 追加 `ComplianceDialog`：

```dart
import '../widgets/compliance_dialog.dart';
```

> 说明：待同意时 `auth` 状态保持 `fresh`，原 1.8s `_redirectTimer` 触发的 `_maybeNavigate` 因 `status != registered` 提前返回，不会提前跳转；同意后 `runPostComplianceInit` 触发注册 → `listenManual` 收到 registered → 原有导航逻辑执行。

- [ ] **Step 3: 运行测试验证通过**

Run: `flutter test test/features/splash/splash_page_test.dart`
Expected: 原有用例仍通过 + 2 个新用例 PASS。

- [ ] **Step 4: 校验**

Run: `flutter analyze lib/features/splash/pages/splash_page.dart lib/features/splash/widgets/compliance_dialog.dart`
Expected: No issues found。

- [ ] **Step 5: 提交**

```bash
git add lumira_app_flutter/lib/features/splash/pages/splash_page.dart lumira_app_flutter/test/features/splash/splash_page_test.dart
git commit -m "feat(splash): 首启合规门控弹窗（同意才初始化，不同意退出）"
```

---

### Task 6: 全量校验 + 手动验收

**Files:**
- Modify: 无

- [ ] **Step 1: 全量静态检查**

Run: `cd lumira_app_flutter && flutter analyze`
Expected: “No issues found” 或仅既有已知告警。

- [ ] **Step 2: 运行相关测试套件**

Run: `flutter test test/core/db/compliance_agreement_test.dart test/features/splash/compliance_dialog_test.dart test/features/splash/splash_page_test.dart`
Expected: 全部通过。

- [ ] **Step 3: 手动验收（真机/模拟器）**

- 全新安装（或清除应用数据）：首启应弹「用户协议与隐私政策」；点「同意并开始使用」后正常注册进入；日志/抓包确认同意前无任何 `/device/register`、`/device/info` 或同步请求。
- 在同意前点「不同意并退出」：应用退出；再次启动仍弹窗。
- 已同意后再次启动：不弹窗，直接进入。
- 模拟版本变更：在 `settings_dao` 里把 `compliance_version` 改成旧值（或改 `complianceCurrentVersion`），重启应重新弹窗。

- [ ] **Step 4: 提交（如有遗留改动）**

```bash
git add -A
git commit -m "chore: 合规门控功能收尾"
```

---

## Self-Review

**Spec 覆盖：**
1. 严格拦截（同意前不联网/不采集）→ Task 3（main 门控分支）+ Task 5（同意后才 `runPostComplianceInit`）✅
2. 链接式 + 同意/不同意 → Task 4（ComplianceDialog 三链接 + 双按钮）✅
3. 版本重问 → Task 1（`getComplianceVersion` vs `complianceCurrentVersion`）✅
4. Splash 首启弹窗 / 不同意退出 → Task 5（`exit(0)`、`showLumiraDialog`）✅
5. DB 迁移 v57 幂等 → Task 1（`_addColumnIfNotExists`）✅

**占位符扫描：** 无 TBD/TODO；每个改动步骤都附完整代码与命令。

**类型一致性：** `getComplianceVersion()→Future<String?>`、`setComplianceAgreed(String)`、`complianceCurrentVersion`、`complianceAwaitingProvider`、`runPostComplianceInit(ProviderContainer)`、`ComplianceDialog(onAgree/onDisagree)` 在各 Task 中的签名一致引用。