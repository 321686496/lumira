# Splash 启动页视觉优化设计

> 日期：2026-09-23 ｜ 模块：`lumira_app_flutter/lib/features/splash/pages/splash_page.dart`

## 目标

在**不改变跳转/认证/合规逻辑**的前提下，重排 Splash 视觉，达成四项：

1. **去光晕、更克制**：删除 logo 背后的径向光晕圆（偏「AI 感」），收窄符号标所占版面。
2. **增强品牌层次**：用细金发丝线 + 更大标题/副标题对比，读出主次。
3. **状态区融入整体**：loading / 网络失败重试成为排版的一部分，而非悬空贴底。
4. **布局更精致**：底部加一行排版版权，垂直空间上下平衡。

## 约束（项目铁律）

- 视觉一律来自 `appThemeProvider`（`tokens`）+ `uiStyleProvider`，随设置切换，**禁止硬编码主题色**。
- 不混用不同 UI 风格的主题元素；背景保持纯 `tokens.canvas`，不叠风格渐变（避免玻璃/新拟态混搭）。
- Splash 是「纯色画布」语境 → 如使用组件走画布槽位，但本设计不新增浮层，仅排版。

## 设计说明

### 1. 布局主干（仍为居中 column）

```
[ 符号标 72dp ]            ← 去光晕，SizedBox 160→128
  细金分隔线 (brand 25%)    ← 新增发丝线 36dp 宽、0.8dp 高，圆角
  标题  26dp w600 字距-0.6%
  副标题 14dp textTertiary 字距 0.12em
（状态区，见 4）
（底部版权，见 5）
```

- 符号标 `LumiraLogo.symbol(size: 72)`，外层 `SizedBox` 收敛到 `128×128`，不加任何光晕/底托。
- 符号标与标题之间加入一条居中的**细发丝线**：`Container(width: 36, height: 0.8, color: tokens.brand.withOpacity(0.25))`，作为品牌层次衔接（发丝线语言，非新元素主题色）。

### 2. 文字组（信息层级加强）

- 标题「如画 Lumira」：`fontSize 26`、`w600`、`letterSpacing -0.06dp`、`height 1.3`，`textPrimary`。
- 副标题「如你所见，皆成画卷」：`fontSize 14`、`letterSpacing 0.12em`、`height 1.4`，`textTertiary`。
- 标题下间距由 6dp 调至 10dp，符号标下与分隔线间距 20dp，分隔线与标题间距 14dp —— 错落而非等距堆叠。

### 3. 去光晕实现

删除 `build()` 中 `Stack` 内的径向渐变 `Container`，`Stack` 改为直接包裹符号标（或退化为单 `SizedBox`）。

### 4. 状态区

- loading：`LumiraProgress.circular()` 保持，置于主 column 内、距文字组固定 `32dp`。
- failed：`网络连接失败` + `LumiraButton(primary, 重试)`，间距对齐 loading 槽位，不额外贴底。
- 实现上用一个 `SizedBox(height: 16)` 占位统一 loading/failed/无状态三态高度，避免切换闪跳。

### 5. 底部版权

- 主 column 外层包 `Column`，底部用 `Spacer` 推出，底部 `Padding(24)` 内放一行：
  `Design · 如画`（`fontSize 12`、`letterSpacing 0.06em`、`textTertiary`）。
- 版权行无需 FadeUp（避免与状态区动画抢注意），仅排版收尾。

### 6. 动画

- 保留 `FadeUp` 阶梯入场：符号标 0ms / 文字组 200ms；分隔线与文字组同一批，版权区不加动画。

## 改动范围

- 仅 `splash_page.dart` 的 `build()` 排版与尺寸。
- 不改认证、合规、路由、定时跳转逻辑。

## 验收

- 4 风格 × 各主题下：无光晕、无硬编码色、无玻璃/新拟态混搭。
- loading / failed / 无状态三态切换无高度跳动。
- 底部版权行在各机型 SafeArea 下不误触且不贴边。