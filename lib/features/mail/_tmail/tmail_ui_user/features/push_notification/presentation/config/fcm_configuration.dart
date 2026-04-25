
import 'package:bluebubbles/features/mail/_tmail/core/utils/app_logger.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/push_notification/presentation/config/firebase_options.dart';

class FcmConfiguration {
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      logWarning('FcmConfiguration::initialize: Exception = $e');
    }
  }
}