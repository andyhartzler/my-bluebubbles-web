import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class GettingThreadDetailStatus extends LoadingState {}

class GetThreadDetailStatusSuccess extends UIState {
  GetThreadDetailStatusSuccess(this.threadDetailEnabled);

  final bool threadDetailEnabled;

  @override
  List<Object?> get props => [threadDetailEnabled];
}

class GetThreadDetailStatusFailure extends FeatureFailure {
  GetThreadDetailStatusFailure({super.exception});
}