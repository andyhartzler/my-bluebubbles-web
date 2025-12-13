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
      context.read<LegislationProvider>().selectBill(widget.billId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    context.read<LegislationProvider>().clearSelectedBill();
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

        if (provider.isLoading || bill == null) {
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
                onPressed: () => provider.syncBills(billId: widget.billId),
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
        // Header with bill info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  BillStatusBadge(bill: bill),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bill.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  PositionSelector(
                    currentPosition: BillPosition.fromString(bill.position),
                    onChanged: (position) => _updatePosition(provider, bill, position.value),
                    compact: true,
                  ),
                  const SizedBox(width: 8),
                  PrioritySelector(
                    currentPriority: BillPriority.fromString(bill.priority),
                    onChanged: (priority) => _updatePriority(provider, bill, priority.value),
                    showLabel: false,
                    compact: true,
                  ),
                ],
              ),
              if (provider.categories.isNotEmpty) ...[
                const SizedBox(height: 12),
                CategoryChips(
                  categories: provider.categories,
                  selectedCategories: bill.categories,
                  onChanged: (categories) => _updateCategories(provider, bill, categories),
                ),
              ],
            ],
          ),
        ),
        // Tab bar
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            _buildTab('Overview', Icons.info_outline, 0),
            _buildTab('Actions', Icons.timeline, provider.selectedBillActions.length),
            _buildTab('Votes', Icons.how_to_vote, provider.selectedBillVotes.length),
            _buildTab('Documents', Icons.description, provider.selectedBillDocuments.length),
            _buildTab('Notes', Icons.note, provider.selectedBillNotes.length),
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
              _buildDocumentsTab(context, theme, provider, bill),
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
        // Left sidebar with bill info
        SizedBox(
          width: 350,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BillStatusBadge(bill: bill),
                      const SizedBox(height: 12),
                      Text(
                        bill.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (bill.description != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          bill.description!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Position',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      PositionSelector(
                        currentPosition: BillPosition.fromString(bill.position),
                        onChanged: (position) => _updatePosition(provider, bill, position.value),
                      ),
                      const SizedBox(height: 16),
                      PrioritySelector(
                        currentPriority: BillPriority.fromString(bill.priority),
                        onChanged: (priority) => _updatePriority(provider, bill, priority.value),
                      ),
                      if (provider.categories.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Categories',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CategoryChips(
                          categories: provider.categories,
                          selectedCategories: bill.categories,
                          onChanged: (categories) => _updateCategories(provider, bill, categories),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Primary abstract
                      if (bill.primaryAbstract != null && bill.primaryAbstract!.isNotEmpty) ...[
                        Text(
                          'Summary',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          bill.primaryAbstract!,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Sponsors
                      if (provider.selectedBillSponsors.isNotEmpty) ...[
                        SponsorList(sponsors: provider.selectedBillSponsors),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        // Main content with tabs
        Expanded(
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: [
                  _buildTab('Overview', Icons.info_outline, 0),
                  _buildTab('Actions', Icons.timeline, provider.selectedBillActions.length),
                  _buildTab('Votes', Icons.how_to_vote, provider.selectedBillVotes.length),
                  _buildTab('Documents', Icons.description, provider.selectedBillDocuments.length),
                  _buildTab('Notes', Icons.note, provider.selectedBillNotes.length),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(context, theme, provider, bill),
                    _buildActionsTab(context, theme, provider, bill),
                    _buildVotesTab(context, theme, provider, bill),
                    _buildDocumentsTab(context, theme, provider, bill),
                    _buildNotesTab(context, theme, provider, bill),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String label, IconData icon, int count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ],
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
          // Bill details card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bill Information',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  _buildInfoRow(theme, 'Identifier', bill.billIdentifier),
                  _buildInfoRow(theme, 'Session', bill.session),
                  if (bill.chamber != null)
                    _buildInfoRow(theme, 'Chamber', bill.chamber == 'lower' ? 'House' : 'Senate'),
                  if (bill.primarySponsorName != null)
                    _buildInfoRow(theme, 'Primary Sponsor', bill.primarySponsorName!),
                  if (bill.latestActionDescription != null)
                    _buildInfoRow(theme, 'Latest Action', bill.latestActionDescription!),
                  if (bill.latestActionDate != null)
                    _buildInfoRow(theme, 'Action Date', BillHelpers.formatDate(bill.latestActionDate)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Summary card
          if (bill.primaryAbstract != null && bill.primaryAbstract!.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Summary',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    Text(bill.primaryAbstract!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Sponsors card
          if (provider.selectedBillSponsors.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sponsors',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    SponsorList(sponsors: provider.selectedBillSponsors),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
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
    final actions = provider.selectedBillActions;

    if (actions.isEmpty) {
      return _buildEmptyState(theme, 'No actions recorded', Icons.timeline);
    }

    return BillTimeline(
      actions: actions,
      onMarkSeen: () => provider.markActionsAsSeen(bill.id),
    );
  }

  Widget _buildVotesTab(
    BuildContext context,
    ThemeData theme,
    LegislationProvider provider,
    TrackedBill bill,
  ) {
    final votes = provider.selectedBillVotes;

    if (votes.isEmpty) {
      return _buildEmptyState(theme, 'No votes recorded', Icons.how_to_vote);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: votes.length,
      itemBuilder: (context, index) {
        final vote = votes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vote.motion ?? 'Vote',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (vote.voteDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    BillHelpers.formatDate(vote.voteDate),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                VoteBreakdownChart(vote: vote),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocumentsTab(
    BuildContext context,
    ThemeData theme,
    LegislationProvider provider,
    TrackedBill bill,
  ) {
    final documents = provider.selectedBillDocuments;

    if (documents.isEmpty) {
      return _buildEmptyState(theme, 'No documents available', Icons.description);
    }

    return BillDocumentsPanel(documents: documents);
  }

  Widget _buildNotesTab(
    BuildContext context,
    ThemeData theme,
    LegislationProvider provider,
    TrackedBill bill,
  ) {
    final notes = provider.selectedBillNotes;

    return BillNotesPanel(
      notes: notes,
      currentUserId: null, // TODO: Get from auth provider
      onAddNote: (content, isInternal) => provider.addNote(
        billId: bill.id,
        content: content,
      ),
      onDeleteNote: (note) => provider.deleteNote(note.id),
      onUpdateNote: (note, content) => provider.updateNote(
        noteId: note.id,
        content: content,
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePosition(LegislationProvider provider, TrackedBill bill, String position) async {
    await provider.updatePosition(billId: bill.id, position: position);
  }

  Future<void> _updatePriority(LegislationProvider provider, TrackedBill bill, String priority) async {
    await provider.updatePriority(billId: bill.id, priority: priority);
  }

  Future<void> _updateCategories(LegislationProvider provider, TrackedBill bill, List<String> categories) async {
    await provider.updateCategories(billId: bill.id, categories: categories);
  }

  void _handleMenuAction(BuildContext context, LegislationProvider provider, TrackedBill bill, String action) {
    switch (action) {
      case 'openstates':
        if (bill.openstatesUrl != null) {
          launchUrl(Uri.parse(bill.openstatesUrl!));
        }
        break;
      case 'legislature':
        // TODO: Construct MO legislature URL
        break;
      case 'archive':
        if (bill.isArchived) {
          provider.unarchiveBill(bill.id);
        } else {
          provider.archiveBill(billId: bill.id);
        }
        Navigator.pop(context);
        break;
    }
  }
}
