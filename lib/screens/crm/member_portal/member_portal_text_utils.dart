import 'package:collection/collection.dart';

/// Normalizes HTML or plain text coming from Supabase rich text fields so it
/// renders cleanly in member portal surfaces.
///
/// - Converts line breaks and block-level tags (div/p/li/br) into newlines
/// - Converts leading dashes and ordered list prefixes into Markdown bullets
/// - Falls back to plain text when no recognizable formatting exists
String normalizeMemberPortalText(String? input) {
  final raw = input?.trim();
  if (raw == null || raw.isEmpty) return '';

  var normalized = raw
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</div>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<div[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '- ')
      .replaceAll(RegExp(r'&nbsp;', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\r'), '');

  // Strip any remaining HTML tags.
  normalized = normalized.replaceAll(RegExp(r'<[^>]+>'), '');

  final lines = normalized
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) {
        final orderedMatch = RegExp(r'^\d+\.\s*(.*)').firstMatch(line);
        if (orderedMatch != null) {
          return '- ${orderedMatch.group(1)!.trim()}';
        }

        final dashMatch = RegExp(r'^[\-–—]\s*(.*)').firstMatch(line);
        if (dashMatch != null) {
          return '- ${dashMatch.group(1)!.trim()}';
        }

        // Normalize inline em/en dashes so Markdown renders consistently.
        if (RegExp(r'[–—]').hasMatch(line)) {
          return line.replaceAll(RegExp(r'[–—]'), '-');
        }

        return line;
      })
      .toList();

  return lines.join('\n');
}

String? firstNonEmptyNormalized(Iterable<String?> values) {
  return values
      .map(normalizeMemberPortalText)
      .firstWhereOrNull((value) => value.isNotEmpty);
}
