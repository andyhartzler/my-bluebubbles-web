import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../models/job_notification_template.dart';
import '../../services/jobs_service.dart';
import '../../widgets/email_template_editor.dart';

/// Screen for managing job notification email/SMS templates
class JobNotificationTemplatesScreen extends StatefulWidget {
  const JobNotificationTemplatesScreen({super.key});

  @override
  State<JobNotificationTemplatesScreen> createState() =>
      _JobNotificationTemplatesScreenState();
}

class _JobNotificationTemplatesScreenState
    extends State<JobNotificationTemplatesScreen> {
  final _jobsService = JobsService();
  List<JobNotificationTemplate> _templates = [];
  bool _loading = true;
  String? _error;
  String _selectedTrigger = 'all';

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final templates = await _jobsService.getNotificationTemplates();
      if (mounted) {
        setState(() {
          _templates = templates;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<JobNotificationTemplate> get _filteredTemplates {
    if (_selectedTrigger == 'all') return _templates;
    return _templates.where((t) => t.triggerType == _selectedTrigger).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Templates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTemplates,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Info card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Automated Notifications',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Configure email and SMS notifications that are automatically sent when job events occur.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Filter tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Job Events', 'job', icon: Icons.work_outline),
                const SizedBox(width: 8),
                _buildFilterChip('Applications', 'application', icon: Icons.person_outline),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorState(theme)
                    : _filteredTemplates.isEmpty
                        ? _buildEmptyState(theme)
                        : _buildTemplatesList(theme),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTemplateEditor(context, null),
        icon: const Icon(Icons.add),
        label: const Text('New Template'),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, {IconData? icon}) {
    final theme = Theme.of(context);
    final isSelected = _selectedTrigger == value ||
        (value == 'job' && _selectedTrigger.startsWith('job_')) ||
        (value == 'application' && _selectedTrigger.startsWith('application_'));

    return FilterChip(
      avatar: icon != null ? Icon(icon, size: 18) : null,
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedTrigger = value == 'job' || value == 'application' ? 'all' : value;
        });
      },
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading templates',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loadTemplates,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No notification templates',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create templates to automatically send emails\nwhen job events occur.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showTemplateEditor(context, null),
            icon: const Icon(Icons.add),
            label: const Text('Create Template'),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatesList(ThemeData theme) {
    // Group templates by trigger type
    final grouped = <String, List<JobNotificationTemplate>>{};
    for (final template in _filteredTemplates) {
      grouped.putIfAbsent(template.triggerType, () => []).add(template);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final triggerType = grouped.keys.elementAt(index);
        final templates = grouped[triggerType]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trigger type header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(
                    JobNotificationTemplate.triggerTypeIcon(triggerType),
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          JobNotificationTemplate.getTriggerLabel(triggerType),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          JobNotificationTemplate.triggerTypeDescription(triggerType),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Templates for this trigger
            ...templates.map((template) => _buildTemplateCard(theme, template)),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildTemplateCard(ThemeData theme, JobNotificationTemplate template) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showTemplateEditor(context, template),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Active indicator
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: template.isActive ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Name
                  Expanded(
                    child: Text(
                      template.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Default badge
                  if (template.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Default',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Recipient badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      template.recipientTypeLabel,
                      style: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (template.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  template.description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              // Channel indicators
              Row(
                children: [
                  if (template.emailEnabled)
                    _buildChannelChip(theme, Icons.email_outlined, 'Email', true),
                  if (template.smsEnabled) ...[
                    const SizedBox(width: 8),
                    _buildChannelChip(theme, Icons.sms_outlined, 'SMS', true),
                  ],
                  const Spacer(),
                  // Actions
                  IconButton(
                    icon: Icon(
                      template.isActive ? Icons.toggle_on : Icons.toggle_off,
                      color: template.isActive ? Colors.green : Colors.grey,
                    ),
                    onPressed: () => _toggleActive(template),
                    tooltip: template.isActive ? 'Disable' : 'Enable',
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(template),
                    tooltip: 'Delete',
                    visualDensity: VisualDensity.compact,
                    color: theme.colorScheme.error,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelChip(ThemeData theme, IconData icon, String label, bool enabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: enabled
            ? theme.colorScheme.primaryContainer.withOpacity(0.5)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: enabled
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: enabled
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(JobNotificationTemplate template) async {
    try {
      await _jobsService.toggleTemplateActive(template.id, !template.isActive);
      await _loadTemplates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(template.isActive ? 'Template disabled' : 'Template enabled'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmDelete(JobNotificationTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Are you sure you want to delete "${template.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _jobsService.deleteTemplate(template.id);
                await _loadTemplates();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Template deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showTemplateEditor(BuildContext context, JobNotificationTemplate? template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _TemplateEditorScreen(
          template: template,
          onSaved: () async {
            await _loadTemplates();
          },
        ),
      ),
    );
  }
}

/// Screen for editing a notification template with WYSIWYG editor
class _TemplateEditorScreen extends StatefulWidget {
  final JobNotificationTemplate? template;
  final VoidCallback? onSaved;

  const _TemplateEditorScreen({
    this.template,
    this.onSaved,
  });

  @override
  State<_TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<_TemplateEditorScreen>
    with SingleTickerProviderStateMixin {
  final _jobsService = JobsService();
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  late String _triggerType;
  late String _recipientType;
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late bool _emailEnabled;
  late TextEditingController _emailSubjectController;
  String _emailHtml = '';
  String _emailPlainText = '';
  late bool _smsEnabled;
  late TextEditingController _smsBodyController;
  late bool _isActive;
  late bool _isDefault;

  bool _saving = false;
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final t = widget.template;
    _triggerType = t?.triggerType ?? 'job_submitted';
    _recipientType = t?.recipientType ?? 'job_submitter';
    _nameController = TextEditingController(text: t?.name ?? '');
    _descriptionController = TextEditingController(text: t?.description ?? '');
    _emailEnabled = t?.emailEnabled ?? true;
    _emailSubjectController = TextEditingController(text: t?.emailSubject ?? '');
    _emailHtml = t?.emailHtml ?? '';
    _emailPlainText = t?.emailPlainText ?? '';
    _smsEnabled = t?.smsEnabled ?? false;
    _smsBodyController = TextEditingController(text: t?.smsBody ?? '');
    _isActive = t?.isActive ?? true;
    _isDefault = t?.isDefault ?? false;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _emailSubjectController.dispose();
    _smsBodyController.dispose();
    super.dispose();
  }

  List<MailMergeVariable> get _mergeVariables {
    return JobNotificationVariables.forTrigger(_triggerType);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.template != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Template' : 'New Template'),
        actions: [
          // Preview toggle
          IconButton(
            icon: Icon(_showPreview ? Icons.edit : Icons.preview),
            onPressed: () => setState(() => _showPreview = !_showPreview),
            tooltip: _showPreview ? 'Edit' : 'Preview',
          ),
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.star),
              onPressed: _isDefault ? null : _setAsDefault,
              tooltip: _isDefault ? 'This is the default' : 'Set as default',
              color: _isDefault ? Colors.amber : null,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
            Tab(icon: Icon(Icons.email), text: 'Email Design'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [
            // Settings Tab
            _buildSettingsTab(theme),
            // Email Design Tab
            _buildEmailDesignTab(theme),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _saveTemplate,
        icon: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save),
        label: Text(_saving ? 'Saving...' : 'Save Template'),
      ),
    );
  }

  Widget _buildSettingsTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Basic Info Section
        _buildSectionHeader(theme, 'Basic Information', Icons.info_outline),
        const SizedBox(height: 12),

        // Name
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Template Name *',
            hintText: 'e.g., Job Approval Confirmation',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Description
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description',
            hintText: 'Brief description of this template',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),

        // Trigger Type Dropdown
        DropdownButtonFormField<String>(
          value: _triggerType,
          decoration: const InputDecoration(
            labelText: 'Trigger Event *',
            border: OutlineInputBorder(),
          ),
          items: JobNotificationTemplate.triggerTypes.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Row(
                children: [
                  Text(JobNotificationTemplate.triggerTypeIcon(type)),
                  const SizedBox(width: 8),
                  Flexible(child: Text(JobNotificationTemplate.getTriggerLabel(type))),
                ],
              ),
            );
          }).toList(),
          onChanged: widget.template != null
              ? null
              : (value) {
                  if (value != null) {
                    setState(() => _triggerType = value);
                  }
                },
        ),
        const SizedBox(height: 16),

        // Recipient Type Dropdown
        DropdownButtonFormField<String>(
          value: _recipientType,
          decoration: const InputDecoration(
            labelText: 'Send To *',
            border: OutlineInputBorder(),
          ),
          items: JobNotificationTemplate.recipientTypes.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(JobNotificationTemplate.getRecipientLabel(type)),
            );
          }).toList(),
          onChanged: widget.template != null
              ? null
              : (value) {
                  if (value != null) {
                    setState(() => _recipientType = value);
                  }
                },
        ),
        const SizedBox(height: 16),

        // Toggle switches
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Active'),
                subtitle: const Text('Enable this template'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Send Email'),
                subtitle: const Text('Send email notification when triggered'),
                value: _emailEnabled,
                onChanged: (value) => setState(() => _emailEnabled = value),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Send SMS'),
                subtitle: const Text('Send SMS notification when triggered'),
                value: _smsEnabled,
                onChanged: (value) => setState(() => _smsEnabled = value),
              ),
            ],
          ),
        ),

        if (_smsEnabled) ...[
          const SizedBox(height: 24),
          _buildSectionHeader(theme, 'SMS Message', Icons.sms_outlined),
          const SizedBox(height: 12),
          _buildSmsEditor(theme),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSmsEditor(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _smsBodyController,
          decoration: const InputDecoration(
            labelText: 'SMS Message *',
            hintText: 'Your job "{{job_title}}" has been approved!',
            border: OutlineInputBorder(),
            helperText: 'Keep under 160 characters for single SMS',
            counterText: '',
          ),
          maxLines: 3,
          maxLength: 320,
          validator: (value) {
            if (_smsEnabled && (value == null || value.isEmpty)) {
              return 'SMS message is required when SMS is enabled';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        // Quick variable buttons for SMS
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _mergeVariables.take(5).map((v) {
            return ActionChip(
              avatar: const Icon(Icons.add, size: 14),
              label: Text(v.label, style: const TextStyle(fontSize: 11)),
              onPressed: () {
                final text = _smsBodyController.text;
                final selection = _smsBodyController.selection;
                final newText = text.replaceRange(
                  selection.start,
                  selection.end,
                  v.token,
                );
                _smsBodyController.text = newText;
                _smsBodyController.selection = TextSelection.collapsed(
                  offset: selection.start + v.token.length,
                );
              },
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEmailDesignTab(ThemeData theme) {
    if (!_emailEnabled) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.email_outlined,
              size: 64,
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Email notifications disabled',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enable "Send Email" in the Settings tab to design your email.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                setState(() => _emailEnabled = true);
                _tabController.animateTo(0);
              },
              icon: const Icon(Icons.toggle_on),
              label: const Text('Enable Email'),
            ),
          ],
        ),
      );
    }

    if (_showPreview) {
      return _buildEmailPreview(theme);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Subject line
        _buildSectionHeader(theme, 'Email Subject', Icons.subject),
        const SizedBox(height: 12),
        _buildSubjectEditor(theme),
        const SizedBox(height: 24),

        // Rich text editor for body
        _buildSectionHeader(theme, 'Email Body', Icons.article_outlined),
        const SizedBox(height: 12),
        EmailTemplateEditor(
          initialHtml: _emailHtml,
          mergeVariables: _mergeVariables,
          minHeight: 400,
          placeholder: 'Design your beautiful email here...',
          helperText: 'Use the toolbar to format your email. Insert merge variables to personalize each message.',
          onHtmlChanged: (html) => _emailHtml = html,
          onPlainTextChanged: (text) => _emailPlainText = text,
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSubjectEditor(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _emailSubjectController,
          decoration: InputDecoration(
            labelText: 'Email Subject *',
            hintText: 'Your job "{{job_title}}" has been approved!',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.data_object),
              onPressed: () => _showSubjectVariablePicker(theme),
              tooltip: 'Insert variable',
            ),
          ),
          validator: (value) {
            if (_emailEnabled && (value == null || value.isEmpty)) {
              return 'Subject is required when email is enabled';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        // Quick variable buttons
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _mergeVariables.take(4).map((v) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: const Icon(Icons.add, size: 14),
                  label: Text(v.label, style: const TextStyle(fontSize: 11)),
                  onPressed: () => _insertSubjectVariable(v.token),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _insertSubjectVariable(String token) {
    final text = _emailSubjectController.text;
    final selection = _emailSubjectController.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      token,
    );
    _emailSubjectController.text = newText;
    _emailSubjectController.selection = TextSelection.collapsed(
      offset: selection.start + token.length,
    );
  }

  void _showSubjectVariablePicker(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Insert Variable',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _mergeVariables.map((v) {
                return ActionChip(
                  label: Text(v.label),
                  onPressed: () {
                    Navigator.pop(context);
                    _insertSubjectVariable(v.token);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailPreview(ThemeData theme) {
    // Create sample data for preview
    final sampleData = {
      'job_title': 'Software Developer',
      'job_organization': 'Missouri Young Democrats',
      'job_type': 'Full-time',
      'job_location': 'Jefferson City, MO',
      'job_url': 'https://moyd.org/jobs/software-developer',
      'submitter_name': 'John Doe',
      'submitter_email': 'john@example.com',
      'applicant_name': 'Jane Smith',
      'applicant_email': 'jane@example.com',
      'applicant_phone': '(555) 123-4567',
      'applicant_city': 'St. Louis',
      'status': 'Under Review',
      'old_status': 'New',
      'rejection_reason': 'Position filled',
    };

    String previewSubject = _emailSubjectController.text;
    String previewHtml = _emailHtml;

    for (final entry in sampleData.entries) {
      previewSubject = previewSubject.replaceAll('{{${entry.key}}}', entry.value);
      previewHtml = previewHtml.replaceAll('{{${entry.key}}}', entry.value);
    }

    return Column(
      children: [
        // Preview header
        Container(
          padding: const EdgeInsets.all(16),
          color: theme.colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Icon(Icons.preview, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Email Preview',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'This shows how the email will look with sample data',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _showPreview = false),
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
              ),
            ],
          ),
        ),
        // Email preview
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Email header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade200,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Subject: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              previewSubject.isEmpty ? '(No subject)' : previewSubject,
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text(
                            'To: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            _recipientType == 'job_submitter'
                                ? sampleData['submitter_email']!
                                : sampleData['applicant_email']!,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Email body
                Expanded(
                  child: previewHtml.isEmpty
                      ? Center(
                          child: Text(
                            'No email content yet.\nGo to Edit mode to design your email.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _HtmlPreview(html: previewHtml),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Future<void> _setAsDefault() async {
    if (widget.template == null) return;

    try {
      await _jobsService.setTemplateAsDefault(widget.template!.id);
      setState(() => _isDefault = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Set as default template'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set as default: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      if (widget.template != null) {
        // Update existing
        await _jobsService.updateTemplate(
          widget.template!.id,
          name: _nameController.text,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          emailEnabled: _emailEnabled,
          emailSubject: _emailSubjectController.text.isEmpty ? null : _emailSubjectController.text,
          emailHtml: _emailHtml.isEmpty ? null : _emailHtml,
          emailPlainText: _emailPlainText.isEmpty ? null : _emailPlainText,
          smsEnabled: _smsEnabled,
          smsBody: _smsBodyController.text.isEmpty ? null : _smsBodyController.text,
          isActive: _isActive,
          isDefault: _isDefault,
        );
      } else {
        // Create new
        await _jobsService.createTemplate(
          triggerType: _triggerType,
          recipientType: _recipientType,
          name: _nameController.text,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          emailEnabled: _emailEnabled,
          emailSubject: _emailSubjectController.text.isEmpty ? null : _emailSubjectController.text,
          emailHtml: _emailHtml.isEmpty ? null : _emailHtml,
          emailPlainText: _emailPlainText.isEmpty ? null : _emailPlainText,
          smsEnabled: _smsEnabled,
          smsBody: _smsBodyController.text.isEmpty ? null : _smsBodyController.text,
          isActive: _isActive,
          isDefault: _isDefault,
        );
      }

      widget.onSaved?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.template != null ? 'Template updated' : 'Template created'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

/// Rich HTML preview widget using flutter_html
class _HtmlPreview extends StatelessWidget {
  final String html;

  const _HtmlPreview({required this.html});

  @override
  Widget build(BuildContext context) {
    if (html.isEmpty) {
      return Center(
        child: Text(
          'Email body will appear here...',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade500,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    // Wrap the HTML content for proper email rendering
    final wrappedHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      line-height: 1.6;
      color: #333;
      margin: 0;
      padding: 0;
    }
    a {
      color: #2563eb;
      text-decoration: none;
    }
    a:hover {
      text-decoration: underline;
    }
    img {
      max-width: 100%;
      height: auto;
    }
    table {
      border-collapse: collapse;
      width: 100%;
    }
    td, th {
      padding: 8px;
      text-align: left;
    }
  </style>
</head>
<body>
$html
</body>
</html>
''';

    return Html(
      data: wrappedHtml,
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontSize: FontSize(14),
          lineHeight: const LineHeight(1.6),
          color: Colors.black87,
        ),
        'h1': Style(
          fontSize: FontSize(24),
          fontWeight: FontWeight.bold,
          margin: Margins.only(bottom: 16),
        ),
        'h2': Style(
          fontSize: FontSize(20),
          fontWeight: FontWeight.bold,
          margin: Margins.only(bottom: 12),
        ),
        'h3': Style(
          fontSize: FontSize(18),
          fontWeight: FontWeight.w600,
          margin: Margins.only(bottom: 10),
        ),
        'p': Style(
          margin: Margins.only(bottom: 12),
        ),
        'a': Style(
          color: const Color(0xFF2563EB),
          textDecoration: TextDecoration.none,
        ),
        'strong': Style(
          fontWeight: FontWeight.bold,
        ),
        'em': Style(
          fontStyle: FontStyle.italic,
        ),
        'u': Style(
          textDecoration: TextDecoration.underline,
        ),
        'table': Style(
          border: Border.all(color: Colors.grey.shade300),
        ),
        'td': Style(
          padding: HtmlPaddings.all(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        'th': Style(
          padding: HtmlPaddings.all(8),
          backgroundColor: Colors.grey.shade100,
          fontWeight: FontWeight.bold,
          border: Border.all(color: Colors.grey.shade300),
        ),
      },
      onLinkTap: (url, _, __) {
        if (url != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Link: $url'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'OK',
                onPressed: () {},
              ),
            ),
          );
        }
      },
    );
  }
}
