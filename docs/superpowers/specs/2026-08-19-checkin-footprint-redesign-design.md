# 探店足迹模块 UI 优化设计

日期：2026-08-19

## 背景

用户对 Flutter 端「探店足迹（checkin）」模块的 UI 不满意，尤其是足迹详情页。希望通过本次优化使其更有特色，走「精致手帐风」——iPhone 美学 + 莫兰迪柔和配色 + 渐变背景 + 非居中标题 + 大图优先 + 大圆角大留白卡片。

## 硬性约束

- **配色不硬编码**：所有颜色、阴影、字体一律来自 `appTheme.tokens`（`ThemeTokens`）+ `uiStyleProvider`（`UIStyle`），自动随 9 套主题 / 4 套 UI 风格切换。
- 仅黑色渐变遮罩（`Colors.black` withOpacity）例外，全主题通用，不属于主题色。
- 复用既有共享组件：`NeuCard`、`LumiraNav`、`LumiraToast`、`FadeUp`、`LumiraButton`、`LumiraProgress`。
- 主项目为 `lumira_app_flutter/`，不改 uni-app 原型。

## 涉及文件

- `lib/features/checkin/pages/checkin_detail_page.dart`（重点）
- `lib/features/checkin/pages/checkin_list_page.dart`
- `lib/features/checkin/pages/checkin_edit_page.dart`
- 复用 `lib/features/checkin/widgets/checkin_common.dart`、`../data/checkin_categories.dart`

---

## 详情页（重点）

### 沉浸式大封面
- 首张照片铺满屏幕宽度，顶部约占屏高 57%。
- AppBar 透明，前景按钮（返回/编辑/删除）改为**白色毛玻璃胶囊**：`ClipRRect` 圆角胶囊 + `Colors.black.withOpacity(0.18)` 底 + 图标用 `tokens.textInverse`。
- 封面叠加自上而下黑色渐变遮罩（`Colors.black.withOpacity`），叠放时文字用白色保证可读。
- 店名（`fontWeight.w700`、约 22）、评分星、分类 tag、「值得一去」徽标、相对日期叠放在封面底部。
- 无照片时：用分类 `category.iconBgColor` 做大渐变封面占位，中央放分类 `category.icon`。
- 标题改为动态店名呈现（保留 AppBar `足迹详情` 语义，或隐藏标题仅保留按钮——实现时以可读性决定）。

### 缩略图带
- 首图之外的照片：封面下方一条横向圆角缩略图（约高 84、圆角 12），选中项品牌描边，点击切换封面主图。

### 信息卡（浮层）
- 地点、心得放入一张大圆角（`borderRadius 20`）`NeuCard`。
- 卡片顶部与封面用负边距重叠少许，形成「浮上来」的手帐感；大留白、信息层级清晰。
- 日期信息已上移到大封面底部，卡片内不重复。

---

## 列表页

- 顶部渐变背景（参考 `_BackgroundDecoration` 径向渐变模式，但用 `tokens`）+ 非居中标题「探店足迹」。
- 统计卡精细化：每个指标加分类图标（足迹总数 / 好评店铺 / 平均评分 / 今年新增）。
- 足迹卡片：封面图更大更圆润，日期做成胶囊，评分强调；保留分享按钮与跳转逻辑。

---

## 编辑页

- 表单控件统一圆角与间距，顶部标题非居中，按钮与详情风格一致。
- 改动克制，聚焦视觉一致性，不改变表单字段与交互逻辑。

---

## 验收标准

- 三个页面视觉风格统一为「精致手帐风」，与全局主题/UI 风格任选一套均自适应、无硬编码色。
- 详情页实现「大封面 + 缩略图 + 浮层信息卡」。
- 原有交互（编辑、删除、分享、跳转、分类筛选、排序）全部保留。