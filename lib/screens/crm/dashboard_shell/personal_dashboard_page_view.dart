import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/dashboard_metrics.dart';
import 'package:bluebubbles/models/crm/dashboard_page.dart';
import 'package:bluebubbles/services/crm/dashboard_metrics_service.dart';

import 'dashboard_widget_renderer.dart';

/// Read-only render of a single user's dashboard page (one tab on the
/// `DashboardShellScreen`). Uses the universal metrics row as the data
/// source and the page's own seeded layout.
///
/// v1: read-only with the v1 renderer (scalar/leaderboard/etc. live;
/// chart widgets stub to "Live values on the Universal tab").
/// v2: drag-drop edit + full chart support.
class PersonalDashboardPageView extends StatefulWidget {
  final DashboardPage page;

  const PersonalDashboardPageView({super.key, required this.page});

  @override
  State<PersonalDashboardPageView> createState() => _PersonalDashboardPageViewState();
}

class _PersonalDashboardPageViewState extends State<PersonalDashboardPageView>
    with AutomaticKeepAliveClientMixin {
  final _metricsService = DashboardMetricsService();
  DashboardMetrics? _metrics;
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final m = await _metricsService.fetchMetrics();
    if (!mounted) return;
    setState(() {
      _metrics = m;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading || _metrics == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final metrics = _metrics!;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final config = isMobile ? widget.page.layoutMobile : widget.page.layout;
    final widgets = config.widgets.where((w) => w.visible).toList();
    final cols = isMobile ? 2 : (config.columns > 0 ? config.columns : 4);

    if (widgets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              Text('No widgets on this page yet',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              const Text(
                'Personal page editing lands in v2. For now, recreate the page seeded from Universal to populate it.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.page.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _load,
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: isMobile ? 1.4 : 1.6,
            children: widgets
                .map((w) => DashboardWidgetRenderer.render(
                      config: w,
                      metrics: metrics,
                    ))
                .toList(),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Personal-page editing lands in v2. Until then, edit the Universal tab and re-create this page.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
