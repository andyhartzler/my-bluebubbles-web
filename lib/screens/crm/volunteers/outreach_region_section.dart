import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/outreach_activity.dart';
import 'package:bluebubbles/models/crm/outreach_touchpoint.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/outreach_repository.dart';
import 'package:bluebubbles/services/crm/touchpoint_repository.dart';

import 'activity_detail_screen.dart' show outreachStatusStyle;
import 'organizing_toolkit_sheet.dart';
import 'volunteers_map_models.dart';

// ═══════════════════════════════════════════════════════════════
//  REGION ORGANIZING SECTION (Layer 2 of Candidate Volunteers)
//  Two blocks mounted in the region detail panel between the candidates and
//  members sections:
//
//   • RECENT CONTACT: what execs have actually sent into this region, read
//     from outreach_touchpoints. This is the half that makes a send "saved to
//     the region's profile" true rather than only visible to whoever sent it.
//     The Desk writes those rows automatically, so nothing here depends on an
//     exec remembering to log anything.
//   • ORGANIZING: the planned field work that covered this region, which
//     opens the OrganizingToolkitSheet in edit/read mode.
//
//  Painted as BrandedCards rather than as loose rows: the section sits inside
//  a panel this file does not own, and self-contained gradient cards keep the
//  white-on-navy row language correct whatever is behind them.
// ═══════════════════════════════════════════════════════════════

class RegionOutreachSection extends StatefulWidget {
  const RegionOutreachSection({
    super.key,
    required this.mode,
    required this.regionId,
  });

  final MapMode mode;
  final String regionId;

  @override
  State<RegionOutreachSection> createState() => _RegionOutreachSectionState();
}

class _RegionOutreachSectionState extends State<RegionOutreachSection> {
  final OutreachRepository _repo = OutreachRepository();
  final TouchpointRepository _touchpoints = TouchpointRepository();
  final MemberRepository _memberRepo = MemberRepository();

  List<OutreachActivity> _activities = const [];
  bool _loading = true;

  List<OutreachTouchpoint> _contacts = const [];

  /// members.id -> display name, for the "by whom" line. The key is
  /// `actor_member_id`, a members.id, NOT the row's auth.users.id.
  Map<String, String> _authors = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RegionOutreachSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode ||
        oldWidget.regionId != widget.regionId) {
      _load();
    }
  }

  /// The two blocks load independently so a failure in one does not blank the
  /// other: they answer different questions and neither is a fallback for the
  /// other.
  Future<void> _load() =>
      Future.wait(<Future<void>>[_loadActivities(), _loadContacts()]);

  Future<void> _loadActivities() async {
    setState(() => _loading = true);
    try {
      final rows = await _repo.activitiesForRegion(widget.mode, widget.regionId);
      if (!mounted) return;
      setState(() {
        _activities = rows;
        _loading = false;
      });
    } catch (e) {
      debugPrint('RegionOutreachSection load failed: $e');
      if (!mounted) return;
      setState(() {
        _activities = const [];
        _loading = false;
      });
    }
  }

  Future<void> _loadContacts() async {
    try {
      final rows =
          await _touchpoints.forRegion(widget.mode, widget.regionId);
      final authors = await _authorNames(rows);
      if (!mounted) return;
      setState(() {
        _contacts = rows;
        _authors = authors;
      });
    } catch (e) {
      debugPrint('RegionOutreachSection contact load failed: $e');
      if (!mounted) return;
      setState(() {
        _contacts = const [];
        _authors = const {};
      });
    }
  }

  Future<Map<String, String>> _authorNames(
      List<OutreachTouchpoint> rows) async {
    final ids = <String>{for (final t in rows) t.actorMemberId}.toList();
    if (ids.isEmpty) return const {};
    final members = await _memberRepo.membersByIds(ids);
    return <String, String>{for (final m in members) m.id: m.name};
  }

  Future<void> _open(OutreachActivity activity) async {
    final saved = await OrganizingToolkitSheet.show(context, existing: activity);
    if (saved == true) _loadActivities();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Absent rather than empty. A region nobody has contacted should read
        // as a quiet panel, not as a card explaining its own emptiness; the
        // block appears the moment a send lands on it.
        if (_contacts.isNotEmpty) ...[
          _contactCard(),
          const SizedBox(height: 16),
        ],
        _organizingCard(),
      ],
    );
  }

  Widget _contactCard() => BrandedCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeader(
              icon: Icons.forum_outlined,
              title: 'Recent contact',
              count: _contacts.length,
            ),
            const SizedBox(height: 12),
            for (final t in _contacts) _contactRow(t),
          ],
        ),
      );

  Widget _organizingCard() => BrandedCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeader(
              icon: Icons.campaign_outlined,
              title: 'Organizing',
              count: _loading ? 0 : _activities.length,
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white),
                  ),
                ),
              )
            else if (_activities.isEmpty)
              _emptyNote()
            else
              for (final a in _activities) _activityRow(a),
          ],
        ),
      );

  Widget _cardHeader({
    required IconData icon,
    required String title,
    required int count,
  }) =>
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: BrandTextStyles.title)),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('$count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800)),
            ),
        ],
      );

  /// One bulk contact, read-only. No tap: the region is where this is
  /// reported, not where it is worked. The exec who sent it owns it from the
  /// Desk.
  Widget _contactRow(OutreachTouchpoint t) {
    final author = _authors[t.actorMemberId];
    return BrandedActivityFeedItem(
      primaryText: '${t.channelLabel} to ${t.attemptedCount}',
      secondaryText: <String>[
        if (author != null && author.isNotEmpty) author,
        if (t.sentAt != null) _fmtDate(t.sentAt!.toLocal()),
      ].join('  ·  '),
      // The outcome only earns a third line when it is not the plain one.
      tertiaryText: t.status == 'sent' ? null : t.outcomeSummary,
      leadingIcon: t.channelIcon,
      showChevron: false,
      // The status colors are computed for white text on this fill; the
      // lightest of them measures 4.83:1.
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: t.statusColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(t.statusLabel.toUpperCase(),
            style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _emptyNote() => Container(
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
              child: const Icon(Icons.event_available,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(height: 10),
            const Text('Nothing organized here yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
              'Canvasses, phone banks and days of action that cover this '
              'region show up here once one is planned.',
              textAlign: TextAlign.center,
              style: BrandTextStyles.caption,
            ),
          ],
        ),
      );

  Widget _activityRow(OutreachActivity a) {
    final style = outreachStatusStyle(a.status);
    return BrandedActivityFeedItem(
      primaryText: a.title,
      secondaryText: _subline(a),
      leadingIcon: a.kindIcon,
      onTap: () => _open(a),
      // The feed item's own action pill is always white-on-fill, which the
      // light state colors cannot carry; this owns the right edge instead.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: style.fill,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(a.statusLabel.toUpperCase(),
                style: TextStyle(
                    color: style.fg,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
        ],
      ),
    );
  }

  String _subline(OutreachActivity a) {
    final parts = <String>[a.kindLabel];
    if (a.scheduledOn != null) parts.add(_fmtDate(a.scheduledOn!));
    return parts.join('  ·  ');
  }

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';
}
