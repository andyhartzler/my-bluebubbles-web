import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/chapter.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/chapter_repository.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

import 'bulk_message_screen.dart';
import 'chapter_detail_screen.dart';
import 'member_detail_screen.dart';

/// Screen showing all CRM members with search and filters
class MembersListScreen extends StatefulWidget {
  final bool embed;
  final bool showChaptersOnly;

  const MembersListScreen({Key? key, this.embed = false, this.showChaptersOnly = false})
      : super(key: key);

  @override
  State<MembersListScreen> createState() => _MembersListScreenState();
}

class _MembersListScreenState extends State<MembersListScreen> {
  final MemberRepository _memberRepo = MemberRepository();
  final ChapterRepository _chapterRepository = ChapterRepository();
  final CRMSupabaseService _supabaseService = CRMSupabaseService();

  List<Member> _members = [];
  List<Member> _filteredMembers = [];
  List<Chapter> _chapters = [];
  List<Chapter> _filteredChapters = [];

  bool _loading = true;
  bool _crmReady = false;
  String _searchQuery = '';
  late int _activeView;
  bool _filtersExpandedOnMobile = false;

  // Filter state
  String? _selectedCounty;
  String? _selectedDistrict;
  List<String>? _selectedCommittees;
  String? _selectedChapter;
  String? _selectedChapterStatus;
  String? _selectedCommunityType;
  String? _selectedChapterPosition;
  String? _registeredVoterFilter;
  String? _contactFilter;
  int? _minAgeFilter;
  int? _maxAgeFilter;

  // Available filter options
  List<String> _counties = [];
  List<String> _districts = [];
  List<String> _committees = [];
  List<String> _chapterNames = [];
  List<String> _chapterStatuses = [];
  List<String> _communityTypes = [];
  List<String> _chapterPositions = [];

  Map<String, int> _memberCountByChapter = {};
  Map<String, int> _leaderCountByChapter = {};
  int? _availableMinAge;
  int? _availableMaxAge;

  static const List<Color> _memberCardGradient = [Color(0xFF0F4C75), Color(0xFF3282B8)];

  @override
  void initState() {
    super.initState();
    _crmReady = _supabaseService.isInitialized && CRMConfig.crmEnabled;
    _activeView = widget.showChaptersOnly ? 1 : 0;
    _loadData();
  }

  @override
  void didUpdateWidget(covariant MembersListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showChaptersOnly != widget.showChaptersOnly) {
      _activeView = widget.showChaptersOnly ? 1 : 0;
    }
  }

  bool get _showingChapters => widget.showChaptersOnly || _activeView == 1;

  Future<void> _loadData() async {
    if (!_crmReady) {
      setState(() {
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);

    try {
      final results = await Future.wait([
        _memberRepo.getAllMembers(),
        _memberRepo.getUniqueCounties(),
        _memberRepo.getUniqueCongressionalDistricts(),
        _memberRepo.getUniqueCommittees(),
        _memberRepo.getChapterCounts(),
        _memberRepo.getChapterStatusCounts(),
        _memberRepo.getCommunityTypeCounts(),
        _memberRepo.getChapterPositionCounts(),
        _chapterRepository.getAllChapters(),
      ]);

      if (!mounted) return;

      final members = results[0] as List<Member>;
      final counties = results[1] as List<String>;
      final districts = results[2] as List<String>;
      final committees = results[3] as List<String>;
      final rawChapterCounts = Map<String, int>.from(results[4] as Map);
      final chapterStatusCounts = Map<String, int>.from(results[5] as Map);
      final communityCounts = Map<String, int>.from(results[6] as Map);
      final chapterPositionCounts = Map<String, int>.from(results[7] as Map);
      final chapters = results[8] as List<Chapter>;

      final normalizedChapterCounts = <String, int>{};
      final chapterNameMap = <String, String>{};
      rawChapterCounts.forEach((key, value) {
        final cleaned = _cleanValue(key);
        if (cleaned == null) return;
        final normalized = _normalizeKey(cleaned)!;
        normalizedChapterCounts[normalized] = value;
        chapterNameMap[normalized] = cleaned;
      });

      for (final chapter in chapters) {
        final cleaned = _cleanValue(chapter.chapterName);
        if (cleaned == null) continue;
        chapterNameMap[_normalizeKey(cleaned)!] = cleaned;
      }

      final chapterNames = chapterNameMap.values.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      final chapterStatuses = chapterStatusCounts.keys
          .map(_cleanValue)
          .whereType<String>()
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      final communityTypes = communityCounts.keys
          .map(_cleanValue)
          .whereType<String>()
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      final chapterPositions = chapterPositionCounts.keys
          .map(_cleanValue)
          .whereType<String>()
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      setState(() {
        _members = members;
        _counties = counties;
        _districts = districts;
        _committees = committees;
        _chapters = chapters;
        _chapterNames = chapterNames;
        _chapterStatuses = chapterStatuses;
        _communityTypes = communityTypes;
        _chapterPositions = chapterPositions;
        _memberCountByChapter = normalizedChapterCounts;
        _leaderCountByChapter = _computeLeaderCounts(members);
        _deriveAgeBounds(members);
        _filteredMembers = _computeFilteredMembers();
        _filteredChapters = _computeFilteredChapters();
        _loading = false;
      });
    } catch (e) {
      print('❌ Error loading members: $e');
      if (!mounted) return;

      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading members: $e')),
      );
    }
  }

  void _deriveAgeBounds(List<Member> members) {
    final ages = members.map((member) => member.age).whereType<int>().toList()..sort();
    if (ages.isEmpty) {
      _availableMinAge = null;
      _availableMaxAge = null;
      _minAgeFilter = null;
      _maxAgeFilter = null;
      return;
    }

    _availableMinAge = ages.first;
    _availableMaxAge = ages.last;

    if (_minAgeFilter != null && _availableMinAge != null && _minAgeFilter! < _availableMinAge!) {
      _minAgeFilter = _availableMinAge;
    }
    if (_maxAgeFilter != null && _availableMaxAge != null && _maxAgeFilter! > _availableMaxAge!) {
      _maxAgeFilter = _availableMaxAge;
    }
  }

  Map<String, int> _computeLeaderCounts(List<Member> members) {
    final counts = <String, int>{};
    for (final member in members) {
      final chapterKey = _normalizeKey(member.chapterName);
      final position = _cleanValue(member.chapterPosition);
      if (chapterKey == null || position == null) continue;
      counts[chapterKey] = (counts[chapterKey] ?? 0) + 1;
    }
    return counts;
  }

  void _updateFilters(void Function() updater) {
    setState(() {
      updater();
      _filteredMembers = _computeFilteredMembers();
      _filteredChapters = _computeFilteredChapters();
    });
  }

  List<Member> _computeFilteredMembers() {
    final query = _searchQuery.trim().toLowerCase();

    final filtered = _members.where((member) {
      if (query.isNotEmpty && !_matchesMemberQuery(member, query)) {
        return false;
      }

      if (_selectedCounty != null && !_equalsIgnoreCase(member.county, _selectedCounty)) {
        return false;
      }

      if (_selectedDistrict != null && !_equalsIgnoreCase(member.congressionalDistrict, _selectedDistrict)) {
        return false;
      }

      if (_selectedChapter != null && !_equalsIgnoreCase(member.chapterName, _selectedChapter)) {
        return false;
      }

      if (_selectedChapterStatus != null && !_equalsIgnoreCase(member.currentChapterMember, _selectedChapterStatus)) {
        return false;
      }

      if (_selectedCommunityType != null && !_equalsIgnoreCase(member.communityType, _selectedCommunityType)) {
        return false;
      }

      if (_selectedChapterPosition != null && !_equalsIgnoreCase(member.chapterPosition, _selectedChapterPosition)) {
        return false;
      }

      if (_selectedCommittees != null && _selectedCommittees!.isNotEmpty) {
        if (member.committee == null) return false;
        final normalizedCommittees = member.committee!
            .map(_normalizeKey)
            .whereType<String>()
            .toSet();
        for (final committee in _selectedCommittees!) {
          final normalized = _normalizeKey(committee);
          if (normalized == null || !normalizedCommittees.contains(normalized)) {
            return false;
          }
        }
      }

      if (_registeredVoterFilter != null) {
        final isRegistered = member.registeredVoter == true;
        if (_registeredVoterFilter == 'registered' && !isRegistered) return false;
        if (_registeredVoterFilter == 'not_registered' && isRegistered) return false;
      }

      if (_contactFilter != null) {
        if (_contactFilter == 'contactable' && member.optOut) return false;
        if (_contactFilter == 'opted_out' && !member.optOut) return false;
      }

      if (_minAgeFilter != null || _maxAgeFilter != null) {
        final age = member.age;
        if (age == null) return false;
        if (_minAgeFilter != null && age < _minAgeFilter!) return false;
        if (_maxAgeFilter != null && age > _maxAgeFilter!) return false;
      }

      return true;
    }).toList()
      ..sort((a, b) {
        final aHasPhoto = a.hasProfilePhoto;
        final bHasPhoto = b.hasProfilePhoto;
        if (aHasPhoto != bHasPhoto) {
          return aHasPhoto ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return filtered;
  }

  List<Chapter> _computeFilteredChapters() {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = _chapters.where((chapter) {
      if (query.isEmpty) return true;
      bool contains(String? value) => value != null && value.toLowerCase().contains(query);
      return contains(chapter.chapterName) ||
          contains(chapter.standardizedName) ||
          contains(chapter.schoolName) ||
          contains(chapter.chapterType) ||
          contains(chapter.status);
    }).toList()
      ..sort((a, b) => a.chapterName.toLowerCase().compareTo(b.chapterName.toLowerCase()));

    return filtered;
  }

  bool _matchesMemberQuery(Member member, String query) {
    bool matches(String? value) => value != null && value.toLowerCase().contains(query);

    if (member.name.toLowerCase().contains(query)) return true;
    if (matches(member.phone)) return true;
    if (matches(member.phoneE164)) return true;
    if (matches(member.preferredEmail)) return true;
    if (matches(member.county)) return true;
    if (matches(member.congressionalDistrict)) return true;
    if (matches(member.chapterName)) return true;
    if (matches(member.chapterPosition)) return true;
    if (matches(member.communityType)) return true;
    if (matches(member.currentChapterMember)) return true;
    if (matches(member.notes)) return true;
    if (member.committee != null && member.committee!.any((committee) => matches(committee))) return true;
    return false;
  }

  String? _cleanValue(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _normalizeKey(String? value) {
    final cleaned = _cleanValue(value);
    return cleaned?.toLowerCase();
  }

  bool _equalsIgnoreCase(String? a, String? b) {
    final normA = _normalizeKey(a);
    final normB = _normalizeKey(b);
    if (normA == null && normB == null) return true;
    if (normA == null || normB == null) return false;
    return normA == normB;
  }

  int _memberCountForChapter(String? name) {
    final key = _normalizeKey(name);
    if (key == null) return 0;
    return _memberCountByChapter[key] ?? 0;
  }

  int _leaderCountForChapter(String? name) {
    final key = _normalizeKey(name);
    if (key == null) return 0;
    return _leaderCountByChapter[key] ?? 0;
  }

  void _clearFilters() {
    _updateFilters(() {
      _searchQuery = '';
      _selectedCounty = null;
      _selectedDistrict = null;
      _selectedCommittees = null;
      _selectedChapter = null;
      _selectedChapterStatus = null;
      _selectedCommunityType = null;
      _selectedChapterPosition = null;
      _registeredVoterFilter = null;
      _contactFilter = null;
      _minAgeFilter = null;
      _maxAgeFilter = null;
    });
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  String? _formatDistrict(String? value) => Member.formatDistrictLabel(value);

  String? _formatMemberPhone(Member member) {
    final e164 = member.phoneE164?.trim();
    if (e164 != null && e164.isNotEmpty) {
      final match = RegExp(r'^\+1(\d{10})$').firstMatch(e164);
      if (match != null) {
        final digits = match.group(1)!;
        final areaCode = digits.substring(0, 3);
        final prefix = digits.substring(3, 6);
        final lineNumber = digits.substring(6);
        return '+1 ($areaCode) $prefix-$lineNumber';
      }
      return e164;
    }

    final fallback = member.phone?.trim();
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildContent(context);

    if (widget.embed) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('CRM Members'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _crmReady ? _loadData : null,
            tooltip: 'Refresh',
          ),
          if (CRMConfig.bulkMessagingEnabled)
            IconButton(
              icon: const Icon(Icons.message),
              onPressed: _crmReady
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BulkMessageScreen(),
                        ),
                      );
                    }
                  : null,
              tooltip: 'Bulk Message',
            ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_crmReady) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'CRM Supabase is not configured. Please verify environment variables.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final showingChapters = _showingChapters;

    final slivers = <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        sliver: SliverToBoxAdapter(child: _buildSearchField()),
      ),
      if (!showingChapters)
        SliverToBoxAdapter(
          child: _buildFilterRow(),
        ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        sliver: SliverToBoxAdapter(
          child: Text(
            showingChapters
                ? 'Showing ${_filteredChapters.length} of ${_chapters.length} chapters'
                : 'Showing ${_filteredMembers.length} of ${_members.length} members',
            style: theme.textTheme.labelMedium,
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
      showingChapters ? _buildChaptersSliver(theme) : _buildMembersSliver(theme),
    ];

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        key: const PageStorageKey<String>('members-scroll-view'),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: slivers,
      ),
    );
  }

  Widget _buildSearchField() {
    final hint = _showingChapters
        ? 'Search chapters by name, contact, or status...'
        : 'Search by name, contact, chapter, or committee...';
    return TextField(
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _updateFilters(() => _searchQuery = ''),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      onChanged: (value) => _updateFilters(() => _searchQuery = value),
    );
  }

  Widget _buildFilterRow() {
    if (_showingChapters) return const SizedBox.shrink();
    final hasFilters = _selectedCounty != null ||
        _selectedDistrict != null ||
        _selectedChapter != null ||
        _selectedChapterStatus != null ||
        _selectedCommunityType != null ||
        _selectedChapterPosition != null ||
        _registeredVoterFilter != null ||
        _contactFilter != null ||
        _minAgeFilter != null ||
        _maxAgeFilter != null ||
        (_selectedCommittees != null && _selectedCommittees!.isNotEmpty);

    final activeFilterCount = _activeFiltersCount();
    final chips = <Widget>[
      _buildFilterChip(
        label: _selectedCounty ?? 'County',
        selected: _selectedCounty != null,
        onTap: _showCountyFilter,
        icon: Icons.map_outlined,
      ),
      _buildFilterChip(
        label: _selectedDistrict != null
            ? 'District ${_formatDistrict(_selectedDistrict) ?? _selectedDistrict!}'
            : 'District',
        selected: _selectedDistrict != null,
        onTap: _showDistrictFilter,
        icon: Icons.account_balance,
      ),
      _buildFilterChip(
        label: _selectedChapter ?? 'Chapter',
        selected: _selectedChapter != null,
        onTap: _showingChapters ? null : _showChapterFilter,
        icon: Icons.flag_outlined,
      ),
      _buildFilterChip(
        label: _selectedChapterStatus ?? 'Chapter Status',
        selected: _selectedChapterStatus != null,
        onTap: _showChapterStatusFilter,
        icon: Icons.how_to_vote,
      ),
      _buildFilterChip(
        label: _selectedChapterPosition ?? 'Leadership Role',
        selected: _selectedChapterPosition != null,
        onTap: _showChapterPositionFilter,
        icon: Icons.emoji_events_outlined,
      ),
      _buildFilterChip(
        label: _selectedCommunityType ?? 'Community',
        selected: _selectedCommunityType != null,
        onTap: _showCommunityFilter,
        icon: Icons.apartment,
      ),
      _buildFilterChip(
        label: _selectedCommittees == null || _selectedCommittees!.isEmpty
            ? 'Committees'
            : '${_selectedCommittees!.length} selected',
        selected: _selectedCommittees != null && _selectedCommittees!.isNotEmpty,
        onTap: _showCommitteeFilter,
        icon: Icons.groups,
      ),
      _buildFilterChip(
        label: _registeredVoterFilter == null
            ? 'Registered Voter'
            : (_registeredVoterFilter == 'registered' ? 'Registered' : 'Not Registered'),
        selected: _registeredVoterFilter != null,
        onTap: _showRegisteredFilter,
        icon: Icons.how_to_reg,
      ),
      _buildFilterChip(
        label: _contactFilter == null
            ? 'Contact Status'
            : (_contactFilter == 'contactable' ? 'Contactable' : 'Opted Out'),
        selected: _contactFilter != null,
        onTap: _showContactFilter,
        icon: Icons.sms_outlined,
      ),
      _buildFilterChip(
        label: _minAgeFilter != null || _maxAgeFilter != null
            ? 'Age ${_minAgeFilter ?? _availableMinAge ?? ''}-${_maxAgeFilter ?? _availableMaxAge ?? ''}'
            : 'Age Range',
        selected: _minAgeFilter != null || _maxAgeFilter != null,
        onTap: _showAgeFilter,
        icon: Icons.cake_outlined,
      ),
    ];

    final isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _filtersExpandedOnMobile = !_filtersExpandedOnMobile;
                    }),
                    icon: Icon(_filtersExpandedOnMobile ? Icons.filter_alt_off : Icons.filter_alt),
                    label: Text(
                      _filtersExpandedOnMobile
                          ? 'Hide Filters'
                          : 'Show Filters${activeFilterCount > 0 ? ' ($activeFilterCount)' : ''}',
                    ),
                  ),
                ),
                if (hasFilters) ...[
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear'),
                  ),
                ],
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: chips,
                ),
              ),
              crossFadeState:
                  _filtersExpandedOnMobile ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ..._interleaveChips(chips),
          if (hasFilters) ...[
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear'),
            ),
          ],
        ],
      ),
    );
  }

  int _activeFiltersCount() {
    int count = 0;
    if (_selectedCounty != null) count++;
    if (_selectedDistrict != null) count++;
    if (_selectedChapter != null) count++;
    if (_selectedChapterStatus != null) count++;
    if (_selectedCommunityType != null) count++;
    if (_selectedChapterPosition != null) count++;
    if (_registeredVoterFilter != null) count++;
    if (_contactFilter != null) count++;
    if (_minAgeFilter != null || _maxAgeFilter != null) count++;
    if (_selectedCommittees != null && _selectedCommittees!.isNotEmpty) count++;
    return count;
  }

  List<Widget> _interleaveChips(List<Widget> chips) {
    if (chips.isEmpty) return <Widget>[];
    final result = <Widget>[];
    for (int i = 0; i < chips.length; i++) {
      if (i > 0) {
        result.add(const SizedBox(width: 12));
      }
      result.add(chips[i]);
    }
    return result;
  }

  Widget _buildMembersSliver(ThemeData theme) {
    if (_filteredMembers.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Align(
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 96),
                _buildEmptyMembersState(theme),
              ],
            ),
          ),
        ),
      );
    }

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        if (width < 600) {
          final itemCount = _filteredMembers.length * 2 - 1;
          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index.isOdd) {
                    return const SizedBox(height: 16);
                  }
                  final itemIndex = index ~/ 2;
                  return _buildMemberCard(
                    _filteredMembers[itemIndex],
                    itemIndex,
                    isMobile: true,
                  );
                },
                childCount: itemCount > 0 ? itemCount : 0,
              ),
            ),
          );
        }

        return SliverPadding(
          padding: EdgeInsets.fromLTRB(width < 900 ? 16 : 24, 0, width < 900 ? 16 : 24, 32),
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, boxConstraints) {
                final availableWidth = boxConstraints.maxWidth;
                const minTileWidth = 280.0;
                const maxTileWidth = 360.0;
                const spacing = 20.0;

                int columnCount = math.max(1, (availableWidth / (minTileWidth + spacing)).floor());
                columnCount = math.min(columnCount, 4);
                double tileWidth = (availableWidth - spacing * (columnCount - 1)) / columnCount;
                tileWidth = tileWidth.clamp(minTileWidth, maxTileWidth).toDouble();

                final effectiveColumns = math.min(columnCount, _filteredMembers.length);
                final wrapWidth = effectiveColumns <= 1
                    ? tileWidth
                    : math.min(
                        availableWidth,
                        effectiveColumns * tileWidth + spacing * (effectiveColumns - 1),
                      );

                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: wrapWidth,
                    child: Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      alignment: WrapAlignment.start,
                      children: [
                        for (int i = 0; i < _filteredMembers.length; i++)
                          SizedBox(
                            width: tileWidth,
                            child: _buildMemberCard(
                              _filteredMembers[i],
                              i,
                              isMobile: false,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildChaptersSliver(ThemeData theme) {
    if (_filteredChapters.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Align(
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 96),
                _buildEmptyChaptersState(theme),
              ],
            ),
          ),
        ),
      );
    }

    final itemCount = _filteredChapters.length * 2 - 1;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index.isOdd) {
              return const SizedBox(height: 16);
            }
            final itemIndex = index ~/ 2;
            return _buildChapterCard(_filteredChapters[itemIndex]);
          },
          childCount: itemCount > 0 ? itemCount : 0,
        ),
      ),
    );
  }

  Widget _buildChapterCard(Chapter chapter) {
    final theme = Theme.of(context);
    final chapterName = _cleanValue(chapter.chapterName) ?? 'Unnamed Chapter';
    final schoolName = _cleanValue(chapter.schoolName);
    final contactEmail = _cleanValue(chapter.contactEmail);
    final website = _cleanValue(chapter.website);
    final memberCount = _memberCountForChapter(chapter.chapterName);
    final leaderCount = _leaderCountForChapter(chapter.chapterName);

    final chips = <Widget>[
      if (_cleanValue(chapter.chapterType) != null)
        _buildMetaTag(Icons.category, chapter.chapterType.toUpperCase()),
      if (_cleanValue(chapter.status) != null)
        _buildMetaTag(Icons.flag, _cleanValue(chapter.status)!),
      _buildMetaTag(
        chapter.isChartered ? Icons.verified : Icons.pending,
        chapter.isChartered ? 'Chartered' : 'Not Chartered',
      ),
      if (chapter.charterDate != null)
        _buildMetaTag(Icons.calendar_month, 'Chartered ${_formatDate(chapter.charterDate!)}'),
    ];

    final borderRadius = BorderRadius.circular(20);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openChapter(chapter),
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chapterName,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (schoolName != null) ...[
                const SizedBox(height: 4),
                Text(schoolName, style: theme.textTheme.titleMedium),
              ],
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: chips,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatTile(Icons.people_alt, '$memberCount members'),
                  const SizedBox(width: 12),
                  if (leaderCount > 0)
                    _buildStatTile(Icons.emoji_events, '$leaderCount leaders'),
                ],
              ),
              if (contactEmail != null)
                _buildChapterInfoRow(theme, Icons.email_outlined, contactEmail),
              if (website != null) _buildChapterInfoRow(theme, Icons.link, website),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile(IconData icon, String label) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterInfoRow(ThemeData theme, IconData icon, String value) {
    final uri = _parseChapterUri(value);
    final displayValue = uri != null && _isWebUrl(uri) ? _formatWebsiteLabel(uri) : value;
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      decoration: uri != null ? TextDecoration.underline : null,
      color: uri != null ? theme.colorScheme.primary : null,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: uri != null ? () => launchUrl(uri, mode: LaunchMode.externalApplication) : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                displayValue,
                style: textStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaTag(IconData icon, String label) {
    final theme = Theme.of(context);
    return Chip(
      avatar: Icon(icon, size: 16, color: theme.colorScheme.primary),
      label: Text(label),
      backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
      labelStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  void _openChapter(Chapter chapter) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChapterDetailScreen(chapter: chapter)),
    );
  }

  String _formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';

  Uri? _parseChapterUri(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains('@') && !trimmed.contains(' ')) {
      return Uri(scheme: 'mailto', path: trimmed);
    }
    final normalized = trimmed.startsWith('http') ? trimmed : 'https://$trimmed';
    return Uri.tryParse(normalized);
  }

  bool _isWebUrl(Uri uri) => uri.scheme == 'http' || uri.scheme == 'https';

  String _formatWebsiteLabel(Uri uri) {
    final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
    final path = uri.path == '/' ? '' : uri.path;
    final query = uri.hasQuery ? '?${uri.query}' : '';
    final fragment = uri.hasFragment ? '#${uri.fragment}' : '';
    return '$host$path$query$fragment';
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    VoidCallback? onTap,
    IconData? icon,
  }) {
    return FilterChip(
      avatar: icon != null ? Icon(icon, size: 18) : null,
      label: Text(label),
      selected: selected,
      onSelected: onTap == null ? null : (_) => onTap(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildEmptyMembersState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 76, color: theme.colorScheme.primary.withOpacity(0.25)),
            const SizedBox(height: 16),
            Text(
              'No members match your filters',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or refreshing to see everyone in your database.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChaptersState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_tree_outlined, size: 76, color: theme.colorScheme.primary.withOpacity(0.25)),
            const SizedBox(height: 16),
            Text(
              'No chapters found',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or refresh to pull the latest chapter roster.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(Member member, int index, {required bool isMobile}) {
    final theme = Theme.of(context);
    const gradient = _memberCardGradient;
    final phoneDisplay = _formatMemberPhone(member);
    final emailDisplay = _cleanValue(member.preferredEmail);
    final county = _cleanValue(member.county);
    final districtLabel = _formatDistrict(member.congressionalDistrict);
    final age = member.age;
    final zodiac = _cleanValue(member.zodiacSign);
    final joinedDate = member.dateJoined;

    final metaChips = <Widget>[];
    if (districtLabel != null) {
      metaChips.add(
        _buildInfoChip(
          Icons.account_balance,
          districtLabel,
          backgroundColor: Colors.white.withOpacity(0.18),
        ),
      );
    }
    if (age != null) {
      metaChips.add(
        _buildInfoChip(
          Icons.cake_outlined,
          '$age yrs',
          backgroundColor: Colors.white.withOpacity(0.18),
        ),
      );
    }
    if (zodiac != null) {
      metaChips.add(
        _buildInfoChip(
          Icons.auto_awesome,
          zodiac,
          backgroundColor: Colors.white.withOpacity(0.18),
        ),
      );
    }
    if (_hasText(member.graduationYear)) {
      metaChips.add(
        _buildInfoChip(
          Icons.school,
          'Grad ${member.graduationYear!.trim()}',
          backgroundColor: Colors.white.withOpacity(0.18),
        ),
      );
    }

    final borderRadius = BorderRadius.circular(isMobile ? 16 : 24);
    const textColor = Colors.white;
    final detailIconColor = Colors.white.withOpacity(0.92);
    final detailTextStyle = (isMobile ? theme.textTheme.bodyMedium : theme.textTheme.bodyLarge)
            ?.copyWith(color: textColor, fontWeight: FontWeight.w600, height: 1.3) ??
        TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: isMobile ? 13.5 : 14.5);

    final detailLines = <Widget>[];
    if (county != null) {
      detailLines.add(
        _buildDetailLine(
          Icons.map_outlined,
          county,
          iconColor: detailIconColor,
          textStyle: detailTextStyle,
        ),
      );
    }
    if (phoneDisplay != null) {
      detailLines.add(
        _buildDetailLine(
          Icons.phone,
          phoneDisplay,
          iconColor: detailIconColor,
          textStyle: detailTextStyle,
        ),
      );
    }
    if (emailDisplay != null) {
      detailLines.add(
        _buildDetailLine(
          Icons.email_outlined,
          emailDisplay,
          iconColor: detailIconColor,
          textStyle: detailTextStyle,
        ),
      );
    }
    if (joinedDate != null) {
      detailLines.add(
        _buildDetailLine(
          Icons.calendar_month,
          'Joined ${_formatDate(joinedDate)}',
          iconColor: detailIconColor,
          textStyle: detailTextStyle,
        ),
      );
    }

    final columnChildren = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileAvatar(member, isMobile: isMobile),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        member.name,
                        style: (isMobile ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)
                                ?.copyWith(fontWeight: FontWeight.w700, color: textColor) ??
                            TextStyle(fontWeight: FontWeight.w700, color: textColor, fontSize: isMobile ? 18 : 22),
                      ),
                    ),
                    if (member.optOut)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: isMobile ? 4 : 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.28),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Opted Out',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ];

    if (metaChips.isNotEmpty) {
      columnChildren.addAll([
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: metaChips,
        ),
      ]);
    }

    if (detailLines.isNotEmpty) {
      columnChildren.add(const SizedBox(height: 14));
      columnChildren.addAll(detailLines);
    }

    final gradientBackground = const LinearGradient(
      colors: _memberCardGradient,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: gradientBackground,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: gradient.last.withOpacity(0.28),
            blurRadius: isMobile ? 16 : 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: () => _openMember(member),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24,
              vertical: isMobile ? 16 : 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: columnChildren,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(Member member, {required bool isMobile}) {
    final double size = isMobile ? 56 : 72;
    final String? photoUrl = member.primaryProfilePhotoUrl;
    final borderColor = Colors.white.withOpacity(0.35);

    Widget buildFallback() {
      final trimmed = member.name.trim();
      final String initial = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF1B262C), Color(0xFF3282B8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            initial,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.45,
            ),
          ),
        ),
      );
    }

    Widget content;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      content = ClipOval(
        child: Image.network(
          photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => buildFallback(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: size * 0.4,
                height: size * 0.4,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              ),
            );
          },
        ),
      );
    } else {
      content = buildFallback();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: content,
    );
  }

  Widget _buildInfoChip(IconData icon, String label,
      {Color? backgroundColor, Color? iconColor, Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor ?? Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: textColor ?? Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailLine(IconData icon, String value,
      {Color? iconColor, TextStyle? textStyle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor ?? Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: textStyle ??
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _openMember(Member member) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemberDetailScreen(member: member),
      ),
    );
  }

  void _showSingleChoiceDialog({
    required String title,
    required List<String> options,
    required String? currentValue,
    required ValueChanged<String?> onSelected,
    String Function(String value)? labelBuilder,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('All'),
                leading: Radio<String?>(
                  value: null,
                  groupValue: currentValue,
                  onChanged: (value) {
                    Navigator.pop(context);
                    onSelected(value);
                  },
                ),
              ),
              ...options.map(
                (option) => ListTile(
                  title: Text(labelBuilder?.call(option) ?? option),
                  leading: Radio<String?>(
                    value: option,
                    groupValue: currentValue,
                    onChanged: (value) {
                      Navigator.pop(context);
                      onSelected(value);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCountyFilter() {
    _showSingleChoiceDialog(
      title: 'Filter by County',
      options: _counties,
      currentValue: _selectedCounty,
      onSelected: (value) => _updateFilters(() => _selectedCounty = value),
    );
  }

  void _showDistrictFilter() {
    _showSingleChoiceDialog(
      title: 'Filter by Congressional District',
      options: _districts,
      currentValue: _selectedDistrict,
      labelBuilder: (value) => 'District ${_formatDistrict(value) ?? value}',
      onSelected: (value) => _updateFilters(() => _selectedDistrict = value),
    );
  }

  void _showChapterFilter() {
    _showSingleChoiceDialog(
      title: 'Filter by Chapter',
      options: _chapterNames,
      currentValue: _selectedChapter,
      onSelected: (value) => _updateFilters(() => _selectedChapter = value),
    );
  }

  void _showChapterStatusFilter() {
    _showSingleChoiceDialog(
      title: 'Filter by Chapter Status',
      options: _chapterStatuses,
      currentValue: _selectedChapterStatus,
      onSelected: (value) => _updateFilters(() => _selectedChapterStatus = value),
    );
  }

  void _showCommunityFilter() {
    _showSingleChoiceDialog(
      title: 'Filter by Community Type',
      options: _communityTypes,
      currentValue: _selectedCommunityType,
      onSelected: (value) => _updateFilters(() => _selectedCommunityType = value),
    );
  }

  void _showChapterPositionFilter() {
    _showSingleChoiceDialog(
      title: 'Filter by Chapter Position',
      options: _chapterPositions,
      currentValue: _selectedChapterPosition,
      onSelected: (value) => _updateFilters(() => _selectedChapterPosition = value),
    );
  }

  void _showRegisteredFilter() {
    _showSingleChoiceDialog(
      title: 'Filter by Registered Voter Status',
      options: const ['registered', 'not_registered'],
      currentValue: _registeredVoterFilter,
      labelBuilder: (value) => value == 'registered' ? 'Registered' : 'Not Registered',
      onSelected: (value) => _updateFilters(() => _registeredVoterFilter = value),
    );
  }

  void _showContactFilter() {
    _showSingleChoiceDialog(
      title: 'Filter by Contact Status',
      options: const ['contactable', 'opted_out'],
      currentValue: _contactFilter,
      labelBuilder: (value) => value == 'contactable' ? 'Contactable' : 'Opted Out',
      onSelected: (value) => _updateFilters(() => _contactFilter = value),
    );
  }

  void _showCommitteeFilter() {
    final tempSelected = List<String>.from(_selectedCommittees ?? []);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Committee'),
        content: SizedBox(
          width: double.maxFinite,
          child: StatefulBuilder(
            builder: (context, setDialogState) => ListView(
              shrinkWrap: true,
              children: _committees.map((committee) {
                final isSelected = tempSelected.contains(committee);
                return CheckboxListTile(
                  title: Text(committee),
                  value: isSelected,
                  onChanged: (checked) {
                    setDialogState(() {
                      if (checked == true) {
                        tempSelected.add(committee);
                      } else {
                        tempSelected.remove(committee);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateFilters(
                () => _selectedCommittees = tempSelected.isEmpty ? null : tempSelected,
              );
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showAgeFilter() {
    if (_availableMinAge == null || _availableMaxAge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No age data available to filter.')),
      );
      return;
    }

    final min = _availableMinAge!;
    final max = _availableMaxAge!;
    RangeValues values = RangeValues(
      (_minAgeFilter ?? min).toDouble(),
      (_maxAgeFilter ?? max).toDouble(),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter by Age Range'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${values.start.round()} - ${values.end.round()} years'),
              RangeSlider(
                values: values,
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: max > min ? max - min : null,
                labels: RangeLabels(
                  values.start.round().toString(),
                  values.end.round().toString(),
                ),
                onChanged: (newValues) {
                  setDialogState(() => values = newValues);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _updateFilters(() {
                  _minAgeFilter = null;
                  _maxAgeFilter = null;
                });
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _updateFilters(() {
                  _minAgeFilter = values.start.round();
                  _maxAgeFilter = values.end.round();
                });
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}
