import 'package:get/get.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email_recovery/presentation/email_recovery_controller.dart';

class EmailRecoveryBindings extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => EmailRecoveryController());
  }
}