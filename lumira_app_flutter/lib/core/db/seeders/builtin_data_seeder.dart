import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../tables.dart';
import '../../../features/capture/data/capture_scene_mock_data.dart';
import '../../../features/templates/data/templates_browse_mock_data.dart';

/// 预置数据 Seeder
/// 在数据库 v4 迁移时插入预置场景 + 预置模板。
///
/// 触发条件：user_settings.seed_v3_done != 1 且 custom_templates 中无 is_builtin=0 的用户自定义模板。
/// 失败时静默回退（spec §9），调用方应 try/catch。
///
/// 适配说明（与 brief 的偏差）：
/// - brief 假设 allScenes 有 12 项，实际 CaptureSceneMockData.allScenes 返回 7 项（1 custom + 6 preset）。
/// - brief 假设存在顶层 templatesBrowseMockData 变量且有 12 项（8 免费 + 4 付费），
///   实际数据源为 TemplatesBrowseMockData.allTemplates，共 10 项（6 免费 + 4 付费）。
/// - ScenePreset.style 为 String（非对象，无 .id），直接使用。
/// - ScenePreset.icon 为 String（'ph-xxx' phosphor 图标名），直接存储。
/// - ScenePreset.category / relatedCategory 为 String（字符串常量），直接存储。
/// - ScenePreset 无 tagIds 字段（仅 CustomScenePreset 有），按类型判断取值。
class BuiltinDataSeeder {
  BuiltinDataSeeder._();

  /// 执行种子插入。
  /// 返回 true 表示本次执行了插入；false 表示已种子化或用户已有自定义数据则跳过。
  static Future<bool> seedAll(Database db) async {
    // 1. 检查 seed_v3_done
    final settings = await db.query(Tables.userSettings, where: '${Tables.colId} = ?', whereArgs: [1]);
    if (settings.isNotEmpty && (settings.first[Tables.colSeedV3Done] as num?)?.toInt() == 1) {
      return false;
    }

    // 2. 检查用户已有自定义模板（避免覆盖）
    final customCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${Tables.customTemplates} WHERE ${Tables.colIsBuiltin} = 0',
    )) ?? 0;
    if (customCount > 0) {
      // 用户已有自定义模板，仅标记 seed_v3_done 避免重复检查
      await _markSeedDone(db);
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    // 3. 插入预置场景（来自 CaptureSceneMockData.allScenes）
    final scenes = CaptureSceneMockData.allScenes;
    final batch = db.batch();
    for (final s in scenes) {
      batch.insert(
        Tables.scenes,
        {
          Tables.colId: s.id,
          Tables.colName: s.name,
          // ScenePreset.icon 为 String（'ph-xxx' phosphor 图标名），直接存储
          Tables.colIcon: s.icon,
          Tables.colCategory: s.category,
          // ScenePreset.style 为 String（非 SceneStyle 对象，无 .id）
          Tables.colStyle: s.style,
          Tables.colFilterJson: jsonEncode({
            'lut': s.filter.lut,
            'systemFilter': s.filter.systemFilter,
            'reason': s.filter.reason,
          }),
          Tables.colVibe: s.vibe,
          Tables.colDescription: s.description,
          Tables.colExampleImagesJson: jsonEncode(s.exampleImages),
          Tables.colTipsJson: jsonEncode(s.tips),
          Tables.colWhereToShoot: s.whereToShoot,
          Tables.colBestTime: s.bestTime,
          Tables.colSceneGuideJson: jsonEncode({
            'lightDirection': s.sceneGuide.lightDirection,
            'shootingDistance': s.sceneGuide.shootingDistance,
            'background': s.sceneGuide.background,
            'props': s.sceneGuide.props,
            'bestTime': s.sceneGuide.bestTime,
            'tips': s.sceneGuide.tips,
          }),
          // ScenePreset.relatedCategory 为 String（字符串常量）
          Tables.colRelatedCategory: s.relatedCategory,
          Tables.colRecommendedTagIdsJson: jsonEncode(s.recommendedTagIds),
          // ScenePreset 基类无 tagIds，仅 CustomScenePreset 有
          Tables.colTagIdsJson: jsonEncode(s is CustomScenePreset ? s.tagIds : <String>[]),
          Tables.colCreator: 'system',
          Tables.colIsFavorite: 0,
          Tables.colCreatedAt: now,
          Tables.colUpdatedAt: now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // 4. 插入预置模板（来自 TemplatesBrowseMockData.allTemplates）
    const items = TemplatesBrowseMockData.allTemplates;
    // 前 3 个标记为 recommended（用于 Hero 区）
    final recommendedIds = items.take(3).map((t) => t.id).toSet();
    for (final t in items) {
      batch.insert(
        Tables.customTemplates,
        {
          Tables.colId: t.id,
          Tables.colName: t.name,
          Tables.colAuthor: 'Lumira',
          Tables.colVersion: '1.0.0',
          Tables.colCategory: t.category,
          Tables.colClassificationJson: jsonEncode({
            'type': t.category,
            'style': t.style,
            'method': t.method,
          }),
          Tables.colTagsJson: jsonEncode(<String>[]),
          Tables.colTagIdsJson: jsonEncode(<String>[]),
          Tables.colPrice: t.price,
          Tables.colCover: 'assets/images/templates/${t.id}.jpg',
          Tables.colDescription: '',
          Tables.colReferenceSource: '',
          Tables.colCompositionJson: jsonEncode({'overlayType': 'rule_of_thirds'}),
          Tables.colPoseJson: jsonEncode(<String, dynamic>{}),
          Tables.colCameraJson: jsonEncode(<String, dynamic>{}),
          Tables.colSceneGuideJson: jsonEncode(<String, dynamic>{}),
          Tables.colPostProcessJson: jsonEncode(<String, dynamic>{}),
          Tables.colIsBuiltin: 1,
          Tables.colIsRecommended: recommendedIds.contains(t.id) ? 1 : 0,
          Tables.colCreatedAt: now,
          Tables.colUpdatedAt: now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);

    // 5. 标记 seed_v3_done = 1
    await _markSeedDone(db);
    return true;
  }

  static Future<void> _markSeedDone(Database db) async {
    await db.update(
      Tables.userSettings,
      {
        Tables.colSeedV3Done: 1,
        Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: '${Tables.colId} = ?',
      whereArgs: [1],
    );
  }
}
