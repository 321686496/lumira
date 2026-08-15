// lib/features/capture/domain/post_process_delta.dart
import 'photo_template.dart';

/// 用户在编辑面板上看到的全量参数 = 基线 baked + 增量 local。
PostProcess fullOf(PostProcess baked, PostProcess local) => baked.merge(local);

/// 由基线 baked 与目标全量 full 反推增量 local。
///
/// 与 [PostProcess.merge] 的互逆性并非对所有字段成立，仅对以下分组成立：
///
/// 1. 加法字段（color 各数值、smoothStrength/sharpen/vignette/grain）：deltaOf 产出差值，
///    merge 按加法合并，保证 baked.merge(deltaOf(baked, full)) 还原 full。
/// 2. lut / systemFilter：相等时归 'none' / null，merge 在 'none'/null 时回退 baked 基线，
///    同样保证互逆成立。
/// 3. cropRatio / customCropRect：为绝对值，不参与 merge 的增量合并（merge 对 cropRatio
///    取 baked 基线 this.cropRatio，对 customCropRect 仅在 delta 非空时覆盖），
///    因此互逆对这两个字段不适用。
PostProcess deltaOf(PostProcess baked, PostProcess full) {
  final bc = baked.color;
  final fc = full.color;
  return PostProcess(
    color: PostProcessColor(
      brightness: fc.brightness - bc.brightness,
      contrast: fc.contrast - bc.contrast,
      saturation: fc.saturation - bc.saturation,
      temperature: fc.temperature - bc.temperature,
      tint: fc.tint - bc.tint,
      highlights: (fc.highlights ?? 0) - (bc.highlights ?? 0),
      shadows: (fc.shadows ?? 0) - (bc.shadows ?? 0),
      blackPoint: (fc.blackPoint ?? 0) - (bc.blackPoint ?? 0),
      clarity: (fc.clarity ?? 0) - (bc.clarity ?? 0),
      vibrance: (fc.vibrance ?? 0) - (bc.vibrance ?? 0),
      brilliance: (fc.brilliance ?? 0) - (bc.brilliance ?? 0),
    ),
    smoothStrength: full.smoothStrength - baked.smoothStrength,
    sharpen: full.sharpen - baked.sharpen,
    vignette: full.vignette - baked.vignette,
    grain: full.grain - baked.grain,
    cropRatio: full.cropRatio,
    lut: full.lut == baked.lut ? 'none' : full.lut,
    systemFilter:
        full.systemFilter == baked.systemFilter ? null : full.systemFilter,
    customCropRect: full.customCropRect,
  );
}