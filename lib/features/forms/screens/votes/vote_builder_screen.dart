import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import '../../../../utils/quill_html_converter.dart';
import '../../../../utils/markdown_quill_loader.dart';
import '../../models/voting_form.dart';
import '../../services/votes_service.dart';

class VoteBuilderScreen extends StatefulWidget {
  final String? voteId;

  const VoteBuilderScreen({Key? key, this.voteId}) : super(key: key);

  @override
  State<VoteBuilderScreen> createState() => _VoteBuilderScreenState();
}

class _VoteBuilderScreenState extends State<VoteBuilderScreen> {
  final _votesService = VotesService();
  final _supabase = Supabase.instance.client;
  final _crmService = CRMSupabaseService();
  final _uuid = const Uuid();
  final _titleController = TextEditingController();
  final _slugController = TextEditingController();
  final _maxSubmissionsController = TextEditingController();
  final _confirmationEmailController = TextEditingController();
  final _notificationEmailsController = TextEditingController();
  final _confirmationSmsController = TextEditingController();

  // Rich text editor for description
  late quill.QuillController _descriptionController;
  final _descriptionFocusNode = FocusNode();
  final _descriptionScrollController = ScrollController();

  // Questions list (new format supporting multiple question types)
  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploadingDocument = false;

  // Supporting documents
  List<Map<String, dynamic>> _supportingDocuments = [];

  // Voting-specific settings
  DateTime? _votingStartsAt;
  DateTime? _votingEndsAt;
  bool _resultsPublic = false;

  // Common settings
  bool _requireLogin = false;
  bool _oneSubmissionPerUser = true; // Default true for votes
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = quill.QuillController.basic();
    if (widget.voteId != null) {
      _loadVote();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _descriptionFocusNode.dispose();
    _descriptionScrollController.dispose();
    _slugController.dispose();
    _maxSubmissionsController.dispose();
    _confirmationEmailController.dispose();
    _notificationEmailsController.dispose();
    _confirmationSmsController.dispose();
    super.dispose();
  }

  Future<void> _loadVote() async {
    setState(() => _isLoading = true);

    try {
      final vote = await _votesService.getVote(widget.voteId!);

      setState(() {
        _titleController.text = vote.title;

        // Load description into Quill editor
        final description = vote.description ?? '';
        if (description.isNotEmpty) {
          // Try to parse as HTML first, then fall back to plain text
          try {
            final doc = MarkdownQuillLoader.fromHtml(description);
            _descriptionController = quill.QuillController(
              document: doc,
              selection: const TextSelection.collapsed(offset: 0),
            );
          } catch (e) {
            // Fallback: treat as plain text
            _descriptionController = quill.QuillController.basic();
            _descriptionController.document.insert(0, description);
          }
        }

        // Load questions - uses extension that handles backwards compatibility
        _questions = List<Map<String, dynamic>>.from(vote.questions);

        // Voting-specific fields
        _votingStartsAt = vote.votingStartsAt;
        _votingEndsAt = vote.votingEndsAt;
        _resultsPublic = vote.resultsPublic;

        // Common settings
        _slugController.text = vote.slug ?? '';
        _maxSubmissionsController.text = vote.maxSubmissions?.toString() ?? '';
        _confirmationEmailController.text = vote.confirmationEmailTemplate ?? '';
        _notificationEmailsController.text = vote.notificationEmails?.join(', ') ?? '';
        _requireLogin = vote.requireLogin;
        _oneSubmissionPerUser = vote.oneSubmissionPerUser;

        // Load SMS confirmation message from settings
        _confirmationSmsController.text =
            vote.settings['confirmation_sms'] as String? ?? '';

        // Load supporting documents
        _supportingDocuments = List<Map<String, dynamic>>.from(
          vote.supportingDocuments ?? [],
        );

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final padding = isMobile ? 12.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.voteId == null ? 'Create Vote' : 'Edit Vote'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveVote,
            tooltip: 'Save',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic Info
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Vote Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Rich Text Description
            _buildDescriptionEditor(isMobile),
            const SizedBox(height: 16),

            // Supporting Documents Section
            _buildSupportingDocumentsSection(isMobile),
            const SizedBox(height: 16),

            // Voting Schedule Section
            Card(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Voting Schedule',
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (isMobile)
                      Column(
                        children: [
                          _buildDatePickerTile(
                            'Voting Starts',
                            _votingStartsAt,
                            (date) => setState(() => _votingStartsAt = date),
                            Icons.play_arrow,
                          ),
                          const SizedBox(height: 8),
                          _buildDatePickerTile(
                            'Voting Ends',
                            _votingEndsAt,
                            (date) => setState(() => _votingEndsAt = date),
                            Icons.stop,
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _buildDatePickerTile(
                              'Voting Starts',
                              _votingStartsAt,
                              (date) => setState(() => _votingStartsAt = date),
                              Icons.play_arrow,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDatePickerTile(
                              'Voting Ends',
                              _votingEndsAt,
                              (date) => setState(() => _votingEndsAt = date),
                              Icons.stop,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Public Results'),
                      subtitle: const Text('Allow voters to see results after voting'),
                      value: _resultsPublic,
                      onChanged: (value) => setState(() => _resultsPublic = value),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Settings Section
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Additional Settings'),
                    subtitle: Text(_showSettings ? 'Tap to collapse' : 'Configure access control, URLs, and notifications'),
                    trailing: Icon(_showSettings ? Icons.expand_less : Icons.expand_more),
                    onTap: () => setState(() => _showSettings = !_showSettings),
                  ),
                  if (_showSettings) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Custom URL Slug
                          TextField(
                            controller: _slugController,
                            decoration: const InputDecoration(
                              labelText: 'Custom URL Slug (optional)',
                              hintText: 'my-vote-name',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.link),
                              helperText: 'Leave blank to auto-generate',
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Access Control Section
                          Text(
                            'Access Control',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            title: const Text('Require Login'),
                            subtitle: const Text('Voters must be logged in'),
                            value: _requireLogin,
                            onChanged: (value) => setState(() => _requireLogin = value),
                            contentPadding: EdgeInsets.zero,
                          ),
                          SwitchListTile(
                            title: const Text('One Vote Per User'),
                            subtitle: const Text('Each user can only vote once'),
                            value: _oneSubmissionPerUser,
                            onChanged: (value) => setState(() => _oneSubmissionPerUser = value),
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _maxSubmissionsController,
                            decoration: const InputDecoration(
                              labelText: 'Max Total Votes (optional)',
                              hintText: 'e.g., 500',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.format_list_numbered),
                              helperText: 'Leave blank for unlimited',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),

                          // Email Settings Section
                          Text(
                            'Email Settings',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _notificationEmailsController,
                            decoration: const InputDecoration(
                              labelText: 'Notification Emails (optional)',
                              hintText: 'admin@example.com, team@example.com',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.notifications),
                              helperText: 'Comma-separated emails to notify on vote',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _confirmationEmailController,
                            decoration: const InputDecoration(
                              labelText: 'Confirmation Email Template (optional)',
                              hintText: 'Thank you for voting...',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email),
                              helperText: 'Supports {{name}}, {{email}}, {{title}} variables',
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _confirmationSmsController,
                            decoration: const InputDecoration(
                              labelText: 'Confirmation SMS Message (optional)',
                              hintText: 'Thank you {{name}} for voting!',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.sms),
                              helperText: 'Supports {{name}}, {{title}} variables',
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Questions Section
            _buildQuestionsSection(isMobile),
            const SizedBox(height: 24),

            // Publishing Controls
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : _saveVote,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Save Draft'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveAndPublish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Save & Publish'),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _saveVote,
                      child: const Text('Save Draft'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveAndPublish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('Save & Publish'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionEditor(bool isMobile) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final selectionStyle = _descriptionController.getSelectionStyle();
    final attributes = selectionStyle.attributes;
    final boldActive = attributes.containsKey(quill.Attribute.bold.key);
    final italicActive = attributes.containsKey(quill.Attribute.italic.key);
    final underlineActive = attributes.containsKey(quill.Attribute.underline.key);
    final linkActive = attributes.containsKey(quill.Attribute.link.key);

    final toolbar = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FormatButton(
          icon: Icons.format_bold,
          tooltip: 'Bold',
          isActive: boldActive,
          onPressed: () => _toggleDescriptionFormat(quill.Attribute.bold),
        ),
        _FormatButton(
          icon: Icons.format_italic,
          tooltip: 'Italic',
          isActive: italicActive,
          onPressed: () => _toggleDescriptionFormat(quill.Attribute.italic),
        ),
        _FormatButton(
          icon: Icons.format_underline,
          tooltip: 'Underline',
          isActive: underlineActive,
          onPressed: () => _toggleDescriptionFormat(quill.Attribute.underline),
        ),
        _FormatButton(
          icon: Icons.link,
          tooltip: 'Insert Link',
          isActive: linkActive,
          onPressed: _promptForDescriptionLink,
        ),
      ],
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Description',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(optional)',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: toolbar,
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(minHeight: 120, maxHeight: 200),
              child: quill.QuillEditor(
                focusNode: _descriptionFocusNode,
                scrollController: _descriptionScrollController,
                configurations: quill.QuillEditorConfigurations(
                  controller: _descriptionController,
                  scrollable: true,
                  expands: false,
                  padding: const EdgeInsets.all(12),
                  placeholder: 'Add a description for this vote...',
                  minHeight: 100,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use the toolbar to format text: bold, italic, underline, or add hyperlinks.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleDescriptionFormat(quill.Attribute attribute) {
    final selection = _descriptionController.selection;
    if (!selection.isValid) return;
    final currentStyle = _descriptionController.getSelectionStyle();
    final isActive = currentStyle.attributes.containsKey(attribute.key);
    final removal = quill.Attribute.clone(attribute, null);
    _descriptionController.formatSelection(isActive ? removal : attribute);
    setState(() {});
  }

  Future<void> _promptForDescriptionLink() async {
    final selection = _descriptionController.selection;
    if (!selection.isValid || selection.isCollapsed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select text before adding a hyperlink.')),
      );
      return;
    }

    final currentStyle = _descriptionController.getSelectionStyle();
    final existingLink =
        currentStyle.attributes[quill.Attribute.link.key]?.value?.toString() ?? '';
    final controller = TextEditingController(text: existingLink);

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Insert Hyperlink'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'https://example.com',
              border: OutlineInputBorder(),
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
                child: const Text('Remove Link'),
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

    if (result == null) return;

    final trimmed = result.trim();
    if (trimmed.isEmpty) {
      final removal = quill.Attribute.clone(quill.Attribute.link, null);
      _descriptionController.formatSelection(removal);
    } else {
      _descriptionController.formatSelection(quill.LinkAttribute(trimmed));
    }
    setState(() {});
  }

  Widget _buildSupportingDocumentsSection(bool isMobile) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_file, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Supporting Documents',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(optional)',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (_isUploadingDocument)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _uploadDocument,
                    tooltip: 'Add Document',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Upload documents that voters can reference (PDF, DOC, DOCX, etc.)',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (_supportingDocuments.isNotEmpty) ...[
              const SizedBox(height: 12),
              ..._supportingDocuments.asMap().entries.map((entry) {
                final index = entry.key;
                final doc = entry.value;
                return _buildDocumentTile(doc, index, isMobile);
              }),
            ] else ...[
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.folder_open,
                      size: 48,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No documents uploaded',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _isUploadingDocument ? null : _uploadDocument,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload Document'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentTile(Map<String, dynamic> doc, int index, bool isMobile) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fileName = doc['name'] as String? ?? 'Unknown';
    final fileSize = doc['size'] as int? ?? 0;
    final fileUrl = doc['url'] as String?;

    String formatFileSize(int bytes) {
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    IconData getFileIcon(String name) {
      final ext = name.split('.').last.toLowerCase();
      switch (ext) {
        case 'pdf':
          return Icons.picture_as_pdf;
        case 'doc':
        case 'docx':
          return Icons.description;
        case 'xls':
        case 'xlsx':
          return Icons.table_chart;
        case 'ppt':
        case 'pptx':
          return Icons.slideshow;
        case 'jpg':
        case 'jpeg':
        case 'png':
        case 'gif':
          return Icons.image;
        default:
          return Icons.insert_drive_file;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: isMobile,
        leading: Icon(getFileIcon(fileName), color: colorScheme.primary),
        title: Text(
          fileName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(formatFileSize(fileSize)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (fileUrl != null)
              IconButton(
                icon: const Icon(Icons.open_in_new, size: 20),
                onPressed: () => _openDocumentUrl(fileUrl),
                tooltip: 'Open',
              ),
            IconButton(
              icon: Icon(Icons.delete, size: 20, color: colorScheme.error),
              onPressed: () => _removeDocument(index),
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'rtf', 'jpg', 'jpeg', 'png', 'gif'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file data')),
          );
        }
        return;
      }

      setState(() => _isUploadingDocument = true);

      // Generate a unique file path
      final fileId = _uuid.v4();
      final ext = file.extension ?? 'bin';
      final voteIdPart = widget.voteId ?? 'new';
      final path = 'votes/$voteIdPart/$fileId.$ext';

      // Determine content type
      String contentType = 'application/octet-stream';
      switch (ext.toLowerCase()) {
        case 'pdf':
          contentType = 'application/pdf';
          break;
        case 'doc':
          contentType = 'application/msword';
          break;
        case 'docx':
          contentType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
          break;
        case 'xls':
          contentType = 'application/vnd.ms-excel';
          break;
        case 'xlsx':
          contentType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          break;
        case 'ppt':
          contentType = 'application/vnd.ms-powerpoint';
          break;
        case 'pptx':
          contentType = 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
          break;
        case 'txt':
          contentType = 'text/plain';
          break;
        case 'rtf':
          contentType = 'application/rtf';
          break;
        case 'jpg':
        case 'jpeg':
          contentType = 'image/jpeg';
          break;
        case 'png':
          contentType = 'image/png';
          break;
        case 'gif':
          contentType = 'image/gif';
          break;
      }

      // Upload to Supabase storage using privileged client to bypass RLS
      final storageClient = _crmService.isInitialized && _crmService.hasServiceRole
          ? _crmService.privilegedClient
          : _supabase;

      await storageClient.storage.from('form-documents').uploadBinary(
        path,
        file.bytes!,
        fileOptions: FileOptions(contentType: contentType, upsert: true),
      );

      // Get the public URL
      final publicUrl = storageClient.storage.from('form-documents').getPublicUrl(path);

      // Add to the documents list
      setState(() {
        _supportingDocuments.add({
          'id': fileId,
          'name': file.name,
          'size': file.size,
          'path': path,
          'url': publicUrl,
          'content_type': contentType,
          'uploaded_at': DateTime.now().toIso8601String(),
        });
        _isUploadingDocument = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded: ${file.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploadingDocument = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeDocument(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Document'),
        content: const Text('Are you sure you want to remove this document?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _supportingDocuments.removeAt(index);
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _openDocumentUrl(String url) {
    // For now, just copy the URL - in a real app you'd use url_launcher
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Document URL: $url')),
    );
  }

  Widget _buildDatePickerTile(
    String label,
    DateTime? value,
    Function(DateTime?) onChanged,
    IconData icon,
  ) {
    final formattedDate = value != null
        ? '${value.month}/${value.day}/${value.year} ${value.hour}:${value.minute.toString().padLeft(2, '0')}'
        : 'Not set';

    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
        );
        if (date != null && mounted) {
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(value ?? DateTime.now()),
          );
          if (time != null) {
            onChanged(DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            ));
          } else {
            onChanged(date);
          }
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    formattedDate,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            if (value != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => onChanged(null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  List<String>? _parseNotificationEmails() {
    final text = _notificationEmailsController.text.trim();
    if (text.isEmpty) return null;
    return text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  int? _parseMaxSubmissions() {
    final text = _maxSubmissionsController.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  // Question type definitions
  static const _questionTypes = [
    {'type': 'multiple_choice', 'label': 'Multiple Choice', 'description': 'Select one option', 'icon': Icons.radio_button_checked},
    {'type': 'multiple_select', 'label': 'Multiple Select', 'description': 'Select multiple options', 'icon': Icons.check_box},
    {'type': 'ranked_choice', 'label': 'Ranked Choice', 'description': 'Rank options in order', 'icon': Icons.format_list_numbered},
    {'type': 'short_answer', 'label': 'Short Answer', 'description': 'Free text response', 'icon': Icons.short_text},
    {'type': 'yes_no', 'label': 'Yes/No', 'description': 'Simple yes or no', 'icon': Icons.thumbs_up_down},
    {'type': 'rating_scale', 'label': 'Rating Scale', 'description': 'Rate on a scale', 'icon': Icons.star_rate},
  ];

  bool _questionTypeHasOptions(String? type) {
    return type == 'multiple_choice' || type == 'multiple_select' || type == 'ranked_choice';
  }

  String _getQuestionTypeLabel(String? type) {
    final found = _questionTypes.firstWhere(
      (t) => t['type'] == type,
      orElse: () => {'label': 'Unknown'},
    );
    return found['label'] as String;
  }

  IconData _getQuestionTypeIcon(String? type) {
    final found = _questionTypes.firstWhere(
      (t) => t['type'] == type,
      orElse: () => {'icon': Icons.help_outline},
    );
    return found['icon'] as IconData;
  }

  Widget _buildQuestionsSection(bool isMobile) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.quiz, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Vote Questions',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _addQuestion,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Question'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: isMobile ? 8 : 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_questions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.quiz_outlined,
                        size: 48,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No questions yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add questions for voters to answer',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._questions.asMap().entries.map((entry) {
                return _buildQuestionCard(entry.key, entry.value, isMobile);
              }),
          ],
        ),
      ),
    );
  }

  void _addQuestion() {
    showDialog(
      context: context,
      builder: (context) => _AddQuestionDialog(
        questionTypes: _questionTypes,
        onAdd: (type, text) {
          setState(() {
            _questions.add({
              'id': _uuid.v4(),
              'text': text,
              'question_type': type,
              'required': true,
              if (_questionTypeHasOptions(type)) 'options': <Map<String, dynamic>>[],
            });
          });
        },
      ),
    );
  }

  void _deleteQuestion(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text('Are you sure you want to delete this question?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _questions.removeAt(index);
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int index, Map<String, dynamic> question, bool isMobile) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final type = question['question_type'] as String?;
    final text = question['text'] as String? ?? '';
    final options = question['options'] as List<dynamic>? ?? [];
    final hasOptions = _questionTypeHasOptions(type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(_getQuestionTypeIcon(type), color: colorScheme.onPrimaryContainer, size: 20),
        ),
        title: Text(
          text.isEmpty ? 'Question ${index + 1}' : text,
          style: const TextStyle(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _getQuestionTypeLabel(type) + (hasOptions ? ' • ${options.length} options' : ''),
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: colorScheme.error),
          onPressed: () => _deleteQuestion(index),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question text editor
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Question Text',
                    border: OutlineInputBorder(),
                    hintText: 'Enter your question',
                  ),
                  controller: TextEditingController(text: text),
                  onChanged: (value) {
                    setState(() {
                      _questions[index]['text'] = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Options section (for types that need options)
                if (hasOptions) ...[
                  Row(
                    children: [
                      Text(
                        'Options',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _addOptionToQuestion(index),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Option'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (options.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'Add at least 2 options',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: options.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final optionsList = List<Map<String, dynamic>>.from(options);
                          final item = optionsList.removeAt(oldIndex);
                          optionsList.insert(newIndex, item);
                          _questions[index]['options'] = optionsList;
                        });
                      },
                      itemBuilder: (context, optIndex) {
                        final opt = options[optIndex] as Map<String, dynamic>;
                        return ListTile(
                          key: ValueKey(opt['id']),
                          leading: Icon(
                            type == 'multiple_choice' ? Icons.radio_button_unchecked :
                            type == 'multiple_select' ? Icons.check_box_outline_blank :
                            Icons.drag_handle,
                            size: 20,
                          ),
                          title: Text(opt['label'] as String? ?? ''),
                          trailing: IconButton(
                            icon: Icon(Icons.close, size: 18, color: colorScheme.error),
                            onPressed: () => _deleteOptionFromQuestion(index, optIndex),
                          ),
                        );
                      },
                    ),
                ],

                // Rating scale settings
                if (type == 'rating_scale') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Min Value',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(
                            text: (question['min_value'] ?? 1).toString(),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _questions[index]['min_value'] = int.tryParse(value) ?? 1;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Max Value',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(
                            text: (question['max_value'] ?? 5).toString(),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _questions[index]['max_value'] = int.tryParse(value) ?? 5;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addOptionToQuestion(int questionIndex) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Option'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Option Label',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  final options = List<Map<String, dynamic>>.from(
                    _questions[questionIndex]['options'] as List<dynamic>? ?? [],
                  );
                  options.add({
                    'id': _uuid.v4(),
                    'label': controller.text,
                  });
                  _questions[questionIndex]['options'] = options;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _deleteOptionFromQuestion(int questionIndex, int optionIndex) {
    setState(() {
      final options = List<Map<String, dynamic>>.from(
        _questions[questionIndex]['options'] as List<dynamic>,
      );
      options.removeAt(optionIndex);
      _questions[questionIndex]['options'] = options;
    });
  }

  // Legacy method - keep for reference, but no longer used
  List<VotingOption> get _options => [];
  set _options(List<VotingOption> _) {}

  Future<void> _saveVote({bool publish = false}) async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a vote title')),
      );
      return;
    }

    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one question')),
      );
      return;
    }

    // Validate that questions with options have at least 2 options
    for (final q in _questions) {
      final type = q['question_type'] as String?;
      final options = q['options'] as List<dynamic>?;
      if (_questionTypeHasOptions(type) && (options == null || options.length < 2)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Question "${q['text']}" needs at least 2 options')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final slug = _slugController.text.trim().isEmpty ? null : _slugController.text.trim();
      final maxSubmissions = _parseMaxSubmissions();
      final notificationEmails = _parseNotificationEmails();
      final confirmationEmail = _confirmationEmailController.text.trim().isEmpty
          ? null
          : _confirmationEmailController.text.trim();
      final confirmationSms = _confirmationSmsController.text.trim().isEmpty
          ? null
          : _confirmationSmsController.text.trim();

      // Convert Quill document to HTML
      final document = _descriptionController.document;
      final deltaOps = document.toDelta().toJson();
      final deltaJson = deltaOps
          .map<Map<String, dynamic>>(
            (dynamic op) => Map<String, dynamic>.from(op as Map),
          )
          .toList(growable: false);
      final plainText = document.toPlainText().trim();
      final descriptionHtml = plainText.isEmpty
          ? null
          : QuillHtmlConverter.generateHtml(deltaJson, plainText);

      if (widget.voteId == null) {
        await _votesService.createVote(
          title: _titleController.text,
          description: descriptionHtml,
          questions: _questions,
          votingStartsAt: _votingStartsAt,
          votingEndsAt: _votingEndsAt,
          resultsPublic: _resultsPublic,
          status: publish ? 'active' : 'draft',
          requireLogin: _requireLogin,
          oneSubmissionPerUser: _oneSubmissionPerUser,
          maxSubmissions: maxSubmissions,
          slug: slug,
          confirmationEmailTemplate: confirmationEmail,
          notificationEmails: notificationEmails,
          confirmationSmsMessage: confirmationSms,
          supportingDocuments: _supportingDocuments.isEmpty ? null : _supportingDocuments,
        );
      } else {
        await _votesService.updateVote(
          widget.voteId!,
          title: _titleController.text,
          description: descriptionHtml,
          questions: _questions,
          votingStartsAt: _votingStartsAt,
          votingEndsAt: _votingEndsAt,
          resultsPublic: _resultsPublic,
          status: publish ? 'active' : null,
          requireLogin: _requireLogin,
          oneSubmissionPerUser: _oneSubmissionPerUser,
          maxSubmissions: maxSubmissions,
          slug: slug,
          confirmationEmailTemplate: confirmationEmail,
          notificationEmails: notificationEmails,
          confirmationSmsMessage: confirmationSms,
          supportingDocuments: _supportingDocuments.isEmpty ? null : _supportingDocuments,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(publish ? 'Vote published!' : 'Vote saved as draft'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveAndPublish() async {
    await _saveVote(publish: true);
  }
}

class _AddQuestionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> questionTypes;
  final Function(String type, String text) onAdd;

  const _AddQuestionDialog({
    required this.questionTypes,
    required this.onAdd,
  });

  @override
  State<_AddQuestionDialog> createState() => _AddQuestionDialogState();
}

class _AddQuestionDialogState extends State<_AddQuestionDialog> {
  final _textController = TextEditingController();
  String? _selectedType;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('Add Question'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question Type',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.questionTypes.map((type) {
                final isSelected = _selectedType == type['type'];
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        type['icon'] as IconData,
                        size: 16,
                        color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                      ),
                      const SizedBox(width: 6),
                      Text(type['label'] as String),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedType = selected ? type['type'] as String : null;
                    });
                  },
                );
              }).toList(),
            ),
            if (_selectedType != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.questionTypes.firstWhere((t) => t['type'] == _selectedType)['description'] as String,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Question Text',
                hintText: 'What would you like to ask?',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              autofocus: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedType == null || _textController.text.isEmpty
              ? null
              : () {
                  widget.onAdd(_selectedType!, _textController.text);
                  Navigator.pop(context);
                },
          child: const Text('Add Question'),
        ),
      ],
    );
  }
}

/// A simple format button for the rich text toolbar
class _FormatButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onPressed;

  const _FormatButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive ? colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 20,
              color: isActive ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
