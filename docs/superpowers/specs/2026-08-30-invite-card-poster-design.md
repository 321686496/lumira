# 邀请卡片分享海报设计（跟随当前 UI 风格）

> 日期：2026-08-30
> 范围：`lumira_app_flutter/`（Flutter，HarmonyOS 兼容）
> 设计稿：`docs/design/poster_mockup_invite.html`

## 背景与目标

现有「邀请有礼」页（`ProfileInvitePage`）点击「生成邀请卡片」会弹出旧版全屏海报弹层 `_InvitePosterSheet`
（`profile_invite_page.dart`）。该旧实现只是简单渐变底 + 大号二维码，**不区分 4 套 UI 风格、不提供分享**，
视觉与 mockup 差距大、交互弱。

本次将其优化为主题化的「邀请卡片分享海报」：

- 卡片信息结构/排版统一，仅在 **UI 风格**（neumorphic / flat / glass / female）间切换视觉语法。
- 卡片**严格跟随当前主题 + UI 风格**，不提供手动风格切换（用户已确认）。
- 操作按钮补齐为 **复制邀请码 + 保存到相册 + 分享海报**（用户已确认）。
- 画布比例 **竖版 3:4**（用户已确认）。

## 与已有海报系统的边界

App 已有 `poster_common.dart` 提供固定品牌色板 `PosterPalette`
（暖白 `#FDFBF7` + 金 `#C9A96E/#B08D4F` + 衬线标题），用于**模板/照片分享海报**——那是导出型品牌资产。

**邀请卡片不引入 `PosterPalette`**：按项目铁律「样式永远跟随设置里的 UI 风格 + 主题，禁止硬编码」，
邀请卡为 App 内可导出的**主题化卡片**，所有颜色/阴影/圆角/边框一律从 `appThemeProvider`
（`AppThemeData.tokens` / `.cardRadius` / `.cardShadow` / `.cardBorder` / `.surfaceAlpha`）+ `uiStyleProvider` 派生。

## 信息结构（4 套风格排版统一）

自上而下固定顺序：

1. **品牌行**：`LUMIRA`（英 + 字距）+ 金渐变细线（`flex 撑开`）+ `如 画`
2. **主标题**：`邀请好友 · 一起来拍照`
3. **副标题**：`和你一起，把生活拍成想要的样子`
4. **利益点 pill**：`好友首次激活，双方各得 +30 积分`（圆角胶囊）
5. **二维码区**（焦点居中）：白底方框 + 品牌描边（样式相关阴影）＋ `长按识别二维码 · 立即加入`
6. **邀请码块**：`我的邀请码` 标签 + `LUMIRA-XXXX` 大字号
7. **底部品牌脚**：`LUMIRA · 如画 · 记录每一帧美好`

## 四套风格视觉语法（全部用 ThemeTokens）

| 风格 | 卡片底 + 阴影 | 场景底（外画布） | 二维码框 | 邀请码块 / pill |
|---|---|---|---|---|
| **neumorphic** | `surface` + `shadowConvex`（双向浮雕） | 暖白 `canvas` 微渐变 + 金细边 | `surfaceAlt` 白底 + `shadowFloat` | 凹陷 `shadowConcaveSubtle` 于 `surfaceAlt`；pill 用 `brandSubtle` 底 + `brandDeep` 字 |
| **flat** | `surfaceAlt` + 细边（`divider`），无阴影 | `canvasDeep` 平渐变 + 金细边 | 白底 + 细边（直角略圆） | 白底 + 细边；pill 白底 + 细边 + `brandDeep` 字 |
| **glass** | 半透明 `glassFill` + `glassBorder` 白细边 + 顶部高光 | 复用 `GlassBackground` 彩色光斑透出 | 白 `0.85` 透明 + 白细边 + 柔影 | 半透明磨砂 + 白细边；pill 半透明白 + 白细边 |
| **female** | 复用 `appTheme.multiGradient`（微渐变 + 径向高光 + hairline 细边 + 品牌柔影） | 微渐变 + 径向氛围光 | 白底 + `brand` 细边 + 柔影 | 白 `0.7` 透明 + hairline；pill 白底 + `brand` 细边 + 柔和投影 |

细节约束：

- 二维码统一 `QrImageView(data: code)`，白底，模块色跟随 `tokens.textPrimary`（保证在各主题下可扫）。
- 顶部品牌行的「金线」在 neumorphic/flat 用 `brand` 渐变线；glass/female 用各自风格的白/品牌微染线。
- 主标题/副标题文字色用 `textPrimary` / `textSecondary`；涉及玻璃/女性浅底时保证对比度。
- 邀请码大字号用 `textPrimary`，等宽（`Courier New`）体现「码」感，符合项目既有风格。

## 组件拆分

### 1. `InvitePosterCard`（新文件 `lib/features/invite/widgets/invite_poster_card.dart`）

- 纯展示、style-aware：内部 `Ref` + `ref.watch(appThemeProvider)`、`uiStyleProvider`。
- 入参：`code`（`String`）。其余文案与固定结构内置。
- 整卡固定逻辑宽（约 `300` px）× 高（`300 * 4 / 3 = 400` px，3:4）。外层场景画布 + 内层卡片一体，均在 `RepaintBoundary` 内捕获。
- 不依赖 `PosterPalette`，不引入任何固定品牌色。

### 2. `showInvitePosterSheet(context, code)`（新文件 `lib/features/invite/widgets/invite_poster_sheet.dart`）

- 底部弹层：标题「邀请卡片」+ 关闭 + 卡片实时预览 + 三个操作按钮。
- 与 `PosterGenerator` 同款交互/视觉：FittedBox 完整预览 + `RepaintBoundary`；`kPosterExportWidth = 1080` 倍率出图。
- 三个操作：
  - **复制邀请码**：`Clipboard.setData` + 成功 toast。
  - **保存到相册**：复用 `PosterGenerator` 的导出能力（iOS/Android `SaverGallery.saveImage`，OHOS `MethodChannel('lumira/photo_saver')` 降级）。
  - **分享海报**：复用 `SafeShare.shareXFiles`（OHOS 降级剪贴板）。
- 为避免重复导出/分享实现，把「捕获 PNG / 写临时文件 / 保存 / 分享」的私有化逻辑收敛在本方案内，或抽取最小共用工具；以不破坏现有 `PosterGenerator` 调用方为前提。

### 3. 改造 `profile_invite_page.dart`

- 删除内联旧 `_InvitePosterSheet` 及其相关旧渲染。
- `_showInvitePoster(code)` 改为调用新的 `showInvitePosterSheet`。
- 保留「生成邀请卡片」按钮触发 `_generateInviteCard` → `repo.generate()` → 打开新弹层逻辑不变。

## 数据流

ProfileInvitePage._generateInviteCard  → repo.generate() → InviteCode.code
  → showInvitePosterSheet(context, code) → InvitePosterCard(code) 渲染（跟随当前风格/主题）
  → 复制 / 保存 / 分享（复用 PosterGenerator 能力）

邀请码与积分文案为静态（`+30 积分` 等沿用现有语义），不做后端改动。

## 错误处理

- `generate()` 失败沿用现有 ApiException toast + 离线兜底。
- 导出/分享失败沿用 `PosterGenerator` 现有 toast 文案与 OHOS 降级。

## 验证

- 4 风格 × 组合主题下 `flutter analyze` 通过。
- 新增 widget 测试：card 正确渲染 code / RepaintBoundary 可捕获 / 复制按钮回写剪贴板 / 二维码存在。
- 手动验证：iOS/Android 保存到相册、分享；OHOS 降级路径（`MissingPluginException`）。

## 不做（范围外）

- 不做四风格手动切换条（用户确认跟随当前风格）。
- 不做后端/邀请码文案改造。
- 不新增 PosterKind 注册（避免过度设计）。
