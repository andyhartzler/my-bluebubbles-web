import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

/// Builds an HTML view using flutter_html for non-web platforms.
/// This is used as a fallback when running on mobile/desktop.
Widget buildHtmlView(String htmlContent) {
  return SingleChildScrollView(
    child: Html(
      data: htmlContent,
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
        'img': Style(
          display: Display.block,
        ),
        'table': Style(
          display: Display.block,
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
    ),
  );
}
