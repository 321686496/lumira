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

  /// 预置所有二三四级系统分类（v17 迁移 + onCreate 调用；v37 重整人像为四级）。
  ///
  /// 对齐后端 009 迁移的四级树形结构（spec 2026-08-24 重整）：
  /// - 人像 portrait：大风格 majorStyle（L2）→ 子风格 subStyle（L3）→ 方法 method（L4）
  /// - 非人像题材：保持浅层（二级=风格 style → 三级=方法 method）
  ///
  /// 使用 INSERT OR IGNORE 配合 UNIQUE(key, parent_key) 约束保证幂等：
  /// 重复调用不会报错（同名已存在则保留，不覆盖 updatedAt）。
  static Future<void> seedStyleMethodCategories(Database db) async {
    // 人像大风格（level=2, parent=portrait）：(parentKey, key, name, sortOrder)
    const majorStyles = <List<Object>>[
      ['portrait', 'fresh_healing', '清新治愈', 1],
      ['portrait', 'emotional_film', '情绪胶片', 2],
      ['portrait', 'retro_nostalgia', '复古怀旧', 3],
      ['portrait', 'urban_trend', '都市潮流', 4],
      ['portrait', 'dreamy_night', '梦幻夜色', 5],
      ['portrait', 'scene_portrait', '场景人像', 6],
    ];

    // 人像子风格（level=3, parent=大风格）：(parentKey, key, name, sortOrder)
    const portraitSubStyles = <List<Object>>[
      // fresh_healing 清新治愈
      ['fresh_healing', 'japanese', '日系', 1],
      ['fresh_healing', 'japanese_fresh', '日系清新', 7],
      ['fresh_healing', 'cream_healing', '奶油治愈', 8],
      ['fresh_healing', 'fresh_green', '清新绿意', 14],
      ['fresh_healing', 'sweet_girl', '甜美少女', 20],
      ['fresh_healing', 'morandi_minimal', '莫兰迪极简', 11],
      ['fresh_healing', 'anime_tender', '动漫温柔青', 22],
      // emotional_film 情绪胶片
      ['emotional_film', 'emotional', '情绪', 2],
      ['emotional_film', 'film', '胶片', 3],
      ['emotional_film', 'ccd_retro', 'CCD复古', 5],
      // retro_nostalgia 复古怀旧
      ['retro_nostalgia', 'hk_noir', '港风Noir', 6],
      ['retro_nostalgia', 'french_lazy', '法式慵懒', 10],
      ['retro_nostalgia', 'chinese_classical', '中式古典', 9],
      // urban_trend 都市潮流
      ['urban_trend', 'western', '欧美', 4],
      ['urban_trend', 'neon_city', '霓虹都市', 13],
      ['urban_trend', 'y2k', 'Y2K千禧', 15],
      ['urban_trend', 'dark_indoor', '暗调室内', 12],
      // dreamy_night 梦幻夜色
      ['dreamy_night', 'blue_night', '蓝色之夜', 17],
      ['dreamy_night', 'purple_dusk', '紫色黄昏', 18],
      // scene_portrait 场景人像
      ['scene_portrait', 'foodie_portrait', '美食人像', 19],
      ['scene_portrait', 'elegant_lady', '优雅女士', 21],
    ];

    // 非人像二级风格（level=2, parent=题材）：(parentKey, key, name, sortOrder)
    const nonPortraitStyles = <List<Object>>[
      // landscape
      ['landscape', 'fresh', '清新', 1],
      ['landscape', 'epic', '大气', 2],
      // food
      ['food', 'overhead', '俯拍', 1],
      ['food', 'closeup', '特写', 2],
      // street
      ['street', 'casual', '随性', 1],
      ['street', 'geometric', '几何', 2],
      // night
      ['night', 'neon', '霓虹', 1],
      ['night', 'starry', '星空', 2],
      // macro
      ['macro', 'nature', '自然', 1],
      ['macro', 'object', '物品', 2],
      // still-life
      ['still-life', 'minimal', '极简', 1],
      ['still-life', 'flat', '扁平', 2],
    ];

    // 方法：人像（level=4, parent=子风格）：(parentKey, key, name, sortOrder)
    // 每风格叶节点下 4 款具体模板用方法(构图/拍法)区分，故每个子风格补 4 个方法。
    const portraitMethods = <List<Object>>[
      // japanese 日系
      ['japanese', 'normal', '他拍', 1],
      ['japanese', 'selfie', '自拍', 2],
      ['japanese', 'overhead', '俯拍', 3],
      ['japanese', 'side', '侧拍', 4],
      // japanese_fresh 日系清新
      ['japanese_fresh', 'seven_body', '七分身', 1],
      ['japanese_fresh', 'selfie', '自拍', 2],
      ['japanese_fresh', 'wide', '远景', 3],
      ['japanese_fresh', 'side', '侧拍', 4],
      // cream_healing 奶油治愈
      ['cream_healing', 'half_body', '半身', 1],
      ['cream_healing', 'normal', '他拍', 2],
      ['cream_healing', 'overhead', '俯拍', 3],
      ['cream_healing', 'side', '侧拍', 4],
      // fresh_green 清新绿意
      ['fresh_green', 'full_body', '全身', 1],
      ['fresh_green', 'wide', '远景', 2],
      ['fresh_green', 'overhead', '俯拍', 3],
      ['fresh_green', 'normal', '他拍', 4],
      // sweet_girl 甜美少女
      ['sweet_girl', 'half_body', '半身', 1],
      ['sweet_girl', 'selfie', '自拍', 2],
      ['sweet_girl', 'full_body', '全身', 3],
      ['sweet_girl', 'side', '侧拍', 4],
      // morandi_minimal 莫兰迪极简
      ['morandi_minimal', 'half_body', '半身', 1],
      ['morandi_minimal', 'normal', '他拍', 2],
      ['morandi_minimal', 'side', '侧拍', 3],
      ['morandi_minimal', 'overhead', '俯拍', 4],
      // anime_tender 动漫温柔青
      ['anime_tender', 'full_body', '全身', 1],
      ['anime_tender', 'side', '侧拍', 2],
      ['anime_tender', 'overhead', '俯拍', 3],
      ['anime_tender', 'normal', '他拍', 4],
      // emotional 情绪
      ['emotional', 'wide', '远景', 1],
      ['emotional', 'selfie', '自拍', 2],
      ['emotional', 'half_body', '半身', 3],
      ['emotional', 'normal', '他拍', 4],
      // film 胶片
      ['film', 'normal', '他拍', 1],
      ['film', 'selfie', '自拍', 2],
      ['film', 'side', '侧拍', 3],
      ['film', 'wide', '远景', 4],
      // ccd_retro CCD复古
      ['ccd_retro', 'half_body', '半身', 1],
      ['ccd_retro', 'selfie', '自拍', 2],
      ['ccd_retro', 'normal', '他拍', 3],
      ['ccd_retro', 'side', '侧拍', 4],
      // western 欧美
      ['western', 'normal', '他拍', 1],
      ['western', 'wide', '远景', 2],
      ['western', 'side', '侧拍', 3],
      ['western', 'half_body', '半身', 4],
      // neon_city 霓虹都市
      ['neon_city', 'half_body', '半身', 1],
      ['neon_city', 'normal', '他拍', 2],
      ['neon_city', 'selfie', '自拍', 3],
      ['neon_city', 'wide', '远景', 4],
      // y2k Y2K千禧
      ['y2k', 'half_body', '半身', 1],
      ['y2k', 'selfie', '自拍', 2],
      ['y2k', 'normal', '他拍', 3],
      ['y2k', 'side', '侧拍', 4],
      // dark_indoor 暗调室内
      ['dark_indoor', 'half_body', '半身', 1],
      ['dark_indoor', 'normal', '他拍', 2],
      ['dark_indoor', 'side', '侧拍', 3],
      ['dark_indoor', 'low_angle', '仰拍', 4],
      // hk_noir 港风Noir
      ['hk_noir', 'half_body', '半身', 1],
      ['hk_noir', 'normal', '他拍', 2],
      ['hk_noir', 'wide', '远景', 3],
      ['hk_noir', 'side', '侧拍', 4],
      // french_lazy 法式慵懒
      ['french_lazy', 'half_body', '半身', 1],
      ['french_lazy', 'normal', '他拍', 2],
      ['french_lazy', 'side', '侧拍', 3],
      ['french_lazy', 'overhead', '俯拍', 4],
      // chinese_classical 中式古典
      ['chinese_classical', 'full_body', '全身', 1],
      ['chinese_classical', 'wide', '远景', 2],
      ['chinese_classical', 'normal', '他拍', 3],
      ['chinese_classical', 'side', '侧拍', 4],
      // blue_night 蓝色之夜
      ['blue_night', 'seven_body', '七分身', 1],
      ['blue_night', 'wide', '远景', 2],
      ['blue_night', 'normal', '他拍', 3],
      ['blue_night', 'side', '侧拍', 4],
      // purple_dusk 紫色黄昏
      ['purple_dusk', 'half_body', '半身', 1],
      ['purple_dusk', 'normal', '他拍', 2],
      ['purple_dusk', 'wide', '远景', 3],
      ['purple_dusk', 'side', '侧拍', 4],
      // foodie_portrait 美食人像
      ['foodie_portrait', 'half_body', '半身', 1],
      ['foodie_portrait', 'normal', '他拍', 2],
      ['foodie_portrait', 'overhead', '俯拍', 3],
      ['foodie_portrait', 'side', '侧拍', 4],
      // elegant_lady 优雅女士
      ['elegant_lady', 'seven_body', '七分身', 1],
      ['elegant_lady', 'normal', '他拍', 2],
      ['elegant_lady', 'side', '侧拍', 3],
      ['elegant_lady', 'wide', '远景', 4],
    ];

    // 方法：非人像（level=3, parent=二级风格）：(parentKey, key, name, sortOrder)
    const nonPortraitMethods = <List<Object>>[
      ['fresh', 'wide', '远景', 1],
      ['fresh', 'flat', '平拍', 2],
      ['epic', 'wide', '远景', 1],
      ['epic', 'overhead', '俯拍', 2],
      ['overhead', 'flat', '平拍', 1],
      ['overhead', 'overhead', '俯拍', 2],
      ['closeup', 'macro', '微距', 1],
      ['closeup', 'detail', '细节', 2],
      ['casual', 'normal', '随拍', 1],
      ['casual', 'wide', '远景', 2],
      ['geometric', 'wide', '远景', 1],
      ['geometric', 'overhead', '俯拍', 2],
      ['neon', 'normal', '他拍', 1],
      ['neon', 'wide', '远景', 2],
      ['starry', 'wide', '远景', 1],
      ['nature', 'macro', '微距', 1],
      ['object', 'macro', '微距', 1],
      ['object', 'detail', '细节', 2],
      ['minimal', 'single', '单品', 1],
      ['flat', 'flat', '扁平', 1],
    ];

    final batch = db.batch();

    void insertRows(
      Iterable<List<Object>> rows,
      int level,
    ) {
      for (final r in rows) {
        batch.insert(
          Tables.templateCategories,
          {
            Tables.colKey: r[1] as String,
            Tables.colName: r[2] as String,
            Tables.colParentKey: r[0] as String,
            Tables.colLevel: level,
            Tables.colIconUrl: '',
            Tables.colSortOrder: r[3] as int,
            Tables.colIsSystem: 1,
            Tables.colIsActive: 1,
            Tables.colUpdatedAt: 0,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }

    insertRows(majorStyles, 2);                    // 大风格（人像）
    insertRows(portraitSubStyles, 3);              // 子风格（人像）
    insertRows(nonPortraitStyles, 2);              // 风格（非人像）
    insertRows(portraitMethods, 4);                // 方法（人像）
    insertRows(nonPortraitMethods, 3);             // 方法（非人像）

    await batch.commit(noResult: true);
  }

  /// 重整存量库中的人像分类为四级（v37 迁移 + onCreate 前调用）。
  ///
  /// 旧版本（v17 结构）把人像子风格直接挂在 portrait 下（L2），大风格缺失，
  /// 导致内置模板引用的大风格（fresh_healing 等）在本地分类树中不存在。
  /// 此方法先删除人像子树原有记录（非人像不动），再重新播种四级结构。
  static Future<void> reseedPortraitCategoriesTo4level(Database db) async {
    const majorStyles = <String>[
      'fresh_healing', 'emotional_film', 'retro_nostalgia',
      'urban_trend', 'dreamy_night', 'scene_portrait',
    ];
    const portraitSubStyles = <String>[
      'japanese', 'japanese_fresh', 'cream_healing', 'fresh_green',
      'sweet_girl', 'morandi_minimal', 'emotional', 'film', 'ccd_retro',
      'hk_noir', 'french_lazy', 'chinese_classical', 'western',
      'neon_city', 'y2k', 'dark_indoor', 'blue_night', 'purple_dusk',
      'anime_tender', 'foodie_portrait', 'elegant_lady',
    ];

    final stylePh = List.generate(
      majorStyles.length, (_) => '?').join(',');
    final subPh =
        List.generate(portraitSubStyles.length, (_) => '?').join(',');

    // 1. 删除人像大风格（L2, parent=portrait）——旧三级结构下不存在此项，作为兜底清理
    await db.delete(
      Tables.templateCategories,
      where: '${Tables.colLevel} = 2 AND ${Tables.colParentKey} = \'portrait\' '
          'AND ${Tables.colKey} IN ($stylePh)',
      whereArgs: majorStyles,
    );
    // 2. 删除旧三级结构中的人像子风格（L2, parent=portrait）。
    //    若遗漏删除，其与新四级结构中（parent=大风格）的同 key 子风格并存，
    //    会造成分类树重复、模板引用的分类存在歧义。
    await db.delete(
      Tables.templateCategories,
      where: '${Tables.colLevel} = 2 AND ${Tables.colParentKey} = \'portrait\' '
          'AND ${Tables.colKey} IN ($subPh)',
      whereArgs: portraitSubStyles,
    );
    // 3. 删除新四级结构中（parent=大风格）的人像子风格
    await db.delete(
      Tables.templateCategories,
      where: '${Tables.colParentKey} IN ($stylePh)',
      whereArgs: majorStyles,
    );
    // 4. 删除人像方法（parent=子风格）——覆盖旧三级结构与新四级结构中的方法记录
    await db.delete(
      Tables.templateCategories,
      where: '${Tables.colParentKey} IN ($subPh)',
      whereArgs: portraitSubStyles,
    );

    // 5. 重新播种四级结构
    await seedStyleMethodCategories(db);
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
