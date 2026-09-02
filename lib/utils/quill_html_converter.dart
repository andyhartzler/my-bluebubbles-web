import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// Line level container a delta line belongs to. Consecutive lines sharing a
/// container are emitted inside ONE element, so three bulleted lines produce a
/// single <ul> rather than three one-item lists.
enum _BlockKind { plain, header, orderedList, bulletList, quote, code }

/// One flushed line: its already-escaped inline HTML plus the block formatting
/// the delta carried on the newline that terminated it.
class _HtmlLine {
  const _HtmlLine({
    required this.content,
    required this.kind,
    required this.tag,
    required this.extraStyle,
  });

  final String content;
  final _BlockKind kind;

  /// Header level tag (h1..h6) when [kind] is [_BlockKind.header].
  final String? tag;

  /// Alignment and indent, appended after the shared line style.
  final String extraStyle;
}

/// Utility helpers for converting Flutter Quill documents/deltas into HTML.
class QuillHtmlConverter {
  static final HtmlEscape _textEscape = const HtmlEscape();
  static final HtmlEscape _attributeEscape =
      const HtmlEscape(HtmlEscapeMode.attribute);

  /// Gmail ignores inline margin styles on <p> tags which caused every newline
  /// to render as a double-spaced paragraph. Using <div> keeps the visual
  /// intent (single spaced lines) while still supporting inline formatting
  /// from the editor.
  static const String _lineStyle = 'margin: 0; line-height: 1.6;';

  /// Every container carries its styling inline. Email clients strip <style>
  /// blocks, so a class based list or quote would arrive unformatted.
  static const String _listStyle = 'margin: 0; padding-left: 24px;';
  static const String _quoteStyle = 'margin: 0 0 0 8px; padding-left: 12px; '
      'border-left: 3px solid #cccccc; color: #555555;';
  static const String _codeStyle = 'margin: 0; padding: 8px 12px; '
      'background-color: #f4f4f4; font-family: monospace; '
      'white-space: pre-wrap;';

  /// Schemes a link or image may use. Anything else, `javascript:` and `data:`
  /// included, never reaches an href or src.
  static const Set<String> _allowedUrlSchemes = {
    'http',
    'https',
    'mailto',
    'tel',
  };

  static const Set<String> _alignments = {'left', 'center', 'right', 'justify'};

  /// Converts a Quill document to HTML.
  /// This is a convenience wrapper around [generateHtml].
  static String convertToHtml(quill.Document document) {
    final plainText = document.toPlainText();
    return generateHtml(_deltaJsonFor(document), plainText);
  }

  /// Renders a Quill document to plain text with link targets preserved, for
  /// the text/plain alternative of an email. `document.toPlainText()` drops the
  /// href entirely, so a member reading the plain part sees anchor text
  /// pointing at nothing. This is a convenience wrapper around
  /// [generatePlainText].
  static String convertToPlainText(quill.Document document) {
    return generatePlainText(_deltaJsonFor(document));
  }

  static List<Map<String, dynamic>> _deltaJsonFor(quill.Document document) {
    return document
        .toDelta()
        .toJson()
        .whereType<Map<String, dynamic>>()
        .toList()
        .cast<Map<String, dynamic>>();
  }

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

  /// Renders a delta to plain text, writing each link as
  /// `anchor text (https://url)` so the text/plain alternative keeps its
  /// targets. An anchor whose text already is its own URL is written once
  /// rather than twice.
  ///
  /// Links are held to the same scheme allowlist as the HTML side: a
  /// `javascript:` href is dropped and only its visible text survives, so the
  /// two alternatives cannot disagree about what a message is pointing at.
  /// Embeds are skipped, since an image has no plain text form.
  static String generatePlainText(List<Map<String, dynamic>> deltaJson) {
    final buffer = StringBuffer();
    final linkText = StringBuffer();
    String? activeLink;

    void closeLink() {
      final link = activeLink;
      if (link == null) {
        return;
      }
      final text = linkText.toString();
      buffer.write(text);
      if (text.trim() != link) {
        buffer.write(' ($link)');
      }
      linkText.clear();
      activeLink = null;
    }

    void write(String text, String? link) {
      if (link != activeLink) {
        closeLink();
        activeLink = link;
      }
      if (link == null) {
        buffer.write(text);
      } else {
        linkText.write(text);
      }
    }

    for (final operation in deltaJson) {
      final insert = operation['insert'];
      if (insert is! String) {
        continue;
      }

      final rawAttributes =
          (operation['attributes'] as Map?)?.cast<String, dynamic>();
      final rawLink = rawAttributes?['link'];
      final link = rawLink is String ? _safeUrl(rawLink) : null;

      final segments = insert.split('\n');
      for (var index = 0; index < segments.length; index++) {
        if (index > 0) {
          // A link never spans a line break, and closing it before the newline
          // keeps its "(url)" beside the text it belongs to.
          closeLink();
          buffer.write('\n');
        }
        if (segments[index].isNotEmpty) {
          write(segments[index], link);
        }
      }
    }

    closeLink();
    return buffer.toString();
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
    final lines = <_HtmlLine>[];
    final currentLine = <String>[];

    void flushLine(Map<String, dynamic>? blockAttributes) {
      final kind = _blockKindFor(blockAttributes);
      final hasVisibleContent =
          currentLine.any((segment) => segment.trim().isNotEmpty);
      // An empty line needs a <br> to survive, except inside a <pre>, where the
      // newline between siblings already carries it.
      final placeholder = kind == _BlockKind.code ? '' : '<br>';
      lines.add(
        _HtmlLine(
          content: hasVisibleContent ? currentLine.join() : placeholder,
          kind: kind,
          tag: _headerTagFor(blockAttributes),
          extraStyle: _blockExtraStyle(blockAttributes),
        ),
      );
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

    return _renderLines(lines);
  }

  /// Walks the flushed lines, wrapping each run of same-kind lines in a single
  /// container. Lists in particular have to group: one <ul> per line would show
  /// a fresh bullet list for every item and restart <ol> numbering at 1.
  static String _renderLines(List<_HtmlLine> lines) {
    final buffer = StringBuffer();
    var index = 0;

    while (index < lines.length) {
      final kind = lines[index].kind;

      if (kind == _BlockKind.orderedList || kind == _BlockKind.bulletList) {
        final tag = kind == _BlockKind.orderedList ? 'ol' : 'ul';
        buffer.write('<$tag${_style(_listStyle)}>');
        while (index < lines.length && lines[index].kind == kind) {
          final line = lines[index];
          buffer.write(
            '<li${_style('$_lineStyle${line.extraStyle}')}>'
            '${line.content}</li>',
          );
          index++;
        }
        buffer.write('</$tag>');
        continue;
      }

      if (kind == _BlockKind.quote) {
        buffer.write('<blockquote${_style(_quoteStyle)}>');
        while (index < lines.length && lines[index].kind == kind) {
          final line = lines[index];
          buffer.write(
            '<div${_style('$_lineStyle${line.extraStyle}')}>'
            '${line.content}</div>',
          );
          index++;
        }
        buffer.write('</blockquote>');
        continue;
      }

      if (kind == _BlockKind.code) {
        final codeLines = <String>[];
        while (index < lines.length && lines[index].kind == kind) {
          codeLines.add(lines[index].content);
          index++;
        }
        buffer.write(
          '<pre${_style(_codeStyle)}>${codeLines.join('\n')}</pre>',
        );
        continue;
      }

      final line = lines[index];
      final tag = line.tag ?? 'div';
      buffer.write(
        '<$tag${_style('$_lineStyle${line.extraStyle}')}>'
        '${line.content}</$tag>',
      );
      index++;
    }

    return buffer.toString();
  }

  static String _style(String css) => ' style="$css"';

  static _BlockKind _blockKindFor(Map<String, dynamic>? attributes) {
    if (attributes == null) {
      return _BlockKind.plain;
    }

    final list = attributes['list'];
    if (list == 'ordered') {
      return _BlockKind.orderedList;
    }
    if (list == 'bullet') {
      return _BlockKind.bulletList;
    }
    if (attributes['code-block'] == true) {
      return _BlockKind.code;
    }
    if (attributes['blockquote'] == true) {
      return _BlockKind.quote;
    }
    if (_headerTagFor(attributes) != null) {
      return _BlockKind.header;
    }
    return _BlockKind.plain;
  }

  static String? _headerTagFor(Map<String, dynamic>? attributes) {
    final header = attributes?['header'];
    if (header is int && header >= 1 && header <= 6) {
      return 'h$header';
    }
    return null;
  }

  /// Alignment and indent, as inline declarations appended to the line style.
  static String _blockExtraStyle(Map<String, dynamic>? attributes) {
    if (attributes == null) {
      return '';
    }

    final buffer = StringBuffer();
    final align = attributes['align'];
    if (align is String && _alignments.contains(align)) {
      buffer.write(' text-align: $align;');
    }

    final indent = attributes['indent'];
    if (indent is int && indent > 0) {
      // Quill nests lists through indent levels rather than nested <ul>s, so
      // the indent is rendered as a margin on the item itself.
      buffer.write(' margin-left: ${indent * 24}px;');
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

    const blockKeys = {
      'header',
      'list',
      'blockquote',
      'code-block',
      'align',
      'indent',
    };
    final result = <String, dynamic>{};

    for (final entry in attributes.entries) {
      if (blockKeys.contains(entry.key)) {
        result[entry.key] = entry.value;
      }
    }

    return result.isEmpty ? null : result;
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
    final isStrike = attributes['strike'] == true;
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
    if (isStrike) {
      styledText = '<s>$styledText</s>';
    }
    if (fontSize != null) {
      styledText = '<span style="font-size: $fontSize;">$styledText</span>';
    }

    if (link is String) {
      final safeLink = _safeUrl(link);
      if (safeLink != null) {
        styledText =
            '<a href="${_attributeEscape.convert(safeLink)}">$styledText</a>';
      }
      // A rejected scheme drops the anchor and keeps the visible text: the
      // composer's link dialog does no validation of its own, so this is the
      // only place a `javascript:` href is stopped before it reaches a member's
      // inbox.
    }

    return styledText;
  }

  /// Returns the URL if it carries an allowed scheme, otherwise null.
  ///
  /// Attribute escaping already blocks a quote breakout, but it does nothing
  /// about the scheme, so `javascript:` and `data:` would otherwise survive
  /// intact.
  static String? _safeUrl(String rawUrl) {
    // Browsers strip control characters and whitespace before resolving a URL,
    // so `java&#9;script:alert(1)` reaches the parser as `javascript:`.
    // Stripping them first is what keeps the allowlist from being walked past.
    final cleaned = rawUrl.replaceAll(_urlStripped, '');
    if (cleaned.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(cleaned);
    if (uri == null) {
      return null;
    }

    // A scheme-relative or relative URL has no scheme and resolves against
    // nothing useful in an email client, so it is rejected with the rest.
    return _allowedUrlSchemes.contains(uri.scheme.toLowerCase())
        ? cleaned
        : null;
  }

  static final RegExp _urlStripped = RegExp(r'[\x00-\x20\x7F]');

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
    if (imageSource is String) {
      final safeSource = _safeUrl(imageSource);
      // An embed has no visible text to fall back to, so a rejected scheme
      // drops the image rather than emitting a src the client would fetch.
      if (safeSource != null) {
        return '<img src="${_attributeEscape.convert(safeSource)}" />';
      }
    }
    return null;
  }
}
