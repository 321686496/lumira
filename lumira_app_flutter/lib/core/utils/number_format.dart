/// 数字千分位格式化（如 1280 → "1,280"）
///
/// 用于 Profile HeroCard 总作品数、Growth LevelCard 经验值等场景。
/// 来源：uni-app lumira-app/src/pages/profile/index.vue 和 growth.vue 中
/// 的 `_formatNum` 函数（两处实现完全一致，此处提取为共享工具）。
///
/// 历史修复说明：原 `_formatNum` 在 4+ 位数字上逗号位置错误
/// （如 1280 错误返回 "128,0"，2000 错误返回 "200,0"）。
/// 本实现采用正向 StringBuffer + 索引取字符的方式，
/// 通过 `(str.length - i) % 3 == 0` 在正确位置插入逗号，
/// 输出 "1,280" / "2,000" 等标准千分位格式，已由单元测试覆盖。
String formatThousands(int value) {
  final str = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(str[i]);
  }
  return buffer.toString();
}
