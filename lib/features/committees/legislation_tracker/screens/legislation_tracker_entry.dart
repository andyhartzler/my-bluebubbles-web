import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bluebubbles/features/committees/legislation_tracker/providers/bill_search_provider.dart';
import 'package:bluebubbles/features/committees/legislation_tracker/providers/legislation_provider.dart';
import 'package:bluebubbles/features/committees/legislation_tracker/screens/legislation_tracker_screen.dart';

/// The Legislation tab, providers included.
///
/// Both committee workspace screens used to build this `MultiProvider` inline,
/// which forced them to import `LegislationProvider` and `BillSearchProvider`
/// eagerly and dragged the whole legislation tracker into `main.dart.js`.
/// The providers were already scoped to this tab only, so moving the wrapper
/// in here changes no provider scope: the tracker still sees them, and no
/// sibling tab ever could.
///
/// This file exists so `legislation_tracker_screen_lazy.dart` has a single
/// `deferred as` target that covers the screen AND its providers.
class LegislationTrackerEntry extends StatelessWidget {
  const LegislationTrackerEntry({
    super.key,
    required this.committeeId,
    this.isMemberView = false,
  });

  final String committeeId;
  final bool isMemberView;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LegislationProvider()),
        ChangeNotifierProvider(create: (_) => BillSearchProvider()),
      ],
      child: LegislationTrackerScreen(
        committeeId: committeeId,
        isMemberView: isMemberView,
      ),
    );
  }
}
