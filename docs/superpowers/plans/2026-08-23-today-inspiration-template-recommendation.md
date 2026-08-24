# 今日灵感智能模板推荐 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 首页「今日灵感」在能推荐出合适模板时把按钮变为「用「模板名」拍摄」，点击直接带 `templateId` 进入拍摄页；推荐不出时维持原「开始拍摄」。

**Architecture:** 复用现有 `InspirationService`（已算当前语境 + 天气）与已落地的本地 `usage_stats`（全站火爆次数）。新增一条**纯函数**推荐链路（规则表 + ambience 匹配 + 热度排序），服务层只是组数据后调用它，便于 TDD；结果写入 `HeroInspiration` 可选字段，`HeroCard` 按钮据此切换文案与跳转。纯 Flutter 改动、无后端。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（无 records 语法）、flutter_riverpod、sqflite、go_router。

## Global Constraints

- Dart 2.19.6，**不支持 Dart 3 records 语法**；结构化返回值一律用类。
- 所有新增读取均为本地（`GalleryDao`/`TemplatesDao`/`UsageDao`），失败静默回落，不抛异常。
- 按钮无推荐时必须与现状完全一致（`开始拍摄` + `widget.onCapture()`）。
- 规则表沿用 `inspiration_rules.dart` 的令牌体系（slot∈morning/noon/dusk/night、season∈春季/…、tempRange∈炎热/温暖/…、weather∈晴/多云/…）。
- 复用已确认符号：`TemplatesDao.getBuiltinAndRemote()`、`UsageDao.countFor(id,'template','use_shoot')`、`RouteNames.capture`、`RouteNames.paramTemplateId`、`homeInspirationProvider`。
- 测试命令：`cd lumira_app_flutter && flutter test test/features/home/template_context_rules_test.dart`；全量 `flutter analyze`。

---

### Task 1: 纯推荐函数 `template_context_rules.dart` + 单元测试

**Files:**
- Create: `lumira_app_flutter/lib/features/home/data/template_context_rules.dart`
- Create: `lumira_app_flutter/test/features/home/template_context_rules_test.dart`
- Modify: `lumira_app_flutter/lib/features/home/data/inspiration_models.dart`（追加 `RecommendedTemplate`，本任务包含该类型定义）

**Interfaces:**
- Produces:
  - `class RecommendedTemplate { final String id; final String name; const RecommendedTemplate({required this.id, required this.name}); }`
  - `class ContextFit { final Set<String> styles; final Set<String> categories; const ContextFit({this.styles = const {}, this.categories = const {}}); bool get isEmpty; }`
  - `ContextFit resolveContextFit(InspirationContext c)`（取最高特异度单条规则）
  - `bool ambienceMatches(Map<String, dynamic> ambience, InspirationContext c)`
  - `class Candidate { final String id, name, category; final String? style, subStyle, type; final Map<String,dynamic> ambience; final int popularity; const Candidate({...}); }`
  - `RecommendedTemplate? pickRecommendedTemplate({required List<Candidate> candidates, required InspirationContext context, required String preferredCategory})`
  - Consumes: `InspirationContext`（来自 `inspiration_rules.dart`）

- [ ] **Step 1: 在 `inspiration_models.dart` 追加 `RecommendedTemplate` 类型（文件末尾）**

```dart
/// 今日灵感推荐出的模板（仅 id + 名称，用于 CTA 按钮）
class RecommendedTemplate {
  final String id;
  final String name;
  const RecommendedTemplate({required this.id, required this.name});
}
```

- [ ] **Step 2: 写失败测试**

`test/features/home/template_context_rules_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/home/data/inspiration_rules.dart';
import 'package:lumira_app_flutter/features/home/data/template_context_rules.dart';

void main() {
  const ctxSunnyWarmNoon = InspirationContext(
    slot: 'noon', season: '夏季', tempRange: '温暖', weather: '晴');

  group('resolveContextFit', () {
    test('晴天+温暖命中含 portrait/landscape 的规则', () {
      final fit = resolveContextFit(ctxSunnyWarmNoon);
      expect(fit.categories, contains('portrait'));
      expect(fit.categories, contains('landscape'));
    });

    test('夜晚命中夜景/街拍类别', () {
      const c = InspirationContext(slot: 'night', season: '冬季', tempRange: '寒冷');
      final fit = resolveContextFit(c);
      expect(fit.categories, contains('night'));
      expect(fit.categories, contains('street'));
    });
  });

  group('ambienceMatches', () {
    test('空 ambience 不视为匹配', () {
      expect(ambienceMatches(const {}, ctxSunnyWarmNoon), isFalse);
    });

    test('天气命中（晴→sunny）即匹配', () {
      expect(ambienceMatches({'weathers': ['sunny']}, ctxSunnyWarmNoon), isTrue);
    });

    test('天气不匹配则不命中', () {
      expect(ambienceMatches({'weathers': ['rain']}, ctxSunnyWarmNoon), isFalse);
    });

    test('季节不匹配则不命中', () {
      expect(ambienceMatches({'seasons': ['winter']}, ctxSunnyWarmNoon), isFalse);
    });

    test('timeTones 按时段宽松匹配（day 命中 noon）', () {
      expect(ambienceMatches({'timeTones': ['day']}, ctxSunnyWarmNoon), isTrue);
      const night = InspirationContext(slot: 'night', season: '冬季', tempRange: '寒冷');
      expect(ambienceMatches({'timeTones': ['night']}, night), isTrue);
    });
  });

  group('pickRecommendedTemplate', () {
    Candidate _c(String id, {String category = 'portrait', String? style,
        String? subStyle, String? type, int popularity = 0,
        Map<String, dynamic> ambience = const {}}) {
      return Candidate(id: id, name: '模板$id', category: category,
        style: style, subStyle: subStyle, type: type,
        ambience: ambience, popularity: popularity);
    }

    test('候选为空返回 null', () {
      expect(pickRecommendedTemplate(candidates: const [], context: ctxSunnyWarmNoon, preferredCategory: 'portrait'), isNull);
    });

    test('无语境命中（类别/风格/ambience 均不匹配）返回 null', () {
      final cands = [_c('a', category: 'food')];
      expect(pickRecommendedTemplate(candidates: cands, context: ctxSunnyWarmNoon, preferredCategory: 'portrait'), isNull);
    });

    test('语境类别命中时选中（不上偏好类别也选热度高者）', () {
      final cands = [
        _c('a', category: 'landscape', popularity: 1),
        _c('b', category: 'portrait', popularity: 100),
      ];
      final r = pickRecommendedTemplate(candidates: cands, context: ctxSunnyWarmNoon, preferredCategory: 'portrait');
      expect(r!.id, 'b'); // 都命中语境，portrait 且两者都匹配用户类别 → 热度高者
    });

    test('ambience 命中优先于规则命中', () {
      final cands = [
        _c('a', category: 'portrait', popularity: 999), // 规则命中（人像）+高热度
        _c('b', category: 'landscape', popularity: 1, ambience: {'weathers': ['sunny']}), // ambience 命中
      ];
      final r = pickRecommendedTemplate(candidates: cands, context: ctxSunnyWarmNoon, preferredCategory: 'portrait');
      expect(r!.id, 'b'); // ambience 最高优先
    });

    test('无条件命中时选择热度最高者', () {
      final cands = [
        _c('a', category: 'portrait', popularity: 50),
        _c('b', category: 'portrait', popularity: 2000),
      ];
      final r = pickRecommendedTemplate(candidates: cands, context: ctxSunnyWarmNoon, preferredCategory: 'portrait');
      expect(r!.id, 'b');
    });
  });
}
```

- [ ] **Step 3: 运行测试确认失败**

Run: `cd lumira_app_flutter && flutter test test/features/home/template_context_rules_test.dart`
Expected: FAIL，编译错误 `template_context_rules.dart` 不存在。

- [ ] **Step 4: 实现 `template_context_rules.dart`**

```dart
// lib/features/home/data/template_context_rules.dart
//
// 今日灵感智能模板——语境 → 候选模板 的纯函数推荐链路。
// 令牌体系与 inspiration_rules.dart 一致（slot / season / tempRange / weather）。
// 匹配策略：规则表为主（取最高特异度单条），ambience 元数据命中者最高优先级。
import '../../capture/domain/photo_template.dart' show TemplateRecord;
import 'inspiration_models.dart' show RecommendedTemplate;
import 'inspiration_rules.dart';

/// 语境 → 推荐的模板类别与风格（产物）
class ContextFit {
  final Set<String> styles;
  final Set<String> categories;
  const ContextFit({this.styles = const {}, this.categories = const {}});
  bool get isEmpty => styles.isEmpty && categories.isEmpty;
}

class TemplateContextRule {
  final String? slot;
  final String? season;
  final String? tempRange;
  final String? weather;
  final List<String> styles;
  final List<String> categories;
  const TemplateContextRule({
    this.slot, this.season, this.tempRange, this.weather,
    this.styles = const [], this.categories = const [],
  });
  int get specificity =>
      (slot != null ? 1 : 0) + (season != null ? 1 : 0) +
      (tempRange != null ? 1 : 0) + (weather != null ? 1 : 0);
}

/// 初始语境 → 类别/风格 规则表（可用模板实际存在的类别/风格覆盖时再扩展；
/// 类别为稳定主键，风格可选命中）。
const List<TemplateContextRule> templateContextRules = [
  // 晴天 + 温暖/炎热 → 人像/风光（"夏日日系"语义靠类别承载）
  TemplateContextRule(weather: '晴', tempRange: '温暖', styles: ['日系'], categories: ['portrait', 'landscape']),
  TemplateContextRule(weather: '晴', tempRange: '炎热', categories: ['portrait', 'landscape']),
  // 黄昏晴日 → 逆光人像/风光
  TemplateContextRule(slot: 'dusk', weather: '晴', categories: ['portrait', 'landscape']),
  // 清晨 → 人像柔光
  TemplateContextRule(slot: 'morning', categories: ['portrait']),
  // 午后/傍晚通用 → 人像/风光
  TemplateContextRule(slot: 'dusk', categories: ['portrait', 'landscape']),
  // 夜间 → 夜景/街拍
  TemplateContextRule(slot: 'night', categories: ['night', 'street']),
  // 雨/阴 → 街拍/静物/风光
  TemplateContextRule(weather: '雨', categories: ['street', 'still-life']),
  TemplateContextRule(weather: '阴', categories: ['landscape', 'street']),
  // 雪天 → 风光
  TemplateContextRule(weather: '雪', categories: ['landscape']),
  // 雾/多云 → 风光氛围
  TemplateContextRule(weather: '雾', categories: ['landscape']),
  TemplateContextRule(weather: '多云', categories: ['landscape']),
];

/// 取最高特异度的单条命中规则，其 styles+categories 即语境候选集合。
ContextFit resolveContextFit(InspirationContext c) {
  TemplateContextRule? best;
  var bestSpec = -1;
  for (final r in templateContextRules) {
    if (r.slot != null && r.slot != c.slot) continue;
    if (r.season != null && r.season != c.season) continue;
    if (r.tempRange != null && r.tempRange != c.tempRange) continue;
    if (r.weather != null && (c.weather.isEmpty || r.weather != c.weather)) continue;
    if (r.specificity > bestSpec) { bestSpec = r.specificity; best = r; }
  }
  if (best == null) return const ContextFit();
  return ContextFit(styles: best.styles.toSet(), categories: best.categories.toSet());
}

// —— ambience 匹配（模板自带 seasons/weathers/timeTones → 当前语境）——

String _weatherKeyZh2En(String zh) {
  switch (zh) {
    case '晴': return 'sunny';
    case '多云': return 'cloudy';
    case '阴': return 'overcast';
    case '雨':
    case '阵雨':
    case '雷雨': return 'rain';
    case '雪': return 'snow';
    case '雾': return 'fog';
    default: return '';
  }
}

String _seasonKeyZh2En(String zh) {
  switch (zh) {
    case '春季': return 'spring';
    case '夏季': return 'summer';
    case '秋季': return 'autumn';
    case '冬季': return 'winter';
    default: return '';
  }
}

bool _slotInTimeTone(String slot, String tone) {
  switch (tone) {
    case 'day': return slot == 'morning' || slot == 'noon' || slot == 'dusk';
    case 'night': return slot == 'night';
    case 'goldenHour': return slot == 'dusk';
    case 'warm': return slot == 'noon' || slot == 'dusk';
    case 'cool': return slot == 'morning' || slot == 'night';
    default: return true;
  }
}

List<String> _strList(dynamic v) =>
    v is List ? v.whereType<String>().toList() : const <String>[];

/// ambience 非空、且每个非空维度都命中当前语境 → 匹配。
bool ambienceMatches(Map<String, dynamic> ambience, InspirationContext c) {
  final seasons = _strList(ambience['seasons']);
  final weathers = _strList(ambience['weathers']);
  final timeTones = _strList(ambience['timeTones']);
  if (seasons.isEmpty && weathers.isEmpty && timeTones.isEmpty) return false;
  if (seasons.isNotEmpty && !seasons.contains(_seasonKeyZh2En(c.season))) return false;
  if (weathers.isNotEmpty) {
    final wk = _weatherKeyZh2En(c.weather);
    if (wk.isEmpty || !weathers.contains(wk)) return false;
  }
  if (timeTones.isNotEmpty && !timeTones.any((t) => _slotInTimeTone(c.slot, t))) return false;
  return true;
}

/// 模板候选描述（服务层把 DB 记录映射成它，再交给 pickRecommendedTemplate）
class Candidate {
  final String id;
  final String name;
  final String category;
  final String? style;
  final String? subStyle;
  final String? type;
  final Map<String, dynamic> ambience;
  final int popularity;
  const Candidate({
    required this.id, required this.name, required this.category,
    this.style, this.subStyle, this.type,
    this.ambience = const {},
    this.popularity = 0,
  });
}

class _Pooled {
  final Candidate c;
  final bool amb;
  _Pooled(this.c, this.amb);
}

/// 推荐主函数（纯）：在候选里选出归属当前语境且最火的模板。
/// 排序：ambience 命中 > 用户偏好类别命中 > 全站 use_shoot 热度（降序）。
/// 候选为空、或无任何语境命中（类别/风格/ambience 均不匹配）时返回 null。
RecommendedTemplate? pickRecommendedTemplate({
  required List<Candidate> candidates,
  required InspirationContext context,
  required String preferredCategory,
}) {
  if (candidates.isEmpty) return null;
  final fit = resolveContextFit(context);
  final styleSet = fit.styles;
  final catSet = fit.categories;
  final pooled = <_Pooled>[];
  for (final c in candidates) {
    final amb = ambienceMatches(c.ambience, context);
    final ruleHit = (c.style != null && styleSet.contains(c.style)) ||
        (c.subStyle != null && styleSet.contains(c.subStyle)) ||
        (c.type != null && catSet.contains(c.type)) ||
        catSet.contains(c.category);
    if (amb || ruleHit) pooled.add(_Pooled(c, amb));
  }
  if (pooled.isEmpty) return null;
  pooled.sort((a, b) {
    final ambCmp = (b.amb ? 1 : 0).compareTo(a.amb ? 1 : 0);
    if (ambCmp != 0) return ambCmp;
    final aCat = a.c.category == preferredCategory ? 1 : 0;
    final bCat = b.c.category == preferredCategory ? 1 : 0;
    final catCmp = bCat.compareTo(aCat);
    if (catCmp != 0) return catCmp;
    return b.c.popularity.compareTo(a.c.popularity);
  });
  final best = pooled.first.c;
  return RecommendedTemplate(id: best.id, name: best.name);
}
```

> 上面 import 的 `TemplateRecord` 实际未使用，请删除该 import 以避免未使用告警；`pickRecommendedTemplate` 只依赖 `Candidate`。

- [ ] **Step 5: 运行测试通过**

Run: `cd lumira_app_flutter && flutter test test/features/home/template_context_rules_test.dart`
Expected: PASS。

- [ ] **Step 6: Analyze**

Run: `cd lumira_app_flutter && flutter analyze lib/features/home/data/template_context_rules.dart lib/features/home/data/inspiration_models.dart`
Expected: 无 error。

- [ ] **Step 7: Commit**

```bash
cd d:/app/projects/photo_post
git add lumira_app_flutter/lib/features/home/data/template_context_rules.dart lumira_app_flutter/lib/features/home/data/inspiration_models.dart lumira_app_flutter/test/features/home/template_context_rules_test.dart
git commit -m "feat(flutter): 今日灵感模板推荐纯函数（规则表+ambience+热度排序）"
```

---

### Task 2: `HeroInspiration` 扩展 + `InspirationService` 接入推荐

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/data/inspiration_models.dart`（`HeroInspiration` 增加字段）
- Modify: `lumira_app_flutter/lib/features/home/services/inspiration_service.dart`
- Modify: `lumira_app_flutter/lib/features/home/data/home_providers.dart`

**Interfaces:**
- Consumes: Task 1 的 `Candidate`/`pickRecommendedTemplate`；`galleryDao.getRecent`、`templatesDao.getBuiltinAndRemote`、`usageDao.countFor`。
- Produces: `HeroInspiration` 新增 `recommendedTemplateId`/`recommendedTemplateName`（可空）。

- [ ] **Step 1: `inspiration_models.dart` 扩展 `HeroInspiration`**

在 `HeroInspiration` 类中新增可空字段并在构造器补可选参数（默认 null）：

```dart
class HeroInspiration {
  final String dateText;
  final String title;
  final String description;
  final String weatherText;
  /// 推荐出的模板（套用即进入拍摄），空串表示无推荐
  final String recommendedTemplateId;
  /// 推荐出的模板名称，用于 CTA 按钮文案
  final String recommendedTemplateName;

  const HeroInspiration({
    required this.dateText,
    required this.title,
    required this.description,
    required this.weatherText,
    this.recommendedTemplateId = '',
    this.recommendedTemplateName = '',
  });
  // fallback 保持不变（新字段默认空串）
}
```

- [ ] **Step 2: 修改 `inspiration_service.dart`**

头部 import 追加：

```dart
import 'dart:convert';
import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/dao/usage_dao.dart';
import '../../templates/domain/photo_template.dart' show TemplateMeta; // 若不需要可省略
import '../data/template_context_rules.dart';
// usage 提供者必需；photo_template 若未用则不 import
```

构造函数增加两个依赖（并保持既有调用兼容——`home_providers.dart` 下一任务同步更新）：

```dart
class InspirationService {
  InspirationService({
    required GalleryDao galleryDao,
    required ApiClient apiClient,
    required TemplatesDao templatesDao,
    required UsageDao usageDao,
  })  : _galleryDao = galleryDao,
        _apiClient = apiClient,
        _templatesDao = templatesDao,
        _usageDao = usageDao;

  final GalleryDao _galleryDao;
  final ApiClient _apiClient;
  final TemplatesDao _templatesDao;
  final UsageDao _usageDao;
```

新增两个私有方法（放在 `_composeDescription` 之后、`build` 之前或之后均可）：

```dart
/// 用户最近 50 张照片中，带模板照片的模板类别计数的最高类别（模板偏好）。
Future<String?> _recentTopTemplateCategory() async {
  final photos = await _galleryDao.getRecent(limit: 50);
  final counts = <String, int>{};
  for (final p in photos) {
    final tid = p.templateId;
    if (tid == null || tid.isEmpty) continue;
    final tpl = await _templatesDao.getById(tid);
    if (tpl == null || tpl.category.isEmpty) continue;
    counts[tpl.category] = (counts[tpl.category] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  final entries = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries.first.key;
}

Map<String, dynamic> _decodeAmbience(String json) {
  if (json.isEmpty) return const {};
  try {
    final v = jsonDecode(json);
    return v is Map<String, dynamic> ? v : const {};
  } catch (_) {
    return const {};
  }
}

/// 计算推荐模板：无近期模板拍摄偏好、或无语境适配模板 → null。
Future<RecommendedTemplate?> _recommend({
  required String slot,
  required int month,
  required int temperature,
  required String weather,
  double latitude = 0,
}) async {
  final prefCat = await _recentTopTemplateCategory();
  if (prefCat == null) return null;

  final context = InspirationContext(
    slot: slot,
    season: seasonOf(month),
    tempRange: tempRangeOf(temperature),
    weather: weather,
    region: regionOf(latitude),
  );

  final templates = await _templatesDao.getBuiltinAndRemote();
  final candidates = <Candidate>[];
  for (final t in templates) {
    final cls = t.classification;
    final pop = await _usageDao.countFor(t.id, 'template', 'use_shoot');
    candidates.add(Candidate(
      id: t.id,
      name: t.name,
      category: t.category,
      style: cls['style'] as String?,
      subStyle: cls['subStyle'] as String?,
      type: cls['type'] as String?,
      ambience: _decodeAmbience(t.ambienceJson),
      popularity: pop,
    ));
  }
  return pickRecommendedTemplate(
    candidates: candidates,
    context: context,
    preferredCategory: prefCat,
  );
}
```

在 `build()` 的 `return HeroInspiration(...)` 之前追加推荐计算，并在构造时带上新字段：

```dart
    // 模板推荐（失败静默回落，不影响卡片）
    RecommendedTemplate? rec;
    try {
      rec = await _recommend(
        slot: _slotName(slot),
        month: now.month,
        temperature: weather.temperature,
        weather: weather.condition,
        latitude: weather.latitude,
      );
    } catch (e) {
      debugPrint('InspirationService recommend failed: $e');
    }

    return HeroInspiration(
      dateText: dateText,
      title: '今日灵感',
      description: description,
      weatherText: weatherText,
      recommendedTemplateId: rec?.id ?? '',
      recommendedTemplateName: rec?.name ?? '',
    );
```

- [ ] **Step 3: 更新 `home_providers.dart` 的 `homeInspirationProvider`**

注入 `templatesDao` 与 `usageDao`：

```dart
final homeInspirationProvider =
    FutureProvider<HeroInspiration>((ref) async {
  final galleryDao = await ref.watch(galleryDaoProvider.future);
  final templatesDao = await ref.watch(templatesDaoProvider.future);
  final usageDao = await ref.watch(usageDaoProvider.future);
  final apiClient = await ref.watch(apiClientProvider.future);

  final service = InspirationService(
    galleryDao: galleryDao,
    apiClient: apiClient,
    templatesDao: templatesDao,
    usageDao: usageDao,
  );
  try {
    return await service.build();
  } catch (_) {
    return HeroInspiration.fallback;
  }
});
```

- [ ] **Step 4: Analyze**

Run: `cd lumira_app_flutter && flutter analyze lib/features/home`
Expected: 无 error（注意清理未使用的 import）。

- [ ] **Step 5: 运行既有 home 测试确认不回归**

Run: `cd lumira_app_flutter && flutter test test/features/home/home_page_test.dart test/features/home/template_context_rules_test.dart`
Expected: PASS。

- [ ] **Step 6: Commit**

```bash
cd d:/app/projects/photo_post
git add lumira_app_flutter/lib/features/home/data/inspiration_models.dart lumira_app_flutter/lib/features/home/services/inspiration_service.dart lumira_app_flutter/lib/features/home/data/home_providers.dart
git commit -m "feat(flutter): 今日灵感接入模板推荐计算"
```

---

### Task 3: `HeroCard` 按钮按推荐状态切换 + 组件测试

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/widgets/hero_card.dart`
- Create: `lumira_app_flutter/test/features/home/hero_card_recommend_test.dart`

**Interfaces:**
- Consumes: `HeroInspiration.recommendedTemplateId/Name`；`RouteNames.capture` / `RouteNames.paramTemplateId` / `RouteNames.build`；`GoRouter.of(context).push`。

- [ ] **Step 1: 写失败测试**

`test/features/home/hero_card_recommend_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/features/home/data/home_providers.dart';
import 'package:lumira_app_flutter/features/home/data/inspiration_models.dart';
import 'package:lumira_app_flutter/features/home/widgets/hero_card.dart';

void main() {
  Widget _wrap({
    required HeroInspiration inspiration,
    VoidCallback? onCapture,
  }) {
    final router = GoRouter(
      initialLocation: RouteNames.home,
      routes: [
        GoRoute(path: RouteNames.home, builder: (_, __) => const SizedBox.shrink()),
        GoRoute(
          path: RouteNames.capture,
          builder: (context, state) {
            final tid = state.queryParameters[RouteNames.paramTemplateId] ?? '';
            return Scaffold(body: Text('CAPTURE:$tid'));
          },
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
        homeInspirationProvider.overrideWith((ref) async => inspiration),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => Scaffold(body: child),
      ),
    );
  }

  testWidgets('有推荐时按钮显示模板名并带 templateId 跳转拍摄页', (tester) async {
    final inspiration = HeroInspiration(
      dateText: '8月23日',
      title: '今日灵感',
      description: '捕捉光',
      weatherText: '',
      recommendedTemplateId: 'soft_portrait',
      recommendedTemplateName: '柔光人像',
    );
    await tester.pumpWidget(_wrap(inspiration: inspiration));
    await tester.pumpAndSettle();

    expect(find.textContaining('柔光人像'), findsOneWidget);
    expect(find.text('开始拍摄'), findsNothing);

    await tester.tap(find.textContaining('柔光人像'));
    await tester.pumpAndSettle();

    expect(find.text('CAPTURE:soft_portrait'), findsOneWidget);
  });

  testWidgets('无推荐时按钮仍是「开始拍摄」并走 onCapture', (tester) async {
    var captured = false;
    final inspiration = HeroInspiration(
      dateText: '8月23日', title: '今日灵感',
      description: '捕捉光', weatherText: '',
    );
    await tester.pumpWidget(_wrap(
      inspiration: inspiration,
      onCapture: () => captured = true,
    ));
    await tester.pumpAndSettle();

    expect(find.text('开始拍摄'), findsOneWidget);

    await tester.tap(find.text('开始拍摄'));
    // pump 一帧触发回调（不跳路由）
    await tester.pump();
    expect(captured, isTrue);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd lumira_app_flutter && flutter test test/features/home/hero_card_recommend_test.dart`
Expected: FAIL — 按钮仍为「开始拍摄」。

- [ ] **Step 3: 修改 `hero_card.dart`**

头部 import 追加：

```dart
import 'package:go_router/go_router.dart';
import 'package:lumira_app_flutter/core/router/route_names.dart';
```

在 `_buildContent` 的 CTA `GestureDetector` 处，先计算推荐态，再替换 onTap 与文案。把现有 CTA 整块替换为：

```dart
                // CTA 按钮
                Builder(builder: (context) {
                  final hasRec = inspiration.recommendedTemplateId.isNotEmpty;
                  return GestureDetector(
                    onTap: () {
                      if (hasRec) {
                        GoRouter.of(context).push(RouteNames.build(
                          RouteNames.capture,
                          {RouteNames.paramTemplateId: inspiration.recommendedTemplateId},
                        ));
                      } else {
                        widget.onCapture();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isNeumorphic ? tokens.brand : null,
                        gradient: isNeumorphic
                            ? null
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [tokens.brand, tokens.brandDeep],
                              ),
                        boxShadow: isNeumorphic ? tokens.shadowConvex : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.camera_alt_outlined,
                              size: 16, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            hasRec
                                ? '用「${inspiration.recommendedTemplateName}」拍摄'
                                : '开始拍摄',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
```

> 说明：这里用局部 `Builder` 包一层只为拿 `context`（`_buildContent` 是 State 方法，直接用 `this.context` 亦可；若用 `this.context` 则可省去 `Builder`。二选一，保证能调用 `GoRouter.of(context)`）。

- [ ] **Step 4: 运行测试通过**

Run: `cd lumira_app_flutter && flutter test test/features/home/hero_card_recommend_test.dart`
Expected: PASS。

- [ ] **Step 5: Analyze + 全量 home 测试**

Run: `cd lumira_app_flutter && flutter analyze lib/features/home/widgets/hero_card.dart && flutter test test/features/home`
Expected: 无 error；home 全部测试通过。

- [ ] **Step 6: Commit**

```bash
cd d:/app/projects/photo_post
git add lumira_app_flutter/lib/features/home/widgets/hero_card.dart lumira_app_flutter/test/features/home/hero_card_recommend_test.dart
git commit -m "feat(flutter): 今日灵感具备推荐态按钮直接套用模板拍摄"
```

---

## 自检

**Spec 覆盖对照**
- 语境（天气/时间/气温）判定 → Task 1 `resolveContextFit` + `ambienceMatches`（规则表为主 + ambience 优先，quad 已确认）
- 用户最近拍摄偏好（模板照片→类别）门控 → Task 2 `_recentTopTemplateCategory`（无任何带模板照片返回 null，回落）
- 候选来源=全部可用模板（内置+远程）→ Task 2 `getBuiltinAndRemote()`
- 最火爆（全站 use_shoot 次数）排序 → Task 1 `pickRecommendedTemplate`（热度降序）
- 按钮=直接套用模板拍摄 → Task 3（push capture?templateId，文案「用「名」拍摄」）
- 无适配回落原样 → Task 3（hasRec=false 时 `开始拍摄` + `onCapture`）
- 「无近期模板偏好 → 不推荐」→ Task 2 门控；「无适配模板 → 不推荐」→ Task 1 `pickRecommendedTemplate` 返回 null

**No-Placeholder 检查**：所有步骤均含完整代码与精确路径。

**类型一致性**：`RecommendedTemplate`（Task 1 定义）在 Task 2 的 `_recommend` 返回类型与 `HeroInspiration` 引用一致；`Candidate` 字段在 Task 1 定义、Task 2 构造使用一致；`pickRecommendedTemplate` 签名在 Task 1 定义、Task 2 调用一致。

**真实数据对齐**：规则表用稳定的 `category` 为主 + 可选风格，避免命中不存在风格；ambience 匹配用天气/季节中英映射覆盖后端 `/weather` 返回的中文 condition。