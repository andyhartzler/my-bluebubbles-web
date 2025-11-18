import 'dart:convert';

/// Utility helpers for converting Flutter Quill documents/deltas into HTML.
class QuillHtmlConverter {
  static final HtmlEscape _textEscape = const HtmlEscape();
  static final HtmlEscape _attributeEscape =
      const HtmlEscape(HtmlEscapeMode.attribute);

  /// Generates HTML from a delta JSON representation while respecting inline
  /// styling information. Falls back to an empty string if the document has no
  /// visible content.
  static String generateHtml(
    List<Map<String, dynamic>> deltaJson,
    String plainText,
  ) {
    if (plainText.trim().isEmpty && !_deltaContainsEmbeds(deltaJson)) {
      return '';
    }
    return _deltaToHtml(deltaJson);
  }

  /// Whether the provided delta contains embed blocks (images, etc.).
  static bool _deltaContainsEmbeds(List<Map<String, dynamic>> deltaJson) {
    for (final operation in deltaJson) {
      if (operation['insert'] is Map<String, dynamic>) {
        return true;
      }
    }
    return false;
  }

  static String _deltaToHtml(List<Map<String, dynamic>> deltaJson) {
    final buffer = StringBuffer();
    final currentLine = <String>[];

    void flushLine(Map<String, dynamic>? blockAttributes) {
      final content = currentLine.join();
      final hasVisibleContent =
          currentLine.any((segment) => segment.trim().isNotEmpty);
      final blockTag = _blockTagForAttributes(blockAttributes);
      final inner = hasVisibleContent ? content : '<br>';
      if (blockTag != null) {
        buffer.write('<$blockTag>$inner</$blockTag>');
      } else {
        buffer.write('<p>$inner</p>');
      }
      currentLine.clear();
    }

    for (final operation in deltaJson) {
      final insert = operation['insert'];
      final rawAttributes =
          (operation['attributes'] as Map?)?.cast<String, dynamic>();

      if (insert is String) {
        var remaining = insert;
        while (true) {
          final newlineIndex = remaining.indexOf('\n');
          if (newlineIndex == -1) {
            if (remaining.isNotEmpty) {
              currentLine.add(
                _applyInlineStyles(
                  remaining,
                  _extractInlineAttributes(rawAttributes),
                ),
              );
            }
            break;
          }

          final segment = remaining.substring(0, newlineIndex);
          currentLine.add(
            _applyInlineStyles(
              segment,
              _extractInlineAttributes(rawAttributes),
            ),
          );
          flushLine(_extractBlockAttributes(rawAttributes));
          remaining = remaining.substring(newlineIndex + 1);
          if (remaining.isEmpty) {
            break;
          }
        }
      } else if (insert is Map<String, dynamic>) {
        final embedHtml = _convertEmbedToHtml(insert, rawAttributes);
        if (embedHtml != null) {
          currentLine.add(embedHtml);
        }
      }
    }

    if (currentLine.isNotEmpty) {
      flushLine(null);
    }

    return buffer.toString();
  }

  static Map<String, dynamic>? _extractInlineAttributes(
    Map<String, dynamic>? attributes,
  ) {
    if (attributes == null || attributes.isEmpty) {
      return null;
    }

    const inlineKeys = {
      'bold',
      'italic',
      'underline',
      'strike',
      'link',
      'size',
    };

    final result = <String, dynamic>{};
    for (final entry in attributes.entries) {
      if (inlineKeys.contains(entry.key)) {
        result[entry.key] = entry.value;
      }
    }

    return result.isEmpty ? null : result;
  }

  static Map<String, dynamic>? _extractBlockAttributes(
    Map<String, dynamic>? attributes,
  ) {
    if (attributes == null || attributes.isEmpty) {
      return null;
    }

    const blockKeys = {'header'};
    final result = <String, dynamic>{};

    for (final entry in attributes.entries) {
      if (blockKeys.contains(entry.key)) {
        result[entry.key] = entry.value;
      }
    }

    return result.isEmpty ? null : result;
  }

  static String? _blockTagForAttributes(Map<String, dynamic>? attributes) {
    if (attributes == null) {
      return null;
    }

    final header = attributes['header'];
    if (header is int && header >= 1 && header <= 6) {
      return 'h$header';
    }

    return null;
  }

  static String _applyInlineStyles(
    String text,
    Map<String, dynamic>? attributes,
  ) {
    if (text.isEmpty) {
      return '';
    }

    var styledText = _textEscape.convert(text);
    if (attributes == null || attributes.isEmpty) {
      return styledText;
    }

    final isBold = attributes['bold'] == true;
    final isItalic = attributes['italic'] == true;
    final isUnderline = attributes['underline'] == true;
    final link = attributes['link'];
    final fontSize = _fontSizeCssValue(attributes['size']);

    if (isBold) {
      styledText = '<strong>$styledText</strong>';
    }
    if (isItalic) {
      styledText = '<em>$styledText</em>';
    }
    if (isUnderline) {
      styledText = '<u>$styledText</u>';
    }
    if (fontSize != null) {
      styledText = '<span style="font-size: $fontSize;">$styledText</span>';
    }

    if (link is String && link.isNotEmpty) {
      final safeLink = _attributeEscape.convert(link);
      styledText = '<a href="$safeLink">$styledText</a>';
    }

    return styledText;
  }

  static String? _fontSizeCssValue(dynamic size) {
    if (size is String) {
      switch (size) {
        case 'small':
          return '0.75em';
        case 'large':
          return '1.5em';
        case 'huge':
          return '2em';
        default:
          final trimmed = size.trim();
          if (trimmed.isEmpty) {
            return null;
          }
          final suffixes = ['px', 'em', 'rem', '%'];
          for (final suffix in suffixes) {
            if (trimmed.endsWith(suffix)) {
              final numeric =
                  trimmed.substring(0, trimmed.length - suffix.length);
              if (numeric.isEmpty) {
                return null;
              }
              final value = double.tryParse(numeric);
              if (value != null) {
                return trimmed;
              }
            }
          }
      }
    } else if (size is num) {
      return '${size}px';
    }
    return null;
  }

  static String? _convertEmbedToHtml(
    Map<String, dynamic> embed,
    Map<String, dynamic>? _attributes,
  ) {
    final imageSource = embed['image'];
    if (imageSource is String && imageSource.isNotEmpty) {
      final safeSource = _attributeEscape.convert(imageSource);
      return '<img src="$safeSource" />';
    }
    return null;
  }
}
