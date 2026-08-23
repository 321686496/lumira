// lib/features/home/data/template_context_rules.dart
//
// 今日灵感智能模板——语境 → 候选模板 的纯函数推荐链路。
// 令牌体系与 inspiration_rules.dart 一致（slot / season / tempRange / weather）。
// 匹配策略：规则表为主（取最高特异度单条），ambience 元数据命中者最高优先级。
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