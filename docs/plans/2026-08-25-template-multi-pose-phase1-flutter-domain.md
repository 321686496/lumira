# 模板多姿势（一套 = 一个模板）实现计划 —— Roadmap + Phase 1 领域层

> 日期：2026-08-25
> 关联设计：`docs/specs/2026-08-25-template-multi-pose-design.md`
> 说明：本改造跨 Flutter（领域层 / DB / UI / 表单 / seeder）、后端、后台。按 writing-plans 拆成多个独立子计划，每个子计划独立编译、独立可测。本文档含 **Phase 1（Flutter 领域层）完整可落地步骤**，Phase 2–5 在末尾给出范围与文件目标，作为后续各自独立计划的基础。

## 目标（全量）

一套 = 一个模板：`images[]`（效果图，`[0]`=封面）+ `poses[]`（姿势剪影组）+ 模板级共享配置（构图/相机/场景引导/后期）。效果图与剪影两条列表独立增删，数量不相等、不一一对应；封面统一取 `images[0]`；分类从四级收敛为三级。自定义模板表单、后台上传模板、seeder、后端存储全部同步调整。

## 架构

- 领域层 `PhotoTemplate`：`Pose pose` → `List<Pose> poses`；`TemplateMeta.cover/coverData` → `List<TemplateImage> images`（`[0]`=封面，保留 `cover`/`coverData` 只读 getter 以兼容旧代码读取）。
- 持久化：`pose_json` 改存 **JSON 数组**（TEXT 列可容纳，无需删表迁移）；读取兼容旧「单个 Map」与新版「数组」。
- 通过兼容 getter（`pose` / `cover` / `coverData`）与兼容构造参数，让既有 UI 代码在领域层调整后依旧编译。

## 技术栈

- Flutter 3.7.12 / Dart 2.19.6（不支持 Dart 3 records 语法，勿用 records/pattern）。
- 领域对象在 `lumira_app_flutter/lib/features/capture/domain/photo_template.dart`（全域名共享）。
- 映射 `lumira_app_flutter/lib/features/templates/services/template_mapper.dart`；DB `lumira_app_flutter/lib/core/db/dao/templates_dao.dart`。

## 全局约束

- 不改 `lumira-app/`（uni-app 原型）。
- 禁止硬编码皮肤色；UI 一律随主题风格，走 `appThemeProvider`/`uiStyleProvider`。
- 不引入新表/删除列；`pose_json` 兼容两种形态（Map 与 List）。
- 所有对 `record.pose` 的读取点必须兼容「Map（旧）与 List（新）」。
- 复用单一封面出口：`meta.cover`（images[0]），保证卡片/推荐封面同源。

---

# Phase 1：Flutter 领域层多姿势 / 多图建模（可独立完成）

**交付物**：领域模型 + 映射 + DB 读写兼容 + 编辑器表单往返兼容 + 导出兼容；`flutter analyze` 通过、相关单测通过。本阶段**不改 UI 与 seeder**（它们通过兼容 getter 继续工作）。

临时约定：
- 效果图多图持久化（`images_json` 列）留到 Phase 2；Phase 1 中 `images` 由现有 `cover`/`cover_data` 单图派生（首图），满足"首张即封面"与兼容。
- 编辑器表单本阶段仍为单姿势，往返时包装/解包为单元素 `poses` 数组。

---

### Task 1: 领域模型 —— `PhotoTemplate` / `TemplateMeta` / `Pose` / `TemplateImage`

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/domain/photo_template.dart`
- Test: `lumira_app_flutter/test/features/templates/services/template_mapper_multi_pose_test.dart`

**Interfaces:**
- Produces:
  - `class TemplateImage { final String url; final String? data; const TemplateImage({required this.url, this.data}); ... ==/hashCode }`
  - `TemplateMeta.get cover => images.isNotEmpty ? images.first.url : '';`
  - `TemplateMeta.get coverData => images.isNotEmpty ? images.first.data : null;`
  - `PhotoTemplate.get Pose pose => poses.isNotEmpty ? poses.first : const Pose();`（兼容旧代码读取）
  - `Pose.name`（新增字段，默认 `''`）

- [ ] **Step 1: 写失败测试**

```dart
// test/features/templates/services/template_mapper_multi_pose_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app/features/capture/domain/photo_template.dart';

void main() {
  group('TemplateMeta images/cover', () {
    test('cover/coverData 派生自 images[0]', () {
      const meta = TemplateMeta(
        id: 't1', name: 'n', category: 'portrait',
        classification: TemplateClassification(type: 'portrait'),
        images: [TemplateImage(url: 'u0'), TemplateImage(url: 'u1')],
      );
      expect(meta.cover, 'u0');
      expect(meta.coverData, isNull);
    });

    test('images 为空时 cover 为空串', () {
      const meta = TemplateMeta(
        id: 't1', name: 'n', category: 'portrait',
        classification: TemplateClassification(type: 'portrait'),
      );
      expect(meta.cover, '');
    });
  });

  group('PhotoTemplate poses', () {
    test('pose 兼容 getter 返回 poses.first', () {
      const t = PhotoTemplate(
        meta: TemplateMeta(
          id: 't1', name: 'n', category: 'portrait',
          classification: TemplateClassification(type: 'portrait'),
        ),
        composition: Composition(),
        poses: [Pose(name: 'a'), Pose(name: 'b', description: 'x')],
        camera: CameraParams(),
        sceneGuide: SceneGuide(),
        postProcess: PostProcess(color: PostProcessColor()),
      );
      expect(t.poses.length, 2);
      expect(t.poses.first.name, 'a');
      expect(t.pose.name, 'a');
    });

    test('构造仍兼容旧 pose: 参数', () {
      const t = PhotoTemplate(
        meta: TemplateMeta(
          id: 't1', name: 'n', category: 'portrait',
          classification: TemplateClassification(type: 'portrait'),
        ),
        composition: Composition(),
        pose: Pose(name: 'legacy'),
        camera: CameraParams(),
        sceneGuide: SceneGuide(),
        postProcess: PostProcess(color: PostProcessColor()),
      );
      expect(t.poses.length, 1);
      expect(t.poses.first.name, 'legacy');
    });
  });
}
```

- [ ] **Step 2: 运行并确认失败**

```bash
flutter test test/features/templates/services/template_mapper_multi_pose_test.dart
```
Expected: 编译失败 —— `TemplateMeta` 还没有 `images` 参数，`PhotoTemplate` 还没有 `poses` 参数，`Pose` 还没有 `name`。

- [ ] **Step 3: 实现领域模型**

在 `photo_template.dart` 顶部新增：

```dart
/// 模板效果图。url 为资源地址（网络/本地），data 为 base64 data URL（可选）。
/// 约定：images[0] 即封面，卡片/推荐统一取 [TemplateMeta.cover]。
class TemplateImage {
  final String url;
  final String? data;
  const TemplateImage({required this.url, this.data});

  TemplateImage copyWith({String? url, Object? data = _unset}) =>
      TemplateImage(
        url: url ?? this.url,
        data: identical(data, _unset) ? this.data : data as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemplateImage && url == other.url && data == other.data;

  @override
  int get hashCode => Object.hash(url, data);
}
```

`TemplateMeta` 修改（构造函数、字段、copyWith、==、hashCode）：

```dart
class TemplateMeta {
  // ... 其余字段保持 ...
  /// 效果图列表，images[0] 为封面。用于卡片/推荐/详情展示。
  final List<TemplateImage> images;

  const TemplateMeta({
    // ... 原参数全部保留，删除 `cover` 与 `coverData` 两个参数 ...
    this.images = const [],
    // ...
  });

  /// 封面 = images[0] 的 url。兼容旧代码读取 meta.cover。
  String get cover => images.isNotEmpty ? images.first.url : '';
  /// 封面对应 base64 data（可选）。
  String? get coverData => images.isNotEmpty ? images.first.data : null;

  TemplateMeta copyWith({
    // ... 原参数全部保留，删除 `cover`/`coverData`，新增：
    Object? images = _unset,
    // ...
  }) => TemplateMeta(
        // ...
        images: identical(images, _unset)
            ? this.images
            : images as List<TemplateImage>,
        // ...
      );

  // == 与 hashCode 中：
  //   移除 cover == other.cover / coverData == ...
  //   新增 listEquals(images, other.images)
}
```

注意：
1. 删除 ctor 里 `this.cover = ''` / `this.coverData`，删除 copyWith 里 `String? cover` / `Object? coverData = _unset` 参数（若 grep 发现其它文件调用 `copyWith(cover: ...)` 相关写法，一并纳入本任务结尾修复）。
2. `==` 改用 `listEquals(images, other.images)`，`hashCode` 用 `Object.hashAll(images.map((e) => e.hashCode))`。

`PhotoTemplate` 修改（字段、构造、copyWith、==、hashCode）。**方案：只保留 `poses` 列表属性 + 兼容 `pose` 只读 getter + 兼容构造参数 `pose:`（值注入单元素列表）。**

```dart
class PhotoTemplate {
  final TemplateMeta meta;
  final Composition composition;
  final List<Pose> poses;          // 由原 `final Pose pose;` 改为列表
  final CameraParams camera;
  final SceneGuide sceneGuide;
  final PostProcess postProcess;

  const PhotoTemplate({
    required this.meta,
    required this.composition,
    required this.camera,
    required this.sceneGuide,
    required this.postProcess,
    List<Pose>? poses,
    Pose? pose,
  }) : poses = pose != null
            ? <Pose>[pose]                 // 兼容旧 `pose:` 调用
            : (poses ?? const <Pose>[]);

  /// 兼容旧代码的单姿势读取；无姿势时返回空姿势。
  Pose get pose => poses.isNotEmpty ? poses.first : const Pose();

  PhotoTemplate copyWith({
    TemplateMeta? meta,
    Composition? composition,
    List<Pose>? poses,
    Pose? pose,
    CameraParams? camera,
    SceneGuide? sceneGuide,
    PostProcess? postProcess,
  }) =>
      PhotoTemplate(
        meta: meta ?? this.meta,
        composition: composition ?? this.composition,
        poses: poses ?? (pose != null ? <Pose>[pose] : this.poses),
        camera: camera ?? this.camera,
        sceneGuide: sceneGuide ?? this.sceneGuide,
        postProcess: postProcess ?? this.postProcess,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoTemplate &&
          meta == other.meta &&
          composition == other.composition &&
          listEquals(poses, other.poses) &&
          camera == other.camera &&
          sceneGuide == other.sceneGuide &&
          postProcess == other.postProcess;

  @override
  int get hashCode => Object.hash(meta, composition,
      Object.hashAll(poses.map((e) => e.hashCode)),
      camera, sceneGuide, postProcess);
}
```

> 保留 `pose:` 构造参数会让既有 `PhotoTemplate(pose: x)` 与 `.copyWith(pose: x)` 调用点继续编译，最大化降低本任务的改动面。`_unset` 哨兵、`Pose` 的 `name`、`==`/`hashCode` 更新见下方。

`Pose` 新增 `name` 字段并同步 copyWith/==/hashCode：

```dart
class Pose {
  final String name;
  const Pose({
    this.name = '',
    this.silhouette = const SilhouetteResource(type: 'builtin', data: 'none'),
    // ... 其余不变
  });
  // copyWith 增加 name；== / hashCode 加入 name。
}
```

- [ ] **Step 4: 更新旧构造点 / 编译检查**

```bash
flutter analyze
```
修复所有 `PhotoTemplate(pose:` / `.copyWith(pose:` 报错：改成 `poses:[x]` / `poses: [x]`。`meta.close` 相关用 `meta.images`。

- [ ] **Step 5: 运行测试确认通过**

```bash
flutter test test/features/templates/services/template_mapper_multi_pose_test.dart
```
Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add lumira_app_flutter/lib/features/capture/domain/photo_template.dart
git commit -m "feat(template): domain 模型支持多姿势 poses 与多效果图 images"
```

---

### Task 2: DB 层 —— `TemplateRecord.pose` 兼容 List / Map 两形态

**Files:**
- Modify: `lumira_app_flutter/lib/core/db/dao/templates_dao.dart`
- Modify: `lumira_app_flutter/lib/core/db/tables.dart`（如需新增图片列，本阶段不加）

**Interfaces:**
- Consumes: Task 1 的 `TemplateImage`。
- Produces: `TemplateRecord.pose` 类型由 `Map<String, dynamic>` 改为 `dynamic`（保存时 jsonEncode 数组）；新增可空字段 `List<TemplateImage>? images`（本阶段始终为 null，Phase 2 接 `images_json` 列）。

- [ ] **Step 1: 改字段类型与读写**

将 `TemplateRecord` 中：
```dart
final Map<String, dynamic> pose;   // → final dynamic pose;
```
`toRow()` 中 `pose` 列写入不变（`jsonEncode(pose)` 对 Map/List 均有效）。
`fromRow` 中 `pose` 解码改为动态解码：
```dart
pose: _decodeJsonAny(row[Tables.colPoseJson]),
```
新增 `_decodeJsonAny`（放在 `_decodeJsonMap` 附近）：
```dart
static dynamic _decodeJsonAny(Object? raw) {
  if (raw is String && raw.isNotEmpty) {
    return jsonDecode(raw);
  }
  return null;
}
```
新增字段：
```dart
final List<TemplateImage>? images;   // 本阶段 null；Phase 2 起接 images_json 列
// ctor / copyWith / toRow / fromRow 同步（toRow 先不写，Phase 2 补列）
```

- [ ] **Step 2: 更新 DB 层既有 `pose` 消费点（可编译）**

```bash
flutter analyze
```
修复 `templates_dao.dart` 内将 `pose` 当 Map 使用的报错。

- [ ] **Step 3: 运行相关测试**

```bash
flutter test test/features/templates
```
Expected: 通过（无回退）。

- [ ] **Step 4: Commit**

```bash
git add lumira_app_flutter/lib/core/db/dao/templates_dao.dart lumira_app_flutter/lib/core/db/tables.dart
git commit -m "feat(template): TemplateRecord.pose 兼容 Map/List，支持多姿势存取"
```

---

### Task 3: 映射层 —— poses / images 序列化与向后兼容

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/services/template_mapper.dart`
- Modify: `lumira_app_flutter/lib/features/templates/services/template_exporter.dart`

**Interfaces:**
- Consumes: Task 1 `Pose.name` / `TemplateImage`；Task 2 `TemplateRecord.pose`(dynamic)。
- Produces:
  - `_poseToJson(Pose p)`：多输出一个 `name`。
  - `_posesToJson(List<Pose>)` → `List<dynamic>`。
  - `_posesFromJson(dynamic raw)` → `List<Pose>`（兼容 Map / List / 空）。
  - `toPhotoTemplate` 用 `poses: _posesFromJson(r.pose)` + `images: _imagesFromRecord(r)`。

- [ ] **Step 1: `_poseToJson` 增加 name，并新增 list 包装**

```dart
static Map<String, dynamic> _poseToJson(Pose p) {
  return <String, dynamic>{
    'name': p.name,
    'silhouette': silhouetteToJson(p.silhouette),
    'position': {'x': p.position.x, 'y': p.position.y},
    'scale': p.scale,
    'rotation': p.rotation,
    'description': p.description,
  };
}

static List<dynamic> _posesToJson(List<Pose> poses) =>
    poses.map(_poseToJson).toList();
```

- [ ] **Step 2: `_poseFromJson` 读取 name，并新增 list 解析（兼容 Map/List）**

```dart
static Pose _poseFromJson(Map<String, dynamic> json) {
  final posJson = json['position'] as Map<String, dynamic>?;
  return Pose(
    name: (json['name'] as String?) ?? '',
    silhouette: silhouetteFromJson((json['silhouette'] as Map<String, dynamic>?) ?? {}),
    position: Position(
      x: (posJson?['x'] as num?)?.toDouble() ?? 0.5,
      y: (posJson?['y'] as num?)?.toDouble() ?? 0.5,
    ),
    scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
    rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
    description: (json['description'] as String?) ?? '',
  );
}

/// 兼容旧「单个 Map」与新版「数组」。
static List<Pose> _posesFromJson(dynamic raw) {
  if (raw is List) {
    return raw
        .whereType<Map<String, dynamic>>()
        .map(_poseFromJson)
        .toList();
  }
  if (raw is Map<String, dynamic>) {
    return [_poseFromJson(raw)];
  }
  return const [];
}
```

- [ ] **Step 3: `toPhotoTemplate` 改为 poses + images**

将 `toPhotoTemplate`（约 152-187 行）中：
```dart
      pose: _poseFromJson(r.pose),
```
改为：
```dart
      poses: _posesFromJson(r.pose),
```
并在 `meta` 构造中把 `cover: r.cover` 相关内容改为 images（构造 `TemplateMeta` 不再传 `cover`/`coverData`，改传 `images`）：

```dart
      meta: TemplateMeta(
        // ... 其它字段 ...
        images: _imagesFromRecord(r),
        // 删除 cover: / coverData: 两行
      ),
```
新增：
```dart
static List<TemplateImage> _imagesFromRecord(TemplateRecord r) {
  final list = <TemplateImage>[];
  if (r.cover.isNotEmpty) list.add(TemplateImage(url: normalizeAssetUrl(r.cover)));
  if (r.coverData != null && r.coverData!.isNotEmpty) {
    if (list.isEmpty) {
      list.add(TemplateImage(url: '', data: r.coverData));
    } else {
      list[0] = TemplateImage(url: list.first.url, data: r.coverData);
    }
  }
  // Phase 2：追加 r.images 中除首张外的效果图。
  return list;
}
```

- [ ] **Step 4: `toRecord` 写 pose 数组**

`toRecord`（约 54 行）：
```dart
      pose: _poseToJson(tpl.pose),
```
改为：
```dart
      pose: _posesToJson(tpl.poses),
```
`cover`/`coverData` 行保持（`tpl.meta.cover` / `tpl.meta.coverData` getter 取 images[0]）：确认这两行仍存在且读取 getter。

- [ ] **Step 5: 编辑器表单往返兼容**

`fromEditorForm`（pose 序列化，约 294-300 行）：将单姿势 Map 包成数组并加 name：

```dart
      pose: <dynamic>[
        <String, dynamic>{
          'name': '',
          'silhouette': editorSilhouetteToJson(form.pose.silhouette),
          'position': {'x': form.pose.position.x, 'y': form.pose.position.y},
          'scale': form.pose.scale,
          'rotation': form.pose.rotation,
          'description': form.pose.description,
        },
      ],
```

`toEditorForm`（约 325 行 `final pose = r.pose;`）：改为兼容数组：

```dart
    final poseRaw = r.pose;
    final pose = poseRaw is List
        ? (poseRaw.isNotEmpty
            ? (poseRaw.first as Map<String, dynamic>? ?? <String, dynamic>{})
            : <String, dynamic>{})
        : (poseRaw as Map<String, dynamic>? ?? <String, dynamic>{});
```
并将后续读取 `pose['silhouette']` 等保持不变。

- [ ] **Step 6: 导出兼容**

`template_exporter.dart`（约 49 行 `'pose': Map<String, dynamic>.from(record.pose)`）改为数组透传：

```dart
      'pose': record.pose,   // dynamic，Map 或 List 均可原样导出
```

- [ ] **Step 7: `flutter analyze` 全绿 + 运行测试**

```bash
flutter analyze
flutter test test/features/templates test/core/db
```
Expected: 0 error；既有 mapper/dao 测试通过（旧单 Map 数据可读为新 List 的 `[0]`）。

- [ ] **Step 8: Commit**

```bash
git add lumira_app_flutter/lib/features/templates/services/template_mapper.dart lumira_app_flutter/lib/features/templates/services/template_exporter.dart
git commit -m "feat(template): 映射层支持多姿势 poses 数组与多图 images，兼容旧单姿势"
```

---

### Task 4: Phase 1 完整性验证

**Files:**
- Modify: `test/features/templates/services/template_mapper_multi_pose_test.dart`

- [ ] **Step 1: 增加映射往返测试（多姿势 + 旧单姿势兼容）**

```dart
// 追加到 template_mapper_multi_pose_test.dart
import 'package:lumira_app/core/db/dao/templates_dao.dart';
import 'package:lumira_app/features/capture/domain/photo_template.dart';
import 'package:lumira_app/features/templates/services/template_mapper.dart';

void mapperTests() {
  test('toPhotoTemplate 读取新版 List pose_json → 多姿势', () {
    final rec = TemplateRecord(
      id: 't1', name: 'n', author: '', version: '1.0', category: 'portrait',
      classification: {'type': 'portrait'}, tags: const [], tagIds: const [],
      price: 0, cover: 'u0', description: '', referenceSource: '',
      composition: const {}, pose: [
        {'name': 'a'}, {'name': 'b', 'description': 'x'},
      ], camera: const {}, sceneGuide: const {}, postProcess: const {},
      createdAt: 1, updatedAt: 1, isBuiltin: true, isRecommended: false,
    );
    final t = TemplateMapper.toPhotoTemplate(rec);
    expect(t.poses.length, 2);
    expect(t.meta.cover, 'u0');
    expect(t.pose.name, 'a');
  });

  test('toPhotoTemplate 兼容旧单 Map pose_json → 单姿势数组', () {
    final rec = TemplateRecord(
      id: 't1', name: 'n', author: '', version: '1.0', category: 'portrait',
      classification: {'type': 'portrait'}, tags: const [], tagIds: const [],
      price: 0, cover: '', description: '', referenceSource: '',
      composition: const {}, pose: {'silhouette': {'type': 'builtin', 'data': 'none'}},
      camera: const {}, sceneGuide: const {}, postProcess: const {},
      createdAt: 1, updatedAt: 1, isBuiltin: true, isRecommended: false,
    );
    final t = TemplateMapper.toPhotoTemplate(rec);
    expect(t.poses.length, 1);
  });

  test('toRecord 将多姿势写为数组', () {
    final rec = TemplateMapper.toRecord(_sampleTemplate(), createdAt: 1);
    expect(rec.pose, isA<List>());
    expect((rec.pose as List).length, 2);
  });
}

PhotoTemplate _sampleTemplate() => const PhotoTemplate(
      meta: TemplateMeta(
        id: 't1', name: 'n', category: 'portrait',
        classification: TemplateClassification(type: 'portrait'),
        images: [TemplateImage(url: 'u0'),
            TemplateImage(url: 'u1')],
      ),
      composition: Composition(),
      poses: [Pose(name: 'a', description: 'first'), Pose(name: 'b')],
      camera: CameraParams(),
      sceneGuide: SceneGuide(),
      postProcess: PostProcess(color: PostProcessColor()),
    );
```
注：`mapperTests()` 需放进 `main()`（在 import 后、`void main()` 体内调用 `mapperTests()`）。

- [ ] **Step 2: 运行全部 Flutter 测试**

```bash
flutter analyze && flutter test
```
Expected: 0 error；全部通过。

- [ ] **Step 3: Commit**

```bash
git add test/features/templates/services/template_mapper_multi_pose_test.dart
git commit -m "test(template): 多姿势/多图映射往返与旧单姿势兼容用例"
```

---

## Roadmap：Phase 2–5（独立子计划，待 Phase 1 完成后各自展开）

### Phase 2：Flutter UI 与表单
文件：模板卡片 / `templates_detail_page.dart` / 拍摄页（`capture_state.dart`、拍摄页模板条）/ `templates_editor_page.dart` / `templates_editor_mock_data.dart`
- 卡片与推荐封面统一取 `meta.cover`（images[0]）——Phase 1 已保证。
- 详情页多效果图画廊（横滑） + 姿势剪影组预览。
- 拍摄页：`poses.length > 1` 显示「切换姿势」按钮（仅切 silhouette、不动共享配置），`==1` 不显示。
- 编辑器「封面与剪影」Tab 拆为「效果图列表（首张=封面，可重排）」与「姿势列表（可增删，含 name/描述/剪影）」；分类下拉从四级收敛为三级（大类→风格→子风格）。
- `EditorForm.pose`（单）→ `EditorForm.poses`（List）；保存/导出按数组。
- 新增 DB 列 `images_json`（存多效果图）+ `schema` 平移，落接 Phase 1 预留的 `TemplateRecord.images`。

### Phase 3：内置模板 seeder 归并
文件：`builtin_data_seeder.dart` / `template_registry*.dart` / `templates_browse_mock_data.dart` / `template_registry_test.dart`
- 现有 132 款按「子风格 × 姿势」归并为「模板套」，每套共享配置 + 多姿势 `poses`。
- 三级分类树由 seeder 重生成；`subtree`/`matchesSubtree` 过滤逻辑收敛为三级；断言数量按新口径更新。
- 生成的剪影/效果图路径与 Phase 2 图片列对齐。

### Phase 4：后端
文件：`lumira-server/packages/backend/` 模板 DTO / service / 表迁移
- `templates.pose_json` 写数组；新增 `images_json`；分类三级 `{type, majorStyle, style}`。
- 详情 DTO 返回 `poses[]`、`images[]`、`cover`=images[0]。

### Phase 5：后台 Admin
文件：`lumira-server/packages/admin/` 模板表单/接口
- 新建/编辑：效果图多图上传（第一张=封面）+ 姿势多组剪影；效果图与剪影独立。
- 三级级联分类选择；保存按 Phase 4 结构落库。

> Phase 2–5 各自需独立编写完整子计划（本文件只做范围与文件目标锚定，不代替其具体 step）。