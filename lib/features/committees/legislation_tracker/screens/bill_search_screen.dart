import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bill_search_provider.dart';
import '../providers/legislation_provider.dart';
import '../services/openstates_service.dart';
import '../models/tracked_bill.dart';
import '../utils/legislation_constants.dart';
import '../utils/bill_helpers.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);

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

  // For debouncing search
  DateTime? _lastSearchTime;
  static const _searchDebounceMs = 400;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);

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
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query.isEmpty) return;

    // Debounce search - wait for user to stop typing
    final now = DateTime.now();
    _lastSearchTime = now;

    Future.delayed(const Duration(milliseconds: _searchDebounceMs), () {
      if (_lastSearchTime == now && mounted && query.isNotEmpty) {
        context.read<BillSearchProvider>().quickSearch(query);
      }
    });

    // Update UI for clear button
    setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<BillSearchProvider>().loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Bills'),
        backgroundColor: _unityBlue,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              // Dark text on white background for search
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search Missouri bills...',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey.shade600),
                        onPressed: () {
                          _searchController.clear();
                          context.read<BillSearchProvider>().clearSearch();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              // Search happens automatically as you type via listener
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Gradient background
          Positioned.fill(
            child: Image.asset(
              'assets/images/Blue-Gradient-Background.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.18),
            ),
          ),
          // Content
          Column(
            children: [
              // Filters
              _buildFilters(context, theme),
              // Results
              Expanded(
                child: Consumer<BillSearchProvider>(
                  builder: (context, provider, child) {
                    if (provider.isSearching && provider.searchResults.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (provider.error != null) {
                      return _buildErrorState(context, theme, provider);
                    }

                    if (provider.searchResults.isEmpty && !provider.isSearching) {
                      return _buildEmptyState(context, theme, provider);
                    }

                    return _buildResultsList(context, theme, provider);
                  },
                ),
              ),
            ],
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
            color: _unityBlue.withOpacity(0.05),
            border: Border(
              bottom: BorderSide(color: _unityBlue.withOpacity(0.1)),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Session filter
                _buildFilterChip(
                  context,
                  label: 'Session',
                  value: provider.session,
                  items: ['2026', '2025', '2024', '2023'],
                  onSelected: (value) => provider.setSession(value ?? '2026'),
                ),
                const SizedBox(width: 8),
                // Chamber filter
                _buildFilterChip(
                  context,
                  label: 'Chamber',
                  value: provider.chamber ?? '',
                  items: const ['', 'lower', 'upper'],
                  itemLabels: const ['All Chambers', 'House', 'Senate'],
                  onSelected: (value) => provider.setChamber(value?.isEmpty == true ? null : value),
                ),
                const SizedBox(width: 8),
                // Classification filter
                _buildFilterChip(
                  context,
                  label: 'Type',
                  value: provider.classification ?? '',
                  items: const ['', 'bill', 'resolution', 'joint resolution', 'concurrent resolution'],
                  itemLabels: const ['All Types', 'Bill', 'Resolution', 'Joint Resolution', 'Concurrent Resolution'],
                  onSelected: (value) => provider.setClassification(value?.isEmpty == true ? null : value),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required String? value,
    required List<String> items,
    List<String>? itemLabels,
    required ValueChanged<String?> onSelected,
  }) {
    final displayValue = value?.isEmpty == true || value == null
        ? itemLabels?.first ?? 'All'
        : (itemLabels != null ? itemLabels[items.indexOf(value)] : value);

    return PopupMenuButton<String>(
      tooltip: label,
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => List.generate(items.length, (i) {
        final isSelected = items[i] == value || (items[i].isEmpty && value?.isEmpty != false);
        return PopupMenuItem<String>(
          value: items[i],
          child: Row(
            children: [
              if (isSelected)
                Icon(Icons.check, size: 18, color: _momentumBlue)
              else
                const SizedBox(width: 18),
              const SizedBox(width: 8),
              Text(
                itemLabels?[i] ?? items[i],
                style: const TextStyle(color: Colors.black87), // Dark text in popup
              ),
            ],
          ),
        );
      }),
      onSelected: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: value?.isNotEmpty == true ? _momentumBlue.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: value?.isNotEmpty == true ? _momentumBlue : _unityBlue.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 13,
                fontWeight: value?.isNotEmpty == true ? FontWeight.w600 : FontWeight.normal,
                color: value?.isNotEmpty == true ? _momentumBlue : _unityBlue,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: value?.isNotEmpty == true ? _momentumBlue : _unityBlue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(BuildContext context, ThemeData theme, BillSearchProvider provider) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: provider.searchResults.length + (provider.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == provider.searchResults.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final bill = provider.searchResults[index];
        final isTracked = provider.isBillTracked(bill.openstatesBillId);

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
      color: _unityBlue,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showBillDetails(context, bill),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Bill identifier - Momentum Blue badge with white text
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _momentumBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      bill.billIdentifier,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Chamber badge - subtle with white text
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      bill.chamber == 'lower' ? 'House' : 'Senate',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Tracked badge or track button
                  if (isTracked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.withOpacity(0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            'Tracked',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () => _trackBill(context, bill),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Track'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _momentumBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Title - white text on dark card
              Text(
                bill.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // Meta info - lighter white text
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.white.withOpacity(0.7)),
                  const SizedBox(width: 4),
                  Text(
                    'Session: ${bill.session}',
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
                  ),
                  const SizedBox(width: 16),
                  if (bill.latestActionDate != null) ...[
                    Icon(Icons.update, size: 14, color: Colors.white.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text(
                      BillHelpers.formatDate(DateTime.tryParse(bill.latestActionDate!)),
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
                    ),
                  ],
                ],
              ),

              // Latest action - subtle background with white text
              if (bill.latestActionDescription != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_forward_rounded, size: 16, color: _momentumBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          bill.latestActionDescription!,
                          style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9)),
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
    final hasSearched = _searchController.text.isNotEmpty || provider.query.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _unityBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasSearched ? Icons.search_off : Icons.search,
                size: 48,
                color: _unityBlue.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasSearched ? 'No bills found' : 'Search for bills',
              style: theme.textTheme.titleMedium?.copyWith(
                color: _unityBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearched
                  ? 'Try different search terms or filters'
                  : 'Enter a search term to find Missouri legislation',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _unityBlue.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            if (!hasSearched) ...[
              const SizedBox(height: 24),
              Text(
                'Popular Topics',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _momentumBlue),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSuggestionChip(context, 'Education'),
                  _buildSuggestionChip(context, 'Healthcare'),
                  _buildSuggestionChip(context, 'Tax'),
                  _buildSuggestionChip(context, 'Environment'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(BuildContext context, String label) {
    return ActionChip(
      label: Text(label, style: TextStyle(color: _unityBlue)),
      backgroundColor: _unityBlue.withOpacity(0.1),
      side: BorderSide(color: _unityBlue.withOpacity(0.3)),
      onPressed: () {
        _searchController.text = label;
        context.read<BillSearchProvider>().quickSearch(label);
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
            ),
            const SizedBox(height: 16),
            Text(
              'Search failed',
              style: theme.textTheme.titleMedium?.copyWith(
                color: _unityBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.error ?? 'An error occurred while searching',
              style: theme.textTheme.bodyMedium?.copyWith(color: _unityBlue.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                if (_searchController.text.isNotEmpty) {
                  provider.quickSearch(_searchController.text);
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _momentumBlue,
                foregroundColor: Colors.white,
              ),
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
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => _BillDetailSheet(
          bill: bill,
          scrollController: scrollController,
          committeeId: widget.committeeId,
          isTracked: context.read<BillSearchProvider>().isBillTracked(bill.openstatesBillId),
          onTrack: () => _trackBill(context, bill),
        ),
      ),
    );
  }

  Future<void> _trackBill(BuildContext context, OpenStatesBillSummary bill) async {
    final legislationProvider = context.read<LegislationProvider>();
    final searchProvider = context.read<BillSearchProvider>();

    try {
      await legislationProvider.trackBill(bill: bill, position: 'watching');
      searchProvider.addTrackedBillId(bill.openstatesBillId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Now tracking ${bill.billIdentifier}'),
            backgroundColor: _unityBlue,
            action: SnackBarAction(
              label: 'View',
              textColor: _momentumBlue,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to track bill: $e'), backgroundColor: Colors.red.shade700),
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

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header - Unity Blue background with white text
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: _unityBlue,
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _momentumBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          bill.billIdentifier,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${bill.chamber == 'lower' ? 'House' : 'Senate'} • Session ${bill.session}',
                        style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
                if (isTracked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.withOpacity(0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 18, color: Colors.green),
                        SizedBox(width: 6),
                        Text('Tracked', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
                      ],
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () {
                      onTrack();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Track Bill'),
                    style: ElevatedButton.styleFrom(backgroundColor: _momentumBlue, foregroundColor: Colors.white),
                  ),
              ],
            ),
          ),
          // Content - Light background with dark text
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // Title section
                Text(
                  'Title',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _momentumBlue),
                ),
                const SizedBox(height: 4),
                Text(
                  bill.title,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500, color: _unityBlue),
                ),
                const SizedBox(height: 24),

                // Latest action
                if (bill.latestActionDescription != null) ...[
                  Text(
                    'Latest Action',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _momentumBlue),
                  ),
                  const SizedBox(height: 4),
                  Card(
                    elevation: 0,
                    color: _unityBlue.withOpacity(0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.timeline, size: 20, color: _momentumBlue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (bill.latestActionDate != null)
                                  Text(
                                    BillHelpers.formatDate(DateTime.tryParse(bill.latestActionDate!)),
                                    style: TextStyle(fontSize: 12, color: _unityBlue.withOpacity(0.6)),
                                  ),
                                const SizedBox(height: 2),
                                Text(bill.latestActionDescription!, style: TextStyle(color: _unityBlue)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Primary sponsor
                if (bill.primarySponsor != null) ...[
                  Text(
                    'Primary Sponsor',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _momentumBlue),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person, size: 18, color: _unityBlue.withOpacity(0.6)),
                      const SizedBox(width: 8),
                      Text(bill.primarySponsor!, style: TextStyle(color: _unityBlue, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
