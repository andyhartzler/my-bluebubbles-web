import 'package:flutter/material.dart';

/// Stub iframe widget - should not be used
class Iframe extends StatelessWidget {
  final String src;

  const Iframe({super.key, required this.src});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Iframe not supported on this platform'),
    );
  }
}
