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
    // If no conditional logic (neither simple nor complex), just return the child
    final hasSimpleCondition = config.conditionalFieldId != null && config.conditionalOperator != null;
    final hasComplexConditions = config.conditions != null && config.conditions!.isNotEmpty;

    if (!hasSimpleCondition && !hasComplexConditions) {
      return child;
    }

    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: _createValueListenable(),
      builder: (context, values, _) {
        final shouldShow = hasComplexConditions
            ? _evaluateAllConditions(values)
            : _evaluateCondition(values);

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

  /// Evaluate all AND conditions - ALL conditions must be met
  bool _evaluateAllConditions(Map<String, dynamic> values) {
    if (config.conditions == null || config.conditions!.isEmpty) {
      return true;
    }

    // ALL conditions must be met (AND logic)
    for (final condition in config.conditions!) {
      final fieldId = condition['field'] as String?;
      final conditionValue = condition['value'];
      final operator = condition['operator'] as String? ?? 'equals';

      if (fieldId == null) continue;

      final watchedFieldValue = values[fieldId];
      final conditionMet = _evaluateSingleCondition(watchedFieldValue, conditionValue, operator);

      if (!conditionMet) {
        // If any condition is not met, return false (AND logic)
        return config.showWhenConditionMet ? false : true;
      }
    }

    // All conditions are met
    return config.showWhenConditionMet ? true : false;
  }

  /// Evaluate a single condition with given operator
  bool _evaluateSingleCondition(dynamic watchedFieldValue, dynamic conditionValue, String operator) {
    switch (operator) {
      case 'equals':
        return watchedFieldValue == conditionValue;

      case 'notEquals':
        return watchedFieldValue != conditionValue;

      case 'contains':
        if (watchedFieldValue is String && conditionValue is String) {
          return watchedFieldValue.contains(conditionValue);
        } else if (watchedFieldValue is List) {
          return watchedFieldValue.contains(conditionValue);
        }
        return false;

      case 'notContains':
        if (watchedFieldValue is String && conditionValue is String) {
          return !watchedFieldValue.contains(conditionValue);
        } else if (watchedFieldValue is List) {
          return !watchedFieldValue.contains(conditionValue);
        }
        return false;

      case 'greaterThan':
        if (watchedFieldValue is num && conditionValue is num) {
          return watchedFieldValue > conditionValue;
        }
        return false;

      case 'lessThan':
        if (watchedFieldValue is num && conditionValue is num) {
          return watchedFieldValue < conditionValue;
        }
        return false;

      case 'greaterThanOrEqual':
        if (watchedFieldValue is num && conditionValue is num) {
          return watchedFieldValue >= conditionValue;
        }
        return false;

      case 'lessThanOrEqual':
        if (watchedFieldValue is num && conditionValue is num) {
          return watchedFieldValue <= conditionValue;
        }
        return false;

      case 'isEmpty':
        return watchedFieldValue == null ||
            (watchedFieldValue is String && watchedFieldValue.isEmpty) ||
            (watchedFieldValue is List && watchedFieldValue.isEmpty);

      case 'isNotEmpty':
        return watchedFieldValue != null &&
            (watchedFieldValue is! String || watchedFieldValue.isNotEmpty) &&
            (watchedFieldValue is! List || watchedFieldValue.isNotEmpty);

      default:
        return false;
    }
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
