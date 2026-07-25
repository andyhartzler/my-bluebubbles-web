import 'package:flutter/material.dart';

import '../../models/candidate_entry.dart';
import '../../slate_controller.dart';
import '../../theme/hub_theme.dart';
import 'roster_card.dart';
import 'roster_filter_shelf.dart';

/// The Roster tab: a faces-first gallery of every candidate with search, sort,
/// a collapsible filter shelf, and tap-to-deep-dive.
class RosterGallery extends StatefulWidget {
  final SlateController controller;
  final void Function(CandidateEntry) onOpen;

  /// Optional per-card decision chip (supplied by the Decisions layer).
  final Widget Function(CandidateEntry)? decisionChipBuilder;

  const RosterGallery({
    super.key,
    required this.controller,
    required this.onOpen,
    this.decisionChipBuilder,
  });

  @override
  State<RosterGallery> createState() => _RosterGalleryState();
}

class _RosterGalleryState extends State<RosterGallery> {
  late final TextEditingController _search =
      TextEditingController(text: widget.controller.search);
  bool _filtersOpen = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncFromController);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromController);
    _search.dispose();
    super.dispose();
  }

  // Search is shared with the ballot toolbar through SlateController: keep
  // this field in sync when the query changes externally (typed in Ballot
  // mode, or clearFilters). Only rewrite when the text differs to avoid
  // cursor jumps and notify loops.
  void _syncFromController() {
    if (!mounted) return;
    if (_search.text != widget.controller.search) {
      _search.text = widget.controller.search;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final visible = c.visible;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _toolbar(context, c, visible.length),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _filtersOpen
                  ? RosterFilterShelf(controller: c)
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 12),
            Expanded(child: _body(context, c, visible)),
          ],
        );
      },
    );
  }

  Widget _toolbar(BuildContext context, SlateController c, int shown) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final search = SizedBox(
      height: 44,
      child: TextField(
        controller: _search,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search name, office, district…',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: c.search.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _search.clear();
                    c.setSearch('');
                  },
                ),
          filled: true,
          fillColor: cs.surfaceContainerHighest.withOpacity(0.35),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: cs.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: cs.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: HubTheme.royal, width: 1.6),
          ),
        ),
        onChanged: c.setSearch,
      ),
    );

    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 620;
      if (narrow) {
        // Phone: search gets its own full-width row; sort / filters / count
        // sit on a second row (sort collapses to its icon so nothing clips).
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            search,
            const SizedBox(height: 8),
            Row(
              children: [
                _sortButton(context, c, iconOnly: true),
                const SizedBox(width: 8),
                _FilterToggle(
                  open: _filtersOpen,
                  active: c.hasActiveFilters,
                  onTap: () => setState(() => _filtersOpen = !_filtersOpen),
                ),
                const Spacer(),
                HubCountPill(
                  icon: Icons.person_outline,
                  text: shown == 1 ? '1 candidate' : '$shown candidates',
                ),
              ],
            ),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: search),
          const SizedBox(width: 10),
          _sortButton(context, c),
          const SizedBox(width: 8),
          _FilterToggle(
            open: _filtersOpen,
            active: c.hasActiveFilters,
            onTap: () => setState(() => _filtersOpen = !_filtersOpen),
          ),
          const SizedBox(width: 12),
          HubCountPill(
            icon: Icons.person_outline,
            text: shown == 1 ? '1 candidate' : '$shown candidates',
          ),
        ],
      );
    });
  }

  Widget _sortButton(BuildContext context, SlateController c,
      {bool iconOnly = false}) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<SlateSort>(
      tooltip: 'Sort',
      onSelected: c.setSort,
      itemBuilder: (context) => [
        for (final s in SlateSort.values)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                Icon(
                  c.sort == s
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: c.sort == s ? HubTheme.royal : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Text(s.label),
              ],
            ),
          ),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: cs.outlineVariant),
          color: cs.surfaceContainerHighest.withOpacity(0.35),
        ),
        child: Row(
          children: [
            const Icon(Icons.sort, size: 18),
            if (!iconOnly) ...[
              const SizedBox(width: 6),
              Text(c.sort.label,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _body(
      BuildContext context, SlateController c, List<CandidateEntry> visible) {
    if (!c.hasSubmissions) {
      return const HubEmptyState(
        icon: Icons.how_to_vote_outlined,
        title: 'No submissions yet',
        message:
            'Candidate questionnaires will appear here as they come in. Every '
            'face, alignment score and policy stance lands on this board.',
      );
    }
    if (visible.isEmpty) {
      return HubEmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: 'No candidates match',
        message: 'Try widening the alignment range or clearing filters.',
        action: c.hasActiveFilters
            ? FilledButton.tonalIcon(
                onPressed: c.clearFilters,
                icon: const Icon(Icons.clear, size: 17),
                label: const Text('Clear filters'),
              )
            : null,
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      // Phone: a single-column list of horizontal cards (face left, details
      // right, always-visible Compare button — no hover needed on touch).
      if (constraints.maxWidth < 480) {
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 24, top: 4),
          itemCount: visible.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final e = visible[i];
            return RosterCard(
              entry: e,
              selected: c.isSelected(e.id),
              horizontal: true,
              onOpen: () => widget.onOpen(e),
              onToggleSelect: () => c.toggleSelected(e.id),
              decisionChip: widget.decisionChipBuilder?.call(e),
            );
          },
        );
      }
      return GridView.builder(
        padding: const EdgeInsets.only(bottom: 24, top: 4),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 236,
          childAspectRatio: 0.66,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: visible.length,
        itemBuilder: (context, i) {
          final e = visible[i];
          return RosterCard(
            entry: e,
            selected: c.isSelected(e.id),
            onOpen: () => widget.onOpen(e),
            onToggleSelect: () => c.toggleSelected(e.id),
            decisionChip: widget.decisionChipBuilder?.call(e),
          );
        },
      );
    });
  }
}

class _FilterToggle extends StatelessWidget {
  final bool open;
  final bool active;
  final VoidCallback onTap;
  const _FilterToggle(
      {required this.open, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: open ? HubTheme.chip : null,
          color: open ? null : cs.surfaceContainerHighest.withOpacity(0.35),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
              color: open ? HubTheme.navy : cs.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.tune,
                size: 18, color: open ? Colors.white : cs.onSurface),
            const SizedBox(width: 6),
            Text('Filters',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: open ? Colors.white : cs.onSurface)),
            if (active) ...[
              const SizedBox(width: 6),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                    color: HubTheme.gold, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
