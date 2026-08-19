# 设备标识稳定性（deviceId）加固 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让设备唯一标识在「卸载重装」后保持稳定，后端据此沿用旧数据。

**Architecture:** 修复鸿蒙端 `defaultResolveDeviceId` 恒取到 `fallback-时间戳` 的根因：鸿蒙改用 `ohosInfo.odID`（ODID），Android/iOS 保持原标识并加非空校验；首选标识缺失时改用稳定硬件属性的 FNV-1a 聚合哈希做确定性兜底；仅当无任何稳定来源时才回退本地 UUID。全部在 Flutter 端自包含完成。

**Tech Stack:** Dart / Flutter（Dart 2.19.6，不支持 records）、device_info_plus 9.1.2（CPF 移植版）、flutter_test。

## Global Constraints

以下约束来自设计文档，所有任务都必须遵守：

- **Dart 2.19.6，不支持 Dart 3 records 语法**——不得使用 `({..})` / `(a, b)`。
- 不引入任何新依赖：FNV-1a 哈希自实现，不得新增 `crypto` 等包。
- `defaultResolveDeviceId` 对外签名仍为 `Future<String> defaultResolveDeviceId(AuthDao dao)`。
- 现有「注册前优先复用本地已存 deviceId」逻辑必须保留，作为第一道防线。
- 运行验证命令：`flutter test test/core/auth/device_id_resolver_test.dart` 与 `flutter analyze`。
- 仅改动 Flutter 端文件，不触碰 `lumira-server/**` 与 `lumira-app/**`。
- 每个任务完成后单独 commit。

---

### Task 1: FNV-1a 稳定哈希工具

**Files:**
- Modify: `lumira_app_flutter/lib/core/auth/auth_controller.dart`（追加顶层纯函数）
- Test: `lumira_app_flutter/test/core/auth/device_id_resolver_test.dart`（新建）

**Interfaces:**
- Produces: `String fnv1a64Hex(Iterable<String> parts)` —— 对若干字符串拼接做 64 位 FNV-1a 哈希（组件间用分隔符 `|` 防碰撞），返回十六进制串。确定性：相同输入恒相同输出，跨进程/跨实例稳定。

- [ ] **Step 1: 写失败的测试**

```dart
// lumira_app_flutter/test/core/auth/device_id_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/auth/auth_controller.dart';

void main() {
  group('fnv1a64Hex', () {
    test('同输入在两次调用中得到相同结果（确定性）', () {
      final a = fnv1a64Hex(['HUAWEI', 'Mate 60 Pro']);
      final b = fnv1a64Hex(['HUAWEI', 'Mate 60 Pro']);
      expect(a, b);
    });

    test('不同输入得到不同结果', () {
      final a = fnv1a64Hex(['A', 'B']);
      final b = fnv1a64Hex(['A', 'C']);
      expect(a, isNot(b));
    });

    test('空输入也能返回非空十六进制串', () {
      expect(fnv1a64Hex([]).length, greaterThan(0));
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/core/auth/device_id_resolver_test.dart`
Expected: FAIL，`fnv1a64Hex` 未定义。

- [ ] **Step 3: 实现最小代码**

在 `auth_controller.dart` 中 `defaultResolveOs()` 之前追加顶层函数：

```dart
/// FNV-1a 64 位稳定哈希，转十六进制。
///
/// 不依赖 crypto 包，跨实例/跨进程可复现。元素间以 '|' 分隔参与者，
/// 避免 ["ab","c"] 与 ["a","bc"] 这类排列产生相同哈希。
/// 注：Dart int 为 64 位有符号，offset basis 用其有符号等价形式，
/// 乘法依赖原生 64 位回绕得到正确哈希，返回前清除符号位得到规范十六进制。
String fnv1a64Hex(Iterable<String> parts) {
  // FNV-1a 64-bit offset basis 的有符号等价（14695981039346656037 - 2^64）
  var hash = -3750763034362895579;
  const prime = 1099511628211; // 0x100000001b3
  for (final part in parts) {
    for (final unit in part.codeUnits) {
      hash = (hash ^ unit) * prime;
    }
    // 段分隔符
    hash = (hash ^ 0x7C) * prime; // '|'
  }
  hash &= 0x7FFFFFFFFFFFFFFF; // 清除符号位，转成非负十六进制
  return hash.toRadixString(16);
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/core/auth/device_id_resolver_test.dart`
Expected: PASS（3 个用例）。

- [ ] **Step 5: 提交**

```bash
git add lumira_app_flutter/lib/core/auth/auth_controller.dart \
        lumira_app_flutter/test/core/auth/device_id_resolver_test.dart
git commit -m "feat(auth): 新增 FNV-1a 稳定哈希工具"
```

---

### Task 2: 聚合哈希与稳定解析核心

**Files:**
- Modify: `lumira_app_flutter/lib/core/auth/auth_controller.dart`（追加 `DeviceAttributes`、`compositeDeviceId`、`resolveStableDeviceId`）
- Test: `lumira_app_flutter/test/core/auth/device_id_resolver_test.dart`

**Interfaces:**
- Consumes: `fnv1a64Hex(Iterable<String>)`（Task 1）。
- Produces:
  - `class DeviceAttributes { final String? osId; final List<String?> stableParts; const DeviceAttributes({this.osId, this.stableParts = const []}); }`
  - `String compositeDeviceId({required List<String?> parts})` —— 过滤空值后拼接 FNV-1a；全空返回 `''`。
  - `String resolveStableDeviceId({String? osId, required List<String?> stableParts})` —— `osId` 非空则返回之，否则返回 `compositeDeviceId`。

- [ ] **Step 1: 写失败的测试**

追加到 `device_id_resolver_test.dart` 的 `void main()` 内：

```dart
  group('compositeDeviceId', () {
    test('同属性组合两次调用结果相同', () {
      final a = compositeDeviceId(parts: ['HUAWEI', 'Mate 60 Pro', null]);
      final b = compositeDeviceId(parts: ['HUAWEI', 'Mate 60 Pro', null]);
      expect(a, b);
      expect(b, startsWith('comp-'));
    });

    test('仅含一个稳定属性也能生成确定性 id', () {
      final a = compositeDeviceId(parts: ['HUAWEI', null, null]);
      final b = compositeDeviceId(parts: ['HUAWEI', null, null]);
      expect(a, b);
    });

    test('全部为空返回空串', () {
      expect(compositeDeviceId(parts: []), '');
      expect(compositeDeviceId(parts: [null, null]), '');
    });
  });

  group('resolveStableDeviceId', () {
    test('osId 非空时优先生效', () {
      expect(
        resolveStableDeviceId(osId: 'ODID-open-123', stableParts: ['HUAWEI', 'Mate']),
        'ODID-open-123',
      );
    });

    test('osId 为空时退回属性聚合哈希', () {
      final id = resolveStableDeviceId(osId: '', stableParts: ['HUAWEI', 'Mate']);
      expect(id, startsWith('comp-'));
    });
  });
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/core/auth/device_id_resolver_test.dart`
Expected: FAIL，`compositeDeviceId` / `resolveStableDeviceId` / `DeviceAttributes` 未定义。

- [ ] **Step 3: 实现最小代码**

在 Task 1 的 `fnv1a64Hex` 上方追加：

```dart
/// 平台采集结果：OS 级唯一标识 + 稳定硬件属性。
class DeviceAttributes {
  final String? osId;
  final List<String?> stableParts;

  const DeviceAttributes({this.osId, this.stableParts = const []});
}
```

紧接着追加：

```dart
/// 将稳定硬件属性聚合生成确定性设备标识。
/// 返回 'comp-' + FNV-1a 哈希；所有属性为空时返回空串。
String compositeDeviceId({required List<String?> parts}) {
  final nonEmpty = parts.where((p) => p != null && p.isNotEmpty).cast<String>().toList();
  if (nonEmpty.isEmpty) return '';
  return 'comp-${fnv1a64Hex(nonEmpty)}';
}

/// 解析稳定设备标识：优先 OS 级唯一标识；缺失时退回属性聚合哈希。
String resolveStableDeviceId({String? osId, required List<String?> stableParts}) {
  if (osId != null && osId.isNotEmpty) return osId;
  return compositeDeviceId(parts: stableParts);
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/core/auth/device_id_resolver_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lumira_app_flutter/lib/core/auth/auth_controller.dart \
        lumira_app_flutter/test/core/auth/device_id_resolver_test.dart
git commit -m "feat(auth): 聚合哈希与稳定解析核心"
```

---

### Task 3: 改写 defaultResolveDeviceId（平台采集 + 兜底）

**Files:**
- Modify: `lumira_app_flutter/lib/core/auth/auth_controller.dart`（`defaultResolveDeviceId`；新增 `DeviceAttributeCollector`、`_collectViaPlugin`）
- Test: `lumira_app_flutter/test/core/auth/device_id_resolver_test.dart`

**Interfaces:**
- Consumes: `DeviceAttributes`、`resolveStableDeviceId`（Task 2）。
- Produces:
  - `typedef DeviceAttributeCollector = Future<DeviceAttributes?> Function(String platform);`（用于测试注入）
  - `Future<String> defaultResolveDeviceId(AuthDao dao, {DeviceAttributeCollector? collect})` —— 签名向后兼容（新增可选具名参数）。

- [ ] **Step 1: 写失败的测试**

追加到 `device_id_resolver_test.dart` 的 `void main()` 内，并在文件末尾追加 `_ResolverFakeDao`：

```dart
  group('defaultResolveDeviceId', () {
    test('无本地记录时，用注入采集到的 ODID 作为 deviceId', () async {
      final id = await defaultResolveDeviceId(
        _ResolverFakeDao(initial: null),
        collect: (platform) async {
          expect(platform, 'harmonyos');
          return const DeviceAttributes(
            osId: 'ODID-open-123',
            stableParts: ['HUAWEI', 'Mate 60 Pro'],
          );
        },
      );
      expect(id, 'ODID-open-123');
    });

    test('有本地记录时优先复用本地 deviceId，不触发采集', () async {
      var collected = false;
      final id = await defaultResolveDeviceId(
        _ResolverFakeDao(initial: 'saved-device'),
        collect: (platform) async {
          collected = true;
          return const DeviceAttributes(osId: 'ODID-other');
        },
      );
      expect(id, 'saved-device');
      expect(collected, false);
    });

    test('osId 与稳定属性全空时落到 fallback（非确定值）', () async {
      final a = await defaultResolveDeviceId(
        _ResolverFakeDao(initial: null),
        collect: (platform) async => const DeviceAttributes(),
      );
      final b = await defaultResolveDeviceId(
        _ResolverFakeDao(initial: null),
        collect: (platform) async => const DeviceAttributes(),
      );
      expect(a, startsWith('fallback-'));
      expect(a, isNot(b)); // 时间戳不同 → 两次不同（记录为已知局限）
    });

    test('无法采集时（collect 抛异常）仍回退到聚合哈希或 fallback', () async {
      final id = await defaultResolveDeviceId(
        _ResolverFakeDao(initial: null),
        collect: (platform) async => throw Exception('plugin down'),
      );
      expect(id, isNotEmpty);
    });
  });
```

```dart
class _ResolverFakeDao implements AuthDaoLike {
  final String? savedDeviceId;
  _ResolverFakeDao({String? initial}) : savedDeviceId = initial;

  @override
  Future<AuthRecord?> load() async {
    if (savedDeviceId == null) return null;
    return AuthRecord(
      deviceId: savedDeviceId!,
      os: 'harmonyos',
      token: 'jwt',
      isNewDevice: false,
      registeredAt: 1700000000,
    );
  }

  @override
  Future<void> save(AuthRecord r) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<void> clearToken() async {}
}
```

需要在此文件顶部补充 `AuthDaoLike`、`AuthRecord` 的 import：

```dart
import 'package:lumira_app_flutter/core/auth/auth_dao.dart';
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/core/auth/device_id_resolver_test.dart`
Expected: FAIL——`defaultResolveDeviceId` 不支持 `collect` 参数名。

- [ ] **Step 3: 实现最小代码**

在 `auth_controller.dart` 顶部（`import` 之后）追加 typedef，并将 `defaultResolveDeviceId` 整体替换为：

```dart
/// 采集设备属性回调，测试时注入以隔离真实插件。
typedef DeviceAttributeCollector = Future<DeviceAttributes?> Function(String platform);
```

```dart
Future<String> defaultResolveDeviceId(
  AuthDao dao, {
  DeviceAttributeCollector? collect,
}) async {
  // 第一道防线：优先复用本地已存的 deviceId，避免任何采集抖动把它换成新值。
  try {
    final saved = await dao.load();
    if (saved != null && saved.deviceId.isNotEmpty) return saved.deviceId;
  } catch (_) {}

  final os = defaultResolveOs();
  final attrs = collect != null ? await collect(os) : await _collectViaPlugin(os);
  final id = resolveStableDeviceId(
    osId: attrs?.osId,
    stableParts: attrs?.stableParts ?? const [],
  );
  if (id.isNotEmpty) return id;

  // 最后兜底：OS 未暴露任何稳定标识且本地无记录（已知局限，重装会变，
  // 由后续「账号恢复」功能兜住）。返回临时 UUID。
  return 'fallback-${DateTime.now().millisecondsSinceEpoch}';
}

/// 通过 device_info_plus 采集各平台稳定标识与属性。
Future<DeviceAttributes> _collectViaPlugin(String platform) async {
  try {
    if (platform == 'harmonyos') {
      final info = await DeviceInfoPlugin().ohosInfo;
      return DeviceAttributes(
        osId: info.odID,
        stableParts: [info.manufacture, info.brand, info.marketName ?? info.productModel],
      );
    }
    if (platform == 'android') {
      final info = await DeviceInfoPlugin().androidInfo;
      return DeviceAttributes(
        osId: info.id,
        stableParts: [info.manufacturer, info.brand, info.model],
      );
    }
    if (platform == 'ios') {
      final info = await DeviceInfoPlugin().iosInfo;
      return DeviceAttributes(osId: info.identifierForVendor);
    }
  } catch (_) {
    // 采集异常：忽略，落入聚合哈希 / fallback
  }
  return const DeviceAttributes();
}
```

> 关键点：鸿蒙走 `ohosInfo.odID`（ODID）而非 `androidInfo.id`——后者在鸿蒙插件上恒为 null，正是本次修复的根因。

- [ ] **Step 4: 运行测试确认通过，并跑 analyze**

Run: `flutter test test/core/auth/device_id_resolver_test.dart`
Expected: PASS。
Run: `flutter analyze`
Expected: 无新增 error / warning（如有既有同文件历史告警，仅需确保本任务 diff 未新增）。

- [ ] **Step 5: 提交**

```bash
git add lumira_app_flutter/lib/core/auth/auth_controller.dart \
        lumira_app_flutter/test/core/auth/device_id_resolver_test.dart
git commit -m "feat(auth): 鸿蒙改用 ODID 并加固设备标识确定性兜底"
```