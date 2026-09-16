import 'package:flutter/material.dart';

import 'package:bluebubbles/widgets/deferred_module_lazy.dart';

import 'dashboard_screen.dart' deferred as ds;

/// Lazy wrapper around [DashboardScreen] (the universal drag-and-drop
/// dashboard). It is tab 0 of `DashboardShellScreen`, and it was the single
/// biggest eager edge in the boot bundle: through
/// `committee_workspace_screen.dart` it reached the whole committees and
/// candidates tree, which is why `committees_dashboard_screen_lazy.dart`
/// deferred almost nothing before this shim existed.
///
/// `DashboardShellScreen` is the only caller. Nothing else may import
/// `dashboard_screen.dart` directly or the split stops working.
class DashboardScreenLazy extends StatelessWidget {
  const DashboardScreenLazy({super.key});

  @override
  Widget build(BuildContext context) {
    return DeferredModule(
      moduleName: 'dashboard module',
      load: () => ds.loadLibrary(),
      builder: (_) => ds.DashboardScreen(),
    );
  }
}
