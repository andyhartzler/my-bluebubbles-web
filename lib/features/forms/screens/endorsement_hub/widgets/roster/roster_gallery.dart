import 'package:flutter/material.dart';

import '../../../../theme/moyd_brand.dart';
import '../../models/candidate_entry.dart';
import '../../slate_controller.dart';
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
  void dispose() {
    _search.dispose();
    super.dispose();
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
            if (_filtersOpen) RosterFilterShelf(controller: c),
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
    return Row(
      children: [
        Expanded(
          child: SizedBox(
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
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: c.setSearch,
            ),
          ),
        ),
        const SizedBox(width: 10),
        _sortButton(context, c),
        const SizedBox(width: 8),
        _FilterToggle(
          open: _filtersOpen,
          active: c.hasActiveFilters,
          onTap: () => setState(() => _filtersOpen = !_filtersOpen),
        ),
        const SizedBox(width: 12),
        Text('$shown',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        Text(shown == 1 ? ' candidate' : ' candidates',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }

  Widget _sortButton(BuildContext context, SlateController c) {
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
                  color: c.sort == s ? MoydBrand.navy : cs.onSurfaceVariant,
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            const Icon(Icons.sort, size: 18),
            const SizedBox(width: 6),
            Text(c.sort.label,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _body(
      BuildContext context, SlateController c, List<CandidateEntry> visible) {
    if (!c.hasSubmissions) {
      return const _EmptyState(
        icon: Icons.how_to_vote_outlined,
        title: 'No submissions yet',
        message:
            'Candidate questionnaires will appear here as they come in. Every '
            'face, alignment score and policy stance lands on this board.',
      );
    }
    if (visible.isEmpty) {
      return _EmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: 'No candidates match',
        message: 'Try widening the alignment range or clearing filters.',
        action: c.hasActiveFilters
            ? TextButton(
                onPressed: c.clearFilters,
                child: const Text('Clear filters'),
              )
            : null,
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 24),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: open ? MoydBrand.navy : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: open ? MoydBrand.navy : cs.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.tune,
                size: 18, color: open ? Colors.white : cs.onSurface),
            const SizedBox(width: 6),
            Text('Filters',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: open ? Colors.white : cs.onSurface)),
            if (active) ...[
              const SizedBox(width: 6),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                    color: MoydBrand.gold, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: cs.onSurfaceVariant.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
