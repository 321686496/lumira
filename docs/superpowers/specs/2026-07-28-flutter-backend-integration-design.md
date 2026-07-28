# Flutter 后端接入设计

**日期**：2026-07-28
**项目**：如画 Lumira (`lumira_app_flutter/`)
**后端**：NestJS + Fastify (`lumira-server/packages/backend/`)，全局前缀 `/api/v1`
**方案**：A — ApiClient 集中 + 每模块 Remote Repository（复用现有 `AcademyRepository` 范式）

---

## 1. 整体架构与模块划分

### 分层架构

```
┌─────────────────────────────────────────────────┐
│ UI (pages/widgets)                              │ ← 不变
├─────────────────────────────────────────────────┤
│ Riverpod Providers                              │ ← 新增 authProvider 等
├─────────────────────────────────────────────────┤
│ Repository (abstract) ← 已有范式               │ ← 新增 4 个抽象
│   └─ Local*Repository   └─ Remote*Repository    │ ← 新增 Remote 实现
├─────────────────────────────────────────────────┤
│ core/network (Dio + Interceptor)               │ ← 新增
│ core/auth (AuthController + AuthDao)           │ ← 新增
│ core/config (AppConfig)                        │ ← 新增
│ core/db (sqflite, v5 加 auth/cache 表)         │ ← 扩展
└─────────────────────────────────────────────────┘
```

### 新增目录

```
lumira_app_flutter/lib/core/
├── config/
│   └── app_config.dart                      # baseUrl + 环境常量
├── network/
│   ├── api_client.dart                       # Dio 单例 Provider
│   ├── auth_interceptor.dart                 # 注入 Bearer
│   ├── api_error.dart                        # ApiError 枚举 + ApiException
│   └── api_response.dart                     # { ok, data, error } 包装
└── auth/
    ├── auth_controller.dart                  # Riverpod: 负责注册流程
    ├── auth_state.dart                       # AuthState(fresh / registered / loading)
    └── auth_dao.dart                         # auth 表 CRUD
```

### 4 个 feature 的数据层扩展

每个 feature 新增两个文件（保持与 `academy` 一致的范式）：

| Feature | 新增文件 |
|---|---|
| device | `features/device/data/device_models.dart` + `device_repository.dart`（含 Local + Remote） |
| invite | `features/invite/data/invite_models.dart` + `invite_repository.dart` |
| redeem | `features/redeem/data/redeem_models.dart` + `redeem_repository.dart` |
| rewards | `features/rewards/data/rewards_models.dart` + `rewards_repository.dart` |

### 离线回退模式

每个 `Remote*Repository` 内部持有 `Local*Repository`（或直接复用 sqflite DAO）：

```dart
class RemoteInviteRepository implements InviteRepository {
  final ApiClient _api;
  final InviteDao _localDao;
  ...
  Future<InviteStats> getStats() async {
    try {
      final result = await _api.get('/invite/stats');
      await _localDao.saveInviteStats(result);
      return result;
    } on ApiException catch (e) {
      if (e.isNetworkError) return _localDao.getInviteStats();
      rethrow;
    }
  }
}
```

UI 层完全无感知：watch provider → 拿到数据 → 渲染；网络失败时 UI 看到的就是上次缓存。

### Riverpod 注入切换

```dart
final inviteRepositoryProvider = Provider<InviteRepository>((ref) {
  return RemoteInviteRepository(
    api: ref.watch(apiClientProvider),
    localDao: ref.watch(inviteDaoProvider),
  );
});

// 测试时 override
ProviderScope(overrides: [
  inviteRepositoryProvider.overrideWithValue(MockInviteRepository()),
])
```

---

## 2. 依赖与 pubspec 变更

### 新增依赖

| 依赖 | 版本 | 类型 | 用途 |
|---|---|---|---|
| `dio` | `4.0.6` | dependencies | HTTP 客户端（4.x 末版支持 Dart 2.19；5.4+ 需 Dart 3） |

### 不引入的依赖与理由

- `http`：与 dio 二选一，统一用 dio（拦截器生态更好）
- `json_serializable` / `build_runner`：用户已选择手写 fromJson/toJson
- `shared_preferences` / `flutter_secure_storage`：复用 sqflite 存 token
- `connectivity_plus`：离线判断通过 try/catch DioException 即可
- `retrofit`：4 个端点规模不值得引入代码生成

### pubspec.yaml 修改点

```yaml
dependencies:
  # 新增
  dio: 4.0.6   # Dart 2.19 兼容版本；5.x 需 Dart 3
```

### 鸿蒙适配风险

- `dio: 4.0.6` 是纯 Dart 库（无原生代码），无需 ohos 原生插件
- 如果 `dio: 4.0.6` 与 `meta: 1.8.0` 产生约束冲突，在 `dependency_overrides` 中钉定 `dio: 4.0.6` 并继续锁定 `meta: 1.8.0`
- 实施第一步先 `flutter pub get` 验证依赖解析

---

## 3. 环境配置与启动流程

### lib/core/config/app_config.dart

```dart
class AppConfig {
  const AppConfig._();

  /// 后端 baseUrl，通过 --dart-define=API_BASE_URL=xxx 切换
  /// 默认指向 Android 模拟器宿主机（10.0.2.2 = host loopback）
  /// 真机调试时需替换为开发机局域网 IP，例如 http://192.168.1.100:3000/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );

  /// 请求超时（ms）
  static const int connectTimeoutMs = 8000;
  static const int receiveTimeoutMs = 10000;

  /// 识别当前是否为 release 构建
  static bool get isRelease => kReleaseMode;
}
```

### 启动流程改造（main.dart）

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 创建容器，先做同步初始化（DB / AuthState 加载）
  final container = ProviderContainer();

  // 1. 等待 sqflite 就绪
  await container.read(databaseProvider.future);

  // 2. 加载本地 auth 状态（token / deviceId / os）
  await container.read(authControllerProvider.notifier).bootstrap();

  // 3. 若未注册则触发设备注册（异步，不阻塞 UI 进入 splash）
  if (container.read(authControllerProvider).needsRegistration) {
    // fire-and-forget，UI 在 splash 上显示进度
    container.read(authControllerProvider.notifier).registerIfNeeded();
  }

  runApp(UncontrolledProviderScope(
    container: container,
    child: const MyApp(),
  ));
}
```

### 关键决策

- **不阻塞 UI 启动**：splash 页固定 1.8s（现有逻辑），设备注册在后台进行；注册失败显示「点击重试」按钮，不阻断进入 `/home`
- **deviceId 生成**：通过 `device_info_plus` 读取 `androidId` / `identifierForVendor` / 鸿蒙 `udid`；若都不可得则 fallback 到 `UUID v4` 持久化到 sqflite
- **os 字段**：基于 `Platform`（android/ios）+ 鸿蒙特殊判定（`Platform.operatingSystem` 在 ohos 上可能返回 android，需通过 `device_info_plus` 的鸿蒙分支判定）

---

## 4. 网络层与拦截器

### lib/core/network/api_error.dart

```dart
enum ApiErrorKind {
  network,         // 断网 / 超时
  unauthorized,    // 401 → 触发重新注册
  forbidden,       // 403
  notFound,        // 404
  server,          // 5xx
  unknown,
}

class ApiException implements Exception {
  final ApiErrorKind kind;
  final int? statusCode;
  final String message;
  final dynamic original;
  const ApiException(this.kind, this.message, {this.statusCode, this.original});

  bool get isNetworkError => kind == ApiErrorKind.network;
  bool get isUnauthorized => kind == ApiErrorKind.unauthorized;
}
```

### lib/core/network/auth_interceptor.dart

```dart
class AuthInterceptor extends Interceptor {
  final AuthController _auth;
  AuthInterceptor(this._auth);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _auth.currentToken;
    if (token != null && !options.path.contains('/device/register')) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    final kind = _classify(err);
    if (kind == ApiErrorKind.unauthorized) {
      _auth.invalidateRegistration();  // 触发下次启动重新注册
    }
    handler.next(err);  // 不吞错，让上层 Repository 决策
  }

  ApiErrorKind _classify(DioError err) {
    if (err.type == DioErrorType.connectTimeout ||
        err.type == DioErrorType.receiveTimeout ||
        err.type == DioErrorType.sendTimeout ||
        err.type == DioErrorType.connectionError) {
      return ApiErrorKind.network;
    }
    switch (err.response?.statusCode) {
      case 401: return ApiErrorKind.unauthorized;
      case 403: return ApiErrorKind.forbidden;
      case 404: return ApiErrorKind.notFound;
      default:
        if ((err.response?.statusCode ?? 0) >= 500) return ApiErrorKind.server;
        return ApiErrorKind.unknown;
    }
  }
}
```

### lib/core/network/api_client.dart

```dart
class ApiClient {
  final Dio _dio;
  ApiClient._(this._dio);

  static Future<ApiClient> create(AuthController auth) async {
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(milliseconds: AppConfig.connectTimeoutMs),
      receiveTimeout: const Duration(milliseconds: AppConfig.receiveTimeoutMs),
      headers: {'Content-Type': 'application/json'},
    ));
    dio.interceptors.add(AuthInterceptor(auth));
    // dev 模式加 LogInterceptor（响应/错误，不记 body 以减少噪声）
    if (kDebugMode) dio.interceptors.add(LogInterceptor(responseBody: false));
    return ApiClient._(dio);
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? query, required T Function(Object?) fromJson}) async {
    final resp = await _dio.get(path, queryParameters: query);
    return fromJson(resp.data);
  }

  Future<T> post<T>(String path, {Object? body, required T Function(Object?) fromJson}) async {
    final resp = await _dio.post(path, data: body);
    return fromJson(resp.data);
  }

  Future<T?> patch<T>(String path, {Object? body, required T Function(Object?) fromJson}) async {
    final resp = await _dio.patch(path, data: body);
    return fromJson(resp.data);
  }
}

final apiClientProvider = FutureProvider<ApiClient>((ref) async {
  final auth = ref.watch(authControllerProvider.notifier);
  return ApiClient.create(auth);
});
```

### 关键点

- **CORS 约束**：后端 `main.ts` 只允许 `GET/POST/PATCH`，禁用 PUT/DELETE
- **错误不吞**：拦截器只把 DioError 映射为 ApiException，由 Repository 决策是否回退本地
- **401 处理**：标记本地 auth 为失效，下次启动重新注册；当前请求仍以异常上抛

---

## 5. Auth 模块与设备注册流程

### AuthState

```dart
enum AuthStatus { loading, fresh, registered, failed }

@immutable
class AuthState {
  final AuthStatus status;
  final String? token;
  final String? deviceId;
  final String? os;  // 'android' | 'ios' | 'harmonyos'
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

  bool get needsRegistration => status == AuthStatus.fresh;
  bool get isReady => status == AuthStatus.registered;
  AuthState copyWith({...});
}
```

### AuthController（StateNotifier<AuthState>）

```dart
class AuthController extends StateNotifier<AuthState> {
  final AuthDao _dao;
  final Ref _ref;
  AuthController(this._dao, this._ref) : super(const AuthState());

  String? get currentToken => state.token;

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
      );
    }
  }

  Future<void> registerIfNeeded() async {
    if (state.status != AuthStatus.fresh) return;
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final deviceId = await _resolveDeviceId();
      final os = _resolveOs();
      final resp = await _doRegister(deviceId, os);  // POST /device/register
      await _dao.save(AuthRecord(
        deviceId: deviceId,
        os: os,
        token: resp.token,
        isNewDevice: resp.isNewDevice,
        registeredAt: DateTime.now().millisecondsSinceEpoch,
      ));
      state = AuthState(
        status: AuthStatus.registered,
        token: resp.token,
        deviceId: deviceId,
        os: os,
        isNewDevice: resp.isNewDevice,
      );
    } catch (e) {
      state = state.copyWith(status: AuthStatus.failed, lastError: e.toString());
    }
  }

  void invalidateRegistration() {
    _dao.clear();
    state = const AuthState(status: AuthStatus.fresh);
  }

  Future<String> _resolveDeviceId() async {
    // device_info_plus 9.1.2
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.id;  // 或 Android ID（需权限）
    }
    if (Platform.isIOS) {
      final info = await DeviceInfoPlugin().iosInfo;
      return info.identifierForVendor ?? _uuid();
    }
    // 鸿蒙：通过 device_info_plus ohos 分支或 fallback UUID
    return _uuid();
  }

  String _resolveOs() {
    if (kDebugMode && const bool.fromEnvironment('HARMONY')) return 'harmonyos';
    if (Platform.isAndroid) {
      // ohos 平台在 CPF-Flutter 环境下 Platform.operatingSystem 可能返回 'android'
      // 通过 device_info_plus 是否拿到 ohos 信息判定
      return 'harmonyos';  // 占位：实际判定逻辑见实施
    }
    if (Platform.isIOS) return 'ios';
    return 'android';
  }
}
```

### device/register 请求扩展

后端契约 `RegisterDeviceRequest` 只有 `{ deviceId }`，本次扩展为：

```json
{
  "deviceId": "xxx",
  "os": "harmonyos" | "ios" | "android"
}
```

后端未接受 `os` 字段时会被忽略（NestJS 默认 whitelist + forbidNonWhitelisted 配置如开启则需后端补字段）。**Flutter 端按契约发送，后端如需扩展端点先在 `lumira-server` 加 `os` 字段。**

### AuthDao（sqflite auth 表）

```dart
class AuthRecord {
  final String deviceId;
  final String os;
  final String token;
  final bool isNewDevice;
  final int registeredAt;
  // ...
}

class AuthDao {
  Future<AuthRecord?> load();         // SELECT * FROM auth WHERE id=1
  Future<void> save(AuthRecord r);    // UPSERT id=1
  Future<void> clear();               // DELETE FROM auth WHERE id=1
}
```

### DB v5 迁移

在 `database_provider.dart` 加：

```dart
const int _kDbVersion = 5;

if (oldVersion < 5) {
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
  // 业务缓存表（每个模块一行 JSON 快照）
  await db.execute('''
    CREATE TABLE IF NOT EXISTS api_cache (
      key TEXT PRIMARY KEY,
      payload TEXT NOT NULL,
      cached_at INTEGER NOT NULL
    )
  ''');
}
```

`api_cache` 表用于离线回退（`invite_stats` / `rewards_list` / `invite_code` 等键值）。

---

## 6. 业务模块设计

### 6.1 device 模块

**模型** (`features/device/data/device_models.dart`)：

```dart
enum DeviceOs { android, ios, harmonyos }

class RegisterDeviceRequest {
  final String deviceId;
  final DeviceOs os;
  // toJson: os → string ('android' | 'ios' | 'harmonyos')
}

class RegisterDeviceResponse {
  final String token;
  final bool isNewDevice;
  // fromJson
}

class DeviceRecord {
  final String deviceId;
  final String? alias;
  final int firstSeenAt;
  final int lastSeenAt;
  final String? ipRegion;
  // fromJson
}
```

**Repository**：

```dart
abstract class DeviceRepository {
  Future<RegisterDeviceResponse> register(RegisterDeviceRequest req);
}

class RemoteDeviceRepository implements DeviceRepository {
  final ApiClient _api;
  RemoteDeviceRepository(this._api);

  @override
  Future<RegisterDeviceResponse> register(RegisterDeviceRequest req) async {
    return _api.post('/device/register',
      body: req.toJson(),
      fromJson: (j) => RegisterDeviceResponse.fromJson(j as Map<String, dynamic>));
  }
}
```

device 模块无离线回退（注册必须在线，失败即重试）。

### 6.2 invite 模块

**模型** (`features/invite/data/invite_models.dart`)：

```dart
enum InviteChannel { direct, shareCard, qrcode }

class ActivateInviteRequest {
  final String inviteCode;
  final InviteChannel? channel;
}

class ActivateInviteResponse {
  final String inviterDeviceId;
  final int? tierReached;
  final ({int tier, List<RewardItem> items})? rewards;
}

class InviteStats {
  final int totalInvites;
  final int currentTier;
  final ({int tier, int requiredInvites, List<RewardItem> rewards})? nextTier;
  final List<UnlockedReward> unlockedRewards;
}

class InviteCode {
  final String code;
  // fromJson for GenerateInviteResponse
}
```

**Repository**：

```dart
abstract class InviteRepository {
  Future<InviteCode> generateCode();             // POST /invite/generate
  Future<ActivateInviteResponse> activate(ActivateInviteRequest req); // POST /invite/activate
  Future<InviteStats> getStats();                // GET /invite/stats
}

class RemoteInviteRepository implements InviteRepository {
  final ApiClient _api;
  final ApiCacheDao _cache;
  ...
  @override
  Future<InviteStats> getStats() async {
    try {
      final stats = await _api.get('/invite/stats', fromJson: ...);
      await _cache.save('invite_stats', stats.toJson());
      return stats;
    } on ApiException catch (e) {
      if (e.isNetworkError) {
        final cached = await _cache.load('invite_stats');
        if (cached != null) return InviteStats.fromJson(cached);
      }
      rethrow;
    }
  }
}
```

### 6.3 redeem 模块

**模型** (`features/redeem/data/redeem_models.dart`)：

```dart
class RedeemCodeRequest {
  final String code;
}

class RedeemCodeResponse {
  final int batchId;
  final String campaignName;
  final int rewardTier;
  final List<RewardItem> rewardItems;
}
```

**Repository**：

```dart
abstract class RedeemRepository {
  Future<RedeemCodeResponse> redeem(RedeemCodeRequest req); // POST /redeem/code
}
```

redeem 无离线回退（提交类操作必须在线）。

### 6.4 rewards 模块

**模型** (`features/rewards/data/rewards_models.dart`)：

```dart
enum RewardType { template, templatePack, achievement }
enum RewardSource { invite, redemption }
enum UnlockStatus { unlocked, claimed }

class RewardItem {
  final RewardType type;
  final String id;
  final String label;
}

class UnlockedReward {
  final int id;
  final int tier;
  final RewardSource source;
  final String? sourceDetail;
  final UnlockStatus status;
  final List<RewardItem> rewardItems;
  final int unlockedAt;
  final int? claimedAt;
}

class RewardsList {
  final List<UnlockedReward> rewards;
}

class ClaimResult {
  final bool success;
}
```

**Repository**：

```dart
abstract class RewardsRepository {
  Future<RewardsList> list();              // GET /rewards
  Future<ClaimResult> claim(int id);      // POST /rewards/:id/claim
}
```

rewards list 离线回退（cache key `rewards_list`）；claim 失败不回退（必须在线确认）。

### 共享类型位置

`RewardItem` / `UnlockedReward` 在 `features/rewards/data/rewards_models.dart` 定义，invite/redeem 模块 `import` 复用，避免循环依赖（invite/redeem → rewards 单向依赖）。

---

## 7. UI 集成点

### 7.1 splash_page.dart（启动页）

现有：1.8s Timer 后 `context.go('/home')`。

新增：监听 `authControllerProvider`：
- `AuthStatus.loading`：显示「正在初始化…」+ 加载指示器
- `AuthStatus.fresh`：触发 `registerIfNeeded()`，UI 显示「正在注册设备…」
- `AuthStatus.registered`：完成 1.8s 后跳转 `/home`（保持原视觉时序）
- `AuthStatus.failed`：显示「网络连接失败，点击重试」按钮，点击触发 `registerIfNeeded()`

### 7.2 profile_invite_page.dart（邀请页）

- `watch(inviteRepositoryProvider.future)` → 拿 `InviteStats` 渲染：
  - 当前 tier / 总邀请数 / 下一档门槛
  - 已解锁奖励列表
- 输入邀请码 → `activate()` → 成功后 SnackBar「邀请码已激活，解锁 X 项奖励」并刷新 stats
- 「生成邀请码」按钮 → `generateCode()` → 显示生成的 code + 复制按钮

### 7.3 个人中心 / 我的奖励入口

- 新增入口卡片在 `profile_page.dart`「我的奖励」
- 跳转到新页面 `rewards_page.dart`（如不存在则新增）
- `watch(rewardsRepositoryProvider.future)` → 渲染 `RewardsList`
- 每个 `UnlockedReward` 卡片：
  - 状态 `unlocked` → 显示「领取」按钮
  - 状态 `claimed` → 显示「已领取」
- 点击领取 → `claim(id)` → 成功后刷新列表

### 7.4 兑换码入口

- 在 `profile_page.dart` 的「设置」分组加「兑换码」入口
- 跳转到 `redeem_page.dart`（如不存在则新增）
- 输入兑换码 → `redeem()` → 成功 SnackBar「已兑换：X 项奖励」并跳转到 rewards 页

### 7.5 错误提示统一

新增 `lib/shared/widgets/api_error_banner.dart`：网络失败时显示在页面顶部，统一文案「网络连接失败，显示的是上次缓存数据」。

---

## 8. 测试策略与鸿蒙适配验证

### 8.1 单元测试

| 测试文件 | 覆盖范围 |
|---|---|
| `test/core/network/api_client_test.dart` | ApiClient 路径解析、超时、错误映射 |
| `test/core/auth/auth_controller_test.dart` | bootstrap 加载已存 auth / 注册新设备 / 401 失效 |
| `test/core/db/migration_v5_test.dart` | v4→v5 升级：auth 表 + api_cache 表创建 |
| `test/features/device/data/device_repository_test.dart` | RemoteDeviceRepository 调用 `/device/register` |
| `test/features/invite/data/invite_repository_test.dart` | 离线回退（mock ApiException network） |
| `test/features/redeem/data/redeem_repository_test.dart` | 兑换成功 / 失败 |
| `test/features/rewards/data/rewards_repository_test.dart` | 列表缓存 / claim 失败不回退 |

### 8.2 Mock 策略

- `ApiClient`：通过 Riverpod `override` 替换为 `FakeApiClient`，硬编码返回 Map
- `AuthController`：通过 `override` 替换为 `FakeAuthController`，预设状态
- `sqflite`：复用 `sqflite_common_ffi`（已有），in-memory DB
- 不引入 `mock_web_server`：直接在 Dart 层 mock，无额外依赖

### 8.3 集成验证清单

实施完成后人工/CI 验证：

1. **后端启动**：`cd lumira-server && pnpm --filter backend dev`，监听 `:3000`
2. **Flutter dev 启动**：`flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1`
3. **首次启动流程**：观察日志 `POST /api/v1/device/register` 200，sqflite auth 表有数据
4. **二次启动流程**：直接读 sqflite，无 `/device/register` 请求
5. **邀请页**：进入 `/profile/invite`，看到 `GET /invite/stats` 调用 + 渲染
6. **激活邀请码**：输入测试 code，看到 `POST /invite/activate` + 解锁奖励 SnackBar
7. **断网模拟**：飞行模式 → 进入邀请页 → 显示「离线模式」+ 上次缓存数据
8. **重连**：关闭飞行模式 → 下拉刷新 → 拉到最新数据
9. **鸿蒙验证**：在 ohos 模拟器/真机上重复 1-8 步，确认 `dio` 纯 Dart 部分工作正常

### 8.4 风险与回退

| 风险 | 触发条件 | 缓解 |
|---|---|---|
| dio 4.0.6 与 meta 1.8.0 冲突 | `flutter pub get` 解析失败 | 在 `dependency_overrides` 钉定 meta |
| 鸿蒙 `Platform.isAndroid` 返回 true | ohos 设备识别失败 | 通过 `device_info_plus` ohos 分支判定 |
| 后端未接受 `os` 字段 | NestJS `forbidNonWhitelisted` | 后端先在 DTO 加 `os` 字段（已在 `lumira-server` 单独提 PR） |
| deviceId 在鸿蒙上获取失败 | `device_info_plus` 9.1.2 在 ohos 上 API 不全 | fallback UUID 持久化 sqflite |
| 真机调试连不上 10.0.2.2 | 真机不是模拟器 | 文档中强调 `--dart-define=API_BASE_URL=http://<局域网IP>:3000/api/v1` |

### 8.5 完成标准

- `flutter analyze` 0 error / 0 warning
- 所有新增测试通过
- 在 Android 模拟器 + 后端本地启动 完整跑通 4 个模块
- 鸿蒙端至少跑通 device 注册（其他模块依赖相同基础设施，理论上同步可用）
- 离线回退在断网场景验证通过

---

## 附录 A：完整文件清单

### 新增文件（共 22 个）

```
lumira_app_flutter/lib/
├── core/
│   ├── config/app_config.dart
│   ├── network/
│   │   ├── api_client.dart
│   │   ├── auth_interceptor.dart
│   │   ├── api_error.dart
│   │   └── api_response.dart  (可选，看是否需要统一包装)
│   └── auth/
│       ├── auth_controller.dart
│       ├── auth_state.dart
│       └── auth_dao.dart
├── features/
│   ├── device/
│   │   └── data/
│   │       ├── device_models.dart
│   │       └── device_repository.dart
│   ├── invite/
│   │   └── data/
│   │       ├── invite_models.dart
│   │       └── invite_repository.dart
│   ├── redeem/
│   │   └── data/
│   │       ├── redeem_models.dart
│   │       └── redeem_repository.dart
│   └── rewards/
│       └── data/
│           ├── rewards_models.dart
│           └── rewards_repository.dart
└── shared/
    └── widgets/api_error_banner.dart

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

### 修改文件（共 5 个）

```
lumira_app_flutter/
├── pubspec.yaml                          # +dio: 4.0.6
├── lib/main.dart                          # 改为 async + bootstrap
├── lib/core/db/database_provider.dart     # +v5 迁移 + authDaoProvider + apiCacheDaoProvider
├── lib/core/db/tables.dart                # +auth 表/api_cache 表常量
└── lib/features/profile/pages/
    ├── profile_invite_page.dart           # 接入 InviteRepository
    └── profile_page.dart                  # + 我的奖励/兑换码入口
```

### 可能新增的 UI 页面

- `lib/features/rewards/pages/rewards_page.dart`（如不存在）
- `lib/features/redeem/pages/redeem_page.dart`（如不存在）

需在 `lib/app/router.dart` 注册新路由 `/profile/rewards` 和 `/profile/redeem`。

---

## 附录 B：后端契约对齐表

| 后端端点 | 方法 | 鉴权 | Flutter Repository 方法 |
|---|---|---|---|
| `/api/v1/device/register` | POST | 无 | `DeviceRepository.register()` |
| `/api/v1/invite/generate` | POST | Device JWT | `InviteRepository.generateCode()` |
| `/api/v1/invite/activate` | POST | Device JWT | `InviteRepository.activate()` |
| `/api/v1/invite/stats` | GET | Device JWT | `InviteRepository.getStats()` |
| `/api/v1/redeem/code` | POST | Device JWT | `RedeemRepository.redeem()` |
| `/api/v1/rewards` | GET | Device JWT | `RewardsRepository.list()` |
| `/api/v1/rewards/:id/claim` | POST | Device JWT | `RewardsRepository.claim()` |

**注意**：后端 `invite/generate` 端点需在实施前确认存在（当前 `app.module.ts` 看到的是 activate + stats，generate 端点需在后端补；如未实现则 Flutter 端先 mock，待后端补齐后切换）。

---

**设计完成**。本设计已与用户对方案 A、JSON 序列化方式（手写）、Token 存储方式（sqflite v5 auth 表）、环境配置方式（dart-define）、离线策略（远程优先回退本地）逐项确认。用户已批准方案并选择 subagent 方式实施，下一步进入实施计划编写。
