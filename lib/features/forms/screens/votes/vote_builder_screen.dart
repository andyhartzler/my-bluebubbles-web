import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
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
  final _uuid = const Uuid();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _slugController = TextEditingController();
  final _maxSubmissionsController = TextEditingController();
  final _confirmationEmailController = TextEditingController();
  final _notificationEmailsController = TextEditingController();

  List<VotingOption> _options = [];
  bool _isLoading = false;
  bool _isSaving = false;

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
    if (widget.voteId != null) {
      _loadVote();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _slugController.dispose();
    _maxSubmissionsController.dispose();
    _confirmationEmailController.dispose();
    _notificationEmailsController.dispose();
    super.dispose();
  }

  Future<void> _loadVote() async {
    setState(() => _isLoading = true);

    try {
      final vote = await _votesService.getVote(widget.voteId!);

      setState(() {
        _titleController.text = vote.title;
        _descriptionController.text = vote.description ?? '';
        _options = vote.options; // Uses extension method

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
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
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
                              labelText: 'Vote Confirmation Message (optional)',
                              hintText: 'Thank you for voting...',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email),
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Options Section
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Voting Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addOption,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Option'),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Text(
                    'Voting Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _addOption,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Option'),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            if (_options.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 24 : 32),
                  child: Text(
                    'No options yet. Add at least 2 options.',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ..._options.map((option) => _buildOptionCard(option, isMobile: isMobile)).toList(),
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

  Widget _buildOptionCard(VotingOption option, {bool isMobile = false}) {
    if (isMobile) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.radio_button_checked, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  option.label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 20),
                onPressed: () => _deleteOption(option.id),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.radio_button_checked),
        title: Text(option.label),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _deleteOption(option.id),
        ),
      ),
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

  void _addOption() {
    showDialog(
      context: context,
      builder: (context) => _AddOptionDialog(
        onAdd: (label) {
          setState(() {
            _options.add(VotingOption(
              id: _uuid.v4(),
              label: label,
            ));
          });
        },
      ),
    );
  }

  void _deleteOption(String optionId) {
    setState(() {
      _options.removeWhere((o) => o.id == optionId);
    });
  }

  Future<void> _saveVote({bool publish = false}) async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a vote title')),
      );
      return;
    }

    if (_options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least 2 options')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final slug = _slugController.text.trim().isEmpty ? null : _slugController.text.trim();
      final maxSubmissions = _parseMaxSubmissions();
      final notificationEmails = _parseNotificationEmails();
      final confirmationEmail = _confirmationEmailController.text.trim().isEmpty
          ? null
          : _confirmationEmailController.text.trim();

      if (widget.voteId == null) {
        await _votesService.createVote(
          title: _titleController.text,
          description: _descriptionController.text.isEmpty
              ? null
              : _descriptionController.text,
          options: _options,
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
        );
      } else {
        await _votesService.updateVote(
          widget.voteId!,
          title: _titleController.text,
          description: _descriptionController.text.isEmpty
              ? null
              : _descriptionController.text,
          options: _options,
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

class _AddOptionDialog extends StatefulWidget {
  final Function(String) onAdd;

  const _AddOptionDialog({required this.onAdd});

  @override
  State<_AddOptionDialog> createState() => _AddOptionDialogState();
}

class _AddOptionDialogState extends State<_AddOptionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Option'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Option Label',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter an option label')),
              );
              return;
            }
            widget.onAdd(_controller.text);
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
