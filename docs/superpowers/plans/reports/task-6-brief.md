# Task 6 简报 — 拍摄页 param_panel 相机 Tab 白平衡 UI（预设 + 色温滑块）

**目标：** 在拍摄页的 param_panel 相机 Tab 新增「白平衡」控制：预设 pill（Auto / 日光 / 阴天 / 荧光 / 白炽）+ 手动色温滑块（3000–8000K，仅非 Auto 可选）。用户在设置里切换 UI 风格/主题时外观随之变化；选择变化即实时调用 `cameraService.setWhiteBalance(settings)` 让取景实时生效。

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/widgets/param_panel.dart`（相机 Tab）
- Modify: 持有 `CameraService` 并接线 `setWhiteBalance` 的地方（`capture_page.dart` 或相机 Tab 的控制器/provider——先读现状确定接线点）

**Interfaces:**
- Consumes: Task 5 `CameraService.setWhiteBalance(WhiteBalanceSettings)`；Task 1 `WhiteBalanceSettings` / `WhiteBalanceMode`（`lib/features/capture/services/white_balance.dart`）
- Produces: 相机 Tab 新增「白平衡」预设 pill + 色温滑块

## 全局约束（binding，来自 plan + AGENTS.md 强制 UI 规范，务必遵守）
- Dart 2.19.6：**禁止 Dart 3 records**。
- 白平衡**仅实时会话调节**，不写入模板 `CameraParams`（不要往 CameraParams 存白平衡）。
- **样式永远跟随「设置里的 UI 风格 + 主题」**：所有颜色/圆角/阴影/透明度从 `appThemeProvider`（`AppThemeData.tokens` / `.style` / `.cardRadius` / `.cardShadow` / `.cardBorder` / `.surfaceAlpha`）+ `uiStyleProvider` 派生。用 `ConsumerWidget` + `ref.watch(appThemeProvider)`。**禁止** `Colors.xxx`、`Color(0xFF...)`、写死 `BoxShadow`/`BorderRadius` 来表达皮肤/主题观感。唯一合法例外是叠在照片上的黑/白半透明遮罩。
- **param_panel 若叠在照片上（浮层/浮卡）**：遵循 AGENTS.md「叠照片取向」表：
  - neumorphic → 实心 `surface` + 细边，无阴影、无模糊
  - flat → 半透明 surface/surfaceAlt + 细边
  - glass → 该风格自己的半透明玻璃（允许模糊）
  - female → 该风格自己的渐变/柔和阴影
  - 先读现有 param_panel 已按风格实现的浮层组件（pill/slider）并复用其样式语义，不要另起一套视觉语言，更不要把别套风格语法塞进来。
- **复用现有组件**：优先复用 param_panel 里既有的 pill/segmented 与 slider 组件（曝光 EV slider / 比例 pill 等的样式与接线方式）。
- 预设与色温映射：`WhiteBalanceMode.auto`→Auto、`daylight`→日光、`cloudy`→阴天、`fluorescent`→荧光、`incandescent`→白炽；手动 K 3000–8000、步进 100、默认/中心 5500。

## 实现步骤
1. **读现状（必做）**：读 `param_panel.dart` 相机 Tab（约 L333-398），看曝光 EV slider 与比例/闪光 pill 的组件、状态管理方式（StatefulWidget 本地状态 or Riverpod provider）、以及它们如何调 `cameraService`。确认接线点（谁持有 CameraService 实例）。
2. **接入状态**：新增本地状态保存当前 `WhiteBalanceSettings`（默认 `WhiteBalanceMode.auto`、temperatureK null）。当预设/滑块变化时调用持有 CameraService 的接线点 → `cameraService.setWhiteBalance(settings)`。
3. **UI 新增**：
   - 预设行：复用一个现有 pill/segmented 组件，5 项 `Auto / 日光 / 阴天 / 荧光 / 白炽`，映射到 `WhiteBalanceMode`。
   - 手动色温行：一个 slider（min 3000、max 8000、步进 100），**仅当选中非 Auto 预设时显示/可调**；当前值显示为 `XXXX K`。
   - 全部颜色/圆角/阴影从 theme/style 取，禁止硬编码；叠照片浮层按当前风格取向（见约束）。
   - 切换/拖动即实时生效（调 setWhiteBalance），切回 Auto 恢复（plugin 端已处理 auto 复位）。
4. **联调（本机可能无真机）**：`flutter analyze` 通过。若你能提供预览/主平台说明本地状态刷新逻辑正确。
5. **验证**：`cd e:\Project\photo_post\lumira_app_flutter; flutter analyze` 无因本次改动新增 error（存量 info 忽略）。
6. **Commit + push**（只 add 你动的 capture 相关文件）：
   ```
   git add lumira_app_flutter/lib/features/capture/widgets/param_panel.dart lumira_app_flutter/lib/features/capture/pages/capture_page.dart (按实际接线点)
   git commit -m "feat(camera): 拍摄页白平衡预设+色温滑块 UI"
   git push origin master ; git push github master
   ```
   **严禁** add 游离文件（lib/features/search/...、lib/features/templates/...、docs/superpowers/plans/reports/ 下未提交项、.trae/tasks/）。

## 不确定就问
对 param_panel 的组件复用方式、接线点、状态管理不确定，先读清楚再按要求实现；仍不确定 BLOCKED/NEEDS_CONTEXT 上报。请勿把白平衡写入模板 CameraParams。

写详细报告到 `e:\Project\photo_post\docs\superpowers\plans\reports\task-6-report.md`（新建）。返回（15 行内）：Status + commit SHA/主题 + 测试摘要 + concerns + 报告路径。