import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Wraps [SelectionArea] but skips it on mobile web (iOS/Android PWA)
/// to prevent the gesture detector from competing with tap handlers.
/// On desktop web and native platforms, [SelectionArea] works as normal.
class MobileAwareSelectionArea extends StatelessWidget {
  final Widget child;
  final FocusNode? focusNode;

  const MobileAwareSelectionArea({
    super.key,
    required this.child,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb && MediaQuery.of(context).size.shortestSide < 600) {
      return child;
    }
    return SelectionArea(
      focusNode: focusNode,
      child: child,
    );
  }
}
