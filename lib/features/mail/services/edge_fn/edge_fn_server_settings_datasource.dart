// Edge-function-backed implementation of tmail's ServerSettingsDataSource.
//
// MOYD CRM Phase 6 manage-account / dashboard server-settings.
//
// What tmail's ServerSettings actually carries:
//   - read.receipts.always         (bool)  — auto-send read receipts
//   - display.sender.priority      (bool)  — show priority badge in list
//   - language                     (String) — UI language
//   - ai.needs-action.enabled      (bool)  — AI "needs action" labeling
//
// None of these have a Gmail-side equivalent that round-trips cleanly:
//   - Gmail does not expose a "send read receipts" toggle in its API.
//   - Sender priority and AI needs-action are tmail UI features that have
//     no JMAP-to-Gmail mapping (they require tmail's own server-side
//     prediction service which we do not run).
//   - Language is a UI preference; the CRM is English-only today.
//
// Why we still implement it:
//   The dashboard controller calls getServerSetting() during boot. If the
//   call fails, the controller surfaces a generic GetServerSettingFailure
//   in onError. That doesn't block the UI but pollutes logs and degrades
//   trust in dashboard health. Returning a synthetic, sensible-defaults
//   payload makes the call succeed cleanly.
//
// Why we do NOT round-trip to Supabase:
//   None of these prefs are wired into the rest of the CRM. If/when we
//   want per-user UI prefs we'll add a `mail_user_prefs` table, but
//   right now the read.receipts / sender-priority / ai-needs-action
//   features simply do not exist in our deployment, so persisting their
//   "off" state would be performative.
//
// Update behavior:
//   updateServerSettings echoes the requested settings back to the
//   caller. The dashboard's UpdateServerSettingInteractor is happy with
//   that — it just wants to see a TMailServerSettings with the merged
//   options. No persistence happens; on next boot the defaults reload.
//   This is honest: we tell tmail "yep, saved" but the user's choice
//   doesn't survive a refresh because we have no UI surface for them
//   in the CRM today. If product wants this, the followup is
//   straightforward (table + RLS + repository round-trip).

import 'dart:async';

import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';

import 'package:bluebubbles/features/mail/_tmail/server_settings/server_settings/server_settings_id.dart';
import 'package:bluebubbles/features/mail/_tmail/server_settings/server_settings/tmail_server_settings.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/server_settings/data/datasource/server_settings_data_source.dart';

class EdgeFnServerSettingsDataSource implements ServerSettingsDataSource {
  EdgeFnServerSettingsDataSource();

  /// Sensible CRM defaults — all of these are off / English. The dashboard
  /// settingOption check requires a non-null `settings` object (not just a
  /// non-null TMailServerSettings), so populate every field explicitly.
  TMailServerSettingOptions _defaultOptions() {
    return TMailServerSettingOptions(
      alwaysReadReceipts: false,
      displaySenderPriority: false,
      language: 'en',
      aiNeedsActionEnabled: false,
    );
  }

  TMailServerSettings _defaultSettings() {
    return TMailServerSettings(
      id: ServerSettingsIdExtension.serverSettingsIdSingleton,
      settings: _defaultOptions(),
    );
  }

  @override
  Future<TMailServerSettings> getServerSettings(AccountId accountId) async {
    return _defaultSettings();
  }

  @override
  Future<TMailServerSettings> updateServerSettings(
    Session session,
    AccountId accountId,
    TMailServerSettings serverSettings,
  ) async {
    // Echo the requested settings back, falling back to defaults for any
    // fields the caller didn't set. We don't persist — see file header.
    final requested = serverSettings.settings;
    final defaults = _defaultOptions();
    final merged = TMailServerSettingOptions(
      alwaysReadReceipts:
          requested?.alwaysReadReceipts ?? defaults.alwaysReadReceipts,
      displaySenderPriority:
          requested?.displaySenderPriority ?? defaults.displaySenderPriority,
      language: requested?.language ?? defaults.language,
      aiNeedsActionEnabled:
          requested?.aiNeedsActionEnabled ?? defaults.aiNeedsActionEnabled,
    );
    return TMailServerSettings(
      id: serverSettings.id ??
          ServerSettingsIdExtension.serverSettingsIdSingleton,
      settings: merged,
    );
  }
}
