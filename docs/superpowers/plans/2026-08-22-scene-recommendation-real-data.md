# 场景推荐真实数据化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将首页场景推荐、首页「收藏/管理」入口、场景详情页从 mock 数据改为真实数据，并展示该场景下拍摄的真实照片。

**Architecture:** 仅改动 Flutter 客户端。首页卡片通过 `SceneRecommendationService` 携带真实封面（自定义场景取 `SceneRecord.coverUrl`，预设取 `ScenePreset.exampleImages` 首图）；场景详情页直接以 `ScenesDao.getById` 的真实 `SceneRecord` 为数据源，新增「此场景拍摄」区块读取 `GalleryDao.getByScene` 的照片并支持全屏查看；成就区改为真实照片数。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6，flutter_riverpod，go_router，sqflite。

## Global Constraints

- 仅改 `lumira_app_flutter/`，不动后端。
- 无真实封面 / 无照片时统一展示主题化占位图，避免白屏；不在 UI 写死 `Colors.xxx` 作为皮肤色，一律走 `tokens.*`。
- 封面渲染优先级：`data:image/` → http/本地路径 → 占位图。`imageSeed` 不再用于 picsum 兜底。
- `homeSceneRecosProvider` 返回空时展示空态，**不得**回退写死的 `HomeMockData.scenes`。
- 场景详情页以 `sceneRecordToCustom` / `sceneRecordToPreset`（`scene_record_mapper.dart`）构造真实 `ScenePreset`；仅当 DB 无该场景时回退 `ScenePresetsData.getScenePreset(id)`。
- 照片展示校验 `_notHidden`（`GalleryDao.getByScene` 已内置）。
- 每次改完后端无关，本计划仅 Flutter 端，提交信息用 `feat:`/`test:` 前缀。

---

### Task 1: `SceneReco` 增加 `coverUrl` 并改造卡片封面渲染

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/data/home_mock_data.dart:16-35`
- Modify: `lumira_app_flutter/lib/features/home/widgets/scene_reco_card.dart:159-187`
- Modify: `lumira_app_flutter/test/features/home/scene_reco_card_asset_test.dart`（改为断言 coverUrl 渲染）

**Interfaces:**
- Consumes: 现有 `SceneReco`（含 `badgeText`/`badgeBrand`/`photoCount`）。
- Produces: `SceneReco.coverUrl`（`String`，默认 `''`）；`SceneRecoCard._buildCoverImage` 按 coverUrl 渲染。

- [ ] **Step 1: 修改模型，写入失败意图（编译期）**

在 `home_mock_data.dart` 的 `SceneReco` 类中新增字段：

```dart
class SceneReco {
  const SceneReco({
    required this.id,
    required this.name,
    required this.vibe,
    required this.imageSeed,
    required this.badgeText,
    required this.badgeBrand,
    required this.photoCount,
    this.coverUrl = '',
  });

  final String id;
  final String name;
  final String vibe;
  final String imageSeed; // 不再用于 picsum 兜底；仅保留字段兼容
  final String badgeText;
  final bool badgeBrand;
  final int photoCount;
  /// 真实封面：`data:image/` base64、http(s)、本地文件路径；空串表示无封面
  final String coverUrl;
}
```

- [ ] **Step 2: 运行测试确认现有 asset 测试将失败（行为变更）**

在 `lumira_app_flutter/` 下运行：

```
flutter test test/features/home/scene_reco_card_asset_test.dart
```

Expected: 因卡片不再渲染 `imageSeed` 的 asset 图，断言 `AssetImage` 将 FAIL。

- [ ] **Step 3: 改造卡片封面渲染**

在 `scene_reco_card.dart` 顶部补充 `import 'dart:convert'; import 'dart:io';`，并把 `_buildCoverImage` 替换为：

```dart
/// 封面图：优先级 data:image/ → http(s)/本地路径 → 统一主题化占位图
Widget _buildCoverImage(ThemeTokens tokens) {
  final placeholder = Container(
    color: tokens.surfaceAlt,
    child: Icon(
      Icons.image_outlined,
      size: 32,
      color: tokens.textTertiary,
    ),
  );
  final cover = scene.coverUrl;
  if (cover.isEmpty) return placeholder;
  if (cover.startsWith('data:image/')) {
    // base64Decode 可能 throws；Image.memory 的 errorBuilder 只捕获解码错误，
    // 故用 try 包裹并在失败时回退占位图
    Widget decode() {
      final comma = cover.indexOf(',');
      final b64 = comma >= 0 ? cover.substring(comma + 1) : cover;
      return Image.memory(
        base64Decode(b64),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }
    try {
      return decode();
    } catch (_) {
      return placeholder;
    }
  }
  if (cover.startsWith('http://') || cover.startsWith('https://')) {
    return CachedNetworkImage(
      url: cover,
      fit: BoxFit.cover,
      placeholder: placeholder,
      errorWidget: placeholder,
    );
  }
  return Image.file(
    File(cover),
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => placeholder,
  );
}
```

- [ ] **Step 4: 重写封面测试**

替换 `scene_reco_card_asset_test.dart` 全部内容为：

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/home/data/home_mock_data.dart';
import 'package:lumira_app_flutter/features/home/widgets/scene_reco_card.dart';

void main() {
  Widget harness(SceneReco scene) {
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SceneRecoCard(scene: scene, onTap: _noop),
        ),
      ),
    );
  }

  testWidgets('coverUrl 为 http 时使用 CachedNetworkImage', (tester) async {
    await tester.pumpWidget(harness(SceneReco(
      id: 'scene-x',
      name: '网络场景',
      vibe: 'v',
      imageSeed: 's',
      badgeText: '推荐',
      badgeBrand: false,
      photoCount: 0,
      coverUrl: 'https://example.com/c.jpg',
    )));
    await tester.pump();
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('coverUrl 为空时显示占位图（Image 数量为 0）', (tester) async {
    await tester.pumpWidget(harness(SceneReco(
      id: 'scene-x',
      name: '无封面',
      vibe: 'v',
      imageSeed: 's',
      badgeText: '推荐',
      badgeBrand: false,
      photoCount: 0,
    )));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.image_outlined), findsWidgets);
  });

  testWidgets('coverUrl 为 data:image 时使用 Image.memory', (tester) async {
    final tinyPng =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
    await tester.pumpWidget(harness(SceneReco(
      id: 'scene-x',
      name: '数据场景',
      vibe: 'v',
      imageSeed: 's',
      badgeText: '推荐',
      badgeBrand: false,
      photoCount: 0,
      coverUrl: 'data:image/png;base64,$tinyPng',
    )));
    await tester.pump();
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, isNotEmpty);
    expect(images.first.image, isA<MemoryImage>());
  });
}

void _noop() {}
```

> 说明：`CachedNetworkImage` 来自 `image_cache.dart`。若测试框架报 `CachedNetworkImageProvider` 网络异常，可在测试中使用 `tester.pump()` 后仅断言类型存在，不触发加载完成。

- [ ] **Step 5: 运行测试通过**

```
flutter test test/features/home/scene_reco_card_asset_test.dart
```

Expected: PASS（3 个用例）。

- [ ] **Step 6: Commit**

```
git add lumira_app_flutter/lib/features/home/data/home_mock_data.dart lumira_app_flutter/lib/features/home/widgets/scene_reco_card.dart lumira_app_flutter/test/features/home/scene_reco_card_asset_test.dart
git commit -m "feat(home): SceneReco 增加 coverUrl，卡片移除 picsum 改为真实封面/占位图"
```

---

### Task 2: `SceneRecommendationService` 携带真实封面 + Provider 去掉 mock 兜底

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/services/scene_recommendation_service.dart`
- Modify: `lumira_app_flutter/lib/features/home/data/home_providers.dart:180-192`
- Modify: `lumira_app_flutter/lib/features/home/pages/home_page.dart:448-486`
- Test: `lumira_app_flutter/test/features/home/scene_recommendation_service_test.dart`（新建）

**Interfaces:**
- Consumes: `SceneRecord.coverUrl`、`ScenePreset.exampleImages`、`GalleryDao.countByScene`。
- Produces: `SceneReco.coverUrl` 被正确填充（自定义=record.coverUrl，预设=exampleImages 首图）。

- [ ] **Step 1: 为 `_SceneInfo` 增加 `coverUrl` 并填充**

在 `scene_recommendation_service.dart` 的 `_SceneInfo` 增加字段：

```dart
class _SceneInfo {
  final String id;
  final String name;
  final String vibe;
  final String category;
  final bool isCustom;
  final bool isPreset;
  final bool isFavorite;
  final String coverUrl; // 新增

  const _SceneInfo({
    required this.id,
    required this.name,
    required this.vibe,
    required this.category,
    required this.isCustom,
    required this.isPreset,
    required this.isFavorite,
    this.coverUrl = '', // 新增
  });
}
```

在 `build()` 构建统一场景列表处填充：

自定义（`s` 为 `SceneRecord`）：

```dart
allScenes.add(_SceneInfo(
  id: s.id,
  name: s.name,
  vibe: s.vibe,
  category: s.category,
  isCustom: true,
  isPreset: false,
  isFavorite: s.isFavorite,
  coverUrl: s.coverUrl, // 新增
));
```

预设（`s` 为 `ScenePreset`）：

```dart
allScenes.add(_SceneInfo(
  id: s.id,
  name: s.name,
  vibe: s.vibe,
  category: s.category,
  isCustom: false,
  isPreset: true,
  isFavorite: customScenes.any((c) => c.id == s.id && c.isFavorite),
  coverUrl: s.exampleImages.isNotEmpty ? s.exampleImages.first : '', // 新增
));
```

更新 `_toReco`：

```dart
SceneReco _toReco(_SceneInfo s, int photoCount, String badgeText, {bool brand = false}) {
  return SceneReco(
    id: s.id,
    name: s.name,
    vibe: s.vibe,
    imageSeed: 'scene-home-${s.id}',
    badgeText: badgeText,
    badgeBrand: brand,
    photoCount: photoCount,
    coverUrl: s.coverUrl, // 新增
  );
}
```

- [ ] **Step 2: 写服务单测（先建库 schema）**

新建 `test/features/home/scene_recommendation_service_test.dart`，复用与 `recommendation_service_test.dart` 相同的 schema（`gallery_items` + `scenes`）：

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/core/db/dao/scenes_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/capture/data/scene_presets_data.dart';
import 'package:lumira_app_flutter/features/home/services/scene_recommendation_service.dart';

void main() {
  late Database db;
  late GalleryDao galleryDao;
  late ScenesDao scenesDao;
  late SceneRecommendationService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('scene_reco_test_');
    final dbPath = p.join(tempDir.path, 'test.db');
    db = await openDatabase(dbPath, version: 1, onCreate: _onCreate);
    galleryDao = GalleryDao(db);
    scenesDao = ScenesDao(db);
    service = SceneRecommendationService(
      galleryDao: galleryDao,
      scenesDao: scenesDao,
    );
  });

  tearDown(() => db.close());

  test('自定义场景 coverUrl 透传到推荐结果', () async {
    await _seedScene(db,
        id: 'custom_x',
        name: '我的咖啡馆',
        category: 'indoor',
        coverUrl: 'data:image/png;base64,AAAA');
    final recos = await service.build();
    final target = recos.where((r) => r.id == 'custom_x').toList();
    expect(target, isNotEmpty);
    expect(target.first.coverUrl, 'data:image/png;base64,AAAA');
  });

  test('预设场景 coverUrl 取 exampleImages 首图', () async {
    final preset = ScenePresetsData.getScenePreset('cafe-window')!;
    // 有一张该场景下的照片 → 进入槽位 1（最常去）
    await _seedGalleryItem(db, id: 'g1', sceneId: 'cafe-window');
    final recos = await service.build();
    expect(recos, isNotEmpty);
    expect(recos.first.id, 'cafe-window');
    expect(recos.first.coverUrl,
        preset.exampleImages.isNotEmpty ? preset.exampleImages.first : '');
  });

  test('自定义场景 coverUrl 为空时返回空串（不抛异常）', () async {
    await _seedScene(db,
        id: 'custom_y',
        name: '无封面场景',
        category: 'light',
        coverUrl: '');
    final recos = await service.build();
    final target = recos.where((r) => r.id == 'custom_y').toList();
    expect(target, isNotEmpty);
    expect(target.first.coverUrl, '');
  });
}

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE ${Tables.galleryItems} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colDataUrl} TEXT,
      ${Tables.colFilePath} TEXT,
      ${Tables.colOriginalPath} TEXT,
      ${Tables.colTransform} TEXT,
      ${Tables.colPostProcess} TEXT,
      ${Tables.colSceneId} TEXT,
      ${Tables.colTemplateId} TEXT,
      ${Tables.colKitId} TEXT,
      ${Tables.colMood} TEXT,
      ${Tables.colLut} TEXT,
      ${Tables.colGalleryItemIsFavorite} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCreatedAt} INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE ${Tables.scenes} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colIcon} TEXT NOT NULL DEFAULT '',
      ${Tables.colCategory} TEXT NOT NULL,
      ${Tables.colStyle} TEXT NOT NULL DEFAULT '',
      ${Tables.colFilterJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colVibe} TEXT NOT NULL DEFAULT '',
      ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
      ${Tables.colExampleImagesJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colTipsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colWhereToShoot} TEXT NOT NULL DEFAULT '',
      ${Tables.colBestTime} TEXT NOT NULL DEFAULT '',
      ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colRelatedCategory} TEXT NOT NULL DEFAULT '',
      ${Tables.colRecommendedTagIdsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colTagIdsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colCreator} TEXT NOT NULL DEFAULT 'user',
      ${Tables.colIsFavorite} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCoverUrl} TEXT NOT NULL DEFAULT '',
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
}

Future<void> _seedScene(Database db,
    {required String id,
    required String name,
    required String category,
    String coverUrl = ''}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.insert(Tables.scenes, {
    Tables.colId: id,
    Tables.colName: name,
    Tables.colCategory: category,
    Tables.colCreator: 'user',
    Tables.colCoverUrl: coverUrl,
    Tables.colCreatedAt: now,
    Tables.colUpdatedAt: now,
  });
}

Future<void> _seedGalleryItem(Database db,
    {required String id, required String sceneId}) async {
  await db.insert(Tables.galleryItems, {
    Tables.colId: id,
    Tables.colSceneId: sceneId,
    Tables.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
  });
}
```

> 注：`scenes` 表须含 `colCoverUrl` 列；若项目的真实 schema 已包含该列，测试直接对齐即可。

- [ ] **Step 3: 运行测试失败确认**

```
flutter test test/features/home/scene_recommendation_service_test.dart
```

Expected: 编译时 `coverUrl` 尚未填充导致断言 FAIL。

- [ ] **Step 4: 去掉 Provider 的 mock 兜底**

在 `home_providers.dart` 中修改：

```dart
  final result = await service.build();
  return result; // 移除 HomeMockData.scenes 兜底
```

- [ ] **Step 5: 改造首页场景网格空态/骨架**

在 `home_page.dart` 的 `_SceneRecoGrid` 中，去掉基于 `HomeMockData.scenes` 的骨架与空态兜底，改为占位加载与空态：

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncScenes = ref.watch(homeSceneRecosProvider);

    return asyncScenes.when(
      loading: () => _buildSkeleton(),
      error: (_, __) => _buildSkeleton(),
      data: (scenes) {
        if (scenes.isEmpty) return const SizedBox.shrink(); // 空态
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.50,
          children: scenes
              .map((scene) => SceneRecoCard(
                    scene: scene,
                    onTap: () => onTap(scene.id),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildSkeleton() {
    // 改为通用加载占位，不再使用 mock 场景数据
    return const SizedBox(
      height: 120,
      child: Center(
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
    );
  }
```

- [ ] **Step 6: 运行测试通过 + 全局回归**

```
flutter test test/features/home/scene_recommendation_service_test.dart
flutter test                                                        # 或对应 affected 目录
```

Expected: 新单测 PASS；既有单测（含 recommendation_service_test、scene_reco_card_asset_test）PASS。

- [ ] **Step 7: Commit**

```
git add lumira_app_flutter/lib/features/home/services/scene_recommendation_service.dart lumira_app_flutter/lib/features/home/data/home_providers.dart lumira_app_flutter/lib/features/home/pages/home_page.dart lumira_app_flutter/test/features/home/scene_recommendation_service_test.dart
git commit -m "feat(home): 场景推荐携带真实封面，Provider 移除 mock 兜底并新增空态/加载态"
```

---

### Task 3: 首页「收藏 / 管理」入口语义分离

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/pages/home_page.dart:194-209`
- Test: `lumira_app_flutter/test/features/home/home_scene_manage_tab_test.dart`（新建）

**Interfaces:**
- Consumes: `RouteNames.captureSceneManage`、`RouteNames.paramTab`。
- Produces: 收藏→`tab=fav`，管理→`tab=custom`。新增纯函数 `sceneManageTabFor(label)` 供测试。

- [ ] **Step 1: 写失败测试（纯函数映射）**

新建 `test/features/home/home_scene_manage_tab_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/home/pages/home_page.dart'
    show sceneManageTabFor;

void main() {
  test('收藏 → tab=fav，管理 → tab=custom', () {
    expect(sceneManageTabFor('收藏'), 'fav');
    expect(sceneManageTabFor('管理'), 'custom');
  });
}
```

Expected: 编译失败（`sceneManageTabFor` 不存在）。

- [ ] **Step 2: 实现映射函数并接入导航**

在 `home_page.dart` 中新增顶层纯函数（文件末尾）：

```dart
/// 首页场景推荐标题右侧链接 → 场景管理 tab 参数
/// 收藏落在「我的收藏」，管理落在「自定义场景」
String sceneManageTabFor(String label) {
  switch (label) {
    case '管理':
      return 'custom';
    case '收藏':
      return 'fav';
    default:
      return 'fav';
  }
}
```

修改 `onLinkTap` 的 `case '收藏'` / `case '管理'` 分支统一走该函数：

```dart
onLinkTap: (label) {
  switch (label) {
    case '查看全部':
      GoRouter.of(context).push(RouteNames.scenes);
      break;
    case '收藏':
    case '管理':
      GoRouter.of(context).push(RouteNames.build(
        RouteNames.captureSceneManage,
        {RouteNames.paramTab: sceneManageTabFor(label)},
      ));
      break;
  }
},
```

- [ ] **Step 3: 运行测试通过**

```
flutter test test/features/home/home_scene_manage_tab_test.dart
```

Expected: PASS。

- [ ] **Step 4: Commit**

```
git add lumira_app_flutter/lib/features/home/pages/home_page.dart lumira_app_flutter/test/features/home/home_scene_manage_tab_test.dart
git commit -m "feat(home): 首页收藏/管理入口分别落在 fav/custom tab"
```

---

### Task 4: 场景详情页真实数据加载

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/pages/capture_scene_detail_page.dart`（`_loadScene`，65-92 行）

**Interfaces:**
- Consumes: `ScenesDao.getById`、`sceneRecordToCustom`/`sceneRecordToPreset`（`scene_record_mapper.dart`）、`ScenePresetsData.getScenePreset`。
- Produces: `_scene` 全部来自真实 `SceneRecord`/真实预设，不再依赖 `CaptureSceneMockData.getSceneById` 作为主数据源。

- [ ] **Step 1: 写失败意图（编译期）：补充 import**

在 `capture_scene_detail_page.dart` 顶部新增：

```dart
import '../../../core/db/dao/gallery_dao.dart';
import '../../../shared/widgets/images/fullscreen_image_gallery.dart';
import '../data/scene_record_mapper.dart';
import '../data/scene_presets_data.dart';
```

并用真实映射替换 `_loadScene` 逻辑：

```dart
  Future<void> _loadScene() async {
    final id = widget.sceneId ?? '';
    // 1. 优先真实 DB 数据
    try {
      final dao = await ref.read(scenesDaoProvider.future);
      final record = await dao.getById(id);
      if (record != null) {
        _sceneRecord = record;
        _isFav = record.isFavorite;
        // 按 creator 映射到领域模型：user → 自定义，否则 → 预设
        _scene = record.creator == 'user'
            ? sceneRecordToCustom(record)
            : sceneRecordToPreset(record);
        if (_scene is CustomScenePreset) {
          _editableTagIds =
              List<String>.from((_scene! as CustomScenePreset).tagIds);
        }
        return;
      }
    } catch (_) {
      // DAO 异常，下方回退真实预设
    }
    // 2. DB 无该场景 → 真实内置预设
    final preset = ScenePresetsData.getScenePreset(id);
    if (preset != null) {
      _scene = preset;
      _isFav = false;
      if (preset is CustomScenePreset) {
        _editableTagIds = List<String>.from(preset.tagIds);
      }
    } else {
      _scene = null;
      _isFav = false;
    }
  }
```

- [ ] **Step 2: 静态检查编译通过**

```
cd lumira_app_flutter && flutter analyze lib/features/capture/pages/capture_scene_detail_page.dart
```

Expected: 无未定义符号错误（`GalleryItemRecord` 等用到时在 Task 5 引入）。

> 说明：`_loadScene` 尚未使用 `GalleryItemRecord`，本 Task 只完成数据源替换；照片加载在 Task 5。

- [ ] **Step 3: Commit**

```
cd lumira_app_flutter && git add lib/features/capture/pages/capture_scene_detail_page.dart
git add lumira_app_flutter/lib/features/capture/pages/capture_scene_detail_page.dart
git commit -m "feat(capture): 场景详情页改用真实 SceneRecord 数据源"
```

---

### Task 5: 场景详情新增「此场景拍摄」区块

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/pages/capture_scene_detail_page.dart`（state、build、新增区块组件）

**Interfaces:**
- Consumes: `GalleryDao.getByScene(sceneId)`、`GalleryItemRecord`、`FullscreenImageGallery`。
- Produces: `_scenePhotos`（真实照片）、`_ScenePhotosSection`（横向缩略 + 空态引导）、`_openViewer(index)`。

- [ ] **Step 1: 扩展 state 与加载照片**

在 state 中新增：

```dart
  List<GalleryItemRecord> _scenePhotos = [];
```

在 `_loadScene` 中，无论 DB 有记录还是回退预设，在 `return` 前都查询照片（把照片加载提到 `return` 之前；DB 有记录分支里在 `return` 上一行加载）：

```dart
        // 加载该场景下拍摄的真实照片
        final galleryDao = await ref.read(galleryDaoProvider.future);
        _scenePhotos = await galleryDao.getByScene(id);
        return;
```

回退预设分支同样在返回前加载：

```dart
    } else {
      _scene = null;
      _isFav = false;
    }
    final galleryDao = await ref.read(galleryDaoProvider.future);
    _scenePhotos = await galleryDao.getByScene(id);
```

在 build 中把照片区块插入成就区之前（`_AchievementSection` 上方）：

```dart
                      _TipsSection(scene: scene),
                      _ScenePhotosSection(
                        sceneName: scene.name,
                        photos: _scenePhotos,
                        onOpenViewer: _openViewer,
                        onCapture: _goCapture,
                      ),
                      _AchievementSection(
                        scene: scene,
                        photoCount: _scenePhotos.length,
                      ),
```

- [ ] **Step 2: 添加照片源解析与全屏打开**

在 state 中新增：

```dart
  /// 照片显示源：filePath > dataUrl > originalPath，取首个非空
  String? _photoSource(GalleryItemRecord p) {
    for (final c in [p.filePath, p.dataUrl, p.originalPath]) {
      if (c != null && c.isNotEmpty) return c;
    }
    return null;
  }

  void _openViewer(int index) {
    final urls = _scenePhotos
        .map(_photoSource)
        .where((u) => u != null && u.isNotEmpty)
        .cast<String>()
        .toList();
    if (urls.isEmpty) return;
    final i = index.clamp(0, urls.length - 1);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FullscreenImageGallery(urls: urls, initialIndex: i),
    ));
  }
```

- [ ] **Step 3: 添加「此场景拍摄」区块组件**

在文件内（`_AchievementSection` 上方）新增：

```dart
/// 该场景下拍摄的照片（真实数据，横向缩略 + 全屏查看；无照片引导拍摄）
class _ScenePhotosSection extends ConsumerWidget {
  const _ScenePhotosSection({
    required this.sceneName,
    required this.photos,
    required this.onOpenViewer,
    required this.onCapture,
  });

  final String sceneName;
  final List<GalleryItemRecord> photos;
  final void Function(int index) onOpenViewer;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    if (photos.isEmpty) {
      // 空态：引导「用此场景拍照」
      return _Section(
        title: '此场景拍摄',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          decoration: BoxDecoration(
            color: tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(Icons.photo_library_outlined,
                  size: 36, color: tokens.textTertiary),
              const SizedBox(height: 8),
              Text(
                '还没有用「$sceneName」拍过照片',
                style: TextStyle(fontSize: 13, color: tokens.textSecondary),
              ),
              const SizedBox(height: 12),
              LumiraButton(
                variant: ButtonVariant.primary,
                child: const Text('用此场景拍照'),
                onPressed: onCapture,
              ),
            ],
          ),
        ),
      );
    }

    return _Section(
      title: '此场景拍摄',
      child: SizedBox(
        height: 140,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: photos.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final src =
                [photos[i].filePath, photos[i].dataUrl, photos[i].originalPath]
                    .where((c) => c != null && c.isNotEmpty)
                    .cast<String>()
                    .toList();
            final url = src.isEmpty ? '' : src.first;
            return GestureDetector(
              onTap: () => onOpenViewer(i),
              behavior: HitTestBehavior.opaque,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 100,
                  height: 140,
                  child: _ScenePhotoThumb(url: url, tokens: tokens),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 单张场景照片缩略：http / data / 本地文件 → 统一占位
class _ScenePhotoThumb extends StatelessWidget {
  const _ScenePhotoThumb({required this.url, required this.tokens});
  final String url;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: tokens.surfaceAlt,
      child: Icon(Icons.image_outlined, size: 28, color: tokens.textTertiary),
    );
    if (url.isEmpty) return placeholder;
    if (url.startsWith('data:image/')) {
      Widget decode() {
        final comma = url.indexOf(',');
        final b64 = comma >= 0 ? url.substring(comma + 1) : url;
        return Image.memory(base64Decode(b64), fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder);
      }
      try {
        return decode();
      } catch (_) {
        return placeholder;
      }
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return CachedNetworkImage(
        url: url,
        fit: BoxFit.cover,
        placeholder: placeholder,
        errorWidget: placeholder,
      );
    }
    return Image.file(File(url),
        fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder);
  }
}
```

> 需在文件顶部补充 import：`import 'dart:convert'; import 'dart:io';`（`base64Decode` / `File`）。

- [ ] **Step 4: 静态检查 + 运行既有 capture 测试**

```
flutter analyze lib/features/capture/pages/capture_scene_detail_page.dart
```

Expected: 无错误。若仓库有测试目录 `test/features/capture/`，运行相关测试确认不回归。

- [ ] **Step 5: Commit**

```
git add lumira_app_flutter/lib/features/capture/pages/capture_scene_detail_page.dart
git commit -m "feat(capture): 场景详情展示该场景拍摄的真实照片并支持全屏查看"
```

---

### Task 6: 场景成就区真实数据化（删除 mock 周榜）

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/pages/capture_scene_detail_page.dart`（`_AchievementSection` 与对应调用处）

**Interfaces:**
- Consumes: `photoCount`（由 Task 5 传入真实照片数）。
- Produces: `_AchievementSection` 使用真实 `photoCount` 构造 `SceneAchievement`，不再传 `rank`，删除周榜依赖。

- [ ] **Step 1: 新增真实成就构造函数**

在文件顶部（顶层，state 类之外）新增：

```dart
/// 由真实照片数构造场景成就（等级阈值：0 → 未开始；1-2 → 初遇 Lv1；3-9 → 熟悉 Lv2；10+ → 精通 Lv3）
SceneAchievement buildSceneAchievement(String sceneId, int count) {
  if (count == 0) {
    return SceneAchievement(
        sceneId: sceneId, level: 0, levelName: '未开始', photoCount: 0, nextLevelCount: 1);
  }
  if (count < 3) {
    return SceneAchievement(
        sceneId: sceneId, level: 1, levelName: '初遇', photoCount: count, nextLevelCount: 3);
  }
  if (count < 10) {
    return SceneAchievement(
        sceneId: sceneId, level: 2, levelName: '熟悉', photoCount: count, nextLevelCount: 10);
  }
  return SceneAchievement(
      sceneId: sceneId, level: 3, levelName: '精通', photoCount: count, nextLevelCount: 30);
}
```

- [ ] **Step 2: 改写 `_AchievementSection` 为接收真实 photoCount 并无周榜**

替换 `_AchievementSection`：

```dart
class _AchievementSection extends StatelessWidget {
  const _AchievementSection({required this.scene, required this.photoCount});
  final ScenePreset scene;
  final int photoCount;

  @override
  Widget build(BuildContext context) {
    final achievement = buildSceneAchievement(scene.id, photoCount);
    return _Section(
      title: '我的成就',
      child: SceneAchievementCard(
        achievement: achievement,
        sceneName: scene.name,
        // rank 为空 → 不渲染排行榜
      ),
    );
  }
}
```

- [ ] **Step 3: 静态检查 + 运行测试**

```
flutter analyze lib/features/capture/pages/capture_scene_detail_page.dart
flutter test
```

Expected: 编译通过；既有测试 PASS。

> 确认第 634-649 行旧逻辑（`CaptureSceneMockData.getSceneAchievement` 与 `weeklyRanking`）已被删除。

- [ ] **Step 4: Commit**

```
git add lumira_app_flutter/lib/features/capture/pages/capture_scene_detail_page.dart
git commit -m "feat(capture): 场景成就区改为真实照片数，删除 mock 周榜"
```

---

### Task 7: 全量验证与收尾

**Files:**
- Run only，不新增文件。

- [ ] **Step 1: 全量测试**

```
cd lumira_app_flutter && flutter test
```

Expected: 全绿。

- [ ] **Step 2: 全量静态检查**

```
flutter analyze
```

Expected: 无新增告警。

- [ ] **Step 3: 对照设计验收清单人工验证**

1. 首页场景推荐卡片显示真实场景名/照片数，封面为真实封面。
2. 有真实数据时不再回退到 4 个写死 mock 场景。
3. 首页「收藏」落在 fav tab、「管理」落在 custom tab。
4. 场景详情各字段来自真实 `SceneRecord`/真实预设；「此场景拍摄」展示该场景照片并全屏可看；无照片有空态。
5. 成就区显示真实照片数与等级，无 mock 周榜。