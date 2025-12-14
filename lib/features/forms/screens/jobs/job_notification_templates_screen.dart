import 'package:flutter/material.dart';
import '../../models/job_notification_template.dart';
import '../../services/jobs_service.dart';

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

/// Screen for editing a notification template
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

class _TemplateEditorScreenState extends State<_TemplateEditorScreen> {
  final _jobsService = JobsService();
  final _formKey = GlobalKey<FormState>();

  late String _triggerType;
  late String _recipientType;
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late bool _emailEnabled;
  late TextEditingController _emailSubjectController;
  late TextEditingController _emailHtmlController;
  late TextEditingController _emailPlainTextController;
  late bool _smsEnabled;
  late TextEditingController _smsBodyController;
  late bool _isActive;
  late bool _isDefault;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _triggerType = t?.triggerType ?? 'job_submitted';
    _recipientType = t?.recipientType ?? 'job_submitter';
    _nameController = TextEditingController(text: t?.name ?? '');
    _descriptionController = TextEditingController(text: t?.description ?? '');
    _emailEnabled = t?.emailEnabled ?? true;
    _emailSubjectController = TextEditingController(text: t?.emailSubject ?? '');
    _emailHtmlController = TextEditingController(text: t?.emailHtml ?? '');
    _emailPlainTextController = TextEditingController(text: t?.emailPlainText ?? '');
    _smsEnabled = t?.smsEnabled ?? false;
    _smsBodyController = TextEditingController(text: t?.smsBody ?? '');
    _isActive = t?.isActive ?? true;
    _isDefault = t?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _emailSubjectController.dispose();
    _emailHtmlController.dispose();
    _emailPlainTextController.dispose();
    _smsBodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.template != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Template' : 'New Template'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.star),
              onPressed: _isDefault ? null : _setAsDefault,
              tooltip: _isDefault ? 'This is the default' : 'Set as default',
              color: _isDefault ? Colors.amber : null,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
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
                      Text(JobNotificationTemplate.getTriggerLabel(type)),
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
            const SizedBox(height: 8),

            // Active toggle
            SwitchListTile(
              title: const Text('Active'),
              subtitle: const Text('Enable this template'),
              value: _isActive,
              onChanged: (value) {
                setState(() => _isActive = value);
              },
            ),
            const SizedBox(height: 24),

            // Email Section
            _buildSectionHeader(theme, 'Email Notification', Icons.email_outlined),
            const SizedBox(height: 12),

            SwitchListTile(
              title: const Text('Send Email'),
              subtitle: const Text('Send email notification when triggered'),
              value: _emailEnabled,
              onChanged: (value) {
                setState(() => _emailEnabled = value);
              },
            ),

            if (_emailEnabled) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailSubjectController,
                decoration: const InputDecoration(
                  labelText: 'Email Subject *',
                  hintText: 'Your job "{{job_title}}" has been approved!',
                  border: OutlineInputBorder(),
                  helperText: 'Use {{variable}} for dynamic content',
                ),
                validator: (value) {
                  if (_emailEnabled && (value == null || value.isEmpty)) {
                    return 'Subject is required when email is enabled';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailHtmlController,
                decoration: const InputDecoration(
                  labelText: 'Email Body (HTML)',
                  hintText: '<h1>Congratulations!</h1><p>Your job...</p>',
                  border: OutlineInputBorder(),
                  helperText: 'HTML content for rich email clients',
                ),
                maxLines: 8,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailPlainTextController,
                decoration: const InputDecoration(
                  labelText: 'Email Body (Plain Text)',
                  hintText: 'Congratulations! Your job...',
                  border: OutlineInputBorder(),
                  helperText: 'Plain text fallback for email clients',
                ),
                maxLines: 6,
              ),
            ],
            const SizedBox(height: 24),

            // SMS Section
            _buildSectionHeader(theme, 'SMS Notification', Icons.sms_outlined),
            const SizedBox(height: 12),

            SwitchListTile(
              title: const Text('Send SMS'),
              subtitle: const Text('Send SMS notification when triggered'),
              value: _smsEnabled,
              onChanged: (value) {
                setState(() => _smsEnabled = value);
              },
            ),

            if (_smsEnabled) ...[
              const SizedBox(height: 16),
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
            ],
            const SizedBox(height: 24),

            // Variable Reference
            _buildVariableReference(theme),
            const SizedBox(height: 100),
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

  Widget _buildVariableReference(ThemeData theme) {
    final variables = _getVariablesForTrigger(_triggerType);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.code, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Available Variables',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Use these placeholders in your template:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: variables.map((v) {
                return InkWell(
                  onTap: () {
                    // Copy to clipboard or insert into focused field
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Use {{$v}} in your template'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '{{$v}}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getVariablesForTrigger(String triggerType) {
    final common = ['job_title', 'job_organization', 'job_type', 'job_location'];

    switch (triggerType) {
      case 'job_submitted':
      case 'job_approved':
      case 'job_rejected':
      case 'job_expiring_soon':
      case 'job_expired':
        return [...common, 'submitter_name', 'submitter_email', 'job_url'];
      case 'application_received':
        return [...common, 'applicant_name', 'applicant_email', 'applicant_phone', 'submitter_name'];
      case 'application_submitted':
        return [...common, 'applicant_name', 'applicant_email', 'job_url'];
      case 'application_status_changed':
        return [...common, 'applicant_name', 'applicant_email', 'status', 'old_status'];
      default:
        return common;
    }
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
          emailHtml: _emailHtmlController.text.isEmpty ? null : _emailHtmlController.text,
          emailPlainText: _emailPlainTextController.text.isEmpty ? null : _emailPlainTextController.text,
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
          emailHtml: _emailHtmlController.text.isEmpty ? null : _emailHtmlController.text,
          emailPlainText: _emailPlainTextController.text.isEmpty ? null : _emailPlainTextController.text,
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
