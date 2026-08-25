# 模板多姿势 Phase 2：Flutter UI、拍摄姿势切换与编辑器双列表 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: 用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 按任务逐条执行。步骤用 `- [ ]` 勾选跟踪。

**Goal:** 在 Phase 1（领域层 pose→poses、cover→images）基础上，完成 Flutter 端消费与编辑增强：详情页多效果图画廊 + 姿势组预览、拍摄页多姿势切换按钮、编辑器「封面与剪影」Tab 拆为效果图/姿势两条独立列表，并落地多图持久化（`images_json` 列）。

**Architecture:** 先在 DB/领域/映射层打通多图与多姿势的持久化；再逐层改造 UI：详情页（画廊 + 姿势组）、拍摄页（仅 poses>1 显示切换按钮，只切换 silhouette 不动共享配置）、编辑器（双列表）。所有改动延续 Phase 1 的「兼容 getter（`pose`/`cover`/`coverData`）」策略，尽量不破坏既有调用点。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（**不支持 Dart 3 records/pattern**）；flutter_riverpod + go_router；sqflite（`custom_templates` 表）。

## 全局约束

- 不改 `lumira-app/`（uni-app 原型）。
- 禁止硬编码皮肤色；UI 一律随 `appThemeProvider` / `uiStyleProvider`（4 UI 风格 × 主题），遵循既有「叠照片浮层」取向（新拟态去阴影、玻璃允许模糊等），**不混搭风格**。
- 多姿势切换只影响剪影/姿势参考显示，**不影响**共享的构图/相机/场景/后期参数。
- 效果图与剪影两条列表**独立增删，数量可不等、不一一对应**；封面统一取 `images[0]`。
- `poses.length <= 1` 时**不显示**切换按钮（保持单姿势行为）。
- 老数据兼容：旧单 `pose_json` Map、旧 `cover`/`cover_data` 单图继续可读。
- 禁止硬编码 `Images 数量`/`模板数量` 断言与真实标签以外的文案推断；数量断言更新到新模型口径。
- 不删除列；新增 `images_json` 列通过 DB version 迁移。

---

### Task 1: DB —— `images_json` 列 + `TemplateRecord.images`

**Files:**
- Modify: `lumira_app_flutter/lib/core/db/tables.dart`（新增列常量）
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart`（建表 + 迁移）
- Modify: `lumira_app_flutter/lib/core/db/dao/templates_dao.dart`
- Test: `lumira_app_flutter/test/core/db/templates_dao_images_test.dart`

**Interfaces:**
- Consumes: Phase 1 的 `TemplateImage`（`features/capture/domain/photo_template.dart`）。
- Produces:
  - `Tables.colImagesJson = 'images_json'`
  - `TemplateRecord.images`（`List<TemplateImage>?`，新字段，读 `images_json`）
  - `TemplateRecordsDao.upsertList`（供批量写入）沿用现有 API，`images` 走 `images_json` 列。

- [ ] **Step 1: 新增列常量与建表列**

在 `tables.dart` 的 `colPoseJson`（第 23 行）旁新增：

```dart
static const String colImagesJson = 'images_json';
```

在 `database_provider.dart` 的 `custom_templates` 建表语句（约第 150 行 `colPoseJson` 之后、`colCameraJson` 之前）加入一列：

```sql
      ${Tables.colImagesJson} TEXT NOT NULL DEFAULT '[]',
```

- [ ] **Step 2: 递增 DB version 并写迁移**

找到 `_onCreate`/`_onUpgrade` 与 `_dbVersion` 常量。将版本号 +1（若当前为 N，则改为 N+1，并在 `_onUpgrade` 的 switch 尾部追加）：

```dart
// case N: /* 上一版本 */ ... ; continue
case N: // 新迁移：新增 images_json 列
  await db.execute(
    'ALTER TABLE ${Tables.customTemplates} '
    'ADD COLUMN ${Tables.colImagesJson} TEXT NOT NULL DEFAULT \'[]\'',
  );
  // fall through（continue）到最新 version
```

> 提示：`_onUpgrade` 中各 case 通常以 `await ...; continue schemaState;` 透传。请按既有迁移风格补 `case N`，N = 当前版本号（newVersion - 1 那条）。

- [ ] **Step 3: `TemplateRecord` 增加 `images` 字段**

在 `TemplateRecord`（`templates_dao.dart`）：`cover`/`coverData` 之后新增字段 + ctor 参数 + `toRow`/`fromRow`/`copyWith`：

```dart
/// 效果图列表（images_json 列）。null 表示未存储（旧模板无该列数据）。
/// [0] 为封面；仅 Phase 1 存量模板由 cover/coverData 派生，Phase 2 起直接读数组。
final List<TemplateImage>? images;
```

ctor（`this.images,`）、`copyWith`（`List<TemplateImage>? images`，`images: images ?? this.images`）同步新增。

`toRow()` 增加：
```dart
Tables.colImagesJson:
    (images == null) ? null : jsonEncode(images!.map(_imageToJson).toList()),
```

`fromRow()` 增加：
```dart
images: _decodeImages(row[Tables.colImagesJson]),
```

新增两个私有静态方法（放在 `_decodeJsonAny` 附近）：
```dart
static Map<String, dynamic> _imageToJson(TemplateImage img) =>
    <String, dynamic>{'url': img.url, if (img.data != null) 'data': img.data};

static List<TemplateImage>? _decodeImages(Object? raw) {
  if (raw is NotZero) return null; // 占位——应在风格后替换为真正的解析，见下
  if (raw is String && raw.isNotEmpty) {
    final list = jsonDecode(raw) as List<dynamic>?;
    if (list == null) return null;
    return list
        .whereType<Map<String, dynamic>>()
        .map((e) => TemplateImage(
              url: (e['url'] as String?) ?? '',
              data: e['data'] as String?,
            ))
        .toList();
  }
  return null;
}
```

> ⚠️ 上述 `_decodeImages` 中的 `if (raw is NotZero)` 是**占位行，禁止保留**。`TemplateRecord` 需要 import `TemplateImage`（`import '../../features/capture/domain/photo_template.dart';`）。删除占位行，只保留 `raw is String` 分支。空 JSON 数组 `[]` 应返回空 `List`（非 null）。

- [ ] **Step 4: 更新 DAO 中对 `cover`/`coverData` 的既有消费点**

`flutter analyze` 后，确认 `templates_dao.dart` 无新报错（`images` 为可空，不影响既有读取）。

- [ ] **Step 5: 写测试**

新建 `test/core/db/templates_dao_images_test.dart`：
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app/core/db/dao/templates_dao.dart';
import 'package:lumira_app/features/capture/domain/photo_template.dart';

void main() {
  TemplateRecord base({dynamic pose = <dynamic>[], List<TemplateImage>? images}) =>
      TemplateRecord(
        id: 't1', name: 'n', author: '', version: '1.0', category: 'portrait',
        classification: const {'type': 'portrait'}, tags: const [], tagIds: const [],
        price: 0, cover: 'u0', description: '', referenceSource: '',
        composition: const {}, pose: pose, camera: const {}, sceneGuide: const {},
        postProcess: const {}, createdAt: 1, updatedAt: 1,
        isBuiltin: true, isRecommended: false, images: images,
      );

  test('toRow/fromRow 往返保留多张效果图', () {
    final rec = base(images: [
      const TemplateImage(url: 'u0'),
      const TemplateImage(url: 'u1', data: 'data:image/png;base64,abc'),
    ]);
    final row = rec.toRow();
    final back = TemplateRecord.fromRow(row);
    expect(back.images, isNotNull);
    expect(back.images!.length, 2);
    expect(back.images![0].url, 'u0');
    expect(back.images![1].data, 'data:image/png;base64,abc');
  });

  test('fromRow 兼容旧数据（无 images_json → images=null）', () {
    final row = base().toRow()..remove('images_json');
    final back = TemplateRecord.fromRow(row);
    expect(back.images, isNull);
  });
}
```

- [ ] **Step 6: 运行测试**

```bash
flutter test test/core/db/templates_dao_images_test.dart
```
Expected: PASS（两个用例）。

- [ ] **Step 7: Commit**

```bash
git add lumira_app_flutter/lib/core/db/tables.dart lumira_app_flutter/lib/core/db/database_provider.dart lumira_app_flutter/lib/core/db/dao/templates_dao.dart test/core/db/templates_dao_images_test.dart
git commit -m "feat(template): 新增 images_json 列与 TemplateRecord.images 多效果图存取"
```

---

### Task 2: 领域层 —— `TemplateMeta.images` 落为存储列表，映射层读写多图

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/domain/photo_template.dart`
- Modify: `lumira_app_flutter/lib/features/templates/services/template_mapper.dart`
- Test: `lumira_app_flutter/test/features/templates/services/template_mapper_images_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `TemplateRecord.images`。
- Produces:
  - `TemplateMeta.images` 从「getter（由 cover/coverData 派生）」改为「**存储字段**」；`cover`/`coverData` 改为只读 getter（`images[0]`）。构造参数保留 `cover`/`coverData` 以兼容存量 const 内置模板调用（未传 `images` 时用其构造单元素列表）。
  - `_imagesFromRecord(TemplateRecord)` 在 Phase 1 基础上**拼接 `r.images`**（跳过首张即封面），供多效果图详情展示。
  - `toPhotoTemplate`/`toRecord` 写入 `images`。

- [ ] **Step 1: `TemplateMeta.images` 改存储字段**

将 `photo_template.dart` 中 `TemplateMeta` 的 `images` getter（约 L126-128）删除，改为字段 + 派生 cover/coverData：

```dart
/// 效果图列表，[0] 即封面。多效果图时由 mapper 从 images_json 填充。
final List<TemplateImage> images;

/// 封面 = images[0] 的 url。兼容旧代码读取 meta.cover。
String get cover => images.isNotEmpty ? images.first.url : '';
/// 封面对应 base64 data（可选）。
String? get coverData => images.isNotEmpty ? images.first.data : null;

const TemplateMeta({
  // ... 其余参数不变 ...
  List<TemplateImage>? images,
  String cover = '',
  String? coverData,
  // ...
}) : images = (images != null)
        ? images
        : (cover.isNotEmpty || coverData != null
            ? <TemplateImage>[TemplateImage(url: cover, data: coverData)]
            : const <TemplateImage>[]);
```

同步调整 `copyWith`：移除 `String? cover`/`Object? coverData = _unset` 参数，新增 `Object? images = _unset`（风格同 Phase 1 `_unset` 哨兵）：
```dart
TemplateMeta copyWith({
  // ...
  Object? images = _unset,
  // ... 移除 cover: / coverData: 两参数 ...
}) => TemplateMeta(
      // ...
      images: identical(images, _unset)
          ? this.images
          : images as List<TemplateImage>,
      // ...
    );
```
`==`/`hashCode`：移除 `cover == other.cover` / `coverData == other.coverData`；`cover` 改 `images` → `listEquals(images, other.images)`、`hashCode` 用 `Object.hashAll(images.map((e) => e.hashCode))`。

> ⚠️ 迁移期间禁止把 `meta.cover` / `meta.coverData` 一起删除——它们是公开读取的 getter，必须先保留。若 `flutter analyze` 报某处 `TemplateMeta(cover:` 或 `.copyWith(cover:)` 无法匹配（因参数改名为 images），在该处改为 `images:[TemplateImage(url: ...)]`。

- [ ] **Step 2: 映射层读多图**

在 `template_mapper.dart` 中，将 Phase 1 的 `_imagesFromRecord` 改为拼接 `r.images`：

```dart
static List<TemplateImage> _imagesFromRecord(TemplateRecord r) {
  final list = <TemplateImage>[];
  if (r.images != null && r.images!.isNotEmpty) {
    list.addAll(r.images!);
    return list; // images_json 优先（已含封面，[0]）。
  }
  // 兜底：仅 cover/coverData 单图（内置/旧数据）。
  if (r.cover.isNotEmpty) list.add(TemplateImage(url: normalizeAssetUrl(r.cover)));
  if (r.coverData != null && r.coverData!.isNotEmpty) {
    if (list.isEmpty) {
      list.add(TemplateImage(url: '', data: r.coverData));
    } else {
      list[0] = TemplateImage(url: list.first.url, data: r.coverData);
    }
  }
  return list;
}
```

- [ ] **Step 3: 映射层写多图（toRecord）**

`toRecord` 中 `cover`/`coverData` 两行**改为**新 `images` 字段（`TemplateRecord` 已支持 `images`，不再依赖 cover 单图派生）：

```dart
// 删除这两行：
//   cover: tpl.meta.cover,
//   coverData: tpl.meta.coverData,
// 替换为：
images: tpl.meta.images.isEmpty ? null : tpl.meta.images,
cover: tpl.meta.cover,
coverData: tpl.meta.coverData,
```
> 说明：`cover`/`coverData` 列保留写首图，供旧版本/分享码等路径兼容读取；`images` 列承载完整多图。

- [ ] **Step 4: 写测试**

新建 `test/features/templates/services/template_mapper_images_test.dart`：
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app/core/db/dao/templates_dao.dart';
import 'package:lumira_app/features/capture/domain/photo_template.dart';
import 'package:lumira_app/features/templates/services/template_mapper.dart';

void main() {
  test('toRecord 写多张效果图到 images', () {
    final tpl = const PhotoTemplate(
      meta: TemplateMeta(
        id: 't1', name: 'n', category: 'portrait',
        classification: TemplateClassification(type: 'portrait'),
        images: [TemplateImage(url: 'u0'), TemplateImage(url: 'u1')],
      ),
      composition: Composition(),
      pose: Pose(name: 'a'),
      camera: CameraParams(),
      sceneGuide: SceneGuide(),
      postProcess: PostProcess(color: PostProcessColor()),
    );
    final rec = TemplateMapper.toRecord(tpl, createdAt: 1);
    expect(rec.images!.length, 2);
    expect(rec.images![0].url, 'u0');
    expect(rec.cover, 'u0'); // 首图兼容回写
  });

  test('toPhotoTemplate 优先读 images_json（多图）', () {
    final rec = TemplateRecord(
      id: 't1', name: 'n', author: '', version: '1.0', category: 'portrait',
      classification: const {'type': 'portrait'}, tags: const [], tagIds: const [],
      price: 0, cover: 'u0', description: '', referenceSource: '',
      composition: const {}, pose: <dynamic>[], camera: const {}, sceneGuide: const {},
      postProcess: const {}, createdAt: 1, updatedAt: 1,
      isBuiltin: true, isRecommended: false,
      images: const [TemplateImage(url: 'a'), TemplateImage(url: 'b')],
    );
    final tpl = TemplateMapper.toPhotoTemplate(rec);
    expect(tpl.meta.images.length, 2);
    expect(tpl.meta.cover, 'a');
  });

  test('无 images_json 时由 cover 派生单图（兼容）', () {
    final rec = TemplateRecord(
      id: 't1', name: 'n', author: '', version: '1.0', category: 'portrait',
      classification: const {'type': 'portrait'}, tags: const [], tagIds: const [],
      price: 0, cover: 'u0', description: '', referenceSource: '',
      composition: const {}, pose: <dynamic>[], camera: const {}, sceneGuide: const {},
      postProcess: const {}, createdAt: 1, updatedAt: 1,
      isBuiltin: true, isRecommended: false,
    );
    final tpl = TemplateMapper.toPhotoTemplate(rec);
    expect(tpl.meta.images.length, 1);
    expect(tpl.meta.cover, 'u0');
  });
}
```

- [ ] **Step 5: 全绿验证**

```bash
flutter analyze && flutter test test/features/templates test/core/db
```
Expected: 0 error；新增 3 用例 PASS，既有用例不回退。

- [ ] **Step 6: Commit**

```bash
git add lumira_app_flutter/lib/features/capture/domain/photo_template.dart lumira_app_flutter/lib/features/templates/services/template_mapper.dart test/features/templates/services/template_mapper_images_test.dart
git commit -m "feat(template): TemplateMeta.images 落为存储列表，映射层读写多效果图"
```

---

### Task 3: 详情页 —— 多效果图画廊 + 姿势组预览

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/data/templates_browse_mock_data.dart`
- Modify: `lumira_app_flutter/lib/features/templates/pages/templates_detail_page.dart`

**Interfaces:**
- Consumes: Task 2 的 `TemplateMeta.images`；Phase 1 的 `PhotoTemplate.poses`。
- Produces:
  - `TemplateDetail.images`（`List<TemplateImage>?`，默认 null → 用 cover/coverData 单图）
  - `TemplateDetail.poses`（`List<PoseData>?`，默认 null → 单 pose）
  - `_PreviewGallery`（横滑画廊，替代 `_PreviewImage`）
  - `_PoseReferenceCard` 支持多姿势切换（`template.poses != null && length>1`）

对 `fromPhotoTemplate` 补充填充 `images`/`poses`。

- [ ] **Step 1: `TemplateDetail` 增加 `images`/`poses`**

在 `templates_browse_mock_data.dart` 的 `TemplateDetail` 增加字段、构造参数（`this.images, this.poses`）、并在 `copyWithClassification` 中透传：

```dart
/// 效果图列表（多图时非 null；null 表示仅有 cover/coverData 单图）。
final List<TemplateImage>? images;
/// 姿势组（多姿势时非 null；null 表示单 pose）。
final List<PoseData>? poses;

// getter：无显式 images 时由 cover/coverData 构造单元素列表，供 UI 统一遍历。
List<TemplateImage> get displayImages => images ?? <TemplateImage>[
  if (cover?.isNotEmpty == true) TemplateImage(url: cover!, data: coverData),
];
// getter：pose 组（兼容单 pose）。
List<PoseData> get displayPoses => poses ?? <PoseData>[pose];
```

> `displayImages` / `displayPoses` 让既有（mock 单图）调用点零改动，画廊/姿势组统一遍历 `displayImages` / `displayPoses`。`TemplateImage` import 自 `features/capture/domain/photo_template.dart`。

- [ ] **Step 2: `fromPhotoTemplate` 填充多图/多姿势**

在 `fromPhotoTemplate` 的 `TemplateDetail(...)` 增加：
```dart
// ... pose: PoseData(...) 保持（displayPoses 默认用它兜底）。
images: tpl.meta.images.isEmpty ? null : tpl.meta.images,
poses: tpl.poses.isEmpty
    ? null
    : tpl.poses
          .map((p) => PoseData(
                silhouetteType: p.silhouette.type,
                silhouetteData: p.silhouette.data,
                positionX: p.position.x,
                positionY: p.position.y,
                description: p.description,
                scale: p.scale,
                rotation: p.rotation,
              ))
          .toList(),
```
并确保 `TemplateDetail` 构造传 `images:`/`poses:` 参数。

- [ ] **Step 3: 详情页 `_PreviewImage` → `_PreviewGallery`（横滑多图）**

将 `_PreviewImage` 改造为横滑画廊（保留封面首图 + 分类角标；`images > 1` 时支持横向滑动）：

```dart
class _PreviewGallery extends StatefulWidget {
  const _PreviewGallery({required this.template, required this.tokens});
  final TemplateDetail template;
  final ThemeTokens tokens;
  ... (State: PageController + int _current)
  @override
  Widget build(BuildContext context) {
    final imgs = template.displayImages;
    final controller = PageController();
    return FadeUp(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: _aspectRatio,
            child: Stack(children: [
              PageView.builder(
                controller: controller,
                itemCount: imgs.length,
                itemBuilder: (_, i) => TemplateCoverImage(
                  cover: imgs[i].url,
                  coverData: imgs[i].data,
                  fit: BoxFit.cover,
                  fallback: ...same as before...,
                  errorFallback: ...,
                ),
              ),
              // 分类角标（沿用原先 _PreviewImage 的 Positioned 覆盖层）
              ...categoryBadge...,
              // 仅多图时显示指示器/页码（右下角）
              if (imgs.length > 1) _PageIndicator(current: ..., total: imgs.length),
            ]),
          ),
        ),
      ),
    );
  }
}
```
将 `_buildDetailContent` 里的 `_PreviewImage(template:..., tokens:...)` 调用替换为 `_PreviewGallery(template:..., tokens:...)`。`_PageIndicator` 用 `tokens.surface`（半透明）+ 细边/无毛玻璃，按当前风格走「叠图浮层」取向。

- [ ] **Step 4: `_PoseReferenceCard` 支持姿势组切换**

改 `_PoseReferenceCard` 为 `StatefulWidget`，用 `template.displayPoses`。当 `length>1` 时在标题行右侧加「上一姿势/下一姿势」小按钮（`LumiraIconButton`），当前姿势用 `PoseData pose = displayPoses[_index]`。剪影渲染逻辑保持复用 `SilhouetteLayer(...)`（用 `pose.silhouetteType/silhouetteData/positionX/positionY/scale/rotation`）。描述展示 `pose.description`。

```dart
// _PoseReferenceCard 内：
final poses = template.displayPoses;
final PoseData pose = poses[_index]; // _index 为 Stateful 内部状态
// 标题右侧，仅 poses.length > 1 时：
Row(children: [
  Icon(Icons.accessibility_new, ...),
  const SizedBox(width: 8),
  Text('姿势参考'), const Spacer(),
  LumiraIconButton(icon: Icons.chevron_left, size:18, onPressed: () => setState(()=>_index=(_index-1+poses.length)%poses.length), color: tokens.brand),
  Text('${_index+1}/${poses.length}', style: ...),
  LumiraIconButton(icon: Icons.chevron_right, size:18, onPressed: () => setState(()=>_index=(_index+1)%poses.length), color: tokens.brand),
])
```

- [ ] **Step 5: 运行分析**

```bash
flutter analyze
```
Expected: 0 error（`_PreviewImage` 已替换，无残留引用；`Icons.chevron_left/right` 与 `LumiraIconButton` 已导入）。

- [ ] **Step 6: Commit**

```bash
git add lumira_app_flutter/lib/features/templates/data/templates_browse_mock_data.dart lumira_app_flutter/lib/features/templates/pages/templates_detail_page.dart
git commit -m "feat(templates): 详情页多效果图画廊与姿势组预览"
```

---

### Task 4: 拍摄页 —— 多姿势切换按钮与剪影切换

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/data/capture_state.dart`
- Modify: `lumira_app_flutter/lib/features/capture/widgets/camera_preview.dart`
- Modify: 拍摄页（`capture_page.dart` / 取景器叠加层，加「切换姿势」按钮）
- Test: `lumira_app_flutter/test/features/capture/capture_pose_switch_test.dart`

**Interfaces:**
- Consumes: Phase 1 `PhotoTemplate.poses`。
- Produces:
  - `CaptureState.currentPoseIndexProvider`（`StateProvider<int>`）
  - `CaptureState.updateCurrentPose(WidgetRef ref)`
  - `camera_preview` 从 `editable.poses[currentPoseIndex]` 读 silhouette（替代 `editable.pose`）。

- [ ] **Step 1: 新增 pose index provider + 辅助**

在 `capture_state.dart` 的「模板编辑状态」区域新增：

```dart
/// 当前生效的姿势下标（多姿势模板拍摄切换用）。
/// originalTemplate 变化时复位为 0。
static final currentPoseIndexProvider = StateProvider<int>((ref) {
  ref.watch(currentTemplateIdProvider); // 模板切换时复位
  return 0;
});

/// 切换到下一个姿势（循环）。仅 poses>1 有意义。
static void nextPose(WidgetRef ref) {
  final editable = ref.read(editableTemplateProvider);
  final poses = editable?.poses ?? const <Pose>[];
  if (poses.length <= 1) return;
  final cur = ref.read(currentPoseIndexProvider);
  ref.read(currentPoseIndexProvider.notifier).state = (cur + 1) % poses.length;
}
```
并在 `resetAll` 中把 `currentPoseIndexProvider` 置 0：
```dart
container.read(currentPoseIndexProvider.notifier).state = 0;
```

> 说明：`currentTemplateIdProvider` 变化 → `editableTemplateProvider` 自动重建新模板副本，`currentPoseIndexProvider` 因 watch 而复位 0。

- [ ] **Step 2: `camera_preview` 读当前姿势剪影**

在 `camera_preview.dart` 的 `else if (editable != null)` 分支，由 `editable.pose` 改为当前姿势：

```dart
} else if (editable != null) {
  final poses = editable.poses;
  final idx = ref.watch(CaptureState.currentPoseIndexProvider);
  final Pose current =
      poses.isNotEmpty ? poses[idx.clamp(0, poses.length - 1)] : const Pose();
  silhouetteType = current.silhouette.type;
  silhouetteData = current.silhouette.data;
  silhouetteScale = current.scale;
  silhouetteRotation = current.rotation;
  silhouettePosX = current.position.x;
  silhouettePosY = current.position.y;
  hasSilhouette = silhouetteData != 'none';
}
```

- [ ] **Step 3: 拍摄页叠加「切换姿势」按钮**

在拍摄页取景器叠加层（悬浮在取景器内的控件区，跟随 `tokens`/`uiStyle`）增加切换按钮。仅当当前模板 `poses.length > 1` 时显示。按钮用「叠照片浮层」取向（实心/半透明 `tokens.surface` + 细边，无阴影/无模糊，按当前风格）：

```dart
final poses = ref.watch(CaptureState.editableTemplateProvider)?.poses ?? const <Pose>[];
if (poses.length > 1)
  Positioned(... align 取景器某角 ...,
    child: LumiraIconButton.icon(
      icon: Icons.swap_horiz,
      label: Text('${idx+1}/${poses.length}'),
      color: tokens.textPrimary,
      backgroundColor: tokens.surface.withOpacity(0.7), // 风格自适应：neural/female 见项目规范
      onPressed: () => CaptureState.nextPose(ref),
    ),
  );
```
> 放置位置跟随既有取景器浮层控件的对齐方式（参考亮度/闪光等按钮的定位）。按钮文字随 `poses.length` 与 `currentPoseIndexProvider` 重建。

- [ ] **Step 4: 写测试**

新建 `test/features/capture/capture_pose_switch_test.dart`（纯 provider 逻辑，不启相机）：
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumira_app/features/capture/data/capture_state.dart';
import 'package:lumira_app/features/capture/domain/photo_template.dart';

void main() {
  final container = ProviderContainer();

  setUp(() {
    container.read(CaptureState.currentTemplateIdProvider.notifier).state = null;
  });
  tearDown(() => container.dispose());

  PhotoTemplate tplN(String id, int n) => PhotoTemplate(
        meta: TemplateMeta(id: id, name: id, category: 'portrait',
            classification: const TemplateClassification(type: 'portrait')),
        composition: const Composition(),
        poses: List.generate(n, (i) => Pose(name: 'p$i')),
        camera: const CameraParams(),
        sceneGuide: const SceneGuide(),
        postProcess: const PostProcess(color: PostProcessColor()),
      );

  test('nextPose 在单姿势时不切换', () {
    container.read(CaptureState.currentTemplateIdProvider.notifier).state = 'a';
    container.read(CaptureState.editableTemplateProvider.notifier).state = tplN('a', 1);
    CaptureState.nextPose(container); // 无 WidgetRef，提供 test 用 helper
    expect(container.read(CaptureState.currentPoseIndexProvider), 0);
  });
}
```
> 若 `nextPose(WidgetRef)` 用 WidgetRef 不便在 test 中调用，可在 `CaptureState` 增加一个可注入的 `ProviderContainer` 版本 `nextPoseFor(ProviderContainer, ProviderContainer-like)`，或在 test 用 `ProviderContainer` 包一个 `WidgetRefHelper`。**保持简洁**：将 `nextPose` 实现为接受 `WidgetRef ref` 的同时，抽一个顶层私有函数 `_nextPose(reader)` 由非泛型 `reader`（`ProviderContainer`/`WidgetRef` 均可调 `ref.read`）。若实现复杂，退化为：测试直接断言 index provider 的读写，不足以保证——请在实现时给出可测的纯函数（如 `int nextIndex(int cur, int count) => (cur+1)%count`），测试断言该纯函数 + provider 复位逻辑即可。

- [ ] **Step 5: 运行测试 + 分析**

```bash
flutter analyze
flutter test test/features/capture/capture_pose_switch_test.dart
```
Expected: 0 error；测试 PASS。

- [ ] **Step 6: Commit**

```bash
git add lumira_app_flutter/lib/features/capture/data/capture_state.dart lumira_app_flutter/lib/features/capture/widgets/camera_preview.dart lumira_app_flutter/lib/features/capture/pages/capture_page.dart test/features/capture/capture_pose_switch_test.dart
git commit -m "feat(capture): 拍摄页多姿势切换（当前姿势下标 + 剪影跟随）"
```

---

### Task 5: 编辑器表单模型 —— `EditorForm` 多姿势/多图

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/data/templates_editor_mock_data.dart`
- Modify: `lumira_app_flutter/lib/features/templates/services/template_mapper.dart`
- Test: `lumira_app_flutter/test/features/templates/editor_multi_pose_test.dart`

**Interfaces:**
- Consumes: Task 2 `TemplateRecord.images`；Phase 1 `TemplateRecord.pose`(dynamic List)。
- Produces:
  - `EditorForm.poses`（`List<EditorFormPose>` backing）+ 兼容 getter `EditorFormPose get pose => poses.isNotEmpty ? poses.first : EditorFormPose();`
  - `EditorFormMeta.images`（`List<EditorFormMetaImage>`，`[0]`=封面）+ 兼容 getter `String? get coverImage => images.isNotEmpty ? images.first.data : null;`
  - `EditorFormMeta.addImage(String dataUrl)` / 列表操作方法。
  - `fromEditorForm` 写 `poses` 数组 + `images`；`toEditorForm` 读回。

- [ ] **Step 1: 新增 `EditorFormMetaImage` 并改 `coverImage`**

在 `templates_editor_mock_data.dart` 新增：
```dart
/// 效果图（编辑器内统一以 base64 data URL 存储）。
/// images[0] 即封面。
class EditorFormMetaImage {
  EditorFormMetaImage({required this.data});
  String data; // data URL
  EditorFormMetaImage copy() => EditorFormMetaImage(data: data);
}
```
`EditorFormMeta`：
```dart
/// 效果图列表，[0] 即封面。兼容 getter [coverImage] 读首张。
List<EditorFormMetaImage> images;

EditorFormMeta({
  // ...
  List<EditorFormMetaImage>? images,
  String? coverImage, // 兼容旧构造：如果传了 coverImage 而没传 images，作为首张
  // ...
}) : images = images ??
         (coverImage != null && coverImage!.isNotEmpty
             ? <EditorFormMetaImage>[EditorFormMetaImage(data: coverImage!)]
             : const <EditorFormMetaImage>[]);

/// 封面 = images[0].data（兼容旧 `coverImage` 读取）。
String? get coverImage => images.isNotEmpty ? images.first.data : null;
```
> 注意：把原来可变的 `String? coverImage` 字段改成 getter，原 `_form.meta.coverImage = dataUrl` 的**赋值写法会失效**。因此提供：
> ```dart
> void setCoverImage(String? url) {
>   if (url == null || url.isEmpty) {
>     images = <EditorFormMetaImage>[]; // 清空铺底，仍由 UI 保留占位
>   } else if (images.isEmpty) {
>     images = <EditorFormMetaImage>[EditorFormMetaImage(data: url)];
>   } else {
>     images = <EditorFormMetaImage>[EditorFormMetaImage(data: url), ...images.skip(1)];
>   }
> }
> ```
> 并同步更新 `EditorFormMeta.copy()`（复制 `images` 列表）。

- [ ] **Step 2: `EditorForm.pose` → `poses` 列表（兼容 getter）**

`EditorForm`：
```dart
/// 姿势列表（多姿势）。兼容 getter [pose] 读首张，供编辑器内既有控件操作 poses[0]。
List<EditorFormPose> poses;

EditorForm({
  // ...
  List<EditorFormPose>? poses,
  EditorFormPose? pose, // 兼容旧构造：单姿势时包装为列表
  // ...
}) : poses = pose != null
        ? <EditorFormPose>[pose]
        : (poses ?? const <EditorFormPose>[]);

EditorFormPose get pose => poses.isNotEmpty ? poses.first : EditorFormPose();

EditorForm copy() => EditorForm(
      meta: meta.copy(),
      composition: composition.copy(),
      poses: poses.map((p) => p.copy()).toList(),
      camera: camera.copy(),
      sceneGuide: sceneGuide.copy(),
      postProcess: postProcess.copy(),
      fillLight: fillLight?.copy(),
    );
```
保持 `EditorFormPose` 不变（含 `name` 字段需补充：Phase 1 的 `_poseToJson` 已写 `name`，但编辑器 `EditorFormPose` 尚无形参 `name`。给 `EditorFormPose` 加 `String name = ''`，`copy()` 透传）。

- [ ] **Step 3: `fromEditorForm` 写多姿势/多图**

在 `template_mapper.dart` `fromEditorForm` 的 `pose:` 段由单元素 `[ {...} ]` 改为遍历 `form.poses`，并给 `coverData` 改 `images`：

```dart
// coverData: form.meta.coverImage  →  改为 images:
images: form.meta.images.isEmpty
    ? null
    : form.meta.images.map((e) => TemplateImage(url: '', data: e.data)).toList(),
cover: form.meta.coverImage ?? '',
coverData: form.meta.coverImage,

pose: <dynamic>[
  for (final p in form.poses)
    <String, dynamic>{
      'name': p.name,
      'silhouette': editorSilhouetteToJson(p.silhouette),
      'position': {'x': p.position.x, 'y': p.position.y},
      'scale': p.scale,
      'rotation': p.rotation,
      'description': p.description,
    },
],
```

- [ ] **Step 4: `toEditorForm` 读多姿势/多图**

`toEditorForm` 中 `pose` 段改为读 `r.poses` 数组；`meta.coverImage:` 原名读取改为 `images:` 列表：

```dart
// coverImage: r.coverData,  →  images:
images: (r.images == null)
    ? (r.coverData?.isNotEmpty == true
        ? <editor.EditorFormMetaImage>[editor.EditorFormMetaImage(data: r.coverData!)]
        : const <editor.EditorFormMetaImage>[])
    : r.images!.map((img) => editor.EditorFormMetaImage(data: img.data ?? img.url)).toList(),
```
`pose:` 段改为遍历（兼容 List / 旧单 Map）：
```dart
final poses = poseIsListAsMapList(poseRaw); // 见下 helper，返回 List<Map>
...
pose 构造参数改为： poses: <editor.EditorFormPose>[
  for (final p in poseList) editor.EditorFormPose(
    silhouette: _toEditorSilhouette(silhouetteFromJson((p['silhouette'] as Map<String,dynamic>?) ?? {})),
    position: Position(x: (p['position']?['x'] as num?)?.toDouble() ?? .5, ...),
    scale: (p['scale'] as num?)?.toDouble() ?? 1.0,
    rotation: (p['rotation'] as num?)?.toDouble() ?? 0,
    description: (p['description'] as String?) ?? '',
    name: (p['name'] as String?) ?? '',
  ),
],
```
> 兼容：`poseRaw` 为数组取原样；为旧单 Map 则包成单元素 List。复用 Phase 1 的解析思路，抽一个私有 `List<Map<String,dynamic>> _poseListRaw(dynamic raw)` 统一处理。

- [ ] **Step 5: 更新 mock 表单（现有 pose: 调用已兼容）**

确认 `TemplatesEditorMockData` 的 `draftForm`/`existingTemplateForm`/`blankForm` 用 `EditorFormPose(...)` 构造仍通过（走兼容 `pose:` 参数包装进 `poses`）。

- [ ] **Step 6: 写测试**

新建 `test/features/templates/editor_multi_pose_test.dart`：
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app/core/db/dao/templates_dao.dart';
import 'package:lumira_app/features/templates/data/templates_editor_mock_data.dart';
import 'package:lumira_app/features/templates/services/template_mapper.dart';

void main() {
  test('EditorForm 兼容 pose getter 返回 poses.first', () {
    final f = EditorForm(
      meta: EditorFormMeta(name: 'n'),
      composition: EditorFormComposition(),
      poses: [EditorFormPose(description: 'a'), EditorFormPose(description: 'b')],
      camera: EditorFormCamera(),
      sceneGuide: EditorFormSceneGuide(),
      postProcess: EditorFormPostProcess(),
    );
    expect(f.poses.length, 2);
    expect(f.pose.description, 'a');
  });

  test('metro images 第 0 张即封面，coverImage getter 读首张', () {
    final m = EditorFormMeta(name: 'n')
      ..images = [EditorFormMetaImage(data: 'u0'), EditorFormMetaImage(data: 'u1')];
    expect(m.coverImage, 'u0');
  });

  test('fromEditorForm 写多姿势数组 + 多图', () {
    final f = EditorForm(
      meta: (EditorFormMeta(name: 'n')
        ..images = [EditorFormMetaImage(data: 'u0'), EditorFormMetaImage(data: 'u1')]),
      composition: EditorFormComposition(),
      poses: [EditorFormPose(description: 'a', name: 'p1'), EditorFormPose(description: 'b')],
      camera: EditorFormCamera(),
      sceneGuide: EditorFormSceneGuide(),
      postProcess: EditorFormPostProcess(),
    );
    // 签名已确认：TemplateRecord fromEditorForm(editor.EditorForm form, {String? id, required int createdAt})
    final rec = TemplateMapper.fromEditorForm(f, createdAt: 1);
    expect((rec.pose as dynamic is List), isTrue);
    expect((rec.pose as List).length, 2);
    expect(rec.images!.length, 2);
  });
}
```

- [ ] **Step 7: 运行测试 + 分析**

```bash
flutter analyze
flutter test test/features/templates
```
Expected: 0 error；新增用例 PASS，既有 editor/mapper 测试不回退。

- [ ] **Step 8: Commit**

```bash
git add lumira_app_flutter/lib/features/templates/data/templates_editor_mock_data.dart lumira_app_flutter/lib/features/templates/services/template_mapper.dart test/features/templates/editor_multi_pose_test.dart
git commit -m "feat(templates): 编辑器表单模型支持多姿势 poses 与多效果图 images"
```

---

### Task 6: 编辑器 UI —— 「封面与剪影」Tab 双列表

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/pages/templates_editor_page.dart`

**Interfaces:**
- Consumes: Task 5 的 `EditorForm.poses` / `EditorFormMeta.images` / 新增操作方法（`setCoverImage`、`addImage`）。
- Produces:
  - `_buildPosesForm`：姿势列表（增/选/删）+ 复用 `_Step3Pose` 绑定当前 `form.poses[_poseIndex]`。
  - `_buildImagesField`：效果图列表（多图缩略图横排 + 新增/删除/设为封面）。
  - 编辑器状态 `int _poseIndex`；所有 `_form.pose` 回调改为操作 `_form.poses[_poseIndex]`。

- [ ] **Step 1: 新增编辑器状态 `_poseIndex` 与回调改写**

在 `_EditorFormPage` 的 state 增加 `int _poseIndex = 0;`。将所有原 `_form.pose.xxx = v` 的处理器（`_onSilhouetteSourceChange`/`_selectBuiltinSilhouette`/`_importSilhouetteImage`/`_openSilhouetteEditor`/拖拽与滑块等）改为作用于 `_form.poses[_poseIndex]`：
```dart
void _ensurePoseIndex() {
  if (_form.poses.isEmpty) _form.poses.add(EditorFormPose());
  if (_poseIndex >= _form.poses.length) _poseIndex = _form.poses.length - 1;
}
// 例：_selectBuiltinSilhouette
void _selectBuiltinSilhouette(String key) {
  _ensurePoseIndex();
  _onChange(() {
    _form.poses[_poseIndex].silhouette.type = 'builtin';
    _form.poses[_poseIndex].silhouette.data = key;
    _form.poses[_poseIndex].silhouette.filename = null;
    _form.poses[_poseIndex].silhouette.sizeKB = null;
  });
}
```
> 每个处理器开头调用 `_ensurePoseIndex()`，防止空列表/越界。

- [ ] **Step 2: 姿势列表选择器（增/切换/删）**

在 `_buildTabContent` case 1 中，`_Step3Pose` 之前插入姿势组选择条 `_BuildPoseListBar`：

```dart
case 1:
  children.add(_StepCard(tokens: tokens, title: '效果图', child: _buildImagesField(tokens)));
  children.add(const SizedBox(height: 12));
  children.add(_buildPoseListBar(tokens));   // 姿势组：添加 / 切换 / 删除
  children.add(const SizedBox(height: 12));
  children.add(_Step3Pose( ... form: _form, poseIndex: _poseIndex, ... ));
  break;
```

`_Step3Pose` 增加 `poseIndex` 参数，内部所有 `form.pose.xxx` 改为 `form.poses[poseIndex].xxx`（`_onChange` 处理器已在 Step 1 改写为 `_form.poses[_poseIndex]`）。

`_buildPoseListBar` 示例：
```dart
Widget _buildPoseListBar(ThemeTokens tokens) {
  _ensurePoseIndex();
  return _StepCard(
    tokens: tokens, title: '姿势列表',
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (var i = 0; i < _form.poses.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            // 当前姿势高亮胶囊（LumiraButton/GhostActionButton 按主题）
            _posePill(tokens, i),
          ],
          const SizedBox(width: 8),
          // 添加姿势
          LumiraIconButton(icon: Icons.add, onPressed: _addPose, color: tokens.brand),
        ]),
      ),
      // 当前姿势删除（至少保留 1 个）
      if (_form.poses.length > 1) ...,
    ]),
  );
}

void _addPose() {
  _setState(() {
    _form.poses.add(EditorFormPose(name: '姿势${_form.poses.length + 1}'));
    _poseIndex = _form.poses.length - 1;
  });
}
void _removePose(int i) {
  if (_form.poses.length <= 1) return;
  _setState(() {
    _form.poses.removeAt(i);
    if (_poseIndex >= _form.poses.length) _poseIndex = _form.poses.length - 1;
  });
}
```
> `_posePill(i)`：显示 `pose.name`（或 `姿势${i+1}`）；选中态用 `tokens.brand`，否则 `tokens.surfaceAlt`；必用 `GestureDetector/InkWell` + 主题色，禁硬编码。

- [ ] **Step 3: 效果图列表（多图，首张=封面）**

将 `_buildCoverField` 改造为 `_buildImagesField`：横向缩略图列表 + 「添加」按钮；第一张标「封面」角标；长按/角标删除；点缩略图放大预览（复用 `_showCoverPreviewDialog`）。

```dart
Widget _buildImagesField(ThemeTokens tokens) {
  _ensureImages();
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _FieldLabel(tokens: tokens, text: '效果图（第一张为封面）'),
    SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _form.meta.images.length + 1, // +1 = 添加按钮
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == _form.meta.images.length) {
            // 添加效果图按钮（调用 _showCoverImagePicker → 追加到 images 末尾或首张后）
            return _AddImageTile(tokens, onTap: _addCoverImage);
          }
          final img = _form.meta.images[i];
          return _ImageTile(
            tokens: tokens, data: img.data, isCover: i == 0,
            onTap: () => _showCoverPreviewDialog(context, img.data, tokens, _replaceCoverImage),
            onDelete: _form.meta.images.length > 1 ? () => _removeImage(i) : null,
          );
        },
      ),
    ),
  ]);
}

void _ensureImages() {
  if (_form.meta.images.isEmpty) _form.meta.images.add(EditorFormMetaImage(data: ''));
}
void _addCoverImage() {
  _showCoverImagePicker(onPicked: (String? dataUrl) {
    // 选取图片：追加到列表末尾；若仅 1 张占位空图则替换之
  });
}
void _removeImage(int i) {
  _setState(() {
    if (i == 0 && _form.meta.images.length > 1) {
      // 删除封面 → 下张自动成为封面（images[0] 语义）
    }
    _form.meta.images.removeAt(i);
    _ensureImages();
  });
}
```
> `_showCoverImagePicker` 的回调签名需与现有实现对齐（现有 `onPickCoverImage` 无参数回调）。为支持「追加」，将封面图选择回调改为带 `String? dataUrl` 参数版本，或新增 `_showCoverImagePickerWith(onPicked)`。以「不破坏现有（点位）调用」为原则调整。

- [ ] **Step 4: 封面展示兼容（`meta.coverImage` getter）**

`_buildTabContent` case 1 中原 `_StepCard(title:'封面', child:_buildCoverField(...))` 已由 Step 2/3 新增的两张卡替代。确认其它仍读取 `_form.meta.coverImage` 的位置（如基本信息预览、保存日志）都用 getter，无需改。

- [ ] **Step 5: 运行分析**

```bash
flutter analyze
```
Expected: 0 error（新增空图占位 `images.add(EditorFormMetaImage(data:''))` 需搭配「空图占位不落库」——在 `fromEditorForm` 过滤空 `data` 的 image，见 Task 5 Step 3 的 images 构造处加 `where((e)=>e.data.isNotEmpty)`）。

- [ ] **Step 6: 手动/真机验证清单**

- 新建模板「封面与剪影」Tab：默认 1 张空效果图占位、1 个空姿势。
- 添加≥2 张效果图：首张显示「封面」角标；删除首张后第二张自动成封面。
- 添加≥2 个姿势：可点击切换，`_Step3Pose` 显示对应当前姿势的剪影/参数；删除仅保留 1 个时删除按钮隐藏。
- 保存后重新编辑：`poses`/`images` 数量与内容回读正确（依赖 Task 5 落库）。

- [ ] **Step 7: Commit**

```bash
git add lumira_app_flutter/lib/features/templates/pages/templates_editor_page.dart
git commit -m "feat(templates): 编辑器封面与剪影 Tab 拆为效果图/姿势双列表"
```

---

### Task 7: 分类三级收敛 + Phase 2 完整性验证

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/pages/templates_editor_page.dart`（分类级联下拉）
- Modify: `lumira_app_flutter/lib/features/capture/domain/photo_template.dart`（`TemplateClassification` 三级注释收敛，保留 `subStyle`/`method` 兼容读取）
- Test: 更新/新增数量与树形断言（`template_registry_test.dart` 等）

**Interfaces:**
- Consumes: 设计稿《三级分类收敛》。
- Produces: 编辑器分类下拉四级 → 三级（大类 → 风格 → 子风格）；`flutter analyze` + `flutter test` 全绿。

- [ ] **Step 1: 分类下拉收敛为三级**

`templates_editor_page.dart` 中分类级联（`_FieldCategory`/级联下拉）由「大类→风格→子风格→拍法(四级)」收敛为「大类→风格→子风格」。删除「拍法/四级」选择层的渲染与 `EditorFormMeta.method` 的新写入（保留字段读取以兼容旧数据）。级联数据源沿用 `templateCategoryProvider` 中 `level<=3` 的分段。

- [ ] **Step 2: 领域分类注释收敛**

`TemplateClassification`：删除 `subStyle`/`method` 作为「分类层级」的注释语义（改注「旧四级兼容读取」），代码字段保留以兼容旧序列化。

- [ ] **Step 3: 跑全量测试**

```bash
flutter analyze
flutter test
```
Expected: 0 error；全量通过。若有 `template_registry_test.dart`/seeder 数量断言因 Phase 2 改变而失效，**本 Phase 2 不修改 seeder 数量口径**（归并到 Phase 3），仅确保 Phase 2 不新增破坏。若确有因 `TemplateMeta` 构造签名（cover→images）导致的测试编译错，按 Task 2 的迁移说明修正对应测试构造。

- [ ] **Step 4: Commit**

```bash
git add -u lumira_app_flutter/lib/features/templates/pages/templates_editor_page.dart lumira_app_flutter/lib/features/capture/domain/photo_template.dart
git commit -m "refactor(templates): 分类下拉收敛为三级 + Phase 2 全量验证"
```

---

## 自检记录

- **Spec 覆盖**：设计稿 §5.2（详情画廊+姿势组）→ Task 3；§5.3（拍摄切换）→ Task 4；§6（双列表+三级）→ Task 5/6/7；§4.1 存储 images/poses 数组 → Task 1/2；封面统一 `images[0]` → Task 2/3。
- **占位符检查**：Task 1 `_decodeImages` 明确标注 `NotZero` 占位行为「禁止保留」；Task 4/5 的「若签名不同请按实际改写」为给执行者的约束而非留空，均附了目标行为。
- **类型一致性**：`TemplateRecord.images`（Task 1）→ 供 Task 2 `_imagesFromRecord`、Task 5 `toEditorForm` 使用；`EditorForm.poses`/`EditorFormMeta.images`（Task 5）→ 供 Task 6 UI 使用；`TemplateDetail.images/poses`（Task 3）独立于 `PhotoTemplate`（mock/DAO 两层模型分离）。