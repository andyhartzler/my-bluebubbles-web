import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/core/utils/app_logger.dart';
import 'package:dartz/dartz.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/domain/repository/app_grid_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/domain/state/get_app_dashboard_configuration_state.dart';

class GetAppDashboardConfigurationInteractor {
  final AppGridRepository _appGridRepository;

  GetAppDashboardConfigurationInteractor(this._appGridRepository);

  Stream<Either<Failure, Success>> execute(String path) async* {
    try {
      yield Right(LoadingAppDashboardConfiguration());
      final linagoraApps = await _appGridRepository.getLinagoraApplicationsFromEnvironment(path);
      yield Right(GetAppDashboardConfigurationSuccess(linagoraApps.apps));
    } catch (e) {
      logWarning('GetAppDashboardConfigurationInteractor::execute(): $e');
      yield Left(GetAppDashboardConfigurationFailure(e));
    }
  }
}