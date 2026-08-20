// lib/features/home/data/inspiration_rules.dart
//
// 今日灵感——数据驱动规则表
// 结构：InspirationRule 每条规则带有若干「命中条件」（可空=任意），按「命中条件数 + 列表顺序」
//       取最优匹配。覆盖维度：时段 × 季节 × 温度区间 × 天气 × 地域 × 用户偏好类别。
// 分层：
//   - lightRules  ：时段 × 天气 × 温度 → 「光线 / 外出建议」骨架
//   - themeRules  ：类别 × 季节 × 地域 → 「拍摄主题」点缀
//   description ≈ lightRules 命中 + themeRules 命中，组合成卡片文案。
//
// 新增/扩展内容时只需向对应 const 列表追加规则，无需改动服务逻辑。

/// 规则命中条件 + 文案
class InspirationRule {
  /// 时段：morning/noon/dusk/night
  final String? slot;
  /// 季节：春季/夏季/秋季/冬季
  final String? season;
  /// 温度区间：炎热/温暖/凉爽/偏冷/寒冷
  final String? tempRange;
  /// 天气：晴/多云/阴/雨/雪/雾/阵雨/雷雨
  final String? weather;
  /// 地域：南方/中部/北方/高寒
  final String? region;
  /// 用户主导类别：portrait/landscape/food/street/night/macro/still-life
  final String? category;
  /// 命中后输出的文案
  final String text;

  const InspirationRule({
    this.slot,
    this.season,
    this.tempRange,
    this.weather,
    this.region,
    this.category,
    required this.text,
  });

  /// 命中条件数（用于排序取最优：条件越多越具体）
  int get specificity =>
      (slot != null ? 1 : 0) +
      (season != null ? 1 : 0) +
      (tempRange != null ? 1 : 0) +
      (weather != null ? 1 : 0) +
      (region != null ? 1 : 0) +
      (category != null ? 1 : 0);
}

/// 时段 × 天气 × 温度 → 光线/外出建议
/// 排序原则：天气/温度的特例在前（避免被时段基础覆盖），时段基础次之，兜底最后。
const List<InspirationRule> lightRules = <InspirationRule>[
  // —— 天气强影响（全时段通用）——
  InspirationRule(
    weather: '雷雨',
    text: '雷雨改变光线节奏，先以安全为重，室内暖光场景更稳',
  ),
  InspirationRule(
    weather: '雪',
    text: '雪天反光强烈，适当减曝光避免过曝，深色点缀更出片',
  ),
  InspirationRule(
    weather: '雾',
    text: '雾天层次极佳，近中远三层构图更有氛围',
  ),
  InspirationRule(
    weather: '雨',
    text: '雨天通透湿润，窗玻璃水珠与地面倒影都是天然道具',
  ),
  // —— 温度强影响 ——
  InspirationRule(
    tempRange: '炎热',
    weather: '晴',
    text: '正午高温强光，改到清晨或傍晚前出门体感与光线都更好',
  ),
  InspirationRule(
    tempRange: '寒冷',
    text: '低温电池掉电快，备好备用电池与手套再安心拍',
  ),
  InspirationRule(
    tempRange: '炎热',
    text: '炎热时段优先挑阴凉处，避免强逆光过曝',
  ),
  // —— 时段 × 天气/温度组合特例 ——
  InspirationRule(
    slot: 'dusk',
    weather: '晴',
    text: '黄昏晴日，逆光剪影与金色光晕正当时',
  ),
  InspirationRule(
    slot: 'dusk',
    weather: '雨',
    text: '雨后黄昏，地面反光让城市更有层次',
  ),
  InspirationRule(
    slot: 'night',
    tempRange: '炎热',
    text: '夏夜闷热，霓虹与街头夜市的光影值得一拍',
  ),
  InspirationRule(
    slot: 'morning',
    tempRange: '寒冷',
    text: '冬日清晨呵气成霜，晨光与热气最易出氛围',
  ),
  InspirationRule(
    slot: 'noon',
    weather: '多云',
    text: '云层柔化正午顶光，是难得的全天候柔和光线',
  ),
  // —— 时段基础 ——
  InspirationRule(
    slot: 'morning',
    text: '清晨光线柔和，逆光与阴影层次都刚刚好',
  ),
  InspirationRule(
    slot: 'noon',
    text: '正午光硬且顶，尽量挑阴影或室内取景',
  ),
  InspirationRule(
    slot: 'dusk',
    text: '黄昏暖光转瞬即逝，抓紧日落前后的一小时',
  ),
  InspirationRule(
    slot: 'night',
    text: '夜色已深，善用霓虹与长曝光',
  ),
  // —— 兜底 ——
  InspirationRule(text: '捕捉每一束光，让日常成为习惯'),
];

/// 类别 × 季节 × 地域 → 拍摄主题
/// 排序原则：用户偏好类别优先（满足「叠加偏好」），地域风物次之，兜底最后。
const List<InspirationRule> themeRules = <InspirationRule>[
  // —— 人像 ——
  InspirationRule(
    category: 'portrait',
    season: '夏季',
    text: '夏日人像挑午后树影或室内阴凉，清爽不油腻',
  ),
  InspirationRule(
    category: 'portrait',
    season: '冬季',
    text: '冬日人像用暖调大衣与围巾，冷暖对比更显质感',
  ),
  InspirationRule(
    category: 'portrait',
    text: '拍人的话，逆光与侧逆光最勾勒轮廓',
  ),
  // —— 风光 ——
  InspirationRule(
    category: 'landscape',
    season: '秋季',
    text: '秋色层林尽染，低角度逆光拍出通透感',
  ),
  InspirationRule(
    category: 'landscape',
    season: '夏季',
    text: '夏日风光雨云与绿植层次最丰富',
  ),
  InspirationRule(
    category: 'landscape',
    text: '风光抓住日出日落前后的一小时',
  ),
  // —— 美食 ——
  InspirationRule(
    category: 'food',
    text: '美食用侧上方自然光，色彩还原更真实',
  ),
  // —— 街拍 ——
  InspirationRule(
    category: 'street',
    season: '冬季',
    text: '冬日街头人流稀少，冷暖灯光的故事感更强',
  ),
  InspirationRule(
    category: 'street',
    text: '街拍等一个行人路过，故事感藏在瞬间',
  ),
  // —— 夜景 ——
  InspirationRule(
    category: 'night',
    text: '夜景上脚架低ISO长曝光，细节更干净',
  ),
  // —— 微距 ——
  InspirationRule(
    category: 'macro',
    text: '微距看细节，稳住支架别手抖',
  ),
  // —— 静物 ——
  InspirationRule(
    category: 'still-life',
    text: '静物单一主光源，暗背景更有质感',
  ),
  // —— 地域风物点缀 ——
  InspirationRule(
    region: '南方',
    text: '南方湿热，午后雨幕与霓虹倒影常有惊喜',
  ),
  InspirationRule(
    region: '北方',
    text: '北方干燥通透，长焦风光与远景更清晰',
  ),
  InspirationRule(
    region: '高寒',
    text: '高寒地区光线冷冽，雪原与星空更具冲击力',
  ),
  // —— 兜底 ——
  InspirationRule(text: '让日常成为习惯，随手记录眼前的光'),
];

/// 推导令牌（由服务根据实时输入生成）
class InspirationContext {
  /// 时段：morning/noon/dusk/night
  final String slot;
  /// 季节：春季/夏季/秋季/冬季
  final String season;
  /// 温度区间：炎热/温暖/凉爽/偏冷/寒冷
  final String tempRange;
  /// 天气：晴/多云/阴/雨/雪/雾/阵雨/雷雨（无数据时为空串）
  final String weather;
  /// 地域：南方/中部/北方/高寒（无数据时为 null）
  final String? region;
  /// 用户主导类别（无数据时为 null）
  final String? category;

  const InspirationContext({
    required this.slot,
    required this.season,
    required this.tempRange,
    this.weather = '',
    this.region,
    this.category,
  });
}

/// 季节推导：由月份（1-12）
String seasonOf(int month) {
  switch (month) {
    case 3:
    case 4:
    case 5:
      return '春季';
    case 6:
    case 7:
    case 8:
      return '夏季';
    case 9:
    case 10:
    case 11:
      return '秋季';
    default:
      return '冬季';
  }
}

/// 温度区间推导（摄氏度）
String tempRangeOf(int temp) {
  if (temp >= 30) return '炎热';
  if (temp >= 22) return '温暖';
  if (temp >= 15) return '凉爽';
  if (temp >= 5) return '偏冷';
  return '寒冷';
}

/// 地域分带推导：由纬度（粗略定位，仅作语境）。纬度未知返回 null。
String? regionOf(double latitude) {
  if (latitude <= 0) return null;
  if (latitude < 23.5) return '南方';
  if (latitude < 35) return '中部';
  if (latitude < 45) return '北方';
  return '高寒';
}

/// 在 [rules] 中取最优匹配规则文案；无匹配时返回 [fallback]。
String matchRule(
  List<InspirationRule> rules,
  InspirationContext c,
  String fallback,
) {
  InspirationRule? hit;
  var best = -1;
  for (final r in rules) {
    if (r.slot != null && r.slot != c.slot) continue;
    if (r.season != null && r.season != c.season) continue;
    if (r.tempRange != null && r.tempRange != c.tempRange) continue;
    if (r.weather != null) {
      // 无天气数据时不命中天气条件（条件要求精确匹配）
      if (c.weather.isEmpty || r.weather != c.weather) continue;
    }
    if (r.region != null && r.region != c.region) continue;
    if (r.category != null && r.category != c.category) continue;
    final spec = r.specificity;
    if (spec > best) {
      best = spec;
      hit = r;
    }
  }
  return hit?.text ?? fallback;
}