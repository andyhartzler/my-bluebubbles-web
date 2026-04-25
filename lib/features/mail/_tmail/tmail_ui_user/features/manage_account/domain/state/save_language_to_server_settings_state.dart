import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:flutter/widgets.dart';

class SavingLanguageToServerSettings extends LoadingState {}

class SaveLanguageToServerSettingsSuccess extends UIState {
  SaveLanguageToServerSettingsSuccess(this.locale);

  final Locale locale;

  @override
  List<Object?> get props => [locale];
}

class SaveLanguageToServerSettingsFailure extends FeatureFailure {
  SaveLanguageToServerSettingsFailure({super.exception});
}