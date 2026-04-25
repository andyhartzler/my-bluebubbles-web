import 'package:flutter/material.dart';

import 'package:bluebubbles/screens/dashboard/models/dashboard_widget_config.dart';

/// Picker for adding a metric tile to the home screen "optional tiles"
/// area. Two-step flow: pick a data source, then pick a widget type
/// supported by that source. Returns a `DashboardWidgetConfig` ready to
/// append to the user's `user_home_preferences.layout.widgets` list.
class AddTileDialog extends StatefulWidget {
  const AddTileDialog({super.key});

  @override
  State<AddTileDialog> createState() => _AddTileDialogState();
}

class _AddTileDialogState extends State<AddTileDialog> {
  DashboardDataSource? _source;
  DashboardWidgetType? _type;
  static const _initialSize = DashboardWidgetSize.small;
  DashboardWidgetSize _size = _initialSize;
  String _search = '';

  List<DashboardDataSource> get _filtered {
    final q = _search.trim().toLowerCase();
    final all = DashboardDataSources.all;
    if (q.isEmpty) return all;
    return all.where((s) =>
        s.label.toLowerCase().contains(q) ||
        s.description.toLowerCase().contains(q) ||
        s.key.toLowerCase().contains(q)).toList();
  }

  void _confirm() {
    final src = _source;
    final type = _type;
    if (src == null || type == null) return;
    final config = DashboardWidgetConfig(
      id: 'home_${DateTime.now().microsecondsSinceEpoch}_${src.key}',
      type: type,
      size: _size,
      dataSourceKey: src.key,
      title: src.label,
      icon: src.icon,
    );
    Navigator.of(context).pop(config);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_source == null ? 'Add a metric tile' : 'Choose a tile style'),
      content: SizedBox(
        width: 480,
        height: 480,
        child: _source == null ? _buildSourcePicker() : _buildTypePicker(),
      ),
      actions: [
        if (_source != null)
          TextButton(
            onPressed: () => setState(() {
              _source = null;
              _type = null;
            }),
            child: const Text('Back'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_source != null)
          FilledButton(
            onPressed: _type == null ? null : _confirm,
            child: const Text('Add tile'),
          ),
      ],
    );
  }

  Widget _buildSourcePicker() {
    final sources = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Search metrics',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: sources.isEmpty
              ? const Center(child: Text('No matching metrics'))
              : ListView.separated(
                  itemCount: sources.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final s = sources[i];
                    return ListTile(
                      leading: Icon(s.icon),
                      title: Text(s.label),
                      subtitle: Text(
                        s.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => setState(() {
                        _source = s;
                        _type = s.supportedWidgets.first;
                      }),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTypePicker() {
    final src = _source!;
    return ListView(
      children: [
        ListTile(
          leading: Icon(src.icon),
          title: Text(src.label, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(src.description),
          dense: true,
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Style', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        ...src.supportedWidgets.map((t) {
          return RadioListTile<DashboardWidgetType>(
            dense: true,
            title: Text(_typeLabel(t)),
            subtitle: Text(_typeDescription(t)),
            value: t,
            groupValue: _type,
            onChanged: (v) => setState(() => _type = v),
          );
        }),
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Size', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        ..._sizeOptions.map((s) {
          return RadioListTile<DashboardWidgetSize>(
            dense: true,
            title: Text(_sizeLabel(s)),
            value: s,
            groupValue: _size,
            onChanged: (v) {
              if (v != null) setState(() => _size = v);
            },
          );
        }),
      ],
    );
  }

  static const _sizeOptions = [
    DashboardWidgetSize.mini,
    DashboardWidgetSize.small,
    DashboardWidgetSize.medium,
    DashboardWidgetSize.large,
  ];

  String _sizeLabel(DashboardWidgetSize s) {
    switch (s) {
      case DashboardWidgetSize.mini:
        return 'Mini (1×1, compact)';
      case DashboardWidgetSize.small:
        return 'Small (½ row)';
      case DashboardWidgetSize.medium:
        return 'Medium (1×1 standard)';
      case DashboardWidgetSize.large:
        return 'Large (2×1 wide)';
      default:
        return s.name;
    }
  }

  String _typeLabel(DashboardWidgetType t) {
    switch (t) {
      case DashboardWidgetType.statCard:
        return 'Stat card';
      case DashboardWidgetType.trendCard:
        return 'Trend card';
      case DashboardWidgetType.progressRing:
        return 'Progress ring';
      case DashboardWidgetType.leaderboard:
        return 'Leaderboard';
      case DashboardWidgetType.memberList:
        return 'Member list';
      case DashboardWidgetType.dynamicDistribution:
        return 'Distribution chart';
      case DashboardWidgetType.quickLinksButton:
        return 'Quick links button';
      case DashboardWidgetType.barChart:
        return 'Bar chart (live on Universal tab)';
      case DashboardWidgetType.lineChart:
        return 'Line chart (live on Universal tab)';
      case DashboardWidgetType.pieChart:
        return 'Pie chart (live on Universal tab)';
      case DashboardWidgetType.donutChart:
        return 'Donut chart (live on Universal tab)';
      case DashboardWidgetType.sparkline:
        return 'Sparkline (live on Universal tab)';
      case DashboardWidgetType.heatmap:
        return 'Heatmap (live on Universal tab)';
    }
  }

  String _typeDescription(DashboardWidgetType t) {
    switch (t) {
      case DashboardWidgetType.statCard:
        return 'Big number with label and icon';
      case DashboardWidgetType.trendCard:
        return 'Number plus trend arrow';
      case DashboardWidgetType.progressRing:
        return 'Circular progress against a target';
      case DashboardWidgetType.leaderboard:
        return 'Ranked list of top contributors';
      case DashboardWidgetType.memberList:
        return 'Recent members with avatars';
      case DashboardWidgetType.dynamicDistribution:
        return 'Bar chart with category dropdown';
      case DashboardWidgetType.quickLinksButton:
        return 'Tappable shortcut to Quick Links';
      default:
        return 'Full version available on the Universal Dashboard tab';
    }
  }
}
