import 'package:bluebubbles/features/mail/_tmail/core/domain/exceptions/app_base_exception.dart';

class SpamDismissCooldownActiveException extends AppBaseException {
  SpamDismissCooldownActiveException([super.message]);

  @override
  String get exceptionName => 'SpamDismissCooldownActiveException';
}

class NotFoundSpamMailboxCachedException extends AppBaseException {
  NotFoundSpamMailboxCachedException([super.message]);

  @override
  String get exceptionName => 'NotFoundSpamMailboxCachedException';
}

class NotFoundSpamMailboxException extends AppBaseException {
  NotFoundSpamMailboxException([super.message]);

  @override
  String get exceptionName => 'NotFoundSpamMailboxException';
}

class NoUnreadSpamEmailsException extends AppBaseException {
  NoUnreadSpamEmailsException([super.message]);

  @override
  String get exceptionName => 'NoUnreadSpamEmailsException';
}
