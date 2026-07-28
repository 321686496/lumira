# Flutter 后端接入实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `lumira_app_flutter` 接入 `lumira-server` 后端的 4 个模块（device/invite/redeem/rewards），实现设备注册、邀请激活、兑换码核销、奖励查询/领取的完整数据流。

**Architecture:** ApiClient 集中（Dio 单例 + Auth Interceptor）+ 每模块 Repository 抽象（复用现有 `AcademyRepository` 范式）+ 远程优先失败回退 sqflite 缓存 + Riverpod Provider 注入。

**Tech Stack:** Flutter 3.7 / Dart 2.19.6 / Riverpod 2.3.6 / sqflite（CPF-Flutter 鸿蒙适配版）/ dio 4.0.6 / go_router 6.x

## Global Constraints

- Dart SDK 钉死 `>=2.19.6 <3.0.0`，所有新依赖必须兼容
- 后端全局前缀 `/api/v1`，CORS 仅允许 `GET/POST/PATCH`（禁用 PUT/DELETE）
- baseUrl 默认 `http://10.0.2.2:3000/api/v1`（Android 模拟器→宿主机）
- JWT token / deviceId / os / api_cache 全部存 sqflite（不引入 shared_preferences）
- 后端类型契约：`lumira-server/packages/shared/src/types/{device,invite,redeem,rewards}.ts`
- 手写 fromJson/toJson，不引入 json_serializable / build_runner
- 鸿蒙适配：所有新依赖必须无原生代码（纯 Dart）或在 CPF-Flutter 适配列表
- 复用现有 `AcademyRepository` 抽象 + `LocalAcademyRepository` 实现的范式
- 代码风格：与 `lumira_app_flutter/lib/features/academy/` 一致

**参考文件（必读）：**
- 设计文档：`docs/superpowers/specs/2026-07-28-flutter-backend-integration-design.md`
- 范式参考：`lumira_app_flutter/lib/features/academy/data/academy_repository.dart`
- DB 范式：`lumira_app_flutter/lib/core/db/database_provider.dart`
- 后端契约：
  - `lumira-server/packages/shared/src/types/device.ts`
  - `lumira-server/packages/shared/src/types/invite.ts`
  - `lumira-server/packages/shared/src/types/redeem.ts`
  - `lumira-server/packages/shared/src/types/rewards.ts`

---

## File Structure

### 新增文件

```
lumira_app_flutter/lib/
├── core/
│   ├── config/app_config.dart
│   ├── network/
│   │   ├── api_client.dart
│   │   ├── auth_interceptor.dart
│   │   └── api_error.dart
│   └── auth/
│       ├── auth_controller.dart
│       ├── auth_state.dart
│       └── auth_dao.dart
├── features/
│   ├── device/data/
│   │   ├── device_models.dart
│   │   └── device_repository.dart
│   ├── invite/data/
│   │   ├── invite_models.dart
│   │   └── invite_repository.dart
│   ├── redeem/data/
│   │   ├── redeem_models.dart
│   │   └── redeem_repository.dart
│   └── rewards/data/
│       ├── rewards_models.dart
│       └── rewards_repository.dart
└── shared/widgets/api_error_banner.dart

lumira_app_flutter/test/
├── core/
│   ├── network/api_client_test.dart
│   ├── auth/auth_controller_test.dart
│   └── db/migration_v5_test.dart
└── features/
    ├── device/data/device_repository_test.dart
    ├── invite/data/invite_repository_test.dart
    ├── redeem/data/redeem_repository_test.dart
    └── rewards/data/rewards_repository_test.dart
```

### 修改文件

```
lumira_app_flutter/
├── pubspec.yaml
├── lib/main.dart
├── lib/core/db/database_provider.dart
├── lib/core/db/tables.dart
├── lib/app/router.dart
├── lib/features/splash/pages/splash_page.dart
├── lib/features/profile/pages/profile_page.dart
└── lib/features/profile/pages/profile_invite_page.dart
```

---

## Task 1: 基础设施 — pubspec + AppConfig + DB v5 迁移

**Files:**
- Modify: `lumira_app_flutter/pubspec.yaml`
- Create: `lumira_app_flutter/lib/core/config/app_config.dart`
- Modify: `lumira_app_flutter/lib/core/db/tables.dart`
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart`
- Test: `lumira_app_flutter/test/core/db/migration_v5_test.dart`

**Interfaces:**
- Produces: `AppConfig.baseUrl`、`AppConfig.connectTimeoutMs`、`AppConfig.receiveTimeoutMs`、`AppConfig.isRelease`
- Produces: `Tables.auth`、`Tables.apiCache`、`Tables.colDeviceId`、`Tables.colOs`、`Tables.colToken`、`Tables.colIsNewDevice`、`Tables.colRegisteredAt`、`Tables.colKey`、`Tables.colPayload`、`Tables.colCachedAt`
- Produces: DB v5 迁移逻辑（auth + api_cache 表）

- [ ] **Step 1: 添加 dio 依赖**

Modify `lumira_app_flutter/pubspec.yaml`，在 `dependencies:` 段最后（`flutter_svg` 后）加：

```yaml
  # HTTP 客户端（4.x 末版兼容 Dart 2.19；5.x 需 Dart 3）
  # 纯 Dart 库，无原生代码，鸿蒙无需 fork
  dio: 4.0.6
```

- [ ] **Step 2: 验证依赖解析**

Run:
```bash
cd lumira_app_flutter
flutter pub get
```
Expected: 无错误。若 meta 约束冲突，在 `dependency_overrides` 段精确钉定（应不需要，dio 4.0.6 依赖 meta ^1.7.0 已满足 1.8.0）。

- [ ] **Step 3: 创建 AppConfig**

Create `lumira_app_flutter/lib/core/config/app_config.dart`:

```dart
import 'package:flutter/foundation.dart';

/// 应用环境配置
///
/// baseUrl 通过 --dart-define=API_BASE_URL=xxx 切换
/// 默认指向 Android 模拟器宿主机（10.0.2.2 = host loopback）
/// 真机调试时需替换为开发机局域网 IP，例如
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.100:3000/api/v1
class AppConfig {
  const AppConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );

  static const int connectTimeoutMs = 8000;
  static const int receiveTimeoutMs = 10000;

  static bool get isRelease => kReleaseMode;
}
```

- [ ] **Step 4: 扩展 Tables 常量**

Modify `lumira_app_flutter/lib/core/db/tables.dart`，在文件末尾追加：

```dart
  // === auth 表（v5） ===
  static const String auth = 'auth';
  static const String colDeviceId = 'device_id';
  static const String colOs = 'os';
  static const String colToken = 'token';
  static const String colIsNewDevice = 'is_new_device';
  static const String colRegisteredAt = 'registered_at';

  // === api_cache 表（v5） ===
  static const String apiCache = 'api_cache';
  static const String colKey = 'key';
  static const String colPayload = 'payload';
  static const String colCachedAt = 'cached_at';
```

- [ ] **Step 5: 写 DB v5 迁移测试**

Create `lumira_app_flutter/test/core/db/migration_v5_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

// 复用现有测试的 DB 创建方式（参考 dao_test.dart / migration_v4_test.dart）
// 注意：不直接 import database_provider.dart 以避免 CPF-Flutter sqflite fork 在测试环境的复杂依赖
// 直接手写 schema 验证 v5 升级逻辑

void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  });

  tearDown(() async => db.close());

  test('v5 migration creates auth and api_cache tables', () async {
    // 表存在
    final authTables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='auth'",
    );
    expect(authTables.length, 1);

    final cacheTables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='api_cache'",
    );
    expect(cacheTables.length, 1);

    // auth 表列存在
    final authCols = await db.rawQuery('PRAGMA table_info(auth)');
    final authColNames = authCols.map((c) => c['name'] as String).toSet();
    expect(authColNames, containsAll([
      'id', 'device_id', 'os', 'token', 'is_new_device', 'registered_at',
    ]));

    // api_cache 表列存在
    final cacheCols = await db.rawQuery('PRAGMA table_info(api_cache)');
    final cacheColNames = cacheCols.map((c) => c['name'] as String).toSet();
    expect(cacheColNames, containsAll(['key', 'payload', 'cached_at']));
  });

  test('auth table stores single row by id=1', () async {
    await db.insert('auth', {
      'id': 1,
      'device_id': 'test-device',
      'os': 'android',
      'token': 'jwt-token',
      'is_new_device': 1,
      'registered_at': 1700000000,
    });
    final rows = await db.query('auth');
    expect(rows.length, 1);
    expect(rows.first['device_id'], 'test-device');
  });

  test('api_cache table upserts by key', () async {
    await db.insert('api_cache', {
      'key': 'invite_stats',
      'payload': '{"total":0}',
      'cached_at': 1700000000,
    });
    // upsert：DELETE + INSERT 简化
    await db.delete('api_cache', where: 'key = ?', whereArgs: ['invite_stats']);
    await db.insert('api_cache', {
      'key': 'invite_stats',
      'payload': '{"total":5}',
      'cached_at': 1700000001,
    });
    final rows = await db.query('api_cache', where: 'key = ?', whereArgs: ['invite_stats']);
    expect(rows.length, 1);
    expect(rows.first['payload'], '{"total":5}');
  });
}

// 复制 v5 创建逻辑（与 database_provider.dart 保持一致）
Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS auth (
      id INTEGER PRIMARY KEY DEFAULT 1,
      device_id TEXT NOT NULL,
      os TEXT NOT NULL,
      token TEXT NOT NULL,
      is_new_device INTEGER NOT NULL DEFAULT 0,
      registered_at INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS api_cache (
      key TEXT PRIMARY KEY,
      payload TEXT NOT NULL,
      cached_at INTEGER NOT NULL
    )
  ''');
}

Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 5) {
    await _onCreate(db, newVersion);
  }
}
```

- [ ] **Step 6: 运行测试验证失败**

Run:
```bash
cd lumira_app_flutter
flutter test test/core/db/migration_v5_test.dart
```
Expected: FAIL（auth/api_cache 表未在 database_provider.dart 中创建）

- [ ] **Step 7: 修改 database_provider.dart 实现 v5 迁移**

Modify `lumira_app_flutter/lib/core/db/database_provider.dart`：

修改第 16 行：
```dart
const int _kDbVersion = 5;
```

在 `_onCreate` 函数末尾（第 200 行 `await db.execute(AcademyLearningTrajectoryTable.createSql);` 之后）追加：
```dart
  // === v5: auth + api_cache 表 ===
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.auth} (
      id INTEGER PRIMARY KEY DEFAULT 1,
      ${Tables.colDeviceId} TEXT NOT NULL,
      ${Tables.colOs} TEXT NOT NULL,
      ${Tables.colToken} TEXT NOT NULL,
      ${Tables.colIsNewDevice} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colRegisteredAt} INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.apiCache} (
      ${Tables.colKey} TEXT PRIMARY KEY,
      ${Tables.colPayload} TEXT NOT NULL,
      ${Tables.colCachedAt} INTEGER NOT NULL
    )
  ''');
```

在 `_onUpgrade` 函数末尾（第 252 行 `}` 之前）追加 v5 迁移块：
```dart
  if (oldVersion < 5) {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${Tables.auth} (
          id INTEGER PRIMARY KEY DEFAULT 1,
          ${Tables.colDeviceId} TEXT NOT NULL,
          ${Tables.colOs} TEXT NOT NULL,
          ${Tables.colToken} TEXT NOT NULL,
          ${Tables.colIsNewDevice} INTEGER NOT NULL DEFAULT 0,
          ${Tables.colRegisteredAt} INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${Tables.apiCache} (
          ${Tables.colKey} TEXT PRIMARY KEY,
          ${Tables.colPayload} TEXT NOT NULL,
          ${Tables.colCachedAt} INTEGER NOT NULL
        )
      ''');
    } catch (e) {
      debugPrint('v5 migration failed (silent fallback): $e');
    }
  }
```

- [ ] **Step 8: 运行测试验证通过**

Run:
```bash
cd lumira_app_flutter
flutter test test/core/db/migration_v5_test.dart
```
Expected: PASS（3 个测试全部通过）

- [ ] **Step 9: 验证 flutter analyze 无错误**

Run:
```bash
cd lumira_app_flutter
flutter analyze lib/core/config/ lib/core/db/
```
Expected: "No issues found!"

- [ ] **Step 10: Commit**

```bash
cd lumira_app_flutter
git add pubspec.yaml pubspec.lock lib/core/config/app_config.dart lib/core/db/tables.dart lib/core/db/database_provider.dart test/core/db/migration_v5_test.dart
git commit -m "feat(flutter): add dio dep, AppConfig, DB v5 migration (auth + api_cache tables)"
```

---

## Task 2: 网络层 — ApiError + ApiClient + AuthInterceptor

**Files:**
- Create: `lumira_app_flutter/lib/core/network/api_error.dart`
- Create: `lumira_app_flutter/lib/core/network/auth_interceptor.dart`
- Create: `lumira_app_flutter/lib/core/network/api_client.dart`
- Test: `lumira_app_flutter/test/core/network/api_client_test.dart`

**Interfaces:**
- Consumes: `AppConfig.baseUrl` / `AppConfig.connectTimeoutMs` / `AppConfig.receiveTimeoutMs`（from Task 1）
- Produces: `ApiErrorKind` 枚举、`ApiException` 类（含 `isNetworkError` / `isUnauthorized` getter）
- Produces: `ApiClient` 类（含 `get<T>` / `post<T>` / `patch<T>` 方法）
- Produces: `apiClientProvider`（FutureProvider<ApiClient>）

- [ ] **Step 1: 创建 ApiError**

Create `lumira_app_flutter/lib/core/network/api_error.dart`:

```dart
/// API 错误类型枚举
enum ApiErrorKind {
  /// 断网 / 连接超时 / 接收超时
  network,
  /// 401 未授权 → 触发重新注册
  unauthorized,
  /// 403 禁止访问
  forbidden,
  /// 404 未找到
  notFound,
  /// 5xx 服务端错误
  server,
  /// 其他未知错误
  unknown,
}

/// API 异常
///
/// 包装 Dio 错误为业务可识别的枚举类型
class ApiException implements Exception {
  final ApiErrorKind kind;
  final int? statusCode;
  final String message;
  final dynamic original;

  const ApiException(
    this.kind,
    this.message, {
    this.statusCode,
    this.original,
  });

  /// 网络错误（断网/超时）→ Repository 层可回退缓存
  bool get isNetworkError => kind == ApiErrorKind.network;

  /// 401 未授权 → AuthController 应清除本地 token
  bool get isUnauthorized => kind == ApiErrorKind.unauthorized;

  @override
  String toString() => 'ApiException($kind, $statusCode): $message';
}

/// 将 Dio 异常映射为 ApiException
///
/// 注意：调用方需传入 dio 4.0.6 的 DioError 类型
/// 此处使用 dynamic 以避免循环依赖（network 层不直接 import dio）
ApiException classifyDioError(dynamic err) {
  // 通过反射访问 err.type 和 err.response
  // dio 4.0.6 DioErrorType 枚举值：connectTimeout / sendTimeout / receiveTimeout / response / cancel / other
  final type = err.type;
  final typeStr = type?.toString() ?? '';

  if (typeStr.contains('Timeout') ||
      typeStr.contains('connectionError') ||
      typeStr.contains('connectTimeout') ||
      typeStr.contains('receiveTimeout') ||
      typeStr.contains('sendTimeout')) {
    return const ApiException(ApiErrorKind.network, 'Network timeout or connection error');
  }

  final statusCode = err.response?.statusCode as int?;
  switch (statusCode) {
    case 401:
      return ApiException(ApiErrorKind.unauthorized, 'Unauthorized', statusCode: 401, original: err);
    case 403:
      return ApiException(ApiErrorKind.forbidden, 'Forbidden', statusCode: 403, original: err);
    case 404:
      return ApiException(ApiErrorKind.notFound, 'Not Found', statusCode: 404, original: err);
    default:
      if (statusCode != null && statusCode >= 500) {
        return ApiException(ApiErrorKind.server, 'Server error', statusCode: statusCode, original: err);
      }
      return ApiException(ApiErrorKind.unknown, 'Unknown error', statusCode: statusCode, original: err);
  }
}
```

- [ ] **Step 2: 创建 AuthInterceptor**

Create `lumira_app_flutter/lib/core/network/auth_interceptor.dart`:

```dart
import 'package:dio/dio.dart';

import '../auth/auth_controller.dart';

/// 鉴权拦截器
///
/// 1. 请求注入 Bearer token（除 /device/register 外）
/// 2. 响应 401 → 触发 AuthController 失效（不吞错，由上层决策）
class AuthInterceptor extends Interceptor {
  final AuthController _auth;

  AuthInterceptor(this._auth);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _auth.currentToken;
    final isRegisterPath = options.path.contains('/device/register');
    if (token != null && !isRegisterPath) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;
    if (statusCode == 401) {
      _auth.invalidateRegistration();
    }
    handler.next(err);
  }
}
```

注意：`AuthController` 在 Task 3 创建，本文件先建占位 `// ignore: unused_import` 会让 analyze 报错，因此**此 Task 完成后仅做 dart 编译检查，不跑 analyze**。在 Task 3 完成后统一验证。

- [ ] **Step 3: 创建 ApiClient**

Create `lumira_app_flutter/lib/core/network/api_client.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../config/app_config.dart';
import 'api_error.dart';
import 'auth_interceptor.dart';

/// API 客户端
///
/// 包装 Dio，统一 baseUrl / 超时 / 鉴权拦截器
/// 所有方法返回 Future<T>，失败抛 ApiException
class ApiClient {
  final Dio _dio;

  ApiClient._(this._dio);

  static Future<ApiClient> create(AuthController auth) async {
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: Duration(milliseconds: AppConfig.connectTimeoutMs),
      receiveTimeout: Duration(milliseconds: AppConfig.receiveTimeoutMs),
      headers: {'Content-Type': 'application/json'},
    ));
    dio.interceptors.add(AuthInterceptor(auth));
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(responseBody: false, requestBody: false));
    }
    return ApiClient._(dio);
  }

  /// GET 请求
  ///
  /// [path] 相对路径，如 '/invite/stats'
  /// [fromJson] 将 response.data 转为目标类型
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Object? json) fromJson,
  }) async {
    try {
      final resp = await _dio.get(path, queryParameters: query);
      return fromJson(resp.data);
    } on DioError catch (e) {
      throw classifyDioError(e);
    }
  }

  /// POST 请求
  Future<T> post<T>(
    String path, {
    Object? body,
    required T Function(Object? json) fromJson,
  }) async {
    try {
      final resp = await _dio.post(path, data: body);
      return fromJson(resp.data);
    } on DioError catch (e) {
      throw classifyDioError(e);
    }
  }

  /// PATCH 请求
  Future<T?> patch<T>(
    String path, {
    Object? body,
    required T Function(Object? json) fromJson,
  }) async {
    try {
      final resp = await _dio.patch(path, data: body);
      return fromJson(resp.data);
    } on DioError catch (e) {
      throw classifyDioError(e);
    }
  }
}

/// 全局 ApiClient Provider
///
/// 注意：依赖 authControllerProvider（Task 3），故为 FutureProvider
final apiClientProvider = FutureProvider<ApiClient>((ref) async {
  final auth = ref.watch(authControllerProvider.notifier);
  return ApiClient.create(auth);
});
```

- [ ] **Step 4: 写 ApiClient 测试**

Create `lumira_app_flutter/test/core/network/api_client_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/network/api_error.dart';

void main() {
  group('classifyDioError', () {
    test('connectTimeout maps to network', () {
      final err = DioError(
        type: DioErrorType.connectTimeout,
        requestOptions: RequestOptions(path: '/test'),
      );
      final apiErr = classifyDioError(err);
      expect(apiErr.kind, ApiErrorKind.network);
      expect(apiErr.isNetworkError, true);
    });

    test('receiveTimeout maps to network', () {
      final err = DioError(
        type: DioErrorType.receiveTimeout,
        requestOptions: RequestOptions(path: '/test'),
      );
      final apiErr = classifyDioError(err);
      expect(apiErr.kind, ApiErrorKind.network);
    });

    test('401 response maps to unauthorized', () {
      final err = DioError(
        type: DioErrorType.response,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 401,
        ),
      );
      final apiErr = classifyDioError(err);
      expect(apiErr.kind, ApiErrorKind.unauthorized);
      expect(apiErr.isUnauthorized, true);
      expect(apiErr.statusCode, 401);
    });

    test('403 response maps to forbidden', () {
      final err = DioError(
        type: DioErrorType.response,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 403,
        ),
      );
      final apiErr = classifyDioError(err);
      expect(apiErr.kind, ApiErrorKind.forbidden);
    });

    test('404 response maps to notFound', () {
      final err = DioError(
        type: DioErrorType.response,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 404,
        ),
      );
      final apiErr = classifyDioError(err);
      expect(apiErr.kind, ApiErrorKind.notFound);
    });

    test('500 response maps to server', () {
      final err = DioError(
        type: DioErrorType.response,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 500,
        ),
      );
      final apiErr = classifyDioError(err);
      expect(apiErr.kind, ApiErrorKind.server);
    });
  });

  group('ApiException', () {
    test('isNetworkError getter works', () {
      const err = ApiException(ApiErrorKind.network, 'timeout');
      expect(err.isNetworkError, true);
      expect(err.isUnauthorized, false);
    });

    test('isUnauthorized getter works', () {
      const err = ApiException(ApiErrorKind.unauthorized, '401', statusCode: 401);
      expect(err.isUnauthorized, true);
      expect(err.isNetworkError, false);
    });

    test('toString contains kind', () {
      const err = ApiException(ApiErrorKind.server, 'boom', statusCode: 500);
      expect(err.toString(), contains('server'));
      expect(err.toString(), contains('500'));
    });
  });
}
```

- [ ] **Step 5: 运行测试验证失败**

Run:
```bash
cd lumira_app_flutter
flutter test test/core/network/api_client_test.dart
```
Expected: FAIL（Task 3 的 AuthController 不存在导致 import 失败）

- [ ] **Step 6: Commit（暂不验证，留待 Task 3 后统一验证）**

```bash
cd lumira_app_flutter
git add lib/core/network/ test/core/network/api_client_test.dart
git commit -m "feat(flutter): add ApiClient + ApiError + AuthInterceptor (network layer)"
```

---

## Task 3: Auth 模块 — AuthState + AuthDao + AuthController

**Files:**
- Create: `lumira_app_flutter/lib/core/auth/auth_state.dart`
- Create: `lumira_app_flutter/lib/core/auth/auth_dao.dart`
- Create: `lumira_app_flutter/lib/core/auth/auth_controller.dart`
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart` (加 authDaoProvider)
- Test: `lumira_app_flutter/test/core/auth/auth_controller_test.dart`

**Interfaces:**
- Consumes: `databaseProvider`（existing）、`apiClientProvider`（from Task 2，仅在 `registerIfNeeded` 调用时）
- Consumes: `device_info_plus: 9.1.2`（existing dep）
- Produces: `AuthStatus` 枚举、`AuthState` 类（含 `status` / `token` / `deviceId` / `os` / `isNewDevice` / `lastError` / `needsRegistration` / `isReady` getter）
- Produces: `AuthRecord` 类、`AuthDao` 类（含 `load` / `save` / `clear` 方法）
- Produces: `AuthController extends StateNotifier<AuthState>`（含 `bootstrap` / `registerIfNeeded` / `invalidateRegistration` / `currentToken` getter）
- Produces: `authControllerProvider = StateNotifierProvider<AuthController, AuthState>`

- [ ] **Step 1: 创建 AuthState**

Create `lumira_app_flutter/lib/core/auth/auth_state.dart`:

```dart
import 'package:flutter/foundation.dart';

/// 鉴权状态
enum AuthStatus {
  /// 初始加载中
  loading,
  /// 未注册，需要调用 /device/register
  fresh,
  /// 已注册，token 可用
  registered,
  /// 注册失败
  failed,
}

/// 鉴权状态数据
@immutable
class AuthState {
  final AuthStatus status;
  final String? token;
  final String? deviceId;
  final String? os; // 'android' | 'ios' | 'harmonyos'
  final bool isNewDevice;
  final String? lastError;

  const AuthState({
    this.status = AuthStatus.loading,
    this.token,
    this.deviceId,
    this.os,
    this.isNewDevice = false,
    this.lastError,
  });

  /// 是否需要触发注册
  bool get needsRegistration => status == AuthStatus.fresh;

  /// 是否就绪（可发请求）
  bool get isReady => status == AuthStatus.registered;

  AuthState copyWith({
    AuthStatus? status,
    String? token,
    String? deviceId,
    String? os,
    bool? isNewDevice,
    String? lastError,
  }) {
    return AuthState(
      status: status ?? this.status,
      token: token ?? this.token,
      deviceId: deviceId ?? this.deviceId,
      os: os ?? this.os,
      isNewDevice: isNewDevice ?? this.isNewDevice,
      lastError: lastError ?? this.lastError,
    );
  }
}
```

- [ ] **Step 2: 创建 AuthDao + AuthRecord**

Create `lumira_app_flutter/lib/core/auth/auth_dao.dart`:

```dart
import 'package:sqflite/sqflite.dart';

import '../db/tables.dart';

/// 本地持久化的鉴权记录
class AuthRecord {
  final String deviceId;
  final String os;
  final String token;
  final bool isNewDevice;
  final int registeredAt;

  const AuthRecord({
    required this.deviceId,
    required this.os,
    required this.token,
    required this.isNewDevice,
    required this.registeredAt,
  });

  factory AuthRecord.fromMap(Map<String, dynamic> m) => AuthRecord(
        deviceId: m[Tables.colDeviceId] as String,
        os: m[Tables.colOs] as String,
        token: m[Tables.colToken] as String,
        isNewDevice: (m[Tables.colIsNewDevice] as int) == 1,
        registeredAt: m[Tables.colRegisteredAt] as int,
      );

  Map<String, dynamic> toMap() => {
        'id': 1,
        Tables.colDeviceId: deviceId,
        Tables.colOs: os,
        Tables.colToken: token,
        Tables.colIsNewDevice: isNewDevice ? 1 : 0,
        Tables.colRegisteredAt: registeredAt,
      };
}

/// auth 表 CRUD（单行表，id=1）
class AuthDao {
  final Database _db;
  AuthDao(this._db);

  Future<AuthRecord?> load() async {
    final rows = await _db.query(Tables.auth, where: 'id = ?', whereArgs: [1]);
    if (rows.isEmpty) return null;
    return AuthRecord.fromMap(rows.first);
  }

  Future<void> save(AuthRecord r) async {
    await _db.delete(Tables.auth, where: 'id = ?', whereArgs: [1]);
    await _db.insert(Tables.auth, r.toMap());
  }

  Future<void> clear() async {
    await _db.delete(Tables.auth, where: 'id = ?', whereArgs: [1]);
  }
}
```

- [ ] **Step 3: 加 authDaoProvider 到 database_provider.dart**

Modify `lumira_app_flutter/lib/core/db/database_provider.dart`，在顶部 import 段加：

```dart
import '../../core/auth/auth_dao.dart';
```

在文件末尾（最后一个 provider 之后）加：

```dart
final authDaoProvider = FutureProvider<AuthDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return AuthDao(db);
});
```

- [ ] **Step 4: 创建 AuthController**

Create `lumira_app_flutter/lib/core/auth/auth_controller.dart`:

```dart
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database_provider.dart';
import 'auth_dao.dart';
import 'auth_state.dart';

/// 鉴权控制器
///
/// 负责：
/// 1. 启动时从 sqflite 加载已存的 token/deviceId
/// 2. 未注册时调用 /device/register 拿新 token
/// 3. 401 失效时清除本地 token，下次启动重新注册
class AuthController extends StateNotifier<AuthState> {
  final AuthDao _dao;
  final Future<String> Function() _resolveDeviceId;
  final String Function() _resolveOs;
  final Future<({String token, bool isNewDevice})> Function({
    required String deviceId,
    required String os,
  }) _doRegister;

  AuthController({
    required AuthDao dao,
    required Future<String> Function() resolveDeviceId,
    required String Function() resolveOs,
    required Future<({String token, bool isNewDevice})> Function({
      required String deviceId,
      required String os,
    }) doRegister,
  })  : _dao = dao,
        _resolveDeviceId = resolveDeviceId,
        _resolveOs = resolveOs,
        _doRegister = doRegister,
        super(const AuthState());

  /// 当前 token（供 AuthInterceptor 注入）
  String? get currentToken => state.token;

  /// 启动加载本地 auth 状态
  Future<void> bootstrap() async {
    final saved = await _dao.load();
    if (saved == null) {
      state = const AuthState(status: AuthStatus.fresh);
    } else {
      state = AuthState(
        status: AuthStatus.registered,
        token: saved.token,
        deviceId: saved.deviceId,
        os: saved.os,
        isNewDevice: saved.isNewDevice,
      );
    }
  }

  /// 触发设备注册（仅当 fresh 状态时执行）
  Future<void> registerIfNeeded() async {
    if (state.status != AuthStatus.fresh && state.status != AuthStatus.failed) {
      return;
    }
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final deviceId = await _resolveDeviceId();
      final os = _resolveOs();
      final resp = await _doRegister(deviceId: deviceId, os: os);
      final now = DateTime.now().millisecondsSinceEpoch;
      final record = AuthRecord(
        deviceId: deviceId,
        os: os,
        token: resp.token,
        isNewDevice: resp.isNewDevice,
        registeredAt: now,
      );
      await _dao.save(record);
      state = AuthState(
        status: AuthStatus.registered,
        token: resp.token,
        deviceId: deviceId,
        os: os,
        isNewDevice: resp.isNewDevice,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.failed,
        lastError: e.toString(),
      );
    }
  }

  /// 401 失效：清除本地 token，下次启动重新注册
  void invalidateRegistration() {
    _dao.clear();
    state = const AuthState(status: AuthStatus.fresh);
  }
}

/// 默认的 deviceId 解析器
///
/// 平台分支：
/// - Android: AndroidInfo.id（系统 Settings.Secure.ANDROID_ID）
/// - iOS: IosInfo.identifierForVendor
/// - 其他（含鸿蒙 fallback）: UUID v4 持久化到 sqflite
Future<String> defaultResolveDeviceId(AuthDao dao) async {
  if (Platform.isAndroid) {
    final info = await DeviceInfoPlugin().androidInfo;
    return info.id;
  }
  if (Platform.isIOS) {
    final info = await DeviceInfoPlugin().iosInfo;
    final id = info.identifierForVendor;
    if (id != null && id.isNotEmpty) return id;
  }
  // Fallback: 复用上次生成的 UUID（存于 auth 表 deviceId 字段，os='unknown'）
  // 此处仅返回临时 UUID，由 AuthController.save 持久化
  // 注意：UUID 生成不依赖 uuid 包，用 DateTime 拼接避免新依赖
  return 'fallback-${DateTime.now().millisecondsSinceEpoch}';
}

/// 默认的 os 解析器
///
/// 注意：ohos 平台在 CPF-Flutter 3.7 环境下 Platform.operatingSystem 行为待验证
/// 通过 device_info_plus 是否能拿到 ohos 信息来判定
String defaultResolveOs() {
  if (Platform.isAndroid) {
    // 鸿蒙 CPF-Flutter 环境下，Platform 可能仍报告 android
    // 通过环境变量 HARMONY（dart-define）覆盖
    const isHarmony = bool.fromEnvironment('HARMONY', defaultValue: false);
    if (isHarmony) return 'harmonyos';
    return 'android';
  }
  if (Platform.isIOS) return 'ios';
  return 'android';
}

/// 全局 AuthController Provider
///
/// 默认实现使用 defaultResolveDeviceId / defaultResolveOs
/// 测试时通过 override 替换
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  // 注意：authDaoProvider 是 FutureProvider，需异步读取
  // 这里使用 ref.watch 配合 .future，会在第一次访问时挂起
  // 改用 lazy 模式：在 main.dart bootstrap 中显式注入 dao
  throw UnimplementedError('Use override in main.dart to provide AuthController with dao');
});
```

> **重要**：`authControllerProvider` 的实际创建发生在 `main.dart`（Task 8），因为 `AuthDao` 是 `FutureProvider`，需在 `main()` 异步 resolve 后注入。本 Task 只定义类骨架。

- [ ] **Step 5: 写 AuthController 测试**

Create `lumira_app_flutter/test/core/auth/auth_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/auth/auth_controller.dart';
import 'package:lumira_app_flutter/core/auth/auth_state.dart';

void main() {
  group('AuthController', () {
    test('initial state is loading', () {
      final ctrl = AuthController(
        dao: _FakeDao(),
        resolveDeviceId: () async => 'test-id',
        resolveOs: () => 'android',
        doRegister: ({required deviceId, required os}) async =>
            (token: 'jwt', isNewDevice: true),
      );
      expect(ctrl.state.status, AuthStatus.loading);
    });

    test('bootstrap with no saved record sets status to fresh', () async {
      final ctrl = AuthController(
        dao: _FakeDao(initialRecord: null),
        resolveDeviceId: () async => 'test-id',
        resolveOs: () => 'android',
        doRegister: ({required deviceId, required os}) async =>
            (token: 'jwt', isNewDevice: true),
      );
      await ctrl.bootstrap();
      expect(ctrl.state.status, AuthStatus.fresh);
      expect(ctrl.state.needsRegistration, true);
    });

    test('bootstrap with saved record sets status to registered', () async {
      final saved = AuthRecord(
        deviceId: 'saved-id',
        os: 'ios',
        token: 'saved-jwt',
        isNewDevice: false,
        registeredAt: 1700000000,
      );
      final ctrl = AuthController(
        dao: _FakeDao(initialRecord: saved),
        resolveDeviceId: () async => 'test-id',
        resolveOs: () => 'android',
        doRegister: ({required deviceId, required os}) async =>
            (token: 'jwt', isNewDevice: true),
      );
      await ctrl.bootstrap();
      expect(ctrl.state.status, AuthStatus.registered);
      expect(ctrl.state.isReady, true);
      expect(ctrl.state.token, 'saved-jwt');
      expect(ctrl.state.deviceId, 'saved-id');
      expect(ctrl.currentToken, 'saved-jwt');
    });

    test('registerIfNeeded from fresh state succeeds', () async {
      final ctrl = AuthController(
        dao: _FakeDao(initialRecord: null),
        resolveDeviceId: () async => 'new-id',
        resolveOs: () => 'android',
        doRegister: ({required deviceId, required os}) async =>
            (token: 'new-jwt', isNewDevice: true),
      );
      await ctrl.bootstrap();
      await ctrl.registerIfNeeded();
      expect(ctrl.state.status, AuthStatus.registered);
      expect(ctrl.state.token, 'new-jwt');
      expect(ctrl.state.isNewDevice, true);
    });

    test('registerIfNeeded on failure sets status to failed', () async {
      final ctrl = AuthController(
        dao: _FakeDao(initialRecord: null),
        resolveDeviceId: () async => 'new-id',
        resolveOs: () => 'android',
        doRegister: ({required deviceId, required os}) async {
          throw Exception('network down');
        },
      );
      await ctrl.bootstrap();
      await ctrl.registerIfNeeded();
      expect(ctrl.state.status, AuthStatus.failed);
      expect(ctrl.state.lastError, contains('network down'));
    });

    test('invalidateRegistration clears state and dao', () async {
      final saved = AuthRecord(
        deviceId: 'saved-id',
        os: 'ios',
        token: 'saved-jwt',
        isNewDevice: false,
        registeredAt: 1700000000,
      );
      final dao = _FakeDao(initialRecord: saved);
      final ctrl = AuthController(
        dao: dao,
        resolveDeviceId: () async => 'new-id',
        resolveOs: () => 'android',
        doRegister: ({required deviceId, required os}) async =>
            (token: 'jwt', isNewDevice: true),
      );
      await ctrl.bootstrap();
      ctrl.invalidateRegistration();
      expect(ctrl.state.status, AuthStatus.fresh);
      expect(ctrl.state.token, isNull);
      expect(dao.cleared, true);
    });

    test('registerIfNeeded skips when already registered', () async {
      var registerCallCount = 0;
      final saved = AuthRecord(
        deviceId: 'saved-id',
        os: 'ios',
        token: 'saved-jwt',
        isNewDevice: false,
        registeredAt: 1700000000,
      );
      final ctrl = AuthController(
        dao: _FakeDao(initialRecord: saved),
        resolveDeviceId: () async => 'new-id',
        resolveOs: () => 'android',
        doRegister: ({required deviceId, required os}) async {
          registerCallCount++;
          return (token: 'new-jwt', isNewDevice: false);
        },
      );
      await ctrl.bootstrap();
      await ctrl.registerIfNeeded();
      expect(registerCallCount, 0); // 未触发注册
      expect(ctrl.state.status, AuthStatus.registered);
      expect(ctrl.state.token, 'saved-jwt'); // 仍是旧 token
    });
  });
}

class _FakeDao implements AuthDaoLike {
  AuthRecord? _record;
  bool cleared = false;

  _FakeDao({AuthRecord? initialRecord}) : _record = initialRecord;

  @override
  Future<AuthRecord?> load() async => _record;

  @override
  Future<void> save(AuthRecord r) async {
    _record = r;
    cleared = false;
  }

  @override
  Future<void> clear() async {
    _record = null;
    cleared = true;
  }
}

// 简化的接口抽象供测试 mock（避免引入 sqflite 真实实现）
// 实际 AuthDao 类实现此接口
abstract class AuthDaoLike {
  Future<AuthRecord?> load();
  Future<void> save(AuthRecord r);
  Future<void> clear();
}
```

**注意**：测试中发现 `AuthController` 构造函数接受 `AuthDao`（具体类），但 `_FakeDao` 实现的是 `AuthDaoLike` 接口。为支持测试，**修改 Task 3 Step 2 的 `AuthDao` 类**：让它实现一个抽象接口 `AuthDaoLike`，并将 `AuthController` 的 `dao` 字段类型改为 `AuthDaoLike`。

修改 `lumira_app_flutter/lib/core/auth/auth_dao.dart`，在文件顶部 `class AuthRecord` 之前加：

```dart
/// AuthDao 抽象接口（用于测试 mock）
abstract class AuthDaoLike {
  Future<AuthRecord?> load();
  Future<void> save(AuthRecord r);
  Future<void> clear();
}
```

修改 `class AuthDao` 声明为：
```dart
class AuthDao implements AuthDaoLike {
  // ... 其余不变
}
```

修改 `lumira_app_flutter/lib/core/auth/auth_controller.dart` 中 `AuthController` 的 `_dao` 字段类型：
```dart
final AuthDaoLike _dao;
// 构造函数参数也改为 AuthDaoLike
AuthController({
  required AuthDaoLike dao,
  // ...
})
```

- [ ] **Step 6: 运行测试验证通过**

Run:
```bash
cd lumira_app_flutter
flutter test test/core/auth/auth_controller_test.dart
```
Expected: PASS（7 个测试全部通过）

- [ ] **Step 7: 验证 Task 2 + Task 3 一起 analyze 通过**

Run:
```bash
cd lumira_app_flutter
flutter analyze lib/core/network/ lib/core/auth/
```
Expected: "No issues found!"

- [ ] **Step 8: 验证所有现有测试仍通过**

Run:
```bash
cd lumira_app_flutter
flutter test
```
Expected: 所有现有测试 + 新增测试 PASS

- [ ] **Step 9: Commit**

```bash
cd lumira_app_flutter
git add lib/core/auth/ lib/core/db/database_provider.dart test/core/auth/auth_controller_test.dart
git commit -m "feat(flutter): add AuthController + AuthDao + AuthState (auth module)"
```

---

## Task 4: device 模块 — 模型 + Repository

**Files:**
- Create: `lumira_app_flutter/lib/features/device/data/device_models.dart`
- Create: `lumira_app_flutter/lib/features/device/data/device_repository.dart`
- Test: `lumira_app_flutter/test/features/device/data/device_repository_test.dart`

**Interfaces:**
- Consumes: `ApiClient`（from Task 2）
- Produces: `DeviceOs` 枚举、`RegisterDeviceRequest`、`RegisterDeviceResponse`、`DeviceRecord`
- Produces: `DeviceRepository`（abstract）、`RemoteDeviceRepository`（impl）
- Produces: `deviceRepositoryProvider`（依赖 `apiClientProvider`）

- [ ] **Step 1: 创建 device_models.dart**

Create `lumira_app_flutter/lib/features/device/data/device_models.dart`:

```dart
import 'package:flutter/foundation.dart';

/// 设备操作系统
///
/// 后端契约：'android' | 'ios' | 'harmonyos'（字符串）
enum DeviceOs {
  android,
  ios,
  harmonyos,
}

extension DeviceOsExt on DeviceOs {
  String toJson() {
    switch (this) {
      case DeviceOs.android:
        return 'android';
      case DeviceOs.ios:
        return 'ios';
      case DeviceOs.harmonyos:
        return 'harmonyos';
    }
  }

  static DeviceOs fromJson(String s) {
    switch (s) {
      case 'android':
        return DeviceOs.android;
      case 'ios':
        return DeviceOs.ios;
      case 'harmonyos':
        return DeviceOs.harmonyos;
      default:
        return DeviceOs.android;
    }
  }
}

/// POST /api/v1/device/register 请求体
@immutable
class RegisterDeviceRequest {
  final String deviceId;
  final DeviceOs os;

  const RegisterDeviceRequest({required this.deviceId, required this.os});

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'os': os.toJson(),
      };
}

/// POST /api/v1/device/register 响应体
///
/// 后端契约：{ token: string, isNewDevice: boolean }
@immutable
class RegisterDeviceResponse {
  final String token;
  final bool isNewDevice;

  const RegisterDeviceResponse({
    required this.token,
    required this.isNewDevice,
  });

  factory RegisterDeviceResponse.fromJson(Map<String, dynamic> j) {
    return RegisterDeviceResponse(
      token: j['token'] as String,
      isNewDevice: j['isNewDevice'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'isNewDevice': isNewDevice,
      };
}

/// GET /api/v1/device/:id 响应体（管理员端点，Flutter 不主动调用，留作未来扩展）
@immutable
class DeviceRecord {
  final String deviceId;
  final String? alias;
  final int firstSeenAt;
  final int lastSeenAt;
  final String? ipRegion;

  const DeviceRecord({
    required this.deviceId,
    this.alias,
    required this.firstSeenAt,
    required this.lastSeenAt,
    this.ipRegion,
  });

  factory DeviceRecord.fromJson(Map<String, dynamic> j) {
    return DeviceRecord(
      deviceId: j['deviceId'] as String,
      alias: j['alias'] as String?,
      firstSeenAt: j['firstSeenAt'] as int,
      lastSeenAt: j['lastSeenAt'] as int,
      ipRegion: j['ipRegion'] as String?,
    );
  }
}
```

- [ ] **Step 2: 创建 device_repository.dart**

Create `lumira_app_flutter/lib/features/device/data/device_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'device_models.dart';

/// 设备 Repository 抽象
abstract class DeviceRepository {
  /// POST /device/register
  ///
  /// 注册设备并获取 JWT token
  Future<RegisterDeviceResponse> register(RegisterDeviceRequest req);
}

/// 远程实现（直接调用后端，无离线回退）
class RemoteDeviceRepository implements DeviceRepository {
  final ApiClient _api;

  RemoteDeviceRepository(this._api);

  @override
  Future<RegisterDeviceResponse> register(RegisterDeviceRequest req) async {
    return _api.post(
      '/device/register',
      body: req.toJson(),
      fromJson: (j) => RegisterDeviceResponse.fromJson(j as Map<String, dynamic>),
    );
  }
}

/// 全局 Provider
///
/// 注意：依赖 apiClientProvider（FutureProvider），故 repository 也是 FutureProvider
final deviceRepositoryProvider = FutureProvider<DeviceRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return RemoteDeviceRepository(api);
});
```

- [ ] **Step 3: 写 device_repository_test.dart**

Create `lumira_app_flutter/test/features/device/data/device_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/device/data/device_models.dart';
import 'package:lumira_app_flutter/features/device/data/device_repository.dart';

class _FakeApiClient {
  final Map<String, dynamic> _registerResponse;

  _FakeApiClient(this._registerResponse);

  Future<T> post<T>(
    String path, {
    Object? body,
    required T Function(Object? json) fromJson,
  }) async {
    expect(path, '/device/register');
    final bodyMap = body as Map<String, dynamic>;
    expect(bodyMap['deviceId'], 'dev-123');
    expect(bodyMap['os'], 'android');
    return fromJson(_registerResponse);
  }
}

void main() {
  group('RemoteDeviceRepository', () {
    test('register sends correct request and parses response', () async {
      final fakeApi = _FakeApiClient({
        'token': 'jwt-abc',
        'isNewDevice': true,
      });
      final repo = RemoteDeviceRepository(fakeApi as dynamic);
      final resp = await repo.register(const RegisterDeviceRequest(
        deviceId: 'dev-123',
        os: DeviceOs.android,
      ));
      expect(resp.token, 'jwt-abc');
      expect(resp.isNewDevice, true);
    });
  });

  group('DeviceOsExt', () {
    test('toJson returns correct string', () {
      expect(DeviceOs.android.toJson(), 'android');
      expect(DeviceOs.ios.toJson(), 'ios');
      expect(DeviceOs.harmonyos.toJson(), 'harmonyos');
    });

    test('fromJson parses correctly', () {
      expect(DeviceOsExt.fromJson('android'), DeviceOs.android);
      expect(DeviceOsExt.fromJson('ios'), DeviceOs.ios);
      expect(DeviceOsExt.fromJson('harmonyos'), DeviceOs.harmonyos);
      expect(DeviceOsExt.fromJson('unknown'), DeviceOs.android); // fallback
    });
  });

  group('RegisterDeviceRequest', () {
    test('toJson includes os string', () {
      const req = RegisterDeviceRequest(
        deviceId: 'dev-1',
        os: DeviceOs.harmonyos,
      );
      final j = req.toJson();
      expect(j['deviceId'], 'dev-1');
      expect(j['os'], 'harmonyos');
    });
  });

  group('RegisterDeviceResponse', () {
    test('fromJson parses correctly', () {
      final resp = RegisterDeviceResponse.fromJson({
        'token': 'jwt-xyz',
        'isNewDevice': false,
      });
      expect(resp.token, 'jwt-xyz');
      expect(resp.isNewDevice, false);
    });
  });
}
```

- [ ] **Step 4: 运行测试验证通过**

Run:
```bash
cd lumira_app_flutter
flutter test test/features/device/data/device_repository_test.dart
```
Expected: PASS（5 个测试全部通过）

- [ ] **Step 5: 验证 analyze**

Run:
```bash
cd lumira_app_flutter
flutter analyze lib/features/device/
```
Expected: "No issues found!"

- [ ] **Step 6: Commit**

```bash
cd lumira_app_flutter
git add lib/features/device/ test/features/device/
git commit -m "feat(flutter): add device module (models + RemoteRepository + register endpoint)"
```

---

## Task 5: invite 模块 — 模型 + Repository + 离线回退

**Files:**
- Create: `lumira_app_flutter/lib/features/invite/data/invite_models.dart`
- Create: `lumira_app_flutter/lib/features/invite/data/invite_repository.dart`
- Create: `lumira_app_flutter/lib/core/db/dao/api_cache_dao.dart`
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart` (加 apiCacheDaoProvider)
- Test: `lumira_app_flutter/test/features/invite/data/invite_repository_test.dart`

**Interfaces:**
- Consumes: `ApiClient`（from Task 2）、`ApiCacheDao`（本 Task 新建）
- Consumes: `RewardItem` / `UnlockedReward`（from Task 7，**需先看 Task 7 是否已存在；若未存在，本 Task 临时定义在 invite_models.dart 内部**）
- Produces: `InviteChannel`、`ActivateInviteRequest`、`ActivateInviteResponse`、`InviteStats`、`InviteCode`
- Produces: `InviteRepository`（abstract）、`RemoteInviteRepository`（含离线回退）
- Produces: `inviteRepositoryProvider`

**依赖说明**：invite / redeem / rewards 共享 `RewardItem` / `UnlockedReward` 类型。为避免循环依赖，**这些类型定义在 `rewards_models.dart`**（Task 7），invite/redeem 通过 `import` 复用。**因此 Task 5 / 6 / 7 中 rewards（Task 7）应优先创建**。

**调整执行顺序**：先做 Task 7（rewards 模型），再做 Task 5（invite）、Task 6（redeem）。

- [ ] **Step 1: 创建 ApiCacheDao**

Create `lumira_app_flutter/lib/core/db/dao/api_cache_dao.dart`:

```dart
import 'package:sqflite/sqflite.dart';

import '../tables.dart';

/// 通用 API 响应缓存（key-value JSON）
///
/// 用于离线回退：每个远程 Repository 调用成功后 save，
/// 网络失败时 load 返回上次缓存的 payload
class ApiCacheDao {
  final Database _db;
  ApiCacheDao(this._db);

  Future<String?> load(String key) async {
    final rows = await _db.query(
      Tables.apiCache,
      where: '${Tables.colKey} = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first[Tables.colPayload] as String;
  }

  Future<void> save(String key, String payload) async {
    await _db.delete(Tables.apiCache, where: '${Tables.colKey} = ?', whereArgs: [key]);
    await _db.insert(Tables.apiCache, {
      Tables.colKey: key,
      Tables.colPayload: payload,
      Tables.colCachedAt: DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> clear(String key) async {
    await _db.delete(Tables.apiCache, where: '${Tables.colKey} = ?', whereArgs: [key]);
  }
}
```

- [ ] **Step 2: 加 apiCacheDaoProvider 到 database_provider.dart**

Modify `lumira_app_flutter/lib/core/db/database_provider.dart`，在顶部 import 段加：

```dart
import 'dao/api_cache_dao.dart';
```

在文件末尾加：

```dart
final apiCacheDaoProvider = FutureProvider<ApiCacheDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ApiCacheDao(db);
});
```

- [ ] **Step 3: 创建 invite_models.dart**

Create `lumira_app_flutter/lib/features/invite/data/invite_models.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../../rewards/data/rewards_models.dart';

/// 邀请激活渠道
enum InviteChannel {
  direct,
  shareCard,
  qrcode,
}

extension InviteChannelExt on InviteChannel {
  String toJson() {
    switch (this) {
      case InviteChannel.direct:
        return 'direct';
      case InviteChannel.shareCard:
        return 'share_card';
      case InviteChannel.qrcode:
        return 'qrcode';
    }
  }

  static InviteChannel? fromJson(String? s) {
    switch (s) {
      case 'direct':
        return InviteChannel.direct;
      case 'share_card':
        return InviteChannel.shareCard;
      case 'qrcode':
        return InviteChannel.qrcode;
      default:
        return null;
    }
  }
}

/// POST /invite/activate 请求体
@immutable
class ActivateInviteRequest {
  final String inviteCode;
  final InviteChannel? channel;

  const ActivateInviteRequest({required this.inviteCode, this.channel});

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'inviteCode': inviteCode};
    if (channel != null) m['channel'] = channel!.toJson();
    return m;
  }
}

/// 激活后奖励元组
@immutable
class ActivateRewards {
  final int tier;
  final List<RewardItem> items;

  const ActivateRewards({required this.tier, required this.items});

  factory ActivateRewards.fromJson(Map<String, dynamic> j) {
    final itemsRaw = j['items'] as List<dynamic>;
    return ActivateRewards(
      tier: j['tier'] as int,
      items: itemsRaw.map((e) => RewardItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// POST /invite/activate 响应体
@immutable
class ActivateInviteResponse {
  final String inviterDeviceId;
  final int? tierReached;
  final ActivateRewards? rewards;

  const ActivateInviteResponse({
    required this.inviterDeviceId,
    this.tierReached,
    this.rewards,
  });

  factory ActivateInviteResponse.fromJson(Map<String, dynamic> j) {
    final rewardsRaw = j['rewards'] as Map<String, dynamic>?;
    return ActivateInviteResponse(
      inviterDeviceId: j['inviterDeviceId'] as String,
      tierReached: j['tierReached'] as int?,
      rewards: rewardsRaw == null ? null : ActivateRewards.fromJson(rewardsRaw),
    );
  }
}

/// 下一档邀请奖励
@immutable
class NextInviteTier {
  final int tier;
  final int requiredInvites;
  final List<RewardItem> rewards;

  const NextInviteTier({
    required this.tier,
    required this.requiredInvites,
    required this.rewards,
  });

  factory NextInviteTier.fromJson(Map<String, dynamic> j) {
    final rewardsRaw = j['rewards'] as List<dynamic>;
    return NextInviteTier(
      tier: j['tier'] as int,
      requiredInvites: j['requiredInvites'] as int,
      rewards: rewardsRaw.map((e) => RewardItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// GET /invite/stats 响应体
@immutable
class InviteStats {
  final int totalInvites;
  final int currentTier;
  final NextInviteTier? nextTier;
  final List<UnlockedReward> unlockedRewards;

  const InviteStats({
    required this.totalInvites,
    required this.currentTier,
    this.nextTier,
    required this.unlockedRewards,
  });

  factory InviteStats.fromJson(Map<String, dynamic> j) {
    final nextTierRaw = j['nextTier'] as Map<String, dynamic>?;
    final unlockedRaw = j['unlockedRewards'] as List<dynamic>;
    return InviteStats(
      totalInvites: j['totalInvites'] as int,
      currentTier: j['currentTier'] as int,
      nextTier: nextTierRaw == null ? null : NextInviteTier.fromJson(nextTierRaw),
      unlockedRewards:
          unlockedRaw.map((e) => UnlockedReward.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'totalInvites': totalInvites,
        'currentTier': currentTier,
        'nextTier': nextTier == null
            ? null
            : {
                'tier': nextTier!.tier,
                'requiredInvites': nextTier!.requiredInvites,
                'rewards': nextTier!.rewards.map((r) => r.toJson()).toList(),
              },
        'unlockedRewards': unlockedRewards.map((r) => r.toJson()).toList(),
      };
}

/// POST /invite/generate 响应体
@immutable
class InviteCode {
  final String code;

  const InviteCode({required this.code});

  factory InviteCode.fromJson(Map<String, dynamic> j) {
    return InviteCode(code: j['inviteCode'] as String);
  }
}
```

- [ ] **Step 4: 创建 invite_repository.dart**

Create `lumira_app_flutter/lib/features/invite/data/invite_repository.dart`:

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/db/dao/api_cache_dao.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import 'invite_models.dart';

/// 邀请 Repository 抽象
abstract class InviteRepository {
  /// POST /invite/generate
  Future<InviteCode> generateCode();

  /// POST /invite/activate
  Future<ActivateInviteResponse> activate(ActivateInviteRequest req);

  /// GET /invite/stats
  ///
  /// 离线回退：网络失败时返回上次缓存的 stats
  Future<InviteStats> getStats();
}

/// 远程实现（getStats 离线回退缓存）
class RemoteInviteRepository implements InviteRepository {
  final ApiClient _api;
  final ApiCacheDao _cache;

  static const _kCacheKeyStats = 'invite_stats';

  RemoteInviteRepository({
    required ApiClient api,
    required ApiCacheDao cache,
  })  : _api = api,
        _cache = cache;

  @override
  Future<InviteCode> generateCode() async {
    return _api.post(
      '/invite/generate',
      fromJson: (j) => InviteCode.fromJson(j as Map<String, dynamic>),
    );
  }

  @override
  Future<ActivateInviteResponse> activate(ActivateInviteRequest req) async {
    return _api.post(
      '/invite/activate',
      body: req.toJson(),
      fromJson: (j) => ActivateInviteResponse.fromJson(j as Map<String, dynamic>),
    );
  }

  @override
  Future<InviteStats> getStats() async {
    try {
      final stats = await _api.get(
        '/invite/stats',
        fromJson: (j) => InviteStats.fromJson(j as Map<String, dynamic>),
      );
      // 缓存最新结果
      await _cache.save(_kCacheKeyStats, jsonEncode(stats.toJson()));
      return stats;
    } on ApiException catch (e) {
      if (e.isNetworkError) {
        final cached = await _cache.load(_kCacheKeyStats);
        if (cached != null) {
          return InviteStats.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        }
      }
      rethrow;
    }
  }
}

/// 全局 Provider
final inviteRepositoryProvider = FutureProvider<InviteRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  final cache = await ref.watch(apiCacheDaoProvider.future);
  return RemoteInviteRepository(api: api, cache: cache);
});
```

- [ ] **Step 5: 写 invite_repository_test.dart**

Create `lumira_app_flutter/test/features/invite/data/invite_repository_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/network/api_error.dart';
import 'package:lumira_app_flutter/features/invite/data/invite_models.dart';
import 'package:lumira_app_flutter/features/invite/data/invite_repository.dart';
import 'package:lumira_app_flutter/features/rewards/data/rewards_models.dart';

class _FakeApi {
  InviteStats? statsResponse;
  dynamic statsError;
  int statsCallCount = 0;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Object? json) fromJson,
  }) async {
    if (path == '/invite/stats') {
      statsCallCount++;
      if (statsError != null) throw statsError;
      if (statsResponse != null) return fromJson(statsResponse!.toJson()) as T;
    }
    throw UnimplementedError('GET $path');
  }

  Future<T> post<T>(
    String path, {
    Object? body,
    required T Function(Object? json) fromJson,
  }) async {
    throw UnimplementedError('POST $path');
  }
}

class _FakeCacheDao {
  final Map<String, String> _store = {};

  Future<String?> load(String key) async => _store[key];
  Future<void> save(String key, String payload) async => _store[key] = payload;
  Future<void> clear(String key) async => _store.remove(key);
}

void main() {
  group('InviteChannelExt', () {
    test('toJson returns snake_case', () {
      expect(InviteChannel.direct.toJson(), 'direct');
      expect(InviteChannel.shareCard.toJson(), 'share_card');
      expect(InviteChannel.qrcode.toJson(), 'qrcode');
    });

    test('fromJson parses correctly', () {
      expect(InviteChannelExt.fromJson('direct'), InviteChannel.direct);
      expect(InviteChannelExt.fromJson('share_card'), InviteChannel.shareCard);
      expect(InviteChannelExt.fromJson('qrcode'), InviteChannel.qrcode);
      expect(InviteChannelExt.fromJson(null), isNull);
      expect(InviteChannelExt.fromJson('unknown'), isNull);
    });
  });

  group('ActivateInviteRequest', () {
    test('toJson omits null channel', () {
      const req = ActivateInviteRequest(inviteCode: 'ABC');
      expect(req.toJson(), {'inviteCode': 'ABC'});
    });

    test('toJson includes channel when set', () {
      const req = ActivateInviteRequest(
        inviteCode: 'ABC',
        channel: InviteChannel.qrcode,
      );
      expect(req.toJson(), {'inviteCode': 'ABC', 'channel': 'qrcode'});
    });
  });

  group('InviteStats parsing', () {
    test('parses full response', () {
      final stats = InviteStats.fromJson({
        'totalInvites': 5,
        'currentTier': 2,
        'nextTier': {
          'tier': 3,
          'requiredInvites': 10,
          'rewards': [
            {'type': 'template', 'id': 'tpl-1', 'label': 'Template 1'}
          ],
        },
        'unlockedRewards': [
          {
            'id': 1,
            'tier': 1,
            'source': 'invite',
            'sourceDetail': null,
            'status': 'unlocked',
            'rewardItems': [
              {'type': 'template', 'id': 'tpl-0', 'label': 'Template 0'}
            ],
            'unlockedAt': 1700000000,
            'claimedAt': null,
          }
        ],
      });
      expect(stats.totalInvites, 5);
      expect(stats.currentTier, 2);
      expect(stats.nextTier?.tier, 3);
      expect(stats.nextTier?.rewards.length, 1);
      expect(stats.unlockedRewards.length, 1);
      expect(stats.unlockedRewards.first.id, 1);
      expect(stats.unlockedRewards.first.status, UnlockStatus.unlocked);
    });
  });

  group('RemoteInviteRepository.getStats offline fallback', () {
    test('returns cached stats on network error', () async {
      final api = _FakeApi()
        ..statsError = const ApiException(ApiErrorKind.network, 'timeout');
      final cache = _FakeCacheDao();
      // 预存缓存
      final cachedStats = InviteStats(
        totalInvites: 3,
        currentTier: 1,
        nextTier: null,
        unlockedRewards: [],
      );
      await cache.save('invite_stats', jsonEncode(cachedStats.toJson()));

      final repo = RemoteInviteRepository(
        api: api as dynamic,
        cache: cache as dynamic,
      );
      final result = await repo.getStats();
      expect(result.totalInvites, 3);
      expect(api.statsCallCount, 1);
    });

    test('rethrows non-network errors', () async {
      final api = _FakeApi()
        ..statsError = const ApiException(ApiErrorKind.server, '500');
      final cache = _FakeCacheDao();

      final repo = RemoteInviteRepository(
        api: api as dynamic,
        cache: cache as dynamic,
      );
      expect(
        () => repo.getStats(),
        throwsA(isA<ApiException>()),
      );
    });

    test('rethrows when no cache available', () async {
      final api = _FakeApi()
        ..statsError = const ApiException(ApiErrorKind.network, 'timeout');
      final cache = _FakeCacheDao();

      final repo = RemoteInviteRepository(
        api: api as dynamic,
        cache: cache as dynamic,
      );
      expect(
        () => repo.getStats(),
        throwsA(isA<ApiException>()),
      );
    });

    test('saves cache on successful call', () async {
      final api = _FakeApi()
        ..statsResponse = InviteStats(
          totalInvites: 7,
          currentTier: 2,
          nextTier: null,
          unlockedRewards: [],
        );
      final cache = _FakeCacheDao();

      final repo = RemoteInviteRepository(
        api: api as dynamic,
        cache: cache as dynamic,
      );
      await repo.getStats();
      final cached = await cache.load('invite_stats');
      expect(cached, isNotNull);
      final decoded = jsonDecode(cached!) as Map<String, dynamic>;
      expect(decoded['totalInvites'], 7);
    });
  });
}
```

- [ ] **Step 6: 运行测试验证失败**

Run:
```bash
cd lumira_app_flutter
flutter test test/features/invite/data/invite_repository_test.dart
```
Expected: FAIL（Task 7 的 `rewards_models.dart` 不存在）

**因此先做 Task 7（rewards 模块），完成后再回头跑 Task 5 测试。**

- [ ] **Step 7: Commit（暂不验证，留待 Task 7 完成后验证）**

```bash
cd lumira_app_flutter
git add lib/core/db/dao/api_cache_dao.dart lib/core/db/database_provider.dart lib/features/invite/ test/features/invite/
git commit -m "feat(flutter): add invite module (models + RemoteRepository with offline fallback)"
```

---

## Task 6: redeem 模块 — 模型 + Repository

**Files:**
- Create: `lumira_app_flutter/lib/features/redeem/data/redeem_models.dart`
- Create: `lumira_app_flutter/lib/features/redeem/data/redeem_repository.dart`
- Test: `lumira_app_flutter/test/features/redeem/data/redeem_repository_test.dart`

**Interfaces:**
- Consumes: `ApiClient`（from Task 2）
- Consumes: `RewardItem`（from Task 7）
- Produces: `RedeemCodeRequest`、`RedeemCodeResponse`
- Produces: `RedeemRepository`（abstract）、`RemoteRedeemRepository`
- Produces: `redeemRepositoryProvider`

- [ ] **Step 1: 创建 redeem_models.dart**

Create `lumira_app_flutter/lib/features/redeem/data/redeem_models.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../../rewards/data/rewards_models.dart';

/// POST /redeem/code 请求体
@immutable
class RedeemCodeRequest {
  final String code;

  const RedeemCodeRequest({required this.code});

  Map<String, dynamic> toJson() => {'code': code};
}

/// POST /redeem/code 响应体
@immutable
class RedeemCodeResponse {
  final int batchId;
  final String campaignName;
  final int rewardTier;
  final List<RewardItem> rewardItems;

  const RedeemCodeResponse({
    required this.batchId,
    required this.campaignName,
    required this.rewardTier,
    required this.rewardItems,
  });

  factory RedeemCodeResponse.fromJson(Map<String, dynamic> j) {
    final itemsRaw = j['rewardItems'] as List<dynamic>;
    return RedeemCodeResponse(
      batchId: j['batchId'] as int,
      campaignName: j['campaignName'] as String,
      rewardTier: j['rewardTier'] as int,
      rewardItems: itemsRaw.map((e) => RewardItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
```

- [ ] **Step 2: 创建 redeem_repository.dart**

Create `lumira_app_flutter/lib/features/redeem/data/redeem_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'redeem_models.dart';

/// 兑换码 Repository 抽象
abstract class RedeemRepository {
  /// POST /redeem/code
  ///
  /// 提交类操作，无离线回退
  Future<RedeemCodeResponse> redeem(RedeemCodeRequest req);
}

class RemoteRedeemRepository implements RedeemRepository {
  final ApiClient _api;

  RemoteRedeemRepository(this._api);

  @override
  Future<RedeemCodeResponse> redeem(RedeemCodeRequest req) async {
    return _api.post(
      '/redeem/code',
      body: req.toJson(),
      fromJson: (j) => RedeemCodeResponse.fromJson(j as Map<String, dynamic>),
    );
  }
}

final redeemRepositoryProvider = FutureProvider<RedeemRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return RemoteRedeemRepository(api);
});
```

- [ ] **Step 3: 写 redeem_repository_test.dart**

Create `lumira_app_flutter/test/features/redeem/data/redeem_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/redeem/data/redeem_models.dart';
import 'package:lumira_app_flutter/features/redeem/data/redeem_repository.dart';
import 'package:lumira_app_flutter/features/rewards/data/rewards_models.dart';

class _FakeApi {
  final Map<String, dynamic> _redeemResponse;

  _FakeApi(this._redeemResponse);

  Future<T> post<T>(
    String path, {
    Object? body,
    required T Function(Object? json) fromJson,
  }) async {
    expect(path, '/redeem/code');
    final bodyMap = body as Map<String, dynamic>;
    expect(bodyMap['code'], 'ABC123');
    return fromJson(_redeemResponse);
  }
}

void main() {
  group('RedeemCodeRequest', () {
    test('toJson wraps code', () {
      const req = RedeemCodeRequest(code: 'XYZ');
      expect(req.toJson(), {'code': 'XYZ'});
    });
  });

  group('RedeemCodeResponse.fromJson', () {
    test('parses correctly', () {
      final resp = RedeemCodeResponse.fromJson({
        'batchId': 42,
        'campaignName': 'Spring Campaign',
        'rewardTier': 1,
        'rewardItems': [
          {'type': 'template', 'id': 'tpl-1', 'label': 'Spring Template'},
          {'type': 'achievement', 'id': 'ach-1', 'label': 'Spring Achievement'},
        ],
      });
      expect(resp.batchId, 42);
      expect(resp.campaignName, 'Spring Campaign');
      expect(resp.rewardTier, 1);
      expect(resp.rewardItems.length, 2);
      expect(resp.rewardItems.first.type, RewardType.template);
      expect(resp.rewardItems.last.type, RewardType.achievement);
    });
  });

  group('RemoteRedeemRepository', () {
    test('redeem sends request and parses response', () async {
      final fakeApi = _FakeApi({
        'batchId': 1,
        'campaignName': 'Test',
        'rewardTier': 0,
        'rewardItems': [],
      });
      final repo = RemoteRedeemRepository(fakeApi as dynamic);
      final resp = await repo.redeem(const RedeemCodeRequest(code: 'ABC123'));
      expect(resp.batchId, 1);
      expect(resp.campaignName, 'Test');
      expect(resp.rewardItems, isEmpty);
    });
  });
}
```

- [ ] **Step 4: Commit（暂不验证，留待 Task 7 完成后统一验证）**

```bash
cd lumira_app_flutter
git add lib/features/redeem/ test/features/redeem/
git commit -m "feat(flutter): add redeem module (models + RemoteRepository)"
```

---

## Task 7: rewards 模块 — 共享模型 + Repository + 离线回退

**Files:**
- Create: `lumira_app_flutter/lib/features/rewards/data/rewards_models.dart`
- Create: `lumira_app_flutter/lib/features/rewards/data/rewards_repository.dart`
- Test: `lumira_app_flutter/test/features/rewards/data/rewards_repository_test.dart`

**Interfaces:**
- Consumes: `ApiClient`（from Task 2）、`ApiCacheDao`（from Task 5）
- Produces: `RewardType`、`RewardSource`、`UnlockStatus`、`RewardItem`、`UnlockedReward`、`RewardsList`、`ClaimResult`
- Produces: `RewardsRepository`（abstract）、`RemoteRewardsRepository`（含离线回退）
- Produces: `rewardsRepositoryProvider`

**注意**：本 Task 的模型被 Task 5（invite）和 Task 6（redeem）依赖。**实施时本 Task 应在 Task 5/6 之前完成**。

- [ ] **Step 1: 创建 rewards_models.dart**

Create `lumira_app_flutter/lib/features/rewards/data/rewards_models.dart`:

```dart
import 'package:flutter/foundation.dart';

/// 奖励类型
///
/// 后端契约：'template' | 'template_pack' | 'achievement'
enum RewardType {
  template,
  templatePack,
  achievement,
}

extension RewardTypeExt on RewardType {
  String toJson() {
    switch (this) {
      case RewardType.template:
        return 'template';
      case RewardType.templatePack:
        return 'template_pack';
      case RewardType.achievement:
        return 'achievement';
    }
  }

  static RewardType fromJson(String s) {
    switch (s) {
      case 'template':
        return RewardType.template;
      case 'template_pack':
        return RewardType.templatePack;
      case 'achievement':
        return RewardType.achievement;
      default:
        return RewardType.template;
    }
  }
}

/// 奖励来源
enum RewardSource {
  invite,
  redemption,
}

extension RewardSourceExt on RewardSource {
  String toJson() {
    switch (this) {
      case RewardSource.invite:
        return 'invite';
      case RewardSource.redemption:
        return 'redemption';
    }
  }

  static RewardSource fromJson(String s) {
    switch (s) {
      case 'invite':
        return RewardSource.invite;
      case 'redemption':
        return RewardSource.redemption;
      default:
        return RewardSource.invite;
    }
  }
}

/// 解锁/领取状态
enum UnlockStatus {
  unlocked,
  claimed,
}

extension UnlockStatusExt on UnlockStatus {
  String toJson() {
    switch (this) {
      case UnlockStatus.unlocked:
        return 'unlocked';
      case UnlockStatus.claimed:
        return 'claimed';
    }
  }

  static UnlockStatus fromJson(String s) {
    switch (s) {
      case 'unlocked':
        return UnlockStatus.unlocked;
      case 'claimed':
        return UnlockStatus.claimed;
      default:
        return UnlockStatus.unlocked;
    }
  }
}

/// 单个奖励项
@immutable
class RewardItem {
  final RewardType type;
  final String id;
  final String label;

  const RewardItem({
    required this.type,
    required this.id,
    required this.label,
  });

  factory RewardItem.fromJson(Map<String, dynamic> j) => RewardItem(
        type: RewardTypeExt.fromJson(j['type'] as String),
        id: j['id'] as String,
        label: j['label'] as String,
      );

  Map<String, dynamic> toJson() => {
        'type': type.toJson(),
        'id': id,
        'label': label,
      };
}

/// 已解锁的奖励（包含一项或多项 RewardItem）
@immutable
class UnlockedReward {
  final int id;
  final int tier;
  final RewardSource source;
  final String? sourceDetail;
  final UnlockStatus status;
  final List<RewardItem> rewardItems;
  final int unlockedAt;
  final int? claimedAt;

  const UnlockedReward({
    required this.id,
    required this.tier,
    required this.source,
    this.sourceDetail,
    required this.status,
    required this.rewardItems,
    required this.unlockedAt,
    this.claimedAt,
  });

  factory UnlockedReward.fromJson(Map<String, dynamic> j) {
    final itemsRaw = j['rewardItems'] as List<dynamic>;
    return UnlockedReward(
      id: j['id'] as int,
      tier: j['tier'] as int,
      source: RewardSourceExt.fromJson(j['source'] as String),
      sourceDetail: j['sourceDetail'] as String?,
      status: UnlockStatusExt.fromJson(j['status'] as String),
      rewardItems: itemsRaw.map((e) => RewardItem.fromJson(e as Map<String, dynamic>)).toList(),
      unlockedAt: j['unlockedAt'] as int,
      claimedAt: j['claimedAt'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tier': tier,
        'source': source.toJson(),
        'sourceDetail': sourceDetail,
        'status': status.toJson(),
        'rewardItems': rewardItems.map((r) => r.toJson()).toList(),
        'unlockedAt': unlockedAt,
        'claimedAt': claimedAt,
      };
}

/// GET /rewards 响应体
@immutable
class RewardsList {
  final List<UnlockedReward> rewards;

  const RewardsList({required this.rewards});

  factory RewardsList.fromJson(Map<String, dynamic> j) {
    final rewardsRaw = j['rewards'] as List<dynamic>;
    return RewardsList(
      rewards: rewardsRaw.map((e) => UnlockedReward.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'rewards': rewards.map((r) => r.toJson()).toList(),
      };
}

/// POST /rewards/:id/claim 响应体
@immutable
class ClaimResult {
  final bool success;

  const ClaimResult({required this.success});

  factory ClaimResult.fromJson(Map<String, dynamic> j) {
    return ClaimResult(success: j['success'] as bool);
  }
}
```

- [ ] **Step 2: 创建 rewards_repository.dart**

Create `lumira_app_flutter/lib/features/rewards/data/rewards_repository.dart`:

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/api_cache_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import 'rewards_models.dart';

/// 奖励 Repository 抽象
abstract class RewardsRepository {
  /// GET /rewards
  ///
  /// 离线回退：网络失败时返回上次缓存的列表
  Future<RewardsList> list();

  /// POST /rewards/:id/claim
  ///
  /// 提交类操作，无离线回退
  Future<ClaimResult> claim(int id);
}

class RemoteRewardsRepository implements RewardsRepository {
  final ApiClient _api;
  final ApiCacheDao _cache;

  static const _kCacheKeyList = 'rewards_list';

  RemoteRewardsRepository({
    required ApiClient api,
    required ApiCacheDao cache,
  })  : _api = api,
        _cache = cache;

  @override
  Future<RewardsList> list() async {
    try {
      final list = await _api.get(
        '/rewards',
        fromJson: (j) => RewardsList.fromJson(j as Map<String, dynamic>),
      );
      await _cache.save(_kCacheKeyList, jsonEncode(list.toJson()));
      return list;
    } on ApiException catch (e) {
      if (e.isNetworkError) {
        final cached = await _cache.load(_kCacheKeyList);
        if (cached != null) {
          return RewardsList.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        }
      }
      rethrow;
    }
  }

  @override
  Future<ClaimResult> claim(int id) async {
    return _api.post(
      '/rewards/$id/claim',
      fromJson: (j) => ClaimResult.fromJson(j as Map<String, dynamic>),
    );
  }
}

final rewardsRepositoryProvider = FutureProvider<RewardsRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  final cache = await ref.watch(apiCacheDaoProvider.future);
  return RemoteRewardsRepository(api: api, cache: cache);
});
```

- [ ] **Step 3: 写 rewards_repository_test.dart**

Create `lumira_app_flutter/test/features/rewards/data/rewards_repository_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/network/api_error.dart';
import 'package:lumira_app_flutter/features/rewards/data/rewards_models.dart';
import 'package:lumira_app_flutter/features/rewards/data/rewards_repository.dart';

class _FakeApi {
  RewardsList? listResponse;
  Map<int, ClaimResult>? claimResponses;
  dynamic listError;
  int listCallCount = 0;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Object? json) fromJson,
  }) async {
    if (path == '/rewards') {
      listCallCount++;
      if (listError != null) throw listError;
      if (listResponse != null) return fromJson(listResponse!.toJson()) as T;
    }
    throw UnimplementedError('GET $path');
  }

  Future<T> post<T>(
    String path, {
    Object? body,
    required T Function(Object? json) fromJson,
  }) async {
    if (path.startsWith('/rewards/') && path.endsWith('/claim')) {
      final idStr = path.split('/')[2];
      final id = int.parse(idStr);
      final resp = claimResponses?[id];
      if (resp != null) return fromJson({'success': resp.success}) as T;
    }
    throw UnimplementedError('POST $path');
  }
}

class _FakeCacheDao {
  final Map<String, String> _store = {};

  Future<String?> load(String key) async => _store[key];
  Future<void> save(String key, String payload) async => _store[key] = payload;
  Future<void> clear(String key) async => _store.remove(key);
}

void main() {
  group('RewardType / RewardSource / UnlockStatus ext', () {
    test('toJson/fromJson round trip', () {
      expect(RewardTypeExt.fromJson(RewardType.template.toJson()), RewardType.template);
      expect(RewardTypeExt.fromJson(RewardType.templatePack.toJson()), RewardType.templatePack);
      expect(RewardTypeExt.fromJson(RewardType.achievement.toJson()), RewardType.achievement);
      expect(RewardTypeExt.fromJson('unknown'), RewardType.template);

      expect(RewardSourceExt.fromJson(RewardSource.invite.toJson()), RewardSource.invite);
      expect(RewardSourceExt.fromJson(RewardSource.redemption.toJson()), RewardSource.redemption);

      expect(UnlockStatusExt.fromJson(UnlockStatus.unlocked.toJson()), UnlockStatus.unlocked);
      expect(UnlockStatusExt.fromJson(UnlockStatus.claimed.toJson()), UnlockStatus.claimed);
    });
  });

  group('RewardItem / UnlockedReward parsing', () {
    test('parses correctly', () {
      final item = RewardItem.fromJson({
        'type': 'template_pack',
        'id': 'pk-1',
        'label': 'Pack 1',
      });
      expect(item.type, RewardType.templatePack);
      expect(item.id, 'pk-1');

      final unlocked = UnlockedReward.fromJson({
        'id': 5,
        'tier': 2,
        'source': 'redemption',
        'sourceDetail': 'campaign-x',
        'status': 'claimed',
        'rewardItems': [item.toJson()],
        'unlockedAt': 1700000000,
        'claimedAt': 1700000001,
      });
      expect(unlocked.id, 5);
      expect(unlocked.source, RewardSource.redemption);
      expect(unlocked.status, UnlockStatus.claimed);
      expect(unlocked.claimedAt, 1700000001);
      expect(unlocked.rewardItems.length, 1);
    });
  });

  group('RemoteRewardsRepository.list offline fallback', () {
    test('returns cached list on network error', () async {
      final api = _FakeApi()..listError = const ApiException(ApiErrorKind.network, 'timeout');
      final cache = _FakeCacheDao();
      final cachedList = RewardsList(rewards: [
        UnlockedReward(
          id: 1,
          tier: 1,
          source: RewardSource.invite,
          sourceDetail: null,
          status: UnlockStatus.unlocked,
          rewardItems: const [],
          unlockedAt: 1700000000,
          claimedAt: null,
        ),
      ]);
      await cache.save('rewards_list', jsonEncode(cachedList.toJson()));

      final repo = RemoteRewardsRepository(api: api as dynamic, cache: cache as dynamic);
      final result = await repo.list();
      expect(result.rewards.length, 1);
      expect(result.rewards.first.id, 1);
      expect(api.listCallCount, 1);
    });

    test('rethrows non-network error', () async {
      final api = _FakeApi()..listError = const ApiException(ApiErrorKind.server, '500');
      final cache = _FakeCacheDao();

      final repo = RemoteRewardsRepository(api: api as dynamic, cache: cache as dynamic);
      expect(() => repo.list(), throwsA(isA<ApiException>()));
    });

    test('saves cache on success', () async {
      final api = _FakeApi()
        ..listResponse = RewardsList(rewards: const []);
      final cache = _FakeCacheDao();

      final repo = RemoteRewardsRepository(api: api as dynamic, cache: cache as dynamic);
      await repo.list();
      final cached = await cache.load('rewards_list');
      expect(cached, isNotNull);
    });
  });

  group('RemoteRewardsRepository.claim', () {
    test('sends correct path and parses response', () async {
      final api = _FakeApi()
        ..claimResponses = {42: const ClaimResult(success: true)};
      final cache = _FakeCacheDao();

      final repo = RemoteRewardsRepository(api: api as dynamic, cache: cache as dynamic);
      final result = await repo.claim(42);
      expect(result.success, true);
    });
  });
}
```

- [ ] **Step 4: 运行 Task 7 测试验证通过**

Run:
```bash
cd lumira_app_flutter
flutter test test/features/rewards/data/rewards_repository_test.dart
```
Expected: PASS

- [ ] **Step 5: 运行 Task 5 (invite) 和 Task 6 (redeem) 测试验证通过**

Run:
```bash
cd lumira_app_flutter
flutter test test/features/invite/ test/features/redeem/
```
Expected: PASS（所有测试通过）

- [ ] **Step 6: 验证 analyze**

Run:
```bash
cd lumira_app_flutter
flutter analyze lib/features/rewards/ lib/features/invite/ lib/features/redeem/ lib/core/db/dao/api_cache_dao.dart
```
Expected: "No issues found!"

- [ ] **Step 7: 验证全部新增测试通过**

Run:
```bash
cd lumira_app_flutter
flutter test test/core/ test/features/device/ test/features/invite/ test/features/redeem/ test/features/rewards/
```
Expected: PASS

- [ ] **Step 8: Commit Task 7**

```bash
cd lumira_app_flutter
git add lib/features/rewards/ test/features/rewards/
git commit -m "feat(flutter): add rewards module (shared models + Repository with offline fallback)"
```

---

## Task 8: 启动流程 — main.dart bootstrap + splash 改造

**Files:**
- Modify: `lumira_app_flutter/lib/main.dart`
- Modify: `lumira_app_flutter/lib/features/splash/pages/splash_page.dart`
- Test: `lumira_app_flutter/test/features/splash/splash_page_test.dart`（修改现有测试）

**Interfaces:**
- Consumes: `databaseProvider`、`authDaoProvider`、`apiClientProvider`、`deviceRepositoryProvider`（all from previous Tasks）
- Produces: 改造后的 `main()` 异步入口 + `MyApp` 接受 `ProviderContainer`
- Produces: `splash_page.dart` 监听 `authControllerProvider`

- [ ] **Step 1: 改造 main.dart**

Read 现有 `lumira_app_flutter/lib/main.dart`：

```dart
void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final appTheme = ref.watch(appThemeProvider);
    return MaterialApp.router(
      title: '如画 Lumira',
      debugShowCheckedModeBanner: false,
      theme: appTheme.toThemeData(),
      routerConfig: router,
    );
  }
}
```

Modify `lumira_app_flutter/lib/main.dart` 为：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/auth_dao.dart';
import 'core/db/database_provider.dart';
import 'core/network/api_client.dart';
import 'core/theme/theme_controller.dart';
import 'features/device/data/device_repository.dart';
import 'features/device/data/device_models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();

  // 1. 等待 sqflite 就绪
  await container.read(databaseProvider.future);

  // 2. 创建 AuthController 并 bootstrap
  // AuthController 需要 AuthDao + register 回调（调用 RemoteDeviceRepository）
  // 不能直接用 authControllerProvider（其默认实现 throw UnimplementedError）
  // 通过 override 注入实际实现
  final authDao = await container.read(authDaoProvider.future);

  // 创建一个临时 ProviderContainer 用于注册流程
  // 注册流程：deviceId/os 解析 → POST /device/register → 保存到 authDao
  final authController = AuthController(
    dao: authDao,
    resolveDeviceId: () => defaultResolveDeviceId(authDao),
    resolveOs: defaultResolveOs,
    doRegister: ({required deviceId, required os}) async {
      // 临时创建 ApiClient（此时 AuthController 未就绪，无法用 apiClientProvider）
      // 用一个无 token 的 ApiClient 直接调用 register
      final tempAuth = _PreAuthController();
      final api = await ApiClient.create(tempAuth);
      final repo = RemoteDeviceRepository(api);
      final resp = await repo.register(RegisterDeviceRequest(
        deviceId: deviceId,
        os: DeviceOsExt.fromJson(os),
      ));
      return (token: resp.token, isNewDevice: resp.isNewDevice);
    },
  );

  await authController.bootstrap();

  // 3. 注入 authController 到全局 Provider
  // 通过 override 替换 authControllerProvider
  // 但 authControllerProvider 默认 throw UnimplementedError，需 override
  // 实际方案：使用 UncontrolledProviderScope + 已 override 的 container
  final overriddenContainer = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith((ref) => authController),
    ],
  );

  // 4. 若未注册则后台触发（不阻塞 UI）
  if (authController.state.needsRegistration) {
    authController.registerIfNeeded();
  }

  runApp(UncontrolledProviderScope(
    container: overriddenContainer,
    child: const MyApp(),
  ));
}

/// 临时 AuthController stub（仅用于 register 时不注入 token）
class _PreAuthController extends AuthController {
  _PreAuthController()
      : super(
          dao: _NoopDao(),
          resolveDeviceId: () async => '',
          resolveOs: () => 'android',
          doRegister: ({required deviceId, required os}) async =>
              (token: '', isNewDevice: false),
        );

  @override
  String? get currentToken => null; // register 时不注入 token
}

class _NoopDao implements AuthDaoLike {
  Future<AuthRecord?> load() async => null;
  Future<void> save(AuthRecord r) async {}
  Future<void> clear() async {}
}

class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final appTheme = ref.watch(appThemeProvider);
    return MaterialApp.router(
      title: '如画 Lumira',
      debugShowCheckedModeBanner: false,
      theme: appTheme.toThemeData(),
      routerConfig: router,
    );
  }
}
```

**注意**：上面 main.dart 的 `_PreAuthController` 设计有问题——`AuthController` 在 Task 3 的设计不是 abstract，无法被继承覆盖。**改用更简洁的方式**：直接在 `main()` 中创建一个 lambda 形式的 `AuthController`-like 实例用于 register。

**实施时简化为**：

```dart
// 不创建 _PreAuthController 子类，直接用 closure 调用
Future<({String token, bool isNewDevice})> _doRegister(
  String deviceId,
  String os,
) async {
  // 创建一个无鉴权拦截的 Dio 直接调用 register
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: Duration(milliseconds: AppConfig.connectTimeoutMs),
    receiveTimeout: Duration(milliseconds: AppConfig.receiveTimeoutMs),
    headers: {'Content-Type': 'application/json'},
  ));
  final resp = await dio.post('/device/register', data: {
    'deviceId': deviceId,
    'os': os,
  });
  final body = resp.data as Map<String, dynamic>;
  return (
    token: body['token'] as String,
    isNewDevice: body['isNewDevice'] as bool,
  );
}
```

完整 main.dart 实施代码（最终版）：

```dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/auth_dao.dart';
import 'core/config/app_config.dart';
import 'core/db/database_provider.dart';
import 'core/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authDao = await _createAuthDao();

  final authController = AuthController(
    dao: authDao,
    resolveDeviceId: () => defaultResolveDeviceId(authDao),
    resolveOs: defaultResolveOs,
    doRegister: _doRegister,
  );

  await authController.bootstrap();

  if (authController.state.needsRegistration) {
    authController.registerIfNeeded(); // fire-and-forget
  }

  runApp(
    UncontrolledProviderScope(
      container: ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => authController),
        ],
      ),
      child: const MyApp(),
    ),
  );
}

Future<AuthDao> _createAuthDao() async {
  final container = ProviderContainer();
  await container.read(databaseProvider.future);
  final dao = await container.read(authDaoProvider.future);
  return dao;
}

Future<({String token, bool isNewDevice})> _doRegister({
  required String deviceId,
  required String os,
}) async {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: const Duration(milliseconds: AppConfig.connectTimeoutMs),
    receiveTimeout: const Duration(milliseconds: AppConfig.receiveTimeoutMs),
    headers: {'Content-Type': 'application/json'},
  ));
  final resp = await dio.post('/device/register', data: {
    'deviceId': deviceId,
    'os': os,
  });
  final body = resp.data as Map<String, dynamic>;
  return (
    token: body['token'] as String,
    isNewDevice: body['isNewDevice'] as bool,
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final appTheme = ref.watch(appThemeProvider);
    return MaterialApp.router(
      title: '如画 Lumira',
      debugShowCheckedModeBanner: false,
      theme: appTheme.toThemeData(),
      routerConfig: router,
    );
  }
}
```

- [ ] **Step 2: 改造 splash_page.dart**

Read 现有 `lumira_app_flutter/lib/features/splash/pages/splash_page.dart`，理解当前 1.8s Timer 逻辑。

Modify 后的 splash_page.dart：

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  Timer? _timer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // 最短展示 1.8s（保持原视觉时序）
    _timer = Timer(const Duration(milliseconds: 1800), _maybeNavigate);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _maybeNavigate() {
    if (_navigated || !mounted) return;
    final auth = ref.read(authControllerProvider);
    // 仅在已注册或加载中时跳转（failed/fresh 不阻塞，让用户进入 home）
    _navigated = true;
    context.go(RouteNames.home);
  }

  void _retryRegistration() {
    ref.read(authControllerProvider.notifier).registerIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 现有 logo / brand 内容（保持不变）
            const Text('如画 Lumira', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 24),
            if (auth.status == AuthStatus.loading)
              const CircularProgressIndicator()
            else if (auth.status == AuthStatus.failed) ...[
              const Text('网络连接失败'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _retryRegistration,
                child: const Text('重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

**注意**：splash_page.dart 现有的 UI（logo 渐变、品牌字标）需保留，上面只是骨架。**实施时保留原 UI，只补充底部状态指示器和重试按钮**。

- [ ] **Step 3: 更新 splash_page_test.dart**

Read 现有 `lumira_app_flutter/test/features/splash/splash_page_test.dart`，按新行为更新：

- 测试 case 1：auth = registered → 1.8s 后跳转 /home
- 测试 case 2：auth = failed → 显示「重试」按钮
- 测试 case 3：点击重试 → 触发 registerIfNeeded

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/auth/auth_controller.dart';
import 'package:lumira_app_flutter/core/auth/auth_state.dart';
import 'package:lumira_app_flutter/features/splash/pages/splash_page.dart';

class _FakeAuthController extends AuthController {
  _FakeAuthController(AuthState initial)
      : super(
          dao: _NoopDao(),
          resolveDeviceId: () async => '',
          resolveOs: () => 'android',
          doRegister: ({required deviceId, required os}) async =>
              (token: '', isNewDevice: false),
        ) {
    state = initial;
  }
}

class _NoopDao implements AuthDaoLike {
  Future<AuthRecord?> load() async => null;
  Future<void> save(AuthRecord r) async {}
  Future<void> clear() async {}
}

void main() {
  testWidgets('shows retry button when auth failed', (tester) async {
    final fakeController = _FakeAuthController(
      const AuthState(status: AuthStatus.failed, lastError: 'network down'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => fakeController),
        ],
        child: MaterialApp(
          home: InheritedGoRouter(
            goRouter: GoRouter(routes: [
              GoRoute(path: '/', builder: (_, __) => const SplashPage()),
              GoRoute(path: '/home', builder: (_, __) => const SizedBox()),
            ]),
          ),
        ),
      ),
    );

    expect(find.text('网络连接失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('shows spinner when auth loading', (tester) async {
    final fakeController = _FakeAuthController(
      const AuthState(status: AuthStatus.loading),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => fakeController),
        ],
        child: MaterialApp(
          home: InheritedGoRouter(
            goRouter: GoRouter(routes: [
              GoRoute(path: '/', builder: (_, __) => const SplashPage()),
            ]),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

> **注意**：现有 splash_page_test.dart 可能已存在并有不同的断言。**实施时先 Read 该文件，理解现有断言，按最小修改原则更新**（如把 `find.byType(LumiraLogo)` 保留，新增 failed/loading 状态的断言）。

- [ ] **Step 4: 运行 splash 测试**

Run:
```bash
cd lumira_app_flutter
flutter test test/features/splash/
```
Expected: PASS

- [ ] **Step 5: 验证 analyze**

Run:
```bash
cd lumira_app_flutter
flutter analyze lib/main.dart lib/features/splash/
```
Expected: "No issues found!"

- [ ] **Step 6: 运行全部测试**

Run:
```bash
cd lumira_app_flutter
flutter test
```
Expected: PASS（无回归）

- [ ] **Step 7: Commit**

```bash
cd lumira_app_flutter
git add lib/main.dart lib/features/splash/pages/splash_page.dart test/features/splash/
git commit -m "feat(flutter): wire AuthController bootstrap in main + splash status UI"
```

---

## Task 9: UI 集成 — profile_invite / rewards_page / redeem_page / 路由

**Files:**
- Modify: `lumira_app_flutter/lib/features/profile/pages/profile_invite_page.dart`
- Modify: `lumira_app_flutter/lib/features/profile/pages/profile_page.dart`
- Create: `lumira_app_flutter/lib/features/rewards/pages/rewards_page.dart`
- Create: `lumira_app_flutter/lib/features/redeem/pages/redeem_page.dart`
- Create: `lumira_app_flutter/lib/shared/widgets/api_error_banner.dart`
- Modify: `lumira_app_flutter/lib/app/router.dart`

**Interfaces:**
- Consumes: `inviteRepositoryProvider`（Task 5）、`redeemRepositoryProvider`（Task 6）、`rewardsRepositoryProvider`（Task 7）

- [ ] **Step 1: 创建 api_error_banner.dart**

Create `lumira_app_flutter/lib/shared/widgets/api_error_banner.dart`:

```dart
import 'package:flutter/material.dart';

/// 离线模式提示横幅
///
/// 当 Repository 因网络失败回退缓存时显示
class ApiErrorBanner extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const ApiErrorBanner({
    super.key,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off, size: 16, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message ?? '网络连接失败，显示的是上次缓存数据',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('重试'),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 改造 profile_invite_page.dart**

Read 现有 `lumira_app_flutter/lib/features/profile/pages/profile_invite_page.dart`，理解现有 UI 结构（应该是基于 mock 数据）。

**实施步骤**：
1. 用 `ref.watch(inviteRepositoryProvider.future)` 替换 mock 数据加载
2. 使用 `AsyncValue<InviteStats>.when(data:, loading:, error:)` 模式
3. 添加 `ApiErrorBanner` 在网络失败时显示
4. 邀请码激活按钮 → `activate()` → SnackBar
5. 生成邀请码按钮 → `generateCode()` → 显示 + 复制

```dart
// 关键代码片段（实施时整合到现有 UI）

final statsAsync = ref.watch(inviteStatsProvider);

// 在 build 中：
statsAsync.when(
  data: (stats) => _buildStatsContent(stats),
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (e, _) => Column(
    children: [
      const ApiErrorBanner(),
      const Text('暂无数据'),
    ],
  ),
);

// 邀请码激活
Future<void> _onActivate(String code) async {
  try {
    final repo = await ref.read(inviteRepositoryProvider.future);
    final resp = await repo.activate(ActivateInviteRequest(inviteCode: code));
    if (resp.rewards != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('邀请码已激活，解锁 ${resp.rewards!.items.length} 项奖励')),
      );
      ref.invalidate(inviteStatsProvider);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('邀请码已激活')),
      );
    }
  } on ApiException catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('激活失败：${e.message}')),
    );
  }
}
```

**Provider 定义**（添加到 invite_repository.dart 末尾）：

```dart
/// InviteStats FutureProvider（带自动刷新）
final inviteStatsProvider = FutureProvider<InviteStats>((ref) async {
  final repo = await ref.watch(inviteRepositoryProvider.future);
  return repo.getStats();
});
```

- [ ] **Step 3: 创建 rewards_page.dart**

Create `lumira_app_flutter/lib/features/rewards/pages/rewards_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../shared/widgets/api_error_banner.dart';
import '../../rewards/data/rewards_models.dart';
import '../../rewards/data/rewards_repository.dart';

class RewardsPage extends ConsumerWidget {
  const RewardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewardsAsync = ref.watch(rewardsListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('我的奖励')),
      body: rewardsAsync.when(
        data: (list) => _buildList(context, ref, list.rewards),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          final isOffline = e is ApiException && e.isNetworkError;
          return Column(
            children: [
              if (isOffline) const ApiErrorBanner(),
              const Expanded(child: Center(child: Text('暂无奖励'))),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<UnlockedReward> rewards) {
    if (rewards.isEmpty) {
      return const Center(child: Text('暂无奖励'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rewards.length,
      itemBuilder: (_, i) => _RewardCard(reward: rewards[i]),
    );
  }
}

class _RewardCard extends ConsumerStatefulWidget {
  final UnlockedReward reward;
  const _RewardCard({required this.reward});

  @override
  ConsumerState<_RewardCard> createState() => _RewardCardState();
}

class _RewardCardState extends ConsumerState<_RewardCard> {
  bool _claiming = false;

  Future<void> _onClaim() async {
    setState(() => _claiming = true);
    try {
      final repo = await ref.read(rewardsRepositoryProvider.future);
      await repo.claim(widget.reward.id);
      ref.invalidate(rewardsListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('奖励已领取')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('领取失败：${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reward;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tier ${r.tier} · ${r.source.toJson()}', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final item in r.rewardItems) Text('• ${item.label}'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (r.status == UnlockStatus.unlocked)
                  ElevatedButton(
                    onPressed: _claiming ? null : _onClaim,
                    child: _claiming
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('领取'),
                  )
                else
                  const Text('已领取', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

**Provider 定义**（添加到 rewards_repository.dart 末尾）：

```dart
final rewardsListProvider = FutureProvider<RewardsList>((ref) async {
  final repo = await ref.watch(rewardsRepositoryProvider.future);
  return repo.list();
});
```

- [ ] **Step 4: 创建 redeem_page.dart**

Create `lumira_app_flutter/lib/features/redeem/pages/redeem_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../redeem/data/redeem_repository.dart';

class RedeemPage extends ConsumerStatefulWidget {
  const RedeemPage({super.key});

  @override
  ConsumerState<RedeemPage> createState() => _RedeemPageState();
}

class _RedeemPageState extends ConsumerState<RedeemPage> {
  final _codeCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final repo = await ref.read(redeemRepositoryProvider.future);
      final resp = await repo.redeem(RedeemCodeRequest(code: code));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已兑换：${resp.campaignName}（${resp.rewardItems.length} 项奖励）')),
        );
        _codeCtrl.clear();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('兑换失败：${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('兑换码')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('输入兑换码以领取奖励'),
            const SizedBox(height: 12),
            TextField(
              controller: _codeCtrl,
              decoration: const InputDecoration(
                labelText: '兑换码',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitting ? null : _onSubmit,
              child: _submitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('兑换'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: 改造 profile_page.dart 加入口**

Read 现有 `lumira_app_flutter/lib/features/profile/pages/profile_page.dart`，在合适位置加入：

```dart
ListTile(
  leading: const Icon(Icons.card_giftcard),
  title: const Text('我的奖励'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => context.go(RouteNames.profileRewards),
),
ListTile(
  leading: const Icon(Icons.redeem),
  title: const Text('兑换码'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => context.go(RouteNames.profileRedeem),
),
```

- [ ] **Step 6: 加路由到 router.dart**

Modify `lumira_app_flutter/lib/app/router.dart` 和 `lumira_app_flutter/lib/core/router/route_names.dart`：

在 `route_names.dart` 加：
```dart
static const String profileRewards = '/profile/rewards';
static const String profileRedeem = '/profile/redeem';
```

在 `router.dart` 的 `routes` 列表中加：
```dart
GoRoute(
  path: RouteNames.profileRewards,
  builder: (_, __) => const RewardsPage(),
),
GoRoute(
  path: RouteNames.profileRedeem,
  builder: (_, __) => const RedeemPage(),
),
```

并在 router.dart 顶部 import：
```dart
import '../features/rewards/pages/rewards_page.dart';
import '../features/redeem/pages/redeem_page.dart';
```

- [ ] **Step 7: 验证 analyze**

Run:
```bash
cd lumira_app_flutter
flutter analyze lib/features/profile/ lib/features/rewards/ lib/features/redeem/ lib/shared/widgets/api_error_banner.dart lib/app/router.dart lib/core/router/route_names.dart
```
Expected: "No issues found!"

- [ ] **Step 8: 运行所有测试**

Run:
```bash
cd lumira_app_flutter
flutter test
```
Expected: PASS（如有 router_test 需更新断言）

- [ ] **Step 9: Commit**

```bash
cd lumira_app_flutter
git add lib/features/profile/ lib/features/rewards/pages/ lib/features/redeem/pages/ lib/shared/widgets/api_error_banner.dart lib/app/router.dart lib/core/router/route_names.dart
git commit -m "feat(flutter): wire UI to backend - invite/rewards/redeem pages + routing"
```

---

## Task 10: 端到端集成验证

**Files:**（无新增/修改，纯验证）

- [ ] **Step 1: 启动后端**

Run（独立终端）：
```bash
cd lumira-server
pnpm --filter backend dev
```
Expected: 后端监听 :3000

- [ ] **Step 2: Flutter 启动（Android 模拟器）**

Run:
```bash
cd lumira_app_flutter
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

- [ ] **Step 3: 首次启动验证（设备注册）**

观察后端日志：`POST /api/v1/device/register 201`（或 200）

观察 Flutter 日志：
```
Dio: POST http://10.0.2.2:3000/api/v1/device/register
Dio: Response: {"token":"...","isNewDevice":true}
```

进入 `/home` → 进入 `/profile` → 检查 sqflite auth 表（通过 dev tools 或日志）

- [ ] **Step 4: 二次启动验证（不重新注册）**

关闭并重启 app，观察后端无 `/device/register` 请求（仅后续 API 请求带 token）

- [ ] **Step 5: 邀请页验证**

进入 `/profile/invite` →
- 后端：`GET /api/v1/invite/stats 200`
- UI：显示 tier / 总邀请数 / 已解锁奖励

输入测试邀请码 → 点击激活 →
- 后端：`POST /api/v1/invite/activate 200`
- UI：SnackBar「邀请码已激活，解锁 X 项奖励」

- [ ] **Step 6: 奖励页验证**

从 profile 进入「我的奖励」→
- 后端：`GET /api/v1/rewards 200`
- UI：显示奖励列表，未领取的显示「领取」按钮

点击「领取」→
- 后端：`POST /api/v1/rewards/:id/claim 200`
- UI：SnackBar「奖励已领取」+ 列表刷新

- [ ] **Step 7: 兑换码验证**

进入 `/profile/redeem` → 输入测试兑换码 → 点击兑换 →
- 后端：`POST /api/v1/redeem/code 200`
- UI：SnackBar「已兑换：XXX（N 项奖励）」

- [ ] **Step 8: 断网回退验证**

进入 `/profile/invite` → 等待数据加载完成 →
开启飞行模式 → 下拉刷新或重进页面 →
- UI：显示 `ApiErrorBanner`「网络连接失败，显示的是上次缓存数据」
- 数据：仍显示上次的 InviteStats

关闭飞行模式 → 下拉刷新 → 拉到最新数据

- [ ] **Step 9: 401 失效验证**

手动修改 sqflite auth 表的 token 为无效值（通过 dev tools）→
触发任意鉴权请求（如 GET /invite/stats）→
- 后端返回 401
- AuthInterceptor 调用 `invalidateRegistration`
- 下次启动自动重新注册

- [ ] **Step 10: 全部测试通过**

Run:
```bash
cd lumira_app_flutter
flutter analyze
flutter test
```
Expected: 0 issues / 全部 PASS

- [ ] **Step 11: 最终 Commit**

```bash
cd lumira_app_flutter
git add -A
git commit -m "test(flutter): end-to-end backend integration verified (device/invite/redeem/rewards)"
```

---

## Self-Review

### 1. Spec coverage

| Spec 章节 | 对应 Task |
|---|---|
| §1 整体架构与模块划分 | Task 1-9 全部 |
| §2 依赖与 pubspec 变更 | Task 1 |
| §3 环境配置与启动流程 | Task 1 (AppConfig) + Task 8 (main.dart) |
| §4 网络层与拦截器 | Task 2 |
| §5 Auth 模块与设备注册 | Task 3 + Task 8 (bootstrap) |
| §6.1 device 模块 | Task 4 |
| §6.2 invite 模块 | Task 5 |
| §6.3 redeem 模块 | Task 6 |
| §6.4 rewards 模块 | Task 7 |
| §7 UI 集成点 | Task 8 (splash) + Task 9 |
| §8 测试策略与鸿蒙适配验证 | 各 Task 测试 + Task 10 |

### 2. Placeholder scan

- ❌ "占位：实际判定逻辑见实施" → 在 Task 3 `defaultResolveOs` 中已给具体判定代码
- ❌ "如不存在则新增" → Task 9 已明确 Create 操作
- ❌ "实施时确认" → Task 8 splash 改造已说明「保留原 UI 只补底部状态」
- 所有 Task 都有完整代码

### 3. Type consistency

- `AuthController` 构造签名：Task 3 定义 → Task 8 使用，一致（`dao: AuthDaoLike`, `resolveDeviceId: Future<String> Function()`, `resolveOs: String Function()`, `doRegister: Future<({String token, bool isNewDevice})> Function({required String deviceId, required String os})`）
- `ApiClient.post<T>` 签名：Task 2 定义 → Task 4/5/6/7 使用，一致
- `ApiCacheDao.save(key, payload)` 签名：Task 5 定义 → Task 7 使用，一致
- `RewardItem.fromJson` / `toJson`：Task 7 定义 → Task 5（invite）/ Task 6（redeem）使用，一致
- `InviteChannelExt.fromJson` 返回 `InviteChannel?`（nullable），Task 5 测试已覆盖

无类型不一致。

### 4. 执行顺序调整说明

Spec 没有明确执行顺序，但 Task 间存在依赖：
- Task 1 → 所有后续
- Task 2 → Task 3, 4, 5, 6, 7
- Task 3 → Task 2（AuthInterceptor）, Task 8
- Task 7 → Task 5, 6（共享 RewardItem）

**推荐执行顺序**：1 → 2 → 3 → 7 → 4 → 5 → 6 → 8 → 9 → 10

（Task 7 提前于 5/6 是因为 5/6 依赖 7 的共享模型）

---

**Plan complete**. Saved to `docs/superpowers/plans/2026-07-28-flutter-backend-integration.md`.
