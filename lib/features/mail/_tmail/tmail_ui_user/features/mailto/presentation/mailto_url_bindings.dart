import 'package:get/get.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailto/presentation/mailto_url_controller.dart';

class MailtoUrlBindings extends Bindings {

  @override
  void dependencies() {
    Get.lazyPut(() => MailtoUrlController());
  }
}