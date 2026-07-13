import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/form_schema.dart';
import '../models/form_submission.dart';
import '../models/form_field_config.dart';
import '../widgets/submission_status_badge.dart';
import '../services/forms_service.dart';
import '../../../models/crm/member.dart';
import '../../../models/crm/subscriber.dart';
import '../../../screens/crm/member_detail_screen.dart';
import '../../../services/crm/member_repository.dart';
import '../../../services/crm/subscriber_repository.dart';

/// Beautiful submission detail screen showing all field responses
class SubmissionDetailScreen extends StatefulWidget {
  /// Constructor with pre-loaded data
  final FormSubmission? submission;
  final FormSchema? form;

  /// Constructor with IDs to load data
  final String? formId;
  final String? submissionId;

  const SubmissionDetailScreen({
    Key? key,
    this.submission,
    this.form,
    this.formId,
    this.submissionId,
  })  : assert(
          (submission != null && form != null) ||
              (formId != null && submissionId != null),
          'Either provide submission+form or formId+submissionId',
        ),
        super(key: key);

  /// Named constructor for loading by IDs
  const SubmissionDetailScreen.byId({
    Key? key,
    required String formId,
    required String submissionId,
  }) : this(key: key, formId: formId, submissionId: submissionId);

  @override
  State<SubmissionDetailScreen> createState() => _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState extends State<SubmissionDetailScreen> {
  final MemberRepository _memberRepo = MemberRepository();
  final SubscriberRepository _subscriberRepo = SubscriberRepository();
  final FormsService _formsService = FormsService();

  Member? _linkedMember;
  Subscriber? _linkedSubscriber;
  bool _loadingLinkedPerson = false;

  // For loading by IDs
  FormSubmission? _loadedSubmission;
  FormSchema? _loadedForm;
  bool _isLoading = true;
  String? _loadError;

  FormSubmission? get submission => widget.submission ?? _loadedSubmission;
  FormSchema? get form => widget.form ?? _loadedForm;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // If data was provided directly, use it
    if (widget.submission != null && widget.form != null) {
      setState(() => _isLoading = false);
      _loadLinkedPerson();
      return;
    }

    // Otherwise load by IDs
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final results = await Future.wait([
        _formsService.getSubmission(widget.submissionId!),
        _formsService.getForm(widget.formId!),
      ]);

      final loadedSubmission = results[0] as FormSubmission?;
      final loadedForm = results[1] as FormSchema;

      if (loadedSubmission == null) {
        setState(() {
          _loadError = 'Submission not found';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _loadedSubmission = loadedSubmission;
        _loadedForm = loadedForm;
        _isLoading = false;
      });

      _loadLinkedPerson();
    } catch (e) {
      setState(() {
        _loadError = 'Failed to load submission: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLinkedPerson() async {
    // Skip if no submission loaded or no linked IDs
    if (submission == null) return;
    if (submission!.memberId == null && submission!.subscriberId == null) {
      return;
    }

    setState(() => _loadingLinkedPerson = true);

    try {
      // Prefer member over subscriber
      if (submission!.memberId != null) {
        final member = await _memberRepo.getMemberById(submission!.memberId!);
        if (mounted && member != null) {
          setState(() => _linkedMember = member);
        }
      }

      // Also load subscriber for additional context
      if (submission!.subscriberId != null) {
        final subscriber = await _subscriberRepo.fetchSubscriberById(submission!.subscriberId!);
        if (mounted && subscriber != null) {
          setState(() => _linkedSubscriber = subscriber);
        }
      }
    } catch (e) {
      debugPrint('Error loading linked person: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingLinkedPerson = false);
      }
    }
  }

  void _navigateToMemberProfile() {
    if (_linkedMember != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MemberDetailScreen(member: _linkedMember!),
        ),
      );
    }
  }

  void _navigateToSubscriberProfile() {
    // Show subscriber detail sheet
    if (_linkedSubscriber != null) {
      _showSubscriberDetailSheet(_linkedSubscriber!);
    }
  }

  Future<void> _showSubscriberDetailSheet(Subscriber subscriber) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SubscriberDetailBottomSheet(subscriber: subscriber),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submission Details'),
        actions: [
          if (!_isLoading && submission != null)
            IconButton(
              icon: const Icon(Icons.content_copy),
              onPressed: () => _copySubmission(context),
              tooltip: 'Copy to clipboard',
            ),
        ],
      ),
      body: _buildBody(context, theme),
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme) {
    // Show loading state
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Show error state
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                _loadError!,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Show empty state if no data
    if (submission == null || form == null) {
      return const Center(
        child: Text('No submission data available'),
      );
    }

    return SingleChildScrollView(
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

          // Field responses.
          // Skip display-only field types (they carry no answer of their own)
          // and conditional fields the applicant never triggered, so we don't
          // render spurious "No response" cards.
          ...form!.schema.fields.where((field) {
            const displayOnly = {'section_header', 'reference_block'};
            if (displayOnly.contains(field.type)) return false;
            return field.isVisibleFor(submission!.data);
          }).map((field) {
            final value = submission!.data[field.id];
            return _buildFieldResponseCard(context, field, value);
          }),

          // References are stored under flat ref_N_* keys (not schema field
          // ids), so render them from a dedicated card where the
          // reference_block field would otherwise have appeared.
          ...(() {
            final refCard = _buildReferencesCard(context);
            return refCard != null ? [refCard] : const <Widget>[];
          })(),

          const SizedBox(height: 24),

          // Metadata section
          _buildMetadataCard(context),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine display info - prefer member, then subscriber, then raw submission
    final hasLinkedMember = _linkedMember != null;
    final hasLinkedSubscriber = _linkedSubscriber != null && !hasLinkedMember;
    final hasLinkedPerson = hasLinkedMember || hasLinkedSubscriber;

    String displayName;
    String? displayEmail;
    String? displayPhone;
    String? profilePhotoUrl;

    if (hasLinkedMember) {
      displayName = _linkedMember!.name;
      displayEmail = _linkedMember!.email;
      displayPhone = _linkedMember!.phoneE164 ?? _linkedMember!.phone;
      profilePhotoUrl = _linkedMember!.profilePhotos.isNotEmpty
          ? _linkedMember!.profilePhotos.first.publicUrl
          : null;
    } else if (hasLinkedSubscriber) {
      displayName = _linkedSubscriber!.name;
      displayEmail = _linkedSubscriber!.email;
      displayPhone = _linkedSubscriber!.phoneE164 ?? _linkedSubscriber!.phone;
      profilePhotoUrl = null;
    } else {
      displayName = submission!.displayName;
      displayEmail = submission!.displayEmail;
      displayPhone = submission!.submitterPhone;
      profilePhotoUrl = null;
    }

    final isAnonymous = displayName == 'Anonymous' && !hasLinkedPerson;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: hasLinkedMember
            ? _navigateToMemberProfile
            : (hasLinkedSubscriber ? _navigateToSubscriberProfile : null),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Profile avatar with photo support
              _buildProfileAvatar(
                context,
                displayName: displayName,
                photoUrl: profilePhotoUrl,
                hasLinkedPerson: hasLinkedPerson,
                isAnonymous: isAnonymous,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name with link indicator
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: hasLinkedPerson
                                  ? colorScheme.primary
                                  : null,
                            ),
                          ),
                        ),
                        if (hasLinkedPerson) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: hasLinkedMember
                                  ? Colors.blue.withOpacity(0.1)
                                  : Colors.teal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasLinkedMember
                                      ? Icons.person
                                      : Icons.contact_mail,
                                  size: 12,
                                  color: hasLinkedMember
                                      ? Colors.blue
                                      : Colors.teal,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  hasLinkedMember ? 'Member' : 'Subscriber',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: hasLinkedMember
                                        ? Colors.blue
                                        : Colors.teal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (displayEmail != null && displayEmail != displayName) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              displayEmail,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (displayPhone != null && displayPhone.isNotEmpty) ...[
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
                            displayPhone,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Show tap hint for linked profiles
                    if (hasLinkedPerson) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.open_in_new,
                            size: 14,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tap to view profile',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Status badge using new widget
              SubmissionStatusBadge(status: submission!.status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(
    BuildContext context, {
    required String displayName,
    String? photoUrl,
    bool hasLinkedPerson = false,
    bool isAnonymous = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    // Determine avatar color
    Color backgroundColor;
    Color foregroundColor;
    if (hasLinkedPerson) {
      backgroundColor = colorScheme.primaryContainer;
      foregroundColor = colorScheme.onPrimaryContainer;
    } else if (isAnonymous) {
      backgroundColor = Colors.grey.shade200;
      foregroundColor = Colors.grey.shade600;
    } else {
      backgroundColor = colorScheme.secondaryContainer;
      foregroundColor = colorScheme.onSecondaryContainer;
    }

    // Get initial
    String initial = '?';
    if (displayName.isNotEmpty && displayName != 'Anonymous') {
      initial = displayName[0].toUpperCase();
    }

    // If we have a photo URL, show the image
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return Stack(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundImage: NetworkImage(photoUrl),
            backgroundColor: backgroundColor,
            onBackgroundImageError: (_, __) {},
          ),
          if (_loadingLinkedPerson)
            Positioned.fill(
              child: CircleAvatar(
                radius: 32,
                backgroundColor: Colors.black26,
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    // Otherwise show initial avatar
    return Stack(
      children: [
        CircleAvatar(
          backgroundColor: backgroundColor,
          radius: 32,
          child: Text(
            initial,
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ),
        if (_loadingLinkedPerson)
          Positioned.fill(
            child: CircleAvatar(
              radius: 32,
              backgroundColor: Colors.black26,
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
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

      case 'file_upload':
      case 'file_picker':
      case 'image_picker':
        return _buildFileValue(context, field, value);

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

  /// Files are stored as arrays of objects [{url, name, storage_path, type}]
  /// (or occasionally a single object / bare url string). Image files render
  /// as tappable thumbnails; other files as a tappable row that opens the url.
  Widget _buildFileValue(BuildContext context, FormFieldConfig field, dynamic value) {
    final files = <Map<String, dynamic>>[];
    if (value is List) {
      for (final v in value) {
        if (v is Map) {
          files.add(v.map((k, val) => MapEntry(k.toString(), val)));
        } else if (v is String && v.isNotEmpty) {
          files.add({'url': v, 'name': v});
        }
      }
    } else if (value is Map) {
      files.add(value.map((k, val) => MapEntry(k.toString(), val)));
    } else if (value is String && value.isNotEmpty) {
      files.add({'url': value, 'name': value});
    }

    if (files.isEmpty) {
      return _buildTextValue(context, value);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < files.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _buildSingleFile(context, field, files[i]),
        ],
      ],
    );
  }

  Widget _buildSingleFile(
    BuildContext context,
    FormFieldConfig field,
    Map<String, dynamic> file,
  ) {
    final url = file['url']?.toString() ?? '';
    final rawName = file['name']?.toString();
    final name = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : (url.isNotEmpty ? url.split('/').last : 'File');
    final mime = file['type']?.toString() ?? '';
    final lowerName = name.toLowerCase();
    final isImage = field.type == 'image_picker' ||
        mime.startsWith('image/') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.gif') ||
        lowerName.endsWith('.webp');

    if (isImage && url.isNotEmpty) {
      return InkWell(
        onTap: () => _openUrl(url),
        borderRadius: BorderRadius.circular(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildFileRow(context, name, url),
          ),
        ),
      );
    }

    return _buildFileRow(context, name, url);
  }

  Widget _buildFileRow(BuildContext context, String name, String url) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: url.isEmpty ? null : () => _openUrl(url),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.attach_file, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  decoration:
                      url.isEmpty ? null : TextDecoration.underline,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (url.isNotEmpty) ...[
              const SizedBox(width: 8),
              Icon(Icons.open_in_new, size: 16, color: colorScheme.primary),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Failed to open url $url: $e');
    }
  }

  Widget _buildSignatureValue(BuildContext context, dynamic value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final str = value?.toString() ?? '';

    if (str.startsWith('http')) {
      return Container(
        padding: const EdgeInsets.all(12),
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
                  'Signature',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                str,
                height: 120,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                errorBuilder: (context, error, stackTrace) => Text(
                  'Signature on file',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.draw, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            'Signature on file',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Renders the applicant's references (stored under flat ref_1_*, ref_2_*,
  /// ref_3_* keys) as grouped "Reference N" cards. Returns null when no
  /// reference has any data so the section is omitted entirely.
  Widget? _buildReferencesCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final data = submission!.data;

    final references = <int, Map<String, String>>{};
    for (int i = 1; i <= 3; i++) {
      final fields = <String, String>{};
      void add(String label, String key) {
        final v = data['ref_${i}_$key'];
        if (v != null && v.toString().trim().isNotEmpty) {
          fields[label] = v.toString();
        }
      }

      add('Name', 'name');
      add('Relationship', 'relationship');
      add('Phone', 'phone');
      add('Email', 'email');
      if (fields.isNotEmpty) references[i] = fields;
    }

    if (references.isEmpty) return null;

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
                Icon(Icons.people_outline, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'References',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final entry in references.entries) ...[
              if (entry.key != references.keys.first)
                const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reference ${entry.key}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final f in entry.value.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 96,
                              child: Text(
                                f.key,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                f.value,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
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
            _buildMetadataRow(context, 'Submission ID', submission!.id),
            _buildMetadataRow(context, 'Form ID', submission!.formId),
            if (submission!.memberId != null)
              _buildMetadataRow(context, 'Member ID', submission!.memberId!),
            _buildMetadataRow(
              context,
              'Submitted At',
              _formatDateTime(submission!.createdAt),
            ),
            _buildMetadataRow(context, 'Status', submission!.status),
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
    if (submission == null || form == null) return;

    final buffer = StringBuffer();
    buffer.writeln('Form: ${form!.title}');
    buffer.writeln('Submitted: ${_formatDateTime(submission!.createdAt)}');
    buffer.writeln('');

    if (submission!.submitterName != null) {
      buffer.writeln('Name: ${submission!.submitterName}');
    }
    if (submission!.submitterEmail != null) {
      buffer.writeln('Email: ${submission!.submitterEmail}');
    }
    if (submission!.submitterPhone != null) {
      buffer.writeln('Phone: ${submission!.submitterPhone}');
    }
    buffer.writeln('');
    buffer.writeln('Responses:');

    for (final field in form!.schema.fields) {
      final value = submission!.data[field.id];
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

/// Bottom sheet for displaying subscriber details
class _SubscriberDetailBottomSheet extends StatelessWidget {
  final Subscriber subscriber;

  const _SubscriberDetailBottomSheet({required this.subscriber});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.teal.withOpacity(0.1),
                      child: Text(
                        subscriber.name.isNotEmpty
                            ? subscriber.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subscriber.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.contact_mail,
                                size: 14,
                                color: Colors.teal,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Subscriber',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: Colors.teal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildInfoTile(
                      context,
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: subscriber.email,
                    ),
                    if (subscriber.phoneE164 != null)
                      _buildInfoTile(
                        context,
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: subscriber.phoneE164!,
                      ),
                    if (subscriber.city != null || subscriber.state != null)
                      _buildInfoTile(
                        context,
                        icon: Icons.location_on_outlined,
                        label: 'Location',
                        value:
                            '${subscriber.city ?? ''}${subscriber.city != null && subscriber.state != null ? ', ' : ''}${subscriber.state ?? ''}',
                      ),
                    if (subscriber.zipCode != null)
                      _buildInfoTile(
                        context,
                        icon: Icons.local_post_office_outlined,
                        label: 'Zip Code',
                        value: subscriber.zipCode!,
                      ),
                    if (subscriber.county != null)
                      _buildInfoTile(
                        context,
                        icon: Icons.map_outlined,
                        label: 'County',
                        value: subscriber.county!,
                      ),
                    if (subscriber.source != null)
                      _buildInfoTile(
                        context,
                        icon: Icons.source_outlined,
                        label: 'Source',
                        value: subscriber.source!,
                      ),
                    if (subscriber.subscribed != null)
                      _buildInfoTile(
                        context,
                        icon: subscriber.subscribed!
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        label: 'Subscription Status',
                        value: subscriber.subscribed! ? 'Subscribed' : 'Unsubscribed',
                        valueColor:
                            subscriber.subscribed! ? Colors.green : Colors.red,
                      ),
                    if (subscriber.donor != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Donor Information',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoTile(
                        context,
                        icon: Icons.volunteer_activism_outlined,
                        label: 'Total Donated',
                        value:
                            '\$${(subscriber.donor!.totalDonated ?? 0).toStringAsFixed(2)}',
                      ),
                      _buildInfoTile(
                        context,
                        icon: Icons.numbers,
                        label: 'Donation Count',
                        value: '${subscriber.donor!.donationCount}',
                      ),
                    ],
                    if (subscriber.notes != null &&
                        subscriber.notes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Notes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(subscriber.notes!),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
