import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:universal_io/io.dart' as io;

/// Exception thrown when the CRM email relay encounters an error.
class CRMEmailException implements Exception {
  final String message;
  final Object? cause;

  CRMEmailException(this.message, {this.cause});

  @override
  String toString() => 'CRMEmailException: $message';
}

/// Attachment payload understood by the Supabase email relay function.
class CRMEmailAttachment {
  final String filename;
  final String mimeType;
  final String content;

  const CRMEmailAttachment({
    required this.filename,
    required this.mimeType,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'mimeType': mimeType,
        'content': content,
      };
}

/// Result returned by the CRM email relay service.
class CRMEmailResult {
  final bool success;
  final int statusCode;
  final Map<String, dynamic>? data;

  const CRMEmailResult({
    required this.success,
    required this.statusCode,
    this.data,
  });
}

/// Service responsible for sending transactional emails through the
/// Supabase-hosted Gmail relay.
class CRMEmailService {
  CRMEmailService._internal();

  static final CRMEmailService instance = CRMEmailService._internal();

  factory CRMEmailService() => instance;

  static const String _endpoint =
      'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/send-email';

  http.Client? _client;

  http.Client get _httpClient => _client ??= http.Client();

  /// Replaces the internal HTTP client. Intended for testing.
  @visibleForTesting
  void debugSetClient(http.Client? client) {
    _client?.close();
    _client = client;
  }

  /// Sends an email to the provided recipients. Throws a
  /// [CRMEmailException] when validation fails or the HTTP request
  /// returns a non-success status code.
  Future<CRMEmailResult> sendEmail({
    required List<String> to,
    required String subject,
    String? htmlBody,
    String? textBody,
    String? fromEmail,
    String? fromName,
    String? replyTo,
    List<String>? cc,
    List<String>? bcc,
    Map<String, dynamic>? variables,
    List<CRMEmailAttachment> attachments = const [],
  }) async {
    final recipients = _sanitizeEmails(to);
    if (recipients.isEmpty) {
      throw CRMEmailException('At least one recipient email is required.');
    }

    final trimmedSubject = subject.trim();
    if (trimmedSubject.isEmpty) {
      throw CRMEmailException('Email subject is required.');
    }

    final trimmedHtml = htmlBody?.trim() ?? '';
    final trimmedText = textBody?.trim() ?? '';

    if (trimmedHtml.isEmpty && trimmedText.isEmpty) {
      throw CRMEmailException('Email body is required. Provide HTML or plain text.');
    }

    final resolvedHtml =
        trimmedHtml.isNotEmpty ? trimmedHtml : _convertPlainTextToHtml(trimmedText);

    final payload = <String, dynamic>{
      'to': recipients.length == 1 ? recipients.first : recipients,
      'subject': trimmedSubject,
      'htmlBody': resolvedHtml,
    };

    final ccList = _sanitizeEmails(cc);
    if (ccList.isNotEmpty) {
      payload['cc'] = ccList.length == 1 ? ccList.first : ccList;
    }

    final bccList = _sanitizeEmails(bcc);
    if (bccList.isNotEmpty) {
      payload['bcc'] = bccList.length == 1 ? bccList.first : bccList;
    }

    if (textBody != null && textBody.trim().isNotEmpty) {
      payload['textBody'] = textBody.trim();
    }

    final singleFromEmail = _sanitizeSingleEmail(fromEmail);
    if (singleFromEmail != null) {
      payload['fromEmail'] = singleFromEmail;
    }

    final trimmedFromName = fromName?.trim() ?? '';
    if (trimmedFromName.isNotEmpty) {
      payload['fromName'] = trimmedFromName;
    }

    final singleReplyTo = _sanitizeSingleEmail(replyTo);
    if (singleReplyTo != null) {
      payload['replyTo'] = singleReplyTo;
    }

    if (variables != null && variables.isNotEmpty) {
      payload['variables'] = variables;
    }

    if (attachments.isNotEmpty) {
      payload['attachments'] = attachments.map((a) => a.toJson()).toList();
    }

    final authToken = _resolveAuthToken();
    if (authToken == null) {
      throw CRMEmailException(
        'Supabase credentials are not configured for the CRM email relay.',
      );
    }

    final response = await _httpClient.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    final statusCode = response.statusCode;
    Map<String, dynamic>? data;
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        // Ignore parsing errors – response may not be JSON on failure.
      }
    }

    if (statusCode >= 200 && statusCode < 300) {
      return CRMEmailResult(success: true, statusCode: statusCode, data: data);
    }

    final message = data != null
        ? (data['error'] ?? data['message'] ?? response.body)
        : response.body;
    throw CRMEmailException(
      message is String && message.isNotEmpty
          ? message
          : 'Failed to send email (HTTP $statusCode).',
    );
  }

  /// Convenience helper that extracts emails from the provided members
  /// and forwards the request to [sendEmail]. Members lacking a usable
  /// email address are ignored. Throws when no valid addresses remain.
  Future<CRMEmailResult> sendEmailToMembers({
    required List<Member> members,
    required String subject,
    String? htmlBody,
    String? textBody,
    String? fromEmail,
    String? fromName,
    String? replyTo,
    List<String>? cc,
    List<String>? bcc,
    Map<String, dynamic>? variables,
    List<CRMEmailAttachment> attachments = const [],
  }) async {
    final memberEmails = members
        .map((member) => member.preferredEmail)
        .whereType<String>()
        .map((email) => email.trim())
        .where((email) => email.isNotEmpty)
        .toList();

    if (memberEmails.isEmpty) {
      throw CRMEmailException('No member email addresses available.');
    }

    return sendEmail(
      to: memberEmails,
      subject: subject,
      htmlBody: htmlBody,
      textBody: textBody,
      fromEmail: fromEmail,
      fromName: fromName,
      replyTo: replyTo,
      cc: cc,
      bcc: bcc,
      variables: variables,
      attachments: attachments,
    );
  }

  /// Builds an email attachment from a [PlatformFile]. Returns null if the
  /// file could not be read or is empty.
  Future<CRMEmailAttachment?> buildAttachmentFromPlatformFile(
    PlatformFile file,
  ) async {
    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null && file.path!.isNotEmpty) {
      try {
        bytes = await io.File(file.path!).readAsBytes();
      } catch (error) {
        throw CRMEmailException(
          'Failed to read attachment "${file.name}": $error',
          cause: error,
        );
      }
    }

    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    final mimeType = lookupMimeType(file.name, headerBytes: bytes) ??
        'application/octet-stream';

    return CRMEmailAttachment(
      filename: file.name,
      mimeType: mimeType,
      content: base64Encode(bytes),
    );
  }

  String? _resolveAuthToken() {
    final serviceRole = CRMConfig.supabaseServiceRoleKey;
    if (serviceRole.isNotEmpty) {
      return serviceRole;
    }
    final anonKey = CRMConfig.supabaseAnonKey;
    if (anonKey.isNotEmpty) {
      return anonKey;
    }
    return null;
  }

  List<String> _sanitizeEmails(List<String>? values) {
    if (values == null || values.isEmpty) {
      return const [];
    }
    final seen = <String>{};
    final emails = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      final lower = trimmed.toLowerCase();
      if (seen.add(lower)) {
        emails.add(trimmed);
      }
    }
    return emails;
  }

  String? _sanitizeSingleEmail(String? value) {
    final sanitized = _sanitizeEmails(value == null ? null : [value]);
    return sanitized.isEmpty ? null : sanitized.first;
  }

  String _convertPlainTextToHtml(String text) {
    final escaped = const HtmlEscape().convert(text);
    final paragraphs = escaped.split(RegExp(r'\n{2,}'));
    return paragraphs
        .map((paragraph) =>
            '<p>${paragraph.replaceAll('\n', '<br>')}</p>')
        .join();
  }
}
