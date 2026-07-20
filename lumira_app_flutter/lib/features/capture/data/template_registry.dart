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
