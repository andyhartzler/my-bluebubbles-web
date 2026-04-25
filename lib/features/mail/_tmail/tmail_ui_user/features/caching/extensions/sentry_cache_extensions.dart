// Minimal extension shims — the original file had a much richer API
// driven by tmail's Sentry telemetry features that we don't ship.
// These shims let fcm_message_controller compile.

import 'package:bluebubbles/features/mail/_tmail/_stubs/sentry_flutter.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/caching/entries/sentry_configuration_cache.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/caching/entries/sentry_user_cache.dart';

extension ConfigCacheToSentryConfig on SentryConfigurationCache {
  SentryConfig toSentryConfig() => SentryConfig(
    dsn: dsn,
    environment: environment,
    release: release,
    tracesSampleRate: tracesSampleRate,
    profilesSampleRate: profilesSampleRate,
    isAvailable: false,
  );
}

extension UserCacheToSentryUser on SentryUserCache {
  SentryUser toSentryUser() => SentryUser(
    id: this.id,
    name: this.name,
    username: this.username,
    email: this.email,
  );
}
