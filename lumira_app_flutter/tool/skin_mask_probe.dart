// 皮肤掩膜覆盖探针：验证放宽后的 YCbCr 肤色盒能覆盖真实肤况，
// 同时不过度把常见背景（红/棕/灰/绿）判成皮肤。
double _ss(double x, double e0, double e1) {
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

// 与 skin_smoother.dart 的 _skinWeight 一致
double skinWeight(int r, int g, int b) {
  final y = 0.299 * r + 0.587 * g + 0.114 * b;
  final cb = (-0.168736 * r - 0.331264 * g + 0.5 * b) + 128.0;
  final cr = (0.5 * r - 0.418688 * g - 0.081312 * b) + 128.0;
  final yWeight = _ss(y, 40, 60) * (1 - _ss(y, 250, 255));
  final crWeight = _ss(cr, 128, 140) * (1 - _ss(cr, 172, 186));
  final cbWeight = _ss(cb, 70, 85) * (1 - _ss(cb, 120, 132));
  return yWeight * crWeight * cbWeight;
}

void main() {
  final cases = <String, List<int>>{
    '浅肤 (200,160,140)': [200, 160, 140],
    '中肤 (180,140,120)': [180, 140, 120],
    '深肤 (110,78,55)': [110, 78, 55],
    '阴影里的浅肤 (110,84,72)': [110, 84, 72],
    // 病理红 / 肤色红调
    '肤色偏红 (220,150,120)': [220, 150, 120],
    // 背景
    '红衣物 (180,40,30)': [180, 40, 30],
    '棕木/毛衣 (150,110,80)': [150, 110, 80],
    '灰墙 (128,128,128)': [128, 128, 128],
    '绿背景 (60,140,60)': [60, 140, 60],
    '白衣物 (245,245,245)': [245, 245, 245],
  };
  print('肤色概率（>0.3 视作会参与磨皮）:');
  cases.forEach((name, rgb) {
    final w = skinWeight(rgb[0], rgb[1], rgb[2]);
    print('  ${name.padRight(24)} ${w.toStringAsFixed(2)} ${w > 0.3 ? '✔' : ''}');
  });
}