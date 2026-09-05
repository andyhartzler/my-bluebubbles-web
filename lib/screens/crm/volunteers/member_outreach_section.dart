import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/outreach_activity.dart';
import 'package:bluebubbles/services/crm/outreach_repository.dart';
import 'package:bluebubbles/services/crm/touchpoint_repository.dart';
import 'package:bluebubbles/screens/crm/volunteers/mobilize_models.dart';
import 'package:bluebubbles/screens/crm/volunteers/outreach_profile_cards.dart';
import 'package:bluebubbles/screens/crm/volunteers/organizing_toolkit_sheet.dart';

/// The member detail screen's outreach column: what has been SENT to this
/// member, then what has been ORGANIZED with them.
///
/// The contact block answers the question an exec actually has before picking
/// up the phone, which is "have we already messaged them this week", and it
/// renders itself only when there is something to report (spec 4.4, Phase 6).
class MemberOutreachSection extends StatefulWidget {
  const MemberOutreachSection({super.key, required this.member});

  final Member member;

  @override
  State<MemberOutreachSection> createState() => _MemberOutreachSectionState();
}

class _MemberOutreachSectionState extends State<MemberOutreachSection> {
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RecentContactCard(
          load: () => _touchpoints.forMember(widget.member.id),
        ),
        OutreachProfileCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutreachProfileHeader(
                icon: Icons.campaign_outlined,
                title: 'Organizing',
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
                    'Could not load activities. Try again.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                )
              else if (_activities.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Nothing organized with this member yet.',
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
