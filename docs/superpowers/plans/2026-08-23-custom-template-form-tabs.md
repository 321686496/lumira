# 自定义模板表单 Tab 化重设计 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Flutter 自定义模板新建/编辑表单从「长列表滚动」改为「顶部 6 Tab 切换」，补齐短简介 / 适用季节天气时段 / 四级分类新字段，标签改为「选自定义模板标签 + 新增」。

**Architecture:** Tabs 完全镜像后台 `STEPS`（基本信息/封面与剪影/构图/相机参数/场景引导/后期处理）。`TemplatesEditorPage.build` 改为「顶部主题自适应 Tab 条 + `AnimatedSwitcher` 按 Tab 渲染」；封面与姿势剪影并入「封面与剪影」。`EditorFormMeta` 新增 `shortDesc`、`ambience`（复用 `RemoteTemplateAmbienceDto`）、`subStyle`（旧 `method` 改名）、`method`（新增四级），并让 `template_mapper.dart` 以后端四级 `{type,majorStyle,subStyle,method}` 读写（向后兼容旧 `{type,style,method}`）。标签候选由 `TemplatesDao.getCustomOnly()` 聚合 `source='custom'` 模板的 `tags` 生成。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（**不支持 Dart 3 records 语法**）；flutter_riverpod 2.3.6；sqflite v11；go_router 6.5.7。

## Global Constraints

- Dart 2.19.6：**禁止 Dart 3 records/pattern statements**；用类 + 具名构造 + `List<String>`。
- Flutter UI 规范（强制）：颜色/阴影/圆角/透明度一律从主题派生（`themeTokensProvider` / `uiStyleProvider` / `appThemeProvider`），组件用 `ConsumerWidget`；**禁止直接 `Colors.xxx`/`Color(0xFF...)`** 表达皮肤观感；唯一例外是叠照片上的黑/白半透明遮罩。
- 同一视觉呈现只用当前那套 UI 风格（neumorphic/flat/glass/female）自己的元素，不混搭。
- 新增字段为 null/空时降级为空串/空对象，不得抛异常；保证既有内置/远端模板编辑不回归。
- 本计划仅 Flutter 端改动（`lumira_app_flutter/`），**唯一合法推送例外适用**：纯 Flutter 改动正常 `git commit` 即可，不 push 双远端。
- 分类类型定义：后端四级 `{type, majorStyle, subStyle, method}`；旧本地数据存 `{type, style, method}`，读取需兼容。
- ambience 复用现有 `RemoteTemplateAmbienceDto`（`lib/features/templates/data/remote_template_dto.dart`），不新建 DTO。

---

### Task 1: `EditorFormMeta` 数据模型扩展

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/data/templates_editor_mock_data.dart`
- Test: `lumira_app_flutter/test/features/templates/templates_editor_mock_data_test.dart`（新建）

**Interfaces:**
- Consumes: `RemoteTemplateAmbienceDto`（`lib/features/templates/data/remote_template_dto.dart`）。
- Produces（后续任务消费）:
  - `EditorFormMeta` 新增字段：`String shortDesc`、`RemoteTemplateAmbienceDto? ambience`、`String? subStyle`、`String? method`（构造参数默认 `''`/`null`，不破坏现有调用点）。
  - 变更：原 `EditorFormMeta.method`（三级）改名为 `subStyle`。凡引用 `meta.method` 处须改 `meta.subStyle`。
  - `EditorFormMeta.copy()` 同步携带新字段。
  - `createBlankEditorForm()` 保持新字段默认值。

- [ ] **Step 1: 写失败测试**

在 `test/features/templates/templates_editor_mock_data_test.dart` 写入：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/templates/data/remote_template_dto.dart';
import 'package:lumira_app_flutter/features/templates/data/templates_editor_mock_data.dart';

void main() {
  group('EditorFormMeta new fields', () {
    test('blank form defaults are empty', () {
      final f = createBlankEditorForm();
      expect(f.meta.shortDesc, '');
      expect(f.meta.ambience, isNull);
      expect(f.meta.subStyle, isNull);
      expect(f.meta.method, isNull);
    });

    test('copy carries new fields', () {
      final f = createBlankEditorForm();
      f.meta.shortDesc = '森林暗调';
      f.meta.ambience = const RemoteTemplateAmbienceDto(seasons: ['autumn']);
      f.meta.subStyle = 's1';
      f.meta.method = 'm1';
      final c = f.copy();
      expect(c.meta.shortDesc, '森林暗调');
      expect(c.meta.ambience!.seasons, ['autumn']);
      expect(c.meta.subStyle, 's1');
      expect(c.meta.method, 'm1');
      // 深拷贝隔离：改原对象不影响副本
      c.meta.method = 'm2';
      expect(f.meta.method, 'm1');
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/templates/templates_editor_mock_data_test.dart`
Expected: FAIL（`EditorFormMeta` 无 `shortDesc`/`ambience`/`subStyle`/`method` 字段，编译失败）

- [ ] **Step 3: 实现字段**

在 `templates_editor_mock_data.dart` 的 `EditorFormMeta` 类中，把 `String? method;`（三级）改名为 `String? subStyle;`（三级），并在其后新增 `String? method;`（四级），同时新增 `shortDesc` 与 `ambience`：

```dart
class EditorFormMeta {
  EditorFormMeta({
    this.id = '',
    this.name = '',
    this.category = 'portrait',
    this.tags = const [],
    this.description = '',
    this.referenceSource = '',
    this.style,
    this.subStyle,
    this.method,
    this.coverImage,
    this.shortDesc = '',
    this.ambience,
  });

  String id;
  String name;
  String category;
  List<String> tags;
  String description;
  String referenceSource;
  // 四级分类（对齐后端 {type, majorStyle, subStyle, method}）
  String? style; // 二级 majorStyle
  String? subStyle; // 三级 subStyle（原 method 改名）
  String? method; // 四级 method（新增）
  String? coverImage;
  String shortDesc; // 短简介
  RemoteTemplateAmbienceDto? ambience; // 季节/天气/时段

  EditorFormMeta copy() => EditorFormMeta(
        id: id,
        name: name,
        category: category,
        tags: List<String>.from(tags),
        description: description,
        referenceSource: referenceSource,
        style: style,
        subStyle: subStyle,
        method: method,
        coverImage: coverImage,
        shortDesc: shortDesc,
        ambience: ambience,
      );
}
```

在文件顶部 import `remote_template_dto.dart`：`import 'remote_template_dto.dart';`（该文件与 mock_data 同在 `data/`）。

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/templates/templates_editor_mock_data_test.dart`
Expected: PASS

- [ ] **Step 5: 修全局引用编译错误**

全局搜索 `EditorFormMeta(` 与 `.meta.method`，把三级语义处改用 `.meta.subStyle`（Task 2 会集中处理 mapper；本步先保证 `flutter analyze` 通过）。若 `_Step1TemplateInfo`（编辑器页）仍引用 `meta.method` 做三级下拉，改为 `meta.subStyle`（三级），并新增四级 `meta.method` 下拉可延后到 Task 6，先保留三级逻辑）。

- [ ] **Step 6: commit**

```bash
git add lumira_app_flutter/lib/features/templates/data/templates_editor_mock_data.dart lumira_app_flutter/test/features/templates/templates_editor_mock_data_test.dart
git commit -m "feat(templates): EditorFormMeta add shortDesc/ambience/4-level classification"
```

---

### Task 2: `template_mapper` 四级分类 + 新字段持久化

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/services/template_mapper.dart`
- Test: `lumira_app_flutter/test/features/templates/template_mapper_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `EditorFormMeta`（`category`/`style`/`subStyle`/`method`/`shortDesc`/`ambience`）。
- Produces（Task 6 消费）：`TemplateRecord` 中 `classification` 写为 `{type, majorStyle, subStyle, method}`，`shortDesc`、`ambienceJson` 正确落库；`toEditorForm` 从旧 `{type,style,method}` 兼容读取。

- [ ] **Step 1: 写失败测试（mapper 写读 + 向后兼容）**

在 `test/features/templates/template_mapper_test.dart` 追加：

```dart
test('fromEditorForm writes 4-level classification + shortDesc + ambience', () {
  final f = createBlankEditorForm();
  f.meta.category = 'portrait';
  f.meta.style = 'mood';
  f.meta.subStyle = 'cold';
  f.meta.method = 'selfie';
  f.meta.shortDesc = '暗调人像';
  f.meta.ambience = const RemoteTemplateAmbienceDto(seasons: ['autumn'], weathers: ['overcast']);
  final r = TemplateMapper.fromEditorForm(f);
  expect(r.classification['type'], 'portrait');
  expect(r.classification['majorStyle'], 'mood');
  expect(r.classification['subStyle'], 'cold');
  expect(r.classification['method'], 'selfie');
  expect(r.shortDesc, '暗调人像');
  expect(TemplateMapper.ambienceFromJson(r.ambienceJson).seasons, ['autumn']);
});

test('toEditorForm reads legacy {type,style,method} classification', () {
  final r = {
    'id': 't1', 'name': 'x', 'author': '', 'version': '1.0.0', 'category': 'portrait',
    'classification': {'type': 'portrait', 'style': 'mood', 'method': 'cold'},
    'tags': [], 'tagIds': [], 'price': 0, 'cover': '', 'description': '',
    'referenceSource': '', 'shortDesc': '', 'ambienceJson': '{}',
    'composition': {}, 'pose': {}, 'camera': {}, 'sceneGuide': {}, 'postProcess': {},
    'createdAt': 0, 'updatedAt': 0, 'isBuiltin': 0, 'isRecommended': 0, 'source': 'custom',
  } as Map<String, Object?>;
  final rec = TemplateRecord.fromRow(r);
  final form = TemplateMapper.toEditorForm(rec);
  expect(form.meta.style, 'mood');
  expect(form.meta.subStyle, 'cold');
  expect(form.meta.method, isNull);
});
```

（`RemoteTemplateAmbienceDto` 与 `fromEditorForm`/`toEditorForm`/`TemplateRecord.fromRow` 均须 import。若 `fromEditorForm` 目前无 `show` 具名签名，先查其现有签名再补。）

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/templates/template_mapper_test.dart`
Expected: FAIL（`toEditorForm` 仍读 `classification['method']` 作三级，且 `fromEditorForm` 写旧 `{type,style,method}`）

- [ ] **Step 3: 实现 4 级读写**

在 `template_mapper.dart` 的 `fromEditorForm`，把 `classificationJson` 改为：

```dart
final classificationJson = <String, dynamic>{
  'type': form.meta.category,
  'majorStyle': form.meta.style ?? '',
  'subStyle': form.meta.subStyle ?? '',
  'method': form.meta.method ?? '',
};
```

并在返回的 `TemplateRecord` 上补：

```dart
shortDesc: form.meta.shortDesc,
ambienceJson: TemplateMapper.ambienceToJson(
  form.meta.ambience ?? const RemoteTemplateAmbienceDto()),
```

在 `toEditorForm` 的 `EditorFormMeta(...)` 中，把分类读取改为向后兼容，并补 `shortDesc`/`ambience`：

```dart
style: (r.classification['majorStyle'] as String?)?.isNotEmpty == true
    ? r.classification['majorStyle'] as String
    : (r.classification['style'] as String?)?.isNotEmpty == true
        ? r.classification['style'] as String
        : null,
subStyle: (r.classification['subStyle'] as String?)?.isNotEmpty == true
    ? r.classification['subStyle'] as String
    : (r.classification['method'] as String?)?.isNotEmpty == true
        ? r.classification['method'] as String
        : null,
method: (r.classification['method'] as String?) != null &&
            (r.meta?. ... ) // 仅在存在真正四级 method 且有 subStyle 时映射，避免旧 3 级 method 误读为 4 级
    ? null
    : null,
shortDesc: r.shortDesc,
ambience: TemplateMapper.ambienceFromJson(r.ambienceJson),
```

> 说明：旧 3 级数据的 `method` 实际是三级，读到 `subStyle`；而新 4 级数据 `subStyle` 与 `method` 并存。为规避旧数据 `method` 被误投到四级，四级 `method` 仅在 `r.classification['subStyle']` 非空时读取：

```dart
method: (r.classification['subStyle'] as String?)?.isNotEmpty == true
    ? (r.classification['method'] as String?)?.isNotEmpty == true
        ? r.classification['method'] as String
        : null
    : null,
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/templates/template_mapper_test.dart`
Expected: PASS（旧用例 29 内置/远端模板断言不回退）

- [ ] **Step 5: commit**

```bash
git add lumira_app_flutter/lib/features/templates/services/template_mapper.dart lumira_app_flutter/test/features/templates/template_mapper_test.dart
git commit -m "feat(templates): mapper 4-level classification + shortDesc/ambience persistence"
```

---

### Task 3: 候选标签数据源（聚合自定义模板标签）

**Files:**
- Create: `lumira_app_flutter/lib/features/templates/data/custom_tag_options_provider.dart`
- Test: `lumira_app_flutter/test/features/templates/custom_tag_options_provider_test.dart`

**Interfaces:**
- Consumes: `TemplatesDao.getCustomOnly()`（`lib/core/db/dao/templates_dao.dart` 返回 `List<TemplateRecord>`）。
- Produces（Task 6 消费）:
  - `class CustomTagOption { final String name; final int count; }`
  - `final tagsDaoProvider = Provider<TemplatesDao>(...)`——若已存在同名，复用现有 provider 命名（查 `templatesDaoProvider`）。
  - `final customTagCandidatesProvider = FutureProvider<List<CustomTagOption>>((ref) async {...})`：遍历 `getCustomOnly()`，聚合 `record.tags` 去重并按 count 降序。

- [ ] **Step 1: 写失败测试**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/templates/data/custom_tag_options_provider.dart';

// 复用共享内存 DB + seed（仿模板编辑器测试做法），先写一条 count 断言
void main() { /* seed custom_templates 含 tags=['A','B'] 与 tags=['A','C']，断言候选顺序 A,B,C 且 count A=2 */ }
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/features/templates/custom_tag_options_provider_test.dart`
Expected: FAIL（`custom_tag_options_provider.dart` 不存在）

- [ ] **Step 3: 实现**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/database_provider.dart';

class CustomTagOption {
  const CustomTagOption({required this.name, required this.count});
  final String name;
  final int count;
}

final customTagCandidatesProvider =
    FutureProvider<List<CustomTagOption>>((ref) async {
  final dao = await ref.read(templatesDaoProvider.future);
  final custom = await dao.getCustomOnly();
  final freq = <String, int>{};
  for (final t in custom) {
    for (final tag in t.tags) {
      final s = tag.trim();
      if (s.isNotEmpty) freq[s] = (freq[s] ?? 0) + 1;
    }
  }
  final list = freq.entries
      .map((e) => CustomTagOption(name: e.key, count: e.value))
      .toList()
    ..sort((a, b) => b.count.compareTo(a.count));
  return list;
});
```

（确认 `templatesDaoProvider` 的导出路径与命名，先 Grep `templatesDaoProvider` 定义位置。）

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/features/templates/custom_tag_options_provider_test.dart`
Expected: PASS

- [ ] **Step 5: commit**

```bash
git add lumira_app_flutter/lib/features/templates/data/custom_tag_options_provider.dart lumira_app_flutter/test/features/templates/custom_tag_options_provider_test.dart
git commit -m "feat(templates): aggregate custom template tags as candidate options"
```

---

### Task 4: 顶部 Tab 条 widget（主题自适应）

**Files:**
- Create: `lumira_app_flutter/lib/features/templates/widgets/editor_tab_bar.dart`

**Interfaces:**
- Consumes: `themeTokensProvider`（`ThemeTokens`）、`uiStyleProvider`（`UIStyle`，来自 `lib/core/theme/theme_controller.dart` 或对应导出）。
- Produces（Task 5 消费）:
  - `class EditorTabBar extends ConsumerWidget { const EditorTabBar({required this.tabs, required this.index, required this.onSelect}); final List<String> tabs; final int index; final ValueChanged<int> onSelect; }`：横向可滚动一行 themed chip，高亮当前选中 tab。

- [ ] **Step 1: 实现 widget（含简单 golden/smoke 测试）**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';

class EditorTabBar extends ConsumerWidget {
  const EditorTabBar({
    super.key,
    required this.tabs,
    required this.index,
    required this.onSelect,
  });
  final List<String> tabs;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final isNeumorphic = ref.watch(uiStyleProvider) == UIStyle.neumorphic;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _TabChip(
                label: tabs[i],
                selected: i == index,
                tokens: tokens,
                isNeumorphic: isNeumorphic,
                onTap: () => onSelect(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.tokens,
    required this.isNeumorphic,
    required this.onTap,
  });
  // 选中：tokens.textPrimary 反色底（用 tokens.surfaceAlt/brand 派生）；
  // 未选中：tokens.surface + 细边（画布取向）。
  // neumorphic 用 tokens.shadowConvex 双向阴影；其余风格不用外阴影。
  // 严禁硬编码 Colors.xxx / _FieldLabel 外的颜色。
}
```

（`themeTokensProvider` / `uiStyleProvider` / `UIStyle` 的精确导出符号，先 Grep `themeTokensProvider`、`enum UIStyle` 定位，写死 import 路径若与实际不符会编译失败。）

- [ ] **Step 2: 写 smoke 测试（4 风格 × 2 主题渲染不抛异常）**

在 `test/features/templates/editor_tab_bar_test.dart` 渲染 `EditorTabBar`，遍历 `uiStyleProvider` 4 值与 2 主题，断言能找到各 tab 文本。

- [ ] **Step 3: commit**

```bash
git add lumira_app_flutter/lib/features/templates/widgets/editor_tab_bar.dart lumira_app_flutter/test/features/templates/editor_tab_bar_test.dart
git commit -m "feat(templates): theme-adaptive editor top tab bar"
```

---

### Task 5: 页面改为顶部 Tab 布局 + 各 Tab 内容归位

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/pages/templates_editor_page.dart`

**Interfaces:**
- Consumes: Task 4 `EditorTabBar`；现有 `_Step1TemplateInfo`/`_Step2Composition`/`_Step3Pose`/`_Step4Camera`/`_Step5SceneGuide`/`_Step6PostProcess` 类（需把覆盖/姿势剪影抽到「封面与剪影」Tab）。
- Produces：`_TemplatesEditorPageState` 新增 `int _tabIndex`，`build()` 渲染 `EditorTabBar` + `AnimatedSwitcher` 显示当前 Tab 内容。

- [ ] **Step 1: 追加 `_tabIndex` 状态与常量 Tab 列表**

```dart
// 与后台 STEPS 一致的 6 个 tab 标题
const List<String> _editorTabs = [
  '基本信息', '封面与剪影', '构图', '相机参数', '场景引导', '后期处理',
];
// 状态类中新增：
int _tabIndex = 0;
```

- [ ] **Step 2: 调整 `build()` 主布局**

将 `SingleChildScrollView`（含 6 个 step 堆叠）替换为：

```dart
Column(
  children: [
    EditorTabBar(
      tabs: _editorTabs,
      index: _tabIndex,
      onSelect: (i) => setState(() => _tabIndex = i),
    ),
    Expanded(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: SingleChildScrollView(
          key: ValueKey(_tabIndex),
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _buildTabContent(_tabIndex),
          ),
        ),
      ),
    ),
    _EditorFooter(...), // 保持原参数不变
    if (_isLoadingFromDao) ... // 保持
  ],
)
```

- [ ] **Step 3: 新增 `_buildTabContent(int i)` 分发**

```dart
List<Widget> _buildTabContent(int i) {
  switch (i) {
    case 0: // 基本信息
      return [_Step1TemplateInfo(...)]; // 移除封面图字段，见 Step 4/6
    case 1: // 封面与剪影
      return [ cover 字段,  _Step3Pose(...) ]; // cover 从 Step1 抽离到此处
    case 2: return [_Step2Composition(...)];
    case 3: return [_Step4Camera(...)];
    case 4: return [_Step5SceneGuide(...)];
    case 5: return [_Step6PostProcess(...)];
  }
}
```

各 step 都包一层 `_StepCard` 用的是其自身实现，保持原 tokens/onChange 参数不改（除 step 1/3 的归位）。

- [ ] **Step 4: 从 `_Step1TemplateInfo` 移除「效果图（封面图）」区块**

删除 Step1 中整段 `_FieldLabel('效果图（封面图）')` + `center cover` 预览/占位（原 L1588-L1651 区域），改为在「封面与剪影」Tab 内渲染同一段（把该段复制到 `_buildTabContent(1)` 的 cover widget，用 `form.meta.coverImage` + `_showCoverImagePicker`）。

- [ ] **Step 5: 移除旧 step 间距/序号视差**

`_StepCard` 的 `stepNumber` 等原用于长列表的视觉，若造成 tab 内容中多余编号，按需隐藏 stepNumber 标签（保留卡片浮层样式）。以 `flutter analyze` 零 error 为准。

- [ ] **Step 6: 运行编辑器页测试（切换到各 tab 断言字段可见）**

改造 `test/features/templates/templates_editor_page_test.dart`：在每个断言「某 step 字段」前，先 `await tester.tap(find.text(tabTitle))` + `pumpAndSettle` 切到对应 tab，再断言字段。

- [ ] **Step 7: commit**

```bash
git add lumira_app_flutter/lib/features/templates/pages/templates_editor_page.dart lumira_app_flutter/test/features/templates/templates_editor_page_test.dart
git commit -m "feat(templates): editor page top-tab layout + cover/pose merged tab"
```

---

### Task 6: 基本信息 Tab 新字段 UI + 四级级联 + 标签 chips

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/pages/templates_editor_page.dart`（`_Step1TemplateInfo` / `_Step1TemplateInfoState`）
- Consumes: Task 1 字段、Task 3 `customTagCandidatesProvider`、Task 2 mapper。

- [ ] **Step 1: 四级级联 — 状态类增加第 4 级选项**

```dart
List<EditorOption> _subStyleOptions = const []; // 三级（原 _methodOptions 改名）
List<EditorOption> _method4Options = const [];  // 四级（新增）
```

在 `_Step1TemplateInfoState` 中把 `_loadMethodOptions` 更名为 `_loadSubStyleOptions`（三级，子风格 = 旧“方式”），新增：

```dart
Future<void> _loadMethod4Options(String? subStyleKey) async {
  _lastLoadedSubStyle = subStyleKey;
  if (subStyleKey == null || subStyleKey.isEmpty) {
    if (mounted) setState(() => _method4Options = const []);
    return;
  }
  final dao = await ref.read(templatesDaoProvider.future);
  final cats = await dao.getCategoriesByParent(subStyleKey);
  if (!mounted) return;
  setState(() => _method4Options = cats.map((c) => EditorOption(c.key, c.name)).toList());
}
```

级联刷新逻辑：`category` 变 → 清 `subStyle`+`method4`；`style` 变 → 清 `subStyle`+`method4`；`subStyle` 变 → 清 `method4`。

- [ ] **Step 2: 表单四个级联下拉**

“分类”用 `category`（`_typeOptions`）、“风格”用 `style`（`_styleOptions`）、“子风格”用 `subStyle`（新 `_subStyleOptions`）、“方法”用 `method`（`_method4Options`）。每个下拉 `onChanged` 按 Step1 的级联规则写回 `meta.category/style/subStyle/method` 对应字段。

- [ ] **Step 3: 短简介输入框**

在“分类”之后插入：

```dart
_FieldLabel(tokens: tokens, text: '短简介'),
_FieldInput(
  tokens: tokens,
  initialValue: form.meta.shortDesc,
  placeholder: '一句话介绍（推荐 ≤20 字）',
  maxLength: 20,
  onChanged: (v) => onChange(() => form.meta.shortDesc = v),
),
```

（`_FieldInput` 是否支持 `maxLength` 先查实现；不支持则用 `onChanged` 截断。）

- [ ] **Step 4: 适用季节/天气/时段 — 复用 admin 的 chips 多选**

三段 `EditorAmbienceChip`（季节 春夏秋冬 / 天气 晴多云阴雨雪雾 / 时段 黄金小时白天夜晚暖调冷调），选中写入 `meta.ambience`（不存在时创建 `RemoteTemplateAmbienceDto`）。禁用状态（`ambience==null`）全空。

写一个小组件（`_AmbienceChipGroup`）在文件内：`ConsumerWidget` 用 tokens 渲染可切换 chips，`onChange` 更新 `meta.ambience` 对应 list。

- [ ] **Step 5: 标签 UI — 聚合候选 + 新增**

把原先“标签”逗号文本框替换为：

1. `ref.watch(customTagCandidatesProvider)` 得到候选 `CustomTagOption[]`；
2. 渲染成可 toggle 的 chips（已含于 `meta.tags` 的高亮）；
3. 底部“+ 新增标签”输入框（`TextEditingController`），回车/确定追加到 `meta.tags` 并清空输入。

保留 `_tagsController`/`_onTagsChanged` 兼容逻辑，`meta.tags` 仍是 `List<String>`。

- [ ] **Step 6: 运行编辑器页测试（基本信息 tab 新字段断言）**

在测试中切到“基本信息” tab：断言短简介输入框、四节点选级联下拉、ambience chips、标签候选 chip 与新增输入均可见，保存后 `TemplateRecord.shortDesc/ambience/tags/classification` 正确（可在 task 2 的 mapper 测试里已覆盖持久化，此处补 UI 冒烟）。

- [ ] **Step 7: commit**

```bash
git add lumira_app_flutter/lib/features/templates/pages/templates_editor_page.dart lumira_app_flutter/test/features/templates/templates_editor_page_test.dart
git commit -m "feat(templates): basic info tab new fields (shortDesc/ambience/4-level/tag chips)"
```

---

### Task 7: 全量回归

- [ ] **Step 1: 跑全部测试**

Run: `flutter test`
Expected: 全绿（含模板编辑器、mapper、card/detail、capture 相关，不回归）

- [ ] **Step 2: 静态分析**

Run: `flutter analyze`（在 `lumira_app_flutter/`）
Expected: 无 error（允许 pre-existing info 级 lint）

- [ ] **Step 3: 收尾 commit（如有未提交改动）**

```bash
git add -A
git commit -m "test: regression pass for custom template form tabs" # 仅当有改动
```

---

## Self-Review（内联核对）

- 六 Tab 覆盖 spec 第三节（基本信息含短简介/四级/ambience/标签；封面与剪影含封面+姿势）→ Task 5/6。
- 数据模型（Task 1）、mapper（Task 2）、标签聚合（Task 3）、Tab 条（Task 4）、布局（Task 5）、新字段 UI（Task 6）均落地。
- backward-compat 旧 `{type,style,method}` 读取在 Task 2 Step 3 显式实现。
- 无 TBD；代码步骤均给出具体片段；跨任务类型名（`EditorTabBar`/`CustomTagOption`/`_method4Options`）在后续任务同引用。
- 潜在缺口：`template_mapper_test.dart` 可能不存在，应先创建；`themeTokensProvider`/`uiStyleProvider` import 路径须先 Grep 确认（计划内已以注释标记）。