import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/database/global/queue_items.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/types/helpers/string_helpers.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/message_filter.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/utils/string_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:mime_type/mime_type.dart';
import 'package:slugify/slugify.dart';
import 'package:universal_io/io.dart';

import 'member_repository.dart';
import 'supabase_service.dart';

/// Bridge between CRM and BlueBubbles messaging
/// Handles bulk messaging by creating individual chats
class CRMMessageService {
  final MemberRepository _memberRepo = MemberRepository();
  final Map<String, String> _serviceCache = {};
  final LinkedHashMap<String, DateTime> _automationGuardCache = LinkedHashMap();

  // Rate limiting
  static const int messagesPerMinute = CRMConfig.messagesPerMinute;
  static const Duration delayBetweenMessages = CRMConfig.messageDelay;
  static const int _automationGuardCacheLimit = 200;
  static const Duration _automationGuardCacheTtl = Duration(minutes: 10);

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
        highSchool: filter.highSchool,
        college: filter.college,
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
    List<Member>? explicitMembers,
    List<file_picker.PlatformFile> attachments = const [],
  }) async {
    final results = <String, bool>{};

    if (!_isReady) {
      print('⚠️ CRM messaging not initialized');
      return results;
    }

    try {
      final members = await _resolveRecipients(
        filter,
        explicitMembers: explicitMembers,
        excludeIntroRecipients: markIntro,
      );
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
            attachments: attachments,
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
      attachments: const [],
    );

    if (success) {
      await _memberRepo.updateLastContacted(member.id);
      await _memberRepo.markIntroSent(member.id);
    }

    return success;
  }

  Future<Map<String, bool>> sendIntroToFilteredMembers(
    MessageFilter filter, {
    Function(int current, int total)? onProgress,
    List<Member>? explicitMembers,
  }) async {
    return await sendBulkMessages(
      filter: filter,
      messageText: _introMessage,
      includeContactCard: true,
      markIntro: true,
      onProgress: onProgress,
      explicitMembers: explicitMembers,
      attachments: const [],
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

    final cacheKey = _buildAutomationCacheKey(chat, message, normalized);
    if (cacheKey != null && _shouldSkipAutomation(cacheKey)) {
      return;
    }

    final member = await _memberRepo.getMemberByPhone(address);
    if (member == null) return;

    if (normalized == 'STOP') {
      if (member.optOut) return;
      await _memberRepo.updateOptOutStatus(member.id, true, reason: 'STOP keyword');
      await _sendSingleMessage(phoneNumber: address, message: _stopResponse);
    } else if (normalized == 'START') {
      if (!member.optOut) return;
      await _memberRepo.updateOptOutStatus(member.id, false);
      const response =
          'Welcome back! You are now opted in to Missouri Young Democrats messages.';
      await _sendSingleMessage(phoneNumber: address, message: response);
    }
  }

  String? _buildAutomationCacheKey(Chat chat, Message message, String normalized) {
    final guid = message.guid;
    if (guid != null && guid.isNotEmpty) {
      return guid;
    }

    final chatGuid = chat.guid;
    if (chatGuid != null && chatGuid.isNotEmpty) {
      return '$chatGuid|$normalized';
    }

    final handleAddress = message.handle?.address;
    if (handleAddress != null && handleAddress.isNotEmpty) {
      return '$handleAddress|$normalized';
    }

    return null;
  }

  bool _shouldSkipAutomation(String key) {
    final now = DateTime.now();

    _pruneAutomationCache(now);

    final existing = _automationGuardCache[key];
    if (existing != null && now.difference(existing) < _automationGuardCacheTtl) {
      return true;
    }

    _automationGuardCache[key] = now;
    _enforceAutomationCacheLimit();
    return false;
  }

  void _pruneAutomationCache(DateTime now) {
    final expiredKeys = <String>[];
    _automationGuardCache.forEach((key, timestamp) {
      if (now.difference(timestamp) >= _automationGuardCacheTtl) {
        expiredKeys.add(key);
      }
    });

    for (final key in expiredKeys) {
      _automationGuardCache.remove(key);
    }
  }

  void _enforceAutomationCacheLimit() {
    while (_automationGuardCache.length > _automationGuardCacheLimit) {
      final oldestKey = _automationGuardCache.keys.first;
      _automationGuardCache.remove(oldestKey);
    }
  }

  Future<bool> _sendSingleMessage({
    required String phoneNumber,
    required String message,
    bool includeContactCard = false,
    List<file_picker.PlatformFile> attachments = const [],
  }) async {
    if (phoneNumber.isEmpty) return false;

    final cleaned = phoneNumber.contains('@') ? phoneNumber : cleansePhoneNumber(phoneNumber);
    Chat? chat = await _findExistingChat(cleaned);
    bool sentViaCreate = false;

    if (chat == null) {
      final service = await _determineService(cleaned);
      try {
        final response = await http.createChat([cleaned], message, service);
        sentViaCreate = true;
        final body = response.data;
        Map<String, dynamic>? payload;
        if (body is Map<String, dynamic>) {
          final raw = body['data'];
          if (raw is Map<String, dynamic>) {
            payload = raw;
          }
        }
        if (payload != null) {
          try {
            var created = Chat.fromMap(payload);
            created = created.save();
            try {
              await chats.addChat(created);
            } catch (_) {}
            chat = created;
          } catch (e, stack) {
            Logger.warn('Unable to register created chat locally for $cleaned', error: e, trace: stack);
          }
        }
      } catch (e, stack) {
        Logger.warn('Failed to create chat for $cleaned via API, attempting fallback send', error: e, trace: stack);
        chat = await _waitForChat(cleaned);
        if (chat == null) {
          return false;
        }
        final queued = await _queueTextMessage(chat, message);
        if (!queued) {
          return false;
        }
      }
    }

    if (!sentViaCreate) {
      chat ??= await _waitForChat(cleaned);
      if (chat == null) {
        return false;
      }
      if (message.trim().isNotEmpty) {
        final queued = await _queueTextMessage(chat, message);
        if (!queued) {
          return false;
        }
      }
    }

    final readyChat = await _waitForChat(cleaned, seed: chat);
    if (readyChat == null) {
      Logger.warn('Queued CRM message but could not confirm chat for $cleaned');
      return true;
    }

    if (attachments.isNotEmpty) {
      final sentAttachments = await _sendAttachments(readyChat, attachments);
      if (!sentAttachments) {
        return false;
      }
    }

    if (includeContactCard) {
      final sent = await _sendContactCardForAddress(cleaned, readyChat);
      if (!sent) {
        Logger.warn('Unable to send CRM contact card for $cleaned');
      }
    }

    return true;
  }

  /// Preview: Get count of members that would receive message
  Future<int> previewBulkMessage(
    MessageFilter filter, {
    List<Member>? explicitMembers,
  }) async {
    final members = await _resolveRecipients(
      filter,
      explicitMembers: explicitMembers,
      excludeIntroRecipients: false,
    );
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
    if (address.contains('@')) {
      _serviceCache[address] = 'iMessage';
      return 'iMessage';
    }

    final cached = _serviceCache[address];
    if (cached != null) {
      return cached;
    }

    try {
      final response = await http.handleiMessageState(address);
      final available = response.data['data']['available'] as bool? ?? false;
      final service = available ? 'iMessage' : 'SMS';
      _serviceCache[address] = service;
      return service;
    } catch (_) {
      // Default to SMS when availability cannot be determined for phone numbers
      final fallback = address.contains('@') ? 'iMessage' : 'SMS';
      _serviceCache[address] = fallback;
      return fallback;
    }
  }

  Future<Map<String, int>> previewTransportBreakdown(List<Member> members) async {
    final counts = <String, int>{'iMessage': 0, 'SMS': 0};
    final futures = <Future<void>>[];

    for (final member in members) {
      final address = member.phoneE164 ?? member.phone;
      if (address == null || address.isEmpty) {
        continue;
      }

      futures.add(() async {
        final normalized = address.contains('@') ? address : cleansePhoneNumber(address);
        final service = await _determineService(normalized);
        counts[service] = (counts[service] ?? 0) + 1;
      }());
    }

    await Future.wait(futures);
    counts.removeWhere((key, value) => value == 0);
    return counts;
  }

  Future<bool> _sendContactCardForAddress(String cleaned, Chat? initialChat) async {
    try {
      final chat = await _waitForChat(cleaned, seed: initialChat);
      if (chat == null) {
        Logger.warn('Unable to locate chat for $cleaned to send contact card');
        return false;
      }

      final message = await _buildContactCardMessage(chat);
      await outq.queue(OutgoingItem(
        type: QueueType.sendAttachment,
        chat: chat,
        message: message,
        customArgs: {'audio': false},
      ));
      return true;
    } catch (e, stack) {
      Logger.warn('Unable to send contact card', error: e, trace: stack);
      return false;
    }
  }

  Future<Message> _buildContactCardMessage(Chat chat) async {
    final bytes = await _buildContactCardBytes();
    final message = Message(
      text: '',
      dateCreated: DateTime.now(),
      hasAttachments: true,
      isFromMe: true,
      handleId: 0,
      attachments: [
        Attachment(
          mimeType: 'text/x-vcard',
          uti: 'public.vcard',
          isOutgoing: true,
          transferName: 'Missouri Young Democrats.vcf',
          totalBytes: bytes.length,
          bytes: bytes,
        ),
      ],
    );

    message.chat.target = chat;
    message.generateTempGuid();
    final attachment = message.attachments.first;
    if (attachment != null) {
      attachment.guid = message.guid;
      attachment.bytes = bytes;
      attachment.totalBytes = bytes.length;
    }
    return message;
  }

  Future<Chat?> _waitForChat(String cleaned, {Chat? seed}) async {
    var chat = seed ?? await _findExistingChat(cleaned);
    if (chat != null) return chat;

    for (var attempt = 0; attempt < 8; attempt++) {
      await Future.delayed(Duration(milliseconds: 200 * (attempt + 1)));
      chat = await _findExistingChat(cleaned);
      if (chat != null) {
        return chat;
      }
    }

    return await _pullChatForAddress(cleaned);
  }

  Future<bool> _queueTextMessage(Chat chat, String message) async {
    try {
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
      return true;
    } catch (e, stack) {
      Logger.error('Failed to queue CRM text message', error: e, trace: stack);
      return false;
    }
  }

  Future<Chat?> _pullChatForAddress(String cleaned) async {
    final slug = slugify(cleaned, delimiter: '');
    try {
      final response = await http.chats(withQuery: const ['participants'], limit: 50);
      final body = response.data;
      final data = body is Map<String, dynamic> ? body['data'] : null;
      if (data is List) {
        for (final entry in data) {
          if (entry is! Map<String, dynamic>) continue;
          final participants = entry['participants'];
          if (participants is! List) continue;
          final match = participants.any((participant) {
            if (participant is! Map<String, dynamic>) return false;
            final address = participant['address'] as String?;
            if (address == null) return false;
            return slugify(address, delimiter: '') == slug;
          });
          if (match) {
            try {
              var chat = Chat.fromMap(entry);
              chat = chat.save();
              try {
                await chats.addChat(chat);
              } catch (_) {}
              return chat;
            } catch (e, stack) {
              Logger.warn('Failed to hydrate chat metadata for $cleaned', error: e, trace: stack);
            }
          }
        }
      }
    } catch (e, stack) {
      Logger.warn('Failed to fetch chat list when locating $cleaned', error: e, trace: stack);
    }

    return null;
  }

  Future<Uint8List> _buildContactCardBytes() async {
    const newline = '\r\n';
    final lines = <String>[
      'BEGIN:VCARD',
      'VERSION:3.0',
      'N:;;;;',
      'FN:Missouri Young Democrats',
      'ORG:Missouri Young Democrats',
      'X-ABShowAs:COMPANY',
      'X-ABCompany:Missouri Young Democrats',
      'TEL;TYPE=WORK,VOICE:+18165300773',
      'EMAIL;TYPE=WORK,INTERNET:info@moyoungdemocrats.org',
      'ADR;TYPE=WORK:;;PO Box 270043;Kansas City;MO;64127;US',
      'URL:https://moyoungdemocrats.org',
    ];

    final photoLines = await _buildPhotoLines();
    if (photoLines != null) {
      lines.addAll(photoLines);
    }

    lines.add('END:VCARD');

    final buffer = StringBuffer();
    for (final line in lines) {
      buffer
        ..write(line)
        ..write(newline);
    }

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  Future<List<String>?> _buildPhotoLines() async {
    try {
      final data = await rootBundle.load('assets/icon/contact-photo.png');
      final encoded = base64Encode(data.buffer.asUint8List());
      return _foldVCardLine('PHOTO;ENCODING=b;TYPE=PNG:$encoded');
    } catch (_) {
      return null;
    }
  }

  List<String> _foldVCardLine(String line) {
    const maxLineLength = 75;
    if (line.length <= maxLineLength) {
      return [line];
    }

    final lines = <String>[];
    lines.add(line.substring(0, maxLineLength));

    var index = maxLineLength;
    while (index < line.length) {
      final remaining = line.length - index;
      final take = remaining > maxLineLength - 1 ? maxLineLength - 1 : remaining;
      final chunk = line.substring(index, index + take);
      lines.add(' $chunk');
      index += take;
    }

    return lines;
  }

  Future<List<Member>> _resolveRecipients(
    MessageFilter filter, {
    List<Member>? explicitMembers,
    bool excludeIntroRecipients = false,
  }) async {
    final combined = LinkedHashMap<String, Member>();

    void add(Member member) {
      if (!member.canContact) return;
      if (excludeIntroRecipients && member.introSentAt != null) return;
      final key = member.id ?? member.phoneE164 ?? member.phone;
      if (key == null) return;
      combined[key] = member;
    }

    if (filter.hasActiveFilters) {
      final filtered = await getFilteredMembers(filter);
      for (final member in filtered) {
        add(member);
      }
    }

    if (explicitMembers != null) {
      for (final member in explicitMembers) {
        add(member);
      }
    }

    return combined.values.toList();
  }

  Future<bool> _sendAttachments(Chat chat, List<file_picker.PlatformFile> attachments) async {
    for (final file in attachments) {
      try {
        final bytes = await _resolveFileBytes(file);
        if (bytes == null || bytes.isEmpty) {
          continue;
        }

        final name = file.name.isNotEmpty ? file.name : 'attachment';
        final ext = file.extension ?? '';
        final resolvedMime =
            mimeFromExtension(ext) ?? mime(name) ?? 'application/octet-stream';

        final attachment = Attachment(
          mimeType: resolvedMime,
          isOutgoing: true,
          uti: null,
          transferName: name,
          totalBytes: bytes.length,
          bytes: bytes,
        );

        final message = Message(
          text: '',
          dateCreated: DateTime.now(),
          hasAttachments: true,
          isFromMe: true,
          handleId: 0,
          attachments: [attachment],
        );

        message.chat.target = chat;
        message.generateTempGuid();
        attachment.guid = message.guid;
        attachment.totalBytes = bytes.length;
        attachment.bytes = bytes;

        await outq.queue(OutgoingItem(
          type: QueueType.sendAttachment,
          chat: chat,
          message: message,
          customArgs: const {'audio': false},
        ));
      } catch (e, stack) {
        Logger.warn('Failed to queue CRM attachment ${file.name}', error: e, trace: stack);
        return false;
      }
    }

    return true;
  }

  Future<Uint8List?> _resolveFileBytes(file_picker.PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes!;
    }

    final path = file.path;
    if (path != null && path.isNotEmpty && !kIsWeb) {
      try {
        return await File(path).readAsBytes();
      } catch (e, stack) {
        Logger.warn('Unable to read attachment bytes from $path', error: e, trace: stack);
      }
    }

    return null;
  }
}
