# Task 2 实施报告：新增 HomeBrandTitle 组件

## 状态总览

```
STATUS: DONE_WITH_CONCERNS
COMMITS: 15c0544099fc071ced3ba377516b7dddbc223c8d
TESTS: flutter test test/shared/widgets/brand/home_brand_title_test.dart → 3 tests PASS
       flutter analyze lib/shared/widgets/brand/home_brand_title.dart lib/core/preferences/home_wordmark_style.dart → No issues found
CONCERNS: 测试文件添加了计划中遗漏的 `import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';`（详见下文）
```

## 执行步骤

### Step 1: 写失败测试 ✅

创建了 `test/shared/widgets/brand/home_brand_title_test.dart`，使用计划中"修正后测试代码"（单层 ProviderScope + style 参数）。

**关键偏离说明（CONCERN）：**

计划中修正后的测试代码只导入了 `theme_controller.dart`：
```dart
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
```

但 `ThemeKey` 和 `UIStyle` 枚举实际定义在 `theme_tokens.dart` 中。Dart 的导入规则不允许通过 `theme_controller.dart` 间接访问这些枚举的值（`ThemeKey.warmWhite`、`UIStyle.neumorphic`），导致编译错误：
```
Error: Undefined name 'ThemeKey'.
Error: Undefined name 'UIStyle'.
```

参考项目现有测试 `test/features/splash/splash_page_test.dart`（第 7-8 行）的约定——同时导入两个文件：
```dart
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
```

因此在测试文件中添加了缺失的 import：
```dart
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
```

此修复不改变测试的任何逻辑或断言，仅让代码能编译。实现文件 `home_brand_title.dart` 本身已包含此 import（计划中的实现代码正确）。

### Step 2: 运行测试验证失败 ✅

命令：`flutter test test/shared/widgets/brand/home_brand_title_test.dart`

结果：FAIL（exit code 1）

失败原因（预期）：
- `lib/shared/widgets/brand/home_brand_title.dart` 不存在
- `HomeBrandTitle` 构造函数找不到

符合 TDD RED 阶段——因功能缺失而失败。

### Step 3: 创建 HomeBrandTitle 组件 ✅

创建了 `lib/shared/widgets/brand/home_brand_title.dart`，代码与计划完全一致。

组件特性：
- `class HomeBrandTitle extends ConsumerWidget`
- `const HomeBrandTitle({super.key, this.preview = false})`
- 监听 `homeWordmarkStyleProvider` 和 `appThemeProvider`
- 三种排版：
  - `logoEnglish`：符号标 + Lumira 英文
  - `logoEnglishChinese`：符号标 + Lumira + 如画
  - `englishChinese`：Lumira + 如画（无 logo）
- `preview` 参数控制尺寸（设置页预览用更小尺寸）

### Step 4: 运行测试验证通过 ✅

命令：`flutter test test/shared/widgets/brand/home_brand_title_test.dart`

结果：PASS（exit code 0）

```
00:00 +0: HomeBrandTitle default style is logoEnglish
00:00 +1: HomeBrandTitle logoEnglishChinese renders logo + Lumira + 如画
00:00 +2: HomeBrandTitle englishChinese renders Lumira + 如画 without logo
00:01 +3: All tests passed!
```

3 个测试全部通过，符合 TDD GREEN 阶段。

### Step 5: 运行 analyze 确保无警告 ✅

命令：`flutter analyze lib/shared/widgets/brand/home_brand_title.dart lib/core/preferences/home_wordmark_style.dart`

结果：No issues found! (ran in 2.0s)

### Step 6: git 提交 ✅

命令：
```bash
git add lib/shared/widgets/brand/home_brand_title.dart test/shared/widgets/brand/home_brand_title_test.dart
git commit -m "feat(brand): add HomeBrandTitle widget with 3 switchable layouts"
```

结果：
- Commit hash: `15c0544099fc071ced3ba377516b7dddbc223c8d`
- 2 files changed, 138 insertions(+)
- Commit message 与计划完全一致

## 依赖验证

| 依赖 | 位置 | 状态 |
|------|------|------|
| `HomeWordmarkStyle` 枚举 | `lib/core/preferences/home_wordmark_style.dart` | ✅ Task 1 已完成 |
| `homeWordmarkStyleProvider` | `lib/core/preferences/home_wordmark_style.dart` | ✅ Task 1 已完成 |
| `appThemeProvider` | `lib/core/theme/theme_controller.dart` | ✅ 现有 |
| `AppThemeData.tokens` | `lib/core/theme/app_theme.dart` | ✅ 现有 |
| `LumiraLogo.symbol({double size})` | `lib/shared/widgets/brand/lumira_logo.dart` | ✅ 现有 |
| `ThemeTokens.textPrimary` / `.brand` | `lib/core/theme/theme_tokens.dart` | ✅ 现有 |
| `ThemeKey.warmWhite` / `UIStyle.neumorphic` | `lib/core/theme/theme_tokens.dart` | ✅ 现有 |

## 产出文件

| 文件 | 类型 | 行数 |
|------|------|------|
| `lib/shared/widgets/brand/home_brand_title.dart` | 新增 | 99 行 |
| `test/shared/widgets/brand/home_brand_title_test.dart` | 新增 | 49 行 |

## 后续任务影响

- Task 8 将修改 `home_brand_title.dart` 添加 `styleOverride` 参数，并新增对应测试用例
- 当前实现已为 Task 8 预留了扩展空间（只需添加 `styleOverride` 字段和修改 build 第一行）
