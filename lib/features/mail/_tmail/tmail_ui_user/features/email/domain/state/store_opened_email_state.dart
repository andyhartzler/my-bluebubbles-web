import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class StoreOpenedEmailLoading extends UIState {}

class StoreOpenedEmailSuccess extends UIState {}

class StoreOpenedEmailFailure extends FeatureFailure {

  StoreOpenedEmailFailure(dynamic exception) : super(exception: exception);
}