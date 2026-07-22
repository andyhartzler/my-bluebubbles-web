import 'package:flutter/material.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

import 'candidates_page.dart' deferred as cp;

/// Lazy wrapper around [CandidatesPage]. Uses Dart's deferred-loading
/// (`import ... deferred as`) so dart2js emits the Candidates module and its
/// heavy dependencies (flutter_map for the Missouri map, fl_chart analytics)
/// as a separate JS chunk that only downloads when this widget mounts.
///
/// `_HomeState` only inserts this into the IndexedStack once the Candidates
/// section is first visited, so users who never open Candidates never
/// download the chunk.
class CandidatesPageLazy extends StatefulWidget {
  const CandidatesPageLazy({super.key});

  @override
  State<CandidatesPageLazy> createState() => _CandidatesPageLazyState();
}

class _CandidatesPageLazyState extends State<CandidatesPageLazy> {
  late final Future<void> _loadFuture = cp.loadLibrary();

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
                        'Failed to load candidates module',
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
        return cp.CandidatesPage();
      },
    );
  }
}
