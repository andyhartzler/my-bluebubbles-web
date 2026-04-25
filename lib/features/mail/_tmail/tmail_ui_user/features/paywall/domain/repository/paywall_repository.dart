import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/paywall/domain/model/paywall_url_pattern.dart';

abstract class PaywallRepository {
  Future<PaywallUrlPattern> getPaywallUrl(String baseUrl);
}
