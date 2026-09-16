import 'package:flutter/material.dart';

import 'package:bluebubbles/widgets/deferred_module_lazy.dart';

import 'endorsement_hub_screen.dart' deferred as ehs;

/// Lazy wrapper around [EndorsementHubScreen].
///
/// The endorsement hub dominates roughly 16K lines (the roster board alone is
/// 8.5K). It had two eager importers, `candidates_page.dart` and the
/// personalized-home `assignments_panel.dart`; both now go through this shim,
/// because deferring only one of them keeps the whole subtree eager.
class EndorsementHubScreenLazy extends StatelessWidget {
  const EndorsementHubScreenLazy({super.key});

  @override
  Widget build(BuildContext context) {
    return DeferredModule(
      moduleName: 'endorsement hub',
      load: () => ehs.loadLibrary(),
      builder: (_) => ehs.EndorsementHubScreen(),
    );
  }
}
