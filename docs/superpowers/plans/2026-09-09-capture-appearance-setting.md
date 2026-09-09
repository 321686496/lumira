# 拍摄页/预览页「沉浸式 vs 跟随主题」外观设置 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增设置开关「沉浸式取景」，控制拍摄页与拍摄预览页使用沉浸式（纯黑+暗色浮层，现状）还是跟随主题（按 UIStyle × ThemeKey 渲染）外观。

**Architecture:** 集中视觉解析器方案——`LumiraThemeResolver.captureOverlayVisual()` 统一解析 `appearance(immersive/theme) × style(4 风格) × role(pill/panel)` 输出容器+前景视觉规格；两页面全部浮层组件消费该解析结果，不再各自硬编码。设置持久化走 `user_settings.capture_appearance` 列（v55 迁移）+ Riverpod StateProvider。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（**不支持 Dart 3 records 语法**）、flutter_riverpod 2.3.6、sqflite v11、sqflite_common_ffi（DAO 测试）。

**Spec:** `docs/superpowers/specs/2026-09-09-capture-appearance-setting-design.md`

## Global Constraints

- Flutter 代码全部在 `lumira_app_flutter/`，Dart 2.19.6，禁用 Dart 3 语法（records、switch 表达式箭头模式等）
- 所有颜色从 `tokens.*` / resolver 输出派生，禁止新硬编码 `Color(0xFF...)` 表达主题观感（resolver 内部的 immersive 暗色值与 `0xFFC9A96E` 金色是唯一合法硬编码，属「黑白半透明遮罩」例外）
- 黑白半透明例外元素（快门白闪、延时大数字、试用遮罩、水印定格动画、照片上的对比徽标/scrim）两模式下均保持现状不动
- immersive 模式允许轻微统一（胶囊 alpha 0.72~0.75 统一为 0.72、毛玻璃 blur 24→20、面板底统一 `0xFF141416@0.80`），视觉近似的「小统一」可接受；theme 模式为全新渲染
- 每个任务完成后 `flutter analyze` 必须 0 error（warning 不新增）；本计划仅动 Flutter 端，**无需 push 双远程**（AGENTS.md 的 push 规则仅适用 backend/admin）
- shell 为 PowerShell：**不支持 `&&`**，用 `;` 分隔或分步执行
- Flutter 命令工作目录：`d:\app\projects\photo_post\lumira_app_flutter`

## 映射总表（Task 5-8 所有组件通用）

组件改造模式：watch 外观 → 调 `captureOverlayVisual` → 用字段替换硬编码。

```dart
// 组件 build 内（ConsumerWidget）：
final visual = LumiraThemeResolver.captureOverlayVisual(
  tokens: ref.watch(themeTokensProvider),
  style: ref.watch(appThemeProvider).style,
  appearance: ref.watch(CaptureState.captureAppearanceProvider),
  role: CaptureOverlayRole.pill, // 或 panel
  radiusDp: 28,                  // 组件现有圆角值
);
// 容器：
decoration: BoxDecoration(
  color: visual.background,
  borderRadius: BorderRadius.circular(28),
  border: visual.border,
  boxShadow: visual.shadows,
),
// 毛玻璃：仅当 visual.backdropBlurSigma > 0 时包裹（替代现有 isNeu 判断）：
child: visual.backdropBlurSigma > 0
    ? ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: visual.backdropBlurSigma,
              sigmaY: visual.backdropBlurSigma),
          child: capsule,
        ),
      )
    : capsule,
```

| 现有硬编码表达式 | 替换为 |
|---|---|
| `Color(0xFF141416).withOpacity(0.72/0.75)`（胶囊底） | `visual.background`（role=pill） |
| `Colors.black.withOpacity(0.4/0.55/0.82)`（面板/抽屉底） | `visual.background`（role=panel） |
| `Colors.white.withOpacity(0.1)`（胶囊边框） | `visual.border` |
| `Colors.black.withOpacity(0.15)`（胶囊阴影） | `visual.shadows` |
| `Colors.white`（主文字/图标） | `visual.foreground` |
| `Colors.white70` | `visual.foregroundSecondary` |
| `Colors.white54` / `white38` / `white30` / `white24` | `visual.foregroundMuted` |
| `Colors.white12` / `white10`（占位/次级底） | `visual.fillSubtle` |
| `Color(0xFFC9A96E)`（激活金） | `visual.accent` |
| `Colors.black`（金色/激活底上的文字） | `visual.onAccent` |
| `isNeu ? capsule : BackdropFilter(...)` | `visual.backdropBlurSigma > 0 ? ... : capsule` |
| `Colors.white.withOpacity(0.25/0.35)`（glass 式白边，仅限 glass 风格分支内） | 保留原样（glass 自身风格语言）或并入 `visual.border` |

注意：`const` 修饰的 Text/Container/Icon 一旦颜色变为运行时值，必须去掉 `const`。

---

### Task 1: 数据层（枚举 / provider / v55 迁移 / DAO）

**Files:**
- Create: `lumira_app_flutter/lib/core/theme/capture_appearance.dart`
- Modify: `lumira_app_flutter/lib/core/db/tables.dart`（~L163 附近，user_settings 列常量区）
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart`（L36 `_kDbVersion`；L1581-1594 v54 迁移后追加 v55）
- Modify: `lumira_app_flutter/lib/core/db/dao/settings_dao.dart`（文件末尾追加方法）
- Modify: `lumira_app_flutter/lib/features/capture/data/capture_state.dart`（文件内 CaptureState 类中追加；import 区追加）
- Test: `lumira_app_flutter/test/core/db/dao/settings_dao_test.dart`（扩展）

**Interfaces:**
- Produces: `enum CaptureAppearance { immersive, theme }`、`enum CaptureOverlayRole { pill, panel }`（core/theme/capture_appearance.dart）；`CaptureState.captureAppearanceProvider`（`StateProvider<CaptureAppearance>`）、`CaptureState.loadCaptureAppearance(ProviderContainer)`、`CaptureState.persistCaptureAppearance(ProviderContainer, CaptureAppearance)`；`SettingsDao.getCaptureAppearance()/setCaptureAppearance()`；`Tables.colCaptureAppearance`。后续所有任务依赖这些名字。

- [ ] **Step 1: 写失败的 DAO 测试**

在 `test/core/db/dao/settings_dao_test.dart`：
1. `onCreate` 的 CREATE TABLE 中 `shutter_sound` 行后加一列：
```dart
            shutter_sound INTEGER NOT NULL DEFAULT 1,
            capture_appearance TEXT NOT NULL DEFAULT 'immersive',
```
2. 文件末尾 `main()` 内追加 group（import 区加 `import 'package:lumira_app_flutter/core/theme/capture_appearance.dart';`）：
```dart
  group('capture appearance persistence', () {
    test('getCaptureAppearance default is immersive', () async {
      expect(await dao.getCaptureAppearance(), CaptureAppearance.immersive);
    });

    test('setCaptureAppearance(theme) persists to DB', () async {
      await dao.setCaptureAppearance(CaptureAppearance.theme);
      expect(await dao.getCaptureAppearance(), CaptureAppearance.theme);
      final rows = await db.query('user_settings', where: 'id = 1');
      expect(rows.first['capture_appearance'], equals('theme'));
    });

    test('setCaptureAppearance(immersive) after theme works', () async {
      await dao.setCaptureAppearance(CaptureAppearance.theme);
      await dao.setCaptureAppearance(CaptureAppearance.immersive);
      expect(await dao.getCaptureAppearance(), CaptureAppearance.immersive);
    });

    test('invalid value falls back to immersive', () async {
      await db.update('user_settings',
          {'capture_appearance': 'bogus'}, where: 'id = 1');
      expect(await dao.getCaptureAppearance(), CaptureAppearance.immersive);
    });

    test('无行时回退 immersive', () async {
      await db.delete('user_settings', where: 'id = 1');
      expect(await dao.getCaptureAppearance(), CaptureAppearance.immersive);
    });
  });
```

- [ ] **Step 2: 运行测试确认失败**

```powershell
cd d:\app\projects\photo_post\lumira_app_flutter ; flutter test test/core/db/dao/settings_dao_test.dart
```
预期：编译失败（`capture_appearance.dart` 不存在 / `getCaptureAppearance` 未定义）。

- [ ] **Step 3: 创建枚举文件**

`lumira_app_flutter/lib/core/theme/capture_appearance.dart`：
```dart
/// 拍摄页/预览页外观模式（持久化到 user_settings.capture_appearance）。
enum CaptureAppearance {
  /// 沉浸式：纯黑取景/看图 + 跨风格统一的暗色浮层（默认）
  immersive,

  /// 跟随主题：画布与浮层按当前主题色 + UI 风格渲染
  theme,
}

/// 拍摄浮层角色（captureOverlayVisual 的输入）：
/// - pill：直接叠在取景器上的胶囊/圆钮/浮条（导航、比例切换、参数 pill、延时按钮、工具栏）
/// - panel：底部承载内容的面板/抽屉（模板抽屉、场景条、滤镜选择器、参数面板）
enum CaptureOverlayRole { pill, panel }
```

- [ ] **Step 4: tables.dart 加列常量**

`tables.dart` 在 `static const String colShutterSound = 'shutter_sound';` 后追加：
```dart
  static const String colCaptureAppearance = 'capture_appearance';
```

- [ ] **Step 5: database_provider.dart v55 迁移 + 版本号**

1. L36：`const int _kDbVersion = 54;` → `const int _kDbVersion = 55;`
2. `if (oldVersion < 54) { ... }` 块之后追加：
```dart
  if (oldVersion < 55) {
    try {
      // v55: user_settings 新增 capture_appearance 列
      // （拍摄页/预览页外观：'immersive'=沉浸式（默认） / 'theme'=跟随主题）
      await _addColumnIfNotExists(
        db,
        Tables.userSettings,
        Tables.colCaptureAppearance,
        "TEXT NOT NULL DEFAULT 'immersive'",
      );
    } catch (e) {
      debugPrint('v55 migration failed (silent fallback): $e');
    }
  }
```

- [ ] **Step 6: SettingsDao 读写方法**

`settings_dao.dart` 末尾（`setTemplateInfoCardHidden` 后）追加；import 区加 `import '../../theme/capture_appearance.dart';`：
```dart
  /// 读取拍摄页/预览页外观（user_settings.capture_appearance，默认 immersive）
  Future<CaptureAppearance> getCaptureAppearance() async {
    final rows = await _db.query(
      Tables.userSettings,
      columns: [Tables.colCaptureAppearance],
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return CaptureAppearance.immersive;
    final raw = rows.first[Tables.colCaptureAppearance] as String?;
    return raw == CaptureAppearance.theme.name
        ? CaptureAppearance.theme
        : CaptureAppearance.immersive;
  }

  /// 保存拍摄页/预览页外观
  Future<void> setCaptureAppearance(CaptureAppearance value) async {
    await _db.update(
      Tables.userSettings,
      {
        Tables.colCaptureAppearance: value.name,
        Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }
```

- [ ] **Step 7: capture_state.dart provider + load/persist**

`capture_state.dart` import 区加 `import '../../../core/theme/capture_appearance.dart';`，在 `shutterSoundProvider` 相关方法之后追加（仿 loadLevelEnabled/persistLevelEnabled 模式，L743-766 附近可见范本）：
```dart
  // ── 拍摄页/预览页外观（沉浸式 vs 跟随主题）──

  /// 拍摄页与拍摄预览页外观模式（持久化到 user_settings.capture_appearance）。
  /// immersive=纯黑取景 + 暗色浮层（默认）；theme=画布与浮层跟随当前主题/风格。
  /// 由设置页 initState 从 DB 加载、开关切换后持久化；拍摄/预览页 watch 渲染。
  static final captureAppearanceProvider =
      StateProvider<CaptureAppearance>((ref) => CaptureAppearance.immersive);

  /// 从 DAO 加载拍摄外观到 provider（设置页 initState 调用）。
  static Future<void> loadCaptureAppearance(ProviderContainer container) async {
    try {
      final dao = await container.read(settingsDaoProvider.future);
      final appearance = await dao.getCaptureAppearance();
      container.read(captureAppearanceProvider.notifier).state = appearance;
    } catch (e) {
      // 加载失败静默降级，保持默认沉浸式
      debugPrint('[capture] loadCaptureAppearance failed: $e');
    }
  }

  /// 持久化拍摄外观（设置页 toggle 切换时调用）。
  static Future<void> persistCaptureAppearance(
    ProviderContainer container,
    CaptureAppearance value,
  ) async {
    try {
      final dao = await container.read(settingsDaoProvider.future);
      await dao.setCaptureAppearance(value);
    } catch (e) {
      // 持久化失败静默，不影响本次设置
      debugPrint('[capture] persist capture appearance failed: $e');
    }
  }
```

- [ ] **Step 8: 运行测试确认通过**

```powershell
cd d:\app\projects\photo_post\lumira_app_flutter ; flutter test test/core/db/dao/settings_dao_test.dart ; flutter analyze
```
预期：全部 PASS；analyze 无新增问题。

- [ ] **Step 9: Commit**

```powershell
git add lumira_app_flutter/lib/core/theme/capture_appearance.dart lumira_app_flutter/lib/core/db/tables.dart lumira_app_flutter/lib/core/db/database_provider.dart lumira_app_flutter/lib/core/db/dao/settings_dao.dart lumira_app_flutter/lib/features/capture/data/capture_state.dart lumira_app_flutter/test/core/db/dao/settings_dao_test.dart ; git commit -m "feat(capture): 拍摄外观设置数据层（CaptureAppearance 枚举/provider/v55 迁移/DAO）"
```

---

### Task 2: 视觉解析器 captureOverlayVisual

**Files:**
- Modify: `lumira_app_flutter/lib/shared/widgets/lumira/_internal/lumira_theme_resolver.dart`（类内追加方法 + 文件尾追加数据类）
- Modify: `lumira_app_flutter/lib/shared/widgets/lumira/lumira.dart`（barrel export）
- Test: Create `lumira_app_flutter/test/shared/widgets/lumira_theme_resolver_capture_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `CaptureAppearance` / `CaptureOverlayRole`
- Produces: `class CaptureOverlayVisual`（字段见下方代码）+ `LumiraThemeResolver.captureOverlayVisual({required ThemeTokens tokens, required UIStyle style, required CaptureAppearance appearance, required CaptureOverlayRole role, required double radiusDp})`。Task 3-9 全部依赖。

- [ ] **Step 1: 写失败测试**

`test/shared/widgets/lumira_theme_resolver_capture_test.dart`：
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/theme/capture_appearance.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/shared/widgets/lumira/_internal/lumira_theme_resolver.dart';

void main() {
  final light = ThemeTokens.of(ThemeKey.warmWhite);
  final dark = ThemeTokens.of(ThemeKey.ink);

  CaptureOverlayVisual resolve(ThemeTokens tokens, UIStyle style,
          CaptureAppearance appearance, CaptureOverlayRole role) =>
      LumiraThemeResolver.captureOverlayVisual(
        tokens: tokens,
        style: style,
        appearance: appearance,
        role: role,
        radiusDp: 20,
      );

  group('immersive：跨风格统一暗色浮层', () {
    for (final style in UIStyle.values) {
      test('pill/$style 暗色胶囊 + 白前景 + 金 accent', () {
        final v = resolve(light, style, CaptureAppearance.immersive,
            CaptureOverlayRole.pill);
        expect(v.background, const Color(0xFF141416).withOpacity(0.72));
        expect(v.foreground, Colors.white);
        expect(v.foregroundSecondary, Colors.white70);
        expect(v.foregroundMuted, Colors.white38);
        expect(v.accent, const Color(0xFFC9A96E));
        expect(v.onAccent, Colors.black);
        expect(v.fillSubtle, Colors.white12);
      });

      test('panel/$style 近黑面板', () {
        final v = resolve(light, style, CaptureAppearance.immersive,
            CaptureOverlayRole.panel);
        expect(v.background, const Color(0xFF141416).withOpacity(0.80));
        expect(v.foreground, Colors.white);
      });

      test('blur/$style 新拟态不毛玻璃，其余 20', () {
        final v = resolve(light, style, CaptureAppearance.immersive,
            CaptureOverlayRole.pill);
        expect(v.backdropBlurSigma, style == UIStyle.neumorphic ? 0 : 20);
      });
    }
  });

  group('theme：按风格「叠照片浮层」取向', () {
    test('neumorphic pill：实心 surface + divider 细边 + 无阴影无模糊', () {
      final v = resolve(light, UIStyle.neumorphic, CaptureAppearance.theme,
          CaptureOverlayRole.pill);
      expect(v.background, light.surface.withOpacity(0.92));
      expect(v.border, Border.all(color: light.divider, width: 0.8));
      expect(v.shadows, isEmpty);
      expect(v.backdropBlurSigma, 0);
    });

    test('flat pill：半透明 surfaceAlt + divider 边 + 无阴影', () {
      final v = resolve(light, UIStyle.flat, CaptureAppearance.theme,
          CaptureOverlayRole.pill);
      expect(v.background, light.surfaceAlt.withOpacity(0.88));
      expect(v.shadows, isEmpty);
      expect(v.backdropBlurSigma, 0);
    });

    test('glass pill：glassFill + glassBorder + blur 20', () {
      final v = resolve(light, UIStyle.glass, CaptureAppearance.theme,
          CaptureOverlayRole.pill);
      expect(v.background, ThemeTokens.glassFill(light));
      expect(v.backdropBlurSigma, 20);
      expect(v.shadows, isNotEmpty);
    });

    test('female pill：surface + 白细边 + 品牌柔和阴影', () {
      final v = resolve(light, UIStyle.female, CaptureAppearance.theme,
          CaptureOverlayRole.pill);
      expect(v.background, light.surface.withOpacity(0.92));
      expect(v.border,
          Border.all(color: Colors.white.withOpacity(0.7), width: 0.8));
      expect(v.shadows, isNotEmpty);
      expect(v.shadows.first.color, light.brand.withOpacity(0.15));
    });

    test('前景取 tokens：浅色主题深字、暗色主题浅字', () {
      final vLight = resolve(light, UIStyle.neumorphic,
          CaptureAppearance.theme, CaptureOverlayRole.pill);
      expect(vLight.foreground, light.textPrimary);
      expect(vLight.accent, light.brand);
      final vDark = resolve(dark, UIStyle.neumorphic,
          CaptureAppearance.theme, CaptureOverlayRole.pill);
      expect(vDark.foreground, dark.textPrimary);
    });

    test('panel：neumorphic 实心 surface（不透明）', () {
      final v = resolve(light, UIStyle.neumorphic, CaptureAppearance.theme,
          CaptureOverlayRole.panel);
      expect(v.background, light.surface);
      expect(v.shadows, isEmpty);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```powershell
cd d:\app\projects\photo_post\lumira_app_flutter ; flutter test test/shared/widgets/lumira_theme_resolver_capture_test.dart
```
预期：编译失败（`CaptureOverlayVisual` / `captureOverlayVisual` 未定义）。

- [ ] **Step 3: 实现解析器**

`lumira_theme_resolver.dart`：
1. import 区加 `import 'capture_appearance.dart'
    show CaptureAppearance, CaptureOverlayRole;`——注意实际相对路径：该文件在 `shared/widgets/lumira/_internal/`，枚举在 `core/theme/`，故为 `import '../../../../core/theme/capture_appearance.dart';`
2. `LumiraThemeResolver` 类内（`overlayOnImageVisual` 方法后）追加：
```dart
  /// 解析拍摄页/预览页浮层视觉规格（沉浸式 vs 跟随主题）。
  ///
  /// - immersive：跨风格统一的暗色浮层（「黑白半透明遮罩」合法例外），
  ///   与历史写死视觉一致（胶囊 0xFF141416@0.72 / 面板 @0.80 / 白细边 /
  ///   金色 0xFFC9A96E 激活态）；neumorphic 不毛玻璃，其余风格 blur 20。
  /// - theme：按当前风格的「叠照片浮层」取向（UI 规范 §4）：
  ///   浮层都落在取景器/照片之上，neumorphic 不得使用双向浮雕外阴影
  ///   （规范 §3），改实心/半透明 surface + 细边表达表面。
  ///
  /// [role]：pill=叠取景器胶囊/浮条；panel=底部承载内容的面板/抽屉。
  static CaptureOverlayVisual captureOverlayVisual({
    required ThemeTokens tokens,
    required UIStyle style,
    required CaptureAppearance appearance,
    required CaptureOverlayRole role,
    required double radiusDp,
  }) {
    // ── 沉浸式：跨风格统一暗色 ──
    if (appearance == CaptureAppearance.immersive) {
      final isPill = role == CaptureOverlayRole.pill;
      return CaptureOverlayVisual(
        background: const Color(0xFF141416)
            .withOpacity(isPill ? 0.72 : 0.80),
        border: Border.all(
          color: Colors.white.withOpacity(isPill ? 0.10 : 0.08),
          width: 0.5,
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withOpacity(isPill ? 0.15 : 0.2),
            blurRadius: isPill ? 12 : 24,
            offset: Offset(0, isPill ? 2 : 4),
          ),
        ],
        backdropBlurSigma: style == UIStyle.neumorphic ? 0 : 20,
        foreground: Colors.white,
        foregroundSecondary: Colors.white70,
        foregroundMuted: Colors.white38,
        fillSubtle: Colors.white12,
        accent: const Color(0xFFC9A96E),
        onAccent: Colors.black,
      );
    }

    // ── 跟随主题：按风格「叠照片浮层」取向 ──
    switch (style) {
      case UIStyle.neumorphic:
        return CaptureOverlayVisual(
          background: role == CaptureOverlayRole.pill
              ? tokens.surface.withOpacity(0.92)
              : tokens.surface,
          border: Border.all(color: tokens.divider, width: 0.8),
          shadows: const [],
          backdropBlurSigma: 0,
          foreground: tokens.textPrimary,
          foregroundSecondary: tokens.textSecondary,
          foregroundMuted: tokens.textTertiary,
          fillSubtle: tokens.divider,
          accent: tokens.brand,
          onAccent: tokens.textInverse,
        );
      case UIStyle.flat:
        return CaptureOverlayVisual(
          background: role == CaptureOverlayRole.pill
              ? tokens.surfaceAlt.withOpacity(0.88)
              : tokens.surface,
          border: Border.all(color: tokens.divider, width: 1),
          shadows: const [],
          backdropBlurSigma: 0,
          foreground: tokens.textPrimary,
          foregroundSecondary: tokens.textSecondary,
          foregroundMuted: tokens.textTertiary,
          fillSubtle: tokens.divider,
          accent: tokens.brand,
          onAccent: tokens.textInverse,
        );
      case UIStyle.glass:
        return CaptureOverlayVisual(
          background: ThemeTokens.glassFill(tokens),
          border: Border.all(color: ThemeTokens.glassBorder(tokens), width: 1),
          shadows: const [
            BoxShadow(
                color: Color(0x14000000), offset: Offset(0, 6), blurRadius: 20),
          ],
          backdropBlurSigma: 20,
          foreground: tokens.textPrimary,
          foregroundSecondary: tokens.textSecondary,
          foregroundMuted: tokens.textTertiary,
          fillSubtle: tokens.divider,
          accent: tokens.brand,
          onAccent: tokens.textInverse,
        );
      case UIStyle.female:
        return CaptureOverlayVisual(
          background: tokens.surface.withOpacity(0.92),
          border: Border.all(color: Colors.white.withOpacity(0.7), width: 0.8),
          shadows: [
            BoxShadow(
              color: tokens.brand.withOpacity(0.15),
              offset: const Offset(0, 6),
              blurRadius: 20,
            ),
          ],
          backdropBlurSigma: 0,
          foreground: tokens.textPrimary,
          foregroundSecondary: tokens.textSecondary,
          foregroundMuted: tokens.textTertiary,
          fillSubtle: tokens.divider,
          accent: tokens.brand,
          onAccent: tokens.textInverse,
        );
    }
  }
```
3. 文件末尾（`DarkNeuPalette` 类后）追加数据类：
```dart
/// 拍摄浮层视觉规格（容器 + 前景），由
/// [LumiraThemeResolver.captureOverlayVisual] 解析。
class CaptureOverlayVisual {
  /// 容器底色
  final Color background;

  /// 容器边框（null 无边框）
  final Border? border;

  /// 容器阴影
  final List<BoxShadow> shadows;

  /// >0 时组件需包裹 BackdropFilter 毛玻璃（新拟态恒 0）
  final double backdropBlurSigma;

  /// 主文字/图标色
  final Color foreground;

  /// 次级文字/未激活图标（对应历史 white70）
  final Color foregroundSecondary;

  /// 三级弱文字（对应历史 white38/white54/white24）
  final Color foregroundMuted;

  /// 弱底色（对应历史 white12/white10 占位底）
  final Color fillSubtle;

  /// 激活态强调色（immersive=金 0xFFC9A96E；theme=brand）
  final Color accent;

  /// 激活态底色上的前景（immersive=黑；theme=textInverse）
  final Color onAccent;

  const CaptureOverlayVisual({
    required this.background,
    required this.border,
    required this.shadows,
    required this.backdropBlurSigma,
    required this.foreground,
    required this.foregroundSecondary,
    required this.foregroundMuted,
    required this.fillSubtle,
    required this.accent,
    required this.onAccent,
  });
}
```
4. barrel export：`lumira.dart` 在 `export '../../../core/theme/app_theme.dart' ...` 块后追加：
```dart
// 拍摄浮层视觉解析（拍摄页/预览页沉浸式与跟随主题双模式）
export '_internal/lumira_theme_resolver.dart'
    show LumiraThemeResolver, CaptureOverlayVisual;
export '../../../core/theme/capture_appearance.dart';
```

- [ ] **Step 4: 运行测试确认通过**

```powershell
cd d:\app\projects\photo_post\lumira_app_flutter ; flutter test test/shared/widgets/lumira_theme_resolver_capture_test.dart ; flutter analyze
```
预期：全部 PASS；analyze 无新增问题。

- [ ] **Step 5: Commit**

```powershell
git add lumira_app_flutter/lib/shared/widgets/lumira/_internal/lumira_theme_resolver.dart lumira_app_flutter/lib/shared/widgets/lumira/lumira.dart lumira_app_flutter/test/shared/widgets/lumira_theme_resolver_capture_test.dart ; git commit -m "feat(theme): captureOverlayVisual 拍摄浮层视觉解析器（2 外观 × 4 风格 × 2 角色）"
```

---

### Task 3: 设置页开关

**Files:**
- Modify: `lumira_app_flutter/lib/features/profile/pages/profile_settings_page.dart`

**Interfaces:**
- Consumes: Task 1 的 `CaptureState.captureAppearanceProvider/loadCaptureAppearance/persistCaptureAppearance`、`CaptureAppearance`

- [ ] **Step 1: initState 加载**

`initState` 中（`loadDefaultResolution` microtask 之后）追加：
```dart
    // 从 DB 异步加载拍摄外观到 provider（与拍摄页/预览页共享同一状态）。
    Future.microtask(() =>
        CaptureState.loadCaptureAppearance(ProviderScope.containerOf(context, listen: false)));
```

- [ ] **Step 2: build 中 watch + 「拍摄」分组顶部加开关**

1. import 区加 `import '../../../core/theme/capture_appearance.dart';`
2. build 内 `final defaultResolution = ...` 附近追加：
```dart
    // 拍摄外观（沉浸式 vs 跟随主题，与拍摄页/预览页共享）
    final captureAppearance = ref.watch(CaptureState.captureAppearanceProvider);
```
3. 「拍摄」分组 `NeuCard` 的 `Column.children` 中，`默认分辨率` 条目**之前**插入：
```dart
                      _SettingItem(
                        icon: Icons.dark_mode_outlined,
                        label: '沉浸式取景',
                        trailing: LumiraSwitch(
                          value: captureAppearance == CaptureAppearance.immersive,
                          onChanged: (v) {
                            // 更新共享 provider + 持久化（拍摄页/预览页即时联动）
                            final next = v
                                ? CaptureAppearance.immersive
                                : CaptureAppearance.theme;
                            final container =
                                ProviderScope.containerOf(context, listen: false);
                            ref
                                .read(CaptureState.captureAppearanceProvider.notifier)
                                .state = next;
                            CaptureState.persistCaptureAppearance(container, next);
                          },
                        ),
                        tokens: tokens,
                      ),
```

- [ ] **Step 3: 验证**

```powershell
cd d:\app\projects\photo_post\lumira_app_flutter ; flutter analyze
```
预期：0 error。

- [ ] **Step 4: Commit**

```powershell
git add lumira_app_flutter/lib/features/profile/pages/profile_settings_page.dart ; git commit -m "feat(settings): 拍摄分组新增「沉浸式取景」开关（联动拍摄页/预览页外观）"
```

---

### Task 4: 拍摄页页面级（Scaffold 背景 ×3 + 权限引导页主题化）

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/pages/capture_page.dart`（build 方法 L2026-2053 区域）
- Modify: `lumira_app_flutter/lib/features/capture/widgets/capture_bottom_controls.dart`（`CameraPermissionGuide` L1833-1930）

**Interfaces:**
- Consumes: Task 1 provider/枚举；Task 2 无需（页面级只用 tokens.canvas）

- [ ] **Step 1: capture_page Scaffold 背景**

build 方法内（权限判断之前）加：
```dart
    // 拍摄页画布：immersive=纯黑 / theme=主题画布色（比例模式 letterbox 区域可见）
    final appearance = ref.watch(CaptureState.captureAppearanceProvider);
    final captureCanvas = appearance == CaptureAppearance.theme
        ? ref.watch(themeTokensProvider).canvas
        : Colors.black;
```
（import 区确认已有 `theme_controller.dart` 与 `capture_appearance.dart`——后者经 `capture_state.dart` 不传递，需显式 `import '../../../core/theme/capture_appearance.dart';`）

三处 `backgroundColor: Colors.black` 全部替换为 `backgroundColor: captureCanvas`：
- L2030（unknown/denied 权限页）
- L2041（permanentlyDenied 权限页）
- L2052（正常拍摄页）

- [ ] **Step 2: CameraPermissionGuide 主题化**

`CameraPermissionGuide` 从 `StatelessWidget` 改为 `ConsumerWidget`（`build(BuildContext context, WidgetRef ref)`），build 开头加：
```dart
    final appearance = ref.watch(CaptureState.captureAppearanceProvider);
    final tokens = ref.watch(themeTokensProvider);
    final isThemed = appearance == CaptureAppearance.theme;
    // 主/次/三级前景：immersive 白系；theme 跟 tokens
    final fg = isThemed ? tokens.textPrimary : Colors.white;
    final fgSecondary = isThemed ? tokens.textSecondary : Colors.white70;
    final fgMuted = isThemed ? tokens.textTertiary : Colors.white54;
```
然后按映射替换（去掉相应 `const`）：
- 返回按钮 `LumiraIconButton(color: Colors.white)` → `color: fg`
- 相机图标 `color: Colors.white54` → `color: fgMuted`
- 标题 `'相机权限未开启'` 的 `color: Colors.white` → `color: fg`
- 说明文字 `color: Colors.white70` → `color: fgSecondary`
- `LumiraButton`（primary/ghost）本身已主题化，不动

- [ ] **Step 3: 验证 + Commit**

```powershell
cd d:\app\projects\photo_post\lumira_app_flutter ; flutter analyze
```
```powershell
git add lumira_app_flutter/lib/features/capture/pages/capture_page.dart lumira_app_flutter/lib/features/capture/widgets/capture_bottom_controls.dart ; git commit -m "feat(capture): 拍摄页画布与权限引导页支持跟随主题模式"
```

---

### Task 5: 顶部胶囊家族（CaptureNav 完整示例 + 比例/参数/延时）

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/widgets/capture_nav.dart`
- Modify: `lumira_app_flutter/lib/features/capture/widgets/aspect_ratio_selector.dart`
- Modify: `lumira_app_flutter/lib/features/capture/widgets/param_pill_bar.dart`
- Modify: `lumira_app_flutter/lib/features/capture/widgets/apply_button.dart`
- Modify: `lumira_app_flutter/lib/features/capture/widgets/raw_mode_toggle.dart`
- Modify: `lumira_app_flutter/lib/features/capture/widgets/delay_timer_button.dart`

**Interfaces:**
- Consumes: Task 1 provider、Task 2 `LumiraThemeResolver.captureOverlayVisual` / `CaptureOverlayRole`（经 barrel `lumira.dart` 或直接 import `_internal/lumira_theme_resolver.dart`；`CaptureAppearance` 经 `core/theme/capture_appearance.dart`）

- [ ] **Step 1: CaptureNav（完整示例，先做）**

`capture_nav.dart` build 方法改造（`_NavIcon` 增加 `defaultColor` 参数由调用方传入；标题/副标题/激活图标全部走 visual）：
```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTemplateId = ref.watch(CaptureState.currentTemplateIdProvider);
    final isFullscreen = ref.watch(CaptureState.isFullscreenProvider);
    final isTrialMode = ref.watch(CaptureState.trialModeProvider);
    final showTemplate = ref.watch(CaptureState.showTemplateProvider);
    final showSilhouette = ref.watch(CaptureState.showSilhouetteProvider);
    final flashMode = ref.watch(CaptureState.flashModeProvider);
    final facing = ref.watch(CaptureState.cameraFacingProvider);
    // 双模式视觉：immersive=暗色胶囊 / theme=当前风格的叠照片浮层取向
    final visual = LumiraThemeResolver.captureOverlayVisual(
      tokens: ref.watch(themeTokensProvider),
      style: ref.watch(appThemeProvider).style,
      appearance: ref.watch(CaptureState.captureAppearanceProvider),
      role: CaptureOverlayRole.pill,
      radiusDp: 28,
    );

    final hasTemplate = currentTemplateId != null;
    final showFlashButton = facing == 'back' && !isTrialMode;

    final rightButtonCount = isTrialMode
        ? 1
        : 1 +
            (hasTemplate ? 2 : 0) +
            1 +
            (showFlashButton ? 1 : 0);
    final balancePadding = !hasTemplate && !isTrialMode
        ? (rightButtonCount - 1) * 36.0
        : 0.0;

    final Widget capsule = Container(
      height: 48,
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: BorderRadius.circular(28),
        border: visual.border,
        boxShadow: visual.shadows,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _NavIcon(
              icon: Icons.arrow_back_ios_new,
              onPressed: onBack,
              iconColor: visual.foreground,
            ),
            if (balancePadding > 0) SizedBox(width: balancePadding),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (isTrialMode) {
                    LumiraToast.show(
                      context,
                      '试用模式不可调整参数，购买解锁后即可使用',
                      duration: const Duration(milliseconds: 1200),
                    );
                    return;
                  }
                  ref
                      .read(CaptureState.panelExpandedProvider.notifier)
                      .state = true;
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      isTrialMode
                          ? '试用模板'
                          : (hasTemplate ? '模板拍摄' : '自由调参'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: visual.foreground,
                        height: 1.2,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasTemplate && !isTrialMode)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '点击调整参数',
                          style: TextStyle(
                            fontSize: 11,
                            color: visual.foregroundSecondary,
                            height: 1.2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (isTrialMode)
              _NavIcon(
                icon: Icons.lock_open_outlined,
                tooltip: '购买解锁',
                onPressed: () { /* 原逻辑不变 */ },
              )
            else ...[
              _NavIcon(
                icon: isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                iconColor: visual.foreground,
                onPressed: () => ref
                    .read(CaptureState.isFullscreenProvider.notifier)
                    .state = !isFullscreen,
              ),
              if (hasTemplate)
                _NavIcon(
                  icon: Icons.crop_free,
                  iconColor:
                      showTemplate ? visual.accent : visual.foreground,
                  onPressed: () => ref
                      .read(CaptureState.showTemplateProvider.notifier)
                      .state = !showTemplate,
                ),
              if (hasTemplate)
                _NavIcon(
                  icon: Icons.accessibility_new,
                  iconColor:
                      showSilhouette ? visual.accent : visual.foreground,
                  onPressed: () => ref
                      .read(CaptureState.showSilhouetteProvider.notifier)
                      .state = !showSilhouette,
                ),
              _NavIcon(
                icon: Icons.explore,
                tooltip: '使用指南',
                iconColor: visual.foreground,
                onPressed: () =>
                    GoRouter.of(context).push(RouteNames.captureTutorial),
              ),
              if (showFlashButton)
                _NavIcon(
                  icon: flashMode == CaptureFlashMode.off
                      ? Icons.flash_off
                      : flashMode == CaptureFlashMode.torch
                          ? Icons.flashlight_on
                          : Icons.flash_on,
                  iconColor: flashMode != CaptureFlashMode.off
                      ? visual.accent
                      : visual.foreground,
                  onPressed: () {
                    final next = flashMode == CaptureFlashMode.off
                        ? CaptureFlashMode.torch
                        : CaptureFlashMode.off;
                    ref.read(CaptureState.flashModeProvider.notifier).state = next;
                  },
                ),
            ],
          ],
        ),
      ),
    );

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        // backdropBlurSigma>0 才包毛玻璃（immersive 非 neu / theme glass）；
        // 新拟态双轨下 sigma=0 直接呈现胶囊本体
        child: visual.backdropBlurSigma > 0
            ? ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: visual.backdropBlurSigma,
                    sigmaY: visual.backdropBlurSigma,
                  ),
                  child: capsule,
                ),
              )
            : capsule,
      ),
    );
  }
```
`_NavIcon` 的 `iconColor` 默认值 `Colors.white` 改为必传（`required this.iconColor`），所有调用点已在上文补齐。删除原 `isNeu` 变量。import：`capture_appearance.dart` 不必直接 import（枚举经 `CaptureState.captureAppearanceProvider` 的值比较需要 `CaptureAppearance`，需 import `core/theme/capture_appearance.dart`；或统一经 barrel `lumira.dart`）。

- [ ] **Step 2: AspectRatioSelector**

按 Task 5 Step 1 模式改造：
- 删 `isNeu`，加 `visual`（role=pill, radiusDp=20）
- 胶囊 `BoxDecoration`：`color: visual.background, border: visual.border, boxShadow: visual.shadows`（原 0xFF141416@0.72 / white0.1 / black0.15）
- 激活档：`color: active ? visual.accent : Colors.transparent`，激活阴影 `Color(0xFFC9A96E).withOpacity(0.25)` → `visual.accent.withOpacity(0.25)`
- 档内图标/文字：`active ? Colors.black : Colors.white.withOpacity(0.5)` → `active ? visual.onAccent : visual.foregroundSecondary`
- 毛玻璃包裹：`isNeu ? capsule : BackdropFilter(blur 24)` → `visual.backdropBlurSigma > 0 ? BackdropFilter(visual.backdropBlurSigma) : capsule`

- [ ] **Step 3: ParamPillBar + 子组件**

`param_pill_bar.dart`：同模式（role=pill, radiusDp=20）；`_Pill` 改为接收 `CaptureOverlayVisual visual`（构造参数），内部 `Colors.white` → `visual.foreground`。
`apply_button.dart` / `raw_mode_toggle.dart`：读取两文件，按映射总表替换（这两个是 pill 内小控件：白字/白图标 → visual 前景，激活金 → accent；底色若有 white12 → fillSubtle）。visual 从父级传入或组件内自行 watch（自行 watch 更简单，二者均为 ConsumerWidget 或改为 ConsumerWidget）。

- [ ] **Step 4: DelayTimerButton**

`delay_timer_button.dart`（role=pill, radiusDp=22 圆形）：
- 圆钮底 `0xFF141416@0.72` → `visual.background`；边 `white@0.3` → `visual.border`
- 图标 `isActive ? 0xFFC9A96E : Colors.white` → `isActive ? visual.accent : visual.foreground`
- 角标底 `0xFFC9A96E` → `visual.accent`，角标字 `Colors.black` → `visual.onAccent`
- `PopupMenuButton` 的 `color: Color(0xFF26262A)` → theme 模式 `tokens.surface`（组件内 watch tokens；immersive 保持 0xFF26262A）。菜单项文字 `Colors.white` → theme 模式 `tokens.textPrimary`；选中勾 `0xFFC9A96E` → `visual.accent`

- [ ] **Step 5: 验证 + Commit**

```powershell
cd d:\app\projects\photo_post\lumira_app_flutter ; flutter analyze ; flutter test
```
预期：analyze 0 error；现有测试全过。
```powershell
git add lumira_app_flutter/lib/features/capture/widgets ; git commit -m "feat(capture): 顶部胶囊家族接入双模式视觉（导航/比例/参数pill/延时）"
```

---

### Task 6: 底部控制区（scrim / 工具栏 / 抽屉容器 / 快门行 / 缩略图 / 补光面板 / ZoomBar）

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/widgets/capture_bottom_controls.dart`（约 2000 行，含 CaptureBottomBar/CaptureToolbar/ToolButton/AnimatedToolDrawer/CaptureFillLightPanel/PresetColorDot/ActionDot/SquareColorPicker/SaveColorsRow/ZoomBar/CaptureButtonRow/LockedCaptureButton）
- Modify: `lumira_app_flutter/lib/features/capture/widgets/capture_button.dart`
- Modify: `lumira_app_flutter/lib/features/capture/widgets/capture_thumbnail.dart`

**Interfaces:**
- Consumes: 同 Task 5

- [ ] **Step 1: CaptureBottomBar scrim**

`CaptureBottomBar` 从 `StatelessWidget` 改 `ConsumerWidget`，build 加：
```dart
    final appearance = ref.watch(CaptureState.captureAppearanceProvider);
    final tokens = ref.watch(themeTokensProvider);
    // scrim：immersive=黑渐变（现状）；theme=画布色渐变（照片向画布过渡）
    final scrimBase = appearance == CaptureAppearance.theme
        ? tokens.canvas
        : Colors.black;
```
原渐变 `Colors.black.withOpacity(0.3/0.7/0.95)` → `scrimBase.withOpacity(0.3/0.7/0.95)`。

- [ ] **Step 2: CaptureToolbar + ToolButton**

`CaptureToolbar` 容器（role=pill, radiusDp=24）：`Colors.black.withOpacity(0.4)` → `visual.background`；`white@0.08` 边 → `visual.border`。
`ToolButton` 改为接收 `CaptureOverlayVisual visual` 参数（由 CaptureToolbar 传入）：`active ? 0xFFC9A96E : Colors.white70` → `active ? visual.accent : visual.foregroundSecondary`（图标+文字+选中指示条，指示条 `Colors.transparent` 不变）。

- [ ] **Step 3: AnimatedToolDrawer 容器**

`Colors.black.withOpacity(0.4)` 全宽容器 → `visual.background`（role=panel, radius 0——border/shadows 传 null/空则 resolver 输出照用，容器无圆角直接用 background 即可）。drawer 内的 TemplateStrip/ScenePresetStrip/FilterPicker/CaptureFillLightPanel 在 Task 7 改。

- [ ] **Step 4: CaptureButtonRow / CaptureButton / LockedCaptureButton / CaptureThumbnail**

- 切换摄像头圆钮：`white@0.1` 底 → theme 时 `tokens.surface.withOpacity(0.9)`、immersive 保持；边 `white@0.3` → theme `tokens.divider`；图标 `Colors.white` → theme `tokens.textPrimary`。（组件改 ConsumerWidget 后按 appearance 分支，或统一用 pill visual 字段近似映射：底=visual.background、边=visual.border、图标=visual.foreground——**优先用 visual 字段**，视觉统一）
- `capture_button.dart` CaptureButton：外环 `Border.all(color: Colors.white, width: 4)` 与内圆 `Colors.white` → theme 时 `tokens.textPrimary`（浅画布上呈深色快门，高对比），immersive 保持白色。需改 ConsumerWidget。
- LockedCaptureButton：环 `white@0.6` → visual 前景类映射；内圆 `white@0.85` → theme `tokens.textPrimary.withOpacity(0.85)`；锁图标 `Colors.black54` → theme `tokens.canvas`（内圆上的对比色）。
- `capture_thumbnail.dart`：读文件后按映射总表替换（白色环/边/占位 → visual 对应字段；组件改 ConsumerWidget）。

- [ ] **Step 5: 补光面板 + 色环 + 保存色行（CaptureFillLightPanel 家族）**

按映射总表替换（role=panel）：
- `Colors.white`（「补光」标题）→ `visual.foreground`
- `Colors.white54`（提示/图标）→ `visual.foregroundMuted`
- `Colors.white70`（百分比文字）→ `visual.foregroundSecondary`
- `PresetColorDot`/`ActionDot`：`selected ? 0xFFC9A96E : white24/white54` → `selected ? visual.accent : visual.foregroundMuted`；底 `white12` → `visual.fillSubtle`
- `SaveColorsRow`：white 系文字 → visual 前景字段；`white24` 边 → `visual.border` 的颜色（`visual.border?.top.color`，或直接 `tokens.divider` theme 分支——用 `visual.fillSubtle`）
- `SquareColorPicker` CustomPainter（L710-729 附近）：白色指示点/白黑渐变属取色器功能色，**保持不变**（颜色选择 UI 的黑白色是内容语义，不是主题观感）
- 自定义色对话框（L852-1007 区域）：white 文字 → visual 前景；`white24` 边 → fillSubtle；`0xFFC9A96E` → accent

- [ ] **Step 6: ZoomBar（缩放轮盘）**

ZoomBar 区域（L1137-1710）：容器 `Colors.black.withOpacity(0.35/0.55)` → `visual.background`（panel）；`Colors.white.withOpacity(0.06/0.22/0.3)` 底/边 → `visual.fillSubtle` / `visual.border` 颜色；文字 `Colors.white` → `visual.foreground`；激活黄 `Color(0xFFF0C040)` → `visual.accent`，其上黑字 `Colors.black` → `visual.onAccent`。CustomPainter 内的白色刻度线（L1589/1625）→ `visual.foregroundMuted.withOpacity(0.25/0.35/0.75)` 对应原透明度（painter 构造参数传入颜色）。

- [ ] **Step 7: 验证 + Commit**

```powershell
cd d:\app\projects\photo_post\lumira_app_flutter ; flutter analyze ; flutter test
```
```powershell
git add lumira_app_flutter/lib/features/capture/widgets ; git commit -m "feat(capture): 底部控制区接入双模式视觉（scrim/工具栏/快门行/补光/缩放轮盘）"
```

---

### Task 7: 抽屉面板家族（模板抽屉 / 模板条 / 场景条 / 滤镜 / 参数面板）

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/widgets/template_drawer_panel.dart`
- Modify: `lumira_app_flutter/lib/features/capture/widgets/template_strip.dart`
- Modify: `lumira_app_flutter/lib/features/capture/widgets/scene_preset_strip.dart`
- Modify: `lumira_app_flutter/lib/features/capture/widgets/filter_picker.dart`
- Modify: `lumira_app_flutter/lib/features/capture/widgets/param_panel.dart`

**Interfaces:**
- Consumes: 同 Task 5；role=panel

- [ ] **Step 1: TemplateDrawerPanel**

按映射总表（role=panel）逐处替换（行号参考，执行时以实际读取为准）：
- L75 `Colors.black.withOpacity(0.55)` 面板底 → `visual.background`
- L86/114/139/145/158 white54/white/white38 → `visual.foregroundMuted` / `visual.foreground` 对应映射
- L105 white（标题等）→ `visual.foreground`
- L127/129 搜索框底 white10 + white24 边 → `visual.fillSubtle` + `visual.border`
- L140 cursorColor white70 → `visual.foregroundSecondary`
- L193 激活 `Colors.amber` → `visual.accent`；white12 未激活底 → `visual.fillSubtle`
- L212/223/234/250/256/261 模板卡黑底白字 → 卡底 `visual.fillSubtle`（或 theme 时 `tokens.surfaceAlt`）、文字 `visual.foreground`/`foregroundSecondary`、锁图标 `visual.foregroundMuted`
- L283 `Colors.black`（选中描边上的字）→ `visual.onAccent`（描边用 `visual.accent`）
- L299-318 占位图标 white12 底 + white54 图标 → `visual.fillSubtle` + `visual.foregroundMuted`

- [ ] **Step 2: TemplateStrip / ScenePresetStrip / FilterPicker**

三个文件逐处按映射总表替换（role=panel；激活金 0xFFC9A96E → accent、白系文字 → foreground 系列、white12/10 底 → fillSubtle、white24 边 → visual.border 颜色）。读文件时注意：条内缩略图卡片若为图片本身，不加底色；文字标签用 foreground。

- [ ] **Step 3: ParamPanel**

`param_panel.dart`（role=panel, radiusDp 由现有值决定）：
- L184-185 渐变 `Colors.black.withOpacity(0.82)` / `Color.lerp(Colors.black, tokens.brand, 0.16)` → theme 时 `visual.background`（纯色）；immersive 时**保留原渐变**（该渐变含 brand 色调，是现状视觉，resolver immersive panel 为纯色 0.80——为忠实现状，此处 immersive 保留原渐变表达式，theme 用 visual.background；即渐变整体替换为 `appearance == theme ? visual.background : 原渐变`）。简化实现：`color: visual.background` 且 visual immersive panel 已定 0.80 近似原 0.82——**选择简化**，直接 `visual.background`（0.80 vs 0.82 视觉不可辨）
- L191/204/217 white@0.08/0.14/0.06 边 → `visual.border`
- L287/297/316 white@0.22/0.06 底 → `visual.fillSubtle`
- L303/325/334/440/706-734/786-798/841 白系文字与 accent → visual 对应字段（`accent` 变量已有 tokens.brand，theme 模式一致；immersive 保留原 white70/38/24 系 → visual 前景字段即等价）
- 面板内滑块/按钮若用 Lumira 组件则已主题化不动

- [ ] **Step 4: 验证 + Commit**

```powershell
cd d:\app\projects\photo_post\lumira_app_flutter ; flutter analyze ; flutter test
```
```powershell
git add lumira_app_flutter/lib/features/capture/widgets ; git commit -m "feat(capture): 抽屉面板家族接入双模式视觉（模板/场景/滤镜/参数面板）"
```

---

### Task 8: 其余浮层（挑战条 / 模板信息卡 / 水平仪）

**Files:**
- Modify: `lumira_app_flutter/lib/features/challenge/widgets/challenge_overlay_bar.dart`
- Modify: `lumira_app_flutter/lib/features/capture/widgets/template_info_card.dart`
- Modify: `lumira_app_flutter/lib/features/capture/widgets/level_indicator.dart`
- Check: `lumira_app_flutter/lib/features/capture/widgets/scene_achievement_card.dart`（仅 1 处硬编码，读后按映射处理或确认无关则不动）

**Interfaces:**
- Consumes: 同 Task 5；challenge 组件 role=pill

- [ ] **Step 1: ChallengeOverlayBar**

`_buildCard`（L121-240）：
- 卡底 `Color(0xF0171512).withOpacity(0.92)` → `visual.background`（role=pill）；阴影 black@0.30 → `visual.shadows`；brand 边保留（theme/immersive 均可，tokens 已主题化）
- `Colors.white` 标题 → `visual.foreground`；`white@0.7` 展开箭头 → `visual.foregroundSecondary`；分隔线 `white@0.12` → `visual.fillSubtle`；描述 `white@0.78` → `visual.foregroundSecondary`；提示 `white@0.85` → `visual.foreground`
- XP 徽标/图标已用 tokens.brand，不动
- 组件已是 ConsumerWidget（watch themeTokensProvider），追加 appearance/style watch 即可

- [ ] **Step 2: TemplateInfoCard**

读文件：若已按风格自适应（类似 CapturePoseSwitchButton 的 per-style switch），仅在其基础上让 immersive 模式回落暗色（用 visual pill 字段替换其 switch 分支，统一走 resolver）；若仍是白系硬编码，按映射总表替换（role=pill）。

- [ ] **Step 3: LevelIndicator（可选润色）**

`_LevelPainter` 颜色改构造参数：`trackColor`/`centerDotColor` 由 build 传入——immersive 保持 `Colors.white24`/`white38`（叠照片白线例外）；theme 时传 `tokens.textTertiary.withOpacity(0.4)`/`tokens.textTertiary`。气泡 `Colors.amber` → theme 时 `tokens.brand`，水平绿 `0xFF69F0AE` 两模式均保留（功能语义色）。

- [ ] **Step 4: 验证 + Commit**

```powershell
cd d:\app\projects\photo_post\lumira_app_flutter ; flutter analyze ; flutter test
```
```powershell
git add lumira_app_flutter/lib/features ; git commit -m "feat(capture): 挑战条/模板信息卡/水平仪接入双模式视觉"
```

---

### Task 9: 拍摄预览页

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/pages/capture_preview_page.dart`

**Interfaces:**
- Consumes: Task 1 provider；`LumiraSurface.darkContext`（现有组件参数）

- [ ] **Step 1: build 加 watch + Scaffold/照片区背景**

build 方法（L1256-1274 区域）`final appTheme = ...` 后加：
```dart
    final appearance = ref.watch(CaptureState.captureAppearanceProvider);
    final isThemed = appearance == CaptureAppearance.theme;
```
- L1274 `backgroundColor: Colors.black` → `backgroundColor: isThemed ? tokens.canvas : Colors.black`
- `_buildPhotoStage` 内两处 `backgroundDecoration: const BoxDecoration(color: Colors.black)`（L1431-1432 单张 / L1448-1449 画廊）→ `backgroundDecoration: BoxDecoration(color: isThemed ? tokens.canvas : Colors.black)`（`isThemed` 需作为参数传入 `_buildPhotoStage` 或在方法内重新 watch——方法在 State 内，用 `ref.watch` 即可）
- 顶部注释 L46 「深色背景 + LumiraNav transparent」更新为「背景随拍摄外观设置：沉浸式纯黑 / 跟随主题画布色」

- [ ] **Step 2: 顶栏图标可读性**

`_PreviewNav` 与 `_NavIcon`（L1529-1710 区域）中 `tokens.textInverse`（返回/分享/删除/保存到相册图标及保存 pill 内图标文字）→ immersive 保持 `tokens.textInverse`（深底白字），theme 改 `tokens.textPrimary`。实现：`_PreviewNav` 加 `final bool isThemed;` 构造参数，调用处传入；颜色表达式 `isThemed ? tokens.textPrimary : tokens.textInverse`。保存 pill 的渐变 `tokens.brand/brandDeep` 与其上 `textInverse` 文字保留（品牌按钮两模式均成立——brand 底上 textInverse 是对比色）。

- [ ] **Step 3: 底部编辑 dock**

`_buildEditDock`（L1481-1526）`LumiraSurface(darkContext: true)` → `darkContext: !isThemed`（theme 模式走正常画布卡片分支）。

- [ ] **Step 4: 验证 + Commit**

```powershell
cd d:\app\projects\photo_post\lumira_app_flutter ; flutter analyze ; flutter test
```
```powershell
git add lumira_app_flutter/lib/features/capture/pages/capture_preview_page.dart ; git commit -m "feat(preview): 拍摄预览页支持跟随主题模式（画布/照片区/顶栏/dock）"
```

---

### Task 10: 全局验证与收尾

**Files:**
- 无新文件（验证任务）

- [ ] **Step 1: 全量静态检查与测试**

```powershell
cd d:\app\projects\photo_post\lumira_app_flutter ; flutter analyze ; flutter test
```
预期：analyze 0 error（且无新增 warning）；测试全过。

- [ ] **Step 2: 硬编码残留扫描**

```powershell
cd d:\app\projects\photo_post\lumira_app_flutter ; Select-String -Path "lib\features\capture\widgets\*.dart","lib\features\capture\pages\capture_page.dart","lib\features\capture\pages\capture_preview_page.dart" -Pattern "0xFF141416|0xFFC9A96E|0xFF26262A|0xFFF0C040" | Select-Object -First 30
```
预期：仅 resolver（`lumira_theme_resolver.dart`）与 delay timer 的 `0xFF26262A`（若 Task 5 已处理则无）存在；组件文件中 0 命中。

- [ ] **Step 3: 手动验收清单（真机/模拟器）**

1. 默认设置（沉浸式开）：拍摄页、预览页与改造前视觉一致（黑底暗浮层）
2. 设置 → 拍摄 → 关闭「沉浸式取景」：两页面即时切换为主题外观
3. 4 风格 × 2 主题（warmWhite/ink）× 2 外观组合检查：无黑色残留浮层、无风格混搭（neu 无毛玻璃/无浮雕阴影、glass 有模糊、female 品牌阴影）
4. 沉浸式回归：比例切换（letterbox 黑）、模板抽屉、参数面板、滤镜、补光、缩放轮盘、快门/缩略图/切摄、水平仪、延时菜单
5. 杀进程重启：设置保持（持久化生效）
6. 权限拒绝态：主题模式下权限引导页文字可读

- [ ] **Step 4: 最终 Commit（如有收尾修改）**

```powershell
git add -A lumira_app_flutter ; git commit -m "chore(capture): 双模式外观收尾（扫描残留清理）"
```

---

## Self-Review 记录

- Spec 覆盖：数据层（Task 1）、解析器（Task 2）、设置项（Task 3）、拍摄页（Task 4-8）、预览页（Task 9）、测试（Task 1/2 + 各任务 analyze/test）、验收（Task 10）✓
- 沉浸式零回归例外已显式声明（胶囊 alpha/blur/面板底小统一），记录于 Global Constraints ✓
- 类型一致性：`CaptureAppearance`/`CaptureOverlayRole`/`CaptureOverlayVisual`/`captureOverlayVisual` 名称在 Task 1/2/5-9 一致 ✓
- 已知简化：ParamPanel immersive 渐变→纯色 0.80（0.82 不可辨）；LevelIndicator 为可选润色 ✓
