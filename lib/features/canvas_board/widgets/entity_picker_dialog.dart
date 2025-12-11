import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  }) async {
    Event? selectedEvent;
    await showDialog(
      context: context,
      builder: (context) => EntityPickerDialog<Event>(
        type: EntityPickerType.event,
        searchFunction: searchFunction,
        onEntitySelected: (event) {
          selectedEvent = event;
          Navigator.pop(context);
        },
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
