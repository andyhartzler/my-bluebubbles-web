import 'dart:math' as math;
import 'package:bluebubbles/helpers/mobile_selection_area.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import 'package:bluebubbles/models/crm/chapter.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/message_filter.dart';
import 'package:bluebubbles/services/crm/chapter_repository.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

import 'bulk_email_screen.dart';
import 'bulk_message_screen.dart';
import 'chapter_detail_screen.dart';
import 'member_detail_screen.dart';

/// Screen showing all CRM members with search and filters
class MembersListScreen extends StatefulWidget {
  final bool embed;
  final bool showChaptersOnly;
  final MemberRepository? memberRepository;
  final ChapterRepository? chapterRepository;
  final int pageSize;

  /// Opens the list already filtered to one county. Set by the Your Counties
  /// tile so the tap lands on the callable list rather than on all 419 members
  /// with a filter the exec then has to find. It seeds `_selectedCounty`, so
  /// the chip renders active and Clear removes it like any other filter.
  final String? initialCounty;

  const MembersListScreen({
    Key? key,
    this.embed = false,
    this.showChaptersOnly = false,
    this.memberRepository,
    this.chapterRepository,
    this.pageSize = 50,
    this.initialCounty,
  }) : super(key: key);

  @visibleForTesting
  static int Function(Member, Member) compareMembersForTesting({
    required bool prioritizeExecutives,
  }) =>
      (a, b) => _MembersListScreenState._compareMembers(
            a,
            b,
            prioritizeExecutives: prioritizeExecutives,
          );

  @override
  State<MembersListScreen> createState() => _MembersListScreenState();
}

class _ExecutiveRoleCandidate {
  final String raw;
  final String normalized;
  final String? displayLabel;

  const _ExecutiveRoleCandidate({
    required this.raw,
    required this.normalized,
    this.displayLabel,
  });
}

class _ExecutiveRoleResolution {
  final String normalized;
  final String? displayLabel;

  const _ExecutiveRoleResolution({required this.normalized, this.displayLabel});
}

class _MembersListScreenState extends State<MembersListScreen> {
  late final MemberRepository _memberRepo;
  late final ChapterRepository _chapterRepository;
  final CRMSupabaseService _supabaseService = CRMSupabaseService();

  List<Member> _members = [];
  List<Member> _filteredMembers = [];
  List<Member> _agedOutMembers = [];
  List<Chapter> _chapters = [];
  List<Chapter> _filteredChapters = [];
  Map<String, Chapter> _chaptersByKey = {};

  bool _loading = true;
  bool _crmReady = false;
  String _searchQuery = '';
  late int _activeView;
  bool _filtersExpandedOnMobile = false;
  bool _showAgedOutMembers = false;

  late final ScrollController _scrollController;
  late final TextEditingController _searchController;
  late final int _pageSize;
  bool _isLoadingPage = false;
  bool _hasMoreMembers = true;
  int? _totalAvailableMembers;
  int _memberFetchRequestId = 0;
  bool _suppressSearchListener = false;
  bool _inlineSearchLoading = false;

  Future<List<String>>? _countiesFuture;
  Future<List<String>>? _districtsFuture;
  Future<List<String>>? _committeesFuture;
  Future<Map<String, int>>? _chapterCountsFuture;
  Future<Map<String, int>>? _leadershipCountsFuture;
  Future<List<Chapter>>? _chaptersFuture;
  Future<AgeBounds>? _ageBoundsFuture;

  // Filter state
  String? _selectedCounty;
  String? _selectedDistrict;
  List<String>? _selectedCommittees;
  String? _selectedChapter;
  List<String>? _selectedLeadershipChapters;
  String? _registeredVoterFilter;
  String? _contactFilter;
  int? _minAgeFilter;
  int? _maxAgeFilter;

  // Available filter options
  List<String> _counties = [];
  List<String> _districts = [];
  List<String> _committees = [];
  List<String> _chapterNames = [];
  List<String> _leadershipChapterOptions = [];

  Map<String, int> _memberCountByChapter = {};
  Map<String, int> _leaderCountByChapter = {};
  int? _availableMinAge;
  int? _availableMaxAge;

  bool get _hasActiveFilters {
    if (_searchQuery.trim().isNotEmpty) return true;
    if ((_selectedCounty ?? '').isNotEmpty) return true;
    if ((_selectedDistrict ?? '').isNotEmpty) return true;
    if ((_selectedChapter ?? '').isNotEmpty) return true;
    if (_selectedCommittees?.isNotEmpty ?? false) return true;
    if (_selectedLeadershipChapters?.isNotEmpty ?? false) return true;
    if (_registeredVoterFilter != null) return true;
    if (_contactFilter != null) return true;
    if (_minAgeFilter != null) return true;
    if (_maxAgeFilter != null) return true;
    return false;
  }

  bool get _shouldUsePaging => !_hasActiveFilters;

  static const List<Color> _memberCardGradient = BrandColors.tileGradient;

  /// Ineligible cards run red instead of blue. The light end is Material red
  /// 700 rather than the red 600 (#E53935) it used to be: white on #E53935
  /// measures 4.23:1 and fails the 4.5:1 normal-text floor. White on #D32F2F
  /// is 4.98:1, on the midpoint (#C52626) 5.71:1, on #B71C1C 6.57:1. All
  /// three computed from WCAG relative luminance.
  static const List<Color> _ineligibleMemberCardGradient = [Color(0xFFB71C1C), Color(0xFFD32F2F)];

  /// Text on the light end of the branded card gradient. White is the ONLY
  /// readable ink on these cards: white on tileGradientEnd (#1C7DAB) is
  /// 4.59:1, on the midpoint 7.59:1, on unityBlue 12.51:1. White at 0.90
  /// alpha on the light end is 4.04:1 and fails, at 0.70 it is 3.08:1, so
  /// hierarchy on a card is size, weight and letter spacing, never alpha.
  static const Color _ink = Colors.white;

  /// Decorative rules and chip borders. Alpha is allowed here because a rule
  /// carries no text. White at 0.35 over unityBlue composites to #737A8E and
  /// at 0.15 over tileGradientEnd to #3E90B8; neither is read as text.
  static final Color _rule = Colors.white.withValues(alpha: 0.35);
  static final Color _rowDivider = Colors.white.withValues(alpha: 0.15);

  /// Solid hint ink for the white search band. channels_tab uses unityBlue
  /// at 0.5 alpha, which composites to #9399A8 and is only 2.85:1 on white.
  /// This is unityBlue at 0.75 composited over white, #5D667C, 5.74:1.
  static const Color _searchHintInk = Color(0xFF5D667C);

  static const int _minAllowedAge = 14;
  static const int _maxAllowedAge = 36;

  @override
  void initState() {
    super.initState();
    _memberRepo = widget.memberRepository ?? MemberRepository();
    _chapterRepository = widget.chapterRepository ?? ChapterRepository();
    _pageSize = widget.pageSize;
    _scrollController = ScrollController()..addListener(_handleScroll);
    _searchController = TextEditingController(text: _searchQuery)
      ..addListener(_handleSearchTextChanged);
    _crmReady = _supabaseService.isInitialized && CRMConfig.crmEnabled;
    _activeView = widget.showChaptersOnly ? 1 : 0;
    final seedCounty = widget.initialCounty?.trim();
    if (seedCounty != null && seedCounty.isNotEmpty) {
      _selectedCounty = seedCounty;
    }
    _loadData(refreshMetadata: true, includeMetadata: true);
  }

  @override
  void didUpdateWidget(covariant MembersListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showChaptersOnly != widget.showChaptersOnly) {
      _activeView = widget.showChaptersOnly ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _searchController.removeListener(_handleSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  bool get _showingChapters => widget.showChaptersOnly || _activeView == 1;

  MessageFilter _buildCurrentMessageFilter() {
    return MessageFilter(
      county: _selectedCounty,
      congressionalDistrict: _selectedDistrict,
      committees: _selectedCommittees,
      chapterName: _selectedChapter,
      minAge: _minAgeFilter,
      maxAge: _maxAgeFilter,
      excludeOptedOut: _contactFilter == 'opted_out' ? false : true,
    );
  }

  Future<void> _loadData({
    bool refreshMetadata = false,
    bool includeMetadata = true,
  }) async {
    if (!_crmReady) {
      setState(() {
        _loading = false;
        _members = [];
        _filteredMembers = [];
        _agedOutMembers = [];
        _inlineSearchLoading = false;
      });
      return;
    }

    if (refreshMetadata) {
      _invalidateMetadataCaches();
    }

    setState(() {
      _loading = true;
      _hasMoreMembers = true;
      _totalAvailableMembers = null;
      _members = [];
      _filteredMembers = [];
      _agedOutMembers = [];
      _inlineSearchLoading = false;
    });

    Future<void>? metadataFuture;
    if (includeMetadata) {
      metadataFuture = _loadMetadata(refresh: refreshMetadata);
    }

    await _fetchMembersPage(reset: true, requestTotalCount: true);

    if (metadataFuture != null) {
      await metadataFuture;
    }

    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }

  void _invalidateMetadataCaches() {
    _countiesFuture = null;
    _districtsFuture = null;
    _committeesFuture = null;
    _chapterCountsFuture = null;
    _leadershipCountsFuture = null;
    _chaptersFuture = null;
    _ageBoundsFuture = null;
  }

  Future<List<String>> _fetchCounties({bool refresh = false}) {
    if (refresh || _countiesFuture == null) {
      _countiesFuture = _memberRepo.getUniqueCounties();
    }
    return _countiesFuture!;
  }

  Future<List<String>> _fetchDistricts({bool refresh = false}) {
    if (refresh || _districtsFuture == null) {
      _districtsFuture = _memberRepo.getUniqueCongressionalDistricts();
    }
    return _districtsFuture!;
  }

  Future<List<String>> _fetchCommittees({bool refresh = false}) {
    if (refresh || _committeesFuture == null) {
      _committeesFuture = _memberRepo.getUniqueCommittees();
    }
    return _committeesFuture!;
  }

  Future<Map<String, int>> _fetchChapterCounts({bool refresh = false}) {
    if (refresh || _chapterCountsFuture == null) {
      _chapterCountsFuture = _memberRepo.getChapterCounts();
    }
    return _chapterCountsFuture!;
  }

  Future<Map<String, int>> _fetchLeadershipCounts({bool refresh = false}) {
    if (refresh || _leadershipCountsFuture == null) {
      _leadershipCountsFuture = _memberRepo.getLeadershipCountsByChapter();
    }
    return _leadershipCountsFuture!;
  }

  Future<List<Chapter>> _fetchChapters({bool refresh = false}) {
    if (refresh || _chaptersFuture == null) {
      _chaptersFuture = _chapterRepository.getAllChapters();
    }
    return _chaptersFuture!;
  }

  Future<AgeBounds> _fetchAgeBounds({bool refresh = false}) {
    if (refresh || _ageBoundsFuture == null) {
      _ageBoundsFuture = _memberRepo.getAgeBounds();
    }
    return _ageBoundsFuture!;
  }

  Future<void> _loadMetadata({bool refresh = false}) async {
    if (!_crmReady) return;

    try {
      final results = await Future.wait<dynamic>([
        _fetchCounties(refresh: refresh),
        _fetchDistricts(refresh: refresh),
        _fetchCommittees(refresh: refresh),
        _fetchChapterCounts(refresh: refresh),
        _fetchLeadershipCounts(refresh: refresh),
        _fetchChapters(refresh: refresh),
        _fetchAgeBounds(refresh: refresh),
      ]);

      if (!mounted) return;

      final counties = List<String>.from(results[0] as List<String>);
      final districts = List<String>.from(results[1] as List<String>);
      final committees = List<String>.from(results[2] as List<String>);
      final rawChapterCounts = Map<String, int>.from(results[3] as Map);
      final rawLeadershipCounts = Map<String, int>.from(results[4] as Map);
      final chapters = results[5] as List<Chapter>;
      final ageBounds = results[6] as AgeBounds;

      final normalizedChapterCounts = <String, int>{};
      final normalizedLeadershipCounts = <String, int>{};
      final chapterNameMap = <String, String>{};

      rawChapterCounts.forEach((key, value) {
        final cleaned = _cleanValue(key);
        if (cleaned == null) return;
        final normalized = _normalizeKey(cleaned);
        if (normalized == null) return;
        normalizedChapterCounts[normalized] = value;
        chapterNameMap[normalized] = cleaned;
      });

      rawLeadershipCounts.forEach((key, value) {
        final cleaned = _cleanValue(key);
        if (cleaned == null) return;
        final normalized = _normalizeKey(cleaned);
        if (normalized == null) return;
        normalizedLeadershipCounts[normalized] = value;
        chapterNameMap.putIfAbsent(normalized, () => cleaned);
      });

      for (final chapter in chapters) {
        final cleaned = _cleanValue(chapter.chapterName);
        if (cleaned == null) continue;
        final normalized = _normalizeKey(cleaned);
        if (normalized == null) continue;
        chapterNameMap[normalized] = cleaned;
      }

      final chapterNames = chapterNameMap.values.toSet().toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      final leadershipChapterOptions = normalizedLeadershipCounts.keys
          .map((key) => chapterNameMap[key])
          .whereType<String>()
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      setState(() {
        _counties = counties;
        _districts = districts;
        _committees = committees;
        _chapters = chapters;
        _chaptersByKey = _buildChapterLookup(chapters);
        _chapterNames = chapterNames;
        _leadershipChapterOptions = leadershipChapterOptions;
        _memberCountByChapter = normalizedChapterCounts;
        _leaderCountByChapter = normalizedLeadershipCounts;
        if (ageBounds.min != null) {
          final clampedMin = ageBounds.min!.clamp(_minAllowedAge, _maxAllowedAge).toInt();
          _availableMinAge = clampedMin;
          if (_minAgeFilter != null && _minAgeFilter! < clampedMin) {
            _minAgeFilter = clampedMin;
          }
        }
        if (ageBounds.max != null) {
          final clampedMax = ageBounds.max!.clamp(_minAllowedAge, _maxAllowedAge).toInt();
          _availableMaxAge = clampedMax;
          if (_maxAgeFilter != null && _maxAgeFilter! > clampedMax) {
            _maxAgeFilter = clampedMax;
          }
        }
        _filteredChapters = _computeFilteredChapters();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading CRM metadata: $e')),
      );
    }
  }

  Future<void> _fetchMembersPage({
    bool reset = false,
    bool requestTotalCount = false,
    bool clearExistingResults = true,
  }) async {
    if (!_crmReady) return;
    if (_isLoadingPage && !reset) return;

    final shouldUsePaging = _shouldUsePaging;
    final currentOffset = !shouldUsePaging || reset ? 0 : _members.length;

    final requestId = ++_memberFetchRequestId;

    setState(() {
      _isLoadingPage = true;
      if (reset || !shouldUsePaging) {
        _hasMoreMembers = true;
        if (requestTotalCount || !shouldUsePaging) {
          _totalAvailableMembers = null;
        }
        if (clearExistingResults) {
          _members = [];
          _filteredMembers = [];
          _agedOutMembers = [];
        }
      }
    });

    try {
      final result = await _memberRepo.getAllMembers(
        county: _selectedCounty,
        congressionalDistrict: _selectedDistrict,
        committees: _selectedCommittees,
        chapterName: _selectedChapter,
        minAge: _minAgeFilter,
        maxAge: _maxAgeFilter,
        optedOut: _resolveOptedOutFilter(),
        registeredVoter: _resolveRegisteredFilter(),
        searchQuery: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
        limit: shouldUsePaging ? _pageSize : null,
        offset: shouldUsePaging ? currentOffset : null,
        fetchTotalCount: requestTotalCount || !shouldUsePaging,
        fetchAll: !shouldUsePaging,
        columns: MemberRepository.listingColumns,
      );

      if (!mounted || requestId != _memberFetchRequestId) {
        return;
      }

      setState(() {
        if (!shouldUsePaging || reset) {
          _members = List<Member>.from(result.members);
        } else {
          _members.addAll(result.members);
        }

        if (!shouldUsePaging) {
          _totalAvailableMembers = result.totalCount ?? _members.length;
          _hasMoreMembers = false;
        } else {
          if (result.totalCount != null) {
            _totalAvailableMembers = result.totalCount;
            _hasMoreMembers = currentOffset + result.members.length < result.totalCount!;
          } else {
            if (reset || _totalAvailableMembers == null) {
              _totalAvailableMembers = _members.length;
            }
            _hasMoreMembers = result.members.length == _pageSize;
          }
        }

        _rebuildFilters();
      });
    } catch (e) {
      if (!mounted || requestId != _memberFetchRequestId) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading members: $e')),
      );
    } finally {
      if (!mounted || requestId != _memberFetchRequestId) {
        return;
      }
      setState(() {
        _isLoadingPage = false;
      });
    }
  }

  void _rebuildFilters() {
    final filtered = _computeFilteredMembers();
    _filteredMembers = filtered;
    if (_agedOutMembers.isEmpty) {
      _showAgedOutMembers = false;
    }
    _filteredChapters = _computeFilteredChapters();

    if ((_availableMinAge == null || _availableMaxAge == null) && _members.isNotEmpty) {
      _deriveAgeBounds(_members);
    }
  }

  bool? _resolveOptedOutFilter() {
    if (_contactFilter == 'contactable') return false;
    if (_contactFilter == 'opted_out') return true;
    return null;
  }

  bool? _resolveRegisteredFilter() {
    if (_registeredVoterFilter == 'registered') return true;
    if (_registeredVoterFilter == 'not_registered') return false;
    return null;
  }

  Future<void> _refreshAll() => _loadData(refreshMetadata: true, includeMetadata: true);

  Future<void> _reloadMembersOnly() async {
    if (!_crmReady) return;

    final useInlineLoading = !_loading;
    if (useInlineLoading) {
      setState(() {
        _inlineSearchLoading = true;
      });
    }

    try {
      await _fetchMembersPage(
        reset: true,
        requestTotalCount: true,
        clearExistingResults: !useInlineLoading,
      );
    } finally {
      if (useInlineLoading && mounted) {
        setState(() {
          _inlineSearchLoading = false;
        });
      }
    }
  }

  void _handleScroll() {
    if (_showingChapters) return;
    if (!_shouldUsePaging) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasPixels || !position.hasContentDimensions) return;
    final threshold = position.maxScrollExtent - 400;
    if (position.pixels >= threshold && !_isLoadingPage && _hasMoreMembers && !_loading) {
      _fetchMembersPage();
    }
  }

  @visibleForTesting
  Future<void> fetchNextPageForTesting() {
    if (!_shouldUsePaging) return Future.value();
    return _fetchMembersPage();
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

    int clampAge(int value) => value.clamp(_minAllowedAge, _maxAllowedAge).toInt();

    final constrainedMin = clampAge(ages.first);
    final constrainedMax = clampAge(ages.last);

    _availableMinAge = constrainedMin;
    _availableMaxAge = constrainedMax;

    if (_minAgeFilter != null && _minAgeFilter! < _minAllowedAge) {
      _minAgeFilter = _minAllowedAge;
    }
    if (_minAgeFilter != null && _minAgeFilter! < constrainedMin) {
      _minAgeFilter = constrainedMin;
    }
    if (_maxAgeFilter != null && _maxAgeFilter! > constrainedMax) {
      _maxAgeFilter = constrainedMax;
    }
  }

  void _updateFilters(void Function() updater) {
    setState(() {
      updater();
      _filteredChapters = _computeFilteredChapters();
    });

    if (_crmReady) {
      _reloadMembersOnly();
    }
  }

  void _handleSearchTextChanged() {
    if (_suppressSearchListener) return;
    final value = _searchController.text;
    if (value == _searchQuery) return;
    _updateFilters(() => _searchQuery = value);
  }

  void _replaceSearchText(String value) {
    if (_searchController.text == value) return;
    _suppressSearchListener = true;
    _searchController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _suppressSearchListener = false;
  }

  List<Member> _computeFilteredMembers() {
    final query = _searchQuery.trim().toLowerCase();
    final leadershipFilterActive =
        _selectedLeadershipChapters != null && _selectedLeadershipChapters!.isNotEmpty;
    final leadershipChapterKeys = leadershipFilterActive
        ? _selectedLeadershipChapters!
            .map(_normalizeKey)
            .whereType<String>()
            .toSet()
        : const <String>{};

    final committeeFilterActive =
        _selectedCommittees != null && _selectedCommittees!.isNotEmpty;

    final primaryMembers = <Member>[];
    final agedOutMembers = <Member>[];

    for (final member in _members) {
      if (query.isNotEmpty && !_matchesMemberQuery(member, query)) {
        continue;
      }

      if (_selectedCounty != null && !_equalsIgnoreCase(member.county, _selectedCounty)) {
        continue;
      }

      if (_selectedDistrict != null &&
          !_equalsIgnoreCase(member.congressionalDistrict, _selectedDistrict)) {
        continue;
      }

      if (_selectedChapter != null && !_equalsIgnoreCase(member.chapterName, _selectedChapter)) {
        continue;
      }

      if (leadershipFilterActive) {
        final hasLeadershipRole = _cleanValue(member.chapterPosition) != null;
        final chapterKey = _normalizeKey(member.chapterName);
        if (!hasLeadershipRole || chapterKey == null || !leadershipChapterKeys.contains(chapterKey)) {
          continue;
        }
      }

      if (_selectedCommittees != null && _selectedCommittees!.isNotEmpty) {
        if (member.committee == null) continue;
        final normalizedCommittees = member.committee!
            .map(_normalizeKey)
            .whereType<String>()
            .toSet();
        bool missingCommittee = false;
        for (final committee in _selectedCommittees!) {
          final normalized = _normalizeKey(committee);
          if (normalized == null || !normalizedCommittees.contains(normalized)) {
            missingCommittee = true;
            break;
          }
        }
        if (missingCommittee) continue;
      }

      if (_registeredVoterFilter != null) {
        final isRegistered = member.registeredVoter == true;
        if (_registeredVoterFilter == 'registered' && !isRegistered) continue;
        if (_registeredVoterFilter == 'not_registered' && isRegistered) continue;
      }

      if (_contactFilter != null) {
        if (_contactFilter == 'contactable' && member.optOut) continue;
        if (_contactFilter == 'opted_out' && !member.optOut) continue;
      }

      final age = member.age;
      if (_minAgeFilter != null || _maxAgeFilter != null) {
        if (age == null) continue;
        if (_minAgeFilter != null && age < _minAgeFilter!) continue;
        if (_maxAgeFilter != null && age > _maxAgeFilter!) continue;
      }

      // Use membership_eligible field to determine eligibility
      // false = ineligible (aged out), true or null = eligible
      if (member.membershipEligible == false) {
        agedOutMembers.add(member);
      } else {
        primaryMembers.add(member);
      }
    }

    final comparator = (Member a, Member b) => _compareMembers(
          a,
          b,
          prioritizeExecutives: committeeFilterActive,
        );

    primaryMembers.sort(comparator);
    agedOutMembers.sort(comparator);
    _agedOutMembers = agedOutMembers;

    return primaryMembers;
  }

  static const List<String> _executiveRoleOrder = [
    'president',
    'vice president',
    'secretary',
    'treasurer',
    'chief of staff',
    'young democrats of america representative',
    'young democrats of america representative',
    'district 1 representative',
    'district 2 representative',
    'district 3 representative',
    'district 4 representative',
    'district 5 representative',
    'district 6 representative',
    'district 7 representative',
    'district 8 representative',
    'college democrats chair',
    'college democrats co chair',
    'high school democrats chair',
    'high school democrats co chair',
    'communications chair',
    'communications co chair',
    'fundraising chair',
    'fundraising co chair',
    'membership and outreach chair',
    'membership and outreach co chair',
    'policy and advocacy chair',
    'policy and advocacy co chair',
    'political affairs chair',
    'political affairs co chair',
  ];

  static String _normalizeExecutiveRole(String? role) {
    if (role == null) return '';

    final trimmedRole = role.trim();
    if (trimmedRole.isEmpty) return '';

    final ordinals = <String, String>{
      'first': '1st',
      'second': '2nd',
      'third': '3rd',
      'fourth': '4th',
      'fifth': '5th',
      'sixth': '6th',
      'seventh': '7th',
      'eighth': '8th',
    };

    String _sanitize(String input) {
      var working = input.toLowerCase();
      ordinals.forEach((word, replacement) {
        working = working.replaceAll(word, replacement);
      });

      working = working
          .replaceAll('cochair', 'co chair')
          .replaceAll('representatives', 'representative')
          .replaceAll('chairs', 'chair')
          .replaceAll(RegExp('[-\u2013\u2014/]'), ' ')
          .replaceAll('&', ' and ')
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      return working;
    }

    String _evaluate(String rawInput) {
      final workingSanitized = _sanitize(rawInput);
      if (workingSanitized.isEmpty) return workingSanitized;

      var working = workingSanitized;

      int? districtNumberFromMatch(RegExp pattern) {
        final match = pattern.firstMatch(working);
        if (match == null) return null;
        final value = match.group(1);
        return value == null ? null : int.tryParse(value);
      }

      final districtPatterns = [
        RegExp(r'(\d+)(?:st|nd|rd|th)? (?:congressional )?district'),
        RegExp(r'district (\d+)(?:st|nd|rd|th)?'),
        RegExp(r'(?:representative|rep) (\d+)(?:st|nd|rd|th)?'),
      ];

      for (final pattern in districtPatterns) {
        final districtNumber = districtNumberFromMatch(pattern);
        if (districtNumber != null) {
          return 'district $districtNumber representative';
        }
      }

      final containsYoungDemocrats =
          working.contains('young democrats of america') || working.contains('yda');

      if (containsYoungDemocrats) {
        return 'young democrats of america representative';
      }

      if (working.contains('vice president')) {
        return 'vice president';
      }

      if (working.contains('president')) {
        return 'president';
      }

      if (working.contains('secretary')) {
        return 'secretary';
      }

      if (working.contains('treasurer')) {
        return 'treasurer';
      }

      if (working.contains('chief of staff')) {
        return 'chief of staff';
      }

      String? committeeRole(String keyword, String canonicalBase) {
        if (!working.contains(keyword) || !working.contains('chair')) {
          return null;
        }
        final isCoChair = working.contains('co chair');
        final suffix = isCoChair ? 'co chair' : 'chair';
        return '$canonicalBase $suffix';
      }

      if (working.contains('college democrats') && working.contains('chair')) {
        return working.contains('co chair')
            ? 'college democrats co chair'
            : 'college democrats chair';
      }

      if (working.contains('high school democrats') && working.contains('chair')) {
        return working.contains('co chair')
            ? 'high school democrats co chair'
            : 'high school democrats chair';
      }

      final committeeMappings = <String, String>{
        'communications': 'communications',
        'fundraising': 'fundraising',
        'membership and outreach': 'membership and outreach',
        'membership outreach': 'membership and outreach',
        'policy and advocacy': 'policy and advocacy',
        'policy advocacy': 'policy and advocacy',
        'political affairs': 'political affairs',
      };

      for (final entry in committeeMappings.entries) {
        final normalized = committeeRole(entry.key, entry.value);
        if (normalized != null) {
          return normalized;
        }
      }

      return working;
    }

    final primary = _evaluate(trimmedRole);
    if (_executiveRoleOrder.contains(primary)) {
      return primary;
    }

    final separators = RegExp(r'\s*[\-/]+\s*');
    final parts = trimmedRole
        .split(separators)
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length > 1) {
      final fillerPhrases = {'executive committee', 'executive board'};
      final combinations = <String>{};

      combinations.add(parts.join(' '));
      combinations.add(parts.reversed.join(' '));

      final filteredParts =
          parts.where((part) => !fillerPhrases.contains(part.toLowerCase())).toList();
      if (filteredParts.isNotEmpty && filteredParts.length < parts.length) {
        combinations.add(filteredParts.join(' '));
        combinations.add(filteredParts.reversed.join(' '));
      }

      for (final combination in combinations) {
        final normalized = _evaluate(combination);
        if (_executiveRoleOrder.contains(normalized)) {
          return normalized;
        }
      }
    }

    return primary;
  }

  static int _compareMembers(
    Member a,
    Member b, {
    bool prioritizeExecutives = true,
  }) {
    if (prioritizeExecutives) {
      final executiveComparison = _compareByExecutivePriority(a, b);
      if (executiveComparison != null) {
        return executiveComparison;
      }
    }

    return _compareByPhotoThenName(a, b);
  }

  static int? _compareByExecutivePriority(Member a, Member b) {
    final aIsExecutive = _isExecutiveMember(a);
    final bIsExecutive = _isExecutiveMember(b);

    if (aIsExecutive != bIsExecutive) {
      return aIsExecutive ? -1 : 1;
    }

    if (aIsExecutive && bIsExecutive) {
      final aResolution = _resolveExecutiveRole(a);
      final bResolution = _resolveExecutiveRole(b);
      final aRoleKey = aResolution.normalized;
      final bRoleKey = bResolution.normalized;

      final defaultRank = _executiveRoleOrder.length;
      final aRankIndex = _executiveRoleOrder.indexOf(aRoleKey);
      final bRankIndex = _executiveRoleOrder.indexOf(bRoleKey);
      final aRank = aRankIndex == -1 ? defaultRank : aRankIndex;
      final bRank = bRankIndex == -1 ? defaultRank : bRankIndex;

      if (aRank != bRank) {
        return aRank.compareTo(bRank);
      }

      final aRoleRaw = aResolution.displayLabel;
      final bRoleRaw = bResolution.displayLabel;
      if (aRoleRaw != null && bRoleRaw != null) {
        final roleCompare = aRoleRaw.toLowerCase().compareTo(bRoleRaw.toLowerCase());
        if (roleCompare != 0) {
          return roleCompare;
        }
      } else if (aRoleRaw != null || bRoleRaw != null) {
        return bRoleRaw == null ? -1 : 1;
      }
    }

    return null;
  }

  static int _compareByPhotoThenName(Member a, Member b) {
    final aHasPhoto = a.hasAvatar;
    final bHasPhoto = b.hasAvatar;
    if (aHasPhoto != bHasPhoto) {
      return aHasPhoto ? -1 : 1;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  static bool _isExecutiveMember(Member member) {
    if (member.executiveCommittee) {
      return true;
    }

    bool hasText(String? value) => value != null && value.trim().isNotEmpty;

    return hasText(member.executiveRoleShort) ||
        hasText(member.executiveRole) ||
        hasText(member.executiveTitle);
  }

  static _ExecutiveRoleResolution _resolveExecutiveRole(Member member) {
    String? _trimmed(String? value) {
      if (value == null) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final shortRole = _trimmed(member.executiveRoleShort);
    final longRole = _trimmed(member.executiveRole);
    final title = _trimmed(member.executiveTitle);

    final seenLabels = <String>{};
    final candidates = <_ExecutiveRoleCandidate>[];

    void addCandidate(String? value, {String? displayLabel}) {
      final trimmed = _trimmed(value);
      if (trimmed == null) return;
      final lower = trimmed.toLowerCase();
      if (!seenLabels.add(lower)) return;
      final normalized = _normalizeExecutiveRole(trimmed);
      candidates.add(
        _ExecutiveRoleCandidate(
          raw: trimmed,
          normalized: normalized,
          displayLabel: displayLabel,
        ),
      );
    }

    addCandidate(title);

    if (title != null && shortRole != null) {
      addCandidate('$title / $shortRole', displayLabel: title);
      addCandidate('$shortRole / $title', displayLabel: title);
    }

    if (title != null && longRole != null) {
      addCandidate('$title / $longRole', displayLabel: title);
      addCandidate('$longRole / $title', displayLabel: title);
    }

    addCandidate(shortRole);

    if (shortRole != null && longRole != null) {
      addCandidate('$shortRole / $longRole');

      if (shortRole.toLowerCase() != longRole.toLowerCase()) {
        addCandidate('$longRole / $shortRole');
      }
    }

    addCandidate(longRole);

    if (candidates.isEmpty) {
      return const _ExecutiveRoleResolution(normalized: '', displayLabel: null);
    }

    for (final candidate in candidates) {
      if (candidate.normalized.isNotEmpty &&
          _executiveRoleOrder.contains(candidate.normalized)) {
        return _ExecutiveRoleResolution(
          normalized: candidate.normalized,
          displayLabel: candidate.displayLabel ?? candidate.raw,
        );
      }
    }

    for (final candidate in candidates) {
      if (candidate.normalized.isNotEmpty) {
        return _ExecutiveRoleResolution(
          normalized: candidate.normalized,
          displayLabel: candidate.displayLabel ?? candidate.raw,
        );
      }
    }

    final fallbackCandidate = candidates.first;
    final fallback = fallbackCandidate.displayLabel ?? fallbackCandidate.raw;
    return _ExecutiveRoleResolution(
      normalized: '',
      displayLabel: fallback.isEmpty ? null : fallback,
    );
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

  Map<String, Chapter> _buildChapterLookup(List<Chapter> chapters) {
    final lookup = <String, Chapter>{};

    for (final chapter in chapters) {
      final candidates = <String?>[
        chapter.chapterName,
        chapter.standardizedName,
        chapter.nameAbbreviation,
        chapter.schoolName,
      ];

      for (final candidate in candidates) {
        final cleaned = _cleanValue(candidate);
        if (cleaned == null) continue;
        final normalized = _normalizeKey(cleaned);
        if (normalized == null) continue;
        lookup.putIfAbsent(normalized, () => chapter);
      }
    }

    return lookup;
  }

  Chapter? _findChapterForMember(Member member) {
    final candidates = <String?>[
      member.chapterName,
      member.schoolName,
    ];

    for (final candidate in candidates) {
      final cleaned = _cleanValue(candidate);
      if (cleaned == null) continue;
      final normalized = _normalizeKey(cleaned);
      if (normalized == null) continue;
      final chapter = _chaptersByKey[normalized];
      if (chapter != null) {
        return chapter;
      }
    }

    return null;
  }

  String? _formatChapterAffiliation(Member member) {
    final chapter = _findChapterForMember(member);
    final abbreviation =
        _cleanValue(chapter?.nameAbbreviation) ?? _cleanValue(member.chapterName);
    if (abbreviation == null) return null;

    final chapterType = _formatChapterTypeLabel(chapter?.chapterType);
    final buffer = StringBuffer(abbreviation);

    if (chapterType != null && chapterType.isNotEmpty) {
      buffer
        ..write(' ')
        ..write(chapterType);

      final typeHasDemocrats = chapterType.toLowerCase().contains('democrat');
      if (!typeHasDemocrats) {
        buffer.write(' Democrats');
      }
    } else if (!abbreviation.toLowerCase().contains('democrat')) {
      buffer.write(' Democrats');
    }

    return buffer.toString().trim();
  }

  String? _formatChapterTypeLabel(String? value) {
    final cleaned = _cleanValue(value);
    if (cleaned == null) return null;

    final lower = cleaned.toLowerCase();
    if (lower == 'n/a' || lower == 'none') {
      return null;
    }

    return _titleCaseWords(cleaned);
  }

  String _titleCaseWords(String value) {
    final words = value.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    if (words.isEmpty) return value;

    return words
        .map((word) {
          if (word.length <= 2 && word == word.toUpperCase()) {
            return word;
          }
          if (word == word.toUpperCase()) {
            return word;
          }
          final lower = word.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
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
    _replaceSearchText('');
    _updateFilters(() {
      _searchQuery = '';
      _selectedCounty = null;
      _selectedDistrict = null;
      _selectedCommittees = null;
      _selectedChapter = null;
      _selectedLeadershipChapters = null;
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
    // BrandedBackground on BOTH paths. The embedded members view used to
    // return the bare body and inherit the host shell's black scaffold, which
    // is the black Andrew asked to lose. Nothing readable sits directly on
    // this background: white on the fallback gradient's light end with the
    // 18% overlay (#57B6E4) is only 2.28:1, so every text run below lives on
    // a gradient card or band.
    final body = BrandedBackground(child: _buildContent(context));

    if (widget.embed) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Members',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: BrandColors.tileGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _crmReady ? () => _refreshAll() : null,
            tooltip: 'Refresh',
          ),
          if (CRMConfig.bulkMessagingEnabled)
            IconButton(
              icon: const Icon(Icons.email_outlined, color: Colors.white),
              onPressed: _crmReady
                  ? () {
                      final filter = _buildCurrentMessageFilter();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BulkEmailScreen(initialFilter: filter),
                        ),
                      );
                    }
                  : null,
              tooltip: 'Bulk Email',
            ),
          if (CRMConfig.bulkMessagingEnabled)
            IconButton(
              icon: const Icon(Icons.message, color: Colors.white),
              onPressed: _crmReady
                  ? () {
                      // Carry the active filters through, exactly as the email
                      // button does. From a county-scoped list, the way the
                      // Your Counties tile opens it, this means "text the
                      // members I'm looking at" texts that county. Without it,
                      // an exec who filtered to Greene lost the scope on tap.
                      final filter = _buildCurrentMessageFilter();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BulkMessageScreen(initialFilter: filter),
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
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (!_crmReady) {
      // A whole-screen notice on the branded background: white text on a
      // gradient card, never on the background itself.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: BrandedCard(
              padding: const EdgeInsets.all(24),
              child: Text(
                'CRM Supabase is not configured. Please verify environment variables.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w500, height: 1.4),
              ),
            ),
          ),
        ),
      );
    }

    final showingChapters = _showingChapters;

    final visibleMembersCount = _filteredMembers.length;
    final fetchedCount = visibleMembersCount + _agedOutMembers.length;
    final knownTotalMembers = _totalAvailableMembers ?? fetchedCount;
    final membersLabel = _totalAvailableMembers != null
        ? 'Showing $visibleMembersCount of $knownTotalMembers members'
        : 'Showing $visibleMembersCount members';
    final countLabel = showingChapters
        ? 'Showing ${_filteredChapters.length} of ${_chapters.length} chapters'
        : membersLabel;

    // The Slack page's header idiom: one white search band, then one gradient
    // band carrying the controls. The count label rides in the gradient band
    // so it is white on tileGradient rather than theme ink on the background.
    final slivers = <Widget>[
      SliverToBoxAdapter(child: _buildSearchBand()),
      SliverToBoxAdapter(child: _buildFilterBand(countLabel)),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];

    if (showingChapters) {
      slivers.add(_buildChaptersSliver());
    } else {
      slivers.addAll(_buildMembersSlivers());
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: MobileAwareSelectionArea(
        child: CustomScrollView(
          controller: _scrollController,
          key: const PageStorageKey<String>('members-scroll-view'),
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: slivers,
        ),
      ),
    );
  }

  /// The one light surface on the page, matching channels_tab.dart's white
  /// search band. Ink is unityBlue on solid white, 12.51:1. The band is
  /// opaque white rather than channels_tab's 0.95 so the ratio does not
  /// depend on what the background image happens to be behind it.
  Widget _buildSearchBand() {
    final hint = _showingChapters
        ? 'Search chapters by name, contact, or status...'
        : 'Search by name, contact, chapter, or committee...';

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width),
        );

    final searchField = TextField(
      controller: _searchController,
      style: const TextStyle(color: BrandColors.unityBlue, fontSize: 15, fontWeight: FontWeight.w500),
      cursorColor: BrandColors.unityBlue,
      decoration: InputDecoration(
        hintText: hint,
        // #5D667C on white is 5.74:1. See _searchHintInk.
        hintStyle: const TextStyle(color: _searchHintInk, fontSize: 15, fontWeight: FontWeight.w400),
        // tileGradientEnd on white is 4.59:1, clearing the 3:1 graphical
        // floor; momentumBlue, which channels_tab uses here, is 2.75:1.
        prefixIcon: const Icon(Icons.search, color: BrandColors.tileGradientEnd),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: BrandColors.unityBlue),
                tooltip: 'Clear search',
                onPressed: () {
                  _replaceSearchText('');
                  _updateFilters(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        // Field strokes are decorative rules; alpha is fine on them.
        border: border(BrandColors.tileGradientEnd.withValues(alpha: 0.35), 1),
        enabledBorder: border(BrandColors.tileGradientEnd.withValues(alpha: 0.35), 1),
        focusedBorder: border(BrandColors.tileGradientEnd, 2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );

    final searchContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        searchField,
        if (_inlineSearchLoading) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 3,
              color: BrandColors.tileGradientEnd,
              backgroundColor: BrandColors.tileGradientEnd.withValues(alpha: 0.15),
            ),
          ),
        ],
      ],
    );

    final Widget row = widget.embed
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: searchContent),
              const SizedBox(width: 8),
              // Stays an IconButton with this tooltip: the embed test finds it
              // by widgetWithIcon and reads onPressed and tooltip off it.
              IconButton(
                icon: const Icon(Icons.refresh),
                color: BrandColors.unityBlue,
                onPressed: _crmReady ? () => _refreshAll() : null,
                tooltip: 'Refresh',
              ),
            ],
          )
        : searchContent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: row,
    );
  }

  /// The gradient control band under the search, in the Slack tab bar's
  /// idiom: tileGradient, white labels, sunriseGold for the active state with
  /// unityBlue ink (7.17:1). The count label sits here too, white 15 w600, so
  /// it is never drawn on the background image.
  Widget _buildFilterBand(String countLabel) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final countText = Text(
      countLabel,
      style: const TextStyle(
        color: _ink,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );

    return Container(
      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 20, 16, isMobile ? 16 : 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: BrandColors.tileGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: BrandColors.unityBlue.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_showingChapters) ...[
            _buildFilterRow(isMobile: isMobile),
            const SizedBox(height: 14),
          ],
          countText,
        ],
      ),
    );
  }

  Widget _buildFilterRow({required bool isMobile}) {
    if (_showingChapters) return const SizedBox.shrink();
    final hasFilters = _selectedCounty != null ||
        _selectedDistrict != null ||
        _selectedChapter != null ||
        (_selectedLeadershipChapters != null && _selectedLeadershipChapters!.isNotEmpty) ||
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
            ? (_formatDistrict(_selectedDistrict) ?? _selectedDistrict!)
            : 'Congressional District',
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
        label: _selectedLeadershipChapters == null || _selectedLeadershipChapters!.isEmpty
            ? 'Chapter Leadership'
            : '${_selectedLeadershipChapters!.length} chapters',
        selected: _selectedLeadershipChapters != null && _selectedLeadershipChapters!.isNotEmpty,
        onTap: _showLeadershipFilter,
        icon: Icons.emoji_events_outlined,
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

    final clearControl = _buildFilterChip(
      label: 'Clear',
      selected: false,
      onTap: _clearFilters,
      icon: Icons.clear_all,
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildFilterChip(
                  label: _filtersExpandedOnMobile
                      ? 'Hide Filters'
                      : 'Show Filters${activeFilterCount > 0 ? ' ($activeFilterCount)' : ''}',
                  selected: false,
                  onTap: () => setState(() {
                    _filtersExpandedOnMobile = !_filtersExpandedOnMobile;
                  }),
                  icon: _filtersExpandedOnMobile ? Icons.filter_alt_off : Icons.filter_alt,
                  expand: true,
                ),
              ),
              if (hasFilters) ...[
                const SizedBox(width: 12),
                clearControl,
              ],
            ],
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: chips,
              ),
            ),
            crossFadeState:
                _filtersExpandedOnMobile ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ..._interleaveChips(chips),
          if (hasFilters) ...[
            const SizedBox(width: 12),
            clearControl,
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
    if (_selectedLeadershipChapters != null && _selectedLeadershipChapters!.isNotEmpty) count++;
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

  List<Widget> _buildMembersSlivers() {
    final hasAgedOutMembers = _agedOutMembers.isNotEmpty;
    final hasPrimaryMembers = _filteredMembers.isNotEmpty;

    if (!hasPrimaryMembers && !hasAgedOutMembers) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Align(
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 48),
                  _buildEmptyMembersState(),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    final slivers = <Widget>[];

    if (hasPrimaryMembers) {
      final bottomPadding = hasAgedOutMembers ? 24.0 : 32.0;
      slivers.add(_buildMemberCollectionSliver(_filteredMembers, bottomPadding: bottomPadding));
    } else {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          sliver: SliverToBoxAdapter(child: _buildEmptyMembersState()),
        ),
      );
    }

    if (hasAgedOutMembers) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverToBoxAdapter(child: _buildAgedOutMembersPanel()),
        ),
      );
    }

    if (!_loading) {
      if (_isLoadingPage) {
        slivers.add(
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
          ),
        );
      } else if (!_hasMoreMembers && (_members.isNotEmpty || _agedOutMembers.isNotEmpty)) {
        // A footer on the background image, so it gets a solid unityBlue
        // pill: white on unityBlue is 12.51:1 wherever the pill lands.
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: _buildSolidPill(Icons.check_circle_outline, 'All members loaded')),
            ),
          ),
        );
      }
    }

    return slivers;
  }

  /// A solid unityBlue pill with white ink for small labels that must sit on
  /// the background image or on a gradient. White on unityBlue is 12.51:1.
  Widget _buildSolidPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _rule, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _ink),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCollectionSliver(List<Member> members, {double bottomPadding = 32}) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        if (width < 600) {
          final itemCount = members.length * 2 - 1;
          return SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index.isOdd) {
                    return const SizedBox(height: 20);
                  }
                  final itemIndex = index ~/ 2;
                  return _buildMemberCard(
                    members[itemIndex],
                    itemIndex,
                    isMobile: true,
                  );
                },
                childCount: itemCount > 0 ? itemCount : 0,
              ),
            ),
          );
        }

        final horizontalPadding = width < 900 ? 20.0 : 24.0;
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, bottomPadding),
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, boxConstraints) {
                final availableWidth = boxConstraints.maxWidth;
                return _buildMemberWrap(members, availableWidth);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildMemberWrap(List<Member> members, double availableWidth) {
    const double minTileWidth = 280.0;
    const double maxTileWidth = 360.0;
    const double spacing = 20.0;

    int columnCount = math.max(1, (availableWidth / (minTileWidth + spacing)).floor());
    columnCount = math.min(columnCount, 4);
    double tileWidth = (availableWidth - spacing * (columnCount - 1)) / columnCount;
    tileWidth = tileWidth.clamp(minTileWidth, maxTileWidth).toDouble();

    final effectiveColumns = math.min(columnCount, members.length);
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
            for (int i = 0; i < members.length; i++)
              SizedBox(
                width: tileWidth,
                child: _buildMemberCard(
                  members[i],
                  i,
                  isMobile: false,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The ineligible drawer, restyled as a gradient card with the Slack header
  /// idiom: icon tile, 18px title, 15px body, all full white. The row rule
  /// under the header is a Border in white 0.15, never a Divider widget.
  Widget _buildAgedOutMembersPanel() {
    final radius = BorderRadius.circular(16);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: BrandColors.tileGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: BrandColors.unityBlue.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          key: const PageStorageKey<String>('aged-out-members-tile'),
          initiallyExpanded: _showAgedOutMembers,
          onExpansionChanged: (expanded) {
            setState(() {
              _showAgedOutMembers = expanded;
            });
          },
          // Border() on both shapes removes the theme divider lines the tile
          // would otherwise paint; the rule below is drawn by hand instead.
          shape: const Border(),
          collapsedShape: const Border(),
          iconColor: _ink,
          collapsedIconColor: _ink,
          textColor: _ink,
          collapsedTextColor: _ink,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: _buildIconTile(Icons.person_off_outlined),
          title: Text(
            'Ineligible Members (${_agedOutMembers.length})',
            style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.2),
          ),
          subtitle: const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Members marked as ineligible are hidden from the main list.',
              style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w400, height: 1.3),
            ),
          ),
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: _rowDivider, width: 1)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  if (width < 600) {
                    return Column(
                      children: [
                        for (int i = 0; i < _agedOutMembers.length; i++) ...[
                          if (i > 0) const SizedBox(height: 20),
                          _buildMemberCard(_agedOutMembers[i], i, isMobile: true),
                        ],
                      ],
                    );
                  }
                  return _buildMemberWrap(_agedOutMembers, width);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The Slack page's signature square behind an icon. Solid unityBlue rather
  /// than white-20% so the tile reads the same at every point on a gradient;
  /// the white glyph on it is 12.51:1 and the glyph only needs 3:1.
  Widget _buildIconTile(IconData icon, {double size = 40, double iconSize = 22}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: BrandColors.unityBlue,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _rule, width: 1),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: _ink, size: iconSize),
    );
  }

  Widget _buildChaptersSliver() {
    if (_filteredChapters.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Align(
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 48),
                _buildEmptyChaptersState(),
              ],
            ),
          ),
        ),
      );
    }

    final itemCount = _filteredChapters.length * 2 - 1;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index.isOdd) {
              return const SizedBox(height: 24);
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

    final borderRadius = BorderRadius.circular(16);

    // Chapters share this screen with members, so they take the same gradient
    // card rather than a themed Card that would be the one odd surface on the
    // branded background.
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: BrandColors.tileGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: BrandColors.unityBlue.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openChapter(chapter),
          borderRadius: borderRadius,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chapterName,
                  style: const TextStyle(color: _ink, fontSize: 24, fontWeight: FontWeight.w800, height: 1.15),
                ),
                if (schoolName != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    schoolName,
                    style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w500, height: 1.3),
                  ),
                ],
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: chips,
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildStatTile(Icons.people_alt, '$memberCount members'),
                    if (leaderCount > 0) _buildStatTile(Icons.emoji_events, '$leaderCount leaders'),
                  ],
                ),
                if (contactEmail != null) _buildChapterInfoRow(Icons.email_outlined, contactEmail),
                if (website != null) _buildChapterInfoRow(Icons.link, website),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A count on a chapter card: solid unityBlue tile, white ink, 12.51:1.
  Widget _buildStatTile(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _rule, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: _ink),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// A contact line on a chapter card. Links are full white with an
  /// underline for affordance; a tinted link colour would fail on the light
  /// end of the gradient (sunriseGold on tileGradientEnd is 2.63:1).
  Widget _buildChapterInfoRow(IconData icon, String value) {
    final uri = _parseChapterUri(value);
    final displayValue = uri != null && _isWebUrl(uri) ? _formatWebsiteLabel(uri) : value;
    final textStyle = TextStyle(
      color: _ink,
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.3,
      decoration: uri != null ? TextDecoration.underline : null,
      decorationColor: _ink,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: uri != null ? () => launchUrl(uri, mode: LaunchMode.externalApplication) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: _ink),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    displayValue,
                    style: textStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaTag(IconData icon, String label) => _buildInfoChip(icon, label);

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

  /// A filter control in the Slack tab bar's idiom rather than a themed
  /// FilterChip. Inactive: white ink and a white decorative border over the
  /// gradient band, 4.59:1 or better at every point on the band. Active: a
  /// SOLID sunriseGold fill with unityBlue ink, 7.17:1, so the ratio is a
  /// property of the chip and not of where it lands on the gradient. A
  /// translucent white fill was rejected: white text on white-20% over the
  /// light end composites to #4997BC and measures 3.26:1.
  Widget _buildFilterChip({
    required String label,
    required bool selected,
    VoidCallback? onTap,
    IconData? icon,
    bool expand = false,
  }) {
    final enabled = onTap != null;
    final Color ink = selected ? BrandColors.unityBlue : _ink;
    final Color fill = selected ? BrandColors.sunriseGold : Colors.transparent;
    // A disabled control is the one place alpha on ink is allowed.
    final Color effectiveInk = enabled ? ink : ink.withValues(alpha: 0.5);
    final radius = BorderRadius.circular(10);

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: effectiveInk),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TextStyle(
            color: effectiveInk,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: radius,
            border: selected ? null : Border.all(color: _rule, width: 1.2),
          ),
          child: content,
        ),
      ),
    );
  }

  Widget _buildEmptyMembersState() {
    return _buildEmptyState(
      icon: Icons.people_outline,
      title: 'No members match your filters',
      body: 'Try adjusting your filters or refreshing to see everyone in your database.',
    );
  }

  Widget _buildEmptyChaptersState() {
    return _buildEmptyState(
      icon: Icons.account_tree_outlined,
      title: 'No chapters found',
      body: 'Try adjusting your search or refresh to pull the latest chapter roster.',
    );
  }

  /// An empty state is a gradient card like everything else here, because
  /// theme ink on the background image is not legible. Title 18 w700 white,
  /// body 15 w400 white, hierarchy by size and weight only.
  Widget _buildEmptyState({required IconData icon, required String title, required String body}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: BrandedCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIconTile(icon, size: 64, iconSize: 34),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.2),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w400, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One member on the list. The Slack card idiom: tileGradient topLeft to
  /// bottomRight, radius 16, every readable run FULL WHITE, hierarchy by size
  /// and weight, chips as solid fills. The card is still the tap target that
  /// opens MemberDetailScreen; nothing about what it opens changed.
  Widget _buildMemberCard(Member member, int index, {required bool isMobile}) {
    final isIneligible = member.membershipEligible == false;
    final gradient = isIneligible ? _ineligibleMemberCardGradient : _memberCardGradient;
    final phoneDisplay = _formatMemberPhone(member);
    final emailDisplay = _cleanValue(member.preferredEmail);
    final county = _cleanValue(member.county);
    final districtLabel = _formatDistrict(member.congressionalDistrict);
    final age = member.age;
    final zodiac = _cleanValue(member.zodiacSign);
    final joinedDate = member.dateJoined;
    final isExecutive = _isExecutiveMember(member);
    final executiveTitle =
        isExecutive ? (_cleanValue(member.executiveTitle) ?? 'Executive Committee') : null;
    final rawExecutiveRole = _cleanValue(member.executiveRole);
    final chapterPosition = _cleanValue(member.chapterPosition);
    final chapterAffiliation = _formatChapterAffiliation(member);

    // Chips are SOLID fills so their ratio is a property of the chip, not of
    // where it lands on the gradient: unityBlue with white ink is 12.51:1,
    // sunriseGold with unityBlue ink is 7.17:1 and is the emphasis pair.
    final metaChips = <Widget>[];
    if (isExecutive) {
      metaChips.add(_buildExecutiveBadge());
    }
    if (isIneligible) {
      metaChips.add(_buildInfoChip(Icons.block, 'INELIGIBLE', emphasis: true));
    }
    if (districtLabel != null) {
      metaChips.add(_buildInfoChip(Icons.account_balance, districtLabel));
    }
    if (age != null) {
      metaChips.add(_buildInfoChip(Icons.cake_outlined, '$age yrs'));
    }
    if (zodiac != null) {
      metaChips.add(_buildInfoChip(Icons.auto_awesome, zodiac));
    }

    final borderRadius = BorderRadius.circular(16);

    // Type scale on the card. Name is the headline. Titles and roles are
    // distinguished from each other by size and weight, never by alpha.
    final nameStyle = TextStyle(
      color: _ink,
      fontSize: isMobile ? 22 : 24,
      fontWeight: FontWeight.w800,
      height: 1.15,
      letterSpacing: -0.2,
    );
    const roleTitleStyle = TextStyle(
      color: _ink,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      height: 1.3,
      letterSpacing: 0.2,
    );
    const roleDetailStyle = TextStyle(
      color: _ink,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.3,
    );

    final dialable = _dialableNumber(member);
    final detailLines = <Widget>[
      _buildDetailLine(Icons.map_outlined, county ?? '-'),
      _buildDetailLine(
        Icons.phone,
        phoneDisplay ?? '-',
        onTap: dialable == null ? null : () => _dialMember(member),
        semanticsLabel: dialable == null ? null : 'Call ${member.name} at ${phoneDisplay ?? dialable}',
      ),
      if (emailDisplay != null) _buildDetailLine(Icons.email_outlined, emailDisplay),
      _buildDetailLine(
        Icons.calendar_month,
        'Joined ${joinedDate != null ? _formatDate(joinedDate) : '-'}',
      ),
    ];

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProfileAvatar(member),
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
                      style: nameStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (member.optOut)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 2),
                      child: _buildInfoChip(Icons.do_not_disturb_on_outlined, 'Opted Out'),
                    ),
                ],
              ),
              if (!isExecutive && chapterPosition != null) ...[
                const SizedBox(height: 6),
                Text(chapterPosition, style: roleTitleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (chapterAffiliation != null) ...[
                  const SizedBox(height: 2),
                  Text(chapterAffiliation, style: roleDetailStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
              if (isExecutive) ...[
                const SizedBox(height: 6),
                if (executiveTitle != null)
                  Text(executiveTitle, style: roleTitleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (rawExecutiveRole != null && rawExecutiveRole.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(rawExecutiveRole, style: roleDetailStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ],
          ),
        ),
      ],
    );

    final columnChildren = <Widget>[
      header,
      if (metaChips.isNotEmpty) ...[
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: metaChips),
      ],
      const SizedBox(height: 16),
      // Field rows separated by a hand drawn rule in white 0.15, never by
      // translucent row fills and never by the Divider widget.
      Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: _rowDivider, width: 1)),
        ),
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: detailLines,
        ),
      ),
    ];

    // Executives get a solid sunriseGold edge. It is a decorative rule, not
    // text, so it needs no ratio; the ring on the avatar is the same gold.
    final BoxBorder? accentBorder = isExecutive
        ? Border.all(color: BrandColors.sunriseGold, width: isMobile ? 1.5 : 2)
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.28),
            blurRadius: isMobile ? 16 : 24,
            offset: const Offset(0, 10),
          ),
        ],
        border: accentBorder,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: () => _openMember(member),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 20 : 24),
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

  /// The emphasis pair: solid sunriseGold with unityBlue ink and glyph,
  /// 7.17:1. Sits first in the chip row on an executive's card.
  Widget _buildExecutiveBadge() {
    return _buildInfoChip(Icons.workspace_premium_outlined, 'Executive', emphasis: true);
  }

  /// The member's photo through the one resolver, Member.effectiveAvatarUrl,
  /// inside a 2px sunriseGold ring. CorsAwareAvatar owns the fallback: an
  /// opaque unityBlue disc with white initials, 12.51:1 wherever the card
  /// gradient happens to sit behind it. The ring is decorative, so gold on
  /// the gradient needs no ratio.
  Widget _buildProfileAvatar(Member member) {
    const double radius = 32;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: BrandColors.sunriseGold, width: 2),
      ),
      child: CorsAwareAvatar(
        imageUrl: member.effectiveAvatarUrl,
        radius: radius,
        backgroundColor: BrandColors.unityBlue,
        fallbackText: member.name,
      ),
    );
  }

  /// A pill carrying text on a gradient card. Default is a solid unityBlue
  /// fill with white ink, 12.51:1; [emphasis] is a solid sunriseGold fill
  /// with unityBlue ink, 7.17:1. The 1px white 0.35 edge is decorative and
  /// keeps the unityBlue pill visible over the navy end of the gradient.
  Widget _buildInfoChip(IconData icon, String label, {bool emphasis = false}) {
    final Color fill = emphasis ? BrandColors.sunriseGold : BrandColors.unityBlue;
    final Color ink = emphasis ? BrandColors.unityBlue : _ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        border: emphasis ? null : Border.all(color: _rule, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ink),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }

  /// One field line on a member card: white glyph, 15px w500 white value.
  Widget _buildDetailLine(IconData icon, String value, {VoidCallback? onTap, String? semanticsLabel}) {
    const valueStyle = TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w500, height: 1.3);
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: _ink),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: valueStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
        if (onTap != null) const Icon(Icons.call, size: 16, color: _ink),
      ],
    );

    if (onTap == null) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: row);
    }

    // A tappable line inside a card that is ALSO tappable, so the InkWell has to
    // be here rather than on the text: without it the tap opens the profile.
    return Semantics(
      label: semanticsLabel,
      button: true,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: row,
          ),
        ),
      ),
    );
  }

  /// The number as dialled, not as displayed. `_formatMemberPhone` inserts
  /// spaces, brackets and a dash for reading, and a `tel:` URI built from that
  /// is not reliably dialled on every platform.
  String? _dialableNumber(Member member) {
    final e164 = member.phoneE164?.trim();
    if (e164 != null && e164.isNotEmpty) return e164;
    final fallback = member.phone?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return null;
  }

  Future<void> _dialMember(Member member) async {
    final number = _dialableNumber(member);
    if (number == null) return;
    // Do NOT gate on canLaunchUrl: on mobile web it returns false for `tel:`
    // even where the dialer opens fine, which would wrongly tell an exec the
    // device can't call. Launch directly and only report failure if it throws.
    final uri = Uri.parse('tel:$number');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This device cannot place calls.')),
      );
    }
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
      labelBuilder: (value) => _formatDistrict(value) ?? value,
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

  void _showLeadershipFilter() {
    final tempSelected = List<String>.from(_selectedLeadershipChapters ?? []);
    tempSelected.retainWhere(_leadershipChapterOptions.contains);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Chapter Leadership'),
        content: SizedBox(
          width: double.maxFinite,
          child: StatefulBuilder(
            builder: (context, setDialogState) => ListView(
              shrinkWrap: true,
              children: _leadershipChapterOptions.map((chapter) {
                final isSelected = tempSelected.contains(chapter);
                return CheckboxListTile(
                  title: Text(chapter),
                  value: isSelected,
                  onChanged: (checked) {
                    setDialogState(() {
                      if (checked == true) {
                        if (!tempSelected.contains(chapter)) {
                          tempSelected.add(chapter);
                        }
                      } else {
                        tempSelected.remove(chapter);
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
              _updateFilters(() => _selectedLeadershipChapters = null);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateFilters(
                () => _selectedLeadershipChapters =
                    tempSelected.isEmpty ? null : List<String>.from(tempSelected),
              );
            },
            child: const Text('Apply'),
          ),
        ],
      ),
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
