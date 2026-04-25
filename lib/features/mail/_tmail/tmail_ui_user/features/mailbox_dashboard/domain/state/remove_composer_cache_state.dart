import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class RemoveComposerCacheSuccess extends UIState {

  RemoveComposerCacheSuccess();

  @override
  List<Object?> get props => [];
}

class RemoveComposerCacheFailure extends FeatureFailure {

  RemoveComposerCacheFailure(dynamic exception) : super(exception: exception);
}