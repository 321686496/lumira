# Task 4 报告：Splash 页添加主题色光晕

STATUS: DONE_WITH_CONCERNS
COMMITS: ff01a7b0778dbdefd3df2cbe31cc8de5ce4df28d
TESTS: `flutter test test/features/splash/splash_page_test.dart` → 3 tests passed (exit 0)
       `flutter analyze lib/features/splash/pages/splash_page.dart` → No issues found (ran in 4.2s)
CONCERNS: 计划 Step 2 标题写「运行测试验证可能通过（Stack 已存在）」但 Expected 又写「FAIL」，存在自相矛盾。实际跑测在 Step 1 之后、Step 3 之前测试已通过——因为 `MaterialApp.router` 内部 Navigator/Overlay 已含 Stack，导致 `find.byType(Stack), findsWidgets` 断言无法区分有无本次新增的 Stack。这是计划中测试用例的精度问题，非实现问题；计划要求「修改代码必须原样使用」，因此保留计划给定的断言。功能本身已按计划完整实现（160×160 圆形径向渐变光晕 + 80×80 logo 叠放在 Stack 中，颜色全部取自 tokens.brandSubtle / brandLight / canvas）。

## 执行步骤

### Step 1 — 修改 splash_page_test.dart
- 文件：`d:\app\projects\photo_post\lumira_app_flutter\test\features\splash\splash_page_test.dart`
- 将第一个测试名由 `SplashPage renders logo + title + caption` 改为 `SplashPage renders logo + title + caption + brand halo`
- 注释从「原 Icons.camera_outlined 已替换为设计好的品牌 SVG 符号标」改为「主题色光晕：用 Stack + Container(circle + RadialGradient)」
- 追加 `expect(find.byType(Stack), findsWidgets);`
- 原样采用计划给出的代码块

### Step 2 — 运行测试
- 命令：`flutter test test/features/splash/splash_page_test.dart`
- 结果：3 tests passed（exit 0）
- 与计划 Expected「FAIL」不一致——见 CONCERNS

### Step 3 — 修改 splash_page.dart
- 文件：`d:\app\projects\photo_post\lumira_app_flutter\lib\features\splash\pages\splash_page.dart`
- 在 line 64-75 的 logo 块替换为 Stack 包裹：
  - 外层 `SizedBox(width: 160, height: 160, child: Stack(...))`
  - 第一个子节点：`Container` 160×160，`BoxDecoration(shape: circle, RadialGradient)` 颜色 `[tokens.brandSubtle.withOpacity(0.45), tokens.brandLight.withOpacity(0.18), tokens.canvas.withOpacity(0)]`，stops `[0.0, 0.55, 1.0]`
  - 第二个子节点：原 80×80 `LumiraLogo.symbol(size: 80, semanticsLabel: '如画品牌符号标')`
  - 外层 `FadeUp` 由 `const` 改为非 const（依赖 tokens）
- 已确认 `ThemeTokens` 中存在 `canvas` / `brandLight` / `brandSubtle` 字段
- 原样采用计划给出的替换代码块

### Step 4 — 运行测试验证通过
- 命令：`flutter test test/features/splash/splash_page_test.dart`
- 结果：3 tests passed（exit 0）
  - SplashPage renders logo + title + caption + brand halo ✅
  - SplashPage uses tokens.canvas as background ✅
  - SplashPage renders across 8 themes without error ✅

### Step 5 — flutter analyze
- 命令：`flutter analyze lib/features/splash/pages/splash_page.dart`
- 结果：`No issues found! (ran in 4.2s)`（exit 0）

### Step 6 — git 提交
- 仅暂存与本任务相关的两个文件（工作树中有大量无关改动，未被纳入）：
  - `lib/features/splash/pages/splash_page.dart`
  - `test/features/splash/splash_page_test.dart`
- commit message：`feat(splash): add brand color halo behind logo`
- commit hash：`ff01a7b0778dbdefd3df2cbe31cc8de5ce4df28d`
- 变更统计：2 files changed, 43 insertions(+), 7 deletions(-)

## 关键文件路径
- 实现：`d:\app\projects\photo_post\lumira_app_flutter\lib\features\splash\pages\splash_page.dart`
- 测试：`d:\app\projects\photo_post\lumira_app_flutter\test\features\splash\splash_page_test.dart`
- 依赖 tokens：`d:\app\projects\photo_post\lumira_app_flutter\lib\core\theme\theme_tokens.dart`
