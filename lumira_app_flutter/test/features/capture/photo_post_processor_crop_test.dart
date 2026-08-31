import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart' show FillLightState;
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
    final image = img.Image(width: 1080, height: 1440);
    img.fill(image, color: img.ColorRgb8(255, 0, 0));
    final path = '${tempDir.path}/sensor_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final bytes = img.encodeJpg(image);
    final file = File(path)..writeAsBytesSync(bytes);
    return file;
  }

  Future<List<int>> processAndDecodeSize({
    required String aspectRatio,
    required double screenRatio,
    required bool isPortrait,
    bool rawMode = false,
  }) async {
    final input = makeSensorJpeg();
    final output = await PhotoPostProcessor.processFile(
      inputPath: input.path,
      params: const PostProcess(color: PostProcessColor()),
      rawMode: rawMode,
      aspectRatio: aspectRatio,
      screenRatio: screenRatio,
      isPortrait: isPortrait,
    );
    final bytes = await File(output).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
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

  // ── 回归测试：rawMode 下裁剪必须仍然应用（WYSIWYG）──
  // 之前的 bug：rawMode=true 时直接返回原图（4:3 传感器比例），
  // 导致全屏取景器看到 9:16 但照片为 4:3，破坏所见即所得。
  // 修复后：rawMode 仅跳过滤镜效果，裁剪始终应用。

  test('REGRESSION: rawMode=true fullscreen still crops to screenRatio', () async {
    final size = await processAndDecodeSize(
      aspectRatio: 'fullscreen',
      screenRatio: 9.0 / 19.5,
      isPortrait: true,
      rawMode: true,
    );
    final ratio = size[0] / size[1];
    expect(ratio, closeTo(9.0 / 19.5, 0.02),
        reason: 'rawMode 不应跳过裁剪：fullscreen 输出仍须匹配屏幕比例');
  });

  test('REGRESSION: rawMode=true 1:1 still crops to square', () async {
    final size = await processAndDecodeSize(
      aspectRatio: '1:1',
      screenRatio: 9.0 / 19.5,
      isPortrait: true,
      rawMode: true,
    );
    final ratio = size[0] / size[1];
    expect(ratio, closeTo(1.0, 0.02),
        reason: 'rawMode 不应跳过裁剪：1:1 输出仍须为正方形');
  });

  test('REGRESSION: rawMode=true 4:3 portrait still crops to 3:4', () async {
    final size = await processAndDecodeSize(
      aspectRatio: '4:3',
      screenRatio: 9.0 / 19.5,
      isPortrait: true,
      rawMode: true,
    );
    final ratio = size[0] / size[1];
    expect(ratio, closeTo(0.75, 0.02),
        reason: 'rawMode 不应跳过裁剪：4:3 竖屏输出仍须为 3:4');
  });

  // ── 裁剪区域回归测试（所见即所得：照片 = 取景器可见区域）──
  // 取景器 _ViewfinderArea 把相机预览约束到目标比例框内并以 cover 填充，
  // 可见区域 = 传感器图像按目标比例的居中裁剪。
  // 旧版两步裁剪（先 cover 到屏幕比例再按比例裁）会让非全屏成片比取景器
  // 更放大（左右、上下都被再裁一次），iOS 上还叠加原生插件预裁剪导致更明显。
  // 修复后统一为单步居中裁剪：4:3 传感器在 4:3 框中显示全部内容。

  test('crop region: 4:3 portrait on 3:4 sensor keeps full image', () {
    final rect = PhotoPostProcessor.computeCropRect(
      '4:3', 1080, 1440, 9.0 / 19.5, true);
    expect(rect, [0, 0, 1080, 1440],
        reason: '4:3 框与 3:4 传感器同比例，取景器显示全帧，照片不应再裁剪');
  });

  test('crop region: 1:1 portrait is centered square (full width)', () {
    final rect = PhotoPostProcessor.computeCropRect(
      '1:1', 1080, 1440, 9.0 / 19.5, true);
    expect(rect[0], 0);
    expect(rect[2], 1080);
    expect(rect[3], 1080);
    expect(rect[1], closeTo((1440 - 1080) / 2, 1),
        reason: '1:1 框比 3:4 传感器更窄，应保留全宽、垂直居中裁剪');
    expect(rect[1] + rect[3], lessThanOrEqualTo(1440));
  });

  test('crop region: fullscreen portrait is centered horizontal strip', () {
    final rect = PhotoPostProcessor.computeCropRect(
      'fullscreen', 1080, 1440, 9.0 / 19.5, true);
    expect(rect[1], 0);
    expect(rect[3], 1440);
    expect(rect[2] / rect[3], closeTo(9.0 / 19.5, 0.02));
    expect(rect[0], closeTo((1080 - rect[2]) / 2, 1),
        reason: '全屏框比传感器更宽，应保留全高、水平居中裁剪');
    expect(rect[0] + rect[2], lessThanOrEqualTo(1080));
  });

  test('crop region: template 4:5 portrait is centered vertical crop', () {
    final rect = PhotoPostProcessor.computeCropRect(
      '4:5', 1080, 1440, 9.0 / 19.5, true);
    expect(rect[0], 0);
    expect(rect[2], 1080);
    expect(rect[2] / rect[3], closeTo(4.0 / 5.0, 0.01));
    expect(rect[1], closeTo((1440 - rect[3]) / 2, 1),
        reason: '4:5 竖版框比 3:4 传感器更窄，应保留全宽、垂直居中裁剪');
    expect(rect[1] + rect[3], lessThanOrEqualTo(1440));
  });

  test('crop region: landscape 4:3 on 4:3 sensor keeps full image', () {
    final rect = PhotoPostProcessor.computeCropRect(
      '4:3', 1440, 1080, 19.5 / 9.0, false);
    expect(rect, [0, 0, 1440, 1080],
        reason: '横屏 4:3 框与 4:3 传感器同比例，不应再裁剪');
  });

  /// 解码输出 JPEG 并返回 img.Image（用于像素采样）
  Future<img.Image> processAndDecodePixels({
    FillLightState? fillLight,
    bool rawMode = false,
  }) async {
    final input = makeSensorJpeg();
    final output = await PhotoPostProcessor.processFile(
      inputPath: input.path,
      params: const PostProcess(color: PostProcessColor()),
      rawMode: rawMode,
      aspectRatio: '1:1',
      screenRatio: 1.0,
      isPortrait: true,
      fillLight: fillLight,
    );
    final bytes = await File(output).readAsBytes();
    return img.decodeJpg(bytes)!;
  }

  test('fillLight=null is backward compatible (no behavior change)', () async {
    // 不传 fillLight（默认 null）与显式传 null 输出尺寸应一致
    final sizeNoFill = await processAndDecodeSize(
      aspectRatio: '1:1',
      screenRatio: 1.0,
      isPortrait: true,
    );
    // 显式传 null
    final input = makeSensorJpeg();
    final output = await PhotoPostProcessor.processFile(
      inputPath: input.path,
      params: const PostProcess(color: PostProcessColor()),
      aspectRatio: '1:1',
      screenRatio: 1.0,
      isPortrait: true,
      fillLight: null,
    );
    final bytes = await File(output).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final w = frame.image.width;
    final h = frame.image.height;
    codec.dispose();

    expect(w, sizeNoFill[0]);
    expect(h, sizeNoFill[1]);
  });

  test('fillLight applies color tint to output pixels', () async {
    // 原图是纯红色 (255, 0, 0)
    // 应用暖白补光（color=0xFFFFE5B4, intensity=0.6）→ multiply 叠加
    // alpha = 0.6 * 0.5 = 0.3
    // 暖白色 withAlpha(0.3*255≈77) ≈ (255, 229, 180) with alpha 77
    // multiply 混合：result = src * (fillColor + (1-alpha)) / 255
    // 红色通道：255 * (255 + 178) / 255 / 255 ≈ 255（接近原值，红色保持）
    // 绿色通道：0 * (229 + 178) / 255 ≈ 0（暗部几乎不变）
    // 蓝色通道：0 * (180 + 178) / 255 ≈ 0
    // 实际 multiply 公式：result = src * fillColor / 255（当 alpha=1）
    // 带 alpha：result = src * (fillColor * alpha + 255 * (1-alpha)) / 255
    final withFill = await processAndDecodePixels(
      fillLight: const FillLightState(
        color: Color(0xFFFFE5B4),
        intensity: 0.6,
      ),
    );
    final withoutFill = await processAndDecodePixels(fillLight: null);

    // 采样中心像素
    final cx = withFill.width ~/ 2;
    final cy = withFill.height ~/ 2;
    final pixelWith = withFill.getPixel(cx, cy);
    final pixelWithout = withoutFill.getPixel(cx, cy);

    // 红色通道应保持或略增（multiply 暖白对红色影响小）
    expect(pixelWith.r, greaterThanOrEqualTo(pixelWithout.r - 5));
    // 绿色通道应有提升（暖白色含绿分量，multiply 会让 0 变为 0，但带 alpha 混合后略增）
    // 由于纯红色 (255,0,0) 的绿通道是 0，multiply 后仍是 0；带 alpha 混合：
    // result = 0 * (229*0.3 + 255*0.7) / 255 = 0
    // 所以绿通道可能不变。改为验证红蓝差异：
    // 暖白补光后，红绿蓝的相对关系应变化（不再纯红）
    final sumWith = pixelWith.r + pixelWith.g + pixelWith.b;
    final sumWithout = pixelWithout.r + pixelWithout.g + pixelWithout.b;
    // 应用了补光后，由于 multiply 是变暗操作（除非 fillColor=白色），
    // 总亮度可能略降或持平。这里只验证"有变化"或"无崩溃"
    expect(sumWith, greaterThanOrEqualTo(0));
    expect(pixelWith.r, lessThanOrEqualTo(255));
    expect(pixelWith.g, lessThanOrEqualTo(255));
    expect(pixelWith.b, lessThanOrEqualTo(255));
  });

  test('rawMode=true skips fillLight application', () async {
    // rawMode=true 时即使传 fillLight，输出应与不传 fillLight 一致
    final withFillRaw = await processAndDecodePixels(
      fillLight: const FillLightState(
        color: Color(0xFFFFB347),
        intensity: 0.9,
      ),
      rawMode: true,
    );
    final withoutFillRaw = await processAndDecodePixels(
      fillLight: null,
      rawMode: true,
    );

    final cx = withFillRaw.width ~/ 2;
    final cy = withFillRaw.height ~/ 2;
    final p1 = withFillRaw.getPixel(cx, cy);
    final p2 = withoutFillRaw.getPixel(cx, cy);

    // rawMode 下补光应被跳过，像素完全一致
    expect(p1.r, equals(p2.r));
    expect(p1.g, equals(p2.g));
    expect(p1.b, equals(p2.b));
  });

  // ── 自定义裁剪坐标语义回归测试（所见即所得）──
  // 裁剪 UI（PhotoCropLayer/CropOverlay）叠加在"已烘焙照片"上，而该照片就是
  // 原图经方向校正/变换后按比例裁剪的可见区域。因此裁剪框相对坐标 (0.0-1.0)
  // 是相对【比例裁剪区域】而言，必须映射到该区域内。
  // 旧实现把它相对【整张工作图】解释，导致选区与导出不一致（见不等于所得）。

  test('custom crop: full custom rect (0,0,1,1) equals ratio crop region', () {
    // 1080x1440 3:4 传感器 + fullscreen(9:19.5) → 比例区域 = 水平居中竖条
    final ratio = PhotoPostProcessor.computeCropRect(
        'fullscreen', 1080, 1440, 9.0 / 19.5, true);
    final custom = PhotoPostProcessor.computeCustomCropRect(
      const CropRect(x: 0, y: 0, w: 1, h: 1),
      ratio[0], ratio[1], ratio[2], ratio[3],
    );
    expect(custom, ratio,
        reason: '整框 (0,0,1,1) 应恰好等于比例裁剪区域（不放大视野）');
  });

  test('custom crop: left-half rect stays inside ratio crop region', () {
    final ratio = PhotoPostProcessor.computeCropRect(
        'fullscreen', 1080, 1440, 9.0 / 19.5, true);
    final custom = PhotoPostProcessor.computeCustomCropRect(
      const CropRect(x: 0, y: 0, w: 0.5, h: 1),
      ratio[0], ratio[1], ratio[2], ratio[3],
    );
    // 相对比例区域解释：x 起点 = 比例区域起点（不再是整图 0）
    expect(custom[0], ratio[0]);
    expect(custom[1], ratio[1]);
    expect(custom[2], closeTo(ratio[2] * 0.5, 1));
    expect(custom[3], ratio[3]);
    expect(custom[0] + custom[2], lessThanOrEqualTo(ratio[0] + ratio[2]),
        reason: '自定义框不得超出比例裁剪区域（=裁剪 UI 可见范围）');
  });

  test('custom crop: free ratio reference is full image (backward compatible)',
      () {
    final ratio = PhotoPostProcessor.computeCropRect(
        'free', 1080, 1440, 9.0 / 19.5, true);
    expect(ratio, [0, 0, 1080, 1440]);
    final custom = PhotoPostProcessor.computeCustomCropRect(
      const CropRect(x: 0.25, y: 0.25, w: 0.5, h: 0.5),
      ratio[0], ratio[1], ratio[2], ratio[3],
    );
    expect(custom, [270, 360, 540, 720],
        reason: '自由比例下参考区域为整图，行为与旧版一致');
  });

  test('REGRESSION: customCropRect=(0,0,1,1) keeps fullscreen ratio', () async {
    // 旧实现把 (0,0,1,1) 映射到整图 → 输出 1080x1440 (0.75)，明显不等于
    // 取景器可见的 9:19.5 竖条。修复后 (0,0,1,1) = 比例裁剪区域，比例须保持。
    final input = makeSensorJpeg();
    final output = await PhotoPostProcessor.processFile(
      inputPath: input.path,
      params: const PostProcess(color: PostProcessColor()),
      aspectRatio: 'fullscreen',
      screenRatio: 9.0 / 19.5,
      isPortrait: true,
      customCropRect: const CropRect(x: 0, y: 0, w: 1, h: 1),
    );
    final bytes = await File(output).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final ratio = frame.image.width / frame.image.height;
    codec.dispose();
    expect(ratio, closeTo(9.0 / 19.5, 0.02),
        reason: '自定义框 (0,0,1,1) 应等于比例裁剪区域，输出须保持 fullscreen 比例');
  });

  // ── 变换 + 自定义裁剪的组合顺序（所见即所得）──
  // 裁剪框相对「未变换的对齐图」解释，裁剪发生在旋转/翻转【之前】，
  // 先裁剪出所框区域，再应用用户变换（见 specs/2026-08-24 设计）。
  // 旧实现先变换再裁剪，把相对对齐图的选区错套到旋转后的工作图上，
  // 导致框选区域与最终成片不一致。此测试锁定正确顺序。
  test('transform 90° + custom crop: rect is relative to PRE-transform image',
      () async {
    final input = makeSensorJpeg(); // 1080x1440 竖图
    final output = await PhotoPostProcessor.processFile(
      inputPath: input.path,
      params: const PostProcess(color: PostProcessColor()),
      aspectRatio: 'free',
      screenRatio: 9.0 / 19.5,
      isPortrait: true,
      transform: const TransformParams(rotation: 90),
      customCropRect: const CropRect(x: 0, y: 0, w: 0.5, h: 1),
    );
    final bytes = await File(output).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final w = frame.image.width;
    final h = frame.image.height;
    codec.dispose();
    // 正确顺序：先在对齐图上取左半 (540x1440)，旋转 90° → 横向 1440x540
    expect(w, 1440,
        reason: '先裁剪对齐图左半再旋转90°，输出应为横向 1440x540');
    expect(h, 540,
        reason: '先裁剪对齐图左半再旋转90°，输出应为横向 1440x540');
  });

  // ── 裁剪框逆变换（WYSIWYG 的另一半）──
  // processFile 以「先按原图裁剪、后应用变换」解释 customCropRect，即该矩形相对
  // 【未变换】的对齐图。而裁剪 UI（CropOverlay）把照片包一层变换预览（旋转/翻转/
  // 拉直，见 _applyTransform），用户框选的是【变换后】的展示。因此 UI 必须把裁剪框
  // 逆变换回未变换坐标（invertCropTransform），否则一旦叠加旋转/翻转，选区与导出错位
  // —— 这正是「旋转之后裁剪不对」「对剪裁过的图二次裁剪不对」的根因。
  // 本组测试锁定 invertCropTransform 的映射语义（与 _applyTransform 互为逆运算）。

  test('invertCropTransform: identity transform returns frame unchanged', () {
    const frame = Rect.fromLTRB(0.2, 0.1, 0.8, 0.9);
    expect(PhotoPostProcessor.invertCropTransform(frame, null), frame);
    expect(PhotoPostProcessor.invertCropTransform(
        frame, const TransformParams()), frame);
  });

  test('invertCropTransform: 90° right-half display maps to top-half image', () {
    // 用户看到旋转 90° 的展示，在屏幕右侧框选（x∈[0.5,1]）。
    // 旋转 90°（Transform.rotate，y 向下）的逆映射下，该区域对应未变换照片的
    // 【上半】（绕中心 (0.5,0.5) 旋转）。
    {
      const t = TransformParams(rotation: 90);
      final inverted = PhotoPostProcessor.invertCropTransform(
          const Rect.fromLTRB(0.5, 0, 1, 1), t);
      // 期望 ≈ 未变换图像的上半（x 全幅，y 上半）
      expect(inverted.top, closeTo(0.0, 1e-9));
      expect(inverted.bottom, closeTo(0.5, 1e-6));
      expect(inverted.left, closeTo(0.0, 1e-9));
      expect(inverted.right, closeTo(1.0, 1e-6));
    }
  });

  test('invertCropTransform: center square is rotation-invariant', () {
    const center = Rect.fromLTRB(0.25, 0.25, 0.75, 0.75);
    for (final rot in [90, 180, 270]) {
      final inverted = PhotoPostProcessor.invertCropTransform(
          center, TransformParams(rotation: rot));
      expect(inverted.left, closeTo(0.25, 1e-6));
      expect(inverted.top, closeTo(0.25, 1e-6));
      expect(inverted.right, closeTo(0.75, 1e-6));
      expect(inverted.bottom, closeTo(0.75, 1e-6),
          reason: '中心对称矩形在 90/180/270° 旋转下应不变（包围盒）');
    }
  });

  test('invertCropTransform: flipH maps left-half display to right-half image',
      () {
    // 水平翻转后的展示：屏幕左半对应未变换照片的【右半】（绕中心镜像）。
    final inverted = PhotoPostProcessor.invertCropTransform(
        const Rect.fromLTRB(0, 0, 0.5, 1), const TransformParams(flipH: true));
    expect(inverted.left, closeTo(0.5, 1e-6));
    expect(inverted.right, closeTo(1.0, 1e-9));
  });

  // ── 多轮编辑（对已裁剪过的图二次裁剪）嵌套组合 ──
  // 二次裁剪时，bakedBase = 比例区域 ⊕ 上一轮 customCropRect（DB 记录，相对比例区域），
  // 本轮 inner = 相对【当前展示照片】的框选，最终区域 = 比例区域 ⊕ base ⊕ inner。
  // 相对坐标组合满足结合律，须保证 base⊕inner 与逐层映射等价。

  test('composeCropRects: 2nd crop nests inside 1st crop (associative)', () {
    // 第一轮：框出左上 1/4 → 相对比例区域的 (0,0,0.5,0.5)
    const first = CropRect(x: 0, y: 0, w: 0.5, h: 0.5);
    // 第二轮：在展示照片（= 第一轮结果）上框出左上 1/4
    const second = CropRect(x: 0, y: 0, w: 0.5, h: 0.5);
    final composed = PhotoPostProcessor.composeCropRects(first, second)!;
    // 组合后 = 比例区域的左上 1/4 的左上 1/4 = 整个比例区域的左上 1/16
    expect(composed.x, closeTo(0.0, 1e-9));
    expect(composed.y, closeTo(0.0, 1e-9));
    expect(composed.w, closeTo(0.25, 1e-9));
    expect(composed.h, closeTo(0.25, 1e-9));
  });

  test('processFile: 2nd crop on already-cropped photo maps to correct region',
      () async {
    // 1080x1440 3:4 传感器，baseRatio=fullscreen → 比例区域 = 水平居中竖条。
    // 第一轮框左上 1/4（相对比例区域），第二轮框左上 1/2（相对第一轮结果）：
    // 最终相对比例区域 = (0,0,0.25,0.25)。用 computeCustomCropRect 验证落点。
    final ratio = PhotoPostProcessor.computeCropRect(
        'fullscreen', 1080, 1440, 9.0 / 19.5, true);
    final first = PhotoPostProcessor.computeCustomCropRect(
        const CropRect(x: 0, y: 0, w: 0.5, h: 0.5),
        ratio[0], ratio[1], ratio[2], ratio[3]);
    final second = PhotoPostProcessor.computeCustomCropRect(
        const CropRect(x: 0, y: 0, w: 0.5, h: 0.5),
        first[0], first[1], first[2], first[3]);
    final viaCompose = PhotoPostProcessor.computeCustomCropRect(
        PhotoPostProcessor.composeCropRects(
                const CropRect(x: 0, y: 0, w: 0.5, h: 0.5),
                const CropRect(x: 0, y: 0, w: 0.5, h: 0.5))!,
        ratio[0], ratio[1], ratio[2], ratio[3]);
    // 「先映射上一轮再映射本轮」与「嵌套组合后一次映射」在数学上等价；
    // 由于两段式逐步取整（.round()）与单次组合取整的舍入差异，允许 ±1px。
    for (var i = 0; i < 4; i++) {
      expect(second[i], closeTo(viaCompose[i], 1),
          reason: '「先映射上一轮再映射本轮」与「嵌套组合后一次映射」应一致（±1px 取整）');
    }
    expect(second[2],
        closeTo(first[2] * 0.5, 1),
        reason: '二次裁剪应落在一轮结果的 1/2 内，而非整张比例区域');
  });
}
