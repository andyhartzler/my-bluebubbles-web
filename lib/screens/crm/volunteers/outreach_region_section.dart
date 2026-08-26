import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/outreach_activity.dart';
import 'package:bluebubbles/services/crm/outreach_repository.dart';

import 'outreach_log_sheet.dart';
import 'volunteers_map_models.dart';

// ═══════════════════════════════════════════════════════════════
//  REGION OUTREACH SECTION (Layer 2 of Candidate Volunteers)
//  The recent-outreach list mounted in the region detail panel between the
//  candidates and members sections. Loads the activities that covered the
//  current region and renders them as compact rows; tapping a row opens the
//  OutreachLogSheet in edit/read mode.
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
    final saved = await OutreachLogSheet.show(context, existing: activity);
    if (saved == true) _load();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _inset => _isDark ? const Color(0xFF212B44) : const Color(0xFFF4F6FA);
  Color get _text => _isDark ? const Color(0xFFF4F6FA) : const Color(0xFF1E2637);
  Color get _secondary =>
      _isDark ? Colors.white.withValues(alpha: 0.72) : const Color(0xFF5A6478);
  Color get _divider =>
      _isDark ? const Color(0xFF2E3A57) : const Color(0xFFE5E9F0);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('OUTREACH'),
        const SizedBox(height: 12),
        if (_loading)
          _spinner()
        else if (_activities.isEmpty)
          _emptyNote()
        else
          ...[for (final a in _activities) _activityRow(a)],
      ],
    );
  }

  Widget _sectionHeader(String label) => Row(
        children: [
          Container(
            width: 20,
            height: 3,
            decoration: BoxDecoration(
              color: MoydMapTheme.gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label,
                style: TextStyle(
                    color: _secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1)),
          ),
        ],
      );

  Widget _spinner() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.4, color: MoydMapTheme.unityBlue),
          ),
        ),
      );

  Widget _emptyNote() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _inset,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _divider),
        ),
        child: Text('No outreach logged here yet.',
            style: TextStyle(color: _secondary, fontSize: 12.5)),
      );

  Widget _activityRow(OutreachActivity a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _open(a),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _inset,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MoydMapTheme.unityBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(a.kindIcon,
                      size: 18, color: MoydMapTheme.unityBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(a.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: _text,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(_subline(a),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _secondary, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _statusChip(a),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subline(OutreachActivity a) {
    final parts = <String>[a.kindLabel];
    if (a.scheduledOn != null) parts.add(_fmtDate(a.scheduledOn!));
    return parts.join('  ·  ');
  }

  Widget _statusChip(OutreachActivity a) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: a.statusColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(a.statusLabel,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800)),
      );

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';
}
