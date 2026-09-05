import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/outreach_activity.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/outreach_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/screens/crm/bulk_email_screen.dart';
import 'package:bluebubbles/screens/crm/bulk_message_screen.dart';
import 'package:bluebubbles/screens/crm/volunteers/organizing_toolkit_sheet.dart';

// ═══════════════════════════════════════════════════════════════
//  ACTIVITY DETAIL (full-screen route)
//
//  Roster + attendance + status transitions for a single outreach activity.
//  Reads the roster via OutreachRepository.getRoster and drives every write
//  (status, role, attendance) back through the repository. "Text roster" /
//  "Email roster" resolve the roster's member ids to Member objects and hand
//  them to the shipped bulk screens.
//
//  Painted in the Slack management language: BrandedBackground page, gradient
//  header band, BrandedCard surfaces, white-pill roster rows.
// ═══════════════════════════════════════════════════════════════

const List<String> _kRoles = <String>['volunteer', 'captain', 'organizer'];

/// Fill + foreground for a filled status chip on a branded gradient.
///
/// The foreground is picked per fill rather than fixed to white: the three
/// brand state colors are light enough that white 10-12px text lands near
/// 2.5:1 on them, while unityBlue clears 4.5:1 on all three. Cancelled
/// inverts (navy fill, white text) so a dead activity reads as recessed
/// rather than as another state color.
///
/// Shared by the hub, this screen and the region section so the three
/// surfaces cannot drift apart.
({Color fill, Color fg}) outreachStatusStyle(String status) {
  switch (status) {
    case 'planned':
      return (fill: BrandColors.momentumBlue, fg: BrandColors.unityBlue);
    case 'in_progress':
      return (fill: BrandColors.warning, fg: BrandColors.unityBlue);
    case 'completed':
      return (fill: BrandColors.success, fg: BrandColors.unityBlue);
    default:
      return (fill: BrandColors.unityBlue, fg: Colors.white);
  }
}

/// Filled-red chips use the deeper red rather than BrandColors.error: white on
/// #EF4444 measures 3.76:1 and unityBlue on it 3.32:1, so neither foreground
/// clears the bar, while white on red.shade700 (#D32F2F) measures 4.98:1.
/// Error itself is still the right color for the large glyphs and tinted
/// circles in the error state, where the 3:1 graphic threshold applies.
final Color outreachDangerFill = Colors.red.shade700;

/// Red for the overdue chip, whose icon and label sit on a SOLID
/// BrandColors.unityBlue fill at 10px bold. 10px bold is nowhere near the WCAG
/// large-text exemption, which needs 18.66px bold or 24px regular, so the
/// 4.5:1 normal-text floor binds.
///
/// Colors.red.shade200 (#EF9A9A) measures 5.81:1 on #273351. shade300
/// (#E57373) stood here and measures 4.19:1, which fails, and the comment it
/// carried claimed 5.1:1 and was simply wrong. Every ratio named in this file
/// is computed from WCAG 2.x relative luminance against the ground it names.
final Color outreachDangerInk = Colors.red.shade200;

/// Opaque surface for the loading, empty and error blocks on both outreach
/// screens.
///
/// Those blocks are centred, so they render at the MIDDLE of the page, and the
/// window is resizable, so no horizontal position is knowable in advance. They
/// therefore cannot take their legibility from the page ground.
///
/// BrandedBackground paints assets/images/Blue-Gradient-Background.png under
/// Colors.white at 0.18 (brand_colors.dart). Decoding that asset shows a
/// 3000x2400 image whose gradient is purely HORIZONTAL and constant down every
/// column, running #37ACE7 at the left edge to #1E2F48 at the right, so the
/// composited ground runs #5BBBEB to #465469 across the window.
///
/// No single foreground clears even the 3:1 graphic floor against both ends of
/// that ground: unityBlue measures 5.81:1 at the far left and 1.63:1 at the far
/// right, white measures 2.15:1 and 7.69:1 the other way, and pure black still
/// only reaches 2.73:1 at the right. So the fix is a surface rather than a
/// color, which is what the branded cards already do.
///
/// On the opaque #FFFFFF this returns, the palette these blocks already use is
/// measured: unityBlue headings 12.51:1, unityBlue at 0.7 alpha body copy
/// 4.95:1, the unityBlue glyph on the momentumBlue 0.15 circle 10.87:1, the
/// BrandColors.error glyph on the error 0.12 circle 3.23:1, white on the
/// unityBlue button 12.51:1 and unityBlue on the sunriseGold button 7.17:1.
///
/// Shared by the hub and this screen so the two cannot drift apart, the same
/// reason outreachStatusStyle above is shared.
Widget outreachStateSurface({required Widget child}) {
  return Center(
    // Scrolls rather than overflows: the card adds padding of its own, so on a
    // short window the taller empty state would otherwise not fit.
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        // Caps the card on a wide window; it still shrink-wraps a small child
        // such as the loading indicator.
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          elevation: 4,
          margin: EdgeInsets.zero,
          // Named rather than taken from the theme: this sits on the branded
          // page in both light and dark, so a theme surface color would move
          // the ground the ratios above are measured against.
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: child,
          ),
        ),
      ),
    ),
  );
}

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

  /// Who owns this activity and who filed it. Null until resolved, and null
  /// forever for a row whose column was never stamped, which is every activity
  /// created before organizer_member_id started being written.
  String? _organizerName;
  String? _createdByName;

  bool _loading = true;
  bool _errored = false;
  bool _busy = false; // guards bulk/status writes

  /// Which roster-wide action is in flight, so only that button swaps its icon
  /// for a spinner instead of the whole card going ambiguous.
  _PendingAction? _pending;

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
      final names = await _resolveAttribution();
      if (!mounted) return;
      setState(() {
        _roster = roster;
        _nomineeCount = nominees;
        _organizerName = names.organizer;
        _createdByName = names.creator;
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

  /// Both attribution names in one query.
  ///
  /// THE TRAP: created_by references auth.users(id) and organizer_member_id
  /// references public.members(id). Both are bare uuids, so the only thing
  /// keeping them apart is resolving each through the right column,
  /// members.user_id for the first and members.id for the second. Swap them and
  /// the screen silently shows nobody.
  ///
  /// It reads members directly because neither repository exposes a user_id
  /// lookup today. Fold it into OutreachRepository when one lands. Failure is
  /// swallowed on purpose: a missing name must never blank the roster.
  Future<({String? organizer, String? creator})> _resolveAttribution() async {
    const empty = (organizer: null, creator: null);
    final organizerMemberId = _activity.organizerMemberId;
    final creatorUserId = _activity.createdBy;

    final filters = <String>[
      if (organizerMemberId != null) 'id.eq.$organizerMemberId',
      if (creatorUserId != null) 'user_id.eq.$creatorUserId',
    ];
    if (filters.isEmpty) return empty;

    final supabase = CRMSupabaseService();
    if (!supabase.isInitialized) return empty;

    try {
      final response = await supabase.client
          .from('members')
          .select('id, user_id, name')
          .or(filters.join(','));

      String? organizer;
      String? creator;
      for (final row in (response as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()) {
        final name = (row['name'] as String?)?.trim();
        if (name == null || name.isEmpty) continue;
        // The null guards are load-bearing: a member row with no auth account
        // carries user_id null, which would match a null creatorUserId and
        // credit the organizer with creating the activity.
        if (organizerMemberId != null && row['id'] == organizerMemberId) {
          organizer = name;
        }
        if (creatorUserId != null && row['user_id'] == creatorUserId) {
          creator = name;
        }
      }
      return (organizer: organizer, creator: creator);
    } catch (_) {
      return empty;
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: BrandColors.unityBlue,
      behavior: SnackBarBehavior.floating,
    ));
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
    setState(() {
      _busy = true;
      _pending = _PendingAction.markAll;
    });
    var failed = false;
    for (final memberId in pending) {
      try {
        await _repo.setAttendance(_activity.id, memberId, true);
      } catch (_) {
        failed = true;
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _pending = null;
    });
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
        backgroundColor: BrandColors.unityBlue,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Record attendance first?',
            style: BrandTextStyles.title),
        content: Text(
          '$unrecorded ${unrecorded == 1 ? 'person has' : 'people have'} no '
          'attendance recorded. Record who showed before completing?',
          style: BrandTextStyles.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_CompleteChoice.recordNow),
            style: TextButton.styleFrom(
                foregroundColor: BrandColors.sunriseGold),
            child: const Text('Record now',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_CompleteChoice.skip),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
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
    setState(() {
      _busy = true;
      _pending = _PendingAction.text;
    });
    final members = await _resolveRosterMembers();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _pending = null;
    });
    if (members == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BulkMessageScreen(initialManualMembers: members),
      ),
    );
  }

  Future<void> _emailRoster() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _pending = _PendingAction.email;
    });
    final members = await _resolveRosterMembers();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _pending = null;
    });
    if (members == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BulkEmailScreen(initialManualMembers: members),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The gradient fallback under BrandedBackground's asset, so a slow or
      // missing image never flashes a white page behind the header band.
      backgroundColor: BrandColors.unityBlue,
      body: BrandedBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _headerBand(),
              Expanded(
                child: _loading
                    ? outreachStateSurface(
                        child: const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.6,
                              color: BrandColors.unityBlue),
                        ),
                      )
                    : _errored
                        ? _errorState()
                        : _content(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header band ────────────────────────────────────────────────
  Widget _headerBand() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
      decoration: BoxDecoration(gradient: BrandColors.getTileGradient()),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            tooltip: 'Back',
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_activity.kindIcon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_activity.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: BrandTextStyles.title),
                  const SizedBox(height: 2),
                  Text(_activity.kindLabel,
                      style: BrandTextStyles.caption),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _statusMenu(),
          ),
        ],
      ),
    );
  }

  Widget _statusMenu() {
    final transitions = _allowedTransitions;
    final style = outreachStatusStyle(_activity.status);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: style.fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_activity.statusLabel,
              style: TextStyle(
                  color: style.fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
          if (transitions.isNotEmpty) ...[
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 16, color: style.fg),
          ],
        ],
      ),
    );

    if (transitions.isEmpty || _busy) return chip;

    return PopupMenuButton<String>(
      tooltip: 'Change status',
      color: BrandColors.unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: _requestStatus,
      itemBuilder: (_) => [
        for (final target in transitions)
          PopupMenuItem<String>(
            value: target,
            child: Text(_transitionLabel(target),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
      ],
      child: chip,
    );
  }

  // ── Body ───────────────────────────────────────────────────────
  Widget _content() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _rosterCard(),
                ),
              ),
              Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                  child: _infoCard(),
                ),
              ),
            ],
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _infoCard(),
              const SizedBox(height: 24),
              _rosterCard(),
            ],
          ),
        );
      },
    );
  }

  Widget _errorState() {
    return outreachStateSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: BrandColors.error.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline,
                size: 56, color: BrandColors.error),
          ),
          const SizedBox(height: 20),
          const Text(
            'Could not load this activity',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: BrandColors.unityBlue,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The roster and attendance could not be read. Check the '
            'connection and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: BrandColors.unityBlue.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _load,
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.unityBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ── Info card ──────────────────────────────────────────────────
  Widget _infoCard() {
    final geo = _geoLabels();
    return BrandedCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.info_outline,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                  child: Text('Details', style: BrandTextStyles.title)),
              IconButton(
                onPressed: _busy ? null : _editDetails,
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                disabledColor: Colors.white38,
                tooltip: 'Edit details',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _kv(
              'Date',
              _activity.scheduledOn == null
                  ? 'No date set'
                  : _fmtDate(_activity.scheduledOn!)),
          _kv('Nominees',
              _nomineeCount == 1 ? '1 nominee' : '$_nomineeCount nominees'),
          if (_activity.channel != null)
            _kv('Channel', _channelLabel(_activity.channel!)),
          if (_organizerName != null) _kv('Organized by', _organizerName!),
          if (_createdByName != null) _kv('Created by', _createdByName!),
          if (_activity.createdAt != null)
            _kv('Created', _fmtDate(_activity.createdAt!)),
          if (_activity.completedAt != null)
            _kv('Completed', _fmtDate(_activity.completedAt!)),
          if (geo.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final g in geo) _pill(g)],
            ),
          ],
          if (_activity.description != null &&
              _activity.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('NOTES',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Text(_activity.description!,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14, height: 1.4)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _secondaryAction(
                  icon: Icons.sms_outlined,
                  label: 'Text roster',
                  busy: _pending == _PendingAction.text,
                  onTap: _textRoster,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _secondaryAction(
                  icon: Icons.mail_outline,
                  label: 'Email roster',
                  busy: _pending == _PendingAction.email,
                  onTap: _emailRoster,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Full edit of everything the row stores, through the same toolkit form the
  /// rest of the CRM plans with. The form hands the edited row straight back,
  /// so the screen repaints without a re-fetch; the roster and the nominee
  /// links are untouched by an edit and stay as loaded.
  Future<void> _editDetails() async {
    await OrganizingToolkitSheet.show(
      context,
      existing: _activity,
      onSaved: (updated) {
        if (!mounted) return;
        setState(() => _activity = updated);
      },
    );
  }

  Widget _secondaryAction({
    required IconData icon,
    required String label,
    required bool busy,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white54,
        side: const BorderSide(color: Colors.white70),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Icon(icon, size: 18),
      label: Text(label,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
    );
  }

  // ── Roster card ────────────────────────────────────────────────
  Widget _rosterCard() {
    final rostered = _roster.length;
    final attended = _roster.where((e) => e.attended == true).length;
    final noShow = _roster.where((e) => e.attended == false).length;
    final unrecorded = _roster.where((e) => e.attended == null).length;
    final anyPending = _roster.any((e) => e.attended != true);

    return BrandedCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.groups_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                  child: Text('Roster', style: BrandTextStyles.title)),
              if (anyPending)
                ElevatedButton.icon(
                  onPressed: _busy ? null : _markAllAttended,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.sunriseGold,
                    foregroundColor: BrandColors.unityBlue,
                    disabledBackgroundColor:
                        BrandColors.sunriseGold.withValues(alpha: 0.5),
                    disabledForegroundColor: BrandColors.unityBlue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _pending == _PendingAction.markAll
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: BrandColors.unityBlue),
                        )
                      : const Icon(Icons.done_all, size: 16),
                  label: const Text('Mark all attended',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _pill('$rostered rostered'),
              // The three attendance states carry their own fills so the split
              // reads without counting: null stays navy because "not yet
              // recorded" must not look like a decision.
              _countChip('$attended attended', BrandColors.success,
                  BrandColors.unityBlue),
              _countChip('$noShow no-show', outreachDangerFill, Colors.white),
              _countChip('$unrecorded unrecorded', BrandColors.unityBlue,
                  Colors.white),
            ],
          ),
          const SizedBox(height: 14),
          if (_roster.isEmpty)
            _inCardEmpty(
              icon: Icons.person_add_alt_1_outlined,
              title: 'Nobody on the roster yet',
              body: 'Add volunteers from the organizing toolkit, then record '
                  'who showed up here.',
            )
          else
            for (final entry in _roster) _rosterRow(entry),
        ],
      ),
    );
  }

  Widget _rosterRow(ActivityRosterEntry entry) {
    return BrandedActivityFeedItem(
      primaryText: entry.memberName,
      secondaryText: _roleLabel(entry.role),
      showChevron: false,
      leadingWidget: CorsAwareAvatar(
        imageUrl: entry.memberAvatarUrl,
        radius: 18,
        backgroundColor: Colors.white.withValues(alpha: 0.2),
        fallbackText: entry.memberName,
        fallbackTextColor: Colors.white,
        fallbackIconColor: Colors.white,
      ),
      trailing: _roleDropdown(entry),
      expansion: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: _attendanceControl(entry),
      ),
    );
  }

  Widget _roleDropdown(ActivityRosterEntry entry) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _kRoles.contains(entry.role) ? entry.role : 'volunteer',
          isDense: true,
          icon: const Icon(Icons.expand_more, color: Colors.white70, size: 18),
          dropdownColor: BrandColors.unityBlue,
          borderRadius: BorderRadius.circular(12),
          style: const TextStyle(
              color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
          items: [
            for (final r in _kRoles)
              DropdownMenuItem<String>(
                value: r,
                child: Text(_roleLabel(r)),
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
      required Color fill,
      required Color fg,
      VoidCallback? onTap,
    }) {
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? fill : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(label,
                  style: TextStyle(
                      color: active ? fg : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // "Unrecorded" shows the null state but cannot be re-selected: there
          // is no clear-to-null write, and null is deliberately distinct from
          // a recorded no-show.
          seg(
            label: 'Unrecorded',
            active: entry.attended == null,
            fill: BrandColors.unityBlue,
            fg: Colors.white,
            onTap: null,
          ),
          seg(
            label: 'Attended',
            active: entry.attended == true,
            fill: BrandColors.success,
            fg: BrandColors.unityBlue,
            onTap: () => _setAttendance(entry, true),
          ),
          seg(
            label: 'No-show',
            active: entry.attended == false,
            fill: outreachDangerFill,
            fg: Colors.white,
            onTap: () => _setAttendance(entry, false),
          ),
        ],
      ),
    );
  }

  // ── Small building blocks ──────────────────────────────────────
  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      );

  Widget _countChip(String label, Color fill, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                color: fg, fontSize: 11, fontWeight: FontWeight.w800)),
      );

  Widget _inCardEmpty({
    required IconData icon,
    required String title,
    required String body,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(body,
                textAlign: TextAlign.center,
                style: BrandTextStyles.caption),
          ],
        ),
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

  String _roleLabel(String role) =>
      role.isEmpty ? role : '${role[0].toUpperCase()}${role.substring(1)}';

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

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

/// The roster-wide writes that own a spinner while they run.
enum _PendingAction { text, email, markAll }
