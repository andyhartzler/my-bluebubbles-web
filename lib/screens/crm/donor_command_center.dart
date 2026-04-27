import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/donor_profile.dart';
import 'package:bluebubbles/services/crm/donor_profile_repository.dart';

import 'package:bluebubbles/screens/crm/donor_profile_screen.dart';
import 'package:bluebubbles/screens/crm/tabs/mec_research_tab.dart';
import 'package:bluebubbles/screens/crm/tabs/call_time_tab.dart';
import 'package:bluebubbles/screens/crm/tabs/committees_tab.dart';
import 'package:bluebubbles/screens/crm/tabs/fundraising_tab.dart';

// ---------------------------------------------------------------------------
// DonorCommandCenter
// ---------------------------------------------------------------------------

class DonorCommandCenter extends StatefulWidget {
  final bool embed;

  const DonorCommandCenter({super.key, this.embed = false});

  @override
  State<DonorCommandCenter> createState() => _DonorCommandCenterState();
}

class _DonorCommandCenterState extends State<DonorCommandCenter>
    with SingleTickerProviderStateMixin {
  static const _pageSize = 25;

  // 5-tab container: MOYD Donors (current view) / Fundraising (donation
  // manager + thank-you tracker) / Donor Research (MEC+FEC research via
  // MecResearchTab) / Call Time / Committees. The main CRM nav's "Donors"
  // button lands here, so this is the only entry point users have to these
  // sub-features. The legacy DonorsListScreen was collapsed into this screen
  // (2026-04-22) so callers only ever see one donors UI.
  late final TabController _tabController;

  /// Needed so MecResearchTab's "Navigate to committee" callback can switch to
  /// the Committees tab AND open a specific committee by id.
  final GlobalKey<CommitteesTabState> _committeesKey =
      GlobalKey<CommitteesTabState>();

  final DonorProfileRepository _repository = DonorProfileRepository();

  // Data
  DonorProfileStats? _stats;
  List<DonorProfileSearchResult> _results = [];
  int _totalCount = 0;
  int _currentPage = 0;
  bool _loading = true;
  String? _error;

  /// Set of profile IDs (from the current page of [_results]) that have a
  /// non-null `donor_profiles.mo_voter_file_id`. Used to render a small
  /// voter-registration indicator next to each donor row. Fetched in a
  /// lightweight follow-up query after each [_search] so we don't have to
  /// modify the `search_donor_profiles` RPC.
  Set<String> _voterFileIds = <String>{};

  // Search
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  // Bulk selection
  Set<String> _selectedIds = {};

  // Filter state
  String? _selectedTier;
  String? _selectedCounty;
  String? _selectedCD;
  String? _selectedPartyLean;
  double? _minWealthScore;
  double? _maxWealthScore;
  double? _minPoliticalGiving;
  bool? _hasEnrichment;
  bool? _hasVan;
  bool? _hasPropertyRecords;
  bool? _isHomeowner;
  List<String>? _selectedTags;

  // Sort state
  String _sortBy = 'name';
  bool _ascending = true;

  // Tag list for filter UI
  List<String> _availableTags = [];

  // Formatters
  static final _currencyFmt =
      NumberFormat.currency(symbol: '\$', decimalDigits: 0);
  static final _compactFmt = NumberFormat.compact();
  static final _dateFmt = DateFormat('MM/dd/yyyy');

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadStats(),
      _search(),
      _loadTags(),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Data methods
  // ---------------------------------------------------------------------------

  Future<void> _loadStats() async {
    try {
      final stats = await _repository.getDonorStats();
      if (mounted) setState(() => _stats = stats);
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> _loadTags() async {
    try {
      final tags = await _repository.getAllTags();
      if (mounted) setState(() => _availableTags = tags);
    } catch (e) {
      debugPrint('Error loading tags: $e');
    }
  }

  Future<void> _search() async {
    if (mounted) setState(() => _loading = true);

    try {
      final result = await _repository.searchProfiles(
        query: _searchController.text.isEmpty ? null : _searchController.text,
        tier: _selectedTier,
        county: _selectedCounty,
        congressionalDistrict: _selectedCD,
        partyLean: _selectedPartyLean,
        minWealthScore: _minWealthScore,
        maxWealthScore: _maxWealthScore,
        minPoliticalGiving: _minPoliticalGiving,
        hasEnrichment: _hasEnrichment,
        hasVan: _hasVan,
        hasPropertyRecords: _hasPropertyRecords,
        isHomeowner: _isHomeowner,
        tags: _selectedTags,
        sortBy: _sortBy,
        ascending: _ascending,
        page: _currentPage,
        pageSize: _pageSize,
      );

      if (mounted) {
        setState(() {
          _results = result.results;
          _totalCount = result.totalCount;
          _loading = false;
          _error = null;
          _voterFileIds = <String>{};
        });
        // Fire-and-forget: populate voter-file indicator for visible rows.
        unawaited(_loadVoterFileIndicators());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load donors: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadVoterFileIndicators() async {
    final ids = _results.map((r) => r.id).whereType<String>().toList();
    if (ids.isEmpty) return;
    try {
      final matched = await _repository.fetchVoterFileIdsForProfiles(ids);
      if (!mounted) return;
      // Only apply if the result set hasn't changed underneath us.
      final currentIds = _results.map((r) => r.id).whereType<String>().toSet();
      if (!currentIds.containsAll(matched)) return;
      setState(() => _voterFileIds = matched);
    } catch (e) {
      debugPrint('Error loading voter-file indicators: $e');
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _currentPage = 0;
      _search();
    });
  }

  void _onSortChanged(String column) {
    setState(() {
      if (_sortBy == column) {
        _ascending = !_ascending;
      } else {
        _sortBy = column;
        _ascending = true;
      }
      _currentPage = 0;
    });
    _search();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _search();
  }

  void _clearFilters() {
    setState(() {
      _selectedTier = null;
      _selectedCounty = null;
      _selectedCD = null;
      _selectedPartyLean = null;
      _minWealthScore = null;
      _maxWealthScore = null;
      _minPoliticalGiving = null;
      _hasEnrichment = null;
      _hasVan = null;
      _hasPropertyRecords = null;
      _isHomeowner = null;
      _selectedTags = null;
      _searchController.clear();
      _currentPage = 0;
    });
    _search();
  }

  void _showMobileFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => StatefulBuilder(
          builder: (bCtx, setSheetState) => Theme(
            data: _lightFilterTheme(bCtx),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1F36),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _clearFilters();
                          Navigator.pop(bCtx);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: BrandColors.momentumBlue,
                        ),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildFilterContent(
                    scrollController: scrollCtrl,
                    onChanged: () {
                      setSheetState(() {});
                      setState(() {});
                      _currentPage = 0;
                      _search();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToProfile(String? profileId) {
    if (profileId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DonorProfileScreen(profileId: profileId),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // The existing MOYD-donors view (stats + filter sidebar + donor table)
    // becomes the body of Tab 0. The other tabs reuse the existing tab-body
    // widgets originally written for the now-deleted DonorsListScreen.
    final moydDonorsBody = LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        return Container(
          color: const Color(0xFFF6F8FB),
          child: Column(
            children: [
              _buildHeroMetrics(),
              const SizedBox(height: 8),
              Expanded(
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 280,
                            child: _buildFilterSidebar(),
                          ),
                          const VerticalDivider(width: 1, color: Color(0xFFE5E7EB)),
                          Expanded(child: _buildMainContent(constraints.maxWidth - 281)),
                        ],
                      )
                    : _buildMainContent(constraints.maxWidth),
              ),
              _buildBulkActionBar(),
            ],
          ),
        );
      },
    );

    final tabView = TabBarView(
      controller: _tabController,
      // Disable swipe-to-change-tab. Andrew's rule: tabs are clickable only.
      physics: const NeverScrollableScrollPhysics(),
      children: [
        moydDonorsBody,
        const FundraisingTab(),
        MecResearchTab(
          onNavigateToCommittee: (committeeId, committeeName, source) {
            // Hop to the Committees tab inside this screen and open the
            // committee detail via CommitteesTab's imperative API.
            _tabController.animateTo(4);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _committeesKey.currentState?.openCommitteeById(
                committeeId,
                committeeName,
                source,
              );
            });
          },
        ),
        const CallTimeTab(),
        CommitteesTab(key: _committeesKey),
      ],
    );

    if (widget.embed) {
      return Column(
        children: [
          _buildTabBar(),
          Expanded(child: tabView),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donors'),
        backgroundColor: BrandColors.unityBlue,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildTabBar(),
        ),
        actions: [
          LayoutBuilder(
            builder: (ctx, c) {
              return Builder(
                builder: (innerCtx) {
                  final mq = MediaQuery.of(innerCtx).size.width;
                  if (mq >= 900) return const SizedBox.shrink();
                  // Show filter icon only on narrow screens AND only on the
                  // MOYD Donors tab (the only tab with a filter sidebar).
                  return AnimatedBuilder(
                    animation: _tabController,
                    builder: (_, __) {
                      if (_tabController.index != 0) return const SizedBox.shrink();
                      return IconButton(
                        icon: const Icon(Icons.filter_list),
                        tooltip: 'Filters',
                        onPressed: _showMobileFilters,
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: BrandColors.tileGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: tabView,
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      // Default `LinearGradient` begins at topLeft → bottomRight, which puts
      // the top edge on a different color than the unityBlue AppBar above
      // — a visible diagonal seam. Run the gradient horizontally so the
      // top edge stays uniform and flows cleanly from the AppBar.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: BrandColors.tileGradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        // 5 tabs don't fit at their natural width on phone — let the bar
        // scroll horizontally on narrow screens.
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: BrandColors.sunriseGold,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: const [
          Tab(icon: Icon(Icons.volunteer_activism), text: 'MOYD Donors'),
          Tab(icon: Icon(Icons.savings), text: 'Fundraising'),
          Tab(icon: Icon(Icons.manage_search), text: 'Donor Research'),
          Tab(icon: Icon(Icons.phone_callback), text: 'Call Time'),
          Tab(icon: Icon(Icons.account_balance), text: 'Committees'),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero Metrics Bar
  // ---------------------------------------------------------------------------

  Widget _buildHeroMetrics() {
    final cards = <_MetricDef>[
      _MetricDef(
        icon: Icons.people,
        label: 'Total Donors',
        value: _compactFmt.format(_stats?.totalProfiles ?? 0),
        gradient: const [BrandColors.unityBlue, BrandColors.momentumBlue],
      ),
      _MetricDef(
        icon: Icons.volunteer_activism,
        label: 'Total Raised MOYD',
        value: _currencyFmt.format(_stats?.totalRaisedMoyd ?? 0),
        gradient: const [BrandColors.momentumBlue, BrandColors.success],
      ),
      _MetricDef(
        icon: Icons.account_balance,
        label: 'Total Political Giving',
        value: _currencyFmt.format(_stats?.totalRaisedPolitical ?? 0),
        gradient: const [BrandColors.steelBlue, BrandColors.royalBlue],
      ),
      _MetricDef(
        icon: Icons.card_giftcard,
        label: 'Avg Gift',
        value: _currencyFmt.format(_stats?.averageGift ?? 0),
        // Gold→warning reads as a caution gradient; blend into the brand
        // palette instead by landing on a deeper gold/amber tone.
        gradient: const [BrandColors.sunriseGold, Color(0xFFE98A0B)],
      ),
      _MetricDef(
        icon: Icons.trending_up,
        label: 'Prospects',
        value: _compactFmt.format(_stats?.prospectCount ?? 0),
        gradient: const [BrandColors.success, BrandColors.momentumBlue],
      ),
    ];

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _buildMetricCard(cards[i]),
      ),
    );
  }

  Widget _buildMetricCard(_MetricDef m) {
    return SizedBox(
      width: 170,
      child: BrandedCard(
        gradientColors: m.gradient,
        borderRadius: 14,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(m.icon, color: Colors.white70, size: 20),
            const SizedBox(height: 6),
            Text(
              m.value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              m.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                shadows: [
                  Shadow(
                    color: Color(0x66000000),
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filter Sidebar
  // ---------------------------------------------------------------------------

  // Sidebar dropdowns live on navy. Default `OutlineInputBorder` is an
  // invisible grey against the background; white-at-24% gives a readable
  // edge without screaming. Paired with `dropdownColor: unityBlue` on each
  // DropdownButtonFormField so the popover menu inherits navy instead of
  // the Material light default (which was making menu items unreadable
  // white-on-white).
  InputDecoration _filterDropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      labelStyle: const TextStyle(color: Color(0xFF374151)),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: BrandColors.momentumBlue),
        borderRadius: BorderRadius.circular(8),
      ),
      border: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  /// Light theme used by the filter sidebar AND the mobile filter sheet so
  /// chips/expansions render with navy text on a white surface.
  ThemeData _lightFilterTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      dividerColor: const Color(0xFFE5E7EB),
      iconTheme: const IconThemeData(color: Color(0xFF6B7280)),
      textTheme: Theme.of(context).textTheme.apply(
            bodyColor: const Color(0xFF1A1F36),
            displayColor: const Color(0xFF1A1F36),
          ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFF6B7280),
        textColor: Color(0xFF1A1F36),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: Color(0xFF6B7280),
        collapsedIconColor: Color(0xFF6B7280),
        textColor: Color(0xFF1A1F36),
        collapsedTextColor: Color(0xFF1A1F36),
      ),
    );
  }

  /// Filter chip label styling — switches to navy when selected, soft slate
  /// when unselected, against the new light filter surface.
  TextStyle _chipLabelStyle(bool selected) {
    return TextStyle(
      color: selected ? const Color(0xFF1A1F36) : const Color(0xFF4B5563),
      fontSize: 13,
    );
  }

  Widget _buildFilterSidebar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Theme(
        data: _lightFilterTheme(context),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tune, color: Color(0xFF6B7280), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1F36),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _clearFilters,
                    style: TextButton.styleFrom(
                      foregroundColor: BrandColors.momentumBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    child: const Text(
                      'Clear',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Expanded(
              child: _buildFilterContent(
                onChanged: () {
                  setState(() {});
                  _currentPage = 0;
                  _search();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterContent({
    ScrollController? scrollController,
    required VoidCallback onChanged,
  }) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          // Tier
          ExpansionTile(
            // Unique PageStorageKey so each ExpansionTile gets its own slot
            // in the parent PageStorageBucket. Without an explicit key,
            // ExpansionTile reads `PageStorage.readState(context) as bool?`
            // off the auto-generated identity. If a sibling widget
            // (TabBarView/KeepAlive/etc.) has stored a non-bool at that same
            // auto-generated identity, the cast throws 'type int is not a
            // subtype of bool?' on every rebuild. The key's value type is
            // String — what matters is uniqueness, not the type.
            key: const PageStorageKey<String>('donor-filter-tier'),
            title: const Text('Tier'),
            initiallyExpanded: true,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final tier in ['major', 'mid', 'small', 'prospect', 'lapsed'])
                      FilterChip(
                        label: Text(
                          tier[0].toUpperCase() + tier.substring(1),
                          style: _chipLabelStyle(_selectedTier == tier),
                        ),
                        selected: _selectedTier == tier,
                        backgroundColor: const Color(0xFFF3F4F6),
                        selectedColor: BrandColors.momentumBlue.withOpacity(0.18),
                        onSelected: (sel) {
                          _selectedTier = sel ? tier : null;
                          onChanged();
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Geography
          ExpansionTile(
            key: const PageStorageKey<String>('donor-filter-geography'),
            title: const Text('Geography'),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedCounty,
                      decoration: _filterDropdownDecoration('County'),
                      style: const TextStyle(color: Color(0xFF1A1F36), fontSize: 13),
                      iconEnabledColor: const Color(0xFF6B7280),
                      dropdownColor: Colors.white,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Counties')),
                        ..._buildCountyItems(),
                      ],
                      onChanged: (v) {
                        _selectedCounty = v;
                        onChanged();
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedCD,
                      decoration: _filterDropdownDecoration('Congressional District'),
                      style: const TextStyle(color: Color(0xFF1A1F36), fontSize: 13),
                      iconEnabledColor: const Color(0xFF6B7280),
                      dropdownColor: Colors.white,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All CDs')),
                        ..._buildCDItems(),
                      ],
                      onChanged: (v) {
                        _selectedCD = v;
                        onChanged();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Political
          ExpansionTile(
            key: const PageStorageKey<String>('donor-filter-political'),
            title: const Text('Political'),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final lean in [
                      'Strong D',
                      'Lean D',
                      'Independent',
                      'Lean R',
                      'Strong R',
                    ])
                      FilterChip(
                        label: Text(
                          lean,
                          style: _chipLabelStyle(_selectedPartyLean == lean),
                        ),
                        selected: _selectedPartyLean == lean,
                        backgroundColor: const Color(0xFFF3F4F6),
                        selectedColor: lean.contains('D')
                            ? BrandColors.democratBlue.withOpacity(0.15)
                            : lean.contains('R')
                                ? BrandColors.republicanRed.withOpacity(0.15)
                                : BrandColors.sunriseGold.withOpacity(0.15),
                        onSelected: (sel) {
                          _selectedPartyLean = sel ? lean : null;
                          onChanged();
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Financial
          ExpansionTile(
            key: const PageStorageKey<String>('donor-filter-financial'),
            title: const Text('Financial'),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wealth Score: ${(_minWealthScore ?? 0).round()} - ${(_maxWealthScore ?? 100).round()}',
                      style: const TextStyle(color: Color(0xFF374151), fontSize: 13),
                    ),
                    // RangeSlider's value-indicator defaults to white-on-white
                    // on the dark sidebar — make the pill navy with white text.
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        inactiveTrackColor: const Color(0xFFE5E7EB),
                        valueIndicatorColor: BrandColors.momentumBlue,
                        valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                        showValueIndicator: ShowValueIndicator.always,
                      ),
                      child: RangeSlider(
                        values: RangeValues(
                          _minWealthScore ?? 0,
                          _maxWealthScore ?? 100,
                        ),
                        min: 0,
                        max: 100,
                        divisions: 20,
                        activeColor: BrandColors.momentumBlue,
                        labels: RangeLabels(
                          (_minWealthScore ?? 0).round().toString(),
                          (_maxWealthScore ?? 100).round().toString(),
                        ),
                        onChanged: (range) {
                          setState(() {
                            _minWealthScore = range.start == 0 ? null : range.start;
                            _maxWealthScore = range.end == 100 ? null : range.end;
                          });
                        },
                        onChangeEnd: (_) => onChanged(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text(
                        'Homeowner',
                        style: TextStyle(color: Color(0xFF1A1F36), fontSize: 14),
                      ),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _isHomeowner ?? false,
                      activeColor: BrandColors.momentumBlue,
                      onChanged: (v) {
                        _isHomeowner = v ? true : null;
                        onChanged();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Data sources
          ExpansionTile(
            key: const PageStorageKey<String>('donor-filter-data'),
            title: const Text('Data'),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    FilterChip(
                      label: Text(
                        'Enrichment',
                        style: _chipLabelStyle(_hasEnrichment == true),
                      ),
                      selected: _hasEnrichment == true,
                      backgroundColor: const Color(0xFFF3F4F6),
                      selectedColor: BrandColors.success.withOpacity(0.18),
                      onSelected: (sel) {
                        _hasEnrichment = sel ? true : null;
                        onChanged();
                      },
                    ),
                    Tooltip(
                      message: 'VAN voter file record attached',
                      child: FilterChip(
                        label: Text(
                          'VAN',
                          style: _chipLabelStyle(_hasVan == true),
                        ),
                        selected: _hasVan == true,
                        backgroundColor: const Color(0xFFF3F4F6),
                        selectedColor: BrandColors.success.withOpacity(0.18),
                        onSelected: (sel) {
                          _hasVan = sel ? true : null;
                          onChanged();
                        },
                      ),
                    ),
                    FilterChip(
                      label: Text(
                        'Property',
                        style: _chipLabelStyle(_hasPropertyRecords == true),
                      ),
                      selected: _hasPropertyRecords == true,
                      backgroundColor: const Color(0xFFF3F4F6),
                      selectedColor: BrandColors.success.withOpacity(0.18),
                      onSelected: (sel) {
                        _hasPropertyRecords = sel ? true : null;
                        onChanged();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Tags
          if (_availableTags.isNotEmpty)
            ExpansionTile(
              key: const PageStorageKey<String>('donor-filter-tags'),
              title: const Text('Tags'),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final tag in _availableTags)
                        FilterChip(
                          label: Text(
                            tag,
                            style: _chipLabelStyle(
                              _selectedTags?.contains(tag) ?? false,
                            ),
                          ),
                          selected: _selectedTags?.contains(tag) ?? false,
                          backgroundColor: const Color(0xFFF3F4F6),
                          selectedColor: BrandColors.sunriseGold.withOpacity(0.18),
                          onSelected: (sel) {
                            final tags = List<String>.from(_selectedTags ?? []);
                            if (sel) {
                              tags.add(tag);
                            } else {
                              tags.remove(tag);
                            }
                            _selectedTags = tags.isEmpty ? null : tags;
                            onChanged();
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _buildCountyItems() {
    final counties = _results
        .map((r) => r.county)
        .where((c) => c != null && c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return counties
        .map((c) => DropdownMenuItem(value: c, child: Text(c!)))
        .toList();
  }

  List<DropdownMenuItem<String>> _buildCDItems() {
    // Missouri has 8 congressional districts. Search results don't carry a
    // CD field today, so render the static list; wire to a real CD column
    // on donor_profiles once that data lands.
    return [
      for (int i = 1; i <= 8; i++)
        DropdownMenuItem(value: 'MO-$i', child: Text('MO-$i')),
    ];
  }

  // ---------------------------------------------------------------------------
  // Main Content
  // ---------------------------------------------------------------------------

  Widget _buildMainContent(double availableWidth) {
    return Column(
      children: [
        // Search bar — light pill matching the rest of the MOYD CRM surfaces.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Color(0xFF1A1F36)),
            decoration: InputDecoration(
              hintText: 'Search donors by name, email, city...',
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF6B7280)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Color(0xFF6B7280)),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: BrandColors.momentumBlue, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: _onSearchChanged,
          ),
        ),

        // Results count + sort
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Text(
                '$_totalCount result${_totalCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1F36),
                ),
              ),
              const Spacer(),
              _buildSortDropdown(),
            ],
          ),
        ),

        // Results body
        Expanded(child: _buildResultsBody(availableWidth)),

        // Pagination
        _buildPagination(),
      ],
    );
  }

  Widget _buildSortDropdown() {
    const options = {
      'name': 'Name',
      'total_donated_moyd': 'Total Given',
      'wealth_score': 'Wealth Score',
      'total_donated_political': 'Political Giving',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortBy,
          dropdownColor: Colors.white,
          style: const TextStyle(color: Color(0xFF1A1F36), fontSize: 13),
          iconEnabledColor: const Color(0xFF6B7280),
          icon: Icon(
            _ascending ? Icons.arrow_upward : Icons.arrow_downward,
            color: const Color(0xFF6B7280),
            size: 16,
          ),
          items: options.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) {
            if (v != null) _onSortChanged(v);
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Results Body (loading / error / empty / data)
  // ---------------------------------------------------------------------------

  Widget _buildResultsBody(double availableWidth) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: BrandColors.momentumBlue),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: BrandColors.error, size: 48),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFF1A1F36)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BrandColors.momentumBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_search, size: 64, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 16),
            const Text(
              'No donors found',
              style: TextStyle(
                color: Color(0xFF1A1F36),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try adjusting your search or filters',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
      );
    }

    // Card grid for ALL widths — single column on phones, multi-column on
    // tablet/desktop. Mirrors the Committees Dashboard tile aesthetic so the
    // MOYD Donors tab body matches the rest of the app's card-driven CRM
    // surfaces (replaces the old DataTable + dense mobile list, 2026-04-27).
    return _buildDonorGrid(availableWidth);
  }

  // ---------------------------------------------------------------------------
  // Donor card grid (replaces DataTable + dense mobile list)
  // ---------------------------------------------------------------------------

  Widget _buildDonorGrid(double availableWidth) {
    // Column count tuned to keep cards ~360–520px wide so the 3-segment
    // stat strip stays readable. Below 720 we collapse to a single column
    // (matches the committee tile layout on phone).
    int columns;
    if (availableWidth >= 1500) {
      columns = 3;
    } else if (availableWidth >= 1000) {
      columns = 2;
    } else if (availableWidth >= 720) {
      columns = 2;
    } else {
      columns = 1;
    }

    const horizontalPadding = 16.0;
    const spacing = 14.0;
    final usable = availableWidth - (horizontalPadding * 2);
    final cardWidth = columns > 1
        ? (usable - spacing * (columns - 1)) / columns
        : usable;
    // Cards have a stable internal layout (avatar/name row + meta row +
    // stat strip) so we drive height from a fixed aspect rather than
    // intrinsic measurement — keeps the grid uniform like the committee
    // tiles while still scaling with width.
    const cardHeight = 168.0;
    final aspect = cardWidth / cardHeight;

    // "Select all on this page" affordance lives above the grid so the
    // bulk-action bar still works with the new card layout.
    final allSelected = _results.isNotEmpty &&
        _results.every((r) => r.id != null && _selectedIds.contains(r.id));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 8),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: allSelected,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedIds.addAll(
                          _results.map((r) => r.id).whereType<String>(),
                        );
                      } else {
                        for (final r in _results) {
                          if (r.id != null) _selectedIds.remove(r.id);
                        }
                      }
                    });
                  },
                  fillColor: WidgetStateProperty.resolveWith((s) =>
                      s.contains(WidgetState.selected)
                          ? BrandColors.momentumBlue
                          : Colors.transparent),
                  side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                  checkColor: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Select all on this page',
                style: TextStyle(color: Color(0xFF4B5563), fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              16,
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: aspect,
            ),
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final r = _results[index];
              final selected =
                  r.id != null && _selectedIds.contains(r.id);
              return _buildDonorCard(r, selected);
            },
          ),
        ),
      ],
    );
  }

  /// Donor card — visual analog of the committee tile but on the light
  /// MOYD-Donors surface. White rounded card, soft shadow, brand-tinted
  /// avatar, name/meta block, and a 3-segment stat strip footer.
  Widget _buildDonorCard(DonorProfileSearchResult r, bool selected) {
    // Initials for the leading avatar; falls back to a person icon.
    String initials = '';
    for (final w in r.fullName.trim().split(RegExp(r'[\s,]+'))) {
      if (w.isEmpty) continue;
      initials += w[0].toUpperCase();
      if (initials.length >= 2) break;
    }

    final avatarColors = _avatarColorsForTier(r.tier);
    final cityCdLine = _composeCityCdLine(r);
    final isVoter = r.id != null && _voterFileIds.contains(r.id);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToProfile(r.id),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? BrandColors.momentumBlue
                  : const Color(0xFFE5E7EB),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: checkbox + avatar + name + trailing chips
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: selected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true && r.id != null) {
                            _selectedIds.add(r.id!);
                          } else if (r.id != null) {
                            _selectedIds.remove(r.id);
                          }
                        });
                      },
                      fillColor: WidgetStateProperty.resolveWith((s) =>
                          s.contains(WidgetState.selected)
                              ? BrandColors.momentumBlue
                              : Colors.transparent),
                      side: const BorderSide(
                        color: Color(0xFFD1D5DB),
                        width: 1.5,
                      ),
                      checkColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: avatarColors.$1,
                    ),
                    alignment: Alignment.center,
                    child: initials.isEmpty
                        ? Icon(Icons.person, color: avatarColors.$2, size: 20)
                        : Text(
                            initials,
                            style: TextStyle(
                              color: avatarColors.$2,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      r.fullName.isEmpty ? '(no name)' : r.fullName,
                      style: const TextStyle(
                        color: BrandColors.unityBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (r.tier != null && r.tier!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _buildTierBadge(r.tier),
                  ],
                  if (isVoter) ...[
                    const SizedBox(width: 6),
                    _buildVoterChipCompact(),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              // Meta row: city · CD · party
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        cityCdLine,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (r.partyLean != null && r.partyLean!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _buildPartyBadge(r.partyLean),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              // Stat strip — 3 segments separated by faint dividers, mirrors
              // the committee tile's stats badge cluster.
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildCardStat(
                        label: 'MOYD',
                        value: _currencyFmt.format(r.totalDonatedMoyd ?? 0),
                      ),
                    ),
                    _statDivider(),
                    Expanded(
                      child: _buildCardStat(
                        label: 'Political',
                        value: _currencyFmt
                            .format(r.totalDonatedPolitical ?? 0),
                      ),
                    ),
                    _statDivider(),
                    Expanded(
                      child: _buildCardStat(
                        label: 'Last Gift',
                        value: r.lastDonationDate != null
                            ? _dateFmt.format(r.lastDonationDate!)
                            : '--',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardStat({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: BrandColors.unityBlue,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFFE5E7EB),
    );
  }

  /// Tinted (background, foreground) pair for the avatar bubble derived from
  /// the donor's tier. Mirrors the tier-badge palette for visual continuity.
  (Color, Color) _avatarColorsForTier(String? tier) {
    switch ((tier ?? '').toLowerCase()) {
      case 'major':
        return (const Color(0xFFFEF3C7), const Color(0xFF92400E));
      case 'mid':
        return (const Color(0xFFDBEAFE), BrandColors.unityBlue);
      case 'small':
        return (const Color(0xFFE0E7FF), const Color(0xFF3730A3));
      case 'prospect':
        return (const Color(0xFFD1FAE5), const Color(0xFF065F46));
      case 'lapsed':
        return (const Color(0xFFFEE2E2), const Color(0xFF991B1B));
      default:
        return (const Color(0xFFF3F4F6), BrandColors.unityBlue);
    }
  }

  String _composeCityCdLine(DonorProfileSearchResult r) {
    final pieces = <String>[];
    if (r.city != null && r.city!.isNotEmpty) pieces.add(r.city!);
    if (r.county != null && r.county!.isNotEmpty) pieces.add(r.county!);
    if (pieces.isEmpty) return '—';
    return pieces.join(' · ');
  }

  /// Compact "Voter" chip used inside the donor card's top row. Pill-style
  /// indicator that the donor is matched to the MO voter file — sized to fit
  /// next to the name without wrapping.
  Widget _buildVoterChipCompact() {
    return Tooltip(
      message: 'Matched to MO voter file',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: BrandColors.success.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: BrandColors.success.withOpacity(0.45)),
        ),
        child: const Text(
          'VOTER',
          style: TextStyle(
            color: BrandColors.success,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pagination
  // ---------------------------------------------------------------------------

  Widget _buildPagination() {
    final totalPages = (_totalCount / _pageSize).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Color(0xFF1A1F36)),
            onPressed: _currentPage > 0
                ? () => _onPageChanged(_currentPage - 1)
                : null,
            disabledColor: const Color(0xFFD1D5DB),
          ),
          Text(
            'Page ${_currentPage + 1} of $totalPages',
            style: const TextStyle(color: Color(0xFF374151), fontSize: 14),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Color(0xFF1A1F36)),
            onPressed: _currentPage < totalPages - 1
                ? () => _onPageChanged(_currentPage + 1)
                : null,
            disabledColor: const Color(0xFFD1D5DB),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bulk Action Bar
  // ---------------------------------------------------------------------------

  Widget _buildBulkActionBar() {
    final hasSelection = _selectedIds.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: hasSelection ? 56 : 0,
      curve: Curves.easeInOut,
      // The shadow still paints at height=0, leaving a black line under the
      // results grid even when nothing is selected. Suppress the whole
      // decoration when the bar is collapsed.
      decoration: hasSelection
          ? const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(blurRadius: 8, color: Color(0x1A000000))],
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            )
          : null,
      child: _selectedIds.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${_selectedIds.length} selected',
                    style: const TextStyle(
                      color: Color(0xFF1A1F36),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ActionChip(
                    avatar: const Icon(Icons.label, size: 16, color: Colors.white),
                    label: const Text('Tag Selected'),
                    backgroundColor: BrandColors.unityBlue,
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                    onPressed: () => _showComingSoon('Tag Selected'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.download, size: 16, color: Colors.white),
                    label: const Text('Export Selected'),
                    backgroundColor: BrandColors.unityBlue,
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                    onPressed: () => _showComingSoon('Export Selected'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.phone, size: 16, color: Colors.white),
                    label: const Text('Add to Call Time'),
                    backgroundColor: BrandColors.unityBlue,
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                    onPressed: () => _showComingSoon('Add to Call Time'),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                    tooltip: 'Deselect all',
                    onPressed: () => setState(() => _selectedIds.clear()),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  void _showComingSoon(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action - Coming soon'),
        backgroundColor: BrandColors.unityBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helper Widgets
  // ---------------------------------------------------------------------------

  Widget _buildTierBadge(String? tier) {
    if (tier == null || tier.isEmpty) return const SizedBox.shrink();

    Color bg;
    Color fg = const Color(0xFF1A1F36);
    switch (tier.toLowerCase()) {
      case 'major':
        bg = const Color(0xFFFEF3C7);
        break;
      case 'mid':
        bg = const Color(0xFFDBEAFE);
        break;
      case 'small':
        bg = const Color(0xFFE0E7FF);
        break;
      case 'prospect':
        bg = const Color(0xFFD1FAE5);
        break;
      case 'lapsed':
        bg = const Color(0xFFFEE2E2);
        break;
      default:
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF4B5563);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        tier[0].toUpperCase() + tier.substring(1),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildPartyBadge(String? partyLean) {
    if (partyLean == null || partyLean.isEmpty) return const SizedBox.shrink();

    Color bg;
    Color fg = const Color(0xFF1A1F36);
    if (partyLean.contains('D')) {
      bg = const Color(0xFFDBEAFE);
    } else if (partyLean.contains('R')) {
      bg = const Color(0xFFFEE2E2);
    } else {
      bg = const Color(0xFFF3F4F6);
      fg = const Color(0xFF4B5563);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        partyLean,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

}

// ---------------------------------------------------------------------------
// Private helper model for metric cards
// ---------------------------------------------------------------------------

class _MetricDef {
  final IconData icon;
  final String label;
  final String value;
  final List<Color> gradient;

  const _MetricDef({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradient,
  });
}
