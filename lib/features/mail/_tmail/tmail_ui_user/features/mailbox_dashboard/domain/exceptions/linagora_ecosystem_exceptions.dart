import 'package:bluebubbles/features/mail/_tmail/core/domain/exceptions/app_base_exception.dart';

class NotFoundLinagoraEcosystem extends AppBaseException {
  NotFoundLinagoraEcosystem([super.message]);

  @override
  String get exceptionName => 'NotFoundLinagoraEcosystem';
}

class NotFoundPaywallUrl extends AppBaseException {
  NotFoundPaywallUrl([super.message]);

  @override
  String get exceptionName => 'NotFoundPaywallUrl';
}
