import 'package:bluebubbles/features/mail/_tmail/core/core.dart';

class DeleteIdentityLoading extends UIState {}

class DeleteIdentitySuccess extends UIState {

  DeleteIdentitySuccess();

  @override
  List<Object?> get props => [];
}

class DeleteIdentityFailure extends FeatureFailure {

  DeleteIdentityFailure(dynamic exception) : super(exception: exception);
}