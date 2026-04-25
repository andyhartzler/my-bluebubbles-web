import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class CleanAndGetAllEmailLoading extends LoadingState {}

class CleanAndGetAllEmailFailure extends FeatureFailure {

  CleanAndGetAllEmailFailure(dynamic exception) : super(exception: exception);
}