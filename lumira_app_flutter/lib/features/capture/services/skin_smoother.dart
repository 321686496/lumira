import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// 皮肤平滑处理器（自然磨皮·保留肤质）
///
/// 纯 Dart 实现，三端兼容（OHOS / iOS / Android）。
///
/// 目标：抖音式「自然磨皮」— 只去掉细毛孔/瑕疵这类**高频小颗粒**，
/// 保住五官边缘与**低频明暗结构**（颧骨高光、鼻侧影、轮廓），并保留一成肤质，
/// 脸不变平、不糊、不塑料。
///
/// 从前迭代教训（切勿回退）：
/// - 大半径高斯+肤色掩膜（或降采样→放大、或"朝模糊底图混合" blend=0.8~1.0）
///   会把颧骨阴影、鼻侧影、法令纹等**中频结构**连同毛孔一起抹平 → 整张脸糊/塑料感。
///   原因：blend 直接把像素朝全局模糊底图拽，低频结构也被削弱。
/// - 抖音/主流美颜用的是**频率分离**：只削高频细节，低频结构 100% 保留。
///
/// 算法（频率分离削细节）：
/// 1. 低频底图 base = 中半径高斯（只去掉毛孔这类高频颗粒，保留低频明暗）；
/// 2. detail = 原图 − base（高通残差 = 高频颗粒 + 五官边缘等高对比结构）；
/// 3. 逐像素门控：肤色概率 skin × 结构门控 struct(smoothstep(|detail|))：
///    - 平坦肤区（|detail| 小）→ removal≈baseRemove×skin，真正磨掉毛孔；
///    - 强结构/五官边缘（|detail| 大）→ struct→1，removal→0，细节全留（锐利）；
///    - 非肤色（背景/衣物/发丝）→ skin→0，removal→0，像素原样（100% 保留）。
/// 4. removal 有上限（≈0.6），**永不把肤质全抹掉** → 不塑料。
/// 5. out = original − detail × removal（低频结构原样保留 → 脸不变平/不糊）。
class SkinSmoother {
  SkinSmoother._();

  /// 皮肤平滑
  /// [strengthInt] 0-100，来自 PostProcess.smoothStrength
  /// 返回处理后的图像；strength=0 返回原对象（快速路径）。不修改入参 [src]。
  static img.Image smooth(img.Image src, int strengthInt) {
    if (strengthInt <= 0) return src;
    final strength = (strengthInt / 100.0).clamp(0.0, 1.0);
    if (strength <= 0.01) return src;
    if (src.width <= 1 || src.height <= 1) return src;

    // 1. 低频底图 base：中半径高斯（2..5），只去掉细毛孔/瑕疵这类高频颗粒。
    //    低频明暗结构（颧骨高光/鼻侧影/轮廓）仍完整保留在 base 里，不会变平。
    //    对 src 的 clone 模糊，保证入参 src 不被修改。
    final blurRadius = (2 + strength * 3).round().clamp(2, 5);
    final base = img.gaussianBlur(src.clone(), radius: blurRadius);

    // 2. 逐像素"频率分离削细节"：
    //    detail = 原图 − 低频底（高频颗粒 + 五官边缘等高对比结构）
    //    removal = baseRemove × 肤色概率 × (1 − 结构门控)
    //    结构门控 = smoothstep(|detail|)：强结构(五官/轮廓) → removal≈0(细节全留)
    //              平坦肤 → removal=baseRemove×skin(磨掉毛孔)
    //    纹理下限：removal 有上限(≈0.6)，永不把肤质全抹掉 → 不塑料。
    //    out = 原图 − detail × removal（低频结构原样保留 → 脸不变平/不糊）
    final baseRemove = 0.50 * strength + 0.04; // 0.04..0.54（自然向，保留肤质不塑料）
    final edgeLow = 6.0 + strength * 6.0; // 结构阈值下限（< 它视为毛孔/平坦）
    final edgeHigh = edgeLow * 2.5; // 结构阈值上限（更灵敏，强保护五官边缘/肩部）

    final out = src.clone();
    final baseIt = base.iterator;
    for (final p in out) {
      baseIt.moveNext();
      final b = baseIt.current;
      final detailR = p.r - b.r;
      final detailG = p.g - b.g;
      final detailB = p.b - b.b;
      final margin = math.max(
        math.max(detailR.abs().toDouble(), detailG.abs().toDouble()),
        detailB.abs().toDouble(),
      );

      final skin = _skinWeight(p.r, p.g, p.b);
      final struct = _smoothstep(margin, edgeLow, edgeHigh); // 0=平坦/毛孔，1=结构
      final removal = (baseRemove * skin * (1.0 - struct)).clamp(0.0, 1.0);
      if (removal <= 0.001) continue; // 非肤色 / 强结构 → 原样保留

      p
        ..r = (b.r + detailR * (1.0 - removal)).round().clamp(0, 255)
        ..g = (b.g + detailG * (1.0 - removal)).round().clamp(0, 255)
        ..b = (b.b + detailB * (1.0 - removal)).round().clamp(0, 255);
    }
    return out;
  }

  /// 平滑步进（smoothstep），用于肤色区间与边缘映射。
  static double _smoothstep(double x, double edge0, double edge1) {
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// YCbCr 肤色概率 0..1。
  ///
  /// 采用经典 YCbCr 肤色区间（BT.601），较窄的盒子（Cb[77,127]、Cr[133,173]）只覆盖
  /// “标准”肤况，真实照片里被阴影、暗光、偏色影响的皮肤会被判非肤色 → 大块皮肤磨不到，
  /// 表现为“只局部糊、没整体磨皮效果”。因此在此放宽：
  /// - Cb∈[70,132]、Cr∈[128,186]（覆盖更多浅/深/偏色肤况）
  /// - 亮度下限降到 40，把阴影里皮肤也算进来；上限放宽到 250 辨昏暗部。
  /// 边界仍用 soft 过渡；放宽带来的“错判到肤色衣物”风险由边缘保护兜底（blend 在边缘≈0）。
  static double _skinWeight(num r, num g, num b) {
    final y = 0.299 * r + 0.587 * g + 0.114 * b;
    final cb = (-0.168736 * r - 0.331264 * g + 0.5 * b) + 128.0;
    final cr = (0.5 * r - 0.418688 * g - 0.081312 * b) + 128.0;

    // 亮度区间外（过暗/过曝）不算肤色
    final yWeight = _smoothstep(y, 40, 60) * (1 - _smoothstep(y, 250, 255));
    // Cr/Cb 肤色盒（放宽），边界 soft
    final crWeight = _smoothstep(cr, 128, 140) * (1 - _smoothstep(cr, 172, 186));
    final cbWeight = _smoothstep(cb, 70, 85) * (1 - _smoothstep(cb, 120, 132));
    return yWeight * crWeight * cbWeight;
  }
}