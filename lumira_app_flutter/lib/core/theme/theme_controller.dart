import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_provider.dart';
import 'theme_tokens.dart';
import 'app_theme.dart';

final themeKeyProvider = StateProvider<ThemeKey>((ref) => ThemeKey.warmWhite);
final uiStyleProvider = StateProvider<UIStyle>((ref) => UIStyle.neumorphic);

final themeTokensProvider = Provider<ThemeTokens>((ref) {
  final theme = ref.watch(themeKeyProvider);
  return ThemeTokens.of(theme);
});

final appThemeProvider = Provider<AppThemeData>((ref) {
  final tokens = ref.watch(themeTokensProvider);
  final style = ref.watch(uiStyleProvider);
  return AppThemeData(tokens: tokens, style: style);
});

/// 应用启动时从 DB 恢复持久化的主题与 UI 风格（写回 StateProvider 供全局生效）。
///
/// 在 main() 中于 runApp 前调用：DB 已在 bootstrap 阶段打开，读取近即时，
/// 可避免首帧主题闪变。
Future<void> restoreThemePreferences(ProviderContainer container) async {
  final dao = await container.read(settingsDaoProvider.future);
  container.read(themeKeyProvider.notifier).state = await dao.getThemeKey();
  container.read(uiStyleProvider.notifier).state = await dao.getUiStyle();
}

/// 切换颜色主题并持久化到本地。写入失败时静默（不影响 UI 即时生效）。
Future<void> persistTheme(WidgetRef ref, ThemeKey key) async {
  ref.read(themeKeyProvider.notifier).state = key;
  try {
    final dao = await ref.read(settingsDaoProvider.future);
    await dao.setThemeKey(key);
  } catch (_) {
    // 持久化失败静默，界面切换已生效
  }
}

/// 切换 UI 风格并持久化到本地。写入失败时静默（不影响 UI 即时生效）。
Future<void> persistUiStyle(WidgetRef ref, UIStyle style) async {
  ref.read(uiStyleProvider.notifier).state = style;
  try {
    final dao = await ref.read(settingsDaoProvider.future);
    await dao.setUiStyle(style);
  } catch (_) {
    // 持久化失败静默，界面切换已生效
  }
}
