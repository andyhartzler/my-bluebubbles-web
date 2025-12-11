import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/event.dart' show Event;
import 'package:bluebubbles/models/crm/chapter.dart';
import 'package:bluebubbles/models/crm/donor.dart';

/// Entity type for picker dialog
enum EntityPickerType {
  member,
  event,
  chapter,
  donor,
}

/// Dialog for picking an entity to add to the canvas
class EntityPickerDialog<T> extends StatefulWidget {
  final EntityPickerType type;
  final Future<List<T>> Function(String query) searchFunction;
  final void Function(T entity) onEntitySelected;

  const EntityPickerDialog({
    super.key,
    required this.type,
    required this.searchFunction,
    required this.onEntitySelected,
  });

  @override
  State<EntityPickerDialog<T>> createState() => _EntityPickerDialogState<T>();

  /// Show a member picker dialog
  static Future<Member?> showMemberPicker(
    BuildContext context, {
    required Future<List<Member>> Function(String query) searchFunction,
  }) async {
    Member? selectedMember;
    await showDialog(
      context: context,
      builder: (context) => EntityPickerDialog<Member>(
        type: EntityPickerType.member,
        searchFunction: searchFunction,
        onEntitySelected: (member) {
          selectedMember = member;
          Navigator.pop(context);
        },
      ),
    );
    return selectedMember;
  }

  /// Show an event picker dialog
  static Future<Event?> showEventPicker(
    BuildContext context, {
    required Future<List<Event>> Function(String query) searchFunction,
    VoidCallback? onCreateNew,
  }) async {
    Event? selectedEvent;
    await showDialog(
      context: context,
      builder: (context) => _EventPickerDialog(
        searchFunction: searchFunction,
        onEntitySelected: (event) {
          selectedEvent = event;
          Navigator.pop(context);
        },
        onCreateNew: onCreateNew,
      ),
    );
    return selectedEvent;
  }

  /// Show a chapter picker dialog
  static Future<Chapter?> showChapterPicker(
    BuildContext context, {
    required Future<List<Chapter>> Function(String query) searchFunction,
  }) async {
    Chapter? selectedChapter;
    await showDialog(
      context: context,
      builder: (context) => EntityPickerDialog<Chapter>(
        type: EntityPickerType.chapter,
        searchFunction: searchFunction,
        onEntitySelected: (chapter) {
          selectedChapter = chapter;
          Navigator.pop(context);
        },
      ),
    );
    return selectedChapter;
  }

  /// Show a donor picker dialog
  static Future<Donor?> showDonorPicker(
    BuildContext context, {
    required Future<List<Donor>> Function(String query) searchFunction,
  }) async {
    Donor? selectedDonor;
    await showDialog(
      context: context,
      builder: (context) => EntityPickerDialog<Donor>(
        type: EntityPickerType.donor,
        searchFunction: searchFunction,
        onEntitySelected: (donor) {
          selectedDonor = donor;
          Navigator.pop(context);
        },
      ),
    );
    return selectedDonor;
  }
}

class _EntityPickerDialogState<T> extends State<EntityPickerDialog<T>> {
  final _searchController = TextEditingController();
  List<T> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  String get _title {
    switch (widget.type) {
      case EntityPickerType.member:
        return 'Select Member';
      case EntityPickerType.event:
        return 'Select Event';
      case EntityPickerType.chapter:
        return 'Select Chapter';
      case EntityPickerType.donor:
        return 'Select Donor';
    }
  }

  String get _hint {
    switch (widget.type) {
      case EntityPickerType.member:
        return 'Search by name or email...';
      case EntityPickerType.event:
        return 'Search by event title...';
      case EntityPickerType.chapter:
        return 'Search by chapter name...';
      case EntityPickerType.donor:
        return 'Search by donor name...';
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case EntityPickerType.member:
        return Icons.person;
      case EntityPickerType.event:
        return Icons.event;
      case EntityPickerType.chapter:
        return Icons.account_tree;
      case EntityPickerType.donor:
        return Icons.volunteer_activism;
    }
  }

  Color get _accentColor {
    switch (widget.type) {
      case EntityPickerType.member:
        return const Color(0xFF2196F3);
      case EntityPickerType.event:
        return const Color(0xFFFF9800);
      case EntityPickerType.chapter:
        return const Color(0xFF4CAF50);
      case EntityPickerType.donor:
        return const Color(0xFF9C27B0);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 2) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await widget.searchFunction(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
          _hasSearched = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
          _isSearching = false;
          _hasSearched = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(_icon, color: _accentColor),
          const SizedBox(width: 12),
          Text(_title),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: 450,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _hint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: _performSearch,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildResultsList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildResultsList() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Type at least 2 characters to search',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final entity = _results[index];
        return _buildEntityTile(entity);
      },
    );
  }

  Widget _buildEntityTile(T entity) {
    switch (widget.type) {
      case EntityPickerType.member:
        return _buildMemberTile(entity as Member);
      case EntityPickerType.event:
        return _buildEventTile(entity as Event);
      case EntityPickerType.chapter:
        return _buildChapterTile(entity as Chapter);
      case EntityPickerType.donor:
        return _buildDonorTile(entity as Donor);
    }
  }

  Widget _buildMemberTile(Member member) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _accentColor.withOpacity(0.1),
        backgroundImage: member.primaryProfilePhotoUrl != null
            ? CachedNetworkImageProvider(member.primaryProfilePhotoUrl!)
            : null,
        child: member.primaryProfilePhotoUrl == null
            ? Text(
                member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                style: TextStyle(color: _accentColor),
              )
            : null,
      ),
      title: Text(member.name),
      subtitle: member.preferredEmail != null
          ? Text(
              member.preferredEmail!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      onTap: () => widget.onEntitySelected(member as T),
    );
  }

  Widget _buildEventTile(Event event) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _accentColor.withOpacity(0.1),
        child: Icon(Icons.event, color: _accentColor),
      ),
      title: Text(event.title),
      subtitle: Text(
        '${event.eventDate.month}/${event.eventDate.day}/${event.eventDate.year}',
      ),
      onTap: () => widget.onEntitySelected(event as T),
    );
  }

  Widget _buildChapterTile(Chapter chapter) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _accentColor.withOpacity(0.1),
        child: Icon(Icons.school, color: _accentColor),
      ),
      title: Text(chapter.chapterName),
      subtitle: Text(chapter.schoolName),
      onTap: () => widget.onEntitySelected(chapter as T),
    );
  }

  Widget _buildDonorTile(Donor donor) {
    final donorName = donor.name ?? 'Unknown';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _accentColor.withOpacity(0.1),
        child: Text(
          donorName.isNotEmpty ? donorName[0].toUpperCase() : '?',
          style: TextStyle(color: _accentColor),
        ),
      ),
      title: Text(donorName),
      subtitle: donor.email != null
          ? Text(
              donor.email!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      onTap: () => widget.onEntitySelected(donor as T),
    );
  }
}

/// Specialized dialog for picking events with better display
class _EventPickerDialog extends StatefulWidget {
  final Future<List<Event>> Function(String query) searchFunction;
  final void Function(Event event) onEntitySelected;
  final VoidCallback? onCreateNew;

  const _EventPickerDialog({
    required this.searchFunction,
    required this.onEntitySelected,
    this.onCreateNew,
  });

  @override
  State<_EventPickerDialog> createState() => _EventPickerDialogState();
}

class _EventPickerDialogState extends State<_EventPickerDialog> {
  final _searchController = TextEditingController();
  List<Event> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  bool _showUpcoming = true;

  static const _eventColor = Color(0xFFFF9800);

  @override
  void initState() {
    super.initState();
    // Load initial events (upcoming by default)
    _loadInitialEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialEvents() async {
    setState(() => _isSearching = true);

    try {
      // Load with empty query to get all/recent events
      final results = await widget.searchFunction('');
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
          _hasSearched = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
          _isSearching = false;
          _hasSearched = true;
        });
      }
    }
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);

    try {
      final results = await widget.searchFunction(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
          _hasSearched = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
          _isSearching = false;
          _hasSearched = true;
        });
      }
    }
  }

  List<Event> get _filteredResults {
    if (!_showUpcoming) return _results;
    final now = DateTime.now();
    return _results.where((e) => e.eventDate.isAfter(now)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.event, color: _eventColor),
          const SizedBox(width: 12),
          const Expanded(child: Text('Select Event')),
          if (widget.onCreateNew != null)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onCreateNew!();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New'),
            ),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 500,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by event title...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: _performSearch,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilterChip(
                  label: const Text('Upcoming only'),
                  selected: _showUpcoming,
                  onSelected: (value) => setState(() => _showUpcoming = value),
                  selectedColor: _eventColor.withOpacity(0.2),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _buildResultsList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildResultsList() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    final events = _filteredResults;

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Loading events...',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _showUpcoming ? 'No upcoming events found' : 'No events found',
              style: TextStyle(color: Colors.grey[500]),
            ),
            if (_showUpcoming) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _showUpcoming = false),
                child: const Text('Show all events'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return _buildEventTile(event);
      },
    );
  }

  Widget _buildEventTile(Event event) {
    final dateFormat = DateFormat.MMMd().add_jm();
    final now = DateTime.now();
    final isUpcoming = event.eventDate.isAfter(now);
    final isPast = event.eventDate.isBefore(now);

    Color statusColor;
    String statusText;
    switch (event.status) {
      case 'published':
        statusColor = Colors.green;
        statusText = 'Published';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'Cancelled';
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'Draft';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => widget.onEntitySelected(event),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Event image or icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _eventColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  image: event.websiteImages.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(event.websiteImages.first.url),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: event.websiteImages.isEmpty
                    ? Icon(Icons.event, color: _eventColor, size: 28)
                    : null,
              ),
              const SizedBox(width: 12),
              // Event details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: isPast ? Colors.grey : _eventColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(event.eventDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: isPast ? Colors.grey : Colors.black87,
                          ),
                        ),
                        if (isPast) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'PAST',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (event.location != null && event.location!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.place, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.location!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
