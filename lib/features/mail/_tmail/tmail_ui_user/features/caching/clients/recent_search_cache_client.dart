
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/caching/config/hive_cache_client.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/data/model/recent_search_cache.dart';

class RecentSearchCacheClient extends HiveCacheClient<RecentSearchCache> {

  @override
  String get tableName => 'RecentSearchCache';
}