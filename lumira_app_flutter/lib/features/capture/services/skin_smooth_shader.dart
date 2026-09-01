import '../domain/photo_template.dart';

/// 磨皮 shader 的宿主无关参数映射。
class SkinSmoothConfig {
  const SkinSmoothConfig({required this.strength});
  final double strength;
  factory SkinSmoothConfig.fromPostProcess(PostProcess p) =>
      SkinSmoothConfig(strength: skinStrength(p));
}

double skinStrength(PostProcess p) =>
    (p.smoothStrength / 100.0).clamp(0.0, 1.0).toDouble();

bool needsSkin(PostProcess p) => p.smoothStrength > 0;