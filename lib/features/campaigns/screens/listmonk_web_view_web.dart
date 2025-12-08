import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;

/// Web-specific iframe widget for Listmonk
/// Users can login manually within the iframe as needed.
class Iframe extends StatefulWidget {
  final String src;

  const Iframe({super.key, required this.src});

  @override
  State<Iframe> createState() => _IframeState();
}

class _IframeState extends State<Iframe> {
  final String _iframeId = 'listmonk-iframe-${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    // Load iframe immediately without auto-authentication
    // Users can login manually if needed
    _registerIframe();
  }


  void _registerIframe() {
    try {
      // Register the view factory
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(
        _iframeId,
        (int viewId) {
          final iframe = html.IFrameElement()
            ..src = widget.src
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            // Allow credentials (cookies) to be sent with requests
            ..setAttribute('credentialless', 'false')
            ..setAttribute('allow', 'same-origin');

          print('📺 Iframe registered with src: ${widget.src}');

          return iframe;
        },
      );
    } catch (e) {
      print('❌ Error registering iframe: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Simply display the iframe - users can login manually if needed
    return HtmlElementView(viewType: _iframeId);
  }
}
