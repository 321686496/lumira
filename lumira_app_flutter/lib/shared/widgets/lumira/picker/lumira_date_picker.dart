import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_tokens.dart';
import '../dialog/lumira_bottom_sheet.dart';

/// Lumira 日期选择器
///
/// 设计文档：docs/superpowers/specs/2026-08-04-lumira-component-foundation-design.md §3.4
///
/// 全宽底部弹层：容器视觉由 [LumiraBottomSheetContainer] 统一解析（4 风格），
/// 圆角 = appTheme.popupRadius / 2（仅顶部两角），底部自动适配安全区。
/// 日历内部颜色全部从 tokens 取，零硬编码；选中日期的 brand 圆形背景为功能
/// 性强调色，4 风格下一致。
///
/// [markedDates]：需要打点标记的日期集合（如「有照片的日期」），
/// 在对应日期下方显示一个小圆点，与无照片日期、选中日期区分。
///
/// 图标说明：项目未依赖 phosphor_flutter，沿用项目既有约定
/// （Icons.chevron_left / right 作为 ph-caret-left / right 替代）。
Future<DateTime?> showLumiraDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  Set<DateTime> markedDates = const {},
}) {
  return showLumiraBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _LumiraDatePickerContent(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      markedDates: markedDates,
    ),
  );
}

class _LumiraDatePickerContent extends ConsumerStatefulWidget {
  const _LumiraDatePickerContent({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.markedDates,
  });

  final DateTime initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;

  /// 需要打点标记的日期集合（date-only）
  final Set<DateTime> markedDates;

  @override
  ConsumerState<_LumiraDatePickerContent> createState() =>
      _LumiraDatePickerContentState();
}

class _LumiraDatePickerContentState
    extends ConsumerState<_LumiraDatePickerContent> {
  late DateTime _selected;
  late DateTime _displayedMonth; // 当月 1 号

  @override
  void initState() {
    super.initState();
    _selected = _dateOnly(widget.initialDate);
    _displayedMonth = DateTime(_selected.year, _selected.month, 1);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _goPrevMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1);
    });
  }

  void _goNextMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;

    final firstDateOnly =
        widget.firstDate != null ? _dateOnly(widget.firstDate!) : null;
    final lastDateOnly =
        widget.lastDate != null ? _dateOnly(widget.lastDate!) : null;

    // 月份切换限制：上月末日在 firstDate 之前 → 禁用上一月；
    // 下月首日在 lastDate 之后 → 禁用下一月。
    final prevMonthLastDay =
        DateTime(_displayedMonth.year, _displayedMonth.month, 0);
    final nextMonthFirstDay =
        DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    final prevDisabled =
        firstDateOnly != null && prevMonthLastDay.isBefore(firstDateOnly);
    final nextDisabled =
        lastDateOnly != null && nextMonthFirstDay.isAfter(lastDateOnly);

    final now = _dateOnly(DateTime.now());

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildMonthBar(tokens, prevDisabled, nextDisabled),
        const SizedBox(height: 12),
        _buildWeekHeader(tokens),
        const SizedBox(height: 8),
        _buildGrid(tokens, firstDateOnly, lastDateOnly, now, widget.markedDates),
        const SizedBox(height: 16),
        _buildActions(tokens, appTheme),
      ],
    );
  }

  Widget _buildMonthBar(ThemeTokens tokens, bool prevDisabled, bool nextDisabled) {
    return Stack(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _navButton(
              icon: Icons.chevron_left,
              enabled: !prevDisabled,
              tokens: tokens,
              onTap: _goPrevMonth,
            ),
            Text(
              '${_displayedMonth.year}年${_displayedMonth.month}月',
              style: (Theme.of(context).textTheme.titleMedium ??
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))
                  .copyWith(
                    fontWeight: FontWeight.bold,
                    color: tokens.textPrimary,
                  ),
            ),
            _navButton(
              icon: Icons.chevron_right,
              enabled: !nextDisabled,
              tokens: tokens,
              onTap: _goNextMonth,
            ),
          ],
        ),
        // 右上角关闭按钮：无需只能通过「取消」退出
        Align(
          alignment: Alignment.topRight,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(null),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.close,
                size: 18,
                color: tokens.textTertiary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _navButton({
    required IconData icon,
    required bool enabled,
    required ThemeTokens tokens,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: Icon(
            icon,
            size: 22,
            color: enabled ? tokens.textSecondary : tokens.textTertiary,
          ),
        ),
      ),
    );
  }

  Widget _buildWeekHeader(ThemeTokens tokens) {
    const labels = <String>['日', '一', '二', '三', '四', '五', '六'];
    return Row(
      children: <Widget>[
        for (final String l in labels)
          Expanded(
            child: Center(
              child: Text(
                l,
                style: TextStyle(color: tokens.textTertiary, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGrid(
    ThemeTokens tokens,
    DateTime? firstDateOnly,
    DateTime? lastDateOnly,
    DateTime now,
    Set<DateTime> markedDates,
  ) {
    // 周日为一周第一天：weekday Mon=1..Sun=7 → SundayStart = weekday % 7
    final firstWeekday = _displayedMonth.weekday;
    final gridStart =
        _displayedMonth.subtract(Duration(days: firstWeekday % 7));

    // 按当月实际占据的周数渲染，避免小月仍堆出 6 行造成弹窗过高
    final lastOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0);
    final daysInSpan = lastOfMonth.difference(gridStart).inDays + 1;
    final rowCount = (daysInSpan / 7).ceil();

    final rows = <Widget>[];
    for (int r = 0; r < rowCount; r++) {
      final cells = <Widget>[];
      for (int c = 0; c < 7; c++) {
        final day = gridStart.add(Duration(days: r * 7 + c));
        cells.add(
          Expanded(
            child: SizedBox(
              width: double.infinity,
              height: 40,
              child: _buildCell(
                day,
                tokens,
                firstDateOnly,
                lastDateOnly,
                now,
                markedDates,
              ),
            ),
          ),
        );
      }
      rows.add(Row(children: cells));
    }
    return Column(children: rows);
  }

  Widget _buildCell(
    DateTime day,
    ThemeTokens tokens,
    DateTime? firstDateOnly,
    DateTime? lastDateOnly,
    DateTime now,
    Set<DateTime> markedDates,
  ) {
    final dayOnly = _dateOnly(day);
    final isThisMonth = day.month == _displayedMonth.month;
    final rangeExcluded =
        (firstDateOnly != null && dayOnly.isBefore(firstDateOnly)) ||
            (lastDateOnly != null && dayOnly.isAfter(lastDateOnly));
    final isOutOfRange = !isThisMonth || rangeExcluded;
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final isToday = _isSameDay(dayOnly, now);
    final isSelected = _isSameDay(dayOnly, _selected);
    final isMarked =
        markedDates.any((d) => _isSameDay(d, dayOnly)) && isThisMonth;

    Color textColor;
    if (isSelected) {
      textColor = tokens.textInverse;
    } else if (isToday) {
      textColor = tokens.brandText;
    } else if (isMarked) {
      // 有照片日期：主色文字突出，区别于无照片日期
      textColor = tokens.brandText;
    } else if (isOutOfRange) {
      textColor = tokens.textTertiary;
    } else if (isWeekend) {
      textColor = tokens.textSecondary;
    } else {
      textColor = tokens.textPrimary;
    }

    final interactive = isThisMonth && !rangeExcluded;

    return GestureDetector(
      onTap: interactive
          ? () {
              setState(() {
                _selected = dayOnly;
              });
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? tokens.brand
                  : (isMarked && !isToday ? tokens.brandSubtle : null),
              border: isToday && !isSelected
                  ? Border.all(color: tokens.brand, width: 1.5)
                  : null,
            ),
            alignment: Alignment.center,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Center(
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight:
                          isSelected || isToday ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                // 有照片日期在数字下方打点，与无照片日期、选中日期区分
                if (isMarked)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 5,
                    child: Center(
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              isSelected ? tokens.textInverse : tokens.brand,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(ThemeTokens tokens, AppThemeData appTheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        _textButton(
          label: '取消',
          color: tokens.textSecondary,
          onTap: () => Navigator.of(context).pop(null),
        ),
        const SizedBox(width: 12),
        _primaryButton(
          label: '确定',
          tokens: tokens,
          appTheme: appTheme,
          onTap: () => Navigator.of(context).pop(_selected),
        ),
      ],
    );
  }

  Widget _textButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required ThemeTokens tokens,
    required AppThemeData appTheme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: tokens.brand,
          borderRadius: BorderRadius.circular(appTheme.buttonRadius / 2),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: tokens.textInverse,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
