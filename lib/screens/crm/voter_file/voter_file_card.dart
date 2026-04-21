import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/voter_file_record.dart';
import 'package:bluebubbles/screens/crm/candidate_ui_helpers.dart';
import 'package:bluebubbles/screens/crm/voter_file/voter_district_strip.dart';
import 'package:bluebubbles/screens/crm/voter_file/voter_history_strip.dart';
import 'package:bluebubbles/screens/crm/voter_file/voter_registration_badge.dart';

/// Composed card showing the MO voter-file record for a candidate or
/// donor: registration status, estimated age (year only), district chips,
/// and voting-history strip.
///
/// Optional staff-debug ExpansionTile exposes match_confidence and
/// match_method when [showDebug] is true.
class VoterFileCard extends StatelessWidget {
  final VoterFileRecord record;
  final String? dobSource;
  final num? matchConfidence;
  final String? matchMethod;
  final bool showDebug;

  const VoterFileCard({
    super.key,
    required this.record,
    this.dobSource,
    this.matchConfidence,
    this.matchMethod,
    this.showDebug = false,
  });

  @override
  Widget build(BuildContext context) {
    return CandidateUI.card(
      'Missouri Voter File',
      Icons.how_to_vote,
      BrandColors.steelBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // ── Status + name summary ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VoterRegistrationBadge(
                status: record.voterStatus,
                registrationDate: record.registrationDate,
              ),
              const Spacer(),
              _voterIdTag(record.voterId),
            ],
          ),
          const SizedBox(height: 14),

          // ── Age + born YYYY + source badge ──
          if (record.birthYear != null) ...[
            _ageRow(),
            const SizedBox(height: 14),
          ],

          // ── Residence ──
          if (_hasResidence()) ...[
            _residenceRow(),
            const SizedBox(height: 14),
          ],

          // ── Districts ──
          VoterDistrictStrip(
            congressionalDistrict: record.congressionalDistrict,
            legislativeDistrict: record.legislativeDistrict,
            senateDistrict: record.senateDistrict,
            precinct: record.precinct,
          ),
          const SizedBox(height: 14),

          // ── History ──
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

          // ── Staff debug ──
          if (showDebug && (matchConfidence != null || matchMethod != null)) ...[
            const SizedBox(height: 10),
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                unselectedWidgetColor: Colors.white54,
              ),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(left: 4, bottom: 8),
                title: Text(
                  'Match diagnostics',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                iconColor: Colors.white70,
                collapsedIconColor: Colors.white54,
                children: [
                  _debugRow('match_confidence',
                      matchConfidence?.toStringAsFixed(2) ?? '—'),
                  _debugRow('match_method', matchMethod ?? '—'),
                  if (dobSource != null) _debugRow('dob_source', dobSource!),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _hasResidence() =>
      (record.residentialCity ?? '').isNotEmpty ||
      (record.county ?? '').isNotEmpty ||
      (record.residentialZip5 ?? '').isNotEmpty;

  Widget _residenceRow() {
    final parts = <String>[
      if ((record.residentialCity ?? '').isNotEmpty) record.residentialCity!,
      if ((record.county ?? '').isNotEmpty) '${record.county} County',
      if ((record.residentialZip5 ?? '').isNotEmpty) record.residentialZip5!,
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.home_outlined,
            size: 14, color: Colors.white.withOpacity(0.7)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            parts.join(' · '),
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _ageRow() {
    final age = record.estimatedAge;
    final line = age != null
        ? 'Age $age  (${record.birthYearDisplay ?? ''})'
        : (record.birthYearDisplay ?? '');
    return Row(
      children: [
        Icon(Icons.cake_outlined,
            size: 14, color: Colors.white.withOpacity(0.75)),
        const SizedBox(width: 6),
        Text(
          line,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        if (dobSource != null && dobSource!.isNotEmpty) ...[
          const SizedBox(width: 8),
          _sourceBadge(dobSource!),
        ],
      ],
    );
  }

  Widget _sourceBadge(String source) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: BrandColors.steelBlue.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: BrandColors.steelBlue.withOpacity(0.3)),
      ),
      child: Text(
        source,
        style: TextStyle(
          color: BrandColors.steelBlue,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _voterIdTag(String id) {
    if (id.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'ID $id',
        style: TextStyle(
          color: Colors.white.withOpacity(0.55),
          fontSize: 10,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _debugRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 130,
              child: Text(
                k,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            Expanded(
              child: Text(
                v,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      );
}
