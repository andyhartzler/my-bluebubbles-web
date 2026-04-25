
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/caching/config/hive_cache_client.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/thread/data/model/email_cache.dart';

class EmailCacheClient extends HiveCacheClient<EmailCache> {

  @override
  String get tableName => 'EmailCache';
}