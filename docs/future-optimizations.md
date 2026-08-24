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

---

## 相册/拍摄日记滑动多选（2026-08-24）

### P1 · 滑动多选滑动超出可滚动区域时不自动滚动
- **模块**：相册页 / 拍摄日记选照片 popup · `SweepSelectGrid`（Flutter）
- **优化点**：互操作仿 iPhone/微信选图的长按滑动多选已落地，但当手指滑到可滚动 popup / 网格的可见区边缘之外时，`SweepSelectGrid` 不会像微信那样在边缘自动滚动以继续加选下方照片，只能先松开重滑。
- **背景/动机**：`SweepSelectGrid` 外层用裸 `Listener` 接收移动事件，滚动由 `GridView` 自带 `ScrollController` 承接；边缘自动滚动（edge scrolling）需在移动到接近视口上/下边界时主动 `jumpTo`/`animateTo` 补充滚动量，并补偿 `scrollOffset` 命中的几何，当前未实现。
- **目标状态**：在 `_handleMove` 中检测指针接近视口边界（阈值如 48~64px）时按增量推进 `_scrollController`，并让 `GridGeometry.cellAt` 用更新后的 `scrollOffset` 命中后续格子，实现手指在边缘持续滑动即自动滚屏加选。
- **状态**：⏳ 待优化

### P2 · 时间分区跨分区滑动选中仍按“仅分区内连续”
- **模块**：相册页（Flutter）
- **优化点**：当前每分区独立渲染 `SweepSelectGrid`，一次滑动只能在单个分区内连续选中；如手指跨过“今天/昨天”分区间隔，第二个分区的选中需重新长按起始。分区头部已提供「全选/取消全选」兜底。
- **背景/动机**：计划评审时按“仅分区内连续”确认；首版跨分区自动续选复杂度较高，交付方与微信行为略有差异。
- **目标状态**：若后续希望一次长按即可跨分区连续滑动选中，需将分区网格升级为单一可滚网格（保留分区头）或在 `_endSweep`/滑到分区边界时接力到下一分区。
- **状态**：⏳ 待优化

---

## 后端 Redis 缓存 + 集群就绪（2026-08-24）

### P1 · 新增 S3/OSS 对象存储适配器
- **模块**：后端存储层（`common/storage`）
- **优化点**：当前 `StorageModule` 仅提供 `LocalStorageAdapter`（本地磁盘）。抽象接口 `StorageAdapter`/`storageAdapterProvider` 已就绪，但 S3/MinIO/阿里 OSS 的实现尚未编写，`storageAdapterProvider` 也未按 `env` 切换实现类。
- **背景/动机**：本地磁盘在集群多副本下不共享，且 `UPLOAD_DIR` 为单机挂载；切对象存储可解耦实例、提升高可用并可接 CDN。本次为「单机到集群」做存储抽象预留，不急于落地。
- **目标状态**：新增 `S3StorageAdapter`/`OssStorageAdapter` 实现 `StorageAdapter`，`storageAdapterProvider` 依据 `STORAGE_DRIVER`（local/s3/oss）选择实现；存量相对路径 `/uploads/...` 经 `buildAssetUrl` 拼接域名，切换驱动不改前端 URL 约定。
- **状态**：⏳ 待优化

### P2 · Redis 演进为 Cluster / Sentinel 部署
- **模块**：后端 Redis 缓存（`common/redis`）
- **优化点**：`RedisService` 当前为单实例 `redis://` 连接；`REDIS_URL` 仅支持单一地址。用户量上来做后端集群时，Redis 单点会成为瓶颈/故障点。
- **背景/动机**：设计时按单机起步、单例 Redis 足够；集群阶段再演进，避免前期过度设计。
- **目标状态**：`RedisService` 支持 `REDIS_URL` 为逗号分隔的节点列表，自动选择 `Cluster`/`Sentinel` 客户端；`delByPattern` 的 `SCAN` 在 Cluster 下需按槽位执行。
- **状态**：⏳ 待优化

### P2 · 后端上传图片引入压缩 / 缩略图
- **模块**：后端上传链路（admin-templates / admin-categories）
- **优化点**：当前 `storage.write` 原样落盘用户上传的原图，无压缩或缩略图；App 端列表缩略图仍拉取原图。
- **背景/动机**：图片量大后原图直出带宽/存储成本高、首屏慢；前端已用 `/uploads` 路径，改缩略图 URL 需后端产出。
- **目标状态**：写入时基于尺寸生成多规格（原始图 + 缩略图），客户端列表用缩略图、详情用原图；后续接入对象存储时一并支持。
- **状态**：⏳ 待优化