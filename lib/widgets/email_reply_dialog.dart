import 'package:bluebubbles/utils/quill_html_converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class EmailReplyData {
  const EmailReplyData({
    required this.to,
    this.subject,
    required this.htmlBody,
    required this.plainTextBody,
    this.cc = const [],
    this.bcc = const [],
  });

  final List<String> to;
  final String? subject;
  final String htmlBody;
  final String plainTextBody;
  final List<String> cc;
  final List<String> bcc;

  @Deprecated('Use htmlBody instead')
  String get body => htmlBody;
}

class EmailReplyDialog extends StatefulWidget {
  const EmailReplyDialog({
    super.key,
    required this.threadSubject,
    this.initialTo,
    this.initialSubject,
    this.initialBody,
    this.initialCc,
    this.initialBcc,
  });

  final String threadSubject;
  final List<String>? initialTo;
  final String? initialSubject;
  final String? initialBody;
  final List<String>? initialCc;
  final List<String>? initialBcc;

  @override
  State<EmailReplyDialog> createState() => _EmailReplyDialogState();
}

class _EmailReplyDialogState extends State<EmailReplyDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _toController;
  late TextEditingController _subjectController;
  late TextEditingController _ccController;
  late TextEditingController _bccController;
  late final quill.QuillController _editorController;
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _editorScrollController = ScrollController();

  String _htmlBody = '';
  String _plainTextBody = '';

  @override
  void initState() {
    super.initState();
    _toController = TextEditingController(
      text: widget.initialTo?.join(', ') ?? '',
    );
    _subjectController = TextEditingController(
      text: widget.initialSubject ?? 'Re: ${widget.threadSubject}'.trim(),
    );
    _ccController = TextEditingController(
      text: widget.initialCc?.join(', ') ?? '',
    );
    _bccController = TextEditingController(
      text: widget.initialBcc?.join(', ') ?? '',
    );

    final initialBody = widget.initialBody ?? '';
    final document = quill.Document();
    if (initialBody.isNotEmpty) {
      document.insert(0, initialBody);
    }
    _editorController = quill.QuillController(
      document: document,
      selection: TextSelection.collapsed(offset: document.length),
    );
    _editorController.addListener(_handleBodyChanged);
    _captureEditorState(triggerSetState: false);
  }

  @override
  void dispose() {
    _toController.dispose();
    _subjectController.dispose();
    _ccController.dispose();
    _bccController.dispose();
    _editorController.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  void _handleBodyChanged() {
    _captureEditorState();
  }

  void _captureEditorState({bool triggerSetState = true}) {
    final document = _editorController.document;
    final deltaJson = document
        .toDelta()
        .toJson()
        .map<Map<String, dynamic>>((dynamic op) => Map<String, dynamic>.from(op as Map))
        .toList(growable: false);
    final plainText = document.toPlainText().trimRight();
    final html = QuillHtmlConverter.generateHtml(deltaJson, plainText);

    void updateValues() {
      _plainTextBody = plainText;
      _htmlBody = html;
    }

    if (triggerSetState) {
      setState(updateValues);
    } else {
      updateValues();
    }
  }

  void _toggleInlineFormat(quill.Attribute attribute) {
    final selection = _editorController.selection;
    if (!selection.isValid) return;
    final currentStyle = _editorController.getSelectionStyle();
    final isActive = currentStyle.attributes.containsKey(attribute.key);
    final target = isActive ? quill.Attribute.clone(attribute, null) : attribute;
    _editorController.formatSelection(target);
  }

  Future<void> _promptForLink() async {
    final selection = _editorController.selection;
    if (!selection.isValid || selection.isCollapsed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select text before adding a hyperlink.')),
      );
      return;
    }

    final currentStyle = _editorController.getSelectionStyle();
    final existingLink =
        currentStyle.attributes[quill.Attribute.link.key]?.value?.toString() ?? '';
    final controller = TextEditingController(text: existingLink);

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Insert hyperlink'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'https://example.com',
            ),
            autofocus: true,
            keyboardType: TextInputType.url,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            if (existingLink.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.of(context).pop(''),
                child: const Text('Remove link'),
              ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null) {
      return;
    }

    if (result.isEmpty) {
      final removal = quill.Attribute.clone(quill.Attribute.link, null);
      _editorController.formatSelection(removal);
    } else {
      _editorController.formatSelection(quill.LinkAttribute(result));
    }
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (_plainTextBody.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message body is required.')),
      );
      return;
    }

    Navigator.of(context).pop(
      EmailReplyData(
        to: _parseEmails(_toController.text),
        subject: _subjectController.text.trim().isEmpty
            ? null
            : _subjectController.text.trim(),
        htmlBody: _htmlBody,
        plainTextBody: _plainTextBody,
        cc: _parseEmails(_ccController.text),
        bcc: _parseEmails(_bccController.text),
      ),
    );
  }

  List<String> _parseEmails(String value) {
    final parts = value
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toSet()
        .toList(growable: false);
    return parts;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.maybeLocaleOf(context) ?? const Locale('en');
    final sharedConfigurations = quill.QuillSharedConfigurations(locale: locale);
    final selectionStyle = _editorController.getSelectionStyle();
    final attributes = selectionStyle.attributes;
    final boldActive = attributes.containsKey(quill.Attribute.bold.key);
    final italicActive = attributes.containsKey(quill.Attribute.italic.key);
    final underlineActive = attributes.containsKey(quill.Attribute.underline.key);
    final linkActive = attributes.containsKey(quill.Attribute.link.key);

    return AlertDialog(
      title: Text('Reply to ${widget.threadSubject.isEmpty ? 'conversation' : widget.threadSubject}'),
      content: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _toController,
                  decoration: const InputDecoration(
                    labelText: 'To',
                    hintText: 'Separate multiple emails with commas',
                  ),
                  validator: (value) {
                    final emails = _parseEmails(value ?? '');
                    if (emails.isEmpty) {
                      return 'At least one recipient is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Subject is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ccController,
                  decoration: const InputDecoration(
                    labelText: 'CC',
                    hintText: 'Separate multiple emails with commas',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bccController,
                  decoration: const InputDecoration(
                    labelText: 'BCC',
                    hintText: 'Separate multiple emails with commas',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Message',
                  style: theme.inputDecorationTheme.labelStyle ?? theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                _RichTextToolbar(
                  boldActive: boldActive,
                  italicActive: italicActive,
                  underlineActive: underlineActive,
                  linkActive: linkActive,
                  onBoldPressed: () => _toggleInlineFormat(quill.Attribute.bold),
                  onItalicPressed: () => _toggleInlineFormat(quill.Attribute.italic),
                  onUnderlinePressed: () => _toggleInlineFormat(quill.Attribute.underline),
                  onLinkPressed: _promptForLink,
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(minHeight: 200),
                  child: quill.QuillEditor(
                    key: const ValueKey('email_reply_editor'),
                    focusNode: _editorFocusNode,
                    scrollController: _editorScrollController,
                    configurations: quill.QuillEditorConfigurations(
                      controller: _editorController,
                      sharedConfigurations: sharedConfigurations,
                      scrollable: true,
                      expands: false,
                      padding: const EdgeInsets.all(12),
                      placeholder: 'Type your message…',
                      minHeight: 180,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.send_outlined),
          label: const Text('Send reply'),
        ),
      ],
    );
  }
}

class _RichTextToolbar extends StatelessWidget {
  const _RichTextToolbar({
    required this.boldActive,
    required this.italicActive,
    required this.underlineActive,
    required this.linkActive,
    required this.onBoldPressed,
    required this.onItalicPressed,
    required this.onUnderlinePressed,
    required this.onLinkPressed,
  });

  final bool boldActive;
  final bool italicActive;
  final bool underlineActive;
  final bool linkActive;
  final VoidCallback onBoldPressed;
  final VoidCallback onItalicPressed;
  final VoidCallback onUnderlinePressed;
  final VoidCallback onLinkPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _FormatChip(
            icon: Icons.format_bold,
            label: 'Bold',
            selected: boldActive,
            onPressed: onBoldPressed,
          ),
          _FormatChip(
            icon: Icons.format_italic,
            label: 'Italic',
            selected: italicActive,
            onPressed: onItalicPressed,
          ),
          _FormatChip(
            icon: Icons.format_underline,
            label: 'Underline',
            selected: underlineActive,
            onPressed: onUnderlinePressed,
          ),
          _FormatChip(
            icon: Icons.link,
            label: 'Hyperlink',
            selected: linkActive,
            onPressed: onLinkPressed,
          ),
        ],
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      avatar: Icon(icon, size: 18),
      selected: selected,
      onSelected: (_) => onPressed(),
    );
  }
}
