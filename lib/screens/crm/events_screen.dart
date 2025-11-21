import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/models/crm/event.dart';
import 'package:bluebubbles/screens/crm/event_detail_screen.dart';
import 'package:bluebubbles/services/crm/event_repository.dart';

const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _sunriseGold = Color(0xFFFDB813);
const _actionRed = Color(0xFFE63946);
const _justicePurple = Color(0xFF6A1B9A);
const _grassrootsGreen = Color(0xFF43A047);

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final EventRepository _repository = EventRepository();
  final TextEditingController _searchController = TextEditingController();

  List<Event> _events = [];
  bool _loading = true;
  String? _error;
  String? _statusFilter;
  String? _typeFilter;
  bool _showUpcoming = true;
  bool _showPast = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    if (!_repository.isReady) {
      setState(() {
        _loading = false;
        _error = 'CRM Supabase is not configured. Add Supabase credentials to enable Events.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final events = await _repository.fetchEvents(
        searchQuery: _searchController.text,
        status: _statusFilter,
        eventType: _typeFilter,
        upcomingOnly: _showUpcoming && !_showPast,
        pastOnly: _showPast && !_showUpcoming,
      );

      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _openEvent(Event event) {
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (context) => TitleBarWrapper(
          child: EventDetailScreen(initialEvent: event),
        ),
      ),
    ).then((_) => _loadEvents());
  }

  void _createEvent() {
    final now = DateTime.now();
    final newEvent = Event(
      title: 'Untitled Event',
      description: '',
      eventDate: now.add(const Duration(days: 1)),
      eventEndDate: now.add(const Duration(days: 1, hours: 2)),
      rsvpEnabled: true,
      checkinEnabled: false,
      status: 'draft',
    );
    _openEvent(newEvent);
  }

  Widget _buildStatusChip(String status) {
    Color background;
    switch (status) {
      case 'published':
        background = _grassrootsGreen.withOpacity(0.18);
        break;
      case 'cancelled':
        background = _actionRed.withOpacity(0.18);
        break;
      default:
        background = _sunriseGold.withOpacity(0.18);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(status.toUpperCase()),
    );
  }

  Widget _buildEventCard(Event event) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd().add_jm();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () => _openEvent(event),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  _buildStatusChip(event.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                dateFormat.format(event.eventDate),
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (event.location?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 18),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.location!,
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _buildInfoChip(Icons.category_outlined, event.eventType ?? 'Other'),
                  _buildInfoChip(Icons.event_available_outlined, event.rsvpEnabled ? 'RSVPs on' : 'RSVPs off'),
                  _buildInfoChip(Icons.verified_outlined, event.checkinEnabled ? 'Check-in on' : 'Check-in off'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _unityBlue.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _unityBlue),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 220,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search events',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onSubmitted: (_) => _loadEvents(),
          ),
        ),
        DropdownButton<String?>(
          value: _statusFilter,
          hint: const Text('Status'),
          items: const [
            DropdownMenuItem(value: null, child: Text('Any status')),
            DropdownMenuItem(value: 'draft', child: Text('Draft')),
            DropdownMenuItem(value: 'published', child: Text('Published')),
            DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
          ],
          onChanged: (value) => setState(() {
            _statusFilter = value;
          }),
        ),
        DropdownButton<String?>(
          value: _typeFilter,
          hint: const Text('Type'),
          items: const [
            DropdownMenuItem(value: null, child: Text('Any type')),
            DropdownMenuItem(value: 'meeting', child: Text('Meeting')),
            DropdownMenuItem(value: 'rally', child: Text('Rally')),
            DropdownMenuItem(value: 'fundraiser', child: Text('Fundraiser')),
            DropdownMenuItem(value: 'social', child: Text('Social')),
            DropdownMenuItem(value: 'other', child: Text('Other')),
          ],
          onChanged: (value) => setState(() {
            _typeFilter = value;
          }),
        ),
        FilterChip(
          label: const Text('Upcoming'),
          selected: _showUpcoming,
          onSelected: (value) => setState(() {
            _showUpcoming = value;
            if (value) _showPast = false;
          }),
          selectedColor: _momentumBlue.withOpacity(0.18),
        ),
        FilterChip(
          label: const Text('Past'),
          selected: _showPast,
          onSelected: (value) => setState(() {
            _showPast = value;
            if (value) _showUpcoming = false;
          }),
          selectedColor: _justicePurple.withOpacity(0.18),
        ),
        ElevatedButton.icon(
          onPressed: _loadEvents,
          icon: const Icon(Icons.filter_alt),
          label: const Text('Apply'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _statusFilter = null;
              _typeFilter = null;
              _showUpcoming = true;
              _showPast = false;
              _searchController.clear();
            });
            _loadEvents();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Reset'),
        ),
        ElevatedButton.icon(
          onPressed: _createEvent,
          style: ElevatedButton.styleFrom(backgroundColor: _unityBlue, foregroundColor: Colors.white),
          icon: const Icon(Icons.add),
          label: const Text('Create New Event'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_repository.isReady) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('CRM Supabase is not configured. Provide credentials to manage events.'),
        ),
      );
    }

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Events',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _unityBlue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.event_available_outlined, color: _momentumBlue),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Manage events, check-in attendees, and keep RSVPs organized.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              _buildFilters(),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text(_error!))
                        : _events.isEmpty
                            ? const Center(child: Text('No events found.'))
                            : ListView.separated(
                                itemCount: _events.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) => _buildEventCard(_events[index]),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
