import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/voter_file_record.dart';

/// Chronological vertical table of a voter's election participation,
/// grouped by year (most recent first), with per-row election-type
/// badges (Primary / General / Special / Municipal).
///
/// At the bottom, aggregate participation counts:
///   "Primary participation: 4 of 6"
///   "General participation: 7 of 7"
///
/// The aggregate denominators come from "every election year on file";
/// since the MO voter file only ships *voted* records, we approximate
/// eligibility by counting distinct primary-cycle and general-cycle
/// years from the candidate's earliest registered year forward. This
/// is good enough for a glance — if a more rigorous denominator is
/// ever needed, surface it from a dedicated `mo_election_calendar`
/// table.
///
/// The class name is unchanged so the parent widget needs zero
/// changes — only the visual presentation is rebuilt.
class VoterHistoryStrip extends StatelessWidget {
  final List<VoterHistoryEntry> history;

  const VoterHistoryStrip({
    super.key,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.history_toggle_off,
                size: 14, color: Colors.white.withOpacity(0.5)),
            const SizedBox(width: 6),
            Text(
              'No voting history on file.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    // Sort newest-first.
    final sorted = List<VoterHistoryEntry>.from(history)
      ..sort((a, b) => b.date.compareTo(a.date));

    // Group by year.
    final byYear = <int, List<VoterHistoryEntry>>{};
    for (final e in sorted) {
      byYear.putIfAbsent(e.date.year, () => <VoterHistoryEntry>[]).add(e);
    }
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));

    // Aggregate counts (eligibility approximated from the year-span).
    final agg = _computeAggregates(sorted);

    // Aggregate pills shown both in collapsed header and as the expanded
    // footer. Keeping them visible while collapsed is the load-bearing
    // affordance — at-a-glance "primary 4 of 6, general 7 of 7" is what
    // users want most of the time.
    final aggWrap = Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        _AggPill(
          label: 'Primary',
          voted: agg.primaryVoted,
          total: agg.primaryTotal,
          color: BrandColors.sunriseGold,
        ),
        _AggPill(
          label: 'General',
          voted: agg.generalVoted,
          total: agg.generalTotal,
          color: BrandColors.democratBlue,
        ),
        if (agg.otherVoted > 0)
          _AggPill(
            label: 'Special / Municipal',
            voted: agg.otherVoted,
            total: agg.otherVoted,
            color: BrandColors.momentumBlue,
          ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Theme(
        // ExpansionTile reads dividerColor from the theme; default would
        // draw a hairline that fights the existing border above.
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          unselectedWidgetColor: Colors.white70,
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: BrandColors.sunriseGold,
              ),
        ),
        child: ExpansionTile(
          // PageStorageKey<String> so the open/closed state has its own
          // bucket slot. Without an explicit key the auto-generated bucket
          // identifier can collide with sibling widgets and the
          // `as bool?` cast inside _ExpansionTileState.initState throws.
          key: const PageStorageKey<String>('voter-history-strip'),
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: EdgeInsets.zero,
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white70,
          title: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: aggWrap,
          ),
          children: [
            for (var i = 0; i < years.length; i++)
              _YearGroup(
                year: years[i],
                entries: byYear[years[i]]!,
                isLast: i == years.length - 1,
              ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────
  // Aggregate computation
  // ────────────────────────────────────────────────────────────────────

  _Aggregates _computeAggregates(List<VoterHistoryEntry> entries) {
    if (entries.isEmpty) return _Aggregates.empty();

    int primaryVoted = 0;
    int generalVoted = 0;
    int otherVoted = 0;

    int? minYear;
    int? maxYear;

    for (final e in entries) {
      final t = _classify(e.electionType);
      if (t == _Type.primary) primaryVoted++;
      else if (t == _Type.general) generalVoted++;
      else otherVoted++;

      final y = e.date.year;
      minYear = (minYear == null || y < minYear) ? y : minYear;
      maxYear = (maxYear == null || y > maxYear) ? y : maxYear;
    }

    // Eligibility window: count even-numbered election years between
    // min and max (inclusive). Federal primaries + generals run on
    // even years (2018, 2020, 2022, 2024, 2026…). This is the
    // candidate's "could-have-voted" window.
    int primaryTotal = 0;
    int generalTotal = 0;
    if (minYear != null && maxYear != null) {
      for (int y = minYear; y <= maxYear; y++) {
        if (y % 2 == 0) {
          primaryTotal++;
          generalTotal++;
        }
      }
      // Make sure denominators never go below the count of recorded
      // votes (data could include odd-year specials etc. — never let
      // "X of Y" show X > Y).
      if (primaryTotal < primaryVoted) primaryTotal = primaryVoted;
      if (generalTotal < generalVoted) generalTotal = generalVoted;
    }

    return _Aggregates(
      primaryVoted: primaryVoted,
      primaryTotal: primaryTotal,
      generalVoted: generalVoted,
      generalTotal: generalTotal,
      otherVoted: otherVoted,
    );
  }

  static _Type _classify(String electionType) {
    final t = electionType.toLowerCase();
    if (t.contains('primary')) return _Type.primary;
    if (t.contains('general')) return _Type.general;
    return _Type.other;
  }
}

// ──────────────────────────────────────────────────────────────────────
// Subviews
// ──────────────────────────────────────────────────────────────────────

class _YearGroup extends StatelessWidget {
  final int year;
  final List<VoterHistoryEntry> entries;
  final bool isLast;

  const _YearGroup({
    required this.year,
    required this.entries,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: BrandColors.sunriseGold.withOpacity(0.07),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
            ),
          ),
          child: Text(
            '$year',
            style: TextStyle(
              color: BrandColors.sunriseGold,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
        for (var i = 0; i < entries.length; i++) ...[
          _ElectionRow(entry: entries[i]),
          if (i < entries.length - 1)
            Container(
              height: 1,
              color: Colors.white.withOpacity(0.04),
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),
        ],
      ],
    );
  }
}

class _ElectionRow extends StatelessWidget {
  final VoterHistoryEntry entry;
  const _ElectionRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d').format(entry.date);
    final type = VoterHistoryStrip._classify(entry.electionType);
    final (badgeColor, badgeText) = _badgeFor(type, entry.electionType);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Voted indicator — every entry in voter_history represents
          // a recorded vote, so always green-check. We render this so
          // the row is unambiguously parseable as "voted".
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: BrandColors.success.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: BrandColors.success.withOpacity(0.55)),
            ),
            child: Icon(Icons.check,
                size: 12, color: BrandColors.success),
          ),
          const SizedBox(width: 10),
          // Date
          SizedBox(
            width: 60,
            child: Text(
              dateStr,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          // Election label
          Expanded(
            child: Text(
              entry.electionType.isNotEmpty ? entry.electionType : 'Election',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: badgeColor.withOpacity(0.45)),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                color: badgeColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, String) _badgeFor(_Type t, String raw) {
    switch (t) {
      case _Type.primary:
        return (BrandColors.sunriseGold, 'PRIMARY');
      case _Type.general:
        return (BrandColors.democratBlue, 'GENERAL');
      case _Type.other:
        final lower = raw.toLowerCase();
        if (lower.contains('special')) {
          return (BrandColors.momentumBlue, 'SPECIAL');
        }
        if (lower.contains('municipal')) {
          return (BrandColors.momentumBlue, 'MUNICIPAL');
        }
        if (lower.contains('runoff')) {
          return (BrandColors.republicanRed, 'RUNOFF');
        }
        return (
          BrandColors.steelBlue,
          raw.isEmpty ? 'OTHER' : raw.toUpperCase()
        );
    }
  }
}

class _AggPill extends StatelessWidget {
  final String label;
  final int voted;
  final int total;
  final Color color;

  const _AggPill({
    required this.label,
    required this.voted,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        RichText(
          text: TextSpan(
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            children: [
              TextSpan(text: '$label participation: '),
              TextSpan(
                text: '$voted of $total',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Internal types
// ──────────────────────────────────────────────────────────────────────

enum _Type { primary, general, other }

class _Aggregates {
  final int primaryVoted;
  final int primaryTotal;
  final int generalVoted;
  final int generalTotal;
  final int otherVoted;

  const _Aggregates({
    required this.primaryVoted,
    required this.primaryTotal,
    required this.generalVoted,
    required this.generalTotal,
    required this.otherVoted,
  });

  factory _Aggregates.empty() => const _Aggregates(
        primaryVoted: 0,
        primaryTotal: 0,
        generalVoted: 0,
        generalTotal: 0,
        otherVoted: 0,
      );
}
