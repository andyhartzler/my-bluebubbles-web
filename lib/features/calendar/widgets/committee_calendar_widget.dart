import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/calendar/models/calendar_event.dart';
import 'package:bluebubbles/features/calendar/services/calendar_service.dart';
import 'package:bluebubbles/features/calendar/widgets/calendar_subscribe_button.dart';

/// Modern calendar widget with proper dark mode support
class CommitteeCalendarWidget extends StatefulWidget {
  final String? committeeName;
  final Color? accentColor;
  final VoidCallback? onAddEvent;

  const CommitteeCalendarWidget({
    super.key,
    this.committeeName,
    this.accentColor,
    this.onAddEvent,
  });

  @override
  State<CommitteeCalendarWidget> createState() => _CommitteeCalendarWidgetState();
}

class _CommitteeCalendarWidgetState extends State<CommitteeCalendarWidget> {
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
      // Fetch ALL events - no committee filter!
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

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    return _events.where((event) {
      final eventDate = event.startTime.toLocal();
      return eventDate.year == day.year &&
          eventDate.month == day.month &&
          eventDate.day == day.day;
    }).toList()
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDark),
          _buildMonthNavigation(isDark),
          _buildDayHeaders(isDark),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _buildError(isDark)
          else ...[
            _buildCalendarGrid(isDark),
            Divider(
              height: 1,
              color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E7EB),
            ),
            _buildSelectedDayEvents(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: Color(0xFF3B82F6),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MOYD Calendar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  'Organization Events & Meetings',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF98989F)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          CalendarSubscribeButton(
            committeeName: widget.committeeName,
            accentColor: widget.accentColor,
          ),
          const SizedBox(width: 8),
          if (widget.onAddEvent != null)
            FilledButton.icon(
              onPressed: widget.onAddEvent,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Event', style: TextStyle(fontSize: 13)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthNavigation(bool isDark) {
    final monthFormat = DateFormat('MMMM yyyy');
    final now = DateTime.now();
    final isCurrentMonth = _focusedMonth.year == now.year &&
        _focusedMonth.month == now.month;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previousMonth,
            icon: Icon(
              Icons.chevron_left_rounded,
              color: isDark ? Colors.white : const Color(0xFF374151),
            ),
            style: IconButton.styleFrom(
              backgroundColor:
                  isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6),
            ),
          ),
          GestureDetector(
            onTap: _goToToday,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  monthFormat.format(_focusedMonth),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                if (!isCurrentMonth) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: _nextMonth,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white : const Color(0xFF374151),
            ),
            style: IconButton.styleFrom(
              backgroundColor:
                  isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeaders(bool isDark) {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: days
            .map((day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFF98989F)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(bool isDark) {
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final firstDayOfMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final startWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0

    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          childAspectRatio: 1.0,
        ),
        itemCount: 42,
        itemBuilder: (context, index) {
          final dayOffset = index - startWeekday;

          if (dayOffset < 0 || dayOffset >= daysInMonth) {
            return const SizedBox();
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
            isDark: isDark,
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

  Widget _buildError(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: isDark ? const Color(0xFFFF6B6B) : Colors.red.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? const Color(0xFFFF6B6B) : Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadEvents,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDayEvents(bool isDark) {
    final dayFormat = DateFormat('EEEE, MMMM d');
    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return Container(
      constraints: const BoxConstraints(maxHeight: 320),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  dayFormat.format(_selectedDate),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 11,
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
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF98989F)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          if (_selectedDayEvents.isEmpty)
            _buildEmptyState(isDark)
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _selectedDayEvents.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _EventCard(
                      event: _selectedDayEvents[index],
                      isDark: isDark,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 40,
              color:
                  isDark ? const Color(0xFF48484A) : const Color(0xFFD1D5DB),
            ),
            const SizedBox(height: 12),
            Text(
              'No events scheduled',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? const Color(0xFF98989F)
                    : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap "Add Event" to create one',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? const Color(0xFF636366)
                    : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Calendar day cell widget
class _CalendarDayCell extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final List<CalendarEvent> events;
  final bool isDark;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.events,
    required this.isDark,
    required this.onTap,
  });

  Color _getEventColor(CalendarEvent event) {
    // Check for Zoom meeting
    if (event.zoomMeetingId != null || event.location?.contains('zoom') == true) {
      return const Color(0xFF2D8CFF);
    }

    // Color by event type
    switch (event.eventType) {
      case EventType.committee:
        return const Color(0xFF3B82F6);
      case EventType.executive:
        return const Color(0xFF8B5CF6);
      case EventType.social:
        return const Color(0xFFF59E0B);
      case EventType.deadline:
        return const Color(0xFFEF4444);
      case EventType.general:
        return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E3A5F) : const Color(0xFFDBEAFE))
              : isToday
                  ? const Color(0xFF3B82F6)
                  : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              date.day.toString(),
              style: TextStyle(
                fontSize: 15,
                fontWeight:
                    isToday || isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isToday
                    ? Colors.white
                    : isSelected
                        ? const Color(0xFF3B82F6)
                        : isDark
                            ? Colors.white
                            : const Color(0xFF1A1A1A),
              ),
            ),
            if (events.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...events.take(3).map((event) => Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: isToday ? Colors.white : _getEventColor(event),
                          shape: BoxShape.circle,
                        ),
                      )),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Event card widget
class _EventCard extends StatelessWidget {
  final CalendarEvent event;
  final bool isDark;

  const _EventCard({
    required this.event,
    required this.isDark,
  });

  bool get _isZoom =>
      event.zoomMeetingId != null || event.location?.contains('zoom') == true;

  Color get _eventColor => _isZoom ? const Color(0xFF2D8CFF) : const Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
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
                      color: isDark
                          ? const Color(0xFF98989F)
                          : const Color(0xFF9CA3AF),
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
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isZoom) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D8CFF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.videocam,
                                size: 10, color: Colors.white),
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
                        color: isDark
                            ? const Color(0xFF98989F)
                            : const Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF98989F)
                                : const Color(0xFF6B7280),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      event.committeeName!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: isDark ? const Color(0xFF48484A) : const Color(0xFFD1D5DB),
          ),
        ],
      ),
    );
  }
}
