// Stub for twake_previewer_flutter (Dart 3.7+ requirement, not on our 3.5.4
// baseline). tmail uses TwakePreviewer + TwakePreviewerController for
// inline file preview (HTML/PDF/image). Phase 1 doesn't need this — we
// expose a no-op shim so imports resolve. Re-add the real package when
// the Flutter SDK upgrades to 3.7+.
import 'package:flutter/widgets.dart';

class TwakePreviewer extends StatelessWidget {
  final TwakePreviewerController? controller;
  final String? url;
  final String? mimeType;
  final Map<String, String>? headers;
  const TwakePreviewer({super.key, this.controller, this.url, this.mimeType, this.headers});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class TwakePreviewerController {
  TwakePreviewerController();
  void dispose() {}
  void reload() {}
}
