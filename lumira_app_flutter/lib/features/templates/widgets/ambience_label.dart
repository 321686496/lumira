import '../data/remote_template_dto.dart';

/// 将 ambience 元数据映射为中文标签（与分类 categoryLabel 风格一致）。
class AmbienceLabel {
  const AmbienceLabel._();

  static const Map<String, String> _seasons = {
    'spring': '春季',
    'summer': '夏季',
    'autumn': '秋季',
    'winter': '冬季',
  };
  static const Map<String, String> _weathers = {
    'sunny': '晴天',
    'cloudy': '多云',
    'overcast': '阴天',
    'rain': '雨天',
    'snow': '雪天',
    'fog': '雾天',
  };
  static const Map<String, String> _timeTones = {
    'goldenHour': '黄金时刻',
    'day': '白天',
    'night': '夜晚',
    'warm': '暖调',
    'cool': '冷调',
  };

  static List<String> seasonLabels(List<String> keys) =>
      keys.map((k) => _seasons[k] ?? '').where((s) => s.isNotEmpty).toList();
  static List<String> weatherLabels(List<String> keys) =>
      keys.map((k) => _weathers[k] ?? '').where((s) => s.isNotEmpty).toList();
  static List<String> timeToneLabels(List<String> keys) =>
      keys.map((k) => _timeTones[k] ?? '').where((s) => s.isNotEmpty).toList();

  /// 全部标签（季节→天气→时段），无则空列表。
  static List<String> labelsFor(RemoteTemplateAmbienceDto? a) {
    if (a == null) return const [];
    return [
      ...seasonLabels(a.seasons),
      ...weatherLabels(a.weathers),
      ...timeToneLabels(a.timeTones),
    ];
  }
}