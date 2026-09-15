# 精选集分享海报重设计 v5「光影纸册 · 双比例」设计规格

- 日期：2026-09-14
- 状态：✅ 已获用户批准（会话内分节确认）
- Supersedes：`docs/superpowers/specs/2026-09-01-collection-poster-redesign-design.md`（4 版式方案作废）
- 视觉基准：`docs/design/collection_poster_mockup_v4.html`（「光影纸册」稿），本文档在其上扩展 1:1 方版配平
- 范围：仅 Flutter 端 `lumira_app_flutter/`；后端与 admin 无改动

## 1. 背景与目标

精选集详情页「导出九宫格拼图」当前使用 `CollectionPosterContent`（渐变小圆角卡 + 文字堆叠），观感差且配色随 App 主题漂移，与模板/照片/探店海报的 `PosterPalette` 固定品牌色板体系不一致。

目标：替换为 v4「光影纸册」版式，支持 3:4 / 1:1 双比例、1-9 张宫格自适应；导出/分享链路（`RepaintBoundary` 捕获、saver_gallery、SafeShare、鸿蒙降级）零改动。

## 2. 用户决策记录

| 决策点 | 结论 |
|---|---|
| 设计起点 | 按 v4「光影纸册」落地（不采用 09-01 的 4 版式方案） |
| 比例 | 3:4 + 1:1 双比例 |
| 二维码 | 不加（严格照 v4） |
| 比例选择交互 | 智能默认 + Sheet 内比例档位（方案 A：小改共用 `_PosterSheet`） |
| 配色 | 固定 `PosterPalette` 品牌色板，不随 App 主题/UI 风格切换（分享海报体系既有约定，UI 铁律明示的唯一例外） |

## 3. 视觉规格（光影纸册 · clPaper）

画布逻辑宽 300（沿用 `posterCanvasWidth` 约定），竖版 300×400、方版 300×300，圆角 6，`surface #FDFBF7` 纸面。五段式结构：

1. **金发丝内框**：距边 9px 的 1px `line` 描边 + 四角 13px `goldDeep` L 角标（`CustomPainter`，参考 `GoldNotchedFrame`）。
2. **品牌行**：`LUMIRA`（Georgia 11px、字距 4、goldDeep）+ 渐隐金发丝横线（flex:1）+ `如画 · 精选集`（9px、字距 3、text3）。
3. **标题区**：衬线（Noto Serif SC）大标题 21px（1:1 时 19px）；空名回退「我的精选集」；描述 10.5px 最多 2 行省略（空则整行不渲染）；下方金渐隐分隔线（goldDeep → line → 透明）。
4. **照片宫格**：`Expanded` 吃剩余高度，gap 4px，cover 居中裁切，圆角 6。自适应规则（与 v4 一致）：

   | 张数 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
   |---|---|---|---|---|---|---|---|---|---|
   | 列×行 | 1×1 | 2×1 | 2×2 | 2×2 | 3×2 | 3×2 | 3×3 | 3×3 | 3×3 |

5. **页脚**：上 1px 金线；左「共收录 **N** 张」（数字 Georgia 15px goldDeep 强调；N=真实收录数，可大于 9）；右日期 `yyyy.MM.dd`；纸面底部居中小字签名「如画 LUMIRA」（8px、字距 4、text3）。

**1:1 方版配平**：同一结构，标题缩至 19px，宫格与页脚间距收紧；3×3 时单元格 ≥50px 逻辑宽（1080px 导出下 ≈180px/格）。

**降级规则**：0 张照片 → 宫格区 `surfaceAlt` 占位块 +「暂无照片」；单张加载失败 → `CheckinPhotoImage` 既有占位逻辑。无动画。

## 4. 技术方案（方案 A）

1. **`poster_style_types.dart`**：`PosterKind` 追加 `collection`；`PosterStyleData` 追加可选字段 `photoCount`（默认 0，0 时回退 `thumbBuilders.length`）。既有调用方零改动。
2. **新建 `lib/features/profile/widgets/collection_poster_styles.dart`**：导出 `collectionPosterStyles()`，含 1 个样式 `clPaper`（光影纸册），`ratios = {PosterRatio.square, PosterRatio.ratio34}`，`supportCheck` 要求 `thumbBuilders` 非空或 `photoCount>0`；照片渲染复用 `checkinPhoto`。
3. **`poster_style_registry.dart`**：`_styles` 追加 `...collectionPosterStyles()`。
4. **`poster_generator.dart` 小改**：`_StylePickerConfig` 新增可选参数 `ratioOptions`（`List<PosterRatio>?`）与 `dataBuilder`（`PosterStyleData Function(PosterRatio)`）。`ratioOptions` 非空时在标题下方渲染比例档位胶囊行（`3:4 竖版` / `1:1 方版`，当前态金描边），点选 `setState` 换比例并用 `dataBuilder` 重建数据；样式数为 1 时隐藏底部「选择版式」缩略条。`ratioOptions` 缺省时既有行为逐字不变（模板/照片/探店零回归）。
5. **详情页 `_showSharePoster`**：改调 `showPosterWithStylePicker`（kind=collection）；智能默认比例：照片数 ≤4 → 1:1，≥5 → 3:4；`ratioOptions=[ratio34, square]`；组装 `PosterStyleData`（title=集名、category=`${typeLabel} · 精选集`、note=描述、dateText、thumbBuilders=前 9 张、photoCount=真实收录数）。
6. **清理**：`collection_poster_generator.dart` 确认无引用后删除。

## 5. 测试与验收

- 单测：
  1. `clPaper` 样式 × 两比例 × 张数（0/1/2/5/9）widget test：无 overflow、宫格 cell 数正确、收录数文案（含 N>9）正确；
  2. registry 测试补 collection 断言；
  3. `_PosterSheet` 档位行渲染/切换回归测试（含 ratioOptions 缺省时不渲染）；
  4. 详情页既有测试改为断言新海报 Sheet 打开。
- 验证命令：`flutter analyze`（零告警）+ `flutter test`（相关套件全绿）。
- 验收：1-9 张无溢出无拉伸；两比例档位可切实时预览；导出 PNG 宽 ≥1080px；任意 App 主题下导出外观一致；断网/空描述/空名称正常降级。

## 6. 风险与约束

- Dart 2.19.6 / Flutter 3.7.12：禁用 Dart 3 records/patterns 语法。
- `_PosterSheet` 为三种海报共用：改动必须向后兼容，缺省路径不得引入行为差异。
- 不修改 `lumira-app/`（uni-app 仅原型参考）。
