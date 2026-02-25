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
  List<MecContribution> _contributions = [];
  bool _loading = false;
  String? _error;
  int? _yearFrom;
  int? _yearTo;
  double? _minAmount;
  Timer? _debounce;

  // Profile state
  bool _inProfileMode = false;
  Map<String, dynamic> _profileData = {};
  bool _profileLoading = false;
  String _profileName = '';
  String? _profileFirstName;
  String? _profileLastName;
  String? _profileCompany;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _minAmountController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Search logic
  // ---------------------------------------------------------------------------

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.trim().isNotEmpty) {
        _performSearch();
      }
    });
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    // Parse min amount from controller
    final minAmountText = _minAmountController.text.trim();
    _minAmount = minAmountText.isNotEmpty ? double.tryParse(minAmountText) : null;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await _repository.searchContributions(
        query: query,
        yearFrom: _yearFrom,
        yearTo: _yearTo,
        minAmount: _minAmount,
        limit: 200,
      );

      if (!mounted) return;
      setState(() {
        _contributions = results;
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

  Future<void> _openProfile(MecContribution contribution) async {
    final lastName = contribution.contributorLastName ?? '';
    final firstName = contribution.contributorFirstName;
    final company = contribution.contributorCompany;

    if (lastName.isEmpty && (company == null || company.isEmpty)) return;

    setState(() {
      _inProfileMode = true;
      _profileLoading = true;
      _profileName = contribution.contributorDisplayName;
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
        // Search bar
        _buildSearchBar(),
        const SizedBox(height: 12),

        // Filter row
        _buildFilterRow(),
        const SizedBox(height: 16),

        // Search button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _performSearch,
            icon: const Icon(Icons.search, color: Colors.white),
            label: const Text('Search MEC Database',
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
        if (!_loading && _error == null && _contributions.isNotEmpty)
          _buildResultsSection(),
        if (!_loading &&
            _error == null &&
            _contributions.isEmpty &&
            _searchController.text.trim().isNotEmpty)
          _buildEmptyState(),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, color: Colors.white70),
        labelText: 'Search contributors, companies, or committees',
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: BrandColors.unityBlue.withOpacity(0.7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: BrandColors.momentumBlue, width: 2),
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
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: BrandColors.momentumBlue, width: 2),
              ),
            ),
          ),
        ),
      ],
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

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            CircularProgressIndicator(color: BrandColors.momentumBlue),
            SizedBox(height: 16),
            Text('Searching...', style: BrandTextStyles.subtitle),
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

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.white38),
            SizedBox(height: 12),
            Text('No contributions found',
                style: BrandTextStyles.subtitle),
            SizedBox(height: 4),
            Text('Try a different search term or adjust filters',
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
        // Result count
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            _contributions.length >= 200
                ? 'Showing first 200 results'
                : 'Found ${_contributions.length} contributions',
            style: BrandTextStyles.subtitle,
          ),
        ),

        // Result cards
        ...List.generate(_contributions.length, (i) {
          final c = _contributions[i];
          return _buildContributionCard(c);
        }),
      ],
    );
  }

  Widget _buildContributionCard(MecContribution c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BrandedCard(
        onTap: () => _openProfile(c),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: name + amount
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    c.contributorDisplayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  c.formattedAmount,
                  style: BrandTextStyles.title,
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Bottom row: committee, date, location, employer
            if (c.committeeName != null)
              Text(c.committeeName!,
                  style: BrandTextStyles.bodySecondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(c.formattedDate, style: BrandTextStyles.caption),
                if (c.city != null || c.state != null) ...[
                  const Text('  |  ', style: BrandTextStyles.caption),
                  Text(
                    [c.city, c.state]
                        .where((s) => s != null && s.isNotEmpty)
                        .join(', '),
                    style: BrandTextStyles.caption,
                  ),
                ],
              ],
            ),
            if (c.employer != null && c.employer!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  c.employer!,
                  style: BrandTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
