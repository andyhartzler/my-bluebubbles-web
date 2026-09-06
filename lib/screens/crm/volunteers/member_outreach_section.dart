import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/outreach_activity.dart';
import 'package:bluebubbles/models/crm/outreach_touchpoint.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/outreach_repository.dart';
import 'package:bluebubbles/services/crm/touchpoint_repository.dart';
import 'package:bluebubbles/screens/crm/volunteers/mobilize_models.dart';
import 'package:bluebubbles/screens/crm/volunteers/organizing_toolkit_sheet.dart';
import 'package:bluebubbles/screens/crm/volunteers/outreach_profile_cards.dart'
    show OutreachStatusPill, outreachFormatDate;
import 'package:bluebubbles/screens/crm/widgets/member_profile_sections.dart';

/// The member detail screen's outreach column: what has been SENT to this
/// member, then what has been ORGANIZED with them.
///
/// The contact block answers the question an exec actually has before picking
/// up the phone, which is "have we already messaged them this week", and it
/// renders itself only when there is something to report (spec 4.4, Phase 6).
///
/// This mounts inside the member profile's Outreach ProfileSectionCard, which
/// is a gradient card running BrandColors.tileGradient, so every colour here is
/// hard-coded from the profile idiom in member_profile_sections.dart and nothing
/// reads Theme.of. The shared Theme.of cards in outreach_profile_cards.dart stay
/// as they are for the candidate detail screen, which is an ordinary Material
/// page; only the two pure helpers, the status pill and the date formatter, are
/// shared with it. Readable text is FULL WHITE, 12.51:1 on unityBlue and 4.59:1
/// at the light end of the card. Rows sit on solid unityBlue blocks with a
/// hairline outline, the shape the sibling record cards on this page use, and
/// the one action is the emphasis pair, unityBlue on sunriseGold (7.17:1).
class MemberOutreachSection extends StatefulWidget {
  const MemberOutreachSection({super.key, required this.member});

  final Member member;

  @override
  State<MemberOutreachSection> createState() => _MemberOutreachSectionState();
}

class _MemberOutreachSectionState extends State<MemberOutreachSection> {
  final OutreachRepository _repo = OutreachRepository();
  final TouchpointRepository _touchpoints = TouchpointRepository();
  final MemberRepository _memberRepo = MemberRepository();

  bool _loading = true;
  Object? _error;
  List<OutreachActivity> _activities = const <OutreachActivity>[];

  /// The bulk sends that reached this member, newest first. The Mobilize Desk
  /// writes these rows automatically on every send, so nothing here depends on
  /// an exec remembering to log anything. ABSENT RATHER THAN EMPTY: a member
  /// nobody has contacted reads as a quiet card, not as a block explaining its
  /// own emptiness.
  List<OutreachTouchpoint> _contacts = const <OutreachTouchpoint>[];

  /// members.id to display name for the "by whom" line. The key is
  /// `actor_member_id`, a members.id, NOT the row's auth.users.id (spec 4.1).
  Map<String, String> _authors = const <String, String>{};

  /// How many recent rows to render before the "Plan activity" button.
  static const int _maxRows = 6;

  @override
  void initState() {
    super.initState();
    _load();
    _loadContacts();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _repo.activitiesForMember(widget.member.id);
      if (!mounted) return;
      setState(() {
        _activities = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadContacts() async {
    try {
      final rows = await _touchpoints.forMember(widget.member.id);
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
      debugPrint('MemberOutreachSection contacts load failed: $e');
      if (!mounted) return;
      setState(() {
        _contacts = const <OutreachTouchpoint>[];
        _authors = const <String, String>{};
      });
    }
  }

  /// Opens the shared toolkit sheet. A brand-new activity is seeded with this
  /// member on the roster and their county; an existing one opens on its own
  /// stored values, so the seed has nothing to say. Refreshes the list when the
  /// sheet reports a save. This screen has no Desk to scroll to, so it keeps
  /// the modal mount.
  Future<void> _openSheet({OutreachActivity? existing}) async {
    final saved = await OrganizingToolkitSheet.show(
      context,
      existing: existing,
      seed: existing == null
          ? OrganizingSeed.forMember(widget.member)
          : const OrganizingSeed.empty(),
    );

    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_contacts.isNotEmpty) ...[
          _subsectionHeader(
            icon: Icons.forum_outlined,
            title: 'Recent contact',
            count: _contacts.length,
          ),
          for (final t in _contacts) _contactRow(t),
          const SizedBox(height: 8),
        ],
        _subsectionHeader(
          icon: Icons.campaign_outlined,
          title: 'Organizing',
          count: _loading ? null : _activities.length,
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          )
        else if (_error != null)
          profileErrorBanner(
            title: 'Could not load activities.',
            message: 'Try again.',
          )
        else if (_activities.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Nothing organized with this member yet.',
              style: ProfileText.caption,
            ),
          )
        else
          for (final activity in _activities.take(_maxRows))
            _activityRow(activity),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: ProfileActionPill(
            icon: Icons.add,
            label: 'Plan activity',
            onPressed: () => _openSheet(),
          ),
        ),
      ],
    );
  }

  /// Subsection header in the profile idiom: an 18 px white icon, the label at
  /// 11 w700 uppercase, and the count as a solid unityBlue chip under white.
  /// The chip appears once there is a number and it is greater than zero.
  Widget _subsectionHeader({
    required IconData icon,
    required String title,
    int? count,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(title.toUpperCase(), style: ProfileText.label)),
          if (count != null && count > 0) profileChip('$count'),
        ],
      ),
    );
  }

  /// Read-only. The profile is where a send is reported, not where it is
  /// worked; the exec who sent it owns it from the Desk.
  Widget _contactRow(OutreachTouchpoint t) {
    final author = _authors[t.actorMemberId];
    final sub = <String>[
      if (author != null && author.isNotEmpty) author,
      if (t.sentAt != null) outreachFormatDate(t.sentAt!.toLocal()),
    ].join('  ·  ');
    return _row(
      icon: t.channelIcon,
      title: '${t.channelLabel} to ${t.attemptedCount}',
      subtitle: sub.isEmpty ? null : sub,
      trailing: OutreachStatusPill(label: t.statusLabel, fill: t.statusColor),
    );
  }

  Widget _activityRow(OutreachActivity activity) => _row(
        icon: activity.kindIcon,
        title: activity.title,
        subtitle: activity.scheduledOn == null
            ? null
            : outreachFormatDate(activity.scheduledOn!),
        trailing: OutreachStatusPill(
          label: activity.statusLabel,
          fill: activity.statusColor,
        ),
        onTap: () => _openSheet(existing: activity),
      );

  /// One row on a solid unityBlue block with a hairline outline: white 22 icon,
  /// the 17 w500 title, the 15 caption, the status pill, and a chevron when the
  /// row is tappable. White on the block is 12.51:1 wherever it sits on the
  /// card. Material(transparent) > InkWell, or the ripple is lost on the
  /// gradient.
  Widget _row({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final row = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: ProfileTokens.fill,
        borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
        border: Border.all(color: ProfileTokens.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: Colors.white),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ProfileText.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: ProfileText.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 22, color: Colors.white),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
        onTap: onTap,
        child: row,
      ),
    );
  }
}
