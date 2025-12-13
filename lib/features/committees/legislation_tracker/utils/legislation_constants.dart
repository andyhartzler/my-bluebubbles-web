import 'package:flutter/material.dart';

/// Constants for the legislation tracker feature
class LegislationConstants {
  LegislationConstants._();

  /// Current legislative session
  static const String currentSession = '2026';

  /// Available legislative sessions
  static const List<String> availableSessions = [
    '2026',
    '2025',
    '2024',
    '2023',
  ];

  /// Missouri jurisdiction code
  static const String jurisdiction = 'mo';

  /// Open States base URL
  static const String openstatesBaseUrl = 'https://openstates.org';

  /// Chamber options
  static const Map<String, String> chambers = {
    'lower': 'House',
    'upper': 'Senate',
  };

  /// Bill classification types
  static const Map<String, String> billClassifications = {
    'bill': 'Bill',
    'resolution': 'Resolution',
    'joint_resolution': 'Joint Resolution',
    'concurrent_resolution': 'Concurrent Resolution',
    'memorial': 'Memorial',
  };

  /// Position colors
  static const Map<String, Color> positionColors = {
    'support': Color(0xFF22C55E),
    'oppose': Color(0xFFEF4444),
    'watching': Color(0xFF3B82F6),
    'neutral': Color(0xFF6B7280),
  };

  /// Priority colors
  static const Map<String, Color> priorityColors = {
    'critical': Color(0xFFDC2626),
    'high': Color(0xFFF97316),
    'medium': Color(0xFFEAB308),
    'low': Color(0xFF22C55E),
  };

  /// Action classification colors
  static const Map<String, Color> actionClassificationColors = {
    'passage': Color(0xFF22C55E),
    'veto': Color(0xFFEF4444),
    'executive-signature': Color(0xFF8B5CF6),
    'became-law': Color(0xFF06B6D4),
    'reading-1': Color(0xFF3B82F6),
    'reading-2': Color(0xFF3B82F6),
    'reading-3': Color(0xFF3B82F6),
    'committee-referral': Color(0xFFF97316),
    'committee-passage': Color(0xFF22C55E),
    'amendment': Color(0xFFEAB308),
  };

  /// Party colors
  static const Map<String, Color> partyColors = {
    'Democratic': Color(0xFF3B82F6),
    'Republican': Color(0xFFEF4444),
    'Independent': Color(0xFF8B5CF6),
    'Other': Color(0xFF6B7280),
  };

  /// Note type colors
  static const Map<String, Color> noteTypeColors = {
    'general': Color(0xFF6B7280),
    'analysis': Color(0xFF3B82F6),
    'talking_point': Color(0xFF8B5CF6),
    'action_item': Color(0xFFF97316),
    'meeting_note': Color(0xFF22C55E),
  };

  /// Sync interval (how often to auto-sync in hours)
  static const int syncIntervalHours = 6;

  /// Maximum bills to sync per run
  static const int maxBillsPerSync = 50;

  /// API rate limit (requests per day)
  static const int apiRateLimitPerDay = 500;

  /// Default page size for searches
  static const int defaultPageSize = 20;

  /// Maximum search results to display
  static const int maxSearchResults = 100;
}

/// Bill status stages
enum BillStage {
  introduced('Introduced', Icons.post_add, Color(0xFF6B7280)),
  inCommittee('In Committee', Icons.groups, Color(0xFFF97316)),
  passedLower('Passed House', Icons.check_circle_outline, Color(0xFF3B82F6)),
  passedUpper('Passed Senate', Icons.check_circle_outline, Color(0xFF8B5CF6)),
  sentToGovernor('Sent to Governor', Icons.send, Color(0xFFEAB308)),
  signed('Signed into Law', Icons.verified, Color(0xFF22C55E)),
  vetoed('Vetoed', Icons.cancel, Color(0xFFEF4444)),
  failed('Failed', Icons.close, Color(0xFF6B7280));

  const BillStage(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

/// Missouri legislative districts
class MissouriDistricts {
  MissouriDistricts._();

  /// Number of House districts
  static const int houseDistricts = 163;

  /// Number of Senate districts
  static const int senateDistricts = 34;

  /// Congressional districts
  static const int congressionalDistricts = 8;
}
