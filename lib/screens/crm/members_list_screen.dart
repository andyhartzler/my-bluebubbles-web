import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

  @visibleForTesting
  static int compareMembersForTesting(Member a, Member b) =>
      _MembersListScreenState._compareMembers(a, b);

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
  final MemberRepository _memberRepo = MemberRepository();
  final ChapterRepository _chapterRepository = ChapterRepository();
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

  // Filter state
  String? _selectedCounty;
  String? _selectedDistrict;
  List<String>? _selectedCommittees;
  String? _selectedChapter;
  String? _selectedCommunityType;
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
  List<String> _communityTypes = [];
  List<String> _leadershipChapterOptions = [];

  Map<String, int> _memberCountByChapter = {};
  Map<String, int> _leaderCountByChapter = {};
  int? _availableMinAge;
  int? _availableMaxAge;

  static const List<Color> _memberCardGradient = [Color(0xFF0F4C75), Color(0xFF3282B8)];
  static const Color _executiveAccentColor = Color(0xFFFDB813);
  static const int _minAllowedAge = 14;
  static const int _maxAllowedAge = 36;

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
        _memberRepo.getCommunityTypeCounts(),
        _chapterRepository.getAllChapters(),
      ]);

      if (!mounted) return;

      final members = results[0] as List<Member>;
      final counties = results[1] as List<String>;
      final districts = results[2] as List<String>;
      final committees = results[3] as List<String>;
      final rawChapterCounts = Map<String, int>.from(results[4] as Map);
      final communityCounts = Map<String, int>.from(results[5] as Map);
      final chapters = results[6] as List<Chapter>;

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

      final communityTypes = communityCounts.keys
          .map(_cleanValue)
          .whereType<String>()
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      final leadershipChapters = members
          .where((member) => _cleanValue(member.chapterPosition) != null)
          .map((member) => _cleanValue(member.chapterName))
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
        _chaptersByKey = _buildChapterLookup(chapters);
        _chapterNames = chapterNames;
        _communityTypes = communityTypes;
        _leadershipChapterOptions = leadershipChapters;
        _memberCountByChapter = normalizedChapterCounts;
        _leaderCountByChapter = _computeLeaderCounts(members);
        _deriveAgeBounds(members);
        _filteredMembers = _computeFilteredMembers();
        if (_agedOutMembers.isEmpty) {
          _showAgedOutMembers = false;
        }
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
      if (_agedOutMembers.isEmpty) {
        _showAgedOutMembers = false;
      }
      _filteredChapters = _computeFilteredChapters();
    });
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

      if (_selectedCommunityType != null &&
          !_equalsIgnoreCase(member.communityType, _selectedCommunityType)) {
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

      if (age != null && age > _maxAllowedAge) {
        agedOutMembers.add(member);
      } else {
        primaryMembers.add(member);
      }
    }

    primaryMembers.sort(_compareMembers);
    agedOutMembers.sort(_compareMembers);
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
          .replaceAll(RegExp(r'[\-–—/]'), ' ')
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

  static int _compareMembers(Member a, Member b) {
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

    final aHasPhoto = a.hasProfilePhoto;
    final bHasPhoto = b.hasProfilePhoto;
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
    _updateFilters(() {
      _searchQuery = '';
      _selectedCounty = null;
      _selectedDistrict = null;
      _selectedCommittees = null;
      _selectedChapter = null;
      _selectedCommunityType = null;
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

    final visibleMembersCount = _filteredMembers.length;
    final totalMembersCount = visibleMembersCount + _agedOutMembers.length;

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
                : 'Showing $visibleMembersCount of $totalMembersCount members',
            style: theme.textTheme.labelMedium,
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
    ];

    if (showingChapters) {
      slivers.add(_buildChaptersSliver(theme));
    } else {
      slivers.addAll(_buildMembersSlivers(theme));
    }

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
        (_selectedLeadershipChapters != null && _selectedLeadershipChapters!.isNotEmpty) ||
        _selectedCommunityType != null ||
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
    if (_selectedLeadershipChapters != null && _selectedLeadershipChapters!.isNotEmpty) count++;
    if (_selectedCommunityType != null) count++;
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

  List<Widget> _buildMembersSlivers(ThemeData theme) {
    final hasAgedOutMembers = _agedOutMembers.isNotEmpty;
    final hasPrimaryMembers = _filteredMembers.isNotEmpty;

    if (!hasPrimaryMembers && !hasAgedOutMembers) {
      return [
        SliverFillRemaining(
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
        ),
      ];
    }

    final slivers = <Widget>[];

    if (hasPrimaryMembers) {
      final bottomPadding = hasAgedOutMembers ? 16.0 : 32.0;
      slivers.add(_buildMemberCollectionSliver(_filteredMembers, bottomPadding: bottomPadding));
    } else {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverToBoxAdapter(child: _buildEmptyMembersState(theme)),
        ),
      );
    }

    if (hasAgedOutMembers) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverToBoxAdapter(child: _buildAgedOutMembersPanel(theme)),
        ),
      );
    }

    return slivers;
  }

  Widget _buildMemberCollectionSliver(List<Member> members, {double bottomPadding = 32}) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        if (width < 600) {
          final itemCount = members.length * 2 - 1;
          return SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index.isOdd) {
                    return const SizedBox(height: 16);
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

        final horizontalPadding = width < 900 ? 16.0 : 24.0;
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

  Widget _buildAgedOutMembersPanel(ThemeData theme) {
    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const PageStorageKey<String>('aged-out-members-tile'),
          initiallyExpanded: _showAgedOutMembers,
          onExpansionChanged: (expanded) {
            setState(() {
              _showAgedOutMembers = expanded;
            });
          },
          title: Text(
            'Aged-Out Members (${_agedOutMembers.length})',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'Members older than $_maxAllowedAge are hidden from the main list.',
            style: theme.textTheme.bodySmall,
          ),
          children: [
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  if (width < 600) {
                    return Column(
                      children: [
                        for (int i = 0; i < _agedOutMembers.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
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
    final isExecutive = _isExecutiveMember(member);
    final executiveTitle =
        isExecutive ? (_cleanValue(member.executiveTitle) ?? 'Executive Committee') : null;
    final rawExecutiveRole = _cleanValue(member.executiveRole);
    final chapterPosition = _cleanValue(member.chapterPosition);
    final chapterAffiliation = _formatChapterAffiliation(member);

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
    final borderRadius = BorderRadius.circular(isMobile ? 16 : 24);
    const textColor = Colors.white;
    final detailIconColor = Colors.white.withOpacity(0.92);
    final detailTextStyle = (isMobile ? theme.textTheme.bodyMedium : theme.textTheme.bodyLarge)
            ?.copyWith(color: textColor, fontWeight: FontWeight.w600, height: 1.3) ??
        TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: isMobile ? 13.5 : 14.5);

    final executiveTitleStyle = (isMobile ? theme.textTheme.titleSmall : theme.textTheme.titleMedium)
            ?.copyWith(
              color: Colors.white.withOpacity(0.95),
              fontWeight: FontWeight.w600,
              height: 1.25,
            ) ??
        TextStyle(
          color: Colors.white.withOpacity(0.95),
          fontWeight: FontWeight.w600,
          fontSize: isMobile ? 15 : 17,
          height: 1.25,
        );
    final executiveRoleStyle = (isMobile ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
            ?.copyWith(
              color: Colors.white.withOpacity(0.82),
              fontWeight: FontWeight.w500,
              height: 1.2,
            ) ??
        TextStyle(
          color: Colors.white.withOpacity(0.82),
          fontWeight: FontWeight.w500,
          fontSize: isMobile ? 12 : 13,
          height: 1.2,
        );
    final chapterPositionStyle = (isMobile ? theme.textTheme.titleSmall : theme.textTheme.titleMedium)
            ?.copyWith(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
              height: 1.22,
            ) ??
        TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontWeight: FontWeight.w600,
          fontSize: isMobile ? 14.5 : 16,
          height: 1.22,
        );
    final chapterAffiliationStyle = (isMobile ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
            ?.copyWith(
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w500,
              height: 1.18,
            ) ??
        TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontWeight: FontWeight.w500,
          fontSize: isMobile ? 12.5 : 13.5,
          height: 1.18,
        );

    final detailLines = <Widget>[
      _buildDetailLine(
        Icons.phone,
        phoneDisplay ?? '-',
        iconColor: detailIconColor,
        textStyle: detailTextStyle,
      ),
    ];
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
    detailLines.insert(
      0,
      _buildDetailLine(
        Icons.map_outlined,
        county ?? '-',
        iconColor: detailIconColor,
        textStyle: detailTextStyle,
      ),
    );
    detailLines.add(
      _buildDetailLine(
        Icons.calendar_month,
        'Joined ${joinedDate != null ? _formatDate(joinedDate) : '-'}',
        iconColor: detailIconColor,
        textStyle: detailTextStyle,
      ),
    );

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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ),
                    if (member.optOut)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Container(
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
                      ),
                  ],
                ),
                if (chapterPosition != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    chapterPosition,
                    style: chapterPositionStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (chapterAffiliation != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      chapterAffiliation,
                      style: chapterAffiliationStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
                if (isExecutive) ...[
                  const SizedBox(height: 6),
                  if (executiveTitle != null)
                    Text(
                      executiveTitle,
                      style: executiveTitleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (rawExecutiveRole != null && rawExecutiveRole.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      rawExecutiveRole,
                      style: executiveRoleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
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

    final BoxBorder? accentBorder = isExecutive
        ? Border.all(
            color: _executiveAccentColor.withOpacity(0.65),
            width: isMobile ? 1.4 : 1.8,
          )
        : null;

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
        border: accentBorder,
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

  Widget _buildExecutiveBadge({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 12, vertical: isMobile ? 4 : 6),
      decoration: BoxDecoration(
        color: _executiveAccentColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _executiveAccentColor.withOpacity(0.7), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_outlined, size: isMobile ? 14 : 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            'Executive',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: isMobile ? 11 : 12.5,
              letterSpacing: 0.2,
            ),
          ),
        ],
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
      final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
      final cacheSize = math.max(1, (size * devicePixelRatio).round());

      content = ClipOval(
        child: CachedNetworkImage(
          imageUrl: photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: cacheSize,
          memCacheHeight: cacheSize,
          fadeInDuration: const Duration(milliseconds: 200),
          fadeOutDuration: const Duration(milliseconds: 200),
          placeholder: (context, url) => Container(
            width: size,
            height: size,
            color: Colors.black.withOpacity(0.1),
            child: Center(
              child: SizedBox(
                width: size * 0.4,
                height: size * 0.4,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              ),
            ),
          ),
          errorWidget: (context, url, error) => buildFallback(),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
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

  void _showCommunityFilter() {
    _showSingleChoiceDialog(
      title: 'Filter by Community Type',
      options: _communityTypes,
      currentValue: _selectedCommunityType,
      onSelected: (value) => _updateFilters(() => _selectedCommunityType = value),
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
