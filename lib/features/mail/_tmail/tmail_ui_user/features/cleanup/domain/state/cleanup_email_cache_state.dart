import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class CleanupEmailCacheSuccess extends UIState {}

class CleanupEmailCacheFailure extends FeatureFailure {

  CleanupEmailCacheFailure(dynamic exception) : super(exception: exception);
}