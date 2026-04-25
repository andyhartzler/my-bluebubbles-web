import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:jmap_dart_client/jmap/mail/vacation/vacation_response.dart';

class LoadingUpdateVacation extends UIState {}

class UpdateVacationSuccess extends UIState {
  final List<VacationResponse> listVacationResponse;
  final bool isAuto;

  UpdateVacationSuccess(this.listVacationResponse, this.isAuto);

  @override
  List<Object?> get props => [listVacationResponse, isAuto];
}

class UpdateVacationFailure extends FeatureFailure {

  UpdateVacationFailure(exception) : super(exception: exception);
}