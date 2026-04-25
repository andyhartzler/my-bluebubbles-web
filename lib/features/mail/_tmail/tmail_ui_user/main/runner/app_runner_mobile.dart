import 'package:bluebubbles/features/mail/_tmail/core/utils/config/env_loader.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/runner/app_runner_base.dart';

Future<void> runAppWithMonitoring(Future<void> Function() runTmail) async {
  await runAppGuarded(() async {
    await EnvLoader.loadEnvFile();

    await runTmail();
  });
}
