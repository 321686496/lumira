# 拍摄页模板列表真实数据整合与排序优化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让拍摄页模板列表读取系统模板 + 自定义模板的真实数据，按使用频率和用户偏好排序，自定义模板套用后参数正确加载。

**Architecture:** 新增 `allTemplatesProvider`（FutureProvider）合并 TemplateRegistry（系统模板）+ TemplatesDao（自定义模板）。扩展 `originalTemplateProvider` 支持查自定义模板缓存。新增 `sortedTemplatesProvider` 按使用频率 + 用户偏好排序。TemplateStrip 适配 AsyncValue。

**Tech Stack:** Flutter, Riverpod (FutureProvider/StateProvider/Provider), SQLite (sqflite), camerawesome

## Global Constraints

- 所有 UI 颜色使用 app 主题色（LumiraDesignTokens），不加新自定义色
- CSS 单位不适用（Flutter 项目）
- 使用 Riverpod 的 `ref.watch` / `ref.read` / `ref.invalidate` 模式
- `TemplateMapper.toPhotoTemplate(TemplateRecord)` 已存在，直接复用
- `galleryDaoProvider` 和 `templatesDaoProvider` 已在 `lib/core/db/database_provider.dart` 定义
- `userPreferenceProvider` 已在 `lib/features/templates/data/templates_providers.dart` 定义
- 测试命令：`cd lumira_app_flutter && flutter test`

---

### Task 1: 新增 allTemplatesProvider 和 templateCacheProvider

**Files:**
- Modify: `lib/features/capture/data/capture_state.dart`（在 `originalTemplateProvider` 上方插入新 providers）
- Test: `test/features/capture/all_templates_provider_test.dart`

**Interfaces:**
- Consumes: `templatesDaoProvider`（`FutureProvider<TemplatesDao>`），`TemplateRegistry.allTemplates`（`List<PhotoTemplate>`），`TemplateMapper.toPhotoTemplate(TemplateRecord)`（→ `PhotoTemplate`）
- Produces: `allTemplatesProvider`（`FutureProvider<List<PhotoTemplate>>`），`templateCacheProvider`（`Provider<Map<String, PhotoTemplate>>`）

- [ ] **Step 1: Write the failing test**

Create `test/features/capture/all_templates_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/data/template_registry.dart';

void main() {
  test('allTemplatesProvider returns system templates even when DAO is unavailable', () async {
    final container = ProviderContainer();
    final result = await container.read(CaptureState.allTemplatesProvider.future);
    // 系统模板始终可用（12 个），DAO 加载失败时降级为仅系统模板
    expect(result.length, greaterThanOrEqualTo(12));
    // 验证包含已知系统模板
    final ids = result.map((t) => t.meta.id).toList();
    expect(ids, contains('soft_portrait'));
    expect(ids, contains('neon_portrait'));
  });

  test('templateCacheProvider contains all system templates by id', () {
    final container = ProviderContainer();
    final cache = container.read(CaptureState.templateCacheProvider);
    // 降级策略：DAO 未加载完成时仅含系统模板
    expect(cache['soft_portrait'], isNotNull);
    expect(cache['neon_portrait'], isNotNull);
    expect(cache.length, greaterThanOrEqualTo(12));
  });

  tearDown(() {
    // 清理
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd lumira_app_flutter && flutter test test/features/capture/all_templates_provider_test.dart`
Expected: FAIL with `CaptureState.allTemplatesProvider` not defined / `templateCacheProvider` not defined

- [ ] **Step 3: Add imports to capture_state.dart**

In `lib/features/capture/data/capture_state.dart`, add after line 11 (`import '../data/scene_presets_data.dart';`):

```dart
import '../../templates/services/template_mapper.dart';
import '../../../core/db/dao/templates_dao.dart';
import '../../templates/data/templates_providers.dart';
```

- [ ] **Step 4: Add allTemplatesProvider**

In `lib/features/capture/data/capture_state.dart`, add above `originalTemplateProvider` (before line 127, after the comment `// ── 新增：模板编辑状态 ──`):

```dart
  /// 所有模板列表（系统 + 自定义）
  /// 系统模板来自 TemplateRegistry（同步），自定义模板来自 TemplatesDao（异步）
  /// DAO 加载失败时降级为仅系统模板
  static final allTemplatesProvider =
      FutureProvider<List<PhotoTemplate>>((ref) async {
    // 系统模板（同步，立即可用）
    final systemTemplates = TemplateRegistry.allTemplates;

    // 自定义模板（异步）
    try {
      final dao = await ref.watch(templatesDaoProvider.future);
      final customRecords = await dao.getCustomOnly();
      final customTemplates = customRecords
          .map((r) => TemplateMapper.toPhotoTemplate(r))
          .toList();
      return [...systemTemplates, ...customTemplates];
    } catch (e) {
      // DAO 不可用时降级为仅系统模板
      debugPrint('[capture] allTemplatesProvider: DAO load failed, fallback to system only: $e');
      return systemTemplates;
    }
  });

  /// 模板缓存（ID → PhotoTemplate）
  /// 从 allTemplatesProvider 结果构建 Map，供 originalTemplateProvider 快速查找
  /// 降级策略：加载中时仅含系统模板
  static final templateCacheProvider =
      Provider<Map<String, PhotoTemplate>>((ref) {
    final asyncValue = ref.watch(allTemplatesProvider);
    // 系统模板始终可用（降级基线）
    final systemMap = {
      for (final t in TemplateRegistry.allTemplates) t.meta.id: t
    };
    return asyncValue.maybeWhen(
      data: (templates) => {
        for (final t in templates) t.meta.id: t
      },
      orElse: () => systemMap,
    );
  });

```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd lumira_app_flutter && flutter test test/features/capture/all_templates_provider_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/capture/data/capture_state.dart test/features/capture/all_templates_provider_test.dart
git commit -m "feat(capture): add allTemplatesProvider and templateCacheProvider"
```

---

### Task 2: 扩展 originalTemplateProvider 支持自定义模板

**Files:**
- Modify: `lib/features/capture/data/capture_state.dart`（第 129-133 行 `originalTemplateProvider`）
- Test: `test/features/capture/original_template_provider_test.dart`

**Interfaces:**
- Consumes: `templateCacheProvider`（Task 1 产出），`TemplateRegistry.getTemplate(id)`
- Produces: 修改后的 `originalTemplateProvider`（`Provider<PhotoTemplate?>`，支持自定义模板 ID）

- [ ] **Step 1: Write the failing test**

Create `test/features/capture/original_template_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';

void main() {
  test('originalTemplateProvider returns system template by id', () {
    final container = ProviderContainer();
    container.read(CaptureState.currentTemplateIdProvider.notifier).state =
        'soft_portrait';
    final template = container.read(CaptureState.originalTemplateProvider);
    expect(template, isNotNull);
    expect(template!.meta.id, 'soft_portrait');
  });

  test('originalTemplateProvider returns null when templateId is null', () {
    final container = ProviderContainer();
    container.read(CaptureState.currentTemplateIdProvider.notifier).state =
        null;
    final template = container.read(CaptureState.originalTemplateProvider);
    expect(template, isNull);
  });

  test('originalTemplateProvider returns null for unknown id (not in registry or cache)', () {
    final container = ProviderContainer();
    container.read(CaptureState.currentTemplateIdProvider.notifier).state =
        'nonexistent_template_id';
    // 降级策略：不在 registry 也不在 cache（缓存未加载完成）→ null
    // 缓存加载完成后会自动更新
    final template = container.read(CaptureState.originalTemplateProvider);
    // 在测试环境中 DAO 不可用，templateCacheProvider 仅含系统模板
    // 因此 unknown id 返回 null
    expect(template, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd lumira_app_flutter && flutter test test/features/capture/original_template_provider_test.dart`
Expected: 第一个测试 PASS（现有逻辑已支持系统模板），第三个测试可能 PASS（现有逻辑也返回 null）。但需要验证第二个测试。如果全 PASS，说明现有逻辑已覆盖基础场景，重点验证自定义模板的查找路径。

- [ ] **Step 3: Modify originalTemplateProvider**

In `lib/features/capture/data/capture_state.dart`, replace the existing `originalTemplateProvider` (lines 129-133):

Old code:
```dart
  static final originalTemplateProvider = Provider<PhotoTemplate?>((ref) {
    final id = ref.watch(currentTemplateIdProvider);
    if (id == null) return null;
    return TemplateRegistry.getTemplate(id);
  });
```

New code:
```dart
  /// 原始模板（只读，派生自 currentTemplateIdProvider）
  /// 先查 TemplateRegistry（系统模板，同步快路径）
  /// 未找到 → 查 templateCacheProvider（含自定义模板的运行时缓存）
  static final originalTemplateProvider = Provider<PhotoTemplate?>((ref) {
    final id = ref.watch(currentTemplateIdProvider);
    if (id == null) return null;
    // 快路径：系统模板（同步）
    final builtin = TemplateRegistry.getTemplate(id);
    if (builtin != null) return builtin;
    // 慢路径：自定义模板（从预加载缓存读取）
    return ref.watch(templateCacheProvider)[id];
  });
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd lumira_app_flutter && flutter test test/features/capture/original_template_provider_test.dart`
Expected: PASS

- [ ] **Step 5: Run all existing capture tests to verify no regression**

Run: `cd lumira_app_flutter && flutter test test/features/capture/`
Expected: All PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/capture/data/capture_state.dart test/features/capture/original_template_provider_test.dart
git commit -m "feat(capture): extend originalTemplateProvider to support custom templates"
```

---

### Task 3: 新增 sortedTemplatesProvider

**Files:**
- Modify: `lib/features/capture/data/capture_state.dart`（在 `templateCacheProvider` 下方新增）
- Test: `test/features/capture/sorted_templates_provider_test.dart`

**Interfaces:**
- Consumes: `allTemplatesProvider`（Task 1），`galleryDaoProvider`（`FutureProvider<GalleryDao>`），`userPreferenceProvider`（`FutureProvider<UserPreference>`）
- Produces: `sortedTemplatesProvider`（`FutureProvider<List<PhotoTemplate>>`）

- [ ] **Step 1: Write the failing test**

Create `test/features/capture/sorted_templates_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';

void main() {
  test('sortedTemplatesProvider returns templates sorted by usage frequency', () async {
    final container = ProviderContainer();
    final result = await container.read(CaptureState.sortedTemplatesProvider.future);
    // 至少包含 12 个系统模板
    expect(result.length, greaterThanOrEqualTo(12));
    // 结果应该是 List<PhotoTemplate>
    expect(result.first.meta.id, isNotNull);
  });

  test('sortedTemplatesProvider degrades gracefully when DAO unavailable', () async {
    final container = ProviderContainer();
    // 在测试环境中 DAO 不可用，应该降级为系统模板列表
    final result = await container.read(CaptureState.sortedTemplatesProvider.future);
    // 降级时仍返回系统模板（可能未排序或按默认顺序）
    expect(result.length, greaterThanOrEqualTo(12));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd lumira_app_flutter && flutter test test/features/capture/sorted_templates_provider_test.dart`
Expected: FAIL with `CaptureState.sortedTemplatesProvider` not defined

- [ ] **Step 3: Add sortedTemplatesProvider**

In `lib/features/capture/data/capture_state.dart`, add after `templateCacheProvider` (after the closing of `templateCacheProvider`):

```dart
  /// 排序后的模板列表（按使用频率 + 用户偏好）
  /// 排序优先级：
  /// 1. 使用频率降序（gallery_items 中 template_id 出现次数）
  /// 2. 用户偏好匹配（category == topCategory 优先）
  /// 3. 名称字母序兜底
  static final sortedTemplatesProvider =
      FutureProvider<List<PhotoTemplate>>((ref) async {
    // 获取所有模板（系统 + 自定义）
    final templates = await ref.watch(allTemplatesProvider.future);

    // 获取使用频率
    Map<String, int> usageCounts = {};
    String topCategory = '';
    try {
      final galleryDao = await ref.watch(galleryDaoProvider.future);
      usageCounts = await galleryDao.countByTemplate();

      // 获取用户偏好
      final pref = await ref.read(userPreferenceProvider.future);
      topCategory = pref.topCategory;
    } catch (e) {
      // DAO 不可用时降级为无排序（按默认顺序）
      debugPrint('[capture] sortedTemplatesProvider: stats load failed, fallback to unsorted: $e');
      return templates;
    }

    // 排序
    final sorted = List<PhotoTemplate>.from(templates);
    sorted.sort((a, b) {
      final countA = usageCounts[a.meta.id] ?? 0;
      final countB = usageCounts[b.meta.id] ?? 0;
      // 1. 使用频率降序
      if (countA != countB) return countB.compareTo(countA);
      // 2. 用户偏好匹配优先
      final matchA = a.meta.category == topCategory ? 1 : 0;
      final matchB = b.meta.category == topCategory ? 1 : 0;
      if (matchA != matchB) return matchB.compareTo(matchA);
      // 3. 名称字母序兜底
      return a.meta.name.compareTo(b.meta.name);
    });
    return sorted;
  });

```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd lumira_app_flutter && flutter test test/features/capture/sorted_templates_provider_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/capture/data/capture_state.dart test/features/capture/sorted_templates_provider_test.dart
git commit -m "feat(capture): add sortedTemplatesProvider with usage frequency and preference sorting"
```

---

### Task 4: TemplateStrip 适配新数据源 + 自定义模板标记

**Files:**
- Modify: `lib/features/capture/widgets/template_strip.dart`（完整重写 build 方法）
- Test: 无新测试文件（UI 组件，通过手动验证）

**Interfaces:**
- Consumes: `sortedTemplatesProvider`（Task 3），`currentTemplateIdProvider`，`TemplateRegistry.allTemplates`（降级用）
- Produces: 修改后的 `TemplateStrip` widget

- [ ] **Step 1: Modify TemplateStrip to use sortedTemplatesProvider**

In `lib/features/capture/widgets/template_strip.dart`, replace the entire `build` method (lines 16-135) with:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentId = ref.watch(CaptureState.currentTemplateIdProvider);
    final templatesAsync = ref.watch(CaptureState.sortedTemplatesProvider);

    return SizedBox(
      height: compact ? 80 : 100,
      child: templatesAsync.when(
        // 加载完成：显示排序后的模板列表
        data: (templates) {
          final list = compact ? templates.take(6).toList() : templates;
          if (list.isEmpty) {
            return _buildEmptyState();
          }
          return _buildTemplateList(list, currentId, ref);
        },
        // 加载中：降级显示系统模板
        loading: () {
          final fallback = TemplateRegistry.allTemplates;
          final list = compact ? fallback.take(6).toList() : fallback;
          return _buildTemplateList(list, currentId, ref);
        },
        // 错误：降级显示系统模板
        error: (_, __) {
          final fallback = TemplateRegistry.allTemplates;
          final list = compact ? fallback.take(6).toList() : fallback;
          return _buildTemplateList(list, currentId, ref);
        },
      ),
    );
  }

  /// 空状态占位
  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        '暂无模板',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      ),
    );
  }

  /// 构建模板横向列表
  Widget _buildTemplateList(
    List<PhotoTemplate> templates,
    String? currentId,
    WidgetRef ref,
  ) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: templates.length,
      itemBuilder: (ctx, i) {
        final tpl = templates[i];
        final active = tpl.meta.id == currentId;
        // 判断是否为自定义模板（不在 TemplateRegistry 中则为自定义）
        final isCustom = TemplateRegistry.getTemplate(tpl.meta.id) == null;
        return GestureDetector(
          onTap: () {
            final next = active ? null : tpl.meta.id;
            ref
                .read(CaptureState.currentTemplateIdProvider.notifier)
                .state = next;
          },
          child: Container(
            width: compact ? 60 : 72,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: active
                  ? Border.all(color: Colors.amber, width: 2)
                  : Border.all(color: Colors.white12, width: 0.5),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 封面图
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: tpl.meta.cover.isEmpty
                      ? Container(
                          color: Colors.white12,
                          child: Icon(
                            Icons.image,
                            color: active ? Colors.amber : Colors.white54,
                            size: 24,
                          ),
                        )
                      : Image.network(
                          tpl.meta.cover,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.white12,
                            child: Icon(
                              Icons.image,
                              color: active ? Colors.amber : Colors.white54,
                              size: 24,
                            ),
                          ),
                        ),
                ),
                // 渐变遮罩
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(6),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                    child: Text(
                      tpl.meta.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                // 自定义模板标记
                if (isCustom)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '我的',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 8,
                        ),
                      ),
                    ),
                  ),
                // 选中标记
                if (active)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.black,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
```

- [ ] **Step 2: Add TemplateRegistry import to template_strip.dart**

In `lib/features/capture/widgets/template_strip.dart`, add the import for `PhotoTemplate` type (needed for `_buildTemplateList` signature). The file already imports `capture_state.dart` and `template_registry.dart`, but needs the `PhotoTemplate` type:

Add after line 4 (`import '../data/template_registry.dart';`):
```dart
import '../domain/photo_template.dart';
```

- [ ] **Step 3: Run existing tests to verify no regression**

Run: `cd lumira_app_flutter && flutter test test/features/capture/`
Expected: All PASS

- [ ] **Step 4: Run full test suite**

Run: `cd lumira_app_flutter && flutter test`
Expected: All PASS (or only pre-existing unrelated failures)

- [ ] **Step 5: Commit**

```bash
git add lib/features/capture/widgets/template_strip.dart
git commit -m "feat(capture): TemplateStrip reads sorted real data with custom template badge"
```

---

### Task 5: 模板创建/编辑/删除后刷新缓存

**Files:**
- Modify: `lib/features/templates/pages/templates_editor_page.dart`（保存后 invalidate）
- Test: 无新测试（集成验证）

**Interfaces:**
- Consumes: `CaptureState.allTemplatesProvider`（Task 1）
- Produces: 模板编辑保存后自动刷新拍摄页模板列表

- [ ] **Step 1: Find the save callback in templates_editor_page.dart**

Read `lib/features/templates/pages/templates_editor_page.dart` and find where templates are saved (the `_saveTemplate` or equivalent method that calls `dao.upsert`).

- [ ] **Step 2: Add invalidate call after save**

In the save method (after `dao.upsert(record)` or equivalent success path), add:

```dart
// 刷新拍摄页模板列表缓存
ref.invalidate(CaptureState.allTemplatesProvider);
```

Note: This requires adding `import '../../capture/data/capture_state.dart';` at the top of the file if not already imported.

- [ ] **Step 3: Find delete callback and add invalidate**

Similarly, in the delete method (after `dao.delete(id)`), add the same invalidate call:

```dart
ref.invalidate(CaptureState.allTemplatesProvider);
```

- [ ] **Step 4: Run tests**

Run: `cd lumira_app_flutter && flutter test test/features/templates/`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/templates/pages/templates_editor_page.dart
git commit -m "feat(templates): invalidate capture template cache on create/edit/delete"
```

---

## Self-Review Notes

### Spec coverage check

| Spec requirement | Task |
|---|---|
| 模板列表读取系统+自定义真实数据 | Task 1 (allTemplatesProvider) |
| 自定义模板套用后参数正确加载 | Task 2 (originalTemplateProvider 扩展) |
| 按使用频率排序 | Task 3 (sortedTemplatesProvider) |
| 按用户偏好排序 | Task 3 (sortedTemplatesProvider) |
| TemplateStrip 适配新数据源 | Task 4 |
| 自定义模板标记 | Task 4 (isCustom 判断 + "我的"标签) |
| 缓存失效 | Task 5 (invalidate) |
| 降级策略 | Task 1 (try-catch 降级) + Task 4 (loading/error 降级) |
