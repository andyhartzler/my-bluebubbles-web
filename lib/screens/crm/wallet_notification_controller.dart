import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

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
    _applySearchFilter();
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
      _pruneSelection();
      _applySearchFilter();
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

  void _applySearchFilter() {
    if (_searchTerm.isEmpty) {
      _visibleMembers = List<WalletPassMember>.from(_members);
      return;
    }

    _visibleMembers = _members.where((member) {
      final searchable =
          '${member.member.name} ${member.member.email ?? ''} ${member.member.phone ?? ''}'
              .toLowerCase();
      return searchable.contains(_searchTerm);
    }).toList(growable: false);
  }

  @override
  void dispose() {
    _visibleMembers = const <WalletPassMember>[];
    super.dispose();
  }
}
