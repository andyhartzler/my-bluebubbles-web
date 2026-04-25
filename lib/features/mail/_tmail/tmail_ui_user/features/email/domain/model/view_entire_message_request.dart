import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/attachment.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/presentation_email.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/localizations/app_localizations.dart';

class ViewEntireMessageRequest with EquatableMixin {
  final String ownEmailAddress;
  final PresentationEmail presentationEmail;
  final List<Attachment> attachments;
  final String emailContent;
  final Locale locale;
  final AppLocalizations appLocalizations;

  ViewEntireMessageRequest({
    required this.ownEmailAddress,
    required this.presentationEmail,
    required this.attachments,
    required this.emailContent,
    required this.locale,
    required this.appLocalizations,
  });

  @override
  List<Object?> get props => [
    ownEmailAddress,
    presentationEmail,
    attachments,
    emailContent,
    locale,
    appLocalizations,
  ];
}