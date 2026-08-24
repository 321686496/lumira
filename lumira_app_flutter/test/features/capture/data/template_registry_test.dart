// test/features/capture/data/template_registry_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/template_registry.dart';

void main() {
  group('TemplateRegistry', () {
    test('returns all 132 templates', () {
      expect(TemplateRegistry.allTemplates.length, 132);
    });

    test('getTemplate returns copy, not singleton', () {
      final t1 = TemplateRegistry.getTemplate('soft_portrait');
      final t2 = TemplateRegistry.getTemplate('soft_portrait');
      expect(t1, isNotNull);
      expect(t2, isNotNull);
      expect(identical(t1, t2), false); // different instances
      expect(t1 == t2, true); // but equal by value
    });

    test('getRecentTemplates returns correct count', () {
      expect(TemplateRegistry.getRecentTemplates(6).length, 6);
      expect(TemplateRegistry.getRecentTemplates(12).length, 12);
      expect(TemplateRegistry.getRecentTemplates(20).length, 20); // now 132 total
    });

    test('getTemplate returns null for unknown id', () {
      expect(TemplateRegistry.getTemplate('unknown'), isNull);
    });

    test('all template ids are unique', () {
      final ids = TemplateRegistry.allTemplates.map((t) => t.meta.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('soft_portrait has expected data', () {
      final tpl = TemplateRegistry.getTemplate('soft_portrait');
      expect(tpl, isNotNull);
      expect(tpl!.meta.name, '窗边柔光人像');
      expect(tpl.meta.price, 0);
      expect(tpl.camera.iso, 200);
      expect(tpl.postProcess.lut, 'pastel');
    });

    test('86 free + 46 paid templates', () {
      final free = TemplateRegistry.allTemplates.where((t) => t.meta.price == 0).toList();
      final paid = TemplateRegistry.allTemplates.where((t) => t.meta.price > 0).toList();
      expect(free.length, 86);
      expect(paid.length, 46);
    });
  });
}
