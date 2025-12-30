import 'package:flutter/material.dart';

/// Stub MauticIframe widget - should not be used
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
    return const Center(
      child: Text('Mautic iframe not supported on this platform'),
    );
  }
}
