import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

class CampaignHtmlPreview extends StatelessWidget {
  final String? htmlContent;
  final String? textContent;

  const CampaignHtmlPreview({
    super.key,
    this.htmlContent,
    this.textContent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if ((htmlContent == null || htmlContent!.isEmpty) &&
        (textContent == null || textContent!.isEmpty)) {
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
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (htmlContent != null && htmlContent!.isNotEmpty) ...[
            _buildPreviewHeader(theme, 'HTML Email Preview'),
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 700),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Html(
                  data: htmlContent!,
                  style: {
                    'body': Style(
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                      fontSize: FontSize(14),
                      color: Colors.black87,
                      backgroundColor: Colors.white,
                    ),
                    'p': Style(
                      margin: Margins.only(bottom: 12),
                    ),
                    'a': Style(
                      color: Colors.blue[700],
                      textDecoration: TextDecoration.underline,
                    ),
                    'h1': Style(
                      fontSize: FontSize(24),
                      fontWeight: FontWeight.bold,
                      margin: Margins.only(bottom: 16, top: 8),
                    ),
                    'h2': Style(
                      fontSize: FontSize(20),
                      fontWeight: FontWeight.bold,
                      margin: Margins.only(bottom: 12, top: 8),
                    ),
                    'h3': Style(
                      fontSize: FontSize(18),
                      fontWeight: FontWeight.bold,
                      margin: Margins.only(bottom: 10, top: 8),
                    ),
                    'td': Style(
                      padding: HtmlPaddings.symmetric(horizontal: 8, vertical: 4),
                    ),
                    'ul': Style(
                      margin: Margins.only(left: 16, bottom: 12),
                    ),
                    'ol': Style(
                      margin: Margins.only(left: 16, bottom: 12),
                    ),
                    'li': Style(
                      margin: Margins.only(bottom: 4),
                    ),
                  },
                  onLinkTap: (url, attributes, element) {
                    if (url != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Link: $url'),
                          action: SnackBarAction(
                            label: 'Copy',
                            onPressed: () {
                              // Could add clipboard functionality here
                            },
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          ],
          if (textContent != null && textContent!.isNotEmpty) ...[
            if (htmlContent != null && htmlContent!.isNotEmpty)
              const SizedBox(height: 24),
            _buildPreviewHeader(theme, 'Plain Text Version'),
            const SizedBox(height: 12),
            Card(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  textContent!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewHeader(ThemeData theme, String title) {
    return Row(
      children: [
        Icon(
          title.contains('HTML') ? Icons.code : Icons.text_fields,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
