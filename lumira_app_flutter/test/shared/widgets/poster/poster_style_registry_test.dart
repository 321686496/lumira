import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_ratio.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_registry.dart';

void main() {
  group('PosterStyleRegistry 模板样式（kind=template）', () {
    test('9:16 提供 pA / pC / s3（对应选型稿）', () {
      final ids = _ids(PosterKind.template, PosterRatio.fullScreen);
      expect(ids, <String>['pA', 'pC', 's3']);
    });

    test('3:4 提供 pA / pC / dK（对应选型稿）', () {
      final ids = _ids(PosterKind.template, PosterRatio.ratio34);
      expect(ids, <String>['pA', 'pC', 'dK']);
    });

    test('1:1 提供 v2a / dE / dD（对应选型稿）', () {
      final ids = _ids(PosterKind.template, PosterRatio.square);
      expect(ids, <String>['v2a', 'dE', 'dD']);
    });

    test('16:9 提供 pA / p3 / pE（对应选型稿）', () {
      final ids = _ids(PosterKind.template, PosterRatio.ratio169);
      expect(ids, <String>['pA', 'p3', 'pE']);
    });

    test('4:3 提供 pA / stage1 / pE（对应选型稿）', () {
      final ids = _ids(PosterKind.template, PosterRatio.ratio43);
      expect(ids, <String>['pA', 'stage1', 'pE']);
    });

    test('模板分享默认样式为选型稿首个样式（pA；1:1 为 v2a）', () {
      for (final ratio in PosterRatio.values) {
        final def = PosterStyleRegistry.defaultFor(PosterKind.template, ratio);
        final expected = ratio == PosterRatio.square ? 'v2a' : 'pA';
        expect(def?.id, expected,
            reason: '$ratio 模板分享应默认选型稿首个样式 $expected');
      }
    });

    test('模板样式不含「扫码导入」海报（走导出分享流程，不在样式切换条）', () {
      for (final ratio in PosterRatio.values) {
        final ids = _ids(PosterKind.template, ratio);
        expect(
          ids.where((id) => id.startsWith('imp')),
          isEmpty,
          reason: '$ratio 模板样式不应包含扫码导入海报',
        );
      }
    });
  });

  group('PosterStyleRegistry 照片样式（kind=photo）', () {
    test('9:16 提供 d1 / dN / dL', () {
      final ids = _ids(PosterKind.photo, PosterRatio.fullScreen);
      expect(ids, containsAll(<String>['d1', 'dN', 'dL']));
      expect(ids.length, 3);
    });

    test('3:4 提供 d3 / dA / s1', () {
      final ids = _ids(PosterKind.photo, PosterRatio.ratio34);
      expect(ids, containsAll(<String>['d3', 'dA', 's1']));
      expect(ids.length, 3);
    });

    test('1:1 提供 pC / dC / dM', () {
      final ids = _ids(PosterKind.photo, PosterRatio.square);
      expect(ids, containsAll(<String>['pC', 'dC', 'dM']));
      expect(ids.length, 3);
    });

    test('16:9 提供 pC', () {
      final ids = _ids(PosterKind.photo, PosterRatio.ratio169);
      expect(ids, <String>['pC']);
    });

    test('4:3 提供 pC', () {
      final ids = _ids(PosterKind.photo, PosterRatio.ratio43);
      expect(ids, <String>['pC']);
    });
  });

  group('PosterStyleRegistry 通用约束', () {
    test('每个受支持的 kind + ratio 组合均有默认样式', () {
      for (final kind in PosterKind.values) {
        for (final ratio in PosterRatio.values) {
          final list = PosterStyleRegistry.stylesFor(kind, ratio);
          // 某些 kind（如 checkin 仅支持 ratio34）默认未覆盖全部比例，跳过未注册组合。
          if (list.isEmpty) continue;
          final def = PosterStyleRegistry.defaultFor(kind, ratio);
          expect(def, isNotNull, reason: '$kind/$ratio 应存在默认样式');
          expect(def!.kind, kind);
          expect(def.supports(ratio), isTrue);
        }
      }
      // template / photo 覆盖全部比例，确保原有约束不回退。
      for (final ratio in PosterRatio.values) {
        expect(PosterStyleRegistry.defaultFor(PosterKind.template, ratio), isNotNull,
            reason: 'template $ratio 应存在默认样式');
        expect(PosterStyleRegistry.defaultFor(PosterKind.photo, ratio), isNotNull,
            reason: 'photo $ratio 应存在默认样式');
      }
    });

    test('返回的样式均匹配 kind 且支持对应 ratio', () {
      for (final kind in PosterKind.values) {
        for (final ratio in PosterRatio.values) {
          final list = PosterStyleRegistry.stylesFor(kind, ratio);
          for (final s in list) {
            expect(s.kind, kind);
            expect(s.supports(ratio), isTrue);
          }
        }
      }
    });

    test('all() 包含模板与照片全部样式且同一 kind 内 id 唯一', () {
      final all = PosterStyleRegistry.all();
      expect(all, isNotEmpty);
      // pC（相纸卡片）在 template 与 photo 两类间复用同一版式，id 允许跨 kind 重复。
      for (final kind in PosterKind.values) {
        final ids = all.where((s) => s.kind == kind).map((s) => s.id).toList();
        expect(ids.toSet().length, ids.length, reason: '$kind 样式 id 应唯一');
      }
      expect(
        all.where((s) => s.kind == PosterKind.template).length,
        greaterThan(0),
      );
      expect(all.where((s) => s.kind == PosterKind.photo).length, greaterThan(0));
    });
  });
}

List<String> _ids(PosterKind kind, PosterRatio ratio) =>
    PosterStyleRegistry.stylesFor(kind, ratio).map((s) => s.id).toList();
