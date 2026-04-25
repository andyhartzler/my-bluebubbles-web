import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class CleanupRecentLoginUrlCacheSuccess extends UIState {}

class CleanupRecentLoginUrlCacheFailure extends FeatureFailure {

  CleanupRecentLoginUrlCacheFailure(dynamic exception) : super(exception: exception);
}