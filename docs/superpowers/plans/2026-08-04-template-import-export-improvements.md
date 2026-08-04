# 模板导入导出功能完善 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 4 bugs (silhouette whitelist, link/QR persistence, filename collision, picsum cover URLs) and close 2 spec gaps (cover embedding in .pptpl, version compatibility check) in the Flutter template import/export pipeline.

**Architecture:** All changes confined to `lumira_app_flutter/`. Data layer migrates real silhouette SVGs from Vue and fixes 12 template cover paths. Domain layer adds nullable `coverData` to `TemplateMeta`/`TemplateRecord`. Services layer embeds cover base64 on export, validates format version on import. Widget layer persists link/QR imports to DAO and surfaces version warnings.

**Tech Stack:** Flutter 3.7+, Dart 2.19, sqflite, riverpod, no new dependencies.

## Global Constraints

- All code must work on iOS, Android, and HarmonyOS (per AGENT.md §1)
- No new third-party dependencies (rootBundle and dart:convert are already available)
- DB migrations must be idempotent (use `_addColumnIfNotExists`)
- `coverData` is nullable — in-app templates leave it null (covers load from assets); only set during .pptpl export/import
- Silhouette SVG rendering (PoseSilhouette component) is out of scope — only migrate key list + SVG string data
- Vue/uni-app engineering is NOT modified (reference implementation only)

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `lib/features/templates/data/builtin_silhouettes.dart` | Canonical silhouette key list + SVG string map (migrated from Vue) | **Create** |
| `lib/features/templates/services/pptpl_format.dart` | .pptpl format version constants + import warning types + validator | **Create** |
| `lib/features/capture/domain/photo_template.dart` | Domain model — add `coverData` to `TemplateMeta` | Modify |
| `lib/core/db/dao/templates_dao.dart` | DAO row model — add `coverData` to `TemplateRecord` + `toRow`/`fromRow` | Modify |
| `lib/core/db/tables.dart` | Add `colCoverData` constant | Modify |
| `lib/core/db/database_provider.dart` | v11 migration: add column + reseed builtin covers | Modify |
| `lib/core/db/seeders/builtin_data_seeder.dart` | Add `reseedBuiltinCovers` method | Modify |
| `lib/features/capture/data/templates/*.dart` (12 files) | Replace picsum URLs with local asset paths | Modify |
| `lib/features/templates/data/templates_editor_mock_data.dart` | Remove mock silhouette keys + SVGs | Modify |
| `lib/features/templates/services/template_mapper.dart` | Fix whitelist source; read `coverData` on import | Modify |
| `lib/features/templates/services/template_exporter.dart` | Embed cover base64; fix filename collision | Modify |
| `lib/features/templates/pages/templates_editor_page.dart` | Update silhouette picker to use new data source | Modify |
| `lib/features/templates/widgets/template_import_sheet.dart` | Persist link/QR to DAO; show version warnings | Modify |
| `lib/features/templates/pages/templates_all_page.dart` | Remove `importedAllTemplatesProvider` dependency | Modify |
| `lib/features/templates/data/imported_templates_provider.dart` | Dead code after link/QR persistence | **Delete** |
| `test/features/templates/builtin_silhouettes_test.dart` | Verify migrated SVG data | **Create** |
| `test/features/templates/cover_embedding_test.dart` | Cover round-trip integration test | **Create** |
| `test/template_import_test.dart` | Add silhouette/coverData/version test cases | Modify |
| `test/template_exporter_test.dart` | Add coverData/filename test cases | Modify |

---

### Task 1: Migrate Silhouette Library from Vue

**Files:**
- Create: `lumira_app_flutter/lib/features/templates/data/builtin_silhouettes.dart`
- Modify: `lumira_app_flutter/lib/features/templates/services/template_mapper.dart` (lines 3, 553-574)
- Modify: `lumira_app_flutter/lib/features/templates/data/templates_editor_mock_data.dart` (lines 389-410)
- Modify: `lumira_app_flutter/lib/features/templates/pages/templates_editor_page.dart` (lines 1538, 1541)
- Create: `lumira_app_flutter/test/features/templates/builtin_silhouettes_test.dart`

**Interfaces:**
- Produces: `kBuiltinSilhouetteKeys` (`List<String>` — 12 keys, no `'none'`), `kBuiltinSilhouettes` (`Map<String, String>` — key → SVG string)

- [ ] **Step 1: Write the failing test**

Create `test/features/templates/builtin_silhouettes_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/templates/data/builtin_silhouettes.dart';

void main() {
  group('builtin_silhouettes', () {
    test('kBuiltinSilhouetteKeys has exactly 12 keys (no none)', () {
      expect(kBuiltinSilhouetteKeys.length, 12);
      expect(kBuiltinSilhouetteKeys, isNot(contains('none')));
    });

    test('kBuiltinSilhouettes has all 12 keys mapped to non-empty SVGs', () {
      for (final key in kBuiltinSilhouetteKeys) {
        final svg = kBuiltinSilhouettes[key];
        expect(svg, isNotNull, reason: 'key $key missing from map');
        expect(svg!, isNotEmpty, reason: 'key $key has empty SVG');
      }
    });

    test('all SVGs use viewBox="0 0 100 200" and fill="currentColor"', () {
      for (final entry in kBuiltinSilhouettes.entries) {
        expect(entry.value, contains('viewBox="0 0 100 200"'),
            reason: '${entry.key} missing viewBox');
        expect(entry.value, contains('fill="currentColor"'),
            reason: '${entry.key} missing currentColor');
      }
    });

    test('contains all expected keys', () {
      const expected = [
        'standing-profile', 'sitting-cafe', 'walking-street', 'soft-portrait',
        'neon-pose', 'vintage-portrait', 'peace-sign-girl', 'food-overhead',
        'cityscape-tripod', 'landscape-wide', 'macro-flower', 'still-life-table',
      ];
      for (final k in expected) {
        expect(kBuiltinSilhouetteKeys, contains(k), reason: 'missing key $k');
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/templates/builtin_silhouettes_test.dart`
Expected: FAIL with "Error when reading file" or "Target of URI doesn't exist" — the file doesn't exist yet.

- [ ] **Step 3: Create `builtin_silhouettes.dart`**

Create `lib/features/templates/data/builtin_silhouettes.dart`. Copy the 12 SVG strings verbatim from `lumira-app/src/data/silhouettes/index.ts` (lines 27-229). Structure:

```dart
// lib/features/templates/data/builtin_silhouettes.dart

/// 内置剪影 SVG 库（从 lumira-app/src/data/silhouettes/index.ts 迁移）
///
/// 所有 SVG 使用 viewBox="0 0 100 200"（1:2 人像比例），fill="currentColor"。
/// 此文件为剪影数据的唯一真实源（source of truth）。
class BuiltinSilhouettes {
  BuiltinSilhouettes._();

  /// 无姿势占位 SVG（空字符串）
  static const String noneSvg = '';

  /// 内置剪影 key → SVG 字符串映射
  static const Map<String, String> svgMap = {
    'standing-profile': standingProfileSvg,
    'sitting-cafe': sittingCafeSvg,
    'walking-street': walkingStreetSvg,
    'soft-portrait': softPortraitSvg,
    'neon-pose': neonPoseSvg,
    'vintage-portrait': vintagePortraitSvg,
    'peace-sign-girl': peaceSignGirlSvg,
    'food-overhead': foodOverheadSvg,
    'cityscape-tripod': cityscapeTripodSvg,
    'landscape-wide': landscapeWideSvg,
    'macro-flower': macroFlowerSvg,
    'still-life-table': stillLifeTableSvg,
  };

  /// 所有内置剪影 key 列表（排除 'none'）
  static const List<String> keys = [
    'standing-profile', 'sitting-cafe', 'walking-street', 'soft-portrait',
    'neon-pose', 'vintage-portrait', 'peace-sign-girl', 'food-overhead',
    'cityscape-tripod', 'landscape-wide', 'macro-flower', 'still-life-table',
  ];
}

// 顶层常量导出（便于直接引用）
final List<String> kBuiltinSilhouetteKeys = BuiltinSilhouettes.keys;
final Map<String, String> kBuiltinSilhouettes = BuiltinSilhouettes.svgMap;

// === SVG 字符串（从 Vue 迁移，保持原始路径数据不变）===

const String standingProfileSvg = '''<svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg" fill="currentColor">
  <path d="M52 14 C46 14 41 17 38 22 C33 31 29 43 27 57 C25 71 26 85 30 96 C34 104 39 108 44 107 C41 98 38 88 38 74 C38 60 40 47 43 38 C44 35 46 33 47 34 C47 39 46 47 44 56 C41 70 40 84 43 96 C45 102 48 106 51 107 L51 94 C49 86 48 76 49 62 C50 48 52 36 53 26 L53 18 C52 16 52 14 52 14 Z"/>
  <path d="M53 14 C58 14 61 18 61 23 C61 25 60 27 58 28 L61 29 C63 30 63 32 61 33 L58 34 L60 35 L59 37 L56 39 L53 41 L51 45 L51 50 C53 54 55 58 56 64 C58 73 58 83 56 93 L54 106 C53 116 53 126 54 136 L56 150 L57 168 L56 184 L55 190 L58 194 L52 195 L49 192 L49 184 L50 168 L51 150 L50 136 L49 126 L47 116 L46 106 C44 96 44 86 45 76 C46 66 48 58 50 52 L50 48 L48 44 C47 42 46 40 45 38 L44 34 C42 28 42 22 44 18 C46 15 49 14 53 14 Z"/>
  <path d="M46 44 C42 48 39 54 37 62 C36 68 37 72 40 74 C42 72 43 68 44 62 C45 56 46 50 47 46 Z"/>
</svg>''';

const String sittingCafeSvg = '''<svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg" fill="currentColor">
  <path d="M50 14 C42 14 35 18 32 25 C28 35 26 49 26 64 C26 78 28 90 32 98 C35 103 39 105 43 104 C40 95 38 85 38 71 C38 57 40 45 43 37 C44 40 44 45 43 51 C41 61 40 73 42 83 C43 89 45 93 47 95 L49 87 C47 81 46 73 47 63 C48 53 50 43 51 35 L51 21 C50 17 50 15 50 14 Z"/>
  <path d="M50 14 C56 14 60 18 60 25 C60 30 57 34 54 36 C57 38 60 42 62 48 L64 59 C65 67 65 75 64 83 L62 91 C60 95 57 97 54 98 L52 104 L54 112 C58 116 62 120 64 126 L66 140 L67 160 L67 180 L65 192 L61 196 L57 194 L56 184 L55 168 L54 152 L52 140 L50 132 L48 140 L46 152 L45 168 L44 184 L43 194 L39 196 L35 192 L33 180 L33 160 L34 140 L36 126 C38 120 42 116 46 112 L48 104 L46 98 C43 97 41 95 39 91 L37 83 C36 75 36 67 37 59 L39 48 C41 42 44 38 47 36 C44 34 41 30 41 25 C41 18 44 14 50 14 Z"/>
  <path d="M60 36 C64 34 68 36 70 40 C72 44 72 50 70 54 C68 56 65 56 63 54 L60 50 L58 44 Z M58 30 C60 26 64 24 68 26 C70 28 70 32 68 34 L64 36 L60 34 Z"/>
</svg>''';

const String walkingStreetSvg = '''<svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg" fill="currentColor">
  <path d="M51 14 C44 14 38 17 35 23 C30 33 25 46 22 60 C19 74 19 88 22 98 C26 104 32 107 37 105 C34 96 30 86 30 72 C30 58 33 45 37 36 C38 39 38 44 37 50 C35 60 34 72 36 82 C37 88 39 92 41 94 L43 86 C41 80 40 72 41 62 C42 52 44 42 46 34 L46 20 C45 16 46 14 51 14 Z"/>
  <path d="M52 14 C57 14 60 18 60 24 C60 29 57 33 54 35 C57 37 60 41 62 47 L64 58 C65 66 65 74 64 82 L62 90 C60 94 57 96 54 97 L52 103 L54 108 C58 110 62 113 65 118 C68 125 70 135 72 148 L74 168 L73 184 L71 192 L67 195 L63 192 L62 182 L61 166 L59 150 L57 138 L55 130 L52 128 L49 130 L47 138 L45 150 L43 166 L42 182 L41 192 L37 195 L33 192 L31 184 L32 168 L34 148 C36 135 38 125 41 118 C44 113 48 110 52 108 L54 103 L52 97 C49 96 47 94 45 90 L43 82 C42 74 42 66 43 58 L45 47 C47 41 50 37 53 35 C50 33 47 29 47 24 C47 18 48 14 52 14 Z"/>
</svg>''';

const String softPortraitSvg = '''<svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg" fill="currentColor">
  <path d="M50 14 C42 14 35 18 32 25 C28 35 26 50 26 65 C26 80 28 92 32 100 C36 106 42 108 48 107 C45 98 43 88 43 74 C43 60 45 48 48 40 C49 43 49 48 48 54 C46 64 45 76 47 86 C48 92 50 96 52 98 L54 90 C52 84 51 76 52 66 C53 56 55 46 56 38 L56 24 C55 20 55 16 50 14 Z"/>
  <path d="M50 14 C56 14 60 18 60 25 C60 30 57 34 54 36 C57 38 60 42 62 48 L64 58 C65 66 65 74 64 82 L62 90 C60 94 57 96 54 97 L52 103 L50 110 L48 103 L46 97 C43 96 41 94 39 90 L37 82 C36 74 36 66 37 58 L39 48 C41 42 44 38 47 36 C44 34 41 30 41 25 C41 18 44 14 50 14 Z"/>
  <path d="M44 88 C42 92 42 98 44 102 C46 105 50 106 54 105 C58 103 60 98 58 94 C56 90 52 88 48 88 Z M40 85 C38 88 38 92 40 94 L44 92 L42 88 Z M60 85 C62 88 62 92 60 94 L56 92 L58 88 Z"/>
</svg>''';

const String neonPoseSvg = '''<svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg" fill="currentColor">
  <path d="M55 18 C62 16 68 18 72 24 C76 32 78 42 77 52 C76 60 73 66 69 68 C67 62 66 54 66 46 C66 38 67 32 65 28 C63 26 60 26 58 28 Z"/>
  <path d="M50 14 C55 14 58 18 58 24 C58 29 56 33 53 35 C56 37 59 41 61 47 L63 56 C64 64 64 72 63 80 L61 88 C59 92 56 94 53 95 L51 100 L53 110 C56 120 59 132 61 145 L63 165 L62 180 L60 192 L56 195 L52 192 L51 182 L50 166 L49 150 L47 138 L45 130 L43 138 L41 150 L40 166 L39 182 L38 192 L34 195 L30 192 L28 180 L29 165 L31 145 C33 132 36 120 39 110 L41 100 L39 95 C36 94 34 92 32 88 L30 80 C29 72 29 64 30 56 L32 47 C34 41 37 37 40 35 C37 33 35 29 35 24 C35 18 39 14 50 14 Z"/>
  <path d="M30 56 C26 60 24 66 24 72 C24 76 26 78 30 77 L34 74 L36 68 L35 62 Z"/>
  <path d="M63 47 C67 43 72 40 77 38 C81 37 84 39 84 43 C83 46 80 48 76 50 L70 53 L65 56 Z"/>
</svg>''';

const String vintagePortraitSvg = '''<svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg" fill="currentColor">
  <path d="M50 10 C42 10 34 14 30 20 C28 24 28 28 30 30 C26 30 22 34 20 40 C19 44 20 48 23 50 C21 52 20 56 22 60 C24 62 28 62 30 60 C29 56 28 52 30 48 C32 44 36 42 40 42 C38 38 38 34 40 32 C42 34 44 36 46 38 C44 34 44 30 46 28 C48 30 50 32 50 34 C50 30 52 28 54 28 C56 30 56 34 54 38 C56 36 58 34 60 32 C62 34 62 38 60 42 C64 42 68 44 70 48 C72 52 71 56 70 60 C72 62 76 62 78 60 C80 56 79 52 77 50 C80 48 81 44 80 40 C78 34 74 30 70 30 C72 28 72 24 70 20 C66 14 58 10 50 10 Z"/>
  <path d="M50 32 C55 32 58 36 58 42 C58 46 56 50 53 52 C56 54 59 58 61 64 L63 75 C64 83 64 91 63 99 L61 107 C59 111 56 113 53 114 L51 120 L53 130 C56 140 59 152 61 165 L63 182 L62 192 L58 195 L54 192 L53 182 L52 168 L50 155 L48 168 L47 182 L46 192 L42 195 L38 192 L37 182 L39 165 C41 152 44 140 47 130 L49 120 L47 114 C44 113 41 111 39 107 L37 99 C36 91 36 83 37 75 L39 64 C41 58 44 54 47 52 C44 50 42 46 42 42 C42 36 45 32 50 32 Z"/>
  <path d="M42 110 C38 114 36 120 38 124 C41 126 46 125 50 122 C54 125 59 126 62 124 C64 120 62 114 58 110 Z"/>
</svg>''';

const String peaceSignGirlSvg = '''<svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg" fill="currentColor">
  <path d="M38 24 C32 26 28 32 27 40 C26 48 28 54 32 58 C30 62 30 68 32 72 C34 74 37 73 38 70 C36 66 35 60 37 56 C35 52 35 46 37 42 C36 38 37 32 38 28 Z"/>
  <path d="M62 24 C68 26 72 32 73 40 C74 48 72 54 68 58 C70 62 70 68 68 72 C66 74 63 73 62 70 C64 66 65 60 63 56 C65 52 65 46 63 42 C64 38 63 32 62 28 Z"/>
  <path d="M48 16 C53 14 58 17 59 23 C59 28 57 32 54 34 C57 36 60 40 62 46 L64 56 C65 64 65 72 64 80 L62 88 C60 92 57 94 54 95 L52 101 L54 110 C57 120 60 132 62 145 L64 162 L63 178 L61 190 L57 194 L53 192 L52 182 L51 168 L50 154 L48 145 L46 154 L45 168 L44 182 L43 192 L39 194 L35 190 L33 178 L34 162 L36 145 C38 132 41 120 44 110 L46 101 L44 95 C41 94 38 92 36 88 L34 80 C33 72 33 64 34 56 L36 46 C38 40 41 36 44 34 C41 32 39 28 39 23 C39 18 42 15 48 16 Z"/>
  <path d="M62 46 C66 44 70 42 74 40 L78 38 C82 36 85 38 85 42 C84 45 81 47 78 48 L74 50 L76 52 C79 54 82 56 84 59 C85 62 83 64 80 63 C77 61 74 59 71 57 L67 54 L64 52 Z"/>
  <path d="M85 42 C88 40 90 38 91 34 C92 30 91 26 89 26 C87 26 85 30 84 34 L83 40 Z M78 36 C80 32 81 28 80 24 C79 22 77 22 76 24 C75 28 75 32 76 36 L77 40 Z"/>
</svg>''';

const String foodOverheadSvg = '''<svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg" fill="currentColor">
  <path d="M0 110 C5 106 12 104 20 102 L28 100 C32 98 36 96 38 94 L40 92 L42 88 L42 84 L40 82 L38 80 L34 80 L28 82 L20 84 L12 86 L0 88 Z"/>
  <path d="M38 92 C42 88 46 86 52 86 C58 86 62 88 64 92 L65 98 C64 102 62 106 58 108 L52 110 C46 110 40 108 37 104 L36 100 Z"/>
  <path d="M58 86 C62 82 66 78 70 76 C74 74 78 74 80 76 C81 78 80 80 77 82 L70 86 L64 90 Z"/>
  <path d="M52 84 C55 78 58 72 62 68 C65 65 68 65 69 67 C69 69 68 72 65 75 L60 80 L55 84 Z"/>
  <path d="M46 86 C48 80 50 74 52 70 C54 67 56 67 57 69 C57 71 56 74 54 77 L51 82 L48 86 Z"/>
  <path d="M41 88 C42 84 43 80 44 76 C45 74 46 74 47 76 C47 78 46 81 45 84 L43 88 Z"/>
</svg>''';

const String cityscapeTripodSvg = '''<svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg" fill="currentColor">
  <path d="M32 40 L68 40 C70 40 72 42 72 44 L72 48 L76 48 C78 48 80 50 80 52 L80 64 C80 66 78 68 76 68 L72 68 L72 72 C72 74 70 76 68 76 L32 76 C30 76 28 74 28 72 L28 68 L24 68 C22 68 20 66 20 64 L20 52 C20 50 22 48 24 48 L28 48 L28 44 C28 42 30 40 32 40 Z"/>
  <path d="M42 76 L58 76 L60 82 L60 92 L58 96 L42 96 L40 92 L40 82 Z"/>
  <path d="M44 36 L56 36 L57 40 L43 40 Z"/>
  <path d="M38 96 L62 96 L64 100 L60 102 L40 102 L36 100 Z"/>
  <path d="M48 102 L52 102 L53 130 L51 135 L49 135 L47 130 Z"/>
  <path d="M48 130 L46 130 L30 175 L28 185 L32 185 L42 145 L48 135 Z"/>
  <path d="M52 130 L54 130 L70 175 L72 185 L68 185 L58 145 L52 135 Z"/>
  <path d="M49 130 L51 130 L51 190 L49 190 Z"/>
</svg>''';

const String landscapeWideSvg = '''<svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg" fill="currentColor">
  <path d="M0 70 L8 60 L15 65 L22 52 L30 58 L38 48 L45 55 L52 45 L60 52 L68 42 L75 50 L82 47 L90 55 L100 50 L100 80 L0 80 Z"/>
  <path d="M0 90 L6 80 L14 85 L20 75 L28 82 L36 72 L44 80 L50 70 L58 78 L66 68 L74 76 L82 72 L90 80 L100 78 L100 100 L0 100 Z"/>
  <path d="M0 110 L5 105 L12 112 L18 100 L25 108 L32 96 L40 104 L48 92 L55 100 L62 88 L70 96 L78 90 L85 98 L92 92 L100 100 L100 200 L0 200 Z"/>
  <path d="M15 110 L14 105 L16 100 L15 95 L17 92 L19 96 L18 101 L20 105 L19 110 L18 115 L16 115 Z M15 110 L17 110 L17 130 L15 130 Z"/>
  <path d="M82 115 L81 110 L83 105 L82 100 L84 97 L86 101 L85 106 L87 110 L86 115 L85 120 L83 120 Z M82 115 L84 115 L84 135 L82 135 Z"/>
</svg>''';

const String macroFlowerSvg = '''<svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg" fill="currentColor">
  <path d="M55 50 L54 55 L53 65 L52 80 L51 100 L50 120 L49 135 L48 140 L50 142 L52 140 L53 125 L54 110 L55 90 L56 70 L57 55 L58 50 Z"/>
  <path d="M55 45 C58 42 62 42 65 45 C67 48 67 52 65 55 C62 57 58 57 55 55 C53 52 53 48 55 45 Z"/>
  <path d="M60 42 C58 36 60 30 65 28 C70 27 73 30 73 35 C72 40 68 43 64 44 Z"/>
  <path d="M67 48 C73 47 78 50 79 55 C79 60 76 63 71 62 C67 60 65 56 65 52 Z"/>
  <path d="M62 58 C65 63 64 70 60 72 C55 73 52 70 52 65 C53 61 57 58 60 58 Z"/>
  <path d="M52 55 C47 58 43 56 41 52 C40 47 43 43 48 43 C52 44 54 48 54 52 Z"/>
  <path d="M53 42 C50 38 51 32 55 30 C60 29 63 32 62 37 C61 41 57 43 54 43 Z"/>
  <path d="M53 70 C48 72 44 78 43 84 C42 88 44 90 48 88 C52 85 54 80 54 75 Z"/>
  <path d="M44 135 C42 133 42 130 44 128 L48 126 L52 127 L55 129 L57 132 L58 136 L57 140 L55 144 L52 146 L48 146 L45 144 L43 140 Z"/>
  <path d="M52 144 C58 148 64 154 70 162 C76 170 82 178 86 186 C88 190 87 194 84 195 C80 195 76 192 72 186 C66 178 60 170 54 164 L50 158 L48 150 Z"/>
</svg>''';

const String stillLifeTableSvg = '''<svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg" fill="currentColor">
  <path d="M25 100 L23 105 L22 110 L21 115 L20 120 L20 140 L19 160 L18 180 L18 190 L19 195 L31 195 L32 190 L32 180 L31 160 L30 140 L30 120 L29 115 L28 110 L27 105 L25 100 Z"/>
  <path d="M22 100 L28 100 L28 95 L27 92 L23 92 L22 95 Z"/>
  <path d="M25 92 L24 80 L24 65 L25 55 L25 50 L25 65 L26 80 L26 92 Z"/>
  <path d="M25 50 C22 46 22 40 25 36 C28 34 30 38 30 42 C30 46 28 50 25 50 Z"/>
  <path d="M22 52 C19 50 18 46 20 42 C22 40 24 44 24 48 C24 52 22 54 22 52 Z"/>
  <path d="M28 52 C30 50 32 48 32 44 C32 40 28 40 27 44 C26 48 27 52 28 52 Z"/>
  <path d="M25 55 C23 53 23 50 25 48 C27 48 27 52 25 55 Z"/>
  <path d="M60 120 L58 125 L58 130 L57 135 L57 160 L58 185 L59 192 L61 195 L73 195 L75 192 L76 185 L77 160 L77 135 L76 130 L74 125 L72 120 Z"/>
  <path d="M58 120 L74 120 L75 115 L74 110 L72 108 L60 108 L58 110 L57 115 Z"/>
  <path d="M77 130 C82 130 85 134 85 140 C85 146 82 150 77 150 L77 146 C80 146 82 143 82 140 C82 137 80 134 77 134 Z"/>
  <path d="M5 195 L95 195 L95 200 L5 200 Z"/>
  <path d="M45 180 C42 178 40 180 40 184 C40 188 43 191 46 191 C49 191 50 188 50 184 C50 181 48 179 45 180 Z M46 178 L47 174 L46 170"/>
</svg>''';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/templates/builtin_silhouettes_test.dart`
Expected: PASS — all 4 test cases pass.

- [ ] **Step 5: Update `template_mapper.dart` — fix whitelist source**

In `lib/features/templates/services/template_mapper.dart`:

1. Add import at top (after line 3):
```dart
import '../data/builtin_silhouettes.dart';
```

2. Replace `_degradeSilhouetteIfNeeded` method (lines 553-574) with:
```dart
  /// 内置剪影 key 不存在于白名单时降级为 'none'
  /// 白名单来源：BuiltinSilhouettes.keys（真实剪影库 12 key）
  static Map<String, dynamic> _degradeSilhouetteIfNeeded(
      Map<String, dynamic> pose) {
    final silhouette = pose['silhouette'];
    if (silhouette is! Map<String, dynamic>) return pose;
    if (silhouette['type'] != 'builtin') return pose;

    final key = silhouette['data'] as String?;
    if (key == null || key == 'none') return pose;
    if (!kBuiltinSilhouetteKeys.contains(key)) {
      // ignore: avoid_print
      print('Warning: builtin silhouette key "$key" not found in library, '
          'degrading to "none"');
      return {
        ...pose,
        'silhouette': {'type': 'builtin', 'data': 'none'},
      };
    }
    return pose;
  }
```

- [ ] **Step 6: Update `templates_editor_page.dart` — fix silhouette picker source**

In `lib/features/templates/pages/templates_editor_page.dart`:

1. Add import (near other imports of data files):
```dart
import '../data/builtin_silhouettes.dart';
```

2. Replace line 1538 `itemCount: TemplatesEditorMockData.builtinSilhouetteKeys.length,` with:
```dart
        itemCount: kBuiltinSilhouetteKeys.length + 1, // +1 for 'none' at front
```

3. Replace lines 1540-1541 `final key = TemplatesEditorMockData.builtinSilhouetteKeys[index];` with:
```dart
          final key = index == 0 ? 'none' : kBuiltinSilhouetteKeys[index - 1];
```

- [ ] **Step 7: Remove mock silhouette data from `templates_editor_mock_data.dart`**

In `lib/features/templates/data/templates_editor_mock_data.dart`, delete lines 389-410 (the `builtinSilhouetteKeys` and `builtinSilhouettes` static members and their comments).

- [ ] **Step 8: Run all existing tests to verify no regressions**

Run: `flutter test test/template_import_test.dart test/template_mapper_test.dart`
Expected: PASS — existing tests still pass. The `standing-profile` key was in the old 5-key mock and is in the new 12-key list, so the existing test case still passes.

- [ ] **Step 9: Run the import test to verify neon-pose is NOT degraded**

Add a quick verification test to `test/template_import_test.dart` (inside the existing `pptpl 格式` group, after the "剪影 builtin key 不存在时应降级为 none" test):

```dart
    test('剪影 builtin key 存在于完整库时应保留（不降级）', () {
      final json = <String, dynamic>{
        'format': 'pptpl',
        'version': '1.0',
        'meta': {
          'id': 'tpl-neon-pose',
          'name': '霓虹剪影',
          'category': 'portrait',
        },
        'composition': {'overlayType': 'rule_of_thirds'},
        'pose': {
          'silhouette': {
            'type': 'builtin',
            'data': 'neon-pose',
          },
        },
        'camera': <String, dynamic>{},
        'sceneGuide': <String, dynamic>{},
        'postProcess': <String, dynamic>{},
      };

      final record = TemplateMapper.recordFromImportedJson(
        json,
        createdAt: 1700000000000,
      );

      expect(record.pose['silhouette']['type'], 'builtin');
      expect(record.pose['silhouette']['data'], 'neon-pose');
    });
```

Run: `flutter test test/template_import_test.dart`
Expected: PASS

- [ ] **Step 10: Commit**

```bash
cd lumira_app_flutter && git add lib/features/templates/data/builtin_silhouettes.dart lib/features/templates/services/template_mapper.dart lib/features/templates/data/templates_editor_mock_data.dart lib/features/templates/pages/templates_editor_page.dart test/features/templates/builtin_silhouettes_test.dart test/template_import_test.dart && git commit -m "fix: migrate real silhouette library from Vue, fix import degradation whitelist"
```

---

### Task 2: Add `coverData` Field to Domain + DAO + DB Schema

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/domain/photo_template.dart` (TemplateMeta class, lines 57-135)
- Modify: `lumira_app_flutter/lib/core/db/dao/templates_dao.dart` (TemplateRecord class, lines 9-122)
- Modify: `lumira_app_flutter/lib/core/db/tables.dart` (add constant after line 19)
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart` (v11 migration, after line 482)
- Modify: `lumira_app_flutter/lib/features/templates/services/template_mapper.dart` (toRecord/toPhotoTemplate, lines 18-80)

**Interfaces:**
- Produces: `TemplateMeta.coverData` (`String?`), `TemplateRecord.coverData` (`String?`), `Tables.colCoverData` (`'cover_data'`)

- [ ] **Step 1: Write the failing test**

Add to `test/template_import_test.dart` (new group at end of `main()`):

```dart
  group('TemplateRecord coverData', () {
    test('toRow/fromRow round-trips coverData', () {
      final db = await openDatabase(inMemoryDatabasePath, version: 1,
          onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE ${Tables.customTemplates} (
            ${Tables.colId} TEXT PRIMARY KEY,
            ${Tables.colName} TEXT NOT NULL,
            ${Tables.colAuthor} TEXT NOT NULL DEFAULT '',
            ${Tables.colVersion} TEXT NOT NULL DEFAULT '1.0.0',
            ${Tables.colCategory} TEXT NOT NULL,
            ${Tables.colClassificationJson} TEXT NOT NULL DEFAULT '{}',
            ${Tables.colTagsJson} TEXT NOT NULL DEFAULT '[]',
            ${Tables.colTagIdsJson} TEXT NOT NULL DEFAULT '[]',
            ${Tables.colPrice} INTEGER NOT NULL DEFAULT 0,
            ${Tables.colCover} TEXT NOT NULL DEFAULT '',
            ${Tables.colCoverData} TEXT,
            ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
            ${Tables.colReferenceSource} TEXT NOT NULL DEFAULT '',
            ${Tables.colCompositionJson} TEXT NOT NULL DEFAULT '{}',
            ${Tables.colPoseJson} TEXT NOT NULL DEFAULT '{}',
            ${Tables.colCameraJson} TEXT NOT NULL DEFAULT '{}',
            ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
            ${Tables.colPostProcessJson} TEXT NOT NULL DEFAULT '{}',
            ${Tables.colIsBuiltin} INTEGER NOT NULL DEFAULT 0,
            ${Tables.colIsRecommended} INTEGER NOT NULL DEFAULT 0,
            ${Tables.colCreatedAt} INTEGER NOT NULL,
            ${Tables.colUpdatedAt} INTEGER NOT NULL
          )
        ''');
      });

      final record = TemplateRecord(
        id: 'test-cover',
        name: '测试',
        author: '',
        version: '1.0.0',
        category: 'portrait',
        classification: {},
        tags: [],
        tagIds: [],
        price: 0,
        cover: 'assets/images/templates/test.jpg',
        coverData: 'data:image/jpeg;base64,abc123',
        description: '',
        referenceSource: '',
        composition: {},
        pose: {},
        camera: {},
        sceneGuide: {},
        postProcess: {},
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
        isBuiltin: false,
        isRecommended: false,
      );

      await db.insert(Tables.customTemplates, record.toRow());
      final rows = await db.query(Tables.customTemplates);
      final restored = TemplateRecord.fromRow(rows.first);

      expect(restored.coverData, 'data:image/jpeg;base64,abc123');
      await db.close();
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/template_import_test.dart --plain-name "toRow/fromRow round-trips coverData"`
Expected: FAIL — `Tables.colCoverData` and `TemplateRecord.coverData` don't exist yet.

- [ ] **Step 3: Add `colCoverData` to `tables.dart`**

In `lib/core/db/tables.dart`, after line 19 (`static const String colCover = 'cover';`), add:

```dart
  static const String colCoverData = 'cover_data';
```

- [ ] **Step 4: Add `coverData` to `TemplateRecord`**

In `lib/core/db/dao/templates_dao.dart`:

1. Add field after line 19 (`final String cover;`):
```dart
  final String? coverData;
```

2. Add to constructor (after `required this.cover,` on line 41):
```dart
    this.coverData,
```

3. Add to `toRow()` (after `Tables.colCover: cover,` on line 67):
```dart
      Tables.colCoverData: coverData,
```

4. Add to `fromRow()` (after `cover: (row[Tables.colCover] as String?) ?? '',` on line 94):
```dart
      coverData: row[Tables.colCoverData] as String?,
```

- [ ] **Step 5: Add `coverData` to `TemplateMeta`**

In `lib/features/capture/domain/photo_template.dart`:

1. Add field after line 68 (`final String cover;`):
```dart
  final String? coverData;
```

2. Add to constructor (after `this.cover = '',` on line 82):
```dart
    this.coverData,
```

3. Add to `copyWith` (after `String? cover,` on line 97):
```dart
    Object? coverData = _unset,
```
And in the body (after `cover: cover ?? this.cover,` on line 110):
```dart
        coverData: identical(coverData, _unset)
            ? this.coverData
            : coverData as String?,
```

4. Add to `==` (after `cover == other.cover &&` on line 129):
```dart
          coverData == other.coverData &&
```

5. Add to `hashCode` (after `cover,` in the `Object.hash` call on line 133-134):
```dart
      coverData,
```

- [ ] **Step 6: Update `TemplateMapper.toRecord` and `toPhotoTemplate`**

In `lib/features/templates/services/template_mapper.dart`:

1. In `toRecord` (after line 38 `cover: tpl.meta.cover,`):
```dart
      coverData: tpl.meta.coverData,
```

2. In `toPhotoTemplate` (after line 71 `cover: r.cover,`):
```dart
        coverData: r.coverData,
```

- [ ] **Step 7: Add v11 DB migration**

In `lib/core/db/database_provider.dart`:

1. Change line 19: `const int _kDbVersion = 10;` → `const int _kDbVersion = 11;`

2. After the `if (oldVersion < 10) { ... }` block (after line 483), add:
```dart
  if (oldVersion < 11) {
    try {
      // v11: 新增 cover_data 列（.pptpl 自包含封面嵌入）
      await _addColumnIfNotExists(
        db,
        Tables.customTemplates,
        Tables.colCoverData,
        'TEXT',
      );
    } catch (e) {
      debugPrint('v11 migration failed (silent fallback): $e');
    }
  }
```

3. In `_onCreate`, add `cover_data` column to the `custom_templates` CREATE TABLE (after `${Tables.colCover} TEXT NOT NULL DEFAULT '',` on line 96):
```dart
      ${Tables.colCoverData} TEXT,
```

- [ ] **Step 8: Run test to verify it passes**

Run: `flutter test test/template_import_test.dart --plain-name "toRow/fromRow round-trips coverData"`
Expected: PASS

- [ ] **Step 9: Run all tests to verify no regressions**

Run: `flutter test`
Expected: PASS — `coverData` is nullable with no default, so existing code creating `TemplateRecord` without it still compiles (it's optional in constructor).

- [ ] **Step 10: Commit**

```bash
cd lumira_app_flutter && git add lib/features/capture/domain/photo_template.dart lib/core/db/dao/templates_dao.dart lib/core/db/tables.dart lib/core/db/database_provider.dart lib/features/templates/services/template_mapper.dart test/template_import_test.dart && git commit -m "feat: add coverData field to TemplateMeta and TemplateRecord for .pptpl self-containment"
```

---

### Task 3: Fix 12 Template Cover Paths + DB Reseed

**Files:**
- Modify: 12 template `.dart` files in `lumira_app_flutter/lib/features/capture/data/templates/`
- Modify: `lumira_app_flutter/lib/core/db/seeders/builtin_data_seeder.dart` (add `reseedBuiltinCovers`)
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart` (v11 migration — add reseed call)

**Interfaces:**
- Produces: `BuiltinDataSeeder.reseedBuiltinCovers(Database db)` — updates 12 builtin template cover paths in DB

- [ ] **Step 1: Write the failing test**

Add to `test/template_import_test.dart` (new group):

```dart
  group('Builtin template cover paths', () {
    test('12 original templates use local asset paths, not picsum URLs', () {
      // 验证导入的模板常量 cover 字段不含 picsum.photos
      // 此测试导入 12 个原始模板文件并检查 cover 字段
      const templates = [
        // (imported individually below — see Step 3 for actual import statements)
      ];
      expect(templates, isEmpty); // placeholder; real check in Step 3
    });
  });
```

Actually, a simpler approach — test the seeder method directly:

Create `test/features/templates/cover_reseed_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/seeders/builtin_data_seeder.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('reseedBuiltinCovers updates 12 builtin covers from picsum to asset paths', () async {
    final db = await openDatabase(inMemoryDatabasePath, version: 1,
        onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE ${Tables.customTemplates} (
          ${Tables.colId} TEXT PRIMARY KEY,
          ${Tables.colName} TEXT NOT NULL,
          ${Tables.colAuthor} TEXT NOT NULL DEFAULT '',
          ${Tables.colVersion} TEXT NOT NULL DEFAULT '1.0.0',
          ${Tables.colCategory} TEXT NOT NULL,
          ${Tables.colClassificationJson} TEXT NOT NULL DEFAULT '{}',
          ${Tables.colTagsJson} TEXT NOT NULL DEFAULT '[]',
          ${Tables.colTagIdsJson} TEXT NOT NULL DEFAULT '[]',
          ${Tables.colPrice} INTEGER NOT NULL DEFAULT 0,
          ${Tables.colCover} TEXT NOT NULL DEFAULT '',
          ${Tables.colCoverData} TEXT,
          ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
          ${Tables.colReferenceSource} TEXT NOT NULL DEFAULT '',
          ${Tables.colCompositionJson} TEXT NOT NULL DEFAULT '{}',
          ${Tables.colPoseJson} TEXT NOT NULL DEFAULT '{}',
          ${Tables.colCameraJson} TEXT NOT NULL DEFAULT '{}',
          ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
          ${Tables.colPostProcessJson} TEXT NOT NULL DEFAULT '{}',
          ${Tables.colIsBuiltin} INTEGER NOT NULL DEFAULT 0,
          ${Tables.colIsRecommended} INTEGER NOT NULL DEFAULT 0,
          ${Tables.colCreatedAt} INTEGER NOT NULL,
          ${Tables.colUpdatedAt} INTEGER NOT NULL
        )
      ''');
    });

    // Insert a builtin template with old picsum URL
    await db.insert(Tables.customTemplates, {
      Tables.colId: 'cafe_portrait',
      Tables.colName: '咖啡馆人像',
      Tables.colCategory: 'portrait',
      Tables.colCover: 'https://picsum.photos/seed/template-cafe-portrait/400/600',
      Tables.colIsBuiltin: 1,
      Tables.colCreatedAt: 1700000000000,
      Tables.colUpdatedAt: 1700000000000,
    });

    await BuiltinDataSeeder.reseedBuiltinCovers(db);

    final rows = await db.query(Tables.customTemplates,
        where: '${Tables.colId} = ?', whereArgs: ['cafe_portrait']);
    expect(rows, isNotEmpty);
    expect(rows.first[Tables.colCover], 'assets/images/templates/cafe_portrait.jpg');
    await db.close();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/templates/cover_reseed_test.dart`
Expected: FAIL — `BuiltinDataSeeder.reseedBuiltinCovers` doesn't exist.

- [ ] **Step 3: Update 12 template `.dart` files — replace picsum URLs with asset paths**

For each of these 12 files in `lib/features/capture/data/templates/`, replace the `cover:` value:

| File | Old value | New value |
|---|---|---|
| `cafe_portrait.dart` | `'https://picsum.photos/seed/template-cafe-portrait/400/600'` | `'assets/images/templates/cafe_portrait.jpg'` |
| `film_vintage.dart` | `'https://picsum.photos/seed/template-film-vintage/400/600'` | `'assets/images/templates/film_vintage.jpg'` |
| `food_flat_lay.dart` | `'https://picsum.photos/seed/template-food-flat-lay/400/600'` | `'assets/images/templates/food_flat_lay.jpg'` |
| `golden_landscape.dart` | `'https://picsum.photos/seed/template-golden-landscape/400/600'` | `'assets/images/templates/golden_landscape.jpg'` |
| `indoor_still_life.dart` | `'https://picsum.photos/seed/template-indoor-still-life/400/600'` | `'assets/images/templates/indoor_still_life.jpg'` |
| `macro_flower.dart` | `'https://picsum.photos/seed/template-macro-flower/400/600'` | `'assets/images/templates/macro_flower.jpg'` |
| `neon_portrait.dart` | `'https://picsum.photos/seed/template-neon-portrait/400/600'` | `'assets/images/templates/neon_portrait.jpg'` |
| `night_cityscape.dart` | `'https://picsum.photos/seed/template-night-cityscape/400/600'` | `'assets/images/templates/night_cityscape.jpg'` |
| `soft_portrait.dart` | `'https://picsum.photos/seed/template-soft-portrait/400/600'` | `'assets/images/templates/soft_portrait.jpg'` |
| `street_bw.dart` | `'https://picsum.photos/seed/template-street-bw/400/600'` | `'assets/images/templates/street_bw.jpg'` |
| `sunset_silhouette.dart` | `'https://picsum.photos/seed/template-sunset-silhouette/400/600'` | `'assets/images/templates/sunset_silhouette.jpg'` |
| `urban_architecture.dart` | `'https://picsum.photos/seed/template-urban-architecture/400/600'` | `'assets/images/templates/urban_architecture.jpg'` |

Use `Edit` tool for each file, replacing the old `cover:` string with the new one.

- [ ] **Step 4: Add `reseedBuiltinCovers` to seeder**

In `lib/core/db/seeders/builtin_data_seeder.dart`, after `reseedBuiltinTemplates` method (after line 82), add:

```dart
  /// 仅更新内置模板的 cover 字段（v11 迁移用）。
  ///
  /// 修复：12 款原始模板的 cover 从 picsum URL 改为本地 asset 路径。
  /// 不删除/重建记录，仅 UPDATE cover 字段，保留用户可能的 is_favorite 等状态。
  static Future<void> reseedBuiltinCovers(Database db) async {
    final templates = TemplateRegistry.allTemplates;
    final batch = db.batch();
    for (final t in templates) {
      batch.update(
        Tables.customTemplates,
        {Tables.colCover: t.meta.cover},
        where: '${Tables.colId} = ? AND ${Tables.colIsBuiltin} = ?',
        whereArgs: [t.meta.id, 1],
      );
    }
    await batch.commit(noResult: true);
  }
```

- [ ] **Step 5: Add reseed call to v11 migration**

In `lib/core/db/database_provider.dart`, in the `if (oldVersion < 11)` block (from Task 2 Step 7), after the `_addColumnIfNotExists` call, add:

```dart
      // v11: 修复 12 款原始模板的 cover 路径（picsum URL → 本地 asset）
      await BuiltinDataSeeder.reseedBuiltinCovers(db);
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/templates/cover_reseed_test.dart`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
cd lumira_app_flutter && git add lib/features/capture/data/templates/cafe_portrait.dart lib/features/capture/data/templates/film_vintage.dart lib/features/capture/data/templates/food_flat_lay.dart lib/features/capture/data/templates/golden_landscape.dart lib/features/capture/data/templates/indoor_still_life.dart lib/features/capture/data/templates/macro_flower.dart lib/features/capture/data/templates/neon_portrait.dart lib/features/capture/data/templates/night_cityscape.dart lib/features/capture/data/templates/soft_portrait.dart lib/features/capture/data/templates/street_bw.dart lib/features/capture/data/templates/sunset_silhouette.dart lib/features/capture/data/templates/urban_architecture.dart lib/core/db/seeders/builtin_data_seeder.dart lib/core/db/database_provider.dart test/features/templates/cover_reseed_test.dart && git commit -m "fix: replace picsum URLs with local asset paths for 12 original template covers"
```

---

### Task 4: Cover Embedding in Export

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/services/template_exporter.dart`
- Modify: `lumira_app_flutter/test/template_exporter_test.dart`

**Interfaces:**
- Produces: `TemplateExporter.embedCoverData(record, {assetLoader})` — async, returns `TemplateRecord` with `coverData` populated; `resolveCoverUrl(record)` — sync, returns the display URL

- [ ] **Step 1: Write the failing test**

Add to `test/template_exporter_test.dart`:

```dart
import 'dart:typed_data';
import 'dart:convert';

// ... existing code ...

void main() {
  // ... existing groups ...

  group('TemplateExporter.embedCoverData', () {
    test('data: URL cover is copied directly to coverData', () async {
      final record = _makeRecord().copyWith(
        cover: 'data:image/jpeg;base64,abc123',
      );
      final result = await TemplateExporter.embedCoverData(record);
      expect(result.coverData, 'data:image/jpeg;base64,abc123');
    });

    test('http URL cover leaves coverData null (offline app)', () async {
      final record = _makeRecord().copyWith(
        cover: 'https://picsum.photos/seed/test/400/600',
      );
      final result = await TemplateExporter.embedCoverData(record);
      expect(result.coverData, isNull);
    });

    test('empty cover leaves coverData null', () async {
      final record = _makeRecord(); // cover = ''
      final result = await TemplateExporter.embedCoverData(record);
      expect(result.coverData, isNull);
    });

    test('asset path cover loads bytes and encodes to base64 data URL', () async {
      final record = _makeRecord().copyWith(
        cover: 'assets/images/templates/cafe_portrait.jpg',
      );
      final fakeBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]); // JPEG magic bytes
      final result = await TemplateExporter.embedCoverData(
        record,
        assetLoader: (_) async => fakeBytes,
      );
      expect(result.coverData, isNotNull);
      expect(result.coverData!, startsWith('data:image/jpeg;base64,'));
    });

    test('coverData exceeding 500KB is skipped', () async {
      final record = _makeRecord().copyWith(
        cover: 'assets/images/templates/huge.jpg',
      );
      final hugeBytes = Uint8List(600 * 1024); // 600KB > 500KB limit
      final result = await TemplateExporter.embedCoverData(
        record,
        assetLoader: (_) async => hugeBytes,
      );
      expect(result.coverData, isNull);
    });
  });

  group('TemplateExporter.exportToPptpl with coverData', () {
    test('meta includes coverData when record has it', () {
      final record = _makeRecord().copyWith(
        coverData: 'data:image/jpeg;base64,abc123',
      );
      final json = TemplateExporter.exportToPptpl(record);
      final data = jsonDecode(json) as Map<String, dynamic>;
      expect(data['meta']['coverData'], 'data:image/jpeg;base64,abc123');
    });

    test('meta omits coverData when null', () {
      final record = _makeRecord(); // coverData = null
      final json = TemplateExporter.exportToPptpl(record);
      final data = jsonDecode(json) as Map<String, dynamic>;
      expect(data['meta'].containsKey('coverData'), isFalse);
    });
  });

  group('resolveCoverUrl', () {
    test('returns coverData when present', () {
      final record = _makeRecord().copyWith(
        cover: 'assets/images/templates/test.jpg',
        coverData: 'data:image/jpeg;base64,abc',
      );
      expect(TemplateExporter.resolveCoverUrl(record), 'data:image/jpeg;base64,abc');
    });

    test('returns cover when coverData is null', () {
      final record = _makeRecord().copyWith(
        cover: 'assets/images/templates/test.jpg',
      );
      expect(TemplateExporter.resolveCoverUrl(record), 'assets/images/templates/test.jpg');
    });
  });
}
```

Note: The `_makeRecord()` helper needs a `coverData` field. Since Task 2 added `coverData` as an optional constructor parameter, `_makeRecord()` already compiles (coverData defaults to null). The `.copyWith()` on `TemplateRecord` needs to be added — see Step 3.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/template_exporter_test.dart`
Expected: FAIL — `TemplateExporter.embedCoverData` and `TemplateExporter.resolveCoverUrl` don't exist.

- [ ] **Step 3: Add `copyWith` to `TemplateRecord`**

In `lib/core/db/dao/templates_dao.dart`, add this method to the `TemplateRecord` class (after `fromRow`, before the private helpers):

```dart
  TemplateRecord copyWith({
    String? id,
    String? name,
    String? author,
    String? version,
    String? category,
    Map<String, dynamic>? classification,
    List<String>? tags,
    List<String>? tagIds,
    int? price,
    String? cover,
    String? coverData,
    String? description,
    String? referenceSource,
    Map<String, dynamic>? composition,
    Map<String, dynamic>? pose,
    Map<String, dynamic>? camera,
    Map<String, dynamic>? sceneGuide,
    Map<String, dynamic>? postProcess,
    int? createdAt,
    int? updatedAt,
    bool? isBuiltin,
    bool? isRecommended,
  }) {
    return TemplateRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      author: author ?? this.author,
      version: version ?? this.version,
      category: category ?? this.category,
      classification: classification ?? this.classification,
      tags: tags ?? this.tags,
      tagIds: tagIds ?? this.tagIds,
      price: price ?? this.price,
      cover: cover ?? this.cover,
      coverData: coverData ?? this.coverData,
      description: description ?? this.description,
      referenceSource: referenceSource ?? this.referenceSource,
      composition: composition ?? this.composition,
      pose: pose ?? this.pose,
      camera: camera ?? this.camera,
      sceneGuide: sceneGuide ?? this.sceneGuide,
      postProcess: postProcess ?? this.postProcess,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      isRecommended: isRecommended ?? this.isRecommended,
    );
  }
```

- [ ] **Step 4: Add `embedCoverData` and `resolveCoverUrl` to exporter**

In `lib/features/templates/services/template_exporter.dart`:

1. Add imports at top (after existing imports):
```dart
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
```

2. Add the asset loader typedef and methods inside the `TemplateExporter` class (after `exportToLumira`, before `shareTemplate`):

```dart
  /// Asset 加载函数类型（便于测试注入）
  typedef AssetLoader = Future<Uint8List> Function(String assetPath);

  /// 嵌入封面图数据到 record.coverData（base64 data URL）。
  ///
  /// 策略：
  /// - cover 以 `data:` 开头 → 直接复制
  /// - cover 以 `assets/` 开头 → 通过 rootBundle 加载字节，base64 编码
  /// - cover 以 `http` 开头 → 离线 App 无法 fetch，跳过
  /// - cover 为空 → 跳过
  /// - 编码后超过 500KB → 跳过（避免膨胀 .pptpl）
  static Future<TemplateRecord> embedCoverData(
    TemplateRecord record, {
    AssetLoader? assetLoader,
  }) async {
    final cover = record.cover;
    if (cover.isEmpty) return record;

    // 已是 data URL → 直接复制
    if (cover.startsWith('data:')) {
      return record.copyWith(coverData: cover);
    }

    // HTTP URL → 离线 App 无法 fetch
    if (cover.startsWith('http://') || cover.startsWith('https://')) {
      return record;
    }

    // Asset 路径 → 加载字节
    if (cover.startsWith('assets/')) {
      try {
        final loader = assetLoader ?? _defaultAssetLoader;
        final bytes = await loader(cover);
        // 大小守卫：500KB
        if (bytes.lengthInBytes > 500 * 1024) {
          // ignore: avoid_print
          print('Warning: cover asset "$cover" exceeds 500KB, skipping embed');
          return record;
        }
        final mime = _mimeFromPath(cover);
        final base64Str = base64Encode(bytes);
        return record.copyWith(coverData: 'data:$mime;base64,$base64Str');
      } catch (e) {
        // ignore: avoid_print
        print('Warning: failed to load cover asset "$cover": $e');
        return record;
      }
    }

    return record;
  }

  /// 默认 asset 加载器（使用 rootBundle）
  static Future<Uint8List> _defaultAssetLoader(String path) async {
    final byteData = await rootBundle.load(path);
    return byteData.buffer.asUint8List();
  }

  /// 根据文件扩展名推断 MIME 类型
  static String _mimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg'; // 默认
  }

  /// 解析封面显示 URL：coverData 优先，否则 cover
  static String resolveCoverUrl(TemplateRecord record) {
    return record.coverData ?? record.cover;
  }
```

- [ ] **Step 5: Update `exportToPptpl` to include `coverData`**

In `lib/features/templates/services/template_exporter.dart`, in the `exportToPptpl` method, after the `'cover': record.cover,` line (line 33), add:

```dart
        if (record.coverData != null) 'coverData': record.coverData,
```

- [ ] **Step 6: Update `shareTemplate` to call `embedCoverData`**

In the same file, update `shareTemplate` (line 76-88). Change:
```dart
  static Future<void> shareTemplate(TemplateRecord record, {required bool usePptpl}) async {
    final json = usePptpl ? exportToPptpl(record) : exportToLumira(record);
```
to:
```dart
  static Future<void> shareTemplate(TemplateRecord record, {required bool usePptpl}) async {
    // .pptpl 导出时嵌入封面图（自包含）
    final recordWithCover = usePptpl ? await embedCoverData(record) : record;
    final json = usePptpl ? exportToPptpl(recordWithCover) : exportToLumira(recordWithCover);
```

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/template_exporter_test.dart`
Expected: PASS — all new and existing test cases pass.

- [ ] **Step 8: Commit**

```bash
cd lumira_app_flutter && git add lib/features/templates/services/template_exporter.dart lib/core/db/dao/templates_dao.dart test/template_exporter_test.dart && git commit -m "feat: embed cover image as base64 in .pptpl export for self-containment"
```

---

### Task 5: Cover Resolution in Import

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/services/template_mapper.dart` (`recordFromImportedJson`, lines 441-520)
- Modify: `lumira_app_flutter/test/template_import_test.dart`

**Interfaces:**
- Produces: `recordFromImportedJson` now reads `meta.coverData` into `TemplateRecord.coverData`

- [ ] **Step 1: Write the failing test**

Add to `test/template_import_test.dart` (new group):

```dart
  group('TemplateMapper.recordFromImportedJson — coverData', () {
    test('coverData field is read into record', () {
      final json = <String, dynamic>{
        'format': 'pptpl',
        'version': '1.0',
        'meta': {
          'id': 'tpl-with-cover',
          'name': '带封面',
          'category': 'portrait',
          'cover': 'assets/images/templates/test.jpg',
          'coverData': 'data:image/jpeg;base64,abc123',
        },
        'composition': {'overlayType': 'rule_of_thirds'},
        'pose': <String, dynamic>{},
        'camera': <String, dynamic>{},
        'sceneGuide': <String, dynamic>{},
        'postProcess': <String, dynamic>{},
      };

      final record = TemplateMapper.recordFromImportedJson(
        json,
        createdAt: 1700000000000,
      );

      expect(record.cover, 'assets/images/templates/test.jpg');
      expect(record.coverData, 'data:image/jpeg;base64,abc123');
    });

    test('cover as data: URL is migrated to coverData', () {
      final json = <String, dynamic>{
        'format': 'pptpl',
        'version': '1.0',
        'meta': {
          'id': 'tpl-data-url',
          'name': 'dataURL封面',
          'category': 'portrait',
          'cover': 'data:image/png;base64,xyz789',
        },
        'composition': {'overlayType': 'center'},
        'pose': <String, dynamic>{},
        'camera': <String, dynamic>{},
        'sceneGuide': <String, dynamic>{},
        'postProcess': <String, dynamic>{},
      };

      final record = TemplateMapper.recordFromImportedJson(
        json,
        createdAt: 1700000000000,
      );

      expect(record.coverData, 'data:image/png;base64,xyz789');
    });

    test('cover as asset path leaves coverData null', () {
      final json = <String, dynamic>{
        'format': 'pptpl',
        'version': '1.0',
        'meta': {
          'id': 'tpl-asset-cover',
          'name': 'asset封面',
          'category': 'portrait',
          'cover': 'assets/images/templates/test.jpg',
        },
        'composition': {'overlayType': 'center'},
        'pose': <String, dynamic>{},
        'camera': <String, dynamic>{},
        'sceneGuide': <String, dynamic>{},
        'postProcess': <String, dynamic>{},
      };

      final record = TemplateMapper.recordFromImportedJson(
        json,
        createdAt: 1700000000000,
      );

      expect(record.cover, 'assets/images/templates/test.jpg');
      expect(record.coverData, isNull);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/template_import_test.dart --plain-name "coverData field is read into record"`
Expected: FAIL — `record.coverData` is null because `recordFromImportedJson` doesn't read it.

- [ ] **Step 3: Update `recordFromImportedJson` to read `coverData`**

In `lib/features/templates/services/template_mapper.dart`, in `recordFromImportedJson`:

1. After line 455 (`final cover = (meta['cover'] as String?) ?? '';`), add:
```dart
    final coverData = (meta['coverData'] as String?) ??
        (cover.startsWith('data:') ? cover : null);
```

2. In the `TemplateRecord` constructor call (after line 507 `cover: cover,`), add:
```dart
      coverData: coverData,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/template_import_test.dart --plain-name "coverData"`
Expected: PASS — all 3 coverData test cases pass.

- [ ] **Step 5: Commit**

```bash
cd lumira_app_flutter && git add lib/features/templates/services/template_mapper.dart test/template_import_test.dart && git commit -m "feat: read coverData from imported .pptpl, migrate data: URL covers"
```

---

### Task 6: Version Compatibility Check

**Files:**
- Create: `lumira_app_flutter/lib/features/templates/services/pptpl_format.dart`
- Modify: `lumira_app_flutter/test/template_import_test.dart`

**Interfaces:**
- Produces: `PptplFormat.currentVersion` (`String`), `PptplFormat.supportedVersions` (`Set<String>`), `TemplateImportWarning` (enum), `PptplFormat.validate(Map<String, dynamic> json)` → `List<TemplateImportWarning>`

- [ ] **Step 1: Write the failing test**

Add to `test/template_import_test.dart` (new group):

```dart
  group('PptplFormat.validate', () {
    test('version 1.0 returns no warnings', () {
      final json = <String, dynamic>{
        'format': 'pptpl',
        'version': '1.0',
        'meta': {'id': 'test', 'name': 'test'},
      };
      final warnings = PptplFormat.validate(json);
      expect(warnings, isEmpty);
    });

    test('missing version returns legacyFormat warning', () {
      final json = <String, dynamic>{
        'meta': {'id': 'test', 'name': 'test'},
      };
      final warnings = PptplFormat.validate(json);
      expect(warnings, contains(TemplateImportWarning.legacyFormat));
    });

    test('version 2.0 returns unsupportedVersion warning', () {
      final json = <String, dynamic>{
        'format': 'pptpl',
        'version': '2.0',
        'meta': {'id': 'test', 'name': 'test'},
      };
      final warnings = PptplFormat.validate(json);
      expect(warnings, contains(TemplateImportWarning.unsupportedVersion));
    });

    test('unrecognized version returns unsupportedVersion warning', () {
      final json = <String, dynamic>{
        'format': 'pptpl',
        'version': '0.5-beta',
        'meta': {'id': 'test', 'name': 'test'},
      };
      final warnings = PptplFormat.validate(json);
      expect(warnings, contains(TemplateImportWarning.unsupportedVersion));
    });
  });
```

Also add the import at top of test file:
```dart
import 'package:lumira_app_flutter/features/templates/services/pptpl_format.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/template_import_test.dart --plain-name "PptplFormat.validate"`
Expected: FAIL — `PptplFormat` and `TemplateImportWarning` don't exist.

- [ ] **Step 3: Create `pptpl_format.dart`**

Create `lib/features/templates/services/pptpl_format.dart`:

```dart
/// .pptpl 格式版本常量与导入校验
///
/// 规范要求（AGENT.md §5）："离线版导入时做版本兼容性检查"
class PptplFormat {
  PptplFormat._();

  /// 当前格式版本
  static const String currentVersion = '1.0';

  /// 支持的格式版本集合
  static const Set<String> supportedVersions = {'1.0'};

  /// 校验导入的 JSON 格式版本，返回警告列表。
  ///
  /// - 无 `version` 字段 → [TemplateImportWarning.legacyFormat]
  /// - `version` 在 [supportedVersions] 中 → 无警告
  /// - `version` 不在支持列表 → [TemplateImportWarning.unsupportedVersion]
  ///
  /// 警告为非阻塞——调用方应继续 best-effort 解析（前向兼容）。
  static List<TemplateImportWarning> validate(Map<String, dynamic> json) {
    final warnings = <TemplateImportWarning>[];
    final version = json['version'] as String?;

    if (version == null) {
      warnings.add(TemplateImportWarning.legacyFormat);
    } else if (!supportedVersions.contains(version)) {
      warnings.add(TemplateImportWarning.unsupportedVersion);
    }

    return warnings;
  }
}

/// 模板导入警告类型
enum TemplateImportWarning {
  /// 旧版格式（无 version 字段）
  legacyFormat,

  /// 不支持的格式版本（可能不兼容）
  unsupportedVersion,
}

/// 模板导入结果
class TemplateImportResult {
  final bool success;
  final String? templateId;
  final String? errorMessage;
  final List<TemplateImportWarning> warnings;

  const TemplateImportResult({
    required this.success,
    this.templateId,
    this.errorMessage,
    this.warnings = const [],
  });

  bool get hasWarnings => warnings.isNotEmpty;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/template_import_test.dart --plain-name "PptplFormat.validate"`
Expected: PASS — all 4 test cases pass.

- [ ] **Step 5: Commit**

```bash
cd lumira_app_flutter && git add lib/features/templates/services/pptpl_format.dart test/template_import_test.dart && git commit -m "feat: add .pptpl format version validation on import"
```

---

### Task 7: Fix Export Filename Collision

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/services/template_exporter.dart` (`_sanitizeFileName` + `shareTemplate` + `saveToFile`)
- Modify: `lumira_app_flutter/test/template_exporter_test.dart`

**Interfaces:**
- Produces: `TemplateExporter.buildFileName(record, {required bool usePptpl})` — returns unique filename `{name}_{id}.{ext}`

- [ ] **Step 1: Write the failing test**

Add to `test/template_exporter_test.dart`:

```dart
  group('TemplateExporter.buildFileName', () {
    test('includes template ID for uniqueness', () {
      final record = _makeRecord(); // id='r1', name='测试模板'
      final filename = TemplateExporter.buildFileName(record, usePptpl: true);
      expect(filename, contains('r1'));
      expect(filename, contains('测试模板'));
      expect(filename, endsWith('.pptpl'));
    });

    test('lumira format uses .lumira extension', () {
      final record = _makeRecord();
      final filename = TemplateExporter.buildFileName(record, usePptpl: false);
      expect(filename, endsWith('.lumira'));
    });

    test('sanitizes illegal characters in name', () {
      final record = _makeRecord().copyWith(
        name: 'test/template:with*illegal',
        id: 'r2',
      );
      final filename = TemplateExporter.buildFileName(record, usePptpl: true);
      expect(filename, isNot(contains('/')));
      expect(filename, isNot(contains(':')));
      expect(filename, isNot(contains('*')));
      expect(filename, contains('r2'));
    });

    test('two templates with same name have different filenames', () {
      final r1 = _makeRecord().copyWith(name: 'same', id: 'id1');
      final r2 = _makeRecord().copyWith(name: 'same', id: 'id2');
      final f1 = TemplateExporter.buildFileName(r1, usePptpl: true);
      final f2 = TemplateExporter.buildFileName(r2, usePptpl: true);
      expect(f1, isNot(equals(f2)));
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/template_exporter_test.dart --plain-name "buildFileName"`
Expected: FAIL — `TemplateExporter.buildFileName` doesn't exist.

- [ ] **Step 3: Add `buildFileName` and update `shareTemplate`/`saveToFile`**

In `lib/features/templates/services/template_exporter.dart`:

1. Add `buildFileName` method (after `_sanitizeFileName`, before the closing brace of the class):

```dart
  /// 构建唯一文件名：`{sanitized_name}_{template_id}.{ext}`
  ///
  /// 模板 ID 在 DAO 中唯一，保证文件名不冲突。
  /// 名称截断至 30 字符，移除文件系统非法字符。
  static String buildFileName(TemplateRecord record, {required bool usePptpl}) {
    final ext = usePptpl ? 'pptpl' : 'lumira';
    final safeName = _sanitizeFileName(record.name);
    final trimmed = safeName.length > 30 ? safeName.substring(0, 30) : safeName;
    return '${trimmed}_${record.id}.$ext';
  }
```

2. Update `shareTemplate` — replace the filename construction. Change:
```dart
    final safeName = _sanitizeFileName(record.name);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/lumira_template_$safeName.$ext');
```
to:
```dart
    final fileName = buildFileName(record, usePptpl: usePptpl);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
```

3. Update `saveToFile` — same change. Replace:
```dart
    final safeName = _sanitizeFileName(record.name);
    final file = File('$dirPath/lumira_template_$safeName.$ext');
```
with:
```dart
    final fileName = buildFileName(record, usePptpl: usePptpl);
    final file = File('$dirPath/$fileName');
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/template_exporter_test.dart --plain-name "buildFileName"`
Expected: PASS — all 4 test cases pass.

- [ ] **Step 5: Commit**

```bash
cd lumira_app_flutter && git add lib/features/templates/services/template_exporter.dart test/template_exporter_test.dart && git commit -m "fix: include template ID in export filename to prevent collision"
```

---

### Task 8: Persist Link/QR Imports + Remove In-Memory Provider + Warning UI

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/widgets/template_import_sheet.dart`
- Modify: `lumira_app_flutter/lib/features/templates/pages/templates_all_page.dart`
- Delete: `lumira_app_flutter/lib/features/templates/data/imported_templates_provider.dart`

**Interfaces:**
- Consumes: `PptplFormat.validate` (from Task 6), `TemplateMapper.recordFromImportedJson` (from Task 5), `TemplateRecord.coverData` (from Task 2)
- Produces: All imports (file/link/QR) persist to DAO; version warnings shown via dialog

- [ ] **Step 1: Update `templates_all_page.dart` — remove `importedAllTemplatesProvider` dependency**

In `lib/features/templates/pages/templates_all_page.dart`:

1. Remove the import (line 14):
```dart
import '../data/imported_templates_provider.dart';
```

2. Replace line 164 `final importedAll = ref.watch(importedAllTemplatesProvider);` with:
```dart
    // 导入的模板现在持久化到 DAO，不再需要内存 provider
    final importedAll = <AllTemplateItem>[];
```

3. Search for any other usage of `importedAll` in the file and ensure it still compiles (it was a `List<AllTemplateItem>`, now it's an empty list — the merge logic should still work).

- [ ] **Step 2: Update `template_import_sheet.dart` — persist link/QR imports to DAO**

In `lib/features/templates/widgets/template_import_sheet.dart`:

1. Remove import (line 13):
```dart
import '../data/imported_templates_provider.dart';
```

2. Add imports:
```dart
import '../services/pptpl_format.dart';
import '../../capture/data/template_registry.dart';
```

3. Replace `_handleLinkImport` method (lines 193-234) with:

```dart
  // ===== 链接导入（DAO 持久化）=====
  Future<void> _handleLinkImport(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    navigator.pop(); // 先关闭 BottomSheet

    final url = await _showInputDialog(
      context: context,
      title: '从链接导入',
      hint: 'lumira://tpl/xxx 或 https://...',
      keyboardType: TextInputType.url,
    );

    if (url == null || url.trim().isEmpty) return;

    final parsed = _parseTemplateLink(url.trim());
    if (parsed == null) {
      _showToast(navigator, '链接格式无效，请输入有效的分享链接');
      return;
    }

    // 轻量形式（无完整 JSON）→ 不支持
    if (parsed['name'] is String && parsed['coverSeed'] is String? && !parsed.containsKey('meta')) {
      _showToast(navigator, '该分享链接不包含完整模板参数，请使用文件导入');
      return;
    }

    // 完整 JSON 形式 → 走 DAO 持久化
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final warnings = PptplFormat.validate(parsed);
      var record = TemplateMapper.recordFromImportedJson(
        parsed,
        createdAt: now,
      );

      final dao = await ref.read(templatesDaoProvider.future);
      var finalId = record.id;
      while (await dao.getById(finalId) != null) {
        finalId = '${finalId}_imported_$now';
      }
      if (finalId != record.id) {
        record = _copyRecordWithId(record, finalId);
      }

      await dao.upsert(record);

      _showToast(navigator, '已导入模板：${record.name}');
      if (warnings.isNotEmpty) {
        _showWarningsDialog(navigator, warnings);
      }
      onImported(record.id);
    } catch (e) {
      _showToast(navigator, '导入失败：$e');
    }
  }
```

4. Replace `_handleQrImport` method (lines 237-279) with:

```dart
  // ===== 扫码导入（DAO 持久化）=====
  Future<void> _handleQrImport(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    navigator.pop(); // 先关闭 BottomSheet

    final code = await _showInputDialog(
      context: context,
      title: '扫码导入',
      hint: '输入分享码（LUMIRA-分类-名称）',
      keyboardType: TextInputType.text,
    );

    if (code == null || code.trim().isEmpty) return;

    final parsed = _parseTemplateCode(code.trim());
    if (parsed == null) {
      _showToast(navigator, '分享码无效，请检查后重试');
      return;
    }

    try {
      final name = parsed['name'] as String;
      final category = parsed['category'] as String;
      final now = DateTime.now().millisecondsSinceEpoch;

      // 从内置模板取该 category 首个模板的参数作为默认值
      final builtinForCategory = TemplateRegistry.allTemplates
          .where((t) => t.meta.category == category)
          .toList();
      final defaultTpl = builtinForCategory.isNotEmpty
          ? builtinForCategory.first
          : TemplateRegistry.allTemplates.first;

      final record = TemplateMapper.toRecord(
        defaultTpl,
        createdAt: now,
        isBuiltin: false,
      ).copyWith(
        id: 'qr_${category}_${now}',
        name: name,
        category: category,
        cover: '',
        isBuiltin: false,
        isRecommended: false,
      );

      final dao = await ref.read(templatesDaoProvider.future);
      await dao.upsert(record);

      _showToast(navigator, '已导入模板：$name');
      onImported(record.id);
    } catch (e) {
      _showToast(navigator, '导入失败：$e');
    }
  }
```

5. Update `_handleFileImport` to show version warnings. After the `await dao.upsert(record);` line (around line 156), add:

```dart
      // 版本兼容性校验
      final warnings = PptplFormat.validate(parsed);
      if (warnings.isNotEmpty) {
        _showWarningsDialog(navigator, warnings);
      }
```

6. Add the `_showWarningsDialog` helper method (after `_showToast`):

```dart
  void _showWarningsDialog(NavigatorState navigator, List<TemplateImportWarning> warnings) {
    if (!navigator.context.mounted) return;
    final messages = warnings.map((w) {
      switch (w) {
        case TemplateImportWarning.legacyFormat:
          return '该模板为旧版格式，缺少版本信息，部分参数可能不兼容';
        case TemplateImportWarning.unsupportedVersion:
          return '该模板来自不支持的格式版本，部分参数可能不兼容';
      }
    }).join('\n');
    lumira.showLumiraDialog(
      context: navigator.context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('导入提示', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(messages, style: const TextStyle(fontSize: 14, height: 1.5)),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: lumira.LumiraButton(
              variant: ButtonVariant.primary,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('知道了'),
            ),
          ),
        ],
      ),
    );
  }
```

7. Update `_parseTemplateLink` to return the full JSON map for `lumira://tpl/` URLs (it already does this — the base64 decoded JSON is returned as `data`). But for the `https://lumira.app/tpl?name=xxx` form, ensure it returns a map WITH a `coverSeed` key but WITHOUT a `meta` key (so the check in Step 3 works). The current implementation already does this — the `https://` branch returns `{name, category, tags, coverSeed}` without `meta`. Good.

- [ ] **Step 3: Delete `imported_templates_provider.dart`**

Delete: `lib/features/templates/data/imported_templates_provider.dart`

- [ ] **Step 4: Verify no remaining references to deleted provider**

Run: `grep -r "imported_templates_provider\|importedTemplatesProvider\|importedAllTemplatesProvider\|importedCustomTemplatesProvider" lumira_app_flutter/lib/`

Expected: No matches (all references removed in Steps 1-2).

If any matches remain, update those files to remove the import and usage.

- [ ] **Step 5: Run all tests**

Run: `flutter test`
Expected: PASS — all tests pass, no compilation errors from deleted provider.

- [ ] **Step 6: Run analyzer**

Run: `flutter analyze lib/features/templates/ lib/features/profile/pages/profile_my_templates_page.dart`
Expected: No errors. (Warnings about unused imports are acceptable if they're from pre-existing code.)

- [ ] **Step 7: Commit**

```bash
cd lumira_app_flutter && git add lib/features/templates/widgets/template_import_sheet.dart lib/features/templates/pages/templates_all_page.dart && git rm lib/features/templates/data/imported_templates_provider.dart && git commit -m "fix: persist link/QR imports to DAO, remove in-memory provider, show version warnings"
```

---

## Self-Review Notes

**Spec coverage check:**
- B-1 (silhouette whitelist): Task 1 ✓
- B-2 (link/QR persistence): Task 8 ✓
- B-3 (filename collision): Task 7 ✓
- B-4 (picsum cover URLs): Task 3 ✓
- S-1 (cover embedding): Tasks 2, 4, 5 ✓
- S-2 (version check): Tasks 6, 8 ✓

**Type consistency check:**
- `coverData` is `String?` in both `TemplateMeta` and `TemplateRecord` — consistent
- `kBuiltinSilhouetteKeys` is `List<String>` — used consistently in mapper and editor page
- `PptplFormat.validate` returns `List<TemplateImportWarning>` — consumed by import sheet
- `TemplateImporter.buildFileName` uses `record.id` — available on all `TemplateRecord` instances
- `embedCoverData` returns `TemplateRecord` (not a new type) — `copyWith` added in Task 4 Step 3

**Ordering:**
- Task 1 (silhouette) is independent — no dependencies
- Task 2 (coverData field) is independent — no dependencies
- Task 3 (cover paths) depends on Task 2 for `colCoverData` in test DB schema, but the actual code changes (template .dart files + seeder) don't depend on Task 2
- Task 4 (cover embedding) depends on Task 2 (`coverData` field on `TemplateRecord`)
- Task 5 (cover import) depends on Task 2 (`coverData` field)
- Task 6 (version check) is independent — no dependencies
- Task 7 (filename) is independent — no dependencies
- Task 8 (persist + remove) depends on Tasks 5, 6 (uses `PptplFormat.validate` and `coverData` on records)
