import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/dashboard_metrics.dart';
import 'package:bluebubbles/models/crm/user_home_preferences.dart';
import 'package:bluebubbles/screens/crm/dashboard_shell/dashboard_widget_renderer.dart';
import 'package:bluebubbles/screens/dashboard/models/dashboard_widget_config.dart';
import 'package:bluebubbles/services/crm/dashboard_metrics_service.dart';
import 'package:bluebubbles/services/crm/user_home_preferences_service.dart';

import 'add_tile_dialog.dart';

/// Drag-add area on the Personalized Home Screen where the user pins
/// dashboard metric tiles. Tiles render via `DashboardWidgetRenderer`
/// (the same dispatcher used by personal Dashboard pages) and persist
/// to `user_home_preferences.layout` / `layout_mobile`.
///
/// Replaces the v1 `_OptionalTilesPlaceholder` placeholder.
class OptionalTilesSection extends StatefulWidget {
  final UserHomePreferences prefs;
  final ValueChanged<UserHomePreferences> onPrefsChanged;

  const OptionalTilesSection({
    super.key,
    required this.prefs,
    required this.onPrefsChanged,
  });

  @override
  State<OptionalTilesSection> createState() => _OptionalTilesSectionState();
}

class _OptionalTilesSectionState extends State<OptionalTilesSection> {
  final _metricsService = DashboardMetricsService();
  final _prefsService = UserHomePreferencesService();
  DashboardMetrics? _metrics;
  bool _loadingMetrics = true;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    final m = await _metricsService.fetchMetrics();
    if (!mounted) return;
    setState(() {
      _metrics = m;
      _loadingMetrics = false;
    });
  }

  bool get _isMobile => MediaQuery.of(context).size.width < 600;

  DashboardConfig get _activeLayout =>
      _isMobile ? widget.prefs.layoutMobile : widget.prefs.layout;

  Future<void> _persist(UserHomePreferences updated) async {
    setState(() => _saving = true);
    final ok = await _prefsService.upsert(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save tile changes')),
      );
      return;
    }
    widget.onPrefsChanged(updated);
  }

  Future<void> _addTile() async {
    final newTile = await showDialog<DashboardWidgetConfig?>(
      context: context,
      builder: (_) => const AddTileDialog(),
    );
    if (newTile == null) return;
    final layout = _activeLayout.copyWith(
      widgets: [..._activeLayout.widgets, newTile],
    );
    final updated = _isMobile
        ? widget.prefs.copyWith(layoutMobile: layout)
        : widget.prefs.copyWith(layout: layout);
    await _persist(updated);
  }

  Future<void> _removeTile(String id) async {
    final layout = _activeLayout.copyWith(
      widgets: _activeLayout.widgets.where((w) => w.id != id).toList(),
    );
    final updated = _isMobile
        ? widget.prefs.copyWith(layoutMobile: layout)
        : widget.prefs.copyWith(layout: layout);
    await _persist(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = _activeLayout;
    final widgets = layout.widgets;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.dashboard_customize,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Metric tiles', style: theme.textTheme.titleSmall),
                const Spacer(),
                if (_saving)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (widgets.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() => _editing = !_editing),
                    icon: Icon(_editing ? Icons.done : Icons.edit_outlined),
                    label: Text(_editing ? 'Done' : 'Edit'),
                  ),
                FilledButton.tonalIcon(
                  onPressed: _addTile,
                  icon: const Icon(Icons.add),
                  label: const Text('Add tile'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loadingMetrics)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (widgets.isEmpty)
              _buildEmptyState(theme)
            else
              _buildTileGrid(widgets),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.add_chart,
              size: 36, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            'No tiles yet',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Pin metrics like Total Members, Donations, Bills Tracked — '
            'they live here on your home screen.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildTileGrid(List<DashboardWidgetConfig> widgets) {
    final metrics = _metrics ?? DashboardMetrics.empty;
    final columns = _isMobile ? 2 : (_activeLayout.columns.clamp(2, 6));
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: widgets.map((cfg) {
            final span = _spanForSize(cfg.size).clamp(1, columns).toInt();
            final width = tileWidth * span + spacing * (span - 1);
            final height = _heightForSize(cfg.size, tileWidth);
            return SizedBox(
              width: width,
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DashboardWidgetRenderer.render(
                    config: cfg,
                    metrics: metrics,
                  ),
                  if (_editing)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: Colors.black.withOpacity(0.6),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Remove tile',
                          icon: const Icon(Icons.close,
                              size: 16, color: Colors.white),
                          onPressed: () => _removeTile(cfg.id),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  static int _spanForSize(DashboardWidgetSize size) {
    switch (size) {
      case DashboardWidgetSize.large:
      case DashboardWidgetSize.featured:
        return 2;
      case DashboardWidgetSize.wide:
      case DashboardWidgetSize.hero:
        return 3;
      case DashboardWidgetSize.mobileFull:
        return 4;
      default:
        return 1;
    }
  }

  static double _heightForSize(DashboardWidgetSize size, double tileWidth) {
    switch (size) {
      case DashboardWidgetSize.mini:
      case DashboardWidgetSize.small:
        return 110;
      case DashboardWidgetSize.medium:
      case DashboardWidgetSize.large:
      case DashboardWidgetSize.wide:
        return 160;
      case DashboardWidgetSize.featured:
        return 200;
      case DashboardWidgetSize.tall:
      case DashboardWidgetSize.mobileFull:
        return 240;
      case DashboardWidgetSize.hero:
        return 280;
    }
  }
}
