import 'package:flutter/material.dart';

import 'package:bluebubbles/widgets/deferred_module_lazy.dart';

import 'legislation_tracker_entry.dart' deferred as lt;

/// Lazy wrapper around the Legislation tab.
///
/// Targets `legislation_tracker_entry.dart` rather than
/// `legislation_tracker_screen.dart` so the two `ChangeNotifierProvider`
/// registrations move behind the boundary as well. A deferred type cannot be
/// used as a type argument, so the `MultiProvider` has to be built inside the
/// deferred library, not here.
///
/// Callers: `committee_workspace_screen.dart` and
/// `committee_member_workspace_screen.dart`. Neither may import the tracker
/// screen or its providers directly.
class LegislationTrackerScreenLazy extends StatelessWidget {
  const LegislationTrackerScreenLazy({
    super.key,
    required this.committeeId,
    this.isMemberView = false,
  });

  final String committeeId;
  final bool isMemberView;

  @override
  Widget build(BuildContext context) {
    return DeferredModule(
      moduleName: 'legislation tracker',
      load: () => lt.loadLibrary(),
      builder: (_) => lt.LegislationTrackerEntry(
        committeeId: committeeId,
        isMemberView: isMemberView,
      ),
    );
  }
}
