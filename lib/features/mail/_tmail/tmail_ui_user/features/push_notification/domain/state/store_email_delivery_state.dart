
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class StoreEmailDeliveryStateLoading extends UIState {}

class StoreEmailDeliveryStateSuccess extends UIState {}

class StoreEmailDeliveryStateFailure extends FeatureFailure {

  StoreEmailDeliveryStateFailure(dynamic exception) : super(exception: exception);
}