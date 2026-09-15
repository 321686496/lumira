import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 首页 APP 名称艺术排版风格
///
/// 用户可在「设置 → 首页标题样式」中切换，默认 [logoEnglish]。
/// 切换后首页导航栏标题实时重建。
enum HomeWordmarkStyle {
  /// 符号标 + Lumira 英文（默认，简洁国际化）
  logoEnglish,

  /// 符号标 + Lumira + 「如画」中文（三段层次最丰富）
  logoEnglishChinese,

  /// Lumira 英文 + 「如画」中文（无 logo，纯字体艺术感）
  englishChinese,
}

/// 首页标题样式偏好
///
/// 与 [themeKeyProvider] / [uiStyleProvider] 保持一致使用 StateProvider，
/// 不引入持久化（保持架构统一）。
final homeWordmarkStyleProvider =
    StateProvider<HomeWordmarkStyle>((_) => HomeWordmarkStyle.logoEnglish);

/// 三种样式在 UI 上的展示元数据（名称 + 观感说明）
///
/// 设置页列表项与「首页标题样式」选择页共用同一份文案，
/// 避免两处各写一份导致不同步。
class HomeWordmarkLabels {
  HomeWordmarkLabels._();

  /// 样式展示名（设置页列表项右侧 value、选择页卡片标题）
  static String labelOf(HomeWordmarkStyle style) {
    switch (style) {
      case HomeWordmarkStyle.logoEnglish:
        return 'Logo + 英文';
      case HomeWordmarkStyle.logoEnglishChinese:
        return 'Logo + 英文 + 中文';
      case HomeWordmarkStyle.englishChinese:
        return '英文 + 中文';
    }
  }

  /// 观感说明（选择页卡片副标题）
  static String descriptionOf(HomeWordmarkStyle style) {
    switch (style) {
      case HomeWordmarkStyle.logoEnglish:
        return '取景器符号标搭配 Lumira 英文衬线字，留白充分、最简洁国际化。';
      case HomeWordmarkStyle.logoEnglishChinese:
        return '符号标、英文、中文三段层次，信息最完整，品牌辨识度最高。';
      case HomeWordmarkStyle.englishChinese:
        return '去掉符号标，靠衬线字体与中文「如画」的疏密对比取胜，最艺术。';
    }
  }

  /// 设置页列表项展示顺序（同时决定选择页卡片顺序）
  static const List<HomeWordmarkStyle> order = <HomeWordmarkStyle>[
    HomeWordmarkStyle.logoEnglish,
    HomeWordmarkStyle.logoEnglishChinese,
    HomeWordmarkStyle.englishChinese,
  ];
}
