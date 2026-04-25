import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class RemovingPreviewEmailEMLContentShared extends LoadingState {}

class RemovePreviewEmailEMLContentSharedSuccess extends UIState {}

class RemovePreviewEmailEMLContentSharedFailure extends FeatureFailure {

  RemovePreviewEmailEMLContentSharedFailure(dynamic exception) : super(exception: exception);
}