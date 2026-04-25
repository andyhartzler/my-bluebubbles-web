import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:dartz/dartz.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/domain/repository/notification_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/domain/state/toggle_notification_setting_state.dart';

class ToggleNotificationSettingInteractor {

  final NotificationRepository _notificationRepository;

  ToggleNotificationSettingInteractor(this._notificationRepository);

  Stream<Either<Failure, Success>> execute() async* {
    try {
      yield Right(TogglingNotificationSetting());
      await _notificationRepository.toggleNotificationSetting();
      yield Right(ToggleNotificationSettingSuccess());
    } catch (_) {
      yield Left(ToggleNotificationSettingFailure());
    }
  }
}