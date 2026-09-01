# 磨皮（皮肤平滑）实时预览 — 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 GPU 片元着色器（`skin_smooth.frag`）让磨皮效果在相册修图/拍摄后修图的滑块拖动时实时预览、并在导出时复用同一 shader 达到所见即所得。

**Architecture:** 单一 GLSL 片元着色器实现「频率分离磨皮」，逐片元并行；静态预览用 `FragmentProgram`（`setFloat` + `setImageSampler`）画 `ui.Image`，导出离线用同一 shader 渲染输出。CPU `SkinSmoother` 保留为降级后端。

**Tech Stack:** Dart 2.19.6 / Flutter 3.7.12，GLSL `#include <flutter/runtime_effect.glsl>`，`dart:ui` FragmentProgram/FragmentShader，`image` 包（降级后端）。

## Global Constraints

- Dart 2.19.6 **不支持 Dart 3 records**；用传统 class/命名参数。
- 不允许 `Color(0xFF…)`/`Colors.xxx` 硬编码皮肤相关观感（UI 风格走 theme tokens）。shader 内存逻辑色不受此限。
- 实时预览**零 GPU 读回**，不得 `toImage`→CPU 回灌（历史拉腿卡顿教训）。
- `smoothStrength` 范围 0..100；`strength = smoothStrength/100` 传 uniform。
- 三端（OHOS/iOS/Android）必须都能编译运营 shader。
- 每次对 `lumira-server/packages/` 或 `admin/` 改动才需双远程 push；本计划全在 `lumira_app_flutter/`，按项目规则相邻改动可合并 commit（纯 Flutter 端，用户按惯例决定是否推送，默认**不主动 push**）。
- 设计文档：`docs/specs/2026-09-01-skin-smooth-real-time-design.md`（已获批）。

---

### Task 0: shader 基础设施 + 参数映射 + 快速路径（含测试）

**Files:**
- Create: `lumira_app_flutter/assets/shaders/skin_smooth.frag`
- Create: `lumira_app_flutter/lib/features/capture/services/skin_smooth_shader.dart`
- Test: `lumira_app_flutter/test/features/capture/services/skin_smooth_shader_test.dart`
- Modify: `lumira_app_flutter/pubspec.yaml`（`flutter:` 节加 `shaders:`）

**Interfaces:**
- Consumes: `PostProcess.smoothStrength`（int 0..100）、`PostProcessColor`（`filter_recipe.dart`）。
- Produces:
  - `double skinStrength(PostProcess p)` → `p.smoothStrength / 100.0`（clamp 0..1）。
  - `bool needsSkin(PostProcess p)` → `p.smoothStrength > 0`。
  - `class SkinSmoothConfig { final double strength; }` + `SkinSmoothConfig.fromPostProcess(PostProcess p)`，构造失败回退 `null` 逻辑在外层。
  - 着色器 GLSL 常量字符串常量 `skinSmoothFragSrc`（供测试校验关键公式存在）。

- [ ] **Step 1: 写失败测试**

`skin_smooth_shader_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/services/skin_smooth_shader.dart';

void main() {
  group('SkinSmoothConfig', () {
    test('strength 归一化 clamp 0..1', () {
      expect(skinStrength(PostProcess(smoothStrength: 50)), closeTo(0.5, 1e-9));
      expect(skinStrength(PostProcess(smoothStrength: 101)), 1.0);
      expect(skinStrength(PostProcess(smoothStrength: -5)), 0.0);
    });
    test('needsSkin 仅 smoothStrength>0', () {
      expect(needsSkin(PostProcess(smoothStrength: 30)), isTrue);
      expect(needsSkin(const PostProcess()), isFalse);
    });
    test('fromPostProcess 生成配置', () {
      final c = SkinSmoothConfig.fromPostProcess(PostProcess(smoothStrength: 60));
      expect(c.strength, closeTo(0.6, 1e-9));
    });
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/features/capture/services/skin_smooth_shader_test.dart -v`
Expected: FAIL，`skin_smooth_shader.dart` 不存在。

- [ ] **Step 3: 写最小实现 `skin_smooth_shader.dart`**

```dart
import '../domain/photo_template.dart';

/// 磨皮 shader 的宿主无关参数映射。
class SkinSmoothConfig {
  const SkinSmoothConfig({required this.strength});
  final double strength;
  factory SkinSmoothConfig.fromPostProcess(PostProcess p) =>
      SkinSmoothConfig(strength: skinStrength(p));
}

double skinStrength(PostProcess p) =>
    (p.smoothStrength / 100.0).clamp(0.0, 1.0).toDouble();

bool needsSkin(PostProcess p) => p.smoothStrength > 0;
```

（`photo_template.dart` 里 `PostProcess` 已有 `smoothStrength` 字段，见 `skin_smoother.dart` 用法。）

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/features/capture/services/skin_smooth_shader_test.dart -v`
Expected: PASS

- [ ] **Step 5: 创建 GLSL `skin_smooth.frag`**

内容应与 `skin_smoother.dart` 频率分离语义对等（`strength` 归一化、`baseRemove`、`edgeLow/edgeHigh`、YCbCr 肤色 soft、`out=base+detail*(1-removal)`），并声明 `uStrength`/`uTexture`/`uSize`：

```glsl
#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uStrength;
uniform sampler2D uTexture;

out vec4 fragColor;

float ss_step(float edge0, float edge1, float x) {
  float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

// 邻域低频采样：以 strength 决定采样半径（对应 CPU radius 2..5）
float lowPassRadius() { return 2.0 + 3.0 * uStrength; }

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  float radius = lowPassRadius();
  // 4 方向 4 采样的低成本低频近似（可后续调权，匹配 CPU 高斯视觉）
  vec2 texel = 1.0 / uSize;
  vec4 base = texture(uTexture, uv) * 0.0;
  float wSum = 0.0;
  for (int i = -4; i <= 4; i++) {
    float w = exp(-float(i * i) / (2.0 * radius * radius));
    vec2 off = vec2(float(i), 0.0) * texel;
    base += texture(uTexture, uv + off) * w;
    wSum += w;
  }
  for (int i = -4; i <= 4; i++) {
    float w = exp(-float(i * i) / (2.0 * radius * radius));
    vec2 off = vec2(0.0, float(i)) * texel;
    base += texture(uTexture, uv + off) * w;
    wSum += w;
  }
  base /= wSum;

  vec4 src = texture(uTexture, uv);
  vec3 detail = src.rgb - base.rgb;
  float margin = max(max(abs(detail.r), abs(detail.g)), abs(detail.b));

  // YCbCr 肤色概率（BT.601，soft 区间 —— 与 skin_smoother.dart:_skinWeight 对等）
  float y  = 0.299 * src.r + 0.587 * src.g + 0.114 * src.b;
  float cb = (-0.168736 * src.r - 0.331264 * src.g + 0.5 * src.b) + 0.5;
  float cr = (0.5 * src.r - 0.418688 * src.g - 0.081312 * src.b) + 0.5;
  float yW   = ss_step(40.0 / 255.0, 60.0 / 255.0, y) * (1.0 - ss_step(250.0 / 255.0, 255.0 / 255.0, y));
  float crW  = ss_step(128.0 / 255.0, 140.0 / 255.0, cr) * (1.0 - ss_step(172.0 / 255.0, 186.0 / 255.0, cr));
  float cbW  = ss_step(70.0 / 255.0, 85.0 / 255.0, cb)  * (1.0 - ss_step(120.0 / 255.0, 132.0 / 255.0, cb));
  float skin = yW * crW * cbW;

  float baseRemove = 0.50 * uStrength + 0.04;
  float edgeLow  = 6.0 + 6.0 * uStrength;
  float edgeHigh = edgeLow * 2.5;
  float struct  = ss_step(edgeLow, edgeHigh, margin);
  float removal = clamp(baseRemove * skin * (1.0 - struct), 0.0, 1.0);

  vec3 outC = base.rgb + detail.rgb * (1.0 - removal);
  fragColor = vec4(outC, src.a);
}
```

> 注意：GLSL 编译以 `#include <flutter/runtime_effect.glsl>`（提供 `FlutterFragCoord`）为准；具体 `#version` 行、loop 语法在目标引擎若报错，按报错就近修正，不改变算法语义。

- [ ] **Step 6: pubspec 声明 shaders**

`pubspec.yaml` `flutter:` 节加入：

```yaml
  shaders:
    - assets/shaders/skin_smooth.frag
```

- [ ] **Step 7: 校验编译**

Run: `flutter analyze`
Expected: 无新增 error；`skin_smooth.frag` 不在 analyzer 范围（资产），shader 运行时编译另有处理。

- [ ] **Step 8: Commit**

```powershell
git add lumira_app_flutter/assets/shaders/skin_smooth.frag lumira_app_flutter/lib/features/capture/services/skin_smooth_shader.dart lumira_app_flutter/test/features/capture/services/skin_smooth_shader_test.dart lumira_app_flutter/pubspec.yaml
git commit -m "feat: 磨皮 GPU shader 基础设施、参数映射与快速路径"
```

---

### Task 1: `SkinSmoothPreview` 渲染组件（含防抖/降级）

**Files:**
- Create: `lumira_app_flutter/lib/features/capture/widgets/skin_smooth_preview.dart`
- Test: `lumira_app_flutter/test/features/capture/widgets/skin_smooth_preview_test.dart`

**Interfaces:**
- Consumes: `skinStrength`/`needsSkin`/`SkinSmoothConfig`（Task 0）；`ui.Image`。
- Produces:
  - `class SkinSmoothPreview extends StatefulWidget { final ui.Image image; final double strength; final bool enabled; }`
  - `static Future<FragmentProgram?> loadProgram()` — 资源加载失败返回 `null`（降级信号）。
  - `shouldRender(Widget) → bool`：`enabled && strength>0 && program!=null`。

- [ ] **Step 1: 写失败测试**

`skin_smooth_preview_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/widgets/skin_smooth_preview.dart';

void main() {
  test('shouldRender: strength=0 返回 false（快速路径）', () {
    final r = SkinSmoothPreview.staticShouldRender(enabled: true, strength: 0.0);
    expect(r, isFalse);
  });
  test('shouldRender: enabled=false 返回 false', () {
    final r = SkinSmoothPreview.staticShouldRender(enabled: false, strength: 0.5);
    expect(r, isFalse);
  });
  test('shouldRender: 启用且 strength>0 返回 true', () {
    final r = SkinSmoothPreview.staticShouldRender(enabled: true, strength: 0.5);
    expect(r, isTrue);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/features/capture/widgets/skin_smooth_preview_test.dart -v`
Expected: FAIL，`skin_smooth_preview.dart` 不存在。

- [ ] **Step 3: 写实现 `skin_smooth_preview.dart`**

```dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 磨皮实时预览渲染组件：用 FragmentShader 逐片元磨皮。
///
/// - enabled && strength>0 且 program 加载成功 → 走 shader 渲染（GPU，零读回）。
/// - 否则快速路径：直接画 [image]。
/// - [fragBuilder] 供测试注入；缺省用 `FragmentProgram.fromAsset`。
/// - 渲染期异常一律降级：捕获后画原图，不抛出（不阻塞编辑页）。
class SkinSmoothPreview extends StatefulWidget {
  const SkinSmoothPreview({
    super.key,
    required this.image,
    required this.strength,
    this.enabled = true,
    this.loadProgram,
  });

  final ui.Image image;
  final double strength;
  final bool enabled;

  /// 自定义着色器程序加载器（测试注入 / 降级探测）。
  final Future<Object?> Function()? loadProgram;

  /// 纯逻辑快速路径判定（便于测试）。
  static bool staticShouldRender({required bool enabled, required double strength}) =>
      enabled && strength > 0;

  @override
  State<SkinSmoothPreview> createState() => _SkinSmoothPreviewState();
}

class _SkinSmoothPreviewState extends State<SkinSmoothPreview> {
  bool _programOk = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _maybeLoadProgram();
  }

  @override
  void didUpdateWidget(SkinSmoothPreview old) {
    super.didUpdateWidget(old);
    if (old.loadProgram != widget.loadProgram || (!_loadedScopeOk())) {
      _maybeLoadProgram();
    }
  }

  bool _loadedScopeOk() => !_loadFailed && _programOk;

  Future<void> _maybeLoadProgram() async {
    final loader = widget.loadProgram;
    final usesShader = widget.enabled && widget.strength > 0;
    if (!usesShader || loader == null) {
      if (mounted && !_programOk) {
        setState(() {
          _programOk = true; // 无 loader 时视为纯原图路径
          _loadFailed = false;
        });
      }
      return;
    }
    try {
      final prog = await loader();
      if (!mounted) return;
      setState(() {
        _programOk = prog != null;
        _loadFailed = prog == null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _programOk = false;
        _loadFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final useShader = widget.enabled && widget.strength > 0 && _programOk;
    return useShader
        ? _ShaderCanvas(image: widget.image, strength: widget.strength)
        : RawImage(image: widget.image, fit: BoxFit.contain);
  }
}

/// 真正用 FragmentProgram + CustomPainter 画 shader 的层。
class _ShaderCanvas extends StatelessWidget {
  const _ShaderCanvas({required this.image, required this.strength});
  final ui.Image image;
  final double strength;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SkinSmoothPainter(image: image, strength: strength),
      child: RawImage(image: image, fit: BoxFit.contain),
    );
  }
}

class _SkinSmoothPainter extends CustomPainter {
  _SkinSmoothPainter({required this.image, required this.strength});
  final ui.Image image;
  final double strength;
  ui.FragmentProgram? _prog;
  bool _failed = false;

  @override
  void paint(Canvas canvas, Size size) {
    try {
      _prog ??= _loadSync();
      if (_prog == null) {
        _fallback(canvas, size);
        return;
      }
      final sh = _prog!.fragmentShader()
        ..setFloat(0, size.width)
        ..setFloat(1, size.height)
        ..setFloat(2, strength)
        ..setImageSampler(0, image);
      // 索引：float 用 setFloat 独立索引（uSize.x→0,uSize.y→1,uStrength→2）；sampler 用 setImageSampler 独立索引（uTexture→0）。
      canvas.drawRect(Offset.zero & size, Paint()..shader = sh);
    } catch (_) {
      _failed = true;
      _fallback(canvas, size);
    }
  }

  void _fallback(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  static ui.FragmentProgram? _loadSync() {
    throw UnimplementedError('异步加载见 canvas/_ShaderCanvas 的异步变体');
  }

  @override
  bool shouldRepaint(covariant _SkinSmoothPainter old) =>
      old.image != image || old.strength != strength;
}
```

> ⚠️ 上述 `_loadSync` 为占位：真实实现必须在 `_ShaderCanvas` 为 StatefulWidget，在 `initState` 用 `FragmentProgram.fromAsset('shaders/skin_smooth.frag')` 异步加载并存状态；painter 接收已加载的 program。**执行时把 `_ShaderCanvas` 改为持有异步加载的 FragmentProgram 的 StatefulWidget，并将 program 传入 painter；将 `.frag` 中 uniform 索引与 `setFloat/setImageSampler` 对齐。** 若运行时报 uniform 索引不匹配，按 shader 声明顺序调整索引（uSize→0,1；uStrength→2；uTexture→3）。

- [ ] **Step 4: 运行通过**

Run: `flutter test test/features/capture/widgets/skin_smooth_preview_test.dart -v`
Expected: PASS

- [ ] **Step 5: 手动冒烟（可选，真机/桌面）**

在任意编辑页临时把某个预览包一层 `SkinSmoothPreview`，确认 `strength=0` 走原图、`strength>0` 走 shader、加载失败自动降级不白屏。

- [ ] **Step 6: Commit**

```powershell
git add lumira_app_flutter/lib/features/capture/widgets/skin_smooth_preview.dart lumira_app_flutter/test/features/capture/widgets/skin_smooth_preview_test.dart
git commit -m "feat: 磨皮实时预览 SkinSmoothPreview 组件（含降级与测试）"
```

---

### Task 2: 相册修图画布接入磨皮实时预览

**Files:**
- Modify: `lumira_app_flutter/lib/features/gallery/pages/gallery_edit_page.dart`（画布 `_buildImage` 及 `_CanvasArea`）

**Interfaces:**
- Consumes: `SkinSmoothPreview`、`needsSkin`/`skinStrength`（Task 0/1）。
- Produces: `_CanvasArea` 在 `postProcess.smoothStrength>0` 时把图片绘制切换到 shader，并把 `ColorFiltered` 与新磨皮层正确组合。

- [ ] **Step 1: 阅读现有实现**

`gallery_edit_page.dart` 的 `_buildImage`（约 L1075）用 `ColorFiltered(colorFilter: fromPostProcess(appliedPost))` 包 `LumiraImage`。磨皮是逐像素，无法进 ColorMatrix。

- [ ] **Step 2: 结构调整（在 `_buildImage` 内）**

把「色彩矩阵 ColorFiltered」与「磨皮」拆成两层叠加，顺序保持一致（色彩矩阵 → 磨皮）：

```dart
// 色彩层：保持现状
imageWidget = ColorFiltered(
  colorFilter: fromPostProcess(appliedPost)
      .withOpacity(/* 透传）*/),
  child: imageWidget,
);
// 磨皮层：若 smoothStrength>0，用 SkinSmoothPreview 覆盖同尺寸区域
final smoothWrapped = SkinSmoothPreview(
  image: /* 由 LumiraImage 对应 ui.Image */,
  strength: skinStrength(appliedPost),
  enabled: !isComparing && needsSkin(appliedPost),
);
```

> 由于 `LumiraImage` 内部持有 `ui.Image`，需在接入时暴露该 `ui.Image` 给 `SkinSmoothPreview`（通过 `LumiraImage` 的回调/预解码）。若直接改它成本高，可行做法：将 `_buildImage` 的图片来源拆成「加载 `ui.Image` → 交给 SkinSmoothPreview 渲染」，以 `image` 包解码路径或现有 `ui.instantiateImageCodec` 复用。

- [ ] **Step 3: 实现接入（执行者按实际 `LumiraImage` 能力确定方案）**

目标：当 `!isComparing && appliedPost.smoothStrength>0` 时，画布渲染为「Shader 磨皮后的图」，且滑块拖动触发 `setState` 即时刷新（`_localPostProcess` 变化已在 `_onPostProcessChanged` 走 `setState`，满足实时）。

- [ ] **Step 4: 验证**

- `flutter analyze` 无新增 error/warning（严重级）。
- 手动：相册修图进入「细节」调磨皮，拖动滑块实时看到磨皮、零卡顿；strength=0 无变化；对比模式仍显示原图。

- [ ] **Step 5: Commit**

```powershell
git add lumira_app_flutter/lib/features/gallery/pages/gallery_edit_page.dart
git commit -m "feat: 相册修图画布接入磨皮实时预览（GPU shader）"
```

---

### Task 3: 拍摄后修图画布接入磨皮实时预览

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/pages/capture_preview_page.dart`（画布渲染处，约 L587-612）

**Interfaces:**
- Consumes: `SkinSmoothPreview`、`needsSkin`/`skinStrength`。
- Produces: 拍摄后修图在 `smoothStrength>0` 时同样走 shader 预览；对比模式仍原图。

- [ ] **Step 1: 阅读现有实现**

`capture_preview_page.dart` `buildImage()`（约 L560-612）返回 `ColorFiltered(colorFilter: fromPostProcess(postProcess))` 包 `Image.file`。

- [ ] **Step 2: 接磨皮层**

与 Task 2 相同手法：把「色彩矩阵」与「磨皮」分层；`smoothStrength>0` 时用 `SkinSmoothPreview` 渲染，缩进保持与现有 `RotatedBox/Transform` 组合兼容。

- [ ] **Step 3: 验证**

- `flutter analyze` 通过。
- 手动：拍摄后修图拖动磨皮滑块实时看到效果、零卡顿；对比模式原图。

- [ ] **Step 4: Commit**

```powershell
git add lumira_app_flutter/lib/features/capture/pages/capture_preview_page.dart
git commit -m "feat: 拍摄后修图画布接入磨皮实时预览（GPU shader）"
```

---

### Task 4: 导出改用同一 shader（WYSIWYG）

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/services/photo_post_processor.dart`（磨皮分支，约 L218-254）

**Interfaces:**
- Consumes: `FragmentProgram` 加载 `shaders/skin_smooth.frag`；`skinStrength`。
- Produces: 导出磨皮从「CPU SkinSmoother」改为「GPU shader 离线渲染」；shader 不可用时降级回 CPU `SkinSmoother`。

- [ ] **Step 1: 阅读现有分支**

`photo_post_processor.dart` 在 `smoothStrength>0` 时做 `toByteData`→`SkinSmoother.smooth`→回灌 `ui.Image`（CPU，且含 GPU 读回）。

- [ ] **Step 2: 改造为 shader 渲染**

```dart
// 替代原 CPU 分支（shader 不可用时捕获并回退 CPU SkinSmoother）
ui.FragmentProgram? prog;
try {
  prog = await ui.FragmentProgram.fromAsset('shaders/skin_smooth.frag');
} catch (_) {
  prog = null;
}
if (prog != null) {
  final w = resultImage.width, h = resultImage.height;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final sh = prog.fragmentShader()
    ..setFloat(0, w.toDouble())
    ..setFloat(1, h.toDouble())
    ..setFloat(2, params.smoothStrength / 100.0)
    ..setImageSampler(0, resultImage); // 索引：float 用 setFloat 独立索引（0,1,2）；sampler 用 setImageSampler 独立索引（0）
  canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..shader = sh);
  final picture = recorder.endRecording();
  final newImage = await picture.toImage(w, h);
  picture.dispose();
  resultImage.dispose();
  resultImage = newImage;
} else {
  // 降级：保留原 CPU SkinSmoother 逻辑（含既有 try/catch）
}
```

- [ ] **Step 3: 验证**

- `flutter analyze` 通过。
- 手动/截图：同一 `smoothStrength` 下，导出图与滑块预览的磨皮观感一致（WYSIWYG）。

- [ ] **Step 4: Commit**

```powershell
git add lumira_app_flutter/lib/features/capture/services/photo_post_processor.dart
git commit -m "feat: 磨皮导出改用同一 GPU shader，实现预览一致"
```

---

### Task 5: 阶段 C 调研与决策（相机实时画面，风险最高）

**Files:**
- 调研：`lumira_app_flutter/ohos/entry/src/main/cpp/photo_processor.cpp`、`camerawesome` 包纹理注入能力、`camera_preview.dart`。

**Interfaces:**
- 不产出代码；产出决策记录与可行性结论（追加到设计文档或本计划报告）。

- [ ] **Step 1: 调研 OHOS 原生侧**

确认 OHOS Flutter 引擎能否对 camera 纹理应用自定义 fragment shader（纹理注入方式；Impeller vs Skia path）。若引擎无 per-texture shader 注入通道，记录结论。

- [ ] **Step 2: 调研 camerawesome 纹理注入**

检查 `packages/camerawesome`/`camerawesome_ohos` 是否暴露「在相机纹理之上挂自定义 shader」的能力（如双层 GPU 合成同类的扩展点）。

- [ ] **Step 3: 结论与回退**

- 若可注入：进入实现设计（另开分计划）。
- 若受阻：采用设计文档已定的回退——「拍摄后修图」覆盖实时场景，不计入本计划交付。
- 将结论写入设计文档状态区。

- [ ] **Step 4: Commit（仅文档）**

```powershell
git add "docs/specs/2026-09-01-skin-smooth-real-time-design.md"
git commit -m "docs: 磨皮相机实时调研结论"
```

---

## Self-Review

- **Spec 覆盖**：阶段 A（Task 1/2/3）、阶段 B（Task 4）、阶段 C 调研（Task 5）、shader 基础设施（Task 0）——全覆盖。
- **占位符**：Task 1 的 `_loadSync` 注明为占位并给出替换指引（异步加载），非“后续再补”式空档；已给执行指令。
- **类型一致**：`skinStrength`/`needsSkin`/`SkinSmoothConfig.fromPostProcess`/`SkinSmoothPreview` 在后续任务中引用名一致。