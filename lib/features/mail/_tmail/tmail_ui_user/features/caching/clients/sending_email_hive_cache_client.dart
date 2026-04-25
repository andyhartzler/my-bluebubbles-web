
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/caching/config/hive_cache_client.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/caching/utils/caching_constants.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/offline_mode/model/sending_email_hive_cache.dart';

class SendingEmailHiveCacheClient extends HiveCacheClient<SendingEmailHiveCache> {

  @override
  String get tableName => CachingConstants.sendingEmailCacheBoxName;

  @override
  bool get encryption => true;
}