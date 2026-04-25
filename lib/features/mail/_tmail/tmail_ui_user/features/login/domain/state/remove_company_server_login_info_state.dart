import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class RemovingCompanyServerLoginInfo extends LoadingState {}

class RemoveCompanyServerLoginInfoSuccess extends UIState {}

class RemoveCompanyServerLoginInfoFailure extends FeatureFailure {
  RemoveCompanyServerLoginInfoFailure(dynamic exception)
      : super(exception: exception);
}
