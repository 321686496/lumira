/// 数字千分位格式化（如 1280 → "1,280"）
///
/// 用于 Profile HeroCard 总作品数、Growth LevelCard 经验值等场景。
/// 来源：uni-app lumira-app/src/pages/profile/index.vue 和 growth.vue 中
/// 的 `_formatNum` 函数（两处实现完全一致，此处提取为共享工具）。
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
