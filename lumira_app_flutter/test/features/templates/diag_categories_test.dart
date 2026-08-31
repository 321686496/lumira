import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/capture/data/template_registry.dart';
import 'package:lumira_app_flutter/features/templates/data/templates_browse_mock_data.dart';
import 'package:lumira_app_flutter/features/templates/services/template_mapper.dart';

// Temporary diagnostic — print real builtin template classification paths
// and simulate the reported filter scenarios.
void main() {
  test('diagnose builtin classification paths', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await openDatabase(':memory:', version: 1,
        onCreate: (db, _) async {
      // minimal columns needed by TemplateRecord.fromRow via dao query
      // Not needed since we build items from the registry directly below.
    });

    // 1) Build AllTemplateItem list directly from registry via TemplateMapper
    final now = DateTime.now().millisecondsSinceEpoch;
    final items = <AllTemplateItem>[];
    for (final t in TemplateRegistry.allTemplates) {
      final r = TemplateMapper.toRecord(t, createdAt: now, isBuiltin: true);
      items.add(AllTemplateItem(
        id: r.id,
        name: r.name,
        category: r.category,
        style: (r.classification['style'] as String?),
        method: (r.classification['method'] as String?),
        majorStyle: (r.classification['majorStyle'] as String?),
        subStyle: (r.classification['subStyle'] as String?),
        coverSeed: r.id,
        price: r.price,
        isCustom: false,
      ));
    }

    // Print all
    for (final it in items) {
      // ignore: avoid_print
      print('TEMPLATE [${it.id}] cat=${it.category} path=${it.classificationPath}');
    }

    bool has(List<String> prefix) =>
        items.any((it) => it.matchesCategoryPathPrefix(prefix));

    // Reported scenarios
    // ignore: avoid_print
    print('\n--- reported checks ---');
    // ignore: avoid_print
    print('food/overhead matches: ${items.where((i) => i.matchesCategoryPathPrefix(['food','overhead'])).map((i)=>'${i.id}(${i.category})').toList()}');
    // ignore: avoid_print
    print('still-life/flat matches: ${items.where((i) => i.matchesCategoryPathPrefix(['still-life','flat'])).map((i)=>'${i.id}(${i.category})').toList()}');
    // ignore: avoid_print
    print('landscape  matches: ${items.where((i) => i.matchesCategoryPathPrefix(['landscape'])).map((i)=>i.id).toList()}');
    // ignore: avoid_print
    print('One-level food card (prefix [food]) matches: ${items.where((i) => i.matchesCategoryPathPrefix(['food'])).map((i)=>i.id).toList()}');
    // ignore: avoid_print
    print('One-level still-life card matches: ${items.where((i) => i.matchesCategoryPathPrefix(['still-life'])).map((i)=>i.id).toList()}');
    // ignore: avoid_print
    print('macro card matches: ${items.where((i) => i.matchesCategoryPathPrefix(['macro'])).map((i)=>i.id).toList()}');

    await db.close();
  });
}