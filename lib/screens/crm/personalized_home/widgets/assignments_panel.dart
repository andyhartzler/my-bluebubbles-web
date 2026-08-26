import 'dart:async';

import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/legislation_tracker/screens/bill_detail_screen.dart';
import 'package:bluebubbles/features/forms/screens/endorsement_hub/endorsement_hub_screen.dart';
import 'package:bluebubbles/features/forms/screens/jobs/job_detail_screen.dart';
import 'package:bluebubbles/models/crm/assignment.dart';
import 'package:bluebubbles/models/crm/event.dart';
import 'package:bluebubbles/screens/crm/candidate_detail_screen.dart';
import 'package:bluebubbles/screens/crm/volunteers/candidate_volunteers_workspace.dart';
import 'package:bluebubbles/screens/crm/event_detail_screen.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/screens/crm/member_portal/member_portal_management_screen.dart';
import 'package:bluebubbles/services/crm/assignments_service.dart';
import 'package:bluebubbles/services/crm/auto_inferred_assignments_service.dart';
import 'package:bluebubbles/services/crm/candidate_repository.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

import 'assignment_create_dialog.dart';
import 'branded_panel.dart';

/// Panel that surfaces both explicit assignments (rows in
/// `public.assignments`) and auto-inferred items (pending profile
/// changes, candidate ownership, mentioned bill notes, pending events
/// or jobs, and the exec's open endorsement ballot) in a single unified,
/// category-tabbed list.
///
/// Tabs are dynamic: `All` is always present (and default); each entity
/// kind only shows up as a tab if at least one item lands in that
/// category. Tap on any item navigates to the right detail screen
/// (or the member-portal pending-changes tab for profile-change items).
class AssignmentsPanel extends StatefulWidget {
  final String authUserId;
  final String memberId;
  final bool isStaff;

  /// Exec-only. When true, a standing "County Outreach" row is included in
  /// the unified list just like any other assignment, opening the Candidate
  /// Volunteers page. It carries no deadline, so it sorts to the bottom and
  /// always appears in All and Candidates.
  final bool showCountyOutreach;

  const AssignmentsPanel({
    super.key,
    required this.authUserId,
    required this.memberId,
    required this.isStaff,
    this.showCountyOutreach = false,
  });

  @override
  State<AssignmentsPanel> createState() => _AssignmentsPanelState();
}

class _AssignmentsPanelState extends State<AssignmentsPanel>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _service = AssignmentsService();
  final _autoService = AutoInferredAssignmentsService();

  StreamSubscription<List<Assignment>>? _toMeSub;
  List<Assignment> _toMe = [];
  List<Assignment> _byMe = [];
  List<AutoInferredAssignment> _auto = [];
  bool _loadingToMe = true;
  bool _loadingByMe = true;
  bool _loadingAuto = true;

  TabController? _tabs;
  List<_HomeCategory> _activeCategories = const [_HomeCategory.all];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSubscribe();
    _loadOutgoing();
    _loadAuto();
    _rebuildTabs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _toMeSub?.cancel();
    _tabs?.dispose();
    super.dispose();
  }

  /// Auto-inferred items are a one-shot fetch behind a 30 second cache, and
  /// nothing on this screen ever invalidated it, so "16 of 73 to vote on"
  /// survived a whole session of voting: the exec came back from the ballot
  /// with every candidate covered and the dashboard still said 16.
  ///
  /// Two triggers, both explicit: coming back from a deep-linked screen (see
  /// [_openAuto]) and the app resuming.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) _refreshAuto();
  }

  Future<void> _refreshAuto() async {
    _autoService.invalidate();
    await _loadAuto();
  }

  Future<void> _initSubscribe() async {
    final stream = _service.watchAssignedToMe(widget.authUserId);
    if (stream == null) {
      final list = await _service.fetchAssignedToMe(widget.authUserId);
      if (!mounted) return;
      setState(() {
        _toMe = list;
        _loadingToMe = false;
      });
      _rebuildTabs();
      return;
    }
    _toMeSub = stream.listen(
      (list) {
        if (!mounted) return;
        setState(() {
          _toMe = list;
          _loadingToMe = false;
        });
        _rebuildTabs();
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
    _rebuildTabs();
  }

  Future<void> _loadAuto() async {
    // Reachable from a lifecycle callback and from a returning route now, so
    // it can no longer assume the panel is still mounted.
    if (!mounted) return;
    setState(() => _loadingAuto = true);
    final list = await _autoService.fetch(
      authUserId: widget.authUserId,
      memberId: widget.memberId,
      isStaff: widget.isStaff,
    );
    if (!mounted) return;
    setState(() {
      _auto = list;
      _loadingAuto = false;
    });
    _rebuildTabs();
  }

  /// Build the unified list of categorized items from the explicit +
  /// auto sources. Each item carries the category and the action.
  List<_Item> _buildItems() {
    final out = <_Item>[];
    for (final a in _auto) {
      out.add(_Item.fromAuto(a, this));
    }
    if (widget.showCountyOutreach) {
      out.add(_Item.countyOutreach(this));
    }
    // Use a set on Assignment.id to avoid duplicates if a single row
    // appears in both _toMe and _byMe streams (assigner-of-self case).
    final seen = <String>{};
    for (final a in [..._toMe, ..._byMe]) {
      if (!seen.add(a.id)) continue;
      out.add(_Item.fromExplicit(a, this));
    }
    out.sort((a, b) {
      final ta = a.at ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.at ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return out;
  }

  void _rebuildTabs() {
    final items = _buildItems();
    final present = <_HomeCategory>{_HomeCategory.all};
    for (final i in items) {
      if (i.category != _HomeCategory.other) present.add(i.category);
    }
    // Fixed display order: All first, then the entity kinds.
    const order = [
      _HomeCategory.all,
      _HomeCategory.profileChanges,
      _HomeCategory.candidates,
      _HomeCategory.bills,
      _HomeCategory.events,
      _HomeCategory.jobs,
      _HomeCategory.tasks,
      _HomeCategory.other,
    ];
    final next = order.where(present.contains).toList();
    if (_listEq(next, _activeCategories) && _tabs != null) return;
    _activeCategories = next;
    _tabs?.dispose();
    _tabs = TabController(length: next.length, vsync: this);
  }

  bool _listEq<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _create() async {
    final created = await showDialog<Assignment?>(
      context: context,
      builder: (_) => AssignmentCreateDialog(currentAuthUserId: widget.authUserId),
    );
    if (created != null) _loadOutgoing();
  }

  Future<void> _edit(Assignment a) async {
    final updated = await showDialog<Assignment?>(
      context: context,
      builder: (_) => AssignmentCreateDialog(
        currentAuthUserId: widget.authUserId,
        existing: a,
      ),
    );
    if (updated != null) _loadOutgoing();
  }

  Future<void> _toggleDone(Assignment a) async {
    final next = a.isDone ? 'pending' : 'done';
    await _service.setStatus(a.id, next);
    setState(() {
      _toMe = _toMe.map((x) => x.id == a.id ? a.copyWith(status: next) : x).toList();
      _byMe = _byMe.map((x) => x.id == a.id ? a.copyWith(status: next) : x).toList();
    });
  }

  Future<void> _openAuto(AutoInferredAssignment a) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Profile-change items go to the member-portal pending-changes tab,
    // NOT the member detail screen — that's where Andrew can actually
    // approve/reject the change.
    if (a.source == 'profile_change') {
      navigator.push(MaterialPageRoute(
        builder: (_) => const MemberPortalManagementScreen(initialTabIndex: 4),
      ));
      return;
    }
    // Endorsement ballot items open the Endorsement HQ directly. The CRM has
    // no named routes, and the hub normally lives behind CandidatesPage's
    // private Field/Endorsement HQ area switcher, so pushing the hub screen
    // standalone is the only deep link. The hub carries no AppBar of its own
    // (the Candidates page hosts it inline), so wrap one around it here for
    // a way back to the dashboard.
    if (a.source == 'endorsement_vote') {
      // AWAITED, then refreshed: the exec comes back from the hub having just
      // voted, and the whole point of the card is the count.
      await navigator.push(MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Endorsement HQ')),
          body: const EndorsementHubScreen(),
        ),
      ));
      await _refreshAuto();
      return;
    }
    final kind = a.entityKind;
    final id = a.entityId;
    if (kind == null || id == null || id.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text('Link: ${a.entityUrl}')));
      return;
    }
    await _navigateToEntity(kind: kind, id: id, committeeId: a.committeeId);
  }

  void _openCountyOutreach() {
    // Land on the real Candidate Volunteers war room (MAP + ACTIVITIES), not
    // the old county-outreach page. The workspace is a bare Column with its own
    // tab strip and no Scaffold, so wrap one here for a way back, the same way
    // the endorsement-hub deep link above does.
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Candidate Volunteers')),
        body: const CandidateVolunteersWorkspace(),
      ),
    ));
  }

  Future<void> _openExplicit(Assignment a, {required bool allowEdit}) async {
    final kind = a.entityType;
    final id = a.entityId;
    if (kind != null &&
        id != null &&
        id.isNotEmpty &&
        const {'candidate', 'member', 'event', 'job', 'bill'}.contains(kind)) {
      await _navigateToEntity(kind: kind, id: id);
      return;
    }
    if (allowEdit) await _edit(a);
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
          navigator.push(MaterialPageRoute(builder: (_) => CandidateDetailScreen(candidate: c)));
          return;
        case 'member':
          final m = await MemberRepository().getMemberById(id);
          if (!mounted) return;
          if (m == null) {
            messenger.showSnackBar(const SnackBar(content: Text('Member not found')));
            return;
          }
          navigator.push(MaterialPageRoute(builder: (_) => MemberDetailScreen(member: m)));
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
          navigator.push(MaterialPageRoute(builder: (_) => EventDetailScreen(initialEvent: ev)));
          return;
        case 'job':
          navigator.push(MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: id)));
          return;
        case 'bill':
          if (committeeId == null || committeeId.isEmpty) {
            messenger.showSnackBar(const SnackBar(
              content: Text('Bill committee unknown — open Legislation tab.'),
            ));
            return;
          }
          navigator.push(MaterialPageRoute(
            builder: (_) => BillDetailScreen(billId: id, committeeId: committeeId),
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

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final items = _buildItems();
    final loading = _loadingToMe || _loadingByMe || _loadingAuto;

    return BrandedPanel(
      title: 'Assignments',
      icon: Icons.task_alt,
      headerAction: BrandedHeaderPillButton(
        onPressed: _create,
        icon: Icons.add,
        label: 'New',
      ),
      tabBar: tabs == null
          ? null
          : BrandedHeaderTabBar(
              controller: tabs,
              onTap: (i) => tabs.animateTo(i),
              tabs: _activeCategories
                  .map((c) => Tab(text: '${c.label} (${_countFor(c, items)})'))
                  .toList(),
            ),
      bodyHeight: 320,
      body: tabs == null
          ? const SizedBox.shrink()
          : TabBarView(
              controller: tabs,
              children: _activeCategories
                  .map((c) => _list(_filter(c, items), loading))
                  .toList(),
            ),
    );
  }

  int _countFor(_HomeCategory c, List<_Item> items) =>
      c == _HomeCategory.all ? items.length : items.where((i) => i.category == c).length;

  List<_Item> _filter(_HomeCategory c, List<_Item> items) =>
      c == _HomeCategory.all ? items : items.where((i) => i.category == c).toList();

  Widget _list(List<_Item> items, bool loading) {
    if (loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Nothing here',
          style: TextStyle(color: Colors.white.withOpacity(0.65)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: Colors.white.withOpacity(0.10)),
      itemBuilder: (_, i) => items[i].buildTile(context),
    );
  }
}

/// Display category for the unified item list.
enum _HomeCategory {
  all,
  profileChanges,
  candidates,
  bills,
  events,
  jobs,
  tasks, // explicit "free-form" assignments with no entityType
  other;

  String get label {
    switch (this) {
      case _HomeCategory.all:
        return 'All';
      case _HomeCategory.profileChanges:
        return 'Profile changes';
      case _HomeCategory.candidates:
        return 'Candidates';
      case _HomeCategory.bills:
        return 'Bills';
      case _HomeCategory.events:
        return 'Events';
      case _HomeCategory.jobs:
        return 'Jobs';
      case _HomeCategory.tasks:
        return 'Tasks';
      case _HomeCategory.other:
        return 'Other';
    }
  }
}

class _Item {
  final String id;
  final _HomeCategory category;
  final String title;
  final String? subtitle;
  final IconData icon;
  final String? memberName;
  final String? memberAvatarUrl;
  final DateTime? at;
  final VoidCallback onTap;
  final bool? isDone;
  final VoidCallback? onToggleDone;
  final VoidCallback? onEdit;
  final String? priority;

  _Item({
    required this.id,
    required this.category,
    required this.title,
    this.subtitle,
    required this.icon,
    this.memberName,
    this.memberAvatarUrl,
    this.at,
    required this.onTap,
    this.isDone,
    this.onToggleDone,
    this.onEdit,
    this.priority,
  });

  factory _Item.fromAuto(AutoInferredAssignment a, _AssignmentsPanelState state) {
    return _Item(
      id: 'auto:${a.key}',
      category: _categoryForSource(a.source),
      title: a.title,
      subtitle: a.subtitle,
      icon: _iconForSource(a.source),
      memberName: a.memberName,
      memberAvatarUrl: a.memberAvatarUrl,
      at: a.at,
      onTap: () => state._openAuto(a),
      // Auto items historically carry no priority; deadline-driven sources
      // (the endorsement ballot) set 'urgent' inside 48 hours of close so
      // the chip reads with the same visual language as explicit items.
      priority: a.priority,
    );
  }

  /// A standing exec item, not backed by any row: opens County Outreach
  /// (the Candidate Volunteers page). Categorized as candidate work so it
  /// shows in both All and Candidates. No `at`, so it sorts to the bottom.
  factory _Item.countyOutreach(_AssignmentsPanelState state) {
    return _Item(
      id: 'county-outreach',
      category: _HomeCategory.candidates,
      title: 'County Outreach',
      subtitle: 'Text or email members by county',
      icon: Icons.campaign_outlined,
      onTap: state._openCountyOutreach,
    );
  }

  factory _Item.fromExplicit(Assignment a, _AssignmentsPanelState state) {
    final allowEdit = a.assignedBy == state.widget.authUserId;
    final note = a.note;
    final due = a.dueDate;
    final subtitle = (note != null && note.isNotEmpty)
        ? note
        : (due != null ? 'Due ${due.toIso8601String().split('T').first}' : null);
    return _Item(
      id: 'explicit:${a.id}',
      category: _categoryForExplicit(a),
      title: a.title,
      subtitle: subtitle,
      icon: _iconForExplicit(a.entityType),
      at: a.updatedAt,
      onTap: () => state._openExplicit(a, allowEdit: allowEdit),
      isDone: a.isDone,
      onToggleDone: () => state._toggleDone(a),
      onEdit: allowEdit ? () => state._edit(a) : null,
      priority: a.priority,
    );
  }

  Widget buildTile(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: _buildLeading(),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          decoration: (isDone == true) ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              // One row. Two lines made the assignment cards different
              // heights and the panel looked ragged; anything that does not
              // fit is better truncated than allowed to reflow the card.
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withOpacity(0.78)),
            ),
      trailing: _buildTrailing(),
    );
  }

  Widget _buildLeading() {
    if (onToggleDone != null) {
      return Checkbox(
        value: isDone ?? false,
        onChanged: (_) => onToggleDone!(),
      );
    }
    final hasName = memberName != null && memberName!.trim().isNotEmpty;
    final initials = hasName ? _initialsOf(memberName!) : null;
    final fallback = initials != null
        ? Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          )
        : Icon(icon, color: Colors.white, size: 18);
    final hasUrl = memberAvatarUrl != null && memberAvatarUrl!.isNotEmpty;
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.white.withOpacity(0.12),
      foregroundImage: hasUrl ? NetworkImage(memberAvatarUrl!) : null,
      onForegroundImageError: hasUrl ? (_, __) {} : null,
      child: fallback,
    );
  }

  Widget? _buildTrailing() {
    final actions = <Widget>[];
    if (priority != null) actions.add(_priorityChip(priority!));
    if (onEdit != null) {
      actions.add(IconButton(
        icon: Icon(Icons.edit, size: 18, color: Colors.white.withOpacity(0.85)),
        onPressed: onEdit,
        tooltip: 'Edit',
      ));
    }
    actions.add(Icon(
      Icons.arrow_forward_ios,
      size: 14,
      color: Colors.white.withOpacity(0.6),
    ));
    return Row(mainAxisSize: MainAxisSize.min, children: actions);
  }

  static Widget _priorityChip(String p) {
    Color bg;
    switch (p) {
      case 'high':
      // 'urgent' marks deadline-driven auto items still inside their action
      // window (endorsement ballot, last 48h before close; never after it,
      // because a closed ballot is not something anyone can act on). Same red
      // as 'high': white-on-red on the fixed dark branded panel surface,
      // identical in both app themes.
      case 'urgent':
        bg = const Color(0xFFEF4444);
        break;
      case 'medium':
        bg = const Color(0xFFF59E0B);
        break;
      default:
        bg = Colors.white.withOpacity(0.20);
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
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static String _initialsOf(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  static _HomeCategory _categoryForSource(String source) {
    switch (source) {
      case 'profile_change':
        return _HomeCategory.profileChanges;
      case 'candidate':
      case 'endorsement_vote': // ballot work is candidate work
        return _HomeCategory.candidates;
      case 'bill_mention':
        return _HomeCategory.bills;
      case 'event_pending':
        return _HomeCategory.events;
      case 'job_pending':
        return _HomeCategory.jobs;
      default:
        return _HomeCategory.other;
    }
  }

  static _HomeCategory _categoryForExplicit(Assignment a) {
    switch (a.entityType) {
      case 'candidate':
        return _HomeCategory.candidates;
      case 'member':
        return _HomeCategory.profileChanges;
      case 'bill':
        return _HomeCategory.bills;
      case 'event':
        return _HomeCategory.events;
      case 'job':
        return _HomeCategory.jobs;
      default:
        return _HomeCategory.tasks;
    }
  }

  static IconData _iconForSource(String source) {
    switch (source) {
      case 'candidate':
        return Icons.how_to_vote;
      case 'endorsement_vote':
        return Icons.ballot;
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

  static IconData _iconForExplicit(String? entityType) {
    switch (entityType) {
      case 'candidate':
        return Icons.how_to_vote;
      case 'member':
        return Icons.person;
      case 'bill':
        return Icons.gavel;
      case 'event':
        return Icons.event;
      case 'job':
        return Icons.work_outline;
      default:
        return Icons.task_alt;
    }
  }
}

