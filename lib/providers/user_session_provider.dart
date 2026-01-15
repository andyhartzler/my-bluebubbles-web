import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

/// Information about a committee the user belongs to, fetched from RPC
class UserCommitteeInfo {
  final String id;
  final String name;
  final String slug;
  final List<String> tools;
  final String? color;
  final String? icon;
  final String? description;
  final int? memberCount;

  const UserCommitteeInfo({
    required this.id,
    required this.name,
    required this.slug,
    required this.tools,
    this.color,
    this.icon,
    this.description,
    this.memberCount,
  });

  factory UserCommitteeInfo.fromJson(Map<String, dynamic> json) {
    final toolsRaw = json['committee_tools'] ?? json['tools'] ?? [];
    final tools = <String>[];
    if (toolsRaw is List) {
      for (final item in toolsRaw) {
        if (item is String && item.isNotEmpty) {
          tools.add(item);
        }
      }
    }

    return UserCommitteeInfo(
      id: json['committee_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['committee_name']?.toString() ?? json['name']?.toString() ?? '',
      slug: json['committee_slug']?.toString() ?? json['slug']?.toString() ?? '',
      tools: tools,
      color: json['committee_color']?.toString() ?? json['color']?.toString(),
      icon: json['committee_icon']?.toString() ?? json['icon']?.toString(),
      description: json['committee_description']?.toString() ?? json['description']?.toString(),
      memberCount: json['member_count'] is int ? json['member_count'] : null,
    );
  }
}

/// Manages user session state including role determination
///
/// This provider handles:
/// - Loading the current user's member record after authentication
/// - Determining if user is executive or committee member
/// - Fetching the user's valid committees with tool configurations
/// - Providing role-based access checks throughout the app
class UserSessionProvider extends ChangeNotifier {
  Member? _currentMember;
  List<UserCommitteeInfo> _userCommittees = [];
  bool _isLoading = true;
  String? _error;
  bool _isInitialized = false;

  // Getters for user state
  Member? get currentMember => _currentMember;
  List<UserCommitteeInfo> get userCommittees => _userCommittees;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;

  /// Whether the current user is an executive committee member
  /// Executives have full access to the CRM dashboard
  bool get isExecutive => _currentMember?.executiveCommittee ?? false;

  /// Whether the current user is a regular committee member (not executive)
  /// Committee members see the Committee Hub with limited tools
  bool get isCommitteeMember => !isExecutive && _userCommittees.isNotEmpty;

  /// Whether the user has any valid access (either executive or committee member)
  bool get hasValidAccess => isExecutive || isCommitteeMember;

  /// List of committee names from the member record
  List<String> get committeeNames => _currentMember?.committee ?? [];

  /// The user's display name
  String get displayName => _currentMember?.name ?? 'Member';

  /// The user's email
  String? get userEmail => _currentMember?.email;

  /// Whether user belongs to multiple committees
  bool get hasMultipleCommittees => _userCommittees.length > 1;

  /// Load the user session after successful authentication
  ///
  /// This should be called after Supabase auth succeeds.
  /// It fetches the member record and their valid committees.
  Future<void> loadUserSession() async {
    if (_isInitialized && _currentMember != null) {
      // Already loaded, just notify listeners
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final supabase = CRMSupabaseService();
      if (!supabase.isInitialized) {
        throw Exception('CRM service not initialized');
      }

      final client = supabase.client;
      final currentUser = client.auth.currentUser;

      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      final email = currentUser.email;
      if (email == null || email.isEmpty) {
        throw Exception('User email not available');
      }

      // Fetch member record by email
      final memberResponse = await client
          .from('members')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (memberResponse == null) {
        // Try school_email as fallback
        final schoolEmailResponse = await client
            .from('members')
            .select()
            .eq('school_email', email)
            .maybeSingle();

        if (schoolEmailResponse != null) {
          _currentMember = Member.fromJson(schoolEmailResponse);
        } else {
          throw Exception('Member record not found for email: $email');
        }
      } else {
        _currentMember = Member.fromJson(memberResponse);
      }

      // If not executive, fetch their valid committees via RPC
      if (!isExecutive) {
        await _loadUserCommittees(email);
      }

      _isInitialized = true;
      _isLoading = false;
      _error = null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _isInitialized = false;
      debugPrint('UserSessionProvider error: $e');
    }

    notifyListeners();
  }

  /// Load the user's valid committees via RPC
  Future<void> _loadUserCommittees(String email) async {
    try {
      final supabase = CRMSupabaseService();
      final client = supabase.client;

      // Call the RPC function to get user's valid committees
      final response = await client.rpc(
        'get_user_valid_committees',
        params: {'user_email': email},
      );

      if (response is List) {
        _userCommittees = response
            .map((item) => UserCommitteeInfo.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback: use member's committee array to build committee info
        await _loadCommitteesFromMemberRecord();
      }
    } catch (e) {
      debugPrint('Error loading user committees via RPC: $e');
      // Fallback: use member's committee array
      await _loadCommitteesFromMemberRecord();
    }
  }

  /// Fallback method to load committees from the member's committee array
  Future<void> _loadCommitteesFromMemberRecord() async {
    final committeeNames = _currentMember?.committee ?? [];
    if (committeeNames.isEmpty) return;

    try {
      final supabase = CRMSupabaseService();
      final client = supabase.client;

      // Query committees table for matching names
      final response = await client
          .from('committees')
          .select()
          .inFilter('name', committeeNames);

      if (response is List) {
        _userCommittees = response
            .map((item) => UserCommitteeInfo.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading committees from member record: $e');
      // Last resort: create basic committee info from names
      _userCommittees = committeeNames.map((name) => UserCommitteeInfo(
        id: name.toLowerCase().replaceAll(' ', '-'),
        name: name,
        slug: name.toLowerCase().replaceAll(' ', '-').replaceAll('&', 'and'),
        tools: ['overview', 'members', 'slack', 'meetings'], // Default tools
      )).toList();
    }
  }

  /// Check if the user has access to a specific committee
  bool hasAccessToCommittee(String committeeName) {
    if (isExecutive) return true;

    final normalizedName = committeeName.toLowerCase().trim();
    return _userCommittees.any((c) =>
      c.name.toLowerCase() == normalizedName ||
      c.slug.toLowerCase() == normalizedName
    );
  }

  /// Get the tools available for a specific committee
  List<String> getToolsForCommittee(String committeeName) {
    final normalizedName = committeeName.toLowerCase().trim();
    final committee = _userCommittees.firstWhere(
      (c) => c.name.toLowerCase() == normalizedName || c.slug.toLowerCase() == normalizedName,
      orElse: () => const UserCommitteeInfo(
        id: '',
        name: '',
        slug: '',
        tools: ['overview', 'members', 'slack', 'meetings'],
      ),
    );
    return committee.tools;
  }

  /// Clear the session (for logout)
  void clearSession() {
    _currentMember = null;
    _userCommittees = [];
    _isLoading = false;
    _error = null;
    _isInitialized = false;
    notifyListeners();
  }

  /// Refresh the session data
  Future<void> refreshSession() async {
    _isInitialized = false;
    await loadUserSession();
  }

  /// Update the current member (e.g., after profile photo upload)
  void refreshMember(Member updatedMember) {
    _currentMember = updatedMember;
    notifyListeners();
  }
}
