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
          builder: (bCtx, setSheetState) => Column(
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
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () {
                        _clearFilters();
                        Navigator.pop(bCtx);
                      },
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

        return Column(
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
                        const VerticalDivider(width: 1),
                        Expanded(child: _buildMainContent(constraints.maxWidth - 281)),
                      ],
                    )
                  : _buildMainContent(constraints.maxWidth),
            ),
            _buildBulkActionBar(),
          ],
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
      body: BrandedBackground(child: tabView),
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
              style: BrandTextStyles.caption,
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
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withOpacity(0.24)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: BrandColors.sunriseGold),
      ),
    );
  }

  Widget _buildFilterSidebar() {
    return Container(
      // Dark navy-blue sidebar that matches the rest of the CRM theme.
      // Previously had a stark white background that looked disconnected
      // from the navy app chrome.
      decoration: BoxDecoration(
        color: BrandColors.unityBlue.withOpacity(0.55),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
      ),
      child: Theme(
        // Override only the style bits we need (text/icon colors, expansion
        // tile + list tile colors, divider). Avoid `brightness: dark` or
        // `colorScheme.copyWith` — those combinations crash ExpansionTile
        // rendering in this codebase's Theme chain ("An unexpected error
        // occurred when rendering" appeared as a result).
        data: Theme.of(context).copyWith(
          dividerColor: Colors.white.withOpacity(0.12),
          iconTheme: const IconThemeData(color: Colors.white70),
          textTheme: Theme.of(context).textTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
          listTileTheme: const ListTileThemeData(
            iconColor: Colors.white70,
            textColor: Colors.white,
          ),
          expansionTileTheme: const ExpansionTileThemeData(
            iconColor: Colors.white70,
            collapsedIconColor: Colors.white70,
            textColor: Colors.white,
            collapsedTextColor: Colors.white,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tune, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _clearFilters,
                    style: TextButton.styleFrom(
                      foregroundColor: BrandColors.sunriseGold,
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
            Divider(height: 1, color: Colors.white.withOpacity(0.12)),
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
                        label: Text(tier[0].toUpperCase() + tier.substring(1)),
                        selected: _selectedTier == tier,
                        selectedColor: BrandColors.momentumBlue.withOpacity(0.25),
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
            title: const Text('Geography'),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedCounty,
                      decoration: _filterDropdownDecoration('County'),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      iconEnabledColor: Colors.white70,
                      dropdownColor: BrandColors.unityBlue,
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
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      iconEnabledColor: Colors.white70,
                      dropdownColor: BrandColors.unityBlue,
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
                        label: Text(lean),
                        selected: _selectedPartyLean == lean,
                        selectedColor: lean.contains('D')
                            ? BrandColors.democratBlue.withOpacity(0.25)
                            : lean.contains('R')
                                ? BrandColors.republicanRed.withOpacity(0.25)
                                : BrandColors.sunriseGold.withOpacity(0.25),
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
            title: const Text('Financial'),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wealth Score: ${(_minWealthScore ?? 0).round()} - ${(_maxWealthScore ?? 100).round()}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    // RangeSlider's value-indicator defaults to white-on-white
                    // on the dark sidebar — make the pill navy with white text.
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        inactiveTrackColor: Colors.white.withOpacity(0.18),
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
                      title: const Text('Homeowner', style: TextStyle(fontSize: 14)),
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
            title: const Text('Data'),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    FilterChip(
                      label: const Text('Enrichment'),
                      selected: _hasEnrichment == true,
                      selectedColor: BrandColors.success.withOpacity(0.25),
                      onSelected: (sel) {
                        _hasEnrichment = sel ? true : null;
                        onChanged();
                      },
                    ),
                    Tooltip(
                      message: 'VAN voter file record attached',
                      child: FilterChip(
                        label: const Text('VAN'),
                        selected: _hasVan == true,
                        selectedColor: BrandColors.success.withOpacity(0.25),
                        onSelected: (sel) {
                          _hasVan = sel ? true : null;
                          onChanged();
                        },
                      ),
                    ),
                    FilterChip(
                      label: const Text('Property'),
                      selected: _hasPropertyRecords == true,
                      selectedColor: BrandColors.success.withOpacity(0.25),
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
                          label: Text(tag),
                          selected: _selectedTags?.contains(tag) ?? false,
                          selectedColor: BrandColors.sunriseGold.withOpacity(0.25),
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
        // Search bar — dark Slack-style input against the navy background.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search donors by name, email, city...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white70),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: BrandColors.unityBlue.withOpacity(0.6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
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
                  color: Colors.white,
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
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortBy,
          dropdownColor: BrandColors.unityBlue,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          icon: Icon(
            _ascending ? Icons.arrow_upward : Icons.arrow_downward,
            color: Colors.white70,
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
              style: const TextStyle(color: Colors.white),
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
            Icon(Icons.person_search, size: 64, color: Colors.white.withOpacity(0.7)),
            const SizedBox(height: 16),
            const Text(
              'No donors found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ],
        ),
      );
    }

    // Desktop table vs mobile list
    if (availableWidth >= 600) {
      return _buildDesktopTable();
    }
    return _buildMobileList();
  }

  // ---------------------------------------------------------------------------
  // Desktop DataTable
  // ---------------------------------------------------------------------------

  Widget _buildDesktopTable() {
    final allSelected =
        _results.isNotEmpty && _results.every((r) => _selectedIds.contains(r.id));

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            BrandColors.unityBlue.withOpacity(0.6),
          ),
          dataRowColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return BrandColors.momentumBlue.withOpacity(0.28);
            }
            // White@0.07 put the city/party text at ~2.8:1 contrast against
            // the page background — below WCAG AA. A deeper navy keeps the
            // theme and pushes row text past 10:1.
            return BrandColors.unityBlue.withOpacity(0.35);
          }),
          headingTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          dataTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
          columns: [
            DataColumn(
              label: Checkbox(
                value: allSelected && _results.isNotEmpty,
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
                fillColor: WidgetStateProperty.all(Colors.white24),
                checkColor: BrandColors.sunriseGold,
              ),
            ),
            DataColumn(
              label: const Text('Name'),
              onSort: (_, __) => _onSortChanged('last_name'),
            ),
            const DataColumn(label: Text('City')),
            const DataColumn(label: Text('Tier')),
            const DataColumn(label: Text('Party')),
            DataColumn(
              label: const Text('Total Given'),
              numeric: true,
              onSort: (_, __) => _onSortChanged('total_donated_moyd'),
            ),
            DataColumn(
              label: const Text('Wealth Score'),
              numeric: true,
              onSort: (_, __) => _onSortChanged('wealth_score'),
            ),
            DataColumn(
              label: const Text('Last Gift'),
              onSort: (_, __) => _onSortChanged('last_donation_date'),
            ),
          ],
          rows: _results.map((r) {
            final selected = _selectedIds.contains(r.id);
            // `DataRow.onSelectChanged` fires for BOTH cell taps AND checkbox
            // taps, which double-fired with the cell's own Checkbox and made
            // the checkbox effectively non-selectable (every click also
            // navigated). Navigation now lives on each non-checkbox DataCell
            // via `onTap`, and the checkbox manages selection alone.
            final navigate = r.id == null ? null : () => _navigateToProfile(r.id);
            return DataRow(
              selected: selected,
              cells: [
                DataCell(
                  Checkbox(
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
                    fillColor: WidgetStateProperty.all(Colors.white24),
                    checkColor: BrandColors.sunriseGold,
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        r.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (r.id != null && _voterFileIds.contains(r.id)) ...[
                        const SizedBox(width: 6),
                        _buildVoterDot(),
                      ],
                    ],
                  ),
                  onTap: navigate,
                ),
                DataCell(Text(r.city ?? ''), onTap: navigate),
                DataCell(_buildTierBadge(r.tier), onTap: navigate),
                DataCell(_buildPartyBadge(r.partyLean), onTap: navigate),
                DataCell(
                  Text(_currencyFmt.format(r.totalDonatedMoyd ?? 0)),
                  onTap: navigate,
                ),
                DataCell(_buildWealthIndicator(r.wealthScore), onTap: navigate),
                DataCell(
                  Text(
                    r.lastDonationDate != null
                        ? _dateFmt.format(r.lastDonationDate!)
                        : '--',
                  ),
                  onTap: navigate,
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mobile List
  // ---------------------------------------------------------------------------

  Widget _buildMobileList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final r = _results[index];
        final selected = _selectedIds.contains(r.id);

        // Card defaults to `elevation: 1`, which on navy paints a subtle
        // dark shadow under every row — the list reads as "floating tiles on
        // a slightly darker navy" instead of a clean list. Kill the
        // elevation and switch to a navy fill so rows sit flat on the page.
        return Card(
          color: BrandColors.unityBlue.withOpacity(0.40),
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _navigateToProfile(r.id),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                r.fullName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (r.id != null &&
                                _voterFileIds.contains(r.id)) ...[
                              _buildVoterDot(),
                              const SizedBox(width: 6),
                            ],
                            _buildTierBadge(r.tier),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (r.city != null && r.city!.isNotEmpty)
                              Expanded(
                                child: Text(
                                  r.city!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            _buildPartyBadge(r.partyLean),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              _currencyFmt.format(r.totalDonatedMoyd ?? 0),
                              style: const TextStyle(
                                color: BrandColors.sunriseGold,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              r.lastDonationDate != null
                                  ? _dateFmt.format(r.lastDonationDate!)
                                  : '--',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Checkbox(
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
                    fillColor: WidgetStateProperty.all(Colors.white24),
                    checkColor: BrandColors.sunriseGold,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Pagination
  // ---------------------------------------------------------------------------

  Widget _buildPagination() {
    final totalPages = (_totalCount / _pageSize).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: _currentPage > 0
                ? () => _onPageChanged(_currentPage - 1)
                : null,
            disabledColor: Colors.white24,
          ),
          Text(
            'Page ${_currentPage + 1} of $totalPages',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: _currentPage < totalPages - 1
                ? () => _onPageChanged(_currentPage + 1)
                : null,
            disabledColor: Colors.white24,
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
              color: BrandColors.unityBlue,
              boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black26)],
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
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ActionChip(
                    avatar: const Icon(Icons.label, size: 16, color: Colors.white),
                    label: const Text('Tag Selected'),
                    backgroundColor: BrandColors.momentumBlue,
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                    onPressed: () => _showComingSoon('Tag Selected'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.download, size: 16, color: Colors.white),
                    label: const Text('Export Selected'),
                    backgroundColor: BrandColors.momentumBlue,
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                    onPressed: () => _showComingSoon('Export Selected'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.phone, size: 16, color: Colors.white),
                    label: const Text('Add to Call Time'),
                    backgroundColor: BrandColors.momentumBlue,
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                    onPressed: () => _showComingSoon('Add to Call Time'),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
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
    switch (tier.toLowerCase()) {
      case 'major':
        bg = BrandColors.sunriseGold;
        break;
      case 'mid':
        bg = BrandColors.momentumBlue;
        break;
      case 'small':
        bg = BrandColors.steelBlue;
        break;
      case 'prospect':
        bg = BrandColors.success;
        break;
      case 'lapsed':
        bg = BrandColors.warning;
        break;
      default:
        bg = BrandColors.slateBlue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.85),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        tier[0].toUpperCase() + tier.substring(1),
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildPartyBadge(String? partyLean) {
    if (partyLean == null || partyLean.isEmpty) return const SizedBox.shrink();

    Color bg;
    if (partyLean.contains('D')) {
      bg = BrandColors.democratBlue;
    } else if (partyLean.contains('R')) {
      bg = BrandColors.republicanRed;
    } else {
      bg = BrandColors.slateBlue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.85),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        partyLean,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  /// Small pill indicating this donor is matched to the MO voter file
  /// (i.e. `donor_profiles.mo_voter_file_id IS NOT NULL`). Keeps the
  /// voter-file linkage visible at-a-glance alongside each row.
  Widget _buildVoterDot() {
    return Tooltip(
      message: 'Matched to MO voter file',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: BrandColors.success.withOpacity(0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: BrandColors.success.withOpacity(0.5)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.how_to_reg, size: 12, color: BrandColors.success),
            SizedBox(width: 4),
            Text(
              'Voter',
              style: TextStyle(
                color: BrandColors.success,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWealthIndicator(int? score) {
    final value = (score ?? 0).clamp(0, 100);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 50,
          child: LinearProgressIndicator(
            value: value / 100,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation(
              // Red reads as "error" — a low wealth score is just low, not
              // broken. Step through the brand palette instead.
              value >= 70
                  ? BrandColors.success
                  : value >= 40
                      ? BrandColors.sunriseGold
                      : BrandColors.slateBlue,
            ),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$value',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
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
