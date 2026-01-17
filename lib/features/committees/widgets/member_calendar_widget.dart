import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/calendar/models/calendar_event.dart';
import 'package:bluebubbles/features/calendar/services/calendar_service.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);

/// A styled calendar widget for the member hub that displays all organization events
/// Uses brand colors (unity blue, momentum blue) for consistent styling
class MemberCalendarWidget extends StatefulWidget {
  const MemberCalendarWidget({super.key});

  @override
  State<MemberCalendarWidget> createState() => _MemberCalendarWidgetState();
}

class _MemberCalendarWidgetState extends State<MemberCalendarWidget> {
  final CalendarService _calendarService = CalendarService();

  List<CalendarEvent> _events = [];
  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  List<CalendarEvent> _selectedDayEvents = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Fetch ALL events - no committee filter
      final events = await _calendarService.getEventsForMonth(
        _focusedMonth.year,
        _focusedMonth.month,
      );

      if (!mounted) return;
      setState(() {
        _events = events;
        _selectedDayEvents = _getEventsForDay(_selectedDate);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load events: $e';
        _loading = false;
      });
    }
  }

  /// Check if an event occurs on a given day (handles multi-day events)
  bool _eventOccursOnDay(CalendarEvent event, DateTime day) {
    final eventStart = event.startTime.toLocal();
    final eventEnd = event.endTime.toLocal();

    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final eventStartDay = DateTime(eventStart.year, eventStart.month, eventStart.day);
    final eventEndDay = DateTime(eventEnd.year, eventEnd.month, eventEnd.day);

    if (event.allDay) {
      return !dayStart.isBefore(eventStartDay) && dayStart.isBefore(eventEndDay);
    }

    return dayStart.isBefore(eventEnd) && dayEnd.isAfter(eventStart);
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    return _events.where((event) => _eventOccursOnDay(event, day)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
    _loadEvents();
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
    _loadEvents();
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedMonth = DateTime(now.year, now.month, 1);
      _selectedDate = now;
      _selectedDayEvents = _getEventsForDay(now);
    });
    _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _unityBlue.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildMonthNavigation(),
          _buildDayHeaders(),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_momentumBlue),
                ),
              ),
            )
          else if (_error != null)
            _buildError()
          else ...[
            _buildCalendarGrid(),
            Divider(height: 1, color: _unityBlue.withOpacity(0.1)),
            _buildSelectedDayEvents(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _momentumBlue.withOpacity(0.1),
            _momentumBlue.withOpacity(0.05),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _momentumBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: _momentumBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Organization Calendar',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: _unityBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthNavigation() {
    final theme = Theme.of(context);
    final monthFormat = DateFormat('MMMM yyyy');
    final now = DateTime.now();
    final isCurrentMonth =
        _focusedMonth.year == now.year && _focusedMonth.month == now.month;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previousMonth,
            icon: const Icon(Icons.chevron_left_rounded, color: _unityBlue),
            style: IconButton.styleFrom(
              backgroundColor: _unityBlue.withOpacity(0.05),
            ),
          ),
          GestureDetector(
            onTap: _goToToday,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  monthFormat.format(_focusedMonth),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _unityBlue,
                  ),
                ),
                if (!isCurrentMonth) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _momentumBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _momentumBlue,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: _nextMonth,
            icon: const Icon(Icons.chevron_right_rounded, color: _unityBlue),
            style: IconButton.styleFrom(
              backgroundColor: _unityBlue.withOpacity(0.05),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeaders() {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: days
            .map((day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _unityBlue.withOpacity(0.6),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final firstDayOfMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final startWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0

    final today = DateTime.now();

    final totalCells = startWeekday + daysInMonth;
    final rowCount = (totalCells / 7).ceil();
    final itemCount = rowCount * 7;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          mainAxisExtent: 72,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          final dayOffset = index - startWeekday;

          if (dayOffset < 0 || dayOffset >= daysInMonth) {
            return Container(
              decoration: BoxDecoration(
                color: _unityBlue.withOpacity(0.02),
                borderRadius: BorderRadius.circular(6),
              ),
            );
          }

          final date =
              DateTime(_focusedMonth.year, _focusedMonth.month, dayOffset + 1);
          final isToday = date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;
          final isSelected = date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;
          final dayEvents = _getEventsForDay(date);

          return _CalendarDayCell(
            date: date,
            isToday: isToday,
            isSelected: isSelected,
            events: dayEvents,
            onTap: () {
              setState(() {
                _selectedDate = date;
                _selectedDayEvents = dayEvents;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadEvents,
              icon: const Icon(Icons.refresh, color: _momentumBlue),
              label: const Text('Retry', style: TextStyle(color: _momentumBlue)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDayEvents() {
    final theme = Theme.of(context);
    final dayFormat = DateFormat('EEEE, MMMM d');
    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Text(
                  dayFormat.format(_selectedDate),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _unityBlue,
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _momentumBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '${_selectedDayEvents.length} event${_selectedDayEvents.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _unityBlue.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          if (_selectedDayEvents.isEmpty)
            _buildEmptyState()
          else
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                shrinkWrap: true,
                itemCount: _selectedDayEvents.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _EventCard(event: _selectedDayEvents[index]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 40,
              color: _unityBlue.withOpacity(0.2),
            ),
            const SizedBox(height: 12),
            Text(
              'No events scheduled',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _unityBlue.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Calendar day cell widget with brand colors
class _CalendarDayCell extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final List<CalendarEvent> events;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.events,
    required this.onTap,
  });

  Color _getEventColor(CalendarEvent event) {
    if (event.hasZoomMeeting) {
      return const Color(0xFF2D8CFF);
    }

    switch (event.eventType) {
      case 'committee':
        return _momentumBlue;
      case 'executive':
        return const Color(0xFF8B5CF6);
      case 'social':
        return const Color(0xFFF59E0B);
      case 'deadline':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected
              ? _momentumBlue.withOpacity(0.15)
              : isToday
                  ? _momentumBlue.withOpacity(0.08)
                  : _unityBlue.withOpacity(0.02),
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: _momentumBlue, width: 2)
              : Border.all(color: _unityBlue.withOpacity(0.08), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day number row
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: isToday
                      ? BoxDecoration(
                          color: _momentumBlue,
                          borderRadius: BorderRadius.circular(11),
                        )
                      : null,
                  child: Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isToday
                          ? Colors.white
                          : isSelected
                              ? _momentumBlue
                              : _unityBlue,
                    ),
                  ),
                ),
                if (events.length > 2) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: _momentumBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '+${events.length - 2}',
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: _momentumBlue,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            // Events area
            if (events.isNotEmpty) ...[
              const SizedBox(height: 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: events.take(2).map((event) {
                    final eventColor = _getEventColor(event);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: eventColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3),
                        border: Border(
                          left: BorderSide(color: eventColor, width: 2),
                        ),
                      ),
                      child: Text(
                        event.title,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: _unityBlue,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Event card widget with brand colors
class _EventCard extends StatelessWidget {
  final CalendarEvent event;

  const _EventCard({required this.event});

  bool get _isZoom => event.hasZoomMeeting;

  Color get _eventColor => _isZoom ? const Color(0xFF2D8CFF) : _momentumBlue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('h:mm a');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _unityBlue.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: _eventColor,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          // Time column
          SizedBox(
            width: 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.allDay
                      ? 'All Day'
                      : timeFormat.format(event.startTime.toLocal()),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _eventColor,
                  ),
                ),
                if (!event.allDay)
                  Text(
                    timeFormat.format(event.endTime.toLocal()),
                    style: TextStyle(
                      fontSize: 11,
                      color: _unityBlue.withOpacity(0.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Event details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: _unityBlue,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isZoom) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D8CFF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.videocam, size: 10, color: Colors.white),
                            SizedBox(width: 2),
                            Text(
                              'Zoom',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                if (event.location != null && event.location!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: _unityBlue.withOpacity(0.5),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _unityBlue.withOpacity(0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (event.committeeName != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _momentumBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      event.committeeName!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _momentumBlue,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
