import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/calendar/models/calendar_event.dart';

/// A month view calendar widget that displays events
class MonthViewCalendar extends StatefulWidget {
  final DateTime? initialDate;
  final List<CalendarEvent> events;
  final Color? accentColor;
  final void Function(DateTime date)? onDaySelected;
  final void Function(CalendarEvent event)? onEventTap;
  final void Function(int year, int month)? onMonthChanged;
  final bool showEventIndicators;

  const MonthViewCalendar({
    super.key,
    this.initialDate,
    this.events = const [],
    this.accentColor,
    this.onDaySelected,
    this.onEventTap,
    this.onMonthChanged,
    this.showEventIndicators = true,
  });

  @override
  State<MonthViewCalendar> createState() => _MonthViewCalendarState();
}

class _MonthViewCalendarState extends State<MonthViewCalendar> {
  late DateTime _currentMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = widget.initialDate ?? DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    _selectedDate = now;
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
    widget.onMonthChanged?.call(_currentMonth.year, _currentMonth.month);
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
    widget.onMonthChanged?.call(_currentMonth.year, _currentMonth.month);
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _currentMonth = DateTime(now.year, now.month, 1);
      _selectedDate = now;
    });
    widget.onMonthChanged?.call(_currentMonth.year, _currentMonth.month);
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    return widget.events.where((event) {
      final eventDate = event.startTime.toLocal();
      return eventDate.year == day.year &&
          eventDate.month == day.month &&
          eventDate.day == day.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.accentColor ?? theme.colorScheme.primary;

    return Column(
      children: [
        // Header with month navigation
        _buildHeader(theme, color),
        const SizedBox(height: 12),

        // Weekday labels
        _buildWeekdayLabels(theme),
        const SizedBox(height: 8),

        // Calendar grid
        _buildCalendarGrid(theme, color),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme, Color color) {
    final monthFormat = DateFormat('MMMM yyyy');
    final now = DateTime.now();
    final isCurrentMonth = _currentMonth.year == now.year &&
        _currentMonth.month == now.month;

    return Row(
      children: [
        IconButton(
          onPressed: _previousMonth,
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous month',
        ),
        Expanded(
          child: Text(
            monthFormat.format(_currentMonth),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        if (!isCurrentMonth)
          TextButton(
            onPressed: _goToToday,
            child: const Text('Today'),
          ),
        IconButton(
          onPressed: _nextMonth,
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next month',
        ),
      ],
    );
  }

  Widget _buildWeekdayLabels(ThemeData theme) {
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Row(
      children: weekdays.map((day) {
        return Expanded(
          child: Text(
            day,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid(ThemeData theme, Color color) {
    final firstDayOfMonth = _currentMonth;
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0
    final daysInMonth = lastDayOfMonth.day;

    final today = DateTime.now();
    final isCurrentMonth = _currentMonth.year == today.year &&
        _currentMonth.month == today.month;

    // Calculate total cells needed (6 rows max)
    final totalCells = 42;
    final days = <Widget>[];

    for (var i = 0; i < totalCells; i++) {
      final dayNumber = i - firstWeekday + 1;

      if (dayNumber < 1 || dayNumber > daysInMonth) {
        // Empty cell for days outside the month
        days.add(const SizedBox());
      } else {
        final day = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
        final events = _getEventsForDay(day);
        final isToday = isCurrentMonth && dayNumber == today.day;
        final isSelected = _selectedDate != null &&
            _selectedDate!.year == day.year &&
            _selectedDate!.month == day.month &&
            _selectedDate!.day == day.day;

        days.add(_buildDayCell(theme, color, day, dayNumber, events, isToday, isSelected));
      }
    }

    // Build rows
    final rows = <Widget>[];
    for (var i = 0; i < 6; i++) {
      final rowDays = days.sublist(i * 7, (i + 1) * 7);

      // Skip row if all cells are empty (last row sometimes)
      if (i > 4 && rowDays.every((w) => w is SizedBox)) {
        continue;
      }

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: rowDays.map((day) => Expanded(child: day)).toList(),
          ),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildDayCell(
    ThemeData theme,
    Color color,
    DateTime day,
    int dayNumber,
    List<CalendarEvent> events,
    bool isToday,
    bool isSelected,
  ) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDate = day;
        });
        widget.onDaySelected?.call(day);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.1)
              : isToday
                  ? color.withOpacity(0.05)
                  : null,
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: color, width: 1.5)
              : isSelected
                  ? Border.all(color: color.withOpacity(0.5))
                  : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Day number
            Text(
              dayNumber.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: isToday || isSelected ? FontWeight.bold : null,
                color: isToday ? color : null,
              ),
            ),

            // Event indicators
            if (widget.showEventIndicators && events.isNotEmpty) ...[
              const SizedBox(height: 2),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 2,
                runSpacing: 2,
                children: events.take(3).map((event) {
                  return Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _getEventColor(event, theme),
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              ),
              if (events.length > 3)
                Text(
                  '+${events.length - 3}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 8,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getEventColor(CalendarEvent event, ThemeData theme) {
    switch (event.eventType) {
      case EventType.committee:
        return Colors.blue;
      case EventType.executive:
        return Colors.purple;
      case EventType.social:
        return Colors.orange;
      case EventType.deadline:
        return Colors.red;
      case EventType.general:
        return widget.accentColor ?? theme.colorScheme.primary;
    }
  }
}
