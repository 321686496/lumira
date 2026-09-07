# 拍摄预览页编辑体验改版 — 设计文档

> 日期：2026-09-07
> 模块：Flutter 客户端（`lumira_app_flutter/`）
> 状态：设计已确认，待实现

## 1. 背景与问题

拍摄后进入的照片预览页（[capture_preview_page.dart](../../lumira_app_flutter/lib/features/capture/pages/capture_preview_page.dart)，约 2830 行）当前交互复杂、编辑能力藏得深：

- **三档拖拽抽屉**（隐藏 → 1/2 屏 → 3/4 屏）承载编辑面板，操作路径长、可发现性差；1/2 档底部还塞了「心情/场景露出区」，3/4 档编辑面板被压到固定 176 高。
- 编辑面板用**文字 Tab**（色彩/细节/滤镜/裁剪旋转），与后期修图页（[gallery_edit_page.dart](../../lumira_app_flutter/lib/features/gallery/pages/gallery_edit_page.dart)）的「底部图标工具条 + 点选滑出面板」交互不一致。
- **对比按钮**藏在底部悬浮按钮组里（与保存/编辑/删除并排），编辑时想看修改前效果需要先收起抽屉，割裂。
- **滤镜 Tab 未传 `previewImagePath`**，滤镜只能显示降级文字 Chip，看不到真实照片滤镜效果。
- 心情/场景标记、生成对比图/EXIF 卡片、保存到系统相册/删除等非编辑功能与编辑功能混在抽屉/悬浮组里，层次不清。

## 2. 目标

1. 编辑交互**对齐后期修图页**：底部图标工具条（色彩/细节/滤镜/裁剪/重置）+ 点选滑出参数面板。
2. 新增**照片右上角对比按钮**（与后期修图页同款），点击切换「修改前（烘焙基线）/ 修改后」，编辑全程随手可看。
3. 心情/场景保留为**工具条上方紧凑 pill 行**（横向滑动），不抢编辑空间。
4. 非编辑操作归位：保存到系统相册/删除收进**顶部导航**；生成对比图/EXIF 卡片收进**分享 Sheet**。
5. 视觉保持**深色沉浸式**（照片全屏黑底），工具条/面板用主题 token 派生的深色质感。
6. 删除三档抽屉机制（约 500 行），页面代码显著瘦身。

## 3. 改版后布局

```
┌─────────────────────────────────┐
│ ←  照片预览   🗑 💾 ↧ ⇪ [保存]  │  顶部导航（透明浮层；保存 pill 仅编辑态出现）
│                                 │
│                                 │
│         照片全屏区               │      ☯ ← 右上角对比按钮（40×40 圆形悬浮）
│    （PhotoView 缩放/滑动历史）    │
│                                 │
│                                 │
├─────────────────────────────────┤
│ 😊开心 · 平静 · 元气 | 街拍 · 室内│  ① 心情/场景紧凑 pill 行（横向滑动）
├─────────────────────────────────┤
│  🎨    ✨    🔄    ⛶    ↺      │  ② 图标工具条（色彩/细节/滤镜/裁剪/重置）
│ 色彩  细节  滤镜  裁剪  重置      │
├─────────────────────────────────┤
│  曝光      ●———————       +8   │  ③ 参数面板（点选工具后 AnimatedSize 滑出，
│  对比度    ——●—————       +5   │     再点同工具收起；高度与后期修图页一致）
└─────────────────────────────────┘
```

- 照片区底部随面板展开动态收缩（`AnimatedContainer` 过渡），面板高度：色彩/细节 160、滤镜 264、裁剪 328（与后期修图页相同）。
- 单击照片：面板展开时先收面板；否则切纯净模式（隐藏全部 UI，再单击恢复）。

## 4. 各区域详细设计

### 4.1 顶部导航

- 保留：返回、标题「照片预览」、分享（弹出底部 Sheet）。
- 新增收进顶栏：删除图标、保存到系统相册图标（原悬浮组操作）。
- 编辑态（`_isEdited == true`）时出现金色渐变「保存」pill（沿用现有 `_PreviewNav.showSave` 逻辑）。
- 顶栏图标叠在照片上：白色 `textInverse` 图标 + 半透明底（与现有拍照页顶栏一致）。

### 4.2 对比按钮（新增核心）

- 位置：照片区右上角（SafeArea 内），40×40 圆形。
- 交互：点击切换 `_isComparing`；开启时显示**烘焙基线**（原始未编辑效果），关闭显示当前编辑效果。与后期修图页 `_CompareButton` 行为一致。
- 视觉：半透明深色底 + 细白描边（「叠照片浮层」取向：无外阴影、无模糊，符合项目 UI 铁律）；激活态图标变品牌色 + 右上角状态点。
- 开启瞬间照片上短暂显示「查看修改前」小徽标（1s 后淡出），帮助用户理解当前状态。
- 实现沿用现有 `_isComparing` 渲染逻辑（对比时 ColorFiltered 透明 + 不应用变换）。

### 4.3 心情/场景 pill 行

- 工具条上方一行，两组 pill 用细分隔线隔开：`心情 pills | 场景 pills`，各自横向滑动。
- 点击即选（保持现状：心情单选可跳过，场景单选含「不标记」）。
- 选中态：品牌色渐变底 + 反色文字（沿用 `_Pill` 样式）。
- 写库逻辑不变（`updateMood`/`updateScene`）。
- 面板展开时 pill 行**保持可见**（编辑与标记互不干扰）。

### 4.4 底部工具条 + 参数面板

- 工具条：5 项图标工具（色彩/细节/滤镜/裁剪/重置），选中项品牌色高亮 + 圆角底，触感反馈（`HapticFeedback.lightImpact`）。
- 参数面板：点选工具后从工具条下方 `AnimatedSize`（260ms easeOutCubic）滑出，再点同工具收起。面板复用现有组件：
  - 色彩 → `PostProcessColorTab`（全量 = baked + 增量，`deltaOf` 反推）
  - 细节 → `PostProcessDetailTab`（同上）
  - 滤镜 → `FilterTab`（**新增传 `previewImagePath` = 当前照片路径**，显示真实滤镜缩略图）
  - 裁剪 → `CropTab` + 照片上叠 `PhotoCropLayer`（保留现有裁剪模式机制）
- 重置：一键重置全部本地编辑（`_localPostProcess` 增量归零 + `_localTransform` 归零 + `customCropRect` 清空，cropRatio 回照片实际比例），带触感反馈。
- 编辑期间照片区实时预览链路不变：色彩增量 ColorFiltered、细节效果 `DetailEffectsLayer` shader。

### 4.5 分享 Sheet

现有分享 Sheet 新增两个选项（从抽屉 3/4 档移入）：

- 生成对比图（`_onCompareCard`）
- 生成 EXIF 海报（`_onExifPoster`）

### 4.6 保持不变的部分

- 保存流程：编辑态 → 保存 pill → 替换/另存弹窗 → `resolveCropSavePlan` + `processFile` 从原图全量重处理 → 更新 DB → 返回/跳挑战确认页。
- 先快后真：`_isPendingFinal` 门控（禁止低清早帧编辑/保存/裁剪）。
- 只读模式：`_isReadOnly` 横幅 + 工具条点击 toast 拦截。
- 历史照片左右滑动（PhotoViewGallery + `_applyPhotoFromHistory`）。
- 双击缩放循环、纯净模式切换。

## 5. 代码结构

| 文件 | 变更 |
|---|---|
| [capture_preview_page.dart](../../lumira_app_flutter/lib/features/capture/pages/capture_preview_page.dart) | 删除三档抽屉（`_SheetMode`/`_sheetHeightNotifier`/拖拽吸附/`_BottomSheet`/`_QuarterPeek`/悬浮按钮组，约 500 行）；新增 `_activeTool` 状态编排新布局；顶栏加删除/保存到相册图标 |
| `capture/widgets/preview_edit_toolbar.dart`（新增） | 图标工具条 + AnimatedSize 滑出面板容器 |
| `capture/widgets/preview_tag_pill_row.dart`（新增） | 心情/场景紧凑 pill 行 |
| [preview_edit_panel.dart](../../lumira_app_flutter/lib/features/capture/widgets/preview_edit_panel.dart) | 删除 `PreviewEditPanel`（TabController 版，仅本页使用）；`FilterTab`/`CropTab`/`FilterThumbnail` 保留在原文件供两页共用 |
| 对比按钮 | 从 gallery_edit_page 提取为共享组件（如 `ComparePhotoButton`），两页复用同款视觉 |

## 6. 样式规范

- 所有颜色/圆角/阴影从 `appThemeProvider.tokens` 派生，禁止硬编码（叠照片的半透明黑/白遮罩除外）。
- 面板/工具条用 `tokens.surface`/`surfaceAlt`/`textPrimary` 等主题 token——浅色主题（warmWhite）下面板随主题浅色化是**预期行为**（与后期修图页一致）；照片区始终纯黑。
- 对比按钮叠照片：半透明底 + 细描边、无外阴影（UI 铁律 3/4）。
- 4 风格（neumorphic/flat/glass/female）× 8 主题下验证无混搭。

## 7. 风险与边界

- **裁剪模式与面板收起联动**：切走裁剪工具或收起面板时必须同步退出 `_isCropMode`（现有逻辑已有，迁移时保留）。
- **滤镜缩略图性能**：`FilterTab` 传路径后每张缩略图解码一次照片；后期修图页已验证可行，无需额外处理。
- **对比按钮与 PhotoView 手势冲突**：按钮放在 PhotoView 之外的 Stack 层（与后期修图页一致），不参与照片手势。
- **心情 pill 行与历史照片滑动**：pill 行显示当前照片的 mood/scene（`_applyPhotoFromHistory` 已恢复），切换照片时同步。
- **`PreviewEditPanel` 删除影响面**：grep 确认仅 capture_preview_page 使用（gallery_edit_page 直接用 Tab 组件），删除安全。

## 8. 验收标准

1. 拍摄 → 预览页：底部见 pill 行 + 工具条，无抽屉、无悬浮组。
2. 点色彩/细节/滤镜/裁剪：面板滑出、实时预览流畅；滤镜显示真实照片缩略图。
3. 编辑中途点右上角对比按钮：照片切回烘焙基线，再点恢复编辑效果。
4. 重置一键还原全部本地编辑。
5. 编辑态顶栏出现保存 pill，保存流程（替换/另存）与改版前结果一致。
6. 顶栏删除、保存到系统相册；分享 Sheet 含生成对比图/EXIF 海报。
7. 心情/场景标记写库正常，历史滑动切换时状态恢复。
8. 只读/先快后真门控正常拦截。
9. `flutter analyze` 无新增告警；4 风格 × 8 主题抽检无样式混搭。
