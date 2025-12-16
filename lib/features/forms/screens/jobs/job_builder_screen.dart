import 'package:flutter/material.dart';
import '../../models/job.dart';
import '../../services/jobs_service.dart';
import '../../widgets/custom_questions_editor.dart';

class JobBuilderScreen extends StatefulWidget {
  final String? jobId;

  const JobBuilderScreen({Key? key, this.jobId}) : super(key: key);

  @override
  State<JobBuilderScreen> createState() => _JobBuilderScreenState();
}

class _JobBuilderScreenState extends State<JobBuilderScreen> {
  final _jobsService = JobsService();
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _titleController = TextEditingController();
  final _organizationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _salaryRangeController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  final _requirementsController = TextEditingController();
  final _qualificationsController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _applicationUrlController = TextEditingController();
  final _applicationInstructionsController = TextEditingController();
  final _submitterNameController = TextEditingController();
  final _submitterEmailController = TextEditingController();
  final _submitterOrganizationController = TextEditingController();
  final _submitterPhoneController = TextEditingController();
  final _tagsController = TextEditingController();

  // State variables
  String _jobType = 'full-time';
  String? _locationType;
  bool _isPaid = false;
  DateTime? _expiresAt;
  bool _featured = false;
  bool _isLoading = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _customQuestions = [];

  // Resume & Cover Letter options
  bool _resumeEnabled = true;
  bool _resumeRequired = false;
  bool _coverLetterEnabled = true;
  bool _coverLetterRequired = false;

  static const List<String> _jobTypes = [
    'full-time',
    'part-time',
    'internship',
    'volunteer',
    'contract',
  ];

  static const List<String> _locationTypes = [
    'remote',
    'hybrid',
    'in-person',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.jobId != null) {
      _loadJob();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _organizationController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _salaryRangeController.dispose();
    _hourlyRateController.dispose();
    _requirementsController.dispose();
    _qualificationsController.dispose();
    _contactEmailController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _applicationUrlController.dispose();
    _applicationInstructionsController.dispose();
    _submitterNameController.dispose();
    _submitterEmailController.dispose();
    _submitterOrganizationController.dispose();
    _submitterPhoneController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _loadJob() async {
    setState(() => _isLoading = true);

    try {
      final job = await _jobsService.getJob(widget.jobId!);

      setState(() {
        _titleController.text = job.title;
        _organizationController.text = job.organization;
        _descriptionController.text = job.description;
        _jobType = job.jobType;
        _locationController.text = job.location ?? '';
        _locationType = job.locationType;
        _isPaid = job.isPaid;
        _salaryRangeController.text = job.salaryRange ?? '';
        _hourlyRateController.text = job.hourlyRate ?? '';
        _requirementsController.text = job.requirements ?? '';
        _qualificationsController.text = job.qualifications ?? '';
        _contactEmailController.text = job.contactEmail;
        _contactNameController.text = job.contactName ?? '';
        _contactPhoneController.text = job.contactPhone ?? '';
        _applicationUrlController.text = job.applicationUrl ?? '';
        _applicationInstructionsController.text = job.applicationInstructions ?? '';
        _expiresAt = job.expiresAt;
        _submitterNameController.text = job.submitterName;
        _submitterEmailController.text = job.submitterEmail;
        _submitterOrganizationController.text = job.submitterOrganization ?? '';
        _submitterPhoneController.text = job.submitterPhone ?? '';
        _tagsController.text = job.tags?.join(', ') ?? '';
        _featured = job.featured;
        _customQuestions = job.customQuestions
            .map((q) => q.toJson())
            .toList();
        _resumeEnabled = job.resumeEnabled ?? true;
        _resumeRequired = job.resumeRequired ?? false;
        _coverLetterEnabled = job.coverLetterEnabled ?? true;
        _coverLetterRequired = job.coverLetterRequired ?? false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading job: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveJob() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final tags = _tagsController.text.isEmpty
          ? null
          : _tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

      if (widget.jobId == null) {
        await _jobsService.createJob(
          title: _titleController.text,
          organization: _organizationController.text,
          description: _descriptionController.text,
          jobType: _jobType,
          location: _locationController.text.isEmpty ? null : _locationController.text,
          locationType: _locationType,
          isPaid: _isPaid,
          salaryRange: _salaryRangeController.text.isEmpty ? null : _salaryRangeController.text,
          hourlyRate: _hourlyRateController.text.isEmpty ? null : _hourlyRateController.text,
          requirements: _requirementsController.text.isEmpty ? null : _requirementsController.text,
          qualifications: _qualificationsController.text.isEmpty ? null : _qualificationsController.text,
          contactEmail: _contactEmailController.text,
          contactName: _contactNameController.text.isEmpty ? null : _contactNameController.text,
          contactPhone: _contactPhoneController.text.isEmpty ? null : _contactPhoneController.text,
          applicationUrl: _applicationUrlController.text.isEmpty ? null : _applicationUrlController.text,
          applicationInstructions: _applicationInstructionsController.text.isEmpty ? null : _applicationInstructionsController.text,
          expiresAt: _expiresAt,
          status: 'approved', // Admin-created jobs are auto-approved
          submitterName: _submitterNameController.text,
          submitterEmail: _submitterEmailController.text,
          submitterOrganization: _submitterOrganizationController.text.isEmpty ? null : _submitterOrganizationController.text,
          submitterPhone: _submitterPhoneController.text.isEmpty ? null : _submitterPhoneController.text,
          featured: _featured,
          tags: tags,
          customQuestions: _customQuestions,
          resumeEnabled: _resumeEnabled,
          resumeRequired: _resumeRequired,
          coverLetterEnabled: _coverLetterEnabled,
          coverLetterRequired: _coverLetterRequired,
        );
      } else {
        await _jobsService.updateJobDetails(
          widget.jobId!,
          title: _titleController.text,
          organization: _organizationController.text,
          description: _descriptionController.text,
          jobType: _jobType,
          location: _locationController.text.isEmpty ? null : _locationController.text,
          clearLocation: _locationController.text.isEmpty,
          locationType: _locationType,
          clearLocationType: _locationType == null,
          isPaid: _isPaid,
          salaryRange: _salaryRangeController.text.isEmpty ? null : _salaryRangeController.text,
          clearSalaryRange: _salaryRangeController.text.isEmpty,
          hourlyRate: _hourlyRateController.text.isEmpty ? null : _hourlyRateController.text,
          clearHourlyRate: _hourlyRateController.text.isEmpty,
          requirements: _requirementsController.text.isEmpty ? null : _requirementsController.text,
          clearRequirements: _requirementsController.text.isEmpty,
          qualifications: _qualificationsController.text.isEmpty ? null : _qualificationsController.text,
          clearQualifications: _qualificationsController.text.isEmpty,
          contactEmail: _contactEmailController.text,
          contactName: _contactNameController.text.isEmpty ? null : _contactNameController.text,
          clearContactName: _contactNameController.text.isEmpty,
          contactPhone: _contactPhoneController.text.isEmpty ? null : _contactPhoneController.text,
          clearContactPhone: _contactPhoneController.text.isEmpty,
          applicationUrl: _applicationUrlController.text.isEmpty ? null : _applicationUrlController.text,
          clearApplicationUrl: _applicationUrlController.text.isEmpty,
          applicationInstructions: _applicationInstructionsController.text.isEmpty ? null : _applicationInstructionsController.text,
          clearApplicationInstructions: _applicationInstructionsController.text.isEmpty,
          expiresAt: _expiresAt,
          clearExpiresAt: _expiresAt == null,
          submitterName: _submitterNameController.text,
          submitterEmail: _submitterEmailController.text,
          submitterOrganization: _submitterOrganizationController.text.isEmpty ? null : _submitterOrganizationController.text,
          clearSubmitterOrganization: _submitterOrganizationController.text.isEmpty,
          submitterPhone: _submitterPhoneController.text.isEmpty ? null : _submitterPhoneController.text,
          clearSubmitterPhone: _submitterPhoneController.text.isEmpty,
          featured: _featured,
          tags: tags,
          clearTags: tags == null || tags.isEmpty,
          customQuestions: _customQuestions,
          resumeEnabled: _resumeEnabled,
          resumeRequired: _resumeRequired,
          coverLetterEnabled: _coverLetterEnabled,
          coverLetterRequired: _coverLetterRequired,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.jobId == null ? 'Job created' : 'Job updated'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving job: $e'),
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

  Future<void> _selectExpiresAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_expiresAt ?? DateTime.now()),
      );

      if (time != null) {
        setState(() {
          _expiresAt = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final padding = isMobile ? 12.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.jobId == null ? 'Create Job' : 'Edit Job'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveJob,
            tooltip: 'Save',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.all(padding),
                children: [
                  // Job Information Section
                  _buildSectionHeader(theme, 'Job Information', Icons.work),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Job Title *',
                      hintText: 'e.g., Campaign Organizer',
                    ),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _organizationController,
                    decoration: const InputDecoration(
                      labelText: 'Organization *',
                      hintText: 'e.g., Missouri Young Democrats',
                    ),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description *',
                      hintText: 'Describe the role and responsibilities...',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 5,
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),

                  // Job Type & Location Section
                  _buildSectionHeader(theme, 'Job Type & Location', Icons.location_on),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _jobType,
                    decoration: const InputDecoration(
                      labelText: 'Job Type *',
                    ),
                    items: _jobTypes.map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(_formatLabel(type)),
                    )).toList(),
                    onChanged: (v) => setState(() => _jobType = v!),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      hintText: 'e.g., St. Louis, MO',
                    ),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String?>(
                    value: _locationType,
                    decoration: const InputDecoration(
                      labelText: 'Location Type',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Select...')),
                      ..._locationTypes.map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(_formatLabel(type)),
                      )),
                    ],
                    onChanged: (v) => setState(() => _locationType = v),
                  ),
                  const SizedBox(height: 24),

                  // Compensation Section
                  _buildSectionHeader(theme, 'Compensation', Icons.attach_money),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    title: const Text('Paid Position'),
                    value: _isPaid,
                    onChanged: (v) => setState(() => _isPaid = v),
                    contentPadding: EdgeInsets.zero,
                  ),

                  if (_isPaid) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _salaryRangeController,
                      decoration: const InputDecoration(
                        labelText: 'Salary Range',
                        hintText: 'e.g., \$40,000 - \$50,000',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _hourlyRateController,
                      decoration: const InputDecoration(
                        labelText: 'Hourly Rate',
                        hintText: 'e.g., \$15 - \$20/hour',
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Requirements Section
                  _buildSectionHeader(theme, 'Requirements', Icons.checklist),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _requirementsController,
                    decoration: const InputDecoration(
                      labelText: 'Requirements',
                      hintText: 'List the job requirements...',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _qualificationsController,
                    decoration: const InputDecoration(
                      labelText: 'Qualifications',
                      hintText: 'List preferred qualifications...',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 24),

                  // Contact Information Section
                  _buildSectionHeader(theme, 'Contact Information', Icons.contact_mail),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _contactEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Email *',
                      hintText: 'jobs@organization.org',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _contactNameController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Name',
                      hintText: 'e.g., Jane Smith',
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _contactPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Phone',
                      hintText: '(555) 123-4567',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),

                  // Application Information Section
                  _buildSectionHeader(theme, 'Application', Icons.send),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _applicationUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Application URL',
                      hintText: 'https://...',
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _applicationInstructionsController,
                    decoration: const InputDecoration(
                      labelText: 'Application Instructions',
                      hintText: 'How to apply...',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  // Resume & Cover Letter Options
                  _buildSectionHeader(theme, 'Application Fields', Icons.upload_file),
                  const SizedBox(height: 8),
                  Text(
                    'Configure which fields applicants see when applying for this job.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Resume options
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.description_outlined,
                                   size: 20,
                                   color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Resume Upload',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            title: const Text('Show resume upload field'),
                            subtitle: const Text('Allow applicants to upload a resume'),
                            value: _resumeEnabled,
                            onChanged: (v) => setState(() {
                              _resumeEnabled = v;
                              if (!v) _resumeRequired = false;
                            }),
                            contentPadding: EdgeInsets.zero,
                          ),
                          if (_resumeEnabled)
                            SwitchListTile(
                              title: const Text('Require resume'),
                              subtitle: const Text('Applicants must upload a resume'),
                              value: _resumeRequired,
                              onChanged: (v) => setState(() => _resumeRequired = v),
                              contentPadding: EdgeInsets.zero,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Cover letter options
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.article_outlined,
                                   size: 20,
                                   color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Cover Letter',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            title: const Text('Show cover letter field'),
                            subtitle: const Text('Allow applicants to submit a cover letter'),
                            value: _coverLetterEnabled,
                            onChanged: (v) => setState(() {
                              _coverLetterEnabled = v;
                              if (!v) _coverLetterRequired = false;
                            }),
                            contentPadding: EdgeInsets.zero,
                          ),
                          if (_coverLetterEnabled)
                            SwitchListTile(
                              title: const Text('Require cover letter'),
                              subtitle: const Text('Applicants must provide a cover letter'),
                              value: _coverLetterRequired,
                              onChanged: (v) => setState(() => _coverLetterRequired = v),
                              contentPadding: EdgeInsets.zero,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Expires At'),
                    subtitle: Text(
                      _expiresAt != null
                          ? '${_expiresAt!.month}/${_expiresAt!.day}/${_expiresAt!.year}'
                          : 'No expiration set',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_expiresAt != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _expiresAt = null),
                          ),
                        IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: _selectExpiresAt,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submitter Information Section
                  _buildSectionHeader(theme, 'Submitter Information', Icons.person),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _submitterNameController,
                    decoration: const InputDecoration(
                      labelText: 'Submitter Name *',
                      hintText: 'Your name',
                    ),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _submitterEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Submitter Email *',
                      hintText: 'your@email.com',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _submitterOrganizationController,
                    decoration: const InputDecoration(
                      labelText: 'Submitter Organization',
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _submitterPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'Submitter Phone',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),

                  // Custom Questions Section
                  CustomQuestionsEditor(
                    initialQuestions: _customQuestions,
                    onChanged: (questions) {
                      setState(() => _customQuestions = questions);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Additional Settings Section
                  _buildSectionHeader(theme, 'Additional Settings', Icons.settings),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _tagsController,
                    decoration: const InputDecoration(
                      labelText: 'Tags',
                      hintText: 'e.g., campaign, organizing, st-louis',
                      helperText: 'Comma-separated tags',
                    ),
                  ),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    title: const Text('Featured Job'),
                    subtitle: const Text('Highlight this job in listings'),
                    value: _featured,
                    onChanged: (v) => setState(() => _featured = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveJob,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(widget.jobId == null ? 'Create Job' : 'Save Changes'),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
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

  String _formatLabel(String value) {
    return value.split('-').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
  }
}
