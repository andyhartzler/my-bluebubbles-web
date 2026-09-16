import 'package:flutter/material.dart';

import 'package:bluebubbles/widgets/deferred_module_lazy.dart';

import 'candidate_volunteers_workspace.dart' deferred as cvw;

/// Lazy wrapper around [CandidateVolunteersWorkspace], the war-room MAP and
/// ACTIVITIES workspace. It dominates roughly 14.6K lines (the mobilize desk
/// and the candidate volunteers map), and it had two eager importers,
/// `candidates_page.dart` and the personalized-home `assignments_panel.dart`.
/// Both go through this shim; deferring only one would keep the subtree eager.
class CandidateVolunteersWorkspaceLazy extends StatelessWidget {
  const CandidateVolunteersWorkspaceLazy({super.key});

  @override
  Widget build(BuildContext context) {
    return DeferredModule(
      moduleName: 'candidate volunteers workspace',
      load: () => cvw.loadLibrary(),
      builder: (_) => cvw.CandidateVolunteersWorkspace(),
    );
  }
}
