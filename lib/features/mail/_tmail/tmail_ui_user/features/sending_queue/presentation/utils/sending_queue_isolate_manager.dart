
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/base/isolate/isolate_manager.dart';

class SendingQueueIsolateManager extends IsolateManager {

  @override
  String get isolateIdentityName => 'sending_queue_isolate';
}