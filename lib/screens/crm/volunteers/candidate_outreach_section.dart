import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/candidate.dart';
import 'package:bluebubbles/models/crm/outreach_activity.dart';
import 'package:bluebubbles/services/crm/outreach_repository.dart';
import 'package:bluebubbles/screens/crm/volunteers/volunteers_map_models.dart';
import 'package:bluebubbles/screens/crm/volunteers/organizing_toolkit_sheet.dart';

/// "Field organizing" card for the candidate detail screen (Layer 2 of Candidate
/// Volunteers). Lists the field activities that supported this candidate and
/// offers a "Plan activity" entry point that opens the shared
/// [OrganizingToolkitSheet] pre-seeded with the candidate and the district
/// derived from their office.
class CandidateOutreachSection extends StatefulWidget {
  const CandidateOutreachSection({super.key, required this.candidate});

  final Candidate candidate;

  @override
  State<CandidateOutreachSection> createState() =>
      _CandidateOutreachSectionState();
}

class _CandidateOutreachSectionState extends State<CandidateOutreachSection> {
  final OutreachRepository _repo = OutreachRepository();

  bool _loading = true;
  Object? _error;
  List<OutreachActivity> _activities = const <OutreachActivity>[];

  /// How many recent rows to render before the "Plan activity" button.
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
      final rows = await _repo.activitiesForCandidate(widget.candidate.id);
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
  /// seeds this candidate plus the district derived from their office; editing
  /// an existing activity just hands the row back unchanged. Refreshes the list
  /// when the sheet reports a save.
  Future<void> _openSheet({OutreachActivity? existing}) async {
    final congressional = <String>[];
    final house = <String>[];
    final senate = <String>[];

    if (existing == null) {
      final district = widget.candidate.district;
      if (district != null && district.trim().isNotEmpty) {
        final bare = bareDigits(district);
        switch (_officeMode(widget.candidate)) {
          case MapMode.congressional:
            congressional.add(bare);
            break;
          case MapMode.house:
            house.add(bare);
            break;
          case MapMode.senate:
            senate.add(bare);
            break;
          case MapMode.county:
          case null:
            break;
        }
      }
    }

    final saved = await OrganizingToolkitSheet.show(
      context,
      existing: existing,
      candidates: existing == null
          ? <Candidate>[widget.candidate]
          : const <Candidate>[],
      congressionalDistricts: congressional,
      senateDistricts: senate,
      houseDistricts: house,
      titleSuggestion:
          existing == null ? 'Organizing for ${widget.candidate.name}' : null,
    );

    if (saved == true) await _load();
  }

  /// Classify a candidate's office into the map geography its district belongs
  /// to. Returns null for statewide/federal-senate seats that carry no single
  /// mappable district, so no geo is pre-filled and the sheet lets the user
  /// choose.
  MapMode? _officeMode(Candidate candidate) {
    final office = candidate.office.toLowerCase();
    final level = (candidate.officeLevel ?? '').toLowerCase();
    final isState = office.contains('state') ||
        office.contains('mo ') ||
        office.contains('missouri') ||
        level == 'state';

    // MO Senate.
    if (office.contains('state sen') ||
        office.contains('senate district') ||
        (office.contains('senat') && isState)) {
      return MapMode.senate;
    }
    // MO House.
    if (office.contains('state rep') ||
        office.contains('state house') ||
        office.contains('house district') ||
        (office.contains('represent') && isState)) {
      return MapMode.house;
    }
    // U.S. House / Congress.
    if (office.contains('congress') ||
        office.contains('u.s. house') ||
        office.contains('us house') ||
        office.contains('u.s. rep') ||
        office.contains('us rep') ||
        (office.contains('house') &&
            (office.contains('u.s') ||
                office.contains('us ') ||
                office.contains('federal') ||
                level == 'federal'))) {
      return MapMode.congressional;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OutreachHeader(
              count: _loading ? null : _activities.length,
            ),
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
                  'Could not load activities. Pull to refresh or try again.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              )
            else if (_activities.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Nothing organized for this candidate yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final activity in _activities.take(_maxRows)) ...[
                _OutreachActivityRow(
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
                label: const Text('Plan activity'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared "Field organizing" card header: a primary-filled badge, the title,
/// and an optional count chip. Kept private to this file so the candidate and
/// member sections stay independently owned.
class _OutreachHeader extends StatelessWidget {
  const _OutreachHeader({this.count});

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
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            Icons.campaign_outlined,
            color: theme.colorScheme.onPrimary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Field organizing',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (count != null && count! > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
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

/// One compact outreach row: kind icon, title, scheduled date, status chip.
class _OutreachActivityRow extends StatelessWidget {
  const _OutreachActivityRow({required this.activity, required this.onTap});

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
            _OutreachStatusChip(activity: activity),
          ],
        ),
      ),
    );
  }
}

/// Status chip: the status color as a solid fill with white text, which clears
/// 4.5:1 in both themes per the OutreachDisplay palette.
class _OutreachStatusChip extends StatelessWidget {
  const _OutreachStatusChip({required this.activity});

  final OutreachActivity activity;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

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
