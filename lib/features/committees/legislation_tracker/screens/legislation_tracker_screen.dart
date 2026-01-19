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
  final TextEditingController _searchController = TextEditingController();
  bool _showFilters = false;

  // Smart filter state
  String? _partyFilter;
  String? _stageFilter;
  String? _categoryFilter;

  // AI status filters
  String? _aiAnalysisFilter; // 'analyzed', 'pending', 'not_analyzed', 'error'
  String? _aiPositionFilter; // 'support', 'oppose', 'watching', 'neutral'
  String? _aiPriorityFilter; // 'critical', 'high', 'medium', 'low'
  String? _aiTalkingPointsFilter; // 'generated', 'pending', 'not_generated'

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
    _searchController.dispose();
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
                  LegislatorsListScreen(
                    committeeId: widget.committeeId,
                    isMemberView: widget.isMemberView,
                  ),
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
          // Search bar
          SliverToBoxAdapter(
            child: _buildSearchBar(provider),
          ),

          // Smart filters (collapsible)
          if (_showFilters)
            SliverToBoxAdapter(
              child: _buildSmartFilters(provider),
            ),

          // Position filter tabs (not sticky)
          SliverPersistentHeader(
            pinned: false,
            delegate: _StickyPositionTabsDelegate(
              child: Container(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _buildPositionTabs(provider),
                ),
              ),
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

  Widget _buildSearchBar(LegislationProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _unityBlue,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _unityBlue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search bills by name, text, or summary...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.7)),
                          onPressed: () {
                            _searchController.clear();
                            provider.setSearchQuery('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (value) {
                  provider.setSearchQuery(value);
                  setState(() {}); // Update clear button visibility
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Advanced Search button
          Material(
            color: _showFilters || _hasActiveFilters() ? _momentumBlue : _unityBlue,
            borderRadius: BorderRadius.circular(12),
            elevation: 4,
            child: InkWell(
              onTap: () {
                setState(() {
                  _showFilters = !_showFilters;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        const Icon(Icons.tune, color: Colors.white, size: 18),
                        if (_hasActiveFilters())
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: _sunriseGold,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Advanced',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showFilters ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return _partyFilter != null ||
           _stageFilter != null ||
           _categoryFilter != null ||
           _aiAnalysisFilter != null ||
           _aiPositionFilter != null ||
           _aiPriorityFilter != null ||
           _aiTalkingPointsFilter != null;
  }

  int _countActiveFilters() {
    int count = 0;
    if (_partyFilter != null) count++;
    if (_stageFilter != null) count++;
    if (_categoryFilter != null) count++;
    if (_aiAnalysisFilter != null) count++;
    if (_aiPositionFilter != null) count++;
    if (_aiPriorityFilter != null) count++;
    if (_aiTalkingPointsFilter != null) count++;
    return count;
  }

  Widget _buildSmartFilters(LegislationProvider provider) {
    final filteredBills = _getFilteredBills(provider);
    final resultCount = filteredBills.length;
    final totalCount = provider.trackedBills.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Result count display
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _unityBlue.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        _hasActiveFilters() || provider.searchQuery.isNotEmpty
                            ? '$resultCount of $totalCount bills'
                            : '$totalCount bills',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_hasActiveFilters())
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _momentumBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_countActiveFilters()} filter${_countActiveFilters() > 1 ? 's' : ''} active',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Basic filters row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Party filter
                _buildFilterDropdown(
                  label: 'Party',
                  value: _partyFilter,
                  icon: Icons.people_outline,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Parties')),
                    DropdownMenuItem(value: 'Republican', child: Text('Republican (R)')),
                    DropdownMenuItem(value: 'Democratic', child: Text('Democrat (D)')),
                  ],
                  onChanged: (value) {
                    setState(() => _partyFilter = value);
                    _applyFilters(provider);
                  },
                ),
                const SizedBox(width: 8),
                // Stage filter
                _buildFilterDropdown(
                  label: 'Stage',
                  value: _stageFilter,
                  icon: Icons.stairs_outlined,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Stages')),
                    DropdownMenuItem(value: 'introduced', child: Text('Introduced')),
                    DropdownMenuItem(value: 'passed_lower', child: Text('Passed House')),
                    DropdownMenuItem(value: 'passed_upper', child: Text('Passed Senate')),
                    DropdownMenuItem(value: 'signed', child: Text('Signed')),
                    DropdownMenuItem(value: 'vetoed', child: Text('Vetoed')),
                  ],
                  onChanged: (value) {
                    setState(() => _stageFilter = value);
                    _applyFilters(provider);
                  },
                ),
                const SizedBox(width: 8),
                // Category filter
                _buildFilterDropdown(
                  label: 'Category',
                  value: _categoryFilter,
                  icon: Icons.category_outlined,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Categories')),
                    DropdownMenuItem(value: 'climate', child: Text('Climate')),
                    DropdownMenuItem(value: 'criminal_justice', child: Text('Criminal Justice')),
                    DropdownMenuItem(value: 'education', child: Text('Education')),
                    DropdownMenuItem(value: 'guns', child: Text('Guns')),
                    DropdownMenuItem(value: 'healthcare', child: Text('Healthcare')),
                    DropdownMenuItem(value: 'housing', child: Text('Housing')),
                    DropdownMenuItem(value: 'immigration', child: Text('Immigration')),
                    DropdownMenuItem(value: 'labor', child: Text('Labor')),
                    DropdownMenuItem(value: 'lgbtq', child: Text('LGBTQ+')),
                    DropdownMenuItem(value: 'taxes_budget', child: Text('Taxes & Budget')),
                    DropdownMenuItem(value: 'transportation', child: Text('Transportation')),
                    DropdownMenuItem(value: 'voting_rights', child: Text('Voting Rights')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    setState(() => _categoryFilter = value);
                    provider.setCategoryFilter(value);
                  },
                ),
                const SizedBox(width: 8),
                // Search in bill text toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: provider.searchBillText ? _momentumBlue : _unityBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: InkWell(
                    onTap: () {
                      provider.setSearchBillText(!provider.searchBillText);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Search Text',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // AI Status filters row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // AI Analysis status
                _buildFilterDropdown(
                  label: 'AI Analysis',
                  value: _aiAnalysisFilter,
                  icon: Icons.psychology,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All AI Status')),
                    DropdownMenuItem(value: 'analyzed', child: Text('✅ Analyzed')),
                    DropdownMenuItem(value: 'pending', child: Text('⏳ Pending')),
                    DropdownMenuItem(value: 'not_analyzed', child: Text('⬜ Not Analyzed')),
                    DropdownMenuItem(value: 'error', child: Text('❌ Error')),
                  ],
                  onChanged: (value) {
                    setState(() => _aiAnalysisFilter = value);
                    _applyFilters(provider);
                  },
                ),
                const SizedBox(width: 8),
                // AI Position Recommendation
                _buildFilterDropdown(
                  label: 'AI Position',
                  value: _aiPositionFilter,
                  icon: Icons.recommend,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Positions')),
                    DropdownMenuItem(value: 'support', child: Text('👍 Support')),
                    DropdownMenuItem(value: 'oppose', child: Text('👎 Oppose')),
                    DropdownMenuItem(value: 'watching', child: Text('👁️ Watching')),
                    DropdownMenuItem(value: 'neutral', child: Text('➖ Neutral')),
                  ],
                  onChanged: (value) {
                    setState(() => _aiPositionFilter = value);
                    _applyFilters(provider);
                  },
                ),
                const SizedBox(width: 8),
                // AI Priority Recommendation
                _buildFilterDropdown(
                  label: 'AI Priority',
                  value: _aiPriorityFilter,
                  icon: Icons.flag,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Priorities')),
                    DropdownMenuItem(value: 'critical', child: Text('🔴 Critical')),
                    DropdownMenuItem(value: 'high', child: Text('🟠 High')),
                    DropdownMenuItem(value: 'medium', child: Text('🟡 Medium')),
                    DropdownMenuItem(value: 'low', child: Text('🟢 Low')),
                  ],
                  onChanged: (value) {
                    setState(() => _aiPriorityFilter = value);
                    _applyFilters(provider);
                  },
                ),
                const SizedBox(width: 8),
                // AI Talking Points status
                _buildFilterDropdown(
                  label: 'Talking Points',
                  value: _aiTalkingPointsFilter,
                  icon: Icons.chat_bubble_outline,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(value: 'generated', child: Text('✅ Generated')),
                    DropdownMenuItem(value: 'pending', child: Text('⏳ Pending')),
                    DropdownMenuItem(value: 'not_generated', child: Text('⬜ Not Generated')),
                  ],
                  onChanged: (value) {
                    setState(() => _aiTalkingPointsFilter = value);
                    _applyFilters(provider);
                  },
                ),
              ],
            ),
          ),
          // Clear filters button
          if (_hasActiveFilters())
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _partyFilter = null;
                    _stageFilter = null;
                    _categoryFilter = null;
                    _aiAnalysisFilter = null;
                    _aiPositionFilter = null;
                    _aiPriorityFilter = null;
                    _aiTalkingPointsFilter = null;
                  });
                  provider.setCategoryFilter(null);
                  _applyFilters(provider);
                },
                icon: Icon(Icons.clear_all, size: 16, color: _momentumBlue),
                label: Text(
                  'Clear all filters',
                  style: TextStyle(color: _momentumBlue, fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String? value,
    required IconData icon,
    required List<DropdownMenuItem<String?>> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: value != null ? _momentumBlue : _unityBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          hint: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white.withOpacity(0.7)),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
            ],
          ),
          icon: Icon(Icons.arrow_drop_down, color: Colors.white.withOpacity(0.7), size: 18),
          dropdownColor: _unityBlue,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _applyFilters(LegislationProvider provider) {
    // Filter bills locally based on party and stage
    // The category filter is handled by the provider
    provider.loadTrackedBills();
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
    // Use stats from the database for accurate counts
    final stats = provider.stats;
    if (position == null) return stats.totalActiveBills;
    if (position == 'support') return stats.supportCount;
    if (position == 'oppose') return stats.opposeCount;
    if (position == 'watching') return stats.watchingCount;
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
    List<TrackedBill> bills;
    if (_selectedPosition == null) {
      bills = provider.trackedBills;
    } else if (_selectedPosition == 'support') {
      bills = provider.supportedBills;
    } else if (_selectedPosition == 'oppose') {
      bills = provider.opposedBills;
    } else if (_selectedPosition == 'watching') {
      bills = provider.watchingBills;
    } else {
      bills = provider.trackedBills;
    }

    // Apply local party filter
    if (_partyFilter != null) {
      bills = bills.where((bill) {
        if (bill.primarySponsorParty == null) return false;
        return bill.primarySponsorParty == _partyFilter;
      }).toList();
    }

    // Apply local stage filter
    if (_stageFilter != null) {
      bills = bills.where((bill) {
        switch (_stageFilter) {
          case 'introduced':
            return !bill.passedLower && !bill.passedUpper && !bill.signedByGovernor && !bill.vetoed;
          case 'passed_lower':
            return bill.passedLower && !bill.passedUpper;
          case 'passed_upper':
            return bill.passedUpper && !bill.signedByGovernor && !bill.vetoed;
          case 'signed':
            return bill.signedByGovernor;
          case 'vetoed':
            return bill.vetoed;
          default:
            return true;
        }
      }).toList();
    }

    // Apply AI analysis status filter
    if (_aiAnalysisFilter != null) {
      bills = bills.where((bill) {
        switch (_aiAnalysisFilter) {
          case 'analyzed':
            return bill.aiAnalyzedAt != null && bill.aiAnalysisError == null;
          case 'pending':
            return bill.aiAnalysisPending == true;
          case 'not_analyzed':
            return bill.aiAnalyzedAt == null && bill.aiAnalysisPending != true;
          case 'error':
            return bill.aiAnalysisError != null;
          default:
            return true;
        }
      }).toList();
    }

    // Apply AI position recommendation filter
    if (_aiPositionFilter != null) {
      bills = bills.where((bill) {
        return bill.aiPositionRecommendation == _aiPositionFilter;
      }).toList();
    }

    // Apply AI priority recommendation filter
    if (_aiPriorityFilter != null) {
      bills = bills.where((bill) {
        return bill.aiPriorityRecommendation == _aiPriorityFilter;
      }).toList();
    }

    // Apply AI talking points status filter
    if (_aiTalkingPointsFilter != null) {
      bills = bills.where((bill) {
        switch (_aiTalkingPointsFilter) {
          case 'generated':
            return bill.hasTalkingPoints;
          case 'not_generated':
            return !bill.hasTalkingPoints;
          default:
            return true;
        }
      }).toList();
    }

    return bills;
  }

  Widget _buildBillCard(TrackedBill bill) {
    final position = bill.position != null ? BillPosition.fromString(bill.position!) : null;
    final priority = bill.priority != null ? BillPriority.fromString(bill.priority!) : null;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      color: _unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: position?.color ?? _momentumBlue, width: 4),
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
                if (position != null) _buildPositionBadge(position),
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
                    '${bill.primarySponsorName!}${bill.primarySponsorParty != null ? ' (${_getPartyAbbreviation(bill.primarySponsorParty)})' : ''}',
                    style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8)),
                  ),
                ],
              ),
            ],
            // Categories
            if (bill.categories.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: bill.categories.take(3).map((cat) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _formatCategoryName(cat),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                )).toList(),
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

  String _getPartyAbbreviation(String? party) {
    if (party == null) return '?';
    switch (party.toLowerCase()) {
      case 'democratic':
        return 'D';
      case 'republican':
        return 'R';
      case 'independent':
        return 'I';
      default:
        return party.isNotEmpty ? party[0].toUpperCase() : '?';
    }
  }

  String _formatCategoryName(String category) {
    return category
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
        .join(' ');
  }
}

/// Delegate for sticky position filter tabs
class _StickyPositionTabsDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyPositionTabsDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        // Add subtle gradient background when sticky
        gradient: overlapsContent || shrinkOffset > 0
            ? LinearGradient(
                colors: [
                  _unityBlue.withOpacity(0.95),
                  _momentumBlue.withOpacity(0.85),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
      ),
      child: child,
    );
  }

  @override
  double get maxExtent => 68;

  @override
  double get minExtent => 68;

  @override
  bool shouldRebuild(covariant _StickyPositionTabsDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}
