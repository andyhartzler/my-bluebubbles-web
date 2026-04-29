// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_composing_email.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SavedComposingEmail _$SavedComposingEmailFromJson(Map<String, dynamic> json) =>
    SavedComposingEmail(
      content: json['content'] as String,
      subject: json['subject'] as String,
      toRecipients: (json['toRecipients'] as List<dynamic>)
          .map((e) => EmailAddress.fromJson(e as Map<String, dynamic>))
          .toSet(),
      ccRecipients: (json['ccRecipients'] as List<dynamic>)
          .map((e) => EmailAddress.fromJson(e as Map<String, dynamic>))
          .toSet(),
      bccRecipients: (json['bccRecipients'] as List<dynamic>)
          .map((e) => EmailAddress.fromJson(e as Map<String, dynamic>))
          .toSet(),
      replyToRecipients: (json['replyToRecipients'] as List<dynamic>)
          .map((e) => EmailAddress.fromJson(e as Map<String, dynamic>))
          .toSet(),
      attachments: (json['attachments'] as List<dynamic>)
          .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
          .toList(),
      identity: json['identity'] == null
          ? null
          : Identity.fromJson(json['identity'] as Map<String, dynamic>),
      hasReadReceipt: json['hasReadReceipt'] as bool,
      isMarkAsImportant: json['isMarkAsImportant'] as bool? ?? false,
    );

Map<String, dynamic> _$SavedComposingEmailToJson(
  SavedComposingEmail instance,
) => <String, dynamic>{
  'content': instance.content,
  'subject': instance.subject,
  'toRecipients': instance.toRecipients.map((e) => e.toJson()).toList(),
  'ccRecipients': instance.ccRecipients.map((e) => e.toJson()).toList(),
  'bccRecipients': instance.bccRecipients.map((e) => e.toJson()).toList(),
  'replyToRecipients': instance.replyToRecipients
      .map((e) => e.toJson())
      .toList(),
  'attachments': instance.attachments.map((e) => e.toJson()).toList(),
  'identity': ?instance.identity?.toJson(),
  'hasReadReceipt': instance.hasReadReceipt,
  'isMarkAsImportant': instance.isMarkAsImportant,
};
