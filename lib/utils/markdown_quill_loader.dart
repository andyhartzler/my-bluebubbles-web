import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:dart_quill_delta/dart_quill_delta.dart' as delta;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:markdown/markdown.dart' as md;

class MarkdownQuillLoader {
  static quill.Document fromMarkdown(String markdown) {
    final trimmed = markdown.trim();
    if (trimmed.isEmpty) {
      return quill.Document();
    }

    final html = md.markdownToHtml(
      trimmed,
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );
    return fromHtml(html);
  }

  static quill.Document fromHtml(String html) {
    final fragment = html_parser.parseFragment(html);
    final builder = _HtmlDeltaBuilder();
    builder.buildFromNodes(fragment.nodes);
    final generated = builder.toDelta();
    if (generated.isEmpty) {
      final fallback = delta.Delta()..insert('\n');
      return quill.Document.fromDelta(fallback);
    }
    return quill.Document.fromDelta(generated);
  }
}

class _HtmlDeltaBuilder {
  final delta.Delta _delta = delta.Delta();
  bool _endsWithNewline = false;

  void buildFromNodes(List<dom.Node> nodes, {Map<String, dynamic>? inlineStyle}) {
    for (final node in nodes) {
      if (node is dom.Text) {
        _insertText(node.text, inlineStyle);
      } else if (node is dom.Element) {
        _handleElement(node, inlineStyle);
      }
    }
  }

  delta.Delta toDelta() {
    if (!_endsWithNewline) {
      _insertBlockBreak();
    }
    return _delta;
  }

  void _handleElement(dom.Element element, Map<String, dynamic>? inlineStyle) {
    final name = element.localName?.toLowerCase();
    switch (name) {
      case 'p':
      case 'div':
        buildFromNodes(element.nodes, inlineStyle: inlineStyle);
        _insertBlockBreak();
        break;
      case 'br':
        _insertLineBreak();
        break;
      case 'strong':
      case 'b':
        buildFromNodes(
          element.nodes,
          inlineStyle: _mergeInlineStyle(inlineStyle, {'bold': true}),
        );
        break;
      case 'em':
      case 'i':
        buildFromNodes(
          element.nodes,
          inlineStyle: _mergeInlineStyle(inlineStyle, {'italic': true}),
        );
        break;
      case 'u':
        buildFromNodes(
          element.nodes,
          inlineStyle: _mergeInlineStyle(inlineStyle, {'underline': true}),
        );
        break;
      case 'a':
        final href = element.attributes['href'] ?? '';
        final merged = href.isNotEmpty
            ? _mergeInlineStyle(inlineStyle, {'link': href})
            : inlineStyle;
        buildFromNodes(element.nodes, inlineStyle: merged);
        break;
      case 'span':
        buildFromNodes(element.nodes, inlineStyle: inlineStyle);
        break;
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        buildFromNodes(element.nodes, inlineStyle: inlineStyle);
        final level = int.tryParse(name!.substring(1)) ?? 1;
        _insertBlockBreak({'header': level});
        break;
      case 'ul':
        _convertList(element, 'bullet', inlineStyle);
        break;
      case 'ol':
        _convertList(element, 'ordered', inlineStyle);
        break;
      case 'li':
        final inferredType = element.parent?.localName == 'ol' ? 'ordered' : 'bullet';
        _convertListItem(element, inferredType, inlineStyle);
        break;
      case 'body':
      case 'html':
        buildFromNodes(element.nodes, inlineStyle: inlineStyle);
        break;
      case 'blockquote':
        buildFromNodes(element.nodes, inlineStyle: inlineStyle);
        _insertBlockBreak();
        break;
      case 'hr':
        _insertBlockBreak();
        break;
      default:
        buildFromNodes(element.nodes, inlineStyle: inlineStyle);
    }
  }

  void _convertList(dom.Element list, String type, Map<String, dynamic>? inlineStyle) {
    for (final child in list.children.where((element) => element.localName == 'li')) {
      _convertListItem(child, type, inlineStyle);
    }
  }

  void _convertListItem(
    dom.Element item,
    String type,
    Map<String, dynamic>? inlineStyle,
  ) {
    buildFromNodes(item.nodes, inlineStyle: inlineStyle);
    _insertBlockBreak({'list': type});
  }

  void _insertText(String text, Map<String, dynamic>? inlineStyle) {
    if (text.trim().isEmpty) {
      return;
    }
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return;
    }
    final attributes = inlineStyle == null || inlineStyle.isEmpty
        ? null
        : Map<String, dynamic>.from(inlineStyle);
    _delta.insert(normalized, attributes);
    _endsWithNewline = normalized.endsWith('\n');
  }

  void _insertLineBreak() {
    _delta.insert('\n');
    _endsWithNewline = true;
  }

  void _insertBlockBreak([Map<String, dynamic>? attributes]) {
    _delta.insert('\n', attributes == null || attributes.isEmpty ? null : attributes);
    _endsWithNewline = true;
  }

  Map<String, dynamic>? _mergeInlineStyle(
    Map<String, dynamic>? base,
    Map<String, dynamic> updates,
  ) {
    if ((updates.isEmpty && (base == null || base.isEmpty))) {
      return base;
    }
    final merged = base == null ? <String, dynamic>{} : Map<String, dynamic>.from(base);
    merged.addAll(updates);
    return merged;
  }
}
