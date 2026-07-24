# 如画品牌呈现与首页排版艺术化设计

**日期**：2026-07-24
**项目**：lumira_app_flutter
**状态**：待实施

## 背景与目标

前期已将设计好的品牌 logo 嵌入 splash、关于页、首页导航栏 wordmark 与 App 启动器图标。本次目标：
1. 为 splash 与关于页的 logo 增加主题色光晕作为视觉底色，提升品牌氛围
2. 让首页 APP 名称具备艺术排版能力，并允许用户在设置页切换三种风格
3. 让 4 个 tab 页标题统一左对齐，呼应「标题不居中」的设计偏好

## 设计决策

### 决策 1：光晕形态 — 圆形径向渐变光晕
- 选定方案：圆形 / 胶囊主题色光晕
- 拒绝方案：全屏主题色背景（视觉过激）；局部主题色卡片（与现有 canvas 风格割裂）
- 配色：径向渐变 `brandSubtle(0.45) → brandLight(0.18) → canvas(0)`，与关于页现有背景装饰的视觉语言一致

### 决策 2：首页排版 — 三种风格可切换，默认 logo + 英文
- 用户可在设置页选择 `logoEnglish | logoEnglishChinese | englishChinese`
- 默认 `logoEnglish`
- 设置页选项卡片实时渲染对应排版供预览

### 决策 3：tab 页标题左对齐 — 仅 tab 页
- 不改 LumiraNav 默认值，避免影响非 tab 页
- 4 个 tab 页显式传 `centerTitle: false`

## 架构与组件

### 新增组件

#### 1. `HomeBrandTitle`（lib/shared/widgets/brand/home_brand_title.dart）
无状态组件，监听 `homeWordmarkStyleProvider`，根据 style 渲染对应排版。

```dart
class HomeBrandTitle extends ConsumerWidget {
  const HomeBrandTitle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(homeWordmarkStyleProvider);
    final tokens = ref.watch(appThemeProvider).tokens;

    switch (style) {
      case HomeWordmarkStyle.logoEnglish:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LumiraLogo.symbol(size: 24),
            const SizedBox(width: 8),
            Text('Lumira', style: _englishStyle(tokens, 20)),
          ],
        );
      case HomeWordmarkStyle.logoEnglishChinese:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LumiraLogo.symbol(size: 22),
            const SizedBox(width: 8),
            Text('Lumira', style: _englishStyle(tokens, 18)),
            const SizedBox(width: 6),
            Text('如画', style: _chineseStyle(tokens, 14)),
          ],
        );
      case HomeWordmarkStyle.englishChinese:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Lumira', style: _englishStyle(tokens, 20)),
            const SizedBox(width: 8),
            Text('如画', style: _chineseStyle(tokens, 14)),
          ],
        );
    }
  }
}
```

**排版规格**：
- 英文：Georgia/Noto Serif，letter-spacing 0.08em，字重 normal，颜色 `textPrimary`
- 中文：Noto Serif SC，字重 w600，颜色 `brand`（艺术对比）

#### 2. `HomeWordmarkStyle` 枚举与 Provider（lib/core/preferences/home_wordmark_style.dart）
```dart
enum HomeWordmarkStyle { logoEnglish, logoEnglishChinese, englishChinese }

final homeWordmarkStyleProvider =
    StateProvider<HomeWordmarkStyle>((_) => HomeWordmarkStyle.logoEnglish);
```
与现有 `themeKeyProvider` / `uiStyleProvider` 一致，使用 StateProvider 不引入持久化（保持架构一致）。

### 修改的组件

#### 1. `LumiraNav`（lib/shared/widgets/nav/lumira_nav.dart）
**变更**：实现 `centerTitle=false` 左对齐语义。

当前 `centerWidget` 用 `Positioned(left:0, right:0) + Center` 强制居中。修改为：
- `centerTitle=true`：保持现有居中布局
- `centerTitle=false`：centerWidget 紧贴 leading 右侧，使用 Row 而非 Stack+Center

```dart
// 伪代码
if (widget.centerTitle) {
  // 现有 Stack + Center 居中布局
} else {
  // Row: leading + SizedBox(width:4) + centerWidget + Spacer + actions
}
```

不破坏现有非 tab 页（默认 `centerTitle=true`）的视觉。

#### 2. `SplashPage`（lib/features/splash/pages/splash_page.dart）
**变更**：在 logo 与文字之间插入径向渐变圆形光晕。

```dart
Stack(
  alignment: Alignment.center,
  children: [
    // 主题色光晕（logo 后方）
    Container(
      width: 160, height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            tokens.brandSubtle.withOpacity(0.45),
            tokens.brandLight.withOpacity(0.18),
            tokens.canvas.withOpacity(0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
    ),
    // 原 FadeUp + LumiraLogo.symbol
    const FadeUp(child: SizedBox(width: 80, height: 80, child: LumiraLogo.symbol(size: 80))),
  ],
)
```
文字组保持不变。

#### 3. `ProfileAboutPage._AppHeader`（lib/features/profile/pages/profile_about_page.dart）
**变更**：移除白色 surface 容器 + 金色 box-shadow，替换为径向渐变圆形光晕 + logo。

```dart
Stack(
  alignment: Alignment.center,
  children: [
    Container(
      width: 140, height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            tokens.brandSubtle.withOpacity(0.45),
            tokens.brandLight.withOpacity(0.18),
            tokens.canvas.withOpacity(0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
    ),
    const LumiraLogo.symbol(size: 80, semanticsLabel: '如画品牌符号标'),
  ],
)
```
版本号胶囊、文字组保持不变。

#### 4. `HomePage`（lib/features/home/pages/home_page.dart）
**变更**：移除 `useWordmark: true`，改用 `leading: HomeBrandTitle()` + `centerTitle: false`。

```dart
appBar: LumiraNav(
  centerTitle: false,
  transparent: true,
  scrolled: _scrolled,
  leading: const HomeBrandTitle(),
  actions: [...],
),
```
首页原本的 `_NavLocation` 位置显示删除（被品牌标题替代）。

#### 5. 4 个 tab 页 — 显式传 `centerTitle: false`
- `templates_page.dart`（line 87）：`LumiraNav(title: '发现', centerTitle: false, ...)`
- `challenge_page.dart`（line 125）：`LumiraNav(title: '每日挑战', centerTitle: false, ...)`
- `profile_page.dart`（line 46）：`LumiraNav(title: '我的', centerTitle: false, showBackButton: false)`
- `home_page.dart`：见上方第 4 条，已传 `centerTitle: false`

#### 6. `ProfileSettingsPage`（lib/features/profile/pages/profile_settings_page.dart）
**变更**：在现有「界面风格」section 下方新增「首页标题样式」section。

UI 结构：
- 标题行：图标 + 「首页标题样式」
- 3 张预览卡片纵向排列，每张卡片：
  - 上半部分：mini 版 `HomeBrandTitle` 渲染（用固定容器宽度，如 200dp）
  - 下半部分：选项标题（如「Logo + 英文」）+ 选中圆点
- 选中态：brand 边框 1.5px + brandSubtle 背景
- 未选中：divider 边框 1px + surface 背景
- 点击：`ref.read(homeWordmarkStyleProvider.notifier).state = ...`

为复用，`HomeBrandTitle` 提供可选 `preview` bool 参数（默认 false）。`preview=true` 时组件内部使用更小尺寸（logo 18dp、英文 16dp、中文 12dp），适配设置页卡片内的预览位。

## 数据流

```
用户在设置页点击选项卡片
    ↓
ref.read(homeWordmarkStyleProvider.notifier).state = newStyle
    ↓
HomePage 监听 homeWordmarkStyleProvider → HomeBrandTitle 重建
    ↓
导航栏标题即时切换排版
```

## 测试

### 单元测试
- `HomeWordmarkStyle` 枚举完整性
- `homeWordmarkStyleProvider` 默认值 = `logoEnglish`

### Widget 测试
- `HomeBrandTitle` 在三种 style 下都能找到对应子组件：
  - `logoEnglish` → `LumiraLogo` + 文本「Lumira」
  - `logoEnglishChinese` → `LumiraLogo` + 「Lumira」+「如画」
  - `englishChinese` → 「Lumira」+「如画」（无 `LumiraLogo`）
- `SplashPage` 能找到径向渐变光晕容器（`find.byType(Container)` + 验证 decoration）
- `ProfileAboutPage._AppHeader` 同上
- `LumiraNav` 在 `centerTitle=false` 时，标题不居中（验证布局类型）

### 人工验证
- Splash 与关于页光晕在 8 个主题下视觉协调
- 首页三种排版在 8 个主题 × 2 UI 风格（neumorphic/glass）下可读
- 4 个 tab 页标题左对齐效果一致
- 设置页选项切换实时反映到首页

## 影响范围

### 新增文件（2 个）
- `lib/shared/widgets/brand/home_brand_title.dart`
- `lib/core/preferences/home_wordmark_style.dart`

### 修改文件（8 个）
- `lib/shared/widgets/nav/lumira_nav.dart`
- `lib/features/splash/pages/splash_page.dart`
- `lib/features/profile/pages/profile_about_page.dart`
- `lib/features/home/pages/home_page.dart`
- `lib/features/templates/pages/templates_page.dart`
- `lib/features/challenge/pages/challenge_page.dart`
- `lib/features/profile/pages/profile_page.dart`
- `lib/features/profile/pages/profile_settings_page.dart`

### 不引入新依赖
复用现有 `flutter_riverpod`、`flutter_svg`、`LumiraLogo`。

## 兼容性

- 非 tab 页保持默认 `centerTitle=true`，无视觉变化
- 现有 `useWordmark` 参数保留（向后兼容，但首页不再使用）
- 默认 `HomeWordmarkStyle.logoEnglish` 与现有首页视觉接近，无突兀切换
