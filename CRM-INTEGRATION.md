# Integrating Apple Wallet Notifications with Your Flutter CRM

This guide explains how to integrate Apple Wallet membership pass notifications into your Flutter-based CRM web app. This allows you to:

- View which members have downloaded their Apple Wallet pass
- Send push notifications to all members' iPhones
- Send targeted notifications to specific members
- Track notification delivery status

## Table of Contents

- [Prerequisites](#prerequisites)
- [Architecture Overview](#architecture-overview)
- [API Endpoints](#api-endpoints)
- [Flutter Integration](#flutter-integration)
- [UI Components](#ui-components)
- [Code Examples](#code-examples)
- [Security](#security)
- [Best Practices](#best-practices)

---

## Prerequisites

1. **Supabase Project** with the following deployed:
   - `send-general-wallet-notification` Edge Function
   - Event tables migration (if using event-based notifications)
   - Apple Wallet credentials configured

2. **Supabase Service Role Key** (for server-side operations)
   - Found in: Supabase Dashboard → Settings → API
   - **NEVER expose this in client code**

3. **Flutter Dependencies**:
```yaml
dependencies:
  http: ^1.1.0
  supabase_flutter: ^2.0.0
```

---

## Architecture Overview

```
Flutter CRM Web App
       ↓
   API Request
       ↓
Supabase Edge Function (send-general-wallet-notification)
       ↓
   APNs (Apple Push Notification Service)
       ↓
Member's iPhone → Apple Wallet Pass Updates
```

### Database Tables Used

1. **`members`** - Core member information
2. **`membership_cards`** - Wallet pass metadata and notification fields
3. **`apple_wallet_registrations`** - Device registration for push notifications

---

## API Endpoints

### Base URL
```
https://faajpcarasilbfndzkmd.supabase.co/functions/v1
```

### 1. Check Which Members Have Wallet Passes

**Endpoint**: Query Supabase database directly

```dart
// Get all members with their wallet pass status
final response = await supabase
  .from('membership_cards')
  .select('''
    id,
    member_id,
    apple_wallet_pass_serial,
    apple_wallet_generated_at,
    google_wallet_url,
    card_status,
    members!inner(
      id,
      name,
      email
    )
  ''')
  .not('apple_wallet_pass_serial', 'is', null);
```

### 2. Check if Specific Member Has Downloaded Pass

```dart
// Check if member has Apple Wallet pass
final response = await supabase
  .from('membership_cards')
  .select('apple_wallet_pass_serial, apple_wallet_generated_at')
  .eq('member_id', memberId)
  .single();

bool hasAppleWallet = response['apple_wallet_pass_serial'] != null;
```

### 3. Check Which Members Have Active Push Notifications

```dart
// Get members who have registered devices (can receive notifications)
final response = await supabase
  .from('apple_wallet_registrations')
  .select('''
    membership_card_id,
    device_library_id,
    push_token,
    registered_at,
    membership_cards!inner(
      member_id,
      members!inner(
        name,
        email
      )
    )
  ''');
```

### 4. Send Notification to All Members

**Endpoint**: `POST /send-general-wallet-notification`

```dart
Future<Map<String, dynamic>> sendNotificationToAll({
  required String title,
  required String message,
}) async {
  final response = await http.post(
    Uri.parse('$supabaseUrl/functions/v1/send-general-wallet-notification'),
    headers: {
      'Authorization': 'Bearer $serviceRoleKey', // SERVER-SIDE ONLY
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'notificationTitle': title,
      'notificationMessage': message,
      'targetMembers': 'all',
    }),
  );

  return jsonDecode(response.body);
}
```

### 5. Send Notification to Specific Members

```dart
Future<Map<String, dynamic>> sendNotificationToMembers({
  required String title,
  required String message,
  required List<String> memberIds,
}) async {
  final response = await http.post(
    Uri.parse('$supabaseUrl/functions/v1/send-general-wallet-notification'),
    headers: {
      'Authorization': 'Bearer $serviceRoleKey', // SERVER-SIDE ONLY
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'notificationTitle': title,
      'notificationMessage': message,
      'targetMembers': memberIds, // Array of member UUIDs
    }),
  );

  return jsonDecode(response.body);
}
```

### 6. Send Notification to Active Members Only

```dart
Future<Map<String, dynamic>> sendNotificationToActiveMembers({
  required String title,
  required String message,
}) async {
  final response = await http.post(
    Uri.parse('$supabaseUrl/functions/v1/send-general-wallet-notification'),
    headers: {
      'Authorization': 'Bearer $serviceRoleKey', // SERVER-SIDE ONLY
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'notificationTitle': title,
      'notificationMessage': message,
      'targetMembers': 'active', // Only non-expired members
    }),
  );

  return jsonDecode(response.body);
}
```

---

## Flutter Integration

### Step 1: Create a Wallet Service Class

Create `lib/services/wallet_notification_service.dart`:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class WalletNotificationService {
  final String supabaseUrl = 'https://faajpcarasilbfndzkmd.supabase.co';
  final String serviceRoleKey = 'YOUR_SERVICE_ROLE_KEY'; // SERVER-SIDE ONLY!

  final supabase = Supabase.instance.client;

  /// Check if a member has downloaded their Apple Wallet pass
  Future<bool> hasAppleWalletPass(String memberId) async {
    try {
      final response = await supabase
        .from('membership_cards')
        .select('apple_wallet_pass_serial')
        .eq('member_id', memberId)
        .single();

      return response['apple_wallet_pass_serial'] != null;
    } catch (e) {
      return false;
    }
  }

  /// Get all members with wallet passes
  Future<List<Map<String, dynamic>>> getMembersWithWalletPasses() async {
    final response = await supabase
      .from('membership_cards')
      .select('''
        id,
        member_id,
        apple_wallet_pass_serial,
        apple_wallet_generated_at,
        card_status,
        members!inner(
          id,
          name,
          email
        )
      ''')
      .not('apple_wallet_pass_serial', 'is', null)
      .order('apple_wallet_generated_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get members with active push notification registrations
  Future<List<Map<String, dynamic>>> getMembersWithActiveNotifications() async {
    final response = await supabase
      .from('apple_wallet_registrations')
      .select('''
        membership_card_id,
        device_library_id,
        registered_at,
        membership_cards!inner(
          member_id,
          members!inner(
            id,
            name,
            email
          )
        )
      ''');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Send notification to all members
  Future<NotificationResult> sendToAll({
    required String title,
    required String message,
  }) async {
    return _sendNotification(
      title: title,
      message: message,
      targetMembers: 'all',
    );
  }

  /// Send notification to specific members
  Future<NotificationResult> sendToMembers({
    required String title,
    required String message,
    required List<String> memberIds,
  }) async {
    return _sendNotification(
      title: title,
      message: message,
      targetMembers: memberIds,
    );
  }

  /// Send notification to active members only
  Future<NotificationResult> sendToActiveMembers({
    required String title,
    required String message,
  }) async {
    return _sendNotification(
      title: title,
      message: message,
      targetMembers: 'active',
    );
  }

  /// Internal method to send notifications
  Future<NotificationResult> _sendNotification({
    required String title,
    required String message,
    required dynamic targetMembers,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/send-general-wallet-notification'),
        headers: {
          'Authorization': 'Bearer $serviceRoleKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'notificationTitle': title,
          'notificationMessage': message,
          'targetMembers': targetMembers,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return NotificationResult(
          success: true,
          sent: data['sent'] ?? 0,
          failed: data['failed'] ?? 0,
          totalCardsFound: data['totalCardsFound'] ?? 0,
          message: data['message'] ?? 'Notifications sent',
        );
      } else {
        return NotificationResult(
          success: false,
          sent: 0,
          failed: 0,
          totalCardsFound: 0,
          message: 'Failed to send notifications: ${response.body}',
        );
      }
    } catch (e) {
      return NotificationResult(
        success: false,
        sent: 0,
        failed: 0,
        totalCardsFound: 0,
        message: 'Error: $e',
      );
    }
  }
}

/// Result of sending notifications
class NotificationResult {
  final bool success;
  final int sent;
  final int failed;
  final int totalCardsFound;
  final String message;

  NotificationResult({
    required this.success,
    required this.sent,
    required this.failed,
    required this.totalCardsFound,
    required this.message,
  });
}
```

---

## UI Components

### 1. Member Profile - Wallet Pass Status Badge

```dart
class WalletPassStatusBadge extends StatelessWidget {
  final String memberId;

  const WalletPassStatusBadge({required this.memberId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: WalletNotificationService().hasAppleWalletPass(memberId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox.shrink();
        }

        final hasPass = snapshot.data!;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: hasPass ? Colors.green.shade100 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasPass ? Colors.green : Colors.grey,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasPass ? Icons.check_circle : Icons.wallet,
                size: 16,
                color: hasPass ? Colors.green.shade700 : Colors.grey.shade600,
              ),
              SizedBox(width: 6),
              Text(
                hasPass ? 'Apple Wallet Added' : 'No Wallet Pass',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: hasPass ? Colors.green.shade700 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

### 2. Send Notification Dialog

```dart
class SendNotificationDialog extends StatefulWidget {
  final List<String>? specificMemberIds; // null = all members

  const SendNotificationDialog({this.specificMemberIds});

  @override
  State<SendNotificationDialog> createState() => _SendNotificationDialogState();
}

class _SendNotificationDialogState extends State<SendNotificationDialog> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _service = WalletNotificationService();
  bool _isLoading = false;

  Future<void> _sendNotification() async {
    if (_titleController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = widget.specificMemberIds != null
          ? await _service.sendToMembers(
              title: _titleController.text,
              message: _messageController.text,
              memberIds: widget.specificMemberIds!,
            )
          : await _service.sendToAll(
              title: _titleController.text,
              message: _messageController.text,
            );

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.sent} notifications sent, ${result.failed} failed',
          ),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Send Wallet Notification'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.specificMemberIds != null)
              Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Sending to ${widget.specificMemberIds!.length} selected member(s)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Notification Title',
                hintText: 'e.g., Membership Renewal',
                border: OutlineInputBorder(),
              ),
              maxLength: 50,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _messageController,
              decoration: InputDecoration(
                labelText: 'Message',
                hintText: 'e.g., Your membership expires in 30 days',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 200,
            ),
            SizedBox(height: 8),
            Text(
              '💡 Members will receive this on their iPhone lock screen',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendNotification,
          child: _isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Send'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}
```

### 3. Members with Wallet Passes List

```dart
class MembersWithWalletPassesPage extends StatelessWidget {
  final _service = WalletNotificationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Members with Apple Wallet Passes'),
        actions: [
          IconButton(
            icon: Icon(Icons.send),
            tooltip: 'Send notification to all',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => SendNotificationDialog(),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _service.getMembersWithWalletPasses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final members = snapshot.data ?? [];

          if (members.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wallet, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No members have added their wallet pass yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              final memberInfo = member['members'];
              final addedDate = DateTime.parse(
                member['apple_wallet_generated_at'],
              );

              return ListTile(
                leading: CircleAvatar(
                  child: Text(memberInfo['name'][0].toUpperCase()),
                ),
                title: Text(memberInfo['name']),
                subtitle: Text(
                  'Added ${_formatDate(addedDate)} • ${memberInfo['email']}',
                ),
                trailing: PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: ListTile(
                        leading: Icon(Icons.send),
                        title: Text('Send notification'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      onTap: () {
                        Future.delayed(Duration(milliseconds: 100), () {
                          showDialog(
                            context: context,
                            builder: (_) => SendNotificationDialog(
                              specificMemberIds: [member['member_id']],
                            ),
                          );
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    return '${(diff.inDays / 30).floor()} months ago';
  }
}
```

### 4. Quick Action Button in Member Profile

```dart
class MemberProfileActions extends StatelessWidget {
  final String memberId;
  final String memberName;

  const MemberProfileActions({
    required this.memberId,
    required this.memberName,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: WalletNotificationService().hasAppleWalletPass(memberId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!) {
          return SizedBox.shrink();
        }

        return ElevatedButton.icon(
          icon: Icon(Icons.notifications),
          label: Text('Send Wallet Notification'),
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => SendNotificationDialog(
                specificMemberIds: [memberId],
              ),
            );
          },
        );
      },
    );
  }
}
```

---

## Code Examples

### Example 1: Add Wallet Status to Member List

```dart
// In your members list
ListTile(
  title: Text(member.name),
  subtitle: Text(member.email),
  trailing: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      WalletPassStatusBadge(memberId: member.id),
      // ... other actions
    ],
  ),
);
```

### Example 2: Bulk Send Notification

```dart
// Send to multiple selected members
void sendToSelectedMembers(List<String> selectedMemberIds) {
  showDialog(
    context: context,
    builder: (_) => SendNotificationDialog(
      specificMemberIds: selectedMemberIds,
    ),
  );
}
```

### Example 3: Scheduled Membership Reminder

```dart
// Send bi-annual reminder
Future<void> sendBiannualReminder() async {
  final service = WalletNotificationService();

  final result = await service.sendToActiveMembers(
    title: 'MOYD Check-In',
    message: 'Thanks for being a MOYD member! Stay engaged at moyd.org',
  );

  print('Sent to ${result.sent} members');
}
```

### Example 4: Get Wallet Pass Statistics

```dart
Future<Map<String, int>> getWalletPassStats() async {
  final service = WalletNotificationService();

  final withPasses = await service.getMembersWithWalletPasses();
  final withNotifications = await service.getMembersWithActiveNotifications();

  // Get total members
  final totalMembers = await supabase
    .from('members')
    .select('id', const FetchOptions(count: CountOption.exact));

  return {
    'total': totalMembers.count ?? 0,
    'withPasses': withPasses.length,
    'withNotifications': withNotifications.length,
    'adoption': ((withPasses.length / (totalMembers.count ?? 1)) * 100).round(),
  };
}
```

---

## Security

### ⚠️ CRITICAL: Never Expose Service Role Key in Client Code

The service role key must **NEVER** be included in your Flutter web app client code, as it would be visible to anyone inspecting your app.

### Recommended Architecture: Backend Proxy

**Option 1: Create a Supabase Edge Function Wrapper**

Create `supabase/functions/crm-send-notification/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.0';

serve(async (req) => {
  // Verify the user is authenticated and has admin role
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response('Unauthorized', { status: 401 });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  // Verify user is admin
  const token = authHeader.replace('Bearer ', '');
  const { data: { user }, error } = await supabase.auth.getUser(token);

  if (error || !user) {
    return new Response('Unauthorized', { status: 401 });
  }

  // Check if user has admin role
  const { data: member } = await supabase
    .from('members')
    .select('is_admin')
    .eq('id', user.id)
    .single();

  if (!member?.is_admin) {
    return new Response('Forbidden', { status: 403 });
  }

  // Forward request to send-general-wallet-notification
  const body = await req.json();

  const response = await fetch(
    `${Deno.env.get('SUPABASE_URL')}/functions/v1/send-general-wallet-notification`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    }
  );

  const data = await response.json();
  return new Response(JSON.stringify(data), {
    status: response.status,
    headers: { 'Content-Type': 'application/json' },
  });
});
```

Then in your Flutter app, call this wrapper instead:

```dart
Future<NotificationResult> _sendNotification({
  required String title,
  required String message,
  required dynamic targetMembers,
}) async {
  // Use user's auth token instead of service role key
  final session = supabase.auth.currentSession;
  if (session == null) throw Exception('Not authenticated');

  final response = await http.post(
    Uri.parse('$supabaseUrl/functions/v1/crm-send-notification'),
    headers: {
      'Authorization': 'Bearer ${session.accessToken}', // User token, not service role
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'notificationTitle': title,
      'notificationMessage': message,
      'targetMembers': targetMembers,
    }),
  );

  // ... handle response
}
```

**Option 2: Use Row Level Security (RLS)**

Add an admin check to your database and use RLS policies to control access.

---

## Best Practices

### 1. Notification Frequency

- **Maximum**: 10 notifications per day per pass (Apple limit)
- **Recommended**: 1-3 per month for general updates
- **Ideal**: 2-4 per year for bi-annual check-ins

### 2. Message Guidelines

✅ **Good Examples:**
- Title: "Membership Expires Soon"
- Message: "Your MOYD membership expires in 30 days. Renew at members.moyd.org"

❌ **Bad Examples:**
- Title: "Update" (too vague)
- Message: "Check your portal" (no context)

### 3. Testing

Always test with yourself first:

```dart
// Test with your own member ID
await service.sendToMembers(
  title: 'Test Notification',
  message: 'Testing the notification system',
  memberIds: ['your-member-uuid'],
);
```

### 4. Error Handling

Always handle errors gracefully:

```dart
try {
  final result = await service.sendToAll(
    title: title,
    message: message,
  );

  if (result.failed > 0) {
    // Some notifications failed
    showWarning('${result.failed} notifications failed to send');
  }
} catch (e) {
  showError('Failed to send notifications: $e');
}
```

### 5. Track Notification History

Consider logging notifications sent:

```sql
CREATE TABLE notification_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sent_by UUID REFERENCES auth.users(id),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  target_type TEXT, -- 'all', 'active', 'specific'
  member_ids UUID[], -- if specific members
  sent_count INT,
  failed_count INT,
  sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

## Dashboard Widget Examples

### Wallet Pass Adoption Card

```dart
class WalletAdoptionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: getWalletPassStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Card(child: Center(child: CircularProgressIndicator()));
        }

        final stats = snapshot.data!;

        return Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Apple Wallet Adoption',
                  style: Theme.of(context).textTheme.headline6,
                ),
                SizedBox(height: 16),
                LinearProgressIndicator(
                  value: stats['adoption']! / 100,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                SizedBox(height: 8),
                Text(
                  '${stats['withPasses']} of ${stats['total']} members (${stats['adoption']}%)',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                SizedBox(height: 8),
                Text(
                  '${stats['withNotifications']} members can receive notifications',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

---

## Troubleshooting

### No notifications received

1. Check if members have added passes to their wallet
2. Verify APNs credentials are configured
3. Check function logs: `supabase functions logs send-general-wallet-notification`

### "Unauthorized" error

- You're trying to use service role key in client code
- Use the backend proxy approach instead

### Some members not receiving notifications

- They may not have added the pass to Apple Wallet yet
- Their device may be offline
- Check the `apple_wallet_registrations` table

---

## Additional Resources

- [Apple Wallet Developer Guide](https://developer.apple.com/documentation/walletpasses)
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)
- [GENERAL-WALLET-NOTIFICATIONS.md](./GENERAL-WALLET-NOTIFICATIONS.md) - Detailed API documentation

---

## Support

For issues or questions:
- Check Supabase function logs
- Review the notification history
- Test with a single member first before sending to all

---

**Last Updated**: November 2025
