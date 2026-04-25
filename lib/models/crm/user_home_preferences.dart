import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:bluebubbles/screens/dashboard/models/dashboard_widget_config.dart';

/// Per-user preferences for the Personalized Home Screen.
/// Backed by `public.user_home_preferences` (migration 20260424_04).
@immutable
class UserHomePreferences {
  final String userId;          // auth.users.id
  final DashboardConfig layout;        // optional metric tiles area (desktop)
  final DashboardConfig layoutMobile;  // optional metric tiles area (mobile)
  final bool showProfileHeader;
  final bool showAssignments;
  final bool showMeetingHistory;
  final bool showOptionalTiles;
  final DateTime updatedAt;

  const UserHomePreferences({
    required this.userId,
    required this.layout,
    required this.layoutMobile,
    this.showProfileHeader = true,
    this.showAssignments = true,
    this.showMeetingHistory = true,
    this.showOptionalTiles = true,
    required this.updatedAt,
  });

  /// Defaults for a brand-new user — empty optional-tiles areas, all
  /// top-level panels visible.
  factory UserHomePreferences.defaultsFor(String userId) {
    return UserHomePreferences(
      userId: userId,
      layout: DashboardConfig(
        id: 'home-$userId',
        name: 'Home Optional Tiles',
        widgets: const [],
        columns: 4,
      ),
      layoutMobile: DashboardConfig(
        id: 'home-mobile-$userId',
        name: 'Home Optional Tiles (Mobile)',
        widgets: const [],
        columns: 2,
      ),
      updatedAt: DateTime.now(),
    );
  }

  factory UserHomePreferences.fromJson(Map<String, dynamic> json) {
    DateTime parseTs(dynamic v) =>
        v is DateTime ? v : DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();

    DashboardConfig parseLayout(dynamic raw, {required bool mobile, required String userId}) {
      Map<String, dynamic>? map;
      if (raw is Map<String, dynamic>) {
        map = raw;
      } else if (raw is String && raw.isNotEmpty) {
        try {
          map = jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {
          map = null;
        }
      }
      if (map == null) {
        return DashboardConfig(
          id: mobile ? 'home-mobile-$userId' : 'home-$userId',
          name: mobile ? 'Home Optional Tiles (Mobile)' : 'Home Optional Tiles',
          widgets: const [],
          columns: mobile ? 2 : 4,
        );
      }
      final patched = <String, dynamic>{
        'id': map['id'] ?? (mobile ? 'home-mobile-$userId' : 'home-$userId'),
        'name': map['name'] ?? (mobile ? 'Home Optional Tiles (Mobile)' : 'Home Optional Tiles'),
        ...map,
      };
      return DashboardConfig.fromJson(patched);
    }

    final userId = json['user_id'] as String;
    return UserHomePreferences(
      userId: userId,
      layout: parseLayout(json['layout'], mobile: false, userId: userId),
      layoutMobile: parseLayout(json['layout_mobile'], mobile: true, userId: userId),
      showProfileHeader: json['show_profile_header'] as bool? ?? true,
      showAssignments: json['show_assignments'] as bool? ?? true,
      showMeetingHistory: json['show_meeting_history'] as bool? ?? true,
      showOptionalTiles: json['show_optional_tiles'] as bool? ?? true,
      updatedAt: parseTs(json['updated_at']),
    );
  }

  Map<String, dynamic> toUpsert() => {
        'user_id': userId,
        'layout': layout.toJson(),
        'layout_mobile': layoutMobile.toJson(),
        'show_profile_header': showProfileHeader,
        'show_assignments': showAssignments,
        'show_meeting_history': showMeetingHistory,
        'show_optional_tiles': showOptionalTiles,
      };

  UserHomePreferences copyWith({
    DashboardConfig? layout,
    DashboardConfig? layoutMobile,
    bool? showProfileHeader,
    bool? showAssignments,
    bool? showMeetingHistory,
    bool? showOptionalTiles,
  }) =>
      UserHomePreferences(
        userId: userId,
        layout: layout ?? this.layout,
        layoutMobile: layoutMobile ?? this.layoutMobile,
        showProfileHeader: showProfileHeader ?? this.showProfileHeader,
        showAssignments: showAssignments ?? this.showAssignments,
        showMeetingHistory: showMeetingHistory ?? this.showMeetingHistory,
        showOptionalTiles: showOptionalTiles ?? this.showOptionalTiles,
        updatedAt: DateTime.now(),
      );
}
