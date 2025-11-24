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
  bool _showPast = true;

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
    final locationLabel = event.multipleLocations
        ? event.location
        : event.location?.isNotEmpty == true
            ? event.location
            : event.locationAddress;
    final heroImage = event.websiteImages.isNotEmpty ? event.websiteImages.first : null;

    return Card(
      elevation: 6,
      color: Colors.grey.shade900,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: () => _openEvent(event),
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: heroImage != null
                  ? AspectRatio(
                      aspectRatio: 1080 / 1350,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          image: DecorationImage(
                            image: NetworkImage(heroImage.url),
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            onError: (_, __) {},
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.black,
                      height: 260,
                      child: const Center(
                        child: Icon(Icons.image_not_supported_outlined, color: Colors.white54, size: 48),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildStatusChip(event.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dateFormat.format(event.eventDate),
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                  if (locationLabel?.isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.place_outlined, size: 18, color: Colors.white70),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            locationLabel!,
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(Icons.category_outlined, event.eventType ?? 'Other'),
                      _buildInfoChip(
                          Icons.event_available_outlined, event.rsvpEnabled ? 'RSVPs on' : 'RSVPs off'),
                      _buildInfoChip(Icons.verified_outlined, event.checkinEnabled ? 'Check-in on' : 'Check-in off'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white),
          ),
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
          }),
          selectedColor: _momentumBlue.withOpacity(0.18),
        ),
        FilterChip(
          label: const Text('Past'),
          selected: _showPast,
          onSelected: (value) => setState(() {
            _showPast = value;
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
              _showPast = true;
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!));
    }

    return Container(
      color: Colors.black,
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _momentumBlue,
                      ),
                      child: const Icon(
                        Icons.event_available_outlined,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Events',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'View upcoming and past gatherings.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: const SliverToBoxAdapter(child: SizedBox(height: 18)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              sliver: SliverToBoxAdapter(
                child: _buildFilters(),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: _events.isEmpty
                  ? const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'No events found.',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final event = _events[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == _events.length - 1 ? 0 : 12,
                            ),
                            child: _buildEventCard(event),
                          );
                        },
                        childCount: _events.length,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
