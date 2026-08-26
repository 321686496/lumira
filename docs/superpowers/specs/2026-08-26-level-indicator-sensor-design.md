# 水平仪接入加速度传感器 设计文档

- 日期：2026-08-26
- 状态：已批准（用户确认方案后进入实现）
- 相关代码：
  - `lumira_app_flutter/lib/features/capture/widgets/level_indicator.dart`（水平仪 Widget）
  - `lumira_app_flutter/lib/features/capture/data/capture_state.dart`（level providers）
  - `lumira_app_flutter/lib/features/profile/pages/profile_settings_page.dart`（设置页开关）
  - `lumira_app_flutter/lib/core/db/dao/settings_dao.dart`（设置 DAO）

## 背景

相机取景器底部的水平仪（LevelIndicator）目前是纯静态摆设：

- `levelAngleProvider` 永远为 0.0，没有任何传感器代码更新它，气泡不动；
- 设置页"水平仪"开关只是本地 `setState`，不持久化、不控制相机侧水平仪；
- DB `user_settings` 表已预留 `level_enabled` 列（schema 默认 0），但从未使用。

目标：让气泡随手机倾斜实时移动，并把设置开关接上、持久化。

## 决策（已与用户确认）

1. **传感器选型**：加速度计（正确测量倾斜的方式，零漂移）。陀螺仪需积分、会漂移，不用于姿态基准。
2. **平台范围**：全平台含鸿蒙。Android/iOS 用 `sensors_plus`，鸿蒙自研原生插件（项目已有 DeepLinkPlugin/PhotoSaverPlugin 先例）。
3. **设置开关**：接上并持久化（写入 `level_enabled` 列）。

## 架构

```
设置页 水平仪开关 ──→ levelEnabledProvider ──→ LevelIndicator 显隐门控
                        │ persist
                        └─→ SettingsDao.level_enabled 列
                        │
LevelIndicator watch ──→ levelSensorProvider (StreamProvider.autoDispose)
                              │
                              ▼
                        LevelSensorService（平台分发）
                          ├─ 非 OHOS → sensors_plus 4.0.2 (accelerometerEventStream)
                          └─ OHOS   → EventChannel 'lumira/level_sensor'
                                          └─ LumiraSensorPlugin.ets (@ohos.sensor)
```

## 组件设计

### 1. LevelSensorService（Dart，新建）

`lib/features/capture/services/level_sensor_service.dart`

- `LevelSensorService.stream()`：按平台分发（沿用 FilePickerService 的 `!kIsWebEnv && Platform.operatingSystem == 'ohos'` 模式）：
  - 非鸿蒙：`sensors_plus`（版本 4.0.2，min Dart 2.18，兼容项目 Dart 2.19.6）的 `accelerometerEventStream()`
  - 鸿蒙：自研 EventChannel `lumira/level_sensor`，事件为 `[x, y, z]`（m/s²）
- 角度计算（纯函数，可单测）：`angleDeg = atan2(x, y) * 180 / π`（竖持手机左右倾斜的 roll 角，0 为水平）
- 低通滤波（EMA，α≈0.25）：先平滑 x/y 原始值再算角度，消除抖动
- 失败/无传感器：流结束或出错时降级为 `LevelReading.available=false`，气泡回中

### 2. LevelReading 模型

- `double angleDeg`：倾斜角（度）
- `bool available`：传感器是否可用

### 3. 鸿蒙原生插件（新建）

`ohos/entry/src/main/ets/plugins/LumiraSensorPlugin.ets`

- EventChannel `lumira/level_sensor`
- 用 `@ohos.sensor` 订阅加速度计：`sensor.on(sensor.SensorId.ACCELEROMETER, cb, { interval })`
- StreamHandler 逻辑：`onListen` 开始订阅，`onCancel` 调用 `sensor.off` 停止
- 事件载荷：`Float32Array` 或数组 `[x, y, z]`
- 注册进 `ohos/entry/src/main/ets/plugins/GeneratedPluginRegistrant.ets`
- `module.json5` 声明 `ohos.permission.ACCELEROMETER`（普通权限，自动授予），并在 resources string.json 补说明文案

### 4. Provider（数据流）

- `levelSensorProvider = StreamProvider.autoDispose<LevelReading>`：LevelIndicator 挂载即订阅、卸载即自动取消（跟随生命周期、省电）
- `levelEnabledProvider`：保留在 capture_state.dart，初始 true；新增从 DB 加载 + 持久化辅助函数（仿水印 `loadWatermarkSettings` / `scheduleWatermarkPersist` 模式）
- 移除已无用的 `levelAngleProvider`（仅 LevelIndicator 与 reset 使用，改由 provider 直供角度）

### 5. LevelIndicator 增强

- 角度源改为 `levelSensorProvider`，气泡 `bubbleX = center.dx + angleDeg * 系数`（clamp ±10°）
- 新增"水平"状态：`|angleDeg| < 0.8°` 时气泡变绿色（沿用叠在照片上的白/琥珀色系，不引入主题色硬编码）
- 保持 `Positioned` + `Stack` 内使用、`levelEnabledProvider` 门控不变

### 6. 设置开关 + 持久化

- `SettingsDao` 新增：
  - `Future<bool> getLevelEnabled()`：无行或缺省时返回 true（保持当前默认开启行为）
  - `Future<void> setLevelEnabled(bool value)`：写 `level_enabled` 列
- 设置页"水平仪"开关 → `ref.read(levelEnabledProvider.notifier).state = v` + `scheduleLevelEnabledPersist(container)`
- 拍摄页 init 时从 DB 加载 `level_enabled` 到 provider

### 7. 平台配置

- Android：加速度计无需权限
- iOS：`ios/Runner/Info.plist` 增加 `NSMotionUsageDescription`（sensors_plus 要求，防止访问 motion 数据崩溃）

### 8. 测试

- 纯函数单测：`atan2` 角度映射、EMA 平滑、clamp、`LevelReading.fromAccel`
- `SettingsDao` 单测：`getLevelEnabled` / `setLevelEnabled`（含默认值）
- Widget 测试：`levelEnabledProvider=false` 时 LevelIndicator 不渲染；true 时渲染
- 验证：`flutter analyze` + `flutter test` 全绿

## 涉及文件清单

新建：
- `lib/features/capture/services/level_sensor_service.dart`
- `ohos/entry/src/main/ets/plugins/LumiraSensorPlugin.ets`

修改：
- `lumira_app_flutter/pubspec.yaml`（+sensors_plus 4.0.2）
- `ohos/entry/src/main/ets/plugins/GeneratedPluginRegistrant.ets`
- `ohos/entry/src/main/module.json5`（+ACCELEROMETER 权限）
- `ohos/entry/src/main/resources/base/element/string.json`（权限说明文案）
- `lib/features/capture/data/capture_state.dart`（provider 调整）
- `lib/features/capture/widgets/level_indicator.dart`
- `lib/features/capture/pages/capture_page.dart`（init 加载 level_enabled）
- `lib/features/profile/pages/profile_settings_page.dart`（开关接线）
- `lib/core/db/dao/settings_dao.dart`
- `ios/Runner/Info.plist`（+NSMotionUsageDescription）
- 测试文件若干

## 风险与降级

- sensors_plus 无鸿蒙实现：服务层在 OHOS 走自研通道，sensors_plus 的 Dart 代码在 OHOS 不执行，不会 MissingPluginException（仿 file_picker/file_picker_ohos 双包模式）
- 鸿蒙真机传感器需真机验证（模拟器无加速度计数据）；编译通过 + 降级逻辑保证
- 无传感器设备（部分低端 Android）：`onError` 降级，气泡保持居中，不崩溃
