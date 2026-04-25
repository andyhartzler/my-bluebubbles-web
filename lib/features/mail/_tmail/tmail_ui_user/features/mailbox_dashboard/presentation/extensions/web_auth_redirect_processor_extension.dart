import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:dartz/dartz.dart';
import 'package:bluebubbles/features/mail/_tmail/model/oidc/oidc_configuration.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/login/domain/exceptions/authentication_exception.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/login/domain/state/get_stored_oidc_configuration_state.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/login/domain/state/get_token_oidc_state.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/routes/app_routes.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/routes/route_navigation.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/utils/app_config.dart';

// MOYD CRM patch — we don't use OIDC auth (Supabase auth handles login).
// The original tmail behavior here was to run a redirect chain that, on
// failure, called `pushAndPopAll(AppRoutes.home)` to bounce the user out
// of the dashboard back to tmail's login page. In our setup that yanks
// the user out of MailScreen entirely (the redirect targets a route we
// never registered with GetX). Neutralized: getAuthenticationInfoRedirect
// is a no-op, and backToHomeScreen is a no-op so the failure paths from
// other code that escape into here don't navigate.
extension WebAuthRedirectProcessorExtension on MailboxDashBoardController {
  void getAuthenticationInfoRedirect() {
    // No-op for MOYD CRM — Supabase auth, not OIDC. Running the OIDC
    // chain here on first mount would call backToHomeScreen on failure
    // (no creds in Hive) and yank the user out of the dashboard.
  }

  void getStoredOidcConfiguration() {
    consumeState(getStoredOidcConfigurationInteractor.execute());
  }

  void getTokenOIDCAction(OIDCConfiguration oidcConfig) {
    final baseUri = Uri.tryParse(AppConfig.baseUrl);

    if (baseUri == null) {
      consumeState(
        Stream.value(Left(GetTokenOIDCFailure(CanNotFoundBaseUrl()))),
      );
    } else {
      consumeState(getTokenOIDCInteractor.execute(baseUri, oidcConfig));
    }
  }

  bool isGetTokenOIDCFailure(Failure? failure) {
    return failure is GetStoredOidcConfigurationFailure ||
        failure is GetTokenOIDCFailure;
  }

  void tryGetAuthenticatedAccountToUseApp() {
    // No-op for MOYD CRM — Supabase auth handles auth state, no need to
    // enter tmail's account-cache fallback flow.
  }

  void backToHomeScreen() {
    // No-op for MOYD CRM — pushAndPopAll(AppRoutes.home) targets tmail's
    // own home route which we never registered with GetX. The user is
    // already inside our MailScreen which is the right place to be.
  }
}
