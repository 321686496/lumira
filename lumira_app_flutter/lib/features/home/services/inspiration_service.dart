// lib/features/home/services/inspiration_service.dart
//
// 今日灵感服务
// 输入：当前时间 + 用户最近 30 天主导 category + 后端天气
// 输出：HeroInspiration（dateText / description / weatherText）
//
// 智能文案规则（本地规则模板）：
// 时段 × 主导 category × 天气状态 → 文案
// - 时段：晨（5-10）/ 午（10-14）/ 暮（14-18）/ 夜（18-5）
// - category：portrait/landscape/food/street/night/macro/still-life/无数据
// - 天气：晴/多云/阴/雨/雪/雾

import 'package:flutter/foundation.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/network/api_client.dart';
import '../data/inspiration_models.dart';
import '../data/inspiration_rules.dart';

/// 黄金时刻计算简化版：日落前 1 小时
/// 返回 "HH:mm" 格式（本地墙钟时刻），失败返回空字符串
/// 注意：后端返回 ISO 带时区偏移（如 +08:00），Dart DateTime.parse 会解析成 UTC，
/// 因此必须 toLocal() 取本地小时，否则 hour 会差一个时区偏移。
String _goldenHourFromSunset(String sunsetIso) {
  if (sunsetIso.isEmpty) return '';
  try {
    final sunset = DateTime.parse(sunsetIso).toLocal();
    final golden = sunset.subtract(const Duration(hours: 1));
    final hh = golden.hour.toString().padLeft(2, '0');
    final mm = golden.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  } catch (_) {
    return '';
  }
}

/// 蓝调时刻：日落后 30 分钟（本地墙钟时刻）
String _blueHourFromSunset(String sunsetIso) {
  if (sunsetIso.isEmpty) return '';
  try {
    final sunset = DateTime.parse(sunsetIso).toLocal();
    final blue = sunset.add(const Duration(minutes: 30));
    final hh = blue.hour.toString().padLeft(2, '0');
    final mm = blue.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  } catch (_) {
    return '';
  }
}

/// 是否处于"黄金时刻窗口"：日落前 1 小时到日落之间（随真实位置本地日落变化）
/// 两者均转为本地时刻后比较即时戳，避免 UTC/本地混比。
bool _inGoldenHourWindow(DateTime now, String sunsetIso) {
  if (sunsetIso.isEmpty) return false;
  try {
    final sunset = DateTime.parse(sunsetIso).toLocal();
    final start = sunset.subtract(const Duration(hours: 1));
    return !now.isBefore(start) && now.isBefore(sunset);
  } catch (_) {
    return false;
  }
}

enum _TimeSlot { morning, noon, dusk, night }

_TimeSlot _slotOf(DateTime t) {
  final h = t.hour;
  if (h >= 5 && h < 10) return _TimeSlot.morning;
  if (h >= 10 && h < 14) return _TimeSlot.noon;
  if (h >= 14 && h < 18) return _TimeSlot.dusk;
  return _TimeSlot.night;
}

const List<String> _weekdayZh = ['一', '二', '三', '四', '五', '六', '日'];

/// 取用户最近 30 天主导 category
/// 返回 null 表示无数据
Future<String?> _topCategory(GalleryDao galleryDao) async {
  // 直接用 countByCategory（DAO 内部按 template 关联统计）
  final countsAll = await galleryDao.countByCategory();
  if (countsAll.isEmpty) return null;
  final entries = countsAll.entries.where((e) => e.value > 0).toList();
  if (entries.isEmpty) return null;
  entries.sort((a, b) => b.value.compareTo(a.value));
  return entries.first.key;
}

/// 时段 → 规则令牌名
String _slotName(_TimeSlot s) {
  switch (s) {
    case _TimeSlot.morning:
      return 'morning';
    case _TimeSlot.noon:
      return 'noon';
    case _TimeSlot.dusk:
      return 'dusk';
    case _TimeSlot.night:
      return 'night';
  }
}

/// 组合生成今日灵感描述文案
/// 输入：时段 + 当月 + 温度 + 天气 + 纬度（信息不足时对应令牌为空，走兜底规则）。
String _composeDescription({
  required _TimeSlot slot,
  required int month,
  required int temperature,
  required String weather,
  double latitude = 0,
  String? category,
}) {
  final c = InspirationContext(
    slot: _slotName(slot),
    season: seasonOf(month),
    tempRange: tempRangeOf(temperature),
    weather: weather,
    region: regionOf(latitude),
    category: category,
  );
  final light = matchRule(lightRules, c, '捕捉每一束光，让日常成为习惯');
  final theme = matchRule(themeRules, c, '');
  if (theme.isEmpty || theme == light) return light;
  return '$light，$theme';
}

/// 灵感服务
class InspirationService {
  InspirationService({
    required GalleryDao galleryDao,
    required ApiClient apiClient,
  })  : _galleryDao = galleryDao,
        _apiClient = apiClient;

  final GalleryDao _galleryDao;
  final ApiClient _apiClient;

  /// 构建今日灵感
  /// 失败时返回 fallback，绝不抛异常
  Future<HeroInspiration> build() async {
    final now = DateTime.now();
    final slot = _slotOf(now);

    // 日期文本：8月5日 星期二 · 夏季 · 光线极佳
    final weekday = _weekdayZh[now.weekday - 1];
    String slotHint;
    switch (slot) {
      case _TimeSlot.morning:
        slotHint = '晨光柔均匀';
        break;
      case _TimeSlot.noon:
        slotHint = '光线强烈';
        break;
      case _TimeSlot.dusk:
        slotHint = '光线极佳';
        break;
      case _TimeSlot.night:
        slotHint = '夜色温柔';
        break;
    }
    final lightHint = '${seasonOf(now.month)} · $slotHint';
    final dateText = '${now.month}月${now.day}日 星期$weekday · $lightHint';

    // 主导 category
    String? topCat;
    try {
      topCat = await _topCategory(_galleryDao);
    } catch (e) {
      debugPrint('InspirationService topCategory failed: $e');
    }

    // 天气（失败时为空）。不再写死上海坐标：
    // 后端 /weather 在未传经纬度时按客户端 IP 反查当地天气，返回城市名与真实日出/日落。
    WeatherInfo weather = WeatherInfo.empty;
    try {
      weather = await _apiClient.get(
        '/weather',
        fromJson: (json) => WeatherInfo.fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      debugPrint('InspirationService weather fetch failed: $e');
    }

    // 描述（数据驱动规则表；处于真实位置的黄金时刻窗口内时，强化"当下最有效"建议）
    String description = _composeDescription(
      slot: slot,
      month: now.month,
      temperature: weather.temperature,
      weather: weather.condition,
      latitude: weather.latitude,
      category: topCat,
    );
    if (_inGoldenHourWindow(now, weather.sunset)) {
      final golden = _goldenHourFromSunset(weather.sunset);
      description = (golden.isNotEmpty
          ? '现在正处黄金时刻（约在 $golden），'
          : '现在正处黄金时刻，') + description;
    }

    // 天气行（含城市名 + 真实位置黄金/蓝调时刻）
    String weatherText = '';
    if (!weather.isEmpty) {
      final parts = <String>[];
      if (weather.city.isNotEmpty) parts.add(weather.city);
      parts.add('${weather.temperature}°C ${weather.condition}');
      final golden = _goldenHourFromSunset(weather.sunset);
      if (golden.isNotEmpty) {
        parts.add('黄金时刻在 $golden');
      }
      weatherText = parts.join(' · ');
    } else if (slot == _TimeSlot.dusk) {
      // 无天气数据但处于暮色时段，给出泛指提示
      weatherText = '黄金时刻即将到来';
    } else if (slot == _TimeSlot.night) {
      final blue = _blueHourFromSunset('');
      // 无 sunset 数据时不显示具体时刻
      weatherText = blue.isEmpty ? '' : '蓝调时刻 $blue';
    }

    return HeroInspiration(
      dateText: dateText,
      title: '今日灵感',
      description: description,
      weatherText: weatherText,
    );
  }
}
