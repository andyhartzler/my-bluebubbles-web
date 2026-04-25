import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/domain/model/email_print.dart';

abstract class PrintFileDataSource {
  Future<void> printEmail(EmailPrint emailPrint);
}