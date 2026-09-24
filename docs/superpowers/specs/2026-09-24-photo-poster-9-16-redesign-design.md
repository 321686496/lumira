# 如画 · 9:16 照片分享海报重设计（三方向九款）

> **状态更新（2026-09-24）：本九款方案已被「最终三款」取代。** 用户在九款实现 +
> v11 新四方向探索后，最终仅选定三款：**满版照片**（源自
> `docs/design/poster_mockup_selected.html` stage2·方向1）、**竖排刊**、**立轴**
> （后两者即本文 §4 的 ⑥/⑦），视觉基准为
> `docs/preview/poster-9-16-preview-v12.html`；其余六款（①-⑤、⑧、⑨）已从代码删除。
> 实现计划：`docs/superpowers/plans/2026-09-24-photo-poster-9-16-final-three.md`。
> 本文以下正文作为九款探索过程的历史记录保留。

- 日期：2026-09-24
- 状态：已批准（用户选定「都来」——三方向九款全部实现）
- 视觉基准：`docs/preview/poster-9-16-preview-v10.html`（三方向九款 HTML 设计稿，picsum 示例图）

## 1. 背景与问题

相册照片分享海报 fullScreen（9:16）比例现有三款：d1 满版照片 / dN 多图拼贴 / dL 对角动态。存在两个明确痛点：

1. **文字被照片压住**：标题 / 作者 / 二维码直接叠在照片上，遮挡且看不清；
2. **一张海报出现两张图**（dN 拼贴款）：观感怪异，与「一张照片一张海报」的分享心智不符。

用户两次关键修正：

- 「注意里面的照片是 9:16 比例」——照片必须按原生 9:16 呈现，不裁切；
- 「注意，照片比例是 9:16，海报比例也是 9:16」——**海报画布本身也必须是 9:16**。

## 2. 设计约束（硬性）

### 2.1 画布与照片

- 画布：**300 × 533.33（9:16）**，与照片同比例，社交分享全屏展示不裁切；
- 实现需将 `posterFixedHeight(fullScreen)` 由 `760 × (300/330) ≈ 691` 调整为 `300 × 16/9 ≈ 533.33`（`poster_common.dart`），并检查所有引用处（分享页画布、缩略图、导出链路）不按旧高度写死；
- 照片：原生 9:16，容器本身即 9:16 + `object-fit: cover`，**零裁切零变形**；
- **一张海报只用一张照片**，拼贴双图不再回归。

### 2.2 品牌语言（固定，不随主题切换）

- 色板 `PosterPalette`：surface `#FDFBF7` / surfaceAlt `#F6F1E8` / gold `#C9A96E` / goldDeep `#B08D4F` / ink `#1A1A1A` / text2 `#6B645C` / text3 `#8E867B` / line `rgba(201,169,110,.32)`；
- 标题一律思源宋体（`posterSerif`），英文期号用 Georgia（`posterSerifEn`）；
- 品牌符号 `PosterLogo`（取景器 + 对角光束 + 对焦点）；
- 二维码 `PosterQr`（高分辨率矢量渲染，可被 App 扫一扫识别）；
- 发丝线一律金色 1px（`PosterPalette.line`）；
- 禁止：emoji、金色纸边框（整幅海报包金边）、双向浮雕阴影、完全居中的大段文字。

### 2.3 文案语义（与现有一致，不新增功能）

| 槽位 | 内容 |
| --- | --- |
| kicker | LUMIRA · 如画出品 |
| 标题 | 晴空田园少女（模板名，示例） |
| 分类 | 自然光 · 清新治愈 · 人像写真 |
| 落款 | @小满 · 用「如画」拍摄 |
| 二维码 | 长按识别 / 查看高清原图 |
| 品牌脚 | LUMIRA · 如画 + 如你所见，皆成画卷 |

- 9:16 画布高度收紧，二维码副文案「打开如画 · 保存原图」暂并入主提示两行（设计文档登记，实现时同步登记后续优化）；
- 方向二 / 方向三新增的刊头、VOL 期号、图注、题跋、小印均为**排版元素**，不引入任何新功能。

## 3. 三方向九款总览

用户决定：**九款全部实现**，替换现有 d1 / dN / dL，照片海报样式选择由 3 款扩为 9 款（3 方向 × 3）。

| # | 名称 | 方向 | 一句话结构 |
| --- | --- | --- | --- |
| ① | 满幅净版 | 一 · 净版 | 照片满幅 + 底部 160px 暖白实底信息带 |
| ② | 画册相框 | 一 · 净版 | 金线相框装裱 9:16 照片的画册内页 |
| ③ | 浮卡叠影 | 一 · 净版 | 照片满幅 + 白色信息卡悬浮叠底 |
| ④ | 刊头装裱 | 二 · 画刊 | 杂志刊头 + VOL 期号 + 金线装裱 + 图注 |
| ⑤ | 双轨夹窗 | 二 · 画刊 | 上下双轨（刊头轨 / 信息轨）夹住照片窗 |
| ⑥ | 竖排刊 | 二 · 画刊 | 左侧竖排衬线标题轨 + 右侧照片 |
| ⑦ | 立轴 | 三 · 画卷 | 天头 / 裱边画心 / 地头（品名 + 题跋 + 款行小印） |
| ⑧ | 诗塘 | 三 · 画卷 | 顶部题字面板（诗塘）+ 画心 + 款行尾轨 |
| ⑨ | 对题 | 三 · 画卷 | 左题跋栏 + 右画心并置 + 尾轨 |

方向气质：**净版**干净现代、社交分享友好；**画刊**杂志编辑感；**画卷**装裱书卷气，最贴品牌名「如画」与标语「如你所见，皆成画卷」。

## 4. 各款详述

以下尺寸均为 300 × 533.33 画布下的逻辑像素；标注「flex」的尺寸由布局剩余空间按 9:16 推导，HTML 稿实测值供实现对标。

### ① 满幅净版（替代 d1 / dL）

- 照片 `position: absolute; inset: 0` 满幅，零叠字；
- 底部信息带：高 160px，`surface` 实底 + 顶部 1px 金线，padding 14/24/12；
  - topline：kicker（左）+ 标语「如你所见，皆成画卷」（右）；
  - title 24px 衬线；
  - cat 9px；
  - bottomrow（`margin-top:auto` 贴底）：author（avatar 18 + @小满 + 落款）｜QR mini（36px + 「长按识别 / 查看高清原图」两行）。

### ② 画册相框（替代 dN）

- 画布 padding 20；
- toprow：`PosterBrandRow`（logo + LUMIRA + 如画）｜`VOL.01`（Georgia 9px）；
- frame：**172 × 305.78**，1px 金线装裱，居中，`margin: 12px auto 0`；
- kicker / title 22px / cat；
- bottomrow：author｜QR mini；
- foot：金线 + `LUMIRA · 如画` + 标语。

### ③ 浮卡叠影（新增）

- 照片满幅；
- 悬浮白卡：left/right 22、bottom 18，白底、1px 金线、圆角 16、padding 18×20、单层柔和投影（`0 16px 36px -16px rgba(70,55,30,.45)`，非双向浮雕）；
- 卡内：kicker / title 22px / cat / author / 1px 金线 divider / bottomrow（QR mini｜footmini 两行小字）。

### ④ 刊头装裱

- 画布 padding 18/22/14；
- 刊头 mast：`PosterBrandRow`（logo 16 + LUMIRA 15px 墨色 + 如画）｜右侧期号两行（`VOL.01` 金 + `第 028 期 · 2026 秋` text3）；
- 刊头下 1px 金线；
- frame：flex 推导 9:16（HTML 实测约 **172 × 306**），1px 金线，居中；
- 图注：「摄于九月晴午 · 光落在草尖上」8px text3；
- kicker / title 24px / cat / bottomrow（author｜QR mini）/ foot。

### ⑤ 双轨夹窗

- 上轨 rail-top：高 40px，`PosterBrandRow`｜标语｜`VOL.01` + `第 028 期`，底部 1px 金线；
- 中段 stage：照片窗 win 拉伸 9:16（HTML 实测约 **202 × 359**），1px 金线 + 轻投影（`0 12px 26px -16px rgba(70,55,30,.4)`）；
- 下轨 rail-bot：顶部 1px 金线，padding 12/22/14；kicker / title 20px / cat / bottomrow（author｜QR mini）。

### ⑥ 竖排刊

- 刊头 head：高 34px，`PosterBrandRow`｜`VOL.01` + `第 028 期`，底部 1px 金线；
- body：左侧 spine 宽 44px（右侧 1px 金线），自上而下：竖排 title（衬线 20px、letter-spacing 7）→ 36px 金线 → 竖排标语（7.5px text3）；
- 右侧 main：照片 flex 9:16（HTML 实测约 **203 × 361**，1px 金线）/ kicker / cat / bottomrow（author｜QR mini）/ foot；
- 竖排实现：Flutter 侧用逐字 `Column`（每字一个 `Text`，字距用 `SizedBox(height:)` 控制，衬线走 `posterSerif`），不依赖 RotatedBox，保证字距与基线可控；

### ⑦ 立轴

- 天头 sky：高 46px，`PosterBrandRow`｜右侧两行（标语 8px + `No.028 · 2026 秋` 金 8px Georgia），底部 1px 金线；
- 画心 heartwrap：heart 拉伸 9:16（HTML 实测约 **172 × 306**），surfaceAlt 裱边（padding 5）+ 1px 金线；
- 地头 ground（padding 0/22/12）：
  - title 20px 衬线；
  - cat；
  - 题跋：「九月晴午，光落草尖，见之成卷。」衬线 9.5px text2、letter-spacing 2；
  - 款行 sign：avatar 18 + @小满 + 落款｜小印（22 × 22 金框圆角 4，竖排「如 / 画」两字）；
  - bottomrow：QR mini｜footmini。

### ⑧ 诗塘

- 诗塘 pond（顶部面板）：surfaceAlt 底 + 底部 1px 金线，padding 14/22/13；
  - toprow：`PosterBrandRow`｜`No.028 · 2026 秋`；
  - kicker / title 24px / cat；
  - sig：题跋「九月晴午，光落草尖，见之成卷。」（左）｜小印（右，底部对齐）；
- 画心 heartwrap：heart 拉伸 9:16（HTML 实测约 **172 × 306**，1px 金线）；
- 尾轨 tail：顶部 1px 金线，padding 10/22/12；bottomrow：author｜QR mini。

### ⑨ 对题

- 刊头 head：高 34px，`PosterBrandRow`｜`No.028 · 2026 秋`，底部 1px 金线；
- body：左题跋栏 col 宽 88px（右侧 1px 金线，padding 16/12，gap 8）：
  - kicker 8.5px / title 19px 衬线 / 题跋 8.5px text2；
  - 弹性 spacer；
  - 小印 22 × 22；
  - author（avatar 16 + @小满）；
- 右侧 main：画心 heart 固定 **184 × 327.11**，1px 金线；
- 尾轨 tail：顶部 1px 金线；cat（左）｜QR mini（右）。

## 5. 组件与代码改动点

| 文件 | 改动 |
| --- | --- |
| `lib/shared/widgets/poster/poster_common.dart` | `posterFixedHeight(fullScreen)` 改为 `300 × 16/9 = 533.33`；核查引用处不写死旧高度 |
| `lib/shared/widgets/poster/poster_styles_shared.dart` | 按需补充共享子组件（QR mini 组合、footmini、题跋文本、款行等），供九款复用 |
| `lib/shared/widgets/poster/photo_poster_styles.dart` | 删除 d1 / dN / dL，重写为九款（①～⑨）；样式枚举 / 注册表同步更新，缩略图走 `PosterThumbnailScope` |
| `lib/shared/widgets/poster/`（新增） | `PosterSeal`：22 × 22 金框圆角 4 小印，竖排两字（默认「如 / 画」），色板取 goldDeep |
| 样式选择条 UI | 由 3 款缩略卡扩为 9 款（3 方向分组展示，组名：净版 / 画刊 / 画卷） |

复用既有组件：`PosterCanvas` / `PosterBrandRow` / `PosterKicker` / `PosterTitle` / `PosterCatText` / `PosterAuthorRow` / `PosterQr` / `PosterBrandFoot` / `PosterLogo` / `posterSerif` / `posterSerifEn` / `posterPlain`。

## 6. 不做的事（YAGNI）

- 不新增海报比例、不新增任何功能（氛围写真、电影海报、AI 一键改图等一律不加）；
- 不引入新颜色 / 新字体；海报固定品牌色板的既有例外不变；
- 不做双图拼贴回归；
- 二维码副文案「打开如画 · 保存原图」暂不上线（画布高度限制），实现时登记 `docs/future-optimizations.md`；
- 不动 uni-app 旧项目。

## 7. 验证

- `flutter analyze` + 现有测试全绿；
- 九款逐款与 HTML 设计稿截图比对（结构 / 字号 / 间距 / 照片比例）；
- 海报为固定品牌色板，重点验证：无文字溢出、无遮挡、照片 9:16 零变形、二维码可被扫一扫识别；
- 样式选择条 9 款缩略卡渲染正常（缩略作用域下 QR 为品牌占位图形）。

## 8. 参考

- 设计稿：`docs/preview/poster-9-16-preview-v10.html`
- 现有实现：`lumira_app_flutter/lib/shared/widgets/poster/poster_common.dart`、`photo_poster_styles.dart`、`poster_styles_shared.dart`、`poster_ratio.dart`
- 品牌资产：`assets/logos/lumira/logo-lumira-symbol.svg`
