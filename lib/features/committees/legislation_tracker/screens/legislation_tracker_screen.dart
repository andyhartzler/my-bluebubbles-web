import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/legislation_provider.dart';
import '../models/tracked_bill.dart';
import '../widgets/bill_list.dart';
import 'bill_detail_screen.dart';
import 'bill_search_screen.dart';
import 'legislation_dashboard_screen.dart';
import 'legislators_list_screen.dart';

// Brand colors matching the main dashboard
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _grassrootsGreen = Color(0xFF43A047);
const _actionRed = Color(0xFFE63946);
const _sunriseGold = Color(0xFFFDB813);
const _justicePurple = Color(0xFF6A1B9A);

/// Modern Legislation Tracker screen matching the main dashboard style
class LegislationTrackerScreen extends StatefulWidget {
  final String committeeId;

  const LegislationTrackerScreen({
    super.key,
    required this.committeeId,
  });

  @override
  State<LegislationTrackerScreen> createState() => _LegislationTrackerScreenState();
}

class _LegislationTrackerScreenState extends State<LegislationTrackerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedPosition;
  String? _selectedPriority;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LegislationProvider>();
      provider.initialize();
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
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_momentumBlue),
            ),
          );
        }

        if (provider.error != null && provider.trackedBills.isEmpty) {
          return _buildErrorState(provider);
        }

        return _buildContent(provider);
      },
    );
  }

  Widget _buildContent(LegislationProvider provider) {
    return RefreshIndicator(
      onRefresh: () => provider.loadTrackedBills(),
      color: _momentumBlue,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // Header section
          SliverToBoxAdapter(
            child: _buildHeader(provider),
          ),

          // Stats cards
          SliverToBoxAdapter(
            child: _buildStatsRow(provider),
          ),

          // Quick actions
          SliverToBoxAdapter(
            child: _buildQuickActions(provider),
          ),

          // Position filter tabs
          SliverToBoxAdapter(
            child: _buildPositionTabs(provider),
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

  Widget _buildHeader(LegislationProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_unityBlue, _momentumBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.gavel_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Legislation Tracker',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _unityBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${provider.trackedBills.length} bills tracked',
                  style: TextStyle(
                    fontSize: 14,
                    color: _unityBlue.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          if (provider.isSyncing)
            Container(
              padding: const EdgeInsets.all(8),
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(_momentumBlue),
                ),
              ),
            )
          else
            IconButton(
              onPressed: () => provider.syncBills(),
              icon: const Icon(Icons.sync_rounded),
              color: _unityBlue,
              tooltip: 'Sync with Open States',
            ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(LegislationProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 500;

          if (isNarrow) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildStatCard(
                      icon: Icons.check_circle_outline,
                      label: 'Support',
                      value: '${provider.supportedBills.length}',
                      colors: [_grassrootsGreen, _momentumBlue],
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard(
                      icon: Icons.cancel_outlined,
                      label: 'Oppose',
                      value: '${provider.opposedBills.length}',
                      colors: [_actionRed, _sunriseGold],
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildStatCard(
                      icon: Icons.visibility_outlined,
                      label: 'Watching',
                      value: '${provider.watchingBills.length}',
                      colors: [_momentumBlue, _justicePurple],
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard(
                      icon: Icons.warning_amber_rounded,
                      label: 'Critical',
                      value: '${provider.criticalBills.length}',
                      colors: [_sunriseGold, _actionRed],
                    )),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: _buildStatCard(
                icon: Icons.check_circle_outline,
                label: 'Support',
                value: '${provider.supportedBills.length}',
                colors: [_grassrootsGreen, _momentumBlue],
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(
                icon: Icons.cancel_outlined,
                label: 'Oppose',
                value: '${provider.opposedBills.length}',
                colors: [_actionRed, _sunriseGold],
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(
                icon: Icons.visibility_outlined,
                label: 'Watching',
                value: '${provider.watchingBills.length}',
                colors: [_momentumBlue, _justicePurple],
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(
                icon: Icons.warning_amber_rounded,
                label: 'Critical',
                value: '${provider.criticalBills.length}',
                colors: [_sunriseGold, _actionRed],
              )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required List<Color> colors,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(LegislationProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.search_rounded,
              label: 'Search Bills',
              onTap: () => _navigateToSearch(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              icon: Icons.dashboard_rounded,
              label: 'Dashboard',
              onTap: () => _navigateToDashboard(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              icon: Icons.people_rounded,
              label: 'Legislators',
              onTap: () => _navigateToLegislators(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _momentumBlue.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: _momentumBlue),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: _unityBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPositionTabs(LegislationProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _unityBlue.withOpacity(0.08),
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
            color: isSelected ? _unityBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : _unityBlue,
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
                      : _momentumBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? Colors.white : _momentumBlue,
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
                color: _momentumBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.gavel_outlined,
                size: 56,
                color: _momentumBlue.withOpacity(0.5),
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
                color: _unityBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search and track bills from the Missouri Legislature',
              style: TextStyle(
                fontSize: 14,
                color: _unityBlue.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _navigateToSearch(),
              icon: const Icon(Icons.search),
              label: const Text('Search Bills'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _momentumBlue,
                foregroundColor: Colors.white,
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
                color: _actionRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 48, color: _actionRed),
            ),
            const SizedBox(height: 20),
            const Text(
              'Error loading bills',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _unityBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.error ?? 'An unknown error occurred',
              style: TextStyle(
                fontSize: 14,
                color: _unityBlue.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => provider.loadTrackedBills(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _momentumBlue,
                foregroundColor: Colors.white,
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

  void _navigateToDashboard() {
    final provider = context.read<LegislationProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: provider,
          child: LegislationDashboardScreen(committeeId: widget.committeeId),
        ),
      ),
    );
  }

  void _navigateToLegislators() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LegislatorsListScreen(committeeId: widget.committeeId),
      ),
    );
  }
}
