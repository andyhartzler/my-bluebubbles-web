import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/voter_file_record.dart';
import 'package:bluebubbles/screens/crm/candidate_ui_helpers.dart';
import 'package:bluebubbles/screens/crm/voter_file/voter_history_strip.dart';
import 'package:bluebubbles/screens/crm/widgets/member_profile_sections.dart';

/// Composed card showing the MO voter-file record for a candidate or
/// donor. Replaces the previous chip-soup with a clean labeled
/// definition list:
///
///   STATUS                Active
///   REGISTERED            Apr 2014 · 12 years
///   BIRTH YEAR            1985 (~age 41)
///   RESIDENCE             St. Louis County · 63101
///   PRECINCT              Precinct 0125 · Ward 02
///   CONGRESSIONAL         CD-01
///   MO HOUSE              HD-77
///   MO SENATE             SD-05
///
/// Followed by the chronological [VoterHistoryStrip] showing election
/// by election participation and primary/general aggregates.
///
/// Optional staff-debug ExpansionTile exposes match_confidence and
/// match_method when [showDebug] is true.
///
/// COLOUR RULES. This card is rendered by the donor and candidate detail
/// screens inside [CandidateUI.card], whose fill is unityBlue #273351 at
/// alpha 0.9 over the screen scaffold. So the real composited parent is a
/// near-solid navy: exactly unityBlue over the dark scaffolds (white on
/// it 12.51:1) and at worst #3D4762 where the scaffold is white (white on
/// it 9.23:1). Every piece of readable text is FULL WHITE at alpha 1.0
/// and hierarchy is size, weight and letter spacing only, following the
/// member_profile_sections idiom. Alpha appears only on the decorative
/// row rules (ProfileTokens.hairline), which nothing is read against.
///
/// Anything that carries meaning through colour sits on a SOLID fill
/// under an ink that clears 4.5:1 on it, never as coloured text on the
/// card. Ratios computed with the WCAG 2.1 relative luminance formula:
///
///   Active      success #10B981 under unityBlue ink ............ 4.93:1
///   Inactive    sunriseGold #FDB813 under unityBlue ink ........ 7.17:1
///   Cancelled   ProfileTokens.danger #B91C1C under white ink ... 6.47:1
///   Unknown     unityBlue #273351 under white ink, white edge .. 12.51:1
///   src chip    unityBlue #273351 under white ink, white edge .. 12.51:1
///
/// The card header accent is sunriseGold, which [CandidateUI.card] draws
/// as a full-strength icon on a 15 percent tint of itself over the card:
/// 5.32:1 on the tile over unityBlue, 4.06:1 on the tile over #3D4762,
/// both above the 3:1 bar for a meaningful icon.
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
      ProfileTokens.emphasisFill,
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
                  const Row(
                    children: [
                      Icon(Icons.history, size: 14, color: ProfileTokens.ink),
                      SizedBox(width: 6),
                      Text('VOTING HISTORY', style: ProfileText.label),
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

    // Birth year: MO releases year only; mirror the dob_source-aware
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

    // Districts: render together so users can see them at a glance.
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
    // Status carries meaning through colour, so it is a chip on a SOLID
    // fill under an ink that clears 4.5:1 on that fill (ratios in the
    // class doc). Never coloured text, never alpha.
    Color fill;
    Color ink;
    Color edge;
    String label;
    if (s == 'active') {
      fill = BrandColors.success;
      ink = ProfileTokens.onEmphasis;
      edge = BrandColors.success;
      label = 'Active';
    } else if (s == 'inactive') {
      fill = ProfileTokens.emphasisFill;
      ink = ProfileTokens.onEmphasis;
      edge = ProfileTokens.emphasisFill;
      label = 'Inactive';
    } else if (s == 'cancelled' || s == 'canceled') {
      fill = ProfileTokens.danger;
      ink = ProfileTokens.ink;
      edge = ProfileTokens.danger;
      label = 'Cancelled';
    } else {
      fill = ProfileTokens.fill;
      ink = ProfileTokens.ink;
      edge = ProfileTokens.border;
      label = record.voterStatus ?? 'Unknown';
    }
    return _DefRow(
      label: 'Status',
      valueWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _solidChip(label, fill: fill, ink: ink, edge: edge),
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
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: ProfileTokens.ink),
          SizedBox(width: 8),
          Expanded(
            child: Text('No voter file linked.', style: ProfileText.caption),
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
              const Icon(Icons.badge_outlined, size: 12, color: ProfileTokens.ink),
              const SizedBox(width: 4),
              Text(
                'Voter ID ${record.voterId}',
                style: const TextStyle(
                  color: ProfileTokens.ink,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ],
            const Spacer(),
            if ((dobSource ?? '').isNotEmpty)
              _solidChip(
                'src: $dobSource',
                fill: ProfileTokens.fill,
                ink: ProfileTokens.ink,
                edge: ProfileTokens.border,
              ),
          ],
        ),
        if (showDebug && (matchConfidence != null || matchMethod != null)) ...[
          const SizedBox(height: 6),
          // Colours are set directly on the tile, never derived from the
          // ambient theme. An empty Border on both shapes removes the divider
          // rules the tile would otherwise draw from the theme.
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(left: 4, bottom: 8),
            shape: const Border(),
            collapsedShape: const Border(),
            iconColor: ProfileTokens.ink,
            collapsedIconColor: ProfileTokens.ink,
            textColor: ProfileTokens.ink,
            collapsedTextColor: ProfileTokens.ink,
            title: const Text('MATCH DIAGNOSTICS', style: ProfileText.label),
            children: [
              _debugRow('match_confidence',
                  matchConfidence?.toStringAsFixed(2) ?? 'n/a'),
              _debugRow('match_method', matchMethod ?? 'n/a'),
              if (dobSource != null) _debugRow('dob_source', dobSource!),
            ],
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
                style: const TextStyle(
                  color: ProfileTokens.ink,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            Expanded(
              child: Text(
                v,
                style: const TextStyle(
                  color: ProfileTokens.ink,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      );
}

// ──────────────────────────────────────────────────────────────────────
// Private helpers
// ──────────────────────────────────────────────────────────────────────

/// A chip on a SOLID fill. [ink] is the label colour and must clear 4.5:1
/// on [fill]; [edge] is the outline, white when the fill is unityBlue so
/// the chip keeps an edge against the navy card, otherwise the fill
/// itself.
Widget _solidChip(
  String text, {
  required Color fill,
  required Color ink,
  required Color edge,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(ProfileTokens.chipRadius),
      border: Border.all(color: edge),
    ),
    child: Text(text, style: ProfileText.chip.copyWith(color: ink)),
  );
}

class _DefRow {
  final String label;
  final String? value;
  final Widget? valueWidget;

  _DefRow({required this.label, this.value, this.valueWidget})
      : assert(value != null || valueWidget != null,
            'Either value or valueWidget must be non-null');
}

/// Solid unityBlue block with a white outline (ProfileTokens.fill and
/// ProfileTokens.border), so every label and value sits on a solid fill
/// at 12.51:1 wherever the card is. Row rules are the decorative
/// hairline; nothing is read against them.
class _DefinitionList extends StatelessWidget {
  final List<_DefRow> rows;
  const _DefinitionList({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: ProfileTokens.fill,
        borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
        border: Border.all(color: ProfileTokens.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Container(
                height: 1,
                color: ProfileTokens.hairline,
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
            width: 124,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(row.label.toUpperCase(), style: ProfileText.label),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: row.valueWidget ??
                Text(row.value ?? 'n/a', style: ProfileText.value),
          ),
        ],
      ),
    );
  }
}
