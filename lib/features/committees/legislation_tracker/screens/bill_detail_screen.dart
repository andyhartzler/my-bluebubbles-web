import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bluebubbles/providers/user_session_provider.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
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
import '../widgets/ai_analysis_panel.dart';
import '../widgets/talking_points_panel.dart';
import '../utils/bill_helpers.dart';
import '../models/legislator.dart';
import 'legislator_detail_screen.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _grassrootsGreen = Color(0xFF43A047);
const _actionRed = Color(0xFFE63946);

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
  LegislationProvider? _provider;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);

    // Load bill details
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = context.read<LegislationProvider>();
      _provider?.selectBill(widget.billId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _provider?.clearSelectedBill();
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
            appBar: AppBar(
              title: const Text('Bill Details'),
              backgroundColor: _unityBlue,
              foregroundColor: Colors.white,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(bill.billIdentifier),
            backgroundColor: _unityBlue,
            foregroundColor: Colors.white,
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
        _buildBillHeader(theme, provider, bill),
        // Tab bar
        Container(
          color: _unityBlue,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: _momentumBlue,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              _buildTab('Overview', Icons.info_outline, 0),
              _buildTab('AI Analysis', Icons.auto_awesome, 0),
              _buildTab('Talking Points', Icons.campaign, 0),
              _buildTab('Bill Text', Icons.article, 0),
              _buildTab('Actions', Icons.timeline, provider.selectedBillActions.length),
              _buildTab('Votes', Icons.how_to_vote, provider.selectedBillVotes.length),
              _buildTab('Documents', Icons.description, provider.selectedBillDocuments.length),
              _buildTab('Notes', Icons.note, provider.selectedBillNotes.length),
            ],
          ),
        ),
        // Tab content with gradient background
        Expanded(
          child: Stack(
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
              // Tab content - disable swiping
              Positioned.fill(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(), // Disable swipe
                  children: [
                    _buildOverviewTab(context, theme, provider, bill),
                    _buildAiAnalysisTab(context, theme, provider, bill),
                    _buildTalkingPointsTab(context, theme, provider, bill),
                    _buildBillTextTab(context, theme, bill),
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

  Widget _buildBillHeader(ThemeData theme, LegislationProvider provider, TrackedBill bill) {
    final position = BillPosition.fromString(bill.position);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _unityBlue,
        border: Border(
          left: BorderSide(color: position.color, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BillStatusBadge(bill: bill, darkBackground: true),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  bill.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.3,
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
          // Position setter info
          if (bill.positionSetByName != null || bill.positionSetAt != null) ...[
            const SizedBox(height: 8),
            _buildPositionSetterInfo(bill),
          ],
          if (provider.categories.isNotEmpty) ...[
            const SizedBox(height: 12),
            CategoryChips(
              availableCategories: provider.categories,
              selectedCategories: bill.categories,
              onChanged: (categories) => _updateCategories(provider, bill, categories),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    ThemeData theme,
    LegislationProvider provider,
    TrackedBill bill,
  ) {
    final position = BillPosition.fromString(bill.position);

    return Row(
      children: [
        // Left sidebar with bill info
        SizedBox(
          width: 380,
          child: Container(
            color: _unityBlue,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BillStatusBadge(bill: bill, expanded: true, darkBackground: true),
                        const SizedBox(height: 16),
                        Text(
                          bill.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.3,
                          ),
                        ),
                        if (bill.description != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            bill.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        _buildSidebarSection('Position'),
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
                          const SizedBox(height: 20),
                          _buildSidebarSection('Categories'),
                          const SizedBox(height: 8),
                          CategoryChips(
                            availableCategories: provider.categories,
                            selectedCategories: bill.categories,
                            onChanged: (categories) => _updateCategories(provider, bill, categories),
                          ),
                        ],
                        // Primary abstract
                        if (bill.primaryAbstract != null && bill.primaryAbstract!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _buildSidebarSection('Summary'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              bill.primaryAbstract!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.9),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                        // Sponsors
                        if (provider.selectedBillSponsors.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          SponsorList(
                            sponsors: provider.selectedBillSponsors,
                            onLegislatorTap: _navigateToLegislatorDetail,
                            darkBackground: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Main content with tabs
        Expanded(
          child: Column(
            children: [
              Container(
                color: _unityBlue.withOpacity(0.9),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: _momentumBlue,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  tabs: [
                    _buildTab('Overview', Icons.info_outline, 0),
                    _buildTab('AI Analysis', Icons.auto_awesome, 0),
                    _buildTab('Talking Points', Icons.campaign, 0),
                    _buildTab('Bill Text', Icons.article, 0),
                    _buildTab('Actions', Icons.timeline, provider.selectedBillActions.length),
                    _buildTab('Votes', Icons.how_to_vote, provider.selectedBillVotes.length),
                    _buildTab('Documents', Icons.description, provider.selectedBillDocuments.length),
                    _buildTab('Notes', Icons.note, provider.selectedBillNotes.length),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
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
                    // Tab content - disable swiping
                    Positioned.fill(
                      child: TabBarView(
                        controller: _tabController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildOverviewTab(context, theme, provider, bill),
                          _buildAiAnalysisTab(context, theme, provider, bill),
                          _buildTalkingPointsTab(context, theme, provider, bill),
                          _buildBillTextTab(context, theme, bill),
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
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarSection(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: _momentumBlue,
        letterSpacing: 0.5,
      ),
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
                color: _momentumBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
          _buildInfoCard(
            title: 'Bill Information',
            icon: Icons.gavel,
            children: [
              _buildInfoRow('Identifier', bill.billIdentifier),
              _buildInfoRow('Session', bill.session),
              if (bill.chamber != null)
                _buildInfoRow('Chamber', bill.chamber == 'lower' ? 'House' : 'Senate'),
              if (bill.primarySponsorName != null)
                _buildInfoRow('Primary Sponsor', bill.primarySponsorName!),
              if (bill.latestActionDescription != null)
                _buildInfoRow('Latest Action', bill.latestActionDescription!),
              if (bill.latestActionDate != null)
                _buildInfoRow('Action Date', BillHelpers.formatDate(bill.latestActionDate)),
            ],
          ),
          const SizedBox(height: 16),
          // Summary card
          if (bill.primaryAbstract != null && bill.primaryAbstract!.isNotEmpty) ...[
            _buildInfoCard(
              title: 'Summary',
              icon: Icons.description,
              children: [
                Text(
                  bill.primaryAbstract!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          // Sponsors card
          if (provider.selectedBillSponsors.isNotEmpty) ...[
            _buildInfoCard(
              title: 'Sponsors',
              icon: Icons.people,
              children: [
                SponsorList(
                  sponsors: provider.selectedBillSponsors,
                  onLegislatorTap: _navigateToLegislatorDetail,
                  darkBackground: true,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      color: _unityBlue,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _momentumBlue, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiAnalysisTab(
    BuildContext context,
    ThemeData theme,
    LegislationProvider provider,
    TrackedBill bill,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: AiAnalysisPanel(
        bill: bill,
        onAnalysisComplete: () {
          // Refresh the bill data
          provider.selectBill(bill.id);
        },
        onApplyPosition: (position) async {
          final memberId = context.read<UserSessionProvider>().currentMember?.id;
          await provider.updatePosition(billId: bill.id, position: position, memberId: memberId);
        },
        onApplyPriority: (priority) async {
          await provider.updatePriority(billId: bill.id, priority: priority);
        },
        onApplyCategories: (categories) async {
          await provider.updateCategories(billId: bill.id, categories: categories);
        },
      ),
    );
  }

  Widget _buildTalkingPointsTab(
    BuildContext context,
    ThemeData theme,
    LegislationProvider provider,
    TrackedBill bill,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: TalkingPointsPanel(
        bill: bill,
        onGenerated: () {
          // Refresh the bill data
          provider.selectBill(bill.id);
        },
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
      return _buildEmptyState('No actions recorded', Icons.timeline);
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
      return _buildEmptyState('No votes recorded', Icons.how_to_vote);
    }

    return VoteBreakdownChart(
      votes: votes,
      onMarkSeen: () => provider.markVotesAsSeen(bill.id),
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
      return _buildEmptyState('No documents available', Icons.description);
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

  Widget _buildBillTextTab(
    BuildContext context,
    ThemeData theme,
    TrackedBill bill,
  ) {
    // Check if bill has text
    if (!bill.hasText && !bill.hasPdf) {
      return _buildEmptyState(
        bill.textExtractionFailed
            ? 'Failed to extract bill text'
            : 'Bill text not yet available',
        Icons.article_outlined,
      );
    }

    return Column(
      children: [
        // Header with PDF button and metadata
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _unityBlue,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (bill.currentBillTextVersion != null)
                          Text(
                            'Version: ${bill.currentBillTextVersion}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        if (bill.currentBillTextWordCount != null)
                          Text(
                            '${bill.currentBillTextWordCount} words',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        if (bill.currentBillTextExtractedAt != null)
                          Text(
                            'Extracted: ${BillHelpers.formatDate(bill.currentBillTextExtractedAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (bill.hasPdf)
                    ElevatedButton.icon(
                      onPressed: () => _openPdf(bill),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('View PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _momentumBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        // Bill text content
        Expanded(
          child: bill.hasText
              ? Container(
                  color: Colors.grey.shade100,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      bill.currentBillText!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                )
              : _buildEmptyState('Text not extracted - PDF available', Icons.picture_as_pdf),
        ),
      ],
    );
  }

  void _openPdf(TrackedBill bill) {
    final pdfUrl = bill.pdfUrl;
    if (pdfUrl != null) {
      launchUrl(Uri.parse(pdfUrl));
    }
  }

  void _navigateToLegislatorDetail(Legislator legislator) {
    final provider = context.read<LegislationProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: provider,
          child: LegislatorDetailScreen(
            legislatorId: legislator.id,
            committeeId: widget.committeeId,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
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
              icon,
              size: 48,
              color: _unityBlue.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: _unityBlue.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePosition(LegislationProvider provider, TrackedBill bill, String position) async {
    final memberId = context.read<UserSessionProvider>().currentMember?.id;
    await provider.updatePosition(billId: bill.id, position: position, memberId: memberId);
  }

  Future<void> _updatePriority(LegislationProvider provider, TrackedBill bill, String priority) async {
    await provider.updatePriority(billId: bill.id, priority: priority);
  }

  Future<void> _updateCategories(LegislationProvider provider, TrackedBill bill, List<String> categories) async {
    await provider.updateCategories(billId: bill.id, categories: categories);
  }

  Widget _buildPositionSetterInfo(TrackedBill bill) {
    final userSession = context.read<UserSessionProvider>();
    final isExecutive = userSession.isExecutive;
    final hasName = bill.positionSetByName != null;
    final hasDate = bill.positionSetAt != null;

    if (!hasName && !hasDate) return const SizedBox.shrink();

    // Format the date
    String dateText = '';
    if (hasDate) {
      final date = bill.positionSetAt!;
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays == 0) {
        dateText = 'today';
      } else if (diff.inDays == 1) {
        dateText = 'yesterday';
      } else if (diff.inDays < 7) {
        dateText = '${diff.inDays} days ago';
      } else {
        dateText = '${date.month}/${date.day}/${date.year}';
      }
    }

    // Get initials for fallback avatar
    String initials = '';
    if (hasName) {
      final parts = bill.positionSetByName!.split(' ');
      if (parts.isNotEmpty) {
        initials = parts.map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase();
      }
    }

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar
        CircleAvatar(
          radius: 12,
          backgroundColor: _momentumBlue.withOpacity(0.3),
          child: bill.positionSetByPhotoUrl != null
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: bill.positionSetByPhotoUrl!,
                    width: 24,
                    height: 24,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Text(
                      initials,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    errorWidget: (context, url, error) => Text(
                      initials,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                )
              : Text(
                  initials,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                ),
        ),
        const SizedBox(width: 6),
        // Text
        Text(
          hasName && hasDate
              ? 'Set by ${bill.positionSetByName} $dateText'
              : hasName
                  ? 'Set by ${bill.positionSetByName}'
                  : 'Set $dateText',
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        // Arrow icon for executives
        if (isExecutive && bill.positionSetBy != null) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_forward_ios,
            size: 10,
            color: Colors.white.withOpacity(0.5),
          ),
        ],
      ],
    );

    // Make clickable for executives
    if (isExecutive && bill.positionSetBy != null) {
      return InkWell(
        onTap: () => _navigateToMemberProfile(bill.positionSetBy!),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: content,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: content,
    );
  }

  Future<void> _navigateToMemberProfile(String memberId) async {
    // Fetch the member from the repository
    final memberRepo = MemberRepository();
    final member = await memberRepo.getMemberById(memberId);

    if (member == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member not found')),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MemberDetailScreen(member: member),
        ),
      );
    }
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
