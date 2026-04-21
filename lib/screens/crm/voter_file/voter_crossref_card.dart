import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/voter_file_record.dart';
import 'package:bluebubbles/screens/crm/candidate_ui_helpers.dart';
import 'package:bluebubbles/screens/crm/voter_file/voter_district_strip.dart';
import 'package:bluebubbles/screens/crm/voter_file/voter_history_strip.dart';
import 'package:bluebubbles/screens/crm/voter_file/voter_registration_badge.dart';

/// **READ-ONLY** cross-reference of the member's self-reported DOB against
/// the MO voter file record.
///
/// This widget intentionally has no save/confirm buttons and performs no
/// writes to `members.date_of_birth`. Per standing instruction
/// (2026-04-21): always preserve member-table data; consult before any
/// writes there.
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
    return CandidateUI.card(
      'Voter File Cross-Reference',
      Icons.verified_user_outlined,
      BrandColors.steelBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          _readOnlyNotice(),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VoterRegistrationBadge(
                status: record.voterStatus,
                registrationDate: record.registrationDate,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _dobComparison(),
          if (_hasDiscrepancy) ...[
            const SizedBox(height: 10),
            _discrepancyWarning(),
          ],
          const SizedBox(height: 14),
          VoterDistrictStrip(
            congressionalDistrict: record.congressionalDistrict,
            legislativeDistrict: record.legislativeDistrict,
            senateDistrict: record.senateDistrict,
            precinct: record.precinct,
          ),
          const SizedBox(height: 14),
          Text(
            'Voting History',
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          VoterHistoryStrip(history: record.voterHistory),
        ],
      ),
    );
  }

  Widget _readOnlyNotice() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline,
                size: 13, color: Colors.white.withOpacity(0.6)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Read-only. Member-reported values are never overwritten.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _dobComparison() {
    final memberDobLabel = memberDateOfBirth != null
        ? DateFormat.yMMMd().format(memberDateOfBirth!)
        : 'Not set';
    final voterFileLabel = record.birthYearDisplay ?? 'Unknown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _comparisonRow('Member-reported DOB', memberDobLabel),
        const SizedBox(height: 6),
        _comparisonRow('Voter file', voterFileLabel),
      ],
    );
  }

  Widget _comparisonRow(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );

  Widget _discrepancyWarning() => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: BrandColors.sunriseGold.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BrandColors.sunriseGold.withOpacity(0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded,
                color: BrandColors.sunriseGold, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Discrepancy — please verify with member. '
                'Do not overwrite member-reported data without confirmation.',
                style: TextStyle(
                  color: BrandColors.sunriseGold,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      );
}
