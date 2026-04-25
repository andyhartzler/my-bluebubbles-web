import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/model/oidc/oidc_configuration.dart';

class GetStoredOidcConfigurationLoading extends LoadingState {}

class GetStoredOidcConfigurationSuccess extends UIState {
  final OIDCConfiguration oidcConfiguration;

  GetStoredOidcConfigurationSuccess(this.oidcConfiguration);

  @override
  List<Object?> get props => [oidcConfiguration];
}

class GetStoredOidcConfigurationFailure extends FeatureFailure {

  GetStoredOidcConfigurationFailure(dynamic exception) : super(exception: exception);
}