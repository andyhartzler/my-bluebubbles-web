import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// A sandboxed iframe rendering a social platform's embed surface (TikTok
/// creator embed / Instagram profile embed) so the committee can see a
/// candidate's recent posts without leaving the CRM.
///
/// View factories are registered once per URL and reused across rebuilds
/// (registering twice with one id throws on web).
class SocialFeedEmbed extends StatefulWidget {
  final String url;
  final double height;

  const SocialFeedEmbed({super.key, required this.url, this.height = 620});

  @override
  State<SocialFeedEmbed> createState() => _SocialFeedEmbedState();
}

class _SocialFeedEmbedState extends State<SocialFeedEmbed> {
  static final Set<String> _registered = {};

  String get _viewType => 'social-embed-${widget.url.hashCode}';

  @override
  void initState() {
    super.initState();
    _register();
  }

  void _register() {
    if (_registered.contains(_viewType)) return;
    _registered.add(_viewType);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final iframe = html.IFrameElement()
        ..src = widget.url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'encrypted-media; picture-in-picture; web-share'
        ..setAttribute('loading', 'lazy');
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
