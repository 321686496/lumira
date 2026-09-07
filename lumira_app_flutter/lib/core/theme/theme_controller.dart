import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_provider.dart';
import 'theme_tokens.dart';
import 'app_theme.dart';

final themeKeyProvider = StateProvider<ThemeKey>((ref) => ThemeKey.warmWhite);
final uiStyleProvider = StateProvider<UIStyle>((ref) => UIStyle.neumorphic);

/// 跟随系统深浅色开关（持久化到 user_settings.follow_system）
final followSystemProvider = StateProvider<bool>((ref) => false);

/// 跟随系统开启时，系统深色模式下使用的主题（持久化到 user_settings.theme_key_dark）
final darkThemeKeyProvider = StateProvider<ThemeKey>((ref) => ThemeKey.ink);

/// 跟随系统开启时，系统浅色模式下使用的主题（持久化到 user_settings.theme_key_light）
final lightThemeKeyProvider =
    StateProvider<ThemeKey>((ref) => ThemeKey.warmWhite);

/// 系统当前明暗模式（由 SystemBrightnessWatcher 同步 platformDispatcher 更新）。
/// 初始值直接取系统当前亮度，避免跟随系统时首帧按浅色渲染造成闪变。
final systemBrightnessProvider = StateProvider<Brightness>((ref) =>
    WidgetsBinding.instance.platformDispatcher.platformBrightness);

/// 当前生效主题：
/// - 跟随系统开启 → 按系统明暗在 [darkThemeKeyProvider] / [lightThemeKeyProvider] 二选一
/// - 跟随系统关闭 → 用户手动选择的 [themeKeyProvider]
final effectiveThemeKeyProvider = Provider<ThemeKey>((ref) {
  if (!ref.watch(followSystemProvider)) {
    return ref.watch(themeKeyProvider);
  }
  final isDark = ref.watch(systemBrightnessProvider) == Brightness.dark;
  return isDark
      ? ref.watch(darkThemeKeyProvider)
      : ref.watch(lightThemeKeyProvider);
});

final themeTokensProvider = Provider<ThemeTokens>((ref) {
  final theme = ref.watch(effectiveThemeKeyProvider);
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
  container.read(followSystemProvider.notifier).state =
      await dao.getFollowSystem();
  container.read(darkThemeKeyProvider.notifier).state =
      await dao.getDarkThemeKey();
  container.read(lightThemeKeyProvider.notifier).state =
      await dao.getLightThemeKey();
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

/// 切换跟随系统开关并持久化到本地。写入失败时静默（不影响 UI 即时生效）。
Future<void> persistFollowSystem(WidgetRef ref, bool enabled) async {
  ref.read(followSystemProvider.notifier).state = enabled;
  try {
    final dao = await ref.read(settingsDaoProvider.future);
    await dao.setFollowSystem(enabled);
  } catch (_) {
    // 持久化失败静默，界面切换已生效
  }
}

/// 切换「系统深色模式」主题并持久化到本地。写入失败时静默。
Future<void> persistDarkThemeKey(WidgetRef ref, ThemeKey key) async {
  ref.read(darkThemeKeyProvider.notifier).state = key;
  try {
    final dao = await ref.read(settingsDaoProvider.future);
    await dao.setDarkThemeKey(key);
  } catch (_) {
    // 持久化失败静默，界面切换已生效
  }
}

/// 切换「系统浅色模式」主题并持久化到本地。写入失败时静默。
Future<void> persistLightThemeKey(WidgetRef ref, ThemeKey key) async {
  ref.read(lightThemeKeyProvider.notifier).state = key;
  try {
    final dao = await ref.read(settingsDaoProvider.future);
    await dao.setLightThemeKey(key);
  } catch (_) {
    // 持久化失败静默，界面切换已生效
  }
}
