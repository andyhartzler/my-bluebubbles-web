import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/services/crm/mec_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/mec_committee.dart';
import 'package:bluebubbles/models/crm/mec_contribution.dart';

/// Committees tab — browse, search, and view detailed committee profiles
/// including fundraising totals, contributions by year, top donors,
/// treasurer/candidate info, and election history.
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

  // Detail state
  bool _showDetail = false;
  MecCommittee? _selectedCommittee;
  Map<String, dynamic>? _committeeStats;
  List<MecContribution> _committeeContributions = [];
  List<Map<String, dynamic>> _topContributors = [];
  bool _loadingDetail = false;

  // Year expansion in detail view
  final Set<int> _expandedYears = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _performSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_showDetail) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

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
    if (!CRMConfig.crmEnabled) return [];

    final supabase = CRMSupabaseService();
    if (!supabase.isInitialized) return [];

    final client = supabase.hasServiceRole ? supabase.privilegedClient : supabase.client;
    final query = _searchController.text.trim();

    var builder = client.from('mec_committees').select();

    if (query.isNotEmpty) {
      builder = builder.or(
        'committee_name.ilike.%$query%,candidate_name.ilike.%$query%,treasurer_name.ilike.%$query%',
      );
    }

    if (_statusFilter != null) {
      builder = builder.eq('committee_status', _statusFilter!);
    }
    if (_partyFilter != null) {
      builder = builder.eq('party_affiliation', _partyFilter!);
    }

    final data = await builder
        .order('committee_name', ascending: true)
        .range(offset, offset + 49);

    return (data as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<void> _openCommitteeDetail(String mecId, String name) async {
    setState(() {
      _loadingDetail = true;
      _showDetail = true;
      _expandedYears.clear();
    });

    try {
      // Fetch committee info
      final committee = await _repository.getCommittee(mecId);

      // Fetch contributions for this committee
      final contributions = await _repository.searchContributions(
        mecId: mecId,
        limit: 5000,
        sortBy: 'contribution_date',
        ascending: false,
      );

      // Fetch top contributors
      final topContrib = await _repository.getTopContributors(
        mecId: mecId,
        limit: 50,
      );

      // Calculate stats
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

      setState(() {
        _selectedCommittee = committee;
        _committeeContributions = contributions;
        _topContributors = topContrib;
        _committeeStats = {
          'totalRaised': totalRaised,
          'contributionCount': contributionCount,
          'yearTotals': yearTotals,
          'yearCounts': yearCounts,
          'avgContribution': contributionCount > 0 ? totalRaised / contributionCount : 0,
          'uniqueDonors': topContrib.length,
        };
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
            _buildFilterChip('Active', _statusFilter == 'Active', () {
              setState(() => _statusFilter = _statusFilter == 'Active' ? null : 'Active');
              _performSearch();
            }),
            const SizedBox(width: 6),
            _buildFilterChip('Terminated', _statusFilter == 'Terminated', () {
              setState(() => _statusFilter = _statusFilter == 'Terminated' ? null : 'Terminated');
              _performSearch();
            }),
            const SizedBox(width: 12),
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
    final name = committee['committee_name'] as String? ?? 'Unknown Committee';
    final mecId = committee['mec_id'] as String? ?? '';
    final type = committee['committee_type'] as String? ?? '';
    final status = committee['committee_status'] as String? ?? '';
    final party = committee['party_affiliation'] as String? ?? '';
    final candidate = committee['candidate_name'] as String? ?? '';
    final treasurer = committee['treasurer_name'] as String? ?? '';

    final isActive = status.toLowerCase() == 'active';
    final isDem = party.toLowerCase().contains('democrat');
    final isRep = party.toLowerCase().contains('republican');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BrandedCard(
        onTap: () => _openCommitteeDetail(mecId, name),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isActive ? BrandColors.success.withOpacity(0.2) : Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status,
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
                  Text('Candidate: $candidate', style: BrandTextStyles.caption),
                ],
              ),
            ],
            if (treasurer.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: Colors.white54, size: 14),
                  const SizedBox(width: 4),
                  Text('Treasurer: $treasurer', style: BrandTextStyles.caption),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'MEC ID: $mecId',
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

    final c = _selectedCommittee;
    if (c == null) return const SizedBox.shrink();

    final stats = _committeeStats ?? {};
    final totalRaised = (stats['totalRaised'] as double?) ?? 0;
    final contribCount = (stats['contributionCount'] as int?) ?? 0;
    final avgContrib = (stats['avgContribution'] as double?) ?? 0;
    final uniqueDonors = (stats['uniqueDonors'] as int?) ?? 0;
    final yearTotals = (stats['yearTotals'] as Map<int, double>?) ?? {};
    final yearCounts = (stats['yearCounts'] as Map<int, int>?) ?? {};

    final isDem = c.isDemocrat;
    final isRep = c.isRepublican;
    final isActive = (c.committeeStatus ?? '').toLowerCase() == 'active';
    final currencyFormat = NumberFormat.simpleCurrency();

    return Column(
      children: [
        // Back button
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
                  c.committeeName ?? 'Committee',
                  style: BrandTextStyles.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // === Header Card ===
              BrandedCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.committeeName ?? '', style: BrandTextStyles.titleLarge),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive ? BrandColors.success.withOpacity(0.2) : Colors.white12,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            c.committeeStatus ?? 'Unknown',
                            style: TextStyle(
                              color: isActive ? BrandColors.success : Colors.white60,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (c.partyAffiliation != null && c.partyAffiliation!.isNotEmpty)
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
                              c.partyAffiliation!,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        const SizedBox(width: 8),
                        if (c.committeeType != null)
                          Text(c.committeeType!, style: BrandTextStyles.caption),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('MEC ID: ${c.mecId}', style: BrandTextStyles.caption),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // === Financial Summary ===
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
                          child: _statBox('Unique Donors', '$uniqueDonors'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // === Contact Info ===
              _buildContactSection(c),
              const SizedBox(height: 12),

              // === Contributions by Year ===
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

              // === Top Donors ===
              BrandedCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Top Donors (${_topContributors.length})', style: BrandTextStyles.title),
                    const SizedBox(height: 12),
                    ..._topContributors.take(25).map((d) => _buildTopDonorRow(d, currencyFormat)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // === Election History ===
              if (c.electionHistory != null) ...[
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

              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

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

  Widget _buildTopDonorRow(Map<String, dynamic> donor, NumberFormat fmt) {
    final name = donor['name'] as String? ?? 'Unknown';
    final total = (donor['total'] as num?)?.toDouble() ?? 0;
    final count = (donor['count'] as num?)?.toInt() ?? 0;
    final city = donor['city'] as String? ?? '';
    final state = donor['state'] as String? ?? '';
    final employer = donor['employer'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: BrandTextStyles.body.copyWith(fontSize: 13)),
                if (city.isNotEmpty || employer.isNotEmpty)
                  Text(
                    [if (city.isNotEmpty) '$city, $state', if (employer.isNotEmpty) employer]
                        .join(' · '),
                    style: BrandTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
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
