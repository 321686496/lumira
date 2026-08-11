# 拍摄日记/穿搭日记功能增强设计

> 日期：2026-08-11
> 范围：`lumira_app_flutter`（Flutter 项目）
> 状态：设计完成，待实现

---

## 0. 背景

在 2026-08-11 的功能审计中，发现拍摄日记与穿搭日记存在以下问题：

1. **灵感页穿搭日记卡片使用 mock 数据**：`OutfitDiaryCard` 的 streak 天数和照片均为 `InspirationMockData` 硬编码，与真实数据脱节
2. **穿搭日记缺乏独立创建入口**：没有主动"标记为穿搭"的机制，只能通过拍照→设置场景间接标记
3. **拍摄日记页缺乏删除能力**：只能浏览，无法删除照片
4. **日期筛选不完整**：日历按钮选择日期后仅 Toast 提示，未实际定位

---

## 1. 灵感页穿搭日记卡片接入真实数据

### 1.1 现状

[outfit_diary_card.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/inspiration/widgets/outfit_diary_card.dart) 使用 `InspirationMockData.outfitStreakDays`（硬编码 7）和 `InspirationMockData.outfitPhotos`（硬编码 2 张 picsum 图）。

### 1.2 改造方案

创建 `outfitDiaryCardProvider`，从 `GalleryDao` 读取真实数据：

```dart
// 穿搭日记卡片数据：连续打卡天数 + 最近 2 张穿搭照片
final outfitDiaryCardProvider = FutureProvider<OutfitDiaryCardData>((ref) async {
  final streak = await ref.watch(diaryStreakProvider.future);
  final entries = await ref.watch(diaryEntriesProvider(kDiaryTabOutfit).future);
  final recentPhotos = entries.isNotEmpty
      ? entries.first.photos.take(2).map((p) => OutfitPhoto(
            imageSeed: p.img,
            date: entries.first.date,
          )).toList()
      : <OutfitPhoto>[];
  return OutfitDiaryCardData(streak: streak, photos: recentPhotos);
});
```

`OutfitDiaryCardData` 模型在 `inspiration_mock_data.dart` 中新增，或在 `gallery_models.dart` 中新增。

`OutfitDiaryCard` 从引用 `InspirationMockData` 改为引用 `outfitDiaryCardProvider`。

### 1.3 涉及文件

| 文件 | 改动 |
|---|---|
| `lib/features/inspiration/widgets/outfit_diary_card.dart` | 改用 Provider 读取真实数据 |
| `lib/features/inspiration/data/inspiration_mock_data.dart` | 新增 `OutfitDiaryCardData` 模型 |
| `lib/features/gallery/providers/gallery_diary_providers.dart` | 新增 `outfitDiaryCardProvider` |

---

## 2. 照片详情页增加"标记为穿搭日记"入口

### 2.1 现状

穿搭日记的筛选条件是 `sceneId != null`，但照片详情页无快捷操作让用户标记照片为"穿搭"。

### 2.2 改造方案

在 [gallery_detail_page.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/gallery/pages/gallery_detail_page.dart) 底部操作栏（`_ActionBar`）增加一个"标记为穿搭"按钮：

- 点击后弹出一个场景选择器 BottomSheet（复用现有的场景列表 `_allScenes`）
- 选择场景后，调用 `GalleryDao.updateScene(photoId, sceneId)` 设置场景
- 设置成功后 Toast 提示"已标记为穿搭日记"，并更新 UI 状态
- 如果照片已有场景，按钮文字变为"更换穿搭场景"

### 2.3 涉及文件

| 文件 | 改动 |
|---|---|
| `lib/features/gallery/pages/gallery_detail_page.dart` | 底部操作栏增加"标记为穿搭"按钮 + 场景选择器 |

---

## 3. 拍摄日记页增加照片删除能力

### 3.1 现状

[gallery_diary_page.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/gallery/pages/gallery_diary_page.dart) 和 [diary_timeline_entry.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/gallery/widgets/diary_timeline_entry.dart) 均无删除操作。

### 3.2 改造方案

在 `_PhotoCard`（diary_timeline_entry.dart）上增加长按手势：

- 长按照片弹出 `LumiraBottomSheet` 操作菜单，包含"删除"选项
- 点击"删除"弹出确认弹窗
- 确认后调用 `GalleryDao.delete(photoId)` 删除照片
- 删除后通过 `ref.invalidate(diaryEntriesProvider(_viewTab))` 刷新列表
- 同时更新 `diaryStreakProvider` 和 `diaryTotalCountProvider`

### 3.3 涉及文件

| 文件 | 改动 |
|---|---|
| `lib/features/gallery/widgets/diary_timeline_entry.dart` | `_PhotoCard` 增加长按删除 |
| `lib/features/gallery/pages/gallery_diary_page.dart` | 传递 `onPhotoLongPress` 回调 |

---

## 4. 日记页日期筛选定位

### 4.1 现状

日历按钮选择日期后仅 Toast 提示"已选择 X月X日"，未实际定位到对应 entry。

### 4.2 改造方案

使用 `ScrollController` 和 `itemScrollTo` 实现定位：

- 给每个 `DiaryTimelineEntry` 添加 `ValueKey(day)`，其中 day 为 `DateTime` 的 ISO 格式
- 选择日期后，查找该日期对应的 entry 索引
- 使用 `ScrollablePositionedList` 或 `ScrollController.animateTo()` 滚动到对应位置
- 如果该日期无照片，Toast 提示"该日期没有照片"

### 4.3 涉及文件

| 文件 | 改动 |
|---|---|
| `lib/features/gallery/pages/gallery_diary_page.dart` | 改用 `ScrollController`，实现日期定位 |

---

## 5. 测试策略

| 改动 | 测试方式 |
|---|---|
| 穿搭日记卡片真实数据 | 单元测试：验证 `outfitDiaryCardProvider` 返回正确数据 |
| 标记为穿搭 | Widget 测试：验证按钮点击后场景选择器弹出 |
| 日记页删除 | Widget 测试：验证长按→删除→刷新 |
| 日期定位 | Widget 测试：验证选择日期后滚动到对应 entry |