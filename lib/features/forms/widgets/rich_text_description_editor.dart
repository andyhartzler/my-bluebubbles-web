import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../../utils/markdown_quill_loader.dart';
import '../../../utils/quill_html_converter.dart';

/// A simple rich text editor for form descriptions.
///
/// Automatically detects if the content is HTML and renders it as formatted text.
/// When saving, converts the rich text back to HTML if the original was HTML.
class RichTextDescriptionEditor extends StatefulWidget {
  /// The initial content (can be plain text or HTML)
  final String? initialContent;

  /// Callback when content changes - returns HTML if original was HTML, else plain text
  final ValueChanged<String>? onChanged;

  /// Placeholder text when editor is empty
  final String? placeholder;

  /// Label for the editor field
  final String? label;

  /// Minimum height for the editor
  final double minHeight;

  /// Maximum number of lines (for sizing)
  final int maxLines;

  const RichTextDescriptionEditor({
    super.key,
    this.initialContent,
    this.onChanged,
    this.placeholder,
    this.label,
    this.minHeight = 100,
    this.maxLines = 5,
  });

  @override
  State<RichTextDescriptionEditor> createState() => _RichTextDescriptionEditorState();
}

class _RichTextDescriptionEditorState extends State<RichTextDescriptionEditor> {
  late quill.QuillController _controller;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  /// Track whether the original content was HTML
  bool _originalWasHtml = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    final content = widget.initialContent ?? '';

    if (content.isNotEmpty && _looksLikeHtml(content)) {
      // Content is HTML - parse it into Quill document
      _originalWasHtml = true;
      try {
        final document = MarkdownQuillLoader.fromHtml(content);
        _controller = quill.QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (_) {
        // Fallback to basic controller with plain text
        _controller = quill.QuillController.basic();
        if (content.isNotEmpty) {
          _controller.document.insert(0, content);
        }
      }
    } else {
      // Plain text content
      _originalWasHtml = false;
      _controller = quill.QuillController.basic();
      if (content.isNotEmpty) {
        _controller.document.insert(0, content);
      }
    }

    _controller.addListener(_onContentChanged);
  }

  /// Detect if content looks like HTML
  bool _looksLikeHtml(String content) {
    final trimmed = content.trim();
    // Check for common HTML patterns
    return trimmed.startsWith('<') &&
           (trimmed.contains('</') || trimmed.contains('/>')) &&
           (trimmed.contains('<div') ||
            trimmed.contains('<p') ||
            trimmed.contains('<span') ||
            trimmed.contains('<strong') ||
            trimmed.contains('<em') ||
            trimmed.contains('<a ') ||
            trimmed.contains('<br') ||
            trimmed.contains('<h1') ||
            trimmed.contains('<h2') ||
            trimmed.contains('<h3'));
  }

  @override
  void dispose() {
    _controller.removeListener(_onContentChanged);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    if (widget.onChanged != null) {
      final output = _getOutputContent();
      widget.onChanged!(output);
    }
  }

  /// Get the content in the appropriate format (HTML if original was HTML, else plain text)
  String _getOutputContent() {
    if (_originalWasHtml) {
      return QuillHtmlConverter.convertToHtml(_controller.document);
    } else {
      // For plain text, check if user added any formatting
      final document = _controller.document;
      final hasFormatting = _documentHasFormatting(document);

      if (hasFormatting) {
        // User added formatting, convert to HTML
        _originalWasHtml = true;
        return QuillHtmlConverter.convertToHtml(document);
      } else {
        // No formatting, return plain text
        return document.toPlainText().trim();
      }
    }
  }

  /// Check if document has any formatting (bold, italic, underline, links)
  bool _documentHasFormatting(quill.Document document) {
    final delta = document.toDelta();
    for (final op in delta.toList()) {
      final attributes = op.attributes;
      if (attributes != null && attributes.isNotEmpty) {
        // Check for formatting attributes
        if (attributes.containsKey('bold') ||
            attributes.containsKey('italic') ||
            attributes.containsKey('underline') ||
            attributes.containsKey('link')) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
        ],

        // Editor container
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _focusNode.hasFocus
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              width: _focusNode.hasFocus ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              // Compact toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
                child: Row(
                  children: [
                    _buildToolbarButton(
                      icon: Icons.format_bold,
                      tooltip: 'Bold',
                      isActive: _controller.getSelectionStyle().containsKey('bold'),
                      onPressed: () => _toggleFormat('bold'),
                    ),
                    _buildToolbarButton(
                      icon: Icons.format_italic,
                      tooltip: 'Italic',
                      isActive: _controller.getSelectionStyle().containsKey('italic'),
                      onPressed: () => _toggleFormat('italic'),
                    ),
                    _buildToolbarButton(
                      icon: Icons.format_underlined,
                      tooltip: 'Underline',
                      isActive: _controller.getSelectionStyle().containsKey('underline'),
                      onPressed: () => _toggleFormat('underline'),
                    ),
                    const SizedBox(width: 8),
                    _buildToolbarButton(
                      icon: Icons.link,
                      tooltip: 'Add Link',
                      isActive: _controller.getSelectionStyle().containsKey('link'),
                      onPressed: () => _showLinkDialog(theme),
                    ),
                    const Spacer(),
                    // Clear formatting
                    _buildToolbarButton(
                      icon: Icons.format_clear,
                      tooltip: 'Clear Formatting',
                      onPressed: _clearFormatting,
                    ),
                  ],
                ),
              ),

              // Divider
              Container(
                height: 1,
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),

              // Editor
              Container(
                constraints: BoxConstraints(
                  minHeight: widget.minHeight,
                  maxHeight: widget.minHeight * 2,
                ),
                child: quill.QuillEditor(
                  focusNode: _focusNode,
                  scrollController: _scrollController,
                  configurations: quill.QuillEditorConfigurations(
                    controller: _controller,
                    sharedConfigurations: const quill.QuillSharedConfigurations(
                      locale: Locale('en', 'US'),
                    ),
                    scrollable: true,
                    autoFocus: false,
                    expands: false,
                    padding: const EdgeInsets.all(12),
                    placeholder: widget.placeholder ?? 'Enter description...',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  void _toggleFormat(String format) {
    final style = _controller.getSelectionStyle();
    final isActive = style.containsKey(format);

    if (isActive) {
      _controller.formatSelection(quill.Attribute.clone(
        quill.Attribute.fromKeyValue(format, true)!,
        null,
      ));
    } else {
      _controller.formatSelection(quill.Attribute.fromKeyValue(format, true)!);
    }
    setState(() {});
  }

  void _clearFormatting() {
    final selection = _controller.selection;
    if (selection.isCollapsed) return;

    _controller.formatSelection(quill.Attribute.clone(quill.Attribute.bold, null));
    _controller.formatSelection(quill.Attribute.clone(quill.Attribute.italic, null));
    _controller.formatSelection(quill.Attribute.clone(quill.Attribute.underline, null));
    _controller.formatSelection(quill.Attribute.clone(quill.Attribute.link, null));
    setState(() {});
  }

  void _showLinkDialog(ThemeData theme) {
    final urlController = TextEditingController();
    final currentLink = _controller.getSelectionStyle().attributes['link']?.value;
    if (currentLink is String) {
      urlController.text = currentLink;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.link),
            SizedBox(width: 8),
            Text('Add Link'),
          ],
        ),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            labelText: 'URL',
            hintText: 'https://example.com',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.link),
          ),
          autofocus: true,
          onSubmitted: (value) {
            Navigator.pop(context);
            _applyLink(value);
          },
        ),
        actions: [
          if (currentLink != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _removeLink();
              },
              child: const Text('Remove Link'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _applyLink(urlController.text);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _applyLink(String url) {
    if (url.isEmpty) return;

    // Ensure URL has protocol
    var finalUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      finalUrl = 'https://$url';
    }

    _controller.formatSelection(quill.Attribute.fromKeyValue('link', finalUrl)!);
    setState(() {});
  }

  void _removeLink() {
    _controller.formatSelection(quill.Attribute.clone(quill.Attribute.link, null));
    setState(() {});
  }

  /// Get current content as HTML
  String getHtml() {
    return QuillHtmlConverter.convertToHtml(_controller.document);
  }

  /// Get current content as plain text
  String getPlainText() {
    return _controller.document.toPlainText().trim();
  }

  /// Get the appropriate output based on original format
  String getContent() {
    return _getOutputContent();
  }
}
