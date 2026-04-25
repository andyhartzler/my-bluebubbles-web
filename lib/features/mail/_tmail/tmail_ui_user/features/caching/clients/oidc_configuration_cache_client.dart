import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/caching/config/hive_cache_client.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/caching/utils/caching_constants.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/login/data/model/oidc_configuration_cache.dart';

class OidcConfigurationCacheClient extends HiveCacheClient<OidcConfigurationCache> {

  @override
  String get tableName => CachingConstants.oidcConfigurationCacheBoxName;

  @override
  bool get encryption => true;
}