import 'package:flutter/material.dart';

class SuggestionChips extends StatelessWidget {
  final List<String> suggestions;
  final Function(String) onTap;

  const SuggestionChips({
    super.key,
    required this.suggestions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: suggestions.map((suggestion) {
        return ActionChip(
          label: Text(suggestion),
          onPressed: () => onTap(suggestion),
          backgroundColor: colorScheme.surfaceContainerHighest,
          side: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
          labelStyle: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        );
      }).toList(),
    );
  }
}
