import 'package:flutter/material.dart';

class EmailReplyData {
  const EmailReplyData({
    this.subject,
    required this.body,
    this.cc = const [],
    this.bcc = const [],
    this.sendAsHtml = true,
  });

  final String? subject;
  final String body;
  final List<String> cc;
  final List<String> bcc;
  final bool sendAsHtml;
}

class EmailReplyDialog extends StatefulWidget {
  const EmailReplyDialog({
    super.key,
    required this.threadSubject,
    this.initialSubject,
    this.initialBody,
    this.initialCc,
    this.initialBcc,
    this.allowHtmlToggle = true,
  });

  final String threadSubject;
  final String? initialSubject;
  final String? initialBody;
  final List<String>? initialCc;
  final List<String>? initialBcc;
  final bool allowHtmlToggle;

  @override
  State<EmailReplyDialog> createState() => _EmailReplyDialogState();
}

class _EmailReplyDialogState extends State<EmailReplyDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _subjectController;
  late TextEditingController _bodyController;
  late TextEditingController _ccController;
  late TextEditingController _bccController;
  bool _sendAsHtml = true;

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController(
      text: widget.initialSubject ?? 'Re: ${widget.threadSubject}'.trim(),
    );
    _bodyController = TextEditingController(text: widget.initialBody ?? '');
    _ccController = TextEditingController(
      text: widget.initialCc?.join(', ') ?? '',
    );
    _bccController = TextEditingController(
      text: widget.initialBcc?.join(', ') ?? '',
    );
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    _ccController.dispose();
    _bccController.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    Navigator.of(context).pop(
      EmailReplyData(
        subject: _subjectController.text.trim().isEmpty
            ? null
            : _subjectController.text.trim(),
        body: _bodyController.text.trim(),
        cc: _parseEmails(_ccController.text),
        bcc: _parseEmails(_bccController.text),
        sendAsHtml: _sendAsHtml,
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
    final colorScheme = theme.colorScheme;

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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bodyController,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Message body is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                if (widget.allowHtmlToggle)
                  SwitchListTile.adaptive(
                    value: _sendAsHtml,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Send as HTML'),
                    subtitle: const Text(
                      'When enabled, the message will be sent using HTML formatting.',
                    ),
                    onChanged: (value) =>
                        setState(() => _sendAsHtml = value),
                    activeColor: colorScheme.primary,
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
