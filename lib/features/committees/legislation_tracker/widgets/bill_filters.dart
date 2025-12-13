import 'package:flutter/material.dart';
import '../models/tracked_bill.dart';
import '../models/legislation_category.dart';
import '../utils/legislation_constants.dart';

/// Widget providing filters for the bill list
class BillFilters extends StatelessWidget {
  final String? positionFilter;
  final String? priorityFilter;
  final String? categoryFilter;
  final String? sponsorFilter;
  final String searchQuery;
  final bool showArchived;
  final bool searchBillText;
  final List<LegislationCategory> categories;
  final List<String> sponsors;
  final ValueChanged<String?> onPositionChanged;
  final ValueChanged<String?> onPriorityChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onSponsorChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool> onShowArchivedChanged;
  final ValueChanged<bool> onSearchBillTextChanged;
  final VoidCallback? onClearFilters;

  const BillFilters({
    super.key,
    this.positionFilter,
    this.priorityFilter,
    this.categoryFilter,
    this.sponsorFilter,
    this.searchQuery = '',
    this.showArchived = false,
    this.searchBillText = false,
    required this.categories,
    this.sponsors = const [],
    required this.onPositionChanged,
    required this.onPriorityChanged,
    required this.onCategoryChanged,
    required this.onSponsorChanged,
    required this.onSearchChanged,
    required this.onShowArchivedChanged,
    required this.onSearchBillTextChanged,
    this.onClearFilters,
  });

  bool get hasActiveFilters =>
      positionFilter != null ||
      priorityFilter != null ||
      categoryFilter != null ||
      sponsorFilter != null ||
      searchQuery.isNotEmpty ||
      showArchived;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar with bill text toggle
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: searchBillText ? 'Search bills & text...' : 'Search bills...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => onSearchChanged(''),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: onSearchChanged,
                  controller: TextEditingController(text: searchQuery)
                    ..selection = TextSelection.collapsed(offset: searchQuery.length),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Search bill text content',
                child: FilterChip(
                  label: const Text('Text'),
                  selected: searchBillText,
                  onSelected: onSearchBillTextChanged,
                  avatar: searchBillText ? const Icon(Icons.article, size: 16) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Filter row
          if (isMobile)
            _buildMobileFilters(context, theme)
          else
            _buildDesktopFilters(context, theme),
        ],
      ),
    );
  }

  Widget _buildDesktopFilters(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        // Position filter
        _buildFilterDropdown(
          context: context,
          theme: theme,
          label: 'Position',
          value: positionFilter,
          items: [
            const DropdownMenuItem(value: null, child: Text('All Positions')),
            ...BillPosition.values.map((p) => DropdownMenuItem(
                  value: p.value,
                  child: Row(
                    children: [
                      Text(p.emoji),
                      const SizedBox(width: 6),
                      Text(p.label),
                    ],
                  ),
                )),
          ],
          onChanged: onPositionChanged,
        ),
        const SizedBox(width: 12),

        // Priority filter
        _buildFilterDropdown(
          context: context,
          theme: theme,
          label: 'Priority',
          value: priorityFilter,
          items: [
            const DropdownMenuItem(value: null, child: Text('All Priorities')),
            ...BillPriority.values.map((p) => DropdownMenuItem(
                  value: p.value,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: p.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(p.label),
                    ],
                  ),
                )),
          ],
          onChanged: onPriorityChanged,
        ),
        const SizedBox(width: 12),

        // Category filter
        if (categories.isNotEmpty)
          _buildFilterDropdown(
            context: context,
            theme: theme,
            label: 'Category',
            value: categoryFilter,
            items: [
              const DropdownMenuItem(value: null, child: Text('All Categories')),
              ...categories.map((c) => DropdownMenuItem(
                    value: c.name,
                    child: Row(
                      children: [
                        Icon(c.iconData, size: 16, color: c.colorValue),
                        const SizedBox(width: 6),
                        Text(c.displayName),
                      ],
                    ),
                  )),
            ],
            onChanged: onCategoryChanged,
          ),
        const SizedBox(width: 12),

        // Sponsor filter
        if (sponsors.isNotEmpty)
          _buildFilterDropdown(
            context: context,
            theme: theme,
            label: 'Sponsor',
            value: sponsorFilter,
            items: [
              const DropdownMenuItem(value: null, child: Text('All Sponsors')),
              ...sponsors.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(
                      s.length > 20 ? '${s.substring(0, 20)}...' : s,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
            ],
            onChanged: onSponsorChanged,
          ),
        const Spacer(),

        // Show archived toggle
        Row(
          children: [
            Checkbox(
              value: showArchived,
              onChanged: (value) => onShowArchivedChanged(value ?? false),
            ),
            const Text('Show Archived'),
          ],
        ),
        const SizedBox(width: 12),

        // Clear filters button
        if (hasActiveFilters && onClearFilters != null)
          TextButton.icon(
            onPressed: onClearFilters,
            icon: const Icon(Icons.clear_all, size: 18),
            label: const Text('Clear'),
          ),
      ],
    );
  }

  Widget _buildMobileFilters(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                context: context,
                label: positionFilter != null
                    ? BillPosition.fromString(positionFilter!).label
                    : 'Position',
                isActive: positionFilter != null,
                onTap: () => _showPositionFilterDialog(context),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                context: context,
                label: priorityFilter != null
                    ? BillPriority.fromString(priorityFilter!).label
                    : 'Priority',
                isActive: priorityFilter != null,
                onTap: () => _showPriorityFilterDialog(context),
              ),
              const SizedBox(width: 8),
              if (categories.isNotEmpty)
                _buildFilterChip(
                  context: context,
                  label: categoryFilter ?? 'Category',
                  isActive: categoryFilter != null,
                  onTap: () => _showCategoryFilterDialog(context),
                ),
              const SizedBox(width: 8),
              if (sponsors.isNotEmpty)
                _buildFilterChip(
                  context: context,
                  label: sponsorFilter != null
                      ? (sponsorFilter!.length > 15 ? '${sponsorFilter!.substring(0, 15)}...' : sponsorFilter!)
                      : 'Sponsor',
                  isActive: sponsorFilter != null,
                  onTap: () => _showSponsorFilterDialog(context),
                ),
              const SizedBox(width: 8),
              _buildFilterChip(
                context: context,
                label: 'Archived',
                isActive: showArchived,
                onTap: () => onShowArchivedChanged(!showArchived),
              ),
            ],
          ),
        ),
        if (hasActiveFilters && onClearFilters != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Clear Filters'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilterDropdown<T>({
    required BuildContext context,
    required ThemeData theme,
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: isActive
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: isActive
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPositionFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Filter by Position'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              onPositionChanged(null);
              Navigator.pop(context);
            },
            child: const Text('All Positions'),
          ),
          ...BillPosition.values.map((p) => SimpleDialogOption(
                onPressed: () {
                  onPositionChanged(p.value);
                  Navigator.pop(context);
                },
                child: Row(
                  children: [
                    Text(p.emoji),
                    const SizedBox(width: 8),
                    Text(p.label),
                    if (positionFilter == p.value) ...[
                      const Spacer(),
                      Icon(Icons.check, color: p.color),
                    ],
                  ],
                ),
              )),
        ],
      ),
    );
  }

  void _showPriorityFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Filter by Priority'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              onPriorityChanged(null);
              Navigator.pop(context);
            },
            child: const Text('All Priorities'),
          ),
          ...BillPriority.values.map((p) => SimpleDialogOption(
                onPressed: () {
                  onPriorityChanged(p.value);
                  Navigator.pop(context);
                },
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: p.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(p.label),
                    if (priorityFilter == p.value) ...[
                      const Spacer(),
                      const Icon(Icons.check),
                    ],
                  ],
                ),
              )),
        ],
      ),
    );
  }

  void _showCategoryFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Filter by Category'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              onCategoryChanged(null);
              Navigator.pop(context);
            },
            child: const Text('All Categories'),
          ),
          ...categories.map((c) => SimpleDialogOption(
                onPressed: () {
                  onCategoryChanged(c.name);
                  Navigator.pop(context);
                },
                child: Row(
                  children: [
                    Icon(c.iconData, size: 18, color: c.colorValue),
                    const SizedBox(width: 8),
                    Text(c.displayName),
                    if (categoryFilter == c.name) ...[
                      const Spacer(),
                      const Icon(Icons.check),
                    ],
                  ],
                ),
              )),
        ],
      ),
    );
  }

  void _showSponsorFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Filter by Sponsor'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              onSponsorChanged(null);
              Navigator.pop(context);
            },
            child: const Text('All Sponsors'),
          ),
          ...sponsors.map((s) => SimpleDialogOption(
                onPressed: () {
                  onSponsorChanged(s);
                  Navigator.pop(context);
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        s,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (sponsorFilter == s) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check),
                    ],
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
