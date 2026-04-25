import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class StoreSessionLoading extends LoadingState {}

class StoreSessionSuccess extends UIState {}

class StoreSessionFailure extends FeatureFailure {

  StoreSessionFailure(dynamic exception) : super(exception: exception);
}