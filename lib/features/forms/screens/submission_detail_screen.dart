import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/form_schema.dart';
import '../models/form_submission.dart';
import '../models/form_field_config.dart';

/// Beautiful submission detail screen showing all field responses
class SubmissionDetailScreen extends StatelessWidget {
  final FormSubmission submission;
  final FormSchema form;

  const SubmissionDetailScreen({
    Key? key,
    required this.submission,
    required this.form,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submission Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_copy),
            onPressed: () => _copySubmission(context),
            tooltip: 'Copy to clipboard',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card with submitter info
            _buildHeaderCard(context),
            const SizedBox(height: 20),

            // Responses section
            Text(
              'Responses',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Field responses
            ...form.schema.fields.map((field) {
              final value = submission.data[field.id];
              return _buildFieldResponseCard(context, field, value);
            }),

            const SizedBox(height: 24),

            // Metadata section
            _buildMetadataCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              radius: 32,
              child: Text(
                submission.displayInitial,
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    submission.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (submission.displayEmail != null && submission.displayEmail != submission.displayName) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          submission.displayEmail!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (submission.submitterPhone != null && submission.submitterPhone!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          submission.submitterPhone!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    submission.status,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldResponseCard(
    BuildContext context,
    FormFieldConfig field,
    dynamic value,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getFieldIcon(field.type),
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    field.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (field.required)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Required',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildValueDisplay(context, field, value),
          ],
        ),
      ),
    );
  }

  Widget _buildValueDisplay(
    BuildContext context,
    FormFieldConfig field,
    dynamic value,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (value == null || (value is String && value.isEmpty)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.remove_circle_outline,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              'No response',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    // Handle different field types
    switch (field.type) {
      case 'checkbox':
      case 'switch':
        return _buildBooleanValue(context, value);

      case 'rating':
        return _buildRatingValue(context, value);

      case 'checkbox_group':
      case 'filter_chips':
        return _buildMultiSelectValue(context, field, value);

      case 'dropdown':
      case 'radio':
      case 'choice_chips':
        return _buildSingleSelectValue(context, field, value);

      case 'date_picker':
      case 'time_picker':
      case 'date_time_picker':
        return _buildDateTimeValue(context, value);

      case 'color_picker':
        return _buildColorValue(context, value);

      case 'file_picker':
      case 'image_picker':
        return _buildFileValue(context, value);

      case 'signature_pad':
        return _buildSignatureValue(context, value);

      case 'slider':
      case 'range_slider':
      case 'touch_spin':
      case 'number':
        return _buildNumericValue(context, value);

      case 'textarea':
        return _buildLongTextValue(context, value);

      default:
        return _buildTextValue(context, value);
    }
  }

  Widget _buildBooleanValue(BuildContext context, dynamic value) {
    final isTrue = value == true || value == 'true' || value == 'yes';
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: (isTrue ? Colors.green : Colors.red).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isTrue ? Colors.green : Colors.red).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isTrue ? Icons.check_circle : Icons.cancel,
            color: isTrue ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            isTrue ? 'Yes' : 'No',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isTrue ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingValue(BuildContext context, dynamic value) {
    final rating = double.tryParse(value.toString()) ?? 0;
    final theme = Theme.of(context);

    return Row(
      children: [
        ...List.generate(5, (index) {
          return Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 28,
          );
        }),
        const SizedBox(width: 12),
        Text(
          rating.toStringAsFixed(1),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.amber.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildMultiSelectValue(
    BuildContext context,
    FormFieldConfig field,
    dynamic value,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    List<String> values = [];
    if (value is List) {
      values = value.map((v) => v.toString()).toList();
    } else if (value is String) {
      values = [value];
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((v) {
        final label = _getOptionLabel(field, v);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check,
                size: 16,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSingleSelectValue(
    BuildContext context,
    FormFieldConfig field,
    dynamic value,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final label = _getOptionLabel(field, value.toString());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.radio_button_checked,
            size: 18,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeValue(BuildContext context, dynamic value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String formattedDate;
    try {
      final date = DateTime.parse(value.toString());
      formattedDate =
          '${date.month}/${date.day}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      formattedDate = value.toString();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            formattedDate,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorValue(BuildContext context, dynamic value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color color;
    try {
      final hex = value.toString().replaceAll('#', '');
      color = Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colorScheme.outline),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value.toString().toUpperCase(),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileValue(BuildContext context, dynamic value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.attach_file,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureValue(BuildContext context, dynamic value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Signature is usually base64 encoded image
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.draw, size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'Signature provided',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          // TODO: Render actual signature if it's a base64 image
        ],
      ),
    );
  }

  Widget _buildNumericValue(BuildContext context, dynamic value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value.toString(),
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _buildLongTextValue(BuildContext context, dynamic value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Text(
        value.toString(),
        style: theme.textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildTextValue(BuildContext context, dynamic value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value.toString(),
        style: theme.textTheme.bodyLarge,
      ),
    );
  }

  Widget _buildMetadataCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Submission Info',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildMetadataRow(context, 'Submission ID', submission.id),
            _buildMetadataRow(context, 'Form ID', submission.formId),
            if (submission.memberId != null)
              _buildMetadataRow(context, 'Member ID', submission.memberId!),
            _buildMetadataRow(
              context,
              'Submitted At',
              _formatDateTime(submission.createdAt),
            ),
            _buildMetadataRow(context, 'Status', submission.status),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getOptionLabel(FormFieldConfig field, String value) {
    if (field.options != null) {
      final option = field.options!.where((o) => o.value == value).firstOrNull;
      if (option != null) return option.label;
    }
    return value;
  }

  IconData _getFieldIcon(String type) {
    switch (type) {
      case 'text':
      case 'textarea':
        return Icons.text_fields;
      case 'email':
        return Icons.email_outlined;
      case 'phone':
        return Icons.phone_outlined;
      case 'url':
        return Icons.link;
      case 'number':
      case 'slider':
      case 'touch_spin':
        return Icons.numbers;
      case 'dropdown':
        return Icons.arrow_drop_down_circle_outlined;
      case 'radio':
        return Icons.radio_button_checked;
      case 'checkbox':
      case 'checkbox_group':
        return Icons.check_box_outlined;
      case 'switch':
        return Icons.toggle_on_outlined;
      case 'rating':
        return Icons.star_outline;
      case 'date_picker':
        return Icons.calendar_today;
      case 'time_picker':
        return Icons.access_time;
      case 'date_time_picker':
        return Icons.event;
      case 'color_picker':
        return Icons.palette_outlined;
      case 'file_picker':
        return Icons.attach_file;
      case 'image_picker':
        return Icons.image_outlined;
      case 'signature_pad':
        return Icons.draw_outlined;
      case 'choice_chips':
      case 'filter_chips':
        return Icons.label_outlined;
      default:
        return Icons.input;
    }
  }

  String _formatDateTime(DateTime date) {
    return '${date.month}/${date.day}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _copySubmission(BuildContext context) {
    final buffer = StringBuffer();
    buffer.writeln('Form: ${form.title}');
    buffer.writeln('Submitted: ${_formatDateTime(submission.createdAt)}');
    buffer.writeln('');

    if (submission.submitterName != null) {
      buffer.writeln('Name: ${submission.submitterName}');
    }
    if (submission.submitterEmail != null) {
      buffer.writeln('Email: ${submission.submitterEmail}');
    }
    if (submission.submitterPhone != null) {
      buffer.writeln('Phone: ${submission.submitterPhone}');
    }
    buffer.writeln('');
    buffer.writeln('Responses:');

    for (final field in form.schema.fields) {
      final value = submission.data[field.id];
      buffer.writeln('${field.label}: ${value ?? 'No response'}');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Submission copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
