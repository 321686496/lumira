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
- **状态**：✅ 已实现（2026-09-09）
- **实现说明**：后端 `operation_banners` 表 + `GET /api/v1/banners`（App 下发，60s Redis 缓存）+ `/api/v1/admin/banners` CRUD（route/condition 白名单校验）；后台「Banner 运营」管理页（`/dashboard/banners`）可视化编辑条目/条件/文案/启停/排序；App 端三级兜底（远端拉取成功写 `user_settings.operation_banners_cache` 离线缓存 → 断网读缓存 → 首装断网回退静态 `kOperationBanners`），空列表为合法下发状态（后台全部停用），非法 route/condition 整条丢弃（fail-safe）。

### P2 · 运营位 A/B 实验 / 时段定向 / 人群定向投放引擎

- **模块**：首页 Banner（后端）
- **优化点**：当前运营位仅按单一用户状态条件取目录中第一条满足的条目，无实验分流与定向投放能力。
- **背景/动机**：设计文档非目标项；依赖运营位下发系统先落地（P1 已实现）。曝光/点击埋点（`item_type='banner'`，`event_type='expose'/'click'`）已可按 `item_id` 聚合出单槽位点击率，为后续实验提供数据基础。
- **目标状态**：支持按设备分桶做 A/B 文案实验、按时段/人群定向投放，基于埋点闭环迭代。
- **状态**：⏳ 待优化

### P2 · Banner 配图上传孤儿文件清理

- **模块**：首页 Banner（NestJS 后端 `src/modules/banners/`）
- **优化点**：配图上传（`POST /api/v1/admin/banners/upload`）与 Banner 保存解耦（选中即传、保存时 URL 落库），用户上传后放弃保存、或反复更换配图时，`{UPLOAD_DIR}/banners/bnr-*` 会残留未被任何条目引用的孤儿文件。
- **背景/动机**：当前先保证上传体验（选中即刻预览），未做引用追踪；文件落本地磁盘，长期累积占空间。
- **目标状态**：定时任务扫描 `banners/` 目录，删除未被 `operation_banners.image_url` 引用且超过保留期（如 24h）的文件；或改为「保存时才搬运文件」的事务性方案。
- **状态**：⏳ 待优化

---

## AI 一键模板录入（2026-09-09）

### P1 · AI 识别/生图切换 Dify / Coze 工作流

- **模块**：AI 模板录入（NestJS 后端 `src/modules/ai/` + Next.js 后台）
- **优化点**：本次（2026-09-09 设计）采用代码直连各厂商 OpenAI 兼容接口（qwen/doubao/zhipu/openai），提示词随代码维护（`analyze.prompt.ts`）。后续可将 `ai-analyze` / `ai-generate-image` 切换为工作流 API（私有化部署的 Dify Workflow 或 Coze），把模型选型与提示词移入工作流侧可视化维护，换模型零代码。
- **背景/动机**：用户明确要求先代码实现、工作流方案保留；`ai_provider_config.provider` 字段已为 `dify` / `coze` 类型预留扩展位，届时新增对应 client 实现即可，接口契约（`{draft, warnings}`）不变，admin 端零改动。
- **目标状态**：`provider` 支持 `dify`/`coze`，配置页相应扩展（Workflow API Key / 基址 / 工作流 ID）；识别与生图经工作流编排，归一化层保持后端不变。
- **状态**：⏳ 待优化

### P2 · 全自动模式支持多姿势

- **模块**：AI 模板录入（后端 + admin 向导页）
- **优化点**：全自动一键生成当前只产出 1 个姿势（1 张剪影）；后续可让识别阶段同时产出图中多个可复现姿势的描述与主体框，剪影管线逐姿势生成分割线稿，批量挂入 poses。
- **背景/动机**：多姿势模板是既定数据结构（`poses` 数组），全自动当前为保成功率只做单姿势；运营需多姿势时仍走编辑页手动补充。
- **目标状态**：全自动产出 N 个姿势（每个含文字描述 + 剪影 + 位置参数），失败姿势跳过并 warning，不阻断整体。
- **状态**：⏳ 待优化

---

## AI 一键建模增强（2026-09-10）

### P2 · 仅文/图文模式 e2e 补全（mock 上游）

- **模块**：AI 模板录入（NestJS 后端 `test/ai-analyze.e2e-spec.ts`）
- **优化点**：本次多输入增强的 e2e 仅新增两个 400 用例（无输入/纯空白 text），仅文与图文混合的成功路径由单测覆盖（`ai-analyze.service.spec.ts` 五输入组合用例）；与该 e2e 文件既有约定一致（成功识别依赖真实厂商 API，走手动验收）。
- **背景/动机**：设计文档 §6 曾设想「mock 上游的仅文模式 e2e」，实施计划刻意收窄；终审（2026-09-10）确认无正确性风险，登记为后续补强项。
- **目标状态**：e2e 中以 supertest + fetch mock（或 Nest DI 替换 LLM client）覆盖仅文/图文成功路径，与单测分支对齐。
- **状态**：⏳ 待优化

### P2 · AI 配置连通测试并行化 / 降超时

- **模块**：AI 模板录入（后端 `ai-config.service.ts` `test()`）
- **优化点**：连通测试 vision(30s) 与 text(30s) 串行执行，最坏 60s；admin「测试连接」经 Vercel server action 转发，可能顶到函数超时上限。
- **背景/动机**：本次新增独立文本模型连通测试后超时暴露翻倍；既有 vision-only 30s 已有此风险。
- **目标状态**：两项测试 `Promise.all` 并行（结果聚合不变），或将单项超时降至 10-15s。
- **状态**：⏳ 待优化

### P3 · 生图 prompt 润色结果按草稿哈希缓存

- **模块**：AI 模板录入（后端 `ai-generate-image.service.ts` + `prompt-polisher.ts`）
- **优化点**：同一草稿多次重 roll 生图时，每次都重新调用润色（每次最多多付 30s 延迟与一次 LLM 调用）。
- **背景/动机**：润色输入仅依赖草稿 JSON（+ 配置），结果确定性高；重 roll 是 Step3 的常规操作。
- **目标状态**：以「草稿 JSON 哈希 + textModel」为键缓存润色结果（进程内 LRU 即可），未命中才调 LLM。
- **状态**：⏳ 待优化

---

## 发现页「今日为你推荐」推荐优化（2026-09-14）

> 见 `docs/superpowers/plans/2026-09-14-today-recommend-optimization.md`。整支特性已实现（四级画像精准、每日轮换+固定上限、mixExplore 顺序修复、热度时效软化、画像命中展示理由/角标）。

### P2 · 每日洗牌当前为均匀全序，「排序由 total 主导」实际只决定入选集合、不决定条内顺序

- **模块**：发现页「今日为你推荐」（Flutter `daily_recommendator.dart` + `templates_providers.dart`）
- **优化点**：`DailyRecommendator.build` 对 `mixExplore` 已排序结果做全序 Fisher–Yates，因此 10 条内各卡的先后顺序与 interest/total 完全无关，仅由日期种子决定。「total 主导排序」的约束实际上只作用于入选集合（cap 内取哪些），而不作用于条内排序。
- **背景/动机**：每日轮换是产品目标（不同天看到不同批次），但洗牌是均匀全序，导致"最贴合用户"的画像/热度命中项也可能被随机排到第 10 位，可能弱化"个性化靠前"的观感。
- **目标状态**：评估折中——仅对后半段（如第 5-10 位）做日期洗牌，前 4 位保留 interest/total 高位置顶；或对首卡/前 N 位按命中强度优先。需权衡"每日新鲜感"与"个性化靠前"。
- **状态**：⏳ 待优化

### P2 · 移除 mixExplore 全量重排后，热度是否需置顶补偿

- **模块**：发现页「今日为你推荐」（Flutter `template_ranking.dart` `mixExplore`）
- **优化点**：修改后探索/兴趣交错顺序不被 `total` 二次重排压制，但全站热门模板也因此不再必然靠前。
- **背景/动机**：修复目标是让高探索信号真正体现在榜首；副产品是"热门模板会被随机/探索信号顶开"。热搜运营诉求与个性化多样性存在张力。
- **目标状态**：若运营需要热门模板打底（如前 1-2 位长期保留全站 Top），可加一个"热度保底置顶"策略，与探索优先做可配置的平衡。
- **状态**：⏳ 待优化

### P2 · 四级分类中文名的映射未国际化

- **模块**：发现页「今日为你推荐」（Flutter `templates_providers.dart` `nameOf`/`TemplatesBrowseMockData.categoryLabel`）
- **优化点**：展示层"匹配你常拍的【…】"的四级分类名依赖硬编码中文 label map，无本地化入口。
- **背景/动机**：目前仅中文产品，硬编码可用；若后续做多语言，分类名与"匹配你常拍的"句式均需按语言切换。
- **目标状态**：将分类名映射与展示句式抽为可本地化的资源（如 l10n / 按 locale 的 label map）。
- **状态**：⏳ 待优化

---

## 首页运营视角重构（2026-09-15）

### P2 · 搜索胶囊占位文案由静态改为运营热词配置

- **模块**：首页搜索胶囊（`search_capsule.dart`，`docs/specs/2026-09-15-homepage-ops-redesign-design.md`）
- **优化点**：搜索胶囊占位文案「搜索模板 / 场景 / 拍摄教程」为硬编码静态字符串；后续运营想用热词（如当前主推模板/活动词）引导搜索时需发版。
- **背景/动机**：本次重构仅落地搜索入口（解决首页无搜索入口问题）；文案动态化依赖运营配置通道（如后端下发），超出本次范围。
- **目标状态**：占位文案由远端运营配置下发（离线回退静态默认文案），点击后的搜索页 scope 保持不变。
- **状态**：⏳ 待优化

---

## 扫一扫优化（2026-09-16）

### P1 · OHOS ScanKit 识别流分辨率降档提速（本次仅降防抖，未降分辨率）

- **模块**：扫一扫 · OHOS（`packages/qr_code_scanner/ohos/src/main/ets/components/plugin/libs/CameraService.ets`）
- **优化点**：首页扫一扫本次优化只把 `decodeImageBuffer` 的识别防抖窗口 800→200ms（约 4× 识别频率）。每帧识别仍是全 1920x1080 JPEG 解码 + ScanKit `decodeImage` 全图解码，单帧耗时仍偏高；进一步提速需把预览流2（imageReceiver 扫码流）降档到 ~720p，并按新尺寸匹配 `previewProfiles` / imageReceiver 尺寸，减少每帧解码量。
- **背景/动机**：降档会牵动 preview profile 匹配与 `imageReceiver` 创建尺寸联动，风险较高且需真机验证，本次刻意不展开，仅作后续优化登记。
- **目标状态**：预览流2 用镜头支持的较低档 profile（如 1280x720 或更小）创建 `imageReceiver`，`previewOutput2` 用同尺寸 profile，`decodeImageBuffer` 按实际宽高传参；真机验证识别速度提升与远距/小码识别不 loss。同时核对 `ByteImage.format` 与接收 buffer 实际编码（当前标 NV21）是否匹配，避免解码耗时或失败。
- **状态**：⏳ 待优化

---

## 拍摄速度优化（2026-09-16）

> 见 `docs/specs/` 无专项文档；官方依据：华为最佳实践《相机分段式拍照性能优化》（bpta-camera-shot2see，分段式 672ms vs 单段式 1900ms）。本次已落地：早帧→原生 processJpeg 出「初版成片」可见 interim（~800ms 上屏）、单帧评分移出成片关键路径、偏黄诊断/尺寸诊断 debug 化、增强兜底 directDone 防护（防晚到增强图覆盖原始直出 JPEG）、早帧临时文件轮转清理。成片链路（photoAvailable 原始 JPEG → C++ 管线）未动，成片质量与优化前一致。

### P1 · 水印合成折叠进 C++ processJpeg 单 pass

- **模块**：拍摄页后处理（`capture_page.dart` + `ohos/entry/src/main/cpp/photo_processor.cpp`）
- **优化点**：开水印时 OHOS 走「原生出底片 → 原生解码 → Flutter 渲染水印 → 原生编码」多一次 decode+encode 往返；可把预渲染的水印 overlay 位图传入 C++，在 processJpeg 内一次合成。
- **背景/动机**：水印路径节省一次解码+编码（数百 ms 级），但当前感知速度主要被 2s 水印定格动画掩盖（动画期间后台完成合成），直接收益被动画时长吞掉；且 C++ 混合绘制引入缩放/混合语义风险，需真机逐像素比对。
- **目标状态**：水印 overlay 预合成为带 alpha 的位图传入原生，尺寸不匹配（旋转/镜像 guard）时回退现有 Dart 合成路径；真机验证水印位置/清晰度与现路径一致。
- **状态**：⏳ 待优化

### P2 · 横屏/拉腿/自定义裁剪场景下沉 C++ 快速路径

- **模块**：拍摄页后处理（`capture_page.dart` fastNative 条件 + `photo_processor.cpp`）
- **优化点**：横屏（需真 90° 旋转）、拉腿（legStretch>0）、自定义裁剪（customCropRect）目前回退 GPU+isolate 慢管线；原生 processJpeg 仅支持 center-cover 近似裁窗。
- **背景/动机**：横屏拍摄成片延迟显著高于竖屏（慢管线逐像素 CPU）；C++ 补齐旋转/拉腿后三场景可全部走快速路径。
- **目标状态**：processJpeg 支持按 isPortrait 的 90° 旋转与拉腿变换；fastNative 条件放宽；真机验证横屏成片方向与现管线一致。
- **状态**：⏳ 待优化

### P2 · 早帧「初版成片」与成片的色彩一致性校准

- **模块**：拍摄页先快后真链路（`capture_page.dart` 早帧处理 + 相机 fork `CameraState.ets`）
- **优化点**：早帧走相册增强管线（FAST_MODE），叠加用户色彩矩阵后的 interim 与最终成片（photoAvailable 原始 JPEG + 同矩阵）存在不可控色差，本次以「约 1s 后原位替换」接受该差异。
- **背景/动机**：根治需拿到未经增强的一阶段原始帧（官方未开放三方通道）或自建 ISP（YUV 拍照，API 23+），改动大。
- **目标状态**：评估 YUV 拍照直出（绕过 JPEG 编解码 + 自建色彩链路）的可行性与画质收益；或调研分段式一阶段图是否可配置关闭增强。
- **状态**：⏳ 待优化

---

## 编辑保存与实时预览修复（2026-09-16）

> 背景：后期修图页 / 照片预览页「拖动磨皮/锐化滑块无实时效果、保存后只有锐化有效果、保存后前置照片水平翻转」三问题修复。已落地：facing 随 PostProcess JSON 持久化（PostProcess + gallery_dao 扁平序列化补全 facing/fillLight/wbResidual）并在 processFile 驱动前置镜像；OHOS 编辑保存接原生 processJpeg 快速路径（无自定义裁剪/变换/拉腿时）；Dart 管线磨皮 GPU 输出加像素级校验、无效即回退 CPU，CPU 回退改 RGBA 直建（去 PNG 编解码往返）；DetailEffectsLayer 修复 core/full shader 程序错配（磨皮值写进暗角槽位）并支持 prewarm 预热（编辑页进入即解码+加载 shader，首拖滑块即实时生效）。

### P2 · 旧照片记录（无 facing）前置照片再编辑保存仍会水平翻转

- **模块**：编辑保存（`photo_post_processor.dart` / `photo_template.dart`）
- **优化点**：facing 于 2026-09-16 起随拍摄落库写入 PostProcess JSON；此前的存量照片记录无该字段，其前置照片在编辑页「从原图重新处理」时无法区分朝向，默认按后置处理，再保存仍会水平翻转（后置照片不受影响）。
- **背景/动机**：如做一次性数据迁移，需要对存量 JPEG 做人脸方向/对称性推断（不可靠）或全量回扫重写 post_process 列（改动大、有写坏数据风险），本次选择只对新拍摄照片生效。
- **目标状态**：评估按「originalPath 与 filePath 像素级镜像比对」（抽样行/列相关性）自动推断存量记录朝向并回填，或接受旧照片一次性翻转缺陷自然淘汰。
- **状态**：⏳ 待优化

### P3 · 编辑保存 OHOS 原生快速路径覆盖自定义裁剪/用户变换/拉腿场景

- **模块**：编辑保存（`photo_post_processor.dart` + `photo_processor.cpp`）
- **优化点**：OHOS 原生编辑保存快速路径当前仅覆盖「无自定义裁剪嵌套、无用户变换、无拉腿」的场景；带裁剪框/旋转翻转/拉腿的编辑保存仍走 Dart 慢管线（含 dart:ui 慢解码与 GPU 读回）。
- **背景/动机**：原生 processJpeg 的几何变换是 center-cover 近似裁窗，不支持嵌套自定义裁剪与任意用户变换；与「拍摄速度优化」P2（横屏/拉腿/自定义裁剪下沉 C++）为同一能力项，补齐后两侧同时受益。
- **目标状态**：processJpeg 支持精确自定义裁剪窗口与用户变换入参，编辑保存全场景走原生；真机验证框选内容与导出一致（WYSIWYG）。
- **状态**：⏳ 待优化

---

## 编辑页细节效果实时预览改走 OHOS 原生管线（2026-09-17）

> 背景：保存链路修复后真机验证发现「拖动磨皮/锐化滑块照片仍无实时变化」。根因确认为 flutter_ohos 引擎上 Dart FragmentShader（skin_smooth.frag / edit_detail_effects.frag / edit_smooth_sharpen.frag）在该真机静默渲染为原图（无异常、无日志）——与此前「保存后 GPU 磨皮无效、CPU 锐化有效」同根因；取景器可用是因为走原生 libpreview_fx，保存可用是因为走原生 processJpeg。已落地：编辑页实时预览在 OHOS 上改走与拍摄成片同一套 C++ processRgba —— ImageProcessorPlugin 新增 cacheDetailSource（原生解码一次入缓存，LRU 上限 4）/ renderDetailPreview（恒等矩阵 + 细果参数渲染，swapRgba 还原展示序）/ releaseDetailSource；DetailEffectsLayer 获取缓存后按参数指纹增量渲染 RawImage（渲染中合并最新参数，LRU 淘汰自动重建重试），prewarm 同步预热原生缓存；非 OHOS 平台与拉腿增量场景仍走 shader 路径。

### P2 · 原生实时预览补齐拉腿几何与色彩增量

- **模块**：编辑页实时预览（`ImageProcessorPlugin.ets` / `detail_effects_layer.dart`）
- **优化点**：原生预览帧只渲染细节增量（锐化/磨皮/暗角/颗粒），色彩增量仍由外层 ColorFiltered 叠加、拉腿增量非零时回落 Dart shader 路径（该真机上等价于无预览）。
- **背景/动机**：processRgba 无几何变换能力；拉腿是低频功能，本次以「拉腿预览降级」换取主路径稳定。
- **目标状态**：renderDetailPreview 支持 0.2 档纵向拉伸参数（或复用成片 legStretchRgba 逻辑），色彩矩阵参数透传（替代外层 ColorFiltered，消除双层合成色差）。
- **状态**：⏳ 待优化

### P3 · 查明 flutter_ohos FragmentShader 静默失效的引擎根因

- **模块**：跨模块（flutter_ohos 引擎 / Skia backend）
- **优化点**：本项目三处 FragmentShader 消费点（编辑页细节预览、保存磨皮、已停用的取景器美颜）在同一真机上全部表现为「shader 输出=输入」，单元测试（tester 环境）则正常。
- **背景/动机**：本次以「绕过」（原生管线）交付，但 shader 能力缺失影响后续任何 GPU 效果方案（曲线/LUT 实时预览等 v2 计划均依赖）。
- **目标状态**：在 flutter_ohos 真机上定位（impeller/skia 差异、驱动兼容、shader 编译产物缓存），或升级引擎版本验证；修复后编辑页可回退纯 shader 路径（保留原生路径作性能优选）。
- **状态**：⏳ 待优化

---

## 相机手动参数 ISO（2026-09-17 · v2）

> 背景：拍摄页顶部胶囊栏原含 ISO 展示（`ISO Auto` / 手动值），但参数面板无 ISO 编辑控件，ISO 仅作展示/推荐参考、不可真实编辑，属占位。2026-09-17 已按「未实现先从胶囊栏去掉」将其从胶囊栏移除（`capture_top_pill_bar.dart`）。数据侧 `CameraParams` 已含 `iso` / `isoMode` 字段，实现闭环所需的数据模型与既有思路均已具备，技术上可实现，规划于 v2 版本落地。

### P1 · 参数面板新增 ISO 编辑控件 + 手动模式联动，并恢复胶囊栏 ISO 入口

- **模块**：拍摄（`param_panel.dart` / `capture_top_pill_bar.dart` / `capture_state.dart`）
- **优化点**：实现 ISO 手动设置闭环：参数面板相机 Tab 增加 ISO 编辑控件（滑块/档位），切换 ISO 手动/自动模式，并与 EV、快门联动；胶囊栏恢复 ISO 入口，按当前模式显示 `Auto` 或手动值；`resetAll` 等重置逻辑覆盖 ISO。
- **背景/动机**：ISO 当前仅占位展示（不可编辑），已从胶囊栏移除等待实现；数据模型与既有计划（`docs/superpowers/plans/2026-08-15-camera-manual-params.md`）已就绪，属 v2 相机手动参数能力的组成部分。
- **目标状态**：手动设置 ISO 后拍摄建议/模板展示按所选 ISO 生效；胶囊栏与参数面板显示同步，并随 4 套 UI 风格 × 主题自适应。
- **状态**：⏳ v2 待实现

---

## AI 模板 Agentic 编排管线（2026-09-21）

> 背景：单次 LLM 调用升级为「文本大模型为中枢 + T1 趋势研究/T2 穷尽识别/T3 姿势面片/T4 生图择优/T5 参数校准/T6 评分闸门」的 Agentic 管线（`AiOrchestratorService`）。以下为本次已落地但「当前先这样、后续再优化」的项，按本文档格式登记。

### P1 · sharp 近似渲染管线：LUT / 磨皮为近似实现，非真实 3D LUT

- **模块**：后端 AI 渲染（`lumira-server/packages/backend/src/modules/ai/render-approx.service.ts`，App 模板录入全自动/后台校准）
- **优化点**：`RenderApproxService.apply` 用 sharp（色阶曲线 `linear` / 复合矩阵 `recomb` / 色罩 `tint` / 模糊 `blur` / 噪点近似）复刻 App 端 `PostProcess` 的 LUT 与磨皮，属**近似**，非服务端真实 3D LUT 变换，也不逐像素等价 App 的 filterRecipe/bakeCanvas。真实 LUT 需把 .cube 3D LUT 与应用语义逐通道映射到 sharp，当前仅做预设近似（如 cinematic/vintage 等按名字映射到线性组合）。
- **背景/动机**：sharp 能力边界内做「App 实拍 ≈ 期望」的粗略校准参考即可满足 P4 主目标；真实 3D LUT 工程量与对齐成本高，非本计划范围。
- **目标状态**：如需更高一致度，加载真实 3D LUT 并在 sharp 内按三线性插值实现（或下沉到后端原生/WebAssembly LUT 内核），使渲染结果与 App 成片逐像素对齐。
- **状态**：⏳ 待优化

### P1 · 真机抽检流程为手工后续项

- **模块**：后端 AI 渲染（RenderApproxService）+ 后台 AI 向导
- **优化点**：P4 实拍闭环的「App 实拍 ≈ 期望」**真机抽检**当前无自动化流程，仅能由运营在后台生成后真机拍摄人工对比，未纳入 CI / Golden Set 门禁。
- **背景/动机**：服务端 sharp 近似只做「粗校准参考」，最终一致性以 App 真机为准；完整自动抽检涉及真机设备接入与自动化拍照，超出本计划范围。
- **目标状态**：建立可复用的真机抽检流程（后台生成 → 下发 App → 真机拍摄 → 回传与原图对比），或接入 GoldenSetService 作为可选回归门禁。
- **状态**：⏳ 待优化

### P2 · 抖音 / 小红书直连适配器后续接入

- **模块**：后端 AI 趋势研究（`src/modules/ai/trend-research/`，`TrendResearchService` / `web-search.provider.ts`）
- **优化点**：P3 计划设想的「抖音 / 小红书直连」内容源目前没有独立实现：`web-search.provider.ts` 仅支持 `bing`（通用搜索 API）与 `vendor`（厂商联网模型检索）两条路径，`baidu` 适配器文件 `web-search-baidu.ts` 尚未编写（`createWebSearchProvider` 对 `baidu` 直接抛「尚未接入」）；抖音 / 小红书作为**热门内容直连趋势源**留存为后续项。
- **背景/动机**：直连内容平台需处理其公开接口 / 反爬 / 合规与限速，风险与合规成本高于通用搜索，本次先以 bing + 厂商检索覆盖热点来源（符合「可开关、可降级、单源失败不阻断」约束）。
- **目标状态**：新增 `web-search-baidu.ts` 与抖音/小红书直连适配器，注册进 `createWebSearchProvider` 工厂与 `search_sources` 可选列表；后台可切换启用，单源失败仍降级不影响主流程。
- **状态**：⏳ 待优化

---

## 后端部署 Ops（2026-09-22）

> 背景：生产服务器系统盘 `/` 100% 满（40G 全用光，剩 1.3M），导致 MySQL InnoDB 写盘失败反复崩溃（`No space left on device` + `#innodb_redo` 无法 resize + `ibtmp1` 无法创建），后台访问连带 502/后端容器停在 `created`。根因：CI（backend-deploy.yml）反复 `docker build` 但从不清理，`/var/lib/docker` 构建缓存累积至 **23.35GB**。已执行 `docker builder prune` + `image prune`（释放 23G）恢复。本条目记录已落地与后续项。

### P1 · 服务器 Nginx 上游改用动态解析（upstream 启动时 resolve 一次后缓存 IP，容器重建 IP 漂移导致 502）

- **模块**：生产部署 · Nginx（服务器独立 nginx 容器，非 compose 管理）
- **优化点**：nginx.conf 的 `upstream lumira_backend_upstream { server backend-lumira-backend-1:3000; keepalive ... }` 采用静态解析——nginx 启动时对主机名仅 resolve 一次并缓存 IP；后端容器每次 `--force-recreate` 重建后 Docker 重配新 IP，nginx 内存仍挂旧 IP 即 `connect() failed (111) Connection refused` → 502，直到手动 `nginx -s reload` 才恢复。
- **背景/动机**：2026-09-22 排查出 502 直接根因之一即此（后端容器重建后 IP 漂移，nginx 未 reload）；另一次是磁盘满导致后端容器未启动、nginx `host not found in upstream` 而 [emerg] 崩溃循环。二者本质同源：nginx 上游依赖「宿主名在启动时一次性解析」这一脆弱机制。
- **目标状态**：nginx.conf 上游改为动态解析——`resolver 127.0.0.11 valid=10s;`（Docker DNS）+ `server backend-lumira-backend-1:3000 resolve;`，或每次后端重建后自动 `nginx -s reload`（可并入 backend-deploy.yml 部署步骤）；同时把 nginx 纳入 compose 管理以利用 `depends_on`+restart 编排。
- **状态**：✅ 已实现（2026-09-22 服务器手动 `docker restart nginx` 恢复；CI 侧补 `docker builder prune -f` 防磁盘再次爆满）——动态解析改造为待后续优化

### P2 · 服务器磁盘使用率告警 / 自动清理兜底

- **模块**：生产部署 · CI/CD（`backend-deploy.yml`）
- **优化点**：本次已落地——部署前置检测 `df -h /` 使用率 >80% 时在 Actions 打 warning；部署末尾追加 `docker builder prune -f`（原只有 `image prune -f`），防构建缓存再累积撑爆系统盘。
- **背景/动机**：23.35GB 构建缓存一次性撑满 40G 小盘；单靠人为清理不可持续。
- **目标状态**：可进一步加「磁盘使用率 >90% 时强制 prune 后再 continue」或定时清理 Cron；并考虑给 CI 构建缓存（GITHUB_ACTIONS 自带）与服务器 builder cache 预设上限。当前已有的 >80% 告警 + 部署后 prune 为起点。
- **状态**：✅ 已实现（2026-09-22：部署后 `builder prune -f` + 磁盘告警已并入 backend-deploy.yml）

---

## OHOS 前置拍照镜像修复（2026-09-23，第三轮根因重查后定稿）

> 背景：用户真机反馈「前置拍出的照片仍是镜像」，且前两轮修复先后被用户实证推翻（「照片还是有镜像」→「现在一直都是水平翻转了，水印动画、早帧、成片，都是水平翻转了」）。经代码 + 真机日志全面重查，确立方向模型：
> - **OHOS 拍照模式（非录像）前置取景器 = 真实方向**：`CameraState.enableMirror` 仅录像模式执行（L356-363），`_mirrorFrontCamera` 默认 false 且 app 从未开启，拍照预览表面无任何镜像配置，Flutter 侧取景器也无 Transform。
> - **OHOS 前置相册 asset / HIGH_QUALITY 增强成片 = 镜像**：takePhoto 虽传 `mirror: false`，设备/相册管线仍对前置照片做镜像（用户实证：早帧 `isFront=false` 上屏即镜像画面）。
> - 结论：**asset 派生图（fd 早帧 / 增强成片 / 编辑保存的 raw 备份）需翻回真实（`isFront=true`）；取景器派生图（快门帧）不能再翻**。
>
> 第三轮已修复：早帧 `isFront: job.isFront`、fastNative 成片 `isFront: params.isFront`、编辑保存 OHOS 原生分支 `isFront: effectiveFacing == 'front'`；快门帧翻转改为 `facing == 'front' && !isOhos`（OHOS 取景器真实不翻，iOS/Android 预览镜像保留翻转）；恢复水印动画 `flipSource` 补翻管线（仅回退源=OHOS 前置 asset 时启用）；`_applyColorMatrixOnGpu` 与 `photo_post_processor._alignOrientation` 的 needMirror 平台收敛为 `facing == 'front' && (isOhos || jpegIsLandscape)`（OHOS asset 镜像，竖屏也补翻；iOS/Android 维持原规则）。
>
> 待真机验证：前置竖屏拍摄的早帧 / 快门帧 interim / 水印动画 / 成片 / 预览 / 编辑保存六处方向一致性（应全部真实、无镜像闪变）；另需覆盖前置横屏持机（快路径不走原生、走 Dart GPU 管线）与拉腿/自定义裁剪场景。

### P1 · OHOS 横屏持机前置拍照/编辑保存 needMirror 规则平台收敛

- **模块**：拍摄成片 / 编辑保存（Flutter：`capture_page.dart` `_applyColorMatrixOnGpu`、`photo_post_processor.dart` `_alignOrientation`）
- **优化点**：原规则 `needMirror = facing == 'front' && jpegIsLandscape` 源于 iOS（竖屏像素已镜像不补、横屏 sensor 帧未镜像才补），对 OHOS 不成立——OHOS 输入恒为相册 asset（设备/相册管线镜像），竖屏像素也需补翻。
- **背景/动机**：前两轮误判「OHOS raw=真实方向」曾把该偏差标为已知问题；第三轮根因重查后确认 OHOS asset 镜像，遂按平台收敛。
- **目标状态**：规则改为 `facing == 'front' && (isOhos || jpegIsLandscape)`，OHOS 恒补翻、iOS/Android 维持原规则；两处调用点已同步收敛，待真机回归。
- **状态**：✅ 已实现（2026-09-23 第三轮：`_applyColorMatrixOnGpu` 与 `_alignOrientation` 均已平台收敛；`dart_photo_pipeline.dart` 为死代码仅纠注释，未改规则）

---

## 场景管理封面加载优化（2026-09-24）

### P2 · 收藏场景数据源仍用 mock 预设（与 ScenePresetsData 重复定义）

- **模块**：场景管理页「我的收藏」（Flutter `scene_manage_providers.dart` + `capture_scene_mock_data.dart`）
- **优化点**：`favoriteScenesProvider` 用 `CaptureSceneMockData.presetScenes`（6 条 mock）建 `presetById` 来补齐内置场景的名称/氛围/描述，而全量 18 条真源在 `ScenePresetsData.allScenePresets`，两者同 id 记录当前字段一致，属重复定义。
- **背景/动机**：本轮只修封面取源（`sceneCoverUrl` 改为「自定义封面 → 本地打包封面 → 示例图首图」），已实测两侧同 id 数据完全一致，切换数据源是无功能收益的重构且带回归风险，故本轮不做；但双份定义后续改文案时易只改一处导致漂移。
- **目标状态**：`favoriteScenesProvider` 直接用 `ScenePresetsData.getScenePreset(id)` 取内置场景，删除 mock `presetScenes` 中与真源重复的记录。
- **状态**：⏳ 待优化

---

## 照片分享海报 · 9:16 重设计（2026-09-24）

三方向九款：净版 `n1`-`n3` / 画刊 `m1`-`m3` / 画卷 `j1`-`j3`（画布统一 300×533.33，文字全部落在暖白实底或白卡上）。已废弃旧 9:16 三款 `d1`/`dN`/`dL`。

### P2 · 二维码副文案「打开如画 · 保存原图」暂并入主提示两行

- **模块**：照片分享海报（Flutter：`poster_styles_shared.dart` 的 `posterQrMiniLinesOf` / `PosterQrMini`）
- **优化点**：9:16 画布高度由 ≈691 收紧到 300×16/9≈533.33 后，二维码迷你卡仅展示主提示拆分两行（「长按识别 / 查看高清原图」），副文案「打开如画 · 保存原图」未单独展示。
- **背景/动机**：画布高度收紧 + 信息带/浮卡垂直空间有限，副文案入卡会挤压标题/作者行或导致溢出；HTML 设计稿基准（`docs/preview/poster-9-16-preview-v10.html`）同样只保留两行。
- **目标状态**：后续若重新分配画布信息区空间（或将副文案与主提示合并为一句完整文案），在 QR 迷你卡中恢复「主提示 + 副提示」完整语义。
- **状态**：⏳ 待优化

### P2 · QR 迷你卡提示来源不统一（hint 取数据字段、sub 走派生函数）

- **模块**：照片分享海报（Flutter：`poster_styles_shared.dart` `posterQrMiniLinesOf`）
- **优化点**：回退路径中第一行取 `data.qrHint`（非空优先），第二行取 `posterQrSubOf(d)`——而后者只按 `authorName` 派生、忽略 `data.qrSub`。当两者与派生值不一致时（如 `authorName` 为空的模板海报），迷你卡与全尺寸 QR 卡（`poster_styles_shared.dart` / `photo_poster_styles.dart` / `template_poster_styles.dart` 共 11 处，均忽略数据字段）会显示不同文案。
- **背景/动机**：`posterQrHintOf`/`posterQrSubOf` 的派生语义被既有 11 处调用依赖，本轮统一会扩大影响面，故只在迷你卡内做了最小修正（`d.qrHint` 优先、否则回退派生）。
- **目标状态**：让 `posterQrHintOf`/`posterQrSubOf` 本身优先取 `data.qrHint`/`data.qrSub`，消去派生与数据的双轨来源。
- **状态**：⏳ 待优化

### P2 · 超长标题在固定高度区溢出（`PosterTitle` 无 maxLines）

- **模块**：照片分享海报（Flutter：`poster_common.dart` `PosterTitle` + `photo_poster_styles.dart` n1/n2/m3 布局）
- **优化点**：`PosterTitle` 未设 `maxLines`。九款中 n1 信息带高 160px（内容区 134px）、n2 画布内高 493.33px、m3 左轨 44px 竖排轨（约 9-10 字预算），标题达 3 行（约 20+ 字）时会溢出。
- **背景/动机**：九款尺寸均按 HTML 选型稿逐条对齐，正常标题（≤2 行）经渲染守护测试验证无溢出；病态超长标题属数据侧边界，本轮未加截断以保持设计稿效果。
- **目标状态**：给 `PosterTitle` 增加 `maxLines`（配合 `TextOverflow.ellipsis`）或按区高度自适应字号；m3 竖排轨可考虑 `FittedBox`。
- **状态**：⏳ 待优化

### P3 · `_FramedPhoto.borderRadius` 预留参数未被消费

- **模块**：照片分享海报（Flutter：`photo_poster_styles.dart` `_FramedPhoto`）
- **优化点**：`_FramedPhoto` 的 `borderRadius` 可选参数在九款（n2/m1/m2/m3/j1/j2/j3 共用）中无一传入，产生 1 条 `unused_element` info（`photo_poster_styles.dart:167`）。
- **背景/动机**：该参数为计划内跨任务复用预留；九款全部落地后确认无人消费，但仓库既有 483 条同类 info、且删除需回归九款渲染守护测试，故本轮保留待一并清理。
- **目标状态**：确认无后续消费场景后删除该参数与对应字段。
- **状态**：⏳ 待优化

### P3 · 九款缺少渲染级视觉回归测试

- **模块**：照片分享海报（Flutter：`test/shared/widgets/poster/`）
- **优化点**：现有 `photo_poster_styles_test.dart` 只做「九款均能渲染且无异常」的守护，未固化为 golden 图，字号/间距/金线位置等视觉细节无回归网。
- **背景/动机**：`test/goldens/` 当前仅有 probe/btn 类资产，既有 `poster_diag_render_test` 等 golden 用例在本机即因缺资产失败，本轮未新增 golden 依赖。
- **目标状态**：补齐 golden 资产后，为九款各生成一张 9:16 golden，纳入 CI 视觉回归。
- **状态**：⏳ 待优化

### P2 · 作者行横向预算紧张（300px 画布下仅约 5px 余量）

- **模块**：照片分享海报（Flutter：`photo_poster_styles.dart` `_AuthorQrRow` + `poster_common.dart` `PosterAuthorRow`）
- **优化点**：`_AuthorQrRow` 为 `Row(PosterAuthorRow + Spacer + PosterQrMini)`，300px 画布（信息带/浮卡内宽约 256-276px）下作者名 + `with` 文案 + QR 迷你卡合计后横向余量仅约 5px；作者名或分类文案再长一档即可能触发 `RenderFlex overflow`。
- **背景/动机**：最终评审（opus）判定为 Important，但 `PosterAuthorRow` 为模板海报等 8 处以上共用的共享组件，在其中加 `Flexible`/`ellipsis` 属跨模块收紧，需连带回归模板海报，故本轮只登记不改。
- **目标状态**：为 `PosterAuthorRow` 的姓名/落款加 `Flexible` + `TextOverflow.ellipsis`，或在 `_AuthorQrRow` 内用 `Expanded` 包裹并让内部文本可截断。
- **状态**：⏳ 待优化

---

## AI 溯源面板（2026-09-24 · LLM 原始数据实时可见）

### P1 · `collapseTraceCalls` 并发同名调用会静默丢弃提示词事件

- **模块**：后台 AI 溯源（`lumira-server/packages/admin/src/components/ai-create/trace-call-card.tsx`）
- **优化点**：合并键为 `种类(llm|search)|title|model`。当同一步骤内**并发**发起多次 title+model 完全相同的调用时（现实存在：`web-search-qwen.ts` 用固定 title `千问联网搜索 · 大模型调用`，`trend-research.service.ts` 的 `splitQueries` 把多组短查询经 `Promise.allSettled` 并发发出），第 2..N 条 `running` 事件会被 `if (open.has(key)) continue` 丢弃，其 System/User 提示词在面板上不可见；对应的 `done` 事件随后因槽位已被占用而退化为无提示词的孤立卡。
- **背景/动机**：本轮按「一次调用合并成一张卡片」的设计（用户决策）实现，简报即预设了该单槽配对策略，作为最小改动落地无过错；但溯源面板的唯一目的正是提示词取证，静默丢失与信息重复同样不可接受。批次流（Task 7）按 `index` 分组后再调用，可规避跨图碰撞，同图内的并发搜索仍会命中。
- **目标状态**：把单槽 Map 改为 **per-key 队列（多槽栈）**——同键的多个 `running` 依次排队，`done` 按 FIFO 消费队列头；或让后端为每次调用附带唯一 `callId` 并以其为配对键（更彻底，需同步改 `llm-trace.ts` 事件结构与两端类型）。补 `collapseTraceCalls` 的 vitest 用例覆盖：并发同名、孤立 done、fail、pending 四类边界。
- **状态**：⏳ 待优化

---

### P2 · f1 满版照片的压暗渐变按照片亮度自适应

- **模块**：照片分享海报（Flutter：`lib/shared/widgets/poster/poster_styles_shared.dart` `PosterFullBleedScrim` + `photo_poster_styles.dart` `_F1FullBleed`）
- **优化点**：f1 的 `PosterFullBleedScrim` 为固定四段压暗，浅亮照片（雪景/天空）底部 0.74 透明度仍可能压不住白色标题。
- **背景/动机**：满版照片是用户点名的唯一压字款，当前逐值照抄 v12 静态设计稿，未做内容自适应。
- **目标状态**：对 `photoBuilder` 输出做粗采样亮度估计，暗图降低压暗强度、亮图提高（或标题区加局部色块），保持零裁切。
- **状态**：📝 登记待做（2026-09-24，随最终三款收敛落地）

---

## 拍摄页对焦 / 曝光交互（2026-09-25）

### P1 · OHOS「AE 锁定后拖动曝光」以「回 AUTO 再重新锁定」实现，待真机验证是否抖动

- **模块**：拍摄页对焦曝光（Flutter `lib/features/capture/widgets/camera_preview.dart` + OHOS `packages/camerawesome_ohos/.../CameraState.ets`）
- **优化点**：OHOS 在 `EXPOSURE_MODE_LOCKED` 下 `setExposureBias` 不生效（与 iOS 的 `exposureTargetBias` 一致），故锁定态拖动曝光按「`EXPOSURE_MODE_AUTO` → `setExposureBias(新 EV)` → `setMeteringPoint(锁定点)` → `EXPOSURE_MODE_LOCKED`」顺序处理，每次 EV 变化会翻转一次曝光模式。
- **背景/动机**：为对齐原相机「AE/AF 锁定后上下拖动拉曝光」的交互，OHOS 无「Locked 下直接改 bias」的可用 API，先以重新锁定实现（Dart 侧已按 0.05 EV 节流）。
- **目标状态**：OHOS 真机验证拖动过程有无曝光跳变/抖动；若抖动明显，改为拖动期间保持 `EXPOSURE_MODE_AUTO` + bias（不逐帧重新锁定），松手后再 `LOCKED` 定格。
- **状态**：⏳ 待优化（待 OHOS 真机验证）

### P1 · Android 前置取景器镜像情况无代码证据，触点水平翻转目前仅 iOS 生效

- **模块**：拍摄页点击对焦（Flutter `lib/features/capture/services/camerawesome_camera_service.dart`）
- **优化点**：iOS 前置预览层镜像（`packages/camerawesome/ios/Classes/CameraPreview/CameraPreview.m` 的 `setVideoMirrored:(Sensor == Front)`，AVCam 惯例为 `devicePoint.x = 1 - devicePoint.x`），已在 Dart 侧按平台翻转触点 x；Android fork 内未见 `MIRROR_MODE`/`scaleX` 镜像证据，故未翻转。
- **背景/动机**：`capture_page.dart` 既有注释称「iOS/Android 前置预览均为系统默认镜像画面」，但当前只找到 iOS 的代码证据；Android（CameraX TextureView 管线）无法在本机编译验证。
- **目标状态**：Android 真机在前置取景器点按左右两侧，确认对焦落点是否左右相反；若确为镜像，再补 Android 分支翻转。
- **状态**：⏳ 待优化（待 Android 真机验证）

### P2 · 取景器对焦曝光拖动量程沿用 ±3 档（iOS 原相机太阳滑块约 ±2 档）

- **模块**：拍摄页对焦曝光（Flutter `lib/features/capture/widgets/camera_preview.dart`）
- **优化点**：对焦框太阳滑块的偏移量程沿用 App 既有 EV 满量程 **±3 档**（`brightness = 0.5 + ev/6`，与顶部 EV 胶囊、参数面板滑块同一语义），iOS 原相机太阳滑块约为 ±2 档。
- **背景/动机**：量程若单独改为 ±2，会与紧邻的顶部 EV 胶囊 / 参数面板滑块的可调区间不一致，且实际下发亮度是按「参数 EV + 对焦偏移」合成后钳制 ±3 的，收窄偏移量程只影响滑动手感、不改变曝光语义，收益有限。
- **目标状态**：若后续产品确认应以 iOS 为准，可单独收敛太阳滑块的偏移量程到 ±2 档。
- **状态**：⏳ 待优化（待产品确认）

> 说明（2026-09-25 已落地）：**对焦曝光与参数曝光已拆分为两个独立功能**，此前本条记录的「轻点不复位」取舍已随拆分取消——
> - 参数 EV（`CameraParams.exposureCompensation`）：模板 / 会话曝光**基准**，落库、随模板复用，显示在顶部胶囊与参数面板；
> - 对焦偏移（`CaptureState.focusExposureOffsetProvider`）：锚定最近对焦触点的**临时微调**，不进模板、不落库、不出现在面板/胶囊；
> - 实际下发 = `CaptureState.effectiveExposureEvProvider`（参数 EV + 偏移，钳制 ±3），取景器亮度与成片同源；换点对焦 / 长按锁定 / 切换前后摄 / 进入拍摄页均将偏移归零。

---

## AI 研究管线 · 联网搜索（2026-09-25）

### P1 · 搜索来源「缺端点/Key」与「未配置」混为一谈，编排层会误写 skip-research

- **模块**：AI 一键生图研究管线（后端 `modules/ai/ai-config.service.ts` `getSearchConfig()` + `modules/ai/ai-orchestrator.service.ts` step 2 研究）
- **优化点**：`getSearchConfig()` 在 `searchProvider=qwen` / `qwen-official` 且**缺端点或 API Key** 时返回 `sources: []`；而 `ai-orchestrator.service.ts:99` 以 `enabled && sources.length && topic` 判定 `researchEnabled`，`sources` 为空即落进 `else if (!researchEnabled)` 分支写 trace `skip-research`。于是「研究已开启、只是凭据没填全」被记成「研究未开启」，与设计文档「绝不误写 skip-research」的表述冲突。
- **背景/动机**：2026-09-25 「Qwen 官方百炼 / Qwen 三方 MaaS 联网搜索拆分」实现时评审发现（I-1）。该行为在拆分前的 `qwen` 分支即已存在，非本次引入，故本次只登记不改，避免扩大改动面。
- **目标状态**：让编排层依 `searchCfg.enabled` 决定是否跳过，而非依 `sources.length`；并把「未配置搜索」（正常 skip）与「已配置但凭据缺失/异常」（应记失败原因，如 `skip-research: missing-credentials`）在 trace 上区分开。补 `ai-orchestrator` / `ai-config.service` 单测覆盖两种情形。
- **状态**：⏳ 待优化

---

## AI 研究管线 · 研究资料二次整理与时间线（2026-09-26）

### P1 · 研究整理结果仅进程内缓存，未落库共享

- **模块**：AI 一键生模板研究管线（后端 `modules/ai/trend-research/research-digest.service.ts`）
- **优化点**：新增的「资料整理」阶段把联网检索条目交给文本模型二次整理成结构化 `ResearchBrief`，结果只放在进程内 LRU（max 100，key = topic + 条目指纹）。多实例部署或进程重启后缓存不共享，同主题会重复调用 LLM。
- **背景/动机**：`schema.ts` 已有 `trend_index`（topic × source × trend_date 幂等 upsert + 7 天新鲜度衰减）表，天然适合承载整理结果；但本次为控制改动面只做进程内缓存，先把「整理后的资料真正进入模板生成提示词」跑通。
- **目标状态**：把 `ResearchBrief` 按 topic + 日期落 `trend_index`（或新增独立表），跨实例/重启复用；读取时按新鲜度衰减决定是否重新整理，避免重复 LLM 调用。
- **状态**：⏳ 待优化

### P2 · 生图阶段未复用同一份研究整理结果

- **模块**：AI 一键生图（后端 `modules/ai/image-prompt.composer.ts`）
- **优化点**：识别阶段已产出结构化 `ResearchBrief`，但生图链路的 `buildPromptMaterial()` 仍消费原始 `ResearchItem[]`（经 `buildResearchLines` 规则拼接），由组织器自身再整理一次。
- **背景/动机**：生图组织器的提示词已明确要求「忽略排版残留 / 只使用有效信息」，本质上已是一次 LLM 整理，因此不构成「联网做无用功」；但两处各整理一次，风格口径可能不完全一致，且多消耗一次上下文。
- **目标状态**：把识别阶段的 `ResearchBrief`（或其渲染文本）透传到 `ai-generate-image/batch` → `AiGenerateImageService.generate`，生图组织器直接复用同一份整理结论，去掉原始条目分节。
- **状态**：⏳ 待优化
