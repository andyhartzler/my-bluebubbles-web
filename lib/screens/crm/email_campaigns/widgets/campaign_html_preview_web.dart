import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Builds an HTML view using an iframe for web platform.
/// This provides pixel-perfect rendering of HTML email content.
Widget buildHtmlView(String htmlContent) {
  return _WebHtmlView(htmlContent: htmlContent);
}

class _WebHtmlView extends StatefulWidget {
  final String htmlContent;

  const _WebHtmlView({required this.htmlContent});

  @override
  State<_WebHtmlView> createState() => _WebHtmlViewState();
}

class _WebHtmlViewState extends State<_WebHtmlView> {
  late String _viewId;
  html.IFrameElement? _iframe;

  @override
  void initState() {
    super.initState();
    _viewId = 'html-preview-${DateTime.now().millisecondsSinceEpoch}';
    _registerView();
  }

  @override
  void didUpdateWidget(_WebHtmlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.htmlContent != widget.htmlContent) {
      _updateIframeContent();
    }
  }

  void _registerView() {
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      _iframe = html.IFrameElement()
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'white'
        ..setAttribute('sandbox', 'allow-same-origin')
        ..srcdoc = widget.htmlContent;
      return _iframe!;
    });
  }

  void _updateIframeContent() {
    if (_iframe != null) {
      _iframe!.srcdoc = widget.htmlContent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewId);
  }
}
