# 拍摄页传感器级白平衡（三端）

> 日期：2026-08-22
> 状态：设计稿（待评审）
> 范围：`lumira_app_flutter/`（Flutter 拍摄页 + camerawesome 三端原生层 + OHOS 依赖本地化）

## 1. 背景与目标

拍摄页目前仅支持曝光 EV 与闪光两种相机调节。模板模型 `CameraParams` 中虽有 `whiteBalance` / `whiteBalanceK` 字段，但从未接到真实相机控制上。目标是在拍摄页提供**传感器级白平衡**——色温/模式直接作用于原生相机传感器，取景器实时生效、拍照直出即带该白平衡，无需任何后处理字节。

### 关键约束（不可妥协）
- **必须是传感器级**（非后处理模拟），各端原生能力为准：
  - iOS（AVFoundation）：可锁定白平衡并设定**真实色温 K + 色调 tint**，最接近 iPhone 原生。
  - Android（CameraX 1.4.0）：仅支持**白平衡模式预设 + 偏移量 offset**，不能任意指定 K 值，需在原生层做归一化适配。
  - OHOS（CameraKit）：支持**模式切换 + 手动色温**。
- 操作粒度：**白平衡模式预设（Auto/日光/阴天/荧光/白炽）+ 手动色温滑块（3000–8000K）**。
- 白平衡为**仅实时会话调节**，不写入模板 `CameraParams`（本次范围不含模板预设联动）。
- 三端一次性完成；UI 风格严格跟随现有「UI 风格 + 主题」（4 风格 × 8 主题），不硬编码。

## 2. 现状盘点

| 层 | 位置 | 现状 |
|---|---|---|
| 拍摄页 UI | `lib/features/capture/widgets/param_panel.dart`（相机 Tab，L333-398） | 只有曝光 EV + 闪光 |
| 相机服务接口 | `lib/features/capture/services/camera_service.dart` | 无白平衡方法 |
| 相机服务实现 | `lib/features/capture/services/camerawesome_camera_service.dart` | 透传 camerawesome `SensorConfig` |
| camerawesome Dart | `packages/camerawesome`（iOS/Android 本地 patch）+ OHOS fork（git fetch） | `SensorConfig` 仅 zoom/flash/aspectRatio/brightness/mirror |
| 模板模型 | `lib/features/capture/domain/photo_template.dart#L351` `CameraParams` | 有 `whiteBalance`/`whiteBalanceK` 字段但未接线 |

> OHOS camerawesome 当前为 pubspec `git:` 依赖（来自 gitcode CPF-Flutter fork），解析自全局 pub 缓存，`flutter pub clear` 会清除本地改动。必须本地化。

## 3. 数据流与分层架构

新增链路由内到外四层，沿用 camerawesome 现有「SensorConfig 订阅 → Plugin 方法通道 → 平台原生」模式（与现有 `setBrightness` 一致）：

```
ParamPanel 相机Tab（预设选择 + 色温滑块）
   │  setWhiteBalance(mode, k)
   ▼
App 层 CameraService.setWhiteBalance(...)   ← 接口新增
   │  透传
   ▼
camerawesome SensorConfig（新增 whiteBalance 模式/色温字段 + 订阅）
   │  CamerawesomePlugin.setWhiteBalance(mode, k)
   ▼
平台原生（Pigeon/MethodChannel → CameraInfo/CameraControl）
   ├── iOS     AVCaptureDevice setWhiteBalanceModeLocked(+setTemperatureAndTint)
   ├── Android CameraX setWhiteBalanceMode + setWhiteBalanceOffset
   └── OHOS    CameraKit whiteBalance mode + color temperature
```

- 手动色温 K 范围统一 **3000–8000K**（与 iOS 一致）。
- 模式预设：Auto / 日光 / 阴天 / 荧光 / 白炽。
- Android 归一化：模式预设原样映射；手动色温 K 按 5500K 中心换算 `setWhiteBalanceOffset`，UI 保持同一滑块语义。

## 4. OHOS 依赖本地化（前置，无功能）

- 将当前 hack 的 camerawesome_ohos fork（pubcache 副本）复制进 `packages/camerawesome_ohos`。
- `pubspec.yaml` 中 `camerawesome_ohos` 由 `git:` 改为 `path: packages/camerawesome_ohos`。
- 目的：三端 camerawesome 全部成为仓库内可改、可同步到 CI 的本地依赖，`flutter pub clear / pub get / clean` 均不影响改动（path 依赖读取仓库源码而非全局缓存）。
- 该改动完成即 commit。

## 5. 三端原生白平衡实现

| 平台 | 挂钩点文件 | 原生实现 |
|---|---|---|
| iOS | `packages/camerawesome/ios/Classes/CameraPreview/CameraPreview.m` | `setWhiteBalanceModeLocked` 锁定，`setTemperatureAndTint` 设色温后恢复锁定；预设映射 `AVCaptureWhiteBalanceMode` |
| iOS | `packages/camerawesome/ios/Classes/CamerawesomePlugin.m` + Pigeon.h/m | 新增 Pigeon 通道注册与实现 |
| Android | `packages/camerawesome/android/.../cameraX/CameraAwesomeX.kt` | `cameraControl.setWhiteBalanceMode(WHITE_BALANCE_*)`；手动色温换算 `setWhiteBalanceOffset` |
| OHOS | `packages/camerawesome_ohos/`（ets 侧原生） | CameraKit `whiteBalanceMode` 切换 + 手动色温；自动模式下 `AWB_LOCK` 语义 |

架构上三端统一：Dart `SensorConfig` 新增白平衡字段 + 订阅 → `CamerawesomePlugin.setWhiteBalance(mode, k)` → 平台 Pigeon/MethodChannel。

## 6. App 层接口与 UI

1. `camera_service.dart`：新增抽象方法 `setWhiteBalance(WhiteBalanceSettings)`（含 mode + k）。
2. `CamerawesomeCameraService`：实现并透传至 `SensorConfig.setWhiteBalance(mode, k)`。
3. `param_panel.dart` 相机 Tab：新增「白平衡」预设选择 + 色温滑块（3000–8000K，非 Auto 时可用）。
4. UI 复用 param_panel 现有 pill / slider 组件，遵循 `appThemeProvider` + `uiStyleProvider`，禁止硬编码主题色。

## 7. 交付顺序与提交策略

- 三端一次性实现并分别真机/模拟器验证（每端验证取景实时变色 + 直出图正确）。
- 提交策略（遵循 AGENTS.md）：OHOS 本地化完成即 commit；每端原生白平衡完成一块 commit 一次；Flutter 前端与 UI 提交一次。每次 commit 后 push 到 `origin`(gitee) + `github` 两个远端。
- 验证要点：各端切换预设/拖拽色温时取景取景实时变化；拍照直出色温符合预期；Auto 恢复正常。

## 8. 风险与注意

- Android 无法任意指定 K 值，手动色温为近似（offset），视觉上在极端值可能有差异，属平台限制。
- OHOS 原生改动需重新编译安装，无法热重载。
- 三端 `SensorConfig`/Plugin 方法需保持 Dart 签名一致，避免平台分支错位。
- 做完本地化后绝不可将 `camerawesome_ohos` 改回 `git:`，否则 `pub clear` 会再次清除改动。