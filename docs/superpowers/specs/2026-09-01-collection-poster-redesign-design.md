# 精选集导出海报重设计（九宫格 · 最多 9 张）

- 日期：2026-09-01
- 状态：已获用户批准（用户反馈"先这样设计吧，对于图片最多放置九张"）
- 关联视觉稿：`docs/design/collection_poster_mockup.html`（v2，含 4 套版式 + 旧版对照）
- 范围：仅 Flutter 端（`lumira_app_flutter/`），不涉及后端/后台

## 1. 背景与目标

现状 `ProfileCollectionDetailPage` 的「导出九宫格拼图」使用 [collection_poster_generator.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/profile/widgets/collection_poster_generator.dart) 的 `CollectionPosterContent`，渲染为「渐变小圆角 + 普通文字堆叠 + 平铺网格」，层次平淡、被用户判定"太丑"。

目标：重设计为 **4 套可切换版式**，复用既有 `PosterStyleRegistry` / `PosterGenerator.showPosterWithStylePicker` 体系，支持用户切换版式、实时预览、导出相册、分享社交。

约束（用户明确）：**图片最多放置 9 张**（超出截断为前 9 张）；不同版式采用不同信息层级与留白；颜色沿用分享海报体系既定的 `PosterPalette` 固定品牌色板（对「样式跟随主题」铁律的既有明示例外），不随 App 设置切换。

## 2. 设计原则（沿用项目铁律 + 海报体系既有约定）

1. **颜色一律取自 `PosterPalette` 固定品牌色板**（`poster_common.dart`：`gold / goldDeep / goldSoft / ink / text2 / text3 / line / surface / surfaceAlt`）。这是分享海报体系的既有约定——分享海报属导出类品牌资产，固定 LUMIRA 原生金/墨/米色板，**不随 App 主题/UI 风格切换**（对「样式跟随主题」铁律的既有明示例外，用户已认可，mockup 亦按此色板绘制）。`ThemeTokens` 仅用于照片加载失败占位（`checkinPhoto` 同款）。
2. **禁止风格混搭**：同一海报只使用当前海报体系自己的视觉语言（衬线标题 + 金线 + 米白底），不引入新拟态/玻璃/扁平等其他 UI 风格语法。
3. **叠图浮层规则**：画册封面的深色压暗遮罩属"叠在照片上的半透明遮罩"，是跨风格通用叠加视觉，允许 `Colors.black.withOpacity(...)`（唯一合法例外）。
4. **衬线字体**：标题统一使用 `Noto Serif SC`（项目已内置），营造杂志/画册气质；品牌英文 `LUMIRA` 用字距加宽的衬线/无衬线小号字。
5. **无动效**：海报是静态导出图，不引入动画。

## 3. 四套版式设计规格

> 画布逻辑宽度统一 320px（沿用 checkin 海报 `_kCkW = 320` 约定），导出时由 `PosterGenerator` 按目标宽度 1080px 计算倍率出图。比例支持：1:1（320×320）与 3:4（320×427）。

### 3.1 杂志大刊 · Editorial（id: `clMag`）

- 气质：编辑排版、大留白、衬线大标题、金线描边、整齐网格。
- 支持比例：1:1、3:4。
- 结构（自上而下）：
  - 品牌行：`LUMIRA`（gold-deep 色）+ `如画 · 精选集`（text-tertiary 色），字距 3-4px。
  - 内描边：距边 10px 的 1px 细线 + 四角 12px 金色小角标（`border: brand`）。
  - 分类行：如 `TRAVEL JOURNAL`（全大写、字距 3px、text-tertiary）。
  - 主标题：26px 衬线加粗、字距 5px、text-primary；下接一句描述（11px、text-secondary、行高 1.6）。
  - 照片网格：`flex:1` 收进剩余空间，gap 4px；≥5 张 3 列，≤4 张 2 列（见第 4 节）。
  - 页脚：上细分隔线 + 左「共收录 **N** 张」（数字用 Georgia 金强调）+ 右日期（如 `2026.08.31`）。

### 3.2 极简网格 · Minimal Grid（id: `clMini`）

- 气质：照片填满网格、文字极简克制、大量留白。
- 支持比例：仅 1:1。
- 结构（自上而下）：
  - 顶部行：左 `LUMIRA`（gold-deep、字距 3px）+ 右 `如画`（text-tertiary）。
  - 主标题：17px 衬线、字距 2px、text-primary；下接一句描述（10px、text-tertiary、行高 1.6）。
  - 照片网格：左右 24px 留白、gap 3px、`flex:1` 收进剩余空间；≥5 张 3 列，≤4 张 2 列。
  - 页脚：细分隔线 + 左「共收录 **N** 张 · 2026.08.31」+ 右 slogan「如画 · 记录每一帧光影」。

### 3.3 胶片拼贴 · Film Collage（id: `clFilm`）

- 气质：拍立得白框 + 1 大图错落 + 手写日期，复古生活感。
- 支持比例：仅 3:4。
- 结构（自上而下）：
  - 品牌行：`LUMIRA` + `如画`。
  - 主标题：20px 衬线、字距 2px、暖深色；下接手写体日期（13px、如 `2026. 08. 31`，用 Kaiti/手写风格）。
  - 拍立得拼贴（`flex:1`）：
    - 第 1 张大图：白框 `polaroid`（米白底 `surface` + 8px 白边 + 底部 20px 手写 caption 条，如「海边的风」），旋转 -1.6°，占宽 74%。
    - 下方 2 张小图并排（各占宽 44%，旋转 +2° / -2° 错落，小图带 caption）。
    - **仅取前 3 张**做错落拼贴（该版式是"拍立得海报"而非网格，超出 3 张不展示）；不足 3 张时降级「1 大 + 1 小」「仅 1 大」（见第 4 节）。
  - 页脚：虚线分隔 + 左「共收录 **N** 张」+ 右 `如画 LUMIRA`。
- 背景：暖米径向渐变 + 底部轻微晕影（同色系透明度，非玻璃）。

### 3.4 画册封面 · Album Cover（id: `clAlbum`）

- 气质：首图全幅背景 + 底部压暗 + 亮色文字，氛围电影感。
- 支持比例：1:1、3:4。
- 结构（自上而下，Stack 布局）：
  - 背景层：第 1 张照片铺满全幅（`BoxFit.cover`）。
  - 压暗层：线性渐变 `rgba(黑) 0.10 → 0.18 → 0.82`（自顶向底），属于"叠照片半透明遮罩"合法例外。
  - 前景层：顶部品牌行（`LUMIRA` 用 `F3E3C2` 亮金 + `如画 · 精选集` 白 62%）；中部 `spacer` 留白；底部主标题（24px 衬线、`FFF8EC`、字距 4px）+ 标题下 46px 金色渐隐短线 + 描述（白 72%）+ 页脚行「共收录 **N** 张」（亮金数字）+ slogan「记录每一帧光影」。

## 4. 照片网格自适应规则（1-9 张）

| 张数 | 布局 | 说明 |
|---|---|---|
| 1 | 1×1 单图 | 网格区占满可用空间；胶片拼贴仅 1 大图 |
| 2 | 1×2 并排 | 两图各半；胶片拼贴为 1 大 + 1 小 |
| 3-4 | 2×2 | 杂志/极简；胶片拼贴取前 3 张做 1 大 + 2 小 |
| 5-9 | 3×3 | 杂志/极简/画册满铺 3 列（九宫格），末行不足自动留空；胶片拼贴仍仅取前 3 张 |

- 网格区域必须是 `flex:1` + `min-height:0`（Flutter 用 `Expanded` + `AspectRatio` 单元格），保证内容收缩进海报盒内、绝不溢出（吸取 mockup v1 溢出教训）。
- 照片一律 `BoxFit.cover` 居中裁剪，不拉伸变形。
- 数据层：海报仅取前 9 张；`photoCount` 显示精选集真实收录数（可大于 9），如「共收录 12 张」。
- 胶片拼贴 caption：无图注数据时降级为空文案条（保留白框底部条）。

## 5. 技术方案（接入现有海报体系）

复用 checkin 海报的成熟模式（[checkin_poster_styles.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/checkin/widgets/checkin_poster_styles.dart) + `showPosterWithStylePicker`），新增一个 `PosterKind.collection` 分支。

### 5.1 数据模型扩展

- [poster_style_types.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/shared/widgets/poster/poster_style_types.dart)：
  - `enum PosterKind { template, photo, checkin, collection }` 新增 `collection`。
  - `PosterStyleData` 复用既有字段映射精选集数据：
    - `title` ← 精选集名称（空时回退「我的精选集」）
    - `category` ← 版式分类文案（如 `TRAVEL JOURNAL`，无则用「LUMIRA COLLECTION」）
    - `shareText` / `note` ← 精选集描述（描述为空时不渲染）
    - `dateText` ← 创建日期文案（`yyyy.MM.dd` 格式，供杂志/画册页脚与胶片手写日期）
    - `thumbBuilders` ← 前 9 张照片的 `(w,h) => Widget` 构建器（复用 checkinPhoto 同款 cover 渲染，支持 `CachedNetworkImage`（http）与 `LumiraImage`（本地路径））
    - `authorName` / `qrData` / `qrHint` / `qrSub` 不适用，保持空。
  - 说明：不新增字段也能承载全部数据，避免侵入既有模板/照片/探店海报调用方。

### 5.2 新增样式文件

新建 `lumira_app_flutter/lib/features/profile/widgets/collection_poster_styles.dart`：

- 定义 `const double _kCkW = 320;`，导出 `List<PosterStyle> collectionPosterStyles()`，含 4 个样式：
  - `clMag` 杂志大刊（1:1、3:4）
  - `clMini` 极简网格（1:1）
  - `clFilm` 胶片拼贴（3:4）
  - `clAlbum` 画册封面（1:1、3:4）
- 样式内部用 `d.thumbBuilders` 构建照片区；画册封面取 `d.thumbBuilders!.first` 作背景。
- 复用 `poster_common.dart` / 既有 `checkinPhoto` 式照片渲染工具（必要时提取为共享 `posterPhoto` helper）。

### 5.3 注册与调用

- [poster_style_registry.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/shared/widgets/poster/poster_style_registry.dart)：在 `_styles` 列表追加 `...collectionPosterStyles()`。
- [profile_collection_detail_page.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/profile/pages/profile_collection_detail_page.dart) 的 `_showSharePoster`：
  - 由 `PosterGenerator.showPoster` 改为 `showPosterWithStylePicker`（kind: `PosterKind.collection`）。
  - 组装 `PosterStyleData`（title/name、category、dateText、thumbBuilders 等）。
  - 比例：图片数 ≤4 → `PosterRatio.square`（默认极简/杂志 1:1），≥5 → `PosterRatio.ratio34` 或 `square`（默认杂志 1:1，用户可在切换条选 3:4 版式）。具体默认比例在实现时与用户确认展示顺序后定。
- 旧 `CollectionPosterContent` 保留或删除：确认不再被引用后删除（避免死代码）；若详情页九宫格预览仍复用其 `_PhotoGrid`，则拆出共享网格组件。

### 5.4 不动的东西

- `PosterGenerator`、`_PosterSheet`、样式切换条、导出/分享逻辑零改动（`showPosterWithStylePicker` 已支持多比例样式注册与翻页切换）。
- 后端/后台不涉及。

## 6. 实施清单（供 writing-plans 拆解）

1. `PosterKind` 增加 `collection`。
2. 新增 `collection_poster_styles.dart`，实现 4 套版式 + 1-9 张网格自适应。
3. 在 `poster_style_registry.dart` 注册 `collectionPosterStyles()`。
4. 改造 `_showSharePoster` 为 `showPosterWithStylePicker`，组装 `PosterStyleData`。
5. 复用/清理 `collection_poster_generator.dart`（删除或拆分共享网格组件）。
6. 真机验证：4 套版式 × 2 比例 × 多主题（暖白·金 / 莫兰迪 / 浓墨 / 玫瑰金）× 图片数 1/2/4/9 张无溢出、无拉伸、导出清晰。

## 7. 验收标准

- 精选集详情页点「导出九宫格拼图」弹出样式切换 Sheet，可左右滑动切换 4 套版式。
- 1-9 张图片全部完整显示、无裁切溢出；第 9 张后不显示。
- 颜色统一取自 `PosterPalette` 固定品牌色板，与既有分享海报体系一致（画册封面压暗遮罩为合法黑透明例外）。
- 导出 PNG ≥1080px 宽，分享到社交平台内容完整清晰。
- `flutter analyze` 通过；无新增未使用代码。
