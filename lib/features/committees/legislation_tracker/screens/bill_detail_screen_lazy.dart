import 'package:flutter/material.dart';

import 'package:bluebubbles/widgets/deferred_module_lazy.dart';

import 'bill_detail_screen.dart' deferred as bds;

/// Lazy wrapper around [BillDetailScreen].
///
/// Pushed as a route from the personalized-home assignments panel, which is on
/// the first screen most execs see. Importing the bill detail screen there
/// eagerly pulled the legislation tracker into the boot bundle on its own,
/// independently of the committee workspaces.
class BillDetailScreenLazy extends StatelessWidget {
  const BillDetailScreenLazy({
    super.key,
    required this.billId,
    required this.committeeId,
  });

  final String billId;
  final String committeeId;

  @override
  Widget build(BuildContext context) {
    return DeferredModule(
      moduleName: 'bill detail',
      load: () => bds.loadLibrary(),
      builder: (_) => bds.BillDetailScreen(
        billId: billId,
        committeeId: committeeId,
      ),
    );
  }
}
