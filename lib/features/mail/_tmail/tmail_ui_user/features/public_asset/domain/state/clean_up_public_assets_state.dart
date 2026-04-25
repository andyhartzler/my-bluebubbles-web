import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class CleaningUpPublicAssetsState extends LoadingState {}

class CleanUpPublicAssetsSuccessState extends UIState {}

class CleanUpPublicAssetsFailureState extends FeatureFailure {
  CleanUpPublicAssetsFailureState({super.exception});
}