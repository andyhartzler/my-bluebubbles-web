import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import '../models/form_schema.dart';
import '../services/forms_service.dart';
import '../widgets/form_field_renderer.dart';

/// Screen for filling out and submitting a form
class FormSubmissionScreen extends StatefulWidget {
  final String formId;

  const FormSubmissionScreen({
    Key? key,
    required this.formId,
  }) : super(key: key);

  @override
  State<FormSubmissionScreen> createState() => _FormSubmissionScreenState();
}

class _FormSubmissionScreenState extends State<FormSubmissionScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _formsService = FormsService();

  FormSchema? _formSchema;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  Future<void> _loadForm() async {
    try {
      final form = await _formsService.getForm(widget.formId);
      setState(() {
        _formSchema = form;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading form: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_formSchema == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Form Not Found')),
        body: const Center(child: Text('Form not found')),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final padding = isMobile ? 12.0 : 16.0;
    // Account for keyboard on mobile
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _formSchema!.title,
          style: TextStyle(fontSize: isMobile ? 16 : 20),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_formSchema!.description != null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showFormInfo,
              tooltip: 'Form Info',
            ),
        ],
      ),
      body: GestureDetector(
        // Dismiss keyboard when tapping outside form fields
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(padding, padding, padding, padding + bottomPadding),
          child: FormBuilder(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Form header
                if (_formSchema!.description != null) ...[
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info, color: Colors.blue[700], size: isMobile ? 20 : 24),
                          SizedBox(width: isMobile ? 12 : 16),
                          Expanded(
                            child: Text(
                              _formSchema!.description!,
                              style: TextStyle(
                                color: Colors.blue[900],
                                fontSize: isMobile ? 13 : 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: isMobile ? 16 : 24),
                ],

                // Form type badge
                Chip(
                  label: Text(
                    _formSchema!.formType.toUpperCase(),
                    style: TextStyle(fontSize: isMobile ? 11 : 12),
                  ),
                  avatar: Icon(
                    _getFormTypeIcon(_formSchema!.formType),
                    size: isMobile ? 14 : 16,
                  ),
                  visualDensity: isMobile ? VisualDensity.compact : VisualDensity.standard,
                ),
                SizedBox(height: isMobile ? 16 : 24),

                // Render all fields
                ..._formSchema!.schema.fields.map((field) {
                  return FormFieldRenderer(
                    key: ValueKey(field.id),
                    config: field,
                    formKey: _formKey,
                  );
                }).toList(),

                SizedBox(height: isMobile ? 16 : 24),

                // Submit button - larger touch target on mobile
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 16),
                      backgroundColor: Colors.green,
                      minimumSize: Size(double.infinity, isMobile ? 48 : 44),
                    ),
                    child: _isSubmitting
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: isMobile ? 18 : 20,
                                height: isMobile ? 18 : 20,
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Submitting...',
                                style: TextStyle(fontSize: isMobile ? 14 : 16),
                              ),
                            ],
                          )
                        : Text(
                            'Submit Form',
                            style: TextStyle(fontSize: isMobile ? 16 : 18),
                          ),
                  ),
                ),

                SizedBox(height: isMobile ? 12 : 16),

                // Privacy/info text
                if (_formSchema!.schema.confirmation?['message'] != null)
                  Card(
                    color: Colors.grey[100],
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 10 : 12),
                      child: Text(
                        _formSchema!.schema.confirmation!['message'] as String,
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getFormTypeIcon(String formType) {
    switch (formType) {
      case 'survey':
        return Icons.poll;
      case 'registration':
        return Icons.how_to_reg;
      case 'feedback':
        return Icons.feedback;
      default:
        return Icons.description;
    }
  }

  void _showFormInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_formSchema!.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_formSchema!.description != null) ...[
              const Text(
                'Description:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_formSchema!.description!),
              const SizedBox(height: 16),
            ],
            const Text(
              'Details:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Type: ${_formSchema!.formType}'),
            Text('Fields: ${_formSchema!.schema.fields.length}'),
            Text('Required fields: ${_formSchema!.schema.fields.where((f) => f.required).length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitForm() async {
    // Validate form
    if (!_formKey.currentState!.saveAndValidate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors in the form'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Get form values
      final formData = _formKey.currentState!.value;

      // TODO: Get actual member/user info
      final memberId = 'anonymous'; // Replace with actual member ID
      final submitterEmail = 'user@example.com'; // Replace with actual email
      final submitterName = 'Anonymous User'; // Replace with actual name

      // Submit to service
      await _formsService.createSubmission(
        formId: widget.formId,
        memberId: memberId,
        submissionData: formData,
        submitterEmail: submitterEmail,
        submitterName: submitterName,
      );

      if (mounted) {
        // Show success message
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                SizedBox(width: 16),
                Text('Success!'),
              ],
            ),
            content: Text(
              _formSchema!.schema.confirmation?['message'] as String? ??
                  'Your form has been submitted successfully.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to previous screen
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting form: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
