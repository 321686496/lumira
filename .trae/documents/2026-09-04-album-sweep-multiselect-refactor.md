# 相册滑动多选重构：按下即选 + 跨分区连续 + 到底自动滚动

## Context（背景）

用户在相册多选时反馈三个体验问题：
1. 进入多选态后，仍要按住图片**长按**才能开始滑动多选，不够流畅——希望**手指一按下就能直接滑动选择**。
2. 滑动多选只应在**已进入多选态**时触发（未进入多选态则不触发滑动选择）。
3. 滑动到底部时，需要**自动滚动**继续选择下方的其他图片。

现状的架构无法干净支持第 2、3 点：

- **嵌套滚动结构**：[gallery_page.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/gallery/pages/gallery_page.dart#L700-L758) 用「外层 `ListView.builder`」承载时间分区，每个分区又用各自的 [`SweepSelectGrid`](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/gallery/widgets/sweep_select_grid.dart)（`shrinkWrap` + `NeverScrollableScrollPhysics`）。
- **每个分区是独立实例**：各自的 `_sweeping` / `_lastIndex` 状态互不相通，滑动无法跨分区连续选择。
- **自动滚动无从谈起**：外层无 ScrollController，单格网格不可滚动，驱动不了整页滚动。
- **滑动只能靠长按触发**：[SweepSelectGrid](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/gallery/widgets/sweep_select_grid.dart#L99-L107) 只有 `onPointerMove`，没有 `onPointerDown`；只有格子 `onLongPress → startSweep()` 才会进入滑动状态。

> 备注：上一轮将多选底部操作栏改成「图标按钮栏」后，[gallery_multiselect_test.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/test/features/gallery/gallery_multiselect_test.dart) 中「断言出现文本 `删除` / `取消`」的用例会失败（图标栏不再显示这些文本），需一并更新。

## 目标行为

- **非多选态**：点按=打开详情/看图；**快速长按（300ms，已实现）**=进入多选态，并以该格为起点开始滑动。
- **多选态**：手指**一按下任一图片即选中该格并进入滑动**，拖动连续加选/回扫取消；**无需再次长按**。
- **跨分区连续**：从当前分区滑到下一分区时无缝续选（分区头占位不参与选择）。
- **自动滚动**：滑动时手指接近可视区上/下边缘，自动滚动列表让下方更多图片进入视口并继续选择。

## 实现方案

### 1. 相册分组改为“单一 CustomScrollView + 单一 ScrollController”

在 `_GalleryPageState`（[gallery_page.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/gallery/pages/gallery_page.dart#L43-L47)）增加 `final ScrollController _albumScrollController`（dispose 释放）。

把 `_buildContent` 的分组分支（原「`ListView.builder` 包分区 Column + 每个 `SweepSelectGrid`」）替换为**一个统一的相册滑动驱动组件** `SweepAlbumGrid`（见第 2 点），其内部渲染：

```
CustomScrollView(
  controller: _albumScrollController,
  physics: AlwaysScrollableScrollPhysics(parent: ...), // 兼容 RefreshIndicator 下拉刷新
  slivers: [
    每个分区:
      SliverToBoxAdapter(child: 分区头，含「… 张」计数 与 _SectionSelectAllButton 全选按钮),
      SliverPadding(SliverGrid(3 列, 同当前 mainAxisSpacing=6/crossAxisSpacing=6, aspect 1)),
  ],
)
```

- 分区头、照片格、`PhotoCell`、`LumiraImage` 等既有组件复用，样式/主题自适应逻辑不变。
- 外层仍是 `RefreshIndicator`（[gallery_page.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/gallery/pages/gallery_page.dart#L570-L583)），CustomScrollView 保持可滚动即可。
- 选中集合仍由 `_selectedIds` / `onSelectionChanged:` 回调驱动（多选态判定用现有 `_isMultiSelectMode`）。

### 2. 重写 `SweepSelectGrid` → 相册级滑动驱动 `SweepAlbumGrid`

文件：[sweep_select_grid.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/gallery/widgets/sweep_select_grid.dart)。保留 `GridGeometry.cellAt / indicesOnSegment`（纯函数、已被单测覆盖）；将 Widget 改造成面向「多分区照片流」的驱动。

新增输入：
- `sections`：`List<({String id, int photoCount})>`（或直接传分组后的照片数据）
- `isMultiSelectMode`：进入多选态后按下即选的关键开关
- `scrollController`：用于自动滚动
- 保留 `selectedIds / onSelectionChanged / maxSelectable / onMaxReached`
- 为单元格命中测试提供 `itemBuilder(BuildContext, int flatIndex, bool isSelected)` 与 flat 索引映射

强化后的状态逻辑：
- **按下即选**：`Listener.onPointerDown` 在 `isMultiSelectMode` 为 true 时，用命中测试定位按下格 → `_beginSweep(flatIndex)`。
- **精确格子定位（命中测试）**：每个照片格挂 `GlobalObjectKey('album_cell_$flatIndex')`；onDown/onMove 时通过 `WidgetsBinding.instance.hitTestInView` 或遍历已挂载 `GlobalKey.currentContext` 的 RenderBox 全局矩形，命中指针位置 → 得到**精确 flat 索引**。对懒加载 sliver 可用（仅挂载格有 context），避免依赖手工几何。
- **跨分区连续 flat 索引**：flat 索引 = 前面所有分区照片数之和 + 分区内下标（分区头不占索引）。跨分区边界时 flat 相邻，`indicesOnSegment` 连续插值天然无缝。
- **到底自动滚动**：onMove 时取滚动视口 RenderBox 的全局矩形，指针 Y 接近 bottom→ `scrollController.jumpTo(offset + step)`、接近 top→上滚，均 clamp 到 `[0, position.maxScrollExtent]`，每帧随 move 调用即可顺畅续选。
- 保留 `_beginSweep / _toggleIndex / _stepTo / _endSweep / _toggleReturn` 既有翻转与 maxSelectable 逻辑，仅由命中测试喂入 flatIndex。

### 3. `PhotoCell` 手势按模式分流（[photo_cell.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/gallery/widgets/photo_cell.dart)）

- **非多选态**：保留现有快速长按 `_QuickLongPressRecognizer`（300ms 进入多选）+ `TapGestureRecognizer`（打开详情）。
- **多选态**：取消 `PhotoCell` 内部全部手势识别（`onTap=null`、`onLongPress=null`，识提升降级为纯透明命中目标），滑动完全交由 `SweepAlbumGrid` 的裸 `Listener`（onDown/onMove）驱动，避免与点击/长按在竞技场里双触发。
- `PhotoCell` 仅需支持传入 null 回调时**不注册对应识别器**（阅读性：现在 `_QuickLongPressRecognizer` 无条件注册，需改为 `onLongPress != null` 才注册；`TapGestureRecognizer` 同理）。

### 4. 底部多选操作栏

沿用上一轮确认的**图标按钮栏**（`NeuCard` + `LumiraIconButton` + 数量角标），无需再改。

### 5. 更新测试

- [sweep_select_grid_test.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/test/features/gallery/sweep_select_grid_test.dart)：
  - 保留 `GridGeometry.cellAt / indicesOnSegment` 纯函数用例；
  - 把 Widget 级用例改为「多选态按下即选、拖动连续加选、跨分区连续、回扫取消」等新行为；补充自动滚动（模拟 move 到边缘后断言 scroll offset 增加）。
- [gallery_multiselect_test.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/test/features/gallery/gallery_multiselect_test.dart)：把断言「文本 删除 / 取消」改为断言图标栏（如 `Icons.delete_outline`、`Icons.close` 或 `多选操作栏` 的 key）；并新增「多选态按下即滑动选中多张」用例。
- [gallery_page_test.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/test/features/gallery/gallery_page_test.dart)：确认多选删除刷新用例仍通过（仅校验其不依赖旧的按钮文本）。

## 变更文件清单

- `lib/features/gallery/widgets/sweep_select_grid.dart` —— 重写为 `SweepAlbumGrid`（保留 GridGeometry）
- `lib/features/gallery/pages/gallery_page.dart` —— 分组分支改用 `SweepAlbumGrid` + 增加 ScrollController；`_buildSectionGrid` 移除/内联
- `lib/features/gallery/widgets/photo_cell.dart` —— 按多选态分流手势，null 回调不注册识别器
- `test/features/gallery/sweep_select_grid_test.dart` —— 更新
- `test/features/gallery/gallery_multiselect_test.dart` —— 更新并新增按压即选用例
- `test/features/gallery/gallery_page_test.dart` —— 校验不回归

（搜索态网格：保持现状，不纳入本次改造，避免扩大范围。）

## 验证

1. `cd d:\app\projects\photo_post\lumira_app_flutter && flutter analyze` —— 无错误。
2. `flutter test test/features/gallery`（重点 `sweep_select_grid_test.dart`、`gallery_multiselect_test.dart`、`gallery_page_test.dart`）—— 全部通过。
3. 手工（真机/OHOS）：
   - 长按一张 → 立即进入多选并可继续滑动；
   - 已进入多选后，直接按下任意图即滑动选中，松手即止；
   - 沿屏幕往下滑，手指到边缘事列表自动下滚继续选中下方图片；回扫可取消；
   - 多选底部图标栏不溢出、有间距、删除为红、带数量角标。