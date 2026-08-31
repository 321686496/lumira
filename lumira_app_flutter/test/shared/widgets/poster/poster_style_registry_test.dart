import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_ratio.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_registry.dart';

void main() {
  group('PosterStyleRegistry 模板样式（kind=template）', () {
    test('9:16 提供 impV / pA / pC / s3', () {
      final ids = _ids(PosterKind.template, PosterRatio.fullScreen);
      expect(ids, containsAll(<String>['impV', 'pA', 'pC', 's3']));
      expect(ids.length, 4);
    });

    test('3:4 提供 impP / pA / pC / dK', () {
      final ids = _ids(PosterKind.template, PosterRatio.ratio34);
      expect(ids, containsAll(<String>['impP', 'pA', 'pC', 'dK']));
      expect(ids.length, 4);
    });

    test('1:1 提供 impS / pC / v2a / dE / dD', () {
      final ids = _ids(PosterKind.template, PosterRatio.square);
      expect(ids, containsAll(<String>['impS', 'pC', 'v2a', 'dE', 'dD']));
      expect(ids.length, 5);
    });

    test('16:9 提供 impC / pA / pC / p3 / pE', () {
      final ids = _ids(PosterKind.template, PosterRatio.ratio169);
      expect(ids, containsAll(<String>['impC', 'pA', 'pC', 'p3', 'pE']));
      expect(ids.length, 5);
    });

    test('4:3 提供 impL / pA / pC / pE / stage1', () {
      final ids = _ids(PosterKind.template, PosterRatio.ratio43);
      expect(ids, containsAll(<String>['impL', 'pA', 'pC', 'pE', 'stage1']));
      expect(ids.length, 5);
    });

    test('每位比例默认样式为对应扫码导入海报', () {
      for (final ratio in PosterRatio.values) {
        final def = PosterStyleRegistry.defaultFor(PosterKind.template, ratio);
        expect(def?.id, _defaultImportId(ratio),
            reason: '$ratio 应默认选中扫码导入海报');
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

/// 各比例应默认选中的扫码导入海报 id。
String? _defaultImportId(PosterRatio ratio) {
  switch (ratio) {
    case PosterRatio.fullScreen:
      return 'impV';
    case PosterRatio.ratio34:
      return 'impP';
    case PosterRatio.square:
      return 'impS';
    case PosterRatio.ratio43:
      return 'impL';
    case PosterRatio.ratio169:
      return 'impC';
  }
}
