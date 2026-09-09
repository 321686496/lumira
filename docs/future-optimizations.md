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

---

## 拍摄页点按对焦 + AE/AF 锁定（2026-08-24）

### P1 · iOS 对焦锁定时机：fire-and-forget 自动对焦后立即锁 lensPosition
- **模块**：拍摄页点按对焦 + AE/AF 锁定 · iOS（camerawesome `CameraPreview.m`）
- **优化点**：iOS 端锁定采用「先触发自动对焦（fire-and-forget）后立即 `setFocusModeLocked(lensPosition:)`」的方式，锁定的镜头位置可能不是最终合焦位置，真机场景画面可能轻微失焦。
- **背景/动机**：任务评审确认该实现为首版可行方案，但「锁定位置是否等于最终合焦位置」未在真机核验。
- **目标状态**：真机核验锁定后画面清晰度；若失焦，改为等待对焦收敛（观察 `AVCaptureDevice.isAdjustingFocus`）后再读取 `lensPosition` 并锁定，或采用连续对焦收敛后锁定的策略。
- **状态**：⏳ 待优化

### P1 · OHOS 设备旋转一次后 AF 锁定静默回退为 CONTINUOUS_AUTO（AF/AE 不一致）
- **模块**：拍摄页点按对焦 + AE/AF 锁定 · OHOS（camerawesome_ohos `CameraAwesomeX.ets`）
- **优化点**：锁定调用 `setFocusPoint` 会注册一次性方向传感器监听（既有行为）；设备旋转一次后，AF 锁定会静默回退为 `CONTINUOUS_AUTO`，而 AE 仍保持 `LOCKED`，造成 AF/AE 状态不一致。
- **背景/动机**：任务评审确认该回退为既有方向监听机制的副作用，非本功能引入，但破坏锁定语义。
- **目标状态**：绕过方向传感器监听（锁定期间不响应旋转），或在 `setFocusAndExposureLockFn` 中加锁定状态守卫：处于 AE/AF 锁定态时忽略方向回调、保持锁定模式；解锁后再恢复旋转响应。
- **状态**：⏳ 待优化

---

## 模板推荐（个性化引擎）

### P1 · user_interests 半衰期/权重参数用真实数据 A/B 校准

- **模块**：模板推荐（个性化引擎·Flutter）
- **优化点**：`user_interests` 默认 14 天半衰期、0.50/0.30/0.20 三维权重为经验初始值。
- **背景/动机**：半衰期与三维权重当前为经验初始值，未经真实行为数据验证，需结合实际效果校准以提升推荐准确度。
- **目标状态**：基于曝光/完成率埋点回灌调参，用真实数据 A/B 校准参数。
- **状态**：⏳ 待优化

### P1 · 模板详情页底部新增「为你推荐」同类板块（同 category/majorStyle 用 TemplateRanking 排序）

- **模块**：模板推荐（个性化引擎·Flutter）
- **优化点**：详情页当前无推荐，浏览后缺乏二次推荐入口。
- **背景/动机**：用户浏览单个模板详情后缺少同类/相关模板的引导，浏览到使用之间断层，影响连续使用。
- **目标状态**：详情页底部展示个性化同类模板（同 category/majorStyle 用 TemplateRanking 排序）。
- **状态**：⏳ 待优化

### P2 · 「不感兴趣」显式负反馈 + 「分享模板」信号接入

- **模块**：模板推荐（个性化引擎·Flutter）
- **优化点**：当前仅正反馈（拍摄/详情/收藏），无负反馈剥离；分享未挂接。
- **背景/动机**：缺负反馈导致不受欢迎模板持续被推荐；分享为强正反馈信号却未进入画像。
- **目标状态**：短期屏蔽同类 + 分享加权。
- **状态**：⏳ 待优化

---

## 模板收藏（2026-08-26）

### P2 · 收藏变化触发「全部模板」页整页 `_loadData` 重跑
- **模块**：模板收藏 · 全部模板页（Flutter）
- **优化点**：`templates_all_page.dart` 在 `build` 顶部 `ref.watch(favoriteTemplateIdsProvider)` 以响应收藏变化；每次收藏 toggle 都会重建页面并令 `FutureBuilder` 生成新 future，重新执行完整查询（builtin/remote/custom、gallery 计数、分类子树键）。这与本页既有「任意 setState 即全量重载」模式一致，非回归，但收藏变更属高频轻量事件，重跑全量较重。
- **背景/动机**：收藏过滤需要待 `favoriteTemplateIdsProvider` 就绪的收藏集合，且要在收藏后自动刷新列表；简单方案即整页重载。后续收藏体量大时可只重筛、不重拉全量数据。
- **目标状态**：将收藏过滤从 `_loadData` 拆出，收藏变化仅对已渲染的列表做增量 `where` 收缩/恢复，避开全量 DAO 查询；或在 provider 内缓存收藏集合以避免整页重建。
- **状态**：⏳ 待优化

---

## OHOS 拍照质量与速度优化（2026-08-27）

### P1 · OHOS 拍照改用分段式拍照（photoAssetAvailable 两阶段出图）
- **模块**：拍摄 · OHOS（camerawesome_ohos `CameraState.ets` + Flutter `capture_page.dart`）
- **优化点**：当前为单段式拍照（photoAvailable 单回调，实测全程 ~1900ms）。HarmonyOS 官方分段式拍照先回调低质量快图（FAQ 实测 ~672ms 可用）再回调高质量图，拍摄体验显著更优。
- **背景/动机**：本次已落地「拍照分辨率上限 3M→8.2M + 画质优先策略（API 21+ HIGH_QUALITY，系统侧）」两项优化；分段式拍照需切换到 photoAssetAvailable 回调 + photoAccessHelper 媒体库链路，媒体库「增强图」存在偏黄复发风险（与 iOS 偏黄问题同源），且 capture_page.dart 正被 iOS 偏黄会话并行修改，为避免冲突与风险叠加延后。
- **目标状态**：iOS 会话收敛后，改用 photoAssetAvailable 两阶段回调：第一阶段快图先上屏预览，第二阶段高质量图替换落库；同步验证媒体库增强图色彩与 photoAvailable 直出图一致。
- **状态**：⏳ 待优化

---

## 后期裁剪 WYSIWYG 修复（2026-08-27）

### P1 · TransformParams 烘焙后显示双重应用（跨轮编辑显示层）

- **模块**：后期编辑 · 裁剪/旋转（Flutter `gallery_edit_page.dart` / `capture_preview_page.dart`）
- **优化点**：保存时 `processFile(transform: _localTransform)` 已把旋转/翻转/拉直烘焙进 JPEG 像素，DB 记录也存了同一 `transform`；下一轮编辑加载时 `_localTransform = photo.transform` 又在显示层（`_CanvasArea` / `CropOverlay._applyTransform`）叠加同一变换，显示双重旋转，且裁剪框坐标基于双重变换视图、与单次变换的导出管线不一致。
- **背景/动机**：本次裁剪修复聚焦无变换场景的坐标基准（比例基准区域 ⊕ 嵌套裁剪），transform+裁剪跨轮组合的显示层双重应用牵涉「DB transform 语义改为增量/显示层改读烘焙态」的模型调整，超出本轮修复范围，先行登记。
- **目标状态**：明确 `transform` 存储语义（建议：存「从原图累计的变换」，显示层不再叠加——因为照片已烘焙；或改为存增量、导出时与历史变换合成），`_applyPhotoFromHistory`/`_loadPhoto` 加载烘焙态照片时显示层用恒等变换，裁剪 UI 与导出管线共用同一变换语义。
- **状态**：⏳ 待优化

### P2 · 拍摄 facing（前/后摄）未持久化到 DB 记录

- **模块**：拍摄落库 · 后期重新处理（Flutter `capture_page.dart` / `photo_post_processor.dart`）
- **优化点**：落库的 `GalleryItemRecord` 未存拍摄时 facing；编辑保存从原图重新处理时 `processFile` 的 `facing` 入参取默认 `'back'`，前置拍摄的照片在重新处理时方向对齐（`_alignOrientation` 的镜像判定）可能与拍摄时不一致。
- **背景/动机**：本次裁剪修复把 `cropRatio` 落库自愈（`resolveCropSavePlan` + `resolveBaseRatio`），facing 的持久化同样属于「编辑重建参数不完整」家族问题，但影响面较窄（仅前置摄照片重处理的镜像），先行登记。
- **目标状态**：`GalleryItemRecord` 增加 facing 字段（或并入 postProcess JSON），拍摄落库时写入；编辑保存 `resolveCropSavePlan` 读取并传给 `processFile(facing:)`。
- **状态**：⏳ 待优化

---

## 首页扫一扫（2026-08-31）

### P2 · 邀请海报二维码由占位图改为真实可扫码二维码

- **模块**：邀请海报（Flutter `invite_poster_card.dart` `_MockupQr`）+ 首页扫一扫
- **优化点**：`invite_poster_card.dart` 的邀请海报二维码当前为确定性伪随机网格占位图（`_MockupQr`），不可真实扫码。首页「扫一扫」本次仅支持识别真实二维码文本，海报上的占位码无法被相机/相册识别，导致「扫一扫 → 邀请码预填」流程无法从海报端闭环验证。
- **背景/动机**：设计文档（`docs/specs/2026-08-31-home-scan-qr-design.md`）明确本次不改造邀请海报二维码，仅让扫一扫能识别邀请码文本并跳转预填；将占位图改为真实二维码后，海报可直接被扫一扫识别并跳转邀请页预填，形成完整闭环。
- **目标状态**：邀请海报渲染真实可扫码二维码（编码邀请码文本或邀请链接），与模板分享海报的二维码实现一致；验证可被首页扫一扫识别并跳转邀请页预填。
- **状态**：⏳ 待优化

---

## iOS 取景器-成片一致性 WYSIWYG 直出（2026-09-02）

### P1 · 取景器原生实时效果管线（磨皮/锐化/清晰度/颗粒/暗角逐帧实时预览）

- **模块**：拍摄 · iOS（camerawesome `CameraPreview.m` 视频帧管线 → 原生 CoreImage/Metal）
- **优化点**：本轮成片改为「取景器 video 帧直出（WYSIWYG）+ Dart 只叠加与取景器相同的用户色彩矩阵」，从根因上消除了「预览≠成片」的色差（不再依赖 photo 管线 + 内容自适应白平衡启发式）。但磨皮/锐化/清晰度/颗粒/暗角仍由 Dart 在拍后 worker isolate 处理，**取景器无法实时预览**这些内容类效果（色彩矩阵本身已可实时预览）。
- **背景/动机**：完整的「取景器全效果实时」需要把整套效果链下沉原生逐帧渲染（CoreImage/Metal GPU 逐帧磨皮掩膜 + 锐化 + 暗角 + 颗粒 + sRGB 统一），工作量与真机调参成本高、全在 iOS 原生层、风险较大。为优先解决用户「实时预览与成片严重不一致」的核心诉求，先落地低风险、可保证一致性的 WYSIWYG 直出，实时效果透传作为后续单独推进。
- **目标状态**：在原生视频帧管线接入逐帧效果 Pipeline（参数经 MethodChannel 透传），取景器实时显示磨皮/锐化/清晰度/暗角/颗粒，且与 WYSIWYG 成片严格一致。
- **状态**：⏳ 待优化

### P2 · WYSIWYG video 帧最大分辨率可能低于 photoOutput 全尺寸

- **模块**：拍摄 · iOS（`CameraPreview.m` 的 `captureVideoFrameToJpegAtPath`）
- **优化点**：非闪光成片改走 `AVCaptureVideoDataOutput` 取景器帧直出，其输出分辨率受 session preset / 视频输出规格限制，极端情况下可能低于 `AVCapturePhotoOutput` 的全尺寸快照。当前 App「高清」档输出封顶 1280px（`CaptureResolutions`），不受影响；仅当用户切换到更高分辨率档位（接近全尺寸）时可能强度不足。
- **背景/动机**：苹果不允许 video 与 photo 输出同时满规格，二者是折中选择；颜色一致性（用户核心诉求）优先于极限分辨率。
- **目标状态**：若未来开放「全尺寸」分辨率档位，权衡在固定 video 输出规格下取到 App 所需最高分辨率，或按分辨率档位决定 photoOutput（牺牲一致性）与 video 直出（保一致性）的取舍开关。
- **状态**：⏳ 待优化

---

## 拍摄页延迟拍照（2026-09-04）

### P2 · resetAll 可选复位延迟拍照时长

- **模块**：拍摄（capture_state.dart 的 CaptureState.resetAll）
- **优化点**：resetAll 重置了 zoomProvider/aspectRatioProvider 等相机 UI 状态，但未重置新加的 delayTimerProvider（保留上次用户所选时长）。
- **背景/动机**：当前设计未要求；保留已选时长属合理 UX（跨会话持续）。若希望跟随返回拍摄页复位，只需在 resetAll 补 delayTimerProvider = 0，成本极低。
- **目标状态**：按产品语义决定是否在 resetAll 一并复位延迟档位。
- **状态**：⏳ 待优化

### P2 · 倒计时节拍跟随快门声开关

- **模块**：拍摄（capture_page.dart _startDelayCountdown）
- **优化点**：延时倒计时每 tick 无条件 SystemSound.click，不尊重 CaptureState.shutterSoundProvider；用户关闭快门声后节拍仍响。
- **背景/动机**：设计未明确节拍是否跟随该开关。
- **目标状态**：节拍是否播放跟随 shutterSoundProvider，或提供独立开关。
- **状态**：⏳ 待优化

### P2 · 比例/模板切换时取消倒计时（spec 边界语义补齐）

- **模块**：拍摄（capture_page.dart）
- **优化点**：设计「边界」第 4 条声明「切换前后摄像头/比例/模板 → 取消倒计时」，当前仅实现了前后摄像头（_switchCamera）取消，比例切换与模板切换未接；倒计时浮层用 IgnorePointer 全屏穿透，顶部 AspectRatioSelector 仍可触达，倒计时归零读取新 ratio 成片。
- **背景/动机**：非破坏性偏差，评审定为 Minor。
- **目标状态**：按设计在各比例/模板切换入口补 _cancelDelayCountdown()，或明确改为「倒计时仅由摄像头切换/dispose 取消」。
- **状态**：⏳ 待优化

### P2 · 延迟拍照菜单 4 风格自适应

- **模块**：拍摄（widgets/delay_timer_button.dart）
- **优化点**：DelayTimerButton 的菜单/胶囊为 iOS 风格硬编码（暗底 0xFF141416、菜单 0xFF26262A、白字、强调色 0xFFC9A96E），当前不随 4 套 UI 风格/主题变化（符合设计 brief 的「叠相机浮层的 iOS 风格」规定，且 iOS 浮层本就主题无感）。
- **背景/动机**：后续若希望延迟按钮在多风格下表现一致，需要接入 token。
- **目标状态**：按需从 appThemeProvider 派生菜单/胶囊配色，或在 4 风格下均采用 iOS 统一浮层观感并弱化当前无用的 theme_controller 依赖残留情况。
- **状态**：⏳ 待优化


---

## OHOS 取景器实时美颜（2026-09-05）

### P0 · 取景器实时美颜原生化（B3 正式方案；Dart 过渡方案已停用）

- **模块**：拍摄（camera_preview.dart / preview_beauty_shader.dart → 目标：ImageProcessorPlugin/XComponent 原生）
- **优化点**：曾用「Ticker 逐帧 RepaintBoundary.toImage → FragmentShader 单 pass → 叠加显示」的 Dart 层方案实现取景器实时锐化/磨皮/颗粒/暗角。**2026-09-05 已整体停用并删除 **_LiveBeautyLayer**：OHOS GPU 读回单帧需数百 ms（快门冻结帧实测 455ms@1.0x，叠加层按 DPR 级采样更慢），取景器在开启磨皮/锐化/颗粒/暗角任一项后沦为幻灯片；且 radius-1 的 5-tap 磨皮核在预览分辨率下视觉不可感知。当前取景器回退纯 ColorFiltered（色彩/亮度等矩阵类效果仍实时预览），磨皮/锐化/颗粒/暗角仅作用于成片。
- **背景/动机**：设计文档（2026-09-04-ohos-camera-capture-performance-design.md）B3 定义的正式方案是 XComponent 原生渲染取景器实时美颜，Dart 层逐帧读回在 OHOS 上架构性不成立（GPU→CPU readback 延迟不可接受）。
- **目标状态**：按 B3 在 ImageProcessorPlugin/XComponent 原生侧用 OpenGL ES 片元着色器直接渲染预览效果（对齐 iOS PreviewEffectProcessor 的统一内核：锐化/颗粒/磨皮/暗角一遍合成），Dart 层仅透传参数；实现后「成片效果 = 取景器效果」闭环。
- **状态**：⏳ 待优化

### P2 · 成片锐化/磨皮强度补偿（HDR 区间与预览感知度对齐）

- **模块**：拍摄 · 成片链（OHOS C++ photo_processor.cpp / Dart dart_photo_pipeline.dart / iOS PreviewEffectProcessor.m）
- **优化点**：锐化响应曲线最终定档 a=v/100×6.0（上限 6.0，四端统一，2026-09-06 第三次修正后定档）。历程：×6.0 原始值（真机可感知）→ 误回调 1.2（四端同步，拉满无感：硬边缘增益仅 ~2.7/255）→ iOS 单独 2.5（仍无感）→ 恢复 6.0。1.2/2.5 均低于人眼可感知阈值；当时「×6.0 效果过重」的反馈实为 iOS kernel 坐标 bug（黑屏/压暗）叠加所致，kernel 修复后纯 6.0 即正常观感。磨皮因 5-tap 内核分辨率语义限制，成片与预览的感知强度仍存在差异。
- **背景/动机**：真机反馈「锐化拉满无感」两轮；每轮根因不同（第一轮 OHOS 死区阈值 4.0→1.0；第二轮 iOS kernel 非 ASCII 编译失败 + 全端强度过低）。iOS 取景器锐化/颗粒/磨皮/暗角整体静默失效的根因：CIKernel 源码字符串内含非 ASCII 字符（中文注释）导致编译失败、kernelWithString: 返回 nil——已清理为纯 ASCII 并补编译失败日志。iOS 颗粒取景器「几条黑线」根因（2026-09-07 终版，修正 2026-09-06 的相位误诊）：噪声采样用裸 tile 局部坐标（全 kernel 唯一不经过 samplerTransform 的采样点），CI 的 sampler 坐标空间/GPU 路径对非常规采样模式处理异常；−0.5 相位/clamp [0,127]/[0.5,127.5] 三轮相位修复均不改变症状，证明根因是裸坐标采样本身。已改为「tiledNoiseImageForWidth 烘焙同尺寸平铺噪声图 + 1:1 samplerTransform 采样」彻底修复（与 image/blur 采样完全同构）。
- **目标状态**：真机验证 6.0 响应曲线四端观感（明显但不过度、无 halo 破坏）；按需微调磨皮强度/核半径与颗粒幅度。
- **状态**：🔄 进行中

### P2 · iOS 预览工作分辨率跟随成片分辨率档位

- **模块**：拍摄（packages/camerawesome/ios PreviewEffectProcessor.m）
- **优化点**：取景器效果处理的工作分辨率固定为长边 1280（对齐成片默认档「高清 maxDim=1280」），不随设置里的成片分辨率档位（standard 1080 / smooth 720）切换。
- **背景/动机**：2026-09-06 修复「锐化拉满无效果 / 颗粒与成片不一致」时确立预览工作分辨率机制（sensor-native 12MP 帧 → 1280 长边 cap，效果与成片同尺度执行）。档位切到 standard/smooth 时成片效果尺度随之变化，预览颗粒密度与成片会有 ±20%~78% 的视觉差异（档位语义本身允许）。
- **目标状态**：通过 updatePreviewEffects 把当前档位 maxDim 传到 iOS 原生侧，renderSync 用其作为 kPreviewWorkLongSide 动态 cap。
- **状态**：⏳ 待优化

---

## 磨皮 σ 跨端统一（2026-09-07）

### P1 · OHOS 原生磨皮 σ 对齐到「(9+15s)×longSide/1280」视觉尺度体系

- **模块**：拍摄 · 成片链（OHOS C++ photo_processor.cpp smoothSkin / preview_fx.cpp）
- **优化点**：2026-09-07 修复 iOS/Flutter 成片磨皮质量时，将 Dart CPU（skin_smoother.dart）、成片 GPU（skin_smooth.frag）、编辑页预览（edit_detail_effects.frag）统一为 σ=(9+15s)×longSide/1280 的「随分辨率缩放」尺度体系（与 iOS 取景器 CIGaussianBlur σ=9+15s @1280 长边一致）。但 OHOS 原生 smoothSkin/preview 仍是旧体系：1/3 分辨率下 σ=3+5s（折算全分辨率 ≈9+15s 固定像素，不随成片分辨率缩放）。两体系在 1280 长边成片上恰好重合，但在其他分辨率档位（1080/720/全尺寸）下 OHOS 与 iOS 的磨皮视觉尺度会有偏差。
- **背景/动机**：OHOS 真机当前观感已验收（成片与 OHOS 取景器自洽），暂不动；跨端一致性留给后续统一。
- **目标状态**：OHOS C++ 侧 σ 改为 (9+15s)×longSide/1280（在降采样图上按比例折算），与 iOS/Dart/三 shader 全端一个公式；改后需 OHOS 真机回归验证磨皮观感与 800ms 性能预算。
- **状态**：⏳ 待优化
---

## 拍摄预览页编辑改版遗留（2026-09-08）

### P2 · 改版终审 Minor 三项 + 死代码清理

- **模块**：拍摄 · 预览页（capture_preview_page.dart；preview_edit_panel.dart 内 FilterThumbnail）
- **优化点**：
  1. FilterThumbnail 无 errorBuilder——滤镜缩略图源文件失效时渲染异常（与修图页共用组件的既有模式，非本次引入）；
  2. FilterThumbnail 仅识别 http 前缀走网络，data: URL 会走 File() 解码失败（自定义模板图已改存绝对路径，实际触发概率极低）；
  3. 拍摄预览页裁剪模式下对比按钮未隐藏（修图页裁剪时隐藏；规格要求「编辑全程随手可看」故不算缺陷，仅交互一致性差异）；
  4. capture_preview_page.dart 的 _computeDeltaPostProcess 死代码（改版前 HEAD 即未使用，analyze info 预存）。
- **背景/动机**：2026-09-07 拍摄预览页编辑改版（commits d16c4191..b90f076c）终审 3 项 Minor + 1 项死代码 info，均不阻塞合入，登记后续处理。
- **目标状态**：FilterThumbnail 补 errorBuilder 与 data: 分支；裁剪模式对比按钮显隐对齐修图页（或明确保持并注明）；删除死方法。
- **状态**：⏳ 待优化

---

## 首页 Banner 运营化（2026-09-08）

### P1 · 后端运营 Banner 下发系统 + 后台运营位管理页

- **模块**：首页 Banner 运营位（`docs/specs/2026-09-08-home-banner-operations-design.md`）
- **优化点**：当前运营位走 App 端静态运营条目配置（`operation_banners.dart`），运营改文案/上下线需发版。后续建后端下发通道 + 后台运营位管理页，可在不改 App 的情况下投放/下线运营 Banner。
- **背景/动机**：设计时确认后端无运营下发能力，新建后端+后台运营模块属大工程，先以 App 端配置落地；条目模型与 `BannerType` 已对齐渲染层与埋点层，未来仅需把配置源从本地静态 swap 成远端拉取。
- **目标状态**：后端新增 `banners`(运营条目)表与下发接口，后台运营位管理页可增删改/上下线/设展示条件与时间窗；App 端 `operation_banners.dart` 改为从远端拉取、离线回退本地缓存；字段与 `OperationBanner`/`OperationCondition` 对齐。
- **状态**：⏳ 待优化

### P2 · 运营位 A/B 实验与人群定向投放

- **模块**：首页 Banner 运营位（Flutter + 可选后端）
- **优化点**：当前运营条目仅按 `OperationCondition` 做单一条件判定，无 A/B 分流与人群定向（时段 / 常拍分类 / 活跃度等）。
- **背景/动机**：首版聚焦「能投放、可埋点观测点击率」，暂不做复杂投放引擎。
- **目标状态**：基于 `banner_id` 埋点做 A/B（同目标多套素材对比点击率）；运营位按用户画像字段做人群定向。
- **状态**：⏳ 待优化

---

## iOS 白平衡极值色斑修复（2026-09-08）

### P2 · 极端色温「K 边界 + LSC 限幅」真机标定

- **模块**：拍摄 · iOS 白平衡（CameraPreview.m：IsExtremeWbTemperature / ClampExtremeWbGains / SetWbGlobalToneMapping）
- **优化点**：极端色温中央色斑第三轮修复（第一轮 49779953 增益软封顶+残差补足；第二轮 全局色调映射增益阈值>2.0——两轮均因触发条件从未命中而失效：maxGain×0.70≈5.6 远高于 3000K 目标增益 2~3.5，封顶不咬合；部分机型 3000K 目标增益 ~1.8 低于 2.0 阈值）。第三轮改为按 K 值判定（≤3400K / ≥7600K 为极端，覆盖滑杆 3000/8000，不含模板 3600-7200），极端时硬件增益限幅 2.0x（LSC 安全区）+ 残差软件补足 + 全局色调映射 + 状态回读日志。待标定项：(1) 3400/7600 边界是否与真机色斑实际出现的区间一致（若 3500K 仍现色斑需放宽）；(2) 2.0x 限幅是否足以让 LSC 保持在校准范围（若仍现色斑降至 1.5x 或 1.0x 全软件）；(3) 论坛 130735 报告的「全局映射 true→false→true 后不再生效」在当前 iOS 版本是否复现（回读日志 `toneMapping=local` 且 extreme=1 即命中，需改设顺序绕过）。
- **背景/动机**：三处参数均为工程估值，需真机 `[WB] k=... extreme=... toneMapping=...` 日志与观感反馈校准。
- **目标状态**：真机多机型验证 3000-8000K 全滑杆无中央色斑；若 LSC 限幅仍不足，评估极端档全软件白平衡（硬件增益锁 1.0x，全部色温偏移由矩阵承担，代价是高光通道软件裁切）。
- **状态**：⏳ 待优化

---

## 搜索页比例筛选 + 抖音式标签搜索（2026-09-09）

### P2 · 远端模板比例筛选依赖本地已缓存详情

- **模块**：搜索页 · 模板比例筛选（`docs/specs/2026-09-08-search-page-ratio-and-tag-filter-design.md`）
- **优化点**：比例筛选（`SearchFilters.ratio`）为纯本地过滤（`TemplateSearchService._templateRatio` 读 `composition['aspectRatio']`，回退 `postProcess['cropRatio']`）。远端（后台运营）模板仅当本地已同步过详情（RDB 中 composition 有 aspectRatio）时才参与比例命中；未拉取详情的远端模板不进入比例筛选结果。且 `ratio` 非空时 `isBackendCapable` 返回 false，整页回退本地全量检索，放弃后端实时结果。
- **背景/动机**：后端搜索接口（GET /templates/search）不支持比例参数，设计时明确「暂不改后端/不引入新增字段」先以本地过滤落地（已知限制）。
- **目标状态**：后端搜索接口支持 `ratio` 参数（或模板列表/搜索响应附带 `aspectRatio` 字段），App 端远端模板无需本地详情缓存即可参与比例筛选，并恢复后端实时检索路径。
- **状态**：⏳ 待优化

---

## 拍摄页参数面板工具条化重构终审遗留（2026-09-08）

### P2 · 面板空白区点击穿透

- **模块**：拍摄页参数面板（param_panel.dart）
- **优化点**：ParamPanel 把手行 Spacer、工具项间隙、控件区 padding 均不吸收命中，点击面板自身空白处会落到全屏 translucent overlay（点面板外关闭整栏）从而误关整栏，且 translucent 会把事件透传到 Stack 底层控件。建议在 shell 内加命中吸收层。
- **背景/动机**：2026-09-08 ParamPanel 工具条化重构终审遗留（plan-mandated 结构）。
- **目标状态**：面板空白区点击不关闭整栏、不透传底层。
- **状态**：⏳ 待优化

### P3 · 构图建议文案失去展示面

- **模块**：拍摄页参数面板（param_panel.dart）
- **优化点**：旧 _CompositionTab 的 comp.description 提示卡在重构后无对应物，构图工具仅剩类型 pill + 透明度滑块，只读信息净减少。
- **背景/动机**：2026-09-08 ParamPanel 工具条化重构（plan verbatim 如此）。
- **目标状态**：构图控件区以紧凑形式恢复 description 展示（如 pill 行下方一行小字或可展开提示）。
- **状态**：⏳ 待优化

### P3 · 展开态总高 ≤220 无永久回归守卫

- **模块**：拍摄页参数面板（param_panel.dart）
- **优化点**：展开态总高 ≤220dp 验收线目前仅靠布局常量算术（38+52+124≈214dp）与一次性临时测试实测（215.2dp）保证；高度完全由常量构成（_controlH、把手行 padding、工具条尺寸、关闭按钮 size/padding），后续调整任一常量时无测试报警。终审修复时守卫测试已取证后回退（提交文件清单约束）。
- **背景/动机**：2026-09-08 ParamPanel 工具条化重构终审修复（a6953c89）遗留。
- **目标状态**：param_panel_test.dart 增加展开态面板高度断言（固定测试视口 + viewPadding 0，`tester.getSize` ≤220），作为常量调整的回归守卫。
- **状态**：⏳ 待优化

---

## 首页 Banner 运营化（2026-09-09）

### P1 · 后端运营 Banner 下发系统 + 后台运营位管理页

- **模块**：首页 Banner（Flutter + NestJS 后端 + Next.js 后台）
- **优化点**：运营位当前为 App 端静态配置（`lumira_app_flutter/lib/features/home/data/operation_banners.dart`），条目/文案/条件改版需发版。后续建后端运营位下发系统与后台管理页。
- **背景/动机**：设计文档《首页 Banner 运营化重构》将此列为非目标、留待单独立项；当前静态配置已与 `BannerType` / 运营条目模型（`OperationBanner`/`OperationCondition`）对齐，未来接入远端下发仅需把配置源从本地静态 swap 成远端拉取，渲染层与埋点层无需改动。
- **目标状态**：后端提供运营位配置 CRUD + 下发接口；App 启动/进首页拉取运营条目（离线缓存兜底静态配置）；后台管理页可视化编辑条目/条件/文案。
- **状态**：⏳ 待优化

### P2 · 运营位 A/B 实验 / 时段定向 / 人群定向投放引擎

- **模块**：首页 Banner（后端）
- **优化点**：当前运营位仅按单一用户状态条件取目录中第一条满足的条目，无实验分流与定向投放能力。
- **背景/动机**：设计文档非目标项；依赖运营位下发系统先落地。曝光/点击埋点（`item_type='banner'`，`event_type='expose'/'click'`）已可按 `item_id` 聚合出单槽位点击率，为后续实验提供数据基础。
- **目标状态**：支持按设备分桶做 A/B 文案实验、按时段/人群定向投放，基于埋点闭环迭代。
- **状态**：⏳ 待优化
