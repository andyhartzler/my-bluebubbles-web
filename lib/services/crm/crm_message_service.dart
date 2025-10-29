import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/types/helpers/string_helpers.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/message_filter.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/utils/string_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:slugify/slugify.dart';

import 'member_repository.dart';
import 'supabase_service.dart';

/// Bridge between CRM and BlueBubbles messaging
/// Handles bulk messaging by creating individual chats
class CRMMessageService {
  final MemberRepository _memberRepo = MemberRepository();

  // Rate limiting
  static const int messagesPerMinute = CRMConfig.messagesPerMinute;
  static const Duration delayBetweenMessages = CRMConfig.messageDelay;

  static const String _introMessage =
      'Hi! Thanks for connecting with MO Young Democrats.\n\nTap the contact card below to save our info.\n\nReply STOP to opt out of future messages.';
  static const String _stopResponse =
      'You have been unsubscribed from Missouri Young Democrats updates. Reply START at any time to opt back in.';

  bool get _isReady => CRMSupabaseService().isInitialized && CRMConfig.crmEnabled;

  /// Get filtered members for messaging
  Future<List<Member>> getFilteredMembers(MessageFilter filter) async {
    if (!_isReady) return [];

    try {
      var members = await _memberRepo.getAllMembers(
        county: filter.county,
        congressionalDistrict: filter.congressionalDistrict,
        committees: filter.committees,
        schoolName: filter.schoolName,
        chapterName: filter.chapterName,
        chapterStatus: filter.chapterStatus,
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
    bool includeContactCard = false,
    bool markIntro = false,
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
            includeContactCard: includeContactCard,
          );

          results[member.id] = success;

          if (success) {
            await _memberRepo.updateLastContacted(member.id);
            if (markIntro) {
              await _memberRepo.markIntroSent(member.id);
            }
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

  Future<bool> sendIntroToMember(Member member) async {
    if (!_isReady || !member.canContact) return false;

    final success = await _sendSingleMessage(
      phoneNumber: member.phoneE164!,
      message: _introMessage,
      includeContactCard: true,
    );

    if (success) {
      await _memberRepo.updateLastContacted(member.id);
      await _memberRepo.markIntroSent(member.id);
    }

    return success;
  }

  Future<Map<String, bool>> sendIntroToFilteredMembers(MessageFilter filter,
      {Function(int current, int total)? onProgress}) async {
    return await sendBulkMessages(
      filter: filter,
      messageText: _introMessage,
      includeContactCard: true,
      markIntro: true,
      onProgress: onProgress,
    );
  }

  Future<void> handleIncomingAutomation(Chat chat, Message message) async {
    if (!_isReady) return;
    if (message.isFromMe ?? true) return;

    final text = message.text?.trim();
    if (text == null || text.isEmpty) return;

    final normalized = text.toUpperCase();
    if (normalized != 'STOP' && normalized != 'START') {
      return;
    }

    final address = message.handle?.address;
    if (address == null || address.isEmpty) return;

    final member = await _memberRepo.getMemberByPhone(address);
    if (member == null) return;

    if (normalized == 'STOP') {
      if (member.optOut) return;
      await _memberRepo.updateOptOutStatus(member.id, true, reason: 'STOP keyword');
      unawaited(_sendSingleMessage(phoneNumber: address, message: _stopResponse));
    } else if (normalized == 'START') {
      if (!member.optOut) return;
      await _memberRepo.updateOptOutStatus(member.id, false);
      const response =
          'Welcome back! You are opted in to Missouri Young Democrats messages again.';
      unawaited(_sendSingleMessage(phoneNumber: address, message: response));
    }
  }

  Future<bool> _sendSingleMessage({
    required String phoneNumber,
    required String message,
    bool includeContactCard = false,
  }) async {
    if (phoneNumber.isEmpty) return false;

    final cleaned = phoneNumber.contains('@') ? phoneNumber : cleansePhoneNumber(phoneNumber);
    Chat? chat = await _findExistingChat(cleaned);
    bool sentViaCreateChat = false;

    try {
      if (chat == null) {
        final service = await _determineService(cleaned);
        final response = await http.createChat([cleaned], message, service);
        var created = Chat.fromMap(response.data['data']);
        created = created.save();
        final saved = await cm.fetchChat(created.guid) ?? created;
        chat = saved;
        sentViaCreateChat = true;
      }

      if (chat == null) return false;

      if (!sentViaCreateChat) {
        final msg = Message(
          text: message,
          dateCreated: DateTime.now(),
          isFromMe: true,
          hasAttachments: false,
          handleId: 0,
        );
        msg.chat.target = chat;
        await outq.queue(OutgoingItem(
          type: QueueType.sendMessage,
          chat: chat,
          message: msg,
        ));
      }

      if (includeContactCard) {
        await _sendContactCard(chat);
      }

      return true;
    } catch (e, stack) {
      Logger.error('Failed to send CRM message', error: e, trace: stack);
      return false;
    }
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

  Future<Chat?> _findExistingChat(String address) async {
    try {
      final slug = slugify(address, delimiter: '');
      if (kIsWeb) {
        return await Chat.findOneWeb(chatIdentifier: slug);
      }
      return Chat.findOne(chatIdentifier: slug);
    } catch (_) {
      return null;
    }
  }

  Future<String> _determineService(String address) async {
    if (address.contains('@')) return 'iMessage';

    try {
      final response = await http.handleiMessageState(address);
      final available = response.data['data']['available'] as bool? ?? false;
      return available ? 'iMessage' : 'SMS';
    } catch (_) {
      return 'iMessage';
    }
  }

  Future<void> _sendContactCard(Chat chat) async {
    try {
      final bytes = await _buildContactCard();
      final attachmentGuid = 'temp-${randomString(8)}';
      final message = Message(
        guid: attachmentGuid,
        text: '',
        dateCreated: DateTime.now(),
        hasAttachments: true,
        isFromMe: true,
        handleId: 0,
        attachments: [
          Attachment(
            guid: attachmentGuid,
            mimeType: 'text/vcard',
            uti: 'public.vcard',
            isOutgoing: true,
            transferName: 'MOYDA Contact.vcf',
            totalBytes: bytes.length,
            bytes: bytes,
          ),
        ],
      );

      message.chat.target = chat;

      await outq.queue(OutgoingItem(
        type: QueueType.sendAttachment,
        chat: chat,
        message: message,
      ));
    } catch (e) {
      Logger.warn('Unable to send contact card', error: e);
    }
  }

  Future<Uint8List> _buildContactCard() async {
    final buffer = StringBuffer()
      ..writeln('BEGIN:VCARD')
      ..writeln('VERSION:3.0')
      ..writeln('FN:Missouri Young Democrats')
      ..writeln('ORG:Missouri Young Democrats')
      ..writeln('TEL;TYPE=WORK,VOICE:+18165300773')
      ..writeln('EMAIL;TYPE=WORK:info@moyoungdemocrats.org')
      ..writeln('ADR;TYPE=WORK:;;PO Box 270043;Kansas City;MO;64127;USA')
      ..writeln('URL:https://moyoungdemocrats.org');

    try {
      final data = await rootBundle.load('assets/icon/contact-photo.png');
      final encoded = base64Encode(data.buffer.asUint8List());
      buffer.writeln('PHOTO;ENCODING=b;TYPE=PNG:$encoded');
    } catch (_) {
      // Ignore missing asset
    }

    buffer
      ..writeln('END:VCARD')
      ..writeln();

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }
}
