import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/form_field_config.dart';
import '../models/form_field_types.dart';
import '../models/form_validators.dart';

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

  // Controllers
  final _labelController = TextEditingController();
  final _placeholderController = TextEditingController();
  final _helpController = TextEditingController();

  // Basic properties
  String _fieldType = FormFieldTypes.text;
  bool _required = false;
  bool _enabled = true;

  // Text field properties
  int? _maxLength;
  int? _minLines;
  int? _maxLines;

  // Numeric properties
  double? _minValue;
  double? _maxValue;
  double? _initialValue;
  double? _step;
  int? _divisions;

  // Date properties
  DateTime? _firstDate;
  DateTime? _lastDate;

  // Options for dropdowns, radio, etc.
  List<FormFieldOption> _options = [];

  // Selected validators
  List<String> _selectedValidators = [];
  Map<String, dynamic> _validatorConfigs = {};

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
      _maxLength = field.maxLength;
      _minLines = field.minLines;
      _maxLines = field.maxLines;
      _minValue = field.minValue;
      _maxValue = field.maxValue;
      _initialValue = field.initialValue;
      _step = field.step;
      _divisions = field.divisions;
      _firstDate = field.firstDate;
      _lastDate = field.lastDate;
      _options = field.options ?? [];
      _selectedValidators = field.validatorTypes ?? [];
      _validatorConfigs = field.validation ?? {};
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _labelController.dispose();
    _placeholderController.dispose();
    _helpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Text(
                  widget.existingField == null ? 'Add Field' : 'Edit Field',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),

            // Tabs
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Basic', icon: Icon(Icons.settings)),
                Tab(text: 'Properties', icon: Icon(Icons.tune)),
                Tab(text: 'Validation', icon: Icon(Icons.verified_user)),
              ],
            ),

            // Tab content
            Expanded(
              child: Form(
                key: _formKey,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBasicTab(),
                    _buildPropertiesTab(),
                    _buildValidationTab(),
                  ],
                ),
              ),
            ),

            // Action buttons
            const Divider(),
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

  Widget _buildBasicTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field Type Selector
          Text(
            'Field Type',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _buildFieldTypeSelector(),
          const SizedBox(height: 24),

          // Label
          TextFormField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Field Label *',
              border: OutlineInputBorder(),
              helperText: 'The label shown above the field',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Label is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Placeholder
          TextFormField(
            controller: _placeholderController,
            decoration: const InputDecoration(
              labelText: 'Placeholder',
              border: OutlineInputBorder(),
              helperText: 'Hint text shown in the field',
            ),
          ),
          const SizedBox(height: 16),

          // Help Text
          TextFormField(
            controller: _helpController,
            decoration: const InputDecoration(
              labelText: 'Help Text',
              border: OutlineInputBorder(),
              helperText: 'Additional help text shown below the field',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // Required & Enabled switches
          SwitchListTile(
            title: const Text('Required Field'),
            subtitle: const Text('User must fill this field'),
            value: _required,
            onChanged: (value) => setState(() => _required = value),
          ),
          SwitchListTile(
            title: const Text('Enabled'),
            subtitle: const Text('Field can be edited'),
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: FormFieldTypes.categorizedTypes.entries.map((category) {
        return ExpansionTile(
          title: Text(category.key),
          initiallyExpanded: category.value.any((field) => field.value == _fieldType),
          children: category.value.map((fieldType) {
            return RadioListTile<String>(
              title: Text(fieldType.label),
              subtitle: Text(fieldType.description),
              value: fieldType.value,
              groupValue: _fieldType,
              onChanged: (value) {
                setState(() {
                  _fieldType = value!;
                  // Reset type-specific properties
                  _options = [];
                  _minValue = null;
                  _maxValue = null;
                });
              },
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildPropertiesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Field-Specific Properties',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),

          // Show different properties based on field type
          if (FormFieldTypes.requiresOptions(_fieldType)) ...[
            _buildOptionsEditor(),
          ] else if (FormFieldTypes.isNumeric(_fieldType)) ...[
            _buildNumericProperties(),
          ] else if (FormFieldTypes.isDateTime(_fieldType)) ...[
            _buildDateTimeProperties(),
          ] else if (_fieldType == FormFieldTypes.textarea) ...[
            _buildTextAreaProperties(),
          ] else if (_fieldType == FormFieldTypes.colorPicker) ...[
            _buildColorPickerProperties(),
          ] else if (_fieldType == FormFieldTypes.rating) ...[
            _buildRatingProperties(),
          ] else ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('This field type has no additional properties'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionsEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        const SizedBox(height: 16),
        if (_options.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No options yet. Click "Add Option" to add one.'),
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
                child: ListTile(
                  title: Text(option.label),
                  subtitle: Text('Value: ${option.value}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
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

  Widget _buildNumericProperties() {
    return Column(
      children: [
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Minimum Value',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          initialValue: _minValue?.toString() ?? '',
          onChanged: (value) {
            _minValue = double.tryParse(value);
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Maximum Value',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          initialValue: _maxValue?.toString() ?? '',
          onChanged: (value) {
            _maxValue = double.tryParse(value);
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Initial Value',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          initialValue: _initialValue?.toString() ?? '',
          onChanged: (value) {
            _initialValue = double.tryParse(value);
          },
        ),
        const SizedBox(height: 16),
        if (_fieldType == FormFieldTypes.slider || _fieldType == FormFieldTypes.cupertinoSlider)
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Divisions',
              border: OutlineInputBorder(),
              helperText: 'Number of discrete values',
            ),
            keyboardType: TextInputType.number,
            initialValue: _divisions?.toString() ?? '',
            onChanged: (value) {
              _divisions = int.tryParse(value);
            },
          ),
        if (_fieldType == FormFieldTypes.touchSpin) ...[
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Step',
              border: OutlineInputBorder(),
              helperText: 'Increment/decrement amount',
            ),
            keyboardType: TextInputType.number,
            initialValue: _step?.toString() ?? '1',
            onChanged: (value) {
              _step = double.tryParse(value);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildDateTimeProperties() {
    return Column(
      children: [
        ListTile(
          title: const Text('First Selectable Date'),
          subtitle: Text(_firstDate?.toString() ?? 'Not set'),
          trailing: const Icon(Icons.calendar_today),
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
          title: const Text('Last Selectable Date'),
          subtitle: Text(_lastDate?.toString() ?? 'Not set'),
          trailing: const Icon(Icons.calendar_today),
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

  Widget _buildTextAreaProperties() {
    return Column(
      children: [
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Minimum Lines',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          initialValue: _minLines?.toString() ?? '3',
          onChanged: (value) {
            _minLines = int.tryParse(value);
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Maximum Lines',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          initialValue: _maxLines?.toString() ?? '5',
          onChanged: (value) {
            _maxLines = int.tryParse(value);
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Maximum Length',
            border: OutlineInputBorder(),
            helperText: 'Maximum character count',
          ),
          keyboardType: TextInputType.number,
          initialValue: _maxLength?.toString() ?? '',
          onChanged: (value) {
            _maxLength = int.tryParse(value);
          },
        ),
      ],
    );
  }

  Widget _buildColorPickerProperties() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('Color picker will use default configuration'),
      ),
    );
  }

  Widget _buildRatingProperties() {
    return Column(
      children: [
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Maximum Rating',
            border: OutlineInputBorder(),
            helperText: 'Number of stars/icons',
          ),
          keyboardType: TextInputType.number,
          initialValue: _maxValue?.toString() ?? '5',
          onChanged: (value) {
            _maxValue = double.tryParse(value);
          },
        ),
      ],
    );
  }

  Widget _buildValidationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Validators',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Select validators to apply to this field',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // Show validators grouped by category
          ...FormValidators.categorizedValidators.entries.map((category) {
            return ExpansionTile(
              title: Text(category.key),
              initiallyExpanded: category.value.any((v) => _selectedValidators.contains(v.value)),
              children: category.value.map((validator) {
                final isSelected = _selectedValidators.contains(validator.value);
                return CheckboxListTile(
                  title: Text(validator.label),
                  subtitle: Text(validator.description),
                  value: isSelected,
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
                          icon: const Icon(Icons.settings),
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

  void _saveField() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate field-specific requirements
    if (FormFieldTypes.requiresOptions(_fieldType) && _options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one option for this field type'),
        ),
      );
      return;
    }

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
      maxLength: _maxLength,
      minLines: _minLines,
      maxLines: _maxLines,
      minValue: _minValue,
      maxValue: _maxValue,
      initialValue: _initialValue,
      step: _step,
      divisions: _divisions,
      firstDate: _firstDate,
      lastDate: _lastDate,
    );

    widget.onSave(field);
    Navigator.pop(context);
  }
}
