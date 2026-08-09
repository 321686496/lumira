# 水印功能 + 拍照相框动画

**日期**: 2026-08-08
**状态**: 已通过设计评审，待编写实现计划
**关联文档**:
- 拍摄页: `docs/superpowers/specs/2026-07-21-capture-page-full-features-design.md`
- 拍摄页增强: `docs/superpowers/specs/2026-07-14-capture-page-enhancement-design.md`
- 设置页: 当前项目 `ProfileSettingsPage`

---

## 一、背景与目标

### 1.1 需求

为 App 添加水印功能，包含：
1. 一套精美的预设水印样式（5种）
2. 水印管理页面，可查看、选择、编辑预设水印参数
3. 水印编辑器，基于预设模板可调整文字内容、位置、颜色等
4. 拍照时水印渲染到最终照片上
5. 拍照相框动画：按下快门后照片定格，水印动画套上，然后照片缩小飞入左下角相册图标
6. 设置项：水印开关、水印动画开关

### 1.2 范围边界

| 项 | 本次实现 | 不在本次范围 |
|---|---|---|
| 水印样式 | 5种预设风格 + 基于预设的参数编辑（文字、位置、颜色、大小） | 从零开始的自定义水印编辑器 |
| 水印渲染 | 合成到照片 JPEG 中（dart:ui Canvas 绘制） | 视频水印、批量水印 |
| 动画 | 拍照后相框动画（水印渐入 → 缩小飞入相册） | 编辑水印时的实时预览动画 |
| 设置 | 水印开关、水印动画开关、水印管理入口 | 水印云同步、水印分享 |

---

## 二、整体架构

```
┌─────────────────────────────────────────────────┐
│                    UI 层                          │
│  WatermarkManagePage  WatermarkEditorPage        │
│  设置项（水印开关/动画开关）  相框动画 Overlay     │
└──────────────────────┬──────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────┐
│                 业务逻辑层                        │
│  WatermarkService（管理/CRUD）                    │
│  WatermarkRenderer（渲染到图片）                   │
│  WatermarkAnimator（相框动画控制）                 │
└──────────────────────┬──────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────┐
│                 数据层                            │
│  WatermarkTemplate（模型）                        │
│  WatermarkDao（SQLite 持久化）                    │
│  预设数据（代码内置）                              │
└─────────────────────────────────────────────────┘
```

### 2.1 模块依赖关系

```
WatermarkManagePage
  └─ WatermarkDao (读取/保存模板)
  └─ WatermarkService (应用/取消选中)

WatermarkEditorPage
  └─ WatermarkDao (保存编辑后的模板)
  └─ WatermarkTemplate (编辑模型)

CapturePage
  └─ WatermarkService (获取当前选中模板)
  └─ WatermarkRenderer (后处理管线中渲染水印)
  └─ WatermarkAnimationOverlay (相框动画)

ProfileSettingsPage
  └─ WatermarkSettings (开关状态)
```

---

## 三、数据模型

### 3.1 WatermarkTemplate

```dart
// 水印模板类型
enum WatermarkTemplateType { preset, custom }

// 水印元素类型
enum WatermarkElementType { text, dateTime, image }

// 水印元素
class WatermarkElement {
  final String id;
  WatermarkElementType type;
  String text;           // 文字内容（如 "Lumira"、"2026.08.08"）
  double x;              // 相对位置 X (0.0 ~ 1.0)
  double y;              // 相对位置 Y (0.0 ~ 1.0)
  double fontSize;       // 字体大小（相对值）
  Color color;           // 文字颜色
  Color shadowColor;     // 阴影颜色
  double opacity;        // 不透明度
  double rotation;       // 旋转角度（弧度）
  String fontFamily;     // 字体
  TextAlign textAlign;   // 对齐方式
  bool bold;             // 是否加粗
  bool italic;           // 是否斜体
}

// 水印模板
class WatermarkTemplate {
  final String id;
  String name;
  WatermarkTemplateType type;
  List<WatermarkElement> elements;
  DateTime createdAt;
}
```

### 3.2 WatermarkSettings

```dart
class WatermarkSettings {
  bool enabled;           // 是否启用拍照水印
  String? activeTemplateId; // 当前选中的水印模板 ID
  bool animationEnabled;  // 是否启用相框动画
}
```

### 3.3 数据库表

```sql
CREATE TABLE watermark_templates (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'preset',  -- 'preset' | 'custom'
  config TEXT NOT NULL,       -- JSON: 含 elements 列表
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

设置项持久化到现有的 `user_settings` 表，使用 JSON 字段存储。

---

## 四、预设水印样式（5种）

### 4.1 简约日期（Minimal Date）

| 属性 | 值 |
|------|-----|
| 位置 | 左下角，距边缘 5% |
| 元素 | 两行文字 |
| 内容 | 行1: `2026.08.08`（日期，小号字体）；行2: `LUMIRA`（品牌名，稍大） |
| 样式 | 白色，80% 不透明度，无背景，无阴影 |
| 装饰 | 两行之间一条短横线分隔 |

### 4.2 胶片印记（Film Stamp）

| 属性 | 值 |
|------|-----|
| 位置 | 右下角 |
| 元素 | 半透明色块背景 + 文字 |
| 内容 | 行1: `2026.08.08`；行2: `iPhone 15 Pro`（设备型号） |
| 样式 | 黑色半透明背景块（圆角 4px, 85% 不透明度），白色文字 |
| 装饰 | 色块左侧有 2px 宽的 accent 竖条 |

### 4.3 艺术签名（Art Signature）

| 属性 | 值 |
|------|-----|
| 位置 | 右下角 |
| 元素 | 单个文字元素 |
| 内容 | `© Lumira` |
| 样式 | 手写风格字体，40% 不透明度，白色，微旋转 -5° |
| 装饰 | 文字前有一个小圆点装饰 |

### 4.4 杂志排版（Magazine Layout）

| 属性 | 值 |
|------|-----|
| 位置 | 底部居中 |
| 元素 | 通栏文字条 |
| 内容 | `2026.08.08  ·  MOMENT  ·  LUMIRA` |
| 样式 | 白色文字，60% 不透明度，居中对齐，字母间距宽松 |
| 装饰 | 文字两侧有细横线装饰 |

### 4.5 画框水印（Frame Border）

| 属性 | 值 |
|------|-----|
| 位置 | 四角 + 底部居中 |
| 元素 | 四角装饰线 + 底部文字 |
| 内容 | 底部: `LUMIRA  |  2026.08.08` |
| 样式 | 白色细线（1px）在四角，白色文字底部居中 |
| 装饰 | 四角 L 型线框（线长 40px），底部文字下方有微横线 |

---

## 五、水印管理页面

### 5.1 WatermarkManagePage

**布局：**
- 顶部导航栏：标题"水印管理"
- 主体：水印模板列表（纵向列表，每个卡片横跨全宽）
- 每个卡片：
  - 左侧：水印样式预览缩略图（在灰色背景上模拟水印效果）
  - 中部：水印名称 + 类型标签（预设/自定义）
  - 右侧：选中状态（勾选图标）或编辑按钮
- 底部：固定按钮"创建自定义水印"

**交互：**
- 点击卡片 → 选中该水印为当前使用（返回上一页并生效）
- 点击"编辑"按钮 → 进入 WatermarkEditorPage
- 预设模板不可删除，自定义模板可左滑删除
- 自动保存：选中后立即写入 WatermarkSettings

### 5.2 WatermarkEditorPage

**布局：**
- 顶部导航栏：标题"编辑水印" + 保存按钮
- 中间：预览区域（在模拟照片上实时显示水印效果）
- 下方：参数编辑面板，分 Tab 或列表形式：
  - **文字内容**：编辑每个文字元素的文本
  - **位置**：拖动滑块调整 X/Y 偏移（或拖拽预览中的元素）
  - **样式**：颜色选择器、透明度滑块、大小滑块、旋转角度
  - **字体**：字体选择（系统内置字体）

**交互：**
- 预览区域实时更新
- 点击"保存" → 保存为自定义模板 / 覆盖预设的参数副本
- 预设模板编辑后保存为新的自定义模板（不修改原始预设）

---

## 六、水印渲染管线

### 6.1 合成时机

水印渲染集成到拍照后处理管线中，位于 CPU 处理之后、JPEG 编码之前：

```
拍照 → 解码JPEG → GPU色彩矩阵 → CPU锐化/磨皮/暗角
                                      ↓
                               [NEW] 水印合成
                                      ↓
                                 JPEG编码保存
```

### 6.2 渲染实现

使用 `dart:ui Canvas` 在原始图片的 `Image` 上绘制水印元素：

```dart
Future<Uint8List> renderWatermark({
  required ui.Image sourceImage,
  required List<WatermarkElement> elements,
  required ImageFormat outputFormat,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(sourceImage.width.toDouble(), sourceImage.height.toDouble());

  // 1. 绘制原始图片
  canvas.drawImage(sourceImage, Offset.zero, Paint());

  // 2. 遍历水印元素，逐个绘制到 Canvas 上
  for (final element in elements) {
    _drawElement(canvas, element, size);
  }

  // 3. 导出为图片
  final picture = recorder.endRecording();
  final img = await picture.toImage(size.width.toInt(), size.height.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  return byteData!.buffer.asUint8List();
}
```

### 6.3 位置映射

水印元素使用相对坐标（0.0~1.0），渲染时按实际图片尺寸缩放：

```dart
Offset resolvePosition(WatermarkElement element, Size imageSize) {
  return Offset(
    element.x * imageSize.width,
    element.y * imageSize.height,
  );
}
```

---

## 七、相框动画

### 7.1 触发条件

- 用户按下快门后
- 设置中"水印动画"开启
- 水印功能开启且当前有水印模板选中

### 7.2 动画流程（多阶段 AnimationController）

```
Phase 1 (0~300ms): 照片定格全屏
  - 取景器中的画面快速淡出
  - 处理后的照片从透明到不透明全屏显示
  - 曲线: easeOut

Phase 2 (300~900ms): 水印元素渐入
  - 水印元素依次出现（每个间隔 100ms）
  - 每个元素: scale(0.8→1.0) + opacity(0→1) + 轻微上移
  - 曲线: easeOutBack（弹性效果）

Phase 3 (900~1500ms): 停顿展示
  - 照片 + 水印完整展示约 600ms
  - 用户可看到带水印的最终效果

Phase 4 (1500~1900ms): 缩小飞入相册
  - 照片从全屏位置缩小到 48x48
  - 同时移动到左下角 CaptureThumbnail 的位置
  - 曲线: easeInCubic（加速）
  - 带轻微的旋转效果（2°→0°）

Phase 5 (1900ms): 完成
  - 动画 Overlay 消失
  - 缩略图更新为最终照片
  - 恢复拍摄界面
```

### 7.3 实现方式

```dart
class WatermarkAnimationOverlay extends StatefulWidget {
  // 参数: 照片路径, 水印模板, 动画结束回调
}

// 使用 Matrix4 进行变换，结合 AnimatedBuilder 实现流畅动画
// 动画结束时通过回调通知 CapturePage 更新缩略图并移除 Overlay
```

### 7.4 位置映射

左下角相册图标的位置通过 `GlobalKey` 获取，确保动画终点准确：

```dart
// CapturePage 中给 CaptureThumbnail 设置 GlobalKey
final _thumbnailKey = GlobalKey();

// 动画 Overlay 获取该位置作为终点
final renderBox = _thumbnailKey.currentContext?.findRenderObject() as RenderBox?;
final position = renderBox?.localToGlobal(Offset.zero);
```

---

## 八、设置项

### 8.1 设置页改动

在 `ProfileSettingsPage` 的"拍摄"区域，扩展水印设置：

```
[拍摄] 区域
  ├── 默认分辨率          → 4:3 (保持不变)
  ├── 水印                → Toggle 开关 (控制水印功能的启用/停用)
  ├── 水印样式            → 点击跳转 WatermarkManagePage (显示当前选中的水印名称)
  ├── 水印动画            → Toggle 开关 (控制是否有相框动画)
  └── 快门声音            → Toggle 开关 (保持不变)
```

### 8.2 持久化

水印设置持久化到 `user_settings` 表：

```json
{
  "watermark": {
    "enabled": true,
    "activeTemplateId": "minimal_date",
    "animationEnabled": true
  }
}
```

---

## 九、路由

新增路由：

| 路由路径 | 页面 | 说明 |
|---------|------|------|
| `/profile/settings/watermark` | WatermarkManagePage | 水印管理列表 |
| `/profile/settings/watermark/edit` | WatermarkEditorPage | 水印编辑器（?templateId=xxx） |

---

## 十、文件清单

| 文件 | 类型 | 说明 |
|------|------|------|
| `lib/features/capture/watermark/models/watermark_template.dart` | 新增 | 数据模型定义 |
| `lib/features/capture/watermark/models/watermark_settings.dart` | 新增 | 设置模型 |
| `lib/features/capture/watermark/data/preset_watermarks.dart` | 新增 | 5种预设水印数据 |
| `lib/features/capture/watermark/services/watermark_service.dart` | 新增 | 水印管理服务 |
| `lib/features/capture/watermark/services/watermark_renderer.dart` | 新增 | 水印渲染器 |
| `lib/features/capture/watermark/pages/watermark_manage_page.dart` | 新增 | 水印管理页 |
| `lib/features/capture/watermark/pages/watermark_editor_page.dart` | 新增 | 水印编辑器 |
| `lib/features/capture/watermark/widgets/watermark_preview.dart` | 新增 | 水印预览组件 |
| `lib/features/capture/watermark/widgets/watermark_animation_overlay.dart` | 新增 | 相框动画 Overlay |
| `lib/core/db/dao/watermark_dao.dart` | 新增 | 水印 DAO |
| `lib/core/db/tables.dart` | 修改 | 新增 watermark_templates 表 |
| `lib/features/capture/pages/capture_page.dart` | 修改 | 集成水印渲染 + 动画 |
| `lib/features/profile/pages/profile_settings_page.dart` | 修改 | 增加水印设置项 |
| `lib/app/router.dart` | 修改 | 新增路由 |
| `lib/core/router/route_names.dart` | 修改 | 新增路由常量 |