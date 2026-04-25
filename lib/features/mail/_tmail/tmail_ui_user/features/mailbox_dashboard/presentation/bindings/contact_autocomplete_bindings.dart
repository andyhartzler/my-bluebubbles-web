
import 'package:get/get.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/base/base_bindings.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/composer/data/datasource/contact_datasource.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/composer/data/datasource_impl/contact_datasource_impl.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/composer/data/repository/contact_repository_impl.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/composer/domain/repository/contact_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/composer/domain/usecases/get_device_contact_suggestions_interactor.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/exceptions/thrower/cache_exception_thrower.dart';

class ContactAutoCompleteBindings extends BaseBindings {

  @override
  void bindingsController() {}

  @override
  void bindingsDataSource() {
    // MOYD CRM patch — registerEdgeFnDataSources() already put a permanent
    // ContactDataSource (EdgeFnContactDataSource) at MailScreen mount.
    // Skip overwriting it so the autocomplete on dashboard search /
    // forward-recipient hits the CRM members directory like the composer
    // does. If the global registration is missing for some reason, fall
    // back to tmail's tagged impl rather than crash.
    if (!Get.isRegistered<ContactDataSource>()) {
      Get.put<ContactDataSource>(Get.find<ContactDataSourceImpl>());
    }
  }

  @override
  void bindingsDataSourceImpl() {
    // Still construct the impl-keyed binding so the legacy fallback path
    // above (and any tmail code path that does Get.find<ContactDataSourceImpl>)
    // still resolves. The impl is harmless when unused.
    if (!Get.isRegistered<ContactDataSourceImpl>()) {
      Get.put(ContactDataSourceImpl(Get.find<CacheExceptionThrower>()));
    }
  }

  @override
  void bindingsInteractor() {
    Get.put(GetDeviceContactSuggestionsInteractor(Get.find<ContactRepository>()));
  }

  @override
  void bindingsRepository() {
    Get.put<ContactRepository>(Get.find<ContactRepositoryImpl>());
  }

  @override
  void bindingsRepositoryImpl() {
    Get.put(ContactRepositoryImpl(Get.find<ContactDataSource>()));
  }
}