import 'package:flutter/material.dart';

import '../../../../theme/moyd_brand.dart';
import '../../models/candidate_entry.dart';
import '../../slate_controller.dart';

/// The collapsible filter panel above the roster gallery. Reads and mutates the
/// [SlateController]; the parent rebuilds on notify.
class RosterFilterShelf extends StatefulWidget {
  final SlateController controller;
  const RosterFilterShelf({super.key, required this.controller});

  @override
  State<RosterFilterShelf> createState() => _RosterFilterShelfState();
}

class _RosterFilterShelfState extends State<RosterFilterShelf> {
  late final TextEditingController _district =
      TextEditingController(text: widget.controller.districtFilter);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncFromController);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromController);
    _district.dispose();
    super.dispose();
  }

  // Keep the district field text in sync when the controller is cleared
  // externally (e.g. "Clear" button).
  void _syncFromController() {
    if (!mounted) return;
    if (_district.text != widget.controller.districtFilter) {
      _district.text = widget.controller.districtFilter;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final c = widget.controller;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text('Filters',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              if (c.hasActiveFilters)
                TextButton.icon(
                  onPressed: c.clearFilters,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: cs.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          _label(theme, 'Office level'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final level in OfficeLevel.values)
                FilterChip(
                  label: Text(level.label),
                  selected: c.officeFilter.contains(level),
                  onSelected: (_) => c.toggleOffice(level),
                  selectedColor: MoydBrand.navy,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: c.officeFilter.contains(level)
                        ? Colors.white
                        : cs.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  backgroundColor: cs.surface,
                  side: BorderSide(color: cs.outlineVariant),
                ),
            ],
          ),
          const SizedBox(height: 14),

          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth > 520;
            final district = SizedBox(
              width: wide ? 200 : double.infinity,
              child: TextField(
                controller: _district,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'District',
                  prefixIcon: const Icon(Icons.place_outlined, size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: c.setDistrictFilter,
              ),
            );
            final align = _AlignmentRange(controller: c);
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  district,
                  const SizedBox(width: 20),
                  Expanded(child: align),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [district, const SizedBox(height: 12), align],
            );
          }),
          const SizedBox(height: 6),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _toggle(theme, 'Young Dem', c.youngDemOnly, c.setYoungDemOnly,
                  icon: Icons.workspace_premium),
              _toggle(theme, 'Non-Dem history', c.flagNonDem, c.setFlagNonDem,
                  icon: Icons.swap_horiz),
              _toggle(theme, 'Self-funded >50%', c.flagSelfFunded,
                  c.setFlagSelfFunded,
                  icon: Icons.savings_outlined),
              _toggle(theme, 'Missing docs', c.flagMissingDocs,
                  c.setFlagMissingDocs,
                  icon: Icons.folder_off_outlined),
              _toggle(theme, 'Not certified', c.flagUncertified,
                  c.setFlagUncertified,
                  icon: Icons.history_edu_outlined),
              _toggle(theme, 'Include unscored', c.includeUnscored,
                  c.setIncludeUnscored,
                  icon: Icons.help_outline),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600)),
      );

  Widget _toggle(ThemeData theme, String label, bool value,
      ValueChanged<bool> onChanged,
      {required IconData icon}) {
    final cs = theme.colorScheme;
    return FilterChip(
      avatar: Icon(icon,
          size: 15, color: value ? Colors.white : cs.onSurfaceVariant),
      label: Text(label),
      selected: value,
      onSelected: onChanged,
      selectedColor: MoydBrand.navySoft,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: value ? Colors.white : cs.onSurface,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      backgroundColor: cs.surface,
      side: BorderSide(color: cs.outlineVariant),
    );
  }
}

class _AlignmentRange extends StatelessWidget {
  final SlateController controller;
  const _AlignmentRange({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final r = controller.alignmentRange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Alignment',
                style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text('${r.start.round()}%–${r.end.round()}%',
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: MoydBrand.navy,
            thumbColor: MoydBrand.navy,
            overlayColor: MoydBrand.navy.withOpacity(0.12),
          ),
          child: RangeSlider(
            values: RangeValues(r.start, r.end),
            min: 0,
            max: 100,
            divisions: 20,
            labels: RangeLabels('${r.start.round()}', '${r.end.round()}'),
            onChanged: (v) => controller
                .setAlignmentRange(RangeValuesLite(v.start, v.end)),
          ),
        ),
      ],
    );
  }
}
