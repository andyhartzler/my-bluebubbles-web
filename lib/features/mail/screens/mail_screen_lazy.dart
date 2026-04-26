import 'package:flutter/material.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

import 'mail_screen.dart' deferred as ms;

/// Lazy wrapper around [MailScreen]. Uses Dart's deferred-loading
/// (`import ... deferred as`) so dart2js emits the entire tmail-flutter
/// fork (~2,500 .dart files) as a separate JS chunk that only downloads
/// when this widget mounts.
///
/// `_HomeState` only inserts this into the IndexedStack once
/// `_mailEnabled` is true (i.e. the alias check confirms the user has a
/// provisioned `mail_aliases` row). Non-execs never mount it, never
/// download the chunk.
class MailScreenLazy extends StatefulWidget {
  const MailScreenLazy({super.key});

  @override
  State<MailScreenLazy> createState() => _MailScreenLazyState();
}

class _MailScreenLazyState extends State<MailScreenLazy> {
  late final Future<void> _loadFuture = ms.loadLibrary();

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
                        'Failed to load mail module',
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
        return ms.MailScreen();
      },
    );
  }
}
