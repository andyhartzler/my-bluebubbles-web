import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/views/html_viewer/html_content_viewer_on_web_widget.dart';
import 'package:bluebubbles/features/mail/providers/mail_thread_provider.dart';
import 'package:bluebubbles/features/mail/services/tmail_bridge.dart';

class MailThreadView extends StatelessWidget {
  const MailThreadView({
    super.key,
    required this.threadId,
    this.initialSubject,
  });

  final String threadId;
  final String? initialSubject;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MailThreadProvider()..load(threadId),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: BrandedBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ThreadHeader(initialSubject: initialSubject),
                  const SizedBox(height: 12),
                  Expanded(child: _ThreadBody(threadId: threadId)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({this.initialSubject});
  final String? initialSubject;

  @override
  Widget build(BuildContext context) {
    final thread = context.watch<MailThreadProvider>();
    String? subject = initialSubject;
    if (thread.messages.isNotEmpty) {
      final headers = _headerMap(thread.messages.first);
      final s = headers['subject'];
      if (s != null && s.isNotEmpty) subject = s;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          gradient: BrandColors.getTileGradient(),
          boxShadow: [
            BoxShadow(
              color: BrandColors.unityBlue.withOpacity(0.32),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back to inbox',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            Expanded(
              child: Text(
                subject ?? 'Loading…',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadBody extends StatelessWidget {
  const _ThreadBody({required this.threadId});
  final String threadId;

  @override
  Widget build(BuildContext context) {
    final thread = context.watch<MailThreadProvider>();
    if (thread.loading && thread.messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Colors.white),
        ),
      );
    }
    if (thread.error != null && thread.messages.isEmpty) {
      return _ThreadError(
        error: thread.error!,
        onRetry: () => context.read<MailThreadProvider>().load(threadId),
      );
    }
    if (thread.messages.isEmpty) {
      return const Center(
        child: Text(
          'Empty thread',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    return ListView.separated(
      itemCount: thread.messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _MessageBubble(message: thread.messages[i]),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({required this.message});
  final Map<String, dynamic> message;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  @override
  void initState() {
    super.initState();
    ensureTmailGetXBindings();
  }

  @override
  Widget build(BuildContext context) {
    final headers = _headerMap(widget.message);
    final from = headers['from'] ?? '';
    final to = headers['to'] ?? '';
    final dateStr = headers['date'] ?? '';
    final htmlBody = _extractHtmlBody(widget.message);
    final plainBody = _extractPlainBody(widget.message);
    final width = MediaQuery.of(context).size.width;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.97),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Row(label: 'From', value: from),
          if (to.isNotEmpty) _Row(label: 'To', value: to),
          if (dateStr.isNotEmpty) _Row(label: 'Date', value: dateStr),
          const SizedBox(height: 10),
          if (htmlBody.isNotEmpty)
            // tmail's HtmlContentViewerOnWeb renders email HTML inside a
            // sandboxed iframe with mailto/link interception. Used in
            // place of a SelectableText fallback when the message
            // contains a text/html body part.
            HtmlContentViewerOnWeb(
              contentHtml: htmlBody,
              widthContent: width - 80,
              autoAdjustHeight: true,
              keepAlive: true,
              useDefaultFontStyle: true,
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                plainBody.isEmpty ? '(no body)' : plainBody,
                style: const TextStyle(color: Colors.black87, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    // Bubble switched to white surface to match tmail's HtmlContentViewerOnWeb
    // which renders inside a white iframe — keep header rows readable.
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadError extends StatelessWidget {
  const _ThreadError({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.white.withOpacity(0.85),
          ),
          const SizedBox(height: 12),
          const Text(
            'Could not load thread',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.78),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('Retry', style: TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withOpacity(0.7)),
            ),
          ),
        ],
      ),
    );
  }
}

Map<String, String> _headerMap(Map<String, dynamic> message) {
  final out = <String, String>{};
  final payload = message['payload'];
  if (payload is Map) {
    final headers = payload['headers'];
    if (headers is List) {
      for (final h in headers) {
        if (h is Map) {
          final name = (h['name'] as String?)?.toLowerCase();
          final value = h['value'] as String?;
          if (name != null && value != null) out[name] = value;
        }
      }
    }
  }
  return out;
}

/// Returns the raw HTML body of the message, if any. Used by the
/// HtmlContentViewerOnWeb renderer.
String _extractHtmlBody(Map<String, dynamic> message) {
  final payload = message['payload'];
  if (payload is! Map) return '';
  final html = _findPart(payload, 'text/html');
  if (html != null) return _decode(html);
  return '';
}

/// Walks the Gmail payload tree and returns the first plain-text body
/// found. Falls back to a stripped HTML body if no text/plain part is
/// present.
String _extractPlainBody(Map<String, dynamic> message) {
  final payload = message['payload'];
  if (payload is! Map) return '';
  final plain = _findPart(payload, 'text/plain');
  if (plain != null) return _decode(plain);
  final html = _findPart(payload, 'text/html');
  if (html != null) {
    final raw = _decode(html);
    return raw.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('&nbsp;', ' ');
  }
  // Top-level body might still contain data even with no MIME type.
  final body = payload['body'];
  if (body is Map && body['data'] is String) {
    return _b64urlDecode(body['data'] as String);
  }
  final snippet = message['snippet'];
  return snippet is String ? snippet : '';
}

Map<String, dynamic>? _findPart(Map part, String mimeType) {
  if ((part['mimeType'] as String?)?.toLowerCase() == mimeType) {
    return Map<String, dynamic>.from(part);
  }
  final parts = part['parts'];
  if (parts is List) {
    for (final p in parts) {
      if (p is Map) {
        final found = _findPart(p, mimeType);
        if (found != null) return found;
      }
    }
  }
  return null;
}

String _decode(Map<String, dynamic> part) {
  final body = part['body'];
  if (body is Map && body['data'] is String) {
    return _b64urlDecode(body['data'] as String);
  }
  return '';
}

String _b64urlDecode(String s) {
  final pad = '=' * ((4 - s.length % 4) % 4);
  final b64 = (s + pad).replaceAll('-', '+').replaceAll('_', '/');
  try {
    return utf8.decode(base64.decode(b64));
  } catch (_) {
    return '';
  }
}
