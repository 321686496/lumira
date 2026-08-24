# 编辑页裁剪一致性、预览页交互舒适度、保存到系统相册、EXIF 完善 设计

> 日期：2026-08-24
> 范围：Flutter 客户端（`lumira_app_flutter/`）
> 关联：拍摄预览页 `capture_preview_page.dart`、相册修图页 `gallery_edit_page.dart`、
>       裁剪组件 `photo_crop_layer.dart`/`crop_overlay.dart`、处理器 `photo_post_processor.dart`、
>       EXIF `photo_exif_reader.dart`/`exif_card_generator.dart`、
>       相册列表 `gallery_page.dart`、照片详情 `gallery_detail_page.dart`。

## 背景动机

用户反馈：拍摄预览页与相册修图页的**裁剪效果与框选内容不一致**；预览页**交互舒适度**待提升；
编辑抽屉弹出时**点击照片会放大照片**而非收起；需要**照片详情页 / 相册多选也能保存到系统相册**；
EXIF 导出需要**补充参数并改善排版**；预览页**保存按钮语义需重整**（仅编辑后显示、仅保存到 app）。

## 1. 裁剪一致性修复（两处编辑入口）

### 根因
- `PhotoCropLayer` / `CropOverlay` 的裁剪框用**相对整张图片 0~1 的坐标**表示（`_emit` 已考虑缩放/平移后的保留区域）。
- 但 `PhotoPostProcessor.processFile` 中 `customCropRect` 是在**比例裁剪 `computeCropRect` 之后**再相对该子区域解释，导致「两次裁剪叠加」与坐标错位，导出与框选不符。
- 拍摄预览页 `_onSave` / `_onSaveToAlbum` 调用 `processFile` 时**未传入 `customCropRect`**，裁剪结果在保存时被丢弃。

### 方案
1. 在 `processFile` 中：当 `customCropRect != null` 时**跳过比例裁剪**，直接
   `computeCustomCropRect(customCropRect, workingImage.width, workingImage.height)`
   相对整张工作图计算，做到**所见即所得**。
2. 拍摄预览页两处保存（编辑态「保存」+ 「保存到系统相册」）都补传 `customCropRect`。
3. 记录裁剪：保存时把 `customCropRect` 写入 DB `postProcess.customCropRect`（替换/另存一致）。

### 边界（已确认）
- 打开裁剪但**未拖拽**时，导出维持现状：按 `cropRatio` 做整张居中满铺裁剪，不受 90% 预览框影响。

## 2. 预览页交互舒适度 + 编辑抽屉收起

### 收起交互
- 照片区 `GestureDetector.onTap`（原仅切换 UI 显隐）改为：`_sheetMode == expanded` 时点击照片 → 折叠回 `hidden`；非编辑态才切换 UI 显隐。

### 抽屉体验
- 增加顶部拖拽把手。
- 点「编辑」直接展开到合适档位；拖拽到底部折叠为 `hidden`，动画更跟手。

### 底部浮动按钮
- 对比 / 保存到系统相册 / 编辑 / 删除：统一更大触控区、柔和按压反馈、间距更均衡。

## 3. 保存到系统相册入口扩展

- **照片详情页**：`_MoreAction` 底部面板新增「保存到系统相册」，复用 `MethodChannel('lumira/photo_saver').saveToAlbum`。
- **相册页多选**：底部多选操作栏新增「保存到相册 (N)」，批量保存选中本地照片到系统相册（跳过网络图片）。

## 4. EXIF 导出完善

- **补充参数**：分辨率 (WxH)、文件大小、拍摄设备品牌 `make`；存在时读取 白平衡 / 曝光补偿 / GPS 等标准 tag。
- **卡片排版清晰度**：字号与对比提升、参数分为「拍摄参数 / 创作信息」两组、缩略图比例更合理、对齐更整齐。

## 5. 保存按钮语义重整

- **移除**当前顶部 `_PreviewNav.showSave` 的「保存」按钮。
- **保留**底部浮动「保存到系统相册」→ device 系统相册。
- **编辑态保存**：仅当「编辑抽屉打开 且 数据已修改」时显示「保存」，点击执行 **app 相册保存**：
  重处理、更新 DB（替换/另存）、toast、约 1s 后返回上一页——与相册「后期修图」页保存语义一致，
  **不写系统相册、不额外跳转**。

## 影响面
- 纯 Flutter 端改动，不涉及后端 / 后台 / uni-app。
- 涉及文件：`photo_post_processor.dart`、`capture_preview_page.dart`、`gallery_edit_page.dart`、
  `gallery_detail_page.dart`、`gallery_page.dart`、`photo_exif_reader.dart`、`exif_card_generator.dart`。