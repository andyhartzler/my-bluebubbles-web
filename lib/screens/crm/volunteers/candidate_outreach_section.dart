import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/candidate.dart';
import 'package:bluebubbles/models/crm/outreach_activity.dart';
import 'package:bluebubbles/services/crm/outreach_repository.dart';
import 'package:bluebubbles/services/crm/touchpoint_repository.dart';
import 'package:bluebubbles/screens/crm/volunteers/mobilize_models.dart';
import 'package:bluebubbles/screens/crm/volunteers/outreach_profile_cards.dart';
import 'package:bluebubbles/screens/crm/volunteers/volunteers_map_models.dart';
import 'package:bluebubbles/screens/crm/volunteers/organizing_toolkit_sheet.dart';

/// The nominee detail screen's outreach column: what has been SENT about this
/// nominee, then what has been ORGANIZED for them.
///
/// The contact block comes first because it is the newer and more perishable
/// fact: a text that went out this morning changes what an exec does next, a
/// canvass planned for October does not. It renders itself only when there is
/// something to report (spec 4.4, Phase 6).
class CandidateOutreachSection extends StatefulWidget {
  const CandidateOutreachSection({super.key, required this.candidate});

  final Candidate candidate;

  @override
  State<CandidateOutreachSection> createState() =>
      _CandidateOutreachSectionState();
}

class _CandidateOutreachSectionState extends State<CandidateOutreachSection> {
  final OutreachRepository _repo = OutreachRepository();
  final TouchpointRepository _touchpoints = TouchpointRepository();

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

  /// Opens the shared toolkit sheet. A brand-new activity is seeded with this
  /// nominee plus the district derived from their office; an existing one opens
  /// on its own stored values, so the seed has nothing to say. Refreshes the
  /// list when the sheet reports a save. This screen has no Desk to scroll to,
  /// so it keeps the modal mount.
  Future<void> _openSheet({OutreachActivity? existing}) async {
    final saved = await OrganizingToolkitSheet.show(
      context,
      existing: existing,
      seed: existing == null ? _seed() : const OrganizingSeed.empty(),
    );

    if (saved == true) await _load();
  }

  /// This nominee, in the one geography their office maps to. [_officeMode]
  /// returns null for a statewide or US Senate seat, and the seed then carries
  /// the nominee with no geo rather than a guessed district.
  OrganizingSeed _seed() {
    final mode = _officeMode(widget.candidate);
    final district = widget.candidate.district?.trim() ?? '';
    return OrganizingSeed.forCandidate(
      widget.candidate,
      mode: district.isEmpty ? null : mode,
      regionId: district.isEmpty ? null : bareDigits(district),
    );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RecentContactCard(
          load: () => _touchpoints.forCandidate(widget.candidate.id),
        ),
        OutreachProfileCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutreachProfileHeader(
                icon: Icons.campaign_outlined,
                title: 'Field organizing',
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
                  OutreachProfileActivityRow(
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
      ],
    );
  }
}
