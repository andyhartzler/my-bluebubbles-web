import 'package:flutter/material.dart';

/// Mobile/Desktop stub for Iframe - uses WebView instead
class Iframe extends StatelessWidget {
  final String src;

  const Iframe({super.key, required this.src});

  @override
  Widget build(BuildContext context) {
    // This should never be called on mobile/desktop
    // The main screen uses WebViewController directly
    return const Center(
      child: Text('Use WebView on mobile/desktop platforms'),
    );
  }
}
