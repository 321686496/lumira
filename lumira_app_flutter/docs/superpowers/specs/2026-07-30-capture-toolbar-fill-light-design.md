# 拍摄页工具栏 + 补光功能设计

- 日期：2026-07-30
- 范围：`lumira_app_flutter`（Flutter 项目），仅拍摄页 `lib/features/capture/`
- 目标：
  1. 将底部"模板横滑条 + 折叠按钮 + 展开后的模板/场景条"重构为一排图标的工具栏 + 底部抽屉
  2. 工具栏包含 4 项：模板 / 场景 / 参数 / 补光
  3. 新增"补光"功能：前置摄像头自拍时取景器上方显示带颜色的透明高亮叠层，并通过 PhotoPostProcessor 用 multiply 混合将颜色映射到成片，达到补光效果

## 1. 架构概览

### 1.1 改造前的底部结构（`_BottomControlArea`）

```
_ZoomSlider                      ← 保留
TemplateStrip(compact: true)     ← 移除（仅紧凑模板条）
折叠按钮                          ← 移除
[展开时] TemplateStrip + ScenePresetStrip  ← 移除
_CaptureButtonRow                ← 保留
```

### 1.2 改造后的底部结构

```
_ZoomSlider                              ← 保留
_CaptureToolbar                          ← 新增（一排图标按钮）
_AnimatedToolDrawer                      ← 新增（抽屉，高度 220）
  ├─ 模板抽屉：复用 TemplateStrip(compact: false)
  ├─ 场景抽屉：复用 ScenePresetStrip()
  ├─ 参数抽屉：触发 ParamPanel 展开（不直接渲染内容）
  └─ 补光抽屉：_FillLightPanel（新组件）
_CaptureButtonRow                        ← 保留
_FillLightOverlay                        ← 新增（取景器上方叠层）
```

### 1.3 不变的部分

- `_ZoomSlider`、`_CaptureButtonRow`、`_ViewfinderArea`、`CaptureNav`、`AspectRatioSelector`、`ParamPillBar`、`ParamPanel`、`FilterPicker`、`LevelIndicator` 全部保留
- 现有 `CaptureState` 中的 provider 不重命名、不重构，仅新增"工具栏 active tab"和"补光状态"相关 provider
- 现有 `TemplateStrip`、`ScenePresetStrip` 不修改（仅在抽屉中以 `compact: false` 方式复用）

## 2. 组件设计

### 2.1 `_CaptureToolbar`（新增，私有 widget，放在 capture_page.dart 内）

- ConsumerWidget，watch `activeToolProvider` 决定高亮项
- 一行 4 个按钮，等宽分布，每个按钮：图标（24x24 Material Icon）+ 文字（12sp）
- 按钮顺序与内容：

| 工具 | 图标 | 文字 | 行为 |
|------|------|------|------|
| 模板 | `Icons.dashboard_outlined`（选中 `Icons.dashboard`） | "模板" | 切换到模板抽屉 |
| 场景 | `Icons.palette_outlined`（选中 `Icons.palette`） | "场景" | 切换到场景抽屉 |
| 参数 | `Icons.tune` | "参数" | 直接打开 `ParamPanel`（设置 `panelExpandedProvider=true`），同时激活参数 tab 高亮但抽屉内只显示一行提示"参数面板已展开" |
| 补光 | `Icons.lightbulb_outline`（选中 `Icons.lightbulb`） | "补光" | 切换到补光抽屉 |

- 交互：
  - 点击未激活的工具 → 激活该工具，抽屉展开
  - 点击已激活的工具 → 抽屉收起，激活态清空（`activeToolProvider = null`）
  - 点击"参数"工具 → 直接设 `panelExpandedProvider = true` 并把 `activeToolProvider = 'params'`（抽屉展开但内容为提示），再次点击关闭 ParamPanel 并收起抽屉
- 视觉：
  - 背景：`Colors.black.withOpacity(0.4)`
  - 按钮：透明背景，选中时图标/文字变为 `Color(0xFFC9A96E)`（项目金色），未选中为 `Colors.white70`
  - 选中按钮上方加 2dp 金色短横线作为指示器
- 全屏模式（`isFullscreenProvider=true`）：整个工具栏+抽屉隐藏，仅保留缩放滑块和拍摄按钮行（与原逻辑一致）

### 2.2 `_AnimatedToolDrawer`（新增，私有 widget）

- 负责根据 `activeToolProvider` 渲染对应内容，并控制展开/收起动画
- 高度固定 220，宽度全屏
- 动画：`AnimatedSize`（duration 250ms，curve `Curves.easeOutCubic`），收起时高度 0
- 内容区按 `activeToolProvider` 渲染：
  - `null` → 空（高度 0）
  - `'templates'` → `TemplateStrip(compact: false)`
  - `'scenes'` → `ScenePresetStrip()`
  - `'params'` → 居中显示一行"参数面板已展开，点击下方任意位置关闭" + 一个"关闭参数面板"按钮
  - `'fillLight'` → `_FillLightPanel`
- 背景与 `_CaptureToolbar` 连续，使用 `Colors.black.withOpacity(0.4)` + 顶部 `LinearGradient`（透明→半透明）做过渡

### 2.3 `_FillLightPanel`（新增，私有 widget）

抽屉内的补光控制面板，包含：

1. **预设色行**：6 个圆形色块横向排列
   - 暖白 `Color(0xFFFFE5B4)` 亮度 0.6
   - 冷白 `Color(0xFFE0F0FF)` 亮度 0.6
   - 黄金 `Color(0xFFFFB347)` 亮度 0.7
   - 柔粉 `Color(0xFFFFC0CB)` 亮度 0.6
   - 青蓝 `Color(0xFF8FD3F4)` 亮度 0.5
   - 紫 `Color(0xFFD8BFD8)` 亮度 0.5
   - 第 7 个："自定义"灰色圆带 `Icons.color_lens` 图标，点击展开色环
   - 第 8 个："关闭"圆带 `Icons.close`，点击设 `fillLightEnabledProvider=false`
2. **亮度滑块**：水平 Slider，范围 [0.1, 1.0]，仅在已选中颜色时可用
3. **色环**（可展开，默认隐藏）：使用 `flutter_hsvcolor_picker` 库的 `ColorPicker` 或自实现简易色环（见 §6 依赖决策）。展开时高度 200，提供任意色相选择 + 亮度滑块联动

交互：
- 点击预设色 → 设 `fillLightEnabledProvider=true`、`fillLightColorProvider=<对应色>`、`fillLightIntensityProvider=<对应亮度>`，色环收起
- 拖动亮度滑块 → 实时更新 `fillLightIntensityProvider`
- 点击"自定义" → 展开/收起色环，色环选中后写入 `fillLightColorProvider`
- 点击"关闭" → `fillLightEnabledProvider=false`，但保留上次颜色供下次开启

### 2.4 `_FillLightOverlay`（新增，私有 widget）

取景器上方的彩色叠层，模拟屏幕补光的视觉效果：

- 位置：放在 `capture_page.dart` build 方法的 Stack 中，作为取景器之上一层（在 `_ViewfinderArea` 之上、`ParamPillBar` 之下）
- 尺寸：与取景器同大（`Positioned.fill` 包裹在 `_ViewfinderArea` 区域内，或直接 `Positioned.fill` 整个 Stack）
- 渲染：
  - `IgnorePointer`（不拦截取景器点击）
  - `Container` + `BoxDecoration`：`color: fillLightColor.withOpacity(intensity * 0.5)`，`blendMode: BlendMode.screen`（在 Stack 上方视觉模拟"屏幕发光"，不会真正影响预览图像）
  - 顶部加入径向渐变（中心亮、边缘暗），模拟屏幕光源中心衰减
- 显示条件：
  - `fillLightEnabledProvider == true`
  - `cameraFacingProvider == 'front'`（默认仅前置显示；后置隐藏叠层但补光色仍可在拍照时应用 — 见 §4 数据流说明）
- 全屏模式：保持显示（补光是核心拍摄辅助，不应被全屏隐藏）

### 2.5 对 `_BottomControlArea` 的改造

- 移除原 `if (!isFullscreen)` 块内的 `TemplateStrip(compact: true)`、`GestureDetector`（折叠按钮）、`if (bottomPanelExpanded) SizedBox(...)` 三段代码
- 在 `_ZoomSlider` 之后、`_CaptureButtonRow` 之前插入 `_CaptureToolbar` 和 `_AnimatedToolDrawer`
- `bottomPanelExpandedProvider` 不再由 `_BottomControlArea` 控制（其状态由 `activeToolProvider != null` 取代）
- `onTogglePanel` 回调参数移除（不再需要外部触发折叠）
- 构造函数参数简化：移除 `bottomPanelExpanded` 和 `onTogglePanel`

### 2.6 对 `CapturePage.build` 的改造

- 在 `Stack` 的 `_ViewfinderArea` 之后、`ParamPillBar`（顶部参数 pill 栏）之前插入 `_FillLightOverlay`（仅在 `fillLightEnabled && cameraFacing == 'front'` 时构建）
- `_BottomControlArea` 调用处移除 `bottomPanelExpanded` 和 `onTogglePanel` 两个参数
- 添加 `ref.listen<FillLightState>` 监听补光状态变化，在 `processFile` 调用时传入补光参数（见 §4）

## 3. 状态管理设计

在 `lib/features/capture/data/capture_state.dart` 的 `CaptureState` 类中新增以下 providers：

### 3.1 工具栏状态

```dart
/// 当前激活的工具栏 tab：null=收起, 'templates'|'scenes'|'params'|'fillLight'
static final activeToolProvider = StateProvider<String?>((ref) => 'templates');
```

- 默认值 `'templates'`：进入拍摄页时默认展开模板抽屉（与改造前的默认行为一致 — 进入即可见模板列表）
- 进入页面时若 `widget.templateId != null`（从模板进入），仍设为 `'templates'` 让用户看到当前模板的选中状态

### 3.2 补光状态

```dart
/// 补光是否启用
static final fillLightEnabledProvider = StateProvider<bool>((ref) => false);

/// 补光颜色（默认暖白）
static final fillLightColorProvider = StateProvider<Color>((ref) => const Color(0xFFFFE5B4));

/// 补光强度 [0.1, 1.0]，默认 0.6
static final fillLightIntensityProvider = StateProvider<double>((ref) => 0.6);
```

> 注意：`Color` 在 Riverpod StateProvider 中需要 `flutter/material.dart`，capture_state.dart 当前已通过 camerawesome_ohos 间接导入 material，需显式 `import 'package:flutter/material.dart'`。

### 3.3 派生 provider

```dart
/// 统一的补光状态快照，供 PhotoPostProcessor 消费
/// 当 fillLightEnabled=false 时返回 null
static final fillLightStateProvider = Provider<FillLightState?>((ref) {
  if (!ref.watch(fillLightEnabledProvider)) return null;
  return FillLightState(
    color: ref.watch(fillLightColorProvider),
    intensity: ref.watch(fillLightIntensityProvider),
  );
});
```

### 3.4 新增数据类

放在 `capture_state.dart` 末尾：

```dart
class FillLightState {
  const FillLightState({required this.color, required this.intensity});
  final Color color;
  final double intensity;
}
```

### 3.5 resetAll 更新

在 `CaptureState.resetAll` 末尾追加：

```dart
container.read(activeToolProvider.notifier).state = 'templates';
container.read(fillLightEnabledProvider.notifier).state = false;
container.read(fillLightColorProvider.notifier).state = const Color(0xFFFFE5B4);
container.read(fillLightIntensityProvider.notifier).state = 0.6;
```

## 4. 数据流：补光如何应用到照片

### 4.1 取景器预览阶段

`_FillLightOverlay` 在 `cameraFacingProvider == 'front' && fillLightEnabledProvider == true` 时渲染：
- 视觉上模拟屏幕补光（屏幕发出彩色光）
- 真实前置摄像头感光元件会捕捉到屏幕反射的彩色光（与原生系统相机"屏幕补光"原理一致）
- 叠层本身用 `BlendMode.screen` 仅影响用户视觉，不会改变预览图像字节

### 4.2 拍照后处理阶段

修改 `photo_post_processor.dart` 的 `processFile` 方法，新增可选参数 `fillLight`：

```dart
static Future<String> processFile({
  // ... 现有参数 ...
  FillLightState? fillLight,  // 新增
}) async {
  // ... 现有裁剪 + 滤镜流程 ...

  // 在所有滤镜之后、保存之前：应用补光混合
  if (fillLight != null) {
    workingImage = await _applyFillLight(workingImage, fillLight);
  }

  // ... 编码保存 ...
}
```

`_applyFillLight` 实现：
- 用 `ui.PictureRecorder` + `Canvas`：
  1. `canvas.drawImageRect(workingImage, src, dst, Paint())` 绘制原图
  2. `Paint()..color = fillLight.color.withOpacity(fillLight.intensity * 0.5)`，`blendMode = BlendMode.multiply`，覆盖整个 dst 矩形
  3. `canvas.drawRect(dst, paint)`
- 这样成片会带补光色调，与前置摄像头实际接收到的屏幕光叠加效果接近
- 重要：rawMode=true 时跳过 `_applyFillLight`（与现有 rawMode 跳过滤镜的语义一致）

### 4.3 调用方更新

在 `capture_page.dart` 的 `_processSingleFrame` 中：

```dart
final fillLight = ref.read(CaptureState.fillLightStateProvider);
// ...
final processedPath = await PhotoPostProcessor.processFile(
  // ... 现有参数 ...
  fillLight: fillLight,
);
```

- 后置摄像头时 `fillLightStateProvider` 仍可能非 null（如果用户开启了补光再切换到后置），此时补光仍会应用到照片（用户可能用作环境补色），但叠层不显示
- 文档明确：后置不显示叠层，但若用户在补光开启时切到后置并拍照，照片仍会被叠加补光色（符合"参数仍生效"的预期）

## 5. 错误处理

- `_FillLightOverlay` 渲染失败（如 Stack overflow）：try-catch 包裹 `BoxDecoration` 计算，失败时退化为纯色覆盖
- `_applyFillLight` 失败（Canvas 异常）：捕获后返回原图（与现有 processFile 错误降级策略一致）
- 色环 widget 加载失败：退化为预设色行（不影响主功能）
- `activeToolProvider` 设为非法值（如 'unknown'）：抽屉渲染空容器，不抛异常

## 6. 依赖决策

### 6.1 色环 widget

**方案 A**（推荐）：自实现简易色环
- 200 行内可实现：`CustomPainter` 绘制 HSV 色环 + 中心亮度方格 + 手势识别
- 优点：无新增依赖，与项目现有"自包含 widget"风格一致
- 缺点：开发量略大

**方案 B**：引入 `flutter_hsvcolor_picker` 包
- 优点：成熟稳定，开箱即用
- 缺点：新增依赖，可能与项目主题色不匹配，需自定义样式

**决策**：采用方案 A，自实现简易色环。理由：
1. 项目当前对外部依赖控制较严（pubspec.yaml 中依赖少）
2. 色环只需色相 + 亮度，不需要 alpha 通道，自实现成本低
3. 与项目设计风格（金色强调、深色背景）保持一致

### 6.2 工具栏图标

使用 Material Icons（项目已使用 `Icons.zoom_in`、`Icons.cameraswitch_outlined` 等），无需新增依赖。

## 7. 测试策略

### 7.1 单元测试

`test/features/capture/capture_state_test.dart` 已存在，追加：
- `activeToolProvider` 默认值为 `'templates'`
- 切换 `activeToolProvider` 后状态正确
- `fillLightEnabledProvider` 默认 false，开启后 `fillLightStateProvider` 返回非 null
- 关闭 `fillLightEnabledProvider` 后 `fillLightStateProvider` 返回 null
- `resetAll` 后所有补光状态重置为默认值

`test/features/capture/photo_post_processor_crop_test.dart` 已存在，追加：
- `processFile(fillLight: FillLightState(暖白, 0.6))` 输出图像与原图像素差异在预期范围
- `processFile(fillLight: null)` 与无 fillLight 参数行为完全一致（向后兼容）
- `rawMode=true` 时 fillLight 不应用

### 7.2 Widget 测试

新增 `test/features/capture/capture_toolbar_test.dart`：
- `_CaptureToolbar` 渲染 4 个按钮
- 点击"模板"按钮 → `activeToolProvider == 'templates'`
- 点击已激活的"模板"按钮 → `activeToolProvider == null`
- 点击"参数"按钮 → `panelExpandedProvider == true`
- 全屏模式下 `_CaptureToolbar` 不渲染

新增 `test/features/capture/fill_light_overlay_test.dart`：
- `fillLightEnabled=false` → 叠层不渲染
- `fillLightEnabled=true && cameraFacing='front'` → 叠层渲染
- `fillLightEnabled=true && cameraFacing='back'` → 叠层不渲染

### 7.3 集成测试

`test/features/capture/capture_page_test.dart` 已存在，追加：
- 进入拍摄页 → 默认看到工具栏 + 模板抽屉展开
- 点击"补光" → 抽屉切换到补光面板
- 在补光面板选择"暖白" → `fillLightColorProvider` 更新
- 切换到后置摄像头 → `_FillLightOverlay` 不渲染

## 8. 文件改动清单

### 新增文件

- 无（所有新 widget 都内嵌在 capture_page.dart 中，保持文件聚焦；如 capture_page.dart 过长可后续拆分）

> 决策：色环 widget（`_HueRingPicker`）也内嵌在 capture_page.dart 中，避免文件爆炸。capture_page.dart 当前约 1200 行，新增约 400 行后约 1600 行，仍可接受。

### 修改文件

1. `lib/features/capture/data/capture_state.dart`
   - 新增 5 个 provider：`activeToolProvider`、`fillLightEnabledProvider`、`fillLightColorProvider`、`fillLightIntensityProvider`、`fillLightStateProvider`
   - 新增 `FillLightState` 数据类
   - `resetAll` 末尾追加 4 行重置代码
   - 显式 `import 'package:flutter/material.dart'`（为 `Color` 类型）

2. `lib/features/capture/pages/capture_page.dart`
   - 改造 `_BottomControlArea`：移除模板条+折叠按钮+展开面板，新增 `_CaptureToolbar` 和 `_AnimatedToolDrawer` 调用
   - 新增 `_CaptureToolbar` widget（约 80 行）
   - 新增 `_AnimatedToolDrawer` widget（约 60 行）
   - 新增 `_FillLightPanel` widget（约 120 行，含预设色行 + 亮度滑块）
   - 新增 `_HueRingPicker` widget（约 150 行，简易 HSV 色环）
   - 新增 `_FillLightOverlay` widget（约 40 行）
   - 修改 `build` 方法：在 Stack 中插入 `_FillLightOverlay`
   - 修改 `_processSingleFrame`：读取 `fillLightStateProvider` 并传入 `processFile`
   - 移除 `_BottomControlArea` 构造函数的 `bottomPanelExpanded` 和 `onTogglePanel` 参数

3. `lib/features/capture/services/photo_post_processor.dart`
   - `processFile` 新增可选参数 `FillLightState? fillLight`
   - 新增私有方法 `_applyFillLight(ui.Image src, FillLightState state)`：Canvas + BlendMode.multiply 叠加补光色
   - rawMode=true 时跳过 `_applyFillLight`

4. 测试文件（新增与追加，详见 §7）

### 不修改的文件

- `template_strip.dart`、`scene_preset_strip.dart`、`param_panel.dart`、`param_pill_bar.dart`、`capture_nav.dart`、`aspect_ratio_selector.dart`、`camera_preview.dart`、`capture_button.dart`、`filter_picker.dart`、`level_indicator.dart`

## 9. 验收标准

1. 进入拍摄页：底部看到缩放滑块 + 一排工具栏（模板/场景/参数/补光，默认"模板"高亮） + 模板抽屉展开（显示模板横滑条） + 拍摄按钮行
2. 点击"场景"：抽屉平滑切换到场景预设条
3. 点击"参数"：底部 ParamPanel 滑入展开
4. 点击"补光"：抽屉切换到补光面板，显示预设色行 + 亮度滑块 + "自定义"按钮
5. 切换到前置摄像头 + 在补光面板选择"暖白"：取景器上方出现暖白色透明叠层
6. 拍照后：预览页照片带暖白色补光色调（与取景器视觉一致）
7. 关闭补光（点击"关闭"圆）：叠层消失，拍照后照片无补光色
8. 全屏模式：工具栏+抽屉隐藏，缩放滑块和拍摄按钮仍可用，补光叠层若已开启仍显示
9. `flutter test test/features/capture/` 全部通过
10. `flutter analyze` 无新增 error

## 10. 风险与缓解

| 风险 | 缓解 |
|------|------|
| capture_page.dart 过长（1600 行） | 本次保持内嵌，后续可拆 `widgets/capture_toolbar.dart`、`widgets/fill_light_panel.dart` 独立文件 |
| 色环 widget 手势识别不精确 | 提供"自定义"按钮展开色环，默认使用预设色；色环仅作为高级选项 |
| 后置摄像头时补光参数仍生效可能引起用户困惑 | 在补光面板加文字提示"补光默认仅前置显示叠层；后置拍照时颜色仍会应用" |
| multiply 全图叠加让背景偏色 | 强度乘以 0.5 系数（`intensity * 0.5`），与前置自拍时屏幕反射光的实际衰减一致 |
| `flutter analyze` 因 Color 比较报 warning | 使用 `Color.value` 比较或在测试中使用 `Color(0xFFxxxxxx)` 字面量 |

## 11. 后续可扩展（不在本次范围）

- 补光形状（圆形/方形/柔光）：本次仅径向渐变，未来可加形状选择
- 补光位置：本次固定中心，未来可拖动
- 多光源补光：本次单色，未来可加主光+辅光
- 后置也显示叠层（作为"虚拟补光"）：本次仅前置，未来可解锁
