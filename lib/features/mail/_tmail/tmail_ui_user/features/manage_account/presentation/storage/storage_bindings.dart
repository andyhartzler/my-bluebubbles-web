import 'package:get/get.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/presentation/storage/storage_controller.dart';

class StorageBindings extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => StorageController());
  }
}
