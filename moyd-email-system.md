# MOYD Email System - Flutter Integration Guide

**Last Updated:** November 16, 2025  
**Audience:** Flutter developers (Codex) working with existing MOYD email infrastructure  
**Purpose:** Complete API reference for integrating email functionality into Flutter apps

---

## ⚠️ Critical Constraints

### YOU CANNOT MODIFY:
- ❌ Database tables, columns, or schema
- ❌ Edge Function code or logic
- ❌ Database triggers or stored procedures
- ❌ Gmail API authentication/configuration
- ❌ Email sending/receiving mechanisms

### YOU CAN:
- ✅ Call Edge Functions via HTTP from Flutter
- ✅ Query database tables using Supabase client
- ✅ Build UI for email display and composition
- ✅ Implement client-side email workflows
- ✅ Handle errors and loading states

---

## System Overview

The MOYD email system provides CRM capabilities for staff to communicate with members:

**Core Features:**
- Send emails with HTML templates and variable substitution
- Attach files (base64 encoded)
- Thread email conversations automatically
- Fetch member email history (sent + received)
- Cache emails in database for fast access
- Link emails to member records automatically

**Architecture:**
```
Flutter App → Supabase Edge Functions → Gmail API → Database
                                              ↓
                                     member_email_history
```

---

## Quick Start

### 1. Initialize Supabase

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

await Supabase.initialize(
  url: 'https://faajpcarasilbfndzkmd.supabase.co',
  anonKey: 'your-anon-key',
);

final supabase = Supabase.instance.client;
```

### 2. Send an Email

```dart
final response = await supabase.functions.invoke(
  'send-email',
  body: {
    'to': 'member@example.com',
    'subject': 'Welcome to MOYD!',
    'htmlBody': '<p>Hi {{name}}, welcome to the team!</p>',
    'variables': {'name': 'John'},
  },
);

final data = response.data;
print('Sent: ${data['gmail_message_id']}');
```

### 3. Fetch Member Emails

```dart
final response = await supabase.functions.invoke(
  'get-member-emails',
  body: {
    'memberId': 'uuid-here',
    'limit': 50,
  },
);

final emails = response.data['emails'] as List;
```

---

## API Endpoints

**Base URL:** `https://faajpcarasilbfndzkmd.supabase.co/functions/v1/`

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/send-email` | POST | Send new emails with templates/attachments |
| `/send-email-reply` | POST | Reply to existing email threads |
| `/get-member-emails` | POST | Fetch all emails for a member |

---

## 1. Send Email

**Endpoint:** `POST /functions/v1/send-email`

### Request Parameters

```dart
Future<Map<String, dynamic>> sendEmail({
  required dynamic to,              // String or List<String>
  required String subject,
  required String htmlBody,
  String? textBody,                 // Plain text version
  List<String>? cc,
  List<String>? bcc,
  Map<String, String>? variables,   // Template variables
  List<Map>? attachments,           // Files (base64)
  String? replyTo,
  String? fromName,                 // Display name
  String? threadId,                 // For threading
  String? inReplyTo,                // Threading header
  String? references,               // Threading header
}) async {
  final response = await Supabase.instance.client.functions.invoke(
    'send-email',
    body: {
      'to': to,
      'subject': subject,
      'htmlBody': htmlBody,
      if (textBody != null) 'textBody': textBody,
      if (cc != null) 'cc': cc,
      if (bcc != null) 'bcc': bcc,
      if (variables != null) 'variables': variables,
      if (attachments != null) 'attachments': attachments,
      if (replyTo != null) 'replyTo': replyTo,
      if (fromName != null) 'fromName': fromName,
      if (threadId != null) 'threadId': threadId,
      if (inReplyTo != null) 'inReplyTo': inReplyTo,
      if (references != null) 'references': references,
    },
  );
  
  return response.data as Map<String, dynamic>;
}
```

### Template Variables

Use `{{variable}}` syntax in HTML:

```dart
final htmlBody = '''
<html>
  <body>
    <p>Hi {{name}},</p>
    <p>Your {{chapter}} chapter membership expires on {{date}}.</p>
  </body>
</html>
''';

await sendEmail(
  to: 'member@example.com',
  subject: 'Membership Renewal',
  htmlBody: htmlBody,
  variables: {
    'name': 'John Doe',
    'chapter': 'Kansas City',
    'date': '2025-12-31',
  },
);
```

### Attachments

```dart
// Convert file to base64
import 'dart:convert';

final fileBytes = await file.readAsBytes();
final base64Content = base64Encode(fileBytes);

await sendEmail(
  to: 'member@example.com',
  subject: 'Your Document',
  htmlBody: '<p>Attached is your document.</p>',
  attachments: [
    {
      'filename': 'membership-card.pdf',
      'mimeType': 'application/pdf',
      'content': base64Content,
    },
  ],
);
```

### Response

```dart
{
  "success": true,
  "gmail_message_id": "18cf8b1a2c3d4e5f",
  "gmail_thread_id": "18cf8b1a2c3d4e5f",
  "email_log_id": "uuid",
  "linked_member_ids": ["uuid1", "uuid2"],
  "from_display_name": "Missouri Young Democrats"
}
```

### Error Response

```dart
{
  "error": "Missing required fields: to, subject, htmlBody"
}
// HTTP 400 or 500
```

---

## 2. Send Email Reply

**Endpoint:** `POST /functions/v1/send-email-reply`

### Request Parameters

```dart
Future<Map<String, dynamic>> sendEmailReply({
  required String threadId,
  required String to,
  required String subject,
  required String htmlBody,
  String? originalMessageId,  // Auto-fetches headers
  String? textBody,
  List<String>? cc,
  String? messageId,          // Manual override
  String? references,         // Manual override
}) async {
  final response = await Supabase.instance.client.functions.invoke(
    'send-email-reply',
    body: {
      'threadId': threadId,
      'to': to,
      'subject': subject,
      'htmlBody': htmlBody,
      if (originalMessageId != null) 'originalMessageId': originalMessageId,
      if (textBody != null) 'textBody': textBody,
      if (cc != null) 'cc': cc,
      if (messageId != null) 'messageId': messageId,
      if (references != null) 'references': references,
    },
  );
  
  return response.data as Map<String, dynamic>;
}
```

### Auto-Header Fetching

If you provide `originalMessageId`, the function automatically:
1. Fetches the original email's headers from Gmail
2. Extracts the `Message-ID` → uses as `In-Reply-To`
3. Builds proper `References` chain for threading

```dart
// Easy reply - let backend handle threading
await sendEmailReply(
  threadId: email.gmailThreadId,
  originalMessageId: email.gmailMessageId,
  to: email.fromAddress,
  subject: 'Re: ${email.subject}',
  htmlBody: '<p>Thanks for reaching out!</p>',
);
```

### Response

```dart
{
  "success": true,
  "gmail_message_id": "18cf8b1a2c3d4e5f",
  "gmail_thread_id": "18cf8b1a2c3d4e5f",
  "email_log_id": "uuid"
}
```

---

## 3. Get Member Emails

**Endpoint:** `POST /functions/v1/get-member-emails`

### Request Parameters

```dart
Future<MemberEmailsResponse> getMemberEmails({
  String? memberId,
  String? email,
  int limit = 50,
  bool syncToDatabase = true,
  bool forceRefresh = false,
}) async {
  final response = await Supabase.instance.client.functions.invoke(
    'get-member-emails',
    body: {
      if (memberId != null) 'memberId': memberId,
      if (email != null) 'email': email,
      'limit': limit,
      'syncToDatabase': syncToDatabase,
      'forceRefresh': forceRefresh,
    },
  );
  
  return MemberEmailsResponse.fromJson(response.data);
}
```

### Caching Behavior

```
forceRefresh = false (default):
  1. Check database cache (email_inbox + email_logs)
  2. If found → return cached data (FAST)
  3. If empty → fetch from Gmail + cache

forceRefresh = true:
  1. Skip cache entirely
  2. Fetch fresh from Gmail API
  3. Optionally sync to database
```

### Response Data Model

```dart
class MemberEmailsResponse {
  final bool success;
  final String memberId;
  final String memberName;
  final List<String> memberEmails;
  final int emailCount;
  final List<EmailMessage> emails;
  final String source;  // "cache" or "gmail"
  final int limit;
  final SyncStats? sync;
  final DateTime timestamp;

  factory MemberEmailsResponse.fromJson(Map<String, dynamic> json) {
    return MemberEmailsResponse(
      success: json['success'] as bool,
      memberId: json['memberId'] as String,
      memberName: json['memberName'] as String,
      memberEmails: List<String>.from(json['memberEmails']),
      emailCount: json['emailCount'] as int,
      emails: (json['emails'] as List)
          .map((e) => EmailMessage.fromJson(e))
          .toList(),
      source: json['source'] as String,
      limit: json['limit'] as int,
      sync: json['sync'] != null ? SyncStats.fromJson(json['sync']) : null,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class EmailMessage {
  final String id;
  final String gmailMessageId;
  final String gmailThreadId;
  final String fromAddress;
  final String toAddress;
  final String? ccAddress;
  final String subject;
  final DateTime date;
  final String snippet;
  final String? bodyHtml;
  final String? bodyText;
  final String? messageId;
  final String? inReplyTo;
  final String? referencesHeader;
  final List<String> labelIds;
  final String memberId;
  final DateTime syncedAt;
  final String? status;
  final String direction;  // "sent" or "received"

  factory EmailMessage.fromJson(Map<String, dynamic> json) {
    return EmailMessage(
      id: json['id'] as String,
      gmailMessageId: json['gmail_message_id'] as String,
      gmailThreadId: json['gmail_thread_id'] as String,
      fromAddress: json['from_address'] as String,
      toAddress: json['to_address'] as String,
      ccAddress: json['cc_address'] as String?,
      subject: json['subject'] as String,
      date: DateTime.parse(json['date'] as String),
      snippet: json['snippet'] as String,
      bodyHtml: json['body_html'] as String?,
      bodyText: json['body_text'] as String?,
      messageId: json['message_id'] as String?,
      inReplyTo: json['in_reply_to'] as String?,
      referencesHeader: json['references_header'] as String?,
      labelIds: List<String>.from(json['label_ids'] ?? []),
      memberId: json['member_id'] as String,
      syncedAt: DateTime.parse(json['synced_at'] as String),
      status: json['status'] as String?,
      direction: json['direction'] as String,
    );
  }
}

class SyncStats {
  final int success;
  final int errors;

  factory SyncStats.fromJson(Map<String, dynamic> json) {
    return SyncStats(
      success: json['success'] as int,
      errors: json['errors'] as int,
    );
  }
}
```

### Use Cases

```dart
// 1. Fast cached lookup
final emails = await getMemberEmails(memberId: 'uuid');

// 2. Force fresh data from Gmail
final fresh = await getMemberEmails(
  memberId: 'uuid',
  forceRefresh: true,
);

// 3. Lookup by email address
final emails = await getMemberEmails(email: 'john@example.com');

// 4. Get more results (max 500)
final many = await getMemberEmails(memberId: 'uuid', limit: 200);
```

---

## Database Tables (Read-Only)

You can query these tables directly for custom filtering/searching.

### 1. `email_inbox` - Received Emails

```dart
// Get all received emails for member
final response = await supabase
    .from('email_inbox')
    .select()
    .eq('member_id', memberId)
    .order('date', ascending: false)
    .limit(50);

// Get unread emails
final unread = await supabase
    .from('email_inbox')
    .select()
    .eq('member_id', memberId)
    .eq('is_read', false);

// Get emails in specific thread
final thread = await supabase
    .from('email_inbox')
    .select()
    .eq('gmail_thread_id', threadId)
    .order('date', ascending: true);
```

**Columns:**
- `id`, `created_at`
- `gmail_message_id`, `gmail_thread_id`
- `from_address`, `to_address`, `cc_address`
- `subject`, `date`, `snippet`
- `body_html`, `body_text`
- `message_id`, `in_reply_to`, `references_header`
- `label_ids`, `is_read`
- `member_id`, `synced_at`

### 2. `email_logs` - Sent Emails

```dart
// Get all sent emails to member
final sent = await supabase
    .from('email_logs')
    .select()
    .contains('member_ids', [memberId])
    .order('created_at', ascending: false);

// Get failed sends
final failed = await supabase
    .from('email_logs')
    .select()
    .eq('status', 'failed')
    .order('created_at', ascending: false);

// Search by recipient email
final toMember = await supabase
    .from('email_logs')
    .select()
    .contains('recipient_emails', ['member@example.com']);
```

**Columns:**
- `id`, `created_at`
- `subject`, `body`, `html`
- `sender`, `reply_to`
- `recipient_emails`, `cc`, `bcc`
- `member_ids` (UUID array)
- `variables`, `attachments` (JSONB)
- `gmail_message_id`, `gmail_thread_id`, `in_reply_to`
- `status`, `error_message`

### 3. `member_email_history` - Unified View

**⭐ RECOMMENDED** for building inbox UIs - combines sent + received.

```dart
// Get complete history for member
final history = await supabase
    .from('member_email_history')
    .select()
    .eq('member_id', memberId)
    .order('email_date', ascending: false)
    .limit(100);

// Filter by type
final sentOnly = await supabase
    .from('member_email_history')
    .select()
    .eq('member_id', memberId)
    .eq('email_type', 'sent');

final received = await supabase
    .from('member_email_history')
    .select()
    .eq('member_id', memberId)
    .eq('email_type', 'received');

// Search by subject
final results = await supabase
    .from('member_email_history')
    .select()
    .eq('member_id', memberId)
    .ilike('subject', '%renewal%');
```

**Columns:**
- `id`, `created_at`, `updated_at`
- `member_id`, `member_name`, `member_email`
- `email_type` ('sent' or 'received')
- `log_id` (UUID, unique)
- `subject`, `body`
- `from_address`, `to_address`
- `email_date`
- `gmail_message_id`, `gmail_thread_id`

---

## Flutter UI Examples

### Member Inbox Screen

```dart
class MemberInboxScreen extends StatefulWidget {
  final String memberId;

  const MemberInboxScreen({required this.memberId});

  @override
  State<MemberInboxScreen> createState() => _MemberInboxScreenState();
}

class _MemberInboxScreenState extends State<MemberInboxScreen> {
  List<EmailHistoryRecord> emails = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadEmails();
  }

  Future<void> _loadEmails() async {
    setState(() => isLoading = true);

    try {
      final response = await Supabase.instance.client
          .from('member_email_history')
          .select()
          .eq('member_id', widget.memberId)
          .order('email_date', ascending: false)
          .limit(100);

      setState(() {
        emails = (response as List)
            .map((json) => EmailHistoryRecord.fromJson(json))
            .toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Email Inbox')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('Email Inbox')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $error'),
              ElevatedButton(
                onPressed: _loadEmails,
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Email Inbox'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadEmails,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: emails.length,
        itemBuilder: (context, index) {
          final email = emails[index];
          return EmailListTile(
            email: email,
            onTap: () => _openEmail(email),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _composeEmail(),
        child: Icon(Icons.edit),
      ),
    );
  }

  void _openEmail(EmailHistoryRecord email) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmailDetailScreen(email: email),
      ),
    );
  }

  void _composeEmail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComposeEmailScreen(memberId: widget.memberId),
      ),
    );
  }
}

class EmailListTile extends StatelessWidget {
  final EmailHistoryRecord email;
  final VoidCallback onTap;

  const EmailListTile({required this.email, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Icon(
          email.emailType == 'sent' ? Icons.send : Icons.mail,
        ),
      ),
      title: Text(
        email.subject ?? '(No Subject)',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        email.emailType == 'sent'
            ? 'To: ${email.toAddress}'
            : 'From: ${email.fromAddress}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _formatDate(email.emailDate),
        style: TextStyle(fontSize: 12),
      ),
      onTap: onTap,
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}

class EmailHistoryRecord {
  final String id;
  final String memberId;
  final String? memberName;
  final String? memberEmail;
  final String emailType;
  final String logId;
  final String? subject;
  final String? body;
  final String? fromAddress;
  final String? toAddress;
  final DateTime? emailDate;
  final String? gmailMessageId;
  final String? gmailThreadId;

  EmailHistoryRecord({
    required this.id,
    required this.memberId,
    this.memberName,
    this.memberEmail,
    required this.emailType,
    required this.logId,
    this.subject,
    this.body,
    this.fromAddress,
    this.toAddress,
    this.emailDate,
    this.gmailMessageId,
    this.gmailThreadId,
  });

  factory EmailHistoryRecord.fromJson(Map<String, dynamic> json) {
    return EmailHistoryRecord(
      id: json['id'].toString(),
      memberId: json['member_id'] as String,
      memberName: json['member_name'] as String?,
      memberEmail: json['member_email'] as String?,
      emailType: json['email_type'] as String,
      logId: json['log_id'] as String,
      subject: json['subject'] as String?,
      body: json['body'] as String?,
      fromAddress: json['from_address'] as String?,
      toAddress: json['to_address'] as String?,
      emailDate: json['email_date'] != null
          ? DateTime.parse(json['email_date'])
          : null,
      gmailMessageId: json['gmail_message_id'] as String?,
      gmailThreadId: json['gmail_thread_id'] as String?,
    );
  }
}
```

### Thread View Screen

```dart
class EmailThreadScreen extends StatelessWidget {
  final String threadId;

  const EmailThreadScreen({required this.threadId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Email Thread')),
      body: FutureBuilder<List<EmailHistoryRecord>>(
        future: _loadThread(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final emails = snapshot.data ?? [];
          if (emails.isEmpty) {
            return Center(child: Text('No emails in thread'));
          }

          return ListView.separated(
            padding: EdgeInsets.all(16),
            itemCount: emails.length,
            separatorBuilder: (_, __) => Divider(height: 32),
            itemBuilder: (context, index) {
              return EmailThreadItem(email: emails[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _replyToThread(context),
        child: Icon(Icons.reply),
      ),
    );
  }

  Future<List<EmailHistoryRecord>> _loadThread() async {
    final response = await Supabase.instance.client
        .from('member_email_history')
        .select()
        .eq('gmail_thread_id', threadId)
        .order('email_date', ascending: true);

    return (response as List)
        .map((json) => EmailHistoryRecord.fromJson(json))
        .toList();
  }

  void _replyToThread(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComposeEmailScreen(threadId: threadId),
      ),
    );
  }
}

class EmailThreadItem extends StatelessWidget {
  final EmailHistoryRecord email;

  const EmailThreadItem({required this.email});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              child: Text(email.fromAddress?[0].toUpperCase() ?? '?'),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email.fromAddress ?? 'Unknown',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    email.emailDate != null
                        ? email.emailDate.toString()
                        : 'Unknown date',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(email.body ?? '(No content)'),
        ),
      ],
    );
  }
}
```

### Compose Email Screen

```dart
class ComposeEmailScreen extends StatefulWidget {
  final String? memberId;
  final String? threadId;
  final String? replyToMessageId;

  const ComposeEmailScreen({
    this.memberId,
    this.threadId,
    this.replyToMessageId,
  });

  @override
  State<ComposeEmailScreen> createState() => _ComposeEmailScreenState();
}

class _ComposeEmailScreenState extends State<ComposeEmailScreen> {
  final _toController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.threadId != null ? 'Reply' : 'Compose Email'),
        actions: [
          if (_isSending)
            Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.send),
              onPressed: _sendEmail,
            ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _toController,
              decoration: InputDecoration(
                labelText: 'To',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _subjectController,
              decoration: InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _bodyController,
                decoration: InputDecoration(
                  labelText: 'Message',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendEmail() async {
    if (_toController.text.isEmpty ||
        _subjectController.text.isEmpty ||
        _bodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      if (widget.threadId != null && widget.replyToMessageId != null) {
        // Send reply
        await Supabase.instance.client.functions.invoke(
          'send-email-reply',
          body: {
            'threadId': widget.threadId!,
            'originalMessageId': widget.replyToMessageId!,
            'to': _toController.text,
            'subject': _subjectController.text,
            'htmlBody': '<p>${_bodyController.text}</p>',
          },
        );
      } else {
        // Send new email
        await Supabase.instance.client.functions.invoke(
          'send-email',
          body: {
            'to': _toController.text,
            'subject': _subjectController.text,
            'htmlBody': '<p>${_bodyController.text}</p>',
          },
        );
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email sent successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }
}
```

---

## Error Handling

### API Errors

```dart
Future<void> sendEmailWithErrorHandling() async {
  try {
    final response = await Supabase.instance.client.functions.invoke(
      'send-email',
      body: {
        'to': 'member@example.com',
        'subject': 'Test',
        'htmlBody': '<p>Test</p>',
      },
    );

    final data = response.data as Map<String, dynamic>;
    
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Unknown error');
    }

    print('Sent: ${data['gmail_message_id']}');
  } on FunctionException catch (e) {
    if (e.status == 400) {
      print('Bad request: Check required fields');
    } else if (e.status == 500) {
      print('Server error: Try again later');
    }
    print('Error: ${e.details}');
  } catch (e) {
    print('Unexpected error: $e');
  }
}
```

### Database Errors

```dart
Future<List<EmailHistoryRecord>> getEmailsWithErrorHandling(
  String memberId,
) async {
  try {
    final response = await Supabase.instance.client
        .from('member_email_history')
        .select()
        .eq('member_id', memberId)
        .order('email_date', ascending: false);

    return (response as List)
        .map((json) => EmailHistoryRecord.fromJson(json))
        .toList();
  } on PostgrestException catch (e) {
    print('Database error: ${e.code} - ${e.message}');
    rethrow;
  }
}
```

---

## Performance Best Practices

### 1. Use Cached Data

```dart
// ❌ BAD: Always fetch from Gmail (slow!)
await getMemberEmails(memberId: id, forceRefresh: true);

// ✅ GOOD: Use cache by default
await getMemberEmails(memberId: id);

// ✅ GOOD: Only force refresh when user explicitly requests
if (userPulledToRefresh) {
  await getMemberEmails(memberId: id, forceRefresh: true);
}
```

### 2. Limit Results

```dart
// ❌ BAD: No limit
final all = await supabase
    .from('member_email_history')
    .select()
    .eq('member_id', memberId);

// ✅ GOOD: Limit + pagination
final page1 = await supabase
    .from('member_email_history')
    .select()
    .eq('member_id', memberId)
    .order('email_date', ascending: false)
    .limit(50);
```

### 3. Select Only Needed Columns

```dart
// ❌ BAD: Full email bodies for list view
final emails = await supabase
    .from('member_email_history')
    .select();

// ✅ GOOD: Only list columns
final emailList = await supabase
    .from('member_email_history')
    .select('id, subject, from_address, email_date, email_type')
    .eq('member_id', memberId)
    .limit(50);

// ✅ Fetch full body only when opening
final full = await supabase
    .from('member_email_history')
    .select()
    .eq('id', emailId)
    .single();
```

---

## Email Threading

### Thread Structure

Emails in the same conversation share `gmail_thread_id`:

```
Thread: 18cf8b1a2c3d4e5f

Email 1 (original):
  - message_id: <abc@gmail.com>
  - in_reply_to: null
  - references: null

Email 2 (reply):
  - message_id: <def@gmail.com>
  - in_reply_to: <abc@gmail.com>
  - references: <abc@gmail.com>

Email 3 (reply to reply):
  - message_id: <ghi@gmail.com>
  - in_reply_to: <def@gmail.com>
  - references: <abc@gmail.com> <def@gmail.com>
```

### Loading Thread

```dart
Future<List<EmailHistoryRecord>> loadThread(String threadId) async {
  final response = await Supabase.instance.client
      .from('member_email_history')
      .select()
      .eq('gmail_thread_id', threadId)
      .order('email_date', ascending: true);  // Chronological

  return (response as List)
      .map((json) => EmailHistoryRecord.fromJson(json))
      .toList();
}
```

---

## Important Constraints

### Organization Emails

All emails are sent from these addresses (cannot customize):

```
info@moyoungdemocrats.org (default)
andrew@moyoungdemocrats.org
collegedems@moyoungdemocrats.org
comms@moyoungdemocrats.org
creators@moyoungdemocrats.org
events@moyoungdemocrats.org
eboard@moyoungdemocrats.org
fundraising@moyoungdemocrats.org
highschool@moyoungdemocrats.org
members@moyoungdemocrats.org
membership@moyoungdemocrats.org
policy@moyoungdemocrats.org
political-affairs@moyoungdemocrats.org
```

You can customize the **display name** but not the actual sender address.

### Data Guarantees

1. **Sent emails** appear in `email_logs` immediately after sending
2. **Received emails** sync when calling `get-member-emails` with `syncToDatabase=true`
3. **History table** updates automatically via database triggers (may take a few seconds)
4. **Member linking** is automatic based on `members.email` or `members.school_email`
5. **Non-members** can receive emails but won't have `member_id` links

---

## Troubleshooting

### Emails Not Showing After Send

```dart
// Check if email was logged
final log = await supabase
    .from('email_logs')
    .select()
    .eq('gmail_message_id', messageId)
    .single();

print('Status: ${log['status']}');
print('Member IDs: ${log['member_ids']}');
```

### Threading Not Working

```dart
// Verify thread emails
final thread = await supabase
    .from('member_email_history')
    .select('subject, gmail_message_id')
    .eq('gmail_thread_id', threadId);

print('Emails in thread: ${thread.length}');
```

### Member Not Found Error

```dart
// Verify member exists
final member = await supabase
    .from('members')
    .select('id, email, school_email')
    .eq('id', memberId)
    .maybeSingle();

if (member == null) {
  print('Member does not exist');
} else {
  print('Email: ${member['email']}');
  print('School: ${member['school_email']}');
}
```

---

## Backend Auto-Sync Behavior

These happen automatically - you don't need to trigger them:

### Email → History Sync

- **Sent emails:** Immediately synced from `email_logs` to `member_email_history`
- **Received emails:** Synced from `email_inbox` to `member_email_history` when cached
- **Multiple recipients:** Creates one history record per member

### Member Linking

When sending emails, the system:
1. Extracts all recipient addresses (to, cc, bcc)
2. Matches against `members.email` and `members.school_email`
3. Populates `member_ids` array in `email_logs`
4. Creates junction records in `email_log_members`

---

**Document Version:** 1.0  
**Last Updated:** November 16, 2025  
**Maintainer:** Andrew
