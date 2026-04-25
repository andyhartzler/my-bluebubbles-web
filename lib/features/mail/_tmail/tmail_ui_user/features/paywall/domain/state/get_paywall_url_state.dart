import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/paywall/domain/model/paywall_url_pattern.dart';

class GettingPaywallUrl extends LoadingState {}

class GetPaywallUrlSuccess extends UIState {
  final PaywallUrlPattern paywallUrlPattern;

  GetPaywallUrlSuccess(this.paywallUrlPattern);

  @override
  List<Object> get props => [paywallUrlPattern];
}

class GetPaywallUrlFailure extends FeatureFailure {
  GetPaywallUrlFailure(dynamic exception) : super(exception: exception);
}
