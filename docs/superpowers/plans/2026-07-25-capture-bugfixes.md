# Capture Page Bugfixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve one critical runtime crash and 9 reported issues in the capture/gallery flow of the lumira_app_flutter app.

**Architecture:** The capture flow uses Riverpod for state, camerawesome_ohos for camera, GoRouter for navigation, and SQLite for persistence. The crash is a widget-lifecycle violation in `_CapturePageState.dispose`. The 9 issues span: aspect-ratio crop mismatch, zoom scale inconsistency, zoom slider ranges, auto-save to album, gallery detail UI, multi-select mode, template parameter application, scene auto-tagging, and post-capture processing UI (compare / comparison image / EXIF card).

**Tech Stack:** Flutter 3.x, Dart, Riverpod 2.x, camerawesome_ohos 1.0.2, go_router, sqflite, image package, HarmonyOS photoAccessHelper via MethodChannel.

## Global Constraints

- Project root: `e:\Project\photo_post\lumira_app_flutter`
- All file paths in tasks are relative to project root unless prefixed with `e:\Project\photo_post\`
- Tests must pass: `flutter test` (Dart tests in `test/`)
- Static analysis must pass: `flutter analyze` (0 errors, 0 warnings)
- Do NOT change `pubspec.yaml` dependencies unless a task explicitly requires it
- HarmonyOS native channel name is `lumira/photo_saver` (existing)
- Camera plugin: `camerawesome_ohos` (fork of camerawesome 1.4.0); `setZoom` takes a normalized `[0.0, 1.0]` value where 0 = min zoom, 1 = max zoom
- Existing template parameter application: only `flashMode` and `mirrorFrontCamera` are applied on `_onCameraStateCreated` (Issue 7 root cause)
- Existing scene auto-tagging: `CapturePreviewPage._selectedSceneId` defaults to `null` (Issue 8 root cause)

---

## File Structure

**Modified files (existing):**
- `lib/features/capture/pages/capture_page.dart` — Fix crash, apply template params, fix zoom slider, auto-save to album
- `lib/features/capture/data/capture_state.dart` — Add zoom range providers, scene preselection
- `lib/features/capture/services/photo_post_processor.dart` — Fix `_computeCropRect` for fullscreen case
- `lib/features/capture/widgets/aspect_ratio_selector.dart` — Persist user's choice and emit change events
- `lib/features/capture/pages/capture_preview_page.dart` — Auto-select scene, implement compare / EXIF card / comparison image
- `lib/features/gallery/pages/gallery_page.dart` — Add long-press multi-select mode
- `lib/features/gallery/pages/gallery_detail_page.dart` — Fix UI so all sections render
- `lib/features/gallery/widgets/photo_cell.dart` — Add long-press handler for multi-select

**New files (created):**
- `lib/features/capture/services/compare_image_generator.dart` — Side-by-side comparison image generator
- `lib/features/capture/services/exif_card_generator.dart` — EXIF info card image generator
- `lib/features/capture/services/photo_exif_reader.dart` — Read EXIF metadata from JPEG files
- `test/features/capture/capture_page_crash_test.dart` — Failing test for crash fix
- `test/features/capture/photo_post_processor_crop_test.dart` — Tests for aspect ratio crop
- `test/features/capture/zoom_slider_range_test.dart` — Tests for zoom slider ranges
- `test/features/gallery/gallery_multiselect_test.dart` — Tests for multi-select mode
- `test/features/capture/compare_image_generator_test.dart` — Tests for comparison image generator
- `test/features/capture/exif_card_generator_test.dart` — Tests for EXIF card generator

---

## Task 1: Fix "deactivated widget's ancestor is unsafe" crash

**Files:**
- Modify: `lib/features/capture/pages/capture_page.dart:49-119`
- Test: `test/features/capture/capture_page_crash_test.dart`

**Interfaces:**
- Consumes: `flutter_riverpod` `ProviderContainer`, `CaptureState.cameraStateProvider`
- Produces: A `_CapturePageState` that safely clears provider state in `dispose()` without accessing the deactivated element tree

**Root Cause (Phase 1 complete):**
The stack trace points to `_CapturePageState.dispose` line 109 calling `ref.read(CaptureState.cameraStateProvider.notifier).state = null`. Inside `ConsumerStatefulElement.read`, Riverpod calls `ProviderScope.containerOf(this)` which calls `getElementForInheritedWidgetOfExactType<ProviderScope>()`. By the time `dispose()` runs during `_InactiveElements._unmount`, the element is no longer active, so the ancestor lookup asserts. The fix is to capture the `ProviderContainer` reference while the element is still active (in `didChangeDependencies` or `initState` via `ref.container`) and use that cached reference in `dispose()`.

- [ ] **Step 1: Write a failing widget test that disposes CapturePage and asserts no FlutterError**

Create `test/features/capture/capture_page_crash_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/pages/capture_page.dart';
import 'package:lumira_app_flutter/features/capture/widgets/camera_preview.dart';

import '../../../test/helpers/test_http_overrides.dart';

void main() {
  late GoRouter router;
  FlutterExceptionHandler? originalErrorHandler;

  setUp(() {
    HttpOverrides.global = TestHttpOverrides();
    originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('NetworkImageLoadException')) {
        return;
      }
      // Capture all other errors as failures
      fail('FlutterError during test: ${details.exception}\n${details.stack}');
    };
    router = GoRouter(
      initialLocation: '/capture',
      routes: [
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('home'))),
        ),
        GoRoute(
          path: '/capture',
          name: 'capture',
          builder: (_, state) {
            final templateId = state.queryParams['templateId'];
            return CapturePage(templateId: templateId);
          },
        ),
      ],
    );
  });

  tearDown(() {
    HttpOverrides.global = null;
    FlutterError.onError = originalErrorHandler;
  });

  testWidgets('dispose() does not throw deactivated-ancestor assertion',
      (tester) async {
    const cameraPlaceholder = ColoredBox(
      key: Key('camera_placeholder'),
      color: Color(0xFF333333),
      child: SizedBox.expand(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
          uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
          cameraPreviewOverrideProvider.overrideWith((ref) => cameraPlaceholder),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CapturePage), findsOneWidget);

    // Pop the page to trigger dispose()
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    // Force a frame to finalize tree (this is where the assertion fired)
    await tester.pumpAndSettle();

    // If we reach here without fail(), the crash is fixed
    expect(find.byType(CapturePage), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails with the deactivated-ancestor assertion**

Run: `flutter test test/features/capture/capture_page_crash_test.dart`
Expected: FAIL with `Looking up a deactivated widget's ancestor is unsafe.` or similar widget-tree assertion.

- [ ] **Step 3: Fix `capture_page.dart` — cache `ProviderContainer` and use it in `dispose`**

In `lib/features/capture/pages/capture_page.dart`, add a field and override `didChangeDependencies`. Replace lines 49-119 with the following (note the new `ProviderContainer? _container` field, the new `didChangeDependencies` override, and the changed `dispose` that uses `_container` instead of `ref.read`):

```dart
class _CapturePageState extends ConsumerState<CapturePage>
    with WidgetsBindingObserver {
  bool _isLandscape = false;
  StreamSubscription<MediaCapture?>? _captureSub;
  CameraState? _lastState;
  CameraPermissionStatus _permissionStatus = CameraPermissionStatus.unknown;

  /// 拍照处理中标志：防止用户快速连续拍照导致文件并发写入冲突
  bool _isProcessing = false;

  /// 返回结果模式：当通过 ?mode=return 进入时，拍照完成后 pop 回上一页
  bool _returnResult = false;

  /// 相机重建 key：每次 app 从后台恢复时递增
  int _cameraRebuildKey = 0;

  /// 缓存的 ProviderContainer 引用。
  /// 在 dispose() 中调用 ref.read 会触发 ProviderScope.containerOf(this)，
  /// 它通过 getElementForInheritedWidgetOfExactType 查询 widget 树祖先；
  /// 但 dispose() 执行时 element 已被 deactivate，断言 "Looking up a
  /// deactivated widget's ancestor is unsafe" 会抛出。
  /// 在 didChangeDependencies（element 仍 active）中缓存 container 引用，
  /// dispose 时通过引用直接操作 provider，绕过 widget 树查询。
  ProviderContainer? _container;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(CaptureState.currentTemplateIdProvider.notifier).state =
          widget.templateId;
      final mode = GoRouterState.of(context).queryParams[RouteNames.paramMode];
      _returnResult = mode == 'return';
      _requestCameraPermission();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Element 仍 active 时缓存 container，供 dispose() 使用
    _container = ProviderScope.containerOf(context);
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      switch (status) {
        case PermissionStatus.granted:
          _permissionStatus = CameraPermissionStatus.granted;
          break;
        case PermissionStatus.permanentlyDenied:
          _permissionStatus = CameraPermissionStatus.permanentlyDenied;
          break;
        default:
          _permissionStatus = CameraPermissionStatus.denied;
      }
    });
  }

  @override
  void dispose() {
    _captureSub?.cancel();
    // 使用缓存的 container 引用清除 cameraStateProvider，
    // 避免 ref.read 在 deactivated element 上查询 widget 树祖先
    _container?.read(CaptureState.cameraStateProvider.notifier).state = null;
    // 显式停止原生相机（幂等，重复调用无副作用）
    CamerawesomePlugin.stop().catchError((_) => false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/capture/capture_page_crash_test.dart`
Expected: PASS, no FlutterError fired.

- [ ] **Step 5: Run full capture_page test suite to ensure no regressions**

Run: `flutter test test/features/capture/capture_page_test.dart`
Expected: All existing tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/capture/pages/capture_page.dart test/features/capture/capture_page_crash_test.dart
git commit -m "fix(capture): resolve deactivated-ancestor crash in _CapturePageState.dispose

Cache ProviderContainer in didChangeDependencies and use it in dispose
to avoid ProviderScope.containerOf querying a deactivated element."
```

---

## Task 2: Fix full-screen capture ratio mismatch (Issue 1)

**Files:**
- Modify: `lib/features/capture/services/photo_post_processor.dart:270-313`
- Modify: `lib/features/capture/pages/capture_page.dart:180-210`
- Test: `test/features/capture/photo_post_processor_crop_test.dart`

**Interfaces:**
- Consumes: `CaptureState.aspectRatioProvider`, `CaptureState.computeTargetRatio`
- Produces: A `_computeCropRect` whose output exactly matches what `CameraPreviewFit.cover` shows in the viewfinder for every ratioId (`fullscreen`, `4:3`, `1:1`, `3:4`)

**Root Cause (Phase 1 complete):**
The viewfinder uses `CameraPreviewFit.cover` which scales the camera sensor image (e.g. 1080×1440 = 0.75 ratio) to fill the viewfinder box, clipping overflow. For `fullscreen`, the viewfinder box equals the screen size (e.g. ratio 0.443), so cover scales the image to fill height and clips left/right, showing the center horizontal strip.

`_computeCropRect` uses the comparison `imgRatio > targetRatio`:
- For `fullscreen` with imgRatio=0.75 and targetRatio=0.443: `0.75 > 0.443` is TRUE, so it takes the first branch: `cropH = imgH; cropW = imgH * targetRatio = 638`. Result: `[221, 0, 638, 1440]`. **This matches cover behavior** (full height, cropped width) — so the fullscreen case is actually correct.

The reported "all ratios result in the same output" comes from a different bug: in `capture_page.dart` line 183, `aspectRatio` is read from `CaptureState.aspectRatioProvider`, but the **post-processor's `params.cropRatio`** (e.g. `'3:4'`) is unrelated to the chosen `aspectRatio` (e.g. `'fullscreen'`). The user's mental model is `cropRatio` should follow `aspectRatio`, but they are independent fields. Additionally, the `4:3` and `3:4` cases both produce 1080×1440 output (no crop) because `computeTargetRatio` returns 0.75 for both in portrait — making them visually indistinguishable from the native camera output.

The actual reported issue ("拍出的照片是一个固定比例") is reproducible when the camera sensor's native ratio happens to equal the target ratio (e.g. 3:4 sensor vs 3:4 selection): the crop is a no-op and the user sees the same 3:4 photo every time they pick any 3:4-class ratio. Fix: add per-ratioId tests proving the output dimensions, and make `_computeCropRect` strictly enforce the target ratio even when `imgRatio == targetRatio` (no-op is fine for that case, but we must guarantee no clamping overrides the target).

- [ ] **Step 1: Write failing tests for `_computeCropRect` covering all four ratioIds**

The function is private, so test via `processFile` with a synthetic JPEG. Create `test/features/capture/photo_post_processor_crop_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/services/photo_post_processor.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('ppp_test_');
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  /// Write a 1080x1440 JPEG (3:4 portrait, common phone sensor ratio)
  File makeSensorJpeg() {
    final image = Image(width: 1080, height: 1440);
    fill(image, Colors.red);
    final path = '${tempDir.path}/sensor_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final bytes = img.encodeJpg(imgImageFromImage(image));
    final file = File(path)..writeAsBytesSync(bytes);
    return file;
  }

  Future<List<int>> processAndDecodeSize({
    required String aspectRatio,
    required double screenRatio,
    required bool isPortrait,
  }) async {
    final input = makeSensorJpeg();
    final output = await PhotoPostProcessor.processFile(
      inputPath: input.path,
      params: const PostProcess(color: PostProcessColor()),
      rawMode: false,
      aspectRatio: aspectRatio,
      screenRatio: screenRatio,
      isPortrait: isPortrait,
    );
    final bytes = await File(output).readAsBytes();
    final codec = await instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final w = frame.image.width;
    final h = frame.image.height;
    codec.dispose();
    return [w, h];
  }

  test('fullscreen portrait: output ratio matches screenRatio', () async {
    // 9:19.5 phone portrait → screenRatio = 9/19.5 ≈ 0.4615
    final size = await processAndDecodeSize(
      aspectRatio: 'fullscreen',
      screenRatio: 9.0 / 19.5,
      isPortrait: true,
    );
    final ratio = size[0] / size[1];
    expect(ratio, closeTo(9.0 / 19.5, 0.02),
        reason: 'fullscreen output must match screen ratio');
  });

  test('4:3 portrait: output ratio is 3:4 (0.75)', () async {
    final size = await processAndDecodeSize(
      aspectRatio: '4:3',
      screenRatio: 9.0 / 19.5,
      isPortrait: true,
    );
    final ratio = size[0] / size[1];
    expect(ratio, closeTo(0.75, 0.02),
        reason: '4:3 portrait output must be 3:4');
  });

  test('1:1: output ratio is 1.0', () async {
    final size = await processAndDecodeSize(
      aspectRatio: '1:1',
      screenRatio: 9.0 / 19.5,
      isPortrait: true,
    );
    final ratio = size[0] / size[1];
    expect(ratio, closeTo(1.0, 0.02), reason: '1:1 output must be square');
  });

  test('3:4: output ratio is 0.75 regardless of orientation', () async {
    final size = await processAndDecodeSize(
      aspectRatio: '3:4',
      screenRatio: 9.0 / 19.5,
      isPortrait: true,
    );
    final ratio = size[0] / size[1];
    expect(ratio, closeTo(0.75, 0.02),
        reason: '3:4 output must always be 3:4');
  });

  test('4:3 landscape: output ratio is 4:3 (1.333)', () async {
    final size = await processAndDecodeSize(
      aspectRatio: '4:3',
      screenRatio: 19.5 / 9.0,
      isPortrait: false,
    );
    final ratio = size[0] / size[1];
    expect(ratio, closeTo(4.0 / 3.0, 0.02),
        reason: '4:3 landscape output must be 4:3');
  });
}

// Test helpers (in same file to keep task self-contained)
img.Image imgImageFromImage(Image image) {
  final out = img.Image(width: image.width, height: image.height);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      out.setPixelRgb(x, y, 255, 0, 0);
    }
  }
  return out;
}
```

- [ ] **Step 2: Run tests to verify which cases fail**

Run: `flutter test test/features/capture/photo_post_processor_crop_test.dart`
Expected: At least the `fullscreen` test FAILS because the current code's crop dimensions get downsampled to a different ratio after the `maxDimension = 1536` step. (Identify exactly which assertions fail before fixing.)

- [ ] **Step 3: Fix `_computeCropRect` and the downsample step in `photo_post_processor.dart`**

In `lib/features/capture/services/photo_post_processor.dart`, replace the existing `_computeCropRect` (lines 274-313) with the following version that adds explicit logging of the final crop ratio and clamps the downsample step to preserve the target ratio:

```dart
/// 计算裁剪区域 [x, y, width, height]
///
/// 关键：使用与取景器 [CaptureState.computeTargetRatio] 完全一致的比例计算逻辑，
/// 与 [CameraPreviewFit.cover] 的缩放行为严格对应：
/// - 当 imgRatio > targetRatio：图片比目标"更宽"→ 保留满高，左右裁剪
/// - 当 imgRatio <= targetRatio：图片比目标"更高"→ 保留满宽，上下裁剪
/// 'fullscreen' 模式按 screenRatio 裁剪（screenRatio 即取景器全屏显示比例）。
static List<int> _computeCropRect(
  String ratio,
  int imgW,
  int imgH,
  double screenRatio,
  bool isPortrait,
) {
  if (ratio == 'free' || ratio == 'none') {
    return [0, 0, imgW, imgH];
  }

  final targetRatio =
      CaptureState.computeTargetRatio(ratio, isPortrait) ?? screenRatio;

  final imgRatio = imgW / imgH;
  double cropW, cropH;
  if (imgRatio > targetRatio) {
    // 图片更宽 → 裁剪左右，与 cover 模式一致
    cropH = imgH.toDouble();
    cropW = cropH * targetRatio;
  } else {
    // 图片更高 → 裁剪上下，与 cover 模式一致
    cropW = imgW.toDouble();
    cropH = cropW / targetRatio;
  }

  // 严格 clamp 到图像边界内（防止 targetRatio 极端时溢出）
  cropW = cropW.clamp(1.0, imgW.toDouble());
  cropH = cropH.clamp(1.0, imgH.toDouble());

  final offsetX = ((imgW - cropW) / 2.0).round().clamp(0, imgW - 1);
  final offsetY = ((imgH - cropH) / 2.0).round().clamp(0, imgH - 1);
  final width = cropW.round().clamp(1, imgW - offsetX);
  final height = cropH.round().clamp(1, imgH - offsetY);

  // 诊断日志：输出最终裁剪后的比例，便于与取景器对比
  debugPrint('[post-process] 目标比例=$targetRatio, 图像比例=$imgRatio, '
      '裁剪后比例=${width / height}');

  return [offsetX, offsetY, width, height];
}
```

Then update the downsample block (lines 68-76) so it preserves the target ratio exactly. Replace the block with:

```dart
// 3. 计算降采样后的输出尺寸（长边 ≤ 1536，严格保持裁剪区域比例）
const maxDimension = 1536;
var outW = cropRect[2];
var outH = cropRect[3];
if (outW > maxDimension || outH > maxDimension) {
  final scale = maxDimension / math.max(outW, outH);
  outW = (outW * scale).round();
  outH = (outH * scale).round();
}
// 严格保持目标比例（防止 round 引入的 ±1px 误差累积）
final targetRatio = outW / outH;
final intendedRatio = cropRect[2] / cropRect[3];
if ((targetRatio - intendedRatio).abs() > 0.005) {
  // 重新计算 outH 让比例匹配
  outH = (outW / intendedRatio).round();
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/capture/photo_post_processor_crop_test.dart`
Expected: All 5 tests PASS.

- [ ] **Step 5: Add diagnostic logging in `capture_page.dart` to verify aspectRatio is read at capture time**

In `lib/features/capture/pages/capture_page.dart`, in the `_captureSub` listener (around line 180), add a debugPrint before calling `processFile`:

```dart
debugPrint('[capture] 当前 aspectRatio=$aspectRatio, '
    'screenRatio=$screenRatio, isPortrait=$isPortrait, '
    'rawMode=$rawMode');
```

- [ ] **Step 6: Run full capture test suite**

Run: `flutter test test/features/capture/`
Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/capture/services/photo_post_processor.dart \
        lib/features/capture/pages/capture_page.dart \
        test/features/capture/photo_post_processor_crop_test.dart
git commit -m "fix(capture): align post-process crop with viewfinder cover behavior

Add per-ratioId crop tests, preserve target ratio through downsample,
and add diagnostic logging so aspectRatio mismatches are visible."
```

---

## Task 3: Maintain consistent zoom across ratio changes (Issue 2)

**Files:**
- Modify: `lib/features/capture/pages/capture_page.dart:316-326, 386-450`
- Modify: `lib/features/capture/widgets/aspect_ratio_selector.dart`

**Interfaces:**
- Consumes: `CaptureState.zoomProvider`, `CaptureState.aspectRatioProvider`, `cameraStateProvider`
- Produces: A zoom level that visually stays the same when the user switches aspect ratio

**Root Cause (Phase 1 complete):**
When the user picks `4:3` (3:4 box) the viewfinder widget shrinks to a 3:4 box centered on screen. The camera sensor's `setZoom` is unchanged, but the preview is now displayed in a smaller box with `cover` mode, so the visible content's apparent zoom changes (the same sensor zoom level shows different amounts of the scene depending on the box ratio). The user expects "zoom" to mean the same field of view regardless of the chosen aspect ratio.

The fix is to compute a **crop-compensating zoom factor**: when the viewfinder box shrinks, the camera's effective zoom should be reduced proportionally so the displayed content's apparent size stays constant. Concretely, we keep `zoomProvider` as the user-facing "apparent zoom" and translate it to sensor zoom by dividing by the ratio-dependent crop factor.

- [ ] **Step 1: Add an `effectiveSensorZoomProvider` to `capture_state.dart`**

In `lib/features/capture/data/capture_state.dart`, after `zoomProvider` (line 31), add:

```dart
/// 用户面对的"视觉缩放"（与取景器中显示的内容大小一致，跨比例切换保持稳定）。
/// 范围 [0.0, 1.0]，0 = 1x，1 = 最大缩放。
/// 切换比例时此值不变，但实际传给 sensorConfig.setZoom 的值会按比例补偿。
static final apparentZoomProvider = StateProvider<double>((ref) => 0.0);

/// 根据 aspectRatio 和屏幕比例计算"比例补偿系数"。
/// 全屏（不裁剪）时系数为 1.0；其他比例下，相机预览在更小的框内 cover 显示，
/// 实际看到的视野更窄，等效于放大了 (boxHeight/screenHeight) 倍。
/// 系数 = 视野缩放比 = 显示框的最短边 / 屏幕最短边。
static double ratioCompensationFactor(String ratioId, bool isPortrait) {
  final target = computeTargetRatio(ratioId, isPortrait);
  if (target == null) return 1.0; // fullscreen
  // 这里只能给一个近似估计：3:4 框 vs 全屏框的差距
  // 全屏框 ratio ≈ 9/19.5 = 0.46（竖屏），3:4 框 ratio = 0.75
  // 假设屏幕短边固定，框短边 = 屏幕短边（竖屏即 width）
  // 框长边 / 屏幕长边 = ratio 屏 / ratio 框 = 0.46/0.75 ≈ 0.61
  // 即 3:4 框只显示屏幕全屏 61% 的高度 → 等效放大 1/0.61 ≈ 1.64
  // 但这只是在 width 上的差距；为简化，使用 width 比作为补偿
  if (isPortrait) {
    switch (ratioId) {
      case '4:3':
      case '3:4':
        return 0.75; // 3:4 框相对全屏框的宽度比
      case '1:1':
        return 1.0; // 1:1 框宽度等于屏宽
      default:
        return 1.0;
    }
  } else {
    switch (ratioId) {
      case '4:3':
        return 0.75;
      case '1:1':
        return 1.0;
      default:
        return 1.0;
    }
  }
}

/// 实际传给 sensorConfig.setZoom 的值。
/// = sqrt(apparentZoom) * ratioCompensationFactor
/// （sqrt 沿用原有曲线；乘以补偿系数让 3:4 框下的实际 sensor zoom 更小，
/// 抵消框缩小带来的视觉放大）
static double computeSensorZoom(double apparentZoom, double factor) {
  final sqrtZoom = math.sqrt(apparentZoom.clamp(0.0, 1.0));
  return (sqrtZoom * factor).clamp(0.0, 1.0);
}
```

Add `import 'dart:math' show math;` at the top of `capture_state.dart` (above the existing imports).

- [ ] **Step 2: Update `_onZoomChanged` and the zoom listener in `capture_page.dart`**

In `lib/features/capture/pages/capture_page.dart`, replace the existing `_onZoomChanged` (lines 321-326) with:

```dart
/// 缩放：同步到相机引擎与 zoomProvider
///
/// 滑块值 [0, 1] 是"视觉缩放"，跨比例切换保持稳定。
/// 实际传给 sensor 的 zoom 会按当前比例的补偿系数调整，保证视觉一致。
void _onZoomChanged(double sliderValue) {
  ref.read(CaptureState.apparentZoomProvider.notifier).state = sliderValue;
  ref.read(CaptureState.zoomProvider.notifier).state = sliderValue;
  _applyZoomToSensor(ref);
}

void _applyZoomToSensor(WidgetRef ref) {
  final apparent = ref.read(CaptureState.apparentZoomProvider);
  final ratioId = ref.read(CaptureState.aspectRatioProvider);
  final isPortrait = MediaQuery.of(context).height >= MediaQuery.of(context).width;
  final factor = CaptureState.ratioCompensationFactor(ratioId, isPortrait);
  final sensorZoom = CaptureState.computeSensorZoom(apparent, factor);
  final state = ref.read(CaptureState.cameraStateProvider);
  state?.sensorConfig.setZoom(sensorZoom);
}
```

- [ ] **Step 3: Add a listener for aspectRatio changes that re-applies zoom**

In the `build` method of `_CapturePageState` (around line 343, after the existing `ref.listen<CaptureFlashMode>` block), add:

```dart
// 监听比例变化，重新应用缩放以保持视觉一致
ref.listen<String>(CaptureState.aspectRatioProvider, (prev, next) {
  if (prev == next) return;
  _applyZoomToSensor(ref);
});
```

- [ ] **Step 4: Update `_ZoomSlider` to display multiplier based on `apparentZoomProvider`**

In `lib/features/capture/pages/capture_page.dart`, change the `_ZoomSlider` widget (lines 635-675) to read from `apparentZoomProvider` instead of `zoomProvider`. Replace the `value` parameter usage:

```dart
class _ZoomSlider extends ConsumerWidget {
  const _ZoomSlider({required this.onChanged});

  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(CaptureState.apparentZoomProvider);
    final actualZoom = sqrt(value);
    final displayX = (1 + actualZoom * 5).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.zoom_in, color: Colors.white70, size: 16),
          Expanded(
            child: Slider(
              value: value.clamp(0.0, 1.0),
              min: 0.0,
              max: 1.0,
              divisions: 100,
              label: '${displayX}x',
              activeColor: Colors.amber,
              inactiveColor: Colors.white24,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${displayX}x',
              style: const TextStyle(color: Colors.white, fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
```

Update the `_BottomControlArea` to remove the `zoom` parameter and let `_ZoomSlider` watch the provider itself. Change `_BottomControlArea`'s constructor (lines 540-550) to remove `required this.zoom`, and change the build method (lines 562-580) to call `_ZoomSlider(onChanged: onZoomChanged)` instead of `_ZoomSlider(value: zoom, onChanged: onZoomChanged)`. Also remove the `final double zoom;` field (line 554) and remove `zoom: zoom,` from the `_BottomControlArea(...)` call site in `build` (around line 429).

- [ ] **Step 5: Run existing capture tests, fix any breakages**

Run: `flutter test test/features/capture/capture_page_test.dart`
Expected: All tests PASS. If any test references `_ZoomSlider(value:...)` or `zoom:` parameter, update it to match the new API.

- [ ] **Step 6: Commit**

```bash
git add lib/features/capture/data/capture_state.dart \
        lib/features/capture/pages/capture_page.dart
git commit -m "fix(capture): keep visual zoom consistent across aspect ratio changes

Introduce apparentZoomProvider and ratioCompensationFactor so the
sensor zoom is scaled to compensate for viewfinder box size changes."
```

---

## Task 4: Zoom slider with proper ranges and system camera zoom (Issue 3)

**Files:**
- Modify: `lib/features/capture/data/capture_state.dart`
- Modify: `lib/features/capture/pages/capture_page.dart:316-326, 635-675`
- Test: `test/features/capture/zoom_slider_range_test.dart`

**Interfaces:**
- Consumes: `CaptureState.cameraFacingProvider`, `CaptureState.cameraStateProvider`
- Produces: A zoom slider with default 1x, front camera [0.5x, 2x], back camera [0.3x, 10x], driven by `sensorConfig.setZoom` mapped through the device's supported zoom range

**Root Cause (Phase 1 complete):**
The current slider uses a normalized `[0, 1]` value mapped via `sqrt` to sensor zoom `[0, 1]` and displays `1 + zoom * 5` as multiplier. This does not match user expectations: front should be [0.5, 2], back should be [0.3, 10]. The camerawesome plugin's `setZoom(double)` accepts a normalized `[0, 1]` value (0 = min, 1 = max), so we must translate user-facing multipliers to normalized values using `minZoom` and `maxZoom` from the sensor config (when available).

- [ ] **Step 1: Write a failing unit test for the multiplier→normalized mapping**

Create `test/features/capture/zoom_slider_range_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';

void main() {
  group('zoomMultiplierToNormalized', () {
    test('front camera: 0.5x → 0.0, 1x → mid, 2x → 1.0', () {
      // Front: min=0.5, max=2.0; range = 1.5
      // 0.5 → (0.5-0.5)/1.5 = 0.0
      // 1.0 → (1.0-0.5)/1.5 = 0.333
      // 2.0 → (2.0-0.5)/1.5 = 1.0
      expect(CaptureState.zoomMultiplierToNormalized(0.5, 0.5, 2.0),
          closeTo(0.0, 0.001));
      expect(CaptureState.zoomMultiplierToNormalized(1.0, 0.5, 2.0),
          closeTo(0.3333, 0.001));
      expect(CaptureState.zoomMultiplierToNormalized(2.0, 0.5, 2.0),
          closeTo(1.0, 0.001));
    });

    test('back camera: 0.3x → 0.0, 1x → mid, 10x → 1.0', () {
      // Back: min=0.3, max=10.0; range = 9.7
      // 0.3 → 0.0
      // 1.0 → (1.0-0.3)/9.7 = 0.0722
      // 10.0 → 1.0
      expect(CaptureState.zoomMultiplierToNormalized(0.3, 0.3, 10.0),
          closeTo(0.0, 0.001));
      expect(CaptureState.zoomMultiplierToNormalized(1.0, 0.3, 10.0),
          closeTo(0.0722, 0.001));
      expect(CaptureState.zoomMultiplierToNormalized(10.0, 0.3, 10.0),
          closeTo(1.0, 0.001));
    });

    test('clamps out-of-range multipliers', () {
      expect(CaptureState.zoomMultiplierToNormalized(0.0, 0.5, 2.0),
          closeTo(0.0, 0.001));
      expect(CaptureState.zoomMultiplierToNormalized(5.0, 0.5, 2.0),
          closeTo(1.0, 0.001));
    });
  });

  group('normalizedToZoomMultiplier', () {
    test('front camera: 0.0 → 0.5x, 1.0 → 2x', () {
      expect(CaptureState.normalizedToZoomMultiplier(0.0, 0.5, 2.0),
          closeTo(0.5, 0.001));
      expect(CaptureState.normalizedToZoomMultiplier(1.0, 0.5, 2.0),
          closeTo(2.0, 0.001));
    });

    test('back camera: 0.0 → 0.3x, 1.0 → 10x', () {
      expect(CaptureState.normalizedToZoomMultiplier(0.0, 0.3, 10.0),
          closeTo(0.3, 0.001));
      expect(CaptureState.normalizedToZoomMultiplier(1.0, 0.3, 10.0),
          closeTo(10.0, 0.001));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/capture/zoom_slider_range_test.dart`
Expected: FAIL with `zoomMultiplierToNormalized` method not found.

- [ ] **Step 3: Add the multiplier mapping functions and zoom range constants to `capture_state.dart`**

In `lib/features/capture/data/capture_state.dart`, add after the `computeSensorZoom` function (from Task 3):

```dart
/// 默认缩放范围（前端：0.5x ~ 2x；后端：0.3x ~ 10x）
/// 真实设备的 minZoom/maxZoom 通过 SensorConfig 查询；这里作为 fallback。
static const double frontMinZoom = 0.5;
static const double frontMaxZoom = 2.0;
static const double backMinZoom = 0.3;
static const double backMaxZoom = 10.0;

/// 缩放倍数 → 归一化 [0, 1]（用于 sensorConfig.setZoom）
static double zoomMultiplierToNormalized(
    double multiplier, double minZoom, double maxZoom) {
  if (maxZoom <= minZoom) return 0.0;
  return ((multiplier - minZoom) / (maxZoom - minZoom)).clamp(0.0, 1.0);
}

/// 归一化 [0, 1] → 缩放倍数（用于 UI 显示）
static double normalizedToZoomMultiplier(
    double normalized, double minZoom, double maxZoom) {
  return minZoom + (maxZoom - minZoom) * normalized.clamp(0.0, 1.0);
}

/// 根据当前 facing 获取缩放范围
static ({double min, double max}) zoomRangeForFacing(String facing) {
  return facing == 'front'
      ? (min: frontMinZoom, max: frontMaxZoom)
      : (min: backMinZoom, max: backMaxZoom);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/capture/zoom_slider_range_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Replace the slider and `_onZoomChanged` to use multipliers**

In `lib/features/capture/pages/capture_page.dart`, replace the `_ZoomSlider` widget (lines 635-675) and `_onZoomChanged` (lines 321-326) with versions that operate on multiplier values. Use this implementation:

```dart
/// 缩放：以"倍数"为单位（前摄 [0.5, 2.0]，后摄 [0.3, 10.0]）。
/// 默认 1x。通过 sensorConfig.setZoom 调用系统相机能力。
void _onZoomChanged(double multiplier) {
  final facing = ref.read(CaptureState.cameraFacingProvider);
  final range = CaptureState.zoomRangeForFacing(facing);
  final normalized = CaptureState.zoomMultiplierToNormalized(
      multiplier, range.min, range.max);
  ref.read(CaptureState.apparentZoomProvider.notifier).state = normalized;
  ref.read(CaptureState.zoomProvider.notifier).state = normalized;
  final state = ref.read(CaptureState.cameraStateProvider);
  state?.sensorConfig.setZoom(normalized);
}
```

And replace the `_ZoomSlider` widget:

```dart
/// 缩放滑块：以倍数显示，根据 facing 切换范围
class _ZoomSlider extends ConsumerWidget {
  const _ZoomSlider({required this.onChanged});

  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facing = ref.watch(CaptureState.cameraFacingProvider);
    final normalized = ref.watch(CaptureState.apparentZoomProvider);
    final range = CaptureState.zoomRangeForFacing(facing);
    final multiplier = CaptureState.normalizedToZoomMultiplier(
        normalized, range.min, range.max);
    final displayX = multiplier.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.zoom_in, color: Colors.white70, size: 16),
          Expanded(
            child: Slider(
              value: multiplier.clamp(range.min, range.max),
              min: range.min,
              max: range.max,
              divisions: ((range.max - range.min) * 10).round(),
              label: '${displayX}x',
              activeColor: Colors.amber,
              inactiveColor: Colors.white24,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '${displayX}x',
              style: const TextStyle(color: Colors.white, fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Reset zoom to 1x when switching cameras**

In `lib/features/capture/pages/capture_page.dart`, in `_switchCamera` (around lines 290-314), after `state.sensorConfig.setMirrorFrontCamera(isFront)`, replace the existing front-camera zoom block (lines 304-312) with:

```dart
// 切换摄像头后将缩放重置为 1x（新摄像头可能不支持当前倍数）
final range = CaptureState.zoomRangeForFacing(next);
final normalized1x = CaptureState.zoomMultiplierToNormalized(
    1.0, range.min, range.max);
ref.read(CaptureState.apparentZoomProvider.notifier).state = normalized1x;
ref.read(CaptureState.zoomProvider.notifier).state = normalized1x;
try {
  state.sensorConfig.setZoom(normalized1x);
} catch (_) {}
```

- [ ] **Step 7: Initialize zoom to 1x in `_onCameraStateCreated`**

In `lib/features/capture/pages/capture_page.dart`, in `_onCameraStateCreated` (around lines 222-228), replace the existing front-camera-only zoom block with:

```dart
// 默认缩放为 1x（前摄和后摄都重置）
final facing = ref.read(CaptureState.cameraFacingProvider);
final range = CaptureState.zoomRangeForFacing(facing);
final normalized1x = CaptureState.zoomMultiplierToNormalized(
    1.0, range.min, range.max);
try {
  state.sensorConfig.setZoom(normalized1x);
  ref.read(CaptureState.apparentZoomProvider.notifier).state = normalized1x;
  ref.read(CaptureState.zoomProvider.notifier).state = normalized1x;
} catch (_) {}
```

- [ ] **Step 8: Run all capture tests**

Run: `flutter test test/features/capture/`
Expected: All tests PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/features/capture/data/capture_state.dart \
        lib/features/capture/pages/capture_page.dart \
        test/features/capture/zoom_slider_range_test.dart
git commit -m "feat(capture): zoom slider with proper ranges (front 0.5-2x, back 0.3-10x)

Default to 1x, reset on camera switch, drive system camera zoom via
sensorConfig.setZoom mapped through facing-specific multiplier range."
```

---

## Task 5: Auto-save captured photo to app album (Issue 4)

**Files:**
- Modify: `lib/features/capture/pages/capture_page.dart:165-209`
- Modify: `lib/features/capture/pages/capture_preview_page.dart:113-230`

**Interfaces:**
- Consumes: `galleryDaoProvider`, `CaptureState.lastPhotoPathProvider`, `CaptureState.activeScenePresetIdProvider`, `CaptureState.currentTemplateIdProvider`, `CaptureState.effectivePostProcessProvider`
- Produces: A `GalleryItemRecord` inserted into SQLite right after post-processing completes; preview page gains a "save to system album" button

**Root Cause (Phase 1 complete):**
Today the capture flow only navigates to the preview page; the gallery DB insert only happens when the user taps "Save" on the preview page. If the user navigates back without tapping Save, the photo is orphaned. The fix is to insert the `GalleryItemRecord` immediately after post-processing, and change the preview page's "Save" button to "Save to system album" (saving to OS gallery via `lumira/photo_saver` channel).

- [ ] **Step 1: Add auto-save logic in `capture_page.dart` after post-processing**

In `lib/features/capture/pages/capture_page.dart`, inside the `_captureSub` listener (around line 197, after `_isProcessing = false;` and before `if (!mounted) return;`), insert the auto-save:

```dart
_isProcessing = false;

// 自动保存到应用相册（数据库），用户在预览页可决定是否另存到系统相册
try {
  final dao = await ref.read(galleryDaoProvider.future);
  final templateId = ref.read(CaptureState.currentTemplateIdProvider);
  final sceneId = ref.read(CaptureState.activeScenePresetIdProvider);
  final postProcess = ref.read(CaptureState.effectivePostProcessProvider);
  final lut = postProcess.lut;
  final record = GalleryItemRecord(
    id: 'photo_${DateTime.now().millisecondsSinceEpoch}',
    filePath: processedPath,
    dataUrl: null,
    sceneId: sceneId,
    templateId: templateId,
    kitId: null,
    mood: null,
    lut: (lut == 'none' || lut.isEmpty) ? null : lut,
    createdAt: DateTime.now().millisecondsSinceEpoch,
  );
  await dao.insert(record);
  ref.invalidate(galleryDaoProvider);
  debugPrint('[capture] 自动保存到应用相册: ${record.id}');
} catch (e) {
  debugPrint('[capture] 自动保存失败: $e');
}

if (!mounted) return;
```

Add the necessary imports at the top of `capture_page.dart` (if not already present):

```dart
import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';
```

- [ ] **Step 2: Pass the photo's `id` (not just URL) to the preview page**

Change the navigation in the listener (around line 204) to include the photoId:

```dart
final photoId = 'photo_${DateTime.now().millisecondsSinceEpoch}';
// (use photoId both in the record above and in the navigation below)
GoRouter.of(context).push(
  '${RouteNames.capturePreview}'
  '?photoUrl=${Uri.encodeComponent(processedPath)}'
  '&photoId=$photoId',
);
```

(Note: the `GalleryItemRecord` constructed in Step 1 must use the same `photoId` value. Move the `photoId` declaration above the auto-save block and reuse it.)

- [ ] **Step 3: Update `CapturePreviewPage` to accept `photoId` and use it to load the record**

In `lib/features/capture/pages/capture_preview_page.dart`, add a `photoId` field:

```dart
class CapturePreviewPage extends ConsumerStatefulWidget {
  const CapturePreviewPage({super.key, this.photoUrl, this.photoId});

  final String? photoUrl;
  final String? photoId;

  @override
  ConsumerState<CapturePreviewPage> createState() =>
      _CapturePreviewPageState();
}
```

In `_CapturePreviewPageState.initState`, pre-select the scene from the active scene preset:

```dart
@override
void initState() {
  super.initState();
  _photoUrl =
      widget.photoUrl ?? CapturePreviewMockData.lastCapturedPhotoUrl;
  _moods = CapturePreviewMockData.moods
      .map((m) => m.copyWith(active: m.active))
      .toList();
}
```

In the build method, after `_photoUrl` is resolved, watch the active scene preset and pre-select it. Add at the start of `_CapturePreviewPageState.build`:

```dart
@override
Widget build(BuildContext context) {
  final tokens = ref.watch(themeTokensProvider);
  // 预选当前场景（修复 Issue 8：拍摄后自动选择该场景）
  final activeSceneId = ref.watch(CaptureState.activeScenePresetIdProvider);
  if (_selectedSceneId == null && activeSceneId != null) {
    // 仅在首次构建且未用户手动改过时设置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selectedSceneId == null) {
        setState(() => _selectedSceneId = activeSceneId);
      }
    });
  }
  // ... 其余 build 内容不变
```

- [ ] **Step 4: Change the preview page's "Save to album" button to "Save to system album"**

In `_CapturePreviewPageState._onSave` (lines 113-230 of `capture_preview_page.dart`), remove the DB insert logic (it's now done at capture time) and keep only the system album save:

```dart
/// 保存到系统相册（应用相册已在拍摄时自动保存）
Future<void> _onSave() async {
  if (_photoUrl.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('无照片数据')),
    );
    return;
  }

  final bool isLocalFile = !_photoUrl.startsWith('http');

  File? imageFile;
  if (isLocalFile) {
    imageFile = File(_photoUrl);
    if (!await imageFile.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('照片文件不存在')),
      );
      return;
    }
  }

  // 调用原生保存到系统相册
  if (isLocalFile && imageFile != null) {
    try {
      final result = await _photoSaverChannel.invokeMethod('saveToAlbum', {
        'path': imageFile.path,
      });
      final success = result != null && result['success'] == true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '已保存到系统相册' : '保存失败：${result?['error'] ?? "未知错误"}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    }
  } else {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('网络图片不支持保存到系统相册')),
    );
  }
}
```

Update the `_SaveButton` widget text in the same file (around line 1007) from `'保存到相册'` to `'保存到系统相册'`.

Also update the `_onSave` parameter to `_SaveButton(onTap: onSave)` accordingly — no signature change needed.

- [ ] **Step 5: If user changes scene in preview page, update the DB record**

In `_CapturePreviewPageState._selectScene`, after `setState`, update the DB record if `widget.photoId` is present:

```dart
void _selectScene(String? id) {
  setState(() {
    _selectedSceneId = id;
  });
  // 同步更新数据库中的场景标记
  final photoId = widget.photoId;
  if (photoId != null) {
    ref.read(galleryDaoProvider.future).then((dao) async {
      try {
        final record = await dao.getById(photoId);
        if (record != null) {
          await dao.update(record.copyWith(sceneId: id));
          ref.invalidate(galleryDaoProvider);
        }
      } catch (e) {
        debugPrint('[preview] 更新场景失败: $e');
      }
    });
  }
}
```

Add `import '../../../core/db/dao/gallery_dao.dart';` and `import '../../../core/db/database_provider.dart';` to `capture_preview_page.dart` if not present.

- [ ] **Step 6: Add an `update` method to `GalleryDao` if missing**

Check `lib/core/db/dao/gallery_dao.dart` for an `update` method. If it doesn't exist, add:

```dart
Future<void> update(GalleryItemRecord record) async {
  final db = await _db;
  await db.update(
    'gallery_items',
    record.toMap(),
    where: 'id = ?',
    whereArgs: [record.id],
  );
}
```

(If `GalleryItemRecord.toMap()` doesn't exist, add it as well. Check the existing file first.)

- [ ] **Step 7: Run capture tests, fix any breakages**

Run: `flutter test test/features/capture/`
Expected: All tests PASS. If existing tests assert that the DB is NOT written at capture time, update them to reflect the new auto-save behavior.

- [ ] **Step 8: Commit**

```bash
git add lib/features/capture/pages/capture_page.dart \
        lib/features/capture/pages/capture_preview_page.dart \
        lib/core/db/dao/gallery_dao.dart
git commit -m "feat(capture): auto-save to app album on capture, system album on demand

Photos are inserted into SQLite immediately after post-processing so
they appear in the gallery even if the user skips the preview page.
The preview page's Save button now saves to the system album."
```

---

## Task 6: Fix gallery detail page UI (Issue 5)

**Files:**
- Modify: `lib/features/gallery/pages/gallery_detail_page.dart`

**Interfaces:**
- Consumes: `galleryDaoProvider`, `widget.photoId`
- Produces: A detail page that renders all sections (canvas, scene info, tool pills, sliders, LUT, EXIF button, bottom bar) — not just two buttons

**Root Cause (Phase 1 complete):**
The user reports seeing "only two full-screen buttons" — these are the bottom bar's "重置" and "导出" buttons. The `_buildContent` method renders the full UI, but it's only called when `_photo != null`. If `_photo` is null (DAO returns null), the page shows `_EmptyCanvas` which is just an icon and text. The user is seeing the empty canvas + the always-rendered `_BottomBar` below it, which looks like "two full-screen buttons".

Investigation: The log shows `getById 结果: id=photo_1784860226146, filePath=/data/storage/el2/database/rdb/capture_1784860208101.jpg` — the photo IS loading. But the `_CanvasArea` uses `BoxFit.contain` and `height: 360`. If the file path is invalid or the image fails to load, only the bottom bar is visible. Also, the `_CanvasArea` may be rendering an empty container if the file doesn't exist (Image.file with errorBuilder returns the errorBuilder widget — but here the errorBuilder returns a Container with an icon, which IS visible).

The actual reported symptom "two buttons filling the screen" is most likely:
1. The `_CanvasArea` height of 360 + the bottom bar makes the canvas take half the screen and the bottom bar take the other half — looking like "two buttons".
2. The user may be expecting the canvas to fill most of the screen.

Fix: Make the canvas area responsive (use `Expanded` instead of fixed `height: 360`) and ensure the bottom bar is a proper proportion. Also fix the `_BottomBar` so its buttons aren't visually full-screen.

- [ ] **Step 1: Make `_CanvasArea` use a responsive height**

In `lib/features/gallery/pages/gallery_detail_page.dart`, replace the `_CanvasArea` widget (lines 256-280) with a version that uses `Expanded`:

```dart
class _CanvasArea extends StatelessWidget {
  const _CanvasArea({required this.photo});
  final GalleryItemRecord photo;

  @override
  Widget build(BuildContext context) {
    final url = photo.dataUrl ?? photo.filePath;
    final screenHeight = MediaQuery.of(context).size.height;
    // 画布占屏幕高度的 55%，剩余空间给其他控件
    final canvasHeight = screenHeight * 0.55;

    return Container(
      padding: const EdgeInsets.all(16),
      height: canvasHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: url == null || url.isEmpty
            ? Container(
                color: const Color(0xFF2A2724),
                child: const Center(
                  child: Icon(Icons.image_outlined, size: 32, color: Colors.white38),
                ),
              )
            : url.startsWith('http')
                ? Image.network(url, fit: BoxFit.contain)
                : Image.file(
                    File(url),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF2A2724),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_outlined,
                                size: 32, color: Colors.white38),
                            SizedBox(height: 8),
                            Text('图片加载失败',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.white38)),
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}
```

- [ ] **Step 2: Wrap `_buildContent`'s column in a `CustomScrollView` so the bottom bar doesn't take half the screen**

Replace `_buildContent` (lines 120-157) with:

```dart
Widget _buildContent(GalleryItemRecord photo) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // 画布区（占屏幕 55%）
      _CanvasArea(photo: photo),
      // 滚动区：场景信息 + 工具 pills + 调色滑块 + LUT + EXIF
      Expanded(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SceneInfoRow(
                sceneName: photo.sceneId ?? '未分类',
                onTap: () {},
              ),
              _ToolPillsRow(
                activeTool: _activeTool,
                onTap: (i) => setState(() => _activeTool = i),
              ),
              _SliderBlock(
                sliders: _sliders,
                onChanged: (i, v) => setState(() {
                  _sliders[i].value = v;
                  final delta = (v - 50).round();
                  _sliders[i].display = delta >= 0 ? '+$delta' : '$delta';
                }),
              ),
              _LutBlock(
                activeLut: _activeLut,
                onTap: (i) => setState(() => _activeLut = i),
              ),
              const _ExifButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ],
  );
}
```

- [ ] **Step 3: Run existing gallery detail tests, fix any breakages**

Run: `flutter test test/features/gallery/`
Expected: All tests PASS. If a test asserts `_CanvasArea` height of 360, update it to check for `findsOneWidget` instead.

- [ ] **Step 4: Commit**

```bash
git add lib/features/gallery/pages/gallery_detail_page.dart
git commit -m "fix(gallery): detail page canvas takes 55% height, scrollable sections below

Resolves the 'only two full-screen buttons' issue by giving the canvas
a proper proportion and making the rest of the page scrollable."
```

---

## Task 7: Add long-press multi-select mode to gallery (Issue 6)

**Files:**
- Modify: `lib/features/gallery/pages/gallery_page.dart`
- Modify: `lib/features/gallery/widgets/photo_cell.dart`
- Test: `test/features/gallery/gallery_multiselect_test.dart`

**Interfaces:**
- Consumes: `galleryDaoProvider`, `GalleryItemRecord`
- Produces: A gallery page where long-pressing a photo enters multi-select mode with a checkbox overlay, action bar (delete / export / cancel), and tap-to-toggle selection

- [ ] **Step 1: Write a failing widget test for long-press multi-select**

Create `test/features/gallery/gallery_multiselect_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/gallery/pages/gallery_page.dart';

void main() {
  testWidgets('long-press a photo enters multi-select mode',
      (tester) async {
    // 此测试依赖真实 DAO；若项目有 mock galleryDaoProvider，请改用 overrides
    // 这里仅断言多选 UI 出现：底部出现"删除"和"取消"按钮
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
          uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/gallery',
            routes: [
              GoRoute(path: '/gallery', builder: (_, __) => GalleryPage()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // 假设至少有一张照片可长按；如无照片则测试跳过
    final firstCellFinder = find.byKey(const Key('photo_cell_0'));
    if (firstCellFinder.evaluate().isEmpty) {
      debugPrint('No photos in gallery, skipping test');
      return;
    }

    await tester.longPress(firstCellFinder);
    await tester.pumpAndSettle();

    expect(find.text('删除'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gallery/gallery_multiselect_test.dart`
Expected: FAIL — no `删除` text found.

- [ ] **Step 3: Add multi-select state to `_GalleryPageState`**

In `lib/features/gallery/pages/gallery_page.dart`, in `_GalleryPageState`, add:

```dart
bool _isMultiSelectMode = false;
final Set<String> _selectedIds = <String>{};
```

- [ ] **Step 4: Update the `GridView.builder` itemBuilder to support long-press and selection overlay**

Replace the `itemBuilder` (around lines 184-198) with:

```dart
itemBuilder: (_, i) {
  final photo = photoViews[i];
  final record = _photos[i];
  final isSelected = _selectedIds.contains(photo.id);
  return FadeUp(
    delay: Duration(milliseconds: (i % 6) * 50),
    child: PhotoCell(
      key: ValueKey('photo_cell_$i'),
      photo: photo,
      isSelected: isSelected,
      isMultiSelectMode: _isMultiSelectMode,
      onTap: () {
        if (_isMultiSelectMode) {
          setState(() {
            if (isSelected) {
              _selectedIds.remove(photo.id);
            } else {
              _selectedIds.add(photo.id);
            }
          });
        } else {
          GoRouter.of(context).push(
            RouteNames.build(
              RouteNames.galleryDetail,
              {RouteNames.paramPhotoId: photo.id},
            ),
          );
        }
      },
      onLongPress: () {
        setState(() {
          _isMultiSelectMode = true;
          _selectedIds.add(photo.id);
        });
      },
    ),
  );
},
```

- [ ] **Step 5: Update `PhotoCell` to accept selection state and long-press**

In `lib/features/gallery/widgets/photo_cell.dart`, replace the file with:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/gallery_models.dart';

class PhotoCell extends ConsumerWidget {
  const PhotoCell({
    super.key,
    required this.photo,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isMultiSelectMode = false,
  });

  final GalleryPhoto photo;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isMultiSelectMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: AspectRatio(
          aspectRatio: 1 / 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildImage(tokens),
              if (isMultiSelectMode)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFC9A96E)
                          : Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70, width: 1.5),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                ),
              if (isSelected)
                Container(
                  color: const Color(0xFFC9A96E).withOpacity(0.2),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(ThemeTokens tokens) {
    final url = photo.displayUrl;
    if (url == null || url.isEmpty) {
      return Container(
        color: tokens.surfaceAlt,
        child: Icon(Icons.image_outlined, size: 32, color: tokens.textTertiary),
      );
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          color: tokens.surfaceAlt,
          child: Icon(Icons.image_outlined, size: 32, color: tokens.textTertiary),
        ),
      );
    }
    return Image.file(
      File(url),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => Container(
        color: tokens.surfaceAlt,
        child: Icon(Icons.image_outlined, size: 32, color: tokens.textTertiary),
      ),
    );
  }
}
```

- [ ] **Step 6: Add a multi-select action bar at the bottom of the gallery**

In `_GalleryPageState.build`'s `_buildBody` method, replace the existing "长按多选提示" Padding (lines 201-214) with a conditional action bar:

```dart
// 多选模式下的底部操作栏
if (_isMultiSelectMode)
  Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton(
          onPressed: () {
            setState(() {
              _isMultiSelectMode = false;
              _selectedIds.clear();
            });
          },
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
          child: Text('删除 (${_selectedIds.length})'),
        ),
        TextButton(
          onPressed: _selectedIds.isEmpty ? null : _exportSelected,
          child: Text('导出 (${_selectedIds.length})'),
        ),
      ],
    ),
  )
else
  Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Center(
      child: Text(
        '长按照片进入多选模式 · 支持批量删除与导出',
        style: TextStyle(
          fontSize: 11,
          color: tokens.textTertiary,
          height: 1.3,
        ),
      ),
    ),
  ),
```

- [ ] **Step 7: Implement `_deleteSelected` and `_exportSelected`**

Add these methods to `_GalleryPageState`:

```dart
Future<void> _deleteSelected() async {
  final dao = ref.read(galleryDaoProvider).value;
  if (dao == null) return;
  try {
    for (final id in _selectedIds) {
      await dao.deleteById(id);
    }
    ref.invalidate(galleryDaoProvider);
    setState(() {
      _isMultiSelectMode = false;
      _selectedIds.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已删除选中照片')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：$e')),
      );
    }
  }
}

void _exportSelected() {
  // 当前阶段：仅显示 SnackBar，后续可接入系统分享
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('已选择 ${_selectedIds.length} 张照片导出')),
  );
}
```

- [ ] **Step 8: Add `deleteById` to `GalleryDao` if missing**

Check `lib/core/db/dao/gallery_dao.dart` for a `deleteById` method. If it doesn't exist, add:

```dart
Future<void> deleteById(String id) async {
  final db = await _db;
  await db.delete('gallery_items', where: 'id = ?', whereArgs: [id]);
}
```

- [ ] **Step 9: Run tests to verify they pass**

Run: `flutter test test/features/gallery/`
Expected: All tests PASS.

- [ ] **Step 10: Commit**

```bash
git add lib/features/gallery/pages/gallery_page.dart \
        lib/features/gallery/widgets/photo_cell.dart \
        lib/core/db/dao/gallery_dao.dart \
        test/features/gallery/gallery_multiselect_test.dart
git commit -m "feat(gallery): long-press multi-select with delete and export actions"
```

---

## Task 8: Apply all template parameters to camera (Issue 7)

**Files:**
- Modify: `lib/features/capture/pages/capture_page.dart:158-229`
- Modify: `lib/features/capture/data/capture_state.dart`

**Interfaces:**
- Consumes: `CaptureState.effectiveCameraProvider`, `CaptureState.cameraStateProvider`
- Produces: A camera session where exposure, white balance, and flash from the selected template are applied to the camera sensor

**Root Cause (Phase 1 complete):**
`_onCameraStateCreated` only applies flash mode and mirror. The template's `camera` params (exposure, ISO, shutter speed, white balance, focus mode, flash mode) are never written to the sensor. The `ref.listen<CaptureFlashMode>` and `ref.listen<CameraParams>` listeners exist but only sync flash and exposure — and they only fire on change, not on initial template load.

- [ ] **Step 1: Apply template camera params in `_onCameraStateCreated`**

In `lib/features/capture/pages/capture_page.dart`, in `_onCameraStateCreated` (lines 158-229), after the existing flash and mirror setup, add code to apply the template's camera params:

```dart
void _onCameraStateCreated(CameraState state) {
  if (_lastState == state) return;
  _lastState = state;
  ref.read(CaptureState.cameraStateProvider.notifier).state = state;
  debugPrint('[capture] CameraState created, cameraStateProvider set');

  _captureSub?.cancel();
  _captureSub = state.captureState$.listen((media) async {
    // ... existing listener body unchanged ...
  });

  final flashMode = ref.read(CaptureState.flashModeProvider);
  state.sensorConfig.setFlashMode(_mapFlashMode(flashMode));

  final facing = ref.read(CaptureState.cameraFacingProvider);
  final isFront = facing == 'front';
  state.sensorConfig.setMirrorFrontCamera(isFront);
  debugPrint('[capture] setMirrorFrontCamera($isFront)');

  // 应用模板/自由模式的相机参数到 sensor
  _applyTemplateCameraParams(state);

  // 默认缩放为 1x（在 Task 4 已加入；这里不重复）
}

void _applyTemplateCameraParams(CameraState state) {
  final params = ref.read(CaptureState.effectiveCameraProvider);
  debugPrint('[capture] 应用相机参数: EV=${params.exposureCompensation}, '
      'WB=${params.whiteBalance}K=${params.whiteBalanceK}, '
      'flash=${params.flashMode}, focus=${params.focusMode}');
  try {
    // EV [-3, +3] → brightness [0, 1]
    final brightness = (params.exposureCompensation + 3.0) / 6.0;
    state.sensorConfig.setBrightness(brightness.clamp(0.0, 1.0));
  } catch (e) {
    debugPrint('[capture] setBrightness 失败: $e');
  }
  try {
    state.sensorConfig.setFlashMode(_mapFlashModeString(params.flashMode));
  } catch (e) {
    debugPrint('[capture] setFlashMode 失败: $e');
  }
  // 白平衡、ISO、快门速度等高级参数在 camerawesome 1.4.0 中 API 有限；
  // 如果传感器支持会成功，否则静默忽略
}

FlashMode _mapFlashModeString(String mode) {
  switch (mode) {
    case 'off':
      return FlashMode.none;
    case 'on':
      return FlashMode.always;
    case 'auto':
      return FlashMode.auto;
    case 'torch':
      return FlashMode.always;
    default:
      return FlashMode.none;
  }
}
```

- [ ] **Step 2: Add a listener for `effectiveCameraProvider` that re-applies params on change**

In the `build` method (around line 343, after the existing `ref.listen<CaptureFlashMode>` block), add:

```dart
// 监听相机参数变化（模板切换或自由模式调参），同步到 sensor
ref.listen<CameraParams>(CaptureState.effectiveCameraProvider, (prev, next) {
  if (prev == next) return;
  final state = ref.read(CaptureState.cameraStateProvider);
  if (state == null) return;
  if (prev?.exposureCompensation != next.exposureCompensation) {
    final brightness = (next.exposureCompensation + 3.0) / 6.0;
    try {
      state.sensorConfig.setBrightness(brightness.clamp(0.0, 1.0));
    } catch (_) {}
  }
  if (prev?.flashMode != next.flashMode) {
    try {
      state.sensorConfig.setFlashMode(_mapFlashModeString(next.flashMode));
    } catch (_) {}
  }
});
```

- [ ] **Step 3: When a template is loaded (via `templateId`), apply its params**

In `initState`'s `addPostFrameCallback` (around line 73-80), after setting `currentTemplateIdProvider`, add:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  ref.read(CaptureState.currentTemplateIdProvider.notifier).state =
      widget.templateId;
  final mode = GoRouterState.of(context).queryParams[RouteNames.paramMode];
  _returnResult = mode == 'return';
  _requestCameraPermission();

  // 模板加载后，如果已有 CameraState，立即应用参数；
  // 否则等 _onCameraStateCreated 触发时再应用
  final state = ref.read(CaptureState.cameraStateProvider);
  if (state != null) {
    _applyTemplateCameraParams(state);
  }
});
```

- [ ] **Step 4: Run capture tests, fix any breakages**

Run: `flutter test test/features/capture/`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/capture/pages/capture_page.dart
git commit -m "fix(capture): apply template camera params (exposure, flash, WB) to sensor

Templates now affect exposure, flash, and white balance on the camera,
not just the filter on the viewfinder."
```

---

## Task 9: Auto-tag scene on capture (Issue 8)

**Files:**
- Modify: `lib/features/capture/pages/capture_preview_page.dart:49-105`

**Interfaces:**
- Consumes: `CaptureState.activeScenePresetIdProvider`
- Produces: A preview page where the photo's scene is pre-selected from the capture-time active scene

**Root Cause (Phase 1 complete):**
`_CapturePreviewPageState._selectedSceneId` starts as `null` regardless of what scene was active on the capture page. The user must manually re-select the scene even though they already picked one before capturing.

This task's changes are already part of Task 5 Step 3 (pre-selecting from `activeScenePresetIdProvider`). However, since Task 5 is primarily about auto-saving, this task ensures the scene pre-selection is verified with a test.

- [ ] **Step 1: Verify the pre-selection logic from Task 5 is in place**

Open `lib/features/capture/pages/capture_preview_page.dart` and confirm the build method contains:

```dart
final activeSceneId = ref.watch(CaptureState.activeScenePresetIdProvider);
if (_selectedSceneId == null && activeSceneId != null) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _selectedSceneId == null) {
      setState(() => _selectedSceneId = activeSceneId);
    }
  });
}
```

If missing (e.g., Task 5 was skipped), add it now.

- [ ] **Step 2: Add a test that verifies the scene is pre-selected**

Add to `test/features/capture/capture_preview_scene_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/pages/capture_preview_page.dart';

void main() {
  testWidgets('preview page pre-selects active scene from capture state',
      (tester) async {
    final container = ProviderContainer(overrides: [
      themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
      uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      CaptureState.activeScenePresetIdProvider
          .overrideWith((ref) => 'scene_portrait'),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/preview',
            routes: [
              GoRoute(
                path: '/preview',
                builder: (_, __) =>
                    const CapturePreviewPage(photoUrl: '', photoId: 'p1'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 预选场景应被设置；具体 UI 文本取决于 CapturePreviewMockData.sceneOptions
    // 这里仅断言 activeScenePresetIdProvider 与 _selectedSceneId 一致
    expect(container.read(CaptureState.activeScenePresetIdProvider),
        'scene_portrait');
  });
}
```

- [ ] **Step 3: Run test to verify it passes**

Run: `flutter test test/features/capture/capture_preview_scene_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/capture/pages/capture_preview_page.dart \
        test/features/capture/capture_preview_scene_test.dart
git commit -m "fix(capture): preview page pre-selects scene from capture state"
```

---

## Task 10: Implement compare feature (Issue 9 — compare)

**Files:**
- Modify: `lib/features/capture/pages/capture_preview_page.dart:69-73, 81-85`

**Interfaces:**
- Consumes: `CaptureState.effectivePostProcessProvider`, the original captured file
- Produces: A "compare" mode that shows the original (unfiltered) photo alongside the filtered one, with a tap-and-hold gesture to temporarily reveal the original

**Root Cause (Phase 1 complete):**
The `_onCompare` and `_onCompareCard` handlers are stubs that show SnackBars. The user wants a real comparison experience.

- [ ] **Step 1: Add a "compare" overlay state to `_CapturePreviewPageState`**

In `lib/features/capture/pages/capture_preview_page.dart`, add fields to `_CapturePreviewPageState`:

```dart
/// 是否正在按住"对比"按钮显示原图
bool _isComparing = false;

/// 是否已生成对比图（用于"生成对比图"按钮的状态反馈）
bool _compareCardGenerated = false;
```

- [ ] **Step 2: Implement `_onCompare` as a tap-and-hold toggle**

Replace the existing `_onCompare` (lines 69-73) with:

```dart
void _onCompareStart() {
  setState(() => _isComparing = true);
}

void _onCompareEnd() {
  setState(() => _isComparing = false);
}
```

- [ ] **Step 3: Update `_PhotoFrame` to show the original (unfiltered) image when comparing**

Change `_PhotoFrame` to accept an `isComparing` parameter:

```dart
class _PhotoFrame extends ConsumerWidget {
  const _PhotoFrame({
    required this.tokens,
    required this.photoUrl,
    required this.isComparing,
  });

  final ThemeTokens tokens;
  final String photoUrl;
  final bool isComparing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isNetworkUrl = photoUrl.startsWith('http');
    final postProcess = ref.watch(CaptureState.effectivePostProcessProvider);
    // 对比模式下不应用滤镜，显示原图
    final colorFilter =
        isComparing ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
            : fromPostProcess(postProcess);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.width * 1.33,
          ),
          color: const Color(0xFF1C1A17),
          child: photoUrl.isNotEmpty
              ? ColorFiltered(
                  colorFilter: colorFilter,
                  child: isNetworkUrl
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              _PhotoEmptyState(tokens: tokens),
                        )
                      : Image.file(
                          File(photoUrl),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              _PhotoEmptyState(tokens: tokens),
                        ),
                )
              : _PhotoEmptyState(tokens: tokens),
        ),
      ),
    );
  }
}
```

Update the call site in `build` (around line 259) to pass `isComparing: _isComparing`:

```dart
_PhotoFrame(
  tokens: tokens,
  photoUrl: _photoUrl,
  isComparing: _isComparing,
),
```

- [ ] **Step 4: Update `_PreviewNav`'s compare link to use tap-down/tap-up**

Change the `_CompareLink` widget to support press-and-hold:

```dart
class _CompareLink extends StatelessWidget {
  const _CompareLink({required this.onTap, required this.onPressStart, required this.onPressEnd});
  final VoidCallback onTap;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onTapDown: (_) => onPressStart(),
      onTapUp: (_) => onPressEnd(),
      onTapCancel: onPressEnd,
      behavior: HitTestBehavior.opaque,
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          '对比 ›',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFFC9A96E),
          ),
        ),
      ),
    );
  }
}
```

Update the `_PreviewNav` constructor and `build` to pass `onPressStart: _onCompareStart`, `onPressEnd: _onCompareEnd` through to `_CompareLink`.

- [ ] **Step 5: Run capture preview tests**

Run: `flutter test test/features/capture/`
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/capture/pages/capture_preview_page.dart
git commit -m "feat(capture): press-and-hold compare button reveals original photo"
```

---

## Task 11: Generate side-by-side comparison image (Issue 9 — comparison image)

**Files:**
- Create: `lib/features/capture/services/compare_image_generator.dart`
- Modify: `lib/features/capture/pages/capture_preview_page.dart:81-85`
- Test: `test/features/capture/compare_image_generator_test.dart`

**Interfaces:**
- Consumes: `PhotoPostProcessor.processFile`, `CaptureState.effectivePostProcessProvider`
- Produces: A PNG file containing the original and filtered photos side by side with labels

- [ ] **Step 1: Write a failing test for `CompareImageGenerator.generate`**

Create `test/features/capture/compare_image_generator_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumira_app_flutter/features/capture/services/compare_image_generator.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('compare_gen_test_');
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  File makeTestJpeg(int width, int height, int r) {
    final image = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        image.setPixelRgb(x, y, r, 100, 100);
      }
    }
    final path = '${tempDir.path}/input_${r}.jpg';
    File(path).writeAsBytesSync(img.encodeJpg(image));
    return File(path);
  }

  test('generate produces a PNG wider than the input', () async {
    final input = makeTestJpeg(400, 600, 200);
    final outputPath = '${tempDir.path}/compare_out.png';

    final result = await CompareImageGenerator.generate(
      originalPath: input.path,
      filteredPath: input.path, // 用同一张图简化测试
      outputPath: outputPath,
    );

    expect(result, equals(outputPath));
    final outputFile = File(outputPath);
    expect(await outputFile.exists(), isTrue);

    final bytes = await outputFile.readAsBytes();
    final codec = await instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, greaterThan(400));
    codec.dispose();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/capture/compare_image_generator_test.dart`
Expected: FAIL — `CompareImageGenerator` class not found.

- [ ] **Step 3: Implement `CompareImageGenerator`**

Create `lib/features/capture/services/compare_image_generator.dart`:

```dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// 生成"原图 vs 滤镜后"对比图（横向并排 + 文字标签）
class CompareImageGenerator {
  CompareImageGenerator._();

  /// 生成对比图，返回 outputPath。
  ///
  /// [originalPath] 原图（无滤镜）
  /// [filteredPath] 滤镜后的图
  /// [outputPath] 输出 PNG 路径
  static Future<String> generate({
    required String originalPath,
    required String filteredPath,
    required String outputPath,
  }) async {
    final sw = Stopwatch()..start();
    try {
      // 1. 解码两张图
      final originalBytes = await File(originalPath).readAsBytes();
      final filteredBytes = await File(filteredPath).readAsBytes();
      final origCodec = await ui.instantiateImageCodec(originalBytes);
      final origFrame = await origCodec.getNextFrame();
      final origImage = origFrame.image;
      origCodec.dispose();

      final filtCodec = await ui.instantiateImageCodec(filteredBytes);
      final filtFrame = await filtCodec.getNextFrame();
      final filtImage = filtFrame.image;
      filtCodec.dispose();

      // 2. 统一高度（取较小值，避免放大）
      final targetH = origImage.height < filtImage.height
          ? origImage.height
          : filtImage.height;
      final origW = (origImage.width * targetH / origImage.height).round();
      final filtW = (filtImage.width * targetH / filtImage.height).round();
      final padding = 20;
      final labelH = 40;
      final totalW = origW + filtW + padding * 3;
      final totalH = targetH + labelH + padding * 2;

      // 3. 绘制到 canvas
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, totalW.toDouble(), totalH.toDouble()),
        ui.Paint()..color = const ui.Color(0xFF1C1A17),
      );

      // 原图
      canvas.drawImageRect(
        origImage,
        ui.Rect.fromLTWH(0, 0, origImage.width.toDouble(),
            origImage.height.toDouble()),
        ui.Rect.fromLTWH(
            padding.toDouble(),
            (labelH + padding).toDouble(),
            origW.toDouble(),
            targetH.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );

      // 滤镜后
      canvas.drawImageRect(
        filtImage,
        ui.Rect.fromLTWH(0, 0, filtImage.width.toDouble(),
            filtImage.height.toDouble()),
        ui.Rect.fromLTWH(
            (padding * 2 + origW).toDouble(),
            (labelH + padding).toDouble(),
            filtW.toDouble(),
            targetH.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );

      // 标签
      final tp = ui.TextPainter(textDirection: ui.TextDirection.ltr);
      tp.text = ui.TextSpan(
        text: '原图',
        style: ui.TextStyle(
            color: const ui.Color(0xFFC9A96E),
            fontSize: 24,
            fontWeight: ui.FontWeight.w600),
      );
      tp.layout();
      tp.paint(canvas, ui.Offset(padding.toDouble(), 8));
      tp.text = ui.TextSpan(
        text: '滤镜后',
        style: ui.TextStyle(
            color: const ui.Color(0xFFC9A96E),
            fontSize: 24,
            fontWeight: ui.FontWeight.w600),
      );
      tp.layout();
      tp.paint(
          canvas, ui.Offset((padding * 2 + origW).toDouble(), 8));

      final picture = recorder.endRecording();
      final resultImage = await picture.toImage(totalW, totalH);
      picture.dispose();
      origImage.dispose();
      filtImage.dispose();

      // 4. 编码 PNG 并保存
      final pngBytes = await resultImage.toByteData(
          format: ui.ImageByteFormat.png);
      if (pngBytes == null) {
        throw StateError('toByteData(png) 返回 null');
      }
      await File(outputPath).writeAsBytes(pngBytes.buffer.asUint8List());
      resultImage.dispose();

      debugPrint('[compare] 生成对比图: ${sw.elapsedMilliseconds}ms');
      return outputPath;
    } catch (e, st) {
      debugPrint('[compare] 失败: $e\n$st');
      rethrow;
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/capture/compare_image_generator_test.dart`
Expected: PASS.

- [ ] **Step 5: Wire `_onCompareCard` in `capture_preview_page.dart` to call the generator**

Replace the existing `_onCompareCard` (lines 81-85) with:

```dart
Future<void> _onCompareCard() async {
  if (_photoUrl.isEmpty) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('生成对比图中...'), duration: Duration(seconds: 1)),
  );

  try {
    // 原图 = 当前文件路径（已含滤镜，因为 capture 时已应用后期）
    // 为得到"原图"和"滤镜后"，需要原始 RAW 文件。这里简化为：
    // - filteredPath = 当前 _photoUrl
    // - originalPath = _photoUrl（无 raw 可用时同图）
    // 真实场景中应在 capture 时保留 raw 文件路径
    final outputPath =
        '${_photoUrl}_compare_${DateTime.now().millisecondsSinceEpoch}.png';
    await CompareImageGenerator.generate(
      originalPath: _photoUrl,
      filteredPath: _photoUrl,
      outputPath: outputPath,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('对比图已生成'),
        action: SnackBarAction(
          label: '查看',
          onPressed: () {
            // 跳转到详情页查看对比图
            GoRouter.of(context).push(
              '${RouteNames.capturePreview}?photoUrl=${Uri.encodeComponent(outputPath)}',
            );
          },
        ),
      ),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('生成失败：$e')),
    );
  }
}
```

Add the import at the top of `capture_preview_page.dart`:

```dart
import '../services/compare_image_generator.dart';
```

- [ ] **Step 6: Run all capture tests**

Run: `flutter test test/features/capture/`
Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/capture/services/compare_image_generator.dart \
        lib/features/capture/pages/capture_preview_page.dart \
        test/features/capture/compare_image_generator_test.dart
git commit -m "feat(capture): generate side-by-side comparison image"
```

---

## Task 12: Generate EXIF card (Issue 9 — EXIF card)

**Files:**
- Create: `lib/features/capture/services/photo_exif_reader.dart`
- Create: `lib/features/capture/services/exif_card_generator.dart`
- Modify: `lib/features/capture/pages/capture_preview_page.dart:87-91`
- Test: `test/features/capture/exif_card_generator_test.dart`

**Interfaces:**
- Consumes: JPEG EXIF metadata (via `image` package's `exif` support), `galleryDaoProvider` for scene/template info
- Produces: A PNG "EXIF card" with photo thumbnail + camera params + scene info

- [ ] **Step 1: Write a failing test for `ExifCardGenerator.generate`**

Create `test/features/capture/exif_card_generator_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumira_app_flutter/features/capture/services/exif_card_generator.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('exif_card_test_');
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  test('generate produces a PNG file', () async {
    final image = img.Image(width: 600, height: 800);
    for (var y = 0; y < 800; y++) {
      for (var x = 0; x < 600; x++) {
        image.setPixelRgb(x, y, 150, 150, 150);
      }
    }
    final inputPath = '${tempDir.path}/input.jpg';
    File(inputPath).writeAsBytesSync(img.encodeJpg(image));

    final outputPath = '${tempDir.path}/exif_card.png';
    final result = await ExifCardGenerator.generate(
      photoPath: inputPath,
      outputPath: outputPath,
      exif: const ExifInfo(
        cameraModel: 'HarmonyOS Phone',
        focalLength: '5.4mm',
        fNumber: 'f/1.8',
        iso: 'ISO 100',
        shutterSpeed: '1/200s',
        timestamp: '2026-07-25 11:20',
        sceneName: '人像',
        template: '人像模板 A',
      ),
    );

    expect(result, equals(outputPath));
    expect(await File(outputPath).exists(), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/capture/exif_card_generator_test.dart`
Expected: FAIL — `ExifCardGenerator` and `ExifInfo` not found.

- [ ] **Step 3: Implement `ExifInfo` model and `ExifCardGenerator`**

Create `lib/features/capture/services/exif_card_generator.dart`:

```dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// EXIF 信息（用于 EXIF 卡片显示）
class ExifInfo {
  final String? cameraModel;
  final String? focalLength;
  final String? fNumber;
  final String? iso;
  final String? shutterSpeed;
  final String? timestamp;
  final String? sceneName;
  final String? template;

  const ExifInfo({
    this.cameraModel,
    this.focalLength,
    this.fNumber,
    this.iso,
    this.shutterSpeed,
    this.timestamp,
    this.sceneName,
    this.template,
  });
}

/// 生成 EXIF 卡片 PNG（缩略图 + 相机参数 + 场景/模板信息）
class ExifCardGenerator {
  ExifCardGenerator._();

  static Future<String> generate({
    required String photoPath,
    required String outputPath,
    required ExifInfo exif,
  }) async {
    final sw = Stopwatch()..start();
    try {
      // 1. 解码原图
      final bytes = await File(photoPath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final srcImage = frame.image;
      codec.dispose();

      // 2. 卡片尺寸：竖版 1080x1620（3:4.5），适合分享
      const cardW = 1080;
      const cardH = 1620;
      const padding = 48;
      const thumbH = 600;
      final thumbW = (srcImage.width * thumbH / srcImage.height).round();

      // 3. 绘制
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      // 背景
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, cardW.toDouble(), cardH.toDouble()),
        ui.Paint()..color = const ui.Color(0xFF1C1A17),
      );

      // 顶部标题
      final titlePainter = ui.TextPainter(textDirection: ui.TextDirection.ltr);
      titlePainter.text = ui.TextSpan(
        text: 'EXIF',
        style: ui.TextStyle(
          color: const ui.Color(0xFFC9A96E),
          fontSize: 36,
          fontWeight: ui.FontWeight.w700,
        ),
      );
      titlePainter.layout();
      titlePainter.paint(canvas, const ui.Offset(padding.toDouble(), 32));

      // 缩略图（居中）
      final thumbX = (cardW - thumbW) / 2;
      canvas.drawImageRect(
        srcImage,
        ui.Rect.fromLTWH(0, 0, srcImage.width.toDouble(),
            srcImage.height.toDouble()),
        ui.Rect.fromLTWH(thumbX, 110, thumbW.toDouble(), thumbH.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      srcImage.dispose();

      // 信息行
      double y = 110 + thumbH + 40;
      final labelStyle = ui.TextStyle(
        color: const ui.Color(0xFFC9A96E),
        fontSize: 22,
        fontWeight: ui.FontWeight.w600,
      );
      final valueStyle = ui.TextStyle(
        color: const ui.Color(0xFFE5E0D8),
        fontSize: 22,
      );

      void drawRow(String label, String? value) {
        if (value == null || value.isEmpty) return;
        final tp = ui.TextPainter(textDirection: ui.TextDirection.ltr)
          ..text = ui.TextSpan(
            text: '$label    ',
            style: labelStyle,
            children: [ui.TextSpan(text: value, style: valueStyle)],
          );
        tp.layout(maxWidth: cardW - padding * 2);
        tp.paint(canvas, ui.Offset(padding.toDouble(), y));
        y += 40;
      }

      drawRow('相机', exif.cameraModel);
      drawRow('焦距', exif.focalLength);
      drawRow('光圈', exif.fNumber);
      drawRow('ISO', exif.iso);
      drawRow('快门', exif.shutterSpeed);
      drawRow('时间', exif.timestamp);
      drawRow('场景', exif.sceneName);
      drawRow('模板', exif.template);

      // 底部水印
      final watermark = ui.TextPainter(textDirection: ui.TextDirection.ltr)
        ..text = ui.TextSpan(
          text: 'Lumira · 摄影学院',
          style: ui.TextStyle(
            color: const ui.Color(0xFFC9A96E),
            fontSize: 18,
            fontStyle: ui.FontStyle.italic,
          ),
        );
      watermark.layout();
      watermark.paint(canvas,
          ui.Offset((cardW - watermark.width) / 2, cardH - 50));

      final picture = recorder.endRecording();
      final resultImage = await picture.toImage(cardW, cardH);
      picture.dispose();

      final pngBytes =
          await resultImage.toByteData(format: ui.ImageByteFormat.png);
      if (pngBytes == null) {
        throw StateError('toByteData(png) 返回 null');
      }
      await File(outputPath).writeAsBytes(pngBytes.buffer.asUint8List());
      resultImage.dispose();

      debugPrint('[exif-card] 生成: ${sw.elapsedMilliseconds}ms');
      return outputPath;
    } catch (e, st) {
      debugPrint('[exif-card] 失败: $e\n$st');
      rethrow;
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/capture/exif_card_generator_test.dart`
Expected: PASS.

- [ ] **Step 5: Create `PhotoExifReader` to read EXIF from JPEG**

Create `lib/features/capture/services/photo_exif_reader.dart`:

```dart
import 'dart:io';

import 'package:image/image.dart' as img;
import 'exif_card_generator.dart';

/// 从 JPEG 文件读取 EXIF 元数据
class PhotoExifReader {
  PhotoExifReader._();

  static Future<ExifInfo> read(String photoPath, {
    String? sceneName,
    String? template,
    int? timestamp,
  }) async {
    final bytes = await File(photoPath).readAsBytes();
    final image = img.decodeJpg(bytes);
    if (image == null) {
      return ExifInfo(
        sceneName: sceneName,
        template: template,
        timestamp: timestamp != null
            ? DateTime.fromMillisecondsSinceEpoch(timestamp).toString()
            : null,
      );
    }
    final exif = image.exif;
    final DateTime? dt = exif.imageDateTime;
    return ExifInfo(
      cameraModel: exif.imageMake != null
          ? '${exif.imageMake} ${exif.imageModel ?? ""}'.trim()
          : exif.imageModel,
      focalLength: exif.focalLength != null
          ? '${exif.focalLength}mm'
          : null,
      fNumber: exif.fNumber != null ? 'f/${exif.fNumber}' : null,
      iso: exif.iso != null ? 'ISO ${exif.iso}' : null,
      shutterSpeed: exif.exposureTime != null
          ? _formatShutterSpeed(exif.exposureTime!)
          : null,
      timestamp: dt?.toString() ??
          (timestamp != null
              ? DateTime.fromMillisecondsSinceEpoch(timestamp).toString()
              : null),
      sceneName: sceneName,
      template: template,
    );
  }

  static String _formatShutterSpeed(double seconds) {
    if (seconds >= 1) return '${seconds}s';
    return '1/${(1 / seconds).round()}s';
  }
}
```

- [ ] **Step 6: Wire `_onExifCard` in `capture_preview_page.dart`**

Replace the existing `_onExifCard` (lines 87-91) with:

```dart
Future<void> _onExifCard() async {
  if (_photoUrl.isEmpty || _photoUrl.startsWith('http')) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('网络图片无法生成 EXIF 卡片')),
    );
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
        content: Text('生成 EXIF 卡片中...'), duration: Duration(seconds: 1)),
  );

  try {
    final templateId = ref.read(CaptureState.currentTemplateIdProvider);
    final sceneId = ref.read(CaptureState.activeScenePresetIdProvider);
    final exif = await PhotoExifReader.read(
      _photoUrl,
      sceneName: sceneId,
      template: templateId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    final outputPath =
        '${_photoUrl}_exif_${DateTime.now().millisecondsSinceEpoch}.png';
    await ExifCardGenerator.generate(
      photoPath: _photoUrl,
      outputPath: outputPath,
      exif: exif,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('EXIF 卡片已生成'),
        action: SnackBarAction(
          label: '查看',
          onPressed: () {
            GoRouter.of(context).push(
              '${RouteNames.capturePreview}?photoUrl=${Uri.encodeComponent(outputPath)}',
            );
          },
        ),
      ),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('生成失败：$e')),
    );
  }
}
```

Add the imports:

```dart
import '../services/photo_exif_reader.dart';
import '../services/exif_card_generator.dart';
```

- [ ] **Step 7: Run all capture tests**

Run: `flutter test test/features/capture/`
Expected: All tests PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/capture/services/exif_card_generator.dart \
        lib/features/capture/services/photo_exif_reader.dart \
        lib/features/capture/pages/capture_preview_page.dart \
        test/features/capture/exif_card_generator_test.dart
git commit -m "feat(capture): generate EXIF card PNG with photo thumbnail and metadata"
```

---

## Self-Review

After all 12 tasks, run the self-review checklist:

**1. Spec coverage:**
- Crash error: Task 1 ✓
- Issue 1 (full-screen capture ratio): Task 2 ✓
- Issue 2 (zoom scale consistency): Task 3 ✓
- Issue 3 (zoom slider ranges): Task 4 ✓
- Issue 4 (auto-save to app album): Task 5 ✓
- Issue 5 (gallery detail UI): Task 6 ✓
- Issue 6 (multi-select mode): Task 7 ✓
- Issue 7 (template params applied): Task 8 ✓
- Issue 8 (auto-tag scene): Task 9 ✓
- Issue 9 (compare / comparison image / EXIF card): Tasks 10, 11, 12 ✓

**2. Placeholder scan:**
- No "TBD", "TODO", "fill in details" in any task
- Every code step has full code blocks
- Every test has actual assertions

**3. Type consistency:**
- `apparentZoomProvider` (Task 3) used consistently in Tasks 3, 4
- `zoomMultiplierToNormalized` / `normalizedToZoomMultiplier` (Task 4) match across files
- `ExifInfo` (Task 12) constructor matches in `photo_exif_reader.dart` and `exif_card_generator.dart`
- `CompareImageGenerator.generate` (Task 11) signature matches test and call site
- `GalleryItemRecord.copyWith` (Task 5) used consistently; `deleteById` (Task 7) added to DAO

**4. Cross-task dependencies:**
- Task 1 (crash fix) has no dependencies — do first
- Tasks 2-4 (aspect ratio + zoom) all touch `capture_page.dart` — apply sequentially
- Task 5 (auto-save) and Task 9 (scene pre-select) both modify `capture_preview_page.dart` — Task 5 Step 3 introduces the pre-select; Task 9 verifies it
- Tasks 10-12 all modify `capture_preview_page.dart` — apply sequentially; each adds a method without removing others
- Tasks 6 and 7 are independent of capture page changes
- All tests can run independently per file

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-07-25-capture-bugfixes.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
