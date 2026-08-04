import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../tables.dart';
import '../../../features/capture/data/capture_scene_mock_data.dart';
import '../../../features/capture/data/template_registry.dart';
import '../../../features/templates/services/template_mapper.dart';

/// 预置数据 Seeder
/// 在数据库 v4 迁移时插入预置场景 + 预置模板。
///
/// 触发条件：user_settings.seed_v3_done != 1 且 custom_templates 中无 is_builtin=0 的用户自定义模板。
/// 失败时静默回退（spec §9），调用方应 try/catch。
///
/// v10 迁移新增 [reseedBuiltinTemplates]：强制重新种子化内置模板（从 [TemplateRegistry]
/// 获取全量 29 个模板），不影响用户自定义模板。
///
/// 适配说明（与 brief 的偏差）：
/// - brief 假设 allScenes 有 12 项，实际 CaptureSceneMockData.allScenes 返回 7 项（1 custom + 6 preset）。
/// - brief 假设存在顶层 templatesBrowseMockData 变量且有 12 项（8 免费 + 4 付费），
///   实际数据源为 TemplateRegistry.allTemplates，共 29 项（含 12 原始 + 17 新增人像模板）。
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
    await _seedScenes(db, now);

    // 4. 插入预置模板（来自 TemplateRegistry.allTemplates）
    await _seedBuiltinTemplates(db, now);

    // 5. 标记 seed_v3_done = 1
    await _markSeedDone(db);
    return true;
  }

  /// 强制重新种子化内置模板（v10 迁移用）。
  ///
  /// 与 [seedAll] 的区别：
  /// - 不检查 seed_v3_done 标志
  /// - 不检查用户自定义模板
  /// - 先删除现有内置模板（is_builtin=1），再插入全量 [TemplateRegistry.allTemplates]
  /// - 不重新插入场景数据（场景已在 v4 种子化，无需重复）
  /// - 不修改 seed_v3_done 标志
  ///
  /// 用于 v10 迁移：将内置模板从旧的 10 个更新为全量 29 个（含 17 个新人像模板）。
  static Future<void> reseedBuiltinTemplates(Database db) async {
    // 删除现有内置模板（保留用户自定义模板 is_builtin=0）
    await db.delete(
      Tables.customTemplates,
      where: '${Tables.colIsBuiltin} = ?',
      whereArgs: [1],
    );
    // 重新插入全量内置模板
    final now = DateTime.now().millisecondsSinceEpoch;
    await _seedBuiltinTemplates(db, now);
  }

  /// 插入预置场景数据
  static Future<void> _seedScenes(Database db, int now) async {
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
    await batch.commit(noResult: true);
  }

  /// 插入预置模板数据（来自 [TemplateRegistry.allTemplates]）
  ///
  /// 数据源：[TemplateRegistry] 是模板的唯一真相源（source of truth），
  /// 包含全量 29 个模板（12 原始 + 17 新增人像模板）。
  /// 前 3 个模板标记为 recommended（用于首页 Hero 推荐区）。
  static Future<void> _seedBuiltinTemplates(Database db, int now) async {
    final templates = TemplateRegistry.allTemplates;
    // 前 3 个标记为 recommended（用于 Hero 区）
    final recommendedIds = templates.take(3).map((t) => t.meta.id).toSet();
    final batch = db.batch();
    for (final t in templates) {
      final record = TemplateMapper.toRecord(
        t,
        createdAt: now,
        isBuiltin: true,
        isRecommended: recommendedIds.contains(t.meta.id),
      );
      batch.insert(
        Tables.customTemplates,
        record.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
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
