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

/// 黄金时刻计算简化版：日落前 1 小时
/// 返回 "HH:mm" 格式，失败返回空字符串
String _goldenHourFromSunset(String sunsetIso) {
  if (sunsetIso.isEmpty) return '';
  try {
    final sunset = DateTime.parse(sunsetIso);
    final golden = sunset.subtract(const Duration(hours: 1));
    final hh = golden.hour.toString().padLeft(2, '0');
    final mm = golden.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  } catch (_) {
    return '';
  }
}

/// 蓝调时刻：日落后 30 分钟
String _blueHourFromSunset(String sunsetIso) {
  if (sunsetIso.isEmpty) return '';
  try {
    final sunset = DateTime.parse(sunsetIso);
    final blue = sunset.add(const Duration(minutes: 30));
    final hh = blue.hour.toString().padLeft(2, '0');
    final mm = blue.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  } catch (_) {
    return '';
  }
}

/// 是否处于"黄金时刻窗口"：日落前 1 小时到日落之间（随真实位置本地日落变化）
bool _inGoldenHourWindow(DateTime now, String sunsetIso) {
  if (sunsetIso.isEmpty) return false;
  try {
    final sunset = DateTime.parse(sunsetIso);
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

/// 智能 description 生成
String _buildDescription(_TimeSlot slot, String? category, String weather) {
  const fallback = '捕捉每一束光，让日常成为习惯';

  // 无 category 数据时使用 fallback 文案
  if (category == null) {
    switch (slot) {
      case _TimeSlot.morning:
        return '清晨光线柔和，开启今天的拍摄之旅';
      case _TimeSlot.noon:
        return '正午光强，适合在阴影或室内取景';
      case _TimeSlot.dusk:
        return '黄金时刻将至，准备好你的镜头';
      case _TimeSlot.night:
        return '夜色温柔，捕捉城市的霓虹与故事';
    }
  }

  // 按 category × slot 组合文案
  switch (category) {
    case 'portrait':
      switch (slot) {
        case _TimeSlot.morning:
          return weather == '晴'
              ? '晨光柔均匀，适合清新人像'
              : '清晨柔光下，自然光人像最佳';
        case _TimeSlot.noon:
          return '正午顶光强，建议阴影或室内人像';
        case _TimeSlot.dusk:
          return weather == '晴'
              ? '黄金时刻侧逆光，人像显瘦又自然'
              : '暮色柔光，适合情绪感人像';
        case _TimeSlot.night:
          return '夜色霓虹背景，人像故事感拉满';
      }
    case 'landscape':
      switch (slot) {
        case _TimeSlot.morning:
          return '晨雾层次丰富，风光大片时段';
        case _TimeSlot.noon:
          return '正午光线硬，风光建议加偏振镜';
        case _TimeSlot.dusk:
          return weather == '晴'
              ? '黄金时刻光线暖黄，风光最佳时段'
              : '暮色云层层次丰富，记得低角度';
        case _TimeSlot.night:
          return '蓝调时刻城市风光，长曝光出片';
      }
    case 'food':
      switch (slot) {
        case _TimeSlot.morning:
          return '晨光均匀，美食色彩还原准确';
        case _TimeSlot.noon:
          return '正午侧光，美食纹理更清晰';
        case _TimeSlot.dusk:
          return '暖色暮光，咖啡甜点更有氛围';
        case _TimeSlot.night:
          return '夜间用暖灯，避免闪光直射食物';
      }
    case 'street':
      switch (slot) {
        case _TimeSlot.morning:
          return '清晨街道人少，捕捉市井安静';
        case _TimeSlot.noon:
          return '正午光影对比强，街拍更有张力';
        case _TimeSlot.dusk:
          return '暮色人流归家，故事感最强';
        case _TimeSlot.night:
          return '夜间霓虹雨后倒影，街拍出片';
      }
    case 'night':
      return '夜色已至，长曝光与高 ISO 的平衡之道';
    case 'macro':
      switch (slot) {
        case _TimeSlot.morning:
          return '晨露未干，微距花草最佳时段';
        case _TimeSlot.noon:
          return '正午光强，微距注意阴影补光';
        case _TimeSlot.dusk:
          return '暮色柔光，微距纹理更细腻';
        case _TimeSlot.night:
          return '夜间微距需稳定光源，避免抖动';
      }
    case 'still-life':
      switch (slot) {
        case _TimeSlot.morning:
          return '晨光透过窗，静物光影最自然';
        case _TimeSlot.noon:
          return '正午柔光帘，静物色彩更准';
        case _TimeSlot.dusk:
          return '暮色暖调，静物更有氛围';
        case _TimeSlot.night:
          return '夜间单光源，静物戏剧感强';
      }
  }
  return fallback;
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

    // 日期文本：8月5日 星期二 · 光线极佳
    final weekday = _weekdayZh[now.weekday - 1];
    String lightHint;
    switch (slot) {
      case _TimeSlot.morning:
        lightHint = '晨光柔均匀';
        break;
      case _TimeSlot.noon:
        lightHint = '光线强烈';
        break;
      case _TimeSlot.dusk:
        lightHint = '光线极佳';
        break;
      case _TimeSlot.night:
        lightHint = '夜色温柔';
        break;
    }
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

    // 描述（处于真实位置的黄金时刻窗口内时，强化"当下最有效"建议）
    String description = _buildDescription(slot, topCat, weather.condition);
    if (_inGoldenHourWindow(now, weather.sunset)) {
      final golden = _goldenHourFromSunset(weather.sunset);
      description = (golden.isNotEmpty
          ? '现在是黄金时刻窗口（约 $golden 前后），'
          : '现在是黄金时刻窗口，') + description;
    }

    // 天气行（含城市名 + 真实位置黄金/蓝调时刻）
    String weatherText = '';
    if (!weather.isEmpty) {
      final parts = <String>[];
      if (weather.city.isNotEmpty) parts.add(weather.city);
      parts.add('${weather.temperature}°C ${weather.condition}');
      final golden = _goldenHourFromSunset(weather.sunset);
      if (golden.isNotEmpty) {
        parts.add('黄金时刻 $golden');
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
