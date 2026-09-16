import 'package:flutter/material.dart';

import 'package:bluebubbles/widgets/deferred_module_lazy.dart';

import 'vote_detail_screen.dart' deferred as vds;

/// Lazy wrapper around [VoteDetailScreen].
///
/// `vote_detail_screen.dart` reaches `vote_builder_screen.dart` and through it
/// flutter_quill (38K package lines). Its eager importers outside
/// `lib/features/forms/` were `committee_votes_tab.dart` and
/// `member_detail_screen.dart`; both now go through this shim.
///
/// Endorsement voting is live, so the callbacks and `isMemberView` are passed
/// straight through unchanged.
class VoteDetailScreenLazy extends StatelessWidget {
  const VoteDetailScreenLazy({
    super.key,
    required this.voteId,
    this.onSendAsEmail,
    this.onSendAsMessage,
    this.isMemberView = false,
  });

  final String voteId;
  final VoidCallback? onSendAsEmail;
  final VoidCallback? onSendAsMessage;
  final bool isMemberView;

  @override
  Widget build(BuildContext context) {
    return DeferredModule(
      moduleName: 'vote detail',
      load: () => vds.loadLibrary(),
      builder: (_) => vds.VoteDetailScreen(
        voteId: voteId,
        onSendAsEmail: onSendAsEmail,
        onSendAsMessage: onSendAsMessage,
        isMemberView: isMemberView,
      ),
    );
  }
}
