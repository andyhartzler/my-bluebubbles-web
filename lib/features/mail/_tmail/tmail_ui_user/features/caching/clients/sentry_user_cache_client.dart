import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/caching/config/hive_cache_client.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/caching/entries/sentry_user_cache.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/caching/utils/caching_constants.dart';

class SentryUserCacheClient
    extends HiveCacheClient<SentryUserCache> {
  @override
  String get tableName => CachingConstants.sentryUserCacheBoxName;

  @override
  bool get encryption => true;
}
