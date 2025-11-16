import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/wallet_pass_member.dart';
import 'package:bluebubbles/services/crm/wallet_notification_service.dart';

class WalletNotificationController extends ChangeNotifier {
  WalletNotificationController({List<String>? initialMemberIds})
      : _initialMemberIds = initialMemberIds ?? const [] {
    Future.microtask(_bootstrap);
  }

  final WalletNotificationService _service = WalletNotificationService.instance;
  final List<String> _initialMemberIds;

  final List<WalletPassMember> _members = [];
  List<WalletPassMember> _visibleMembers = const <WalletPassMember>[];
  final LinkedHashSet<String> _selectedMemberIds = LinkedHashSet();

  List<String> _countyOptions = const <String>[];
  List<String> _districtOptions = const <String>[];
  List<String> _schoolOptions = const <String>[];
  List<String> _chapterOptions = const <String>[];

  String? _selectedCounty;
  String? _selectedDistrict;
  String? _selectedSchool;
  String? _selectedChapter;

  WalletNotificationTarget _target = WalletNotificationTarget.allPassHolders;
  bool _loading = false;
  bool _sending = false;
  String? _errorMessage;
  String _searchTerm = '';

  List<WalletPassMember> get members => List.unmodifiable(_visibleMembers);
  bool get isLoading => _loading;
  bool get isSending => _sending;
  WalletNotificationTarget get target => _target;
  String? get errorMessage => _errorMessage;
  int get selectedCount => _selectedMemberIds.length;
  int get totalCount => _members.length;
  int get activeCount =>
      _members.where((member) => member.isActive).length;
  int get registeredCount =>
      _members.where((member) => member.isRegistered).length;
  bool get isServiceReady => _service.isReady;
  List<String> get countyOptions => List.unmodifiable(_countyOptions);
  List<String> get districtOptions => List.unmodifiable(_districtOptions);
  List<String> get schoolOptions => List.unmodifiable(_schoolOptions);
  List<String> get chapterOptions => List.unmodifiable(_chapterOptions);
  String? get selectedCountyFilter => _selectedCounty;
  String? get selectedDistrictFilter => _selectedDistrict;
  String? get selectedSchoolFilter => _selectedSchool;
  String? get selectedChapterFilter => _selectedChapter;
  bool get hasMemberFilters =>
      (_selectedCounty ?? '').isNotEmpty ||
      (_selectedDistrict ?? '').isNotEmpty ||
      (_selectedSchool ?? '').isNotEmpty ||
      (_selectedChapter ?? '').isNotEmpty;
  int get estimatedRecipientCount {
    switch (_target) {
      case WalletNotificationTarget.allPassHolders:
        return totalCount;
      case WalletNotificationTarget.activePasses:
        return activeCount;
      case WalletNotificationTarget.registeredDevices:
        return registeredCount;
      case WalletNotificationTarget.selectedMembers:
        return selectedCount;
    }
  }

  bool canSend({required String title, required String message}) {
    if (title.trim().isEmpty || message.trim().isEmpty) {
      return false;
    }
    if (_target == WalletNotificationTarget.selectedMembers &&
        _selectedMemberIds.isEmpty) {
      return false;
    }
    if (!isServiceReady) {
      return false;
    }
    return true;
  }

  void updateSearch(String query) {
    _searchTerm = query.trim().toLowerCase();
    _applyMemberFilters();
    notifyListeners();
  }

  void setTarget(WalletNotificationTarget target) {
    if (_target == target) return;
    _target = target;
    notifyListeners();
  }

  bool isSelected(String memberId) => _selectedMemberIds.contains(memberId);

  void toggleMember(String memberId) {
    if (_selectedMemberIds.contains(memberId)) {
      _selectedMemberIds.remove(memberId);
    } else {
      _selectedMemberIds.add(memberId);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedMemberIds.clear();
    notifyListeners();
  }

  void selectAllVisible() {
    for (final member in _visibleMembers) {
      _selectedMemberIds.add(member.member.id);
    }
    notifyListeners();
  }

  void updateCountyFilter(String? county) {
    final normalizedValue = (county ?? '').trim();
    final normalized = normalizedValue.isEmpty ? null : normalizedValue;
    if (_selectedCounty == normalized) return;
    _selectedCounty = normalized;
    _applyMemberFilters();
    notifyListeners();
  }

  void updateDistrictFilter(String? district) {
    final normalizedValue = (district ?? '').trim();
    final normalized = normalizedValue.isEmpty ? null : normalizedValue;
    if (_selectedDistrict == normalized) return;
    _selectedDistrict = normalized;
    _applyMemberFilters();
    notifyListeners();
  }

  void updateSchoolFilter(String? school) {
    final normalizedValue = (school ?? '').trim();
    final normalized = normalizedValue.isEmpty ? null : normalizedValue;
    if (_selectedSchool == normalized) return;
    _selectedSchool = normalized;
    _applyMemberFilters();
    notifyListeners();
  }

  void updateChapterFilter(String? chapter) {
    final normalizedValue = (chapter ?? '').trim();
    final normalized = normalizedValue.isEmpty ? null : normalizedValue;
    if (_selectedChapter == normalized) return;
    _selectedChapter = normalized;
    _applyMemberFilters();
    notifyListeners();
  }

  void clearMemberFilters() {
    if (!hasMemberFilters) return;
    _selectedCounty = null;
    _selectedDistrict = null;
    _selectedSchool = null;
    _selectedChapter = null;
    _applyMemberFilters();
    notifyListeners();
  }

  Future<void> refreshMembers() async {
    await _bootstrap(force: true);
  }

  Future<WalletNotificationResult> send({
    required String title,
    required String message,
  }) async {
    if (!canSend(title: title, message: message)) {
      return WalletNotificationResult.error(
        'Fill out the title/message and select recipients.',
      );
    }

    _sending = true;
    notifyListeners();

    try {
      final result = await _service.sendNotification(
        target: _target,
        title: title.trim(),
        message: message.trim(),
        memberIds: _target == WalletNotificationTarget.selectedMembers
            ? _selectedMemberIds.toList(growable: false)
            : null,
      );
      return result;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> _bootstrap({bool force = false}) async {
    if (!isServiceReady) {
      _errorMessage =
          'Wallet notifications require Supabase CRM credentials.';
      notifyListeners();
      return;
    }

    if (_loading && !force) return;

    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final members = await _service.fetchPassMembers();
      final merged = _mergeMembers(members);
      if (_initialMemberIds.isNotEmpty) {
        final seedMembers = await _service.fetchPassMembers(
          memberIds: _initialMemberIds,
        );
        merged
          ..removeWhere(
            (member) => _initialMemberIds.contains(member.member.id),
          )
          ..insertAll(0, seedMembers);
      }
      _members
        ..clear()
        ..addAll(merged);
      _refreshFilterOptions();
      _pruneSelection();
      _applyMemberFilters();
      _applyInitialSelections();
    } catch (error) {
      _errorMessage = 'Failed to load wallet pass holders: $error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _applyInitialSelections() {
    if (_selectedMemberIds.isNotEmpty || _initialMemberIds.isEmpty) {
      return;
    }
    bool matchedAny = false;
    for (final id in _initialMemberIds) {
      if (_members.any((member) => member.member.id == id)) {
        _selectedMemberIds.add(id);
        matchedAny = true;
      }
    }
    if (matchedAny) {
      _target = WalletNotificationTarget.selectedMembers;
    }
  }

  List<WalletPassMember> _mergeMembers(List<WalletPassMember> source) {
    final map = LinkedHashMap<String, WalletPassMember>();
    for (final member in source) {
      map[member.member.id] = member;
    }
    return map.values.toList(growable: false);
  }

  void _pruneSelection() {
    if (_selectedMemberIds.isEmpty) return;
    final validIds = _members.map((member) => member.member.id).toSet();
    _selectedMemberIds.removeWhere((id) => !validIds.contains(id));
  }

  void _applyMemberFilters() {
    Iterable<WalletPassMember> filtered = _members;

    if (_searchTerm.isNotEmpty) {
      filtered = filtered.where((member) {
        final searchable =
            '${member.member.name} ${member.member.email ?? ''} ${member.member.phone ?? ''}'
                .toLowerCase();
        return searchable.contains(_searchTerm);
      });
    }

    if (_selectedCounty != null) {
      filtered = filtered.where(
        (member) => _memberCountyLabel(member) == _selectedCounty,
      );
    }

    if (_selectedDistrict != null) {
      filtered = filtered.where(
        (member) => _memberDistrictLabel(member) == _selectedDistrict,
      );
    }

    if (_selectedSchool != null) {
      filtered = filtered.where(
        (member) => _memberSchoolLabel(member) == _selectedSchool,
      );
    }

    if (_selectedChapter != null) {
      filtered = filtered.where(
        (member) => _memberChapterLabel(member) == _selectedChapter,
      );
    }

    _visibleMembers = filtered.toList(growable: false);
  }

  void _refreshFilterOptions() {
    _countyOptions = _collectOptions(_memberCountyLabel);
    _districtOptions = _collectOptions(_memberDistrictLabel);
    _schoolOptions = _collectOptions(_memberSchoolLabel);
    _chapterOptions = _collectOptions(_memberChapterLabel);

    if (_selectedCounty != null && !_countyOptions.contains(_selectedCounty)) {
      _selectedCounty = null;
    }
    if (_selectedDistrict != null &&
        !_districtOptions.contains(_selectedDistrict)) {
      _selectedDistrict = null;
    }
    if (_selectedSchool != null && !_schoolOptions.contains(_selectedSchool)) {
      _selectedSchool = null;
    }
    if (_selectedChapter != null && !_chapterOptions.contains(_selectedChapter)) {
      _selectedChapter = null;
    }
  }

  List<String> _collectOptions(
    String? Function(WalletPassMember member) extractor,
  ) {
    final set = <String>{};
    for (final member in _members) {
      final label = extractor(member);
      if (label != null && label.trim().isNotEmpty) {
        set.add(label.trim());
      }
    }
    final list = set.toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  String? _memberCountyLabel(WalletPassMember member) {
    return Member.normalizeCountyLabel(member.member.county);
  }

  String? _memberDistrictLabel(WalletPassMember member) {
    return Member.formatDistrictLabel(member.member.congressionalDistrict);
  }

  String? _memberSchoolLabel(WalletPassMember member) {
    final candidates = [
      member.member.schoolName,
      member.member.highSchool,
      member.member.college,
    ];
    for (final value in candidates) {
      final normalized = Member.normalizeText(value);
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  String? _memberChapterLabel(WalletPassMember member) {
    return Member.normalizeText(
      member.member.chapterName ?? member.member.currentChapterMember,
    );
  }

  @override
  void dispose() {
    _visibleMembers = const <WalletPassMember>[];
    super.dispose();
  }
}
