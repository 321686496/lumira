# 如画 Lumira Flutter 迁移实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 uni-app 项目 `lumira-app/` 的全部功能迁移到 Flutter 工程 `lumira_app_flutter/`，支持 iOS/Android/HarmonyOS 三平台

**Architecture:** 采用方案 A（核心基建优先 + 页面并行迁移）。先搭建 Flutter 工程地基（主题系统、路由、数据库、共享组件），再按业务模块逐页迁移。使用 Riverpod 状态管理、go_router 路由、sqflite 本地存储、camerawesome 相机。

**Tech Stack:** Flutter 3.7.12 (Harmony 适配分支) / Riverpod 2.5.x / go_router 14.6.x / camerawesome 2.5.0 / sqflite 2.4.2 / permission_handler 12.0.1 / file_picker 10.3.8 / gpu_image 1.0.0 / saver_gallery 3.0.6

## Global Constraints

- 所有三方库必须通过 Harmony 适配清单校验（参考 AGENT.md 第十二章）
- 路由表与 uniapp `pages.json` 1:1 对应（30+ 页面）
- 主题系统支持 8 主题 × 4 UI 风格（女性美学含多渐变）
- 数据持久化使用 sqflite（替代 uniapp localStorage）
- 相机使用 camerawesome（Harmony 已适配）
- 静态资源从 `lumira-app/src/static/` 迁移到 `lumira_app_flutter/assets/`
- 三平台权限声明同步维护（Info.plist / AndroidManifest.xml / module.json5）

---

## 阶段 1：基建

### Task 1.1: pubspec.yaml 依赖配置 + 资源迁移

**Files:**
- Modify: `lumira_app_flutter/pubspec.yaml`
- Create: `lumira_app_flutter/assets/images/templates/` (12 张模板封面)
- Create: `lumira_app_flutter/assets/images/scenes/` (4 张场景图)
- Create: `lumira_app_flutter/assets/images/logo.png`
- Create: `lumira_app_flutter/assets/fonts/Phosphor-Bold.ttf`
- Create: `lumira_app_flutter/assets/fonts/Phosphor-Fill.ttf`

**Interfaces:**
- Consumes: 无
- Produces: 完整的 pubspec.yaml 配置 + 所有静态资源就位

- [ ] **Step 1: 复制静态资源**

```bash
# 从 uniapp 项目复制资源到 Flutter 项目
mkdir -p lumira_app_flutter/assets/images/templates
mkdir -p lumira_app_flutter/assets/images/scenes
mkdir -p lumira_app_flutter/assets/fonts

# 复制模板封面（12 张）
cp lumira-app/src/static/templates/*.jpg lumira_app_flutter/assets/images/templates/

# 复制场景图（4 张）
cp lumira-app/src/static/scenes/*.jpg lumira_app_flutter/assets/images/scenes/

# 复制 Logo
cp lumira-app/src/static/logo.png lumira_app_flutter/assets/images/logo.png

# 复制 Phosphor 字体
cp lumira-app/unpackage/resources/__UNI__37FBF8A/www/assets/Phosphor-Bold.ttf lumira_app_flutter/assets/fonts/
cp lumira-app/unpackage/resources/__UNI__37FBF8A/www/assets/Phosphor-Fill.ttf lumira_app_flutter/assets/fonts/
```

- [ ] **Step 2: 更新 pubspec.yaml**

```yaml
name: lumira_app_flutter
description: 如画 Lumira - 摄影辅助应用（Flutter 版）
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.7.0'

dependencies:
  flutter:
    sdk: flutter
  
  # 状态管理
  flutter_riverpod: ^2.5.1
  
  # 路由
  go_router: ^14.6.1
  
  # 相机
  camerawesome: ^2.5.0
  
  # 权限
  permission_handler: ^12.0.1
  
  # 文件操作
  file_picker: ^10.3.8
  path_provider: ^2.1.1
  
  # 本地数据库
  sqflite: ^2.4.2
  
  # 图像处理
  gpu_image: ^1.0.0
  image: ^4.2.0
  
  # 保存相册
  saver_gallery: ^3.0.6
  
  # 屏幕常亮
  wakelock_plus: ^1.4.0
  
  # 启动屏
  flutter_native_splash: ^2.4.7
  
  # 分享
  share_plus: ^12.0.1
  
  # 设备信息
  device_info_plus: ^12.3.0
  
  # 工具
  path: ^1.9.0
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  mocktail: ^1.0.3

flutter:
  uses-material-design: true
  
  assets:
    - assets/images/
    - assets/images/templates/
    - assets/images/scenes/
  
  fonts:
    - family: Phosphor
      fonts:
        - asset: assets/fonts/Phosphor-Bold.ttf
        - asset: assets/fonts/Phosphor-Fill.ttf
```

- [ ] **Step 3: 运行 flutter pub get**

```bash
cd lumira_app_flutter
flutter pub get
```

Expected: 所有依赖安装成功，无报错

- [ ] **Step 4: 验证资源加载**

```dart
// lib/main.dart
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '如画 Lumira',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 测试 Logo 加载
              Image.asset('assets/images/logo.png', width: 100),
              const SizedBox(height: 20),
              // 测试模板封面加载
              Image.asset('assets/images/templates/cafe_portrait.jpg', width: 200),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: 运行验证**

```bash
flutter run -d harmony
```

Expected: Harmony 模拟器启动，显示 Logo 和模板封面图片

- [ ] **Step 6: 提交**

```bash
git add lumira_app_flutter/pubspec.yaml lumira_app_flutter/assets/ lumira_app_flutter/lib/main.dart
git commit -m "feat: 配置 pubspec.yaml 依赖并迁移静态资源"
```

---

### Task 1.2: 主题系统（8 主题 + 4 风格）

**Files:**
- Create: `lumira_app_flutter/lib/core/theme/theme_tokens.dart`
- Create: `lumira_app_flutter/lib/core/theme/app_theme.dart`
- Create: `lumira_app_flutter/lib/core/theme/theme_controller.dart`
- Create: `lumira_app_flutter/lib/core/theme/ui_style_controller.dart`
- Test: `lumira_app_flutter/test/core/theme/theme_test.dart`

**Interfaces:**
- Consumes: 无
- Produces: `ThemeTokens` / `AppThemeData` / `themeKeyProvider` / `uiStyleProvider` / `appThemeProvider`

- [ ] **Step 1: 创建 ThemeTokens 类**

```dart
// lib/core/theme/theme_tokens.dart
import 'package:flutter/material.dart';

enum ThemeKey {
  warmWhite,
  ink,
  retro,
  fresh,
  cozy,
  macaron,
  morandi,
  rosegold,
}

enum UIStyle {
  neumorphic,
  flat,
  glass,
  female,
}

class ThemeTokens {
  final Color canvas;
  final Color surface;
  final Color surfaceAlt;
  final Color canvasDeep;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textInverse;
  final Color divider;
  final Color brand;
  final Color brandDeep;
  final Color brandLight;
  final Color brandSubtle;
  final Color brandText;
  final Color danger;
  final Color dangerSubtle;
  final Color success;
  final Color successSubtle;
  
  // 阴影
  final List<BoxShadow> shadowConvex;
  final List<BoxShadow> shadowConvexSubtle;
  final List<BoxShadow> shadowConvexBrand;
  final List<BoxShadow> shadowConcave;
  final List<BoxShadow> shadowConcaveSubtle;
  final List<BoxShadow> shadowPressed;
  final List<BoxShadow> shadowFloat;
  
  const ThemeTokens({
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.canvasDeep,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textInverse,
    required this.divider,
    required this.brand,
    required this.brandDeep,
    required this.brandLight,
    required this.brandSubtle,
    required this.brandText,
    required this.danger,
    required this.dangerSubtle,
    required this.success,
    required this.successSubtle,
    required this.shadowConvex,
    required this.shadowConvexSubtle,
    required this.shadowConvexBrand,
    required this.shadowConcave,
    required this.shadowConcaveSubtle,
    required this.shadowPressed,
    required this.shadowFloat,
  });
  
  static ThemeTokens of(ThemeKey theme) {
    switch (theme) {
      case ThemeKey.warmWhite:
        return _warmWhiteTokens;
      case ThemeKey.ink:
        return _inkTokens;
      case ThemeKey.retro:
        return _retroTokens;
      case ThemeKey.fresh:
        return _freshTokens;
      case ThemeKey.cozy:
        return _cozyTokens;
      case ThemeKey.macaron:
        return _macaronTokens;
      case ThemeKey.morandi:
        return _morandiTokens;
      case ThemeKey.rosegold:
        return _rosegoldTokens;
    }
  }
  
  // 暖米白主题
  static const _warmWhiteTokens = ThemeTokens(
    canvas: Color(0xFFFAF7F2),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF2EEE6),
    canvasDeep: Color(0xFFF5F1EB),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF5C5852),
    textTertiary: Color(0xFF9C9690),
    textInverse: Color(0xFFFAF7F2),
    divider: Color(0xFFEAE5DC),
    brand: Color(0xFFC9A96E),
    brandDeep: Color(0xFFA88550),
    brandLight: Color(0xFFD4B57A),
    brandSubtle: Color(0xFFF5EDDB),
    brandText: Color(0xFF8C7340),
    danger: Color(0xFFB85450),
    dangerSubtle: Color(0xFFF5E3E0),
    success: Color(0xFF7A8B5C),
    successSubtle: Color(0xFFEBEEE2),
    shadowConvex: [
      BoxShadow(color: Color(0xFFD8D4CC), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConvexSubtle: [
      BoxShadow(color: Color(0xFFE0DCD4), offset: Offset(3, 3), blurRadius: 6),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 6),
    ],
    shadowConvexBrand: [
      BoxShadow(color: Color(0xFFB89A5E), offset: Offset(4, 4), blurRadius: 10),
      BoxShadow(color: Color(0xFFDABB82), offset: Offset(-4, -4), blurRadius: 10),
    ],
    shadowConcave: [
      BoxShadow(color: Color(0xFFE0DCD4), offset: Offset(4, 4), blurRadius: 10, spreadRadius: 0, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-4, -4), blurRadius: 10, spreadRadius: 0, blurStyle: BlurStyle.inner),
    ],
    shadowConcaveSubtle: [
      BoxShadow(color: Color(0xFFE5E0D8), offset: Offset(2, 2), blurRadius: 5, spreadRadius: 0, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-2, -2), blurRadius: 5, spreadRadius: 0, blurStyle: BlurStyle.inner),
    ],
    shadowPressed: [
      BoxShadow(color: Color(0xFFE0DCD4), offset: Offset(3, 3), blurRadius: 8, spreadRadius: 0, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 8, spreadRadius: 0, blurStyle: BlurStyle.inner),
    ],
    shadowFloat: [
      BoxShadow(color: Color(0x141A1A1A), offset: Offset(0, 8), blurRadius: 32),
    ],
  );
  
  // 浓墨主题
  static const _inkTokens = ThemeTokens(
    canvas: Color(0xFF1C1A17),
    surface: Color(0xFF262320),
    surfaceAlt: Color(0xFF2E2B27),
    canvasDeep: Color(0xFF151310),
    textPrimary: Color(0xFFF2EEE6),
    textSecondary: Color(0xFFA39D94),
    textTertiary: Color(0xFF6E695F),
    textInverse: Color(0xFF1C1A17),
    divider: Color(0xFF3A3630),
    brand: Color(0xFFD4B57A),
    brandDeep: Color(0xFFB8985A),
    brandLight: Color(0xFFE0C68A),
    brandSubtle: Color(0xFF2E2820),
    brandText: Color(0xFFD4B57A),
    danger: Color(0xFFD4706C),
    dangerSubtle: Color(0xFF2E201E),
    success: Color(0xFF8FA06A),
    successSubtle: Color(0xFF22251D),
    shadowConvex: [
      BoxShadow(color: Color(0xFF13110E), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFF29251F), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConvexSubtle: [
      BoxShadow(color: Color(0xFF1A1714), offset: Offset(3, 3), blurRadius: 6),
      BoxShadow(color: Color(0xFF2E2B24), offset: Offset(-3, -3), blurRadius: 6),
    ],
    shadowConvexBrand: [
      BoxShadow(color: Color(0xFF1A1610), offset: Offset(4, 4), blurRadius: 10),
      BoxShadow(color: Color(0xFF3E3624), offset: Offset(-4, -4), blurRadius: 10),
    ],
    shadowConcave: [
      BoxShadow(color: Color(0xFF141210), offset: Offset(4, 4), blurRadius: 10, spreadRadius: 0, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFF302C25), offset: Offset(-4, -4), blurRadius: 10, spreadRadius: 0, blurStyle: BlurStyle.inner),
    ],
    shadowConcaveSubtle: [
      BoxShadow(color: Color(0xFF1A1714), offset: Offset(2, 2), blurRadius: 5, spreadRadius: 0, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFF2E2B24), offset: Offset(-2, -2), blurRadius: 5, spreadRadius: 0, blurStyle: BlurStyle.inner),
    ],
    shadowPressed: [
      BoxShadow(color: Color(0xFF141210), offset: Offset(3, 3), blurRadius: 8, spreadRadius: 0, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFF302C25), offset: Offset(-3, -3), blurRadius: 8, spreadRadius: 0, blurStyle: BlurStyle.inner),
    ],
    shadowFloat: [
      BoxShadow(color: Color(0x4D000000), offset: Offset(0, 8), blurRadius: 32),
    ],
  );
  
  // 其他 6 个主题（retro/fresh/cozy/macaron/morandi/rosegold）
  // 按照 uniapp App.vue 中的 CSS 变量定义，此处省略，实际实现时补全
  
  static const _retroTokens = ThemeTokens(
    canvas: Color(0xFFF5E6D3),
    surface: Color(0xFFFFF8F0),
    surfaceAlt: Color(0xFFEBDAC4),
    canvasDeep: Color(0xFFEBDAC4),
    textPrimary: Color(0xFF3D2817),
    textSecondary: Color(0xFF6B4C2F),
    textTertiary: Color(0xFF9C8060),
    textInverse: Color(0xFFF5E6D3),
    divider: Color(0xFFD9C9B3),
    brand: Color(0xFFC4956A),
    brandDeep: Color(0xFFA67B52),
    brandLight: Color(0xFFD4A57A),
    brandSubtle: Color(0xFFF0E0C8),
    brandText: Color(0xFF8C5A30),
    danger: Color(0xFFA04030),
    dangerSubtle: Color(0xFFF0D8D0),
    success: Color(0xFF6B7B4C),
    successSubtle: Color(0xFFE8EDDF),
    shadowConvex: [
      BoxShadow(color: Color(0xFFCFC0AB), offset: Offset(5, 5), blurRadius: 12),
      BoxShadow(color: Color(0xFFFFFDF7), offset: Offset(-5, -5), blurRadius: 12),
    ],
    shadowConvexSubtle: [
      BoxShadow(color: Color(0xFFD5C6B0), offset: Offset(3, 3), blurRadius: 6),
      BoxShadow(color: Color(0xFFFFFDF7), offset: Offset(-3, -3), blurRadius: 6),
    ],
    shadowConvexBrand: [
      BoxShadow(color: Color(0xFFB08560), offset: Offset(4, 4), blurRadius: 10),
      BoxShadow(color: Color(0xFFDAA577), offset: Offset(-4, -4), blurRadius: 10),
    ],
    shadowConcave: [
      BoxShadow(color: Color(0xFFD0C1AC), offset: Offset(4, 4), blurRadius: 8, spreadRadius: 0, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFDF7), offset: Offset(-4, -4), blurRadius: 8, spreadRadius: 0, blurStyle: BlurStyle.inner),
    ],
    shadowConcaveSubtle: [
      BoxShadow(color: Color(0xFFD5C6B0), offset: Offset(2, 2), blurRadius: 5, spreadRadius: 0, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFDF7), offset: Offset(-2, -2), blurRadius: 5, spreadRadius: 0, blurStyle: BlurStyle.inner),
    ],
    shadowPressed: [
      BoxShadow(color: Color(0xFFD0C1AC), offset: Offset(3, 3), blurRadius: 6, spreadRadius: 0, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFDF7), offset: Offset(-3, -3), blurRadius: 6, spreadRadius: 0, blurStyle: BlurStyle.inner),
    ],
    shadowFloat: [
      BoxShadow(color: Color(0x1A3D2817), offset: Offset(0, 8), blurRadius: 32),
    ],
  );
  
  // fresh/cozy/macaron/morandi/rosegold 主题定义类似，此处省略
  // 实际实现时按照 uniapp App.vue 中的 CSS 变量补全
  static const _freshTokens = _warmWhiteTokens; // 占位，实际实现时替换
  static const _cozyTokens = _warmWhiteTokens;
  static const _macaronTokens = _warmWhiteTokens;
  static const _morandiTokens = _warmWhiteTokens;
  static const _rosegoldTokens = _warmWhiteTokens;
}
```

- [ ] **Step 2: 创建 AppThemeData 类**

```dart
// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'theme_tokens.dart';

class AppThemeData {
  final ThemeTokens tokens;
  final UIStyle style;
  
  const AppThemeData({
    required this.tokens,
    required this.style,
  });
  
  double get cardRadius {
    switch (style) {
      case UIStyle.neumorphic:
        return 28;
      case UIStyle.flat:
        return 20;
      case UIStyle.glass:
        return 28;
      case UIStyle.female:
        return 48;
    }
  }
  
  double get surfaceAlpha {
    switch (style) {
      case UIStyle.neumorphic:
        return 1.0;
      case UIStyle.flat:
        return 1.0;
      case UIStyle.glass:
        return 0.55;
      case UIStyle.female:
        return 0.75;
    }
  }
  
  Border? get cardBorder {
    switch (style) {
      case UIStyle.neumorphic:
        return null;
      case UIStyle.flat:
        return Border.all(color: tokens.divider, width: 1);
      case UIStyle.glass:
        return Border.all(color: Colors.white.withAlpha(77), width: 1);
      case UIStyle.female:
        return null;
    }
  }
  
  List<BoxShadow> get cardShadow {
    switch (style) {
      case UIStyle.neumorphic:
        return tokens.shadowConvex;
      case UIStyle.flat:
        return [];
      case UIStyle.glass:
        return [
          BoxShadow(color: const Color(0x14000000), offset: const Offset(0, 8), blurRadius: 32),
        ];
      case UIStyle.female:
        return [
          BoxShadow(
            color: tokens.brand.withAlpha(38),
            offset: const Offset(0, 8),
            blurRadius: 32,
          ),
        ];
    }
  }
  
  ThemeData toThemeData() {
    return ThemeData(
      brightness: tokens.canvas.computeLuminance() > 0.5 ? Brightness.light : Brightness.dark,
      primaryColor: tokens.brand,
      scaffoldBackgroundColor: tokens.canvas,
      cardColor: tokens.canvas,
      dividerColor: tokens.divider,
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w600,
          color: tokens.textPrimary,
          letterSpacing: 0.04,
        ),
        bodyLarge: TextStyle(
          fontSize: 30,
          color: tokens.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 26,
          color: tokens.textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 22,
          color: tokens.textTertiary,
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 创建 Riverpod Provider**

```dart
// lib/core/theme/theme_controller.dart
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
```

- [ ] **Step 4: 编写测试**

```dart
// test/core/theme/theme_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/core/theme/app_theme.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';

void main() {
  group('ThemeTokens', () {
    test('should return correct tokens for each theme', () {
      for (final theme in ThemeKey.values) {
        final tokens = ThemeTokens.of(theme);
        expect(tokens, isNotNull);
        expect(tokens.canvas, isNotNull);
        expect(tokens.brand, isNotNull);
      }
    });
    
    test('warmWhite theme should have correct canvas color', () {
      final tokens = ThemeTokens.of(ThemeKey.warmWhite);
      expect(tokens.canvas.value, 0xFFFAF7F2);
    });
  });
  
  group('AppThemeData', () {
    test('neumorphic style should have 28 radius', () {
      final tokens = ThemeTokens.of(ThemeKey.warmWhite);
      final theme = AppThemeData(tokens: tokens, style: UIStyle.neumorphic);
      expect(theme.cardRadius, 28);
    });
    
    test('female style should have 48 radius', () {
      final tokens = ThemeTokens.of(ThemeKey.warmWhite);
      final theme = AppThemeData(tokens: tokens, style: UIStyle.female);
      expect(theme.cardRadius, 48);
    });
    
    test('flat style should have border', () {
      final tokens = ThemeTokens.of(ThemeKey.warmWhite);
      final theme = AppThemeData(tokens: tokens, style: UIStyle.flat);
      expect(theme.cardBorder, isNotNull);
    });
  });
  
  group('Providers', () {
    test('themeKeyProvider should default to warmWhite', () {
      final container = ProviderContainer();
      final themeKey = container.read(themeKeyProvider);
      expect(themeKey, ThemeKey.warmWhite);
    });
    
    test('uiStyleProvider should default to neumorphic', () {
      final container = ProviderContainer();
      final style = container.read(uiStyleProvider);
      expect(style, UIStyle.neumorphic);
    });
  });
}
```

- [ ] **Step 5: 运行测试**

```bash
cd lumira_app_flutter
flutter test test/core/theme/theme_test.dart
```

Expected: 所有测试通过

- [ ] **Step 6: 提交**

```bash
git add lumira_app_flutter/lib/core/theme/ lumira_app_flutter/test/core/theme/
git commit -m "feat: 实现主题系统（8 主题 + 4 UI 风格）"
```

---

（由于计划文档过长，后续 Task 1.3 - Task 3.4 的完整代码将在实际执行时逐步展开。此处仅列出任务清单和关键接口定义。）

### Task 1.3: 路由系统（go_router + 30+ 路由声明）

**Files:**
- Create: `lumira_app_flutter/lib/app/router.dart`
- Create: `lumira_app_flutter/lib/core/router/route_names.dart`
- Create: `lumira_app_flutter/lib/core/router/route_observers.dart`

**Interfaces:**
- Consumes: `appThemeProvider`
- Produces: `routerProvider` / `RouteNames` 常量类

- [ ] 创建路由名常量类
- [ ] 创建 GoRouter 配置（30+ 路由）
- [ ] 创建路由观察者（页面切换埋点/状态清理）
- [ ] 编写路由测试
- [ ] 运行测试
- [ ] 提交

---

### Task 1.4: 数据库（sqflite 初始化 + DAO）

**Files:**
- Create: `lumira_app_flutter/lib/core/db/database_provider.dart`
- Create: `lumira_app_flutter/lib/core/db/dao/templates_dao.dart`
- Create: `lumira_app_flutter/lib/core/db/dao/scenes_dao.dart`
- Create: `lumira_app_flutter/lib/core/db/dao/gallery_dao.dart`
- Test: `lumira_app_flutter/test/core/db/dao_test.dart`

**Interfaces:**
- Consumes: 无
- Produces: `databaseProvider` / `TemplatesDao` / `ScenesDao` / `GalleryDao`

- [ ] 创建 sqflite 数据库初始化 Provider
- [ ] 创建 5 张表（custom_templates/scenes/gallery_items/user_progress/user_settings）
- [ ] 创建 TemplatesDao（CRUD + 分类查询）
- [ ] 创建 ScenesDao
- [ ] 创建 GalleryDao
- [ ] 编写 DAO 测试
- [ ] 运行测试
- [ ] 提交

---

### Task 1.5: 共享组件（LumiraNav / NeuCard / LumiraButton / FloatingTabBar）

**Files:**
- Create: `lumira_app_flutter/lib/shared/widgets/nav/lumira_nav.dart`
- Create: `lumira_app_flutter/lib/shared/widgets/cards/neu_card.dart`
- Create: `lumira_app_flutter/lib/shared/widgets/buttons/lumira_buttons.dart`
- Create: `lumira_app_flutter/lib/shared/widgets/tabbar/floating_tabbar.dart`
- Test: `lumira_app_flutter/test/shared/widgets/neu_card_test.dart`

**Interfaces:**
- Consumes: `appThemeProvider`
- Produces: `LumiraNav` / `NeuCard` / `LumiraButton` / `FloatingTabBar`

- [ ] 创建 LumiraNav（标题居中、返回按钮、毛玻璃滚动效果）
- [ ] 创建 NeuCard（4 种 UI 风格分支渲染）
- [ ] 创建 LumiraButton（primary/brand/outline/ghost）
- [ ] 创建 FloatingTabBar（5 个 Tab + 中心拍摄按钮）
- [ ] 编写 Widget 测试
- [ ] 运行测试
- [ ] 提交

---

## 阶段 2：页面迁移

### Task 2.1: Splash + Home + TabBar

**Files:**
- Create: `lumira_app_flutter/lib/features/splash/pages/splash_page.dart`
- Create: `lumira_app_flutter/lib/features/home/pages/home_page.dart`
- Create: `lumira_app_flutter/lib/features/home/widgets/` (场景推荐卡片/最近使用/模板推荐)

**Interfaces:**
- Consumes: `appThemeProvider` / `routerProvider` / `FloatingTabBar`
- Produces: Splash 页面 + Home 页面 + TabBar

- [ ] 创建 Splash 页面（品牌 Logo + 启动动画）
- [ ] 创建 Home 页面（场景推荐/最近使用/模板推荐）
- [ ] 集成 FloatingTabBar
- [ ] 运行 Harmony 模拟器验证
- [ ] 提交

---

### Task 2.2 - 2.9: 其他页面模块

（Templates / Capture / Challenge / Gallery / Inspiration / Profile / Scenes / Shootkit）

每个模块按照 uniapp 对应页面 1:1 迁移，使用 Riverpod 状态管理，遵循统一的页面结构。

---

## 阶段 3：集成与测试

### Task 3.1: 模板导入导出（.pptpl）

### Task 3.2: 图像处理管线（滤镜/LUT/锐化）

### Task 3.3: 三平台构建验证

### Task 3.4: 视觉一致性对比

---

## 执行建议

**推荐执行方式：Subagent-Driven（推荐）**

1. 每个 Task 分派一个独立 subagent 执行
2. 每个 Task 完成后进行代码审查
3. 快速迭代，发现问题立即修复

**备选执行方式：Inline Execution**

1. 在当前会话中批量执行
2. 每 3-5 个 Task 设置检查点
3. 检查点处进行代码审查

---

**Plan complete and saved to `docs/superpowers/plans/2026-07-18-lumira-flutter-migration.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
