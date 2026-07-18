import 'package:flutter_riverpod/flutter_riverpod.dart';
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
