import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/identity_creator/domain/model/identity_cache.dart';

class GettingIdentityCacheOnWeb extends LoadingState {}

class GetIdentityCacheOnWebSuccess extends UIState {
  GetIdentityCacheOnWebSuccess(this.identityCache);

  final IdentityCache? identityCache;

  @override
  List<Object?> get props => [identityCache];
}

class GetIdentityCacheOnWebFailure extends FeatureFailure {
  GetIdentityCacheOnWebFailure({super.exception});
}