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
  };

  static PhotoTemplate? getTemplate(String id) {
    final tpl = _templates[id];
    if (tpl == null) return null;
    return tpl.copyWith();
  }

  static List<PhotoTemplate> get allTemplates =>
      _templates.values.map((t) => t.copyWith()).toList();

  static List<PhotoTemplate> getRecentTemplates(int count) =>
      allTemplates.take(count).toList();
}
