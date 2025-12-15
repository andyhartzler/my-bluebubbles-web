import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

/// Web-specific email HTML preview using an iframe for accurate rendering.
///
/// This widget renders email HTML in an iframe which provides:
/// - Accurate rendering of inline CSS styles (backgrounds, gradients, shadows)
/// - Proper table layout rendering
/// - Accurate font rendering
/// - Isolated styling (email CSS doesn't affect app)
class EmailHtmlPreview extends StatefulWidget {
  final String html;
  final String? subject;
  final String? recipientEmail;

  const EmailHtmlPreview({
    super.key,
    required this.html,
    this.subject,
    this.recipientEmail,
  });

  @override
  State<EmailHtmlPreview> createState() => _EmailHtmlPreviewState();
}

class _EmailHtmlPreviewState extends State<EmailHtmlPreview> {
  String? _viewId;
  bool _isRegistered = false;
  html.IFrameElement? _iframe;

  @override
  void initState() {
    super.initState();
    _createIframe();
  }

  @override
  void didUpdateWidget(EmailHtmlPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _updateIframeContent();
    }
  }

  @override
  void dispose() {
    _iframe = null;
    super.dispose();
  }

  String _buildEmailDocument() {
    // Wrap the email HTML in a proper HTML document for rendering
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * {
      box-sizing: border-box;
    }
    html, body {
      margin: 0;
      padding: 0;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      font-size: 14px;
      line-height: 1.5;
      color: #333;
      background-color: #f5f5f5;
    }
    body {
      padding: 20px;
    }
    /* Ensure tables render correctly for email layouts */
    table {
      border-collapse: collapse;
    }
    /* Ensure images are responsive */
    img {
      max-width: 100%;
      height: auto;
    }
    /* Style links to look clickable */
    a {
      color: #1976d2;
    }
  </style>
</head>
<body>
${widget.html}
</body>
</html>
''';
  }

  void _createIframe() {
    final viewId = 'email-preview-${DateTime.now().millisecondsSinceEpoch}-${widget.hashCode}';

    final iframe = html.IFrameElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#f5f5f5'
      ..setAttribute('sandbox', 'allow-same-origin') // Security: restrict iframe capabilities
      ..srcdoc = _buildEmailDocument();

    _iframe = iframe;

    // Register the view factory
    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int id) => iframe,
    );

    setState(() {
      _viewId = viewId;
      _isRegistered = true;
    });
  }

  void _updateIframeContent() {
    if (_iframe != null) {
      _iframe!.srcdoc = _buildEmailDocument();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.html.isEmpty) {
      return Center(
        child: Text(
          'Email body will appear here...',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade500,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    if (!_isRegistered || _viewId == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return HtmlElementView(viewType: _viewId!);
  }
}
