
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/caching/config/hive_cache_client.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/caching/utils/caching_constants.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/push_notification/data/model/firebase_registration_cache.dart';

class FirebaseRegistrationCacheClient extends HiveCacheClient<FirebaseRegistrationCache> {

  @override
  String get tableName => CachingConstants.firebaseRegistrationCacheBoxName;
}