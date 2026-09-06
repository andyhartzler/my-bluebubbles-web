import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/voter_file_record.dart';
import 'package:bluebubbles/screens/crm/widgets/member_profile_sections.dart';

/// Chronological vertical table of a voter's election participation,
/// grouped by year (most recent first), with per-row election-type
/// badges (Primary / General / Special / Municipal).
///
/// At the bottom, aggregate participation counts:
///   "PRIMARY participation: 4 of 6"
///   "GENERAL participation: 7 of 7"
///
/// The aggregate denominators come from "every election year on file";
/// since the MO voter file only ships *voted* records, we approximate
/// eligibility by counting distinct primary-cycle and general-cycle
/// years from the candidate's earliest registered year forward. This
/// is good enough for a glance. If a more rigorous denominator is
/// ever needed, surface it from a dedicated `mo_election_calendar`
/// table.
///
/// The class name is unchanged so the parent widget needs zero
/// changes. Only the visual presentation is rebuilt.
///
/// COLOUR RULES. This widget renders INSIDE a gradient profile card
/// (BrandColors.tileGradient, unityBlue #273351 to tileGradientEnd
/// #1C7DAB), so it follows the member_profile_sections idiom exactly:
/// every piece of readable text is FULL WHITE at alpha 1.0, which
/// measures 12.51:1 on unityBlue and 4.59:1 on tileGradientEnd.
/// Hierarchy is size, weight and letter spacing only. Alpha appears
/// only on the decorative hairline frame and row rules (white 0.15,
/// 1.60:1 on navy and 1.29:1 on the light end), which nothing is read
/// against.
///
/// Election-type badges carry meaning through colour, so each one is a
/// SOLID fill under an ink that clears 4.5:1 regardless of where the
/// badge sits on the gradient. Ratios computed with the WCAG 2.1
/// relative luminance formula on the hex values named:
///
///   PRIMARY            sunriseGold #FDB813 under unityBlue ink ...  7.17:1
///   GENERAL            unityBlue #273351 under white ink .......... 12.51:1
///                      (solid white 1 px outline gives it an edge at
///                      the card's dark end: 12.51:1 against the fill,
///                      4.59:1 against the light end)
///   SPECIAL, MUNICIPAL momentumBlue #32A6DE under unityBlue ink ..  4.55:1
///   RUNOFF             ProfileTokens.danger #B91C1C under white ...  6.47:1
///   OTHER              white #FFFFFF under unityBlue ink .......... 12.51:1
///
/// Rejected fills, with the measured reason: democratBlue #3B82F6 is
/// 3.68:1 under white and 3.40:1 under navy; steelBlue #4682B4 is
/// 4.11:1 and 3.05:1; republicanRed #EF4444 is 3.76:1 and 3.32:1. None
/// clears 4.5:1 with either ink. sunriseGold is never TEXT on the card
/// (2.63:1 at the light end); it is only ever a fill under navy ink.
///
/// The old translucent frame (white 0.03) composited to #2381AE at the
/// light end and pulled white text down to 4.35:1, so the frame is now
/// a hairline border with no fill.
class VoterHistoryStrip extends StatelessWidget {
  final List<VoterHistoryEntry> history;

  const VoterHistoryStrip({
    super.key,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.history_toggle_off, size: 16, color: Colors.white),
            SizedBox(width: 8),
            Text('No voting history on file.', style: ProfileText.caption),
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

    // Aggregate pills are the collapsed header AND stay visible when
    // expanded. Keeping them visible while collapsed is the load-bearing
    // affordance: at-a-glance "primary 4 of 6, general 7 of 7" is what
    // users want most of the time.
    final aggWrap = Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _AggPill(
          label: 'Primary',
          voted: agg.primaryVoted,
          total: agg.primaryTotal,
          style: _BadgeStyle.primary,
        ),
        _AggPill(
          label: 'General',
          voted: agg.generalVoted,
          total: agg.generalTotal,
          style: _BadgeStyle.general,
        ),
        if (agg.otherVoted > 0)
          _AggPill(
            label: 'Special / Municipal',
            voted: agg.otherVoted,
            total: agg.otherVoted,
            style: _BadgeStyle.civic,
          ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ProfileTokens.hairline),
      ),
      child: ExpansionTile(
        // PageStorageKey<String> so the open/closed state has its own
        // bucket slot and survives scrolling. Without an explicit key
        // the auto-generated bucket identifier can collide with sibling
        // widgets and the `as bool?` cast inside
        // _ExpansionTileState.initState throws.
        key: const PageStorageKey<String>('voter-history-strip'),
        initiallyExpanded: false,
        // Every colour is set explicitly so nothing reaches this tile
        // from Theme. Border() on both shapes removes the theme divider
        // that would otherwise fight the hairline frame above.
        shape: const Border(),
        collapsedShape: const Border(),
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        iconColor: Colors.white,
        collapsedIconColor: Colors.white,
        textColor: Colors.white,
        collapsedTextColor: Colors.white,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
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
    );
  }

  // Aggregate computation

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
    // even years (2018, 2020, 2022, 2024, 2026 and so on). This is the
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
      // votes (data could include odd-year specials etc.), so "X of Y"
      // never shows X > Y.
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

// Subviews

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
        // Year header: the field-label scale (11 w700 white, letter
        // spacing 1.2) over a decorative hairline. No fill, so white
        // keeps its full ratio against the card wherever the group
        // lands on the gradient.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: ProfileTokens.hairline),
              bottom: BorderSide(color: ProfileTokens.hairline),
            ),
          ),
          child: Text('$year', style: ProfileText.label),
        ),
        for (var i = 0; i < entries.length; i++) ...[
          _ElectionRow(entry: entries[i]),
          if (i < entries.length - 1)
            Container(
              height: 1,
              color: ProfileTokens.hairline,
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
    final (style, badgeText) = _badgeFor(type, entry.electionType);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Voted indicator. Every entry in voter_history represents a
          // recorded vote, so the row always carries a check. Full
          // white glyph straight on the card: 4.59:1 at the light end,
          // which clears the 3:1 bar for a graphic and the 4.5:1 bar
          // for text. No fill, so there is no translucent colour to
          // fail against.
          const Icon(Icons.check_circle, size: 18, color: Colors.white),
          const SizedBox(width: 10),
          // Date
          SizedBox(
            width: 60,
            child: Text(
              dateStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          // Election label
          Expanded(
            child: Text(
              entry.electionType.isNotEmpty ? entry.electionType : 'Election',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Type badge
          _TypeBadge(label: badgeText, style: style),
        ],
      ),
    );
  }

  (_BadgeStyle, String) _badgeFor(_Type t, String raw) {
    switch (t) {
      case _Type.primary:
        return (_BadgeStyle.primary, 'PRIMARY');
      case _Type.general:
        return (_BadgeStyle.general, 'GENERAL');
      case _Type.other:
        final lower = raw.toLowerCase();
        if (lower.contains('special')) {
          return (_BadgeStyle.civic, 'SPECIAL');
        }
        if (lower.contains('municipal')) {
          return (_BadgeStyle.civic, 'MUNICIPAL');
        }
        if (lower.contains('runoff')) {
          return (_BadgeStyle.runoff, 'RUNOFF');
        }
        return (
          _BadgeStyle.other,
          raw.isEmpty ? 'OTHER' : raw.toUpperCase()
        );
    }
  }
}

/// One election-type badge. Solid fill, ink that clears 4.5:1 against
/// that fill (ratios in the class doc above), 11 w800 letter spacing
/// 1.0 on radius 6, the same scale as ProfilePill. The fill is opaque,
/// so its ratio is a property of the badge and not of where it sits on
/// the gradient.
class _TypeBadge extends StatelessWidget {
  final String label;
  final _BadgeStyle style;

  const _TypeBadge({required this.label, required this.style});

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color ink;
    Border? border;
    switch (style) {
      case _BadgeStyle.primary:
        // sunriseGold under unityBlue: 7.17:1.
        fill = BrandColors.sunriseGold;
        ink = BrandColors.unityBlue;
        break;
      case _BadgeStyle.general:
        // unityBlue under white: 12.51:1. Solid white outline so the
        // badge keeps an edge at the dark end of the card.
        fill = BrandColors.unityBlue;
        ink = Colors.white;
        border = Border.all(color: ProfileTokens.border);
        break;
      case _BadgeStyle.civic:
        // momentumBlue under unityBlue: 4.55:1.
        fill = BrandColors.momentumBlue;
        ink = BrandColors.unityBlue;
        break;
      case _BadgeStyle.runoff:
        // ProfileTokens.danger #B91C1C under white: 6.47:1.
        fill = ProfileTokens.danger;
        ink = Colors.white;
        break;
      case _BadgeStyle.other:
        // White under unityBlue: 12.51:1.
        fill = Colors.white;
        ink = BrandColors.unityBlue;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(ProfileTokens.pillRadius),
        border: border,
      ),
      child: Text(label, style: ProfileText.pill.copyWith(color: ink)),
    );
  }
}

/// One aggregate line: the type badge carries the colour, and the
/// count is full white text beside it. The badge is the same solid
/// fill the rows use, so the colour meaning reads identically in the
/// collapsed header and the expanded table.
class _AggPill extends StatelessWidget {
  final String label;
  final int voted;
  final int total;
  final _BadgeStyle style;

  const _AggPill({
    required this.label,
    required this.voted,
    required this.total,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TypeBadge(label: label.toUpperCase(), style: style),
        const SizedBox(width: 8),
        Text.rich(
          TextSpan(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            children: [
              const TextSpan(text: 'participation: '),
              TextSpan(
                text: '$voted of $total',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Internal types

enum _Type { primary, general, other }

/// Which solid fill a badge takes. `civic` covers both SPECIAL and
/// MUNICIPAL, which shared one colour before this restyle too.
enum _BadgeStyle { primary, general, civic, runoff, other }

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
