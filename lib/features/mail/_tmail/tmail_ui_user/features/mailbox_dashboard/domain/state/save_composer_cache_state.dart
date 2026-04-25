import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class SaveComposerCacheSuccess extends UIState {}

class SaveComposerCacheFailure extends FeatureFailure {

  SaveComposerCacheFailure(dynamic exception) : super(exception: exception);
}