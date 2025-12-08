import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:form_builder_extra_fields/form_builder_extra_fields.dart';
import 'package:form_builder_cupertino_fields/form_builder_cupertino_fields.dart';
import 'package:form_builder_file_picker/form_builder_file_picker.dart';
import 'package:form_builder_image_picker/form_builder_image_picker.dart';
import '../models/form_field_config.dart';
import '../models/form_field_types.dart';

/// Renders a form field based on its configuration
class FormFieldRenderer extends StatelessWidget {
  final FormFieldConfig config;
  final GlobalKey<FormBuilderState> formKey;

  const FormFieldRenderer({
    Key? key,
    required this.config,
    required this.formKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildField(context),
    );
  }

  Widget _buildField(BuildContext context) {
    switch (config.type) {
      // Basic text fields
      case FormFieldTypes.text:
      case FormFieldTypes.email:
      case FormFieldTypes.phone:
      case FormFieldTypes.url:
      case FormFieldTypes.number:
        return _buildTextField();

      case FormFieldTypes.textarea:
        return _buildTextArea();

      // Selection fields
      case FormFieldTypes.dropdown:
        return _buildDropdown();

      case FormFieldTypes.searchableDropdown:
        return _buildSearchableDropdown();

      case FormFieldTypes.checkbox:
        return _buildCheckbox();

      case FormFieldTypes.checkboxGroup:
        return _buildCheckboxGroup();

      case FormFieldTypes.radio:
        return _buildRadioGroup();

      case FormFieldTypes.choiceChips:
        return _buildChoiceChips();

      case FormFieldTypes.filterChips:
        return _buildFilterChips();

      case FormFieldTypes.switchField:
        return _buildSwitch();

      // Date/Time fields
      case FormFieldTypes.datePicker:
        return _buildDatePicker(InputType.date);

      case FormFieldTypes.timePicker:
        return _buildDatePicker(InputType.time);

      case FormFieldTypes.dateTimePicker:
        return _buildDatePicker(InputType.both);

      case FormFieldTypes.dateRangePicker:
        return _buildDateRangePicker();

      // Numeric fields
      case FormFieldTypes.slider:
        return _buildSlider();

      case FormFieldTypes.rangeSlider:
        return _buildRangeSlider();

      case FormFieldTypes.touchSpin:
        return _buildTouchSpin();

      case FormFieldTypes.rating:
        return _buildRating();

      // Special fields
      case FormFieldTypes.colorPicker:
        return _buildColorPicker();

      case FormFieldTypes.signaturePad:
        return _buildSignaturePad();

      case FormFieldTypes.typeahead:
        return _buildTypeahead();

      case FormFieldTypes.filePicker:
        return _buildFilePicker();

      case FormFieldTypes.imagePicker:
        return _buildImagePicker();

      // Cupertino fields
      case FormFieldTypes.cupertinoTextField:
        return _buildCupertinoTextField();

      case FormFieldTypes.cupertinoCheckbox:
        return _buildCupertinoCheckbox();

      case FormFieldTypes.cupertinoSwitch:
        return _buildCupertinoSwitch();

      case FormFieldTypes.cupertinoSlider:
        return _buildCupertinoSlider();

      case FormFieldTypes.cupertinoSegmentedControl:
        return _buildCupertinoSegmentedControl();

      case FormFieldTypes.cupertinoSlidingSegmentedControl:
        return _buildCupertinoSlidingSegmentedControl();

      default:
        return Text('Unknown field type: ${config.type}');
    }
  }

  // Validators
  List<String? Function(String?)> _buildValidators() {
    final validators = <String? Function(String?)>[];

    if (config.required) {
      validators.add(FormBuilderValidators.required());
    }

    if (config.validatorTypes != null) {
      for (final validatorType in config.validatorTypes!) {
        final validatorConfig = config.validation?[validatorType];

        switch (validatorType) {
          case 'email':
            validators.add(FormBuilderValidators.email());
            break;
          case 'url':
            validators.add(FormBuilderValidators.url());
            break;
          case 'minLength':
            if (validatorConfig is int) {
              validators.add(FormBuilderValidators.minLength(validatorConfig));
            }
            break;
          case 'maxLength':
            if (validatorConfig is int) {
              validators.add(FormBuilderValidators.maxLength(validatorConfig));
            }
            break;
          case 'numeric':
            validators.add(FormBuilderValidators.numeric());
            break;
          case 'integer':
            validators.add(FormBuilderValidators.integer());
            break;
          case 'min':
            if (validatorConfig is num) {
              validators.add(FormBuilderValidators.min(validatorConfig));
            }
            break;
          case 'max':
            if (validatorConfig is num) {
              validators.add(FormBuilderValidators.max(validatorConfig));
            }
            break;
          case 'phoneNumber':
            validators.add(FormBuilderValidators.phoneNumber());
            break;
          case 'creditCard':
            validators.add(FormBuilderValidators.creditCard());
            break;
          case 'ip':
            validators.add(FormBuilderValidators.ip());
            break;
          case 'alphabetical':
            validators.add(FormBuilderValidators.alphabetical());
            break;
          case 'lowercase':
            validators.add((value) {
              if (value == null || value.isEmpty) return null;
              if (value != value.toLowerCase()) return 'Must be lowercase';
              return null;
            });
            break;
          case 'uppercase':
            validators.add((value) {
              if (value == null || value.isEmpty) return null;
              if (value != value.toUpperCase()) return 'Must be uppercase';
              return null;
            });
            break;
          case 'contains':
            if (validatorConfig is String) {
              validators.add((value) {
                if (value == null || value.isEmpty) return null;
                if (!value.contains(validatorConfig)) {
                  return 'Must contain "$validatorConfig"';
                }
                return null;
              });
            }
            break;
          case 'match':
            if (validatorConfig is String) {
              validators.add(FormBuilderValidators.match(validatorConfig));
            }
            break;
          // Add more validators as needed
        }
      }
    }

    return validators;
  }

  InputDecoration _buildDecoration() {
    return InputDecoration(
      labelText: config.label,
      hintText: config.placeholder ?? config.hintText,
      helperText: config.help,
      prefixText: config.prefixText,
      suffixText: config.suffixText,
      border: const OutlineInputBorder(),
    );
  }

  // Text field implementations
  Widget _buildTextField() {
    TextInputType? keyboardType;
    switch (config.type) {
      case FormFieldTypes.email:
        keyboardType = TextInputType.emailAddress;
        break;
      case FormFieldTypes.phone:
        keyboardType = TextInputType.phone;
        break;
      case FormFieldTypes.url:
        keyboardType = TextInputType.url;
        break;
      case FormFieldTypes.number:
        keyboardType = TextInputType.number;
        break;
      default:
        keyboardType = TextInputType.text;
    }

    return FormBuilderTextField(
      name: config.id,
      decoration: _buildDecoration(),
      keyboardType: keyboardType,
      maxLength: config.maxLength,
      enabled: config.enabled,
      validator: FormBuilderValidators.compose(_buildValidators()),
    );
  }

  Widget _buildTextArea() {
    return FormBuilderTextField(
      name: config.id,
      decoration: _buildDecoration(),
      maxLines: config.maxLines ?? 5,
      minLines: config.minLines ?? 3,
      maxLength: config.maxLength,
      enabled: config.enabled,
      validator: FormBuilderValidators.compose(_buildValidators()),
    );
  }

  Widget _buildDropdown() {
    return FormBuilderDropdown<String>(
      name: config.id,
      decoration: _buildDecoration(),
      items: (config.options ?? [])
          .map((option) => DropdownMenuItem(
                value: option.value,
                child: Text(option.label),
              ))
          .toList(),
      enabled: config.enabled,
      validator: config.required ? FormBuilderValidators.required() : null,
    );
  }

  Widget _buildSearchableDropdown() {
    return FormBuilderSearchableDropdown<String>(
      name: config.id,
      decoration: _buildDecoration(),
      items: (config.options ?? [])
          .map((option) => DropdownMenuItem(
                value: option.value,
                child: Text(option.label),
              ))
          .toList(),
      enabled: config.enabled,
      validator: config.required ? FormBuilderValidators.required() : null,
    );
  }

  Widget _buildCheckbox() {
    return FormBuilderCheckbox(
      name: config.id,
      title: Text(config.label),
      subtitle: config.help != null ? Text(config.help!) : null,
      enabled: config.enabled,
      validator: config.required
          ? (value) {
              if (value != true) return 'This field is required';
              return null;
            }
          : null,
    );
  }

  Widget _buildCheckboxGroup() {
    return FormBuilderCheckboxGroup<String>(
      name: config.id,
      decoration: _buildDecoration(),
      options: (config.options ?? [])
          .map((option) => FormBuilderFieldOption(
                value: option.value,
                child: Text(option.label),
              ))
          .toList(),
      enabled: config.enabled,
      validator: config.required ? FormBuilderValidators.required() : null,
    );
  }

  Widget _buildRadioGroup() {
    return FormBuilderRadioGroup<String>(
      name: config.id,
      decoration: _buildDecoration(),
      options: (config.options ?? [])
          .map((option) => FormBuilderFieldOption(
                value: option.value,
                child: Text(option.label),
              ))
          .toList(),
      enabled: config.enabled,
      validator: config.required ? FormBuilderValidators.required() : null,
    );
  }

  Widget _buildChoiceChips() {
    return FormBuilderChoiceChip<String>(
      name: config.id,
      decoration: _buildDecoration(),
      options: (config.options ?? [])
          .map((option) => FormBuilderChipOption(
                value: option.value,
                child: Text(option.label),
              ))
          .toList(),
      enabled: config.enabled,
      validator: config.required ? FormBuilderValidators.required() : null,
    );
  }

  Widget _buildFilterChips() {
    return FormBuilderFilterChip<String>(
      name: config.id,
      decoration: _buildDecoration(),
      options: (config.options ?? [])
          .map((option) => FormBuilderChipOption(
                value: option.value,
                child: Text(option.label),
              ))
          .toList(),
      enabled: config.enabled,
      validator: config.required ? FormBuilderValidators.required() : null,
    );
  }

  Widget _buildSwitch() {
    return FormBuilderSwitch(
      name: config.id,
      title: Text(config.label),
      subtitle: config.help != null ? Text(config.help!) : null,
      enabled: config.enabled,
      initialValue: config.defaultValue as bool? ?? false,
    );
  }

  Widget _buildDatePicker(InputType inputType) {
    return FormBuilderDateTimePicker(
      name: config.id,
      decoration: _buildDecoration(),
      inputType: inputType,
      firstDate: config.firstDate,
      lastDate: config.lastDate,
      enabled: config.enabled,
      validator: config.required ? FormBuilderValidators.required() : null,
    );
  }

  Widget _buildDateRangePicker() {
    return FormBuilderDateRangePicker(
      name: config.id,
      decoration: _buildDecoration(),
      firstDate: config.firstDate ?? DateTime(2000),
      lastDate: config.lastDate ?? DateTime(2100),
      enabled: config.enabled,
      validator: config.required ? FormBuilderValidators.required() : null,
    );
  }

  Widget _buildSlider() {
    return FormBuilderSlider(
      name: config.id,
      decoration: _buildDecoration(),
      min: config.minValue ?? 0,
      max: config.maxValue ?? 100,
      initialValue: config.initialValue ?? (config.minValue ?? 0),
      divisions: config.divisions,
      enabled: config.enabled,
    );
  }

  Widget _buildRangeSlider() {
    return FormBuilderRangeSlider(
      name: config.id,
      decoration: _buildDecoration(),
      min: config.minValue ?? 0,
      max: config.maxValue ?? 100,
      initialValue: RangeValues(
        config.minValue ?? 0,
        config.maxValue ?? 100,
      ),
      divisions: config.divisions,
      enabled: config.enabled,
    );
  }

  Widget _buildTouchSpin() {
    return FormBuilderTouchSpin(
      name: config.id,
      decoration: _buildDecoration(),
      initialValue: config.initialValue ?? config.minValue ?? 0,
      min: config.minValue ?? 0,
      max: config.maxValue ?? 100,
      step: config.step ?? 1,
      enabled: config.enabled,
      validator: config.required ? FormBuilderValidators.required() : null,
    );
  }

  Widget _buildRating() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (config.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              config.label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        FormBuilderRating(
          name: config.id,
          decoration: const InputDecoration(border: InputBorder.none),
          maxRating: (config.maxValue ?? 5).toInt(),
          initialRating: config.initialValue ?? 0,
          enabled: config.enabled,
          validator: config.required ? FormBuilderValidators.required() : null,
        ),
        if (config.help != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              config.help!,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
      ],
    );
  }

  Widget _buildColorPicker() {
    return FormBuilderColorPicker(
      name: config.id,
      decoration: _buildDecoration(),
      enabled: config.enabled,
      validator: config.required ? FormBuilderValidators.required() : null,
    );
  }

  Widget _buildSignaturePad() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (config.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              config.label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        FormBuilderSignaturePad(
          name: config.id,
          decoration: const InputDecoration(border: InputBorder.none),
          height: config.signatureHeight ?? 200,
          enabled: config.enabled,
          validator: config.required ? FormBuilderValidators.required() : null,
        ),
        if (config.help != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              config.help!,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
      ],
    );
  }

  Widget _buildTypeahead() {
    return FormBuilderTypeAhead<String>(
      name: config.id,
      decoration: _buildDecoration(),
      itemBuilder: (context, item) => ListTile(title: Text(item)),
      suggestionsCallback: (search) {
        // Filter options based on search
        return (config.options ?? [])
            .where((option) =>
                option.label.toLowerCase().contains(search.toLowerCase()))
            .map((option) => option.value)
            .toList();
      },
      enabled: config.enabled,
      validator: config.required ? FormBuilderValidators.required() : null,
    );
  }

  // Cupertino (iOS) field implementations
  Widget _buildCupertinoTextField() {
    return FormBuilderCupertinoTextField(
      name: config.id,
      decoration: _buildDecoration(),
      placeholder: config.placeholder,
      maxLength: config.maxLength,
      enabled: config.enabled,
      validator: FormBuilderValidators.compose(_buildValidators()),
    );
  }

  Widget _buildCupertinoCheckbox() {
    return FormBuilderCupertinoCheckbox(
      name: config.id,
      title: Text(config.label),
      subtitle: config.help != null ? Text(config.help!) : null,
      enabled: config.enabled,
      validator: config.required
          ? (value) {
              if (value != true) return 'This field is required';
              return null;
            }
          : null,
    );
  }

  Widget _buildCupertinoSwitch() {
    return FormBuilderCupertinoSwitch(
      name: config.id,
      title: Text(config.label),
      subtitle: config.help != null ? Text(config.help!) : null,
      enabled: config.enabled,
      initialValue: config.defaultValue as bool? ?? false,
    );
  }

  Widget _buildCupertinoSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (config.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              config.label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        FormBuilderCupertinoSlider(
          name: config.id,
          decoration: const InputDecoration(border: InputBorder.none),
          min: config.minValue ?? 0,
          max: config.maxValue ?? 100,
          initialValue: config.initialValue ?? (config.minValue ?? 0),
          divisions: config.divisions,
          enabled: config.enabled,
        ),
        if (config.help != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              config.help!,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
      ],
    );
  }

  Widget _buildCupertinoSegmentedControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (config.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              config.label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        FormBuilderCupertinoSegmentedControl<String>(
          name: config.id,
          decoration: const InputDecoration(border: InputBorder.none),
          options: (config.options ?? [])
              .map((option) => FormBuilderFieldOption(
                    value: option.value,
                    child: Text(option.label),
                  ))
              .toList(),
          enabled: config.enabled,
          validator: config.required ? FormBuilderValidators.required() : null,
        ),
        if (config.help != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              config.help!,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
      ],
    );
  }

  Widget _buildCupertinoSlidingSegmentedControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (config.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              config.label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        FormBuilderCupertinoSlidingSegmentedControl<String>(
          name: config.id,
          decoration: const InputDecoration(border: InputBorder.none),
          options: (config.options ?? [])
              .asMap()
              .map((index, option) => MapEntry(
                    option.value,
                    Text(option.label),
                  )),
          enabled: config.enabled,
          validator: config.required ? FormBuilderValidators.required() : null,
        ),
        if (config.help != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              config.help!,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
      ],
    );
  }

  Widget _buildFilePicker() {
    return FormBuilderFilePicker(
      name: config.id,
      decoration: _buildDecoration(),
      maxFiles: config.allowMultipleFiles ? null : 1,
      previewImages: true,
      allowedExtensions: config.allowedExtensions,
      type: _getFileType(),
      allowCompression: true,
      validator: config.required ? FormBuilderValidators.required() : null,
      onChanged: (files) {
        // Check file size if maxFileSizeMB is set
        if (config.maxFileSizeMB != null && files != null) {
          for (final file in files) {
            if (file.size > (config.maxFileSizeMB! * 1024 * 1024)) {
              // File too large - handled by validator
            }
          }
        }
      },
    );
  }

  FileType _getFileType() {
    switch (config.fileTypeFilter) {
      case 'image':
        return FileType.image;
      case 'video':
        return FileType.video;
      case 'audio':
        return FileType.audio;
      case 'custom':
        return FileType.custom;
      default:
        return FileType.any;
    }
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (config.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              config.label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        FormBuilderImagePicker(
          name: config.id,
          decoration: const InputDecoration(border: InputBorder.none),
          maxImages: config.maxImages ?? (config.allowMultipleFiles ? null : 1),
          imageQuality: ((config.imageQuality ?? 0.8) * 100).toInt(),
          maxWidth: config.maxImageWidth?.toDouble(),
          maxHeight: config.maxImageHeight?.toDouble(),
          validator: config.required ? FormBuilderValidators.required() : null,
        ),
        if (config.help != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              config.help!,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
      ],
    );
  }
}
