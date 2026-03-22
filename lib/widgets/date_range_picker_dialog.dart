import 'package:flutter/material.dart';

import 'glass_container.dart';

/// Shows a glass-styled calendar dialog that lets the user pick
/// a start and end date by scrolling through months vertically.
Future<Map<String, DateTime?>?> showTaskDateRangePickerDialog({
  required BuildContext context,
  DateTime? initialStartDate,
  DateTime? initialEndDate,
  DateTime? minDate,
  DateTime? maxDate,
}) {
  final now = DateTime.now();
  return showDialog<Map<String, DateTime?>>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.2),
    builder: (context) {
      return _DateRangePickerDialog(
        initialStartDate: initialStartDate,
        initialEndDate: initialEndDate,
        minDate: minDate ?? DateTime(now.year - 2),
        maxDate: maxDate ?? DateTime(now.year + 3),
      );
    },
  );
}

class _DateRangePickerDialog extends StatefulWidget {
  const _DateRangePickerDialog({
    required this.initialStartDate,
    required this.initialEndDate,
    required this.minDate,
    required this.maxDate,
  });

  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final DateTime minDate;
  final DateTime maxDate;

  @override
  State<_DateRangePickerDialog> createState() => _DateRangePickerDialogState();
}

class _DateRangePickerDialogState extends State<_DateRangePickerDialog> {
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  late final ScrollController _scrollController;
  late final List<DateTime> _months;
  late final List<double> _monthOffsets;
  static const double _cellSize = 40.0;
  static const double _monthTitleHeight = 32.0;
  static const double _monthGap = 16.0;

  int _rowCountForMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final leadingDays = firstDay.weekday % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    return ((leadingDays + daysInMonth) / 7).ceil();
  }

  double _monthHeight(DateTime month) {
    return _monthTitleHeight + (_rowCountForMonth(month) * _cellSize) + _monthGap;
  }

  @override
  void initState() {
    super.initState();
    _selectedStartDate = widget.initialStartDate;
    _selectedEndDate = widget.initialEndDate;

    _months = [];
    var cursor = DateTime(widget.minDate.year, widget.minDate.month);
    final end = DateTime(widget.maxDate.year, widget.maxDate.month);
    while (!cursor.isAfter(end)) {
      _months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1);
    }

    // Pre-compute cumulative offsets for each month
    _monthOffsets = List.filled(_months.length, 0.0);
    double offset = 0;
    for (int i = 0; i < _months.length; i++) {
      _monthOffsets[i] = offset;
      offset += _monthHeight(_months[i]);
    }

    // Scroll to the relevant month
    final baseDate =
        widget.initialStartDate ?? widget.initialEndDate ?? DateTime.now();
    final targetMonth = DateTime(baseDate.year, baseDate.month);
    final targetIndex = _months.indexWhere(
        (m) => m.year == targetMonth.year && m.month == targetMonth.month);
    final initialOffset = targetIndex > 0 ? _monthOffsets[targetIndex] : 0.0;
    _scrollController = ScrollController(initialScrollOffset: initialOffset);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleDateTap(DateTime date) {
    if (date.isBefore(widget.minDate) || date.isAfter(widget.maxDate)) {
      return;
    }

    setState(() {
      if (_selectedStartDate == null ||
          (_selectedStartDate != null && _selectedEndDate != null) ||
          date.isBefore(_selectedStartDate!)) {
        _selectedStartDate = date;
        _selectedEndDate = null;
      } else if (_selectedEndDate == null) {
        if (date.isAtSameMomentAs(_selectedStartDate!)) {
          _selectedEndDate = date;
        } else if (date.isAfter(_selectedStartDate!)) {
          _selectedEndDate = date;
        } else {
          _selectedStartDate = date;
        }
      } else {
        _selectedStartDate = date;
        _selectedEndDate = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 620),
        child: GlassContainer(
          padding: const EdgeInsets.all(20),
          borderRadius: 20.0,
          blur: 18.0,
          gradientColors: [
            colorScheme.surface.withValues(alpha: 0.6),
            colorScheme.surface.withValues(alpha: 0.5),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSelectionSummary(colorScheme),
              const SizedBox(height: 16),
              _buildWeekdayHeader(colorScheme),
              const SizedBox(height: 4),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _months.length,
                  itemExtent: null,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  itemBuilder: (context, index) {
                    return _MonthWidget(
                      key: ValueKey(_months[index]),
                      month: _months[index],
                      cellSize: _cellSize,
                      titleHeight: _monthTitleHeight,
                      gap: _monthGap,
                      selectedStartDate: _selectedStartDate,
                      selectedEndDate: _selectedEndDate,
                      minDate: widget.minDate,
                      maxDate: widget.maxDate,
                      onDateTap: _handleDateTap,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      '취소',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop({
                        'startDate': _selectedStartDate,
                        'endDate': _selectedEndDate,
                      });
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      '적용',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekdayHeader(ColorScheme colorScheme) {
    const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    return Row(
      children: List.generate(7, (index) {
        return Expanded(
          child: Center(
            child: Text(
              weekdays[index],
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: index == 0
                    ? const Color(0xFFEF5350)
                    : colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSelectionSummary(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: _SelectionChip(
            label: '시작일',
            date: _selectedStartDate,
            colorScheme: colorScheme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SelectionChip(
            label: '종료일',
            date: _selectedEndDate,
            colorScheme: colorScheme,
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: '선택 초기화',
          onPressed: () {
            setState(() {
              _selectedStartDate = null;
              _selectedEndDate = null;
            });
          },
          icon: const Icon(Icons.refresh),
          color: colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      ],
    );
  }
}

/// Separate StatelessWidget for each month to avoid rebuilding all months
/// on selection change via repaint boundaries.
class _MonthWidget extends StatelessWidget {
  const _MonthWidget({
    super.key,
    required this.month,
    required this.cellSize,
    required this.titleHeight,
    required this.gap,
    required this.selectedStartDate,
    required this.selectedEndDate,
    required this.minDate,
    required this.maxDate,
    required this.onDateTap,
  });

  final DateTime month;
  final double cellSize;
  final double titleHeight;
  final double gap;
  final DateTime? selectedStartDate;
  final DateTime? selectedEndDate;
  final DateTime minDate;
  final DateTime maxDate;
  final ValueChanged<DateTime> onDateTap;

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final firstDay = DateTime(month.year, month.month, 1);
    final leadingDays = firstDay.weekday % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final rowCount = ((leadingDays + daysInMonth) / 7).ceil();
    final firstVisibleDay = firstDay.subtract(Duration(days: leadingDays));

    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month title
          SizedBox(
            height: titleHeight,
            child: Center(
              child: Text(
                '${month.year}년 ${month.month}월',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ),
          // Calendar grid as Column of Rows (no shrinkWrap GridView)
          for (int row = 0; row < rowCount; row++)
            SizedBox(
              height: cellSize,
              child: Row(
                children: List.generate(7, (col) {
                  final dayIndex = row * 7 + col;
                  final date =
                      firstVisibleDay.add(Duration(days: dayIndex));
                  final isCurrentMonth =
                      date.month == month.month && date.year == month.year;
                  final isToday = _isSameDay(date, today);
                  final isSunday = date.weekday == DateTime.sunday;
                  final isDisabled = !isCurrentMonth ||
                      date.isBefore(minDate) ||
                      date.isAfter(maxDate);
                  final isSelectedStart = selectedStartDate != null &&
                      _isSameDay(date, selectedStartDate!);
                  final isSelectedEnd = selectedEndDate != null &&
                      _isSameDay(date, selectedEndDate!);
                  final isRange = selectedStartDate != null &&
                      selectedEndDate != null &&
                      date.isAfter(selectedStartDate!) &&
                      date.isBefore(selectedEndDate!);

                  final textColor = isSelectedStart || isSelectedEnd
                      ? Colors.white
                      : isDisabled
                          ? colorScheme.onSurface.withValues(alpha: 0.25)
                          : isSunday && isCurrentMonth
                              ? const Color(0xFFEF5350)
                              : colorScheme.onSurface.withValues(
                                  alpha: isCurrentMonth ? 0.9 : 0.4);

                  return Expanded(
                    child: GestureDetector(
                      onTap:
                          isDisabled ? null : () => onDateTap(date),
                      child: Stack(
                        children: [
                          if (isCurrentMonth &&
                              (isRange ||
                                  isSelectedStart ||
                                  isSelectedEnd))
                            Positioned.fill(
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                    vertical: 8),
                                decoration: BoxDecoration(
                                  color:
                                      colorScheme.primary.withValues(
                                    alpha: isRange ? 0.15 : 0.2,
                                  ),
                                  borderRadius:
                                      BorderRadius.horizontal(
                                    left: isSelectedStart &&
                                            !isSelectedEnd
                                        ? const Radius.circular(999)
                                        : Radius.zero,
                                    right: isSelectedEnd &&
                                            !isSelectedStart
                                        ? const Radius.circular(999)
                                        : Radius.zero,
                                  ),
                                ),
                              ),
                            ),
                          Center(
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color:
                                    isSelectedStart || isSelectedEnd
                                        ? colorScheme.primary
                                        : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${date.day}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                          if (isToday && isCurrentMonth)
                            const Positioned.fill(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: 3),
                                  child: SizedBox(
                                    width: 5,
                                    height: 5,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Color(0xFFE53935),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectionChip extends StatelessWidget {
  const _SelectionChip({
    required this.label,
    required this.date,
    required this.colorScheme,
  });

  final String label;
  final DateTime? date;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            date != null
                ? '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}'
                : '선택 안 됨',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: date != null
                  ? colorScheme.onSurface
                  : colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
