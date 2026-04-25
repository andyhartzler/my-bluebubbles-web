
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/caching/config/hive_cache_client.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/data/model/state_cache.dart';

class StateCacheClient extends HiveCacheClient<StateCache> {

  @override
  String get tableName => 'StateCache';
}