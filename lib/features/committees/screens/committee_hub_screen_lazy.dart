import 'package:flutter/material.dart';

import 'package:bluebubbles/widgets/deferred_module_lazy.dart';

import 'committee_hub_screen.dart' deferred as chs;

/// Lazy wrapper around [CommitteeHubScreen], the landing screen for committee
/// members. It reaches `committee_member_workspace_screen.dart` and from there
/// most of the committees tree, so holding it eagerly in `main.dart` defeated
/// `committees_dashboard_screen_lazy.dart` entirely.
///
/// `main.dart` is the only caller.
class CommitteeHubScreenLazy extends StatelessWidget {
  const CommitteeHubScreenLazy({super.key});

  @override
  Widget build(BuildContext context) {
    return DeferredModule(
      moduleName: 'committee hub',
      load: () => chs.loadLibrary(),
      builder: (_) => chs.CommitteeHubScreen(),
    );
  }
}
