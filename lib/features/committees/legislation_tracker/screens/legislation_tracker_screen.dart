import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/legislation_provider.dart';
import '../models/tracked_bill.dart';
import 'bill_detail_screen.dart';
import 'bill_search_screen.dart';
import 'legislators_list_screen.dart';
import 'legislation_stats_dashboard.dart';

// Brand colors matching the main dashboard
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _grassrootsGreen = Color(0xFF43A047);
const _actionRed = Color(0xFFE63946);
const _sunriseGold = Color(0xFFFDB813);
const _justicePurple = Color(0xFF6A1B9A);

/// Modern Legislation Tracker screen with integrated dashboard
class LegislationTrackerScreen extends StatefulWidget {
  final String committeeId;
  final bool isMemberView;

  const LegislationTrackerScreen({
    super.key,
    required this.committeeId,
    this.isMemberView = false,
  });

  @override
  State<LegislationTrackerScreen> createState() => _LegislationTrackerScreenState();
}

class _LegislationTrackerScreenState extends State<LegislationTrackerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedPosition;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LegislationProvider>();
      provider.initialize();
      provider.loadStats();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LegislationProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.trackedBills.isEmpty) {
          return Stack(
            children: [
              _buildGradientBackground(),
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_momentumBlue),
                ),
              ),
            ],
          );
        }

        if (provider.error != null && provider.trackedBills.isEmpty) {
          return Stack(
            children: [
              _buildGradientBackground(),
              _buildErrorState(provider),
            ],
          );
        }

        return _buildContent(provider);
      },
    );
  }

  Widget _buildGradientBackground() {
    return Positioned.fill(
      child: Stack(
        children: [
          Image.asset(
            'assets/images/Blue-Gradient-Background.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          Container(
            color: Colors.white.withOpacity(0.18),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(LegislationProvider provider) {
    return Stack(
      children: [
        _buildGradientBackground(),
        Column(
          children: [
            // Tab bar at top
            Container(
              color: _unityBlue,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                indicatorColor: _momentumBlue,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'Overview', icon: Icon(Icons.dashboard_outlined, size: 20)),
                  Tab(text: 'All Bills', icon: Icon(Icons.list_alt_outlined, size: 20)),
                  Tab(text: 'Legislators', icon: Icon(Icons.people_outline, size: 20)),
                ],
              ),
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  LegislationStatsDashboard(
                    committeeId: widget.committeeId,
                    isExecutive: !widget.isMemberView,
                  ),
                  _buildAllBillsTab(provider),
                  LegislatorsListScreen(committeeId: widget.committeeId),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAllBillsTab(LegislationProvider provider) {
    return RefreshIndicator(
      onRefresh: () => provider.loadTrackedBills(),
      color: _momentumBlue,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // Position filter tabs
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildPositionTabs(provider),
            ),
          ),

          // Bill list
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: _buildBillList(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionTabs(LegislationProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: _unityBlue,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _unityBlue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            _buildTabButton('All', null, provider),
            _buildTabButton('Support', 'support', provider),
            _buildTabButton('Oppose', 'oppose', provider),
            _buildTabButton('Watching', 'watching', provider),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, String? position, LegislationProvider provider) {
    final isSelected = _selectedPosition == position;
    final count = _getCountForPosition(position, provider);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedPosition = position);
          provider.setPositionFilter(position);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _momentumBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _getCountForPosition(String? position, LegislationProvider provider) {
    if (position == null) return provider.trackedBills.length;
    if (position == 'support') return provider.supportedBills.length;
    if (position == 'oppose') return provider.opposedBills.length;
    if (position == 'watching') return provider.watchingBills.length;
    return 0;
  }

  Widget _buildBillList(LegislationProvider provider) {
    final bills = _getFilteredBills(provider);

    if (bills.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(provider),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final bill = bills[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: GestureDetector(
              onTap: () => _navigateToBillDetail(bill),
              child: _buildBillCard(bill),
            ),
          );
        },
        childCount: bills.length,
      ),
    );
  }

  List<TrackedBill> _getFilteredBills(LegislationProvider provider) {
    if (_selectedPosition == null) return provider.trackedBills;
    if (_selectedPosition == 'support') return provider.supportedBills;
    if (_selectedPosition == 'oppose') return provider.opposedBills;
    if (_selectedPosition == 'watching') return provider.watchingBills;
    return provider.trackedBills;
  }

  Widget _buildBillCard(TrackedBill bill) {
    final position = BillPosition.fromString(bill.position);
    final priority = BillPriority.fromString(bill.priority);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      color: _unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: position.color, width: 4),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(
              children: [
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
                if (bill.chamber != null)
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
                _buildPositionBadge(position),
              ],
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              bill.title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.white,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            if (bill.primarySponsorName != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: Colors.white.withOpacity(0.7)),
                  const SizedBox(width: 4),
                  Text(
                    bill.primarySponsorName!,
                    style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPositionBadge(BillPosition position) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: position.color.withOpacity(0.25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: position.color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(position.emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            position.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: position.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(LegislationProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.gavel_outlined,
                size: 56,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _selectedPosition != null
                  ? 'No bills in this category'
                  : 'No bills being tracked',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search and track bills from the Missouri Legislature',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _navigateToSearch(),
              icon: const Icon(Icons.search),
              label: const Text('Search Bills'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _unityBlue,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(LegislationProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'Error loading bills',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.error ?? 'An unknown error occurred',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => provider.loadTrackedBills(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _unityBlue,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToBillDetail(TrackedBill bill) {
    final provider = context.read<LegislationProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: provider,
          child: BillDetailScreen(
            billId: bill.id,
            committeeId: widget.committeeId,
          ),
        ),
      ),
    );
  }

  void _navigateToSearch() {
    final provider = context.read<LegislationProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: provider,
          child: BillSearchScreen(committeeId: widget.committeeId),
        ),
      ),
    );
  }
}
