import 'package:flutter/material.dart';

/// Mobile/Desktop stub for MauticIframe - the main screen uses WebViewController directly
///
/// This class is only used as a fallback. The actual WebView implementation
/// is in mautic_embed_screen.dart which uses WebViewController for mobile/desktop.
class MauticIframe extends StatelessWidget {
  final String loginUrl;
  final VoidCallback? onRefresh;
  final Function(String path)? onNavigate;

  const MauticIframe({
    super.key,
    required this.loginUrl,
    this.onRefresh,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    // This should never be called on mobile/desktop
    // The main screen uses WebViewController directly
    return const Center(
      child: Text('Use WebView on mobile/desktop platforms'),
    );
  }
}
