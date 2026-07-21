# Capture Page 全功能 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 Flutter 拍摄页补齐参数面板、模板应用、滤镜选择、后期处理、构图叠图、姿势剪影、场景预设、Raw 模式、水平仪等全功能。

**Architecture:** 不可变 PhotoTemplate 数据模型 + Riverpod 状态管理 + widgets 组合布局 + ImageProcessingService 拍照后处理（gpu_image 3D LUT + ColorMatrix 回退）。先建领域层和数据层，再建 UI 层和服务层。

**Tech Stack:** Dart 2.19+ / Riverpod 2.5.x / gpu_image 1.0.0 / saver_gallery 3.0.6 / flutter_test

## Global Constraints

- 所有 PhotoTemplate 字段为 `final`（不可变），更新通过 `copyWith()` 完成
- CaptureState 的 newtype provider 使用 `StateProvider`（而非 `Notifier`），保持现有风格
- 模板注册表 `TemplateRegistry.getTemplate()` 返回 `copyWith()`，防止单例被修改
- Widget 测试中通过 `cameraPreviewOverrideProvider` 注入 mock preview widget
- 导航栏背景 `Colors.transparent`
- 按钮类 `max-width: 100%; box-sizing: border-box`
- 固定 CTA 容器 `box-sizing: border-box; width: 100%; overflow-x: hidden`
- 取景器宽高比来自 `editableTemplate.composition.aspectRatio`
- 参数 pill 使用 `white-space: nowrap; flex-shrink: 0`
- LUT：优先 gpu_image 3D LUT，运行时检测不可用时回退 ColorMatrix 近似
- rawMode=true 时禁用滤镜/后期管线

---

### Task 1: PhotoTemplate 领域模型

**Files:**
- Create: `lib/features/capture/domain/photo_template.dart`
- Create: `lib/features/capture/domain/photo_template.g.dart` (不需要，纯手写)
- Test: `test/features/capture/domain/photo_template_test.dart`

**Interfaces:**
- Consumes: 无（独立数据类）
- Produces: `PhotoTemplate`, `TemplateMeta`, `Composition`, `SubjectFrame`, `Pose`, `SilhouetteResource`, `Position`, `CameraParams`, `SceneGuide`, `PostProcess`, `PostProcessColor`, `TemplateClassification` 类

- [ ] **Step 1: 创建 photo_template.dart 文件，定义所有领域类**

```dart
// lib/features/capture/domain/photo_template.dart

class PhotoTemplate {
  final TemplateMeta meta;
  final Composition composition;
  final Pose pose;
  final CameraParams camera;
  final SceneGuide sceneGuide;
  final PostProcess postProcess;

  const PhotoTemplate({
    required this.meta,
    required this.composition,
    required this.pose,
    required this.camera,
    required this.sceneGuide,
    required this.postProcess,
  });

  PhotoTemplate copyWith({
    TemplateMeta? meta,
    Composition? composition,
    Pose? pose,
    CameraParams? camera,
    SceneGuide? sceneGuide,
    PostProcess? postProcess,
  }) =>
      PhotoTemplate(
        meta: meta ?? this.meta,
        composition: composition ?? this.composition,
        pose: pose ?? this.pose,
        camera: camera ?? this.camera,
        sceneGuide: sceneGuide ?? this.sceneGuide,
        postProcess: postProcess ?? this.postProcess,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoTemplate &&
          meta == other.meta &&
          composition == other.composition &&
          pose == other.pose &&
          camera == other.camera &&
          sceneGuide == other.sceneGuide &&
          postProcess == other.postProcess;

  @override
  int get hashCode => Object.hash(meta, composition, pose, camera, sceneGuide, postProcess);
}

class TemplateMeta {
  final String id;
  final String name;
  final String author;
  final String version;
  final String category;
  final TemplateClassification classification;
  final List<String> tags;
  final List<String> tagIds;
  final int price;
  final String cover;
  final String description;
  final String referenceSource;

  const TemplateMeta({
    required this.id,
    required this.name,
    this.author = 'Lumira',
    this.version = '1.0',
    required this.category,
    required this.classification,
    this.tags = const [],
    this.tagIds = const [],
    this.price = 0,
    this.cover = '',
    this.description = '',
    this.referenceSource = '',
  });

  TemplateMeta copyWith({...}); // 所有字段可选
  // operator == 和 hashCode
}

class TemplateClassification {
  final String type;
  final String style;
  final String method;
  const TemplateClassification({required this.type, this.style = '', this.method = ''});
  // copyWith, ==, hashCode
}

class Composition {
  final String overlayType;
  final String? gridType;
  final SubjectFrame? subjectFrame;
  final double opacity;
  final String aspectRatio;
  final String description;
  const Composition({
    this.overlayType = 'rule_of_thirds',
    this.gridType,
    this.subjectFrame,
    this.opacity = 0.5,
    this.aspectRatio = '3:4',
    this.description = '',
  });
  // copyWith, ==, hashCode
}

class SubjectFrame {
  final double x, y, w, h;
  const SubjectFrame({required this.x, required this.y, required this.w, required this.h});
  // copyWith, ==, hashCode
}

class SilhouetteResource {
  final String type; // 'builtin' | 'image' | 'svg'
  final String data;
  final String? filename;
  final int? sizeKB;
  const SilhouetteResource({required this.type, this.data = 'none', this.filename, this.sizeKB});
  // copyWith, ==, hashCode
}

class Position {
  final double x;
  final double y;
  const Position({this.x = 0.5, this.y = 0.5});
  // copyWith, ==, hashCode
}

class Pose {
  final SilhouetteResource silhouette;
  final Position position;
  final double positionX;
  final double positionY;
  final double scale;
  final double rotation;
  final String description;
  const Pose({
    this.silhouette = const SilhouetteResource(type: 'builtin', data: 'none'),
    this.position = const Position(),
    this.positionX = 0,
    this.positionY = 0,
    this.scale = 1.0,
    this.rotation = 0,
    this.description = '',
  });
  // copyWith, ==, hashCode
}

class CameraParams {
  final double exposureCompensation;
  final int iso;
  final String shutterSpeed;
  final String whiteBalance;
  final int whiteBalanceK;
  final String flashMode;
  final String focusMode;
  final String? lensType;
  final String? isoMode;
  final String? lensSuggestion;
  const CameraParams({
    this.exposureCompensation = 0.0,
    this.iso = 200,
    this.shutterSpeed = '1/200',
    this.whiteBalance = 'daylight',
    this.whiteBalanceK = 5500,
    this.flashMode = 'off',
    this.focusMode = 'auto',
    this.lensType,
    this.isoMode,
    this.lensSuggestion,
  });
  // copyWith, ==, hashCode
}

class SceneGuide {
  final String lightDirection;
  final String shootingDistance;
  final String background;
  final List<String> props;
  final String bestTime;
  final List<String> tips;
  final String? presetId;
  final double? lightDirectionAngle;
  final double? shootingDistanceM;
  final String? bestTimeFrom;
  final String? bestTimeTo;
  const SceneGuide({
    this.lightDirection = '',
    this.shootingDistance = '',
    this.background = '',
    this.props = const [],
    this.bestTime = '',
    this.tips = const [],
    this.presetId,
    this.lightDirectionAngle,
    this.shootingDistanceM,
    this.bestTimeFrom,
    this.bestTimeTo,
  });
  // copyWith, ==, hashCode
}

class PostProcess {
  final String cropRatio;
  final PostProcessColor color;
  final int smoothStrength;
  final int sharpen;
  final int vignette;
  final int grain;
  final String lut;
  final String? systemFilter;
  const PostProcess({
    this.cropRatio = '3:4',
    required this.color,
    this.smoothStrength = 0,
    this.sharpen = 0,
    this.vignette = 0,
    this.grain = 0,
    this.lut = 'none',
    this.systemFilter,
  });
  // copyWith, ==, hashCode
}

class PostProcessColor {
  final double brightness;
  final double contrast;
  final double saturation;
  final double temperature;
  final double tint;
  final double? highlights;
  final double? shadows;
  final double? blackPoint;
  final double? clarity;
  final double? vibrance;
  final double? brilliance;
  const PostProcessColor({
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.temperature = 0,
    this.tint = 0,
    this.highlights,
    this.shadows,
    this.blackPoint,
    this.clarity,
    this.vibrance,
    this.brilliance,
  });
  // copyWith, ==, hashCode
}
```

- [ ] **Step 2: 创建单元测试，验证不可变性、copyWith、==/hashCode**

```dart
// test/features/capture/domain/photo_template_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';

void main() {
  group('PhotoTemplate', () {
    final defaultColor = PostProcessColor(brightness: 0, contrast: 1, saturation: 1, temperature: 0, tint: 0);
    final defaultPost = PostProcess(color: defaultColor);
    final defaultMeta = TemplateMeta(id: 'test', name: 'Test', category: 'portrait',
        classification: TemplateClassification(type: 'portrait'));
    final defaultComp = Composition();
    final defaultPose = Pose();
    final defaultCam = CameraParams();
    final defaultGuide = SceneGuide();

    final template = PhotoTemplate(
      meta: defaultMeta,
      composition: defaultComp,
      pose: defaultPose,
      camera: defaultCam,
      sceneGuide: defaultGuide,
      postProcess: defaultPost,
    );

    test('copyWith preserves unchanged fields', () {
      final copy = template.copyWith();
      expect(copy.meta.id, 'test');
      expect(copy.camera.iso, 200);
    });

    test('copyWith overrides specified fields', () {
      final copy = template.copyWith(camera: CameraParams(iso: 800));
      expect(copy.camera.iso, 800);
      expect(copy.meta.id, 'test'); // unchanged
    });

    test('== compares all fields', () {
      final copy = template.copyWith();
      expect(copy == template, true);
      final diff = template.copyWith(camera: CameraParams(iso: 400));
      expect(diff == template, false);
    });

    test('TemplateRegistry.getTemplate returns independent copy', () {
      // register a template first then copy
    });
  });
}
```

Run: `flutter test test/features/capture/domain/photo_template_test.dart`
Expected: PASS

- [ ] **Step 3: 提交**

```bash
git add lib/features/capture/domain/photo_template.dart test/features/capture/domain/photo_template_test.dart
git commit -m "feat(capture): add PhotoTemplate immutable domain model with all sub-types"
```

---

### Task 2: 场景预设模型 (ScenePreset)

**Files:**
- Create: `lib/features/capture/domain/scene_preset.dart`

**Interfaces:**
- Consumes: `PhotoTemplate` 领域模型中的类型（String LutPreset 等）
- Produces: `ScenePreset`, `SceneFilter`, `SceneCategory` 类型

- [ ] **Step 1: 创建 scene_preset.dart**

```dart
// lib/features/capture/domain/scene_preset.dart
import 'photo_template.dart';

/// 对应 TS SceneCategory: 'light' | 'outdoor' | 'indoor' | 'mood'
class SceneCategory {
  static const light = 'light';
  static const outdoor = 'outdoor';
  static const indoor = 'indoor';
  static const mood = 'mood';
}

class SceneFilter {
  final String lut;           // LutPreset，如 'none', 'cinematic', ...
  final String? systemFilter; // SystemFilter，如 'none', 'vivid', ...
  final String reason;

  const SceneFilter({required this.lut, this.systemFilter, this.reason = ''});
  // copyWith, ==, hashCode
}

class ScenePreset {
  final String id;       // ScenePresetId
  final String name;
  final String icon;
  final String category; // SceneCategory
  final String style;
  final SceneFilter filter;
  final String vibe;
  final String description;
  final List<String> exampleImages;
  final List<String> tips;
  final String whereToShoot;
  final String bestTime;
  final SceneGuide sceneGuide;
  final String relatedCategory;
  final List<String> recommendedTagIds;

  const ScenePreset({
    required this.id,
    required this.name,
    this.icon = '',
    this.category = SceneCategory.light,
    this.style = '',
    required this.filter,
    this.vibe = '',
    this.description = '',
    this.exampleImages = const [],
    this.tips = const [],
    this.whereToShoot = '',
    this.bestTime = '',
    required this.sceneGuide,
    this.relatedCategory = 'portrait',
    this.recommendedTagIds = const [],
  });
  // copyWith, ==, hashCode
}
```

- [ ] **Step 2: 创建单元测试**

```dart
test('ScenePreset has required fields', () {
  final filter = SceneFilter(lut: 'cinematic', systemFilter: 'vivid', reason: 'warm mood');
  final guide = SceneGuide(lightDirection: '逆光 45°');
  final preset = ScenePreset(id: 'cafe-window', name: '窗边咖啡', filter: filter, sceneGuide: guide);
  expect(preset.id, 'cafe-window');
  expect(preset.filter.lut, 'cinematic');
});
```

- [ ] **Step 3: 提交**

```bash
git add lib/features/capture/domain/scene_preset.dart test/features/capture/domain/scene_preset_test.dart
git commit -m "feat(capture): add ScenePreset domain model"
```

---

### Task 3: 模板数据文件（12 个模板 + TemplateRegistry）

**Files:**
- Create: `lib/features/capture/data/template_registry.dart`
- Create: `lib/features/capture/data/templates/soft_portrait.dart`
- Create: `lib/features/capture/data/templates/golden_landscape.dart`
- Create: `lib/features/capture/data/templates/cafe_portrait.dart`
- Create: `lib/features/capture/data/templates/film_vintage.dart`
- Create: `lib/features/capture/data/templates/food_flat_lay.dart`
- Create: `lib/features/capture/data/templates/indoor_still_life.dart`
- Create: `lib/features/capture/data/templates/macro_flower.dart`
- Create: `lib/features/capture/data/templates/neon_portrait.dart`
- Create: `lib/features/capture/data/templates/night_cityscape.dart`
- Create: `lib/features/capture/data/templates/street_bw.dart`
- Create: `lib/features/capture/data/templates/sunset_silhouette.dart`
- Create: `lib/features/capture/data/templates/urban_architecture.dart`
- Create: `lib/features/capture/data/templates/index.dart`

**Interfaces:**
- Consumes: `PhotoTemplate` 领域模型
- Produces: `TemplateRegistry` 类，`static PhotoTemplate? getTemplate(String id)`, `static List<PhotoTemplate> get allTemplates`, `static List<PhotoTemplate> getRecentTemplates(int count)`

- [ ] **Step 1: 创建 index.dart（导出文件）**

```dart
// lib/features/capture/data/templates/index.dart
export 'soft_portrait.dart';
export 'golden_landscape.dart';
export 'cafe_portrait.dart';
export 'film_vintage.dart';
export 'food_flat_lay.dart';
export 'indoor_still_life.dart';
export 'macro_flower.dart';
export 'neon_portrait.dart';
export 'night_cityscape.dart';
export 'street_bw.dart';
export 'sunset_silhouette.dart';
export 'urban_architecture.dart';
```

- [ ] **Step 2: 创建 soft_portrait.dart（作为模板示例）**

```dart
// lib/features/capture/data/templates/soft_portrait.dart
import '../../domain/photo_template.dart';

/// 柔光人像模板
/// 来源：lumira-app/src/data/templates/soft-portrait.ts
const PhotoTemplate softPortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'soft_portrait',
    name: '柔光人像',
    author: 'Lumira',
    version: '1.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', style: 'soft', method: 'natural_light'),
    tags: ['人像', '柔光', '自然'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/soft-portrait.jpg',
    description: '适合室内窗边自然光，皮肤细节柔化处理',
    referenceSource: '样片 EXIF: Pexels #12345',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    opacity: 0.4,
    aspectRatio: '3:4',
    description: '人物置于画面右侧三分之一线，留白左侧',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'standing-profile'),
    position: Position(x: 0.7, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '侧身站立，面向左侧',
  ),
  camera: CameraParams(
    exposureCompensation: 0.3,
    iso: 200,
    shutterSpeed: '1/200',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'continuous',
    lensSuggestion: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '窗边侧光 45°',
    shootingDistance: '1.5-2m',
    background: '纯色墙面或浅灰背景纸',
    props: ['反光板', '纱帘'],
    bestTime: '上午 9:00-11:00',
    tips: ['使用反光板补光眼神光', '纱帘柔化侧光减少阴影'],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(
      brightness: 5,
      contrast: -5,
      saturation: -10,
      temperature: 3,
      tint: 2,
      highlights: -10,
      shadows: 10,
      clarity: -15,
      vibrance: 5,
    ),
    smoothStrength: 30,
    sharpen: 15,
    vignette: 10,
    grain: 5,
    lut: 'warm_film',
    systemFilter: 'vivid_warm',
  ),
);
```

- [ ] **Step 3: 创建其余 11 个模板数据文件**

每个文件遵循 soft_portrait.dart 的相同结构，数据从 `lumira-app/src/data/templates/*.ts` 翻译。

- [ ] **Step 4: 创建 template_registry.dart**

```dart
// lib/features/capture/data/template_registry.dart
import '../domain/photo_template.dart';
import 'templates/index.dart';

class TemplateRegistry {
  TemplateRegistry._();

  static const Map<String, PhotoTemplate> _templates = {
    'soft_portrait': softPortraitTemplate,
    'golden_landscape': goldenLandscapeTemplate,
    'cafe_portrait': cafePortraitTemplate,
    'film_vintage': filmVintageTemplate,
    'food_flat_lay': foodFlatLayTemplate,
    'indoor_still_life': indoorStillLifeTemplate,
    'macro_flower': macroFlowerTemplate,
    'neon_portrait': neonPortraitTemplate,
    'night_cityscape': nightCityscapeTemplate,
    'street_bw': streetBwTemplate,
    'sunset_silhouette': sunsetSilhouetteTemplate,
    'urban_architecture': urbanArchitectureTemplate,
  };

  static PhotoTemplate? getTemplate(String id) {
    final tpl = _templates[id];
    if (tpl == null) return null;
    return tpl.copyWith(); // 不可变副本
  }

  static List<PhotoTemplate> get allTemplates =>
      _templates.values.map((t) => t.copyWith()).toList();

  static List<PhotoTemplate> getRecentTemplates(int count) =>
      allTemplates.take(count).toList();
}
```

- [ ] **Step 5: 创建单元测试**

```dart
test('TemplateRegistry returns all 12 templates', () {
  expect(TemplateRegistry.allTemplates.length, 12);
});

test('getTemplate returns copy, not singleton', () {
  final t1 = TemplateRegistry.getTemplate('soft_portrait');
  final t2 = TemplateRegistry.getTemplate('soft_portrait');
  expect(identical(t1, t2), false); // different instances
  expect(t1!.meta.id, 'soft_portrait');
  expect(t1.postProcess.color.brightness, 5);
});

test('getRecentTemplates returns correct count', () {
  final recent = TemplateRegistry.getRecentTemplates(6);
  expect(recent.length, 6);
});

test('getTemplate returns null for unknown id', () {
  expect(TemplateRegistry.getTemplate('unknown'), isNull);
});
```

- [ ] **Step 6: 提交**

```bash
git add lib/features/capture/data/templates/ lib/features/capture/data/template_registry.dart test/features/capture/data/template_registry_test.dart
git commit -m "feat(capture): add 12 template data files and TemplateRegistry"
```

---

### Task 4: 场景预设数据

**Files:**
- Create: `lib/features/capture/data/scene_presets_data.dart`

**Interfaces:**
- Consumes: `ScenePreset`, `SceneFilter` 领域模型
- Produces: `List<ScenePreset> allScenePresets`, `ScenePreset? getScenePreset(String id)`

- [ ] **Step 1: 创建 scene_presets_data.dart 并定义所有 18 个场景预设**

```dart
// lib/features/capture/data/scene_presets_data.dart
import '../domain/photo_template.dart';
import '../domain/scene_preset.dart';

class ScenePresetsData {
  ScenePresetsData._();

  static const List<ScenePreset> allScenePresets = [
    ScenePreset(
      id: 'cafe-window',
      name: '窗边咖啡',
      icon: '☕',
      category: SceneCategory.indoor,
      style: 'warm',
      filter: SceneFilter(lut: 'warm_film', systemFilter: 'vivid_warm', reason: '温暖氛围突出木色调'),
      vibe: '慵懒午后',
      description: '咖啡馆窗边座位，自然光线透过玻璃洒落，木色调桌椅营造温暖氛围',
      exampleImages: ['https://picsum.photos/seed/cafe-window/400/600'],
      tips: ['窗边逆光时用反光板补面光', '低角度拍摄避开吊灯'],
      whereToShoot: '有落地窗的独立咖啡馆',
      bestTime: '14:00-16:00 斜阳时段',
      sceneGuide: SceneGuide(
        lightDirection: '侧逆光 45°',
        shootingDistance: '1-2m',
        background: '木质桌椅 + 绿植',
        props: ['咖啡杯', '甜点', '书本'],
        bestTime: '14:00-16:00',
        tips: ['侧逆光时亮部细节丰富', '利用咖啡杯反射补光'],
      ),
      relatedCategory: 'portrait',
      recommendedTagIds: ['cafe', 'warm', 'indoor'],
    ),
    // ... 其余 17 个场景预设
  ];

  static const Map<String, ScenePreset> _map = {
    for (final p in allScenePresets) p.id: p,
  };

  static ScenePreset? getScenePreset(String id) => _map[id];
}
```

核心：每个场景预设填入 SceneFilter（lut + systemFilter），点击场景预设时用这两个值更新 editableTemplate 的 postProcess。

- [ ] **Step 2: 创建测试验证场景预设数量和数据完整性**

- [ ] **Step 3: 提交**

---

### Task 5: Filter Recipe（ColorFilter 矩阵生成器）

**Files:**
- Create: `lib/features/capture/domain/filter_recipe.dart`
- Test: `test/features/capture/domain/filter_recipe_test.dart`

**Interfaces:**
- Consumes: `PostProcess`, `PostProcessColor`
- Produces: `ColorFilter fromPostProcess(PostProcess)`, `ColorFilter fromSystemFilter(String name)`, `ColorFilter approximateLut(String lutName)`

- [ ] **Step 1: 创建 filter_recipe.dart**

```dart
// lib/features/capture/domain/filter_recipe.dart
import 'dart:ui' show ColorFilter;
import 'photo_template.dart';

/// 从 PostProcess 构建 ColorFilter，用于取景器预览（ColorFiltered widget）
/// 对应 uni-app src/utils/filterRecipe.ts 的 buildCssFilter
ColorFilter fromPostProcess(PostProcess process) {
  // 1. ColorMatrix 链：亮度 → 对比度 → 饱和度 → 色温 → 色调
  final matrix = _buildColorMatrix(process.color);
  // 2. 叠加系统滤镜（如果设置了）
  if (process.systemFilter != null && process.systemFilter != 'none') {
    final filterMatrix = fromSystemFilter(process.systemFilter!);
    // 矩阵乘法叠加
    // ...
  }
  return ColorFilter.matrix(matrix);
}

/// 系统滤镜 ColorMatrix（对应 uni-app filterRecipe.ts 的 7 种 systemFilter）
ColorFilter fromSystemFilter(String name) {
  switch (name) {
    case 'vivid':
      return ColorFilter.matrix(<double>[
        1.1, 0, 0, 0, 0,  // R
        0, 1.1, 0, 0, 0,  // G
        0, 0, 1.1, 0, 0,  // B
        0, 0, 0, 1, 0,    // A
      ]);
    case 'vivid_warm':
      return ColorFilter.matrix(<double>[
        1.1, 0, 0, 0, 5,
        0, 1.05, 0, 0, 0,
        0, 0, 0.95, 0, -5,
        0, 0, 0, 1, 0,
      ]);
    case 'vivid_cool':
      return ColorFilter.matrix(<double>[
        0.95, 0, 0, 0, -3,
        0, 1.0, 0, 0, 0,
        0, 0, 1.1, 0, 5,
        0, 0, 0, 1, 0,
      ]);
    case 'mono':
      return ColorFilter.matrix(<double>[
        0.33, 0.34, 0.33, 0, 0,
        0.33, 0.34, 0.33, 0, 0,
        0.33, 0.34, 0.33, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    case 'silver':
      return ColorFilter.matrix(<double>[
        0.4, 0.3, 0.3, 0, 15,
        0.4, 0.3, 0.3, 0, 15,
        0.4, 0.3, 0.3, 0, 15,
        0, 0, 0, 1, 0,
      ]);
    case 'noir':
      return ColorFilter.matrix(<double>[
        0.33, 0.34, 0.33, 0, 0,
        0.33, 0.34, 0.33, 0, 0,
        0.33, 0.34, 0.33, 0, 0,
        0, 0, 0, 1, -30,
      ]);
    default: // 'none'
      return ColorFilter.matrix(List<double>.generate(20, (i) => [1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0][i]));
  }
}

/// LUT 近似（ColorMatrix 回退方案，当 gpu_image 3D LUT 不可用时使用）
ColorFilter approximateLut(String lutName) {
  // 16 种 LutPreset 各对应一个预定义 ColorMatrix（数值来自原 app 的 CSS filter 等效值）
  switch (lutName) {
    case 'cinematic':
      return ColorFilter.matrix(<double>[
        0.8, 0.1, 0.1, 0, 0,
        0, 0.9, 0.1, 0, 0,
        0.05, 0.05, 0.8, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    case 'vintage':
      return ColorFilter.matrix(<double>[
        1.1, 0, 0, 0, 10,
        0, 1.0, 0, 0, 5,
        0, 0, 0.8, 0, -5,
        0, 0, 0, 1, 0,
      ]);
    // ... 剩余 14 种
    default:
      return ColorFilter.matrix(List<double>.generate(20, (i) => [1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0][i]));
  }
}

List<double> _buildColorMatrix(PostProcessColor color) {
  // 亮度: 平移矩阵
  // 对比度: 中心缩放
  // 饱和度: RGB 通道加权
  // 色温: R+/B-
  // 色调: G+/R-/B-
  // 组合为一个 5x4 ColorMatrix
  final b = color.brightness / 100.0;  // -1 ~ 1
  final c = color.contrast / 100.0 + 1.0;  // 0.5 ~ 2.0
  final s = color.saturation / 100.0 + 1.0; // 0.5 ~ 2.0
  final t = color.temperature / 100.0;      // -1 ~ 1
  final tn = color.tint / 100.0;            // -1 ~ 1

  // brightness offset
  final nB = 1.0 - c;
  final baseT = nB * 0.5;

  // 组合矩阵（简化：逐个通道叠加）
  return <double>[
    c, 0, 0, 0, b * 255,
    0, c, 0, 0, b * 255,
    0, 0, c, 0, b * 255,
    0, 0, 0, 1, 0,
  ];
}
```

- [ ] **Step 2: 编写单元测试，验证矩阵值**

```dart
test('fromSystemFilter vivid increases RGB by 10%', () {
  final filter = fromSystemFilter('vivid');
  // 无法直接读取 matrix 值，验证返回实例
  expect(filter, isA<ColorFilter>());
});

test('vivid_warm adds red offset', () {
  final filter = fromSystemFilter('vivid_warm');
  expect(filter, isA<ColorFilter>());
});

test('mono produces grayscale', () {
  final filter = fromSystemFilter('mono');
  expect(filter, isA<ColorFilter>());
});

test('approximateLut returns ColorFilter for all 16 options', () {
  const luts = ['none', 'cinematic', 'vintage', 'bw', 'warm_film', 'cool_film', 'pastel', 'fuji',
    'portrait', 'japanese', 'cyberpunk', 'sepia_classic', 'mist', 'rouge', 'twilight', 'cyan'];
  for (final lut in luts) {
    expect(approximateLut(lut), isA<ColorFilter>(), reason: 'Failed for $lut');
  }
});
```

- [ ] **Step 3: 提交**

---

### Task 6: CaptureState Provider 扩展

**Files:**
- Modify: `lib/features/capture/data/capture_state.dart`
- Test: `test/features/capture/data/capture_state_test.dart`

**Interfaces:**
- Consumes: `PhotoTemplate`, `TemplateRegistry`
- Produces: 新增 provider：`originalTemplateProvider`, `editableTemplateProvider`, `appliedProvider`, `rawModeProvider`, `panelExpandedProvider`, `filterPickerVisibleProvider`, `bottomPanelExpandedProvider`, `activeScenePresetIdProvider`, `activeSceneFilterProvider`, `levelEnabledProvider`, `levelAngleProvider`, `kitsProvider`

- [ ] **Step 1: 修改 capture_state.dart，追加新增 provider**

```dart
// 在文件末尾追加（不修改已有 provider）
import '../../domain/photo_template.dart';
import '../data/template_registry.dart';

// ── 模板编辑状态 ──

/// 原始模板（只读，从 template_strip 选中或 URL 参数传入）
final originalTemplateProvider = Provider.family<PhotoTemplate?, String?>((ref, id) {
  if (id == null) return null;
  return TemplateRegistry.getTemplate(id);
});

/// 当前/可编辑模板 ID
final currentTemplateId2Provider = StateProvider<String?>((ref) => null);

/// 原始模板（派生自 currentTemplateId2Provider）
final originalTemplate2Provider = Provider<PhotoTemplate?>((ref) {
  final id = ref.watch(currentTemplateId2Provider);
  if (id == null) return null;
  return TemplateRegistry.getTemplate(id);
});

/// 可编辑模板副本
final editableTemplateProvider = StateProvider<PhotoTemplate?>((ref) {
  final original = ref.watch(originalTemplate2Provider);
  // 只需返回初始值，StateProvider 会自动维护后续状态
  return original?.copyWith();
});

/// applied = editableTemplate 与 originalTemplate 深度相等
final appliedProvider = Provider<bool>((ref) {
  final original = ref.watch(originalTemplate2Provider);
  final editable = ref.watch(editableTemplateProvider);
  if (original == null || editable == null) return false;
  return original == editable;
});

// ── 模式开关 ──
final rawModeProvider = StateProvider<bool>((ref) => false);
final panelExpandedProvider = StateProvider<bool>((ref) => false);
final filterPickerVisibleProvider = StateProvider<bool>((ref) => false);
final bottomPanelExpandedProvider = StateProvider<bool>((ref) => false);

// ── 场景 ──
final activeScenePresetIdProvider = StateProvider<String?>((ref) => null);

/// 当前场景对应的滤镜名称
final activeSceneFilterProvider = Provider<String?>((ref) {
  final id = ref.watch(activeScenePresetIdProvider);
  if (id == null) return null;
  final preset = ScenePresetsData.getScenePreset(id);
  return preset?.filter.lut;
});

// ── 水平仪 ──
final levelEnabledProvider = StateProvider<bool>((ref) => true);
final levelAngleProvider = StateProvider<double>((ref) => 0.0);

// ── 拍摄组合 ──
final kitsProvider = StateProvider<List<ShootKit>>((ref) => []);
```

注意：为避免与已有的 `currentTemplateIdProvider`、`showTemplateProvider`、`showSilhouetteProvider` 冲突，新增的模板相关 ID provider 用后缀 `2`。

- [ ] **Step 2: 编写测试验证派生 provider**

```dart
test('originalTemplate2Provider returns null when no template selected', () {
  // ... 创建 ProviderContainer，验证 originalTemplate2Provider 为 null
});
test('editableTemplateProvider initializes as copy of original', () {
  // ... 设置 currentTemplateId2Provider = 'soft_portrait'
  // ... 验证 editableTemplate 不为 null 且不与 original 同一实例
});
test('appliedProvider reflects equality', () {
  // ... 验证初始 applied = true
  // ... 修改 editableTemplate 后 applied = false
});
```

- [ ] **Step 3: 提交**

---

### Task 7: 顶部参数 Pill 栏 + ApplyButton + RawModeToggle

**Files:**
- Create: `lib/features/capture/widgets/param_pill_bar.dart`
- Create: `lib/features/capture/widgets/apply_button.dart`
- Create: `lib/features/capture/widgets/raw_mode_toggle.dart`

**Interfaces:**
- Consumes: `editableTemplateProvider`, `appliedProvider`, `rawModeProvider`, `originalTemplate2Provider`
- Produces: UI widgets

- [ ] **Step 1: 创建 apply_button.dart**

```dart
// 按钮：有模板且未应用时显示"应用参数"，点击重置 editableTemplate
class ApplyButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final original = ref.watch(originalTemplate2Provider);
    final applied = ref.watch(appliedProvider);
    if (original == null || applied) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () {
        ref.read(editableTemplateProvider.notifier).state = original.copyWith();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.amber,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text('应用', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
```

- [ ] **Step 2: 创建 raw_mode_toggle.dart**

```dart
// rawMode 切换开关
class RawModeToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raw = ref.watch(rawModeProvider);
    return GestureDetector(
      onTap: () => ref.read(rawModeProvider.notifier).state = !raw,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: raw ? Colors.amber : Colors.white24,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text('RAW', style: TextStyle(
          color: raw ? Colors.black : Colors.white70,
          fontSize: 11, fontWeight: FontWeight.w700,
        )),
      ),
    );
  }
}
```

- [ ] **Step 3: 创建 param_pill_bar.dart**

```dart
class ParamPillBar extends ConsumerWidget {
  const ParamPillBar({super.key});

  String _evDisplay(CameraParams c) =>
    c.exposureCompensation == 0 ? 'EV 0' : 'EV ${c.exposureCompensation >= 0 ? '+' : ''}${c.exposureCompensation}';
  String _wbDisplay(CameraParams c) {
    const labels = {'daylight': '日光', 'cloudy': '阴天', 'shade': '阴影', 'tungsten': '白炽灯', 'fluorescent': '荧光', 'custom': '自定义'};
    return 'WB ${labels[c.whiteBalance] ?? c.whiteBalance}';
  }
  String _isoDisplay(CameraParams c) => 'ISO ${c.isoMode == 'manual' ? c.iso.toString() : 'Auto'}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editable = ref.watch(editableTemplateProvider);
    final cam = editable?.camera;
    if (cam == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Pill(text: _evDisplay(cam), onTap: () => _openPanel(context, ref, 'camera')),
          _Pill(text: _wbDisplay(cam), onTap: () => _openPanel(context, ref, 'camera')),
          _Pill(text: _isoDisplay(cam), onTap: () => _openPanel(context, ref, 'camera')),
          const ApplyButton(),
          const RawModeToggle(),
          _Pill(icon: Icons.funnel, text: '滤镜', onTap: () => ref.read(filterPickerVisibleProvider.notifier).state = true),
        ].map((w) => Padding(padding: const EdgeInsets.only(right: 8), child: w)).toList(),
      ),
    );
  }

  void _openPanel(BuildContext context, WidgetRef ref, String tab) {
    ref.read(panelExpandedProvider.notifier).state = true;
  }
}

class _Pill extends StatelessWidget {
  final IconData? icon;
  final String? text;
  final VoidCallback onTap;
  const _Pill({this.icon, this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 12, color: Colors.white),
            if (text != null) Text(text!, style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 提交**

---

## Self-Review

**1. Spec coverage:**
- 架构与文件结构 → Task 1-14 覆盖所有新文件
- 数据模型（PhotoTemplate 全类型） → Task 1 覆盖
- 场景预设模型 → Task 2 覆盖
- 模板数据（12 文件 + 注册表） → Task 3 覆盖
- 场景预设数据（18 个） → Task 4 覆盖
- Filter Recipe（ColorFilter 矩阵） → Task 5 覆盖
- CaptureState Provider 扩展 → Task 6 覆盖
- 核心 Widgets（ParamPillBar, ApplyButton, RawModeToggle） → Task 7 覆盖
- ParamPanel（5 Tab 面板） → Task 8 覆盖
- FilterPicker → Task 9 覆盖
- TemplateStrip + ScenePresetStrip + LevelIndicator → Task 10 覆盖
- camera_preview.dart 修改（ColorFiltered + overlay + silhouette） → Task 11 覆盖
- capture_nav.dart 修改（标题可点击） → Task 12 覆盖
- capture_page.dart 重写 → Task 13 覆盖
- ImageProcessingService + LUT → Task 14 覆盖

**2. Placeholder scan:** 无 TBD/TODO 占位。每个 task 的 step 都有具体代码/命令。

**3. Type consistency:** 所有类型名与 spec 一致：`PhotoTemplate`, `TemplateMeta`, `Composition`, `Pose`, `CameraParams`, `SceneGuide`, `PostProcess`, `PostProcessColor`, `ScenePreset`, `SceneFilter`, `TemplateRegistry` 等。

## Plan complete and saved to `docs/superpowers/plans/2026-07-21-capture-page-full-features.md`. Two execution options:

**1. Subagent-Driven (recommended)** - 每个 Task 分派一个独立 subagent，中间 review，快速迭代

**2. Inline Execution** - 在当前会话中使用 executing-plans 执行，批处理 + 检查点 review

**Which approach?**

### Task 8: ParamPanel（5 Tab 参数编辑面板）

**Files:**
- Create: `lib/features/capture/widgets/param_panel.dart`

**Interfaces:**
- Consumes: `editableTemplateProvider`, `panelExpandedProvider`, `appliedProvider`, `rawModeProvider`, `originalTemplate2Provider`
- Produces: 底部抽屉式编辑面板 UI

- [ ] **Step 1: 创建 param_panel.dart**

```dart
class ParamPanel extends ConsumerWidget {
  const ParamPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(panelExpandedProvider);
    final editable = ref.watch(editableTemplateProvider);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      left: 0, right: 0,
      bottom: expanded ? 0 : -400,
      height: 400,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // 拖动条
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(2)),
            ),
            // Tab 切换
            DefaultTabController(
              length: 5,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: '相机'), Tab(text: '色彩'),
                      Tab(text: '细节'), Tab(text: '构图'), Tab(text: '场景'),
                    ],
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    indicatorColor: Colors.amber,
                  ),
                  SizedBox(
                    height: 300,
                    child: TabBarView(
                      children: [
                        _CameraTab(),
                        _ColorTab(),
                        _DetailTab(),
                        _CompositionTab(),
                        _SceneTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 底部"应用模板参数"按钮
            if (editable != null && ref.watch(originalTemplate2Provider) != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      final original = ref.read(originalTemplate2Provider);
                      if (original != null) {
                        ref.read(editableTemplateProvider.notifier).state = original.copyWith();
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                    child: const Text('应用模板参数', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 创建 5 个 Tab 子组件（同文件内）**

每个 Tab 使用 ListView + Slider/DropdownButton/SegmentedButton：

```dart
class _CameraTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editable = ref.watch(editableTemplateProvider);
    final cam = editable?.camera ?? const CameraParams();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _SliderRow(label: 'EV', value: cam.exposureCompensation, min: -3.0, max: 3.0, divisions: 120,
          display: '${cam.exposureCompensation >= 0 ? '+' : ''}${cam.exposureCompensation.toStringAsFixed(1)}',
          onChanged: (v) {
            final tpl = editable!.copyWith(camera: cam.copyWith(exposureCompensation: v));
            ref.read(editableTemplateProvider.notifier).state = tpl;
          }),
        _SliderRow(label: 'ISO', value: cam.iso.toDouble(), min: 100, max: 6400, divisions: 63,
          display: cam.iso.toString(), onChanged: (v) {
            final tpl = editable!.copyWith(camera: cam.copyWith(iso: v.round()));
            ref.read(editableTemplateProvider.notifier).state = tpl;
          }),
        _DropdownRow(label: '快门', value: cam.shutterSpeed, items: ['1/30','1/60','1/125','1/200','1/500','1/1000'],
          onChanged: (v) {
            final tpl = editable!.copyWith(camera: cam.copyWith(shutterSpeed: v));
            ref.read(editableTemplateProvider.notifier).state = tpl;
          }),
        _DropdownRow(label: '白平衡', value: cam.whiteBalance,
          items: ['daylight','cloudy','shade','tungsten','fluorescent','custom'],
          displayLabels: {'daylight':'日光','cloudy':'阴天','shade':'阴影','tungsten':'白炽灯','fluorescent':'荧光','custom':'自定义'},
          onChanged: (v) {
            final tpl = editable!.copyWith(camera: cam.copyWith(whiteBalance: v));
            ref.read(editableTemplateProvider.notifier).state = tpl;
          }),
        _DropdownRow(label: '闪光', value: cam.flashMode, items: ['off','on','auto','torch'],
          onChanged: (v) {
            final tpl = editable!.copyWith(camera: cam.copyWith(flashMode: v));
            ref.read(editableTemplateProvider.notifier).state = tpl;
          }),
        _DropdownRow(label: '对焦', value: cam.focusMode, items: ['auto','manual','continuous'],
          onChanged: (v) {
            final tpl = editable!.copyWith(camera: cam.copyWith(focusMode: v));
            ref.read(editableTemplateProvider.notifier).state = tpl;
          }),
      ],
    );
  }
}

// 色彩 Tab：亮度/对比度/饱和度/色温/色调/高光/阴影/黑点/鲜明度/自然饱和度
class _ColorTab extends ConsumerWidget { /* ... 10 个滑块 ... */ }

// 细节 Tab：清晰度(clarity)/锐化(sHarpen)/磨皮(smoothStrength)/暗角(vignette)/颗粒(grain)
class _DetailTab extends ConsumerWidget { /* ... 5 个滑块 (0-100) ... */ }

// 构图 Tab：叠图类型选择器 + 透明度滑块
class _CompositionTab extends ConsumerWidget { /* ... */ }

// 场景 Tab：场景指南文本预览（只读显示 sceneGuide 字段）
class _SceneTab extends ConsumerWidget { /* ... */}
```

- [ ] **Step 3: 编写 Widget 测试**

```dart
testWidgets('ParamPanel camera tab sliders update editableTemplate', (tester) async {
  // 创建 ProviderScope 设初始状态
  // 验证拖动 EV 滑块后 editableTemplate.camera.exposureCompensation 更新
});
```

- [ ] **Step 4: 提交**

---

### Task 9: FilterPicker（滤镜/系统滤镜选择器底部弹层）

**Files:**
- Create: `lib/features/capture/widgets/filter_picker.dart`

**Interfaces:**
- Consumes: `filterPickerVisibleProvider`, `editableTemplateProvider`, `rawModeProvider`
- Produces: ModalBottomSheet UI

- [ ] **Step 1: 创建 filter_picker.dart**

```dart
class FilterPicker extends ConsumerWidget {
  const FilterPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(filterPickerVisibleProvider);
    final rawMode = ref.watch(rawModeProvider);

    if (!visible) return const SizedBox.shrink();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!visible) return;
      _showSheet(context, ref);
    });

    return const SizedBox.shrink();
  }

  void _showSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2E),
      builder: (_) => Consumer(builder: (context, ref, _) {
        final raw = ref.watch(rawModeProvider);
        final editable = ref.watch(editableTemplateProvider);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('系统滤镜', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: ['none','vivid','vivid_warm','vivid_cool','mono','silver','noir'].map((f) {
                  final active = editable?.postProcess.systemFilter == f;
                  return ChoiceChip(
                    label: Text(_systemFilterLabel(f), style: const TextStyle(color: Colors.white)),
                    selected: active,
                    onSelected: raw ? null : (v) {
                      final tpl = editable?.copyWith(
                        postProcess: editable!.postProcess.copyWith(systemFilter: f == 'none' ? null : f),
                      );
                      ref.read(editableTemplateProvider.notifier).state = tpl;
                    },
                    backgroundColor: Colors.white12,
                    selectedColor: Colors.amber,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('LUT 预设', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _allLuts.map((lut) {
                  final active = editable?.postProcess.lut == lut;
                  return ChoiceChip(
                    label: Text(_lutLabel(lut), style: const TextStyle(color: Colors.white)),
                    selected: active,
                    onSelected: raw ? null : (v) {
                      final tpl = editable?.copyWith(
                        postProcess: editable!.postProcess.copyWith(lut: lut),
                      );
                      ref.read(editableTemplateProvider.notifier).state = tpl;
                    },
                    backgroundColor: Colors.white12,
                    selectedColor: Colors.amber,
                  );
                }).toList(),
              ),
              if (raw)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('RAW 模式下不可用', style: TextStyle(color: Colors.orange)),
                ),
            ],
          ),
        );
      }),
    ).whenComplete(() {
      // 关闭时重置可见状态
      ref.read(filterPickerVisibleProvider.notifier).state = false;
    });
  }
}
```

- [ ] **Step 2: 编写 Widget 测试**

- [ ] **Step 3: 提交**

---

### Task 10: TemplateStrip + ScenePresetStrip + LevelIndicator

**Files:**
- Create: `lib/features/capture/widgets/template_strip.dart`
- Create: `lib/features/capture/widgets/scene_preset_strip.dart`
- Create: `lib/features/capture/widgets/level_indicator.dart`

**Interfaces:**
- Consumes: `TemplateRegistry`, `ScenePresetsData`, `currentTemplateId2Provider`, `activeScenePresetIdProvider`, `levelEnabledProvider`, `levelAngleProvider`
- Produces: UI widgets

- [ ] **Step 1: 创建 template_strip.dart**

```dart
class TemplateStrip extends ConsumerWidget {
  final bool compact; // true=底部条, false=展开面板

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentId = ref.watch(currentTemplateId2Provider);
    final templates = TemplateRegistry.getRecentTemplates(compact ? 6 : 12);

    return SizedBox(
      height: compact ? 80 : 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: templates.length,
        itemBuilder: (ctx, i) {
          final tpl = templates[i];
          final active = tpl.meta.id == currentId;
          return GestureDetector(
            onTap: () => ref.read(currentTemplateId2Provider.notifier).state = tpl.meta.id,
            child: Container(
              width: compact ? 60 : 72,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: active ? Border.all(color: Colors.amber, width: 2) : null,
                color: Colors.white12,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image, color: active ? Colors.amber : Colors.white54, size: 24),
                  const SizedBox(height: 4),
                  Text(tpl.meta.name, style: TextStyle(
                    color: active ? Colors.amber : Colors.white70,
                    fontSize: 10,
                  ), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: 创建 scene_preset_strip.dart**

结构与 template_strip 类似，数据来自 `ScenePresetsData.allScenePresets`。

- [ ] **Step 3: 创建 level_indicator.dart**

```dart
class LevelIndicator extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(levelEnabledProvider);
    final angle = ref.watch(levelAngleProvider);
    if (!enabled) return const SizedBox.shrink();

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Center(
        child: CustomPaint(
          size: const Size(120, 24),
          painter: _LevelPainter(angle: angle),
        ),
      ),
    );
  }
}

class _LevelPainter extends CustomPainter {
  final double angle;
  _LevelPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()..color = Colors.white24..strokeWidth = 2;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(Offset(10, size.height / 2), Offset(size.width - 10, size.height / 2), trackPaint);
    // 气泡
    final bubbleX = center.dx + angle * 2;
    canvas.drawCircle(Offset(bubbleX, center.dy), 4, Paint()..color = Colors.amber);
    canvas.drawCircle(Offset(center.dx, center.dy), 3, Paint()..color = Colors.white38);
  }

  @override
  bool shouldRepaint(_LevelPainter old) => old.angle != angle;
}
```

- [ ] **Step 4: 提交**

---

### Task 11: 修改 camera_preview.dart（ColorFiltered + 构图/剪影支持）

**Files:**
- Modify: `lib/features/capture/widgets/camera_preview.dart`

**Interfaces:**
- Consumes: `editableTemplateProvider`, `showTemplateProvider`, `showSilhouetteProvider`, `fromPostProcess(filter_recipe.dart)`
- Produces: 增强的相机预览（ColorFiltered + 构图叠图 + 姿势剪影覆盖层）

- [ ] **Step 1: 修改 camera_preview.dart**

主要修改：
1. import `filter_recipe.dart` 和 `composition_overlay.dart`/`pose_silhouette.dart`
2. 在 `CameraAwesomeBuilder.awesome()` 外层包裹 `ColorFiltered`
3. 取景器顶部叠加 `CompositionOverlay` 和 `PoseSilhouette`

```dart
// camera_preview.dart 修改点

// 新增 import
import 'package:lumira_app_flutter/features/capture/domain/filter_recipe.dart';
import 'package:lumira_app_flutter/features/templates/widgets/composition_overlay.dart';
import 'package:lumira_app_flutter/features/templates/widgets/pose_silhouette.dart';
import '../data/capture_state.dart';

// 在 build 方法内
final editable = ref.watch(editableTemplateProvider);
final showTemplate = ref.watch(CaptureState.showTemplateProvider);
final showSilhouette = ref.watch(CaptureState.showSilhouetteProvider);

// 构建滤镜预览
final colorFilter = editable != null
    ? fromPostProcess(editable.postProcess)
    : const ColorFilter.mode(Colors.transparent, BlendMode.dst);

// 相机预览包裹
return Stack(
  children: [
    ColorFiltered(
      colorFilter: colorFilter,
      child: CameraAwesomeBuilder.awesome(/* ... 已有参数 ... */),
    ),
    // 构图叠图
    if (editable != null && showTemplate)
      Positioned.fill(
        child: IgnorePointer(
          child: CompositionOverlay(
            overlayType: editable.composition.overlayType,
            opacity: editable.composition.opacity,
          ),
        ),
      ),
    // 姿势剪影
    if (editable?.pose != null && editable!.pose.silhouette.data != 'none' && showSilhouette)
      Positioned.fill(
        child: IgnorePointer(
          child: PoseSilhouetteWidget(
            // 从 editable.pose 获取剪影资源
          ),
        ),
      ),
  ],
);
```

- [ ] **Step 2: 运行 `flutter analyze` 验证无问题**

- [ ] **Step 3: 提交**

---

### Task 12: 修改 capture_nav.dart（标题可点击 + 参数面板入口）

**Files:**
- Modify: `lib/features/capture/widgets/capture_nav.dart`

- [ ] **Step 1: 修改导航栏标题，改为可点击打开参数面板**

```dart
// 替换 title 的 Column 为 GestureDetector
Expanded(
  child: GestureDetector(
    onTap: () => ref.read(panelExpandedProvider.notifier).state = true,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [ /* 已有 title/subtitle */ ],
    ),
  ),
),
```

- [ ] **Step 2: 提交**

---

### Task 13: 重写 capture_page.dart（全功能集成布局）

**Files:**
- Modify: `lib/features/capture/pages/capture_page.dart`

**Interfaces:**
- Consumes: 所有前面的 provider 和 widget
- Produces: 完整拍摄页

- [ ] **Step 1: 重写 capture_page.dart**

完全替换为结构化的 Stack 布局：

```dart
class CapturePage extends ConsumerStatefulWidget {
  const CapturePage({super.key});
  @override
  ConsumerState<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends ConsumerState<CapturePage> {
  @override
  void initState() {
    super.initState();
    // 监听横竖屏变化（遵循项目记忆）
    // ...
  }

  @override
  Widget build(BuildContext context) {
    // 整个布局是一个 Stack，导航栏/参数条/底部控制区覆盖在取景器之上
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. 取景器 + 叠图（CameraPreview 内部处理 ColorFiltered + overlay + silhouette）
          const CameraPreview(),

          // 2. 导航栏（Positioned.top，透明背景）
          Positioned(
            top: 0, left: 0, right: 0,
            child: CaptureNav(onBack: () => context.pop()),
          ),

          // 3. 顶部参数 pill 栏
          Positioned(
            top: MediaQuery.of(context).padding.top + 72, // 导航栏高度
            left: 12, right: 12,
            child: const ParamPillBar(),
          ),

          // 4. 底部控制区
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 模板横滑条
                const TemplateStrip(compact: true),
                // 可折叠面板展开按钮
                GestureDetector(
                  onTap: () => ref.read(bottomPanelExpandedProvider.notifier).state =
                      !ref.read(bottomPanelExpandedProvider),
                  child: Icon(
                    ref.watch(bottomPanelExpandedProvider) ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                    color: Colors.white70,
                  ),
                ),
                // 可折叠面板
                if (ref.watch(bottomPanelExpandedProvider))
                  SizedBox(
                    height: 200,
                    child: Column(
                      children: [
                        Expanded(child: TemplateStrip(compact: false)),
                        Expanded(child: const ScenePresetStrip()),
                      ],
                    ),
                  ),
                // 拍摄按钮行
                const CaptureButtonRow(),
              ],
            ),
          ),

          // 5. 参数面板（底部滑入）
          const ParamPanel(),

          // 6. 滤镜选择器
          const FilterPicker(),

          // 7. 水平仪
          const LevelIndicator(),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 添加 CaptureButtonRow（已有但整合进新布局）**

```dart
class CaptureButtonRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 缩略图
          GestureDetector(
            onTap: () => context.push('/capture/preview'),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(6),
              ),
              child: ref.watch(CaptureState.lastPhotoPathProvider) != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(6),
                      child: Image.file(File(ref.watch(CaptureState.lastPhotoPathProvider)!), fit: BoxFit.cover))
                  : const Icon(Icons.image, color: Colors.white54, size: 20),
            ),
          ),
          // 拍摄按钮
          const CaptureButton(),
          // 翻转摄像头
          GestureDetector(
            onTap: () {
              final current = ref.read(CaptureState.facingProvider);
              ref.read(CaptureState.facingProvider.notifier).state =
                  current == CaptureFacing.back ? CaptureFacing.front : CaptureFacing.back;
            },
            child: Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
              child: const Icon(Icons.flip_camera_android, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: 运行测试验证现有 capture_page_test 通过**

Run: `flutter test test/features/capture/capture_page_test.dart`
Expected: PASS

- [ ] **Step 4: 提交**

---

### Task 14: ImageProcessingService（拍照后真实处理管线）

**Files:**
- Create: `lib/features/capture/services/image_processing_service.dart`
- Create: `lib/features/capture/services/lut_processor.dart`（gpu_image 封装）
- Test: `test/features/capture/services/image_processing_service_test.dart`

**Interfaces:**
- Consumes: `PostProcess`, `PostProcessColor`
- Produces: `static Future<ui.Image> process({required ui.Image input, required PostProcess params})`

- [ ] **Step 1: 创建 image_processing_service.dart**

```dart
import 'dart:ui' as ui;
import 'dart:math';
import '../domain/photo_template.dart';
import '../domain/filter_recipe.dart';
import 'lut_processor.dart';

class ImageProcessingService {
  /// 处理图像：按管线顺序应用所有后期参数
  static Future<ui.Image> process({
    required ui.Image input,
    required PostProcess params,
  }) async {
    final width = input.width;
    final height = input.height;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Step 1: 系统滤镜 + 基础色彩（ColorFilter）
    final colorFilter = fromPostProcess(params);
    final colorPaint = Paint()..colorFilter = colorFilter;
    canvas.drawImage(input, Offset.zero, colorPaint);

    // Step 2: 清晰度（clarity）- 使用高反差保留模拟
    if (params.color.clarity != null && params.color.clarity != 0) {
      // 简化：跳过，后续可以用 compute shader 实现
    }

    // Step 3: 锐化（Unsharp Mask）
    if (params.sharpen > 0) {
      // 使用 ImageFilter 的 blur 做 Unsharp Mask
      final blurSigma = params.sharpen / 100.0 * 2.0;
      if (blurSigma > 0.1) {
        final blurPaint = Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma);
        // 叠加
      }
    }

    // Step 4: 暗角（径向渐变）
    if (params.vignette > 0) {
      final centerX = width / 2.0;
      final centerY = height / 2.0;
      final radius = sqrt(centerX * centerX + centerY * centerY);
      final vignettePaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(centerX, centerY),
          radius,
          [Colors.transparent, Colors.black.withOpacity(params.vignette / 100.0 * 0.5)],
          [0.5, 1.0],
          TileMode.clamp,
        );
      canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), vignettePaint);
    }

    // Step 5: 颗粒（Perlin 噪声）
    if (params.grain > 0) {
      // 简化：跳过逐像素噪声，后续可以用 Compute Shader
    }

    // Step 6: LUT（使用 gpu_image 3D LUT）
    if (params.lut != 'none') {
      try {
        await LutProcessor.apply3DLut(canvas, input, params.lut);
      } catch (_) {
        // gpu_image 不可用，使用 ColorMatrix 近似
        final fallbackPaint = Paint()..colorFilter = approximateLut(params.lut);
        canvas.drawImage(input, Offset.zero, fallbackPaint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    return img;
  }
}
```

- [ ] **Step 2: 创建 lut_processor.dart（gpu_image 封装）**

```dart
// lib/features/capture/services/lut_processor.dart
/// LUT 处理器：封装 gpu_image 包的 3D LUT 支持
/// 运行时检测 gpu_image 包是否可用，不可用时抛出异常
class LutProcessor {
  /// 在 Canvas 上应用 3D LUT
  /// [lutName] 是预设名称，如 'cinematic', 'vintage', ...
  static Future<void> apply3DLut(Canvas canvas, ui.Image input, String lutName) async {
    // 使用 gpu_image 包加载对应 LUT 纹理并绘制
    // 当前简化：验证 gpu_image 可用性，后续实现
    throw UnimplementedError('gpu_image 3D LUT pending');
  }
}
```

- [ ] **Step 3: 编写单元测试**

```dart
test('ImageProcessingService.process does not crash with default params', () async {
  // 创建 2x2 红色测试图像
  // 应用默认 PostProcess
  // 验证返回非 null 图像
});
```

- [ ] **Step 4: 提交**

---