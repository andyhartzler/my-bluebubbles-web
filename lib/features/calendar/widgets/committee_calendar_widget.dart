import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/features/calendar/models/calendar_event.dart';
import 'package:bluebubbles/features/calendar/services/calendar_service.dart';
import 'package:bluebubbles/features/calendar/widgets/calendar_subscribe_button.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);

/// Modern calendar widget with brand color styling
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
  bool _isSyncing = false;
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

  /// Sync Google Calendar and refresh events
  Future<void> _syncGoogleCalendar() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      // Get auth token for the edge function
      final session = Supabase.instance.client.auth.currentSession;
      final accessToken = session?.accessToken;

      if (accessToken == null) {
        throw Exception('Not authenticated');
      }

      // Call the sync edge function
      final response = await http.post(
        Uri.parse('https://faajpcarasilbfndzkmd.supabase.co/functions/v1/sync-google-calendar'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Sync failed: ${response.body}');
      }

      // Reload events to reflect the sync
      await _loadEvents();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Calendar synced successfully'),
            backgroundColor: Color(0xFF43A047),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  /// Check if an event occurs on a given day (handles multi-day events)
  bool _eventOccursOnDay(CalendarEvent event, DateTime day) {
    final eventStart = event.startTime.toLocal();
    final eventEnd = event.endTime.toLocal();

    // Normalize dates to start of day for comparison
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final eventStartDay = DateTime(eventStart.year, eventStart.month, eventStart.day);
    final eventEndDay = DateTime(eventEnd.year, eventEnd.month, eventEnd.day);

    // For all-day events, check if day falls within the range
    if (event.allDay) {
      // All-day events: day is within [eventStartDay, eventEndDay)
      // Note: end time for all-day events is typically midnight of the day AFTER
      return !dayStart.isBefore(eventStartDay) && dayStart.isBefore(eventEndDay);
    }

    // For timed events spanning multiple days
    // Check if the day overlaps with the event's time range
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
    // Always use brand gradient styling (like other tiles)
    const isDark = true; // Force dark mode styling for gradient background

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_unityBlue, _momentumBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
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
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              )
            else if (_error != null)
              _buildError(isDark)
            else ...[
              _buildCalendarGrid(isDark),
              // Only show selected day events section if there are events
              if (_selectedDayEvents.isNotEmpty) ...[
                Divider(
                  height: 1,
                  color: Colors.white.withOpacity(0.1),
                ),
                _buildSelectedDayEvents(isDark),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Organization Events & Meetings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          CalendarSubscribeButton(
            committeeName: widget.committeeName,
            accentColor: Colors.white,
          ),
          const SizedBox(width: 8),
          // Sync/Refresh button
          FilledButton.icon(
            onPressed: _isSyncing ? null : _syncGoogleCalendar,
            icon: _isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh, size: 16),
            label: Text(
              _isSyncing ? 'Syncing...' : 'Sync',
              style: const TextStyle(fontSize: 13),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.white.withOpacity(0.15),
              disabledForegroundColor: Colors.white.withOpacity(0.7),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (widget.onAddEvent != null)
            FilledButton.icon(
              onPressed: widget.onAddEvent,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Event', style: TextStyle(fontSize: 13)),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previousMonth,
            icon: Icon(
              Icons.chevron_left_rounded,
              color: isDark ? Colors.white : _unityBlue,
            ),
            style: IconButton.styleFrom(
              backgroundColor:
                  isDark ? Colors.white.withOpacity(0.1) : _unityBlue.withOpacity(0.05),
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
                    color: isDark ? Colors.white : _unityBlue,
                  ),
                ),
                if (!isCurrentMonth) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
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
              color: isDark ? Colors.white : _unityBlue,
            ),
            style: IconButton.styleFrom(
              backgroundColor:
                  isDark ? Colors.white.withOpacity(0.1) : _unityBlue.withOpacity(0.05),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeaders(bool isDark) {
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
                        color: isDark
                            ? Colors.white.withOpacity(0.6)
                            : _unityBlue.withOpacity(0.6),
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

    // Calculate number of rows needed (typically 5-6 weeks)
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
          childAspectRatio: 1.0,
          mainAxisExtent: 80,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          final dayOffset = index - startWeekday;

          if (dayOffset < 0 || dayOffset >= daysInMonth) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.02) : _unityBlue.withOpacity(0.02),
                borderRadius: BorderRadius.circular(8),
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
            isDark: isDark,
            showEventNames: true, // Show event names on desktop
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
              color: isDark ? Colors.red.shade300 : Colors.red.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.red.shade300 : Colors.red.shade700,
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

  Widget _buildSelectedDayEvents(bool isDark) {
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : _unityBlue,
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    color: isDark
                        ? Colors.white.withOpacity(0.5)
                        : _unityBlue.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              shrinkWrap: true,
              itemCount: _selectedDayEvents.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
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
}

/// Calendar day cell widget
class _CalendarDayCell extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final List<CalendarEvent> events;
  final bool isDark;
  final bool showEventNames;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.events,
    required this.isDark,
    this.showEventNames = false,
    required this.onTap,
  });

  Color _getEventColor(CalendarEvent event) {
    // Check for Zoom meeting
    if (event.hasZoomMeeting) {
      return const Color(0xFF2D8CFF);
    }

    // Color by event type string
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
              ? (isDark ? _momentumBlue.withOpacity(0.3) : _momentumBlue.withOpacity(0.15))
              : isToday
                  ? _momentumBlue.withOpacity(0.08)
                  : isDark
                      ? Colors.white.withOpacity(0.03)
                      : _unityBlue.withOpacity(0.02),
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: _momentumBlue, width: 2)
              : Border.all(
                  color: isDark ? Colors.white.withOpacity(0.1) : _unityBlue.withOpacity(0.08),
                  width: 0.5,
                ),
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
                              : isDark
                                  ? Colors.white
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
            if (events.isNotEmpty && showEventNames) ...[
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
                          color: isDark ? Colors.white.withOpacity(0.9) : _unityBlue,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ] else if (events.isNotEmpty) ...[
              // Fallback to dots when not showing names
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: events.take(3).map((event) => Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: _getEventColor(event),
                        shape: BoxShape.circle,
                      ),
                    )).toList(),
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
  final bool isDark;

  const _EventCard({
    required this.event,
    required this.isDark,
  });

  bool get _isZoom => event.hasZoomMeeting;

  Color get _eventColor => _isZoom ? const Color(0xFF2D8CFF) : _momentumBlue;

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : _unityBlue.withOpacity(0.03),
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
                      color: isDark
                          ? Colors.white.withOpacity(0.5)
                          : _unityBlue.withOpacity(0.5),
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
                          color: isDark ? Colors.white : _unityBlue,
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
                            ? Colors.white.withOpacity(0.5)
                            : _unityBlue.withOpacity(0.5),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white.withOpacity(0.5)
                                : _unityBlue.withOpacity(0.6),
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

          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: isDark ? Colors.white.withOpacity(0.2) : _unityBlue.withOpacity(0.2),
          ),
        ],
      ),
    );
  }
}
