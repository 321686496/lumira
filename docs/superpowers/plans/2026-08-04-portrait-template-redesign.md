# 人像拍照模板重构实现路线图

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 按《人像拍照模板重构设计规范》分阶段实现 17 款人像模板，使套用模板拍出的照片比原图更好看。

**Architecture:** 规范涵盖 5 个独立子系统，按依赖顺序分 5 阶段实现。每阶段产出可独立测试的交付物。阶段间有明确依赖：阶段 1（剪影）和阶段 2（模板数据）可并行，阶段 3（参数校验）依赖阶段 2，阶段 4（AI 生成）依赖阶段 1 和 2，阶段 5（算法重构）依赖阶段 3。

**Tech Stack:** Flutter 3.7 + Dart 2.19 + Riverpod + image 4.0 + gpu_image 1.0 + camerawesome_ohos；uni-app（Vue 3 + TypeScript）作为参考实现同步更新。

**规范文档:** `docs/superpowers/specs/2026-08-04-portrait-template-redesign-design.md`

## Global Constraints

- 所有模板参数必须通过 C1-C5 约束检查（磨皮≤30、锐化≤25、颗粒≤25、同方向叠加≤2处、WB与temperature同向）
- Flutter 版与 uni-app 版模板数据保持一致
- 所有 image 资源来自 picsum.photos（项目硬约束）
- CSS 单位使用 rpx（uni-app），Flutter 使用逻辑像素
- uni-app 组件使用 `<view>`/`<text>`/`<image>` 而非 HTML 标签
- 不修改未经授权的代码（用户偏好）

---

## 阶段总览

| 阶段 | 名称 | 依赖 | 核心交付物 | 优先级 |
|---|---|---|---|---|
| 1 | 剪影 SVG 迁移与解析器扩展 | 无 | 17 个 SVG 剪影 + 贝塞尔曲线解析器 | P0 |
| 2 | 17 款模板数据文件编写 | 无 | Flutter + uni-app 双端模板数据 | P0 |
| 3 | 参数校准规则代码化 | 阶段 2 | C1-C5 约束校验器 + 冲突检测 | P1 |
| 4 | AI 生成脚本对接 | 阶段 1+2 | 封面图生成 + 剪影生成脚本 | P1 |
| 5 | 底层算法重构 | 阶段 3 | LUT 3D + 分区磨皮 + USM 锐化 + 色彩统一 | P2 |

### 阶段间依赖图

```
阶段1（剪影）──┐
               ├──> 阶段4（AI生成）
阶段2（数据）──┤
               └──> 阶段3（校验）──> 阶段5（算法）
```

---

## 阶段 1：剪影 SVG 迁移与解析器扩展

**目标：** 将 uni-app 的 12 个 SVG 剪影迁移到 Flutter，并为 17 款模板新增 5 个剪影，扩展 SVG 解析器支持贝塞尔曲线（C 命令）。

**文件结构：**
- Modify: `lumira_app_flutter/lib/features/templates/widgets/pose_silhouette.dart`（扩展 SVG 解析器）
- Modify: `lumira_app_flutter/lib/features/templates/data/templates_editor_mock_data.dart`（填充 builtinSilhouettes Map）
- Create: `lumira_app_flutter/lib/features/templates/data/silhouettes/silhouette_library.dart`（17 个 SVG 剪影库）
- Create: `lumira_app_flutter/test/features/templates/silhouette_parser_test.dart`（解析器测试）

**关键任务：**

### Task 1.1: 扩展 SVG 解析器支持贝塞尔曲线

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/widgets/pose_silhouette.dart:206-229`
- Test: `lumira_app_flutter/test/features/templates/silhouette_parser_test.dart`

**Interfaces:**
- Consumes: 无（基础组件）
- Produces: `_SilhouetteSvgParser` 支持 M/L/C/Q/Z 命令，输出 `Path` 对象

- [ ] **Step 1: 编写贝塞尔曲线解析失败测试**

```dart
// test/features/templates/silhouette_parser_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/templates/widgets/pose_silhouette.dart';

void main() {
  group('SilhouetteSvgParser', () {
    test('parses cubic bezier C command', () {
      final svg = 'M 10 10 C 20 20, 40 20, 50 10 Z';
      final parser = SilhouetteSvgParser(svg);
      final path = parser.parse();
      expect(path, isNotNull);
      // 验证路径包含贝塞尔曲线段
      expect(path.getBounds().width, greaterThan(0));
    });

    test('parses quadratic bezier Q command', () {
      final svg = 'M 10 10 Q 30 5, 50 10 Z';
      final parser = SilhouetteSvgParser(svg);
      final path = parser.parse();
      expect(path, isNotNull);
    });

    test('parses complex path with multiple commands', () {
      final svg = 'M 10 10 L 20 10 C 25 15, 35 15, 40 10 L 50 10 Z';
      final parser = SilhouetteSvgParser(svg);
      final path = parser.parse();
      expect(path, isNotNull);
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/features/templates/silhouette_parser_test.dart`
Expected: FAIL - 当前解析器不支持 C/Q 命令

- [ ] **Step 3: 实现 C/Q 命令解析**

修改 `pose_silhouette.dart` 的 `_SilhouetteSvgParser` 类，在 `_parseCommand` 方法中添加：

```dart
// 在 _parseCommand 方法中添加 C 和 Q 命令处理
case 'C':
  // 三次贝塞尔曲线: C x1 y1, x2 y2, x y
  final x1 = coords[0], y1 = coords[1];
  final x2 = coords[2], y2 = coords[3];
  final x = coords[4], y = coords[5];
  _currentPath.cubicTo(x1, y1, x2, y2, x, y);
  break;
case 'Q':
  // 二次贝塞尔曲线: Q x1 y1, x y
  final x1 = coords[0], y1 = coords[1];
  final x = coords[2], y = coords[3];
  _currentPath.quadraticBezierTo(x1, y1, x, y);
  break;
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/features/templates/silhouette_parser_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lumira_app_flutter/lib/features/templates/widgets/pose_silhouette.dart lumira_app_flutter/test/features/templates/silhouette_parser_test.dart
git commit -m "feat: 扩展剪影SVG解析器支持贝塞尔曲线C/Q命令"
```

### Task 1.2: 创建 17 个剪影 SVG 库

**Files:**
- Create: `lumira_app_flutter/lib/features/templates/data/silhouettes/silhouette_library.dart`
- Modify: `lumira_app_flutter/lib/features/templates/data/templates_editor_mock_data.dart:397-400`

**Interfaces:**
- Consumes: 无
- Produces: `SilhouetteLibrary.getSilhouette(String key)` 返回 SVG 字符串

- [ ] **Step 1: 创建剪影库文件，从 uni-app 迁移 12 个 SVG**

从 `lumira-app/src/data/silhouettes/index.ts` 复制 12 个 SVG 字符串到 Dart 常量：

```dart
// lib/features/templates/data/silhouettes/silhouette_library.dart
class SilhouetteLibrary {
  static const Map<String, String> silhouettes = {
    'standing-profile': '<svg viewBox="0 0 100 200">...',
    'sitting-cafe': '<svg viewBox="0 0 100 200">...',
    // ... 其余 10 个从 uni-app 迁移
  };

  static String? getSilhouette(String key) => silhouettes[key];
}
```

- [ ] **Step 2: 为 17 款模板新增 5 个剪影**

根据规范文档的 pose 结构化描述，为以下模板创建新 SVG：
- `ccd_retro_pose`（侧身回眸触发发梢）
- `cream_healing_pose`（坐姿托腮）
- `chinese_classical_pose`（执扇遮面）
- `anime_dream_pose`（张开双臂仰望）
- `foodie_pose`（举杯托腮看食物）

- [ ] **Step 3: 更新 builtinSilhouettes Map**

修改 `templates_editor_mock_data.dart`，将空字符串替换为实际 SVG：

```dart
final Map<String, String> builtinSilhouettes = SilhouetteLibrary.silhouettes;
```

- [ ] **Step 4: 修改 pose_silhouette.dart 渲染逻辑**

将 builtin 类型的占位 `Icon(Icons.person_outline)` 替换为从 `SilhouetteLibrary` 加载并解析 SVG：

```dart
// pose_silhouette.dart 中 builtin 类型处理
case 'builtin':
  final svg = SilhouetteLibrary.getSilhouette(data) ?? '';
  if (svg.isEmpty) return Icon(Icons.person_outline, size: 80);
  final path = SilhouetteSvgParser(svg).parse();
  return CustomPaint(
    painter: _SilhouettePainter(path, color: color),
    size: Size(80, 160),
  );
```

- [ ] **Step 5: 提交**

```bash
git add lumira_app_flutter/lib/features/templates/data/silhouettes/ lumira_app_flutter/lib/features/templates/data/templates_editor_mock_data.dart lumira_app_flutter/lib/features/templates/widgets/pose_silhouette.dart
git commit -m "feat: 迁移17个剪影SVG并替换占位符渲染"
```

---

## 阶段 2：17 款模板数据文件编写

**目标：** 按规范文档创建 17 款模板的 Flutter 和 uni-app 数据文件，替换现有 12 款模板。

**文件结构：**
- Create: `lumira_app_flutter/lib/features/capture/data/templates/ccd_retro_portrait.dart`（等 17 个文件）
- Modify: `lumira_app_flutter/lib/features/capture/data/template_registry.dart`（注册 17 款新模板）
- Create: `lumira-app/src/data/templates/ccd_retro_portrait.ts`（等 17 个文件）
- Modify: `lumira-app/src/data/templates/index.ts`（注册 17 款新模板）
- Delete: 旧 12 款模板文件（可选，或标记为 deprecated）

**关键任务：**

### Task 2.1: 创建 Flutter 版 17 款模板数据

**Files:**
- Create: 17 个 `.dart` 文件在 `lumira_app_flutter/lib/features/capture/data/templates/`
- Modify: `lumira_app_flutter/lib/features/capture/data/template_registry.dart`

**Interfaces:**
- Consumes: `PhotoTemplate` 领域模型（`photo_template.dart`）
- Produces: 17 个 `PhotoTemplate` 常量

- [ ] **Step 1: 创建 ccd_retro_portrait.dart 作为模板**

按规范文档模板 1 的参数创建：

```dart
// lib/features/capture/data/templates/ccd_retro_portrait.dart
import '../../domain/photo_template.dart';

final ccdRetroPortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'ccd_retro_portrait',
    name: 'CCD 胶片复古',
    author: 'Lumira',
    version: '1.0.0',
    category: Target.portrait,
    classification: TemplateClassification(
      type: 'portrait',
      style: 'ccd_retro',
      method: 'half_body',
    ),
    tags: ['复古', 'CCD', '胶片', '暖黄'],
    tagIds: [],
    price: 0,
    cover: 'https://picsum.photos/seed/ccd_retro/400/533',
    description: '90 年代 CCD 复古质感，暖黄颗粒自带柔光，拍出老照片的温柔记忆。',
    referenceSource: '醒图/ProCCD',
  ),
  composition: Composition(
    overlayType: OverlayType.rule_of_thirds,
    subjectFrame: SubjectFrame(x: 0.28, y: 0.15, w: 0.45, h: 0.7),
    opacity: 0.3,
    aspectRatio: '3:4',
    description: '三分线左侧，半身取景，头部位于上三分线',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'ccd_retro_pose'),
    position: PosePosition(x: 0.28, y: 0.5),
    scale: 0.75,
    rotation: 0,
    description: '随性侧身回眸',
  ),
  camera: CameraParams(
    exposureCompensation: 0.3,
    iso: 200,
    shutterSpeed: '1/125',
    whiteBalance: WhiteBalance.cloudy,
    whiteBalanceK: 6000,
    flashMode: FlashMode.off,
    focusMode: FocusMode.auto,
    lensType: '1x',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧顺光',
    lightDirectionAngle: 45,
    shootingDistance: '1.5-2m',
    background: '老街/室内暖光/复古墙面',
    props: [],
    bestTime: '下午 15:00-17:00',
    bestTimeFrom: '15:00',
    bestTimeTo: '17:00',
    tips: ['利用午后暖光营造复古氛围', '可轻微晃动模拟 CCD 对焦不准', '服装选择纯色或格纹'],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(
      brightness: 8,
      contrast: -5,
      saturation: 5,
      temperature: 15,
      tint: 0,
      highlights: -10,
      shadows: 10,
      clarity: -5,
      vibrance: 5,
    ),
    smoothStrength: 15,
    sharpen: 8,
    vignette: 15,
    grain: 20,
    lut: LutPreset.vintage,
  ),
);
```

- [ ] **Step 2: 按相同模式创建其余 16 个模板文件**

根据规范文档第 6 节的参数，逐一创建：
- `hk_noir_portrait.dart`（模板 2）
- `japanese_fresh_portrait.dart`（模板 3）
- `cream_healing_portrait.dart`（模板 4）
- `chinese_classical_portrait.dart`（模板 5）
- `french_lazy_portrait.dart`（模板 6）
- `morandi_minimal_portrait.dart`（模板 7）
- `dark_indoor_portrait.dart`（模板 8）
- `neon_city_portrait.dart`（模板 9）
- `fresh_green_portrait.dart`（模板 10）
- `y2k_portrait.dart`（模板 11）
- `anime_dream_portrait.dart`（模板 12）
- `blue_night_portrait.dart`（模板 13）
- `purple_dusk_portrait.dart`（模板 14）
- `foodie_portrait.dart`（模板 15）
- `sweet_girl_portrait.dart`（模板 16）
- `elegant_lady_portrait.dart`（模板 17）

- [ ] **Step 3: 更新 template_registry.dart 注册新模板**

```dart
// lib/features/capture/data/template_registry.dart
class TemplateRegistry {
  static final Map<String, PhotoTemplate> _templates = {
    'ccd_retro_portrait': ccdRetroPortraitTemplate,
    'hk_noir_portrait': hkNoirPortraitTemplate,
    // ... 其余 15 个
  };

  static PhotoTemplate? getTemplate(String id) => _templates[id];
  static List<PhotoTemplate> get allTemplates => _templates.values.toList();
}
```

- [ ] **Step 4: 提交**

```bash
git add lumira_app_flutter/lib/features/capture/data/templates/ lumira_app_flutter/lib/features/capture/data/template_registry.dart
git commit -m "feat: 创建17款人像拍照模板数据（Flutter版）"
```

### Task 2.2: 创建 uni-app 版 17 款模板数据

与 Task 2.1 相同的参数，但用 TypeScript 格式，存放到 `lumira-app/src/data/templates/`。

- [ ] **Step 1-3:** 按 Task 2.1 模式创建 17 个 `.ts` 文件并更新 `index.ts`
- [ ] **Step 4:** 提交

---

## 阶段 3：参数校准规则代码化

**目标：** 将 C1-C5 约束和三段式校准规则实现为代码校验器，在模板加载时自动检测参数冲突。

**文件结构：**
- Create: `lumira_app_flutter/lib/features/capture/domain/template_validator.dart`
- Create: `lumira_app_flutter/test/features/capture/template_validator_test.dart`

**关键任务：**

### Task 3.1: 实现 C1-C5 约束校验器

- [ ] **Step 1:** 编写 C1-C5 约束测试（smoothStrength≤30, sharpen≤25, grain≤25, 叠加≤2处, WB同向）
- [ ] **Step 2:** 实现 `TemplateValidator.validate(PhotoTemplate)` 返回 `ValidationResult`
- [ ] **Step 3:** 运行测试
- [ ] **Step 4:** 提交

### Task 3.2: 在模板注册表集成校验

- [ ] **Step 1:** 在 `TemplateRegistry` 加载时调用校验器
- [ ] **Step 2:** 校验失败的模板输出警告日志
- [ ] **Step 3:** 提交

---

## 阶段 4：AI 生成脚本对接

**目标：** 根据规范的 AI 生成输入规范，创建封面图和剪影的 AI 生成脚本接口（实际脚本由用户提供）。

**文件结构：**
- Create: `lumira_app_flutter/lib/features/templates/services/ai_generation_service.dart`
- Create: `lumira_app_flutter/lib/features/templates/services/cover_prompt_builder.dart`
- Create: `lumira_app_flutter/lib/features/templates/services/pose_prompt_builder.dart`

**关键任务：**

### Task 4.1: 封面图 prompt 构建器

- [ ] **Step 1:** 实现 `CoverPromptBuilder.build(PhotoTemplate)` 返回结构化 prompt 字符串
- [ ] **Step 2:** 测试 17 款模板的 prompt 生成
- [ ] **Step 3:** 提交

### Task 4.2: 剪影 pose 描述构建器

- [ ] **Step 1:** 实现 `PosePromptBuilder.build(Pose)` 返回 YAML 结构化描述
- [ ] **Step 2:** 测试 17 款模板的 pose 描述生成
- [ ] **Step 3:** 提交

---

## 阶段 5：底层算法重构

**目标：** 修复 A-1（LUT 线性近似）、A-2（磨皮全图模糊）、A-3（色彩空间差异）三类算法问题。

**文件结构：**
- Modify: `lumira_app_flutter/lib/features/capture/services/lut_processor.dart`
- Modify: `lumira_app_flutter/lib/features/capture/services/skin_smoother.dart`
- Modify: `lumira_app_flutter/lib/features/capture/services/dart_photo_pipeline.dart`
- Modify: `lumira_app_flutter/lib/features/capture/domain/filter_recipe.dart`

**关键任务：**

### Task 5.1: LUT 3D 查找表支持
- 替换 ColorMatrix 近似为真实 3D LUT 文件加载
- 评估 gpu_image 替代方案或自实现 3D LUT 插值

### Task 5.2: 分区磨皮算法
- 实现皮肤区域检测（基于肤色阈值或 ML 分割）
- 仅对皮肤区域应用磨皮，保留眼睛/头发/背景细节

### Task 5.3: USM 锐化替代
- 替换当前卷积核为 USM（Unsharp Mask）算法
- 控制白边光晕

### Task 5.4: 色彩空间统一
- 统一 GPU 管线与 worker Isolate 的色彩处理
- 确保 WYSIWYG 一致性

### Task 5.5: 颗粒随机种子
- 移除固定种子 `Random(42)`，改为 `Random()` 每张变化

---

## 执行顺序建议

1. **阶段 1 + 阶段 2 可并行**（无依赖关系）
2. **阶段 3 在阶段 2 完成后**
3. **阶段 4 在阶段 1+2 完成后**
4. **阶段 5 在阶段 3 完成后**

建议从**阶段 1 和阶段 2 并行启动**，因为这两个阶段直接解决用户最关心的"模板让照片变丑"问题（剪影占位符 + 参数错误）。

---

## 自检清单

- [x] 规范覆盖：17 款模板数据（阶段 2）、剪影迁移（阶段 1）、参数校验（阶段 3）、AI 生成（阶段 4）、算法修复（阶段 5）均有对应任务
- [x] 占位符扫描：无 TBD/TODO，所有任务有具体步骤
- [x] 类型一致性：`PhotoTemplate`/`SilhouetteLibrary`/`TemplateValidator` 等类型在任务间一致
- [x] 依赖顺序：阶段间依赖图清晰，无循环依赖
