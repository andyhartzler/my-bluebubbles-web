import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:bluebubbles/screens/dashboard/models/dashboard_widget_config.dart';

/// A per-user dashboard page. Tab 0 of the Dashboard tab strip is always
/// the global universal Dashboard (untouched, backed by
/// crm_dashboard_metrics.dashboard_layout). Tabs 1..N are these rows.
///
/// `layout` and `layoutMobile` use the same `DashboardConfig.toJson()`
/// shape as the universal layout, so the existing widget renderer can
/// consume them without translation.
@immutable
class DashboardPage {
  final String id;
  final String userId;        // auth.users.id (whose page this is)
  final String? createdBy;    // auth.users.id (who made the page; nullable after deletion)
  final String title;
  final int position;
  final DashboardConfig layout;
  final DashboardConfig layoutMobile;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DashboardPage({
    required this.id,
    required this.userId,
    this.createdBy,
    required this.title,
    required this.position,
    required this.layout,
    required this.layoutMobile,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DashboardPage.fromJson(Map<String, dynamic> json) {
    DateTime parseTs(dynamic v) =>
        v is DateTime ? v : DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();

    DashboardConfig parseLayout(dynamic raw, {required bool mobile}) {
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
          id: json['id'] as String? ?? 'page',
          name: (json['title'] as String?) ?? 'My Dashboard',
          widgets: const [],
          columns: mobile ? 2 : 4,
        );
      }
      // The DashboardConfig.fromJson expects {id, name, widgets, columns}
      // but our DB column may store just {widgets, columns}. Patch in id+name.
      final patched = <String, dynamic>{
        'id': map['id'] ?? json['id'],
        'name': map['name'] ?? (json['title'] as String? ?? 'My Dashboard'),
        ...map,
      };
      return DashboardConfig.fromJson(patched);
    }

    return DashboardPage(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      createdBy: json['created_by'] as String?,
      title: (json['title'] as String?) ?? 'My Dashboard',
      position: (json['position'] as int?) ?? 0,
      layout: parseLayout(json['layout'], mobile: false),
      layoutMobile: parseLayout(json['layout_mobile'], mobile: true),
      createdAt: parseTs(json['created_at']),
      updatedAt: parseTs(json['updated_at']),
    );
  }

  Map<String, dynamic> toInsert() => {
        'user_id': userId,
        'created_by': createdBy,
        'title': title,
        'position': position,
        'layout': layout.toJson(),
        'layout_mobile': layoutMobile.toJson(),
      };

  DashboardPage copyWith({
    String? title,
    int? position,
    DashboardConfig? layout,
    DashboardConfig? layoutMobile,
  }) =>
      DashboardPage(
        id: id,
        userId: userId,
        createdBy: createdBy,
        title: title ?? this.title,
        position: position ?? this.position,
        layout: layout ?? this.layout,
        layoutMobile: layoutMobile ?? this.layoutMobile,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
