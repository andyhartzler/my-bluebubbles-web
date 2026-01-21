import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/features/calendar/models/calendar_event.dart';
import 'package:bluebubbles/features/calendar/services/calendar_service.dart';
import 'package:bluebubbles/features/calendar/widgets/event_create_dialog.dart';

// Brand colors matching desktop calendar
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);

/// iOS Calendar-style mobile view with swipeable week strip
class MobileCalendarView extends StatefulWidget {
  final String? committeeName;
  final VoidCallback? onAddEvent;

  const MobileCalendarView({
    super.key,
    this.committeeName,
    this.onAddEvent,
  });

  @override
  State<MobileCalendarView> createState() => _MobileCalendarViewState();
}

class _MobileCalendarViewState extends State<MobileCalendarView> {
  final CalendarService _calendarService = CalendarService();
  late PageController _weekController;
  late DateTime _selectedDate;
  late DateTime _focusedWeek;
  List<CalendarEvent> _events = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _focusedWeek = _getWeekStart(_selectedDate);
    _weekController = PageController(initialPage: 1000);
    _loadEvents();
  }

  @override
  void dispose() {
    _weekController.dispose();
    super.dispose();
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday % 7));
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load events for current month and surrounding months
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month - 1, 1);
      final endDate = DateTime(now.year, now.month + 2, 0);

      final events = await _calendarService.getAllEvents(
        startDate: startDate,
        endDate: endDate,
      );

      if (!mounted) return;
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load events: $e';
        _isLoading = false;
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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

  bool _hasEventsOnDay(DateTime day) {
    return _events.any((e) => _eventOccursOnDay(e, day));
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    return _events
        .where((e) => _eventOccursOnDay(e, day))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = now;
      _focusedWeek = _getWeekStart(now);
    });
    _weekController.animateToPage(
      1000,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _showCreateEventDialog() async {
    final event = await EventCreateDialog.show(
      context,
      committeeName: widget.committeeName,
    );

    if (event != null && mounted) {
      _loadEvents();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Event "${event.title}" created')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dayEvents = _getEventsForDay(_selectedDate);

    // Calculate dynamic height based on content
    // Header (~90) + Week strip (90) + divider (1) + day header (~50) + events
    const baseHeight = 231.0; // Header + week strip + divider + day header
    const eventCardHeight = 120.0; // Approximate height per event card
    const emptyStateHeight = 150.0;
    const maxEventsToShow = 3;

    final eventsHeight = dayEvents.isEmpty
        ? emptyStateHeight
        : (dayEvents.length.clamp(1, maxEventsToShow) * eventCardHeight);
    final totalHeight = baseHeight + eventsHeight;

    // Use brand gradient styling like desktop calendar
    // Always use dark mode styling since gradient background is dark
    const useDarkStyling = true;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        height: totalHeight,
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
            // Header with month/year - use dark styling for gradient bg
            _buildHeader(useDarkStyling),

            // Scrollable week strip - use dark styling for gradient bg
            _buildWeekStrip(useDarkStyling),

            Divider(
              height: 1,
              color: Colors.white.withOpacity(0.1),
            ),

            // Events list - use dark styling for gradient bg
            Expanded(
              child: _buildEventsList(useDarkStyling),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final monthFormat = DateFormat('MMMM yyyy');

    // With gradient background, use white/light colors for all elements
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Events & Meetings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      monthFormat.format(_selectedDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _goToToday,
                child: Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Sync/Refresh button
              IconButton(
                onPressed: _isSyncing ? null : _syncGoogleCalendar,
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isSyncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.refresh, color: Colors.white, size: 18),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Sync Calendar',
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: widget.onAddEvent ?? _showCreateEventDialog,
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 18),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStrip(bool isDark) {
    return SizedBox(
      height: 90,
      child: PageView.builder(
        controller: _weekController,
        onPageChanged: (index) {
          final weeksDiff = index - 1000;
          final newWeek = DateTime.now().add(Duration(days: weeksDiff * 7));
          setState(() {
            _focusedWeek = _getWeekStart(newWeek);
          });
        },
        itemBuilder: (context, index) {
          final weeksDiff = index - 1000;
          final weekStart =
              _getWeekStart(DateTime.now()).add(Duration(days: weeksDiff * 7));

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (dayIndex) {
                final date = weekStart.add(Duration(days: dayIndex));
                return _WeekDayCell(
                  date: date,
                  isSelected: _isSameDay(date, _selectedDate),
                  isToday: _isSameDay(date, DateTime.now()),
                  hasEvents: _hasEventsOnDay(date),
                  isDark: isDark,
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                    });
                  },
                );
              }),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEventsList(bool isDark) {
    final dayEvents = _getEventsForDay(_selectedDate);
    final dayFormat = DateFormat('EEEE, MMMM d');

    // With gradient background, use white-based colors
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 40, color: Colors.red.shade300),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade300),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _loadEvents,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                dayFormat.format(_selectedDate),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              // Only show event count when there are events
              if (dayEvents.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${dayEvents.length} event${dayEvents.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: dayEvents.isEmpty
              ? const SizedBox.shrink()
              : RefreshIndicator(
                  onRefresh: _loadEvents,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: dayEvents.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MobileEventCard(
                          event: dayEvents[index],
                          isDark: isDark,
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    // With gradient background, use white-based colors
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note_outlined,
            size: 56,
            color: Colors.white.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No Events',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to add an event',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Week day cell for the horizontal scrolling week strip
class _WeekDayCell extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final bool hasEvents;
  final bool isDark;
  final VoidCallback onTap;

  const _WeekDayCell({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.hasEvents,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const dayNames = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    // With gradient background, use white-based colors
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.25) : null,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dayNames[date.weekday % 7],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isToday && !isSelected
                    ? Colors.white.withOpacity(0.2)
                    : null,
                shape: BoxShape.circle,
                border: isToday
                    ? Border.all(color: Colors.white.withOpacity(0.5), width: 2)
                    : null,
              ),
              child: Center(
                child: Text(
                  date.day.toString(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        isToday || isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: hasEvents
                    ? Colors.white
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mobile-optimized event card
class _MobileEventCard extends StatelessWidget {
  final CalendarEvent event;
  final bool isDark;

  const _MobileEventCard({
    required this.event,
    required this.isDark,
  });

  bool get _isZoom => event.hasZoomMeeting;

  Color get _eventColor =>
      _isZoom ? const Color(0xFF2D8CFF) : Colors.white;

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');

    // With gradient background, use semi-transparent white cards
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Color bar
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: _eventColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      event.allDay
                          ? 'All Day'
                          : '${timeFormat.format(event.startTime.toLocal())} - ${timeFormat.format(event.endTime.toLocal())}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _eventColor,
                      ),
                    ),
                    if (_isZoom) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D8CFF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.videocam, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Zoom',
                              style: TextStyle(
                                fontSize: 11,
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
                const SizedBox(height: 4),
                // With gradient background, use white text
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (event.location != null && event.location!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (event.committeeName != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      event.committeeName!,
                      style: const TextStyle(
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
        ],
      ),
    );
  }
}
