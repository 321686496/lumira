# 模板卡片封面自适应高度 + 瀑布流统一设计

> 日期：2026-08-29
> 状态：已确认（方案 A），待转入实施计划
> 相关前置：2026-08-22-template-display-optimization-design.md（卡片已含 shortDesc/ambience/使用次数，本轮只改封面展示与网格布局，不动这些已有字段）
> 技术参考：`photo_crop_layer.dart` 已有 `ImageStream.resolve` 取图片真实宽高的先例

## 1. 背景与目标

当前三处模板卡片的封面都用了**固定宽高比 + `BoxFit.cover`**，导致不同比例（尤其 9:16 长屏）的封面被裁切、展示不完整；同时发现页「更多模板」仍是固定行高的 2 列网格，与搜索页、模板库的瀑布流不一致。目标：

1. **模板封面完全展示**：宽度 100%，高度按封面真实比例自适应；9:16 长屏**温和削减**高度（最低展示比例 0.65），避免卡片过长。
2. **所有模板卡片网格统一为瀑布流双列**：发现页「更多模板」由固定 GridView 改为瀑布流（搜索页、模板库已是瀑布流，仅改封面）。

## 2. 现状分析

| 页面 | 卡片组件 | 封面当前实现 | 网格布局 |
|---|---|---|---|
| 发现页「更多模板」 | `TemplateGridCard`（template_grid_card.dart `_GridImage`） | 固定 `AspectRatio 1:1` + `BoxFit.cover` | `GridView` 固定 `childAspectRatio: 0.70`（非瀑布流） |
| 搜索页 | `SearchResultCard`（search_result_card.dart `_imageStack`） | 模板/场景固定 `3:4`、美学院固定 `4:3` | 已是瀑布流（global_search_page.dart `_buildWaterfallView`） |
| 模板库（全部模板页） | `_TplCard`（templates_all_page.dart `_TemplateGrid`） | 固定 `AspectRatio 3:4` | 已是瀑布流（左/右列等高平衡） |
| 我的收藏页 | `TemplateCard`（template_grid.dart `TemplateGrid`） | 固定 `AspectRatio 3:4` | 已是瀑布流（左/右列等高平衡） |

**关键约束**：

- 数据模型（`TemplateItem` / `AllTemplateItem` / `TemplateRecord`）**不存封面宽高**。
- 封面来源四种：`assets/*`（内置）、`data:` base64（自定义）、`http`（远程）、本地文件路径。
- 瀑布流是「手写双列 + 估算高度配平」架构（无第三方库），卡片为 `Column` 固有高度，封面比例变化会自然带动卡片高度、参与下一帧布局。
- 瀑布流左右列**分配**发生在 build 时（按估算高度），加载后比例变化不触发重新分配——估算值只需合理即可，无需精确。

## 3. 方案 A 设计：自适应封面组件 `AdaptiveCoverImage`

### 3.1 组件定位

新建 `lib/features/templates/widgets/adaptive_cover_image.dart`，有状态组件。职责：

1. 按来源构造 `ImageProvider`（复用 `TemplateCoverImage` 的来源路由逻辑：`coverData` base64 → `MemoryImage`；`cover` 前缀 `data:` → `MemoryImage`、`assets/` → `AssetImage`、`http` → `NetworkImage`、其它 → `FileImage`）。
2. 通过 `ImageStream.resolve(const ImageConfiguration())` + `ImageStreamListener` 取图片真实宽高（先例：`photo_crop_layer.dart`），算出真实比例 `realRatio = w / h`。
3. 对真实比例做**钳制**得到展示比例 `displayRatio`：

```
displayRatio = realRatio.clamp(kMinCoverRatio, kMaxCoverRatio)
kMinCoverRatio = 0.65   // 9:16(0.5625) 钳到 0.65，高度减约 13%，轻微上下裁切
kMaxCoverRatio = 2.0    // 超宽全景裁左右
```

4. 渲染：`AspectRatio(displayRatio)` + 原图（`BoxFit.cover`）。比例在区间内时完全展示；超出区间时 `cover` 裁切多余方向。**加载中/未知比例**时用默认 `kDefaultCoverRatio = 3 / 4`（0.75）+ 现有 fallback 占位，不出现空白。

### 3.2 组件签名

```dart
class AdaptiveCoverImage extends StatefulWidget {
  const AdaptiveCoverImage({
    super.key,
    this.cover,          // 同 TemplateCoverImage.cover
    this.coverData,      // 同 TemplateCoverImage.coverData
    this.fit = BoxFit.cover,
    this.fallback,       // 无封面数据时的占位
    this.errorFallback,  // 加载失败占位
  });
}
```

- 状态：`double? _realAspect`；`initState`/`didUpdateWidget`（封面来源变化时）重新 resolve。
- `dispose` 移除 listener。
- 未知比例期间：`AspectRatio(kDefaultCoverRatio)` + 图片 `BoxFit.cover`（首帧可能轻微跳变，可接受）。

### 3.3 来源路由小重构

`TemplateCoverImage` 的来源识别逻辑抽成共享函数（放 `adaptive_cover_image.dart` 或 `template_cover_image.dart` 内 `ImageProvider? buildCoverProvider(String? cover, String? coverData)`），`AdaptiveCoverImage` 与 `TemplateCoverImage` 共用，避免重复。`TemplateCoverImage` 自身行为不变（其它调用方不受影响）。

## 4. 四处卡片改造

### 4.1 我的收藏页 `TemplateCard`（template_grid.dart）

- 封面：固定 `AspectRatio(3/4)` → `AdaptiveCoverImage(cover, coverData)`（fallback/errorFallback 沿用现有）。
- `_estimateCardHeight`：封面高度 `cardWidth * 4 / 3` → `cardWidth / kDefaultCoverRatio`（约等于原值，配平行为不变）。

### 4.2 模板库 `_TplCard`（templates_all_page.dart）

与 4.1 相同改造（全部模板页的 `_TemplateGrid` 内独立副本，一并替换）。

### 4.3 搜索页 `SearchResultCard`（search_result_card.dart）

- 仅**模板**封面：固定 `3:4` → `AdaptiveCoverImage`。
- 场景卡片保持现有 `3:4`、美学院保持 `4:3`（本轮范围外，见 §6）。
- `_imageStack` 内 `ratio` 逻辑调整：模板走自适应组件，非模板仍用 `AspectRatio(ratio)`。
- global_search_page.dart `_estimateCardHeight`：模板封面高度改用 `w / kDefaultCoverRatio`；场景/美学院保持原估算。

### 4.4 发现页「更多模板」`_OtherSection`（templates_page.dart）

- 布局：`GridView.builder`（固定 `childAspectRatio: 0.70`）→ 手写双列瀑布流（左/右 `Column` + 估算高度配平，与 `TemplateGrid` 同模式）。
- 卡片 `TemplateGridCard`：`_GridImage` 固定 `AspectRatio(1:1)` → `AdaptiveCoverImage`。
- 保留「最多 6 个」截断与 loading/空态逻辑。
- 瀑布流估算高度：封面 `cardWidth / kDefaultCoverRatio` + 文字区（名称 13dp + 分类 11dp + padding）。

## 5. 常量与共用

- 新增常量（`adaptive_cover_image.dart` 顶部）：`kDefaultCoverRatio = 3 / 4`、`kMinCoverRatio = 0.65`、`kMaxCoverRatio = 2.0`。
- 瀑布流估算函数统一引用 `kDefaultCoverRatio`，保证「估算用默认比例、加载后自然修正」。

## 6. 范围边界

- **仅模板封面自适应**；搜索页场景、美学院卡片保持现有固定比例（用户确认）。
- 9:16 用**温和削减**（`kMinCoverRatio = 0.65`），不做更激进的 3:4 钳制（用户确认）。
- 发现页顶部「今日推荐」横向滑动卡片、模板详情页封面不在本轮。
- 不改后端、不改数据模型、不改 `LumiraImage` 降采样逻辑。
- 瀑布流左右列分配仍用估算高度，不引入加载后重平衡（避免过度设计）。

## 7. 回归注意

- `TemplateCoverImage` 仅抽公共来源路由函数，行为不变；其它调用方（模板详情页、推荐卡、搜索结果等）不受影响。
- base64 封面：`MemoryImage` 与 `TemplateCoverImage` 内部字节缓存解耦，`AdaptiveCoverImage` 只取尺寸后仍委托 `TemplateCoverImage` 渲染原图（避免重复解码——渲染走现有 `TemplateCoverImage`，本组件只负责定尺寸外层）。
- 空/损坏封面：fallback/errorFallback 沿用各卡片现有占位。
- 瀑布流页面（搜索、模板库）改造后卡片高度变化，需目视检查左右列配平无异常错位。
