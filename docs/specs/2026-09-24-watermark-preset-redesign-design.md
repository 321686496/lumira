# 内置水印重做：统一坐标布局 + 6 款预置重排 + 日期真实化

- 日期：2026-09-24
- 端：`lumira_app_flutter`（Flutter 3.7.12 / Dart 2.19.6，不支持 Dart 3 语法）
- 预览稿：[watermark-presets-preview-v1.html](../preview/watermark-presets-preview-v1.html)

## 1. 背景与问题

用户反馈原文：

> 优化一下目前项目中的内置水印，目前这些水印的样式都设置的不对，例如拍立得这个内置水印，为什么日期在图片中间的位置？

根因调查后确认这是**一个系统性架构问题**：水印的「画框几何 + 元素坐标」在三处被独立实现，三份实现互不一致。

| 实现 | 文件 | 职责 |
| --- | --- | --- |
| 成片渲染 | `lib/features/watermark/services/watermark_renderer.dart` | 真实合成到照片（正确） |
| 缩略图预览 | `lib/features/watermark/widgets/watermark_preview.dart` | 管理页网格 / 列表缩略图 |
| 编辑页预览 | `lib/features/watermark/pages/watermark_editor_page.dart` | 编辑器内所见即所得 |

### 缺陷清单

**缺陷 A —— 缩略图完全不处理画框（用户看到的症状）**

`_WatermarkPreviewPainter` 只跳过 `image` 类型元素，**完全不处理 `WatermarkFrame`**（不画拍立得白边、不画内描边），且**彻底忽略 `element.space`**，一律以整个预览矩形为基准：

```
anchorY = element.y * size.height
```

拍立得日期元素是 `x: 0.5, y: 0.5, space: frame`，于是落到缩略图**垂直正中** —— 这就是用户看到的「日期在图片中间」。

**缺陷 B —— 编辑页 frame 基准矩形算错**

`watermark_editor_page.dart` 的 `_baseRectFor` 在 `space == frame && polaroid && bottomPlate` 时返回：

```dart
Rect.fromLTRB(photoRect.left, photoRect.top,
              photoRect.right, photoRect.bottom + plateH)   // 高 = 1.18 × 照片高
```

正确基准应是**底部白板矩形**（高 = `padBottom`），而非「照片 + 白板」的并集。导致编辑页日期比成片高出约 0.5 × 照片高，**编辑器不 WYSIWYG**。

同文件 `_buildElementOverlay` 的垂直偏移用 `-fontSize`，而渲染器用 `-实际行高 × 0.85`，**永远对不齐**。

**缺陷 C —— 成片白板基准矩形左移**

`watermark_renderer.dart` 中：

```dart
final plateRect = ... ui.Rect.fromLTWH(padLeft, photoRect.bottom, photoW + padLeft + padRight, padBottom);
```

宽度已是整卡宽，但 `left` 取了 `padLeft`，于是 `x: 0.5` 的白板内元素被整体右移 `padLeft`，**拍立得日期不居中**。（预览 Section A 的「现状成片」复现了这一点。）

**缺陷 D —— `dateTime` 元素从不解析真实日期**

`WatermarkElementType.dateTime` 已存在，但渲染器把它当普通文本按 `element.text` 字面量绘制；编辑器 `_addElement` 也写死 `'2026.08.20'`。所有预置水印的日期都是硬编码字符串。

**缺陷 E —— 画框水印用 `┌┐└┘` 字符拼角**

`preset_watermarks.dart` 的 `_frameBorder` 用四个角字符画框。上角 `y: 0.04` 经 `offsetY = -0.85 × 行高` 后顶出画布上沿被裁切，下角 `y: 0.94` 又离底边过远，**框上下不对称且四角残缺**。

**缺陷 F —— 文字阴影不随尺寸缩放，亮底白字消失**

`blurRadius = (absoluteFontSize * 0.08).clamp(0.5, 8.0)` 的 8px 上限在 3000×4000 的成片上几乎不可见；缩略图侧 `(element.fontSize * size.width).clamp(7.0, size.width * 0.18)` 的夹取又做在**卡片坐标系**上，小尺寸下会把文字放大到互相重叠。

## 2. 目标 / 非目标

**目标**

1. 抽出**唯一**的画框几何 + 元素坐标布局函数，成片 / 缩略图 / 编辑页三者共用。
2. 缩略图补上画框绘制（白边 + 白板 + 内描边），并遵守 `element.space`。
3. 编辑页与成片完全 WYSIWYG。
4. `dateTime` 元素按**照片真实拍摄日期**渲染；预置 6 款与用户自定义模板中选日期的元素一律生效。
5. 重做 6 款预置水印的排版参数（名称与风格定位不变）。
6. 文字可读性：新增深色描边能力，亮底白字可读，**不加底色块**。

**非目标**

- 不新增/删除预置款数（仍是 6 款）。
- 不改水印管理页、拍摄流程的交互。
- 不改后端与后台（水印为纯端上功能）。
- 不引入 `dart:ui` 之外的渲染依赖。

## 3. 架构：统一布局层

新增 `lib/features/watermark/services/watermark_layout.dart`，作为画框几何与元素坐标的**唯一真源**。

### 3.1 `WatermarkLayout` —— 画框几何

```dart
class WatermarkLayout {
  final ui.Rect cardRect;    // 整个输出画布
  final ui.Rect photoRect;   // 照片区域
  final ui.Rect plateRect;   // 元素 space==frame 的基准矩形
  final double padLeft, padTop, padRight, padBottom;

  factory WatermarkLayout.compute({
    required double photoW,
    required double photoH,
    required WatermarkFrame frame,
  });

  ui.Rect baseFor(WatermarkElementSpace space);
  int get outputWidth;   // cardRect.width.round()
  int get outputHeight;  // cardRect.height.round()
}
```

计算规则（与既有渲染器一致，仅修正 `plateRect.left`）：

| 量 | 公式 |
| --- | --- |
| `padLeft/Right/Top` | `frame.borderX × photoW`（仅 polaroid，否则 0） |
| `padBottom` | `frame.borderBottom × photoW + (bottomPlate ? bottomRatio × photoH : 0)` |
| `photoRect` | `(padLeft, padTop, photoW, photoH)` |
| `cardRect` | `(0, 0, photoW + padLeft + padRight, photoH + padTop + padBottom)` |
| `plateRect` | polaroid 且 `bottomPlate` → `(0, photoRect.bottom, cardRect.width, padBottom)`；**否则 → `photoRect`** |

`plateRect.left = 0`（而非 `padLeft`）是本设计对缺陷 C 的修正；`plateRect.w = cardRect.width` 保持不变。

`baseFor(space)`：`space == frame` → `plateRect`，否则 → `photoRect`。因 `plateRect` 在非拍立得/无白板时回退为 `photoRect`，调用方无需再判空。

### 3.2 `WatermarkElementMetrics` —— 元素→绝对量换算

同文件：

```dart
class WatermarkElementMetrics {
  final double fontSize;        // element.fontSize × base.width
  final double letterSpacing;   // element.letterSpacing × (base.width / 400)
  final ui.Color color;         // alpha × element.opacity
  final List<ui.Shadow> shadows;
  final FontWeight fontWeight;
  final FontStyle fontStyle;
  final String? fontFamily;

  factory WatermarkElementMetrics.of(WatermarkElement e, double baseWidth);
}
```

阴影规则（**这是缺陷 F 的修正**）：

- `k = baseWidth / 400`（参考宽度归一化系数）
- 描边：`element.shadowOutline > 0` 且 `shadowColor` 有 alpha 时，生成 **8 个零模糊 `ui.Shadow`**，偏移为 `(±o, 0) (0, ±o) (±o, ±o)`，其中 `o = fontSize × shadowOutline`，颜色 alpha = `shadowColor.alpha × element.opacity`。
- 光晕：`blur = (fontSize × element.shadowBlur).clamp(0.5 × k, 8.0 × k)`，单个 Shadow，`offset = (blur × 0.4, blur × 0.4)`，颜色 alpha = `shadowColor.alpha × element.opacity × 0.75`。
- `shadowBlur` 默认 `0.08`、夹取上下限按 `k` 缩放后，**与旧实现逐像素一致**；`shadowOutline` 默认 `0`（不描边）。

> 用 8 向零模糊 Shadow 而非 `PaintingStyle.stroke`，原因：`canvas.drawParagraph` 无法用 stroke Paint 绘制段落。

### 3.3 `WatermarkTextPlacement` —— 锚点与偏移

```dart
class WatermarkTextPlacement {
  final double anchorX, anchorY, offsetX, offsetY;
  factory WatermarkTextPlacement.compute({
    required WatermarkElement element,
    required ui.Rect base,
    required double textWidth,
    required double textHeight,
  });
}
```

- `anchorX = element.x × base.width + base.left`
- `anchorY = element.y × base.height + base.top`
- `offsetX`：`left` → `0`；`center` → `-textWidth / 2`；`right` → `-textWidth`
- `offsetY = -textHeight × 0.85`

绘制顺序统一为 `translate(anchorX, anchorY)` → `rotate(element.rotation)` → `translate(offsetX, offsetY)` → 绘制文字。

### 3.4 消费方改造

| 消费方 | 改造 |
| --- | --- |
| `WatermarkRenderer.render` | 用 `WatermarkLayout.compute`、`WatermarkElementMetrics.of`、`WatermarkTextPlacement.compute` 替换内联计算。新增可选参数 `DateTime? captureDate`。 |
| `_WatermarkPreviewPainter.paint` | 按 `WatermarkLayout` **实际绘制**卡片底色（拍立得白卡，含 `borderRadius` / 渐变）、照片、内描边，再用统一换算绘制文字。几何按 `WatermarkLayout.cardRect` 等比缩放（`k = min(width / cardRect.width, height / cardRect.height)`）后居中绘制：`background` 图片绘制进 `photoRect`（`BoxFit.cover`），卡片底色铺满 `cardRect`；`frame == none` 时 `photoRect == cardRect`，与现状一致。字号夹取改为**在显示像素上做**：`显示宽 = cardRect.width × k`，`fs = clamp(fs × k, 5, 显示宽 × 0.16) / k`。 |
| `watermark_editor_page.dart` | 删除 `_baseRectFor`，改用 `WatermarkLayout`；`_buildElementOverlay` 改用 `WatermarkElementMetrics` + 用 `TextPainter`（同字号/字距/字重/字体）测量后按 `WatermarkTextPlacement` 定位；`_buildPolaroidPreview` 的白边/白板几何改用 `WatermarkLayout`。 |

## 4. 数据模型变更

`lib/features/watermark/models/watermark_template.dart`：

`WatermarkElement` 新增两个字段：

| 字段 | 类型 | 默认 | 含义 |
| --- | --- | --- | --- |
| `shadowOutline` | `double` | `0.0` | 深色描边宽度 = 值 × 绝对字号（0 = 关闭），颜色取 `shadowColor` |
| `shadowBlur` | `double` | `0.08` | 柔光晕半径 = 值 × 绝对字号 |

两者都要补齐 `构造函数默认值` / `copyWith` / `toJson` / `fromJson`（缺省回落默认值，保证旧模板 JSON 反序列化后视觉不回退）。

`WatermarkFrame` **不改字段**。既有 `shadowColor/shadowOpacity/shadowBlur` 仅用于编辑页屏幕上的卡片投影，不参与成片（当前 `render()` 有注释明确说明「不把投影烘焙进输出图像」）。

## 5. `dateTime` 真实日期

### 5.1 契约

`WatermarkRenderer.render` 新增可选参数：

```dart
Future<WatermarkRenderResult> render({
  required ui.Image sourceImage,
  required WatermarkTemplate template,
  DateTime? captureDate,          // 照片真实拍摄时间；null 时用 DateTime.now()
});
```

渲染器保持**无 context 的纯函数**：它不读文件、不碰 `dart:io`，日期由调用方注入。

- 元素 `type == text` / `image` → 用 `element.text`。
- 元素 `type == dateTime` → **忽略 `element.text`**，用 `captureDate ?? DateTime.now()` 格式化。

格式化函数（`watermark_layout.dart` 或模型文件内）：

```dart
String formatWatermarkDate(DateTime d);   // → '2026.08.08'（零填充 yyyy.MM.dd）
```

### 5.2 调用方取日期

两处调用点都持有照片路径，先用既有的 `lib/features/capture/services/photo_exif_reader.dart` 读 EXIF：

1. `lib/features/capture/pages/capture_page.dart:1573` —— 成片合成（后处理管线）
2. `lib/features/watermark/widgets/watermark_animation_overlay.dart:204` —— 定格动画

`PhotoExifReader.read(path, timestamp: ...)` 返回的 `ExifInfo.timestamp` 是 EXIF `DateTime` 原始字符串，格式 `"YYYY:MM:DD HH:MM:SS"`。取前 10 个字符，把 `:` 换成 `-` 后交给 `DateTime.tryParse`；解析失败 → 传 `null`（渲染器回退 `DateTime.now()`）。拍摄流程本身持有的快门时间戳可作为 `timestamp:` 兜底传入。

> 该步骤需要 `dart:io` + JPEG 解码，放在各处现有异步管线内，**不阻塞 UI 线程**；读取失败一律静默回退，绝不阻断出片。

### 5.3 编辑器侧

`watermark_editor_page.dart` 的 `_addElement` 创建 `dateTime` 元素时不再写死 `'2026.08.20'`，`text` 留空。编辑器内（无照片、无 EXIF）以**当天日期**展示；管理页缩略图同理。

## 6. 预置 6 款重做参数

文件：`lib/features/watermark/data/preset_watermarks.dart`。所有日期元素 `type` 改为 `WatermarkElementType.dateTime`（缺陷 D）。

下表中 `text` 列里写日期的元素即 `dateTime` 类型，其余为 `text` 类型。底色照片基准 900×1200 竖构图。

### 01 `preset_minimal_date` 简约日期

左下角单列，日期为主视觉、品牌为辅。`frame: WatermarkFrame()`（none）。

| 类型 | 文本 | x | y | fontSize | 其他 |
| --- | --- | --- | --- | --- | --- |
| dateTime | — | 0.06 | 0.914 | 0.045 | `bold`，`align: left` |
| text | `LUMIRA` | 0.06 | 0.962 | 0.023 | `letterSpacing: 6.0`，`opacity: 0.80`，`align: left` |

去掉原 `——` 分隔行。

### 02 `preset_film_stamp` 胶片印记

右下角，琥珀色日期模拟胶片打印机等宽走纸。`frame: none`。

| 类型 | 文本 | x | y | fontSize | 其他 |
| --- | --- | --- | --- | --- | --- |
| dateTime | — | 0.94 | 0.912 | 0.036 | `bold`，`letterSpacing: 3.5`，`align: right`，`color: 0xFFF0B45A` |
| text | `LUMIRA` | 0.94 | 0.955 | 0.018 | `letterSpacing: 5.0`，`opacity: 0.82`，`align: right` |

把原来的设备型号行 `iPhone 15 Pro` 换成品牌行。

### 03 `preset_art_signature` 艺术签名

右下角衬线斜体签名 + 小字距日期，整体微倾 `-0.05 rad`。`frame: none`。

| 类型 | 文本 | x | y | fontSize | 其他 |
| --- | --- | --- | --- | --- | --- |
| text | `Lumira` | 0.93 | 0.905 | 0.050 | `italic`，`fontFamily: 'serif'`，`rotation: -0.05`，`opacity: 0.95`，`align: right` |
| dateTime | — | 0.93 | 0.945 | 0.017 | `letterSpacing: 3.5`，`rotation: -0.05`，`opacity: 0.72`，`align: right` |

去掉原来那个孤立的 `●` 元素。

### 04 `preset_magazine_layout` 杂志排版

**改为左上刊头**（原「底部三行居中」与简约日期在版面上重复）。`frame: none`。

| 类型 | 文本 | x | y | fontSize | 其他 |
| --- | --- | --- | --- | --- | --- |
| text | `LUMIRA` | 0.06 | 0.055 | 0.022 | `letterSpacing: 9.0`，`opacity: 0.92`，`align: left` |
| dateTime | — | 0.06 | 0.095 | 0.017 | `letterSpacing: 3.0`，`opacity: 0.70`，`align: left` |

原三行合并文案 `2026.08.08 · MOMENT · LUMIRA` 与两条 `——` 全部移除。

### 05 `preset_frame_border` 画框水印

**改用真正的内描边画框**（弃用 `┌┐└┘` 字符拼角，解决缺陷 E）。

```dart
frame: WatermarkFrame(
  type: WatermarkFrameType.innerBorder,
  borderRatio: 0.012,
  borderRadius: 0.0,
  color: Color(0xE6FFFFFF),   // 白 90%
)
```

| 类型 | 文本 | x | y | fontSize | 其他 |
| --- | --- | --- | --- | --- | --- |
| dateTime | — | 0.5 | 0.947 | 0.026 | `letterSpacing: 3.0`，`opacity: 0.95`，`align: center` |

原 `LUMIRA | 2026.08.08` 合并行拆为纯日期，品牌由画框本身承担。

### 06 `preset_polaroid` 拍立得

几何与 `frame` 保持不变（`borderTop/Right/Bottom/Left: 0.05`、`bottomPlate: true`、`bottomRatio: 0.18`、`color: 0xFFFFFFFF`、`borderRadius: 0`）——白边永远不画字，所以改的是基准矩形与元素参数：

| 类型 | 文本 | x | y | fontSize | 其他 |
| --- | --- | --- | --- | --- | --- |
| dateTime | — | 0.5 | 0.54 | 0.035 | `space: frame`，`italic`，`fontFamily: 'serif'`，`align: center`，`color: 0xFF3D3D3D`，`shadowColor: 0x00000000`（即不描边不发光） |

`space: frame` 使基准矩形为 `plateRect`（整卡宽、高 `padBottom`），`x: 0.5` 因缺陷 C 修正后真正居中。深灰字落在纯白板上，可读性由底板本身提供，故不挂任何阴影。

### 通用

6 款中所有**叠在照片上的白色/琥珀色文字**统一：

```dart
shadowColor: Color(0xFF000000),  // 不透明黑：描边与光晕的实际强度 = 元素 opacity
shadowOutline: 0.07,   // 深色描边，亮底白字立起来（用户选定方案，不加底色块）
shadowBlur: 0.45,      // 柔光晕，暗底不发虚
```

拍立得白板内文字除外（`shadowColor: 0x00000000` → 即 `shadowOutline: 0`、`shadowBlur: 0`）。

## 7. 测试

现有测试文件（需同步更新，不得只改生产代码）：

- `test/features/watermark/watermark_renderer_test.dart` —— 输出尺寸断言；新增 `plateRect` 居中、`captureDate` 生效、`shadowOutline` 生成 8 个零模糊阴影的断言。
- `test/features/watermark/preset_watermarks_test.dart` —— 6 款 / id 唯一；新增：日期元素均为 `dateTime`、画框水印 frame 为 `innerBorder`、不存在 `┌┐└┘` 字符。
- `test/features/watermark/watermark_model_test.dart` —— 新增 `shadowOutline` / `shadowBlur` 的 `toJson`/`fromJson`/`copyWith` 与缺省回落。
- `test/features/watermark/watermark_editor_page_test.dart` —— 编辑页不再出现写死日期。

新增测试：

- `watermark_layout_test.dart` —— 纯函数，覆盖 polaroid（有/无 bottomPlate）、innerBorder、none 三种 frame 的 `cardRect/photoRect/plateRect`；`baseFor` 回退；`formatWatermarkDate` 零填充。
- 缩略图 painter 的 golden 或几何断言：拍立得缩略图中日期元素落在白板区域内（回归缺陷 A）。

验证命令：

```
cd lumira_app_flutter
flutter analyze
flutter test
```

## 8. 影响面与风险

| 项 | 说明 |
| --- | --- |
| **存量自定义水印** | 使用 `space: frame` 的元素在拍立得模板下会**左移 `padLeft`** —— 这是缺陷 C 的修正，属预期变更。JSON 反序列化向后兼容，无需数据迁移。 |
| **存量自定义水印阴影** | 新字段缺省值与旧行为一致，视觉不回退。 |
| **成片输出尺寸** | 不变（`cardRect` 与旧的 `outputW/outputH` 公式逐项相同）。 |
| **性能** | 描边把单元素绘制从 1 次增至 9 次文字绘制。仅对短文本（日期/品牌行）生效，元素数量 ≤ 2，成片耗时增量可忽略；缩略图为 `CustomPaint`，管理页同屏项数有限。 |
| **EXIF 读取开销** | 每次出片多一次 JPEG 解码读 EXIF。既有后处理管线已在读同一文件，读取失败静默回退。 |
| **平台** | 纯 `dart:ui` + `dart:io`，iOS / Android / HarmonyOS 一致；无新增依赖。 |
| **部署** | Flutter 仅 CI 验证，不自动部署，需下次发版生效。 |

## 9. 未决 / 已明确排除

- **已排除**：文字下方加半透明暗色衬底（用户明确选择「加强深色描边，不加底色块」）。
- **已排除**：把卡片投影烘焙进成片（会造成白边下方灰线，维持现状）。
- **已排除**：改预置款数、改水印管理页交互、改后端。