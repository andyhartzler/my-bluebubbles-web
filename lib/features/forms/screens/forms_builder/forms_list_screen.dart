import 'package:flutter/material.dart';
import '../../models/form_schema.dart';
import '../../models/form_template_db.dart';
import '../../services/forms_service.dart';
import '../../widgets/form_card.dart';
import 'form_builder_screen.dart';
import '../form_submission_screen.dart';
import '../form_results_screen.dart';
import '../templates/templates_list_screen.dart';
import '../templates/template_builder_screen.dart';

class FormsListScreen extends StatefulWidget {
  const FormsListScreen({Key? key}) : super(key: key);

  @override
  State<FormsListScreen> createState() => _FormsListScreenState();
}

class _FormsListScreenState extends State<FormsListScreen>
    with AutomaticKeepAliveClientMixin {
  final _formsService = FormsService();
  String _typeFilter = 'all';

  /// Key to force stream recreation on refresh
  int _refreshKey = 0;

  @override
  bool get wantKeepAlive => true;

  /// Force refresh by incrementing key to recreate stream
  Future<void> _refreshForms() async {
    setState(() {
      _refreshKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final padding = isMobile ? 12.0 : 16.0;

    return Scaffold(
      body: Column(
        children: [
          // Filter Chips and Templates button
          Container(
            padding: EdgeInsets.all(padding),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All', 'all', isMobile: isMobile),
                        SizedBox(width: isMobile ? 6 : 8),
                        _buildFilterChip('Survey', 'survey', isMobile: isMobile),
                        SizedBox(width: isMobile ? 6 : 8),
                        _buildFilterChip('Registration', 'registration', isMobile: isMobile),
                        SizedBox(width: isMobile ? 6 : 8),
                        _buildFilterChip('Feedback', 'feedback', isMobile: isMobile),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _openTemplates,
                  icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
                  label: Text(isMobile ? 'Templates' : 'Manage Templates'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: isMobile ? 8 : 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Forms List
          Expanded(
            child: StreamBuilder<List<FormSchema>>(
              // Use key to force stream recreation on refresh
              key: ValueKey('forms_stream_${_typeFilter}_$_refreshKey'),
              stream: _formsService.watchForms(_typeFilter),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final forms = snapshot.data ?? [];

                if (forms.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: isMobile ? 48 : 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: isMobile ? 12 : 16),
                          Text(
                            'No forms yet',
                            style: TextStyle(
                              fontSize: isMobile ? 16 : 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: isMobile ? 12 : 8),
                          ElevatedButton.icon(
                            onPressed: _createNewForm,
                            icon: const Icon(Icons.add),
                            label: const Text('Create Form'),
                            style: isMobile
                                ? ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshForms,
                  child: ListView.builder(
                    padding: EdgeInsets.all(padding),
                    itemCount: forms.length,
                    itemBuilder: (context, index) {
                      final form = forms[index];
                      return FormCard(
                        form: form,
                        // Tap opens results view (or edit if no submissions)
                        onTap: form.submissionCount > 0
                            ? () => _viewResults(form)
                            : () => _editForm(form),
                        onEdit: () => _editForm(form),
                        onViewResults: form.submissionCount > 0
                            ? () => _viewResults(form)
                            : null,
                        onDelete: () => _confirmDeleteForm(form),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateOptions,
        tooltip: 'Create Form',
        icon: const Icon(Icons.add),
        label: const Text('Create Form'),
      ),
    );
  }

  void _showCreateOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Blank Form'),
              subtitle: const Text('Start from scratch'),
              onTap: () {
                Navigator.pop(context);
                _createNewForm();
              },
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_customize_outlined),
              title: const Text('From Template'),
              subtitle: const Text('Use a pre-built template'),
              onTap: () {
                Navigator.pop(context);
                _createFromTemplate();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _createFromTemplate() async {
    final template = await Navigator.push<FormTemplateDb>(
      context,
      MaterialPageRoute(
        builder: (_) => const TemplatesListScreen(pickerMode: true),
      ),
    );

    if (template != null && mounted) {
      // Navigate to form builder with template pre-filled
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FormBuilderScreen(templateToApply: template),
        ),
      );
    }
  }

  void _openTemplates() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Form Templates')),
          body: const TemplatesListScreen(),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, {bool isMobile = false}) {
    final isSelected = _typeFilter == value;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(fontSize: isMobile ? 12 : 14),
      ),
      selected: isSelected,
      visualDensity: isMobile ? VisualDensity.compact : VisualDensity.standard,
      padding: isMobile ? const EdgeInsets.symmetric(horizontal: 4) : null,
      onSelected: (selected) {
        setState(() {
          _typeFilter = value;
        });
      },
    );
  }

  void _createNewForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FormBuilderScreen(),
      ),
    );
  }

  void _editForm(FormSchema form) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormBuilderScreen(formId: form.id),
      ),
    );
  }

  void _viewForm(FormSchema form) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormSubmissionScreen(formId: form.id),
      ),
    );
  }

  void _viewResults(FormSchema form) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormResultsScreen(formId: form.id),
      ),
    );
  }

  void _confirmDeleteForm(FormSchema form) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Form'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${form.title}"?',
            ),
            if (form.submissionCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will also delete ${form.submissionCount} submission${form.submissionCount == 1 ? '' : 's'}.',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'This action cannot be undone.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _formsService.deleteForm(form.id);
                if (mounted) {
                  // Refresh the list after deletion
                  await _refreshForms();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Form deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete form: $e'),
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
}
