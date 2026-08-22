# Task 5 简报 — App 层 CameraService 接口 + 三端透传

**目标：** 在 App 层把白平衡能力暴露给 UI：`CameraService.setWhiteBalance(WhiteBalanceSettings)` 抽象方法，并让 `CamerawesomeCameraService` 按平台（ohos vs ios/android）透传到对应插件包。

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/services/camera_service.dart`（新增抽象方法）
- Modify: `lumira_app_flutter/lib/features/capture/services/camerawesome_camera_service.dart`（实现透传）
- （如存在并发相机/其它实现服务的 `camera_service.dart` 的实现类，仅需在 `CamerawesomeCameraService` 实现；其它实现类若非目标平台可留空/按现有多平台惯例处理——先读现状确定有哪些实现类。）

**Interfaces:**
- Consumes: Task 1 `WhiteBalanceSettings`（`lib/features/capture/services/white_balance.dart`，`enum WhiteBalanceMode {auto,daylight,cloudy,fluorescent,incandescent}` + `WhiteBalanceSettings`：`mode`、`temperatureK`、`isAuto`）；Task 2/3/4 三端插件 `CamerawesomePlugin.setWhiteBalance(String mode, int? k)`。
- Produces: `CameraService.setWhiteBalance(WhiteBalanceSettings settings)` 抽象方法；`CamerawesomeCameraService.setWhiteBalance` 实现（按平台分派）。

## 全局约束（来自 plan，binding）
- Dart 2.19.6 禁 records；三端插件签名 `setWhiteBalance(String mode, int? k)`。
- 白平衡仅实时会话调节，不写入模板 CameraParams。
- UI 遵循「风格+主题」，但本任务不涉及 UI（Task 6 做 UI）。
- 每端完成一块 commit；commit 后 `git push origin master`（gitee）+ `git push github master`。

## 实现步骤
1. **读现状（必做）**：读 `camerawesome_camera_service.dart` 现有 `setFlashMode`/`setBrightness` 的透传写法（如何判别 ohos/iOS/Android、`_delegate` 或平台字段、import 别名 `ca.`/`ohos.`）。读 `camera_service.dart` 抽象类接口，确认放置位置（`setBrightness` 之类之后）与文件顶部 import（需加 `white_balance.dart`）。若平台分派不是用 `_delegate.platformTag`，以**实际代码**为准复刻。
2. **接口新增**（`camera_service.dart`，放 `setBrightness` 之后）：
   ```dart
   /// 设置传感器级白平衡（预设 + 手动色温 K）。取景实时生效，直出即带。
   void setWhiteBalance(WhiteBalanceSettings settings);
   ```
   文件顶部 import `white_balance.dart`。
3. **实现透传**（`camerawesome_camera_service.dart`，仿 `setFlashMode`/`setBrightness` 的既有多平台分派）：
   ```dart
   @override
   void setWhiteBalance(WhiteBalanceSettings settings) {
     final mode = settings.mode.name; // 'auto'|'daylight'|'cloudy'|'fluorescent'|'incandescent'
     try {
       if (<ohos>) {
         ohos.CamerawesomePlugin.setWhiteBalance(mode, settings.temperatureK);
       } else {
         ca.CamerawesomePlugin.setWhiteBalance(mode, settings.temperatureK);
       }
     } catch (e) {
       debugPrint('[camera] setWhiteBalance failed: $e');
     }
   }
   ```
   以实际存在的 `ca.`/`ohos.` 别名与平台判别表达式为准（保持与 setFlashMode 一致），不要硬凑 plan 里的 `_delegate.platformTag`。
4. **验证**：`cd e:\Project\photo_post\lumira_app_flutter; flutter analyze` 无因本次改动新增 error。
5. **Commit + push**（只 add 这两个 service 文件）：
   ```
   git add lumira_app_flutter/lib/features/capture/services/camera_service.dart lumira_app_flutter/lib/features/capture/services/camerawesome_camera_service.dart
   git commit -m "feat(camera): CameraService 暴露白平衡 setter 并透传三端"
   git push origin master ; git push github master
   ```
   **严禁** add 游离文件（lib/features/search/...、lib/features/templates/...、docs/superpowers/plans/reports/ 下未提交项、.trae/tasks/）。

## 不确定就问
若 `camera_service.dart` 有多个平台实现类、或平台判别方式与描述不一致，先读清楚再按实际结构补；仍不确定 BLOCKED/NEEDS_CONTEXT 上报。

写详细报告到 `e:\Project\photo_post\docs\superpowers\plans\reports\task-5-report.md`（新建）。返回（15 行内）：Status + commit SHA/主题 + 测试摘要 + concerns + 报告路径。