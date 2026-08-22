# 模板卡片 + 详情页展示优化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 模板卡片展示短简介+使用次数；模板详情页展示 shortDesc/ambience/updatedAt 及「该模板拍摄的照片」区，点击进入新增的模板照片网格页。

**Architecture:** `shortDesc`/`ambience` 从后端 DTO 拉取后贯通 Flutter 本地 sqflite `custom_templates`（新增 v35 迁移两列）→ `TemplateRecord` → `PhotoTemplate(TemplateMeta)` → `AllTemplateItem`（卡片）/ `TemplateDetail`（详情页）。使用次数取 `GalleryDao.countByTemplate()`（本机相机该模板已拍照片数）；「该模板照片」取 `GalleryDao.getByTemplate(templateId)`。新增 `TemplatePhotosPage` 网格页（复用 `PhotoCell` + `GalleryDetailPage`）与 `/templates/photos` 路由。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（**不支持 Dart 3 records 语法** / 命名参数 + 具名构造）；flutter_riverpod 2.3.6；sqflite v11；go_router 6.5.7。

## Global Constraints

- Dart 2.19.6：**禁止 Dart 3 records/pattern statements**；用类 + 具名构造。
- Flutter UI 规范（强制）：所有颜色/阴影/圆角/透明度一律从 `appThemeProvider`（`AppThemeTokens`）派生，组件用 `ConsumerWidget` + `ref.watch(appThemeProvider)`；**禁止直接 `Colors.xxx`/`Color(0xFF...)`** 表达皮肤观感；唯一例外是叠在照片上的黑/白半透明遮罩。
- 同一次视觉呈现只用当前那套 UI 风格（neumorphic / flat / glass / female）自己的元素，不混搭。
- 现有共享组件：`NeuCard` / `LumiraIconButton` / `FadeUp` / `PhotoCell`。新风格自适应组件放 `lib/shared/widgets/`。
- 模板 id 及新字段为 null/空时**降级为空串/空对象**，不得抛异常；保证既有 29 内置模板与远程模板不回归。
- 后端/Admin 字段已落库（spec 2026-08-20），本轮只做 Flutter 展示，不动后端。
- 后端改动才需双 remote push；本计划仅 Flutter 端改动，正常 commit 即可。

---

### Task 1: DB v35 迁移（custom_templates 新增 short_desc / ambience_json 列）

**Files:**
- Modify: `lumira_app_flutter/lib/core/db/tables.dart`（新增列常量）
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart`（`_kDbVersion`→35、`_onCreate` 建列、`_onUpgrade` 的 `if (oldVersion < 35)`）

**Interfaces:**
- Consumes: 现有 `Tables.customTemplates`、`_addColumnIfNotExists(db, table, column, typeClause)`。
- Produces: 新增列常量 `Tables.colShortDesc`（值 `'short_desc'`）、`Tables.colAmbienceJson`（值 `'ambience_json'`）；`custom_templates` 表新增两列（默认值可让存量行自动填充）。

- [ ] **Step 1: 在 tables.dart 新增列常量**

在 `tables.dart` 中 `colSource`（第 53 行附近）之后追加：

```dart
  static const String colShortDesc = 'short_desc';
  static const String colAmbienceJson = 'ambience_json';
```

- [ ] **Step 2: 在 database_provider.dart `_onCreate` 的 custom_templates 建表语句中补列**

把 `custom_templates` 的 `CREATE TABLE`（database_provider.dart 约 133-160 行）中加入两列：

```dart
      ${Tables.colReferenceSource} TEXT NOT NULL DEFAULT '',
      ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
      ${Tables.colShortDesc} TEXT NOT NULL DEFAULT '',
      ${Tables.colAmbienceJson} TEXT NOT NULL DEFAULT '{}',
```

- [ ] **Step 3: 版本号提升到 35**

```dart
const int _kDbVersion = 35;
```

- [ ] **Step 4: `_onUpgrade` 追加迁移分支**

在 `_onUpgrade` 末尾（`if (oldVersion < 34)` 块之后）追加：

```dart
  if (oldVersion < 35) {
    try {
      // v35: 模板卡片/详情展示 shortDesc + ambience 元数据
      await _addColumnIfNotExists(
        db,
        Tables.customTemplates,
        Tables.colShortDesc,
        "TEXT NOT NULL DEFAULT ''",
      );
      await _addColumnIfNotExists(
        db,
        Tables.customTemplates,
        Tables.colAmbienceJson,
        "TEXT NOT NULL DEFAULT '{}'",
      );
      // 存量内置模板可后续增量标注，本次无需回填
    } catch (e) {
      debugPrint('v35 migration failed (silent fallback): $e');
    }
  }
```

- [ ] **Step 5: commit**

```bash
git add lumira_app_flutter/lib/core/db/tables.dart lumira_app_flutter/lib/core/db/database_provider.dart
git commit -m "feat(templates): v35 db migration add short_desc & ambience_json columns"
```

---

### Task 2: RemoteTemplateAmbienceDto + DTO 解析 shortDesc/ambience

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/data/remote_template_dto.dart`

**Interfaces:**
- Produces（后续任务消费）:
  - `class RemoteTemplateAmbienceDto { final List<String> seasons; final List<String> weathers; final List<String> timeTones; const RemoteTemplateAmbienceDto({this.seasons = const [], this.weathers = const [], this.timeTones = const []}); factory RemoteTemplateAmbienceDto.fromJson(Map<String, dynamic>? j); bool get isEmpty; }`（`isEmpty` = 三组全空）。
  - `RemoteTemplateMetaDto` 新增只读字段 `final String shortDesc;` 与 `final RemoteTemplateAmbienceDto ambience;`（构造参数默认空值，避免破坏现有 `RemoteTemplateMetaDto(...)` 调用点）。
  - `RemoteTemplateDetailDto` 新增同样两个字段，并在 `fromMetaAndSegments` / `fromJson` 中透传。

- [ ] **Step 1: 在 remote_template_dto.dart 追加 ambience DTO 类（文件末尾）**

```dart
/// 模板季节/天气/时段元数据（对应后端 TemplateAmbience，仅展示用）。
@immutable
class RemoteTemplateAmbienceDto {
  const RemoteTemplateAmbienceDto({
    this.seasons = const [],
    this.weathers = const [],
    this.timeTones = const [],
  });

  final List<String> seasons;
  final List<String> weathers;
  final List<String> timeTones;

  bool get isEmpty =>
      seasons.isEmpty && weathers.isEmpty && timeTones.isEmpty;

  factory RemoteTemplateAmbienceDto.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const RemoteTemplateAmbienceDto();
    return RemoteTemplateAmbienceDto(
      seasons: (j['seasons'] as List<dynamic>?)?.cast<String>() ?? const [],
      weathers: (j['weathers'] as List<dynamic>?)?.cast<String>() ?? const [],
      timeTones: (j['timeTones'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }
}
```

- [ ] **Step 2: 扩展 `RemoteTemplateMetaDto` 字段**

在 `RemoteTemplateMetaDto` 构造参数与字段中新增：

```dart
  final String shortDesc;
  final RemoteTemplateAmbienceDto ambience;
```

构造参数：`this.shortDesc = '',` `this.ambience = const RemoteTemplateAmbienceDto(),`（注意 now该 class 有两个 `required` 以外：`sortOrder`/`updatedAt` 已 required，新字段放可选）。在 `fromJson` 中解析：

```dart
      shortDesc: j['shortDesc'] as String? ?? '',
      ambience: RemoteTemplateAmbienceDto.fromJson(
        (j['ambience'] as Map<String, dynamic>?) ?? const {},
      ),
```

- [ ] **Step 3: 扩展 `RemoteTemplateDetailDto`**

- 字段与构造参数新增 `shortDesc`、`ambience`（默认值同上）。
- `fromMetaAndSegments`：把 `meta.shortDesc` / `meta.ambience` 透传进 `RemoteTemplateDetailDto(...)`。
- `fromJson`：`final meta = RemoteTemplateMetaDto.fromJson(j);`（meta 已解析 `j['shortDesc']` / `j['ambience']`，无需改动即可透传）。

- [ ] **Step 4: 新增单元测试**

新建 `lumira_app_flutter/test/features/templates/remote_template_dto_ambience_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/templates/data/remote_template_dto.dart';

void main() {
  group('RemoteTemplateAmbienceDto', () {
    test('fromJson 解析 season/weather/timeTone', () {
      final a = RemoteTemplateAmbienceDto.fromJson({
        'seasons': ['summer'],
        'weathers': ['sunny'],
        'timeTones': ['goldenHour'],
      });
      expect(a.seasons, ['summer']);
      expect(a.weathers, ['sunny']);
      expect(a.timeTones, ['goldenHour']);
      expect(a.isEmpty, isFalse);
    });

    test('缺失/空对象 isEmpty==true', () {
      expect(RemoteTemplateAmbienceDto.fromJson(null).isEmpty, isTrue);
      expect(const RemoteTemplateAmbienceDto({}).isEmpty, isTrue);
    });
  });

  group('RemoteTemplateMetaDto', () {
    test('解析 shortDesc 与 ambience', () {
      final m = RemoteTemplateMetaDto.fromJson({
        'id': 't1',
        'name': 'n',
        'category': 'portrait',
        'price': 0,
        'coverUrl': '',
        'description': '',
        'referenceSource': '',
        'tags': <String>[],
        'tagIds': <String>[],
        'classification': <String, dynamic>{},
        'sortOrder': 0,
        'updatedAt': 1,
        'shortDesc': '初夏甜点',
        'ambience': {'timeTones': ['warm']},
      });
      expect(m.shortDesc, '初夏甜点');
      expect(m.ambience.timeTones, ['warm']);
    });
  });
}
```

- [ ] **Step 5: 运行测试验证**

Run（在 `lumira_app_flutter/`）：`flutter test test/features/templates/remote_template_dto_ambience_test.dart`
Expected: 2 组 tests 通过（PASS）。

- [ ] **Step 6: commit**

```bash
git add lumira_app_flutter/lib/features/templates/data/remote_template_dto.dart lumira_app_flutter/test/features/templates/remote_template_dto_ambience_test.dart
git commit -m "feat(templates): parse shortDesc & ambience in remote template DTOs"
```

---

### Task 3: TemplateRecord 贯通 shortDesc / ambienceJson（含 Mapper DTO→Record）

**Files:**
- Modify: `lumira_app_flutter/lib/core/db/dao/templates_dao.dart`（`TemplateRecord`）
- Modify: `lumira_app_flutter/lib/features/templates/services/template_mapper.dart`（`metaToRecord` / `detailToRecord` / `toRecord`）

**Interfaces:**
- Consumes: Task 1 列常量 `colShortDesc`/`colAmbienceJson`；Task 2 `RemoteTemplateMetaDto.ambience`/`RemoteTemplateDetailDto.ambience`。
- Produces（Task 4/5 消费）:
  - `TemplateRecord.shortDesc: String`、`TemplateRecord.ambienceJson: String`（存原始 JSON；默认 `''` / `'{}'`）。
  - 新增 helper：`String TemplateMapper.ambienceToJson(RemoteTemplateAmbienceDto a)` 与 `RemoteTemplateAmbienceDto TemplateMapper.ambienceFromJson(String json)`（JSON 编解码，编解码失败/空返回空对象）。用于 record 与 Meta 之间转换。

- [ ] **Step 1: 扩展 `TemplateRecord`（templates_dao.dart）**

字段：`final String shortDesc; final String ambienceJson;`
构造：`this.shortDesc = '', this.ambienceJson = '{}',`
`toRow()` 追加：`Tables.colShortDesc: shortDesc, Tables.colAmbienceJson: ambienceJson,`
`fromRow()` 追加：`shortDesc: (row[Tables.colShortDesc] as String?) ?? '',` / `ambienceJson: (row[Tables.colAmbienceJson] as String?) ?? '{}',`
`copyWith()` 追加两个可选参数并透传。

（注意：构造参数为可选默认值，调用方如 `metaToRecord`/`seeder`/`editor` 传 `TemplateRecord(...)` 的地方无需全改。）

- [ ] **Step 2: 在 template_mapper.dart 新增 ambience JSON helper**

```dart
  static String ambienceToJson(RemoteTemplateAmbienceDto a) {
    return jsonEncode({
      'seasons': a.seasons,
      'weathers': a.weathers,
      'timeTones': a.timeTones,
    });
  }

  static RemoteTemplateAmbienceDto ambienceFromJson(String json) {
    if (json.isEmpty) return const RemoteTemplateAmbienceDto();
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      return RemoteTemplateAmbienceDto(
        seasons: (m['seasons'] as List<dynamic>?)?.cast<String>() ?? const [],
        weathers: (m['weathers'] as List<dynamic>?)?.cast<String>() ?? const [],
        timeTones: (m['timeTones'] as List<dynamic>?)?.cast<String>() ?? const [],
      );
    } catch (_) {
      return const RemoteTemplateAmbienceDto();
    }
  }
```

（在 template_mapper.dart 顶部确认已 import `dart:convert`，未 import 则加 `import 'dart:convert';`。）

- [ ] **Step 3: `metaToRecord` 写入新字段**

在 `metaToRecord` 的 `TemplateRecord(...)` 中追加：

```dart
      shortDesc: meta.shortDesc,
      ambienceJson: ambienceToJson(meta.ambience),
```

- [ ] **Step 4: `detailToRecord` 透传**

`detailToRecord` 构造 `RemoteTemplateMetaDto(...)` 时把 `detail.shortDesc` / `detail.ambience` 传进去（它们已存在于 Task 2 新增字段），其余逻辑不变即可让 `metaToRecord` 写入。

- [ ] **Step 5: `toRecord`（PhotoTemplate→Record）处理**

`toRecord` 从 `PhotoTemplate.meta` 读新字段（Task 4 才给 Meta 加字段）。为保持 Task 3 可独立编译，`toRecord` 先写 `shortDesc: tpl.meta.shortDesc,` 与 `ambienceJson: ambienceToJson(tpl.meta.ambience ?? const RemoteTemplateAmbienceDto()),`（届时 `tpl.meta.shortDesc` / `tpl.meta.ambience` 已是存在字段，见 Task 4）。若当前 Tree Task 3 先做而 Meta 未加字段会编译失败——因此 Task 3 与 Task 4 的 Meta 字段变更需**在同一 commit 内一起提交**（见 Task 4 引导）。

- [ ] **Step 6: 单元测试（templates_dao 已有测试则扩展；否则新增最小测试）**

在 `test/` 下新增或扩展，验证 `TemplateRecord.fromRow(toRow())` 往返保留 shortDesc/ambienceJson：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';

void main() {
  test('TemplateRecord roundtrip keeps shortDesc & ambienceJson', () {
    final r = TemplateRecord(
      id: 't', name: 'n', category: 'portrait', classification: {},
      tags: [], tagIds: [], price: 0, cover: '', description: '',
      referenceSource: '', composition: {}, pose: {}, camera: {},
      sceneGuide: {}, postProcess: {}, createdAt: 1, updatedAt: 1,
      isBuiltin: true, isRecommended: false,
      shortDesc: '初夏甜点', ambienceJson: '{"timeTones":["warm"]}',
    );
    final back = TemplateRecord.fromRow(r.toRow());
    expect(back.shortDesc, '初夏甜点');
    expect(back.ambienceJson, contains('warm'));
  });
}
```

- [ ] **Step 7: 运行测试**

Run（在 `lumira_app_flutter/`）：`flutter test test/core/db/dao/templates_dao_test.dart`
Expected：PASS（若该测试文件不存在，则放到 `test/core/db/dao/templates_record_test.dart` 并运行之）。

- [ ] **Step 8: commit（含 Task 4 的 Meta 字段，配合为同一提交）**

```bash
git add lumira_app_flutter/lib/core/db/dao/templates_dao.dart lumira_app_flutter/lib/features/templates/services/template_mapper.dart lumira_app_flutter/lib/features/capture/domain/photo_template.dart
git commit -m "feat(templates): thread shortDesc & ambience through TemplateRecord & TemplateMeta"
```

> **注意**：Task 3 与 Task 4 的 Meta 字段必须同时合入以保持通过编译；若严格按序，则将两个 Task 的代码合并为一个提交执行。

---

### Task 4: TemplateMeta 新增 shortDesc / ambience / updatedAt + fromPhotoTemplate/TemplateDetail + AmbienceLabel

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/domain/photo_template.dart`（`TemplateMeta`）
- Modify: `lumira_app_flutter/lib/features/templates/services/template_mapper.dart`（`toPhotoTemplate`）
- Modify: `lumira_app_flutter/lib/features/templates/data/templates_browse_mock_data.dart`（`TemplateDetail` + `fromPhotoTemplate` + `copyWithClassification`）
- Create: `lumira_app_flutter/lib/features/templates/widgets/ambience_label.dart`

**Interfaces:**
- Produces（Task 5/6 消费）:
  - `TemplateMeta.shortDesc: String`、`TemplateMeta.ambience: RemoteTemplateAmbienceDto?`、`TemplateMeta.updatedAt: int`（默认 0）。
  - `TemplateDetail.shortDesc: String`、`TemplateDetail.ambience: RemoteTemplateAmbienceDto?`、`TemplateDetail.updatedAt: int`。
  - `class AmbienceLabel { static final List<String> Function(List<String>) seasonLabels / weatherLabels / timeToneLabels; static List<String> labelsFor(RemoteTemplateAmbienceDto a); }` — 返回中文标签列表（无标签则空）。

- [ ] **Step 1: 扩展 `TemplateMeta`（photo_template.dart）**

字段：`final String shortDesc; final RemoteTemplateAmbienceDto? ambience; final int updatedAt;`
构造：`this.shortDesc = '', this.ambience, this.updatedAt = 0,`
`copyWith`：新增参数并透传（`ambience` 需用类似 `_unset` 的哨兵以支持置 null，参考现有 `coverData` 处理）。
`==` / `hashCode`：把 `shortDesc`、`ambience`、`updatedAt` 纳入。

（photo_template.dart 顶部需 `import` RemoteTemplateAmbienceDto——它位于 `remote_template_dto.dart`。若担心跨 feature 依赖，可在 photo_template.dart 内声明最小 `TemplateAmbience` 值对象并在 Mapper 转换；推荐直接复用 DTO。）

- [ ] **Step 2: `TemplateMapper.toPhotoTemplate`（Record→Meta）写入新字段**

在被读取的 `meta: TemplateMeta(...)` 处追加：

```dart
        shortDesc: r.shortDesc,
        ambience: ambienceFromJson(r.ambienceJson),
        updatedAt: r.updatedAt,
```

- [ ] **Step 3: 扩展 `TemplateDetail`（templates_browse_mock_data.dart）**

在 `TemplateDetail` 构造与字段新增：`final String shortDesc; final RemoteTemplateAmbienceDto? ambience; final int updatedAt;`（默认 `shortDesc=''`, `ambience=null`, `updatedAt=0`；在 `copyWithClassification` 中透传保留）。
确保持 `TemplatesBrowseMockData.details`（14 个 mock）无需改动即可编译（新字段为可选默认值）。

- [ ] **Step 4: `fromPhotoTemplate`（Meta→TemplateDetail）写入新字段**

在返回的 `TemplateDetail(...)` 中追加：

```dart
      shortDesc: tpl.meta.shortDesc,
      ambience: tpl.meta.ambience,
      updatedAt: tpl.meta.updatedAt,
```

- [ ] **Step 5: 新建 `ambience_label.dart`**

```dart
import '../data/remote_template_dto.dart';

/// 将 ambience 元数据映射为中文标签（与分类 categoryLabel 风格一致）。
class AmbienceLabel {
  static const Map<String, String> _seasons = {
    'spring': '春季', 'summer': '夏季', 'autumn': '秋季', 'winter': '冬季',
  };
  static const Map<String, String> _weathers = {
    'sunny': '晴天', 'cloudy': '多云', 'overcast': '阴天',
    'rain': '雨天', 'snow': '雪天', 'fog': '雾天',
  };
  static const Map<String, String> _timeTones = {
    'goldenHour': '黄金时刻', 'day': '白天', 'night': '夜晚',
    'warm': '暖调', 'cool': '冷调',
  };

  static List<String> seasonLabels(List<String> keys) =>
      keys.map((k) => _seasons[k] ?? '').where((s) => s.isNotEmpty).toList();
  static List<String> weatherLabels(List<String> keys) =>
      keys.map((k) => _weathers[k] ?? '').where((s) => s.isNotEmpty).toList();
  static List<String> timeToneLabels(List<String> keys) =>
      keys.map((k) => _timeTones[k] ?? '').where((s) => s.isNotEmpty).toList();

  /// 全部标签（季节→天气→时段），无则空列表。
  static List<String> labelsFor(RemoteTemplateAmbienceDto? a) {
    if (a == null) return const [];
    return [
      ...seasonLabels(a.seasons),
      ...weatherLabels(a.weathers),
      ...timeToneLabels(a.timeTones),
    ];
  }
}
```

- [ ] **Step 6: 单元测试（AmbienceLabel）**

新建 `lumira_app_flutter/test/features/templates/ambience_label_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/templates/data/remote_template_dto.dart';
import 'package:lumira_app_flutter/features/templates/widgets/ambience_label.dart';

void main() {
  test('labelsFor returns mapped chinese labels in season>weather>tone order', () {
    final a = RemoteTemplateAmbienceDto(
      seasons: ['summer'], weathers: ['sunny'], timeTones: ['goldenHour'],
    );
    expect(AmbienceLabel.labelsFor(a), ['夏季', '晴天', '黄金时刻']);
  });

  test('labelsFor null/empty returns empty', () {
    expect(AmbienceLabel.labelsFor(null), isEmpty);
    expect(AmbienceLabel.labelsFor(const RemoteTemplateAmbienceDto()), isEmpty);
  });

  test('unknown keys are dropped', () {
    expect(AmbienceLabel.labelsFor(RemoteTemplateAmbienceDto(seasons: ['xxx'])), isEmpty);
  });
}
```

- [ ] **Step 7: 运行测试**

Run（在 `lumira_app_flutter/`）：`flutter test test/features/templates/ambience_label_test.dart test/features/templates/remote_template_dto_ambience_test.dart`
Expected：全部 PASS。

- [ ] **Step 8: commit**

```bash
git add lumira_app_flutter/lib/features/capture/domain/photo_template.dart lumira_app_flutter/lib/features/templates/services/template_mapper.dart lumira_app_flutter/lib/features/templates/data/templates_browse_mock_data.dart lumira_app_flutter/lib/features/templates/widgets/ambience_label.dart lumira_app_flutter/test/features/templates/ambience_label_test.dart
git commit -m "feat(templates): add shortDesc/ambience/updatedAt to TemplateMeta & TemplateDetail + AmbienceLabel"
```

---

### Task 5: 模板卡片 UI（shortDesc + ambience + 使用次数）

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/data/templates_browse_mock_data.dart`（`AllTemplateItem` 加 shortDesc/ambience）
- Modify: `lumira_app_flutter/lib/features/templates/pages/templates_all_page.dart`（`_recordToItem` + `_TplCard` + `_AllPageData` 加入次数 map + 需要时改 `childAspectRatio`）
- Modify（卡片短简介兜底用 `description`）：`_TplCard` 直接读 `AllTemplateItem`，短简介空时展示截断的 `description`（`TemplateItem` 版/首页 `_recordToItem`(`templates_page.dart:647`) 可同步补 `shortDesc` 供模板入口页卡片）。

**Interfaces:**
- Consumes: `GalleryDao.countByTemplate()`（返回值 `Map<String,int>`）；Task 4 `AllTemplateItem.shortDesc`/`ambience`。
- Produces: 无新接口（UI 变更）。

- [ ] **Step 1: `AllTemplateItem` 新增字段**

在 `AllTemplateItem` 构造与字段新增（默认值避免破坏 const 调用点）：

```dart
  final String shortDesc;
  final RemoteTemplateAmbienceDto? ambience;
```

构造：`this.shortDesc = '', this.ambience,`

- [ ] **Step 2: `templates_all_page.dart` 的两个 `_recordToItem` 透传**

`AllTemplateItem` 版 `_recordToItem`（约 1640 行）追加：

```dart
    shortDesc: r.shortDesc,
    ambience: TemplateMapper.ambienceFromJson(r.ambienceJson),
```

（同文件 `_loadData` 在 `_AllPageData` 组装时需拿到各模板使用次数。step 3 处理。）

- [ ] **Step 3: `_AllPageData` 加入使用次数 map，`_loadData` 一次性查询**

在 `_AllPageData` 类增加字段 `final Map<String, int> usageCounts;`，并在 `_loadData` 结尾（构建 `_AllPageData` 前）注入（`GalleryDao` 来自 `galleryDaoProvider`，`_loadData` 已是 `Future`，改为在调用处 hold 一个 `final galleryDao = await ref.read(galleryDaoProvider.future);`，再 `final counts = await galleryDao.countByTemplate();`）：

```dart
    final galleryDao = await ref.read(galleryDaoProvider.future);
    final usageCounts = await galleryDao.countByTemplate();
    return _AllPageData(
      // ...原有字段...
      usageCounts: usageCounts,
    );
```

并把 `_TemplateGrid` / `_TplCard` 传入 `usageCounts`（`_TemplateGrid` 构造函数加 `required this.usageCounts`，`_TplCard` 加 `final Map<String,int> usageCounts`）。

- [ ] **Step 4: `_TplCard` 增加短简介 + ambience + 使用次数展示**

在 `_TplCard` 现有的 `name` 与底部分类 `Wrap` 之间插入：

```dart
                  if (shortDesc.isNotEmpty || shortDesc2.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        shortDesc2, // 见下方本地变量计算
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
```

其中 `template` 形参为 `AllTemplateItem`（`_recordToItem` 已带 `description`？——`AllTemplateItem` 无 description，故在 `_recordToItem` 里用 `description: r.description` 一并放入；或在 `_TplCard` 内直接使用 `template.shortDesc`。为最小改动：把 `shortDesc2` 定义为 `template.shortDesc.isNotEmpty ? template.shortDesc : fallbackTruncated`，fallback 用短描述兜底文案常量，如 `'暂无简介'`；**推荐**把 `r.description` 传入 `AllTemplateItem` 新字段以截断兜底 —— 见下方更优做法）。

> **更优做法（推荐，避免新常量）**：给 `AllTemplateItem` 增加 `final String description;`（默认 `''`），`_recordToItem` 透传 `r.description`；`_TplCard` 中 `final text = (template.shortDesc.isNotEmpty ? template.shortDesc : _truncate(template.description));` 其中 `_truncate(s)` 截断到约 24 字符加 `…`。底部分类 `Wrap` 末尾追加使用次数与 ambience：

```dart
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Wrap(spacing: 6, runSpacing: 4, children: [
                          Text(TemplatesBrowseMockData.categoryLabel(template.category),
                              style: TextStyle(fontSize: 11, color: tokens.brand)),
                          if (template.ambience != null && AmbienceLabel.timeToneLabels(template.ambience!.timeTones).isNotEmpty)
                            Text(AmbienceLabel.timeToneLabels(template.ambience!.timeTones).first,
                                style: TextStyle(fontSize: 11, color: tokens.textTertiary)),
                        ]),
                      ),
                      if ((usageCounts[template.id] ?? 0) > 0)
                        Row(children: [
                          Icon(Icons.camera_alt_outlined, size: 12, color: tokens.textTertiary),
                          const SizedBox(width: 3),
                          Text('已拍 ${usageCounts[template.id]} 张',
                              style: TextStyle(fontSize: 11, color: tokens.textTertiary)),
                        ]),
                    ],
                  ),
```

- [ ] **Step 5: 校验卡片高度，必要时调 `childAspectRatio`**

`_TemplateGrid` 当前 `childAspectRatio: 0.56`。新增 2 行文本后在小屏可能溢出，改为 `0.50` 并同时在 spec §4 记录依实测调整（若实机/截图无溢出可保留 0.56）。本项目遵循「跟随当前风格撞过不溢出」。

- [ ] **Step 6: 运行 analyze + 相关测试**

Run（在 `lumira_app_flutter/`）：`flutter analyze lib/features/templates/pages/templates_all_page.dart lib/features/templates/data/templates_browse_mock_data.dart`
Expected：No issues found（若模板入口页首页 `templates_page.dart _recordToItem` 构造 `TemplateItem` 也读取新字段，需确认 `TemplateItem` 无新必填字段，避免其他页面编译报错）。

- [ ] **Step 7: commit**

```bash
git add lumira_app_flutter/lib/features/templates/data/templates_browse_mock_data.dart lumira_app_flutter/lib/features/templates/pages/templates_all_page.dart
git commit -m "feat(templates): card shows shortDesc, ambience & local usage count"
```

---

### Task 6: 模板详情页 UI（新增信息卡 + 模板照片区）

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/pages/templates_detail_page.dart`

**Interfaces:**
- Consumes: Task 4 `TemplateDetail.shortDesc`/`ambience`/`updatedAt`；`AmbienceLabel`；`GalleryDao.getByTemplate(templateId)`；`PhotoCell`；`GalleryDetailPage(photoId)`；`RouteNames.templatesPhotos`.
- Produces: 无新接口。

- [ ] **Step 1: 详情数据已含新字段**

`templateDetailProvider`（Task 4 后）返回的 `TemplateDetail` 已带 `shortDesc`/`ambience`/`updatedAt`。本 Task 只做 UI。

- [ ] **Step 2: 标题区下新增「模板信息卡」**

在 `_TitleAndTags` 之后、`UserTagsSection` 之前插入一个 `_MetaInfoCard`（私有小部件），展示：
- `shortDesc`（若非空）：`tokens.textSecondary`，fontSize 13。
- `ambience`（若非空）：`AmbienceLabel.labelsFor(ambience)`，render 成一行小 chips（`Container` + `tokens.brandSubtle` 底 + `tokens.brandText` 文字，`BorderRadius.circular(9999)`）。
- `updatedAt > 0`：`更新于 ${yyyy-MM-dd}`，`tokens.textTertiary`，fontSize 11（用 Dart `DateTime.fromMillisecondsSinceEpoch(updatedAt)` 格式化）。
包裹在 `NeuCard`（或按当前风格用画布卡）中，`margin` 水平 20、上下 8。

- [ ] **Step 3: 页面底部新增「用此模板拍摄的照片」区**

在 `_ReferenceSource` 之后、`_UnlockStatus` 附近合适位置（`cta-spacer` 之前）插入 `_TemplatePhotosSection`（私有 `ConsumerWidget`）：
- 内部 `final galleryDao = await ref.read(galleryDaoProvider.future);` + `final photos = await galleryDao.getByTemplate(template.id, limit: 4);`
- 若 `photos.isEmpty`：`SizedBox.shrink()`（隐藏）。
- 否则显示标题行（"用此模板拍摄的照片" + 右侧"查看全部 →"按钮，`onTap` → `GoRouter.push(RouteNames.build(RouteNames.templatesPhotos, {RouteNames.paramTemplateId: template.id!}))`）+ 横向 `ListView` 4 张 `GalleryPhoto`（`GalleryPhoto.fromRecord(photo)`）；
- 每张 `PhotoCell`，`onTap` → `GoRouter.push(RouteNames.build(RouteNames.galleryDetail, {RouteNames.paramPhotoId: photoId}))`。

> 在 `Stack` 的 `SingleChildScrollView` 顶部需 watch `templateDetailProvider`（现有代码已在 `ref.watch/templateDetailProvider(widget.templateId!))` 处拿到 `TemplateDetail`），把 `TemplateDetail` 透传给 `_buildDetailContent`，再传给新 section 即可。当前 `_buildDetailContent(TemplateDetail template, ...)` 已接收 `template`，在 body 内加对应 section 即可。

- [ ] **Step 4: 运行 analyze**

Run（在 `lumira_app_flutter/`）：`flutter analyze lib/features/templates/pages/templates_detail_page.dart`
Expected：No issues。

- [ ] **Step 5: commit**

```bash
git add lumira_app_flutter/lib/features/templates/pages/templates_detail_page.dart
git commit -m "feat(templates): detail page shows shortDesc/ambience/updatedAt + template photos section"
```

---

### Task 7: 新增「模板照片网格页」+ 路由

**Files:**
- Create: `lumira_app_flutter/lib/features/gallery/pages/template_photos_page.dart`
- Modify: `lumira_app_flutter/lib/core/router/route_names.dart`（新增 `templatesPhotos` 路由 + `paramTemplateId` 已存在）
- Modify: `lumira_app_flutter/lib/app/router.dart`（新增 `GoRoute`）

**Interfaces:**
- Consumes: `GalleryDao.getByTemplate(templateId)`；`GalleryPhoto`/`PhotoCell`；`GalleryDetailPage(photoId)`；`RouteNames.galleryDetail` + `RouteNames.paramPhotoId`。
- Produces: `TemplatePhotosPage({required String templateId})`；`RouteNames.templatesPhotos = '/templates/photos'`。

- [ ] **Step 1: RouteNames 新增路径**

在 `route_names.dart` 中 `templatesCategory`/`templatesAll` 附近追加：

```dart
  static const String templatesPhotos = '/templates/photos';
```

（`paramTemplateId` 已声明，见 86 行。）

- [ ] **Step 2: 新建 `template_photos_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../features/gallery/data/gallery_models.dart';
import '../../../features/gallery/widgets/photo_cell.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../../shared/widgets/lumira/lumira.dart';

/// 某模板在本机拍摄的全部照片网格页。
class TemplatePhotosPage extends ConsumerWidget {
  const TemplatePhotosPage({super.key, required this.templateId});
  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final daoAsync = ref.watch(galleryDaoProvider);
    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        backgroundColor: tokens.canvas,
        title: Text('模板照片', style: TextStyle(color: tokens.textPrimary)),
        leading: BackButton(color: tokens.textPrimary),
      ),
      body: daoAsync.when(
        loading: () => Center(child: LumiraProgress.circular()),
        error: (e, _) => Center(child: Text('加载失败', style: TextStyle(color: tokens.textSecondary))),
        data: (dao) => FutureBuilder<List<GalleryItemRecord>>(
          future: dao.getByTemplate(templateId),
          builder: (context, snap) {
            final photos = snap.data ?? const <GalleryItemRecord>[];
            if (photos.isEmpty) {
              return Center(child: Text('还没有用此模板拍摄的照片', style: TextStyle(color: tokens.textSecondary)));
            }
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, mainAxisSpacing: 4, crossAxisSpacing: 4,
              ),
              itemCount: photos.length,
              itemBuilder: (context, i) {
                final p = photos[i];
                final g = GalleryPhoto.fromRecord(p);
                return PhotoCell(
                  photo: g,
                  onTap: () => GoRouter.of(context).push(
                    RouteNames.build(RouteNames.galleryDetail, {RouteNames.paramPhotoId: p.id}),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 注册路由**

在 `router.dart` 的 templates 相关 `GoRoute` 后新增：

```dart
      GoRoute(
        path: RouteNames.templatesPhotos,
        name: 'templatesPhotos',
        builder: (context, state) => TemplatePhotosPage(
          templateId: state.queryParams[RouteNames.paramTemplateId] ?? '',
        ),
      ),
```

并在文件顶部 import `template_photos_page.dart`。

- [ ] **Step 4: 运行 analyze**

Run（在 `lumira_app_flutter/`）：`flutter analyze lib/features/gallery/pages/template_photos_page.dart lib/app/router.dart`
Expected：No issues。

- [ ] **Step 5: commit**

```bash
git add lumira_app_flutter/lib/features/gallery/pages/template_photos_page.dart lumira_app_flutter/lib/core/router/route_names.dart lumira_app_flutter/lib/app/router.dart
git commit -m "feat(templates): add template photos grid page & /templates/photos route"
```

---

## Self-Review

- **Spec 覆盖**：卡片（shortDesc/useCount/ambience）→ Task 5；详情（shortDesc/ambience/updatedAt）→ Task 6；模板照片区 + 查看全部 + 网格页 → Task 6+7；DTO 解析 → Task 2；DB 贯通 → Task 1+3+4。
- **占位符扫描**：无 TBD/TODO；步骤含具体代码与命令。
- **类型一致性**：
  - `RemoteTemplateAmbienceDto`（Task 2）为唯一 ambience 值类型，Task 3/4/5/6 复用同名字段。
  - `TemplateRecord.shortDesc`/`ambienceJson`（Task 3）→ `TemplateMapper.ambienceFromJson` → `TemplateMeta.ambience`（DTO，Task 4）→ `TemplateDetail.ambience` → `AmbienceLabel.labelsFor(RemoteTemplateAmbienceDto?)`。
  - `AllTemplateItem.shortDesc`/`ambience` 由 `_recordToItem` 从 `TemplateRecord` 填。
  - 路由 `RouteNames.templatesPhotos` + `paramTemplateId`；详情/网格页均用 `GalleryPhoto.fromRecord` + `PhotoCell`。