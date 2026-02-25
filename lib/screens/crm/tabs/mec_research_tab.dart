import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/mec_contribution.dart';
import 'package:bluebubbles/services/crm/mec_repository.dart';

class MecResearchTab extends StatefulWidget {
  /// Called when the user taps a committee name in a donor's contribution list.
  /// Parameters: committeeId, committeeName, source ('mec' or 'fec').
  final void Function(String committeeId, String committeeName, String source)? onNavigateToCommittee;

  const MecResearchTab({super.key, this.onNavigateToCommittee});

  @override
  State<MecResearchTab> createState() => _MecResearchTabState();
}

class _MecResearchTabState extends State<MecResearchTab> {
  final MecRepository _repository = MecRepository();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minAmountController = TextEditingController();

  final _currencyFormat = NumberFormat.simpleCurrency();
  final _dateFormat = DateFormat.yMMMd();

  // Search state
  List<Map<String, dynamic>> _donors = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _hasSearched = false;
  String? _error;
  int _yearFrom = DateTime.now().year - 1;
  int _yearTo = DateTime.now().year;
  String _selectedState = 'MO';
  String? _selectedParty;
  String _selectedSource = 'both'; // 'mec', 'fec', 'both'

  // Infinite scroll
  final ScrollController _scrollController = ScrollController();

  // Profile state
  bool _inProfileMode = false;
  Map<String, dynamic> _profileData = {};
  Map<String, dynamic>? _enrichmentData;
  Map<String, dynamic>? _unifiedProfile;
  bool _profileLoading = false;
  String _profileName = '';
  Map<String, dynamic>? _profileDonorRow;

  // US states list
  static const List<String> _usStates = [
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
    'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
    'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
    'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY',
    'DC',
  ];

  // Party options with colors
  static const List<_PartyOption> _partyOptions = [
    _PartyOption(label: 'All', value: null, color: Colors.white70),
    _PartyOption(label: 'Democrat', value: 'democrat', color: Colors.blue),
    _PartyOption(label: 'Republican', value: 'republican', color: Colors.red),
    _PartyOption(label: 'Progressive', value: 'progressive', color: Colors.green),
    _PartyOption(label: 'Conservative', value: 'conservative', color: Colors.orange),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minAmountController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore &&
        _hasSearched &&
        !_loading) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    try {
      final nameQuery = _searchController.text.trim();
      final minAmountText = _minAmountController.text.trim();
      final minTotal = minAmountText.isNotEmpty ? double.tryParse(minAmountText) : null;

      final results = await _repository.searchDonorsUnified(
        nameQuery: nameQuery.isNotEmpty ? nameQuery : null,
        state: _selectedState.isNotEmpty ? _selectedState : null,
        yearFrom: _yearFrom,
        yearTo: _yearTo,
        minTotal: minTotal,
        party: _selectedParty,
        source: _selectedSource,
        limit: 100,
        offset: _donors.length,
      );

      if (!mounted) return;
      setState(() {
        _donors.addAll(results);
        _hasMore = results.length >= 100;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Donor search
  // ---------------------------------------------------------------------------

  Future<void> _performSearch() async {
    final nameQuery = _searchController.text.trim();
    final minAmountText = _minAmountController.text.trim();
    final minTotal = minAmountText.isNotEmpty ? double.tryParse(minAmountText) : null;

    setState(() {
      _loading = true;
      _error = null;
      _hasSearched = true;
      _donors = [];
      _hasMore = true;
    });

    try {
      final results = await _repository.searchDonorsUnified(
        nameQuery: nameQuery.isNotEmpty ? nameQuery : null,
        state: _selectedState.isNotEmpty ? _selectedState : null,
        yearFrom: _yearFrom,
        yearTo: _yearTo,
        minTotal: minTotal,
        party: _selectedParty,
        source: _selectedSource,
        limit: 100,
        offset: 0,
      );

      if (!mounted) return;
      setState(() {
        _donors = results;
        _hasMore = results.length >= 100;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Search failed: $e';
        _loading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Profile logic
  // ---------------------------------------------------------------------------

  Future<void> _openProfileFromDonor(Map<String, dynamic> donor) async {
    final lastName = (donor['last_name'] as String?) ??
        (donor['contributor_last_name'] as String?) ?? '';
    final firstName = (donor['first_name'] as String?) ??
        (donor['contributor_first_name'] as String?);
    final company = (donor['company_name'] as String?) ??
        (donor['contributor_company'] as String?);
    final donorId = (donor['donor_id'] as num?)?.toInt();

    if (lastName.isEmpty && (company == null || company.isEmpty)) return;

    // Build display name
    final displayName = (donor['donor_name'] as String?) ??
        (() {
          if (company != null && company.isNotEmpty && lastName.isEmpty) {
            return company;
          }
          final parts = <String>[];
          if (lastName.isNotEmpty) parts.add(lastName);
          if (firstName != null && firstName.isNotEmpty) parts.add(firstName);
          return parts.join(', ');
        })();

    setState(() {
      _inProfileMode = true;
      _profileLoading = true;
      _profileName = displayName;
      _profileDonorRow = donor;
      _profileData = {};
      _enrichmentData = null;
      _unifiedProfile = null;
    });

    try {
      // Try unified profile first if we have a donorId
      if (donorId != null) {
        final profileResult = await _repository.getDonorUnifiedProfile(donorId);
        if (profileResult != null && mounted) {
          setState(() {
            _profileData = {
              'contributions': <MecContribution>[],
              'totalAmount': 0.0,
              'count': 0,
              'committees': <Map<String, dynamic>>[],
            };
            _unifiedProfile = profileResult;
            _enrichmentData = null;
            _profileLoading = false;
          });
          return;
        }
      }

      // Fall back to old method if donorId is null or unified profile failed
      final futures = <Future>[];
      futures.add(_repository.getContributorProfile(
        lastName: lastName,
        firstName: firstName,
        company: company,
      ));
      if (donorId != null) {
        futures.add(_repository.getDonorEnrichment(donorId));
      }

      final results = await Future.wait(futures);

      if (!mounted) return;
      setState(() {
        _profileData = results[0] as Map<String, dynamic>;
        if (donorId != null && results.length > 1) {
          _enrichmentData = results[1] as Map<String, dynamic>?;
        }
        _profileLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _profileLoading = false;
        _error = 'Failed to load profile: $e';
      });
    }
  }

  void _closeProfile() {
    setState(() {
      _inProfileMode = false;
      _profileData = {};
      _enrichmentData = null;
      _unifiedProfile = null;
      _profileDonorRow = null;
      _profileName = '';
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Color _partyColor(String party) {
    switch (party.toLowerCase()) {
      case 'democrat':
        return Colors.blue;
      case 'republican':
        return Colors.red;
      case 'progressive':
        return Colors.green;
      case 'conservative':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _donorDisplayName(Map<String, dynamic> donor) {
    final lastName = (donor['contributor_last_name'] as String?) ?? '';
    final firstName = (donor['contributor_first_name'] as String?) ?? '';
    final company = (donor['contributor_company'] as String?) ?? '';

    if (lastName.isNotEmpty || firstName.isNotEmpty) {
      final parts = <String>[];
      if (lastName.isNotEmpty) parts.add(lastName);
      if (firstName.isNotEmpty) parts.add(firstName);
      return parts.join(', ');
    }
    if (company.isNotEmpty) return company;
    return 'Unknown';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_inProfileMode) {
      return _buildProfileMode();
    }
    return _buildSearchMode();
  }

  // ===========================================================================
  // SEARCH MODE
  // ===========================================================================

  Widget _buildSearchMode() {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      children: [
        // Name search
        _buildSearchBar(),
        const SizedBox(height: 12),

        // State dropdown + year range row
        _buildFilterRow(),
        const SizedBox(height: 12),

        // Party filter chips
        _buildPartyChips(),
        const SizedBox(height: 8),

        // Source filter chips
        _buildSourceChips(),
        const SizedBox(height: 16),

        // Search button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _performSearch,
            icon: const Icon(Icons.search, color: Colors.white),
            label: const Text('Search Donor Database',
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.unityBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Results section
        if (_loading) _buildLoadingIndicator(),
        if (_error != null) _buildErrorMessage(),
        if (!_loading && _error == null && _hasSearched && _donors.isNotEmpty)
          _buildResultsSection(),
        if (!_loading && _error == null && _hasSearched && _donors.isEmpty)
          _buildEmptyState(),
        if (!_loading && _error == null && !_hasSearched)
          _buildInitialState(),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.person_search, color: Colors.white70),
        labelText: 'Search by donor name',
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: BrandColors.unityBlue.withOpacity(0.7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BrandColors.momentumBlue, width: 2),
        ),
      ),
      onSubmitted: (_) => _performSearch(),
    );
  }

  Widget _buildFilterRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // State dropdown
        Expanded(
          flex: 2,
          child: _buildStateDropdown(),
        ),
        const SizedBox(width: 8),

        // Year range slider
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Text('$_yearFrom', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
              Expanded(
                child: RangeSlider(
                  values: RangeValues(_yearFrom.toDouble(), _yearTo.toDouble()),
                  min: 2002,
                  max: DateTime.now().year.toDouble(),
                  divisions: DateTime.now().year - 2002,
                  labels: RangeLabels('$_yearFrom', '$_yearTo'),
                  activeColor: BrandColors.sunriseGold,
                  inactiveColor: Colors.white24,
                  onChanged: (values) {
                    setState(() {
                      _yearFrom = values.start.round();
                      _yearTo = values.end.round();
                    });
                  },
                ),
              ),
              Text('$_yearTo', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Min amount text field
        Expanded(
          flex: 2,
          child: TextField(
            controller: _minAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Min \$',
              labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
              filled: true,
              fillColor: BrandColors.unityBlue.withOpacity(0.7),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: BrandColors.momentumBlue, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStateDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedState,
          isExpanded: true,
          dropdownColor: BrandColors.unityBlue,
          iconEnabledColor: Colors.white70,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: [
            const DropdownMenuItem<String>(
              value: '',
              child: Text('All States',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ),
            ..._usStates.map(
              (s) => DropdownMenuItem<String>(
                value: s,
                child: Text(s, style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _selectedState = v ?? ''),
        ),
      ),
    );
  }

  Widget _buildPartyChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _partyOptions.map((option) {
        final isSelected = _selectedParty == option.value;
        return ChoiceChip(
          label: Text(
            option.label,
            style: TextStyle(
              color: isSelected ? Colors.white : option.color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
          selected: isSelected,
          selectedColor: option.value == null
              ? BrandColors.momentumBlue
              : option.color.withOpacity(0.8),
          backgroundColor: BrandColors.unityBlue.withOpacity(0.7),
          side: BorderSide(
            color: isSelected ? Colors.transparent : option.color.withOpacity(0.5),
          ),
          onSelected: (_) {
            setState(() => _selectedParty = option.value);
          },
        );
      }).toList(),
    );
  }

  Widget _buildSourceChips() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Text('Source: ', style: BrandTextStyles.caption),
          const SizedBox(width: 8),
          _buildSourceChip('Both', 'both', BrandColors.sunriseGold),
          const SizedBox(width: 6),
          _buildSourceChip('MEC', 'mec', BrandColors.momentumBlue),
          const SizedBox(width: 6),
          _buildSourceChip('FEC', 'fec', BrandColors.success),
        ],
      ),
    );
  }

  Widget _buildSourceChip(String label, String value, Color color) {
    final isSelected = _selectedSource == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedSource = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : BrandColors.unityBlue.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.white24 : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            CircularProgressIndicator(color: BrandColors.momentumBlue),
            SizedBox(height: 16),
            Text('Searching donors...', style: BrandTextStyles.subtitle),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: BrandedCard(
        gradientColors: [BrandColors.error, BrandColors.error.withOpacity(0.7)],
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_error!, style: BrandTextStyles.body),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.how_to_vote, size: 56, color: BrandColors.sunriseGold.withOpacity(0.6)),
            const SizedBox(height: 16),
            const Text('Donor Research', style: BrandTextStyles.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Use the filters above to search 4M+ donor records.\n'
              'Results are aggregated by donor with party affiliations.',
              style: BrandTextStyles.subtitle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.white38),
            SizedBox(height: 12),
            Text('No donors found', style: BrandTextStyles.subtitle),
            SizedBox(height: 4),
            Text('Try a different name, state, or adjust filters',
                style: BrandTextStyles.caption),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Result count header
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Showing ${_donors.length} donor${_donors.length == 1 ? '' : 's'}'
            '${_hasMore ? ' (scroll for more)' : ''}',
            style: BrandTextStyles.subtitle,
          ),
        ),

        // Donor cards
        ...List.generate(_donors.length, (i) {
          final donor = _donors[i];
          return _buildDonorCard(donor);
        }),

        // Loading more indicator
        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(color: BrandColors.momentumBlue),
            ),
          ),

        // End of results
        if (!_hasMore && _donors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                'All ${_donors.length} results loaded',
                style: BrandTextStyles.caption,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDonorCard(Map<String, dynamic> donor) {
    final name = donor['donor_name'] as String? ?? _donorDisplayName(donor);
    final totalAmount = (donor['total_amount'] as num?)?.toDouble() ?? 0.0;
    final contributionCount = (donor['contribution_count'] as num?)?.toInt() ?? 0;
    final city = donor['city'] as String?;
    final state = donor['state'] as String?;
    final employer = (donor['current_employer'] as String?) ?? (donor['employer'] as String?);
    final occupation = (donor['current_job_title'] as String?) ?? (donor['occupation'] as String?);
    final firstYear = (donor['first_year'] as num?)?.toInt();
    final lastYear = (donor['last_year'] as num?)?.toInt();
    final avgAmount = (donor['avg_amount'] as num?)?.toDouble();
    final parties = (donor['parties'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final committees = (donor['committees'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    // Source data from unified search
    final dataSources = donor['data_sources'] as String? ?? 'MEC';
    final mecTotal = (donor['mec_total'] as num?)?.toDouble() ?? 0.0;
    final fecTotal = (donor['fec_total'] as num?)?.toDouble() ?? 0.0;

    // Enrichment data from search_donors_v2
    final partyLean = donor['party_lean'] as String?;
    final ageEstimate = (donor['age_estimate'] as num?)?.toInt();
    final gender = donor['gender'] as String?;
    final phoneMobile = donor['phone_mobile'] as String?;
    final phoneHome = donor['phone_home'] as String?;
    final hasPhone = (phoneMobile != null && phoneMobile.isNotEmpty) ||
        (phoneHome != null && phoneHome.isNotEmpty);

    final location = [city, state]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BrandedCard(
        onTap: () => _openProfileFromDonor(donor),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: name + total amount
            Row(
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (dataSources.contains('FEC'))
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: BrandColors.success.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: BrandColors.success.withOpacity(0.5), width: 0.5),
                              ),
                              child: const Text('FEC', style: TextStyle(color: BrandColors.success, fontSize: 9, fontWeight: FontWeight.w700)),
                            ),
                          if (dataSources.contains('MEC'))
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: BrandColors.momentumBlue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: BrandColors.momentumBlue.withOpacity(0.5), width: 0.5),
                              ),
                              child: const Text('MEC', style: TextStyle(color: BrandColors.momentumBlue, fontSize: 9, fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                      // Enrichment badges row
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (partyLean != null && partyLean.isNotEmpty)
                            _buildEnrichmentChip(
                              partyLean,
                              _partyLeanColor(partyLean),
                            ),
                          if (ageEstimate != null)
                            _buildEnrichmentChip(
                              'Age ~$ageEstimate',
                              Colors.white54,
                            ),
                          if (gender != null && gender.isNotEmpty)
                            _buildEnrichmentChip(
                              gender,
                              Colors.white54,
                            ),
                          if (hasPhone)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: BrandColors.success.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: BrandColors.success.withOpacity(0.5),
                                  width: 0.5,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.phone, size: 11, color: BrandColors.success),
                                  SizedBox(width: 3),
                                  Text(
                                    'Phone',
                                    style: TextStyle(
                                      color: BrandColors.success,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _currencyFormat.format(totalAmount),
                      style: const TextStyle(
                        color: BrandColors.sunriseGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      '$contributionCount contribution${contributionCount == 1 ? '' : 's'}',
                      style: BrandTextStyles.caption,
                    ),
                    if (mecTotal > 0 && fecTotal > 0) ...[
                      Text('MEC: ${_currencyFormat.format(mecTotal)}', style: BrandTextStyles.caption.copyWith(fontSize: 10)),
                      Text('FEC: ${_currencyFormat.format(fecTotal)}', style: BrandTextStyles.caption.copyWith(fontSize: 10, color: BrandColors.success)),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Location + employer/occupation
            if (location.isNotEmpty || (employer != null && employer.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    if (location.isNotEmpty) ...[
                      const Icon(Icons.location_on, size: 14, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text(location, style: BrandTextStyles.caption),
                    ],
                    if (location.isNotEmpty && employer != null && employer.isNotEmpty)
                      const Text('  |  ', style: BrandTextStyles.caption),
                    if (employer != null && employer.isNotEmpty) ...[
                      const Icon(Icons.business, size: 14, color: Colors.white54),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          occupation != null && occupation.isNotEmpty
                              ? '$employer ($occupation)'
                              : employer,
                          style: BrandTextStyles.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Year range + avg amount
            Row(
              children: [
                if (firstYear != null && lastYear != null) ...[
                  const Icon(Icons.calendar_today, size: 13, color: Colors.white54),
                  const SizedBox(width: 4),
                  Text(
                    firstYear == lastYear ? '$firstYear' : '$firstYear - $lastYear',
                    style: BrandTextStyles.caption,
                  ),
                  const SizedBox(width: 12),
                ],
                if (avgAmount != null) ...[
                  Text(
                    'Avg: ${_currencyFormat.format(avgAmount)}',
                    style: BrandTextStyles.caption,
                  ),
                  const SizedBox(width: 12),
                ],
                if (committees.isNotEmpty)
                  Text(
                    '${committees.length} committee${committees.length == 1 ? '' : 's'}',
                    style: BrandTextStyles.caption,
                  ),
              ],
            ),

            // Party chips
            if (parties.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: parties.map((party) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _partyColor(party).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _partyColor(party).withOpacity(0.6),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      party[0].toUpperCase() + party.substring(1),
                      style: TextStyle(
                        color: _partyColor(party),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEnrichmentChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _partyLeanColor(String partyLean) {
    final lower = partyLean.toLowerCase();
    if (lower.contains('democrat') || lower.contains('left') || lower.contains('liberal')) {
      return BrandColors.democratBlue;
    }
    if (lower.contains('republican') || lower.contains('right') || lower.contains('conservative')) {
      return BrandColors.republicanRed;
    }
    if (lower.contains('independent') || lower.contains('moderate')) {
      return Colors.purple;
    }
    return Colors.grey;
  }

  // ===========================================================================
  // PROFILE MODE
  // ===========================================================================

  Widget _buildProfileMode() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Back button
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _closeProfile,
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            label: const Text('Back to search',
                style: TextStyle(color: Colors.white70)),
          ),
        ),
        const SizedBox(height: 8),

        if (_profileLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(color: BrandColors.momentumBlue),
            ),
          )
        else ...[
          // Header card
          _buildProfileHeader(),
          const SizedBox(height: 16),

          // Enrichment sections (personal, contact, employment, political)
          _buildEnrichmentSections(),

          // Unified MEC contributions section
          _buildMecContributionsSection(),
          const SizedBox(height: 12),

          // Unified FEC contributions section
          _buildFecContributionsSection(),
          const SizedBox(height: 16),

          // Legacy committees section (fallback when _unifiedProfile is null)
          if (_unifiedProfile == null) ...[
            _buildCommitteesSection(),
            const SizedBox(height: 24),
          ],

          // Legacy contributions timeline (fallback when _unifiedProfile is null)
          if (_unifiedProfile == null)
            _buildContributionsTimeline(),
        ],
      ],
    );
  }

  Widget _buildProfileHeader() {
    // When unified profile is available, use its data
    final profile = _unifiedProfile;
    if (profile != null) {
      // Compute totals from contribution arrays (RPC doesn't return summary fields)
      final mecContribs = (profile['mec_contributions'] as List<dynamic>?) ?? [];
      final fecContribs = (profile['fec_contributions'] as List<dynamic>?) ?? [];
      final mecTotal = mecContribs.fold<double>(0, (sum, c) => sum + ((c['contribution_amount'] as num?)?.toDouble() ?? 0));
      final fecTotal = fecContribs.fold<double>(0, (sum, c) => sum + ((c['transaction_amount'] as num?)?.toDouble() ?? 0));
      final grandTotal = mecTotal + fecTotal;
      final mecCount = mecContribs.length;
      final fecCount = fecContribs.length;
      final totalCount = mecCount + fecCount;

      // Compute year range from contributions
      int? firstYear;
      int? lastYear;
      for (final c in mecContribs) {
        final d = c['contribution_date'] as String?;
        if (d != null && d.length >= 4) {
          final y = int.tryParse(d.substring(0, 4));
          if (y != null) {
            firstYear = firstYear == null ? y : (y < firstYear ? y : firstYear);
            lastYear = lastYear == null ? y : (y > lastYear ? y : lastYear);
          }
        }
      }
      for (final c in fecContribs) {
        final d = c['transaction_date'] as String?;
        if (d != null && d.length >= 4) {
          final y = int.tryParse(d.substring(0, 4));
          if (y != null) {
            firstYear = firstYear == null ? y : (y < firstYear ? y : firstYear);
            lastYear = lastYear == null ? y : (y > lastYear ? y : lastYear);
          }
        }
      }

      // Enrichment data is inside the 'donor' object (joined in the RPC)
      final enr = profile['donor'] as Map<String, dynamic>?;
      final donorRow = _profileDonorRow;

      String? city = enr?['city'] as String? ??
          donorRow?['city'] as String?;
      String? state = enr?['state'] as String? ??
          donorRow?['state'] as String?;
      String? employer = enr?['current_employer'] as String? ??
          donorRow?['current_employer'] as String? ??
          donorRow?['employer'] as String?;
      String? occupation = enr?['current_job_title'] as String? ??
          donorRow?['current_job_title'] as String? ??
          donorRow?['occupation'] as String?;

      // Enrichment badges
      final partyLean = enr?['party_lean'] as String? ??
          donorRow?['party_lean'] as String?;
      final ageEstimate = (enr?['age_estimate'] as num?)?.toInt() ??
          (donorRow?['age_estimate'] as num?)?.toInt();
      final gender = enr?['gender'] as String? ??
          donorRow?['gender'] as String?;
      final generation = enr?['generation'] as String?;
      final isHomeowner = enr?['is_homeowner'] as bool? ??
          donorRow?['is_homeowner'] as bool?;
      final wealthScore = (enr?['wealth_score'] as num?)?.toDouble() ??
          (donorRow?['wealth_score'] as num?)?.toDouble();
      final phoneMobile = enr?['phone_mobile'] as String? ??
          donorRow?['phone_mobile'] as String?;
      final phoneHome = enr?['phone_home'] as String? ??
          donorRow?['phone_home'] as String?;
      final emailPersonal = enr?['email_personal'] as String? ??
          donorRow?['email_personal'] as String?;
      final hasPhone = (phoneMobile != null && phoneMobile.isNotEmpty) ||
          (phoneHome != null && phoneHome.isNotEmpty);
      final hasEmail = emailPersonal != null && emailPersonal.isNotEmpty;

      return BrandedCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name
            Text(
              _profileName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),

            // Enrichment badges
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (partyLean != null && partyLean.isNotEmpty)
                  _buildEnrichmentChip(partyLean, _partyLeanColor(partyLean)),
                if (ageEstimate != null)
                  _buildEnrichmentChip('Age ~$ageEstimate', Colors.white54),
                if (gender != null && gender.isNotEmpty)
                  _buildEnrichmentChip(gender, Colors.white54),
                if (generation != null && generation.isNotEmpty)
                  _buildEnrichmentChip(generation, Colors.tealAccent),
                if (isHomeowner == true)
                  _buildEnrichmentChip('Homeowner', Colors.green),
                if (wealthScore != null && wealthScore > 0)
                  _buildEnrichmentChip(
                    'Wealth: ${wealthScore.toStringAsFixed(0)}',
                    BrandColors.sunriseGold,
                  ),
                if (hasPhone)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: BrandColors.success.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: BrandColors.success.withOpacity(0.5),
                        width: 0.5,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone, size: 11, color: BrandColors.success),
                        SizedBox(width: 3),
                        Text('Phone',
                            style: TextStyle(
                                color: BrandColors.success,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                if (hasEmail)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.lightBlue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.lightBlue.withOpacity(0.5),
                        width: 0.5,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.email, size: 11, color: Colors.lightBlue),
                        SizedBox(width: 3),
                        Text('Email',
                            style: TextStyle(
                                color: Colors.lightBlue,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Total given
            Text(
              _currencyFormat.format(grandTotal),
              style: const TextStyle(
                color: BrandColors.sunriseGold,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Show MEC/FEC breakdown if both exist
            if (mecTotal > 0 && fecTotal > 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: BrandColors.momentumBlue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'MEC: ${_currencyFormat.format(mecTotal)}',
                      style: const TextStyle(color: BrandColors.momentumBlue, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: BrandColors.success.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'FEC: ${_currencyFormat.format(fecTotal)}',
                      style: const TextStyle(color: BrandColors.success, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),

            // Count + year range
            Text(
              '$totalCount contribution${totalCount == 1 ? '' : 's'}'
              '${firstYear != null && lastYear != null ? ' from $firstYear to $lastYear' : ''}',
              style: BrandTextStyles.bodySecondary,
            ),
            const SizedBox(height: 8),

            // Location / Employer / Occupation
            _buildProfileMetaRow(city, state, employer, occupation),
          ],
        ),
      );
    }

    // Legacy profile header (when _unifiedProfile is null)
    final totalAmount = _profileData['totalAmount'] as double? ?? 0.0;
    final count = _profileData['count'] as int? ?? 0;
    final firstYear = _profileData['firstYear'] as int?;
    final lastYear = _profileData['lastYear'] as int?;
    final contributions =
        _profileData['contributions'] as List<MecContribution>? ?? [];

    // Gather metadata: prefer enrichment data, fall back to contribution data
    final enr = _enrichmentData;
    final donorRow = _profileDonorRow;

    String? city = enr?['city'] as String? ??
        donorRow?['city'] as String?;
    String? state = enr?['state'] as String? ??
        donorRow?['state'] as String?;
    String? employer = enr?['current_employer'] as String? ??
        donorRow?['current_employer'] as String? ??
        donorRow?['employer'] as String?;
    String? occupation = enr?['current_job_title'] as String? ??
        donorRow?['current_job_title'] as String? ??
        donorRow?['occupation'] as String?;

    if ((city == null || city.isEmpty) && contributions.isNotEmpty) {
      final recent = contributions.first;
      city = recent.city;
      state = recent.state;
      employer ??= recent.employer;
      occupation ??= recent.occupation;
    }

    // Enrichment badges
    final partyLean = enr?['party_lean'] as String? ??
        donorRow?['party_lean'] as String?;
    final ageEstimate = (enr?['age_estimate'] as num?)?.toInt() ??
        (donorRow?['age_estimate'] as num?)?.toInt();
    final gender = enr?['gender'] as String? ??
        donorRow?['gender'] as String?;
    final generation = enr?['generation'] as String?;
    final isHomeowner = enr?['is_homeowner'] as bool? ??
        donorRow?['is_homeowner'] as bool?;
    final wealthScore = (enr?['wealth_score'] as num?)?.toDouble() ??
        (donorRow?['wealth_score'] as num?)?.toDouble();
    final phoneMobile = enr?['phone_mobile'] as String? ??
        donorRow?['phone_mobile'] as String?;
    final phoneHome = enr?['phone_home'] as String? ??
        donorRow?['phone_home'] as String?;
    final emailPersonal = enr?['email_personal'] as String? ??
        donorRow?['email_personal'] as String?;
    final hasPhone = (phoneMobile != null && phoneMobile.isNotEmpty) ||
        (phoneHome != null && phoneHome.isNotEmpty);
    final hasEmail = emailPersonal != null && emailPersonal.isNotEmpty;

    return BrandedCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name
          Text(
            _profileName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),

          // Enrichment badges
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (partyLean != null && partyLean.isNotEmpty)
                _buildEnrichmentChip(partyLean, _partyLeanColor(partyLean)),
              if (ageEstimate != null)
                _buildEnrichmentChip('Age ~$ageEstimate', Colors.white54),
              if (gender != null && gender.isNotEmpty)
                _buildEnrichmentChip(gender, Colors.white54),
              if (generation != null && generation.isNotEmpty)
                _buildEnrichmentChip(generation, Colors.tealAccent),
              if (isHomeowner == true)
                _buildEnrichmentChip('Homeowner', Colors.green),
              if (wealthScore != null && wealthScore > 0)
                _buildEnrichmentChip(
                  'Wealth: ${wealthScore.toStringAsFixed(0)}',
                  BrandColors.sunriseGold,
                ),
              if (hasPhone)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: BrandColors.success.withOpacity( 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: BrandColors.success.withOpacity( 0.5),
                      width: 0.5,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone, size: 11, color: BrandColors.success),
                      SizedBox(width: 3),
                      Text('Phone',
                          style: TextStyle(
                              color: BrandColors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              if (hasEmail)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.lightBlue.withOpacity( 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.lightBlue.withOpacity( 0.5),
                      width: 0.5,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.email, size: 11, color: Colors.lightBlue),
                      SizedBox(width: 3),
                      Text('Email',
                          style: TextStyle(
                              color: Colors.lightBlue,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Total given
          Text(
            _currencyFormat.format(totalAmount),
            style: const TextStyle(
              color: BrandColors.sunriseGold,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),

          // Count + year range
          Text(
            '$count contribution${count == 1 ? '' : 's'}'
            '${firstYear != null && lastYear != null ? ' from $firstYear to $lastYear' : ''}',
            style: BrandTextStyles.bodySecondary,
          ),
          const SizedBox(height: 8),

          // Location / Employer / Occupation
          _buildProfileMetaRow(city, state, employer, occupation),
        ],
      ),
    );
  }

  Widget _buildProfileMetaRow(
    String? city,
    String? state,
    String? employer,
    String? occupation,
  ) {
    final parts = <String>[];
    final location =
        [city, state].where((s) => s != null && s.isNotEmpty).join(', ');
    if (location.isNotEmpty) parts.add(location);
    if (employer != null && employer.isNotEmpty) parts.add(employer);
    if (occupation != null && occupation.isNotEmpty) parts.add(occupation);

    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(
      parts.join(' \u2022 '),
      style: BrandTextStyles.caption,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  // ===========================================================================
  // ENRICHMENT SECTIONS
  // ===========================================================================

  Widget _buildEnrichmentSections() {
    final enr = _enrichmentData ?? (_unifiedProfile?['donor'] as Map<String, dynamic>?);
    final donorRow = _profileDonorRow;
    if (enr == null && donorRow == null) return const SizedBox.shrink();

    // Collect all enrichment fields
    final phoneMobile = enr?['phone_mobile'] as String? ??
        donorRow?['phone_mobile'] as String?;
    final phoneHome = enr?['phone_home'] as String? ??
        donorRow?['phone_home'] as String?;
    final emailPersonal = enr?['email_personal'] as String? ??
        donorRow?['email_personal'] as String?;
    final employer = enr?['current_employer'] as String? ??
        donorRow?['current_employer'] as String?;
    final jobTitle = enr?['current_job_title'] as String? ??
        donorRow?['current_job_title'] as String?;
    final incomeRange = enr?['estimated_income_range'] as String? ??
        donorRow?['estimated_income_range'] as String?;
    final partyLean = enr?['party_lean'] as String? ??
        donorRow?['party_lean'] as String?;
    final partyLeanConf = (enr?['party_lean_confidence'] as num?)?.toDouble() ??
        (donorRow?['party_lean_confidence'] as num?)?.toDouble();
    final givingCapacity = (enr?['giving_capacity_estimate'] as num?)?.toDouble() ??
        (donorRow?['giving_capacity_estimate'] as num?)?.toDouble();
    final wealthScore = (enr?['wealth_score'] as num?)?.toDouble() ??
        (donorRow?['wealth_score'] as num?)?.toDouble();
    final engagementScore = (enr?['engagement_score'] as num?)?.toDouble() ??
        (donorRow?['engagement_score'] as num?)?.toDouble();
    final socialCount = (enr?['social_profile_count'] as num?)?.toInt() ??
        (donorRow?['social_profile_count'] as num?)?.toInt();
    final ethnicity = enr?['ethnicity'] as String? ??
        donorRow?['ethnicity'] as String?;

    // Address fields
    final addressLine1 = enr?['address_line_1'] as String? ??
        donorRow?['address_line_1'] as String? ??
        enr?['address'] as String? ??
        donorRow?['address'] as String?;
    final addressLine2 = enr?['address_line_2'] as String? ??
        donorRow?['address_line_2'] as String?;
    final addrCity = enr?['city'] as String? ??
        donorRow?['city'] as String?;
    final addrState = enr?['state'] as String? ??
        donorRow?['state'] as String?;
    final zipCode = enr?['zip_code'] as String? ??
        donorRow?['zip_code'] as String? ??
        enr?['zip'] as String? ??
        donorRow?['zip'] as String?;

    final hasAddress = (addressLine1 != null && addressLine1.isNotEmpty) ||
        (addrCity != null && addrCity.isNotEmpty);

    final hasContact = (phoneMobile != null && phoneMobile.isNotEmpty) ||
        (phoneHome != null && phoneHome.isNotEmpty) ||
        (emailPersonal != null && emailPersonal.isNotEmpty);
    final hasEmployment = (employer != null && employer.isNotEmpty) ||
        (jobTitle != null && jobTitle.isNotEmpty) ||
        (incomeRange != null && incomeRange.isNotEmpty);
    final hasPolitical = (partyLean != null && partyLean.isNotEmpty) ||
        givingCapacity != null ||
        wealthScore != null ||
        engagementScore != null;

    if (!hasContact && !hasEmployment && !hasPolitical && !hasAddress) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Address
        if (hasAddress) ...[
          BrandedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.location_on, color: BrandColors.sunriseGold, size: 18),
                    SizedBox(width: 8),
                    Text('Address', style: BrandTextStyles.title),
                  ],
                ),
                const SizedBox(height: 12),
                if (addressLine1 != null && addressLine1.isNotEmpty)
                  _buildDetailRow(Icons.home, 'Street', addressLine1),
                if (addressLine2 != null && addressLine2.isNotEmpty)
                  _buildDetailRow(Icons.home_outlined, 'Line 2', addressLine2),
                if (addrCity != null && addrCity.isNotEmpty || addrState != null && addrState.isNotEmpty) ...[
                  _buildDetailRow(Icons.place, 'City/State',
                    [addrCity, addrState].where((s) => s != null && s.isNotEmpty).join(', ')),
                ],
                if (zipCode != null && zipCode.isNotEmpty)
                  _buildDetailRow(Icons.markunread_mailbox, 'ZIP', zipCode),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Contact Information
        if (hasContact) ...[
          BrandedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.contact_phone, color: BrandColors.sunriseGold, size: 18),
                    SizedBox(width: 8),
                    Text('Contact Information', style: BrandTextStyles.title),
                  ],
                ),
                const SizedBox(height: 12),
                if (phoneMobile != null && phoneMobile.isNotEmpty)
                  _buildDetailRow(Icons.phone_android, 'Mobile', phoneMobile),
                if (phoneHome != null && phoneHome.isNotEmpty)
                  _buildDetailRow(Icons.phone, 'Home', phoneHome),
                if (emailPersonal != null && emailPersonal.isNotEmpty)
                  _buildDetailRow(Icons.email_outlined, 'Email', emailPersonal),
                if (socialCount != null && socialCount > 0)
                  _buildDetailRow(Icons.share, 'Social Profiles', '$socialCount found'),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Employment & Income
        if (hasEmployment) ...[
          BrandedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.work, color: BrandColors.sunriseGold, size: 18),
                    SizedBox(width: 8),
                    Text('Employment', style: BrandTextStyles.title),
                  ],
                ),
                const SizedBox(height: 12),
                if (employer != null && employer.isNotEmpty)
                  _buildDetailRow(Icons.business, 'Employer', employer),
                if (jobTitle != null && jobTitle.isNotEmpty)
                  _buildDetailRow(Icons.badge, 'Title', jobTitle),
                if (incomeRange != null && incomeRange.isNotEmpty)
                  _buildDetailRow(Icons.attach_money, 'Est. Income', incomeRange),
                if (ethnicity != null && ethnicity.isNotEmpty)
                  _buildDetailRow(Icons.people, 'Ethnicity', ethnicity),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Political & Fundraising Profile
        if (hasPolitical) ...[
          BrandedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.how_to_vote, color: BrandColors.sunriseGold, size: 18),
                    SizedBox(width: 8),
                    Text('Political & Fundraising Profile', style: BrandTextStyles.title),
                  ],
                ),
                const SizedBox(height: 12),
                if (partyLean != null && partyLean.isNotEmpty) ...[
                  _buildDetailRow(Icons.flag, 'Party Lean', partyLean),
                  if (partyLeanConf != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 32, bottom: 8),
                      child: Row(
                        children: [
                          Text('Confidence: ', style: BrandTextStyles.caption),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: partyLeanConf,
                                backgroundColor: Colors.white12,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _partyLeanColor(partyLean),
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(partyLeanConf * 100).round()}%',
                            style: BrandTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                ],
                if (givingCapacity != null)
                  _buildDetailRow(Icons.volunteer_activism, 'Giving Capacity',
                      _currencyFormat.format(givingCapacity)),
                if (wealthScore != null)
                  _buildScoreRow('Wealth Score', wealthScore, BrandColors.sunriseGold),
                if (engagementScore != null)
                  _buildScoreRow('Engagement', engagementScore, BrandColors.momentumBlue),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white54, size: 16),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: BrandTextStyles.caption.copyWith(color: Colors.white54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow(String label, double score, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 114,
            child: Text(label, style: BrandTextStyles.caption),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (score / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            score.toStringAsFixed(0),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // UNIFIED PROFILE: MEC CONTRIBUTIONS SECTION
  // ===========================================================================

  Widget _buildMecContributionsSection() {
    final profile = _unifiedProfile;
    if (profile == null) return const SizedBox.shrink();

    final mecContribs = (profile['mec_contributions'] as List<dynamic>?) ?? [];
    final mecBreakdown = (profile['mec_committee_breakdown'] as List<dynamic>?) ?? [];

    if (mecContribs.isEmpty) return const SizedBox.shrink();

    final totalMec = mecContribs.fold<double>(0, (sum, c) => sum + ((c['contribution_amount'] as num?)?.toDouble() ?? 0));

    return BrandedCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BrandColors.momentumBlue.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('MEC', style: TextStyle(color: BrandColors.momentumBlue, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              const Text('Missouri Contributions', style: BrandTextStyles.title),
              const Spacer(),
              Text(_currencyFormat.format(totalMec), style: const TextStyle(color: BrandColors.sunriseGold, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          // Individual MEC contributions with alternating rows
          ...List.generate(mecContribs.length, (i) {
            final c = mecContribs[i];
            final amount = (c['contribution_amount'] as num?)?.toDouble() ?? 0;
            final date = c['contribution_date'] as String? ?? '';
            final committee = c['committee_name'] as String? ?? '';
            final mecId = c['mec_id'] as String? ?? '';
            String displayDate = date;
            if (date.isNotEmpty) {
              try { displayDate = _dateFormat.format(DateTime.parse(date)); } catch (_) {}
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: i.isEven
                    ? BrandColors.unityBlue.withOpacity(0.5)
                    : BrandColors.unityBlue.withOpacity(0.3),
                borderRadius: i == 0
                    ? const BorderRadius.vertical(top: Radius.circular(8))
                    : i == mecContribs.length - 1
                        ? const BorderRadius.vertical(bottom: Radius.circular(8))
                        : BorderRadius.zero,
              ),
              child: Row(
                children: [
                  SizedBox(width: 90, child: Text(displayDate, style: BrandTextStyles.caption)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: mecId.isNotEmpty && widget.onNavigateToCommittee != null
                          ? () => widget.onNavigateToCommittee!(mecId, committee, 'mec')
                          : null,
                      child: Text(
                        committee,
                        style: TextStyle(
                          color: mecId.isNotEmpty && widget.onNavigateToCommittee != null
                              ? BrandColors.momentumBlue
                              : Colors.white,
                          fontSize: 13,
                          decoration: mecId.isNotEmpty && widget.onNavigateToCommittee != null
                              ? TextDecoration.underline
                              : null,
                          decorationColor: BrandColors.momentumBlue,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_currencyFormat.format(amount), style: const TextStyle(color: BrandColors.sunriseGold, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // UNIFIED PROFILE: FEC CONTRIBUTIONS SECTION
  // ===========================================================================

  Widget _buildFecContributionsSection() {
    final profile = _unifiedProfile;
    if (profile == null) return const SizedBox.shrink();

    final fecContribs = (profile['fec_contributions'] as List<dynamic>?) ?? [];
    final fecBreakdown = (profile['fec_committee_breakdown'] as List<dynamic>?) ?? [];

    if (fecContribs.isEmpty) return const SizedBox.shrink();

    final totalFec = fecContribs.fold<double>(0, (sum, c) => sum + ((c['contribution_amount'] as num?)?.toDouble() ?? 0));

    return BrandedCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BrandColors.success.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('FEC', style: TextStyle(color: BrandColors.success, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              const Text('Federal Contributions', style: BrandTextStyles.title),
              const Spacer(),
              Text(_currencyFormat.format(totalFec), style: const TextStyle(color: BrandColors.sunriseGold, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          // Individual FEC contributions with alternating rows
          ...List.generate(fecContribs.length, (i) {
            final c = fecContribs[i];
            final amount = (c['transaction_amount'] as num?)?.toDouble() ??
                (c['contribution_amount'] as num?)?.toDouble() ?? 0;
            final date = c['transaction_date'] as String? ?? '';
            final committee = c['committee_name'] as String? ?? '';
            final cmteId = c['cmte_id'] as String? ?? '';
            String displayDate = date;
            if (date.isNotEmpty) {
              try { displayDate = _dateFormat.format(DateTime.parse(date)); } catch (_) {}
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: i.isEven
                    ? BrandColors.unityBlue.withOpacity(0.5)
                    : BrandColors.unityBlue.withOpacity(0.3),
                borderRadius: i == 0
                    ? const BorderRadius.vertical(top: Radius.circular(8))
                    : i == fecContribs.length - 1
                        ? const BorderRadius.vertical(bottom: Radius.circular(8))
                        : BorderRadius.zero,
              ),
              child: Row(
                children: [
                  SizedBox(width: 90, child: Text(displayDate, style: BrandTextStyles.caption)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: cmteId.isNotEmpty && widget.onNavigateToCommittee != null
                          ? () => widget.onNavigateToCommittee!(cmteId, committee, 'fec')
                          : null,
                      child: Text(
                        committee,
                        style: TextStyle(
                          color: cmteId.isNotEmpty && widget.onNavigateToCommittee != null
                              ? BrandColors.success
                              : Colors.white,
                          fontSize: 13,
                          decoration: cmteId.isNotEmpty && widget.onNavigateToCommittee != null
                              ? TextDecoration.underline
                              : null,
                          decorationColor: BrandColors.success,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_currencyFormat.format(amount), style: const TextStyle(color: BrandColors.sunriseGold, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // COMMITTEE DONATIONS POPUP
  // ===========================================================================

  void _showCommitteeDonationsDialog(Map<String, dynamic> committee) {
    final committeeName = committee['committeeName'] as String? ?? 'Unknown Committee';
    final mecId = committee['mecId'] as String?;
    final total = committee['total'] as double? ?? 0.0;
    final count = committee['count'] as int? ?? 0;

    // Filter contributions for this committee
    final allContribs =
        _profileData['contributions'] as List<MecContribution>? ?? [];
    final matching = allContribs.where((c) {
      if (mecId != null && c.mecId == mecId) return true;
      if (c.committeeName == committeeName) return true;
      return false;
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: BrandColors.unityBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: BrandColors.tileGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      committeeName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_currencyFormat.format(total)} across $count contribution${count == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: BrandColors.sunriseGold,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Contributions list
              Flexible(
                child: matching.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No individual contribution records found',
                            style: BrandTextStyles.subtitle),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        shrinkWrap: true,
                        itemCount: matching.length,
                        itemBuilder: (ctx, i) {
                          final c = matching[i];
                          final isEven = i.isEven;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isEven ? Colors.white10 : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    c.contributionDate != null
                                        ? _dateFormat.format(c.contributionDate!)
                                        : 'Unknown',
                                    style: BrandTextStyles.caption,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    c.monetaryOrInkind ?? 'Monetary',
                                    style: BrandTextStyles.caption,
                                  ),
                                ),
                                Text(
                                  c.formattedAmount,
                                  style: const TextStyle(
                                    color: BrandColors.sunriseGold,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              // Footer with actions
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (mecId != null)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          if (widget.onNavigateToCommittee != null) {
                            widget.onNavigateToCommittee!(mecId, committeeName, 'mec');
                          }
                        },
                        icon: const Icon(Icons.open_in_new,
                            color: BrandColors.momentumBlue, size: 16),
                        label: const Text('View Committee',
                            style: TextStyle(color: BrandColors.momentumBlue)),
                      ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Close',
                          style: TextStyle(color: Colors.white70)),
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

  Widget _buildCommitteesSection() {
    final committees =
        _profileData['committees'] as List<dynamic>? ?? [];

    if (committees.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Committees Donated To', style: BrandTextStyles.titleLarge),
        const SizedBox(height: 12),
        ...committees.map((c) {
          final map = c as Map<String, dynamic>;
          final name = map['committeeName'] as String? ?? 'Unknown Committee';
          final total = map['total'] as double? ?? 0.0;
          final count = map['count'] as int? ?? 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: BrandedCard(
              onTap: () => _showCommitteeDonationsDialog(map),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              elevation: 2,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$count contribution${count == 1 ? '' : 's'}',
                          style: BrandTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currencyFormat.format(total),
                    style: const TextStyle(
                      color: BrandColors.sunriseGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildContributionsTimeline() {
    final contributions =
        _profileData['contributions'] as List<MecContribution>? ?? [];

    if (contributions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Contributions (${contributions.length})',
          style: BrandTextStyles.titleLarge,
        ),
        const SizedBox(height: 12),
        ...List.generate(contributions.length, (i) {
          final c = contributions[i];
          final isEven = i.isEven;

          return Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isEven
                  ? BrandColors.unityBlue.withOpacity(0.5)
                  : BrandColors.unityBlue.withOpacity(0.3),
              borderRadius: i == 0
                  ? const BorderRadius.vertical(top: Radius.circular(10))
                  : i == contributions.length - 1
                      ? const BorderRadius.vertical(
                          bottom: Radius.circular(10))
                      : BorderRadius.zero,
            ),
            child: Row(
              children: [
                // Date
                SizedBox(
                  width: 90,
                  child: Text(
                    c.contributionDate != null
                        ? _dateFormat.format(c.contributionDate!)
                        : 'Unknown',
                    style: BrandTextStyles.caption,
                  ),
                ),
                const SizedBox(width: 8),

                // Committee name
                Expanded(
                  child: GestureDetector(
                    onTap: c.mecId != null && c.mecId!.isNotEmpty && widget.onNavigateToCommittee != null
                        ? () => widget.onNavigateToCommittee!(c.mecId!, c.committeeName ?? '', 'mec')
                        : null,
                    child: Text(
                      c.committeeName ?? 'Unknown Committee',
                      style: TextStyle(
                        color: c.mecId != null && c.mecId!.isNotEmpty && widget.onNavigateToCommittee != null
                            ? BrandColors.momentumBlue
                            : Colors.white,
                        fontSize: 13,
                        decoration: c.mecId != null && c.mecId!.isNotEmpty && widget.onNavigateToCommittee != null
                            ? TextDecoration.underline
                            : null,
                        decorationColor: BrandColors.momentumBlue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Amount
                Text(
                  c.formattedAmount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Party option helper
// ---------------------------------------------------------------------------

class _PartyOption {
  final String label;
  final String? value;
  final Color color;

  const _PartyOption({
    required this.label,
    required this.value,
    required this.color,
  });
}
