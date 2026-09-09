# 拍摄页与预览页「沉浸式 / 跟随主题」外观设置

- 日期：2026-09-09
- 状态：已批准（用户确认默认沉浸式、照片区跟随主题用画布色、方案 A 集中解析器）

## 背景与目标

拍摄页（`capture_page.dart`）与拍摄预览页（`capture_preview_page.dart`）当前写死沉浸式（纯黑背景 + 暗色浮层 + 白色前景），不随设置中的 UI 风格 / 主题色变化。

目标：在设置页「拍摄」分组新增开关项「沉浸式取景」，用户可选择：

- **沉浸式（默认，保持现状）**：纯黑取景/看图 + 暗色浮层，视觉与现版本零差异
- **跟随主题**：两页面画布与浮层按当前主题色（ThemeKey）+ UI 风格（UIStyle）渲染

一个设置项同时控制两个页面（拍摄 → 预览为连续流程）。

## 硬约束

- 遵循项目 UI 规范：样式跟随「设置里的 UI 风格 + 主题」，禁止硬编码主题色；禁止风格混搭
- 「黑白半透明遮罩」为跨风格合法例外（叠照片的黑/白 scrim、白闪反馈、延时数字等可保持）
- 沉浸式模式下所有页面视觉与现版本保持一致（回归零变化）

## 1. 数据层

### 枚举与 provider

- 新枚举 `CaptureAppearance { immersive, theme }`，定义于 `lib/features/capture/data/capture_state.dart`（与 `CaptureFlashMode` 同级）
- `CaptureState.captureAppearanceProvider`（`StateProvider<CaptureAppearance>`，默认 `immersive`）
- `CaptureState.loadCaptureAppearance(container)`：从 DB 异步加载（设置页 initState 调用，仿 `loadLevelEnabled`）
- `CaptureState.persistCaptureAppearance(container, value)`：写 provider + DB（失败静默）

### 持久化

- `user_settings` 表新列 `capture_appearance TEXT NOT NULL DEFAULT 'immersive'`（v55 迁移，`_addColumnIfNotExists`，失败静默）
- `SettingsDao.getCaptureAppearance()` / `setCaptureAppearance()`：按枚举名存取，非法值回退 `immersive`
- `tables.dart` 加 `colCaptureAppearance` 常量
- DB 版本 54 → 55

## 2. 视觉解析层（方案 A 核心）

`LumiraThemeResolver`（`lib/shared/widgets/lumira/_internal/lumira_theme_resolver.dart`）新增：

```dart
static CaptureOverlayVisual captureOverlayVisual({
  required ThemeTokens tokens,
  required UIStyle style,
  required CaptureAppearance appearance,
  required CaptureOverlayRole role, // pill（叠取景器浮层）/ panel（落画布面板）
  required double radiusDp,
})
```

返回 `CaptureOverlayVisual`（新数据类）：

- `background` / `border` / `shadows` / `backdropBlurSigma` / `glassOverlay`（容器规格）
- `foreground` / `foregroundSecondary` / `accent`（前景规格：主文字/图标、次级文字、激活态强调色）

### 解析规则

**immersive（跨风格统一，属"黑白半透明遮罩"合法例外）**：

- `pill`：近黑半透明底 `Color(0xFF141416).withOpacity(0.75)` + 白 0.1 细边 + 柔和黑投影；前景白 / white70；accent 金 `0xFFC9A96E`
- `panel`：近黑渐变底（black 0.82 → brand lerp 0.16，与现 ParamPanel 一致）+ 白 0.08 细边；前景同上

**theme**：

- `pill` → 按规范「叠照片浮层取向」：
  - neumorphic：实心 `tokens.surface` + 细边（divider 级）+ 无阴影无模糊
  - flat：半透明 `surfaceAlt` + 细边
  - glass：`glassFill` + `glassBorder` + blur sigma 20（组件据此包 `BackdropFilter`）
  - female：品牌渐变 + 柔和品牌阴影
- `panel` → 画布卡片语义，直接复用 `cardVisual`（含 darkContext=false）
- 前景：`textPrimary` / `textSecondary` / `brand`

组件侧不再自行判断 `isNeu` 决定是否毛玻璃，改为读 `backdropBlurSigma > 0`。

## 3. 拍摄页改造

涉及 `capture_page.dart`（Scaffold 背景 ×3，含权限页）与 `lib/features/capture/widgets/` 下浮层组件：

| 组件 | immersive（保留现状） | theme（新） |
|---|---|---|
| Scaffold 背景（正常 + 权限页×2） | 纯黑 | `tokens.canvas`（比例模式取景器 letterbox 自然变画布色） |
| CaptureNav（导航胶囊） | 暗色胶囊 + 毛玻璃（非 neu） | `pill` 取向 + tokens 前景 |
| ParamPillBar / AspectRatioSelector / DelayTimerButton / ChallengeOverlayBar / CapturePoseSwitchButton | 暗色胶囊 | `pill` 取向 |
| CaptureBottomBar | 黑色渐变 scrim | canvas 渐变 scrim（tokens.canvas 渐变到深色 canvas）|
| CaptureToolbar / AnimatedToolDrawer | 暗色半透明 | `panel` 取向 |
| TemplateDrawerPanel / TemplateStrip / ScenePresetStrip / FilterPicker | 暗色面板（硬编码 white70 等） | `panel` 取向（surface 卡 + tokens 文字） |
| ParamPanel | 暗色渐变面板 | `panel` 取向 |
| CaptureButtonRow（快门/缩略图/切摄） | 白圈黑底 | `tokens.surface` 底 + divider 描边 |
| LevelIndicator / TemplateInfoCard | 白色系 | tokens 色 |
| ShutterFeedback / 延时数字 / TrialWatermarkOverlay / 水印定格动画 | 黑白半透明例外 | **保持不变** |

## 4. 预览页改造

| 层 | immersive | theme |
|---|---|---|
| Scaffold + PhotoView 照片区背景（`backgroundDecoration` ×2） | 纯黑 | `tokens.canvas`（用户已确认） |
| 底部编辑 dock `LumiraSurface.darkContext` | `true` | `false`（正常画布卡片） |
| 顶栏 `_PreviewNav` / `_NavIcon` 图标色 | `textInverse` | `textPrimary` |
| 只读横幅（dangerSubtle/danger） | tokens 色 | tokens 色（不变，本就主题化） |
| 对比徽标 / ComparePhotoButton 叠图取向 | 黑白半透明例外 | 保持不变 |

## 5. 设置页

`profile_settings_page.dart`「拍摄」分组顶部新增：

- 图标：`Icons.dark_mode_outlined`
- label：`沉浸式取景`
- trailing：`LumiraSwitch`，value = `appearance == immersive`
- onChanged：切换 provider + `persistCaptureAppearance`
- initState 加 `loadCaptureAppearance`

## 6. 测试

- `lumira_theme_resolver_test.dart`（新建或扩展）：2 appearance × 4 风格 × 2 role 断言（immersive 跨风格一致、theme 各风格符合取向、前景色正确）
- `settings_dao` 相关：capture_appearance 读写 + 非法值回退（如现有 DAO 测试模式）
- `flutter analyze` + `flutter test` 全过

## 7. 验收标准

1. 默认（未设置）：两页面与现版本视觉零差异
2. 关闭「沉浸式取景」后：两页面画布、浮层、文字全部按当前主题 + 风格渲染；4 风格 × 亮/暗主题下无黑色残留、无风格混搭
3. 拍摄页所有浮层（导航、pill、抽屉、面板、底部栏）与预览页（顶栏、照片区、dock）均响应切换
4. 黑白半透明例外元素（scrim、白闪、延时数字、试用遮罩）不受影响
5. 设置持久化：杀进程重启后保持用户选择
