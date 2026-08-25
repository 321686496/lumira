// lib/features/capture/data/template_registry.dart
import '../domain/photo_template.dart';
import 'templates/index.dart';

class TemplateRegistry {
  TemplateRegistry._();

  static const Map<String, PhotoTemplate> _templates = {
    'soft_portrait': softPortraitTemplate,
    'golden_landscape': goldenLandscapeTemplate,
    'cafe_portrait': cafePortraitTemplate,
    'film_vintage': filmVintageTemplate,
    'food_flat_lay': foodFlatLayTemplate,
    'indoor_still_life': indoorStillLifeTemplate,
    'macro_flower': macroFlowerTemplate,
    'neon_portrait': neonPortraitTemplate,
    'night_cityscape': nightCityscapeTemplate,
    'street_bw': streetBwTemplate,
    'sunset_silhouette': sunsetSilhouetteTemplate,
    'urban_architecture': urbanArchitectureTemplate,
    // 新增 17 款人像拍照模板（2026-08-04 重构）
    'ccd_retro_portrait': ccdRetroPortraitTemplate,
    'hk_noir_portrait': hkNoirPortraitTemplate,
    'japanese_fresh_portrait': japaneseFreshPortraitTemplate,
    'cream_healing_portrait': creamHealingPortraitTemplate,
    'chinese_classical_portrait': chineseClassicalPortraitTemplate,
    'french_lazy_portrait': frenchLazyPortraitTemplate,
    'morandi_minimal_portrait': morandiMinimalPortraitTemplate,
    'dark_indoor_portrait': darkIndoorPortraitTemplate,
    'neon_city_portrait': neonCityPortraitTemplate,
    'fresh_green_portrait': freshGreenPortraitTemplate,
    'y2k_portrait': y2kPortraitTemplate,
    'anime_dream_portrait': animeDreamPortraitTemplate,
    'blue_night_portrait': blueNightPortraitTemplate,
    'purple_dusk_portrait': purpleDuskPortraitTemplate,
    'foodie_portrait': foodiePortraitTemplate,
    'sweet_girl_portrait': sweetGirlPortraitTemplate,
    'elegant_lady_portrait': elegantLadyPortraitTemplate,
    // 新增 12 款非人像内置模板（2026-08-24补充）
    'mountain_dawn': mountainDawnTemplate,
    'seaside_dusk': seasideDuskTemplate,
    'dessert_closeup': dessertCloseupTemplate,
    'cafe_table': cafeTableTemplate,
    'rainy_neon_street': rainyNeonStreetTemplate,
    'architectural_lines': architecturalLinesTemplate,
    'city_lights_trail': cityLightsTrailTemplate,
    'starry_desert': starryDesertTemplate,
    'dew_moss': dewMossTemplate,
    'jewelry_closeup': jewelryCloseupTemplate,
    'ceramic_vessel': ceramicVesselTemplate,
    'magazine_flat': magazineFlatTemplate,
    // 新增 29 款非人像内置变体模板（2026-08-24 补全 12 节风格节点）
    'fresh_lake': freshLakeTemplate,
    'fresh_flower_field': freshFlowerFieldTemplate,
    'epic_valley': epicValleyTemplate,
    'epic_sea': epicSeaTemplate,
    'overhead_brunch': overheadBrunchTemplate,
    'overhead_dessert_table': overheadDessertTableTemplate,
    'closeup_soup': closeupSoupTemplate,
    'closeup_sushi': closeupSushiTemplate,
    'closeup_pizza': closeupPizzaTemplate,
    'casual_crosswalk': casualCrosswalkTemplate,
    'casual_market': casualMarketTemplate,
    'geometric_shadow': geometricShadowTemplate,
    'geometric_stairs': geometricStairsTemplate,
    'geometric_facade': geometricFacadeTemplate,
    'neon_storefront': neonStorefrontTemplate,
    'neon_river': neonRiverTemplate,
    'starry_milkyway': starryMilkywayTemplate,
    'starry_meteor': starryMeteorTemplate,
    'starry_campsite': starryCampsiteTemplate,
    'nature_butterfly': natureButterflyTemplate,
    'nature_bees': natureBeesTemplate,
    'object_watch': objectWatchTemplate,
    'object_leaf': objectLeafTemplate,
    'object_coin': objectCoinTemplate,
    'minimal_book': minimalBookTemplate,
    'minimal_fruit': minimalFruitTemplate,
    'flat_sonboc': flatSonbocTemplate,
    'flat_tshirt': flatTshirtTemplate,
    'flat_cosmetics': flatCosmeticsTemplate,
    // 新增 15 款人像模板批量变体（2026-08-24 emotional_film / scene_portrait）
    'emotional_selfie': emotionalSelfieTemplate,
    'emotional_half': emotionalHalfTemplate,
    'emotional_corridor': emotionalCorridorTemplate,
    'film_selfie': filmSelfieTemplate,
    'film_side': filmSideTemplate,
    'film_wide': filmWideTemplate,
    'ccd_retro_selfie': ccdRetroSelfieTemplate,
    'ccd_retro_he': ccdRetroHeTemplate,
    'ccd_retro_side': ccdRetroSideTemplate,
    'foodie_he': foodieHeTemplate,
    'foodie_overhead': foodieOverheadTemplate,
    'foodie_side': foodieSideTemplate,
    'elegant_lady_he': elegantLadyHeTemplate,
    'elegant_lady_side': elegantLadySideTemplate,
    'elegant_lady_wide': elegantLadyWideTemplate,
    // 新增 21 款人像模板批量变体二（2026-08-24 urban_trend / retro_nostalgia）
    'neon_city_selfie': neonCitySelfieTemplate,
    'neon_city_wide': neonCityWideTemplate,
    'y2k_selfie': y2kSelfieTemplate,
    'y2k_he': y2kHeTemplate,
    'y2k_side': y2kSideTemplate,
    'dark_indoor_he': darkIndoorHeTemplate,
    'dark_indoor_side': darkIndoorSideTemplate,
    'dark_indoor_low': darkIndoorLowTemplate,
    'western_street': westernStreetTemplate,
    'western_wide': westernWideTemplate,
    'western_side': westernSideTemplate,
    'western_half': westernHalfTemplate,
    'hk_noir_he': hkNoirHeTemplate,
    'hk_noir_wide': hkNoirWideTemplate,
    'hk_noir_side': hkNoirSideTemplate,
    'french_lazy_he': frenchLazyHeTemplate,
    'french_lazy_side': frenchLazySideTemplate,
    'french_lazy_overhead': frenchLazyOverheadTemplate,
    'chinese_classical_wide': chineseClassicalWideTemplate,
    'chinese_classical_he': chineseClassicalHeTemplate,
    'chinese_classical_side': chineseClassicalSideTemplate,
    // 新增 26 款人像 4-variant 变体（2026-08-24 fresh_healing / dreamy_night 补齐）
    'japanese_golden_hour': japaneseGoldenHourTemplate,
    'japanese_tulip': japaneseTulipTemplate,
    'japanese_fresh_beach': japaneseFreshBeachTemplate,
    'japanese_fresh_meadow': japaneseFreshMeadowTemplate,
    'japanese_fresh_side': japaneseFreshSideTemplate,
    'cream_healing_window': creamHealingWindowTemplate,
    'cream_healing_overhead': creamHealingOverheadTemplate,
    'cream_healing_side': creamHealingSideTemplate,
    'fresh_green_park': freshGreenParkTemplate,
    'fresh_green_overhead': freshGreenOverheadTemplate,
    'fresh_green_courtyard': freshGreenCourtyardTemplate,
    'sweet_girl_selfie': sweetGirlSelfieTemplate,
    'sweet_girl_dress': sweetGirlDressTemplate,
    'sweet_girl_side': sweetGirlSideTemplate,
    'morandi_minimal_he': morandiMinimalHeTemplate,
    'morandi_minimal_side': morandiMinimalSideTemplate,
    'morandi_minimal_overhead': morandiMinimalOverheadTemplate,
    'anime_tender_girl_side': animeTenderGirlSideTemplate,
    'anime_tender_girl_overhead': animeTenderGirlOverheadTemplate,
    'anime_tender_girl_two': animeTenderGirlTwoTemplate,
    'blue_night_wide': blueNightWideTemplate,
    'blue_night_he': blueNightHeTemplate,
    'blue_night_side': blueNightSideTemplate,
    'purple_dusk_he': purpleDuskHeTemplate,
    'purple_dusk_wide': purpleDuskWideTemplate,
    'purple_dusk_side': purpleDuskSideTemplate,
  };

  static PhotoTemplate? getTemplate(String id) {
    final tpl = _suitesById[id];
    if (tpl == null) return null;
    return tpl.copyWith();
  }

  // ---- 套归并（Phase 5）----
  // 内置模板按「分类（type+majorStyle+style）+ 共享配置」归并为套：
  // 每个套 = 一个 PhotoTemplate，images = 各成员封面（[0] 即封面），poses = 各成员姿势。
  // 合并后的套映射到其成员的全部原始 id，故 getTemplate(id) 对任意成员 id 均返回所属套。

  static final Map<String, PhotoTemplate> _suitesById = _buildSuitesById();

  static List<PhotoTemplate> get allTemplates =>
      _suitesById.values.toSet().map((t) => t.copyWith()).toList();

  static List<PhotoTemplate> getRecentTemplates(int count) =>
      allTemplates.take(count).toList();

  /// 将 [_templates] 按归并 key 分组，产出「新模板 id → 套」映射。
  static Map<String, PhotoTemplate> _buildSuitesById() {
    final byKey = <String, List<String>>{};
    for (final id in _templates.keys) {
      final key = _suiteKey(_templates[id]!);
      byKey.putIfAbsent(key, () => []).add(id);
    }
    final result = <String, PhotoTemplate>{};
    for (final members in byKey.values) {
      final suite = _mergeSuite(members);
      for (final id in members) {
        result[id] = suite;
      }
    }
    return result;
  }

  /// 归并 key = 分类三元组 + 共享配置签名。
  static String _suiteKey(PhotoTemplate t) {
    final c = t.meta.classification;
    return '${c.type}|${c.majorStyle}|${c.style}|${_sharedConfigSig(t)}';
  }

  /// 共享配置签名：composition / camera / sceneGuide / postProcess 关键参数。
  static String _sharedConfigSig(PhotoTemplate t) =>
      '${t.composition.toJson()}|${t.camera.toJson()}|'
      '${_sceneGuideSig(t.sceneGuide)}|${t.postProcess.toJson()}';

  static String _sceneGuideSig(SceneGuide s) =>
      '${s.lightDirection}|${s.shootingDistance}|${s.background}|'
      '${s.props}|${s.bestTime}|${s.tips}';

  /// 将同 key 的成员归并为一个套。
  /// id/name 取归并组首个成员的（模板名须具体，不用纯风格名）；
  /// images = 各成员封面（[0] 为封面），poses = 各成员姿势。
  static PhotoTemplate _mergeSuite(List<String> memberIds) {
    final first = _templates[memberIds.first]!;
    final images = <TemplateImage>[];
    final poses = <Pose>[];
    for (final id in memberIds) {
      final t = _templates[id]!;
      images.addAll(t.meta.images);
      poses.addAll(t.poses);
    }
    return first.copyWith(
      meta: first.meta.copyWith(images: images),
      poses: poses,
    );
  }
}
