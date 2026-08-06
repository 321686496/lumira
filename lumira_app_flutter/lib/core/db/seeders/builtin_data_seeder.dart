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

  /// 仅更新内置模板的 cover 字段（v11 迁移用）。
  ///
  /// 修复：12 款原始模板的 cover 从 picsum URL 改为本地 asset 路径。
  /// 不删除/重建记录，仅 UPDATE cover 字段，保留用户可能的 is_favorite 等状态。
  static Future<void> reseedBuiltinCovers(Database db) async {
    final templates = TemplateRegistry.allTemplates;
    final batch = db.batch();
    for (final t in templates) {
      batch.update(
        Tables.customTemplates,
        {Tables.colCover: t.meta.cover},
        where: '${Tables.colId} = ? AND ${Tables.colIsBuiltin} = ?',
        whereArgs: [t.meta.id, 1],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 预置 7 个系统分类（v14 迁移 + onCreate 调用）。
  ///
  /// 与内置 7 类 key 严格对齐（portrait/landscape/food/street/night/macro/still-life），
  /// 保证离线场景下分类瀑布流永远可展示。iconUrl 留空表示使用 Flutter 端内置 Material Icons 回退映射。
  /// v17: 新增 parent_key=NULL, level=1 字段（三级树形分类的一级节点）。
  /// 使用 INSERT OR REPLACE 保证幂等：重复调用不会报错，会覆盖已存在的系统分类。
  static Future<void> seedCategories(Database db) async {
    const categories = <Map<String, Object?>>[
      {
        Tables.colKey: 'portrait',
        Tables.colName: '人像',
        Tables.colParentKey: null,
        Tables.colLevel: 1,
        Tables.colIconUrl: '',
        Tables.colSortOrder: 1,
        Tables.colIsSystem: 1,
        Tables.colIsActive: 1,
        Tables.colUpdatedAt: 0,
      },
      {
        Tables.colKey: 'landscape',
        Tables.colName: '风光',
        Tables.colParentKey: null,
        Tables.colLevel: 1,
        Tables.colIconUrl: '',
        Tables.colSortOrder: 2,
        Tables.colIsSystem: 1,
        Tables.colIsActive: 1,
        Tables.colUpdatedAt: 0,
      },
      {
        Tables.colKey: 'food',
        Tables.colName: '美食',
        Tables.colParentKey: null,
        Tables.colLevel: 1,
        Tables.colIconUrl: '',
        Tables.colSortOrder: 3,
        Tables.colIsSystem: 1,
        Tables.colIsActive: 1,
        Tables.colUpdatedAt: 0,
      },
      {
        Tables.colKey: 'street',
        Tables.colName: '街拍',
        Tables.colParentKey: null,
        Tables.colLevel: 1,
        Tables.colIconUrl: '',
        Tables.colSortOrder: 4,
        Tables.colIsSystem: 1,
        Tables.colIsActive: 1,
        Tables.colUpdatedAt: 0,
      },
      {
        Tables.colKey: 'night',
        Tables.colName: '夜景',
        Tables.colParentKey: null,
        Tables.colLevel: 1,
        Tables.colIconUrl: '',
        Tables.colSortOrder: 5,
        Tables.colIsSystem: 1,
        Tables.colIsActive: 1,
        Tables.colUpdatedAt: 0,
      },
      {
        Tables.colKey: 'macro',
        Tables.colName: '微距',
        Tables.colParentKey: null,
        Tables.colLevel: 1,
        Tables.colIconUrl: '',
        Tables.colSortOrder: 6,
        Tables.colIsSystem: 1,
        Tables.colIsActive: 1,
        Tables.colUpdatedAt: 0,
      },
      {
        Tables.colKey: 'still-life',
        Tables.colName: '静物',
        Tables.colParentKey: null,
        Tables.colLevel: 1,
        Tables.colIconUrl: '',
        Tables.colSortOrder: 7,
        Tables.colIsSystem: 1,
        Tables.colIsActive: 1,
        Tables.colUpdatedAt: 0,
      },
    ];
    final batch = db.batch();
    for (final c in categories) {
      batch.insert(
        Tables.templateCategories,
        c,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// 预置所有二三级系统分类（v17 迁移 + onCreate 调用）。
  ///
  /// 对应 spec §11.3 的完整分类树：
  /// - 二级（level=2, parent_key=一级key）：视觉风格，如 japanese/emotional/film...
  /// - 三级（level=3, parent_key=二级key）：拍摄方式，如 normal/selfie/wide...
  ///
  /// 使用 INSERT OR IGNORE 配合 UNIQUE(key, parent_key) 约束保证幂等：
  /// 重复调用不会报错，已存在的记录保留不动（不覆盖 updatedAt）。
  static Future<void> seedStyleMethodCategories(Database db) async {
    // 二级分类（level=2）：(parentKey, key, name, sortOrder)
    const styles = <List<Object>>[
      // portrait 下 21 个二级
      ['portrait', 'japanese', '日系', 1],
      ['portrait', 'emotional', '情绪', 2],
      ['portrait', 'film', '胶片', 3],
      ['portrait', 'western', '欧美', 4],
      ['portrait', 'ccd_retro', 'CCD复古', 5],
      ['portrait', 'hk_noir', '港风Noir', 6],
      ['portrait', 'japanese_fresh', '日系清新', 7],
      ['portrait', 'cream_healing', '奶油治愈', 8],
      ['portrait', 'chinese_classical', '中式古典', 9],
      ['portrait', 'french_lazy', '法式慵懒', 10],
      ['portrait', 'morandi_minimal', '莫兰迪极简', 11],
      ['portrait', 'dark_indoor', '暗调室内', 12],
      ['portrait', 'neon_city', '霓虹都市', 13],
      ['portrait', 'fresh_green', '清新绿意', 14],
      ['portrait', 'y2k', 'Y2K千禧', 15],
      ['portrait', 'anime_dream', '动漫梦境', 16],
      ['portrait', 'blue_night', '蓝色之夜', 17],
      ['portrait', 'purple_dusk', '紫色黄昏', 18],
      ['portrait', 'foodie_portrait', '美食人像', 19],
      ['portrait', 'sweet_girl', '甜美少女', 20],
      ['portrait', 'elegant_lady', '优雅女士', 21],
      // landscape 下 2 个二级
      ['landscape', 'fresh', '清新', 1],
      ['landscape', 'epic', '大气', 2],
      // food 下 2 个二级
      ['food', 'overhead', '俯拍', 1],
      ['food', 'closeup', '特写', 2],
      // street 下 2 个二级
      ['street', 'casual', '随性', 1],
      ['street', 'geometric', '几何', 2],
      // night 下 2 个二级
      ['night', 'neon', '霓虹', 1],
      ['night', 'starry', '星空', 2],
      // macro 下 2 个二级
      ['macro', 'nature', '自然', 1],
      ['macro', 'object', '物品', 2],
      // still-life 下 2 个二级
      ['still-life', 'minimal', '极简', 1],
      ['still-life', 'flat', '扁平', 2],
    ];

    // 三级分类（level=3）：(parentKey, key, name, sortOrder)
    const methods = <List<Object>>[
      // japanese 下
      ['japanese', 'normal', '他拍', 1],
      ['japanese', 'selfie', '自拍', 2],
      ['japanese', 'overhead', '俯拍', 3],
      // emotional 下
      ['emotional', 'wide', '远景', 1],
      ['emotional', 'selfie', '自拍', 2],
      // film 下
      ['film', 'normal', '他拍', 1],
      ['film', 'selfie', '自拍', 2],
      // western 下
      ['western', 'normal', '他拍', 1],
      ['western', 'wide', '远景', 2],
      // ccd_retro 下
      ['ccd_retro', 'half_body', '半身', 1],
      // hk_noir 下
      ['hk_noir', 'half_body', '半身', 1],
      // japanese_fresh 下
      ['japanese_fresh', 'seven_body', '七分身', 1],
      // cream_healing 下
      ['cream_healing', 'half_body', '半身', 1],
      // chinese_classical 下
      ['chinese_classical', 'full_body', '全身', 1],
      // french_lazy 下
      ['french_lazy', 'half_body', '半身', 1],
      // morandi_minimal 下
      ['morandi_minimal', 'half_body', '半身', 1],
      // dark_indoor 下
      ['dark_indoor', 'half_body', '半身', 1],
      // neon_city 下
      ['neon_city', 'half_body', '半身', 1],
      // fresh_green 下
      ['fresh_green', 'full_body', '全身', 1],
      // y2k 下
      ['y2k', 'half_body', '半身', 1],
      // anime_dream 下
      ['anime_dream', 'full_body', '全身', 1],
      // blue_night 下
      ['blue_night', 'seven_body', '七分身', 1],
      // purple_dusk 下
      ['purple_dusk', 'half_body', '半身', 1],
      // foodie_portrait 下
      ['foodie_portrait', 'half_body', '半身', 1],
      // sweet_girl 下
      ['sweet_girl', 'half_body', '半身', 1],
      // elegant_lady 下
      ['elegant_lady', 'seven_body', '七分身', 1],
      // fresh(landscape) 下
      ['fresh', 'wide', '远景', 1],
      ['fresh', 'flat', '平拍', 2],
      // epic 下
      ['epic', 'wide', '远景', 1],
      ['epic', 'overhead', '俯拍', 2],
      // overhead(food) 下
      ['overhead', 'flat', '平拍', 1],
      ['overhead', 'overhead', '俯拍', 2],
      // closeup 下
      ['closeup', 'macro', '微距', 1],
      ['closeup', 'detail', '细节', 2],
      // casual 下
      ['casual', 'normal', '随拍', 1],
      ['casual', 'wide', '远景', 2],
      // geometric 下
      ['geometric', 'wide', '远景', 1],
      ['geometric', 'overhead', '俯拍', 2],
      // neon(night) 下
      ['neon', 'normal', '他拍', 1],
      ['neon', 'wide', '远景', 2],
      // nature 下
      ['nature', 'macro', '微距', 1],
      // minimal 下
      ['minimal', 'single', '单品', 1],
    ];

    final batch = db.batch();
    for (final s in styles) {
      batch.insert(
        Tables.templateCategories,
        {
          Tables.colKey: s[1] as String,
          Tables.colName: s[2] as String,
          Tables.colParentKey: s[0] as String,
          Tables.colLevel: 2,
          Tables.colIconUrl: '',
          Tables.colSortOrder: s[3] as int,
          Tables.colIsSystem: 1,
          Tables.colIsActive: 1,
          Tables.colUpdatedAt: 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    for (final m in methods) {
      batch.insert(
        Tables.templateCategories,
        {
          Tables.colKey: m[1] as String,
          Tables.colName: m[2] as String,
          Tables.colParentKey: m[0] as String,
          Tables.colLevel: 3,
          Tables.colIconUrl: '',
          Tables.colSortOrder: m[3] as int,
          Tables.colIsSystem: 1,
          Tables.colIsActive: 1,
          Tables.colUpdatedAt: 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
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
