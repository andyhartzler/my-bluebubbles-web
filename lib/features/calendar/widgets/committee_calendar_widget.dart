import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/calendar/models/calendar_event.dart';
import 'package:bluebubbles/features/calendar/services/calendar_service.dart';
import 'package:bluebubbles/features/calendar/widgets/calendar_event_card.dart';
import 'package:bluebubbles/features/calendar/widgets/calendar_subscribe_button.dart';
import 'package:bluebubbles/features/calendar/widgets/month_view_calendar.dart';

/// Main calendar widget for committee pages
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
  DateTime? _selectedDate;
  bool _loading = true;
  String? _error;

  int _currentYear = DateTime.now().year;
  int _currentMonth = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final events = await _calendarService.getEventsForMonth(
        _currentYear,
        _currentMonth,
        committeeName: widget.committeeName,
      );

      if (!mounted) return;
      setState(() {
        _events = events;
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

  void _onMonthChanged(int year, int month) {
    _currentYear = year;
    _currentMonth = month;
    _loadEvents();
  }

  List<CalendarEvent> get _eventsForSelectedDate {
    if (_selectedDate == null) return [];
    return _events.where((event) {
      final eventDate = event.startTime.toLocal();
      return eventDate.year == _selectedDate!.year &&
          eventDate.month == _selectedDate!.month &&
          eventDate.day == _selectedDate!.day;
    }).toList();
  }

  List<CalendarEvent> get _upcomingEvents {
    final now = DateTime.now();
    return _events
        .where((event) => event.startTime.isAfter(now))
        .take(5)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.accentColor ?? theme.colorScheme.primary;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(theme, color),

            const SizedBox(height: 16),

            // Content
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              _buildError()
            else
              _buildContent(theme, color),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Color color) {
    return Row(
      children: [
        Icon(Icons.calendar_month, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Calendar',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        CalendarSubscribeButton(
          committeeName: widget.committeeName,
          accentColor: color,
        ),
        const SizedBox(width: 8),
        if (widget.onAddEvent != null)
          FilledButton.icon(
            onPressed: widget.onAddEvent,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Event'),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade700),
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

  Widget _buildContent(ThemeData theme, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month calendar view
        MonthViewCalendar(
          events: _events,
          accentColor: color,
          onDaySelected: (date) {
            setState(() {
              _selectedDate = date;
            });
          },
          onMonthChanged: _onMonthChanged,
        ),

        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 16),

        // Selected day events or upcoming events
        if (_selectedDate != null && _eventsForSelectedDate.isNotEmpty)
          _buildSelectedDayEvents(theme, color)
        else if (_upcomingEvents.isNotEmpty)
          _buildUpcomingEvents(theme, color)
        else
          _buildEmptyState(theme, color),
      ],
    );
  }

  Widget _buildSelectedDayEvents(ThemeData theme, Color color) {
    final dateFormat = DateFormat('EEEE, MMMM d');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.event, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              dateFormat.format(_selectedDate!),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_eventsForSelectedDate.length} event${_eventsForSelectedDate.length != 1 ? 's' : ''}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._eventsForSelectedDate.map((event) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CalendarEventCard(
                event: event,
                accentColor: color,
                compact: true,
              ),
            )),
      ],
    );
  }

  Widget _buildUpcomingEvents(ThemeData theme, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.upcoming, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              'Upcoming Events',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._upcomingEvents.map((event) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CalendarEventCard(
                event: event,
                accentColor: color,
              ),
            )),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_available,
            size: 48,
            color: color.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No events scheduled',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add events to your calendar to get started',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
