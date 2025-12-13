import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/legislation_provider.dart';
import '../models/tracked_bill.dart';
import '../widgets/bill_status_badge.dart';
import '../widgets/position_selector.dart';
import '../widgets/priority_selector.dart';
import '../widgets/category_chips.dart';
import '../widgets/bill_timeline.dart';
import '../widgets/vote_breakdown_chart.dart';
import '../widgets/sponsor_list.dart';
import '../widgets/bill_notes_panel.dart';
import '../widgets/bill_documents_panel.dart';
import '../utils/bill_helpers.dart';

/// Detail screen for a tracked bill
class BillDetailScreen extends StatefulWidget {
  final String billId;
  final String committeeId;

  const BillDetailScreen({
    super.key,
    required this.billId,
    required this.committeeId,
  });

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    // Load bill details
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LegislationProvider>().loadBillDetails(
            widget.committeeId,
            widget.billId,
          );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 900;

    return Consumer<LegislationProvider>(
      builder: (context, provider, child) {
        final bill = provider.selectedBill;

        if (provider.isLoadingDetails || bill == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Bill Details')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(bill.billIdentifier),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => provider.syncBill(widget.committeeId, widget.billId),
                tooltip: 'Sync with Open States',
              ),
              PopupMenuButton<String>(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'openstates',
                    child: Row(
                      children: [
                        Icon(Icons.open_in_new),
                        SizedBox(width: 8),
                        Text('View on Open States'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'legislature',
                    child: Row(
                      children: [
                        Icon(Icons.account_balance),
                        SizedBox(width: 8),
                        Text('View on Legislature'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(bill.isArchived ? Icons.unarchive : Icons.archive),
                        const SizedBox(width: 8),
                        Text(bill.isArchived ? 'Unarchive' : 'Archive'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) => _handleMenuAction(context, provider, bill, value),
              ),
            ],
          ),
          body: isWideScreen
              ? _buildWideLayout(context, theme, provider, bill)
              : _buildMobileLayout(context, theme, provider, bill),
        );
      },
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    ThemeData theme,
    LegislationProvider provider,
    TrackedBill bill,
  ) {
    return Column(
      children: [
        // Header card
        _buildHeaderCard(context, theme, provider, bill),
        // Tabs
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            _buildTab('Overview', Icons.info_outline),
            _buildTab('Actions', Icons.timeline, _getNewCount(bill.actions)),
            _buildTab('Votes', Icons.how_to_vote, _getNewCount(bill.votes)),
            _buildTab('Documents', Icons.description, _getNewCount(bill.documents)),
            _buildTab('Notes', Icons.note, bill.notes?.length ?? 0),
          ],
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(context, theme, provider, bill),
              _buildActionsTab(context, theme, provider, bill),
              _buildVotesTab(context, theme, provider, bill),
              _buildDocumentsTab(context, theme, bill),
              _buildNotesTab(context, theme, provider, bill),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    ThemeData theme,
    LegislationProvider provider,
    TrackedBill bill,
  ) {
    return Row(
      children: [
        // Left sidebar: Overview and controls
        SizedBox(
          width: 400,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card
                _buildHeaderCard(context, theme, provider, bill),
                const SizedBox(height: 16),
                // Sponsors
                if (bill.sponsors != null && bill.sponsors!.isNotEmpty) ...[
                  SponsorList(sponsors: bill.sponsors!),
                  const SizedBox(height: 16),
                ],
                // Categories
                if (bill.categories.isNotEmpty) ...[
                  Text(
                    'Categories',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CategoryChips(
                    selectedCategories: bill.categories,
                    availableCategories: provider.categories,
                    onChanged: (categories) => _updateCategories(provider, bill, categories),
                  ),
                ],
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        // Right content: Tabs
        Expanded(
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: [
                  _buildTab('Actions', Icons.timeline, _getNewCount(bill.actions)),
                  _buildTab('Votes', Icons.how_to_vote, _getNewCount(bill.votes)),
                  _buildTab('Documents', Icons.description, _getNewCount(bill.documents)),
                  _buildTab('Notes', Icons.note, bill.notes?.length ?? 0),
                  _buildTab('Abstract', Icons.article),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildActionsTab(context, theme, provider, bill),
                    _buildVotesTab(context, theme, provider, bill),
                    _buildDocumentsTab(context, theme, bill),
                    _buildNotesTab(context, theme, provider, bill),
                    _buildAbstractTab(context, theme, bill),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String label, IconData icon, [int? count]) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label),
          if (count != null && count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    ThemeData theme,
    LegislationProvider provider,
    TrackedBill bill,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bill identifier and status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.billIdentifier,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Session: ${bill.session}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                BillStatusBadge(bill: bill),
              ],
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              bill.title,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // Position selector
            Text(
              'Our Position',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            PositionSelector(
              currentPosition: bill.position,
              onPositionChanged: (position) => _updatePosition(provider, bill, position),
            ),
            const SizedBox(height: 16),

            // Priority selector
            Text(
              'Priority',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            PrioritySelector(
              currentPriority: bill.priority,
              onPriorityChanged: (priority) => _updatePriority(provider, bill, priority),
            ),

            // Last updated
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.sync,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Last synced: ${bill.lastSyncedAt != null ? BillHelpers.formatRelativeTime(bill.lastSyncedAt!) : 'Never'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    ThemeData theme,
    LegislationProvider provider,
    TrackedBill bill,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Abstract
          if (bill.billAbstract != null && bill.billAbstract!.isNotEmpty) ...[
            Text(
              'Summary',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              bill.billAbstract!,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
          ],

          // Sponsors
          if (bill.sponsors != null && bill.sponsors!.isNotEmpty) ...[
            SponsorList(sponsors: bill.sponsors!),
            const SizedBox(height: 24),
          ],

          // Categories
          Text(
            'Categories',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          CategoryChips(
            selectedCategories: bill.categories,
            availableCategories: provider.categories,
            onChanged: (categories) => _updateCategories(provider, bill, categories),
          ),
          const SizedBox(height: 24),

          // Subject tags
          if (bill.subjects != null && bill.subjects!.isNotEmpty) ...[
            Text(
              'Subjects',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildActionsTab(
    BuildContext context,
    ThemeData theme,
    LegislationProvider provider,
    TrackedBill bill,
  ) {
    final actions = bill.actions ?? [];

    return BillTimeline(
      actions: actions,
      onMarkSeen: actions.any((a) => a.isNew)
          ? () => provider.markActionsSeen(widget.committeeId, widget.billId)
          : null,
    );
  }

  Widget _buildVotesTab(
    BuildContext context,
    ThemeData theme,
    LegislationProvider provider,
    TrackedBill bill,
  ) {
    final votes = bill.votes ?? [];

    return VoteBreakdownChart(
      votes: votes,
      onMarkSeen: votes.any((v) => v.isNew)
          ? () => provider.markVotesSeen(widget.committeeId, widget.billId)
          : null,
    );
  }

  Widget _buildDocumentsTab(
    BuildContext context,
    ThemeData theme,
    TrackedBill bill,
  ) {
    final documents = bill.documents ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: BillDocumentsPanel(documents: documents),
    );
  }

  Widget _buildNotesTab(
    BuildContext context,
    ThemeData theme,
    LegislationProvider provider,
    TrackedBill bill,
  ) {
    final notes = bill.notes ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: BillNotesPanel(
        notes: notes,
        onAddNote: (content, isInternal) => provider.addNote(
          widget.committeeId,
          widget.billId,
          content,
          isInternal,
        ),
        onDeleteNote: (note) => provider.deleteNote(
          widget.committeeId,
          widget.billId,
          note.id,
        ),
        onUpdateNote: (note, content) => provider.updateNote(
          widget.committeeId,
          widget.billId,
          note.id,
          content,
        ),
      ),
    );
  }

  Widget _buildAbstractTab(
    BuildContext context,
    ThemeData theme,
    TrackedBill bill,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bill.billAbstract != null && bill.billAbstract!.isNotEmpty) ...[
            Text(
              'Official Summary',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              bill.billAbstract!,
              style: theme.textTheme.bodyMedium,
            ),
          ] else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 48,
                      color: theme.colorScheme.outline.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No summary available',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  int _getNewCount<T>(List<T>? items) {
    if (items == null) return 0;
    return items.where((item) {
      if (item is dynamic && item.isNew is bool) {
        return item.isNew as bool;
      }
      return false;
    }).length;
  }

  Future<void> _updatePosition(LegislationProvider provider, TrackedBill bill, String position) async {
    await provider.updateBillPosition(widget.committeeId, bill.id, position);
  }

  Future<void> _updatePriority(LegislationProvider provider, TrackedBill bill, String priority) async {
    await provider.updateBillPriority(widget.committeeId, bill.id, priority);
  }

  Future<void> _updateCategories(LegislationProvider provider, TrackedBill bill, List<String> categories) async {
    await provider.updateBillCategories(widget.committeeId, bill.id, categories);
  }

  void _handleMenuAction(BuildContext context, LegislationProvider provider, TrackedBill bill, String action) {
    switch (action) {
      case 'openstates':
        if (bill.openstatesUrl != null) {
          launchUrl(Uri.parse(bill.openstatesUrl!));
        }
        break;
      case 'legislature':
        // Open Missouri Legislature URL
        final url = 'https://house.mo.gov/Bill.aspx?bill=${bill.billIdentifier}&year=${bill.session}';
        launchUrl(Uri.parse(url));
        break;
      case 'archive':
        provider.toggleBillArchived(widget.committeeId, bill.id, !bill.isArchived);
        break;
    }
  }
}
