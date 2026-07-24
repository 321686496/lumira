# Task 6 报告：首页使用 HomeBrandTitle 并传 centerTitle: false

## STATUS: DONE_WITH_CONCERNS

## 执行摘要

按计划 Task 6 的 Step 1-6 严格执行，完成 `lib/features/home/pages/home_page.dart` 的 appBar 改造：移除 `title: '如画'` 与 `_NavLocation` leading，改用 `LumiraNav(centerTitle: false, showBackButton: false, leading: const HomeBrandTitle(), ...)`；追加 `home_brand_title.dart` import；删除不再使用的 `_NavLocation` 类。

## COMMITS

- **Hash:** `fcf82268bc2cdd4ab2b3419a97b2f4a59eff3ade`
- **Message:** `feat(home): use HomeBrandTitle with left-aligned layout`
- **Files:** 2 files changed, 10 insertions(+), 39 deletions(-)
  - `lumira_app_flutter/lib/features/home/pages/home_page.dart`
  - `lumira_app_flutter/test/features/home/home_page_test.dart`（计划外修改，见 CONCERNS）

## 各 Step 执行情况

### Step 1: 修改 home_page.dart appBar ✅
严格按计划"替换为"代码块修改。原代码（实际为 `title: '如画'`，非计划描述的 `useWordmark: true`——可能是 Task 1-5 期间变动）替换为：
```dart
appBar: LumiraNav(
  centerTitle: false,
  transparent: true,
  scrolled: _scrolled,
  showBackButton: false,
  leading: const HomeBrandTitle(),
  actions: [...],
),
```

### Step 2: 添加 import ✅
在 import 区按字母序插入 `lib/features/home/pages/home_page.dart:8`：
```dart
import '../../../shared/widgets/brand/home_brand_title.dart';
```

### Step 3: 删除 _NavLocation 类 ✅
- Grep 确认 `_NavLocation` 仅在 `home_page.dart` 引用（无其他文件依赖）
- Grep 确认 `HomeMockData.location` 仅在 `home_page.dart`（_NavLocation 内）使用，但 `home_mock_data.dart` 仍被 `HomeMockData.banners/scenes/recents` 使用，故保留该 import
- 按计划给出的完整代码块删除 `_NavLocation` 类

### Step 4: flutter analyze ✅（无本次引入的警告）
```
flutter analyze lib/features/home/pages/home_page.dart
```
结果：3 个 info 级别问题，**均为预存在**（git diff 确认我的修改未触碰这些代码行）：
- `_goChallenge` unused (line 76) — 预存在
- prefer_const_constructors (line 131, 132) — body 区域 HomeBanner，预存在

无 "unused import" 警告（`home_mock_data.dart` 仍被使用，未误删）。

### Step 5: 运行首页测试 ✅（部分通过，1 项预存在失败）
```
flutter test test/features/home/home_page_test.dart
```
结果：**4 pass / 1 fail**

| 测试 | 结果 | 说明 |
|------|------|------|
| HomePage renders all 8 sections | ❌ FAIL | 预存在失败：`find.text('模板')` 找不到（QuickActions 区域）|
| HomePage tip refresh button changes tip text | ✅ PASS | |
| HomePage renders across 4 UI styles | ✅ PASS | |
| HomePage renders across 8 themes | ✅ PASS | |
| HomePage scroll toggles LumiraNav scrolled state | ✅ PASS | |

**'模板' 失败为预存在问题的验证：**
通过 `git stash push` 仅暂存我的两个文件（home_page.dart + home_page_test.dart），在提交态代码（Task 5 commit 7fa6e78，title:'如画' + _NavLocation）上运行提交态测试：
- line 106 `find.text('如画')` → PASS（提交态有 title:'如画'）
- line 107 `find.text('上海')` → PASS（提交态有 _NavLocation）
- line 116 `find.text('模板')` → **FAIL**（"zero widgets with text '模板'"）

这确证 '模板' 失败在 Task 6 之前就已存在，与本次修改无关。`LumiraNav.preferredSize` 固定为 `Size.fromHeight(56)`，不受 `centerTitle` 影响，body 布局（QuickActions 所在）完全未受 Task 6 影响。

### Step 6: git 提交 ✅
```bash
git add lib/features/home/pages/home_page.dart test/features/home/home_page_test.dart
git commit -m "feat(home): use HomeBrandTitle with left-aligned layout"
```
（计划 Step 6 仅 add home_page.dart；因我同步更新了测试断言，一并提交以保持仓库一致）

## TESTS

- **命令:** `flutter test test/features/home/home_page_test.dart`
- **结果:** 4 passed, 1 failed
- **失败项:** `HomePage renders all 8 sections` — `find.text('模板')` findsWidgets 断言失败（预存在，非 Task 6 引入）

## CONCERNS

### 1. 计划外修改了 home_page_test.dart（必要变更）
计划的"测试修改"清单仅列 `splash_page_test.dart` 与 `profile_about_page_test.dart`，未包含 `home_page_test.dart`。但 Task 6 的代码变更（移除 `title: '如画'`、删除 `_NavLocation`）使现有测试断言失效：
- 4 处 `expect(find.text('如画'), findsOneWidget)` → 改为 `expect(find.text('Lumira'), findsOneWidget)`（HomeBrandTitle 默认 logoEnglish 渲染 "Lumira"）
- 1 处 `expect(find.text('上海'), findsOneWidget)` → 删除（_NavLocation 已移除，'上海' 即 HomeMockData.location 不再显示）

这些更新是代码变更的直接必要后果（非"优化"），且计划 Step 5 明确期望"若存在则应通过"、Task 9 要求全部测试通过。已在提交中包含此文件。

### 2. 预存在测试失败：'模板' 断言
`HomePage renders all 8 sections` 测试中 `find.text('模板')` 失败。已通过 stash 对照实验确证此失败在 Task 5 提交态即存在，与 Task 6 无关。可能原因：QuickActions 渲染或视口/offstage 问题。建议后续任务排查（不在 Task 6 范围内）。

### 3. 预存在 analyze 警告
`flutter analyze lib/features/home/pages/home_page.dart` 报 3 个 info（`_goChallenge` unused + 2 处 prefer_const），均在我未修改的代码行，为预存在问题，按 scope 规则未处理。

### 4. 工作树存在大量先前任务的未提交变更
git status 显示 `pubspec.yaml`、`pubspec.lock`、`lumira_logo.dart`（untracked）、`capture_page.dart`、`academy_*.dart`、android/ios 资源等均为未提交状态。这些非 Task 6 引入，但提示先前任务的提交可能不完整（例如 `lumira_logo.dart` 仍为 untracked，`pubspec.yaml` 添加 flutter_svg 未提交）。stash 全部变更会导致 flutter_svg 编译失败——已通过仅 stash Task 6 文件的方式规避。
