# 精选集导出海报重设计（九宫格 · 最多 9 张）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把精选集详情页「导出九宫格拼图」从单一丑陋版式重设计为 4 套可切换版式（杂志大刊 / 极简网格 / 胶片拼贴 / 画册封面），复用既有海报样式注册表与样式切换 Sheet，支持 1-9 张照片自适应、导出/分享。

**Architecture:** 复用 `PosterStyleRegistry` + `PosterGenerator.showPosterWithStylePicker` 成熟体系（checkin 海报同款模式）。新增 `PosterKind.collection` 与一个可选字段 `PosterStyleData.photoCount`；新建 `collection_poster_styles.dart` 实现 4 套版式并注册；详情页 `_showSharePoster` 由 `showPoster` 改为 `showPosterWithStylePicker` 并组装 `PosterStyleData`；删除不再引用的 `collection_poster_generator.dart`。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（无 records 语法）；flutter_riverpod；`CachedNetworkImage` / `LumiraImage`（照片渲染）；复用 `poster_common.dart` 的 `PosterPalette` 固定品牌色板与 `posterSerif/posterPlain/posterSerifEn` 文本样式。

## Global Constraints

- 颜色一律取自 `PosterPalette` 固定品牌色板（`gold / goldDeep / goldSoft / ink / text2 / text3 / line / surface / surfaceAlt`），**不随 App 主题/UI 风格切换**；`ThemeTokens` 仅用于照片加载失败占位（复用 `checkinPhoto` 即含占位）。画册封面深色压暗遮罩允许 `Colors.black.withOpacity(...)`（唯一合法例外）。
- 海报画布逻辑宽度固定 `_kCkW = 320`；比例 1:1（320×320，`PosterRatio.square`）与 3:4（320×427，`PosterRatio.ratio34`）。
- 网格区域必须用 `Expanded`（`flex:1`，`min-height:0`）收进海报盒内，照片一律 `BoxFit.cover` 居中裁剪，**绝不溢出/拉伸变形**（吸取 mockup v1 教训；最终以 `docs/design/collection_poster_mockup.html` v2 为视觉基准）。
- 海报仅取前 9 张照片；页脚「共收录 N 张」显示精选集真实收录数 `photoCount`（可 > 9）。取数规则：`count = photoCount > 0 ? photoCount : thumbBuilders.length`。
- 胶片拼贴 `clFilm` **仅取前 3 张**做拍立得错落拼贴，超出不展示；不足 3 张降级「1 大 + 1 小」/「仅 1 大」。
- 默认比例（用户已选「智能默认」）：照片数 ≤4 → `PosterRatio.square`；≥5 → `PosterRatio.ratio34`。
- 不引入动画；不修改 `PosterGenerator` / `_PosterSheet` / `PosterStylePicker` / `poster_style_registry.dart` 的既有逻辑（仅追加注册）；不涉及后端/后台。
- 禁止风格混搭：只用当前海报体系自己的视觉语言（衬线标题 + 金线 + 米白底）。
- 提交遵循仓库约定：仅当用户明确要求时才 commit/push（本计划不预设 commit 步骤）。
- 本仓库 `AGENTS.md`：Flutter 端改动在 `lumira_app_flutter/`，uni-app 项目 `lumira-app/` 仅作参考不可修改。

---

### Task 1: 数据模型扩展（PosterKind.collection + PosterStyleData.photoCount）

**Files:**
- Modify: `lumira_app_flutter/lib/shared/widgets/poster/poster_style_types.dart`
- Modify（文档一致性）: `docs/superpowers/specs/2026-09-01-collection-poster-redesign-design.md#5.1`

**Interfaces:**
- Consumes: 无（纯类型扩展）。
- Produces: `enum PosterKind { template, photo, checkin, collection }`；`PosterStyleData` 新增可选字段 `final int photoCount;`（默认 `0`，构造参数 `this.photoCount = 0`）。既有调用方（template/photo/checkin）零改动。

**Steps:**
- [ ] 1.1 阅读 `poster_style_types.dart`，确认 `PosterKind` 枚举与 `PosterStyleData` 构造签名。
- [ ] 1.2 在 `enum PosterKind` 末尾追加 `collection`（不改变既有枚举序，避免任何序列化依赖）。
- [ ] 1.3 在 `PosterStyleData` 构造参数追加 `this.photoCount = 0`，并在类中新增字段 `final int photoCount;`，紧邻 `thumbBuilders` 之后，附文档注释：「精选集真实收录数（可大于展示的 9 张），供页脚『共收录 N 张』；0 表示未提供，回退用 thumbBuilders.length」。
- [ ] 1.4 修正设计文档 5.1 的「不新增字段」说明，改为：`PosterStyleData` 仅新增一个可选字段 `photoCount`（`int`，默认 0，页脚展示真实收录数用）；其余全部复用既有字段，不侵入既有调用方。
- [ ] 1.5 验证：`flutter analyze` 通过；`flutter test test/shared/widgets/poster/poster_style_registry_test.dart` 仍全绿（既有行为不回退）。

**Verify:** `flutter analyze` 无新增告警；registry 测试通过。

---

### Task 2: 新建 collection_poster_styles.dart（4 套版式 + 1-9 张网格自适应）

**Files:**
- Create: `lumira_app_flutter/lib/features/profile/widgets/collection_poster_styles.dart`
- Test: `lumira_app_flutter/test/features/profile/collection_poster_styles_test.dart`

**Interfaces:**
- Consumes:
  - `poster_common.dart`：`PosterPalette`、`posterSerif/posterSerifEn/posterPlain`、`PosterLogo/PosterRule/PosterDivider/PosterKicker` 等既有组件。
  - `poster_style_types.dart`：`PosterStyle`、`PosterKind.collection`、`PosterStyleData`。
  - `poster_ratio.dart`：`PosterRatio.square / ratio34`。
  - `checkin_poster_widgets.dart` 的 `checkinPhoto`（已含 cover 渲染 + 失败占位；`lib/features/checkin/widgets/checkin_poster_widgets.dart`）。
- Produces: `List<PosterStyle> collectionPosterStyles()`（含 `clMag/clMini/clFilm/clAlbum` 4 个样式；`clMag` 与 `clAlbum` 支持 `{square, ratio34}`，`clMini` 仅 `square`，`clFilm` 仅 `ratio34`）。

**设计规格摘要（完整见设计文档 §3/§4，视觉基准为 mockup v2）：**

- 常量：`const double _kCkW = 320;`。画布 `SizedBox(width: 320, height: ratio==square ? 320 : 427)` 固定高度，保证页脚贴底、网格 `Expanded` 填满、绝不溢出。
- 共享网格组件 `_CollectionGrid`（内部私有）：
  - 输入：`List<Widget Function(double w,double h)> builders`、`double gap`。
  - `count` 由 `builders.length` 得出；`crossCount`：`count<=1→1`、`count<=4→2`、否则 `3`；`rows = (count/crossCount).ceil()`。
  - 结构：`Column(children: [for r in rows: Expanded(Row(children:[for c: Expanded(cell)]))])`；cell 为空位时 `Expanded(child: SizedBox.shrink())`；cell 内 `LayoutBuilder(builder: (_, cc) => ClipRect(child: builders[i](cc.maxWidth, cc.maxHeight)))`（照片 cover 填充单元格，cell 随 1fr 拉伸填满，非固定方块——与 mockup v2 的 `1fr` 网格一致）。
- `clMag` 杂志大刊（square + ratio34）：品牌行 `LUMIRA`(goldDeep)+`如画 · 精选集`(text3)；距边 10px 细内描边 + 四角 12px 金色 L 角标（可参考 `GoldNotchedFrame` 思路自行绘制或简化）；分类行 `d.category` 全大写字距 3（缺省用「LUMIRA COLLECTION」）；26px 衬线标题 + 11px 描述（`d.note`，空则不渲染）；`_CollectionGrid`（gap 4，无水平留白）占 `Expanded`；页脚：`PosterDivider` + 左「共收录 N 张」（数字用 `posterSerifEn` 金强调）+ 右 `d.dateText`。
- `clMini` 极简网格（square）：顶部行 `LUMIRA`(goldDeep 字距 3)+右 `如画`(text3)；17px 衬线标题 + 10px 描述；`_CollectionGrid`（左右 24px 留白、gap 3）占 `Expanded`；页脚「共收录 N 张 · dateText」+ 右 slogan「如画 · 记录每一帧光影」。
- `clFilm` 胶片拼贴（ratio34）：暖米径向渐变背景 + 底部轻晕影（同色系透明，非玻璃）；品牌行；20px 衬线标题；手写日期 `d.dateText`（`fontFamilyFallback: ['Kaiti SC','STKaiti','楷体']`）；拍立得拼贴区 `Expanded`：取前 3 张，`1 大（宽 74%，rotate -1.6°，白框+底部 caption 条）+ 下方 2 小（各宽 44%，rotate +2°/-2°，带 caption）`；张数 1→仅 1 大、2→1 大+1 小；caption 无数据时保留空白条（不显示文案）；页脚虚线分隔 + 左「共收录 N 张」+ 右「如画 LUMIRA」。
- `clAlbum` 画册封面（square + ratio34）：`Stack`；背景层 `thumbBuilders!.first`（不足 1 张时用 `PosterPalette.surfaceAlt` 占位）全幅 `BoxFit.cover`（`LayoutBuilder` 取画布尺寸）；压暗渐变 `rgba(black) 0.10→0.18→0.82` 自上而下（`Colors.black.withOpacity`，合法例外）；前景：顶部品牌行（`LUMIRA` 用 `Color(0xFFF3E3C2)` 亮金 + `如画 · 精选集` 白 62%）、中部 `Spacer`、底部 24px 衬线标题（`Color(0xFFFFF8EC)` 字距 4）+ 46px 金色渐隐短线 + 描述（白 72%）+ 页脚「共收录 N 张」（亮金数字）+ slogan「记录每一帧光影」。

**Steps:**
- [ ] 2.1 阅读 `checkin_poster_styles.dart`（模板范式）、`poster_common.dart`（色板/文本）、`docs/design/collection_poster_mockup.html`（视觉基准）。
- [ ] 2.2 写失败测试 `test/features/profile/collection_poster_styles_test.dart`（仿 `checkin_poster_generator_test.dart` 的 `_pumpSteel`）：
  - 注册断言：`stylesFor(collection, square)` 含 `{clMag, clMini, clAlbum}`（3 个）；`stylesFor(collection, ratio34)` 含 `{clMag, clFilm, clAlbum}`（3 个）。
  - 渲染断言：对 4 个样式 × 关键 thumb 数（0/1/2/3/4/9）在 `FittedBox` 无界约束下 `pump` 后 `takeException()` 为 null，且 `clFilm` 最多取前 3 张。
  - `PosterStyleData` 用 `ratio: PosterRatio.square`（clFilm 用 ratio34），`photoCount` 传真实数（如 12），验证「共收录 12 张」文案出现（`find.textContaining('共收录')`）。
- [ ] 2.3 运行新测试，确认因缺少实现文件而失败（红）。
- [ ] 2.4 实现 `collection_poster_styles.dart`：`_kCkW`、`collectionPosterStyles()`、4 个 `_build*`、共享 `_CollectionGrid`、胶片 caption 小部件、`_ClCount` 取数 helper（`d.photoCount > 0 ? d.photoCount : builders.length`）。
- [ ] 2.5 运行新测试，全部转绿；`flutter analyze` 通过。
- [ ] 2.6 手工核对：对照 mockup v2，1/2/4/9 张在 square 与 ratio34 下网格填满无溢出、`clFilm` 前 3 张错落拼贴正确。

**Verify:** `flutter test test/features/profile/collection_poster_styles_test.dart` 全绿；`flutter analyze` 无告警。

---

### Task 3: 注册 collection 样式到 PosterStyleRegistry

**Files:**
- Modify: `lumira_app_flutter/lib/shared/widgets/poster/poster_style_registry.dart`
- Test: `lumira_app_flutter/test/shared/widgets/poster/poster_style_registry_test.dart`

**Interfaces:**
- Consumes: `collectionPosterStyles()`（Task 2 产物）。
- Produces: `PosterStyleRegistry.stylesFor(PosterKind.collection, ratio)` 返回对应样式；`defaultFor` 在 square/ratio34 均非空。

**Steps:**
- [ ] 3.1 在 `poster_style_registry.dart` 顶部 `import 'package:lumira_app_flutter/features/profile/widgets/collection_poster_styles.dart';`，并在 `_styles` 列表末尾追加 `...collectionPosterStyles()`（保持注册顺序：collection 样式排最后，不影响既有默认样式选取）。
- [ ] 3.2 扩展 `poster_style_registry_test.dart` 新增 group「collection」：square → `{clMag, clMini, clAlbum}`；ratio34 → `{clMag, clFilm, clAlbum}`；`defaultFor` 非空且 kind==collection；全 kind 遍历约束（`all()` 内 collection 样式 id 唯一）仍通过。
- [ ] 3.3 运行 registry 测试全绿；`flutter analyze` 通过。

**Verify:** `flutter test test/shared/widgets/poster/poster_style_registry_test.dart` 全绿。

---

### Task 4: 改造 _showSharePoster 走 showPosterWithStylePicker

**Files:**
- Modify: `lumira_app_flutter/lib/features/profile/pages/profile_collection_detail_page.dart`
- Test: `lumira_app_flutter/test/features/profile/profile_collection_detail_page_test.dart`

**Interfaces:**
- Consumes:
  - `PosterGenerator.showPosterWithStylePicker(context, tokens, title, kind: PosterKind.collection, ratio, data, shareSubject, shareText, fileNamePrefix)`。
  - `PosterStyleData`（`lib/shared/widgets/poster/poster_style_types.dart`）。
  - `checkinPhoto`（`lib/features/checkin/widgets/checkin_poster_widgets.dart`）构建 `thumbBuilders`。
  - `PosterRatio`（`lib/shared/widgets/poster/poster_ratio.dart`）。
- Produces: 精选集海报样式切换 Sheet（含 4 版式切换条 + 保存相册 + 分享）。

**Steps:**
- [ ] 4.1 阅读 `_showSharePoster`（现为 `PosterGenerator.showPoster` + `CollectionPosterContent`）。
- [ ] 4.2 先改失败测试（`profile_collection_detail_page_test.dart`）：「点击导出九宫格拼图显示 SnackBar」用例断言 `'导出功能即将上线'` 已过时（页面早已走 `showPoster`，该断言当前即已失真），改为断言样式选择 Sheet 打开：`find.text('保存到相册')`、`find.text('分享海报')`、`find.text('选择版式')` 各 `findsOneWidget`。注意：测试环境 `pumpAndSettle` 在此仓库 Flutter 版本会 hang，沿用页面现有 `pumpAndSettleCompat`（仅 `pump()`）；如 Sheet 动画未完成导致断言不稳，改用固定次数 `pump(const Duration(milliseconds: 120))`（底部 Sheet 无 BackdropFilter，可安全推进时间），并在注释说明原因。
- [ ] 4.3 运行该测试确认失败（红）。
- [ ] 4.4 实现 `_showSharePoster` 新逻辑：
  - 计算 `photos`（`data.photos`）前 9 张 url 列表：`url = p.dataUrl ?? p.filePath`，过滤空串。
  - `thumbBuilders = urls.map((u) => (double w, double h) => checkinPhoto(url: u, tokens: tokens, width: w, height: h)).toList()`（`tokens = ref.read(themeTokensProvider)`）。
  - `ratio = urls.length <= 4 ? PosterRatio.square : PosterRatio.ratio34`（智能默认）。
  - `title` 回退：`collection.name.isEmpty ? '我的精选集' : collection.name`；`note` 用 `collection.description ?? ''`；`dateText` 用 `DateFormat('yyyy.MM.dd').format(...)`；`category` 缺省 `'LUMIRA COLLECTION'`；`photoCount: collection.photoCount`；`qrData/qrHint/qrSub` 空；`authorName` 空；`photoBuilder` 用首张 url 兜底（`checkinPhoto`）以防某样式引用。
  - 调 `PosterGenerator.showPosterWithStylePicker(...)`，`title: '精选集海报'`，`shareSubject/shareText` 沿用现值，`fileNamePrefix: 'lumira_collection_${collection.name}'`。
  - 移除对 `CollectionPosterContent` 的 import/使用。
- [ ] 4.5 运行详情页测试全绿；`flutter analyze` 通过。

**Verify:** `flutter test test/features/profile/profile_collection_detail_page_test.dart` 全绿（含 8 主题 × 4 UIStyle 稳定性用例不回退）。

---

### Task 5: 删除死代码 collection_poster_generator.dart

**Files:**
- Delete: `lumira_app_flutter/lib/features/profile/widgets/collection_poster_generator.dart`

**Steps:**
- [ ] 5.1 `Grep` 全仓确认 `CollectionPosterContent` / `collection_poster_generator` 已无任何引用（Task 4 已移除页面唯一引用）。
- [ ] 5.2 删除该文件。
- [ ] 5.3 `flutter analyze` 通过，无「未使用/缺失 import」告警。

**Verify:** `flutter analyze` 通过；`Grep` 无残留引用。

---

### Task 6: 全量验证

**Files:**
- Verify-only（不新增/修改）：相关测试与真机清单。

**Steps:**
- [ ] 6.1 `flutter analyze`（零告警）。
- [ ] 6.2 运行相关测试套件：`test/shared/widgets/poster/poster_style_registry_test.dart`、`test/features/profile/collection_poster_styles_test.dart`、`test/features/profile/profile_collection_detail_page_test.dart`、`test/features/checkin/checkin_poster_generator_test.dart`、`test/poster_sheet_screenshot_test.dart`（golden 若本机无基线则跳过或以 `--update-goldens` 本地比对）——全部通过。
- [ ] 6.3 真机/模拟器验证清单：
  - 精选集照片数 1/2/4/5/9 各开一次「导出九宫格拼图」：默认比例正确（≤4→1:1、≥5→3:4），Sheet 内左右滑动可切换 4 版式，无溢出、无拉伸、无崩溃。
  - 精选集真实收录数 >9（如 12 张）时，页脚显示「共收录 12 张」且海报只展示前 9 张。
  - 描述为空、名称为空、照片加载失败（断网）时各版式正常降级（占位/隐藏文案）。
  - 导出 PNG ≥1080px 宽、分享到社交平台内容完整清晰。
  - 在暖白·金 / 莫兰迪 / 浓墨 / 玫瑰金主题下导出外观一致（固定 PosterPalette，不随主题变化）。

**Verify:** 上述命令与真机清单全部通过后，向用户汇报成果并请求验收。

---

## 验收标准（对应设计文档 §7）

- 精选集详情页点「导出九宫格拼图」弹出样式切换 Sheet，可左右滑动切换 4 套版式（含智能默认比例）。
- 1-9 张图片全部完整显示、无裁切溢出；第 9 张后不显示；胶片拼贴仅取前 3 张。
- 颜色统一取自 `PosterPalette` 固定品牌色板（画册封面压暗遮罩为合法黑透明例外）。
- 导出 PNG ≥1080px 宽，分享内容完整清晰。
- `flutter analyze` 通过；无新增未使用代码；既有 registry / checkin / 详情页测试不回退。
