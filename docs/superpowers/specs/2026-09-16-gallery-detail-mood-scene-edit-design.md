# 照片详情页：心情设置 + 非模板照片场景设置 设计文档

- 日期：2026-09-16
- 模块：`lumira_app_flutter/lib/features/gallery/pages/gallery_detail_page.dart`
- 关联文档：`docs/superpowers/specs/2026-07-31-gallery-detail-edit-split-design.md`（详情页与编辑页拆分）

## 背景与问题

1. **心情只能单向查看**：心情（mood）此前仅在拍摄预览页（`capture_preview_page.dart`）的
   「心情 | 场景」pill 行可选择；详情页的 `_MoodHero` 只在已有心情时只读展示，无入口设置/更换/清除。
2. **非模板照片无法设置场景**：详情页 `_PhotoInfoSection` 的「来源信息」区块整体被
   `showSource = 有场景 || 有模板` 门控。既无场景又无模板的照片（如无模板直拍/导入照片）
   整块隐藏，连「更换」按钮一起消失，导致永远无法设置场景。

## 方案

### 心情：`_MoodHero` 从只读改为可编辑入口

- `_MoodHero` **始终渲染**于照片正下方：
  - 已记录：维持原品牌柔和底胶囊（icon + 「今天的心情 · X」），尾部加 `edit` 小图标提示可点。
  - 未记录：浅色占位态（`surfaceAlt` 底 + divider 描边 + `add_reaction_outlined` 图标 +
    「记录今天的心情」），引导添加。
- 点击弹出 `_MoodPickerSheet`（底部 Sheet，结构与 `_CategoryPickerSheet` 同构）：
  - 选项复用 `CapturePreviewMockData.moods`（与拍摄预览页同一套 7 个心情，保证全端一致）；
  - 已记录心情时首项提供「不记录心情」清除项（返回协议 `__none__`，与场景 Sheet 的
    「移除场景」一致）；未记录时不展示清除项。
- 保存：`GalleryDao.updateMood(photoId, mood?)`（DAO 已有）→ `_replaceCurrent` 同步当前照片
  → toast「已更新心情 / 已清除心情」→ `ref.invalidate(galleryDaoProvider)` 刷新下游
  （拍摄日记按心情筛选、统计页等，与拍摄预览页更新心情后的失效行为一致）。

### 场景：场景行脱离模板门控

- `_PhotoInfoSection` 移除 `showSource` 整块门控：
  - **场景行始终展示**：有场景 → 场景名（可点击跳场景详情）+「更换」按钮；
    无场景 → 「未设置场景」占位 +「设置」按钮。按钮复用原 `brandSubtle` 胶囊样式。
  - **模板 Chip 仅在套用模板拍摄时显示**（含跳转模板详情）。
- `_onChangeCategory` 行为不变（`_CategoryPickerSheet` + `updateScene`），补
  `ref.invalidate(galleryDaoProvider)`（场景被穿搭日记视图/统计 JOIN 使用，此前详情页
  换场景后下游存在脏读，与预览页行为对齐）。

### 配套细节

- 详情页 `daoAsync.when` 增加 `skipLoadingOnReload: true`：失效 `galleryDaoProvider`
  刷新下游时保留当前内容继续展示，避免整页闪加载圈（`_isInitialLoaded` 守卫保证不会重拉列表）。

## 测试

`test/features/gallery/gallery_detail_page_test.dart`：

1. `未记录心情的照片展示占位态，选择心情后保存并凸显展示`：占位态可见 → Sheet 选「开心」
   → 凸显区更新 + DB `mood == '开心'`。
2. `未套用模板拍摄的照片也可在详情页设置场景`：无模板无场景 → 「未设置场景」+「设置」
   → Sheet 选「咖啡馆」→ 场景名展示 + DB `sceneId == 'cafe'`。

### 顺带修复（历史遗留）

- 两个详情页测试夹具 `_onCreate` 缺失 `hidden` 列（隐藏照片功能引入后未同步），导致
  `GalleryDao.getAll/insert` 抛 `no such column: hidden`，测试在 HEAD 即全红；补齐列。
- `lumira_nav.dart` `_actionsRow()` 与 `_buildCenterToolbar()` 对 `LayoutId(id: trailing)`
  双重包裹，内层 LayoutId 落在 Padding 内触发 ParentData 冲突断言（debug 模式下所有
  `centerTitle` 顶栏渲染即抛错，HEAD 即存在）；删除 `_actionsRow` 中的内层包裹，
  由 `_buildCenterToolbar` 统一包裹。

## 状态

- ✅ 已实现（详情页心情编辑 + 非模板照片场景设置 + 上述修复），`flutter analyze` 通过，
  详情页 7 个测试全部通过。
