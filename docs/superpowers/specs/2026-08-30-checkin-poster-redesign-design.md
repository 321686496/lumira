# 探店足迹分享海报 · 多款式重设计（Phase 1）设计

日期：2026-08-30

## 背景与目标

当前「探店足迹」分享海报是单一旧版通用居中布局（渐变底 + 单张封面 + 店名 + 评分/分类/地点/时间/备注 + 水印）。用户在项目根目录迭代了一套 HTML 海报预览稿，期望把探店足迹分享海报改成**多款可选样式**，并支持**多图排版、照片选择**，视觉对齐该套 HTML。

本期（Phase 1）交付：**4 款可选样式 + 1 大图/至多 4 小图多图排版 + 照片选择（>5 张时）**。裁剪工具列入 Phase 2，不在本期实现。

## 待实现款式（来源：项目根 HTML mockup）

| 款式 id | 名称 | 来源 HTML | 风格要点 |
|---|---|---|---|
| `f` | 温柔手帐 | `poster_mockup_checkin_f.html` | 燕麦奶油→晨曦粉微渐变、大圆角、玻璃拟态、玫瑰粉/鼠尾草绿点缀、评分浮胶 |
| `base` | 原风格 3:4 | `poster_mockup_checkin.html` | 暖白金、缺角相框+金 L 角标、衬线大字、金线夹斜体心得 |
| `v4` | 金字招牌·留白 | `poster_mockup_checkin_v4.html` | 居中超大金字店名、四角照片点缀、印章、大量留白 |
| `m4` | 克制奢华·非对称 | `poster_mockup_checkin_m4.html` | 左大图右信息列、下四错落图、金色 L 角标 |

## 架构（复用现有海报体系，零破坏）

- 在 `PosterKind` 新增 `checkin`，在 `PosterStyleRegistry._styles` 注册上述 4 款（新增 `checkin_poster_styles.dart` 集中定义）。
- 复用 `showPosterWithStylePicker` 与 `_PosterSheet`：自动获得「样式切换条 + 整页预览 + 保存/分享双主按钮」整套能力。
- 海报为**独立导出图形**，各款式用其品牌调色板（延续现有 `PosterPalette` 风格的做法），**不走** app 主题/UI 风格切换。

### 数据模型泛化（关键改动）

现有 `PosterStyleData` 只支持单图 `photoBuilder(w,h)`。为不影响模板/照片两张海报，扩展出 checkin 专用数据载体：在 `poster_style_types.dart` 中让 `PosterStyleData` 增加**可选** checkin 扩展字段（默认 null，既有两张海报不受影响）：

- `List<Widget Function(double w, double h)>? thumbBuilders`（至多 4 个小图，每格槽位比例由样式自定）
- `String? checkinNote`（心得）
- `String? checkinPlace`、`String? checkinCategory`、`String? checkinDate`（地点/分类/日期）
- `double? rating`（评分 0-5）

`photoBuilder` 继续作为「大图」语义。4 款 checkin 样式据此渲染「1 大图 + 至多 4 小图 + 评价信息」。

> 若字段膨胀，可在 Phase 1 先以独立 `CheckinPosterData` + 少量适配为先，实现时以最小改动、又不破坏模板/照片海报为原则。

### 海报展示比例

checkin 海报为纵向卡片，统一按 `PosterRatio.ratio34`（3:4）注册，4 款样式均 `supports(ratio34)`。样式选择器按该 ratio 过滤即可。

## 数据来源（加载全部照片）

- 目前 `showCheckinPoster` 只接收 `CheckinListItem`（单封面）。改为需要时异步解析该次探店全部照片：
  - 复用 `checkinDetailProvider(record.id)`（`FutureProvider.family`，返回 `CheckinDetail`），其 `photos` 即 `List<GalleryItemRecord>`。
  - 或直接用 `CheckinDao.getPhotoIds(checkinId)` → 逐条取 `GalleryItemRecord`。
- 照片渲染沿用 `GalleryItemRecord` 的 `data_url`/`file_path`，复用 `CheckinPhotoImage`/`LumiraImage` 懒加载。

## 选图交互（>5 张照片时）

- **照片 ≤5**：全用，直接进入海报预览。
- **照片 >5**：先弹「选照片」面板：
  - 网格多选，最多 5 张；
  - 选中顺序即展示顺序，**列表首位=大图**；
  - 提供顺序微调（上移/下移）；
  - 确认后进入海报预览。
- 少于 5 张时，各样式按实际张数少排小图（空位不显示/不占位）。

## 样式渲染约束（对照 HTML）

- `f`：微渐变底、圆角卡片、评分浮大图左下、胶囊 meta、心得卡、底部小图带。
- `base`：缺角相框(`clip-path`)+金 L 角标、评分/分类胶囊、衬线大字店名、金线夹斜体心得、小图带、水印。
- `v4`：居中超大金字店名、四角照片点缀（缺角/斜放）、印章、底部金评分/日期/地点/分类、水印、大量留白。
- `m4`：上排左大图右信息列（眉题+金线+衬线大字店名+英文+星+评分+meta+分类 tag）、下四图错落、金色 L 角标、心得、底部水印。

缺失字段兜底：无心得则不显示心得块；无评分（0）不显示星；无地点/分类显示默认。

## 测试

- 纯数据映射：`CheckinRecord`/照片列表 → `CheckinPosterData`（字段兜底、顺序、>5 截断/选图）单测。
- Widget：4 款样式在 `FittedBox`（无界约束）下渲染不抛「无限宽」异常（承接近期已修 bug），并断言关键文案/图形存在；`showCheckinPoster` 打开样式选择器、切换样式正常。
- 回归：既有模板/照片海报样式测试不受影响（确认 `PosterKind` 新增不破坏枚举 switch）。

## 涉及文件（预估）

- 新增：`lib/features/checkin/widgets/checkin_poster_styles.dart`、`checkin_poster_data.dart`（数据载体）、选图面板组件。
- 修改：`poster_style_types.dart`（`PosterKind.checkin` + 可选 checkin 字段）、`poster_style_registry.dart`（注册）、`checkin_poster_generator.dart`（改走样式选择器 + 加载照片/选图）、`checkin_list_page.dart`（分享入口传 photo/record 上下文）。
- 测试：`test/features/checkin/checkin_poster_*_test.dart`。

## 验收标准

1. 分享探店足迹弹出**样式选择器**，可切换 f/base/v4/m4 四款，预览与导出一致。
2. 海报展示「1 大图 + 至多 4 小图」；照片按实际张数排布。
3. 足迹照片 >5 时，先出现选图面板（最多 5 张、首位为大图、可调序）。
4. 所有样式在无界约束下正常布局，无「无限宽」异常。
5. 既有 4 款海报样式（模板/照片）与分享入口不回归。

## 二期范围（不在本期）

- 照片宽高比与槽位不一致时的**选区裁剪**工具（锁定槽位比例，拖拽/缩放选择可见区域，覆写到展示的图）。
- 裁剪结果需在导出与各样式预览中一致。