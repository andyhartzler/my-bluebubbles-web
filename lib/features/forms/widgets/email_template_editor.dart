import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../../utils/markdown_quill_loader.dart';
import '../../../utils/quill_html_converter.dart';

/// Mail merge variable definition for job notification templates
class MailMergeVariable {
  final String token;
  final String label;
  final String? description;
  final String? category;

  const MailMergeVariable({
    required this.token,
    required this.label,
    this.description,
    this.category,
  });
}

/// A rich text email template editor with WYSIWYG editing and mail merge support
class EmailTemplateEditor extends StatefulWidget {
  /// Initial HTML content to load into the editor
  final String? initialHtml;

  /// Callback when the HTML content changes
  final ValueChanged<String>? onHtmlChanged;

  /// Callback when the plain text content changes
  final ValueChanged<String>? onPlainTextChanged;

  /// Available mail merge variables for insertion
  final List<MailMergeVariable> mergeVariables;

  /// Minimum height of the editor
  final double minHeight;

  /// Whether the editor is read-only
  final bool readOnly;

  /// Placeholder text when editor is empty
  final String? placeholder;

  /// Label for the editor
  final String? label;

  /// Helper text below the editor
  final String? helperText;

  const EmailTemplateEditor({
    super.key,
    this.initialHtml,
    this.onHtmlChanged,
    this.onPlainTextChanged,
    this.mergeVariables = const [],
    this.minHeight = 300,
    this.readOnly = false,
    this.placeholder,
    this.label,
    this.helperText,
  });

  @override
  State<EmailTemplateEditor> createState() => _EmailTemplateEditorState();
}

class _EmailTemplateEditorState extends State<EmailTemplateEditor> {
  late quill.QuillController _controller;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _showVariables = false;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    if (widget.initialHtml != null && widget.initialHtml!.isNotEmpty) {
      try {
        final document = MarkdownQuillLoader.fromHtml(widget.initialHtml!);
        _controller = quill.QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (_) {
        _controller = quill.QuillController.basic();
      }
    } else {
      _controller = quill.QuillController.basic();
    }
    _controller.addListener(_onContentChanged);
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
    final document = _controller.document;
    final html = QuillHtmlConverter.convertToHtml(document);
    final plainText = document.toPlainText();

    widget.onHtmlChanged?.call(html);
    widget.onPlainTextChanged?.call(plainText);
  }

  void _insertVariable(MailMergeVariable variable) {
    final index = _controller.selection.baseOffset;
    _controller.document.insert(index, variable.token);
    _controller.updateSelection(
      TextSelection.collapsed(offset: index + variable.token.length),
      quill.ChangeSource.local,
    );
    setState(() => _showVariables = false);
  }

  List<String> get _categories {
    final cats = widget.mergeVariables
        .where((v) => v.category != null)
        .map((v) => v.category!)
        .toSet()
        .toList();
    cats.sort();
    return cats;
  }

  List<MailMergeVariable> get _filteredVariables {
    if (_selectedCategory == null) {
      return widget.mergeVariables;
    }
    return widget.mergeVariables
        .where((v) => v.category == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Toolbar
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              // Main formatting toolbar
              _buildToolbar(theme),

              // Mail merge button
              if (widget.mergeVariables.isNotEmpty)
                _buildMergeToolbar(theme),
            ],
          ),
        ),

        // Editor
        Container(
          constraints: BoxConstraints(minHeight: widget.minHeight),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
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
                padding: const EdgeInsets.all(16),
                placeholder: widget.placeholder ?? 'Compose your email...',
                readOnlyMouseCursor: SystemMouseCursors.text,
                readOnly: widget.readOnly,
              ),
            ),
          ),
        ),

        // Variables panel
        if (_showVariables && widget.mergeVariables.isNotEmpty)
          _buildVariablesPanel(theme),

        if (widget.helperText != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.helperText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildToolbar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: quill.QuillToolbar.simple(
          controller: _controller,
          configurations: quill.QuillSimpleToolbarConfigurations(
            showAlignmentButtons: true,
            showBackgroundColorButton: false,
            showCenterAlignment: true,
            showClearFormat: true,
            showCodeBlock: false,
            showColorButton: true,
            showDirection: false,
            showDividers: true,
            showFontFamily: false,
            showFontSize: true,
            showHeaderStyle: true,
            showIndent: false,
            showInlineCode: false,
            showJustifyAlignment: true,
            showLeftAlignment: true,
            showLink: true,
            showListBullets: true,
            showListCheck: false,
            showListNumbers: true,
            showQuote: false,
            showRedo: true,
            showRightAlignment: true,
            showSearchButton: false,
            showSmallButton: false,
            showStrikeThrough: true,
            showSubscript: false,
            showSuperscript: false,
            showUnderLineButton: true,
            showUndo: true,
            multiRowsDisplay: false,
            fontSizesValues: const {
              'Small': '12',
              'Normal': '16',
              'Large': '20',
              'Huge': '28',
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMergeToolbar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.data_object,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Mail Merge:',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showVariables = !_showVariables;
                if (!_showVariables) _selectedCategory = null;
              });
            },
            icon: Icon(
              _showVariables ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
            label: Text(_showVariables ? 'Hide Variables' : 'Insert Variable'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const Spacer(),
          // Quick insert for common variables
          ...widget.mergeVariables.take(3).map((v) => Padding(
            padding: const EdgeInsets.only(left: 4),
            child: ActionChip(
              avatar: const Icon(Icons.add, size: 14),
              label: Text(v.label),
              onPressed: () => _insertVariable(v),
              visualDensity: VisualDensity.compact,
              labelStyle: const TextStyle(fontSize: 11),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildVariablesPanel(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Click a variable to insert it at the cursor position. Variables will be replaced with actual values when the email is sent.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Category filter
          if (_categories.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedCategory == null,
                  onSelected: (selected) {
                    setState(() => _selectedCategory = null);
                  },
                  visualDensity: VisualDensity.compact,
                ),
                ..._categories.map((cat) => FilterChip(
                  label: Text(cat),
                  selected: _selectedCategory == cat,
                  onSelected: (selected) {
                    setState(() => _selectedCategory = selected ? cat : null);
                  },
                  visualDensity: VisualDensity.compact,
                )),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Variables grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _filteredVariables.map((variable) {
              return Tooltip(
                message: variable.description ?? 'Insert ${variable.label}',
                child: ActionChip(
                  avatar: const Icon(Icons.data_object, size: 16),
                  label: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        variable.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        variable.token,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  onPressed: () => _insertVariable(variable),
                  backgroundColor: theme.colorScheme.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Get current HTML content
  String getHtml() {
    return QuillHtmlConverter.convertToHtml(_controller.document);
  }

  /// Get current plain text content
  String getPlainText() {
    return _controller.document.toPlainText();
  }

  /// Set HTML content
  void setHtml(String html) {
    try {
      final document = MarkdownQuillLoader.fromHtml(html);
      _controller.document = document;
      _controller.updateSelection(
        const TextSelection.collapsed(offset: 0),
        quill.ChangeSource.local,
      );
    } catch (_) {
      // Ignore parse errors
    }
  }

  /// Clear the editor content
  void clear() {
    _controller.clear();
  }
}

/// Default job notification template variables
class JobNotificationVariables {
  static const List<MailMergeVariable> all = [
    // Job variables
    MailMergeVariable(
      token: '{{job_title}}',
      label: 'Job Title',
      description: 'The title of the job posting',
      category: 'Job',
    ),
    MailMergeVariable(
      token: '{{job_organization}}',
      label: 'Organization',
      description: 'The organization posting the job',
      category: 'Job',
    ),
    MailMergeVariable(
      token: '{{job_type}}',
      label: 'Job Type',
      description: 'Full-time, Part-time, Internship, etc.',
      category: 'Job',
    ),
    MailMergeVariable(
      token: '{{job_location}}',
      label: 'Location',
      description: 'The job location',
      category: 'Job',
    ),
    MailMergeVariable(
      token: '{{job_url}}',
      label: 'Job URL',
      description: 'Link to the job posting',
      category: 'Job',
    ),

    // Submitter variables
    MailMergeVariable(
      token: '{{submitter_name}}',
      label: 'Submitter Name',
      description: 'Name of the person who submitted the job',
      category: 'Submitter',
    ),
    MailMergeVariable(
      token: '{{submitter_email}}',
      label: 'Submitter Email',
      description: 'Email of the job submitter',
      category: 'Submitter',
    ),

    // Applicant variables
    MailMergeVariable(
      token: '{{applicant_name}}',
      label: 'Applicant Name',
      description: 'Name of the applicant',
      category: 'Applicant',
    ),
    MailMergeVariable(
      token: '{{applicant_email}}',
      label: 'Applicant Email',
      description: 'Email of the applicant',
      category: 'Applicant',
    ),
    MailMergeVariable(
      token: '{{applicant_phone}}',
      label: 'Applicant Phone',
      description: 'Phone number of the applicant',
      category: 'Applicant',
    ),
    MailMergeVariable(
      token: '{{applicant_city}}',
      label: 'Applicant City',
      description: 'City of the applicant',
      category: 'Applicant',
    ),

    // Status variables
    MailMergeVariable(
      token: '{{status}}',
      label: 'Current Status',
      description: 'Current application status',
      category: 'Status',
    ),
    MailMergeVariable(
      token: '{{old_status}}',
      label: 'Previous Status',
      description: 'Previous application status (for status change notifications)',
      category: 'Status',
    ),
    MailMergeVariable(
      token: '{{rejection_reason}}',
      label: 'Rejection Reason',
      description: 'Reason for job rejection',
      category: 'Status',
    ),
  ];

  /// Get variables for a specific trigger type
  static List<MailMergeVariable> forTrigger(String triggerType) {
    switch (triggerType) {
      case 'job_submitted':
      case 'job_approved':
      case 'job_expiring_soon':
      case 'job_expired':
        return all.where((v) =>
          v.category == 'Job' || v.category == 'Submitter'
        ).toList();
      case 'job_rejected':
        return all.where((v) =>
          v.category == 'Job' ||
          v.category == 'Submitter' ||
          v.token == '{{rejection_reason}}'
        ).toList();
      case 'application_received':
        return all.where((v) =>
          v.category == 'Job' ||
          v.category == 'Submitter' ||
          v.category == 'Applicant'
        ).toList();
      case 'application_submitted':
        return all.where((v) =>
          v.category == 'Job' || v.category == 'Applicant'
        ).toList();
      case 'application_status_changed':
        return all.where((v) =>
          v.category == 'Job' ||
          v.category == 'Applicant' ||
          v.category == 'Status'
        ).toList();
      default:
        return all;
    }
  }
}
