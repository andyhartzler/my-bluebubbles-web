import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

/// Shared scaffolding for every `*_lazy.dart` deferred-import shim.
///
/// A `deferred as` import only keeps bytes out of `main.dart.js` when the
/// target library is unreachable through any eager import. Every shim in this
/// repo therefore owns exactly one deferred import and every call site of the
/// deferred screen goes through the shim.
///
/// [load] must be a closure that calls `loadLibrary()` on the deferred prefix
/// (`() => prefix.loadLibrary()`). It cannot be a tear-off: `loadLibrary` is a
/// synthetic member and Dart forbids tearing it off.
///
/// [builder] is only invoked once the chunk has finished downloading, so it is
/// the one place where the deferred prefix may be dereferenced.
class DeferredModule extends StatefulWidget {
  const DeferredModule({
    super.key,
    required this.load,
    required this.builder,
    required this.moduleName,
  });

  /// `() => prefix.loadLibrary()`.
  final Future<void> Function() load;

  /// Builds the real widget. Runs only after [load] completes.
  final WidgetBuilder builder;

  /// Human readable module name, used in the failure message.
  final String moduleName;

  @override
  State<DeferredModule> createState() => _DeferredModuleState();
}

class _DeferredModuleState extends State<DeferredModule> {
  // `late` so the future is created on first build rather than during the
  // State constructor, and `final` so a parent rebuild never restarts the
  // download or discards the already-loaded module.
  late final Future<void> _loadFuture = widget.load();

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
                      Text(
                        'Failed to load ${widget.moduleName}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
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
        return widget.builder(context);
      },
    );
  }
}
