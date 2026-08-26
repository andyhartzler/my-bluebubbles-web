import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/outreach_activity.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/outreach_repository.dart';
import 'package:bluebubbles/screens/crm/bulk_email_screen.dart';
import 'package:bluebubbles/screens/crm/bulk_message_screen.dart';
import 'package:bluebubbles/screens/crm/volunteers/volunteers_map_models.dart';

// ═══════════════════════════════════════════════════════════════
//  ACTIVITY DETAIL (full-screen route)
//
//  Roster + attendance + status transitions for a single outreach activity.
//  Reads the roster via OutreachRepository.getRoster and drives every write
//  (status, role, attendance) back through the repository. "Text roster" /
//  "Email roster" resolve the roster's member ids to Member objects and hand
//  them to the shipped bulk screens.
// ═══════════════════════════════════════════════════════════════

const List<String> _kRoles = <String>['volunteer', 'captain', 'organizer'];

class ActivityDetailScreen extends StatefulWidget {
  const ActivityDetailScreen({super.key, required this.activity});

  final OutreachActivity activity;

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  final OutreachRepository _repo = OutreachRepository();
  final MemberRepository _members = MemberRepository();

  late OutreachActivity _activity;
  List<ActivityRosterEntry> _roster = <ActivityRosterEntry>[];
  int _nomineeCount = 0;

  bool _loading = true;
  bool _errored = false;
  bool _busy = false; // guards bulk/status writes

  @override
  void initState() {
    super.initState();
    _activity = widget.activity;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errored = false;
    });
    try {
      final roster = await _repo.getRoster(_activity.id);
      final nominees = await _repo.activityCandidateCount(_activity.id);
      if (!mounted) return;
      setState(() {
        _roster = roster;
        _nomineeCount = nominees;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errored = true;
        _loading = false;
      });
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Attendance ─────────────────────────────────────────────────
  Future<void> _setAttendance(ActivityRosterEntry entry, bool attended) async {
    if (entry.attended == attended) return;
    final index = _roster.indexWhere((e) => e.memberId == entry.memberId);
    if (index < 0) return;
    setState(() => _roster[index] = _withAttendance(entry, attended));
    try {
      await _repo.setAttendance(_activity.id, entry.memberId, attended);
    } catch (_) {
      if (!mounted) return;
      setState(() => _roster[index] = entry); // revert
      _snack('Could not save attendance. Try again.');
    }
  }

  Future<void> _markAllAttended() async {
    if (_busy) return;
    final pending =
        _roster.where((e) => e.attended != true).map((e) => e.memberId).toList();
    if (pending.isEmpty) return;
    setState(() => _busy = true);
    var failed = false;
    for (final memberId in pending) {
      try {
        await _repo.setAttendance(_activity.id, memberId, true);
      } catch (_) {
        failed = true;
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (failed) _snack('Some attendance could not be saved.');
    await _load();
  }

  // ── Role ───────────────────────────────────────────────────────
  Future<void> _setRole(ActivityRosterEntry entry, String role) async {
    if (entry.role == role) return;
    final index = _roster.indexWhere((e) => e.memberId == entry.memberId);
    if (index < 0) return;
    setState(() => _roster[index] = _withRole(entry, role));
    try {
      await _repo.updateParticipantRole(_activity.id, entry.memberId, role);
    } catch (_) {
      if (!mounted) return;
      setState(() => _roster[index] = entry);
      _snack('Could not update role. Try again.');
    }
  }

  // ── Status transitions ─────────────────────────────────────────
  List<String> get _allowedTransitions {
    switch (_activity.status) {
      case 'planned':
        return const ['in_progress', 'completed', 'cancelled'];
      case 'in_progress':
        return const ['completed', 'cancelled'];
      case 'completed':
        return const ['in_progress']; // Reopen
      case 'cancelled':
        return const ['in_progress']; // Reopen
      default:
        return const [];
    }
  }

  String _transitionLabel(String target) {
    if ((_activity.status == 'completed' || _activity.status == 'cancelled') &&
        target == 'in_progress') {
      return 'Reopen';
    }
    return 'Mark ${OutreachDisplay.statusLabel(target).toLowerCase()}';
  }

  Future<void> _requestStatus(String target) async {
    if (_busy) return;

    if (target == 'completed') {
      final unrecorded = _roster.where((e) => e.attended == null).length;
      if (unrecorded > 0) {
        final choice = await _attendanceInterposer(unrecorded);
        if (choice != _CompleteChoice.skip) return; // record-now or dismissed
      }
    }

    setState(() => _busy = true);
    try {
      await _repo.updateStatus(_activity.id, target);
      if (!mounted) return;
      setState(() {
        _activity = _activity.copyWith(
          status: target,
          completedAt: target == 'completed' ? DateTime.now() : null,
        );
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Could not change status. Try again.');
    }
  }

  Future<_CompleteChoice?> _attendanceInterposer(int unrecorded) {
    return showDialog<_CompleteChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record attendance first?'),
        content: Text(
            '$unrecorded ${unrecorded == 1 ? 'person has' : 'people have'} no '
            'attendance recorded. Record who showed before completing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_CompleteChoice.recordNow),
            child: const Text('Record now'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_CompleteChoice.skip),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }

  // ── Bulk roster actions ────────────────────────────────────────
  Future<List<Member>?> _resolveRosterMembers() async {
    final ids = _roster.map((e) => e.memberId).toList();
    if (ids.isEmpty) {
      _snack('No one is on the roster yet.');
      return null;
    }
    final members = await _members.membersByIds(ids);
    if (members.isEmpty) {
      _snack('Could not load the roster.');
      return null;
    }
    return members;
  }

  Future<void> _textRoster() async {
    if (_busy) return;
    setState(() => _busy = true);
    final members = await _resolveRosterMembers();
    if (!mounted) return;
    setState(() => _busy = false);
    if (members == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BulkMessageScreen(initialManualMembers: members),
      ),
    );
  }

  Future<void> _emailRoster() async {
    if (_busy) return;
    setState(() => _busy = true);
    final members = await _resolveRosterMembers();
    if (!mounted) return;
    setState(() => _busy = false);
    if (members == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BulkEmailScreen(initialManualMembers: members),
      ),
    );
  }

  // ── Theme tokens ───────────────────────────────────────────────
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF151B2B) : const Color(0xFFF4F6FA);
  Color get _surface => _isDark ? const Color(0xFF1B2337) : Colors.white;
  Color get _inset => _isDark ? const Color(0xFF212B44) : const Color(0xFFEEF1F6);
  // Blue text/icons on the dark neutral surfaces fall below 4.5:1; lift them to
  // a lighter blue in dark mode. Solid blue FILLS (with white on them) stay
  // unityBlue.
  Color get _action =>
      _isDark ? const Color(0xFF4D82E0) : MoydMapTheme.unityBlue;
  Color get _text => _isDark ? const Color(0xFFF4F6FA) : const Color(0xFF1E2637);
  Color get _secondary =>
      _isDark ? Colors.white.withValues(alpha: 0.72) : const Color(0xFF5A6478);
  Color get _divider =>
      _isDark ? const Color(0xFF2E3A57) : const Color(0xFFE5E9F0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: MoydMapTheme.navy,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Icon(_activity.kindIcon, size: 20, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_activity.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                    strokeWidth: 2.6, color: MoydMapTheme.unityBlue),
              ),
            )
          : _errored
              ? _errorBody()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: _rosterSection(),
                            ),
                          ),
                          Container(width: 1, color: _divider),
                          Expanded(
                            flex: 4,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: _infoSection(),
                            ),
                          ),
                        ],
                      );
                    }
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoSection(),
                          const SizedBox(height: 20),
                          _rosterSection(),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _errorBody() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 44, color: _secondary),
            const SizedBox(height: 14),
            Text('Could not load this activity.',
                style: TextStyle(color: _secondary, fontSize: 14)),
            const SizedBox(height: 14),
            TextButton(
              onPressed: _load,
              child: Text('Retry',
                  style: TextStyle(
                      color: _action,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );

  // ── Info / status ──────────────────────────────────────────────
  Widget _infoSection() {
    final geo = _geoLabels();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_activity.kindLabel,
                  style: TextStyle(
                      color: _secondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              _statusMenu(),
            ],
          ),
          const SizedBox(height: 12),
          _kv('Date',
              _activity.scheduledOn == null
                  ? 'No date set'
                  : _fmtDate(_activity.scheduledOn!)),
          _kv('Nominees',
              _nomineeCount == 1 ? '1 nominee' : '$_nomineeCount nominees'),
          if (_activity.channel != null)
            _kv('Channel', _channelLabel(_activity.channel!)),
          if (_activity.createdAt != null)
            _kv('Created', _fmtDate(_activity.createdAt!)),
          if (_activity.completedAt != null)
            _kv('Completed', _fmtDate(_activity.completedAt!)),
          if (geo.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final g in geo) _readChip(g)],
            ),
          ],
          if (_activity.description != null &&
              _activity.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('NOTES',
                style: TextStyle(
                    color: _secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(_activity.description!,
                style: TextStyle(color: _text, fontSize: 13.5, height: 1.4)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                    Icons.sms_outlined, 'Text roster', _textRoster),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                    Icons.mail_outline, 'Email roster', _emailRoster),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusMenu() {
    final transitions = _allowedTransitions;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _activity.statusColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_activity.statusLabel,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
          if (transitions.isNotEmpty) ...[
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 16, color: Colors.white),
          ],
        ],
      ),
    );

    if (transitions.isEmpty || _busy) return chip;

    return PopupMenuButton<String>(
      tooltip: 'Change status',
      color: _surface,
      onSelected: _requestStatus,
      itemBuilder: (_) => [
        for (final target in transitions)
          PopupMenuItem<String>(
            value: target,
            child: Text(_transitionLabel(target),
                style: TextStyle(color: _text, fontWeight: FontWeight.w600)),
          ),
      ],
      child: chip,
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: _inset,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: _busy ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Opacity(
          opacity: _busy ? 0.5 : 1,
          child: Container(
            height: 44,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: _action),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(
                        color: _action,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Roster ─────────────────────────────────────────────────────
  Widget _rosterSection() {
    final rostered = _roster.length;
    final attended = _roster.where((e) => e.attended == true).length;
    final noShow = _roster.where((e) => e.attended == false).length;
    final unrecorded = _roster.where((e) => e.attended == null).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('ROSTER',
                    style: TextStyle(
                        color: _secondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1)),
              ),
              if (_roster.any((e) => e.attended != true))
                TextButton(
                  onPressed: _busy ? null : _markAllAttended,
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: Text('Mark all attended',
                      style: TextStyle(
                          color: _action,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$rostered rostered  ·  $attended attended  ·  '
            '$noShow no-show  ·  $unrecorded unrecorded',
            style: TextStyle(color: _secondary, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          if (_roster.isEmpty)
            _emptyNote('No one on the roster yet.')
          else
            for (final entry in _roster) _rosterRow(entry),
        ],
      ),
    );
  }

  Widget _rosterRow(ActivityRosterEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(entry.memberAvatarUrl, entry.memberName),
              const SizedBox(width: 12),
              Expanded(
                child: Text(entry.memberName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: _text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              _roleDropdown(entry),
            ],
          ),
          const SizedBox(height: 8),
          _attendanceControl(entry),
        ],
      ),
    );
  }

  Widget _roleDropdown(ActivityRosterEntry entry) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _inset,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _kRoles.contains(entry.role) ? entry.role : 'volunteer',
          isDense: true,
          icon: Icon(Icons.expand_more, color: _secondary, size: 18),
          dropdownColor: _surface,
          style: TextStyle(
              color: _text, fontSize: 12.5, fontWeight: FontWeight.w600),
          items: [
            for (final r in _kRoles)
              DropdownMenuItem<String>(
                value: r,
                child: Text('${r[0].toUpperCase()}${r.substring(1)}'),
              ),
          ],
          onChanged: (v) {
            if (v != null) _setRole(entry, v);
          },
        ),
      ),
    );
  }

  Widget _attendanceControl(ActivityRosterEntry entry) {
    Widget seg({
      required String label,
      required bool active,
      required Color activeColor,
      VoidCallback? onTap,
    }) {
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? activeColor.withValues(alpha: _isDark ? 0.30 : 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(label,
                  style: TextStyle(
                      color: active ? activeColor : _secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _inset,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _divider),
      ),
      child: Row(
        children: [
          // "Unrecorded" reflects the null state but cannot be re-selected once
          // attendance is set (there is no clear-to-null path).
          seg(
            label: 'Unrecorded',
            active: entry.attended == null,
            activeColor: _secondary,
            onTap: null,
          ),
          seg(
            label: 'Attended',
            active: entry.attended == true,
            activeColor: const Color(0xFF2E7D32),
            onTap: () => _setAttendance(entry, true),
          ),
          seg(
            label: 'No-show',
            active: entry.attended == false,
            activeColor: const Color(0xFFC62828),
            onTap: () => _setAttendance(entry, false),
          ),
        ],
      ),
    );
  }

  // ── Small building blocks ──────────────────────────────────────
  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label,
                style: TextStyle(
                    color: _secondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: _text, fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _readChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: MoydMapTheme.unityBlue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(
                color: _action,
                fontSize: 11,
                fontWeight: FontWeight.w800)),
      );

  Widget _emptyNote(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _inset,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _divider),
        ),
        child: Text(text, style: TextStyle(color: _secondary, fontSize: 12.5)),
      );

  Widget _avatar(String? url, String name) {
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(url,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _initialsAvatar(name)),
      );
    }
    return _initialsAvatar(name);
  }

  Widget _initialsAvatar(String name) => Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: MapPalette.avatarColorFor(name),
          shape: BoxShape.circle,
        ),
        child: Text(_initials(name),
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      );

  List<String> _geoLabels() => [
        for (final c in _activity.counties) '$c County',
        for (final d in _activity.congressionalDistricts) 'CD $d',
        for (final d in _activity.senateDistricts) 'SD $d',
        for (final d in _activity.houseDistricts) 'HD $d',
      ];

  static const Map<String, String> _channelLabels = <String, String>{
    'in_person': 'In person',
    'sms': 'Text',
    'email': 'Email',
    'phone': 'Phone',
    'social': 'Social',
  };

  String _channelLabel(String key) => _channelLabels[key] ?? key;

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  // Immutable ActivityRosterEntry rebuild helpers for optimistic updates.
  ActivityRosterEntry _withAttendance(ActivityRosterEntry e, bool attended) =>
      ActivityRosterEntry(
        participantId: e.participantId,
        memberId: e.memberId,
        memberName: e.memberName,
        memberAvatarUrl: e.memberAvatarUrl,
        role: e.role,
        attended: attended,
      );

  ActivityRosterEntry _withRole(ActivityRosterEntry e, String role) =>
      ActivityRosterEntry(
        participantId: e.participantId,
        memberId: e.memberId,
        memberName: e.memberName,
        memberAvatarUrl: e.memberAvatarUrl,
        role: role,
        attended: e.attended,
      );
}

enum _CompleteChoice { recordNow, skip }
