# 水印功能 V2：模块化 + 沉浸式编辑器 + 白边/拍立得 + 相册二次添加

**日期**: 2026-08-20
**状态**: 已通过设计评审（含可视化确认），待编写实现计划
**评审结论**: 用户确认符合需求、覆盖完整、无决策调整（2026-08-20）；授权直接进入实现计划并以 subagent 执行
**关联文档**:
- V1 设计: `docs/superpowers/specs/2026-08-08-watermark-feature-design.md`
- 现有实现: `lumira_app_flutter/lib/features/capture/watermark/`
- Flutter UI 设计规范: `AGENTS.md`（样式必须跟随设置主题，禁止硬编码/混搭）
- 相册详情页: `lumira_app_flutter/lib/features/gallery/pages/gallery_detail_page.dart`

---

## 一、背景与目标

现有水印功能（V1）存在以下问题，本次整体升级：

1. **样式排版与布局不佳**：管理页列表单调、预览缩略不真实；编辑器参数面板遮挡预览、不够沉浸。
2. **自定义化程度不足**：只能微调已有元素，无法表达"拍立得白边"这类结构化的画框效果；文字只能打在照片上，不能打在白边上。
3. **模块耦合**：水印代码嵌在 `features/capture/watermark/` 下，被拍摄页语义束缚，实际还服务于设置页，宜独立成模块。
4. **缺少相册二次添加**：已拍照片无法再补加水印。

### 1.1 目标（经可视化确认）

| 项 | 内容 |
|---|---|
| 模块化 | 水印独立为 `lib/features/watermark/` 顶层 feature 模块 |
| 数据模型 | 新增**画框（WatermarkFrame）**概念；元素增加**坐标空间（positionSpace）**：照片(默认)/白边 |
| 渲染器 | 支持画框（拍立得白边 / 内描边）、画框投影、元素按坐标空间定位 |
| 编辑器 | 方案 H 定稿：全屏照片预览（等比 contain、宽高比不变、全貌可见）+ **底部可收起操作栏**（三段 Tab：元素/样式/边框），逐元素手势编辑 |
| 管理页 | **单列卡片 + 双列网格可切换**（右上角按钮），选择**持久化**；预览用真实照片效果 |
| 预设 | 保留 5 款并优化 + 新增**「拍立得」**（白边 + 底部白板 + 手写日期）；文字默认打照片、可切到白边 |
| 相册二次添加 | 相册详情页"更多"菜单新增"添加水印"，带真实照片进编辑器，保存后另存新照片 |

### 1.2 范围边界

| 项 | 本次实现 | 不在本次范围 |
|---|---|---|
| 画框 | 拍立得白边（含底部白板）、内描边、投影 | 复杂多框组合 |
| 编辑器 | 逐元素编辑（文本/日期/颜色/字号/透明度/旋转/字间距/对齐/坐标空间）+ 手势（拖拽/双指缩放）+ 画框编辑 | 贴纸/表情/多字体库 |
| 管理页 | 单列/双列切换并持久化、新建/复制/删除自定义 | 模板云同步、模板分享 |
| 相册二次添加 | 详情页"更多"→ 编辑器 → 渲染另存新照片（复用 SaveMode） | 批量添加 |

---

## 二、模块化重构

### 2.1 目录迁移

水印由 `lib/features/capture/watermark/` 整体迁移为独立顶层模块 `lib/features/watermark/`，内部结构不变：

```
lib/features/watermark/
├── models/
│   ├── watermark_template.dart   # 扩展：WatermarkFrame + positionSpace
│   └── watermark_settings.dart   # 扩展：manageLayout
├── data/
│   ├── watermark_providers.dart
│   └── preset_watermarks.dart    # 扩展：+拍立得
├── services/
│   └── watermark_renderer.dart   # 扩展：画框渲染 + 坐标空间
├── pages/
│   ├── watermark_manage_page.dart  # 重做：单列/双列切换
│   └── watermark_editor_page.dart  # 重做：全屏沉浸 + 底部可收起操作栏
└── widgets/
    ├── watermark_preview.dart       # 优化：真实照片预览
    └── watermark_animation_overlay.dart  # 不动（保留）
```

### 2.2 依赖改动

| 文件 | 改动 |
|---|---|
| `lib/features/capture/pages/capture_page.dart` | import 路径改为 `features/watermark/...` |
| `lib/features/profile/pages/profile_settings_page.dart` | import 路径改为 `features/watermark/...` |
| `lib/app/router.dart`、`lib/core/router/route_names.dart` | 路由常量与 import 更新，新增相册添加水印路由 |
| `lib/features/gallery/pages/gallery_detail_page.dart` | 更多菜单新增"添加水印"，跳转带照片的编辑器 |

---

## 三、数据模型扩展

### 3.1 新增画框类型（WatermarkFrame）

```dart
/// 画框类型：none（无画框）/ polaroid（拍立得白边）/ innerBorder（内描边）
enum WatermarkFrameType { none, polaroid, innerBorder }

/// 水印画框：挂在 WatermarkTemplate 上，描述照片四周的边框/白边。
///
/// polaroid：画布向外扩展（照片分辨率不变，四周加白边，底部可加宽白板），
///   整体带投影，经典拍立得观感。
/// innerBorder：画布尺寸与照片一致，沿照片边缘画一圈内描边。
class WatermarkFrame {
  final WatermarkFrameType type;   // 默认 none
  final ui.Color color;            // 白边/描边颜色（拍立得默认白色）
  final double borderRatio;        // 边框厚度 = borderRatio × 照片宽（0~0.2，拍立得默认 ≈0.05）
  final double borderRadius;       // 圆角（相对照片宽的比例，0~0.08）
  final bool bottomPlate;          // 拍立得底部白板开关（默认 true）
  final double bottomRatio;        // 白板高 = bottomRatio × 照片高（默认 ≈0.18）
  final ui.Color shadowColor;      // 投影颜色（默认黑）
  final double shadowOpacity;      // 投影不透明度（0~1）
  final double shadowBlur;         // 投影模糊（相对照片宽的比例）
}
```

### 3.2 元素坐标空间（positionSpace）

```dart
/// 元素定位坐标系：photo（相对照片区域，默认）/ frame（相对画框/白板区域）
enum WatermarkElementSpace { photo, frame }

// WatermarkElement 新增字段
WatermarkElementSpace space;   // 默认 WatermarkElementSpace.photo
```

- `photo`：x/y 为 0~1，相对**照片绘制区域**定位（无画框时即整个画布）。
- `frame`：x/y 为 0~1，相对**画框区域**定位。拍立得下即底部白板区（文字打在白边上）；无画框或内描边时退化为照片区域。
- 拍立得默认把日期元素放到 `frame` 空间（白板区），其余元素在 `photo` 空间。
- `toJson`/`fromJson` 增加 `space` 与 `frame` 字段，旧数据缺省回退：space=photo、frame=none（兼容 V1 已存模板）。

### 3.3 设置扩展（WatermarkSettings）

```dart
/// 管理页布局
enum WatermarkManageLayout { list, grid }

class WatermarkSettings {
  ...
  WatermarkManageLayout manageLayout;  // 默认 list，持久化到 user_settings
}
```

---

## 四、渲染器扩展（watermark_renderer.dart）

### 4.1 画布尺寸计算

```
无画框 / 内描边：outputW = photoW，outputH = photoH
拍立得：        pad   = borderRatio × photoW
                plate = bottomPlate ? bottomRatio × photoH : 0
                outputW = photoW + 2·pad
                outputH = photoH + pad + pad + plate   （上/下各 pad，底部再加 plate）
```

### 4.2 绘制顺序

```
1. 建立画布（尺寸如上），白/透明底
2. 拍立得：先画整块白底（含白板区）→ 画投影（白卡下方阴影）→ 画照片（位于 (pad, pad)）
3. 内描边：画照片 → 沿边缘用 frame.color 画描边（stroke，厚度 = borderRatio×photoW，圆角可选）
4. 元素：按 space 解析基准矩形（photo→照片区 rect；frame→白板区 rect），
   x,y 映射到该 rect，绘制（沿用现有 Paragraph 绘制 + 旋转 + 阴影）
5. 圆角：拍立得/内描边按 borderRadius 裁剪
6. 输出：Picture.toImage → rawRgba（保持现有后处理管线不变）
```

### 4.3 对外接口

```dart
/// 渲染结果：输出 RGBA 字节 + 实际输出尺寸（画框会使输出 ≠ 原图尺寸）
class WatermarkRenderResult {
  final Uint8List rgbaBytes;
  final int width;
  final int height;
}

Future<WatermarkRenderResult> render({
  required ui.Image sourceImage,
  required WatermarkTemplate template,   // 由 elements 改为整个模板（含 frame）
});
```

- 渲染器入口从 `List<WatermarkElement>` 升级为 `WatermarkTemplate`，内部先计算画布再绘制。
- **输出尺寸显式返回**：拍照后处理管线（`capture_page.dart` L679-685）当前用 `workerResult.width/height` 重建图片，画框会使其与实际输出不符——改为用 `result.width/height` 重建（这是本次必须同步修改的点，已核实）。

---

## 五、编辑器重做（方案 H 定稿）

### 5.1 页面结构与状态

`WatermarkEditorPage({ WatermarkTemplate? template, String? photoPath })`

- **双模式**：
  - 模板模式（从管理页进入，`photoPath` 为空）：预览背景用内置示例照片，保存=保存模板。
  - 应用模式（从相册详情"添加水印"进入，`photoPath` 有值）：预览背景=真实照片，保存=渲染并另存新照片。
- 编辑状态：当前正在编辑的模板副本（`List<WatermarkElement> + WatermarkFrame`）、当前选中元素 id、操作栏展开/折叠状态、三段 Tab 状态。

### 5.2 布局（关键铁律）

```
┌─────────────────────────────┐
│  顶部导航：‹取消     标题  保存 │
├─────────────────────────────┤
│                             │
│       预览区（照片 contain）  │
│   • 等比适配，宽高比不变       │
│   • 展开操作栏时自动缩小到     │
│     操作栏上方可用区域，       │
│     全貌始终可见（不裁切）     │
│   • 周围黑色留白 letterbox    │
│                             │
├─────────────────────────────┤
│ 底部操作栏（锚定）            │
│  折叠态：34px 细条「展开 ⌃」  │
│  展开态：≈240px 三 Tab        │
│    [元素] [样式] [边框]       │
└─────────────────────────────┘
```

- 预览区 `BoxFit.contain`，显示高度 = min(可用高度, 按照片宽高比换算高度)，**比例恒等于照片原始比例**。
- 操作栏用 `AnimatedContainer`/`AnimatedSize` 平滑展开折叠；展开时预览区高度同步收缩，`LayoutBuilder` 计算可用高度。
- 颜色/圆角/阴影全部走 `appThemeProvider` + `uiStyleProvider`（遵循 AGENTS.md 规范），不硬编码 iOS 色值；操作栏作为"叠在照片上"的浮层，按当前风格取 `tokens.surface` 半透明 + 细边（新拟态下无外阴影）。

### 5.3 手势编辑（预览区）

- 点选元素 → 高亮 + 选中态（进入"样式"Tab 联动）。
- **单指拖拽** → 更新元素 x/y（相对坐标，越界 clamp）。
- **双指捏合** → 调整字号（相对缩放）。
- 旋转在"样式"Tab 用滑块（避免手势冲突）。

### 5.4 底部操作栏三 Tab

**元素 Tab**
- 已添加元素列表（横向 chip：预览缩略 + 名称），点选切换选中。
- 「＋ 文本」「＋ 日期」添加新元素；选中元素支持「复制」「删除」。

**样式 Tab（针对选中元素）**
- 文本内容输入框（仅 text 类型；dateTime 类型为只读实时日期）。
- 字号滑块、透明度滑块、旋转滑块、字间距滑块。
- 颜色色板（主题色板 + 白/黑常用色）。
- 粗体/斜体 chip、对齐方式（左/中/右）。
- **位置空间切换**：「照片 / 白边」segmented——白边仅当 frame.type=polaroid 且 bottomPlate 开启时可选，默认照片。

**边框 Tab（针对模板）**
- 画框类型 segmented：无 / 拍立得 / 内描边。
- 拍立得：白边厚度滑块、底部白板开关 + 比例滑块、圆角滑块、投影开关/强度。
- 内描边：颜色色板、厚度滑块、圆角。
- 拍立得时预览区照片四周实时出现白边，白板区可放文字（放白边元素）。

### 5.5 保存

- 模板模式：「保存」→ 自定义模板写入 DAO + 更新内存 provider（沿用 V1 逻辑；预设编辑后另存为自定义）。
- 应用模式：「保存并应用」→ 用真实照片 + 当前模板渲染 → 弹出既有 `SaveMode` sheet → 另存新照片（复用 `lumira_save_mode_sheet` 与画廊保存管线）。

---

## 六、管理页重做（watermark_manage_page.dart）

### 6.1 布局与切换

- 顶部导航：标题「水印管理」+ 右侧 `≡`/`▦` 布局切换按钮 +「＋ 新建」。
- **单列卡片**：每个模板横向大卡片——左侧真实照片缩略预览（套水印效果）、中间名称 + 类型标签、右侧选中/编辑/删除。
- **双列网格**：2 列照片墙卡片，选中态用主题色描边，卡下显示名称 + 选中/编辑。
- 切换选择写入 `WatermarkSettings.manageLayout`（经 `scheduleWatermarkPersist` 持久化），进入页面时读取应用。

### 6.2 真实预览

- 新增内置示例照片资源 `assets/images/watermark_sample.jpg`（普通风景/生活照），管理页卡片缩略图与编辑器模板模式预览背景均使用它。
- 缩略图可用渲染器对示例照片预渲染（小尺寸）或直接实时叠加预览组件（`watermark_preview.dart` 优化为"照片底 + 元素叠加"，替代 V1 的灰底模拟）。

### 6.3 操作

- 点击卡片 → 选中为当前使用水印（写 settings + 持久化，返回上一页生效）。
- 「编辑」→ 编辑器（模板模式）。
- 自定义模板支持复制/删除；预设只读不可删。
- 「＋ 新建」→ 以空白模板进入编辑器（含默认文字元素），保存为自定义。

---

## 七、相册二次添加水印

### 7.1 入口

`gallery_detail_page.dart` 的 `_MoreAction` 底部弹层新增菜单项「添加水印」，与现有"保存/编辑"等菜单并列。

### 7.2 流程

```
相册详情「添加水印」
  → WatermarkEditorPage(photoPath: 当前照片, template: 当前选中水印模板)
  → 预览背景 = 真实照片，可拖拽/编辑水印元素
  → 「保存并应用」→ renderer 渲染 → SaveMode sheet → 另存新照片入相册
```

- 新照片沿用当前水印模板（settings.activeTemplateId），用户可在编辑器中实时调整后应用。
- 原照片不被修改（只新增）。

---

## 八、预设更新（preset_watermarks.dart）

保留并优化 5 款（简约日期/胶片印记/艺术签名/杂志排版/画框水印），**新增第 6 款「拍立得」**：

| 属性 | 值 |
|---|---|
| frame | type=polaroid，color=白，borderRatio≈0.05，bottomPlate=true，bottomRatio≈0.18，阴影轻微 |
| 日期元素 | text=`2026.08.08`，space=**frame**（白板区居中，y≈0.5），手写感字体（`Comic Sans MS`/`Segoe Print` 回退系统斜体），深灰 |
| 其余元素 | 无（保持拍立得极简） |

其余 5 款可微调坐标/字号使各分辨率下观感更协调（视觉对照已确认，细节在实现时对齐）。

---

## 九、持久化

| 数据 | 存储 |
|---|---|
| 管理页布局选择 | `user_settings.watermark.manageLayout`（经 settingsDao + `scheduleWatermarkPersist`） |
| 自定义模板（含 frame/space） | `watermark_templates.config` JSON（DAO 序列化升级，兼容旧字段缺省） |
| 当前选中模板 | 不变（settings.activeTemplateId） |

---

## 十、文件清单

| 文件 | 类型 | 说明 |
|---|---|---|
| `lib/features/watermark/`（整目录自 `features/capture/watermark/` 迁移） | 迁移+改 | 独立模块 |
| `lib/features/watermark/models/watermark_template.dart` | 改 | +WatermarkFrame、+WatermarkElementSpace、+space 字段、序列化兼容 |
| `lib/features/watermark/models/watermark_settings.dart` | 改 | +WatermarkManageLayout、+manageLayout |
| `lib/features/watermark/services/watermark_renderer.dart` | 改 | 画框/白板/投影/描边/坐标空间渲染 |
| `lib/features/watermark/data/preset_watermarks.dart` | 改 | +拍立得预设、5 款微调 |
| `lib/features/watermark/data/watermark_providers.dart` | 改 | import 路径、manageLayout 读写 |
| `lib/features/watermark/pages/watermark_manage_page.dart` | 重做 | 单列/双列切换 + 真实预览 + 新建/复制/删除 |
| `lib/features/watermark/pages/watermark_editor_page.dart` | 重做 | 全屏沉浸 + 底部可收起操作栏 + 三 Tab + 双模式 |
| `lib/features/watermark/widgets/watermark_preview.dart` | 改 | 真实照片预览 |
| `assets/images/watermark_sample.jpg` | 新增 | 内置示例照片（用于预览） |
| `lib/features/capture/pages/capture_page.dart` | 改 | import 路径 |
| `lib/features/profile/pages/profile_settings_page.dart` | 改 | import 路径 |
| `lib/features/gallery/pages/gallery_detail_page.dart` | 改 | 更多菜单 +「添加水印」 |
| `lib/app/router.dart`、`lib/core/router/route_names.dart` | 改 | 路由更新/新增 |

---

## 十一、风险与注意

1. **坐标空间默认值**：V1 已有模板无 `space`/`frame`，反序列化必须缺省回退（space=photo、frame=none），避免老用户水印错乱。
2. **拍立得画布变大**：渲染输出尺寸 ≠ 原图尺寸，拍照后处理管线/画廊保存需按返回字节实际尺寸处理，勿假定尺寸不变。
3. **编辑器性能**：预览区实时渲染（拖拽/滑杆）建议节流或用轻量 `CustomPaint` 叠加预览，保存时才走重渲染。
4. **风格规范**：编辑器/管理页全部颜色、圆角、阴影必须走主题 tokens；底部操作栏作为叠图浮层按当前风格取半透明 surface + 细边，禁止跨风格混搭（AGENTS.md）。
