import 'package:flutter/material.dart';
import '../models/legislation_category.dart';

/// Widget for displaying and selecting bill categories
class CategoryChips extends StatelessWidget {
  final List<String> selectedCategories;
  final List<LegislationCategory> availableCategories;
  final ValueChanged<List<String>> onChanged;
  final bool readOnly;
  final bool wrap;
  final int? maxDisplay;

  const CategoryChips({
    super.key,
    required this.selectedCategories,
    required this.availableCategories,
    required this.onChanged,
    this.readOnly = false,
    this.wrap = true,
    this.maxDisplay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Get category objects for selected categories
    final selectedCategoryObjects = selectedCategories
        .map((name) => availableCategories.firstWhere(
              (c) => c.name == name || c.id == name,
              orElse: () => LegislationCategory(
                id: name,
                name: name,
                displayName: name,
              ),
            ))
        .toList();

    if (readOnly) {
      return _buildReadOnlyChips(context, theme, selectedCategoryObjects);
    }

    return _buildEditableChips(context, theme);
  }

  Widget _buildReadOnlyChips(
    BuildContext context,
    ThemeData theme,
    List<LegislationCategory> categories,
  ) {
    final displayCategories = maxDisplay != null
        ? categories.take(maxDisplay!).toList()
        : categories;
    final remaining = categories.length - displayCategories.length;

    if (wrap) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          ...displayCategories.map((category) => _buildCategoryChip(
                context,
                theme,
                category,
                isSelected: true,
                onTap: null,
              )),
          if (remaining > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '+$remaining more',
                style: theme.textTheme.labelSmall,
              ),
            ),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...displayCategories.map((category) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _buildCategoryChip(
                  context,
                  theme,
                  category,
                  isSelected: true,
                  onTap: null,
                ),
              )),
          if (remaining > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '+$remaining',
                style: theme.textTheme.labelSmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditableChips(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categories',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: availableCategories.map((category) {
            final isSelected = selectedCategories.contains(category.name) ||
                selectedCategories.contains(category.id);
            return _buildCategoryChip(
              context,
              theme,
              category,
              isSelected: isSelected,
              onTap: () {
                final newSelection = List<String>.from(selectedCategories);
                if (isSelected) {
                  newSelection.remove(category.name);
                  newSelection.remove(category.id);
                } else {
                  newSelection.add(category.name);
                }
                onChanged(newSelection);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(
    BuildContext context,
    ThemeData theme,
    LegislationCategory category, {
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    final color = category.colorValue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                category.iconData,
                size: 14,
                color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                category.displayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog for selecting multiple categories
class CategorySelectionDialog extends StatefulWidget {
  final List<String> initialSelection;
  final List<LegislationCategory> categories;

  const CategorySelectionDialog({
    super.key,
    required this.initialSelection,
    required this.categories,
  });

  @override
  State<CategorySelectionDialog> createState() => _CategorySelectionDialogState();
}

class _CategorySelectionDialogState extends State<CategorySelectionDialog> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelection);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Select Categories'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.categories.map((category) {
              final isSelected = _selected.contains(category.name) ||
                  _selected.contains(category.id);
              final color = category.colorValue;

              return FilterChip(
                selected: isSelected,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      category.iconData,
                      size: 16,
                      color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(category.displayName),
                  ],
                ),
                selectedColor: color.withOpacity(0.2),
                checkmarkColor: color,
                side: BorderSide(
                  color: isSelected ? color : theme.colorScheme.outline.withOpacity(0.3),
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selected.add(category.name);
                    } else {
                      _selected.remove(category.name);
                      _selected.remove(category.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
