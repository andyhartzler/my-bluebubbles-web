import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart' show Html, Style, Margins, HtmlPaddings, FontSize, LineHeight;

/// Stub implementation for non-web platforms using flutter_html.
///
/// This provides a fallback for mobile/desktop platforms that don't
/// support HtmlElementView with iframes.
class EmailHtmlPreview extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (html.isEmpty) {
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Html(
        data: html,
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            fontSize: FontSize(14),
            color: Colors.black87,
            backgroundColor: Colors.transparent,
          ),
          'h1': Style(
            fontSize: FontSize(24),
            fontWeight: FontWeight.bold,
            margin: Margins.only(bottom: 16),
          ),
          'h2': Style(
            fontSize: FontSize(20),
            fontWeight: FontWeight.bold,
            margin: Margins.only(bottom: 14),
          ),
          'h3': Style(
            fontSize: FontSize(18),
            fontWeight: FontWeight.w600,
            margin: Margins.only(bottom: 12),
          ),
          'p': Style(
            margin: Margins.only(bottom: 12),
            lineHeight: const LineHeight(1.6),
          ),
          'a': Style(
            color: theme.colorScheme.primary,
            textDecoration: TextDecoration.underline,
          ),
          'table': Style(
            border: Border.all(color: Colors.grey.shade300),
          ),
          'td': Style(
            padding: HtmlPaddings.all(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          'th': Style(
            padding: HtmlPaddings.all(8),
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.grey.shade100,
          ),
          'div': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
          ),
          'img': Style(
            margin: Margins.symmetric(vertical: 8),
          ),
          'ul': Style(
            margin: Margins.only(bottom: 12),
            padding: HtmlPaddings.only(left: 20),
          ),
          'ol': Style(
            margin: Margins.only(bottom: 12),
            padding: HtmlPaddings.only(left: 20),
          ),
          'li': Style(
            margin: Margins.only(bottom: 4),
          ),
          'hr': Style(
            margin: Margins.symmetric(vertical: 16),
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          'blockquote': Style(
            margin: Margins.symmetric(vertical: 12),
            padding: HtmlPaddings.only(left: 16),
            border: Border(left: BorderSide(color: Colors.grey.shade400, width: 4)),
            backgroundColor: Colors.grey.shade50,
          ),
        },
      ),
    );
  }
}
