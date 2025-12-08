import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import '../models/form_field_config.dart';

/// Wrapper that conditionally shows/hides a field based on another field's value
class ConditionalFieldWrapper extends StatelessWidget {
  final FormFieldConfig config;
  final GlobalKey<FormBuilderState> formKey;
  final Widget child;

  const ConditionalFieldWrapper({
    Key? key,
    required this.config,
    required this.formKey,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If no conditional logic, just return the child
    if (config.conditionalFieldId == null || config.conditionalOperator == null) {
      return child;
    }

    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: _createValueListenable(),
      builder: (context, values, _) {
        final shouldShow = _evaluateCondition(values);

        if (!shouldShow) {
          // Field is hidden - return empty container
          return const SizedBox.shrink();
        }

        return child;
      },
    );
  }

  ValueListenable<Map<String, dynamic>> _createValueListenable() {
    // Listen to form value changes
    return _FormValueNotifier(formKey);
  }

  bool _evaluateCondition(Map<String, dynamic> values) {
    final watchedFieldValue = values[config.conditionalFieldId];
    final conditionValue = config.conditionalValue;
    final operator = config.conditionalOperator!;

    bool conditionMet = false;

    switch (operator) {
      case 'equals':
        conditionMet = watchedFieldValue == conditionValue;
        break;

      case 'notEquals':
        conditionMet = watchedFieldValue != conditionValue;
        break;

      case 'contains':
        if (watchedFieldValue is String && conditionValue is String) {
          conditionMet = watchedFieldValue.contains(conditionValue);
        } else if (watchedFieldValue is List) {
          conditionMet = watchedFieldValue.contains(conditionValue);
        }
        break;

      case 'notContains':
        if (watchedFieldValue is String && conditionValue is String) {
          conditionMet = !watchedFieldValue.contains(conditionValue);
        } else if (watchedFieldValue is List) {
          conditionMet = !watchedFieldValue.contains(conditionValue);
        }
        break;

      case 'greaterThan':
        if (watchedFieldValue is num && conditionValue is num) {
          conditionMet = watchedFieldValue > conditionValue;
        }
        break;

      case 'lessThan':
        if (watchedFieldValue is num && conditionValue is num) {
          conditionMet = watchedFieldValue < conditionValue;
        }
        break;

      case 'greaterThanOrEqual':
        if (watchedFieldValue is num && conditionValue is num) {
          conditionMet = watchedFieldValue >= conditionValue;
        }
        break;

      case 'lessThanOrEqual':
        if (watchedFieldValue is num && conditionValue is num) {
          conditionMet = watchedFieldValue <= conditionValue;
        }
        break;

      case 'isEmpty':
        conditionMet = watchedFieldValue == null ||
                      (watchedFieldValue is String && watchedFieldValue.isEmpty) ||
                      (watchedFieldValue is List && watchedFieldValue.isEmpty);
        break;

      case 'isNotEmpty':
        conditionMet = watchedFieldValue != null &&
                      (watchedFieldValue is! String || watchedFieldValue.isNotEmpty) &&
                      (watchedFieldValue is! List || watchedFieldValue.isNotEmpty);
        break;

      default:
        conditionMet = false;
    }

    // If showWhenConditionMet is false, invert the result
    return config.showWhenConditionMet ? conditionMet : !conditionMet;
  }
}

/// Custom ValueNotifier that listens to form changes
class _FormValueNotifier extends ValueNotifier<Map<String, dynamic>> {
  final GlobalKey<FormBuilderState> formKey;

  _FormValueNotifier(this.formKey) : super({}) {
    _updateValue();
  }

  void _updateValue() {
    value = formKey.currentState?.value ?? {};
    // Listen for changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (formKey.currentState != null) {
          final newValue = formKey.currentState!.value;
          if (newValue.toString() != value.toString()) {
            value = newValue;
          }
          _updateValue();
        }
      });
    });
  }
}
