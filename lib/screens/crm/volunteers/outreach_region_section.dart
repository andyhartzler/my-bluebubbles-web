import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/outreach_activity.dart';
import 'package:bluebubbles/services/crm/outreach_repository.dart';

import 'activity_detail_screen.dart' show outreachStatusStyle;
import 'organizing_toolkit_sheet.dart';
import 'volunteers_map_models.dart';

// ═══════════════════════════════════════════════════════════════
//  REGION ORGANIZING SECTION (Layer 2 of Candidate Volunteers)
//  The recent-activity list mounted in the region detail panel between the
//  candidates and members sections. Loads the activities that covered the
//  current region and renders them as compact rows; tapping a row opens the
//  OrganizingToolkitSheet in edit/read mode.
//
//  Painted as ONE BrandedCard rather than as loose rows: the section sits
//  inside a panel this file does not own, and a self-contained gradient card
//  keeps the white-on-navy row language correct whatever is behind it.
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

  List<OutreachActivity> _activities = const [];
  bool _loading = true;

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

  Future<void> _load() async {
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

  Future<void> _open(OutreachActivity activity) async {
    final saved = await OrganizingToolkitSheet.show(context, existing: activity);
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
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
                child: const Icon(Icons.campaign_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                  child: Text('Organizing', style: BrandTextStyles.title)),
              if (!_loading && _activities.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${_activities.length}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800)),
                ),
            ],
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
