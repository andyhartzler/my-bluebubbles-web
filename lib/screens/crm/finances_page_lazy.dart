import 'package:flutter/material.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

import 'finances_page.dart' deferred as fp;

/// Lazy wrapper around [FinancesPage]. Uses Dart's deferred-loading
/// (`import ... deferred as`) so dart2js emits the Finances module and its
/// heavy dependencies (fl_chart, the printing/pdf export path, the Plaid
/// link flow) as a separate JS chunk that only downloads when this widget
/// mounts.
///
/// `_HomeState` only inserts this into the IndexedStack once the Finances
/// section is first visited, so users who never open Finances never download
/// the chunk.
class FinancesPageLazy extends StatefulWidget {
  const FinancesPageLazy({super.key});

  @override
  State<FinancesPageLazy> createState() => _FinancesPageLazyState();
}

class _FinancesPageLazyState extends State<FinancesPageLazy> {
  late final Future<void> _loadFuture = fp.loadLibrary();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: BrandedBackground(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: BrandedBackground(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Failed to load finances module',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        snap.error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return fp.FinancesPage();
      },
    );
  }
}
