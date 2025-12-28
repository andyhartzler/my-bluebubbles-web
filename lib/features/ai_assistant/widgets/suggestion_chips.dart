import 'package:flutter/material.dart';

// Brand colors matching dashboard theme
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);

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
          backgroundColor: _momentumBlue.withOpacity(0.1),
          side: BorderSide(color: _momentumBlue.withOpacity(0.3)),
          labelStyle: TextStyle(
            color: _unityBlue,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          avatar: Icon(
            Icons.arrow_forward_ios,
            size: 12,
            color: _momentumBlue,
          ),
        );
      }).toList(),
    );
  }
}
