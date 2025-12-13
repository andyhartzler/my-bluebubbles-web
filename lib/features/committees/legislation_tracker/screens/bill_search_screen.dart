import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bill_search_provider.dart';
import '../providers/legislation_provider.dart';
import '../services/openstates_service.dart';
import '../models/tracked_bill.dart';
import '../utils/legislation_constants.dart';
import '../utils/bill_helpers.dart';

/// Screen for searching and tracking bills from Open States
class BillSearchScreen extends StatefulWidget {
  final String committeeId;

  const BillSearchScreen({
    super.key,
    required this.committeeId,
  });

  @override
  State<BillSearchScreen> createState() => _BillSearchScreenState();
}

class _BillSearchScreenState extends State<BillSearchScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Initialize the search provider with tracked bill IDs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final legislationProvider = context.read<LegislationProvider>();
      final searchProvider = context.read<BillSearchProvider>();
      searchProvider.setTrackedBillIds(
        legislationProvider.trackedBills.map((b) => b.openstatesBillId).toSet(),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<BillSearchProvider>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Bills'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Missouri bills...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          context.read<BillSearchProvider>().clearSearch();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  context.read<BillSearchProvider>().search(value);
                }
              },
              onChanged: (value) {
                setState(() {}); // Update clear button visibility
              },
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filters
          _buildFilters(context, theme),
          // Results
          Expanded(
            child: Consumer<BillSearchProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.results.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null) {
                  return _buildErrorState(context, theme, provider);
                }

                if (provider.results.isEmpty && !provider.isLoading) {
                  return _buildEmptyState(context, theme, provider);
                }

                return _buildResultsList(context, theme, provider);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context, ThemeData theme) {
    return Consumer<BillSearchProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: theme.dividerColor),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Session filter
                _buildFilterDropdown(
                  context,
                  theme,
                  label: 'Session',
                  value: provider.sessionFilter ?? currentSession,
                  items: ['2026', '2025', '2024', '2023'],
                  onChanged: (value) => provider.setSessionFilter(value),
                ),
                const SizedBox(width: 12),
                // Chamber filter
                _buildFilterDropdown(
                  context,
                  theme,
                  label: 'Chamber',
                  value: provider.chamberFilter,
                  items: const ['', 'lower', 'upper'],
                  itemLabels: const ['All', 'House', 'Senate'],
                  onChanged: (value) => provider.setChamberFilter(value?.isEmpty == true ? null : value),
                ),
                const SizedBox(width: 12),
                // Classification filter
                _buildFilterDropdown(
                  context,
                  theme,
                  label: 'Type',
                  value: provider.classificationFilter,
                  items: const ['', 'bill', 'resolution', 'joint resolution', 'concurrent resolution'],
                  itemLabels: const ['All', 'Bill', 'Resolution', 'Joint Resolution', 'Concurrent Resolution'],
                  onChanged: (value) => provider.setClassificationFilter(value?.isEmpty == true ? null : value),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterDropdown(
    BuildContext context,
    ThemeData theme, {
    required String label,
    required String? value,
    required List<String> items,
    List<String>? itemLabels,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      child: DropdownButtonFormField<String>(
        value: value ?? '',
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
        ),
        items: List.generate(items.length, (i) {
          return DropdownMenuItem(
            value: items[i],
            child: Text(itemLabels?[i] ?? items[i]),
          );
        }),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildResultsList(BuildContext context, ThemeData theme, BillSearchProvider provider) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: provider.results.length + (provider.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == provider.results.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final bill = provider.results[index];
        final isTracked = provider.isTracked(bill.openstatesId);

        return _buildSearchResultCard(context, theme, bill, isTracked);
      },
    );
  }

  Widget _buildSearchResultCard(
    BuildContext context,
    ThemeData theme,
    OpenStatesBillSummary bill,
    bool isTracked,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showBillDetails(context, bill),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Bill identifier
                  Text(
                    bill.identifier,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Chamber badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      bill.chamber == 'lower' ? 'House' : 'Senate',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  const Spacer(),
                  // Tracked badge or track button
                  if (isTracked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tracked',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => _trackBill(context, bill),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Track'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                bill.title,
                style: theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Meta info
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Session: ${bill.session}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (bill.latestActionDate != null) ...[
                    Icon(
                      Icons.update,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      BillHelpers.formatDate(bill.latestActionDate!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),

              // Latest action
              if (bill.latestActionDescription != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          bill.latestActionDescription!,
                          style: theme.textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme, BillSearchProvider provider) {
    final hasSearched = _searchController.text.isNotEmpty || provider.hasSearched;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasSearched ? Icons.search_off : Icons.search,
              size: 64,
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              hasSearched ? 'No bills found' : 'Search for bills',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearched
                  ? 'Try different search terms or filters'
                  : 'Enter a search term to find Missouri legislation',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            if (!hasSearched) ...[
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSuggestionChip(context, theme, 'Education'),
                  _buildSuggestionChip(context, theme, 'Healthcare'),
                  _buildSuggestionChip(context, theme, 'Tax'),
                  _buildSuggestionChip(context, theme, 'Environment'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(BuildContext context, ThemeData theme, String label) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        _searchController.text = label;
        context.read<BillSearchProvider>().search(label);
      },
    );
  }

  Widget _buildErrorState(BuildContext context, ThemeData theme, BillSearchProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              'Search failed',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.error ?? 'An error occurred while searching',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                if (_searchController.text.isNotEmpty) {
                  provider.search(_searchController.text);
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBillDetails(BuildContext context, OpenStatesBillSummary bill) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => _BillDetailSheet(
          bill: bill,
          scrollController: scrollController,
          committeeId: widget.committeeId,
          isTracked: context.read<BillSearchProvider>().isTracked(bill.openstatesId),
          onTrack: () => _trackBill(context, bill),
        ),
      ),
    );
  }

  Future<void> _trackBill(BuildContext context, OpenStatesBillSummary bill) async {
    final legislationProvider = context.read<LegislationProvider>();
    final searchProvider = context.read<BillSearchProvider>();

    try {
      await legislationProvider.trackBill(
        widget.committeeId,
        bill.openstatesId,
        initialPosition: 'watching',
      );

      searchProvider.addTrackedBillId(bill.openstatesId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Now tracking ${bill.identifier}'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                // Navigate to bill detail
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to track bill: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

/// Bottom sheet showing bill details
class _BillDetailSheet extends StatelessWidget {
  final OpenStatesBillSummary bill;
  final ScrollController scrollController;
  final String committeeId;
  final bool isTracked;
  final VoidCallback onTrack;

  const _BillDetailSheet({
    required this.bill,
    required this.scrollController,
    required this.committeeId,
    required this.isTracked,
    required this.onTrack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Handle
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.dividerColor),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.identifier,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${bill.chamber == 'lower' ? 'House' : 'Senate'} • Session ${bill.session}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isTracked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Tracked',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: () {
                    onTrack();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Track Bill'),
                ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              // Title
              Text(
                'Title',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(bill.title, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 24),

              // Latest action
              if (bill.latestActionDescription != null) ...[
                Text(
                  'Latest Action',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.timeline,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (bill.latestActionDate != null)
                                Text(
                                  BillHelpers.formatDate(bill.latestActionDate!),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              const SizedBox(height: 2),
                              Text(bill.latestActionDescription!),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Subjects
              if (bill.subjects != null && bill.subjects!.isNotEmpty) ...[
                Text(
                  'Subjects',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: bill.subjects!.map((subject) => Chip(
                        label: Text(subject, style: const TextStyle(fontSize: 12)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      )).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
