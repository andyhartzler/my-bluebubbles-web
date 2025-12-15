import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
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

/// Pre-built email template layouts
class EmailTemplate {
  final String name;
  final String description;
  final String html;
  final IconData icon;

  const EmailTemplate({
    required this.name,
    required this.description,
    required this.html,
    required this.icon,
  });
}

/// A comprehensive rich text email template editor with WYSIWYG editing,
/// advanced design features, and mail merge support
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
  bool _showDesignElements = false;
  bool _showTemplates = false;
  String? _selectedCategory;
  int _selectedToolbarTab = 0; // 0: Format, 1: Insert, 2: Design

  // Pre-built email templates
  static const List<EmailTemplate> _emailTemplates = [
    EmailTemplate(
      name: 'Professional',
      description: 'Clean and formal business style',
      icon: Icons.business,
      html: '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
  <div style="background-color: #1a365d; padding: 24px; text-align: center;">
    <h1 style="color: #ffffff; margin: 0; font-size: 24px;">{{job_organization}}</h1>
  </div>
  <div style="padding: 32px; background-color: #ffffff;">
    <h2 style="color: #1a365d; margin-top: 0;">Hello {{applicant_name}},</h2>
    <p style="color: #4a5568; line-height: 1.6;">Thank you for your interest in the <strong>{{job_title}}</strong> position.</p>
    <p style="color: #4a5568; line-height: 1.6;">We have received your application and will review it carefully. We will be in touch soon regarding the next steps.</p>
    <div style="text-align: center; margin: 32px 0;">
      <a href="{{job_url}}" style="background-color: #1a365d; color: #ffffff; padding: 12px 32px; text-decoration: none; border-radius: 4px; display: inline-block;">View Job Details</a>
    </div>
    <p style="color: #4a5568; line-height: 1.6;">Best regards,<br><strong>{{job_organization}}</strong></p>
  </div>
  <div style="background-color: #f7fafc; padding: 16px; text-align: center; border-top: 1px solid #e2e8f0;">
    <p style="color: #718096; font-size: 12px; margin: 0;">This is an automated message from {{job_organization}}</p>
  </div>
</div>
''',
    ),
    EmailTemplate(
      name: 'Friendly',
      description: 'Warm and welcoming tone',
      icon: Icons.emoji_emotions,
      html: '''
<div style="font-family: 'Segoe UI', sans-serif; max-width: 600px; margin: 0 auto;">
  <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 32px; text-align: center; border-radius: 12px 12px 0 0;">
    <h1 style="color: #ffffff; margin: 0; font-size: 28px;">Great News! 🎉</h1>
  </div>
  <div style="padding: 32px; background-color: #ffffff;">
    <p style="color: #4a5568; font-size: 18px; line-height: 1.6;">Hey {{applicant_name}}!</p>
    <p style="color: #4a5568; line-height: 1.8;">We're excited to let you know that we've received your application for <strong style="color: #667eea;">{{job_title}}</strong>!</p>
    <div style="background-color: #f0f4ff; border-left: 4px solid #667eea; padding: 16px; margin: 24px 0; border-radius: 0 8px 8px 0;">
      <p style="color: #4a5568; margin: 0;"><strong>What happens next?</strong><br>Our team will review your application and get back to you within a few days.</p>
    </div>
    <p style="color: #4a5568; line-height: 1.8;">In the meantime, feel free to check out the full job details:</p>
    <div style="text-align: center; margin: 24px 0;">
      <a href="{{job_url}}" style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: #ffffff; padding: 14px 36px; text-decoration: none; border-radius: 25px; display: inline-block; font-weight: 600;">View Job Posting</a>
    </div>
    <p style="color: #4a5568; line-height: 1.6;">Cheers,<br>The {{job_organization}} Team</p>
  </div>
</div>
''',
    ),
    EmailTemplate(
      name: 'Minimal',
      description: 'Simple and clean design',
      icon: Icons.minimize,
      html: '''
<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 560px; margin: 0 auto; padding: 40px 20px;">
  <p style="color: #111827; font-size: 16px; line-height: 1.7; margin-bottom: 24px;">Dear {{applicant_name}},</p>
  <p style="color: #374151; font-size: 16px; line-height: 1.7; margin-bottom: 24px;">Thank you for applying to <strong>{{job_title}}</strong> at {{job_organization}}.</p>
  <p style="color: #374151; font-size: 16px; line-height: 1.7; margin-bottom: 24px;">We will review your application and contact you soon.</p>
  <p style="color: #374151; font-size: 16px; line-height: 1.7; margin-bottom: 8px;">Best,</p>
  <p style="color: #111827; font-size: 16px; line-height: 1.7; font-weight: 600;">{{job_organization}}</p>
  <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 32px 0;">
  <p style="color: #9ca3af; font-size: 13px;"><a href="{{job_url}}" style="color: #6366f1;">View job details</a></p>
</div>
''',
    ),
    EmailTemplate(
      name: 'Modern Card',
      description: 'Card-based layout with shadow',
      icon: Icons.credit_card,
      html: '''
<div style="font-family: 'Inter', sans-serif; background-color: #f3f4f6; padding: 40px 20px;">
  <div style="max-width: 520px; margin: 0 auto; background: #ffffff; border-radius: 16px; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06); overflow: hidden;">
    <div style="background-color: #0ea5e9; padding: 24px; text-align: center;">
      <h1 style="color: #ffffff; margin: 0; font-size: 22px; font-weight: 600;">Application Received</h1>
    </div>
    <div style="padding: 32px;">
      <div style="background-color: #f0f9ff; border-radius: 12px; padding: 20px; margin-bottom: 24px;">
        <h3 style="color: #0369a1; margin: 0 0 8px 0; font-size: 14px; text-transform: uppercase; letter-spacing: 0.05em;">Position</h3>
        <p style="color: #0c4a6e; margin: 0; font-size: 18px; font-weight: 600;">{{job_title}}</p>
      </div>
      <p style="color: #4b5563; line-height: 1.7; margin-bottom: 20px;">Hi {{applicant_name}},</p>
      <p style="color: #4b5563; line-height: 1.7; margin-bottom: 24px;">Thank you for your interest in joining {{job_organization}}! We've received your application and our team is reviewing it.</p>
      <a href="{{job_url}}" style="display: block; background-color: #0ea5e9; color: #ffffff; text-align: center; padding: 14px 24px; text-decoration: none; border-radius: 8px; font-weight: 600;">View Application Status</a>
    </div>
    <div style="background-color: #f9fafb; padding: 20px; text-align: center;">
      <p style="color: #6b7280; font-size: 13px; margin: 0;">Questions? Reply to this email.</p>
    </div>
  </div>
</div>
''',
    ),
    EmailTemplate(
      name: 'Status Update',
      description: 'For application status changes',
      icon: Icons.update,
      html: '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
  <div style="padding: 32px; background-color: #ffffff;">
    <div style="text-align: center; margin-bottom: 32px;">
      <div style="background-color: #10b981; width: 64px; height: 64px; border-radius: 50%; margin: 0 auto 16px; display: flex; align-items: center; justify-content: center;">
        <span style="color: #ffffff; font-size: 32px;">✓</span>
      </div>
      <h1 style="color: #111827; margin: 0; font-size: 24px;">Status Update</h1>
    </div>
    <p style="color: #4b5563; line-height: 1.7; text-align: center;">Hi {{applicant_name}},</p>
    <p style="color: #4b5563; line-height: 1.7; text-align: center; margin-bottom: 24px;">Your application for <strong>{{job_title}}</strong> has been updated.</p>
    <div style="background-color: #f3f4f6; border-radius: 8px; padding: 24px; margin: 24px 0;">
      <table style="width: 100%;">
        <tr>
          <td style="color: #6b7280; padding: 8px 0;">Previous Status:</td>
          <td style="color: #374151; font-weight: 600; text-align: right; padding: 8px 0;">{{old_status}}</td>
        </tr>
        <tr>
          <td style="color: #6b7280; padding: 8px 0;">New Status:</td>
          <td style="color: #10b981; font-weight: 600; text-align: right; padding: 8px 0;">{{status}}</td>
        </tr>
      </table>
    </div>
    <div style="text-align: center; margin-top: 32px;">
      <a href="{{job_url}}" style="background-color: #111827; color: #ffffff; padding: 12px 32px; text-decoration: none; border-radius: 6px; display: inline-block;">View Details</a>
    </div>
  </div>
  <div style="text-align: center; padding: 24px;">
    <p style="color: #9ca3af; font-size: 13px; margin: 0;">{{job_organization}}</p>
  </div>
</div>
''',
    ),
  ];

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

  void _insertText(String text) {
    final index = _controller.selection.baseOffset;
    _controller.document.insert(index, text);
    _controller.updateSelection(
      TextSelection.collapsed(offset: index + text.length),
      quill.ChangeSource.local,
    );
  }

  void _applyTemplate(EmailTemplate template) {
    try {
      final document = MarkdownQuillLoader.fromHtml(template.html);
      _controller.document = document;
      _controller.updateSelection(
        const TextSelection.collapsed(offset: 0),
        quill.ChangeSource.local,
      );
      _onContentChanged();
      setState(() => _showTemplates = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Applied "${template.name}" template'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to apply template: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

        // Main editor container
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Toolbar tabs
              _buildToolbarTabs(theme),

              // Active toolbar content
              _buildActiveToolbar(theme),

              // Divider
              Container(
                height: 1,
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),

              // Editor area
              Container(
                constraints: BoxConstraints(minHeight: widget.minHeight),
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
                    padding: const EdgeInsets.all(20),
                    placeholder: widget.placeholder ?? 'Start designing your email...',
                  ),
                ),
              ),
            ],
          ),
        ),

        // Expandable panels
        if (_showVariables && widget.mergeVariables.isNotEmpty)
          _buildVariablesPanel(theme),

        if (_showDesignElements)
          _buildDesignElementsPanel(theme),

        if (_showTemplates)
          _buildTemplatesPanel(theme),

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

  Widget _buildToolbarTabs(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          _buildToolbarTab(theme, 0, 'Format', Icons.text_format),
          _buildToolbarTab(theme, 1, 'Insert', Icons.add_box_outlined),
          _buildToolbarTab(theme, 2, 'Design', Icons.palette_outlined),
          const Spacer(),
          // Quick actions
          IconButton(
            icon: const Icon(Icons.undo, size: 20),
            onPressed: () => _controller.undo(),
            tooltip: 'Undo',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.redo, size: 20),
            onPressed: () => _controller.redo(),
            tooltip: 'Redo',
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildToolbarTab(ThemeData theme, int index, String label, IconData icon) {
    final isSelected = _selectedToolbarTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedToolbarTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? theme.colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveToolbar(ThemeData theme) {
    switch (_selectedToolbarTab) {
      case 0:
        return _buildFormattingToolbar(theme);
      case 1:
        return _buildInsertToolbar(theme);
      case 2:
        return _buildDesignToolbar(theme);
      default:
        return _buildFormattingToolbar(theme);
    }
  }

  Widget _buildFormattingToolbar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: quill.QuillToolbar.simple(
          configurations: quill.QuillSimpleToolbarConfigurations(
            controller: _controller,
            showAlignmentButtons: true,
            showBackgroundColorButton: true,
            showCenterAlignment: true,
            showClearFormat: true,
            showCodeBlock: false,
            showColorButton: true,
            showDirection: false,
            showDividers: true,
            showFontFamily: true,
            showFontSize: true,
            showHeaderStyle: true,
            showIndent: true,
            showInlineCode: false,
            showJustifyAlignment: true,
            showLeftAlignment: true,
            showLink: true,
            showListBullets: true,
            showListCheck: true,
            showListNumbers: true,
            showQuote: true,
            showRedo: false,
            showRightAlignment: true,
            showSearchButton: false,
            showSmallButton: true,
            showStrikeThrough: true,
            showSubscript: true,
            showSuperscript: true,
            showUnderLineButton: true,
            showUndo: false,
            multiRowsDisplay: false,
            fontFamilyValues: const {
              'Sans Serif': 'sans-serif',
              'Serif': 'serif',
              'Monospace': 'monospace',
              'Arial': 'Arial',
              'Georgia': 'Georgia',
              'Verdana': 'Verdana',
            },
            fontSizesValues: const {
              'Small': '12',
              'Normal': '16',
              'Medium': '18',
              'Large': '22',
              'X-Large': '28',
              'Huge': '36',
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInsertToolbar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Mail Merge Variables
            _buildToolbarButton(
              theme,
              icon: Icons.data_object,
              label: 'Variable',
              color: theme.colorScheme.primary,
              onPressed: () => setState(() {
                _showVariables = !_showVariables;
                _showDesignElements = false;
                _showTemplates = false;
              }),
              isActive: _showVariables,
            ),
            const SizedBox(width: 8),

            // Image/Logo
            _buildToolbarButton(
              theme,
              icon: Icons.image,
              label: 'Image',
              onPressed: () => _showImageDialog(theme),
            ),
            const SizedBox(width: 8),

            // Link
            _buildToolbarButton(
              theme,
              icon: Icons.link,
              label: 'Link',
              onPressed: () => _showLinkDialog(theme),
            ),
            const SizedBox(width: 8),

            // Button
            _buildToolbarButton(
              theme,
              icon: Icons.smart_button,
              label: 'Button',
              onPressed: () => _showButtonDialog(theme),
            ),
            const SizedBox(width: 8),

            // Divider
            _buildToolbarButton(
              theme,
              icon: Icons.horizontal_rule,
              label: 'Divider',
              onPressed: () => _insertDivider(),
            ),
            const SizedBox(width: 8),

            // Table
            _buildToolbarButton(
              theme,
              icon: Icons.table_chart_outlined,
              label: 'Table',
              onPressed: () => _showTableDialog(theme),
            ),
            const SizedBox(width: 8),

            // Spacer
            _buildToolbarButton(
              theme,
              icon: Icons.space_bar,
              label: 'Spacer',
              onPressed: () => _insertSpacer(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesignToolbar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Templates
            _buildToolbarButton(
              theme,
              icon: Icons.auto_awesome,
              label: 'Templates',
              color: Colors.purple,
              onPressed: () => setState(() {
                _showTemplates = !_showTemplates;
                _showVariables = false;
                _showDesignElements = false;
              }),
              isActive: _showTemplates,
            ),
            const SizedBox(width: 8),

            // Design Elements
            _buildToolbarButton(
              theme,
              icon: Icons.widgets_outlined,
              label: 'Elements',
              onPressed: () => setState(() {
                _showDesignElements = !_showDesignElements;
                _showVariables = false;
                _showTemplates = false;
              }),
              isActive: _showDesignElements,
            ),
            const SizedBox(width: 8),

            // Background color
            _buildToolbarButton(
              theme,
              icon: Icons.format_color_fill,
              label: 'Background',
              onPressed: () => _showBackgroundColorPicker(theme),
            ),
            const SizedBox(width: 8),

            // Section box
            _buildToolbarButton(
              theme,
              icon: Icons.crop_square,
              label: 'Box',
              onPressed: () => _showBoxDialog(theme),
            ),
            const SizedBox(width: 8),

            // Callout
            _buildToolbarButton(
              theme,
              icon: Icons.info_outline,
              label: 'Callout',
              onPressed: () => _showCalloutDialog(theme),
            ),
            const SizedBox(width: 8),

            // Social icons
            _buildToolbarButton(
              theme,
              icon: Icons.share,
              label: 'Social',
              onPressed: () => _showSocialIconsDialog(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarButton(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
    bool isActive = false,
  }) {
    return Material(
      color: isActive
          ? (color ?? theme.colorScheme.primary).withOpacity(0.15)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: color ?? theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color ?? theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVariablesPanel(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
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
                Icons.data_object,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Mail Merge Variables',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _showVariables = false),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Click a variable to insert it. Variables are replaced with real data when sent.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // Category filter
          if (_categories.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _selectedCategory == null,
                    onSelected: (selected) {
                      setState(() => _selectedCategory = null);
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                  ..._categories.map((cat) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilterChip(
                      label: Text(cat),
                      selected: _selectedCategory == cat,
                      onSelected: (selected) {
                        setState(() => _selectedCategory = selected ? cat : null);
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  )),
                ],
              ),
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
                  avatar: Icon(Icons.add, size: 16, color: theme.colorScheme.primary),
                  label: Text(variable.label),
                  onPressed: () => _insertVariable(variable),
                  backgroundColor: theme.colorScheme.surface,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesignElementsPanel(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.secondary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.widgets_outlined,
                size: 20,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Design Elements',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _showDesignElements = false),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Design elements grid
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.2,
            children: [
              _buildElementCard(
                theme,
                icon: Icons.image,
                label: 'Logo',
                onTap: () => _showImageDialog(theme),
              ),
              _buildElementCard(
                theme,
                icon: Icons.smart_button,
                label: 'CTA Button',
                onTap: () => _showButtonDialog(theme),
              ),
              _buildElementCard(
                theme,
                icon: Icons.horizontal_rule,
                label: 'Divider',
                onTap: () => _insertDivider(),
              ),
              _buildElementCard(
                theme,
                icon: Icons.space_bar,
                label: 'Spacer',
                onTap: () => _insertSpacer(),
              ),
              _buildElementCard(
                theme,
                icon: Icons.crop_square,
                label: 'Box',
                onTap: () => _showBoxDialog(theme),
              ),
              _buildElementCard(
                theme,
                icon: Icons.format_quote,
                label: 'Quote',
                onTap: () => _insertQuote(),
              ),
              _buildElementCard(
                theme,
                icon: Icons.info_outline,
                label: 'Callout',
                onTap: () => _showCalloutDialog(theme),
              ),
              _buildElementCard(
                theme,
                icon: Icons.share,
                label: 'Social',
                onTap: () => _showSocialIconsDialog(theme),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildElementCard(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: theme.colorScheme.primary),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplatesPanel(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.purple.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 20,
                color: Colors.purple,
              ),
              const SizedBox(width: 8),
              Text(
                'Email Templates',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _showTemplates = false),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a pre-designed template to start with. Your content will be replaced.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // Templates grid
          GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.8,
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _emailTemplates.length,
            itemBuilder: (context, index) {
              final template = _emailTemplates[index];
              return _buildTemplateCard(theme, template);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(ThemeData theme, EmailTemplate template) {
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _confirmApplyTemplate(template),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      template.icon,
                      size: 20,
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          template.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmApplyTemplate(EmailTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Apply "${template.name}" Template?'),
        content: const Text(
          'This will replace your current email content with the template. '
          'You can then customize it with your own text and merge variables.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _applyTemplate(template);
            },
            child: const Text('Apply Template'),
          ),
        ],
      ),
    );
  }

  // Insert methods
  void _insertDivider() {
    _insertText('\n───────────────────────────────\n');
  }

  void _insertSpacer() {
    _insertText('\n\n\n');
  }

  void _insertQuote() {
    _insertText('\n❝ Your quote here... ❞\n');
  }

  // Dialog methods
  void _showImageDialog(ThemeData theme) {
    final urlController = TextEditingController();
    final altController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.image),
            SizedBox(width: 8),
            Text('Insert Image'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Image URL',
                hintText: 'https://example.com/logo.png',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: altController,
              decoration: const InputDecoration(
                labelText: 'Alt Text (optional)',
                hintText: 'Company Logo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              if (urlController.text.isNotEmpty) {
                final alt = altController.text.isEmpty ? 'Image' : altController.text;
                _insertText('\n[Image: $alt](${urlController.text})\n');
              }
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    );
  }

  void _showLinkDialog(ThemeData theme) {
    final urlController = TextEditingController();
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.link),
            SizedBox(width: 8),
            Text('Insert Link'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'Link Text',
                hintText: 'Click here',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.text_fields),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              if (urlController.text.isNotEmpty) {
                final text = textController.text.isEmpty ? urlController.text : textController.text;
                _insertText('[$text](${urlController.text})');
              }
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    );
  }

  void _showButtonDialog(ThemeData theme) {
    final textController = TextEditingController(text: 'Click Here');
    final urlController = TextEditingController();
    Color buttonColor = theme.colorScheme.primary;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.smart_button),
              SizedBox(width: 8),
              Text('Insert Button'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  labelText: 'Button Text',
                  hintText: 'View Details',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.text_fields),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'Button URL',
                  hintText: '{{job_url}}',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                  helperText: 'Use {{job_url}} for dynamic links',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Button Color: '),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Pick a color'),
                          content: SingleChildScrollView(
                            child: BlockPicker(
                              pickerColor: buttonColor,
                              onColorChanged: (color) {
                                setState(() => buttonColor = color);
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: buttonColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Preview
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
                decoration: BoxDecoration(
                  color: buttonColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  textController.text.isEmpty ? 'Click Here' : textController.text,
                  style: TextStyle(
                    color: buttonColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                final text = textController.text.isEmpty ? 'Click Here' : textController.text;
                final url = urlController.text.isEmpty ? '#' : urlController.text;
                final hex = '#${buttonColor.value.toRadixString(16).substring(2)}';
                _insertText('\n[🔘 $text]($url) <!-- Button: $hex -->\n');
              },
              child: const Text('Insert'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTableDialog(ThemeData theme) {
    int rows = 2;
    int cols = 2;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.table_chart_outlined),
              SizedBox(width: 8),
              Text('Insert Table'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('Rows: '),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: rows,
                    items: List.generate(6, (i) => i + 1)
                        .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                        .toList(),
                    onChanged: (v) => setState(() => rows = v!),
                  ),
                  const SizedBox(width: 24),
                  const Text('Columns: '),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: cols,
                    items: List.generate(4, (i) => i + 1)
                        .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                        .toList(),
                    onChanged: (v) => setState(() => cols = v!),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                final header = '| ' + List.generate(cols, (i) => 'Header ${i + 1}').join(' | ') + ' |';
                final divider = '| ' + List.generate(cols, (i) => '---').join(' | ') + ' |';
                final rowsText = List.generate(rows, (r) {
                  return '| ' + List.generate(cols, (c) => 'Cell ${r + 1}.${c + 1}').join(' | ') + ' |';
                }).join('\n');
                _insertText('\n$header\n$divider\n$rowsText\n');
              },
              child: const Text('Insert'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBackgroundColorPicker(ThemeData theme) {
    Color selectedColor = Colors.white;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Section Background Color'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: selectedColor,
            onColorChanged: (color) {
              selectedColor = color;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              final hex = '#${selectedColor.value.toRadixString(16).substring(2)}';
              _insertText('\n<!-- Section Background: $hex -->\nYour content here...\n<!-- End Section -->\n');
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showBoxDialog(ThemeData theme) {
    Color borderColor = theme.colorScheme.primary;
    Color bgColor = theme.colorScheme.primaryContainer.withOpacity(0.3);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.crop_square),
            SizedBox(width: 8),
            Text('Insert Colored Box'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('A colored box can highlight important information.'),
            const SizedBox(height: 16),
            // Preview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor, width: 2),
              ),
              child: const Text('Your highlighted content will appear here...'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _insertText('\n┌─────────────────────────────┐\n│ Your content here...        │\n└─────────────────────────────┘\n');
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    );
  }

  void _showCalloutDialog(ThemeData theme) {
    String calloutType = 'info';
    final contentController = TextEditingController();

    final types = {
      'info': {'icon': 'ℹ️', 'label': 'Info'},
      'success': {'icon': '✅', 'label': 'Success'},
      'warning': {'icon': '⚠️', 'label': 'Warning'},
      'tip': {'icon': '💡', 'label': 'Tip'},
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline),
              SizedBox(width: 8),
              Text('Insert Callout'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: types.entries
                    .map((e) => ButtonSegment(
                          value: e.key,
                          label: Text(e.value['label']!),
                        ))
                    .toList(),
                selected: {calloutType},
                onSelectionChanged: (s) => setState(() => calloutType = s.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'Callout Content',
                  hintText: 'Important information here...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                final icon = types[calloutType]!['icon'];
                final content = contentController.text.isEmpty
                    ? 'Your message here...'
                    : contentController.text;
                _insertText('\n$icon $content\n');
              },
              child: const Text('Insert'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSocialIconsDialog(ThemeData theme) {
    final links = {
      'facebook': '',
      'twitter': '',
      'linkedin': '',
      'instagram': '',
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.share),
            SizedBox(width: 8),
            Text('Social Media Links'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Facebook URL',
                  prefixIcon: Icon(Icons.facebook),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => links['facebook'] = v,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Twitter/X URL',
                  prefixIcon: Icon(Icons.alternate_email),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => links['twitter'] = v,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'LinkedIn URL',
                  prefixIcon: Icon(Icons.work),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => links['linkedin'] = v,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Instagram URL',
                  prefixIcon: Icon(Icons.camera_alt),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => links['instagram'] = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              final socialText = <String>[];
              if (links['facebook']!.isNotEmpty) socialText.add('[Facebook](${links['facebook']})');
              if (links['twitter']!.isNotEmpty) socialText.add('[Twitter](${links['twitter']})');
              if (links['linkedin']!.isNotEmpty) socialText.add('[LinkedIn](${links['linkedin']})');
              if (links['instagram']!.isNotEmpty) socialText.add('[Instagram](${links['instagram']})');
              if (socialText.isNotEmpty) {
                _insertText('\n${socialText.join(' • ')}\n');
              }
            },
            child: const Text('Insert'),
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
