import 'package:flutter/material.dart';

import 'package:bluebubbles/widgets/deferred_module_lazy.dart';

import 'vote_builder_screen.dart' deferred as vbs;

/// Lazy wrapper around [VoteBuilderScreen], the flutter_quill rich-text vote
/// editor. Its only eager importer outside `lib/features/forms/` was
/// `committee_votes_tab.dart`.
class VoteBuilderScreenLazy extends StatelessWidget {
  const VoteBuilderScreenLazy({super.key, this.voteId, this.committee});

  final String? voteId;
  final String? committee;

  @override
  Widget build(BuildContext context) {
    return DeferredModule(
      moduleName: 'vote builder',
      load: () => vbs.loadLibrary(),
      builder: (_) => vbs.VoteBuilderScreen(
        voteId: voteId,
        committee: committee,
      ),
    );
  }
}
