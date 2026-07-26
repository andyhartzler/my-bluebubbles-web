import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/candidate_repository.dart';
import 'package:bluebubbles/services/crm/crm_message_service.dart';
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
  final bool workspaceEnabled;

  const UserCommitteeInfo({
    required this.id,
    required this.name,
    required this.slug,
    required this.tools,
    this.color,
    this.icon,
    this.description,
    this.memberCount,
    this.workspaceEnabled = true, // Default true since RPC now filters
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
      workspaceEnabled: json['workspace_enabled'] == true,
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
  String? _authUserId;
  bool _isSuperadmin = false;

  // Getters for user state
  Member? get currentMember => _currentMember;
  List<UserCommitteeInfo> get userCommittees => _userCommittees;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;

  /// The Supabase auth user id (`auth.users.id`) for the current session,
  /// distinct from the `members.id` primary key. Populated after
  /// `loadUserSession()` resolves the member record.
  String? get authUserId => _authUserId;

  /// Whether the current user is a superadmin (per the
  /// `current_user_is_superadmin()` RPC). Superadmins bypass member/committee
  /// gates and can access break-glass tooling. Defaults to false while the
  /// Phase 0 migration creating the RPC rolls out.
  bool get isSuperadmin => _isSuperadmin;

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
    debugPrint('UserSessionProvider.loadUserSession called - isInitialized: $_isInitialized, currentMember: ${_currentMember?.email}');

    if (_isInitialized && _currentMember != null) {
      // Already loaded, just notify listeners
      debugPrint('Session already initialized, skipping load');
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
      debugPrint('Loading session for auth user email: $email');

      if (email == null || email.isEmpty) {
        throw Exception('User email not available');
      }

      // Fetch the member record and superadmin status in parallel — they're
      // independent round-trips, so serializing them just adds spinner time.
      // ilike, not eq. Email is case INSENSITIVE by RFC and by every provider
      // people actually use, but GoTrue stores whatever case the account was
      // created with, and members.email stores whatever case someone typed.
      // Rogelio Rodriguez had two auth rows differing only in the capital R,
      // GoTrue resolved his sign-ins to the capital one, and an eq() lookup
      // against a lowercase members row returned zero, so the CRM threw
      // "Member record not found" and no session ever loaded. Seven more
      // account pairs of the same shape exist today; any one of them becomes
      // the same outage the day that person is made an executive.
      //
      // ilike with no wildcards in the pattern is an exact case-insensitive
      // match, so this cannot widen to a different member. Email is unique
      // per member in practice, and maybeSingle still throws if it is not.
      final parallelResults = await Future.wait<dynamic>([
        client.from('members').select().ilike('email', email).maybeSingle(),
        _fetchSuperadminFlag(),
      ]);
      final memberResponse = parallelResults[0] as Map<String, dynamic>?;
      _isSuperadmin = parallelResults[1] as bool;

      if (memberResponse == null) {
        debugPrint('No member found by primary email, trying school_email');
        // Try school_email as fallback
        final schoolEmailResponse = await client
            .from('members')
            .select()
            .ilike('school_email', email)
            .maybeSingle();

        if (schoolEmailResponse != null) {
          _currentMember = Member.fromJson(schoolEmailResponse);
        } else {
          throw Exception('Member record not found for email: $email');
        }
      } else {
        _currentMember = Member.fromJson(memberResponse);
      }

      // Capture the auth user id — distinct from members.id — so callers can
      // reference `auth.users.id` (for audit writes, RLS checks that compare
      // to auth.uid(), etc.) without another round-trip to Supabase.
      _authUserId = Supabase.instance.client.auth.currentUser?.id;

      debugPrint('Member loaded: ${_currentMember?.name}, executiveCommittee: ${_currentMember?.executiveCommittee}, isExecutive: $isExecutive, isSuperadmin: $_isSuperadmin');

      // If not executive, fetch their valid committees via RPC
      if (!isExecutive) {
        debugPrint('Not executive - loading user committees');
        await _loadUserCommittees(email);
      } else {
        debugPrint('User is executive - skipping committee load');
      }

      _isInitialized = true;
      _isLoading = false;
      _error = null;
      debugPrint('Session load complete - isExecutive: $isExecutive, isCommitteeMember: $isCommitteeMember, userCommittees: ${_userCommittees.length}');

      // Identify the user on every Sentry event (internal exec tool, so
      // attaching the email is intentional despite sendDefaultPii: false).
      if (Sentry.isEnabled) {
        Sentry.configureScope((scope) {
          scope.setUser(SentryUser(
            id: _currentMember?.id,
            email: _currentMember?.email,
            name: _currentMember?.name,
          ));
          scope.setTag(
            'user.role',
            isExecutive
                ? 'executive'
                : (isCommitteeMember ? 'committee' : 'member'),
          );
          scope.setTag('user.superadmin', _isSuperadmin.toString());
        });
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _isInitialized = false;
      debugPrint('UserSessionProvider error: $e');
    }

    notifyListeners();
  }

  /// Resolve superadmin status via the security-definer RPC. Wrapped in
  /// try/catch so the app tolerates the pre-migration state during the
  /// Phase 0 rollout (plan §3) — if the RPC doesn't exist yet we simply
  /// fall back to the default of `false`. The RPC is a scalar `boolean`
  /// under the hood, but supabase-dart's rpc() returns `dynamic` so we
  /// defensively handle bool/Map/List shapes.
  Future<bool> _fetchSuperadminFlag() async {
    try {
      // ignore: avoid_dynamic_calls
      final dynamic superadminResponse =
          await Supabase.instance.client.rpc('current_user_is_superadmin');
      return _coerceSuperadminResult(superadminResponse);
    } catch (e) {
      debugPrint('UserSessionProvider: current_user_is_superadmin RPC failed '
          '(defaulting to false — migration may not be applied yet): $e');
      return false;
    }
  }

  // Committees the auth gate (password screen) already fetched via
  // get_user_valid_committees while validating the sign-in. One-shot: consumed
  // by the next loadUserSession so refreshSession() still hits the RPC fresh.
  static String? _preauthCommitteesEmail;
  static List<dynamic>? _preauthCommitteesRows;

  /// Called by the auth gate after its pre-auth get_user_valid_committees
  /// call so [loadUserSession] can skip the duplicate RPC on the login path.
  static void cachePreauthCommittees(String email, List<dynamic> rows) {
    _preauthCommitteesEmail = email.toLowerCase().trim();
    _preauthCommitteesRows = rows;
  }

  static List<dynamic>? _takePreauthCommittees(String email) {
    final rows = _preauthCommitteesRows;
    final cachedEmail = _preauthCommitteesEmail;
    _preauthCommitteesRows = null;
    _preauthCommitteesEmail = null;
    if (rows == null || cachedEmail != email.toLowerCase().trim()) return null;
    return rows;
  }

  /// Load the user's valid committees via RPC
  Future<void> _loadUserCommittees(String email) async {
    try {
      // Reuse the committees the auth gate fetched moments ago this session —
      // skips a duplicate get_user_valid_committees round-trip at login.
      final preauth = _takePreauthCommittees(email);
      if (preauth != null) {
        _userCommittees = preauth
            .map((item) => UserCommitteeInfo.fromJson(item as Map<String, dynamic>))
            .toList();
        return;
      }

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

      // Query committees table for matching names with workspace enabled
      final response = await client
          .from('committees')
          .select()
          .inFilter('name', committeeNames)
          .eq('workspace_enabled', true)
          .eq('is_active', true);

      if (response is List) {
        _userCommittees = response
            .map((item) => UserCommitteeInfo.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading committees from member record: $e');
      // Don't create fake committee entries - we can't verify workspace_enabled.
      // But DO distinguish "query failed" from "member has no committees": this
      // member has committee names, so an exception here is a transient DB/
      // network failure, not a verdict on their access. Setting _error routes
      // the UI to the retry screen instead of _NoAccessScreen, which reads as
      // being locked out and pushes valid users to sign out and re-OTP.
      _userCommittees = [];
      _error = 'Could not verify committee access. Please try again.';
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

  /// Get the tools available for a specific committee. Callers MUST check
  /// `hasAccessToCommittee` first; if the user isn't on the committee this
  /// returns an empty list. Previously the `orElse` default silently granted
  /// `overview/members/slack/meetings` for committees the user didn't belong
  /// to, which meant skipping the membership check opened those tools up.
  List<String> getToolsForCommittee(String committeeName) {
    final normalizedName = committeeName.toLowerCase().trim();
    final committee = _userCommittees.firstWhere(
      (c) => c.name.toLowerCase() == normalizedName || c.slug.toLowerCase() == normalizedName,
      orElse: () => const UserCommitteeInfo(
        id: '',
        name: '',
        slug: '',
        tools: <String>[],
      ),
    );
    return committee.tools;
  }

  /// Coerce the `current_user_is_superadmin()` RPC payload into a bool.
  /// Supabase's Dart client can return the scalar directly, a single-key map
  /// (e.g. `{'current_user_is_superadmin': true}`), or a one-row list
  /// containing such a map — so we accept all three shapes defensively.
  bool _coerceSuperadminResult(dynamic response) {
    if (response is bool) return response;
    if (response is Map) {
      final value = response['current_user_is_superadmin'];
      if (value is bool) return value;
      if (response.values.isNotEmpty) {
        final first = response.values.first;
        if (first is bool) return first;
      }
      return false;
    }
    if (response is List && response.isNotEmpty) {
      return _coerceSuperadminResult(response.first);
    }
    return false;
  }

  /// Clear the session (for logout)
  ///
  /// Also flushes per-session static caches in repositories/services so that
  /// one user's data can never leak into a subsequent login on the same
  /// process (Wave 2 audit §A.5 / §B.3). Does NOT sign out of Supabase —
  /// that is the caller's responsibility (existing behavior preserved).
  void clearSession() {
    debugPrint('UserSessionProvider.clearSession called - clearing all session data');
    if (Sentry.isEnabled) {
      Sentry.configureScope((scope) => scope.setUser(null));
    }
    _currentMember = null;
    _userCommittees = [];
    _isLoading = false;
    _error = null;
    _isInitialized = false;
    _authUserId = null;
    _isSuperadmin = false;
    _preauthCommitteesEmail = null;
    _preauthCommitteesRows = null;

    // Flush cross-user static caches.
    try {
      CandidateRepository.clearFinanceCache();
      CandidateRepository.clearHeadshotCache();
    } catch (e) {
      debugPrint('UserSessionProvider.clearSession: CandidateRepository.clearFinanceCache failed: $e');
    }
    try {
      CRMMessageService.clearAutomationCache();
    } catch (e) {
      debugPrint('UserSessionProvider.clearSession: CRMMessageService.clearAutomationCache failed: $e');
    }

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
