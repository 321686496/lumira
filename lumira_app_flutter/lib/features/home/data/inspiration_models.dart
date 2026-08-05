// lib/features/home/data/inspiration_models.dart
//
// 今日灵感数据模型
// - WeatherInfo：后端 /weather 接口返回的简化天气信息
// - HeroInspiration：首页 HeroCard 显示的完整数据

/// 后端 /weather 接口返回结构（与 lumira-server WeatherService.WeatherResult 对齐）
class WeatherInfo {
  final int temperature;
  final String condition; // 晴/多云/阴/雨/雪/雾/阵雨/雷雨
  final String sunrise; // ISO 8601
  final String sunset; // ISO 8601
  final int fetchedAt;

  const WeatherInfo({
    required this.temperature,
    required this.condition,
    required this.sunrise,
    required this.sunset,
    required this.fetchedAt,
  });

  factory WeatherInfo.fromJson(Map<String, dynamic> json) {
    return WeatherInfo(
      temperature: (json['temperature'] as num?)?.toInt() ?? 0,
      condition: (json['condition'] as String?) ?? '晴',
      sunrise: (json['sunrise'] as String?) ?? '',
      sunset: (json['sunset'] as String?) ?? '',
      fetchedAt: (json['fetchedAt'] as num?)?.toInt() ?? 0,
    );
  }

  static const WeatherInfo empty = WeatherInfo(
    temperature: 0,
    condition: '',
    sunrise: '',
    sunset: '',
    fetchedAt: 0,
  );

  bool get isEmpty => condition.isEmpty && sunrise.isEmpty;
}

/// 今日灵感卡片数据
class HeroInspiration {
  /// 日期行文本，如「8月5日 星期二 · 光线极佳」
  final String dateText;

  /// 标题，固定为「今日灵感」
  final String title;

  /// 描述文案（基于时段+主导 category+天气动态生成）
  final String description;

  /// 天气行文本，如「28°C 晴 · 黄金时刻 16:30」
  /// 为空时 HeroCard 隐藏天气行
  final String weatherText;

  const HeroInspiration({
    required this.dateText,
    required this.title,
    required this.description,
    required this.weatherText,
  });

  static const HeroInspiration fallback = HeroInspiration(
    dateText: '',
    title: '今日灵感',
    description: '捕捉每一束光，让日常成为习惯',
    weatherText: '',
  );
}
