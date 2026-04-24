import 'dart:async';

import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/assignment.dart';
import 'package:bluebubbles/services/crm/assignments_service.dart';
import 'package:bluebubbles/services/crm/auto_inferred_assignments_service.dart';

import 'assignment_create_dialog.dart';

/// Two-tab panel showing assignments to the user (incoming) and from the
/// user (outgoing). Includes a third virtual tab for auto-inferred items.
///
/// Realtime updates: subscribes to the realtime stream of `assignments`
/// rows where `assigned_to = me` so newly-created items appear without
/// a manual refresh.
class AssignmentsPanel extends StatefulWidget {
  final String authUserId;
  final String memberId;
  final bool isStaff;

  const AssignmentsPanel({
    super.key,
    required this.authUserId,
    required this.memberId,
    required this.isStaff,
  });

  @override
  State<AssignmentsPanel> createState() => _AssignmentsPanelState();
}

class _AssignmentsPanelState extends State<AssignmentsPanel>
    with SingleTickerProviderStateMixin {
  final _service = AssignmentsService();
  final _autoService = AutoInferredAssignmentsService();
  late final TabController _tabs;

  StreamSubscription<List<Assignment>>? _toMeSub;
  List<Assignment> _toMe = [];
  List<Assignment> _byMe = [];
  List<AutoInferredAssignment> _auto = [];
  bool _loadingToMe = true;
  bool _loadingByMe = true;
  bool _loadingAuto = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _initSubscribe();
    _loadOutgoing();
    _loadAuto();
  }

  @override
  void dispose() {
    _toMeSub?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _initSubscribe() async {
    final stream = _service.watchAssignedToMe(widget.authUserId);
    if (stream == null) {
      // Fallback to one-shot fetch (Supabase not initialized for streams)
      final list = await _service.fetchAssignedToMe(widget.authUserId);
      if (mounted) {
        setState(() {
          _toMe = list;
          _loadingToMe = false;
        });
      }
      return;
    }
    _toMeSub = stream.listen(
      (list) {
        if (!mounted) return;
        setState(() {
          _toMe = list;
          _loadingToMe = false;
        });
      },
      onError: (_) {
        if (mounted) setState(() => _loadingToMe = false);
      },
    );
  }

  Future<void> _loadOutgoing() async {
    final list = await _service.fetchAssignedByMe(widget.authUserId);
    if (!mounted) return;
    setState(() {
      _byMe = list;
      _loadingByMe = false;
    });
  }

  Future<void> _loadAuto() async {
    setState(() => _loadingAuto = true);
    final list = await _autoService.fetch(
      authUserId: widget.authUserId,
      memberId: widget.memberId,
      isStaff: widget.isStaff,
    );
    if (mounted) {
      setState(() {
        _auto = list;
        _loadingAuto = false;
      });
    }
  }

  Future<void> _create() async {
    final created = await showDialog<Assignment?>(
      context: context,
      builder: (_) => AssignmentCreateDialog(currentAuthUserId: widget.authUserId),
    );
    if (created != null) {
      _loadOutgoing();
      // The realtime stream will pick up incoming-to-me cases automatically.
    }
  }

  Future<void> _edit(Assignment a) async {
    final updated = await showDialog<Assignment?>(
      context: context,
      builder: (_) => AssignmentCreateDialog(
        currentAuthUserId: widget.authUserId,
        existing: a,
      ),
    );
    if (updated != null) {
      _loadOutgoing();
    }
  }

  Future<void> _toggleDone(Assignment a) async {
    final next = a.isDone ? 'pending' : 'done';
    await _service.setStatus(a.id, next);
    // Optimistic UI: update local lists without waiting for realtime.
    setState(() {
      _toMe = _toMe.map((x) => x.id == a.id ? a.copyWith(status: next) : x).toList();
      _byMe = _byMe.map((x) => x.id == a.id ? a.copyWith(status: next) : x).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.task_alt),
                ),
                const SizedBox(width: 4),
                Text(
                  'Assignments',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: _create,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabs: [
                Tab(text: 'To me (${_toMe.length})'),
                Tab(text: 'By me (${_byMe.length})'),
                Tab(text: 'Auto (${_auto.length})'),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 320,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _explicitList(_toMe, _loadingToMe, allowEdit: false),
                  _explicitList(_byMe, _loadingByMe, allowEdit: true),
                  _autoList(_auto, _loadingAuto),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _explicitList(List<Assignment> items, bool loading, {required bool allowEdit}) {
    if (loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return const Center(
        child: Text('Nothing here yet', style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final a = items[i];
        return ListTile(
          leading: Checkbox(
            value: a.isDone,
            onChanged: (_) => _toggleDone(a),
          ),
          title: Text(
            a.title,
            style: TextStyle(
              decoration: a.isDone ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: a.note != null && a.note!.isNotEmpty
              ? Text(a.note!, maxLines: 2, overflow: TextOverflow.ellipsis)
              : (a.dueDate != null
                  ? Text('Due ${a.dueDate!.toIso8601String().split('T').first}')
                  : null),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (a.priority != null) _priorityChip(a.priority!),
              if (allowEdit)
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _edit(a),
                  tooltip: 'Edit',
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _autoList(List<AutoInferredAssignment> items, bool loading) {
    if (loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No auto-detected items',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final a = items[i];
        return ListTile(
          leading: Icon(_iconForSource(a.source), size: 20),
          title: Text(a.title),
          subtitle: a.subtitle != null
              ? Text(a.subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis)
              : null,
          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
          // Deep-link routing not yet wired to in-app navigator;
          // for now copy the URL to clipboard as a placeholder action.
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Link: ${a.entityUrl}')),
            );
          },
        );
      },
    );
  }

  Widget _priorityChip(String p) {
    Color color;
    switch (p) {
      case 'high':
        color = Colors.red;
        break;
      case 'medium':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        p,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  IconData _iconForSource(String source) {
    switch (source) {
      case 'candidate':
        return Icons.how_to_vote;
      case 'profile_change':
        return Icons.person_search;
      case 'event_pending':
        return Icons.event_note;
      case 'bill_mention':
        return Icons.gavel;
      case 'job_pending':
        return Icons.work_outline;
      default:
        return Icons.notifications;
    }
  }
}
