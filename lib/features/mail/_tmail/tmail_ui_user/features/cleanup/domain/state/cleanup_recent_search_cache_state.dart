import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class CleanupRecentSearchCacheLoading extends LoadingState {}

class CleanupRecentSearchCacheSuccess extends UIState {}

class CleanupRecentSearchCacheFailure extends FeatureFailure {

  CleanupRecentSearchCacheFailure(dynamic exception) : super(exception: exception);
}