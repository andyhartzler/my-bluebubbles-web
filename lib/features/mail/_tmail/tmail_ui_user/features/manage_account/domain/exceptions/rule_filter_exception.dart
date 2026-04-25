import 'package:bluebubbles/features/mail/_tmail/core/domain/exceptions/app_base_exception.dart';

class RuleFilterNotBindingException extends AppBaseException {
  RuleFilterNotBindingException([super.message]);

  @override
  String get exceptionName => 'RuleFilterNotBindingException';
}
