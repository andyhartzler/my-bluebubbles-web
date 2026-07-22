import 'package:flutter/material.dart';

/// Non-web fallback for [SocialFeedEmbed]: the CRM is a web app, but keep
/// native builds compiling. Renders nothing; the panel shows link-out chips
/// alongside every embed anyway.
class SocialFeedEmbed extends StatelessWidget {
  final String url;
  final double height;

  const SocialFeedEmbed({super.key, required this.url, this.height = 620});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
