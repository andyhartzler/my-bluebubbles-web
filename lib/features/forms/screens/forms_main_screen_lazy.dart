import 'package:flutter/material.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

import 'forms_main_screen.dart' deferred as fs;

/// Lazy wrapper around [FormsMainScreen]. Uses Dart's deferred-loading
/// (`import ... deferred as`) so dart2js emits the Forms module and its
/// heavy dependencies (flutter_quill rich-text editor, fl_chart results
/// analytics) as a separate JS chunk that only downloads when this widget
/// mounts.
///
/// `_HomeState` only inserts this into the IndexedStack once the Forms
/// section is first visited, so users who never open Forms never download
/// the chunk.
class FormsMainScreenLazy extends StatefulWidget {
  const FormsMainScreenLazy({super.key});

  @override
  State<FormsMainScreenLazy> createState() => _FormsMainScreenLazyState();
}

class _FormsMainScreenLazyState extends State<FormsMainScreenLazy> {
  late final Future<void> _loadFuture = fs.loadLibrary();

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
                        'Failed to load forms module',
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
        return fs.FormsMainScreen();
      },
    );
  }
}
