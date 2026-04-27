import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/voter_file_record.dart';
import 'package:bluebubbles/screens/crm/candidate_ui_helpers.dart';
import 'package:bluebubbles/screens/crm/voter_file/voter_history_strip.dart';

/// Composed card showing the MO voter-file record for a candidate or
/// donor. Replaces the previous chip-soup with a clean labeled
/// definition list:
///
///   Status                Active (10y registered)
///   Registered Since      Apr 2014 · 12 years
///   Party                 Democrat
///   Birth Year            1985 (~age 41)
///   Precinct / Ward       0125 / 02
///   Congressional         CD-01
///   MO House              D-77
///   MO Senate             SD-05
///   County                St. Louis County
///
/// Followed by the chronological [VoterHistoryStrip] showing election-
/// by-election participation and primary/general aggregates.
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
    // Empty-record guard. If we somehow rendered a card with no useful
    // identifiers at all, surface the polite empty state.
    final hasAnyData = record.voterId.isNotEmpty ||
        (record.voterStatus ?? '').isNotEmpty ||
        record.registrationDate != null ||
        record.birthYear != null ||
        record.voterHistory.isNotEmpty;

    return CandidateUI.card(
      'Missouri Voter File',
      Icons.how_to_vote,
      BrandColors.steelBlue,
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: !hasAnyData
            ? _emptyState()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Definition list of registration facts ──
                  _DefinitionList(rows: _buildRows()),
                  const SizedBox(height: 18),

                  // ── Voting history table ──
                  Row(
                    children: [
                      Icon(Icons.history,
                          size: 14,
                          color: BrandColors.sunriseGold.withOpacity(0.8)),
                      const SizedBox(width: 6),
                      Text(
                        'Voting History',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  VoterHistoryStrip(history: record.voterHistory),

                  // ── Voter ID + staff debug ──
                  if (record.voterId.isNotEmpty || showDebug) ...[
                    const SizedBox(height: 14),
                    _footer(context),
                  ],
                ],
              ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────
  // Row builders
  // ────────────────────────────────────────────────────────────────────

  List<_DefRow> _buildRows() {
    final rows = <_DefRow>[];

    // Status
    rows.add(_statusRow());

    // Registered since
    if (record.registrationDate != null) {
      rows.add(_registeredSinceRow(record.registrationDate!));
    }

    // Birth year — MO releases year only; mirror the dob_source-aware
    // pattern from candidate_detail_screen.dart so we never synthesize
    // a fake month/day.
    if (record.birthYear != null) {
      final age = record.estimatedAge;
      rows.add(_DefRow(
        label: 'Birth Year',
        value: age != null ? '${record.birthYear}  (~age $age)' : '${record.birthYear}',
      ));
    }

    // Residence (city / county / zip)
    final residenceParts = <String>[
      if ((record.residentialCity ?? '').isNotEmpty) record.residentialCity!,
      if ((record.county ?? '').isNotEmpty) '${record.county} County',
      if ((record.residentialZip5 ?? '').isNotEmpty) record.residentialZip5!,
    ];
    if (residenceParts.isNotEmpty) {
      rows.add(_DefRow(label: 'Residence', value: residenceParts.join(' · ')));
    }

    // Precinct + ward
    final precinctWard = <String>[
      if ((record.precinct ?? '').isNotEmpty) 'Precinct ${record.precinct}',
      if ((record.ward ?? '').isNotEmpty) 'Ward ${record.ward}',
      if ((record.township ?? '').isNotEmpty) record.township!,
    ];
    if (precinctWard.isNotEmpty) {
      rows.add(_DefRow(label: 'Precinct', value: precinctWard.join(' · ')));
    }

    // Districts — render together so users can see them at a glance.
    if ((record.congressionalDistrict ?? '').isNotEmpty) {
      rows.add(_DefRow(
        label: 'Congressional',
        value: 'CD-${record.congressionalDistrict}',
      ));
    }
    if ((record.legislativeDistrict ?? '').isNotEmpty) {
      rows.add(_DefRow(
        label: 'MO House',
        value: 'HD-${record.legislativeDistrict}',
      ));
    }
    if ((record.senateDistrict ?? '').isNotEmpty) {
      rows.add(_DefRow(
        label: 'MO Senate',
        value: 'SD-${record.senateDistrict}',
      ));
    }

    return rows;
  }

  _DefRow _statusRow() {
    final s = (record.voterStatus ?? '').toLowerCase();
    Color dot;
    String label;
    if (s == 'active') {
      dot = BrandColors.success;
      label = 'Active';
    } else if (s == 'inactive') {
      dot = BrandColors.sunriseGold;
      label = 'Inactive';
    } else if (s == 'cancelled' || s == 'canceled') {
      dot = BrandColors.republicanRed;
      label = 'Cancelled';
    } else {
      dot = Colors.white54;
      label = record.voterStatus ?? 'Unknown';
    }
    return _DefRow(
      label: 'Status',
      valueWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: dot.withOpacity(0.5), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: dot,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  _DefRow _registeredSinceRow(DateTime date) {
    final now = DateTime.now();
    final years = now.year - date.year - ((now.month < date.month || (now.month == date.month && now.day < date.day)) ? 1 : 0);
    final formatted = DateFormat.yMMMd().format(date);
    final tail = years > 0 ? '  ·  $years ${years == 1 ? "year" : "years"}' : '';
    return _DefRow(label: 'Registered', value: '$formatted$tail');
  }

  // ────────────────────────────────────────────────────────────────────
  // Subviews
  // ────────────────────────────────────────────────────────────────────

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 16, color: Colors.white.withOpacity(0.5)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No voter file linked.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (record.voterId.isNotEmpty) ...[
              Icon(Icons.badge_outlined,
                  size: 12, color: Colors.white.withOpacity(0.45)),
              const SizedBox(width: 4),
              Text(
                'Voter ID ${record.voterId}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
            const Spacer(),
            if ((dobSource ?? '').isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: BrandColors.steelBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: BrandColors.steelBlue.withOpacity(0.3)),
                ),
                child: Text(
                  'src: $dobSource',
                  style: TextStyle(
                    color: BrandColors.steelBlue,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
          ],
        ),
        if (showDebug && (matchConfidence != null || matchMethod != null)) ...[
          const SizedBox(height: 6),
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

// ──────────────────────────────────────────────────────────────────────
// Private helpers
// ──────────────────────────────────────────────────────────────────────

class _DefRow {
  final String label;
  final String? value;
  final Widget? valueWidget;

  _DefRow({required this.label, this.value, this.valueWidget})
      : assert(value != null || valueWidget != null,
            'Either value or valueWidget must be non-null');
}

class _DefinitionList extends StatelessWidget {
  final List<_DefRow> rows;
  const _DefinitionList({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Container(
                height: 1,
                color: Colors.white.withOpacity(0.04),
              ),
            _DefRowView(row: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _DefRowView extends StatelessWidget {
  final _DefRow row;
  const _DefRowView({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              row.label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: row.valueWidget ??
                Text(
                  row.value ?? '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
