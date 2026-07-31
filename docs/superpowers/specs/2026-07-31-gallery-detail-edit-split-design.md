# 相册详情页与修图页拆分设计

**日期**：2026-07-31
**作者**：协作设计（用户 + AI）
**状态**：已批准，待实施

## 背景与动机

用户反馈：拍摄出的照片如果套用了模板，相册点击照片时应能查看照片基本信息（拍摄时间等）以及使用的模板与场景信息，并可跳转到对应模板/场景详情页；同时希望详情页有"后期修图"入口。

**当前现状**：
- 拍照时已记录 `templateId` / `sceneId` 到 `gallery_items` 表（`capture_page.dart:484-496`）—— **已正确**
- 相册页点击照片已跳转到详情页（`gallery_page.dart:296-301`）—— **已正确**
- `GalleryItemRecord` 数据模型字段完备（含 `templateId` / `sceneId` / `mood` / `originalPath` / `postProcess` / `createdAt`）—— **已正确**
- `TemplatesDao.getById` / `ScenesDao.getById` 可查询名称 —— **已存在**

**当前问题**：
- 详情页（`gallery_detail_page.dart`）当前是"编辑页"：含完整 PreviewEditPanel + 重置/导出按钮，没有"查看为主"的元信息展示
- 没有显示拍摄时间、心情、原图保留状态等元信息
- 只显示 `sceneId` 字符串，未查询场景名/模板名，且无模板信息行
- 场景信息行 `onTap: () {}` 是空回调，无法跳转
- 没有"后期修图"按钮入口

## 目标

1. 将当前 `gallery_detail_page` 改造为"查看为主"的详情页：
   - 显示照片预览（只读，应用照片已保存的 postProcess 滤镜）
   - 显示照片元信息：拍摄时间（相对+绝对）、心情标签、原图保留状态
   - 显示模板/场景信息为可点击 Chip，点击跳转对应详情页
   - 底部"后期修图"按钮
2. 新建独立的修图页 `gallery_edit_page.dart`：
   - 承载现有 PreviewEditPanel 编辑能力（4 标签：色彩/细节/滤镜/裁剪旋转）
   - 重置/导出按钮
   - 保存成功后自动 pop 返回详情页
3. 路由新增 `/gallery/edit?photoId=xxx`
4. 三端兼容（OHOS / iOS / Android），无原生代码
5. 不破坏现有 242+ 测试

## 非目标

- 不修改拍照流程（已正确记录 templateId / sceneId）
- 不修改 `GalleryItemRecord` 数据模型
- 不修改 `GalleryDao` 接口
- 不引入新的 AI 修图能力（仅复用现有 PreviewEditPanel）
- 不做相册页（`gallery_page.dart`）的网格改造

## 方案选择

**选定方案**：拆分为两个页面

| 决策点 | 选择 | 理由 |
|---|---|---|
| 详情页 vs 修图页关系 | 独立两个页面 | 用户明确选择"拆分为两个页面"，职责清晰 |
| 元信息字段 | 拍摄时间（相对+绝对）+ 心情标签 + 原图保留状态 | 用户多选确认，不含裁剪比例 |
| 模板/场景行样式 | Chip 标签式 | 用户选择，两个独立可点击 Chip |
| 原图未保留处理 | "后期修图"按钮置灰 | 用户选择，详情页直接防护 |
| 保存后行为 | 自动 pop 返回详情页 | 用户选择，详情页重新加载刷新预览 |
| 详情页预览滤镜 | 应用照片已保存的 postProcess | 与拍摄时所见一致 |

**被否决方案**：
- 同页模式切换（详情页+编辑模式切换）：用户未选择，因职责隔离更清晰
- 详情页内嵌始终可见编辑区：用户未选择，不强调"查看 vs 编辑"区分

## 架构设计

### 模块划分

```
lib/core/router/
├── route_names.dart              # 修改：新增 galleryEdit 路径常量
└── (router.dart 在 app/ 下)

lib/app/
└── router.dart                   # 修改：新增 /gallery/edit GoRoute

lib/features/gallery/
├── pages/
│   ├── gallery_detail_page.dart  # 修改：改造为查看为主的详情页
│   └── gallery_edit_page.dart    # 新增：修图页（搬迁现有编辑逻辑）
└── (其他不变)
```

### 数据流

```
相册页点击照片
  ↓
/gallery/detail?photoId=xxx
  ↓
详情页 _loadPhoto(dao):
  ├─ GalleryDao.getById(photoId) → GalleryItemRecord
  ├─ 若 templateId != null:
  │    └─ TemplatesDao.getById(templateId) → TemplateRecord? (取 name)
  ├─ 若 sceneId != null:
  │    └─ ScenesDao.getById(sceneId) → SceneRecord? (取 name)
  └─ 并行 Future.wait 加载

详情页渲染:
  ├─ 照片预览区（应用 photo.postProcess 滤镜，只读）
  ├─ 元信息 section:
  │    ├─ 拍摄时间: _formatRelativeTime(createdAt) + _formatAbsoluteTime(createdAt)
  │    ├─ 心情标签: photo.mood (如有)
  │    └─ 原图保留状态: photo.originalPath != null ? "可再次修图" : "原图未保留"
  ├─ 模板/场景 Chip 区（条件渲染）:
  │    ├─ 场景 Chip (若 sceneId != null 且查询到名称) → 跳 /capture/scene-detail?sceneId=xxx
  │    └─ 模板 Chip (若 templateId != null 且查询到名称) → 跳 /templates/detail?templateId=xxx
  └─ 底部"后期修图"按钮:
       ├─ originalPath == null → 置灰 disabled + toast
       └─ originalPath != null → push /gallery/edit?photoId=xxx

修图页 _loadPhoto(dao):
  ├─ GalleryDao.getById(photoId) → GalleryItemRecord
  ├─ _localPostProcess = photo.postProcess ?? 默认
  └─ _localTransform = photo.transform ?? 默认

修图页编辑 + 保存:
  ├─ 用户调整 _localPostProcess / _localTransform（PreviewEditPanel）
  ├─ 点击"导出":
  │    ├─ PhotoPostProcessor.processFile(originalPath, _localPostProcess, _localTransform, outputPath: filePath)
  │    ├─ GalleryDao.updateEdit(id, filePath, originalPath, transform, postProcess)
  │    ├─ evict FileImage cache
  │    ├─ LumiraToast.show('已保存')
  │    └─ Navigator.pop() → 返回详情页
  └─ 详情页 didChangeDependencies 重新 _loadPhoto 刷新预览
```

## 详情页改造（gallery_detail_page.dart）

### 移除项

- PreviewEditPanel 引用与 SizedBox 包裹
- `_localPostProcess` / `_localTransform` 本地状态字段
- `_reset()` / `_export()` 方法
- `_BottomBar`（重置 + 导出按钮）
- `_isExporting` 状态
- `preview_edit_panel.dart` / `photo_post_processor.dart` 导入

### 保留项

- 暗色主题 `#1C1A17`
- LumiraNav（标题"照片详情" + 返回 + 收藏 + 对比 + 更多）
- 照片预览区 `_CanvasArea`（简化为只读：直接使用 `photo.postProcess` 而非 `_localPostProcess`，`photo.transform` 而非 `_localTransform`）
- 收藏按钮 `_FavoriteButton`
- `_EmptyCanvas` 空状态

### 新增项

#### 照片元信息 Section（紧接预览区下方）

```
┌──────────────────────────────────────────┐
│  拍摄时间                                 │
│  3 小时前                                 │
│  2026-07-31 14:30                         │
│                                          │
│  心情                                     │
│  [宁静]                                   │
│                                          │
│  ● 原图已保留 · 可再次修图                │
└──────────────────────────────────────────┘
```

- **拍摄时间**：双行展示
  - 第一行：相对时间（`_formatRelativeTime`）
    - < 60s → "刚刚"
    - < 60min → "X 分钟前"
    - < 24h → "X 小时前"
    - < 7d → "X 天前"
    - ≥ 7d → 仅显示绝对时间
  - 第二行：绝对时间 `YYYY-MM-DD HH:mm`
- **心情标签**：仅当 `photo.mood != null && photo.mood!.isNotEmpty` 时显示
  - 小 Chip 样式：圆角矩形 + 图标 + 文字
- **原图保留状态**：
  - `originalPath != null` → 绿色 dot + "原图已保留 · 可再次修图"
  - `originalPath == null` → 灰色 dot + "原图未保留"

#### 模板/场景 Chip 区（元信息下方）

```
┌──────────────────────────────────────────┐
│  [📍 咖啡馆]  [📖 咖啡馆人像]              │
└──────────────────────────────────────────┘
```

- 通过 `TemplatesDao.getById` / `ScenesDao.getById` 异步查询名称
- **场景 Chip**（仅当 `photo.sceneId != null` 且查询到 SceneRecord 时显示）：
  - `Icons.place_outlined` + 场景名
  - 点击 → `GoRouter.of(context).push('/capture/scene-detail?sceneId=${photo.sceneId}')`
- **模板 Chip**（仅当 `photo.templateId != null` 且查询到 TemplateRecord 时显示）：
  - `Icons.collections_bookmark_outlined` + 模板名
  - 点击 → `GoRouter.of(context).push('/templates/detail?templateId=${photo.templateId}')`
- Chip 样式：暗色背景 `#2A2724` + 金色边框 `#C9A96E` + 白色文字
- 两个都没有时整个 Chip 区隐藏（不渲染）

#### 底部"后期修图"按钮（替换原 `_BottomBar`）

```
┌──────────────────────────────────────────┐
│  [      后期修图      ]                   │
└──────────────────────────────────────────┘
```

- 全宽金色渐变按钮（`LinearGradient[#C9A96E → #A88550]`）
- `originalPath == null` → 置灰（灰色背景 + 灰色文字 + 禁用点击）
  - 强制点击（防误触）→ `LumiraToast.show('原图未保留，无法修图')`
- `originalPath != null` → 点击 `GoRouter.of(context).push('/gallery/edit?photoId=${photo.id}')`

### 详情页返回刷新

修图页 pop 返回后，详情页需要重新加载照片记录以刷新预览：
- 方案：使用 `RouteAware` 监听路由返回，或在 `didChangeDependencies` 中检查 `ModalRoute.of(context)?.canPop` 状态
- 简化方案：在 `_loadPhoto` 中保存 photoId，每次 `didChangeDependencies` 触发时重新加载（go_router 的 push 不会触发 didChangeDependencies，需用 `routeObserver` 或在 `Navigator.push` 时 await 返回结果）

**最终方案**：在详情页中 `await GoRouter.of(context).push(...)` 返回后调用 `_loadPhoto(dao)` 重新加载：

```dart
Future<void> _onEditTap() async {
  if (_photo?.originalPath == null) {
    LumiraToast.show(context, '原图未保留，无法修图');
    return;
  }
  await GoRouter.of(context).push(
    RouteNames.build(RouteNames.galleryEdit, {RouteNames.paramPhotoId: _photo!.id}),
  );
  // 修图页 pop 返回后刷新
  final dao = ref.read(galleryDaoProvider).value;
  if (dao != null) _loadPhoto(dao);
}
```

## 修图页新建（gallery_edit_page.dart）

### 文件位置

`lib/features/gallery/pages/gallery_edit_page.dart`

### 结构

完全复用现有 `gallery_detail_page.dart` 的编辑逻辑（搬迁）：

```dart
class GalleryEditPage extends ConsumerStatefulWidget {
  const GalleryEditPage({super.key, this.photoId});
  final String? photoId;
  // ...
}

class _GalleryEditPageState extends ConsumerState<GalleryEditPage> {
  PostProcess _localPostProcess = const PostProcess(color: PostProcessColor());
  TransformParams _localTransform = const TransformParams();
  bool _isExporting = false;
  GalleryItemRecord? _photo;
  bool _isLoading = true;
  bool _isInitialLoaded = false;

  // _loadPhoto: 从 GalleryDao.getById 加载，初始化 _localPostProcess / _localTransform
  // _reset: 重置本地参数
  // _export: 保存到原 filePath + updateEdit + evict cache + pop 返回
  // build: Scaffold + LumiraNav(标题"后期修图") + _CanvasArea + PreviewEditPanel + _BottomBar
}
```

### 与原 gallery_detail_page 的差异

1. **标题**："后期修图"（原"照片详情"）
2. **保存成功后**：增加 `Navigator.of(context).pop()` 自动返回（原页面不 pop）
3. **只读防护**：直达 URL 时若 `originalPath == null`，显示只读横幅 + 禁用编辑

### _export 保存逻辑

```dart
Future<void> _export() async {
  // ... 现有逻辑（PhotoPostProcessor.processFile + dao.updateEdit）
  // 成功后:
  if (mounted) {
    LumiraToast.show(context, '已保存', duration: const Duration(seconds: 1));
    // 延迟 1s 让 toast 显示后 pop
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }
}
```

## 路由变更

### route_names.dart

新增常量：

```dart
static const String galleryEdit = '/gallery/edit';
```

### router.dart

新增 GoRoute：

```dart
GoRoute(
  path: RouteNames.galleryEdit,
  name: 'galleryEdit',
  builder: (context, state) {
    final photoId = state.queryParams[RouteNames.paramPhotoId];
    return GalleryEditPage(photoId: photoId);
  },
),
```

并在文件顶部 import：

```dart
import '../features/gallery/pages/gallery_edit_page.dart';
```

## 时间格式化工具

在 `lib/core/utils/` 新增 `time_format.dart`：

```dart
/// 格式化相对时间（"刚刚" / "X 分钟前" / "X 小时前" / "X 天前"）
String formatRelativeTime(int timestampMs) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final diff = now - timestampMs;
  if (diff < 60 * 1000) return '刚刚';
  if (diff < 60 * 60 * 1000) return '${diff ~/ (60 * 1000)} 分钟前';
  if (diff < 24 * 60 * 60 * 1000) return '${diff ~/ (60 * 60 * 1000)} 小时前';
  if (diff < 7 * 24 * 60 * 60 * 1000) return '${diff ~/ (24 * 60 * 60 * 1000)} 天前';
  return '';  // ≥ 7d 不显示相对时间，仅显示绝对时间
}

/// 格式化绝对时间 "YYYY-MM-DD HH:mm"
String formatAbsoluteTime(int timestampMs) {
  final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  final y = dt.year;
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final h = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$min';
}
```

## 测试策略

### Widget 测试

1. **`gallery_detail_page_test.dart`**（新增或扩展）
   - 元信息正确显示（拍摄时间相对+绝对、心情标签、原图保留状态）
   - `originalPath == null` 时"后期修图"按钮置灰
   - `originalPath != null` 时点击按钮 push `/gallery/edit`
   - 场景 Chip 点击 push `/capture/scene-detail`
   - 模板 Chip 点击 push `/templates/detail`
   - 无 templateId / sceneId 时 Chip 区不渲染

2. **`gallery_edit_page_test.dart`**（新增）
   - 加载照片后 `_localPostProcess` / `_localTransform` 正确初始化
   - 调整参数后预览实时更新
   - 点击导出按钮触发 `dao.updateEdit`
   - 保存成功后 pop 返回
   - 只读模式横幅显示（originalPath == null）

3. **`time_format_test.dart`**（新增）
   - `formatRelativeTime` 各档位正确
   - `formatAbsoluteTime` 格式正确

### 路由测试

- `/gallery/edit?photoId=xxx` 正确解析 photoId 参数

### 回归测试

- 现有 242+ 测试全部通过
- 相册页跳转详情页流程不受影响
- 拍照流程不受影响

## 不变更项

- 拍照流程（`capture_page.dart`）已正确记录 templateId / sceneId
- 相册页（`gallery_page.dart`）跳转逻辑已正确
- `GalleryItemRecord` 数据模型字段完备
- `GalleryDao` / `TemplatesDao` / `ScenesDao` 接口不变
- `PreviewEditPanel` / `PhotoPostProcessor` / `photo_post_processor.dart` 不变

## 验收标准

1. 相册点击照片进入详情页，能看到拍摄时间（相对+绝对）、心情标签（如有）、原图保留状态
2. 若照片使用了模板/场景，详情页显示为可点击 Chip，点击跳转对应详情页
3. 详情页底部"后期修图"按钮，点击进入修图页
4. 修图页可调整色彩/细节/滤镜/裁剪旋转 4 类参数，实时预览
5. 修图页点击导出后保存到原文件 + 自动返回详情页，详情页预览刷新为新版本
6. 原图未保留时（originalPath == null）"后期修图"按钮置灰
7. 三端（OHOS / iOS / Android）行为一致，无原生代码
8. `flutter analyze` 0 error / 0 warning
9. 现有 242+ 测试全部通过
