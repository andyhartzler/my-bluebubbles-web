import 'package:get/get.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/quotas/domain/use_case/get_quotas_interactor.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/quotas/presentation/quotas_controller.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/quotas/presentation/quotas_interactor_bindings.dart';

class QuotasBindings extends Bindings {
  @override
  void dependencies() {
    QuotasInteractorBindings().dependencies();
    Get.put(QuotasController(Get.find<GetQuotasInteractor>()));
  }
}