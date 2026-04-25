import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/core/utils/app_logger.dart';
import 'package:jmap_dart_client/jmap/core/state.dart' as jmap;
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/base/action/ui_action.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/presentation/action/mailbox_ui_action.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/push_notification/presentation/action/push_notification_state_change_action.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/push_notification/presentation/listener/change_listener.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/routes/route_navigation.dart';

class MailboxChangeListener extends ChangeListener {
  MailboxDashBoardController? _dashBoardController;

  MailboxChangeListener._internal() {
    try {
      _dashBoardController = getBinding<MailboxDashBoardController>();
    } catch (e) {
      logWarning(
          'MailboxChangeListener::_internal(): IS NOT REGISTERED: ${e.toString()}');
    }
  }

  static final MailboxChangeListener _instance =
      MailboxChangeListener._internal();

  static MailboxChangeListener get instance => _instance;

  @override
  void dispatchActions(List<Action> actions) {
    log('MailboxChangeListener::dispatchActions():actions: $actions');
    for (var action in actions) {
      if (action is SynchronizeMailboxOnForegroundAction) {
        _synchronizeMailboxOnForegroundAction(action.newState);
      }
    }
  }

  @override
  void handleFailureViewState(Failure failure) {
    log('MailboxChangeListener::_handleFailureViewState(): $failure');
  }

  @override
  void handleSuccessViewState(Success success) {
    log('MailboxChangeListener::_handleSuccessViewState(): $success');
  }

  void _synchronizeMailboxOnForegroundAction(jmap.State newState) {
    log('MailboxChangeListener::_synchronizeMailboxOnForegroundAction():newState: $newState');
    _dashBoardController?.dispatchMailboxUIAction(RefreshChangeMailboxAction(
      newState: newState,
    ));
  }
}
