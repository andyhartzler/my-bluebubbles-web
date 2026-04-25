import 'dart:async';

import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/legislation_tracker/screens/bill_detail_screen.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/forms/screens/jobs/job_detail_screen.dart';
import 'package:bluebubbles/models/crm/assignment.dart';
import 'package:bluebubbles/models/crm/event.dart';
import 'package:bluebubbles/screens/crm/candidate_detail_screen.dart';
import 'package:bluebubbles/screens/crm/event_detail_screen.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/assignments_service.dart';
import 'package:bluebubbles/services/crm/auto_inferred_assignments_service.dart';
import 'package:bluebubbles/services/crm/candidate_repository.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

import 'assignment_create_dialog.dart';
import 'branded_panel.dart';

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
    setState(() {
      _toMe = _toMe.map((x) => x.id == a.id ? a.copyWith(status: next) : x).toList();
      _byMe = _byMe.map((x) => x.id == a.id ? a.copyWith(status: next) : x).toList();
    });
  }

  /// Navigate to the entity an auto-inferred item points at, by pushing
  /// the existing native detail screen. Falls back to opening the
  /// member-edit dialog or surfacing a snackbar if a fetch fails.
  Future<void> _openAuto(AutoInferredAssignment a) async {
    final kind = a.entityKind;
    final id = a.entityId;
    if (kind == null || id == null || id.isEmpty) {
      _snackbarFallback(a.entityUrl);
      return;
    }
    await _navigateToEntity(kind: kind, id: id, committeeId: a.committeeId);
  }

  /// Navigate from an explicit assignment to its linked entity, if any.
  /// If the assignment has no `entityType/entityId`, opens the edit
  /// dialog (when the user is the assigner) instead.
  Future<void> _openExplicit(Assignment a, {required bool allowEdit}) async {
    final kind = a.entityType;
    final id = a.entityId;
    if (kind != null && id != null && id.isNotEmpty &&
        const {'candidate','member','event','job','bill'}.contains(kind)) {
      await _navigateToEntity(kind: kind, id: id);
      return;
    }
    if (allowEdit) {
      await _edit(a);
    }
  }

  Future<void> _navigateToEntity({
    required String kind,
    required String id,
    String? committeeId,
  }) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (kind) {
        case 'candidate':
          final c = await CandidateRepository().fetchCandidate(id);
          if (!mounted) return;
          if (c == null) {
            messenger.showSnackBar(const SnackBar(content: Text('Candidate not found')));
            return;
          }
          navigator.push(MaterialPageRoute(
            builder: (_) => CandidateDetailScreen(candidate: c),
          ));
          return;

        case 'member':
          final m = await MemberRepository().getMemberById(id);
          if (!mounted) return;
          if (m == null) {
            messenger.showSnackBar(const SnackBar(content: Text('Member not found')));
            return;
          }
          navigator.push(MaterialPageRoute(
            builder: (_) => MemberDetailScreen(member: m),
          ));
          return;

        case 'event':
          final client = CRMSupabaseService().client;
          final row = await client.from('events').select().eq('id', id).maybeSingle();
          if (!mounted) return;
          if (row == null) {
            messenger.showSnackBar(const SnackBar(content: Text('Event not found')));
            return;
          }
          final ev = Event.fromJson(Map<String, dynamic>.from(row));
          navigator.push(MaterialPageRoute(
            builder: (_) => EventDetailScreen(initialEvent: ev),
          ));
          return;

        case 'job':
          navigator.push(MaterialPageRoute(
            builder: (_) => JobDetailScreen(jobId: id),
          ));
          return;

        case 'bill':
          if (committeeId == null || committeeId.isEmpty) {
            messenger.showSnackBar(const SnackBar(
              content: Text('Bill committee unknown — open Legislation tab.'),
            ));
            return;
          }
          navigator.push(MaterialPageRoute(
            builder: (_) => BillDetailScreen(
              billId: id,
              committeeId: committeeId,
            ),
          ));
          return;

        default:
          messenger.showSnackBar(SnackBar(content: Text('Cannot open: $kind')));
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Open failed: $e')));
    }
  }

  void _snackbarFallback(String url) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Link: $url')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BrandedPanel(
      title: 'Assignments',
      icon: Icons.task_alt,
      headerAction: BrandedHeaderPillButton(
        onPressed: _create,
        icon: Icons.add,
        label: 'New',
      ),
      tabBar: BrandedHeaderTabBar(
        controller: _tabs,
        onTap: (i) => _tabs.animateTo(i),
        tabs: [
          Tab(text: 'To me (${_toMe.length})'),
          Tab(text: 'By me (${_byMe.length})'),
          Tab(text: 'Auto (${_auto.length})'),
        ],
      ),
      bodyHeight: 320,
      body: TabBarView(
        controller: _tabs,
        children: [
          _explicitList(_toMe, _loadingToMe, allowEdit: false),
          _explicitList(_byMe, _loadingByMe, allowEdit: true),
          _autoList(_auto, _loadingAuto),
        ],
      ),
    );
  }

  Widget _explicitList(List<Assignment> items, bool loading, {required bool allowEdit}) {
    if (loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return const Center(
        child: Text('Nothing here yet', style: TextStyle(color: Color(0xFF6B7280))),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final a = items[i];
        return ListTile(
          onTap: () => _openExplicit(a, allowEdit: allowEdit),
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
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final a = items[i];
        return ListTile(
          leading: _autoLeading(a),
          title: Text(a.title),
          subtitle: a.subtitle != null
              ? Text(a.subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis)
              : null,
          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
          onTap: () => _openAuto(a),
        );
      },
    );
  }

  /// Always render initials (or a source icon) as the `child:` of the
  /// CircleAvatar, then lay the network image over it via `foregroundImage`.
  /// On a 404/CORS/empty-URL failure the foreground falls away and the
  /// child stays visible — so Andrew sees "AH" / "SJ" / icon, never an
  /// empty grey circle.
  Widget _autoLeading(AutoInferredAssignment a) {
    final hasName = a.memberName != null && a.memberName!.trim().isNotEmpty;
    final initials = hasName ? _initialsOf(a.memberName!) : null;

    final fallbackChild = initials != null
        ? Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          )
        : Icon(_iconForSource(a.source), color: Colors.white, size: 18);

    final hasUrl = a.memberAvatarUrl != null && a.memberAvatarUrl!.isNotEmpty;

    return CircleAvatar(
      radius: 18,
      backgroundColor: BrandColors.unityBlue,
      foregroundImage: hasUrl ? NetworkImage(a.memberAvatarUrl!) : null,
      onForegroundImageError: hasUrl ? (_, __) {} : null,
      child: fallbackChild,
    );
  }

  static String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  Widget _priorityChip(String p) {
    Color bg;
    Color fg;
    switch (p) {
      case 'high':
        bg = const Color(0xFFFEE2E2); // red-100
        fg = const Color(0xFF991B1B); // red-800
        break;
      case 'medium':
        bg = const Color(0xFFFFEDD5); // orange-100
        fg = const Color(0xFF9A3412); // orange-800
        break;
      default:
        bg = const Color(0xFFF1F5F9); // slate-100
        fg = const Color(0xFF334155); // slate-700
    }
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        p,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
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
