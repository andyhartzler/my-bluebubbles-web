import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Conditional imports for web
import 'campaign_html_preview_stub.dart'
    if (dart.library.html) 'campaign_html_preview_web.dart' as platform;

class CampaignHtmlPreview extends StatefulWidget {
  final String? htmlContent;
  final String? textContent;

  const CampaignHtmlPreview({
    super.key,
    this.htmlContent,
    this.textContent,
  });

  @override
  State<CampaignHtmlPreview> createState() => _CampaignHtmlPreviewState();
}

class _CampaignHtmlPreviewState extends State<CampaignHtmlPreview> {
  bool _showTextVersion = false;

  String _wrapHtml(String content) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { box-sizing: border-box; }
    body {
      margin: 0;
      padding: 16px;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      font-size: 14px;
      line-height: 1.5;
      color: #333;
      background-color: #fff;
    }
    img { max-width: 100%; height: auto; }
    table { max-width: 100%; border-collapse: collapse; }
    a { color: #0066cc; }
    pre, code { overflow-x: auto; max-width: 100%; }
  </style>
</head>
<body>
$content
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasHtml = widget.htmlContent != null && widget.htmlContent!.isNotEmpty;
    final hasText = widget.textContent != null && widget.textContent!.isNotEmpty;

    // Empty state
    if (!hasHtml && !hasText) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.email_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No email content available',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The email content was not stored for this campaign.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Toggle between HTML and Text if both are available
        if (hasHtml && hasText)
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('HTML Preview'),
                  icon: Icon(Icons.code),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Plain Text'),
                  icon: Icon(Icons.text_fields),
                ),
              ],
              selected: {_showTextVersion},
              onSelectionChanged: (selected) {
                setState(() => _showTextVersion = selected.first);
              },
            ),
          ),

        // Content area
        Expanded(
          child: _showTextVersion || !hasHtml
              ? _buildTextContent(theme)
              : _buildHtmlContent(theme),
        ),
      ],
    );
  }

  Widget _buildHtmlContent(ThemeData theme) {
    final wrappedHtml = _wrapHtml(widget.htmlContent!);

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: platform.buildHtmlView(wrappedHtml),
    );
  }

  Widget _buildTextContent(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            widget.textContent ?? 'No plain text content available',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}
