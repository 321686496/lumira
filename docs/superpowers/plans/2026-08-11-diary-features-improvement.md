# 拍摄日记/穿搭日记功能增强 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 改造拍摄日记/穿搭日记的 4 个问题：灵感页 mock 数据、穿搭无独立入口、日记页无法删除、日期筛选不定位

**Architecture:** 全部为 Flutter 客户端本地改造，不涉及后端 API。数据来源为 sqflite 的 `GalleryDao`，状态管理使用 Riverpod FutureProvider。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6, flutter_riverpod 2.3.6, sqflite

---

### Task 1: 灵感页穿搭日记卡片接入真实数据

**Files:**
- Modify: `lib/features/inspiration/widgets/outfit_diary_card.dart`
- Modify: `lib/features/inspiration/data/inspiration_mock_data.dart`
- Modify: `lib/features/gallery/providers/gallery_diary_providers.dart`

**Interfaces:**
- Consumes: `diaryStreakProvider` (existing), `diaryEntriesProvider(kDiaryTabOutfit)` (existing)
- Produces: `outfitDiaryCardProvider` — `FutureProvider<OutfitDiaryCardData>`

- [ ] **Step 1: 新增 `OutfitDiaryCardData` 模型**

在 `lib/features/inspiration/data/inspiration_mock_data.dart` 末尾追加：

```dart
/// 穿搭日记卡片真实数据（替代 mock）
class OutfitDiaryCardData {
  const OutfitDiaryCardData({required this.streak, required this.photos});
  final int streak;
  final List<OutfitPhoto> photos;
}
```

- [ ] **Step 2: 新增 `outfitDiaryCardProvider`**

在 `lib/features/gallery/providers/gallery_diary_providers.dart` 末尾追加：

```dart
/// 穿搭日记卡片数据：连续打卡天数 + 最近 2 张穿搭照片
final outfitDiaryCardProvider = FutureProvider<OutfitDiaryCardData>((ref) async {
  final streak = await ref.watch(diaryStreakProvider.future);
  final entries = await ref.watch(diaryEntriesProvider(kDiaryTabOutfit).future);
  final recentPhotos = <OutfitPhoto>[];
  if (entries.isNotEmpty) {
    final firstEntry = entries.first;
    for (final p in firstEntry.photos.take(2)) {
      recentPhotos.add(OutfitPhoto(imageSeed: p.img, date: firstEntry.date));
    }
  }
  return OutfitDiaryCardData(streak: streak, photos: recentPhotos);
});
```

注意需要 import `OutfitDiaryCardData` 和 `OutfitPhoto`。在文件顶部 import 列表中添加：

```dart
import '../../../features/inspiration/data/inspiration_mock_data.dart';
```

- [ ] **Step 3: 改造 `OutfitDiaryCard` 使用真实数据**

替换 `lib/features/inspiration/widgets/outfit_diary_card.dart`：

将 `// streak 行` 中的 `InspirationMockData.outfitStreakDays` 替换为 `data.streak`，将 `// 2 张照片横排` 中的 `InspirationMockData.outfitPhotos` 替换为 `data.photos`。

具体改动：

```dart
// 1. 顶部 import 区移除 mock 数据 import，添加 Provider import
// 移除：import '../data/inspiration_mock_data.dart';
// 添加：
import '../../../core/db/database_provider.dart';
import '../../gallery/providers/gallery_diary_providers.dart';

// 2. 将 class OutfitDiaryCard extends ConsumerWidget 改为：
class OutfitDiaryCard extends ConsumerWidget {
  const OutfitDiaryCard({super.key, required this.onViewDiary});
  final VoidCallback onViewDiary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final dataAsync = ref.watch(outfitDiaryCardProvider);

    return NeuCard(
      child: dataAsync.when(
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: LumiraProgress.circular()),
        ),
        error: (e, _) => SizedBox(
          height: 200,
          child: Center(
            child: Text('加载失败', style: TextStyle(color: tokens.textSecondary)),
          ),
        ),
        data: (data) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行（保持不变）
            _buildHeader(context, tokens),
            const SizedBox(height: 16),
            // streak 行
            _buildStreakRow(tokens, data.streak),
            const SizedBox(height: 16),
            // 照片行
            _buildPhotosRow(tokens, data.photos),
          ],
        ),
      ),
    );
  }
}
```

注意 `_buildHeader`、`_buildStreakRow`、`_buildPhotosRow` 是提取的私有方法，保持原有内部逻辑不变，仅将数据源从 `InspirationMockData` 改为参数传入。

- [ ] **Step 4: 运行测试验证**

```bash
flutter test test/features/inspiration/inspiration_page_test.dart
```

- [ ] **Step 5: 提交**

```bash
git add -A
git commit -m "feat: 灵感页穿搭日记卡片接入真实数据"
```

---

### Task 2: 照片详情页增加"标记为穿搭日记"入口

**Files:**
- Modify: `lib/features/gallery/pages/gallery_detail_page.dart`

**Interfaces:**
- Consumes: `GalleryDao.updateScene(photoId, sceneId)` (existing), `_allScenes` (existing in page state)
- Produces: 无（纯 UI 交互）

- [ ] **Step 1: 在 `_ActionBar` 中增加"标记为穿搭"按钮**

在 `lib/features/gallery/pages/gallery_detail_page.dart` 的 `_ActionBar` 组件中，找到当前的操作按钮行，在分享按钮旁边增加：

```dart
// 穿搭日记标记按钮
_ActionButton(
  icon: Icons.checkroom_outlined,
  label: _photo?.sceneId != null ? '更换穿搭' : '标记穿搭',
  onTap: _onMarkOutfit,
),
```

并在 `_GalleryDetailPageState` 类中实现 `_onMarkOutfit` 方法：

```dart
/// 标记为穿搭日记：弹出场景选择器
Future<void> _onMarkOutfit() async {
  final scenes = _allScenes;
  if (scenes.isEmpty) {
    LumiraToast.show(context, '暂无可用场景', duration: const Duration(milliseconds: 1500));
    return;
  }
  final tokens = ref.read(themeTokensProvider);
  final selected = await showLumiraBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _OutfitScenePicker(
      scenes: scenes,
      currentSceneId: _photo?.sceneId,
      tokens: tokens,
    ),
  );
  if (selected == null || !mounted) return;
  final dao = await ref.read(galleryDaoProvider.future);
  await dao.updateScene(_photo!.id, selected);
  setState(() {
    _photo = GalleryItemRecord(
      id: _photo!.id,
      dataUrl: _photo!.dataUrl,
      filePath: _photo!.filePath,
      originalPath: _photo!.originalPath,
      transform: _photo!.transform,
      postProcess: _photo!.postProcess,
      sceneId: selected,
      templateId: _photo!.templateId,
      kitId: _photo!.kitId,
      mood: _photo!.mood,
      lut: _photo!.lut,
      isFavorite: _photo!.isFavorite,
      createdAt: _photo!.createdAt,
    );
  });
  LumiraToast.show(context, '已标记为穿搭日记', duration: const Duration(milliseconds: 1500));
}
```

- [ ] **Step 2: 创建 `_OutfitScenePicker` 底部弹窗组件**

在 `gallery_detail_page.dart` 末尾新增：

```dart
/// 穿搭场景选择器 BottomSheet
class _OutfitScenePicker extends StatelessWidget {
  const _OutfitScenePicker({
    required this.scenes,
    required this.currentSceneId,
    required this.tokens,
  });

  final List<SceneRecord> scenes;
  final String? currentSceneId;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '选择穿搭场景',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...scenes.map((scene) => GestureDetector(
            onTap: () => Navigator.of(context).pop(scene.id),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: scene.id == currentSceneId ? tokens.brandSubtle : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.checkroom_outlined, size: 18, color: tokens.brand),
                  const SizedBox(width: 12),
                  Text(
                    scene.name,
                    style: TextStyle(
                      fontSize: 15,
                      color: tokens.textPrimary,
                    ),
                  ),
                  if (scene.id == currentSceneId) ...[
                    const Spacer(),
                    Icon(Icons.check, size: 18, color: tokens.brand),
                  ],
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: 运行测试验证**

```bash
flutter test test/features/gallery/gallery_detail_page_test.dart
```

- [ ] **Step 4: 提交**

```bash
git add -A
git commit -m "feat: 照片详情页增加标记为穿搭日记入口"
```

---

### Task 3: 拍摄日记页增加照片删除能力

**Files:**
- Modify: `lib/features/gallery/widgets/diary_timeline_entry.dart`
- Modify: `lib/features/gallery/pages/gallery_diary_page.dart`

**Interfaces:**
- Consumes: `GalleryDao.delete(photoId)` (existing), `diaryEntriesProvider(viewTab)` (existing)
- Produces: 无（纯 UI 交互）

- [ ] **Step 1: `_PhotoCard` 增加长按删除**

在 `lib/features/gallery/widgets/diary_timeline_entry.dart` 中，修改 `_PhotoCard` 的 `build` 方法，在 `GestureDetector` 上增加 `onLongPress`：

```dart
// 修改 GestureDetector
GestureDetector(
  onTap: onTap,
  onLongPress: onLongPress,
  behavior: HitTestBehavior.opaque,
  child: Column(...),
)
```

在 `DiaryTimelineEntry` 的构造函数中增加 `onLongPress` 回调：

```dart
class DiaryTimelineEntry extends ConsumerWidget {
  const DiaryTimelineEntry({
    super.key,
    required this.entry,
    this.onPhotoTap,
    this.onPhotoLongPress,
  });

  final DiaryEntry entry;
  final void Function(String photoId)? onPhotoTap;
  final void Function(String photoId)? onPhotoLongPress;
```

在 `_PhotoCard` 的构造函数中增加 `onLongPress`：

```dart
class _PhotoCard extends ConsumerWidget {
  const _PhotoCard({
    required this.photo,
    this.onTap,
    this.onLongPress,
  });
  final DiaryPhoto photo;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
```

- [ ] **Step 2: `GalleryDiaryPage` 实现删除逻辑**

在 `lib/features/gallery/pages/gallery_diary_page.dart` 中，在 `_GalleryDetailPageState` 增加：

```dart
Future<void> _onPhotoLongPress(String photoId) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('删除照片'),
      content: const Text('确定要删除这张照片吗？此操作不可撤销。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('删除', style: TextStyle(color: ref.read(themeTokensProvider).danger)),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  final dao = await ref.read(galleryDaoProvider.future);
  await dao.delete(photoId);
  ref.invalidate(diaryEntriesProvider(_viewTab));
  ref.invalidate(diaryStreakProvider);
  ref.invalidate(diaryTotalCountProvider);
  if (mounted) {
    LumiraToast.show(context, '已删除', duration: const Duration(milliseconds: 1200));
  }
}
```

在 `build` 方法的 `DiaryTimelineEntry` 调用处传入 `onPhotoLongPress`：

```dart
DiaryTimelineEntry(
  entry: e.value,
  onPhotoTap: _navigateToPhoto,
  onPhotoLongPress: _onPhotoLongPress,
),
```

- [ ] **Step 3: 运行测试验证**

```bash
flutter test test/features/gallery/gallery_diary_page_test.dart
```

- [ ] **Step 4: 提交**

```bash
git add -A
git commit -m "feat: 拍摄日记页增加照片长按删除功能"
```

---

### Task 4: 日记页日期筛选定位

**Files:**
- Modify: `lib/features/gallery/pages/gallery_diary_page.dart`

**Interfaces:**
- Consumes: `diaryEntriesProvider` (existing), `ScrollController`
- Produces: 无（纯 UI 交互）

- [ ] **Step 1: 改用 `ListView` + `ScrollController` 实现定位**

在 `_GalleryDetailPageState` 中增加：

```dart
final ScrollController _scrollController = ScrollController();
```

在 `dispose` 中释放：

```dart
@override
void dispose() {
  _scrollController.dispose();
  super.dispose();
}
```

- [ ] **Step 2: 给每个 entry 添加 `Key`**

修改 `build` 方法中 `ListView` 的 children 构建，为每个 `DiaryTimelineEntry` 添加 key：

```dart
// 找到 entries 列表的构建处，将：
DiaryTimelineEntry(
  entry: e.value,
  ...
)
// 改为：
DiaryTimelineEntry(
  key: ValueKey('diary_${e.value.date}'),
  entry: e.value,
  ...
)
```

- [ ] **Step 3: 实现 `_pickDate` 定位逻辑**

修改 `_pickDate` 方法：

```dart
Future<void> _pickDate() async {
  final picked = await showLumiraDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime.now(),
  );
  if (picked == null || !mounted) return;

  final entries = ref.read(diaryEntriesProvider(_viewTab)).valueOrNull;
  if (entries == null || entries.isEmpty) {
    LumiraToast.show(context, '暂无照片数据', duration: const Duration(milliseconds: 1200));
    return;
  }

  final targetDay = DateTime(picked.year, picked.month, picked.day);
  final targetLabel = DateFormat('M月d日').format(targetDay);

  // 查找匹配的 entry 索引
  final index = entries.indexWhere((e) => e.date == targetLabel);
  if (index < 0) {
    LumiraToast.show(
      context,
      '该日期没有照片',
      duration: const Duration(milliseconds: 1200),
    );
    return;
  }

  // 计算滚动位置：每个 entry 约 200dp，header 约 200dp
  final offset = 200.0 + index * 200.0;
  _scrollController.animateTo(
    offset,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
  );
}
```

- [ ] **Step 4: 将 `ListView` 绑定 `_scrollController`**

```dart
ListView(
  controller: _scrollController,
  padding: const EdgeInsets.only(bottom: 100),
  children: [...],
)
```

- [ ] **Step 5: 运行测试验证**

```bash
flutter test test/features/gallery/gallery_diary_page_test.dart
```

- [ ] **Step 6: 提交**

```bash
git add -A
git commit -m "feat: 日记页日期选择后定位到对应条目"
```