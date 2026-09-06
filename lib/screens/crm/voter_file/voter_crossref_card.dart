import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/models/crm/voter_file_record.dart';
import 'package:bluebubbles/screens/crm/voter_file/voter_history_strip.dart';
import 'package:bluebubbles/screens/crm/widgets/member_profile_sections.dart';

/// **READ-ONLY** cross-reference of the member's self-reported DOB against
/// the MO voter file record.
///
/// This widget intentionally has no save/confirm buttons and performs no
/// writes to `members.date_of_birth`. Per standing instruction
/// (2026-04-21): always preserve member-table data; consult before any
/// writes there.
///
/// It mounts inside the member profile's Voter file ProfileSectionCard, which
/// is a gradient card running BrandColors.tileGradient, so every colour here
/// is the profile idiom from member_profile_sections.dart and nothing reads
/// Theme.of. Readable text is FULL WHITE, 12.51:1 on unityBlue and 4.59:1 at
/// the light end; hierarchy is size, weight and letter spacing. Alpha appears
/// only on the hairline rules between blocks, which nothing is read against.
/// The registration status is the emphasis pair, unityBlue on sunriseGold
/// (7.17:1), or a solid unityBlue pill under white, or the text-safe red
/// under white (6.47:1); the discrepancy notice is the emphasis pair.
class VoterCrossRefCard extends StatelessWidget {
  final VoterFileRecord record;

  /// Member's self-reported DOB. May be null.
  final DateTime? memberDateOfBirth;

  const VoterCrossRefCard({
    super.key,
    required this.record,
    this.memberDateOfBirth,
  });

  bool get _hasDiscrepancy {
    if (memberDateOfBirth == null || record.birthYear == null) return false;
    return memberDateOfBirth!.year != record.birthYear;
  }

  @override
  Widget build(BuildContext context) {
    final districts = _districtChips();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _block(_readOnlyNotice()),
        _block(_registration()),
        _block(_dobComparison()),
        if (districts.isNotEmpty) _block(_districts(districts)),
        _block(_votingHistory(), last: true),
      ],
    );
  }

  /// One block of the card. Blocks are separated by a hairline Border, white
  /// 0.15 over the gradient, which is decorative: nothing is read against it.
  Widget _block(Widget child, {bool last = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: last
            ? null
            : BoxDecoration(
                border: Border(bottom: BorderSide(color: ProfileTokens.hairline)),
              ),
        child: child,
      );

  Widget _readOnlyNotice() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.lock_outline, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Read-only. Member-reported values are never overwritten.',
              style: ProfileText.caption,
            ),
          ),
        ],
      );

  /// Registration status as a solid pill. Active is the emphasis pair,
  /// cancelled is the text-safe red, everything else is a unityBlue pill under
  /// white with a white outline. The status word carries the meaning, so no
  /// coloured text sits on the gradient.
  ({String label, ProfilePillStyle style}) _registrationMeta() {
    final s = (record.voterStatus ?? '').toLowerCase();
    if (s == 'active') {
      return (label: 'Active voter', style: ProfilePillStyle.emphasis);
    }
    if (s == 'inactive') {
      return (label: 'Inactive', style: ProfilePillStyle.soft);
    }
    if (s == 'cancelled' || s == 'canceled') {
      return (label: 'Cancelled', style: ProfilePillStyle.danger);
    }
    return (label: record.voterStatus ?? 'Unknown', style: ProfilePillStyle.soft);
  }

  Widget _registration() {
    final meta = _registrationMeta();
    final registered = record.registrationDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('REGISTRATION', style: ProfileText.label),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ProfilePill(label: meta.label, style: meta.style),
            if (registered != null)
              Text(
                'Registered ${DateFormat.yMMMd().format(registered)}',
                style: ProfileText.caption,
              ),
          ],
        ),
      ],
    );
  }

  Widget _dobComparison() {
    final memberDobLabel = memberDateOfBirth != null
        ? DateFormat.yMMMd().format(memberDateOfBirth!)
        : 'Not set';
    final voterFileLabel = record.birthYearDisplay ?? 'Unknown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileFieldFlow(
          items: [
            ProfileFlowItem(
              ProfileField(label: 'Member-reported DOB', value: memberDobLabel),
            ),
            ProfileFlowItem(
              ProfileField(label: 'Voter file', value: voterFileLabel),
            ),
          ],
        ),
        if (_hasDiscrepancy) ...[
          const SizedBox(height: 8),
          _discrepancyWarning(),
        ],
      ],
    );
  }

  /// The emphasis pair: solid sunriseGold under unityBlue ink, 7.17:1. Gold is
  /// never text on the card, since it measures 2.63:1 at the light end.
  Widget _discrepancyWarning() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ProfileTokens.emphasisFill,
          borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: ProfileTokens.onEmphasis,
              size: 20,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Discrepancy: verify with the member. '
                'Member-reported data is never overwritten without confirmation.',
                style: TextStyle(
                  color: ProfileTokens.onEmphasis,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );

  /// Districts from the voter file as solid unityBlue chips under white with a
  /// white outline, 12.51:1. Only non-empty values render.
  List<Widget> _districtChips() {
    final chips = <Widget>[];
    void add(String? value, String label, IconData icon) {
      if (value == null || value.isEmpty) return;
      chips.add(profileChip('$label $value', icon: icon));
    }

    add(record.congressionalDistrict, 'CD', Icons.flag_outlined);
    add(record.legislativeDistrict, 'MO House', Icons.account_balance);
    add(record.senateDistrict, 'MO Senate', Icons.gavel);
    add(record.precinct, 'Precinct', Icons.pin_drop_outlined);
    return chips;
  }

  Widget _districts(List<Widget> chips) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DISTRICTS', style: ProfileText.label),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      );

  Widget _votingHistory() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('VOTING HISTORY', style: ProfileText.label),
          const SizedBox(height: 10),
          VoterHistoryStrip(history: record.voterHistory),
        ],
      );
}
