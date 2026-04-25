import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class GenerateEmailLoading extends LoadingState {}

class GenerateEmailFailure extends FeatureFailure {

  GenerateEmailFailure(dynamic exception) : super(exception: exception);
}