// lib/features/capture/domain/post_process_delta.dart
import 'photo_template.dart';

/// 用户在编辑面板上看到的全量参数 = 基线 baked + 增量 local。
PostProcess fullOf(PostProcess baked, PostProcess local) => baked.merge(local);

/// 由基线 baked 与目标全量 full 反推增量 local。
///
/// 与 [PostProcess.merge] 的互逆性并非对所有字段成立，仅对以下分组成立：
///
/// 1. 加法字段（color 各数值、smoothStrength/sharpen/vignette/grain）：deltaOf 产出差值，
///    merge 按加法合并，保证 baked.merge(deltaOf(baked, full)) 还原 full，互逆成立。
/// 2. lut / systemFilter：当 full 与 baked 相等时，deltaOf 归哨兵（'none'/null），merge 在
///    哨兵时回退 baked 基线，此时互逆成立；当 full 为非哨兵值时同样互逆成立。
///    但存在一个固有边界：一旦烘焙值存在（如 baked.lut='fuji'），用户无法通过增量模型
///    "清除回原图"（让 full.lut 回到 'none'）——因为 deltaOf 会把 full.lut='none' 映射为
///    delta.lut='none'，而 merge 把 'none' 视为"保留 baked"。因此互逆仅对 full == baked
///    （→ 哨兵）或 full 为非哨兵值时成立，这是 baked+delta 模型的固有边界，不是 bug。
/// 3. cropRatio / customCropRect：为绝对值，不参与 merge 的增量合并（merge 对 cropRatio
///    取 baked 基线 this.cropRatio，对 customCropRect 仅在 delta 非空时覆盖），
///    因此互逆对这两个字段不适用。
///
/// [current] 当前增量（调用方持有的 local）。色彩/细节滑块走「全量 → 反推增量」时，
/// full 的 cropRatio 恒等于 baked（merge 丢弃 delta 的比例）、customCropRect 在
/// local 为 null 时会回退成 baked 的烘焙值——若直接采用会把「本轮未框选」污染成
/// 「沿用上一轮裁剪」，以及把用户刚选的比例冲掉。故这两个字段在 full 与 baked
/// 一致时优先保留 [current] 的值（无 current 时归 'free'/null 哨兵）。
PostProcess deltaOf(PostProcess baked, PostProcess full, {PostProcess? current}) {
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
    cropRatio: full.cropRatio == baked.cropRatio
        ? (current?.cropRatio ?? 'free')
        : full.cropRatio,
    lut: full.lut == baked.lut ? 'none' : full.lut,
    systemFilter:
        full.systemFilter == baked.systemFilter ? null : full.systemFilter,
    customCropRect: full.customCropRect == baked.customCropRect
        ? current?.customCropRect
        : full.customCropRect,
  );
}