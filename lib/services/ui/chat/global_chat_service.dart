import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/backend/web/listeners.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

// ignore: library_private_types_in_public_api, non_constant_identifier_names
_GlobalChatService GlobalChatService = Get.isRegistered<_GlobalChatService>() ? Get.find<_GlobalChatService>() : Get.put(_GlobalChatService());

class _GlobalChatService extends GetxService {
  final RxInt _unreadCount = 0.obs;
  final Map<String, RxBool> _unreadCountMap = <String, RxBool>{}.obs;
  final Map<String, RxnString> _muteTypeMap = <String, RxnString>{}.obs;

  RxInt get unreadCount => _unreadCount;

  RxBool unreadState(String chatGuid) {
    final map = _unreadCountMap[chatGuid];
    if (map == null) {
      _unreadCountMap[chatGuid] = false.obs;
      return _unreadCountMap[chatGuid]!;
    }

    return map;
  }

  RxnString muteState(String chatGuid) {
    final map = _muteTypeMap[chatGuid];
    if (map == null) {
      _muteTypeMap[chatGuid] = RxnString();
      return _muteTypeMap[chatGuid]!;
    }

    return map;
  }

  @override
  void onInit() {
    super.onInit();
    watchChats();
  }

  void watchChats() {
    if (kIsWeb) {
      void handle(Chat chat) => updateFromChat(chat);

      WebListeners.chatUpdate.listen(handle);
      WebListeners.newChat.listen(handle);
      return;
    }

    final query = Database.chats.query().watch(triggerImmediately: true);
    query.listen((event) {
      final chats = event.find();

      // Detect changes and make updates
      _evaluateUnreadInfo(chats);
      _evaluateMuteInfo(chats);
    });
  }

  void updateFromChat(Chat chat) {
    _updateUnreadEntry(chat);
    _updateMuteEntry(chat);
    _recalculateUnreadTotal();
  }

  void removeChatState(String chatGuid) {
    final removedUnread = _unreadCountMap.remove(chatGuid);
    _muteTypeMap.remove(chatGuid);

    if (removedUnread != null) {
      _recalculateUnreadTotal();
    }
  }

  void _evaluateUnreadInfo(List<Chat> chats) {
    final guids = chats.map((chat) => chat.guid).toSet();
    final stale = _unreadCountMap.keys.where((key) => !guids.contains(key)).toList();
    for (final guid in stale) {
      _unreadCountMap.remove(guid);
    }
    for (final chat in chats) {
      _updateUnreadEntry(chat);
    }
    _recalculateUnreadTotal();
  }

  void _evaluateMuteInfo(List<Chat> chats) {
    final guids = chats.map((chat) => chat.guid).toSet();
    final stale = _muteTypeMap.keys.where((key) => !guids.contains(key)).toList();
    for (final guid in stale) {
      _muteTypeMap.remove(guid);
    }
    for (final chat in chats) {
      _updateMuteEntry(chat);
    }
  }

  void _updateUnreadEntry(Chat chat) {
    final bool unread = chat.hasUnreadMessage ?? false;
    final RxBool? currentUnreadStatus = _unreadCountMap[chat.guid];

    if (currentUnreadStatus == null) {
      _unreadCountMap[chat.guid] = RxBool(unread);
    } else if (currentUnreadStatus.value != unread) {
      Logger.debug(
        "Updating Chat (${chat.guid}) Unread Status from ${currentUnreadStatus.value} to $unread",
      );
      currentUnreadStatus.value = unread;
    }
  }

  void _updateMuteEntry(Chat chat) {
    final Rx<String?>? currentMuteStatus = _muteTypeMap[chat.guid];

    if (currentMuteStatus == null) {
      final rx = RxnString();
      rx.value = chat.muteType;
      _muteTypeMap[chat.guid] = rx;
    } else if (currentMuteStatus.value != chat.muteType) {
      Logger.debug(
        "Updating Chat (${chat.guid}) Mute Type from ${currentMuteStatus.value} to ${chat.muteType}",
      );
      currentMuteStatus.value = chat.muteType;
    }
  }

  void _recalculateUnreadTotal() {
    unreadCount.value = _unreadCountMap.values.where((element) => element.value).length;
  }
}
