import 'package:flutter/material.dart';

import 'glass_container.dart';

/// Shows a glass-styled calendar dialog that lets the user pick
/// a start and end date within a single calendar just like a
/// flight ticket booking experience.
Future<Map<String, DateTime?>?> showTaskDateRangePickerDialog({
  required BuildContext context,
  DateTime? initialStartDate,
  DateTime? initialEndDate,
  DateTime? minDate,
  DateTime? maxDate,
}) {
  return showDialog<Map<String, DateTime?>>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.2),
    builder: (context) {
      return _DateRangePickerDialog(
        initialStartDate: initialStartDate,
        initialEndDate: initialEndDate,
        minDate: minDate ?? DateTime(2020),
        maxDate: maxDate ?? DateTime(2030),
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
  late DateTime _visibleMonth;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  @override
  void initState() {
    super.initState();
    final baseDate =
        widget.initialStartDate ?? widget.initialEndDate ?? DateTime.now();
    _visibleMonth = DateTime(baseDate.year, baseDate.month);
    _selectedStartDate = widget.initialStartDate;
    _selectedEndDate = widget.initialEndDate;
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

  void _changeMonth(int offset) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + offset,
      );
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 640,
        ),
        child: GlassContainer(
          padding: const EdgeInsets.all(24),
          borderRadius: 20.0,
          blur: 25.0,
          gradientColors: [
            colorScheme.surface.withOpacity(0.6),
            colorScheme.surface.withOpacity(0.5),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      _buildCalendarNavigation(colorScheme),
                      const SizedBox(height: 12),
                      _buildWeekdayHeader(colorScheme),
                      const SizedBox(height: 8),
                      _buildCalendarGrid(colorScheme),
                      const SizedBox(height: 16),
                      _buildSelectionSummary(colorScheme),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
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

  Widget _buildCalendarNavigation(ColorScheme colorScheme) {
    return Row(
      children: [
      Text(
          '${_visibleMonth.year}년 ${_visibleMonth.month}월',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => _changeMonth(-1),
          icon: const Icon(Icons.chevron_left),
          color: colorScheme.onSurface,
        ),
        IconButton(
          onPressed: () => _changeMonth(1),
          icon: const Icon(Icons.chevron_right),
          color: colorScheme.onSurface,
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader(ColorScheme colorScheme) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return Row(
      children: List.generate(7, (index) {
        return Expanded(
          child: Center(
            child: Text(
              weekdays[index],
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCalendarGrid(ColorScheme colorScheme) {
    final firstDayOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final firstWeekday = firstDayOfMonth.weekday; // Monday=1 ... Sunday=7
    final leadingDays = (firstWeekday + 6) % 7; // shift so Monday starts column
    final firstVisibleDay =
        firstDayOfMonth.subtract(Duration(days: leadingDays));
    final days = List.generate(
      42,
      (index) => firstVisibleDay.add(Duration(days: index)),
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.2,
      ),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final date = days[index];
        final isCurrentMonth = date.month == _visibleMonth.month;
        final isDisabled = !isCurrentMonth ||
            date.isBefore(widget.minDate) ||
            date.isAfter(widget.maxDate);
        final isSelectedStart =
            _selectedStartDate != null && _isSameDay(date, _selectedStartDate!);
        final isSelectedEnd =
            _selectedEndDate != null && _isSameDay(date, _selectedEndDate!);
        final isRange = _selectedStartDate != null &&
            _selectedEndDate != null &&
            date.isAfter(_selectedStartDate!) &&
            date.isBefore(_selectedEndDate!);

        final textColor = isSelectedStart || isSelectedEnd
            ? Colors.white
            : isDisabled
                ? colorScheme.onSurface.withOpacity(0.25)
                : colorScheme.onSurface.withOpacity(
                    isCurrentMonth ? 0.9 : 0.4,
                  );

        return GestureDetector(
          onTap: isDisabled ? null : () => _handleDateTap(date),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Stack(
              children: [
                if (isRange || isSelectedStart || isSelectedEnd)
                  Positioned.fill(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(
                          isRange ? 0.15 : 0.2,
                        ),
                        borderRadius: BorderRadius.horizontal(
                          left: isSelectedStart && !isSelectedEnd
                              ? const Radius.circular(999)
                              : Radius.zero,
                          right: isSelectedEnd && !isSelectedStart
                              ? const Radius.circular(999)
                              : Radius.zero,
                        ),
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.center,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isSelectedStart || isSelectedEnd
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
              ],
            ),
          ),
        );
      },
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
          color: colorScheme.onSurface.withOpacity(0.8),
        ),
      ],
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
        color: colorScheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.onSurface.withOpacity(0.15),
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
              color: colorScheme.onSurface.withOpacity(0.7),
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
                  : colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

