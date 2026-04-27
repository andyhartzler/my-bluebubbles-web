import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/form_field_config.dart';
import '../models/form_field_types.dart';
import '../models/form_validators.dart';
import '../models/identity_config.dart';

/// Comprehensive field configuration dialog for all field types
class FieldConfigDialog extends StatefulWidget {
  final FormFieldConfig? existingField;
  final Function(FormFieldConfig) onSave;

  const FieldConfigDialog({
    Key? key,
    this.existingField,
    required this.onSave,
  }) : super(key: key);

  @override
  State<FieldConfigDialog> createState() => _FieldConfigDialogState();
}

class _FieldConfigDialogState extends State<FieldConfigDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Controllers for text fields
  final _labelController = TextEditingController();
  final _placeholderController = TextEditingController();
  final _helpController = TextEditingController();

  // Controllers for numeric fields to avoid glitchiness
  final _minValueController = TextEditingController();
  final _maxValueController = TextEditingController();
  final _initialValueController = TextEditingController();
  final _stepController = TextEditingController();
  final _divisionsController = TextEditingController();
  final _minLinesController = TextEditingController();
  final _maxLinesController = TextEditingController();
  final _maxLengthController = TextEditingController();

  // Basic properties
  String _fieldType = FormFieldTypes.text;
  bool _required = false;
  bool _enabled = true;

  // Date properties
  DateTime? _firstDate;
  DateTime? _lastDate;

  // Options for dropdowns, radio, etc.
  List<FormFieldOption> _options = [];

  // Selected validators
  List<String> _selectedValidators = [];
  Map<String, dynamic> _validatorConfigs = {};

  // Smart-form prefilled-confirm metadata. Only surfaced when the author
  // picks `prefilled_confirm` from the field-type dropdown — and only sent
  // back through onSave when meaningful. See migration
  // 20260507_01_prefill_endorsement_for_candidate.sql for the contract.
  String? _prefillSource;
  String? _prefillFormat;
  String _fallbackQuestionType = FormFieldTypes.text;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load existing field if editing
    if (widget.existingField != null) {
      final field = widget.existingField!;
      _labelController.text = field.label;
      _placeholderController.text = field.placeholder ?? '';
      _helpController.text = field.help ?? '';
      _fieldType = field.type;
      _required = field.required;
      _enabled = field.enabled;

      // Populate numeric field controllers
      _maxLengthController.text = field.maxLength?.toString() ?? '';
      _minLinesController.text = field.minLines?.toString() ?? '';
      _maxLinesController.text = field.maxLines?.toString() ?? '';
      _minValueController.text = field.minValue?.toString() ?? '';
      _maxValueController.text = field.maxValue?.toString() ?? '';
      _initialValueController.text = field.initialValue?.toString() ?? '';
      _stepController.text = field.step?.toString() ?? '';
      _divisionsController.text = field.divisions?.toString() ?? '';

      _firstDate = field.firstDate;
      _lastDate = field.lastDate;
      // Create mutable copies of lists (Freezed returns immutable lists)
      _options = List.from(field.options ?? []);
      _selectedValidators = List.from(field.validatorTypes ?? []);
      _validatorConfigs = Map.from(field.validation ?? {});

      // Smart-form metadata
      _prefillSource = field.prefillSource;
      _prefillFormat = field.prefillFormat;
      _fallbackQuestionType = field.fallbackQuestionType ?? FormFieldTypes.text;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _labelController.dispose();
    _placeholderController.dispose();
    _helpController.dispose();
    _minValueController.dispose();
    _maxValueController.dispose();
    _initialValueController.dispose();
    _stepController.dispose();
    _divisionsController.dispose();
    _minLinesController.dispose();
    _maxLinesController.dispose();
    _maxLengthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;

    // Responsive dialog sizing
    final dialogWidth = isMobile
        ? screenWidth * 0.95  // Nearly full width on mobile
        : screenWidth > 1200
            ? 800.0  // Max width on large screens
            : screenWidth * 0.8;

    final dialogHeight = isMobile
        ? screenHeight * 0.9  // More height on mobile for scrolling
        : screenHeight * 0.8;

    final padding = isMobile ? 12.0 : 16.0;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        constraints: BoxConstraints(
          minWidth: 280,
          maxWidth: 900,
          minHeight: 400,
          maxHeight: screenHeight * 0.95,
        ),
        padding: EdgeInsets.all(padding),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.existingField == null ? 'Add Field' : 'Edit Field',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: isMobile ? 18 : 24,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
            const Divider(),

            // Tabs - responsive layout
            TabBar(
              controller: _tabController,
              labelPadding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 16),
              tabs: [
                Tab(
                  text: isMobile ? null : 'Basic',
                  icon: const Icon(Icons.settings),
                  iconMargin: EdgeInsets.only(bottom: isMobile ? 0 : 4),
                ),
                Tab(
                  text: isMobile ? null : 'Properties',
                  icon: const Icon(Icons.tune),
                  iconMargin: EdgeInsets.only(bottom: isMobile ? 0 : 4),
                ),
                Tab(
                  text: isMobile ? null : 'Validation',
                  icon: const Icon(Icons.verified_user),
                  iconMargin: EdgeInsets.only(bottom: isMobile ? 0 : 4),
                ),
              ],
            ),

            // Tab content
            Expanded(
              child: Form(
                key: _formKey,
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildBasicTab(isMobile: isMobile),
                    _buildPropertiesTab(isMobile: isMobile),
                    _buildValidationTab(isMobile: isMobile),
                  ],
                ),
              ),
            ),

            // Action buttons - stack vertically on mobile
            const Divider(),
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: _saveField,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Save Field'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveField,
                    child: const Text('Save Field'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicTab({bool isMobile = false}) {
    final padding = isMobile ? 12.0 : 16.0;
    final spacing = isMobile ? 12.0 : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field Type Selector
          Text(
            'Field Type',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: isMobile ? 14 : 16,
            ),
          ),
          SizedBox(height: isMobile ? 6 : 8),
          _buildFieldTypeSelector(isMobile: isMobile),
          SizedBox(height: isMobile ? 16 : 24),

          // Label
          TextFormField(
            controller: _labelController,
            decoration: InputDecoration(
              labelText: 'Field Label *',
              border: const OutlineInputBorder(),
              helperText: isMobile ? null : 'The label shown above the field',
              contentPadding: isMobile
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
                  : null,
            ),
            style: TextStyle(fontSize: isMobile ? 14 : 16),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Label is required';
              }
              return null;
            },
          ),
          SizedBox(height: spacing),

          // Placeholder
          TextFormField(
            controller: _placeholderController,
            decoration: InputDecoration(
              labelText: 'Placeholder',
              border: const OutlineInputBorder(),
              helperText: isMobile ? null : 'Hint text shown in the field',
              contentPadding: isMobile
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
                  : null,
            ),
            style: TextStyle(fontSize: isMobile ? 14 : 16),
          ),
          SizedBox(height: spacing),

          // Help Text
          TextFormField(
            controller: _helpController,
            decoration: InputDecoration(
              labelText: 'Help Text',
              border: const OutlineInputBorder(),
              helperText: isMobile ? null : 'Additional help text shown below the field',
              contentPadding: isMobile
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
                  : null,
            ),
            style: TextStyle(fontSize: isMobile ? 14 : 16),
            maxLines: 2,
          ),
          SizedBox(height: spacing),

          // Required & Enabled switches - more compact on mobile
          SwitchListTile(
            title: Text(
              'Required Field',
              style: TextStyle(fontSize: isMobile ? 14 : 16),
            ),
            subtitle: isMobile
                ? null
                : const Text('User must fill this field'),
            value: _required,
            dense: isMobile,
            contentPadding: isMobile ? EdgeInsets.zero : null,
            onChanged: (value) => setState(() => _required = value),
          ),
          SwitchListTile(
            title: Text(
              'Enabled',
              style: TextStyle(fontSize: isMobile ? 14 : 16),
            ),
            subtitle: isMobile
                ? null
                : const Text('Field can be edited'),
            value: _enabled,
            dense: isMobile,
            contentPadding: isMobile ? EdgeInsets.zero : null,
            onChanged: (value) => setState(() => _enabled = value),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldTypeSelector({bool isMobile = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: FormFieldTypes.categorizedTypes.entries.map((category) {
        return ExpansionTile(
          title: Text(
            category.key,
            style: TextStyle(fontSize: isMobile ? 14 : 16),
          ),
          tilePadding: isMobile ? const EdgeInsets.symmetric(horizontal: 8) : null,
          childrenPadding: isMobile ? EdgeInsets.zero : null,
          initiallyExpanded: category.value.any((field) => field.value == _fieldType),
          children: category.value.map((fieldType) {
            return RadioListTile<String>(
              title: Text(
                fieldType.label,
                style: TextStyle(fontSize: isMobile ? 13 : 14),
              ),
              subtitle: isMobile
                  ? null
                  : Text(
                      fieldType.description,
                      style: const TextStyle(fontSize: 12),
                    ),
              value: fieldType.value,
              groupValue: _fieldType,
              dense: isMobile,
              contentPadding: isMobile
                  ? const EdgeInsets.symmetric(horizontal: 8)
                  : null,
              onChanged: (value) {
                setState(() {
                  _fieldType = value!;
                  // Reset type-specific properties
                  _options = [];
                  _minValueController.clear();
                  _maxValueController.clear();
                });
              },
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildPropertiesTab({bool isMobile = false}) {
    final padding = isMobile ? 12.0 : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Field-Specific Properties',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: isMobile ? 14 : 16,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),

          // Show different properties based on field type
          if (FormFieldTypes.isPrefilledConfirm(_fieldType)) ...[
            _buildPrefilledConfirmProperties(isMobile: isMobile),
          ] else if (FormFieldTypes.requiresOptions(_fieldType)) ...[
            _buildOptionsEditor(isMobile: isMobile),
          ] else if (FormFieldTypes.isNumeric(_fieldType)) ...[
            _buildNumericProperties(isMobile: isMobile),
          ] else if (FormFieldTypes.isDateTime(_fieldType)) ...[
            _buildDateTimeProperties(isMobile: isMobile),
          ] else if (_fieldType == FormFieldTypes.textarea) ...[
            _buildTextAreaProperties(isMobile: isMobile),
          ] else if (_fieldType == FormFieldTypes.colorPicker) ...[
            _buildColorPickerProperties(isMobile: isMobile),
          ] else if (_fieldType == FormFieldTypes.rating) ...[
            _buildRatingProperties(isMobile: isMobile),
          ] else ...[
            Center(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 24 : 32),
                child: Text(
                  'This field type has no additional properties',
                  style: TextStyle(fontSize: isMobile ? 13 : 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Smart-form prefilled-confirm property panel.
  ///
  /// Renders two dropdowns:
  ///  1. `prefill_source` — which key in the bag returned by
  ///     `prefill_endorsement_for_candidate(<uuid>)` should populate this
  ///     field. Picking from a dropdown (instead of free-form text) prevents
  ///     typos that would silently disable the prefill.
  ///  2. `fallback_question_type` — the editable widget the moydforms
  ///     renderer mounts when the candidate picks Edit (or when the RPC
  ///     returned no value for this source).
  Widget _buildPrefilledConfirmProperties({bool isMobile = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome, color: Colors.blue, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Smart Form: Prefilled Confirm. The candidate sees the value '
                  'we already have and confirms or edits it. Only fires when '
                  'the form URL has ?candidate_id=<uuid>.',
                  style: TextStyle(fontSize: isMobile ? 12 : 13),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),
        Text(
          'Prefill Source',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 13 : 14),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _prefillSource,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            hintText: 'Pick the data source',
          ),
          items: FormFieldTypes.prefillSources
              .map((src) => DropdownMenuItem(value: src, child: Text(src)))
              .toList(),
          onChanged: (v) => setState(() => _prefillSource = v),
        ),
        SizedBox(height: isMobile ? 12 : 16),
        Text(
          'Fallback Question Type',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 13 : 14),
        ),
        const SizedBox(height: 6),
        Text(
          'Widget rendered when the candidate picks Edit (or when no prefill data is available).',
          style: TextStyle(fontSize: isMobile ? 11 : 12, color: Colors.grey[700]),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _fallbackQuestionType,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: const [
            DropdownMenuItem(value: 'short_answer', child: Text('Short answer')),
            DropdownMenuItem(value: 'long_answer', child: Text('Long answer')),
            DropdownMenuItem(value: 'number', child: Text('Number')),
            DropdownMenuItem(value: 'radio', child: Text('Radio (yes/no)')),
            DropdownMenuItem(value: 'date_picker', child: Text('Date picker')),
          ],
          onChanged: (v) => setState(() => _fallbackQuestionType = v ?? FormFieldTypes.text),
        ),
        SizedBox(height: isMobile ? 12 : 16),
        Text(
          'Display Format (optional)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 13 : 14),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String?>(
          value: _prefillFormat,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            hintText: 'Auto',
          ),
          items: const [
            DropdownMenuItem(value: null, child: Text('Auto')),
            DropdownMenuItem(value: 'currency', child: Text(r'Currency ($1,234.56)')),
            DropdownMenuItem(value: 'date', child: Text('Date')),
            DropdownMenuItem(value: 'csv', child: Text('Comma-separated list')),
            DropdownMenuItem(value: 'text', child: Text('Plain text')),
          ],
          onChanged: (v) => setState(() => _prefillFormat = v),
        ),
      ],
    );
  }

  Widget _buildOptionsEditor({bool isMobile = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile) ...[
          Text(
            'Options',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addOption,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Option'),
            ),
          ),
        ] else
          Row(
            children: [
              const Text('Options', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _addOption,
                icon: const Icon(Icons.add),
                label: const Text('Add Option'),
              ),
            ],
          ),
        SizedBox(height: isMobile ? 12 : 16),
        if (_options.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 24 : 32),
              child: Text(
                isMobile
                    ? 'No options yet. Tap "Add Option" to add one.'
                    : 'No options yet. Click "Add Option" to add one.',
                style: TextStyle(fontSize: isMobile ? 13 : 14),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _options.length,
            itemBuilder: (context, index) {
              final option = _options[index];
              return Card(
                margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
                child: ListTile(
                  dense: isMobile,
                  title: Text(
                    option.label,
                    style: TextStyle(fontSize: isMobile ? 14 : 16),
                  ),
                  subtitle: Text(
                    'Value: ${option.value}',
                    style: TextStyle(fontSize: isMobile ? 12 : 14),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, size: isMobile ? 20 : 24),
                    onPressed: () {
                      setState(() {
                        _options.removeAt(index);
                      });
                    },
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildNumericProperties({bool isMobile = false}) {
    final spacing = isMobile ? 12.0 : 16.0;
    final contentPadding = isMobile
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
        : null;

    return Column(
      children: [
        TextFormField(
          controller: _minValueController,
          decoration: InputDecoration(
            labelText: 'Minimum Value',
            border: const OutlineInputBorder(),
            contentPadding: contentPadding,
          ),
          style: TextStyle(fontSize: isMobile ? 14 : 16),
          keyboardType: TextInputType.number,
        ),
        SizedBox(height: spacing),
        TextFormField(
          controller: _maxValueController,
          decoration: InputDecoration(
            labelText: 'Maximum Value',
            border: const OutlineInputBorder(),
            contentPadding: contentPadding,
          ),
          style: TextStyle(fontSize: isMobile ? 14 : 16),
          keyboardType: TextInputType.number,
        ),
        SizedBox(height: spacing),
        TextFormField(
          controller: _initialValueController,
          decoration: InputDecoration(
            labelText: 'Initial Value',
            border: const OutlineInputBorder(),
            contentPadding: contentPadding,
          ),
          style: TextStyle(fontSize: isMobile ? 14 : 16),
          keyboardType: TextInputType.number,
        ),
        SizedBox(height: spacing),
        if (_fieldType == FormFieldTypes.slider || _fieldType == FormFieldTypes.cupertinoSlider)
          TextFormField(
            controller: _divisionsController,
            decoration: InputDecoration(
              labelText: 'Divisions',
              border: const OutlineInputBorder(),
              helperText: isMobile ? null : 'Number of discrete values',
              contentPadding: contentPadding,
            ),
            style: TextStyle(fontSize: isMobile ? 14 : 16),
            keyboardType: TextInputType.number,
          ),
        if (_fieldType == FormFieldTypes.touchSpin) ...[
          SizedBox(height: spacing),
          TextFormField(
            controller: _stepController,
            decoration: InputDecoration(
              labelText: 'Step',
              border: const OutlineInputBorder(),
              helperText: isMobile ? null : 'Increment/decrement amount',
              contentPadding: contentPadding,
            ),
            style: TextStyle(fontSize: isMobile ? 14 : 16),
            keyboardType: TextInputType.number,
          ),
        ],
      ],
    );
  }

  Widget _buildDateTimeProperties({bool isMobile = false}) {
    return Column(
      children: [
        ListTile(
          dense: isMobile,
          contentPadding: isMobile ? EdgeInsets.zero : null,
          title: Text(
            'First Selectable Date',
            style: TextStyle(fontSize: isMobile ? 14 : 16),
          ),
          subtitle: Text(
            _firstDate?.toString() ?? 'Not set',
            style: TextStyle(fontSize: isMobile ? 12 : 14),
          ),
          trailing: Icon(Icons.calendar_today, size: isMobile ? 20 : 24),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _firstDate ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (date != null) {
              setState(() => _firstDate = date);
            }
          },
        ),
        ListTile(
          dense: isMobile,
          contentPadding: isMobile ? EdgeInsets.zero : null,
          title: Text(
            'Last Selectable Date',
            style: TextStyle(fontSize: isMobile ? 14 : 16),
          ),
          subtitle: Text(
            _lastDate?.toString() ?? 'Not set',
            style: TextStyle(fontSize: isMobile ? 12 : 14),
          ),
          trailing: Icon(Icons.calendar_today, size: isMobile ? 20 : 24),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _lastDate ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (date != null) {
              setState(() => _lastDate = date);
            }
          },
        ),
      ],
    );
  }

  Widget _buildTextAreaProperties({bool isMobile = false}) {
    final spacing = isMobile ? 12.0 : 16.0;
    final contentPadding = isMobile
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
        : null;

    // Set defaults if empty
    if (_minLinesController.text.isEmpty) {
      _minLinesController.text = '3';
    }
    if (_maxLinesController.text.isEmpty) {
      _maxLinesController.text = '5';
    }

    return Column(
      children: [
        TextFormField(
          controller: _minLinesController,
          decoration: InputDecoration(
            labelText: 'Minimum Lines',
            border: const OutlineInputBorder(),
            contentPadding: contentPadding,
          ),
          style: TextStyle(fontSize: isMobile ? 14 : 16),
          keyboardType: TextInputType.number,
        ),
        SizedBox(height: spacing),
        TextFormField(
          controller: _maxLinesController,
          decoration: InputDecoration(
            labelText: 'Maximum Lines',
            border: const OutlineInputBorder(),
            contentPadding: contentPadding,
          ),
          style: TextStyle(fontSize: isMobile ? 14 : 16),
          keyboardType: TextInputType.number,
        ),
        SizedBox(height: spacing),
        TextFormField(
          controller: _maxLengthController,
          decoration: InputDecoration(
            labelText: 'Maximum Length',
            border: const OutlineInputBorder(),
            helperText: isMobile ? null : 'Maximum character count',
            contentPadding: contentPadding,
          ),
          style: TextStyle(fontSize: isMobile ? 14 : 16),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildColorPickerProperties({bool isMobile = false}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 24 : 32),
        child: Text(
          'Color picker will use default configuration',
          style: TextStyle(fontSize: isMobile ? 13 : 14),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildRatingProperties({bool isMobile = false}) {
    final contentPadding = isMobile
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
        : null;

    // Set default if empty
    if (_maxValueController.text.isEmpty) {
      _maxValueController.text = '5';
    }

    return Column(
      children: [
        TextFormField(
          controller: _maxValueController,
          decoration: InputDecoration(
            labelText: 'Maximum Rating',
            border: const OutlineInputBorder(),
            helperText: isMobile ? null : 'Number of stars/icons',
            contentPadding: contentPadding,
          ),
          style: TextStyle(fontSize: isMobile ? 14 : 16),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildValidationTab({bool isMobile = false}) {
    final padding = isMobile ? 12.0 : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Validators',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: isMobile ? 14 : 16,
            ),
          ),
          SizedBox(height: isMobile ? 6 : 8),
          Text(
            'Select validators to apply to this field',
            style: TextStyle(
              color: Colors.grey,
              fontSize: isMobile ? 12 : 14,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),

          // Show validators grouped by category
          ...FormValidators.categorizedValidators.entries.map((category) {
            return ExpansionTile(
              title: Text(
                category.key,
                style: TextStyle(fontSize: isMobile ? 14 : 16),
              ),
              tilePadding: isMobile ? const EdgeInsets.symmetric(horizontal: 8) : null,
              childrenPadding: isMobile ? EdgeInsets.zero : null,
              initiallyExpanded: category.value.any((v) => _selectedValidators.contains(v.value)),
              children: category.value.map((validator) {
                final isSelected = _selectedValidators.contains(validator.value);
                return CheckboxListTile(
                  title: Text(
                    validator.label,
                    style: TextStyle(fontSize: isMobile ? 13 : 14),
                  ),
                  subtitle: isMobile
                      ? null
                      : Text(
                          validator.description,
                          style: const TextStyle(fontSize: 12),
                        ),
                  value: isSelected,
                  dense: isMobile,
                  contentPadding: isMobile
                      ? const EdgeInsets.symmetric(horizontal: 8)
                      : null,
                  onChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        _selectedValidators.add(validator.value);
                        if (validator.requiresValue) {
                          _showValidatorConfigDialog(validator);
                        }
                      } else {
                        _selectedValidators.remove(validator.value);
                        _validatorConfigs.remove(validator.value);
                      }
                    });
                  },
                  secondary: isSelected && validator.requiresValue
                      ? IconButton(
                          icon: Icon(Icons.settings, size: isMobile ? 20 : 24),
                          onPressed: () => _showValidatorConfigDialog(validator),
                        )
                      : null,
                );
              }).toList(),
            );
          }).toList(),
        ],
      ),
    );
  }

  void _addOption() {
    final valueController = TextEditingController();
    final labelController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Option'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: valueController,
              decoration: const InputDecoration(
                labelText: 'Value',
                helperText: 'Leave empty to use label as value',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (labelController.text.isNotEmpty) {
                setState(() {
                  _options.add(FormFieldOption(
                    value: valueController.text.isEmpty ? labelController.text : valueController.text,
                    label: labelController.text,
                  ));
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

  void _showValidatorConfigDialog(ValidatorInfo validator) {
    final controller = TextEditingController(
      text: _validatorConfigs[validator.value]?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Configure ${validator.label}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Value',
            helperText: 'Type: ${validator.valueType ?? "string"}',
          ),
          keyboardType: validator.valueType == 'int' || validator.valueType == 'double'
              ? TextInputType.number
              : TextInputType.text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                if (validator.valueType == 'int') {
                  _validatorConfigs[validator.value] = int.tryParse(controller.text);
                } else if (validator.valueType == 'double') {
                  _validatorConfigs[validator.value] = double.tryParse(controller.text);
                } else {
                  _validatorConfigs[validator.value] = controller.text;
                }
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Convert label to a field key (snake_case)
  String _labelToKey(String label) {
    return label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  void _saveField() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Generate field key from label
    final fieldKey = _labelToKey(_labelController.text);

    // Validate against reserved identity field keys
    if (ReservedFieldKeys.isReserved(fieldKey)) {
      final category = ReservedFieldKeys.getCategory(fieldKey);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'The field key "$fieldKey" is reserved for identity tracking ($category). '
            'Please use a different label.',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Also check if the label itself matches a reserved key
    if (ReservedFieldKeys.isReserved(_labelController.text)) {
      final category = ReservedFieldKeys.getCategory(_labelController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'The label "${_labelController.text}" is reserved for identity tracking ($category). '
            'Please use a different label, such as "Additional Phone" or "Work Email".',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Validate field-specific requirements. Smart-form prefilled_confirm
    // requires a prefill_source (so the renderer knows which RPC key to
    // map this field to), but the radio fallback doesn't need options
    // configured here — the renderer hard-codes yes/no for the
    // incumbent_yn case and treats other fallbacks as plain text/number.
    if (_fieldType == FormFieldTypes.prefilledConfirm) {
      if (_prefillSource == null || _prefillSource!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pick a Prefill Source for this prefilled-confirm field'),
          ),
        );
        return;
      }
    } else if (FormFieldTypes.requiresOptions(_fieldType) && _options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one option for this field type'),
        ),
      );
      return;
    }

    // Parse values from controllers
    final maxLength = int.tryParse(_maxLengthController.text);
    final minLines = int.tryParse(_minLinesController.text);
    final maxLines = int.tryParse(_maxLinesController.text);
    final minValue = double.tryParse(_minValueController.text);
    final maxValue = double.tryParse(_maxValueController.text);
    final initialValue = double.tryParse(_initialValueController.text);
    final step = double.tryParse(_stepController.text);
    final divisions = int.tryParse(_divisionsController.text);

    final field = FormFieldConfig(
      id: widget.existingField?.id ?? const Uuid().v4(),
      type: _fieldType,
      label: _labelController.text,
      placeholder: _placeholderController.text.isEmpty ? null : _placeholderController.text,
      help: _helpController.text.isEmpty ? null : _helpController.text,
      required: _required,
      enabled: _enabled,
      options: _options.isEmpty ? null : _options,
      validatorTypes: _selectedValidators.isEmpty ? null : _selectedValidators,
      validation: _validatorConfigs.isEmpty ? null : _validatorConfigs,
      maxLength: maxLength,
      minLines: minLines,
      maxLines: maxLines,
      minValue: minValue,
      maxValue: maxValue,
      initialValue: initialValue,
      step: step,
      divisions: divisions,
      firstDate: _firstDate,
      lastDate: _lastDate,
      // Smart-form metadata — only emit when the field is actually a
      // prefilled_confirm so other field types stay clean in JSON.
      prefillSource: _fieldType == FormFieldTypes.prefilledConfirm ? _prefillSource : null,
      prefillFormat: _fieldType == FormFieldTypes.prefilledConfirm ? _prefillFormat : null,
      fallbackQuestionType: _fieldType == FormFieldTypes.prefilledConfirm
          ? _fallbackQuestionType
          : null,
    );

    widget.onSave(field);
    Navigator.pop(context);
  }
}
