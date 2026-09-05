import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/outreach_activity.dart';
import 'package:bluebubbles/models/crm/outreach_touchpoint.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';

// ═══════════════════════════════════════════════════════════════
//  PROFILE OUTREACH CARDS (Layer 2 of Candidate Volunteers)
//
//  The nominee detail screen and the member detail screen each carry the same
//  two blocks: what we have SENT to or about this person (touchpoints) and
//  what we have ORGANIZED with them (activities). The two screens had
//  independent copies of the header, the activity row, the status chip and the
//  date formatter, which is four chances for the same card to drift into two
//  cards. They live here once instead.
//
//  DELIBERATELY Theme.of, unlike everything else in this directory. These
//  cards mount on the ordinary CRM detail screens, not on the war-room
//  surfaces, so they take the app's own scheme; painting them navy would leave
//  a branded island in the middle of a Material page. The fixed VolunteersTheme
//  palette stays for the map, the panel, the Desk and the toolkit.
// ═══════════════════════════════════════════════════════════════

/// Compact "MMM d, yyyy" date, shared by the outreach sections without pulling
/// in intl.
String outreachFormatDate(DateTime date) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

/// The card shell both blocks sit in: a hairline-outlined surface at radius 16.
class OutreachProfileCard extends StatelessWidget {
  const OutreachProfileCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side:
            BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [child],
        ),
      ),
    );
  }
}

/// A primary-filled badge, the title, and an optional count chip.
class OutreachProfileHeader extends StatelessWidget {
  const OutreachProfileHeader({
    super.key,
    required this.icon,
    required this.title,
    this.count,
  });

  final IconData icon;
  final String title;

  /// Null while loading; the chip appears once there is a number and it is
  /// greater than zero.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = count;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: theme.colorScheme.onPrimary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (n != null && n > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$n',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

/// One compact activity row: kind icon, title, scheduled date, status chip.
class OutreachProfileActivityRow extends StatelessWidget {
  const OutreachProfileActivityRow({
    super.key,
    required this.activity,
    required this.onTap,
  });

  final OutreachActivity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(activity.kindIcon,
                size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (activity.scheduledOn != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        outreachFormatDate(activity.scheduledOn!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutreachStatusPill(
              label: activity.statusLabel,
              fill: activity.statusColor,
            ),
          ],
        ),
      ),
    );
  }
}

/// A status fill with white text. Every colour it is handed comes from
/// [OutreachDisplay.statuses] or [TouchpointDisplay.statuses], both of which
/// are chosen so white on them clears 4.5:1; the lightest of the ten is the
/// touchpoint 'draft' grey at 4.83:1.
class OutreachStatusPill extends StatelessWidget {
  const OutreachStatusPill({super.key, required this.label, required this.fill});

  final String label;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// "Recent contact": the bulk sends that reached this profile, newest first.
///
/// The Mobilize Desk writes these rows automatically on every send, so nothing
/// here depends on an exec remembering to log anything. That is what makes a
/// send "saved to the profile" true rather than only visible to whoever sent
/// it (spec 4.4, Phase 6).
///
/// ABSENT RATHER THAN EMPTY, exactly as on the region panel: a profile nobody
/// has contacted should read as a quiet page, not as a card explaining its own
/// emptiness. The block appears the moment a send lands on it.
class RecentContactCard extends StatefulWidget {
  const RecentContactCard({super.key, required this.load});

  /// What to fetch. The two profiles filter on different GIN-indexed arrays
  /// (candidate_ids, recipient_member_ids), which is the only thing that
  /// differs between them, so it is the only thing passed in.
  final Future<List<OutreachTouchpoint>> Function() load;

  @override
  State<RecentContactCard> createState() => _RecentContactCardState();
}

class _RecentContactCardState extends State<RecentContactCard> {
  final MemberRepository _memberRepo = MemberRepository();

  List<OutreachTouchpoint> _contacts = const <OutreachTouchpoint>[];

  /// members.id to display name for the "by whom" line. The key is
  /// `actor_member_id`, a members.id, NOT the row's auth.users.id (spec 4.1).
  Map<String, String> _authors = const <String, String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.load();
      final ids = <String>{for (final t in rows) t.actorMemberId}.toList();
      final members = ids.isEmpty
          ? const <Member>[]
          : await _memberRepo.membersByIds(ids);
      if (!mounted) return;
      setState(() {
        _contacts = rows;
        _authors = <String, String>{for (final m in members) m.id: m.name};
      });
    } catch (e) {
      debugPrint('RecentContactCard load failed: $e');
      if (!mounted) return;
      setState(() {
        _contacts = const <OutreachTouchpoint>[];
        _authors = const <String, String>{};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_contacts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    // The gap belongs to the card, not to the page: a caller that reserved it
    // would leave a hole on every profile that has never been contacted.
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: OutreachProfileCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutreachProfileHeader(
              icon: Icons.forum_outlined,
              title: 'Recent contact',
              count: _contacts.length,
            ),
            const SizedBox(height: 12),
            for (final t in _contacts) ...[
              _row(theme, t),
              const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }

  /// Read-only. The profile is where a send is reported, not where it is
  /// worked; the exec who sent it owns it from the Desk.
  Widget _row(ThemeData theme, OutreachTouchpoint t) {
    final author = _authors[t.actorMemberId];
    final sub = <String>[
      if (author != null && author.isNotEmpty) author,
      if (t.sentAt != null) outreachFormatDate(t.sentAt!.toLocal()),
    ].join('  ·  ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(t.channelIcon,
              size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t.channelLabel} to ${t.attemptedCount}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (sub.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutreachStatusPill(label: t.statusLabel, fill: t.statusColor),
        ],
      ),
    );
  }
}
