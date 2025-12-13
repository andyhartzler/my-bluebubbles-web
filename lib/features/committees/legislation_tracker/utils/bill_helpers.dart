import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tracked_bill.dart';
import '../models/bill_action.dart';
import 'legislation_constants.dart';

/// Helper functions for bill-related operations
class BillHelpers {
  BillHelpers._();

  /// Format a date for display
  static String formatDate(DateTime? date, {String fallback = 'N/A'}) {
    if (date == null) return fallback;
    return DateFormat('MMM d, yyyy').format(date);
  }

  /// Format a date with time
  static String formatDateTime(DateTime? date, {String fallback = 'N/A'}) {
    if (date == null) return fallback;
    return DateFormat('MMM d, yyyy h:mm a').format(date);
  }

  /// Format a relative time (e.g., "2 days ago")
  static String formatRelativeTime(DateTime? date, {String fallback = 'N/A'}) {
    if (date == null) return fallback;

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      }
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months == 1 ? '' : 's'} ago';
    } else {
      return formatDate(date);
    }
  }

  /// Get chamber display name
  static String getChamberName(String? chamber) {
    if (chamber == null) return 'Unknown';
    return LegislationConstants.chambers[chamber.toLowerCase()] ?? chamber;
  }

  /// Get party abbreviation
  static String getPartyAbbreviation(String? party) {
    if (party == null) return '?';
    switch (party.toLowerCase()) {
      case 'democratic':
        return 'D';
      case 'republican':
        return 'R';
      case 'independent':
        return 'I';
      default:
        return party.isNotEmpty ? party[0].toUpperCase() : '?';
    }
  }

  /// Get party color
  static Color getPartyColor(String? party) {
    if (party == null) return LegislationConstants.partyColors['Other']!;
    return LegislationConstants.partyColors[party] ??
        LegislationConstants.partyColors['Other']!;
  }

  /// Get position color
  static Color getPositionColor(String position) {
    return LegislationConstants.positionColors[position] ??
        LegislationConstants.positionColors['watching']!;
  }

  /// Get priority color
  static Color getPriorityColor(String priority) {
    return LegislationConstants.priorityColors[priority] ??
        LegislationConstants.priorityColors['medium']!;
  }

  /// Get current bill stage
  static BillStage getBillStage(TrackedBill bill) {
    if (bill.vetoed) return BillStage.vetoed;
    if (bill.signedByGovernor) return BillStage.signed;
    if (bill.passedUpper && bill.passedLower) return BillStage.sentToGovernor;
    if (bill.passedUpper) return BillStage.passedUpper;
    if (bill.passedLower) return BillStage.passedLower;

    // Check latest action for committee status
    // This is a simplified check - could be enhanced
    return BillStage.introduced;
  }

  /// Get action icon
  static IconData getActionIcon(List<String> classifications) {
    for (final classification in classifications) {
      switch (classification.toLowerCase()) {
        case 'passage':
          return Icons.check_circle;
        case 'veto':
          return Icons.cancel;
        case 'executive-signature':
          return Icons.edit_document;
        case 'became-law':
          return Icons.verified;
        case 'reading-1':
        case 'reading-2':
        case 'reading-3':
          return Icons.menu_book;
        case 'committee-referral':
          return Icons.send;
        case 'committee-passage':
          return Icons.thumb_up;
        case 'amendment':
          return Icons.edit;
        case 'introduction':
          return Icons.post_add;
      }
    }
    return Icons.circle_outlined;
  }

  /// Get action color
  static Color getActionColor(List<String> classifications) {
    for (final classification in classifications) {
      final color = LegislationConstants.actionClassificationColors[classification.toLowerCase()];
      if (color != null) return color;
    }
    return Colors.grey;
  }

  /// Check if action is significant
  static bool isSignificantAction(BillAction action) {
    final significantClassifications = [
      'passage',
      'veto',
      'executive-signature',
      'became-law',
    ];

    return action.actionClassification.any(
      (c) => significantClassifications.contains(c.toLowerCase()),
    );
  }

  /// Build Open States URL for a bill
  static String buildOpenstatesUrl({
    required String session,
    required String billIdentifier,
    String jurisdiction = 'mo',
  }) {
    final cleanIdentifier = billIdentifier.replaceAll(' ', '-');
    return '${LegislationConstants.openstatesBaseUrl}/$jurisdiction/bills/$session/$cleanIdentifier/';
  }

  /// Parse bill identifier to get chamber
  static String? parseChamberfromIdentifier(String identifier) {
    final upper = identifier.toUpperCase();
    if (upper.startsWith('HB') ||
        upper.startsWith('HR') ||
        upper.startsWith('HCR') ||
        upper.startsWith('HJR')) {
      return 'lower';
    }
    if (upper.startsWith('SB') ||
        upper.startsWith('SR') ||
        upper.startsWith('SCR') ||
        upper.startsWith('SJR')) {
      return 'upper';
    }
    return null;
  }

  /// Get bill type from identifier
  static String getBillType(String identifier) {
    final upper = identifier.toUpperCase();
    if (upper.contains('JR')) return 'Joint Resolution';
    if (upper.contains('CR')) return 'Concurrent Resolution';
    if (upper.contains('R')) return 'Resolution';
    if (upper.contains('B')) return 'Bill';
    return 'Bill';
  }

  /// Truncate text with ellipsis
  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  /// Format vote count for display
  static String formatVoteCount({
    required int yes,
    required int no,
    int? abstain,
    int? notVoting,
  }) {
    final parts = <String>['$yes-$no'];
    final other = (abstain ?? 0) + (notVoting ?? 0);
    if (other > 0) {
      parts.add('$other other');
    }
    return parts.join(', ');
  }

  /// Get vote result color
  static Color getVoteResultColor(String result) {
    return result.toLowerCase() == 'pass' ? Colors.green : Colors.red;
  }

  /// Calculate vote margin
  static int calculateVoteMargin({required int yes, required int no}) {
    return yes - no;
  }

  /// Check if bill matches search query
  static bool matchesSearch(TrackedBill bill, String query) {
    if (query.isEmpty) return true;

    final lowerQuery = query.toLowerCase();
    return bill.billIdentifier.toLowerCase().contains(lowerQuery) ||
        bill.title.toLowerCase().contains(lowerQuery) ||
        (bill.description?.toLowerCase().contains(lowerQuery) ?? false) ||
        (bill.primarySponsorName?.toLowerCase().contains(lowerQuery) ?? false) ||
        bill.categories.any((c) => c.toLowerCase().contains(lowerQuery)) ||
        bill.tags.any((t) => t.toLowerCase().contains(lowerQuery));
  }

  /// Sort bills by priority (critical first)
  static int compareBillsByPriority(TrackedBill a, TrackedBill b) {
    final priorityOrder = {'critical': 1, 'high': 2, 'medium': 3, 'low': 4};
    final aPriority = priorityOrder[a.priority] ?? 5;
    final bPriority = priorityOrder[b.priority] ?? 5;
    return aPriority.compareTo(bPriority);
  }

  /// Sort bills by latest action date (most recent first)
  static int compareBillsByDate(TrackedBill a, TrackedBill b) {
    final aDate = a.latestActionDate ?? DateTime(1900);
    final bDate = b.latestActionDate ?? DateTime(1900);
    return bDate.compareTo(aDate);
  }
}
