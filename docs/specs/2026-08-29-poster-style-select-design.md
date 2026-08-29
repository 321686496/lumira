# 分享海报样式选择 设计

> 日期：2026-08-29
> 范围：Flutter 客户端（`lumira_app_flutter/`）
> 关联：`shared/services/poster_generator.dart`、`shared/widgets/poster/template_poster_widgets.dart`、
>       `features/gallery/pages/gallery_detail_page.dart`、`features/templates/pages/templates_detail_page.dart`
> 参考：`docs/design/poster_mockup_selected.html`（已选 26 款样式汇总，含 5 比例 × 模板/照片）

## 背景动机

App 内可调整三种照片比例（全屏 9:16、3:4、1:1），横屏拍摄时会旋转（19:6、4:3、1:1），共 5 种比例。
用户希望**导出/分享海报时可选样式**：为每种比例提供多款分享海报样式（模板详情海报 + 照片详情海报），
点击「导出海报 / 分享海报」后用户可先选择样式，再导出 / 分享。

品牌基调沿用已确认的 LUMIRA 原生风格：暖白纸感底 `#FDFBF7` + 金色细线 `#C9A96E/#B08D4F` +
衬线大标题（宋体/思源宋体）+ 金色 L 角标 + 居中留白。**分享海报为导出类品牌资产，固定品牌色板，
不随 App 主题/UI 风格切换**（此为对「样式跟随主题」铁律的唯一例外，属用户明确要求）。

## 核心结论

| 维度 | 说明 |
|---|---|
| 比例归类 | 照片宽高比 → 5 类：`fullScreen(9:16)` / `ratio34(3:4)` / `square(1:1)` / `ratio169(16:9)` / `ratio43(4:3)`（19:6 归入 16:9 宽幅） |
| 样式注册表 | `PosterStyleRegistry` 按 `kind(template/photo)` + `ratio` 返回可选样式列表 |
| 样式数 | 模板 15 款 + 照片 11 款（16:9/4:3 照片各有 2 款「待选」，暂以已选样式填充） |
| 交互 | 海报预览 Sheet 顶部为「样式切换条」，实时切换预览；导出/分享按当前选中样式出图 |
| 兼容 | 保留 `showPoster`（打卡/成就/合集等其它海报继续使用），新增 `showPosterWithStylePicker` |

---

## 1. 比例识别（poster_ratio.dart）

按照片宽高比 `aspect = width / height` 归类：

| 区间 | PosterRatio | 说明 |
|---|---|---|
| `aspect >= 1.6` | `ratio169` | 16:9 / 19:6 宽幅横图 |
| `1.15 <= aspect < 1.6` | `ratio43` | 4:3 横图 |
| `0.87 <= aspect < 1.15` | `square` | 1:1 方图 |
| `0.65 <= aspect < 0.87` | `ratio34` | 3:4 竖图 |
| `aspect < 0.65` | `fullScreen` | 9:16 全屏竖图 |

配套异步解析：
- `posterRatioFromFile(String path)`：解码本地图片文件取宽高。
- `posterRatioFromTemplateCover(TemplateRecord)`：从 `coverData`(base64) / `cover`(url/asset) 解码取宽高，
  解析失败回退 `fullScreen`。

## 2. 样式注册表（poster_style_registry.dart）

```dart
enum PosterKind { template, photo }

class PosterStyle {
  final String id;          // 如 'pA' / 'dN' / 'pE'
  final String name;        // 如 '经典面板' / '相纸卡片'
  final String groupName;   // 如 '样式一 · 经典面板'
  final PosterKind kind;
  final Set<PosterRatio> ratios;   // 支持的图片比例
  final Widget Function(PosterStyleData data) builder;
}

class PosterStyleData {
  final PosterRatio ratio;
  final String title;        // 模板名 / 照片名
  final String category;     // 如 '人像写真 · 摄影模板'
  final String qrData;       // 二维码内容
  final String qrHint;       // '长按识别 · 查看完整模板'
  final String qrSub;        // '打开如画，拍出同款'
  final String shareText;    // 分享文案（部分样式展示）
  final String authorName;   // 照片海报的 '@小满'
  final Widget Function(double w, double h) photoBuilder; // 照片按尺寸渲染
}
```

`PosterStyleRegistry.stylesFor(kind, ratio)` 返回该比例下可用样式；`defaultFor(kind, ratio)` 返回首个。

## 3. 共享积木（poster_common.dart）

固定品牌色板 + 通用小部件：

- 色板：`surface #FDFBF7`、`surfaceAlt #F6F1E8`、`gold #C9A96E`、`goldDeep #B08D4F`、
  `ink #1A1A1A`、`text2 #6B645C`、`text3 #8E867B`、`line rgba(201,169,110,.32)`。
- `PosterLogo`：CustomPainter 复刻四角框 logo（金色描边 + 角标 + 圆点）。
- `PosterBrandRow` / `PosterBrandFoot`：LUMIRA · 如画 + 标语「如你所见，皆成画卷」。
- `PosterQr`：qr_flutter 的 `QrImageView` 封装（方形、黑色模块）。
- `PosterAvatar`：圆形首字头像（照片海报「满」）。
- 字体：中文衬线（系统宋体 / `serif`），英文衬线 `Georgia`。

## 4. 模板样式（template_poster_styles.dart，15 款）

| 比例 | 样式 |
|---|---|
| 9:16 | `pA`经典面板 · `pC`相纸卡片 · `s3`全出血浮层 |
| 3:4  | `pA`经典面板 · `pC`相纸卡片 · `dK`居中极简 |
| 1:1  | `v2a`取景器角标 · `dE`国风水墨 · `dD`电影海报 |
| 16:9 | `pA`经典面板 · `p3`画廊陈列 · `pE`大标题压图 |
| 4:3  | `pA`经典面板 · `stage1`早期手绘 · `pE`大标题压图 |

- `pA` 支持 4 种比例（9:16 / 3:4 / 16:9 / 4:3），照片区按比例撑高 + 顶部品牌浮层 + 底部信息面板。
- `pC` 支持 5 种比例（相纸卡片：白底卡 + 胶带贴纸 + 照片 + 手写标题 + 二维码条）。
- `pE` 支持 16:9 / 4:3（暗底大图压字 + 右上角小二维码）。
- `v2a` / `stage1` 为原静态图方案的代码复刻。

## 5. 照片样式（photo_poster_styles.dart，11 款）

| 比例 | 样式 |
|---|---|
| 9:16 | `d1`满版照片 · `dN`多图拼贴 · `dL`对角动态 |
| 3:4  | `d3`相纸拼贴 · `dA`取景器镜头 · `s1`大图出血+面板 |
| 1:1  | `pC`相纸卡片 · `dC`几何构成 · `dM`底图倒置 |
| 16:9 | `pC`相纸卡片（横版） |
| 4:3  | `pC`相纸卡片（横版） |

照片海报统一落款 `@小满`，二维码语义为「查看高清原图」。
`dN` 多图拼贴仅有单张成品照片，副图以同图不同裁切呈现。

## 6. 样式选择 Sheet（poster_style_picker.dart）

海报预览 Sheet 顶部新增横向「样式切换条」：

- 按 `kind` + `ratio` 从注册表取样式列表；
- 每项为一个迷你样式卡（小尺寸实时渲染 + 样式名 + 选中态金边）；
- 点击切换当前预览样式（`RepaintBoundary` 捕获当前样式）；
- 底部保留「生成海报 / 导出海报 / 分享海报」三按钮，按当前样式出图。

## 7. 生成器改造（poster_generator.dart）

新增入口（保留原 `showPoster`）：

```dart
static Future<void> showPosterWithStylePicker({
  required BuildContext context,
  required ThemeTokens tokens,
  required String title,
  required PosterKind kind,
  required PosterRatio ratio,
  required PosterStyleData data,
  required String shareSubject,
  required String shareText,
  required String fileNamePrefix,
})
```

内部 `_PosterSheet` 升级为 StatefulWidget 持有 `_selectedStyleId`，内容区实时按选中样式重建。

## 8. 页面接入

- `gallery_detail_page._onSharePoster`：由 `photo.filePath` 解析比例 → 构造照片 `PosterStyleData`（作者 @小满，二维码「查看高清原图」）→ 调 `showPosterWithStylePicker`。
- `templates_detail_page._goSharePoster`：由模板封面解析比例 → 构造模板 `PosterStyleData`（二维码「查看完整模板」）→ 调 `showPosterWithStylePicker`。

## 9. 测试

- `poster_ratio_test.dart`：比例区间边界归类（9:16 / 3:4 / 1:1 / 4:3 / 16:9 / 19:6）。
- `poster_style_registry_test.dart`：注册表按 kind + ratio 返回正确样式集合、默认样式存在。
