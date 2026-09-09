# OHOS 出片「先快后真」改造

## Context（为什么做）

OHOS 端快门到用户看到可用照片太慢（~3s）。根因是 `_onCapture()` 同步阻塞链：

1. `await cameraService.capture()` 阻塞等 CameraKit 交付 full-res JPEG（实测 ~2.2s，`QUALITY_LEVEL_HIGH`+`HIGH_QUALITY`，用户已决定保留）；
2. 全尺寸后处理 `processJpeg`（解码→矩阵→磨皮/锐化/暗角/颗粒→硬编码）同步跑完才 `setFinalResult`；
3. `_goToPreviewWhenReady()` 等到 `finalPath` 才打开预览页。

原生相机/官方 demo 之所以"瞬间出片"，是因为用 `DeliveryMode.FAST_MODE` 低质量帧先顶屏（~672ms），全尺寸后台落盘。我们已有 OHOS 早帧通道 `cameraService.photoEarlyFrames()`（EventChannel，`{cacheDir}/anim_early_*.jpg`，~672ms 到），目前只用于水印动画。

**用户拍板方向（已确认）**：先快后真——快门 → ~672ms 早帧即作为可见缩略图 + 立即可打开预览页；full-res 后处理后台完成后**原位升级**高清。保持 HIGH_QUALITY。只动 OHOS 路径，不破坏 iOS/Android 与水印动画/连拍。

**关键事实（已核实）**：`CameraState.ets` 的 `photoAssetAvailable` 分支只要 `_photoDirectDone`（photoAvailable 直出成功）就**无条件** `requestEarlyFrameForAnimation`，水印门控只在 Dart 侧。所以早帧每次成功拍摄都会产生，Dart 始终订阅即可，**fork 零改动**。

## 方案

### 1. 缩略图状态机 — `lib/features/capture/data/capture_thumbnail_state.dart`
- `enum CaptureThumbnailStatus` 增加 `interim`。
- 新增字段 `final String? interimPath;`（早帧路径），`copyWith` 同步。
- `startCapture({String? photoId})`：photoId 前置（快门处生成），`photoId: photoId ?? state.photoId`。
- 新增 `setInterimResult(String path, {String? photoId})`：`status=interim, interimPath=path, photoId=...`。

### 2. 缩略图渲染 — `lib/features/capture/widgets/capture_thumbnail.dart`
`_buildContent` 的 switch 增加：
```dart
case CaptureThumbnailStatus.interim:
  final ip = state.interimPath;
  if (ip != null && File(ip).existsSync()) return Image.file(File(ip), fit: BoxFit.cover);
  return const SizedBox.shrink(); // 早帧未就绪退回转圈位
```

### 3. 捕获流程 — `lib/features/capture/pages/capture_page.dart`
- **快门 photoId 前置 + 实例字段**（`_onCapture`）：`final photoId='photo_${ts}'`；新增实例字段 `_currentShutterPhotoId`、`_currentShouldAnimate`、`_currentWmTemplate`。`startCapture(photoId: photoId)`。
- **早帧订阅改无条件（OHOS）**（原只在 `shouldAnimateNow` 时订阅）：
  ```dart
  final isOhos = !isIos && !Platform.isAndroid;
  _expectingEarlyFrame = isOhos;
  if (isOhos) {
    _earlyFrameSub ??= cameraService.photoEarlyFrames().listen((path) {
      if (!_expectingEarlyFrame || _showWatermarkAnimation || path.isEmpty) return;
      _expectingEarlyFrame = false;
      final pid = _currentShutterPhotoId;
      if (pid != null) { ref.read(captureThumbnailProvider.notifier).setInterimResult(path, photoId: pid); }
      if (_currentShouldAnimate && _currentWmTemplate != null) { _startWatermarkAnimation(path, _currentWmTemplate!); }
    });
  }
  ```
  订阅一次性（`??=`），回调从实例字段读水印参数（防连拍/中途开关串值）。原水印回退分支保留不动。
- **入队透传 photoId**：`_CaptureProcessParams`（类约 4059 行）加 `required String photoId`；`_processCaptureQueue.add(... photoId: photoId)`。
- **后处理落点**：删 `_processCaptureQueueItem` 内 `final photoId='photo_'...`（约 1177 行），改用 `params.photoId`；DB 落库 / `setFinalResult(finalPath, params.photoId)` 沿用同一 id。interim/final 各加 `debugPrint('[perf] interim/final ...ms')` 埋点。
- **`_goToPreviewWhenReady`**（约 1317 行）放行 interim：
  ```dart
  if ((state.finalPath != null || state.interimPath != null) && state.photoId != null) { _onThumbnailTap(); return; }
  ```
- **`_onThumbnailTap`**（约 1919 行）：`path = state.finalPath ?? state.interimPath`；`pendingFinal = state.finalPath==null && state.interimPath!=null`；route 追加 `&pendingFinal=1`。
- **挑战模式监听**（约 1724-1733 行）：prev 校验集合加 `CaptureThumbnailStatus.interim`（仍只 `next==final_` 跳转）。

### 4. 路由 — `lib/app/router.dart`
`capturePreview` builder（139-152 行）读 `state.queryParams['pendingFinal']`，透传 `CapturePreviewPage(pendingFinal: pendingFinal=='1')`。

### 5. 预览页 — `lib/features/capture/pages/capture_preview_page.dart`
- 构造加 `final bool pendingFinal = false;`。
- 新增 `bool _isPendingFinal`、`String? _interimUrl`；`initState`（约 196 行）`_isPendingFinal = widget.pendingFinal`。
- `initState` 用 `ref.listenManual<CaptureThumbnailState>(captureThumbnailProvider, ...)` 监听：当 `_isPendingFinal && next.status==final_ && next.finalPath!=null && _isEdited==false` → `_upgradeInterimToFinal(next.finalPath!)`。`dispose` 关闭订阅，且升级后置 `_isPendingFinal=false`。
- `_upgradeInterimToFinal(String finalPath)`：`setState(_photoUrl=finalPath; _isPendingFinal=false)`；`PaintingBinding.instance.imageCache.evict(FileImage(...))` 新旧路径；`_loadHistoryPhotos()` 重载 full-res（恢复 originalPath/bakedPostProcess/只读位）。
- **编辑门控**：`_updateLocalPostProcess`/`_updateLocalTransform`/裁剪 onChanged/保存入口，若 `_isPendingFinal` 则 toast「高清照片生成中，稍后再编辑」并 return，升级后自动放行。
- `_isEdited` 字段需确认已存在（用于防覆盖）；若不存在则用 `_isPendingFinal` 门控兜底。

### 6. DB（默认方案 B：interim 不写库）
- 保持全量后处理完成后再 `insert` 一次，仅把 id 换成 `params.photoId`。
- interim 预览时 `galleryDaoProvider.getById` 查不到记录 → 走 `_loadOriginalPath` 退化为单张；full-res 升级后 `_loadHistoryPhotos()` 重新拉到已插入记录。零 DB 双写、不把 `cacheDir` 低清文件写进相册。
- （备选 A：若产品要"拍完立即进相册"，则先插 interim、full-res 后 `updateFinalPath` 仅改 path。默认不做。）

## 边界与降级
- 非水印 OHOS：早帧无条件产生，interim 生效。
- 早帧未到（失败/兜底）：不 `setInterimResult`，状态停 `processing`，完整回退现状，不卡死。
- 连拍：沿用现有 `captureSeq`+`_expectingEarlyFrame` 防串机制（与现有水印同局限，不新增回归）。
- 预览打开后 full-res 完成：原位升级 + evict，`_isEdited==false` 才升；门控拦截编辑。
- iOS/Android：`isOhos=false`，早帧流空，interim 永不写入，`pendingFinal` 不置位，完整回落。

## 验证（OHOS 真机）
`flutter run --dart-define=API_BASE_URL=...`，看 `[perf]/[capture]` 日志：
1. 快门 t0 → `interim ≈ 672ms` 缩略图立即显示早帧、点击即开预览；
2. `final ≈ 2.2s` 预览原位升级高清（观察锐度变化、无旧帧残留）；
3. 水印+动画：动画照常，淡出即进预览（interim）后升级；
4. 挑战模式：不因 interim 提前跳确认页，full-res 后才跳；
5. 无早帧兜底：回落到 processing 等 final，不卡死；
6. 连拍 3 张：interim/final 一一对应不串 pid；
7. iOS/Android 回归：行为无变化；
8. 预览 pendingFinal 窗口内编辑/保存被门控提示，升级后正常。

**同时确认分辨率修复**：`_ohosNativeMaxDim=2560`（capture_page.dart#L105）已 在 工作区，需一并真机重测确认「不糊」。

## 涉及文件
- lib/features/capture/data/capture_thumbnail_state.dart
- lib/features/capture/widgets/capture_thumbnail.dart
- lib/features/capture/pages/capture_page.dart
- lib/app/router.dart
- lib/features/capture/pages/capture_preview_page.dart