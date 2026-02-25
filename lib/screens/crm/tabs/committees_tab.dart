import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/services/crm/mec_repository.dart';
import 'package:bluebubbles/models/crm/mec_committee.dart';
import 'package:bluebubbles/models/crm/mec_contribution.dart';

/// Committees tab — browse, search, and view detailed committee profiles
/// including fundraising totals, contributions by year, donors with pagination,
/// treasurer/candidate info, and election history.
///
/// Supports unified MEC + FEC committee search via the searchCommitteesUnified RPC,
/// with source filtering (MEC / FEC / Both), and paginated donor lists via
/// getCommitteeDonorsPaginated RPC.
class CommitteesTab extends StatefulWidget {
  const CommitteesTab({super.key});

  @override
  State<CommitteesTab> createState() => _CommitteesTabState();
}

class _CommitteesTabState extends State<CommitteesTab> {
  final MecRepository _repository = MecRepository();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Search state
  List<Map<String, dynamic>> _committees = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String? _statusFilter;
  String? _partyFilter;
  String _sourceFilter = 'both';

  // Detail state
  bool _showDetail = false;
  Map<String, dynamic>? _selectedCommitteeData; // raw search result row
  MecCommittee? _selectedCommittee; // full MEC committee (null for FEC-only)
  Map<String, dynamic>? _committeeStats;
  List<MecContribution> _committeeContributions = [];
  List<Map<String, dynamic>> _donors = [];
  bool _loadingDetail = false;
  bool _loadingMoreDonors = false;
  bool _hasMoreDonors = true;
  int _donorOffset = 0;
  String _donorSortBy = 'total';

  // Year expansion in detail view
  final Set<int> _expandedYears = {};

  // Detail scroll controller (separate from list scroll controller)
  final ScrollController _detailScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _detailScrollController.addListener(_onDetailScroll);
    _performSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _detailScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_showDetail) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  void _onDetailScroll() {
    if (!_showDetail) return;
    if (_detailScrollController.position.pixels >=
        _detailScrollController.position.maxScrollExtent - 300) {
      _loadMoreDonors();
    }
  }

  /// Strip leading zeros from committee names (client-side backup
  /// for the regexp_replace in the RPC).
  String _cleanCommitteeName(String name) {
    return name.replaceFirst(RegExp(r'^0+'), '');
  }

  // ============================================================
  // Search / Browse
  // ============================================================

  Future<void> _performSearch() async {
    if (!_repository.isReady) return;
    setState(() {
      _loading = true;
      _committees = [];
      _offset = 0;
      _hasMore = true;
    });

    try {
      final results = await _searchCommittees(0);
      setState(() {
        _committees = results;
        _loading = false;
        _hasMore = results.length >= 50;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    try {
      final more = await _searchCommittees(_committees.length);
      setState(() {
        _committees.addAll(more);
        _loadingMore = false;
        _hasMore = more.length >= 50;
      });
    } catch (e) {
      setState(() => _loadingMore = false);
    }
  }

  Future<List<Map<String, dynamic>>> _searchCommittees(int offset) async {
    final query = _searchController.text.trim();

    final results = await _repository.searchCommitteesUnified(
      query: query.isNotEmpty ? query : null,
      status: _statusFilter,
      party: _partyFilter,
      source: _sourceFilter,
      limit: 50,
      offset: offset,
    );

    return results;
  }

  // ============================================================
  // Detail View — open committee
  // ============================================================

  Future<void> _openCommitteeDetail(Map<String, dynamic> committeeData) async {
    final source = (committeeData['source'] as String?) ?? 'mec';
    final mecId = committeeData['mec_id'] as String? ?? committeeData['committee_id'] as String? ?? '';

    setState(() {
      _loadingDetail = true;
      _showDetail = true;
      _selectedCommitteeData = committeeData;
      _selectedCommittee = null;
      _expandedYears.clear();
      _donors = [];
      _donorOffset = 0;
      _hasMoreDonors = true;
      _donorSortBy = 'total';
    });

    try {
      MecCommittee? committee;
      List<MecContribution> contributions = [];
      Map<String, dynamic> stats = {};

      // Only fetch full MEC committee data for MEC-source committees
      if (source.toLowerCase() == 'mec') {
        committee = await _repository.getCommittee(mecId);

        // Fetch contributions for year breakdown
        contributions = await _repository.searchContributions(
          mecId: mecId,
          limit: 5000,
          sortBy: 'contribution_date',
          ascending: false,
        );

        // Calculate stats from contributions
        double totalRaised = 0;
        int contributionCount = contributions.length;
        final yearTotals = <int, double>{};
        final yearCounts = <int, int>{};

        for (final c in contributions) {
          final amt = c.contributionAmount ?? 0;
          totalRaised += amt;
          final year = c.filingYear ?? c.contributionDate?.year ?? 0;
          if (year > 0) {
            yearTotals[year] = (yearTotals[year] ?? 0) + amt;
            yearCounts[year] = (yearCounts[year] ?? 0) + 1;
          }
        }

        stats = {
          'totalRaised': totalRaised,
          'contributionCount': contributionCount,
          'yearTotals': yearTotals,
          'yearCounts': yearCounts,
          'avgContribution': contributionCount > 0 ? totalRaised / contributionCount : 0.0,
        };
      }

      // Fetch paginated donors (works for both MEC and FEC via RPC)
      final donors = await _repository.getCommitteeDonorsPaginated(
        mecId: mecId,
        limit: 100,
        offset: 0,
        sortBy: _donorSortBy,
      );

      setState(() {
        _selectedCommittee = committee;
        _committeeContributions = contributions;
        _committeeStats = stats;
        _donors = donors;
        _donorOffset = donors.length;
        _hasMoreDonors = donors.length >= 100;
        _loadingDetail = false;
      });
    } catch (e) {
      setState(() {
        _loadingDetail = false;
        _showDetail = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading committee: $e')),
        );
      }
    }
  }

  Future<void> _loadMoreDonors() async {
    if (_loadingMoreDonors || !_hasMoreDonors) return;
    final mecId = _selectedCommitteeData?['mec_id'] as String? ??
        _selectedCommitteeData?['committee_id'] as String? ??
        '';
    if (mecId.isEmpty) return;

    setState(() => _loadingMoreDonors = true);

    try {
      final more = await _repository.getCommitteeDonorsPaginated(
        mecId: mecId,
        limit: 100,
        offset: _donorOffset,
        sortBy: _donorSortBy,
      );

      setState(() {
        _donors.addAll(more);
        _donorOffset += more.length;
        _hasMoreDonors = more.length >= 100;
        _loadingMoreDonors = false;
      });
    } catch (e) {
      setState(() => _loadingMoreDonors = false);
    }
  }

  Future<void> _changeDonorSort(String sortBy) async {
    if (sortBy == _donorSortBy) return;
    final mecId = _selectedCommitteeData?['mec_id'] as String? ??
        _selectedCommitteeData?['committee_id'] as String? ??
        '';
    if (mecId.isEmpty) return;

    setState(() {
      _donorSortBy = sortBy;
      _donors = [];
      _donorOffset = 0;
      _hasMoreDonors = true;
      _loadingMoreDonors = true;
    });

    try {
      final donors = await _repository.getCommitteeDonorsPaginated(
        mecId: mecId,
        limit: 100,
        offset: 0,
        sortBy: sortBy,
      );

      setState(() {
        _donors = donors;
        _donorOffset = donors.length;
        _hasMoreDonors = donors.length >= 100;
        _loadingMoreDonors = false;
      });
    } catch (e) {
      setState(() => _loadingMoreDonors = false);
    }
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_showDetail) {
      return _buildDetailView();
    }
    return _buildSearchView();
  }

  // ============================================================
  // Search / Browse View
  // ============================================================

  Widget _buildSearchView() {
    return Column(
      children: [
        _buildSearchBar(),
        _buildFilterChips(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: BrandColors.sunriseGold))
              : _committees.isEmpty
                  ? Center(
                      child: Text(
                        'Search for committees by name, candidate, or treasurer',
                        style: BrandTextStyles.subtitle,
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _committees.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _committees.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(color: BrandColors.sunriseGold),
                            ),
                          );
                        }
                        return _buildCommitteeCard(_committees[index]);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search committees, candidates, treasurers...',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white54),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white54),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch();
                  },
                )
              : null,
          filled: true,
          fillColor: BrandColors.unityBlue.withOpacity(0.6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (_) => _performSearch(),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Source filter chips
            _buildFilterChip('Both', _sourceFilter == 'both', () {
              setState(() => _sourceFilter = 'both');
              _performSearch();
            }),
            const SizedBox(width: 6),
            _buildFilterChip('MEC', _sourceFilter == 'mec', () {
              setState(() => _sourceFilter = 'mec');
              _performSearch();
            }, color: BrandColors.momentumBlue),
            const SizedBox(width: 6),
            _buildFilterChip('FEC', _sourceFilter == 'fec', () {
              setState(() => _sourceFilter = 'fec');
              _performSearch();
            }, color: BrandColors.success),
            const SizedBox(width: 16),
            // Divider
            Container(width: 1, height: 24, color: Colors.white24),
            const SizedBox(width: 16),
            // Status filter chips
            _buildFilterChip('Active', _statusFilter == 'Active', () {
              setState(() => _statusFilter = _statusFilter == 'Active' ? null : 'Active');
              _performSearch();
            }),
            const SizedBox(width: 6),
            _buildFilterChip('Terminated', _statusFilter == 'Terminated', () {
              setState(() => _statusFilter = _statusFilter == 'Terminated' ? null : 'Terminated');
              _performSearch();
            }),
            const SizedBox(width: 16),
            Container(width: 1, height: 24, color: Colors.white24),
            const SizedBox(width: 16),
            // Party filter chips
            _buildFilterChip('Democrat', _partyFilter == 'Democrat', () {
              setState(() => _partyFilter = _partyFilter == 'Democrat' ? null : 'Democrat');
              _performSearch();
            }, color: BrandColors.democratBlue),
            const SizedBox(width: 6),
            _buildFilterChip('Republican', _partyFilter == 'Republican', () {
              setState(() => _partyFilter = _partyFilter == 'Republican' ? null : 'Republican');
              _performSearch();
            }, color: BrandColors.republicanRed),
            const SizedBox(width: 6),
            _buildFilterChip('Nonpartisan', _partyFilter == 'Nonpartisan', () {
              setState(() => _partyFilter = _partyFilter == 'Nonpartisan' ? null : 'Nonpartisan');
              _performSearch();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? (color ?? BrandColors.sunriseGold)
              : BrandColors.unityBlue.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.white24 : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCommitteeCard(Map<String, dynamic> committee) {
    final rawName = committee['committee_name'] as String? ?? 'Unknown Committee';
    final name = _cleanCommitteeName(rawName);
    final mecId = committee['mec_id'] as String? ?? committee['committee_id'] as String? ?? '';
    final type = committee['committee_type'] as String? ?? '';
    final status = committee['committee_status'] as String? ?? '';
    final party = committee['party_affiliation'] as String? ?? '';
    final candidate = committee['candidate_name'] as String? ?? '';
    final treasurer = committee['treasurer_name'] as String? ?? '';
    final source = (committee['source'] as String? ?? 'mec').toUpperCase();

    final isActive = status.toLowerCase() == 'active';
    final isDem = party.toLowerCase().contains('democrat');
    final isRep = party.toLowerCase().contains('republican');
    final isMec = source == 'MEC';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BrandedCard(
        onTap: () => _openCommitteeDetail(committee),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: BrandTextStyles.title.copyWith(fontSize: 15),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Source badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isMec
                        ? BrandColors.momentumBlue.withOpacity(0.35)
                        : BrandColors.success.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    source,
                    style: TextStyle(
                      color: isMec ? BrandColors.momentumBlue : BrandColors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isActive ? BrandColors.success.withOpacity(0.2) : Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status.isNotEmpty ? status : 'Unknown',
                    style: TextStyle(
                      color: isActive ? BrandColors.success : Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (party.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isDem
                          ? BrandColors.democratBlue.withOpacity(0.3)
                          : isRep
                              ? BrandColors.republicanRed.withOpacity(0.3)
                              : Colors.white12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      party,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                if (type.isNotEmpty)
                  Text(type, style: BrandTextStyles.caption),
              ],
            ),
            if (candidate.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.person, color: Colors.white54, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Candidate: $candidate',
                      style: BrandTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (treasurer.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: Colors.white54, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Treasurer: $treasurer',
                      style: BrandTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '${source} ID: $mecId',
              style: BrandTextStyles.caption.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Detail View
  // ============================================================

  Widget _buildDetailView() {
    if (_loadingDetail) {
      return const Center(
        child: CircularProgressIndicator(color: BrandColors.sunriseGold),
      );
    }

    final data = _selectedCommitteeData;
    if (data == null) return const SizedBox.shrink();

    final source = (data['source'] as String? ?? 'mec').toUpperCase();
    final isMecSource = source == 'MEC';
    final c = _selectedCommittee; // may be null for FEC committees

    // Use MecCommittee fields when available, fall back to search result data
    final rawName = c?.committeeName ?? data['committee_name'] as String? ?? 'Unknown Committee';
    final displayName = _cleanCommitteeName(rawName);
    final mecId = data['mec_id'] as String? ?? data['committee_id'] as String? ?? '';
    final status = c?.committeeStatus ?? data['committee_status'] as String? ?? '';
    final party = c?.partyAffiliation ?? data['party_affiliation'] as String? ?? '';
    final type = c?.committeeType ?? data['committee_type'] as String? ?? '';
    final isActive = status.toLowerCase() == 'active';
    final isDem = party.toLowerCase().contains('democrat');
    final isRep = party.toLowerCase().contains('republican');

    final stats = _committeeStats ?? {};
    final totalRaised = (stats['totalRaised'] as double?) ?? 0;
    final contribCount = (stats['contributionCount'] as int?) ?? 0;
    final avgContrib = (stats['avgContribution'] as double?) ?? 0;
    final yearTotals = (stats['yearTotals'] as Map<int, double>?) ?? {};
    final yearCounts = (stats['yearCounts'] as Map<int, int>?) ?? {};

    final currencyFormat = NumberFormat.simpleCurrency();

    return Column(
      children: [
        // Back button header
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() => _showDetail = false),
              ),
              Expanded(
                child: Text(
                  displayName,
                  style: BrandTextStyles.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Source badge in header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isMecSource
                      ? BrandColors.momentumBlue.withOpacity(0.35)
                      : BrandColors.success.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  source,
                  style: TextStyle(
                    color: isMecSource ? BrandColors.momentumBlue : BrandColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: _detailScrollController,
            padding: const EdgeInsets.all(12),
            children: [
              // === Header Card ===
              BrandedCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: BrandTextStyles.titleLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive ? BrandColors.success.withOpacity(0.2) : Colors.white12,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.isNotEmpty ? status : 'Unknown',
                            style: TextStyle(
                              color: isActive ? BrandColors.success : Colors.white60,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (party.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDem
                                  ? BrandColors.democratBlue.withOpacity(0.3)
                                  : isRep
                                      ? BrandColors.republicanRed.withOpacity(0.3)
                                      : Colors.white12,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              party,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        if (type.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              type,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isMecSource
                                ? BrandColors.momentumBlue.withOpacity(0.25)
                                : BrandColors.success.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            source,
                            style: TextStyle(
                              color: isMecSource ? BrandColors.momentumBlue : BrandColors.success,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('$source ID: $mecId', style: BrandTextStyles.caption),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // === Financial Summary (MEC only — we have contribution data) ===
              if (isMecSource && contribCount > 0) ...[
                BrandedCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Financial Summary', style: BrandTextStyles.title),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _statBox('Total Raised', currencyFormat.format(totalRaised)),
                          ),
                          Expanded(
                            child: _statBox('Contributions', NumberFormat.compact().format(contribCount)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _statBox('Avg Contribution', currencyFormat.format(avgContrib)),
                          ),
                          Expanded(
                            child: _statBox('Donors Loaded', '${_donors.length}${_hasMoreDonors ? '+' : ''}'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // === Contact Info (MEC only) ===
              if (c != null) ...[
                _buildContactSection(c),
                const SizedBox(height: 12),
              ],

              // === Contributions by Year (MEC only) ===
              if (isMecSource && yearTotals.isNotEmpty) ...[
                BrandedCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Contributions by Year', style: BrandTextStyles.title),
                      const SizedBox(height: 12),
                      ...(_buildYearBreakdown(yearTotals, yearCounts, currencyFormat)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // === Donors (all sources, paginated) ===
              _buildDonorSection(currencyFormat),
              const SizedBox(height: 12),

              // === Election History (MEC only) ===
              if (c != null && c.electionHistory != null) ...[
                BrandedCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Election History', style: BrandTextStyles.title),
                      const SizedBox(height: 8),
                      _buildElectionHistory(c.electionHistory),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Loading more donors indicator
              if (_loadingMoreDonors)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(color: BrandColors.sunriseGold),
                  ),
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Donor Section with sort + infinite scroll
  // ============================================================

  Widget _buildDonorSection(NumberFormat currencyFormat) {
    return BrandedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Donors (${_donors.length}${_hasMoreDonors ? '+' : ''})',
                  style: BrandTextStyles.title,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Sort chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSortChip('Total', 'total'),
                const SizedBox(width: 6),
                _buildSortChip('Count', 'count'),
                const SizedBox(width: 6),
                _buildSortChip('Name', 'name'),
                const SizedBox(width: 6),
                _buildSortChip('Last Date', 'last_date'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_donors.isEmpty && !_loadingMoreDonors)
            Text('No donor data available', style: BrandTextStyles.bodySecondary),
          ..._donors.map((d) => _buildDonorRow(d, currencyFormat)),
          if (_hasMoreDonors && !_loadingMoreDonors)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: TextButton(
                  onPressed: _loadMoreDonors,
                  child: const Text(
                    'Load more donors...',
                    style: TextStyle(color: BrandColors.sunriseGold),
                  ),
                ),
              ),
            ),
          if (_loadingMoreDonors)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: BrandColors.sunriseGold,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String sortValue) {
    final isSelected = _donorSortBy == sortValue;
    return GestureDetector(
      onTap: () => _changeDonorSort(sortValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? BrandColors.sunriseGold.withOpacity(0.8)
              : Colors.white10,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? BrandColors.sunriseGold : Colors.white24,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildDonorRow(Map<String, dynamic> donor, NumberFormat fmt) {
    final name = donor['name'] as String? ?? 'Unknown';
    final total = (donor['total'] as num?)?.toDouble() ?? 0;
    final count = (donor['count'] as num?)?.toInt() ?? 0;
    final city = donor['city'] as String? ?? '';
    final state = donor['state'] as String? ?? '';
    final employer = donor['employer'] as String? ?? '';
    final hasFec = donor['has_fec'] as bool? ?? false;

    // Build the subtitle line
    final subtitleParts = <String>[];
    if (city.isNotEmpty) {
      subtitleParts.add(state.isNotEmpty ? '$city, $state' : city);
    } else if (state.isNotEmpty) {
      subtitleParts.add(state);
    }
    if (employer.isNotEmpty) {
      subtitleParts.add(employer);
    }
    final subtitle = subtitleParts.join(' \u00B7 '); // middle dot separator

    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening donor profile for $name...'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: BrandTextStyles.body.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasFec) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: BrandColors.success.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'FEC',
                            style: TextStyle(
                              color: BrandColors.success,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: BrandTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fmt.format(total),
                  style: BrandTextStyles.body.copyWith(
                    color: BrandColors.sunriseGold,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text('$count gifts', style: BrandTextStyles.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Shared Widgets
  // ============================================================

  Widget _statBox(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: BrandTextStyles.stat.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 2),
        Text(label, style: BrandTextStyles.statLabel),
      ],
    );
  }

  Widget _buildContactSection(MecCommittee c) {
    final sections = <Widget>[];

    if (c.candidateName != null && c.candidateName!.isNotEmpty) {
      sections.add(_contactRow(
        Icons.person,
        'Candidate',
        c.candidateName!,
        c.candidateAddress,
        c.candidatePhone,
      ));
    }

    if (c.treasurerName != null && c.treasurerName!.isNotEmpty) {
      sections.add(_contactRow(
        Icons.account_balance_wallet,
        'Treasurer',
        c.treasurerName!,
        c.treasurerAddress,
        c.treasurerPhone,
      ));
    }

    if (c.committeeAddress != null || c.committeePhone != null) {
      sections.add(_contactRow(
        Icons.business,
        'Committee',
        c.committeeName ?? '',
        c.committeeAddress,
        c.committeePhone,
      ));
    }

    if (sections.isEmpty) return const SizedBox.shrink();

    return BrandedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Contact Information', style: BrandTextStyles.title),
          const SizedBox(height: 12),
          ...sections,
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String role, String name, String? address, String? phone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: BrandColors.sunriseGold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role, style: BrandTextStyles.caption.copyWith(color: BrandColors.sunriseGold)),
                Text(name, style: BrandTextStyles.body),
                if (address != null && address.isNotEmpty)
                  Text(address, style: BrandTextStyles.bodySecondary),
                if (phone != null && phone.isNotEmpty)
                  Text(phone, style: BrandTextStyles.bodySecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildYearBreakdown(
    Map<int, double> yearTotals,
    Map<int, int> yearCounts,
    NumberFormat fmt,
  ) {
    if (yearTotals.isEmpty) {
      return [Text('No contribution data', style: BrandTextStyles.bodySecondary)];
    }

    final years = yearTotals.keys.toList()..sort((a, b) => b.compareTo(a));
    final maxTotal = yearTotals.values.reduce((a, b) => a > b ? a : b);

    return years.map((year) {
      final total = yearTotals[year] ?? 0;
      final count = yearCounts[year] ?? 0;
      final barWidth = maxTotal > 0 ? (total / maxTotal) : 0.0;
      final expanded = _expandedYears.contains(year);

      return Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (expanded) {
                  _expandedYears.remove(year);
                } else {
                  _expandedYears.add(year);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    child: Text('$year', style: BrandTextStyles.body.copyWith(fontSize: 13)),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: barWidth,
                          child: Container(
                            height: 22,
                            decoration: BoxDecoration(
                              color: BrandColors.sunriseGold.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 90,
                    child: Text(
                      fmt.format(total),
                      style: BrandTextStyles.body.copyWith(fontSize: 12),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '($count)',
                      style: BrandTextStyles.caption,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white38,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) _buildYearContributions(year),
        ],
      );
    }).toList();
  }

  Widget _buildYearContributions(int year) {
    final yearContribs = _committeeContributions
        .where((c) => (c.filingYear ?? c.contributionDate?.year) == year)
        .toList()
      ..sort((a, b) => (b.contributionAmount ?? 0).compareTo(a.contributionAmount ?? 0));

    if (yearContribs.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(left: 42, bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: yearContribs.take(50).map((c) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    c.contributorDisplayName,
                    style: BrandTextStyles.caption.copyWith(color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  c.formattedDate,
                  style: BrandTextStyles.caption,
                ),
                const SizedBox(width: 8),
                Text(
                  c.formattedAmount,
                  style: BrandTextStyles.body.copyWith(fontSize: 12, color: BrandColors.sunriseGold),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildElectionHistory(dynamic history) {
    if (history == null) return const SizedBox.shrink();

    if (history is List) {
      return Column(
        children: history.map<Widget>((item) {
          if (item is Map) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.how_to_vote, color: Colors.white38, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.entries.map((e) => '${e.key}: ${e.value}').join(', '),
                      style: BrandTextStyles.bodySecondary,
                    ),
                  ),
                ],
              ),
            );
          }
          return Text('$item', style: BrandTextStyles.bodySecondary);
        }).toList(),
      );
    }

    if (history is Map) {
      return Column(
        children: history.entries.map<Widget>((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Text('${e.key}:', style: BrandTextStyles.body),
                const SizedBox(width: 8),
                Expanded(child: Text('${e.value}', style: BrandTextStyles.bodySecondary)),
              ],
            ),
          );
        }).toList(),
      );
    }

    return Text('$history', style: BrandTextStyles.bodySecondary);
  }
}
