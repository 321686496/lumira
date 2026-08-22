# 后续优化清单（Future Optimizations）

> 本文档独立存放，与 `docs/specs/` 下的功能设计文档分开，专门记录**当前实现已完成、但计划后续再优化的内容**。
>
> **维护规则**：开发过程中若出现“先实现、后续再优化”的点，一律登记到本文件末尾，标注状态；已实现后请更新状态为 ✅已实现。不要混入仍在进行中的功能设计。

## 格式说明

每条记录包含：优先级、模块、优化点、背景/动机、目标状态。

- 优先级：P0 高 / P1 中 / P2 低
- 状态：⏳ 待优化 / 🔄 进行中 / ✅ 已实现

---

## 通知中心（通知中心优化功能）

### P1 · 通知读状态由「本机存储」迁移到「后端数据库」持久化

- **模块**：通知中心（Flutter + NestJS 后端）
- **优化点**：当前（方案 C）后端只下发公告内容并在本机 SQLite 保存已读/清除状态及未读红点。后续改为在数据库中持久化每设备的读状态。
- **背景/动机**：当前产品为设备中心制、离线优先，本机存读状态足够；但后续若同一账号跨设备，读状态无法共享，未读红点与“标记全部已读”将不一致。改为后端持久化可多端同步。
- **目标状态**：
  - 后端新增 `notification_reads`（或并入设备维度）表，记录 `device_id / notification_id / read_at / cleared_at`。
  - 手机端进入通知中心时调用已读/清除接口，红点以服务端计数为准。
  - 保留离线回退：网络不可达时仍可基于本机缓存展示，恢复网络后同步。
- **状态**：⏳ 待优化

### P2 · 通知中心「全部已读/清空」改为统一 Provider 调用

- **模块**：通知中心（Flutter）
- **优化点**：当前通知中心页对「全部已读/清空」通过 `notificationDaoProvider` 直接调用 DAO（`markAllRead`/`clearAll`）再手动 invalidate，而单条已读/清除走 `markAsReadProvider`/`clearNotificationProvider`，风格不一致。
- **背景/动机**：保持状态操作入口统一、便于后续把读状态迁移到后端时统一收口。
- **目标状态**：新增 `markAllReadProvider` / `clearAllProvider`（写操作 + invalidate），页面统一走 provider。
- **状态**：⏳ 待优化

---

## 拍摄页传感器级白平衡（2026-08-22）

### P1 · param_panel.dart 整体迁移到 appThemeProvider/uiStyleProvider（存量 dark/gold 硬编码未主题化）

- **模块**：拍摄页 param_panel（Flutter）
- **优化点**：`param_panel.dart` 相机 Tab 的浮层抽屉整体仍是存量硬编码 dark/gold（`Color(0xFFC9A96E)` / `Colors.white.withOpacity` / 写死 `BorderRadius`/`BoxShadow`），未接入全局「UI 风格 + 主题」系统。本次白平衡 UI（`_WbPresetRow` 等）为保持面板内一致性而沿用既有视觉，未作为全局迁移范围。
- **背景/动机**：AGENTS.md 强制「样式永远跟随设置里的 UI 风格 + 主题」，禁止硬编码色值/阴影表达皮肤观感；存量 panel 未遵守。用户切换 4 套 UI 风格 × 8+1 主题色时该面板不同步。
- **目标状态**：将 param_panel 整体改造为从 `appThemeProvider.tokens/.style/.cardRadius/.cardShadow/.cardBorder/.surfaceAlpha` + `uiStyleProvider` 派生颜色/圆角/阴影/透明度；叠照片浮层按当前风格取向（neumorphic 实心 surface+细边、flat 半透明+细边、glass 半透明玻璃、female 渐变/柔和阴影）。所有新增/存量组件在 4 风格 × 主题下验证。
- **状态**：⏳ 待优化

### P1 · Android 手动色温做真机灰度/灰卡方向复核并按设备归一增益

- **模块**：拍摄页白平衡 · Android（camerawesome CameraX via Camera2Interop）
- **优化点**：`gainsFromKelvin` 按补偿式换算（`kelvinToRgb(5500)/kelvinToRgb(k)`），但 ① 未按设备 `COLOR_CORRECTION_GAINS_RANGE` 归一，暖端 B<1 增益在部分下界=1.0 的机型可能被 HAL 钳掉/拒绝；② `kelvinToRgb` 红通道在 t 略>66 处被 clamp 到 255，导致 3000K 附近 R 增益恒为 1.0 而非 <1；③ 手动色温依赖厂商 ISP 对 `CONTROL_AWB_MODE_OFF`+gains 的适配。
- **背景/动机**：上轮评审（Task 3 re-review）确认补偿方向正确（3000K B>1、8000K R>1/B<1、5500K 全 1），但真机上增益方向是否与物理传感器响应最终一致、低增益是否被钳，需真机灰卡验证。
- **目标状态**：真机在 3000/5500/8000K 下对照灰卡核实 W/B 方向；按 `COLOR_CORRECTION_GAINS_RANGE` 把增益归一到设备允许范围（或将最小通道归一到 ≥1）；必要时解红 clamp 使 3000K R 真正 <1。
- **状态**：⏳ 待优化

### P2 · Android setCaptureRequestOptions 异步失败打日志

- **模块**：拍摄页白平衡 · Android
- **优化点**：`setCaptureRequestOptions` 返回的 `ListenableFuture` 当前被丢弃，`OperationCanceledException`（被更新请求取代）之外的真实失败（如增益被 HAL 拒绝）无任何日志。
- **背景/动机**：便于真机排查白平衡未生效的根因。
- **目标状态**：对 future 挂 `addListener`，对非 `OperationCanceledException` 分支 `Log.w("CameraAwesome", ...)`。
- **状态**：⏳ 待优化

### P2 · OHOS 白平衡需 DevEco 真机构建验证（API 20+）

- **模块**：拍摄页白平衡 · OHOS（camerawesome_ohos CameraKit）
- **优化点**：`session.setWhiteBalance(number)` / `getWhiteBalanceRange()` 为 API 20+ 接口；本机无 DevEco/ohos 工具链，ETS 仅按官方文档编写、未实际编译/打包/真机取景验证。
- **背景/动机**：上轮评审（Task 4）确认通道与枚举映射均与官方 API 证一致，但缺少真机构建这一「documented known-unknown」。
- **目标状态**：在目标 OHOS 设备（系统版本满足 API 20+）经 DevEco 真机构建并验证预设与连续色温取景实时变色、直出即带。
- **状态**：⏳ 待优化

---
<!-- 后续新增的“待优化”条目请追加到本文件末尾，遵循上方格式说明 -->

## 首页场景推荐真实数据化（2026-08-22）

### P1 · 首页场景网格 error 态改为可重试提示而非无限 loading

- **模块**：首页场景推荐（Flutter）
- **优化点**：`_SceneRecoGrid` 对 `homeSceneRecosProvider` 的 `error` 分支直接复用 `_buildSkeleton()`（转圈加载态），DB 异常时首页会永久停在 spinner，用户得不到「加载失败/重试」提示。
- **背景/动机**：计划阶段按「error 与 loading 同构」简化实现；但用户视角下错误被无限转圈掩盖，影响可用性。
- **目标状态**：`error` 分支改为一个带「重试」按钮的空态/错误卡片，点击后 `ref.invalidate(homeSceneRecosProvider)` 重新加载。
- **状态**：⏳ 待优化

### P2 · 场景详情页新增强大圆角改走 tokens.cardRadius

- **模块**：场景详情页（Flutter）
- **优化点**：`capture_scene_detail_page.dart` 新增的 `BorderRadius.circular(10)` / `circular(8)` 为硬编码圆角，未接入 `tokens.cardRadius`。
- **背景/动机**：AGENTS.md 规定圆角一律从主题派生；当前为与计划原文一致而暂用字面量。
- **目标状态**：改用 `tokens.cardRadius`（或对应五级 token），随主题切换。
- **状态**：⏳ 待优化

### P3 · 无源照片缩略图禁用点击

- **模块**：场景详情页「此场景拍摄」（Flutter）
- **优化点**：仅有占位但三条源（filePath/dataUrl/originalPath）全为空的照片，其 `GestureDetector` 仍触发 `_openViewer(i)`，因 `urls` 过滤后变短、`clamp` 会跳到邻近有效索引，点击行为略违背直觉（不崩溃）。
- **背景/动机**：评审时确认 `clamp` 已保证不越界；保持现状符合 brief，故不扩大改动面，仅登记。
- **目标状态**：无有效源的照片 item 置空 `onTap` 或置灰。
- **状态**：⏳ 待优化