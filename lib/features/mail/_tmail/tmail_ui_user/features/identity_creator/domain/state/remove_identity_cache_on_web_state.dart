import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class RemovingIdentityCacheOnWeb extends LoadingState {}

class RemoveIdentityCacheOnWebSuccess extends UIState {}

class RemoveIdentityCacheOnWebFailure extends FeatureFailure {
  RemoveIdentityCacheOnWebFailure({super.exception});
}