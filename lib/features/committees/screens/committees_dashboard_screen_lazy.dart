import 'package:flutter/material.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

import 'committees_dashboard_screen.dart' deferred as cds;

/// Lazy wrapper around [CommitteesDashboardScreen]. Uses Dart's
/// deferred-loading (`import ... deferred as`) so dart2js emits the
/// Committees module and its heavy dependencies (fl_chart analytics, the
/// legislation-tracker widgets) as a separate JS chunk that only downloads
/// when this widget mounts.
///
/// `_HomeState` only inserts this into the IndexedStack once the Committees
/// section is first visited, so users who never open Committees never
/// download the chunk.
class CommitteesDashboardScreenLazy extends StatefulWidget {
  const CommitteesDashboardScreenLazy({super.key, this.embed = false});

  final bool embed;

  @override
  State<CommitteesDashboardScreenLazy> createState() =>
      _CommitteesDashboardScreenLazyState();
}

class _CommitteesDashboardScreenLazyState
    extends State<CommitteesDashboardScreenLazy> {
  late final Future<void> _loadFuture = cds.loadLibrary();

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
                        'Failed to load committees module',
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
        return cds.CommitteesDashboardScreen(embed: widget.embed);
      },
    );
  }
}
