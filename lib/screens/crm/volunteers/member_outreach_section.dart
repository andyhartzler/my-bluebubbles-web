import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/outreach_activity.dart';
import 'package:bluebubbles/services/crm/outreach_repository.dart';
import 'package:bluebubbles/screens/crm/volunteers/volunteers_map_models.dart';
import 'package:bluebubbles/screens/crm/volunteers/outreach_log_sheet.dart';

/// "Outreach" card for the member detail screen (Layer 2 of Candidate
/// Volunteers). Lists the field activities this member took part in and offers
/// a "Log outreach" entry point that opens the shared [OutreachLogSheet]
/// pre-seeded with this member as a participant and their county.
class MemberOutreachSection extends StatefulWidget {
  const MemberOutreachSection({super.key, required this.member});

  final Member member;

  @override
  State<MemberOutreachSection> createState() => _MemberOutreachSectionState();
}

class _MemberOutreachSectionState extends State<MemberOutreachSection> {
  final OutreachRepository _repo = OutreachRepository();

  bool _loading = true;
  Object? _error;
  List<OutreachActivity> _activities = const <OutreachActivity>[];

  /// How many recent rows to render before the "Log outreach" button.
  static const int _maxRows = 6;

  @override
  void initState() {
    super.initState();
    _load();
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

  /// Opens the shared log sheet. For a brand-new activity ([existing] null) it
  /// seeds this member as a participant and their county; editing an existing
  /// activity just hands the row back unchanged. Refreshes the list when the
  /// sheet reports a save.
  Future<void> _openSheet({OutreachActivity? existing}) async {
    final counties = <String>[];
    if (existing == null) {
      final county = widget.member.county;
      if (county != null && county.trim().isNotEmpty) counties.add(county.trim());
    }

    final saved = await OutreachLogSheet.show(
      context,
      existing: existing,
      participants:
          existing == null ? <Member>[widget.member] : const <Member>[],
      counties: counties,
      titleSuggestion:
          existing == null ? 'Outreach with ${widget.member.name}' : null,
    );

    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: MoydMapTheme.navy.withValues(alpha: 0.10)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MemberOutreachHeader(count: _loading ? null : _activities.length),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Could not load outreach. Try again.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              )
            else if (_activities.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'No outreach logged with this member yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final activity in _activities.take(_maxRows)) ...[
                _MemberOutreachRow(
                  activity: activity,
                  onTap: () => _openSheet(existing: activity),
                ),
                const Divider(height: 1),
              ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => _openSheet(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Log outreach'),
                style: FilledButton.styleFrom(
                  backgroundColor: MoydMapTheme.unityBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Outreach" card header: a unityBlue badge, the title, and an optional count
/// chip. Private to this file so the member section stays independently owned.
class _MemberOutreachHeader extends StatelessWidget {
  const _MemberOutreachHeader({this.count});

  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: MoydMapTheme.unityBlue,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(
            Icons.campaign_outlined,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Outreach',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (count != null && count! > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: MoydMapTheme.unityBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

/// One compact outreach row: kind icon, title, scheduled date, status chip.
class _MemberOutreachRow extends StatelessWidget {
  const _MemberOutreachRow({required this.activity, required this.onTap});

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
            Icon(
              activity.kindIcon,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (activity.scheduledOn != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _formatDate(activity.scheduledOn!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: activity.statusColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                activity.statusLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Compact "MMM d, yyyy" without pulling in intl.
  static String _formatDate(DateTime date) {
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
}
