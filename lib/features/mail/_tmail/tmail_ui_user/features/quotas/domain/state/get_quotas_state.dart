import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:jmap_dart_client/jmap/quotas/quota.dart';

class GetQuotasLoading extends LoadingState {}

class GetQuotasSuccess extends UIState {
  final List<Quota> quotas;

  GetQuotasSuccess(this.quotas);

  @override
  List<Object?> get props => [quotas];
}

class GetQuotasFailure extends FeatureFailure {

  GetQuotasFailure(dynamic exception) : super(exception: exception);
}
