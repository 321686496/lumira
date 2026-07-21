# Capture Page 全功能实现设计文档

> 实现日期：2026-07-21
> 范围：参数面板、模板应用、滤镜选择、后期处理、构图叠图、姿势剪影、场景预设、Raw 模式、水平仪

## 1. 架构与文件结构

```
lib/features/capture/
├── data/
│   ├── capture_state.dart                [扩展] 增加 editableTemplate/originalTemplate/applied/rawMode 等
│   └── template_registry.dart            [新建] 12 模板统一注册表
├── domain/
│   ├── photo_template.dart               [新建] 完整 PhotoTemplate 不可变数据类（迁移自 TS 接口）
│   ├── scene_preset.dart                 [新建] ScenePreset Dart 类
│   └── filter_recipe.dart                [新建] ColorFilter matrix 生成器（对应 uni-app filterRecipe.ts）
├── services/
│   └── image_processing_service.dart     [新建] 拍照后真实应用滤镜/色彩/锐化/暗角/颗粒/LUT
├── pages/
│   └── capture_page.dart                 [重写] 集成全部叠图 + 控制区 + 面板
└── widgets/
    ├── camera_preview.dart               [修改] 包裹 ColorFiltered 应用滤镜预览
    ├── capture_nav.dart                  [小改] 标题可点击打开参数面板
    ├── capture_button.dart               [不变]
    ├── param_pill_bar.dart               [新建] 顶部 EV/WB/ISO/Apply/RAW/滤镜 入口条
    ├── param_panel.dart                  [新建] 底部抽屉式参数编辑面板（5 Tab）
    ├── apply_button.dart                 [新建] 模板参数应用状态切换按钮
    ├── raw_mode_toggle.dart              [新建] 原相机模式切换
    ├── filter_picker.dart                [新建] 系统滤镜 + LUT 选择器底部弹层
    ├── template_strip.dart               [新建] 底部模板横滑条
    ├── scene_preset_strip.dart           [新建] 场景预设横滑条
    ├── composition_overlay.dart          [复用] 来自 templates/widgets/
    ├── pose_silhouette.dart              [复用] 来自 templates/widgets/
    └── level_indicator.dart              [新建] 水平仪

lib/features/templates/data/templates/
├── soft_portrait.dart                    [新建] 12 模板数据文件（1:1 翻译自 TS）
├── golden_landscape.dart
├── ... 其余 10 个
└── index.dart                            [新建] 模板注册表
```

### 1.1 关键设计决策
- CompositionOverlay / PoseSilhouette 复用已有 Widget，不重复实现
- 模板数据"1 模板 1 Dart 文件"（遵循项目记忆约定）
- 拍照后处理独立为 ImageProcessingService，便于隔离测试

## 2. 数据模型

### 2.1 PhotoTemplate 类
```dart
class PhotoTemplate {
  final TemplateMeta meta;
  final Composition composition;
  final Pose pose;
  final CameraParams camera;
  final SceneGuide sceneGuide;
  final PostProcess postProcess;

  PhotoTemplate copyWith({...});
  bool operator ==(Object other);   // 深度比较（所有字段）
  int get hashCode;
}
```
所有字段为 `final`（不可变），更新通过 `copyWith()` 完成。

### 2.2 子类型
| 类 | 关键字段 | 来源 TS 接口 |
|---|---|---|
| TemplateMeta | id, name, author, version, category, price, cover, tags, tagIds, referenceSource | TemplateMeta |
| Composition | overlayType, gridType?, subjectFrame?, opacity, aspectRatio, description | Composition |
| Pose | silhouette, position, positionX, positionY, scale, rotation, description | Pose |
| CameraParams | exposureCompensation, iso, shutterSpeed, whiteBalance, whiteBalanceK, flashMode, focusMode, lensType?, isoMode?, lensSuggestion? | CameraParams |
| SceneGuide | lightDirection, shootingDistance, background, props, bestTime, tips, presetId?, lightDirectionAngle? | SceneGuide |
| PostProcess | cropRatio, color, smoothStrength, sharpen, vignette, grain, lut, systemFilter | PostProcess |
| PostProcessColor | brightness, contrast, saturation, temperature, tint, highlights?, shadows?, blackPoint?, clarity?, vibrance?, brilliance? | PostProcessColor |

### 2.3 模板注册表
```dart
class TemplateRegistry {
  static const Map<String, PhotoTemplate> _templates = {
    'soft_portrait': softPortraitTemplate,
    'golden_landscape': goldenLandscapeTemplate,
    // ... 12 个
  };

  static PhotoTemplate? getTemplate(String id) => _templates[id]?.copyWith();
  static List<PhotoTemplate> get allTemplates => _templates.values.map((t) => t.copyWith()).toList();
  static List<PhotoTemplate> getRecentTemplates(int count) => allTemplates.take(count).toList();
}
```
`getTemplate` 返回 `copyWith()` 确保调用方无法修改注册表内的单例（避免 uni-app 中 `JSON.parse(JSON.stringify())` 的坑）。

## 3. 状态管理（CaptureState 扩展）

在现有 `capture_state.dart` 基础上新增以下 Provider：

### 3.1 模板编辑状态
```dart
/// 原始模板（从 template_strip 选中）
originalTemplateProvider = Provider<PhotoTemplate?>;

/// 可编辑模板副本（参数面板所有修改写这里）
editableTemplateProvider = StateProvider<PhotoTemplate?>;

/// 是否完全匹配原始模板参数
appliedProvider = Provider<bool>;  // 派生：original == editable
```

### 3.2 模式开关
```dart
rawModeProvider = StateProvider<bool>(false);
panelExpandedProvider = StateProvider<bool>(false);
filterPickerVisibleProvider = StateProvider<bool>(false);
bottomPanelExpandedProvider = StateProvider<bool>(false);  // 底部可折叠面板
```

### 3.3 场景状态
```dart
activeScenePresetIdProvider = StateProvider<String?>(null);
activeSceneFilterProvider = Provider<String?>;  // 派生
```

### 3.4 水平仪
```dart
levelEnabledProvider = StateProvider<bool>(true);
levelAngleProvider = StateProvider<double>(0.0);
```

### 3.5 拍摄组合
```dart
kitsProvider = StateProvider<List<ShootKit>>([]);   // 内存态，无持久化
```

## 4. 核心 Widgets

### 4.1 param_pill_bar.dart — 顶部参数入口条
- 水平 ListView，每项为 `Container`（pill 样式）
- Pill 内容：EV / WB / ISO / [ApplyButton] / [RawModeToggle] / 滤镜
- 每项显示 `editableTemplate.camera` 的当前值
- 点击 → `panelExpanded = true` + 切换到对应 Tab

### 4.2 param_panel.dart — 底部参数编辑面板
- `AnimatedPositioned` 从底部滑入
- 5 个 Tab：相机 / 色彩 / 细节 / 构图 / 场景
- 使用 Riverpod `family` provider 管理当前 Tab
- 底部大按钮："应用模板参数"（`onApplyClick` 重置 editableTemplate）
- 所有修改通过 `ref.read(editableTemplateProvider.notifier).state = newTpl.copyWith(...)` 更新

### 4.3 filter_picker.dart — 滤镜选择器
- `showModalBottomSheet`
- 两段式：系统滤镜（7 种）+ LUT 预设（16 种）
- 点击 → 更新 `editableTemplate.postProcess.systemFilter` / `lut`
- `rawMode=true` 时禁用显示
- 每个滤镜显示缩略图（ColorFilter 色块）

### 4.4 template_strip.dart — 模板横滑条
- `ListView.builder(scrollDirection: Axis.horizontal)`
- 数据：`TemplateRegistry.getRecentTemplates(6)`
- 选中高亮 + 点击切换 `currentTemplateIdProvider`
- 列表底部也有展开入口 → `bottomPanelExpanded = true`

### 4.5 scene_preset_strip.dart — 场景预设横滑条
- 同 template_strip 结构
- 数据：18 个 ScenePreset（从 TS 文件翻译）
- 点击 → 设定场景预设 + 自动设置对应滤镜

### 4.6 level_indicator.dart — 水平仪
- 小型视觉 Widget，取景器底部居中
- 当前为 mock UI（`levelAngle=0` 固定）
- Canvas 自定义绘制：轨道条 + 气泡

### 4.7 修改 camera_preview.dart
- 在 `CameraAwesomeBuilder.awesome()` 外层包裹 `ColorFiltered`
- ColorFilter 由 `_buildColorFilterFromPostProcess()` 生成
- 引入 `CompositionOverlay` 和 `PoseSilhouette` 支持

### 4.8 修改 capture_nav.dart
- 标题文字改为可点击，点击打开 `ParamPanel`
- 增加场景指南跳转的链接确认

## 5. 拍照后处理

### 5.1 ImageProcessingService
```dart
class ImageProcessingService {
  /// 输入原始图像，输出应用了所有后期参数的图像
  static Future<ui.Image> process({
    required ui.Image input,
    required PostProcess params,
  }) async { ... }
}
```

### 5.2 处理管线顺序
1. 系统滤镜（ColorMatrix，与预览一致）
2. 色彩（亮度→对比度→饱和度→色温→色调→高光→阴影→黑点→鲜明度→自然饱和度）
3. 清晰度（clarity，中间调对比度）
4. 锐化（Unsharp Mask kernel）
5. 磨皮强度（smoothStrength，简化为高斯模糊混合）
6. 暗角（径向渐变叠加）
7. 颗粒（Perlin 噪声叠加）
8. LUT（使用 gpu_image 包 3D LUT，不可用时回退 ColorMatrix 近似）

### 5.3 LUT 方案
- 主要方案：gpu_image 包的 3D LUT 支持
- 运行时检测：判断 gpu_image 是否加载成功
- 回退方案：flutter 的 ColorMatrix 近似（1D 查表），16 种 LutPreset 各对应一个预定义 matrix
- 调用方受 `rawModeProvider` 保护：rawMode=true 时跳过整个管线

### 5.4 存储
- 使用 `saver_gallery` 保存到系统相册
- 保存后更新 `lastPhotoPathProvider`
- 缩略图显示在拍摄按钮左侧

## 6. CapturePage 集成布局

### 6.1 布局层级
```
Stack（全屏）
├── Scaffold
│   └── Stack
│       ├── Column（取景器区域）
│       │   ├── CameraPreview（ColorFiltered）
│       │   │   ├── CompositionOverlay（条件：hasTemplate && showTemplate）
│       │   │   └── PoseSilhouette（条件：hasTemplate && hasSilhouette && showSilhouette）
│       │   ├── SceneFilterBadge（条件：activeSceneFilter）
│       │   └── LevelIndicator（条件：levelEnabled）
│       ├── CaptureNav（Positioned.top，背景透明）
│       ├── ParamPillBar（Positioned.top，Padding.top=nav_height）
│       ├── 底部控制区（Positioned.bottom）
│       │   ├── CaptureButton + 缩略图 + 翻转
│       │   └── TemplateStrip
│       ├── 相机错误遮罩（条件：cameraError）
│       └── AnimatedPositioned（ParamPanel，条件：panelExpanded）
└── FilterPicker（showModalBottomSheet 独立）
```

### 6.2 布局约束
- 导航栏背景 `Colors.transparent`
- 按钮类使用 `max-width: 100%; box-sizing: border-box`
- 固定 CTA 容器使用 `box-sizing: border-box; width: 100%; overflow-x: hidden`
- 取景器宽高比来自 `editableTemplate.composition.aspectRatio`
- 参数 pill 使用 `white-space: nowrap` + `flex-shrink: 0`

### 6.3 错误处理
- 相机初始化失败 → 半透明错误遮罩 + 重试按钮
- RAW 模式下点击滤镜 → SnackBar 提示
- 拍照失败 → SnackBar 错误 + 日志

## 7. 数据源（模板 + 场景预设文件清单）

### 7.1 模板（从 TS 1:1 翻译）
| 文件 | 对应 TS |
|---|---|
| soft_portrait.dart | soft-portrait.ts |
| golden_landscape.dart | golden-landscape.ts |
| cafe_portrait.dart | cafe-portrait.ts |
| film_vintage.dart | film-vintage.ts |
| food_flat_lay.dart | food-flat-lay.ts |
| indoor_still_life.dart | indoor-still-life.ts |
| macro_flower.dart | macro-flower.ts |
| neon_portrait.dart | neon-portrait.ts |
| night_cityscape.dart | night-cityscape.ts |
| street_bw.dart | street-bw.ts |
| sunset_silhouette.dart | sunset-silhouette.ts |
| urban_architecture.dart | urban-architecture.ts |

### 7.2 场景预设
- `scene_preset.dart` 文件内 18 个 ScenePreset 常量
- 数据翻译自 `lumira-app/src/data/scenePresets.ts`
- 场景滤镜格式：`{ lut: LutPreset, systemFilter?: SystemFilter, reason: string }`

## 8. 测试策略

### 8.1 单元测试
- filter_recipe.dart：验证 ColorFilter matrix 数值与 uni-app CSS filter 等效
- photo_template.dart：验证不可变性和 copyWith 行为
- ImageProcessingService.process()：mock 2x2 image 验证像素值
- capture_state.dart：验证 applied 派生状态的计算逻辑

### 8.2 Widget 测试
- param_panel.dart：验证 slider 修改更新 editableTemplate
- filter_picker.dart：验证点击选择更新状态
- template_strip.dart：验证选中切换
- capture_page.dart：验证整体布局和条件渲染（使用 cameraPreviewOverrideProvider）

### 8.3 集成测试（真机验证）
- Harmony 端验证取景器正常 + 参数调整 + 拍照 + 滤镜应用
- 拍照后处理管线验证

## 9. 排除范围（后续 Task）
- 拍摄组合 kits 的 sqflite 持久化
- 场景成就系统（SceneAchievement）
- 模板导入导出（.pptpl）
- 传感器驱动的水平仪（sensors_plus 集成）
- 双击取景器 AE/AF 锁定
- 模板推荐（recentTemplates 的持久化存储）
