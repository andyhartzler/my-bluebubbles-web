import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class SaveRecentSearchSuccess extends UIState {}

class SaveRecentSearchFailure extends FeatureFailure {

  SaveRecentSearchFailure(dynamic exception) : super(exception: exception);
}