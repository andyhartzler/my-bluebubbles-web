import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:idb_shim/idb.dart' as idb;
import 'package:idb_shim/idb_browser.dart';
import 'package:bluebubbles/utils/logger/logger.dart';

/// Web Storage Service using IndexedDB for browser-based persistence
///
/// This service provides a comprehensive storage solution for the web platform,
/// replacing ObjectBox which is not available on web. It uses IndexedDB to store:
/// - Chat history
/// - Messages
/// - Attachments metadata
/// - User settings
/// - Cached data
///
/// Usage:
/// ```dart
/// await webStorage.init();
/// await webStorage.set('key', 'value');
/// final value = await webStorage.get('key');
/// ```
class WebStorageService {
  static const String _dbName = 'BlueBubbles.db';
  static const int _dbVersion = 2;

  // Object stores (similar to tables)
  static const String _storeGeneral = 'BBStore';
  static const String _storeMessages = 'Messages';
  static const String _storeChats = 'Chats';
  static const String _storeSettings = 'Settings';
  static const String _storeAttachments = 'Attachments';
  static const String _storeCache = 'Cache';

  late idb.Database _db;
  bool _initialized = false;
  final Completer<void> _initCompleter = Completer<void>();

  /// Initialize the web storage service
  /// This must be called before any other operations
  Future<void> init() async {
    if (_initialized) return;
    if (_initCompleter.isCompleted) {
      return _initCompleter.future;
    }

    try {
      Logger.info('Initializing Web Storage Service...');
      final idbFactory = idbFactoryBrowser;

      _db = await idbFactory.open(
        _dbName,
        version: _dbVersion,
        onUpgradeNeeded: _onUpgradeNeeded,
      );

      _initialized = true;
      _initCompleter.complete();
      Logger.info('Web Storage Service initialized successfully');
    } catch (e, stackTrace) {
      Logger.error('Failed to initialize Web Storage Service', error: e, trace: stackTrace);
      _initCompleter.completeError(e, stackTrace);
      rethrow;
    }
  }

  /// Handle database schema upgrades
  void _onUpgradeNeeded(idb.VersionChangeEvent event) {
    final db = (event.target as idb.OpenDBRequest).result;
    final oldVersion = event.oldVersion ?? 0;

    Logger.info('Upgrading database from version $oldVersion to ${event.newVersion}');

    // Create object stores if they don't exist
    if (!db.objectStoreNames.contains(_storeGeneral)) {
      db.createObjectStore(_storeGeneral);
      Logger.debug('Created object store: $_storeGeneral');
    }

    if (!db.objectStoreNames.contains(_storeMessages)) {
      final msgStore = db.createObjectStore(_storeMessages, keyPath: 'guid', autoIncrement: false);
      msgStore.createIndex('chatId', 'chatId', unique: false);
      msgStore.createIndex('dateCreated', 'dateCreated', unique: false);
      Logger.debug('Created object store: $_storeMessages');
    }

    if (!db.objectStoreNames.contains(_storeChats)) {
      final chatStore = db.createObjectStore(_storeChats, keyPath: 'guid', autoIncrement: false);
      chatStore.createIndex('lastMessageDate', 'lastMessageDate', unique: false);
      Logger.debug('Created object store: $_storeChats');
    }

    if (!db.objectStoreNames.contains(_storeSettings)) {
      db.createObjectStore(_storeSettings);
      Logger.debug('Created object store: $_storeSettings');
    }

    if (!db.objectStoreNames.contains(_storeAttachments)) {
      final attachStore = db.createObjectStore(_storeAttachments, keyPath: 'guid', autoIncrement: false);
      attachStore.createIndex('messageGuid', 'messageGuid', unique: false);
      Logger.debug('Created object store: $_storeAttachments');
    }

    if (!db.objectStoreNames.contains(_storeCache)) {
      final cacheStore = db.createObjectStore(_storeCache);
      Logger.debug('Created object store: $_storeCache');
    }
  }

  /// Ensure the service is initialized before operations
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }

  // ==================== GENERAL STORAGE OPERATIONS ====================

  /// Get a value from the general store
  Future<T?> get<T>(String key) async {
    await _ensureInitialized();
    try {
      final txn = _db.transaction(_storeGeneral, idb.idbModeReadOnly);
      final store = txn.objectStore(_storeGeneral);
      final value = await store.getObject(key);
      await txn.completed;
      return value as T?;
    } catch (e, stackTrace) {
      Logger.error('Failed to get value for key: $key', error: e, trace: stackTrace);
      return null;
    }
  }

  /// Set a value in the general store
  Future<void> set(String key, dynamic value) async {
    await _ensureInitialized();
    try {
      final txn = _db.transaction(_storeGeneral, idb.idbModeReadWrite);
      final store = txn.objectStore(_storeGeneral);
      await store.put(value, key);
      await txn.completed;
    } catch (e, stackTrace) {
      Logger.error('Failed to set value for key: $key', error: e, trace: stackTrace);
      rethrow;
    }
  }

  /// Delete a value from the general store
  Future<void> delete(String key) async {
    await _ensureInitialized();
    try {
      final txn = _db.transaction(_storeGeneral, idb.idbModeReadWrite);
      final store = txn.objectStore(_storeGeneral);
      await store.delete(key);
      await txn.completed;
    } catch (e, stackTrace) {
      Logger.error('Failed to delete value for key: $key', error: e, trace: stackTrace);
      rethrow;
    }
  }

  /// Clear all data from the general store
  Future<void> clear() async {
    await _ensureInitialized();
    try {
      final txn = _db.transaction(_storeGeneral, idb.idbModeReadWrite);
      final store = txn.objectStore(_storeGeneral);
      await store.clear();
      await txn.completed;
      Logger.info('Cleared general store');
    } catch (e, stackTrace) {
      Logger.error('Failed to clear general store', error: e, trace: stackTrace);
      rethrow;
    }
  }

  // ==================== MESSAGE OPERATIONS ====================

  /// Save a message to storage
  Future<void> saveMessage(Map<String, dynamic> message) async {
    await _ensureInitialized();
    try {
      final txn = _db.transaction(_storeMessages, idb.idbModeReadWrite);
      final store = txn.objectStore(_storeMessages);
      await store.put(message);
      await txn.completed;
    } catch (e, stackTrace) {
      Logger.error('Failed to save message', error: e, trace: stackTrace);
      rethrow;
    }
  }

  /// Save multiple messages in a batch
  Future<void> saveMessages(List<Map<String, dynamic>> messages) async {
    await _ensureInitialized();
    try {
      final txn = _db.transaction(_storeMessages, idb.idbModeReadWrite);
      final store = txn.objectStore(_storeMessages);
      for (final message in messages) {
        await store.put(message);
      }
      await txn.completed;
      Logger.debug('Saved ${messages.length} messages');
    } catch (e, stackTrace) {
      Logger.error('Failed to save messages batch', error: e, trace: stackTrace);
      rethrow;
    }
  }

  /// Get messages for a specific chat
  Future<List<Map<String, dynamic>>> getMessagesForChat(String chatId, {int? limit}) async {
    await _ensureInitialized();
    try {
      final txn = _db.transaction(_storeMessages, idb.idbModeReadOnly);
      final store = txn.objectStore(_storeMessages);
      final index = store.index('chatId');

      final messages = <Map<String, dynamic>>[];
      await index.openCursor(key: chatId, autoAdvance: true).listen((cursor) {
        if (cursor.value != null) {
          messages.add(cursor.value as Map<String, dynamic>);
        }
      }).asFuture();

      await txn.completed;

      // Sort by date and apply limit
      messages.sort((a, b) => (b['dateCreated'] ?? 0).compareTo(a['dateCreated'] ?? 0));
      if (limit != null && messages.length > limit) {
        return messages.sublist(0, limit);
      }

      return messages;
    } catch (e, stackTrace) {
      Logger.error('Failed to get messages for chat: $chatId', error: e, trace: stackTrace);
      return [];
    }
  }

  /// Delete a message
  Future<void> deleteMessage(String guid) async {
    await _ensureInitialized();
    try {
      final txn = _db.transaction(_storeMessages, idb.idbModeReadWrite);
      final store = txn.objectStore(_storeMessages);
      await store.delete(guid);
      await txn.completed;
    } catch (e, stackTrace) {
      Logger.error('Failed to delete message: $guid', error: e, trace: stackTrace);
      rethrow;
    }
  }

  // ==================== CHAT OPERATIONS ====================

  /// Save a chat to storage
  Future<void> saveChat(Map<String, dynamic> chat) async {
    await _ensureInitialized();
    try {
      final txn = _db.transaction(_storeChats, idb.idbModeReadWrite);
      final store = txn.objectStore(_storeChats);
      await store.put(chat);
      await txn.completed;
    } catch (e, stackTrace) {
      Logger.error('Failed to save chat', error: e, trace: stackTrace);
      rethrow;
    }
  }

  /// Get all chats
  Future<List<Map<String, dynamic>>> getAllChats() async {
    await _ensureInitialized();
    try {
      final txn = _db.transaction(_storeChats, idb.idbModeReadOnly);
      final store = txn.objectStore(_storeChats);

      final chats = <Map<String, dynamic>>[];
      await store.openCursor(autoAdvance: true).listen((cursor) {
        if (cursor.value != null) {
          chats.add(cursor.value as Map<String, dynamic>);
        }
      }).asFuture();

      await txn.completed;

      // Sort by last message date
      chats.sort((a, b) => (b['lastMessageDate'] ?? 0).compareTo(a['lastMessageDate'] ?? 0));

      return chats;
    } catch (e, stackTrace) {
      Logger.error('Failed to get all chats', error: e, trace: stackTrace);
      return [];
    }
  }

  /// Delete a chat
  Future<void> deleteChat(String guid) async {
    await _ensureInitialized();
    try {
      final txn = _db.transaction(_storeChats, idb.idbModeReadWrite);
      final store = txn.objectStore(_storeChats);
      await store.delete(guid);
      await txn.completed;
    } catch (e, stackTrace) {
      Logger.error('Failed to delete chat: $guid', error: e, trace: stackTrace);
      rethrow;
    }
  }

  // ==================== SETTINGS OPERATIONS ====================

  /// Get a setting value
  Future<T?> getSetting<T>(String key) async {
    await _ensureInitialized();
    try {
      final txn = _db.transaction(_storeSettings, idb.idbModeReadOnly);
      final store = txn.objectStore(_storeSettings);
      final value = await store.getObject(key);
      await txn.completed;
      return value as T?;
    } catch (e, stackTrace) {
      Logger.error('Failed to get setting: $key', error: e, trace: stackTrace);
      return null;
    }
  }

  /// Set a setting value
  Future<void> setSetting(String key, dynamic value) async {
    await _ensureInitialized();
    try {
      final txn = _db.transaction(_storeSettings, idb.idbModeReadWrite);
      final store = txn.objectStore(_storeSettings);
      await store.put(value, key);
      await txn.completed;
    } catch (e, stackTrace) {
      Logger.error('Failed to set setting: $key', error: e, trace: stackTrace);
      rethrow;
    }
  }

  // ==================== CACHE OPERATIONS ====================

  /// Cache data with optional TTL (time to live in milliseconds)
  Future<void> cache(String key, dynamic value, {int? ttlMs}) async {
    await _ensureInitialized();
    try {
      final cacheEntry = {
        'value': value,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'ttl': ttlMs,
      };

      final txn = _db.transaction(_storeCache, idb.idbModeReadWrite);
      final store = txn.objectStore(_storeCache);
      await store.put(cacheEntry, key);
      await txn.completed;
    } catch (e, stackTrace) {
      Logger.error('Failed to cache value for key: $key', error: e, trace: stackTrace);
      rethrow;
    }
  }

  /// Get cached data, returns null if expired or not found
  Future<T?> getCached<T>(String key) async {
    await _ensureInitialized();
    try {
      final txn = _db.transaction(_storeCache, idb.idbModeReadOnly);
      final store = txn.objectStore(_storeCache);
      final cacheEntry = await store.getObject(key) as Map<String, dynamic>?;
      await txn.completed;

      if (cacheEntry == null) return null;

      final ttl = cacheEntry['ttl'] as int?;
      if (ttl != null) {
        final timestamp = cacheEntry['timestamp'] as int;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - timestamp > ttl) {
          // Cache expired, delete it
          await _deleteCached(key);
          return null;
        }
      }

      return cacheEntry['value'] as T?;
    } catch (e, stackTrace) {
      Logger.error('Failed to get cached value for key: $key', error: e, trace: stackTrace);
      return null;
    }
  }

  /// Delete cached data
  Future<void> _deleteCached(String key) async {
    try {
      final txn = _db.transaction(_storeCache, idb.idbModeReadWrite);
      final store = txn.objectStore(_storeCache);
      await store.delete(key);
      await txn.completed;
    } catch (e, stackTrace) {
      Logger.error('Failed to delete cached value for key: $key', error: e, trace: stackTrace);
    }
  }

  /// Clear expired cache entries
  Future<void> clearExpiredCache() async {
    await _ensureInitialized();
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final txn = _db.transaction(_storeCache, idb.idbModeReadWrite);
      final store = txn.objectStore(_storeCache);

      final keysToDelete = <String>[];
      await store.openCursor(autoAdvance: true).listen((cursor) {
        if (cursor.value != null) {
          final entry = cursor.value as Map<String, dynamic>;
          final ttl = entry['ttl'] as int?;
          if (ttl != null) {
            final timestamp = entry['timestamp'] as int;
            if (now - timestamp > ttl) {
              keysToDelete.add(cursor.key as String);
            }
          }
        }
      }).asFuture();

      for (final key in keysToDelete) {
        await store.delete(key);
      }

      await txn.completed;
      Logger.debug('Cleared ${keysToDelete.length} expired cache entries');
    } catch (e, stackTrace) {
      Logger.error('Failed to clear expired cache', error: e, trace: stackTrace);
    }
  }

  // ==================== UTILITY OPERATIONS ====================

  /// Get storage usage statistics
  Future<Map<String, int>> getStorageStats() async {
    await _ensureInitialized();
    try {
      final stats = <String, int>{};

      final stores = [_storeGeneral, _storeMessages, _storeChats, _storeSettings, _storeAttachments, _storeCache];

      for (final storeName in stores) {
        final txn = _db.transaction(storeName, idb.idbModeReadOnly);
        final store = txn.objectStore(storeName);
        int count = 0;
        await store.openCursor(autoAdvance: true).listen((cursor) {
          if (cursor.value != null) count++;
        }).asFuture();
        await txn.completed;
        stats[storeName] = count;
      }

      return stats;
    } catch (e, stackTrace) {
      Logger.error('Failed to get storage stats', error: e, trace: stackTrace);
      return {};
    }
  }

  /// Clear all data from all stores
  Future<void> clearAllData() async {
    await _ensureInitialized();
    try {
      final stores = [_storeGeneral, _storeMessages, _storeChats, _storeSettings, _storeAttachments, _storeCache];

      for (final storeName in stores) {
        final txn = _db.transaction(storeName, idb.idbModeReadWrite);
        final store = txn.objectStore(storeName);
        await store.clear();
        await txn.completed;
      }

      Logger.warn('Cleared all data from all stores');
    } catch (e, stackTrace) {
      Logger.error('Failed to clear all data', error: e, trace: stackTrace);
      rethrow;
    }
  }

  /// Close the database connection
  void close() {
    if (_initialized) {
      _db.close();
      _initialized = false;
      Logger.info('Web Storage Service closed');
    }
  }
}

/// Global instance of the web storage service
final webStorage = WebStorageService();
