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
