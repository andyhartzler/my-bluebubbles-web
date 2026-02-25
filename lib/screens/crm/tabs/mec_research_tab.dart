import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/mec_contribution.dart';
import 'package:bluebubbles/services/crm/mec_repository.dart';

class MecResearchTab extends StatefulWidget {
  const MecResearchTab({super.key});

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
  bool _hasSearched = false;
  String? _error;
  int? _yearFrom;
  int? _yearTo;
  String _selectedState = 'MO';
  String? _selectedParty;

  // Profile state
  bool _inProfileMode = false;
  Map<String, dynamic> _profileData = {};
  bool _profileLoading = false;
  String _profileName = '';
  String? _profileFirstName;
  String? _profileLastName;
  String? _profileCompany;

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
  void dispose() {
    _searchController.dispose();
    _minAmountController.dispose();
    super.dispose();
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
    });

    try {
      final results = await _repository.searchDonors(
        nameQuery: nameQuery.isNotEmpty ? nameQuery : null,
        state: _selectedState.isNotEmpty ? _selectedState : null,
        yearFrom: _yearFrom,
        yearTo: _yearTo,
        minTotal: minTotal,
        party: _selectedParty,
        limit: 100,
      );

      if (!mounted) return;
      setState(() {
        _donors = results;
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
    final lastName = (donor['contributor_last_name'] as String?) ?? '';
    final firstName = donor['contributor_first_name'] as String?;
    final company = donor['contributor_company'] as String?;

    if (lastName.isEmpty && (company == null || company.isEmpty)) return;

    // Build display name
    String displayName;
    if (company != null && company.isNotEmpty && lastName.isEmpty) {
      displayName = company;
    } else {
      final parts = <String>[];
      if (lastName.isNotEmpty) parts.add(lastName);
      if (firstName != null && firstName.isNotEmpty) parts.add(firstName);
      displayName = parts.join(', ');
    }

    setState(() {
      _inProfileMode = true;
      _profileLoading = true;
      _profileName = displayName;
      _profileFirstName = firstName;
      _profileLastName = lastName;
      _profileCompany = company;
      _profileData = {};
    });

    try {
      final data = await _repository.getContributorProfile(
        lastName: lastName,
        firstName: firstName,
        company: company,
      );

      if (!mounted) return;
      setState(() {
        _profileData = data;
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
    final currentYear = DateTime.now().year;
    final years = List.generate(currentYear - 2001, (i) => currentYear - i);

    return Row(
      children: [
        // State dropdown
        Expanded(
          child: _buildStateDropdown(),
        ),
        const SizedBox(width: 8),

        // Year From dropdown
        Expanded(
          child: _buildYearDropdown(
            label: 'From',
            value: _yearFrom,
            years: years,
            onChanged: (v) => setState(() => _yearFrom = v),
          ),
        ),
        const SizedBox(width: 8),

        // Year To dropdown
        Expanded(
          child: _buildYearDropdown(
            label: 'To',
            value: _yearTo,
            years: years,
            onChanged: (v) => setState(() => _yearTo = v),
          ),
        ),
        const SizedBox(width: 8),

        // Min amount text field
        Expanded(
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

  Widget _buildYearDropdown({
    required String label,
    required int? value,
    required List<int> years,
    required ValueChanged<int?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: value,
          hint: Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          isExpanded: true,
          dropdownColor: BrandColors.unityBlue,
          iconEnabledColor: Colors.white70,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text('$label: All',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ),
            ...years.map(
              (y) => DropdownMenuItem<int?>(
                value: y,
                child: Text('$y', style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],
          onChanged: onChanged,
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
              'Use the filters above to search 3M+ donor records.\n'
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
            _donors.length >= 100
                ? 'Showing first 100 donors'
                : 'Found ${_donors.length} donor${_donors.length == 1 ? '' : 's'}',
            style: BrandTextStyles.subtitle,
          ),
        ),

        // Donor cards
        ...List.generate(_donors.length, (i) {
          final donor = _donors[i];
          return _buildDonorCard(donor);
        }),
      ],
    );
  }

  Widget _buildDonorCard(Map<String, dynamic> donor) {
    final name = _donorDisplayName(donor);
    final totalAmount = (donor['total_amount'] as num?)?.toDouble() ?? 0.0;
    final contributionCount = (donor['contribution_count'] as num?)?.toInt() ?? 0;
    final city = donor['city'] as String?;
    final state = donor['state'] as String?;
    final employer = donor['employer'] as String?;
    final occupation = donor['occupation'] as String?;
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
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
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
          const SizedBox(height: 24),

          // Committees section
          _buildCommitteesSection(),
          const SizedBox(height: 24),

          // Contributions timeline
          _buildContributionsTimeline(),
        ],
      ],
    );
  }

  Widget _buildProfileHeader() {
    final totalAmount = _profileData['totalAmount'] as double? ?? 0.0;
    final count = _profileData['count'] as int? ?? 0;
    final firstYear = _profileData['firstYear'] as int?;
    final lastYear = _profileData['lastYear'] as int?;
    final contributions =
        _profileData['contributions'] as List<MecContribution>? ?? [];

    // Gather metadata from the most recent contribution
    String? city;
    String? state;
    String? employer;
    String? occupation;
    if (contributions.isNotEmpty) {
      final recent = contributions.first;
      city = recent.city;
      state = recent.state;
      employer = recent.employer;
      occupation = recent.occupation;
    }

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
          const SizedBox(height: 8),

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.committeeName ?? 'Unknown Committee',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (c.reportType != null)
                        Text(
                          c.reportType!,
                          style: BrandTextStyles.caption,
                        ),
                    ],
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
