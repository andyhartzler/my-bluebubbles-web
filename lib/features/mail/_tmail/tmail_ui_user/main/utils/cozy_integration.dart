import 'package:bluebubbles/features/mail/_tmail/core/utils/app_logger.dart';
import 'package:bluebubbles/features/mail/_tmail/core/utils/platform_info.dart';
import 'package:cozy/cozy_config_manager/cozy_config_manager.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/utils/app_config.dart';

class CozyIntegration {
  const CozyIntegration._();

  static Future<void> integrateCozy() async {
    if (!PlatformInfo.isWeb || !AppConfig.isCozyIntegrationEnabled) return;

    try {
      final cozyConfig = CozyConfigManager();
      await cozyConfig.injectCozyScript(AppConfig.cozyExternalBridgeVersion);
      await cozyConfig.initialize();
    } catch (e) {
      logWarning('CozyIntegration::integrateCozy:Exception = $e');
    }
  }
}