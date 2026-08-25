import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';

/// 单格数据（date 非空表示该格落在请求范围内；空表示补齐边界的空白格）。
class _HeatCell {
  const _HeatCell({this.date, this.count = 0, this.level = 0});
  final DateTime? date; // null = 边界补齐空格
  final int count;
  final int level;
}

/// 构建结果：列（周）矩阵 + 每月标注。
class _GridData {
  const _GridData({required this.columns, required this.monthLabels});
  final List<List<_HeatCell>> columns;
  final List<String?> monthLabels;
}

/// GitHub 风格的拍摄日历热力图。
///
/// - 列 = 一周（7 天，日~六），行首显示星期标签
/// - 顶部按月份标注（跨月时在包含 1 日的列上显示月份）
/// - 格子颜色跟随主题品牌色（0–4 级透明度阶梯，不硬编码色值）
/// - 点击有记录的格子回调 [onCellTap]
///
/// [daysBack] 非空时仅显示最近 N 天（用于成长中心卡片）；
/// 为空时显示「最早有记录的一天 → [endDate]」的全部跨度（用于「全部记录」页）。
class ShootingCalendarHeatmap extends StatelessWidget {
  const ShootingCalendarHeatmap({
    super.key,
    required this.heatmap,
    required this.tokens,
    required this.onCellTap,
    this.endDate,
    this.daysBack,
    this.cellSize = 14,
    this.cellGap = 3,
    this.showWeekdayLabels = true,
  });

  /// date(YYYY-MM-DD) -> 当日活动量
  final Map<String, int> heatmap;
  final ThemeTokens tokens;

  /// 点击回调：(date, count, level)
  final void Function(String date, int count, int level) onCellTap;
  final DateTime? endDate;
  final int? daysBack;
  final double cellSize;
  final double cellGap;
  final bool showWeekdayLabels;

  static const _weekdayNames = ['日', '一', '二', '三', '四', '五', '六'];

  String _fmt(DateTime d) {
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  int _countToLevel(int count) {
    if (count == 0) return 0;
    if (count == 1) return 1;
    if (count == 2) return 2;
    if (count <= 4) return 3;
    return 4;
  }

  Color _heatColor(int level) {
    switch (level) {
      case 0:
        return tokens.divider;
      case 1:
        return tokens.brand.withOpacity(0.2);
      case 2:
        return tokens.brand.withOpacity(0.4);
      case 3:
        return tokens.brand.withOpacity(0.6);
      default:
        return tokens.brand;
    }
  }

  /// 计算列（周）与单格数据。
  /// 返回 [_GridData]（每列 7 格，index0=日）。
  _GridData _buildGrid() {
    final endUtc = DateTime.utc(
      (endDate ?? DateTime.now().toUtc()).year,
      (endDate ?? DateTime.now().toUtc()).month,
      (endDate ?? DateTime.now().toUtc()).day,
    );

    // 起点：daysBack 指定最近 N 天；否则取最早活动日（无数据则今天）。
    DateTime rangeStart;
    if (daysBack != null && daysBack! > 0) {
      rangeStart = endUtc.subtract(Duration(days: daysBack! - 1));
    } else {
      final keys = heatmap.keys;
      if (keys.isEmpty) {
        rangeStart = endUtc;
      } else {
        var earliest = endUtc;
        for (final key in keys) {
          final parsed = DateTime.tryParse(key);
          if (parsed != null && parsed.isBefore(earliest)) earliest = parsed;
        }
        rangeStart = earliest;
      }
    }

    // 首列起点 = rangeStart 所在周的周日；末列起点 = endUtc 所在周的周日。
    final firstColStart = rangeStart.subtract(Duration(days: rangeStart.weekday % 7));
    final lastColStart = endUtc.subtract(Duration(days: endUtc.weekday % 7));
    final numWeeks = ((lastColStart.difference(firstColStart).inDays) ~/ 7) + 1;

    final columns = <List<_HeatCell>>[];
    final monthLabels = List<String?>.filled(numWeeks, null);

    for (var w = 0; w < numWeeks; w++) {
      final weekStart = firstColStart.add(Duration(days: w * 7));
      final column = <_HeatCell>[];
      for (var d = 0; d < 7; d++) {
        final day = weekStart.add(Duration(days: d));
        if (day.isBefore(rangeStart) || day.isAfter(endUtc)) {
          column.add(const _HeatCell()); // 边界补齐空格
          continue;
        }
        final dateStr = _fmt(day);
        final count = heatmap[dateStr] ?? 0;
        // 记录该周内的「1 日」用于顶部月标注
        if (d == 0 && day.day == 1) monthLabels[w] = '${day.month}月';
        column.add(_HeatCell(date: day, count: count, level: _countToLevel(count)));
      }
      columns.add(column);
    }
    return _GridData(columns: columns, monthLabels: monthLabels);
  }

  @override
  Widget build(BuildContext context) {
    final grid = _buildGrid();
    final columns = grid.columns;
    final monthLabels = grid.monthLabels;
    final pitch = cellSize + cellGap;
    final labelW = showWeekdayLabels ? cellSize : 0.0;
    const monthRowH = 18.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧星期标签列
          SizedBox(
            width: labelW,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: monthRowH),
                for (var i = 0; i < 7; i++)
                  SizedBox(
                    height: pitch,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: (showWeekdayLabels && _shouldShowLabel(i))
                          ? Text(
                              _weekdayNames[i],
                              style: TextStyle(
                                fontSize: 9,
                                color: tokens.textTertiary,
                              ),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          // 月份行
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: monthRowH,
                child: Row(
                  children: [
                    for (var w = 0; w < columns.length; w++)
                      SizedBox(
                        width: pitch,
                        child: Center(
                          child: monthLabels[w] == null
                              ? null
                              : Text(
                                  monthLabels[w]!,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: tokens.textTertiary,
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
              // 热力图（每列一周，7 行 = 日~六）
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var w = 0; w < columns.length; w++)
                    SizedBox(
                      width: pitch,
                      child: Column(
                        children: [
                          for (var d = 0; d < 7; d++)
                            SizedBox(
                              height: pitch,
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: _buildCell(columns[w][d]),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _shouldShowLabel(int weekday) => const {0, 1, 3, 5}.contains(weekday);

  Widget _buildCell(_HeatCell cell) {
    final date = cell.date;
    // 范围内（date 非空）的格子始终有底色：有记录用对应 level，空白天用 level 0 浅底；
    // 仅范围外边界补齐格保持透明。
    final inRange = date != null;
    final color = inRange ? _heatColor(cell.level) : Colors.transparent;

    final box = Container(
      width: cellSize,
      height: cellSize,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );

    if (!inRange) return box;

    return GestureDetector(
      onTap: () => onCellTap(_fmt(date), cell.count, cell.level),
      behavior: HitTestBehavior.opaque,
      child: box,
    );
  }
}