import 'dart:async';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/message_filter.dart';

import 'member_repository.dart';
import 'supabase_service.dart';

/// Bridge between CRM and BlueBubbles messaging
/// Handles bulk messaging by creating individual chats
class CRMMessageService {
  final MemberRepository _memberRepo = MemberRepository();

  // Rate limiting
  static const int messagesPerMinute = CRMConfig.messagesPerMinute;
  static const Duration delayBetweenMessages = CRMConfig.messageDelay;

  bool get _isReady => CRMSupabaseService().isInitialized && CRMConfig.crmEnabled;

  /// Get filtered members for messaging
  Future<List<Member>> getFilteredMembers(MessageFilter filter) async {
    if (!_isReady) return [];

    try {
      var members = await _memberRepo.getAllMembers(
        county: filter.county,
        congressionalDistrict: filter.congressionalDistrict,
        committees: filter.committees,
        minAge: filter.minAge,
        maxAge: filter.maxAge,
        optedOut: filter.excludeOptedOut ? false : null,
      );

      if (filter.excludeRecentlyContacted) {
        final threshold = DateTime.now().subtract(
          filter.recentContactThreshold ?? const Duration(days: 7),
        );
        members = members.where((m) {
          return m.lastContacted == null || m.lastContacted!.isBefore(threshold);
        }).toList();
      }

      members = members.where((m) => m.canContact).toList();

      return members;
    } catch (e) {
      print('❌ Error getting filtered members: $e');
      return [];
    }
  }

  /// Send individual messages to filtered members
  /// Returns: Map of member ID to success/failure status
  Future<Map<String, bool>> sendBulkMessages({
    required MessageFilter filter,
    required String messageText,
    Function(int current, int total)? onProgress,
  }) async {
    final results = <String, bool>{};

    if (!_isReady) {
      print('⚠️ CRM messaging not initialized');
      return results;
    }

    try {
      final members = await getFilteredMembers(filter);
      final total = members.length;

      if (total == 0) {
        print('⚠️ No members match the filter criteria');
        return results;
      }

      print('📤 Sending messages to $total members...');

      for (int i = 0; i < members.length; i++) {
        final member = members[i];

        try {
          final success = await _sendSingleMessage(
            phoneNumber: member.phoneE164!,
            message: messageText,
          );

          results[member.id] = success;

          if (success) {
            await _memberRepo.updateLastContacted(member.id);
          }

          onProgress?.call(i + 1, total);

          if (i < members.length - 1) {
            await Future.delayed(delayBetweenMessages);
          }
        } catch (e) {
          print('❌ Failed to send message to ${member.name}: $e');
          results[member.id] = false;
        }
      }

      final successCount = results.values.where((v) => v).length;
      print('✅ Successfully sent $successCount/$total messages');

      return results;
    } catch (e) {
      print('❌ Error in bulk message sending: $e');
      return results;
    }
  }

  /// PLACEHOLDER: Send single message via BlueBubbles
  /// TODO: Replace this with actual BlueBubbles API call
  Future<bool> _sendSingleMessage({
    required String phoneNumber,
    required String message,
  }) async {
    // IMPLEMENTATION NEEDED:
    // 1. Find or create Handle for this phone number in BlueBubbles
    // 2. Find or create Chat for this Handle
    // 3. Use existing BlueBubbles sendMessage() API
    // 4. Return true if successful, false otherwise

    print('📨 Would send to $phoneNumber: $message');

    await Future.delayed(const Duration(milliseconds: 100));

    return true;
  }

  /// Preview: Get count of members that would receive message
  Future<int> previewBulkMessage(MessageFilter filter) async {
    final members = await getFilteredMembers(filter);
    return members.length;
  }

  /// Get member info for a phone number (for displaying in chat)
  Future<Member?> getMemberByPhone(String phoneE164) async {
    return await _memberRepo.getMemberByPhone(phoneE164);
  }
}
