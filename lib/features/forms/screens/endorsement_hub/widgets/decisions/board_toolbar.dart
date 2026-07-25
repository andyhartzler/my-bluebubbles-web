import 'package:flutter/material.dart';

import '../../theme/hub_theme.dart';

/// Ballot list filter (promoted from the board's private enum; same values).
enum VoteFilter { all, needsMyVote, splits }

/// Ballot list sort (promoted from the board's private enum; same values).
///
/// [race] orders by office rank (US House, State Senate, State House, then
/// keyless rows last), then numeric district, then name. It is deliberately
/// NOT the default: a district run-through is a real way to chair a meeting,
/// but reordering all ~46 solo races to serve 7 contested ones would displace
/// the yesShare consensus-readiness order the committee actually used. The
/// race clusters render under every sort, so this composes for free.
enum VoteSort { yesShare, name, alignment, race }

/// Pin-only [SliverPersistentHeaderDelegate] for the sticky toolbar: the
/// board computes the extent from its single LayoutBuilder breakpoint and the
/// delegate never shrinks (minExtent == maxExtent).
class BoardToolbarDelegate extends SliverPersistentHeaderDelegate {
  final double extent;
  final bool narrow;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoteFilter filter;
  final ValueChanged<VoteFilter> onFilterChanged;
  final bool showSplits;
  final int needsMyVoteCount;
  final VoteSort sort;
  final ValueChanged<VoteSort> onSortChanged;

  /// Ballot progress for the pill: how many the signed-in exec voted on.
  final int votedCount;
  final int ballotTotal;

  const BoardToolbarDelegate({
    required this.extent,
    required this.narrow,
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
    required this.filter,
    required this.onFilterChanged,
    required this.showSplits,
    required this.needsMyVoteCount,
    required this.sort,
    required this.onSortChanged,
    required this.votedCount,
    required this.ballotTotal,
  });

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return BoardToolbar(
      narrow: narrow,
      overlaps: overlapsContent,
      searchController: searchController,
      query: query,
      onQueryChanged: onQueryChanged,
      filter: filter,
      onFilterChanged: onFilterChanged,
      showSplits: showSplits,
      needsMyVoteCount: needsMyVoteCount,
      sort: sort,
      onSortChanged: onSortChanged,
      votedCount: votedCount,
      ballotTotal: ballotTotal,
    );
  }

  // The board rebuilds the whole sliver tree per notify; a fresh delegate
  // instance always carries the live state, so always rebuild (cheap).
  @override
  bool shouldRebuild(covariant BoardToolbarDelegate oldDelegate) => true;
}

/// The sticky control strip: search + the existing filter switch + sort menu
/// + the signed-in exec's ballot progress. Fully opaque [ColorScheme.surface]
/// so rows never ghost through while pinned; a hairline + soft shadow fade in
/// via [overlaps] as the list scrolls under it.
class BoardToolbar extends StatelessWidget {
  final bool narrow;
  final bool overlaps;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoteFilter filter;
  final ValueChanged<VoteFilter> onFilterChanged;
  final bool showSplits;
  final int needsMyVoteCount;
  final VoteSort sort;
  final ValueChanged<VoteSort> onSortChanged;
  final int votedCount;
  final int ballotTotal;

  const BoardToolbar({
    super.key,
    required this.narrow,
    required this.overlaps,
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
    required this.filter,
    required this.onFilterChanged,
    required this.showSplits,
    required this.needsMyVoteCount,
    required this.sort,
    required this.onSortChanged,
    required this.votedCount,
    required this.ballotTotal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    final search = _SearchField(
      controller: searchController,
      query: query,
      onChanged: onQueryChanged,
    );
    final filterSwitch = _FilterSwitch(
      filter: filter,
      compact: narrow,
      showSplits: showSplits,
      needsMyVoteCount: needsMyVoteCount,
      onChanged: onFilterChanged,
    );
    final sortMenu = _SortMenu(sort: sort, onChanged: onSortChanged);
    final progress = _ProgressPill(mine: votedCount, total: ballotTotal);

    final Widget content;
    if (narrow) {
      content = Column(
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 8),
                progress,
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: filterSwitch,
                  ),
                ),
                const SizedBox(width: 8),
                sortMenu,
              ],
            ),
          ),
        ],
      );
    } else {
      content = SizedBox(
        height: 40,
        child: Row(
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: search,
              ),
            ),
            const SizedBox(width: 10),
            filterSwitch,
            const SizedBox(width: 10),
            sortMenu,
            const Spacer(),
            progress,
          ],
        ),
      );
    }

    // The "lifts on scroll" affordance: overlapsContent drives the hairline
    // and shadow, no scroll listeners involved. The hairline is painted via
    // foregroundDecoration so it never consumes layout height: a layout
    // border would add 1px the pinned extent (116/64) does not include and
    // overflow the toolbar's content on every build.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      foregroundDecoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: overlaps ? cs.outlineVariant : Colors.transparent,
          ),
        ),
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: overlaps
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(dark ? 0.18 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : const [],
      ),
      // The board hosts this header full-bleed (the opaque surface runs edge
      // to edge under the status-bar-adjacent chrome), so the toolbar owns
      // its own 16px content inset to stay aligned with the padded slivers
      // scrolling beneath it.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: narrow ? 14 : 12),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Name/district search over the ballot AND the locked baseline. In-memory
/// filter over ~70 entries, so no debounce.
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  const _SearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: cs.outlineVariant),
    );
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search name or district',
          prefixIcon: Icon(Icons.search, size: 18, color: cs.onSurfaceVariant),
          // Keep the icons inside the 40px field (their defaults assume 48).
          prefixIconConstraints:
              const BoxConstraints(minWidth: 36, minHeight: 36),
          suffixIconConstraints:
              const BoxConstraints(minWidth: 36, minHeight: 36),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          filled: true,
          fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          enabledBorder: border,
          border: border,
          // Focus ring is an affordance only; the text stays theme tokens.
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: HubTheme.royal, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// "All" / "Needs my vote" / (chair-only) "Splits" segmented pill, matching
/// the hub's segmented-switch treatment (navy gradient on the active segment).
class _FilterSwitch extends StatelessWidget {
  final VoteFilter filter;
  final int needsMyVoteCount;
  final bool showSplits;
  final ValueChanged<VoteFilter> onChanged;

  /// Compact (phone) mode: shorter segment labels so the switch fits a
  /// ~360px viewport beside the sort menu.
  final bool compact;

  const _FilterSwitch({
    required this.filter,
    required this.needsMyVoteCount,
    required this.showSplits,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget seg(VoteFilter f, IconData icon, String label) {
      final active = filter == f;
      return InkWell(
        onTap: () => onChanged(f),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: active ? HubTheme.chip : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 15, color: active ? Colors.white : cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : cs.onSurface)),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg(VoteFilter.all, Icons.groups_2_outlined,
              compact ? 'All' : 'All candidates'),
          const SizedBox(width: 2),
          seg(
            VoteFilter.needsMyVote,
            Icons.pending_actions,
            needsMyVoteCount > 0
                ? (compact
                    ? 'Needs vote ($needsMyVoteCount)'
                    : 'Needs my vote ($needsMyVoteCount)')
                : (compact ? 'Needs vote' : 'Needs my vote'),
          ),
          if (showSplits) ...[
            const SizedBox(width: 2),
            seg(VoteFilter.splits, Icons.call_split, 'Splits'),
          ],
        ],
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  final VoteSort sort;
  final ValueChanged<VoteSort> onChanged;
  const _SortMenu({required this.sort, required this.onChanged});

  String _label(VoteSort s) => switch (s) {
        VoteSort.yesShare => 'Yes share',
        VoteSort.name => 'Name',
        VoteSort.alignment => 'Alignment',
        VoteSort.race => 'Race',
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<VoteSort>(
      tooltip: 'Sort candidates',
      initialValue: sort,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final s in VoteSort.values)
          PopupMenuItem(value: s, child: Text('Sort by ${_label(s)}')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort, size: 15, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(_label(sort),
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Compact ballot-progress pill: white-on-navy text (>= 8:1) with a small
/// decorative gold bar reinforcing the spelled-out count. The scoreboard's
/// fuller progress line scrolls away; this stays pinned.
class _ProgressPill extends StatelessWidget {
  final int mine;
  final int total;
  const _ProgressPill({required this.mine, required this.total});

  @override
  Widget build(BuildContext context) {
    final done = total > 0 && mine == total;
    return Semantics(
      label: 'You voted on $mine of $total ballot candidates',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: HubTheme.chip,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                width: 46,
                height: 5,
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : mine / total,
                  backgroundColor: Colors.white24,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(HubTheme.gold),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              done ? 'All $total in' : '$mine / $total voted',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
