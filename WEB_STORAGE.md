# Web Storage Guide for BlueBubbles

This guide explains how data storage works in the BlueBubbles web application.

## Overview

Unlike the desktop and mobile versions which use ObjectBox for local storage, the web version uses **IndexedDB** - a browser-based NoSQL database that's built into all modern browsers.

## Why Not ObjectBox on Web?

ObjectBox requires native code and file system access, which are not available in web browsers. IndexedDB is the industry-standard solution for web applications and provides:

- ✅ Persistent storage (data survives browser restarts)
- ✅ Asynchronous API (doesn't block the UI)
- ✅ Indexed queries (fast lookups)
- ✅ Transaction support (data integrity)
- ✅ Cross-browser compatibility

## Storage Architecture

### Object Stores (Similar to Tables)

The web app uses 6 object stores:

1. **BBStore** - General key-value storage
2. **Messages** - Chat messages with indexes
3. **Chats** - Chat metadata and lists
4. **Settings** - User preferences and app settings
5. **Attachments** - Attachment metadata (not files)
6. **Cache** - Temporary data with TTL support

### Database Schema

```
BlueBubbles.db (IndexedDB)
├── BBStore (general key-value)
├── Messages
│   ├── Primary Key: guid
│   ├── Index: chatId
│   └── Index: dateCreated
├── Chats
│   ├── Primary Key: guid
│   └── Index: lastMessageDate
├── Settings (key-value)
├── Attachments
│   ├── Primary Key: guid
│   └── Index: messageGuid
└── Cache (key-value with TTL)
```

## Web Storage Service API

### Initialization

The storage service initializes automatically on app startup. If you need to manually initialize:

```dart
import 'package:bluebubbles/services/backend/web_storage_service.dart';

await webStorage.init();
```

### Basic Operations

#### Store Data

```dart
// Simple key-value storage
await webStorage.set('username', 'john_doe');
await webStorage.set('preferences', {'theme': 'dark', 'notifications': true});
```

#### Retrieve Data

```dart
// Get data
final username = await webStorage.get<String>('username');
final prefs = await webStorage.get<Map<String, dynamic>>('preferences');

// Returns null if not found
final missing = await webStorage.get<String>('nonexistent'); // null
```

#### Delete Data

```dart
await webStorage.delete('username');
```

#### Clear All Data

```dart
await webStorage.clear(); // Clears only BBStore
await webStorage.clearAllData(); // Clears ALL stores
```

### Message Operations

#### Save Messages

```dart
// Save a single message
await webStorage.saveMessage({
  'guid': 'message-123',
  'chatId': 'chat-456',
  'text': 'Hello, world!',
  'dateCreated': DateTime.now().millisecondsSinceEpoch,
  'isFromMe': true,
});

// Batch save messages
await webStorage.saveMessages([
  {'guid': 'msg-1', 'chatId': 'chat-1', 'text': 'Message 1'},
  {'guid': 'msg-2', 'chatId': 'chat-1', 'text': 'Message 2'},
  {'guid': 'msg-3', 'chatId': 'chat-1', 'text': 'Message 3'},
]);
```

#### Get Messages

```dart
// Get all messages for a chat
final messages = await webStorage.getMessagesForChat('chat-456');

// Get with limit
final recent = await webStorage.getMessagesForChat('chat-456', limit: 50);

// Messages are automatically sorted by dateCreated (newest first)
```

#### Delete Message

```dart
await webStorage.deleteMessage('message-123');
```

### Chat Operations

#### Save Chat

```dart
await webStorage.saveChat({
  'guid': 'chat-123',
  'displayName': 'Family Group',
  'lastMessageDate': DateTime.now().millisecondsSinceEpoch,
  'hasUnreadMessage': false,
});
```

#### Get All Chats

```dart
final chats = await webStorage.getAllChats();
// Automatically sorted by lastMessageDate (newest first)
```

#### Delete Chat

```dart
await webStorage.deleteChat('chat-123');
```

### Settings Operations

```dart
// Save settings
await webStorage.setSetting('theme', 'dark');
await webStorage.setSetting('fontSize', 16);
await webStorage.setSetting('enableNotifications', true);

// Get settings
final theme = await webStorage.getSetting<String>('theme');
final fontSize = await webStorage.getSetting<int>('fontSize');
final notifs = await webStorage.getSetting<bool>('enableNotifications');
```

### Cache Operations

Cache is perfect for temporary data that should expire:

```dart
// Cache for 1 hour (3,600,000 milliseconds)
await webStorage.cache('api_response', data, ttlMs: 3600000);

// Cache for 24 hours
await webStorage.cache('user_profile', profile, ttlMs: 86400000);

// Get cached data (returns null if expired)
final cached = await webStorage.getCached<Map>('api_response');

// Clear expired cache entries
await webStorage.clearExpiredCache();
```

### Storage Statistics

```dart
final stats = await webStorage.getStorageStats();
print(stats);
// {
//   'BBStore': 10,
//   'Messages': 523,
//   'Chats': 15,
//   'Settings': 25,
//   'Attachments': 89,
//   'Cache': 5
// }
```

## Storage Limits

### Browser Quotas

Different browsers have different storage limits:

| Browser | Typical Limit | Notes |
|---------|--------------|-------|
| Chrome | ~10 GB | 10% of free disk space |
| Firefox | ~10 GB | 10% of free disk space |
| Safari | ~1 GB | May prompt user for more |
| Edge | ~10 GB | 10% of free disk space |

### Check Available Storage

```javascript
if (navigator.storage && navigator.storage.estimate) {
  const estimate = await navigator.storage.estimate();
  console.log(`Using ${estimate.usage} of ${estimate.quota} bytes`);
  console.log(`${Math.round(estimate.usage / estimate.quota * 100)}% used`);
}
```

### Request Persistent Storage

For critical apps, request persistent storage to prevent auto-cleanup:

```javascript
if (navigator.storage && navigator.storage.persist) {
  const persistent = await navigator.storage.persist();
  console.log(`Persistent storage: ${persistent ? 'granted' : 'denied'}`);
}
```

## Best Practices

### 1. Handle Errors Gracefully

```dart
try {
  await webStorage.saveMessage(message);
} catch (e) {
  print('Failed to save message: $e');
  // Show user-friendly error
  showSnackbar('Failed to save message. Please try again.');
}
```

### 2. Batch Operations

Instead of:
```dart
// ❌ Slow - multiple transactions
for (final message in messages) {
  await webStorage.saveMessage(message);
}
```

Do this:
```dart
// ✅ Fast - single transaction
await webStorage.saveMessages(messages);
```

### 3. Clean Up Old Data

```dart
// Periodically clean up cache
Timer.periodic(Duration(hours: 1), (_) {
  webStorage.clearExpiredCache();
});
```

### 4. Offline-First Architecture

```dart
Future<List<Message>> getMessages(String chatId) async {
  // 1. Get from local storage first (instant)
  final cached = await webStorage.getMessagesForChat(chatId);

  if (cached.isNotEmpty) {
    return cached; // Return immediately
  }

  // 2. Fetch from server in background
  try {
    final remote = await api.getMessages(chatId);
    // 3. Cache for next time
    await webStorage.saveMessages(remote);
    return remote;
  } catch (e) {
    // 4. Fallback to cache even if stale
    return cached;
  }
}
```

### 5. Sync Strategy

```dart
class SyncService {
  Future<void> sync() async {
    final lastSync = await webStorage.getSetting<int>('lastSyncTime') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Only sync if 5 minutes have passed
    if (now - lastSync < 300000) return;

    // Fetch updates from server
    final updates = await api.getUpdates(since: lastSync);

    // Save to local storage
    await webStorage.saveMessages(updates.messages);
    await webStorage.saveChats(updates.chats.map((c) => c.toMap()).toList());

    // Update last sync time
    await webStorage.setSetting('lastSyncTime', now);
  }
}
```

## Migration from ObjectBox

If you're familiar with ObjectBox from the mobile/desktop versions, here's a mapping:

| ObjectBox | IndexedDB (Web) |
|-----------|-----------------|
| `Box<T>` | Object Store |
| `store.box<Message>()` | `webStorage.saveMessage()` |
| `box.put(object)` | `webStorage.saveMessage(object.toMap())` |
| `box.get(id)` | Use queries or key lookup |
| `box.getAll()` | `webStorage.getAllChats()` |
| `box.query(condition).build()` | Use indexes and cursors |
| Transaction | Built into each operation |

## Debugging

### View Storage in Browser

#### Chrome DevTools
1. Open DevTools (F12)
2. Go to Application tab
3. Click IndexedDB → BlueBubbles.db
4. Inspect each object store

#### Firefox DevTools
1. Open DevTools (F12)
2. Go to Storage tab
3. Click Indexed DB → BlueBubbles.db

#### Safari Web Inspector
1. Open Web Inspector
2. Go to Storage tab
3. Click Indexed Databases → BlueBubbles.db

### Clear Storage Manually

```javascript
// In browser console
indexedDB.deleteDatabase('BlueBubbles.db');
location.reload();
```

### Check for Errors

```dart
// Enable verbose logging
import 'package:bluebubbles/utils/logger/logger.dart';

Logger.setLogLevel(LogLevel.debug);
```

## Privacy & Security

### Data Encryption

IndexedDB data is **not encrypted by default**. Sensitive data should be encrypted before storage:

```dart
import 'package:encrypt/encrypt.dart';

final key = Key.fromSecureRandom(32);
final iv = IV.fromSecureRandom(16);
final encrypter = Encrypter(AES(key));

// Encrypt before storage
final encrypted = encrypter.encrypt(sensitiveData, iv: iv);
await webStorage.set('encrypted_key', encrypted.base64);

// Decrypt after retrieval
final stored = await webStorage.get<String>('encrypted_key');
final decrypted = encrypter.decrypt64(stored!, iv: iv);
```

### Private Browsing

In private/incognito mode:
- Storage is available but cleared when the window closes
- Storage quota may be smaller
- Consider showing a warning to users

```dart
// Detect private browsing (approximation)
Future<bool> isPrivateBrowsing() async {
  if (kIsWeb) {
    try {
      final estimate = await js.context.callMethod('eval', [
        'navigator.storage.estimate()'
      ]);
      return estimate['quota'] < 120000000; // Less than 120MB typically means private
    } catch (e) {
      return false;
    }
  }
  return false;
}
```

### GDPR Compliance

Provide users a way to export and delete their data:

```dart
// Export all user data
Future<Map<String, dynamic>> exportUserData() async {
  return {
    'chats': await webStorage.getAllChats(),
    'stats': await webStorage.getStorageStats(),
    'settings': await webStorage.getSetting('userSettings'),
  };
}

// Delete all user data (GDPR "Right to be forgotten")
Future<void> deleteAllUserData() async {
  await webStorage.clearAllData();
  // Also clear from server
  await api.deleteAccount();
}
```

## Troubleshooting

### Storage Not Working

**Problem:** Data isn't persisting

**Solutions:**
1. Check browser allows IndexedDB: `'indexedDB' in window`
2. Check storage isn't full: `navigator.storage.estimate()`
3. Check browser settings allow storage
4. Try clearing existing data and reinitializing

### Quota Exceeded Error

**Problem:** "QuotaExceededError: The quota has been exceeded"

**Solutions:**
1. Clear old/expired data: `webStorage.clearExpiredCache()`
2. Delete old messages: Keep only recent N messages
3. Request persistent storage
4. Reduce data size (compress, remove redundant fields)

### Performance Issues

**Problem:** Slow queries or saves

**Solutions:**
1. Use batch operations for multiple items
2. Use indexes for common queries
3. Limit query results
4. Clear expired cache regularly

---

## Additional Resources

- [IndexedDB API Documentation](https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API)
- [idb_shim Package](https://pub.dev/packages/idb_shim)
- [Web Storage Best Practices](https://web.dev/storage-for-the-web/)

---

**Last Updated:** October 2025
