import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/outreach_activity.dart';
import 'package:bluebubbles/services/crm/outreach_repository.dart';

import 'volunteers_map_models.dart';
import 'volunteers_theme.dart';

// ═══════════════════════════════════════════════════════════════
//  ADD-TO-ACTIVITY PICKER
//  Drops an audience onto an existing planned or in-progress activity in a
//  region, or reports that the caller should open the create flow instead.
//  Returns an [AddToActivityChoice]; the caller does the follow-up, so this
//  sheet stays region-agnostic and knows nothing about the Desk.
//
//  It moved out of volunteers_detail_panel.dart when outreach left the map:
//  the members pane no longer owns any action that sends or schedules, and
//  the Desk's PLAN section is now the only caller. Behavior is unchanged.
// ═══════════════════════════════════════════════════════════════

enum AddToActivityKind { added, newActivity, failed }

class AddToActivityChoice {
  const AddToActivityChoice.added(this.addedCount, this.title)
      : kind = AddToActivityKind.added;
  const AddToActivityChoice.newActivity()
      : kind = AddToActivityKind.newActivity,
        addedCount = 0,
        title = '';
  const AddToActivityChoice.failed(this.title)
      : kind = AddToActivityKind.failed,
        addedCount = 0;

  final AddToActivityKind kind;

  /// New participant rows the repository actually inserted (0 when every
  /// member handed in was already on the activity).
  final int addedCount;
  final String title;
}

class AddToActivitySheet extends StatefulWidget {
  const AddToActivitySheet({
    super.key,
    required this.mode,
    required this.regionId,
    required this.members,
  });

  final MapMode mode;
  final String regionId;
  final List<Member> members;

  /// Modal entry point. Null on dismiss.
  static Future<AddToActivityChoice?> show(
    BuildContext context, {
    required MapMode mode,
    required String regionId,
    required List<Member> members,
  }) {
    return showModalBottomSheet<AddToActivityChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddToActivitySheet(
        mode: mode,
        regionId: regionId,
        members: members,
      ),
    );
  }

  @override
  State<AddToActivitySheet> createState() => _AddToActivitySheetState();
}

class _AddToActivitySheetState extends State<AddToActivitySheet> {
  final OutreachRepository _repo = OutreachRepository();

  List<OutreachActivity> _activities = const <OutreachActivity>[];
  bool _loading = true;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _repo.activitiesForRegion(widget.mode, widget.regionId);
      if (!mounted) return;
      // Only the actionable activities: planned or in progress. Filtered
      // client-side so the repository stays a plain region query.
      setState(() {
        _activities = rows
            .where((a) => a.status == 'planned' || a.status == 'in_progress')
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activities = const <OutreachActivity>[];
        _loading = false;
      });
    }
  }

  Future<void> _addTo(OutreachActivity activity) async {
    if (_adding) return;
    setState(() => _adding = true);
    final inputs = widget.members
        .map((m) => OutreachParticipantInput(memberId: m.id))
        .toList();
    // PINNED: addParticipants dedupes on (activity_id, member_id) and returns
    // the count of newly inserted rows; it rethrows on a rejected write so a
    // failure is not mistaken for "everyone was already on the activity".
    AddToActivityChoice result;
    try {
      final added = await _repo.addParticipants(activity.id, inputs);
      result = AddToActivityChoice.added(added, activity.title);
    } catch (_) {
      result = AddToActivityChoice.failed(activity.title);
    }
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final vt = VolunteersTheme.of(context);
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.8;
    final n = widget.members.length;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: vt.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(vt, n),
              Flexible(
                child: _loading
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: vt.accent),
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                        children: [
                          _newActivityTile(vt),
                          const SizedBox(height: 12),
                          if (_activities.isEmpty)
                            _emptyNote(vt)
                          else
                            ...[for (final a in _activities) _activityRow(vt, a)],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(VolunteersTheme vt, int n) {
    return Container(
      decoration: BoxDecoration(
        gradient: BrandColors.getTileGradient(),
        border: Border(bottom: BorderSide(color: vt.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      child: Row(
        children: [
          _iconTile(Icons.playlist_add),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add $n member${n == 1 ? '' : 's'} to an activity',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        shadows: _onGradient)),
                const SizedBox(height: 4),
                Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: vt.highlight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _newActivityTile(VolunteersTheme vt) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _adding
              ? null
              : () => Navigator.of(context)
                  .pop(const AddToActivityChoice.newActivity()),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: vt.highlight),
            ),
            child: Row(
              children: [
                Icon(Icons.add_circle_outline, size: 20, color: vt.text),
                const SizedBox(width: 12),
                Text('New activity',
                    style: TextStyle(
                        color: vt.text,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      );

  Widget _emptyNote(VolunteersTheme vt) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: vt.inset,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: vt.divider),
        ),
        child: Text('No planned activities in this region yet.',
            style: TextStyle(color: vt.secondary, fontSize: 12.5)),
      );

  Widget _activityRow(VolunteersTheme vt, OutreachActivity a) {
    final kind = OutreachDisplay.kinds[a.kind];
    final status = OutreachDisplay.statuses[a.status];
    return BrandedActivityFeedItem(
      leadingWidget: _iconTile(kind?.icon ?? a.kindIcon),
      primaryText: a.title,
      // Never an empty second line: fall back to the kind when an activity
      // carries no date, the same way the rail's This-week rows read.
      secondaryText: [
        if (a.scheduledOn != null) _fmtDate(a.scheduledOn!),
        kind?.label ?? a.kindLabel,
      ].join(' · '),
      onTap: _adding ? null : () => _addTo(a),
      trailing: _statusBadge(
        status?.label ?? a.statusLabel,
        fill: status?.color ?? a.statusColor,
      ),
    );
  }

  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';
}

/// The kit's contrast shadow. White text on the light end of the gradient
/// drops under 3:1 on its own; this is the shadow BrandedStatCard uses to
/// hold it legible wherever the gradient lands.
const List<Shadow> _onGradient = <Shadow>[
  Shadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 2),
];

/// The kit's signature icon tile: a white-20% square holding a white glyph,
/// sized to sit flush with the 36px avatars in the branded feed rows.
Widget _iconTile(IconData icon) => Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: Colors.white),
    );

/// Compact status pill. The status fills come from [OutreachDisplay] and are
/// chosen there to carry white text at 4.5:1; this carries no guarantee of
/// its own for an overridden fill.
Widget _statusBadge(String label, {required Color fill}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w800)),
    );
