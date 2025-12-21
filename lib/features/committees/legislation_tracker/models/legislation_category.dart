import 'package:flutter/material.dart';

/// Helper to safely coerce values to bool (handles Supabase returning int for bool)
bool _coerceBool(dynamic value, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase();
    if (lower == 'true' || lower == '1') return true;
    if (lower == 'false' || lower == '0') return false;
  }
  return defaultValue;
}

/// Represents a category for organizing tracked legislation
class LegislationCategory {
  final String id;
  final String name;
  final String displayName;
  final String? description;
  final String? color;
  final String? icon;
  final int sortOrder;
  final bool isActive;

  const LegislationCategory({
    required this.id,
    required this.name,
    required this.displayName,
    this.description,
    this.color,
    this.icon,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory LegislationCategory.fromJson(Map<String, dynamic> json) {
    return LegislationCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      displayName: json['display_name'] as String,
      description: json['description'] as String?,
      color: json['color'] as String?,
      icon: json['icon'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: _coerceBool(json['is_active'], defaultValue: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
      'description': description,
      'color': color,
      'icon': icon,
      'sort_order': sortOrder,
      'is_active': isActive,
    };
  }

  LegislationCategory copyWith({
    String? id,
    String? name,
    String? displayName,
    String? description,
    String? color,
    String? icon,
    int? sortOrder,
    bool? isActive,
  }) {
    return LegislationCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Get color as Color object
  Color get colorValue {
    if (color == null) return Colors.grey;
    try {
      return Color(int.parse(color!.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  /// Get icon as IconData
  IconData get iconData {
    switch (icon) {
      case 'eco':
        return Icons.eco;
      case 'health_and_safety':
        return Icons.health_and_safety;
      case 'school':
        return Icons.school;
      case 'how_to_vote':
        return Icons.how_to_vote;
      case 'work':
        return Icons.work;
      case 'home':
        return Icons.home;
      case 'gavel':
        return Icons.gavel;
      case 'diversity_3':
        return Icons.diversity_3;
      case 'travel_explore':
        return Icons.travel_explore;
      case 'security':
        return Icons.security;
      case 'account_balance':
        return Icons.account_balance;
      case 'directions_bus':
        return Icons.directions_bus;
      case 'attach_money':
        return Icons.attach_money;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'child_care':
        return Icons.child_care;
      case 'apartment':
        return Icons.apartment;
      case 'agriculture':
        return Icons.agriculture;
      case 'bolt':
        return Icons.bolt;
      case 'water_drop':
        return Icons.water_drop;
      case 'forest':
        return Icons.forest;
      default:
        return Icons.category;
    }
  }
}

/// Predefined categories for Missouri legislation
class LegislationCategories {
  LegislationCategories._();

  static const defaultCategories = [
    LegislationCategory(
      id: 'climate',
      name: 'climate',
      displayName: 'Climate & Environment',
      description: 'Environmental protection, climate policy, clean energy',
      color: '#22C55E',
      icon: 'eco',
      sortOrder: 1,
    ),
    LegislationCategory(
      id: 'healthcare',
      name: 'healthcare',
      displayName: 'Healthcare',
      description: 'Healthcare access, Medicaid, public health',
      color: '#EF4444',
      icon: 'local_hospital',
      sortOrder: 2,
    ),
    LegislationCategory(
      id: 'education',
      name: 'education',
      displayName: 'Education',
      description: 'K-12 education, higher education, school funding',
      color: '#3B82F6',
      icon: 'school',
      sortOrder: 3,
    ),
    LegislationCategory(
      id: 'voting',
      name: 'voting',
      displayName: 'Voting Rights',
      description: 'Voting access, election administration, redistricting',
      color: '#8B5CF6',
      icon: 'how_to_vote',
      sortOrder: 4,
    ),
    LegislationCategory(
      id: 'labor',
      name: 'labor',
      displayName: 'Labor & Workers',
      description: 'Worker rights, minimum wage, workplace safety',
      color: '#F97316',
      icon: 'work',
      sortOrder: 5,
    ),
    LegislationCategory(
      id: 'housing',
      name: 'housing',
      displayName: 'Housing',
      description: 'Affordable housing, tenant rights, homelessness',
      color: '#06B6D4',
      icon: 'apartment',
      sortOrder: 6,
    ),
    LegislationCategory(
      id: 'criminal_justice',
      name: 'criminal_justice',
      displayName: 'Criminal Justice',
      description: 'Criminal justice reform, policing, incarceration',
      color: '#6366F1',
      icon: 'gavel',
      sortOrder: 7,
    ),
    LegislationCategory(
      id: 'civil_rights',
      name: 'civil_rights',
      displayName: 'Civil Rights',
      description: 'LGBTQ+ rights, racial equity, anti-discrimination',
      color: '#EC4899',
      icon: 'diversity_3',
      sortOrder: 8,
    ),
    LegislationCategory(
      id: 'reproductive',
      name: 'reproductive',
      displayName: 'Reproductive Rights',
      description: 'Abortion access, reproductive healthcare',
      color: '#F472B6',
      icon: 'health_and_safety',
      sortOrder: 9,
    ),
    LegislationCategory(
      id: 'budget',
      name: 'budget',
      displayName: 'Budget & Taxes',
      description: 'State budget, taxation, fiscal policy',
      color: '#84CC16',
      icon: 'attach_money',
      sortOrder: 10,
    ),
    LegislationCategory(
      id: 'transportation',
      name: 'transportation',
      displayName: 'Transportation',
      description: 'Roads, public transit, infrastructure',
      color: '#14B8A6',
      icon: 'directions_bus',
      sortOrder: 11,
    ),
    LegislationCategory(
      id: 'agriculture',
      name: 'agriculture',
      displayName: 'Agriculture',
      description: 'Farming, rural development, food systems',
      color: '#A3E635',
      icon: 'agriculture',
      sortOrder: 12,
    ),
  ];
}
