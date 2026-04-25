import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class MovingPreviewEmailEMLContentFromPersistentToMemory extends LoadingState {}

class MovePreviewEmailEMLContentFromPersistentToMemorySuccess extends UIState {}

class MovePreviewEmailEMLContentFromPersistentToMemoryFailure extends FeatureFailure {

  MovePreviewEmailEMLContentFromPersistentToMemoryFailure(dynamic exception) : super(exception: exception);
}