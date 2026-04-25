
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/caching/config/hive_cache_client.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/caching/utils/caching_constants.dart';

class FcmCacheClient extends HiveCacheClient<String> {

  @override
  String get tableName => CachingConstants.fcmCacheBoxName;
}