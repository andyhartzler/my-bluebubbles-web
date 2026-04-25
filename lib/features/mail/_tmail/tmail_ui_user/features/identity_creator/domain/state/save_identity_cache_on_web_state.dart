import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class SavingIdentityCacheOnWeb extends LoadingState {}

class SaveIdentityCacheOnWebSuccess extends UIState {}

class SaveIdentityCacheOnWebFailure extends FeatureFailure {
  SaveIdentityCacheOnWebFailure({super.exception});
}