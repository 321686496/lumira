// 白平衡「残差」机制验证：
// 1. composePostProcessMatrix 把 wbResidual 对角矩阵乘在最内层（先于调色）
// 2. toJson/fromJson 往返保留 wbResidual（旧记录无字段 → null 向后兼容）
// 3. copyWith 哨兵：未传保留 / 显式 null 清空
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/domain/filter_recipe.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';

void main() {
  group('composePostProcessMatrix wbResidual', () {
    test('identity 调色 + 非恒等残差 → 对角矩阵 (r,g,b)', () {
      const post = PostProcess(
        color: PostProcessColor(),
        wbResidual: WbResidual(r: 1.5, g: 1.0, b: 0.8),
      );
      final m = composePostProcessMatrix(post);
      expect(m[0], closeTo(1.5, 1e-9)); // R 对角
      expect(m[6], closeTo(1.0, 1e-9)); // G 对角
      expect(m[12], closeTo(0.8, 1e-9)); // B 对角
      expect(m[18], closeTo(1.0, 1e-9)); // A 对角
    });

    test('残差在最内层：先于 brightness 应用', () {
      // brightness=100 → 系数 2.0；若残差在内层，R 对角 = 2.0 × 1.5 = 3.0
      const post = PostProcess(
        color: PostProcessColor(brightness: 100),
        wbResidual: WbResidual(r: 1.5, g: 1.0, b: 0.8),
      );
      final m = composePostProcessMatrix(post);
      expect(m[0], closeTo(3.0, 1e-9));
    });

    test('残差为恒等 → 矩阵与无残差一致', () {
      const identityResidual = PostProcess(
        color: PostProcessColor(),
        wbResidual: WbResidual(r: 1.0, g: 1.0, b: 1.0),
      );
      final m = composePostProcessMatrix(identityResidual);
      expect(m[0], 1.0);
      expect(m[12], 1.0);
    });
  });

  group('PostProcess wbResidual 序列化与 copyWith', () {
    test('toJson/fromJson 往返保留 wbResidual', () {
      const post = PostProcess(
        color: PostProcessColor(),
        wbResidual: WbResidual(r: 1.42, g: 1.0, b: 1.31),
      );
      final restored = PostProcess.fromJson(post.toJson());
      expect(restored.wbResidual, const WbResidual(r: 1.42, g: 1.0, b: 1.31));
    });

    test('旧记录无 wbResidual 字段 → null（向后兼容）', () {
      final restored = PostProcess.fromJson(<String, dynamic>{
        'cropRatio': '3:4',
        'color': <String, dynamic>{},
      });
      expect(restored.wbResidual, isNull);
    });

    test('copyWith：未传保留 / 显式 null 清空', () {
      const base = PostProcess(
        color: PostProcessColor(),
        wbResidual: WbResidual(r: 1.5, g: 1.0, b: 0.8),
      );
      expect(base.copyWith(color: const PostProcessColor()).wbResidual,
          const WbResidual(r: 1.5, g: 1.0, b: 0.8));
      expect(base.copyWith(wbResidual: null).wbResidual, isNull);
    });

    test('merge：增量无残差时保留烘焙残差', () {
      const baked = PostProcess(
        color: PostProcessColor(),
        wbResidual: WbResidual(r: 1.5, g: 1.0, b: 0.8),
      );
      const local = PostProcess(color: PostProcessColor(brightness: 10));
      final merged = baked.merge(local);
      expect(merged.wbResidual, const WbResidual(r: 1.5, g: 1.0, b: 0.8));
    });

    test('WbResidual.fromPlatformMap 解析', () {
      expect(
        WbResidual.fromPlatformMap({'r': 1.5, 'g': 1.0, 'b': 0.8}),
        const WbResidual(r: 1.5, g: 1.0, b: 0.8),
      );
      expect(WbResidual.fromPlatformMap(null), isNull);
      expect(WbResidual.fromPlatformMap({'r': 1.5}), isNull);
    });
  });
}
