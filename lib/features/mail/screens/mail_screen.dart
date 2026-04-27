import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
// MOYD CRM is web-only — mount the web variant of the dashboard, which:
//   - renders ComposerOverlayView (without it, compose/reply/forward
//     fire composerManager.addComposer() but nothing visually opens)
//   - uses the desktop split-pane layout instead of the mobile stub
//   - registers the desktop click handlers for delete/star/etc on the
//     thread + email-detail toolbars
// The non-web `mailbox_dashboard_view.dart` is a 67-line mobile stub.
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/presentation/mailbox_dashboard_view_web.dart';
import 'package:bluebubbles/features/mail/services/edge_fn/dashboard_controller_fixups.dart';
import 'package:bluebubbles/features/mail/services/edge_fn/mail_screen_tmail_bindings.dart';

/// Root mail screen. Mounts tmail-flutter's `MailboxDashBoardView` —
/// tmail's literal forked widget tree — wrapped in a Theme override that
/// recolors LinagoraColors to MOYD's BrandColors.
///
/// Boot sequence on first mount:
///   1. `MailScreenTmailBindings.initialize()` registers our EdgeFn data
///      sources first (permanent), then walks tmail's CoreBindings,
///      LocalBindings, NetworkBindings, CredentialBindings, SessionBindings,
///      NetWorkConnectionBindings, MailboxDashBoardBindings.
///   2. `registerDashboardControllerFixups()` validates the 7 controllers
///      MailboxDashBoardController depends on are registered (fast-fails
///      with a descriptive StateError otherwise).
///   3. `MailboxDashBoardView()` constructor runs — it's a `GetWidget`
///      that resolves its `controller` via `Get.find` from the registry
///      we just primed.
///
/// Theme override: tmail uses `LinagoraColors`/`AppColor` constants
/// throughout. We wrap in a `Theme` that maps the most-load-bearing
/// surfaces (primary, secondary, surface, scaffold background, app bar)
/// to BrandColors so the navy + sunrise-gold accent pulls through.
class MailScreen extends StatefulWidget {
  const MailScreen({super.key});

  @override
  State<MailScreen> createState() => _MailScreenState();
}

class _MailScreenState extends State<MailScreen> {
  Future<void>? _bootFuture;

  @override
  void initState() {
    super.initState();
    _bootFuture = _boot();
  }

  Future<void> _boot() async {
    await MailScreenTmailBindings.initialize();
    registerDashboardControllerFixups();
    // Tmail normally calls `_setUpComponentsFromSession(session)` in
    // response to a Session arriving via `Get.arguments`. We mount the
    // dashboard view directly (no Get.to navigation), so that path never
    // fires — leaving `accountId` null forever, which means
    // MailboxController never calls getAllMailbox(), no mailbox is
    // selected, and ThreadController never calls getAllEmailAction().
    // bootDashboardFromSyntheticSession() reproduces the load-bearing
    // assignments (sessionCurrent + accountId.value) so the entire
    // mailbox tree → selected mailbox → email list chain wakes up.
    bootDashboardFromSyntheticSession();
    // Identities are also populated by _setUpComponentsFromSession, but
    // we keep the dedicated helper because it routes the result through
    // controller.consumeState — the same path tmail itself uses, with
    // diagnostic logging on success/failure.
    populateDashboardListIdentities();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _moydTmailTheme(context),
      child: FutureBuilder<void>(
        future: _bootFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: BrandedBackground(
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
            );
          }
          if (snap.hasError) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: BrandedBackground(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Failed to boot mail',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          snap.error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          // Wrap the dashboard in a subtle unityBlue → momentumBlue gradient
          // backdrop. The dashboard's own Scaffold paints its background
          // (tinted-off-white, set in this theme below) over most of the
          // surface, but any gap — rounded edges, drawer transitions,
          // safe-area insets — shows MOYD navy instead of bare white. This
          // bridges the navy nav chrome above with the cool-off-white mail
          // surface inside without clipping the dashboard (which would
          // break its drawer slide-in animation on tabletLarge).
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [BrandColors.unityBlue, BrandColors.momentumBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: MailboxDashBoardView(),
          );
        },
      ),
    );
  }
}

/// Theme override applied at the MailScreen scope. Pulls MOYD's BrandColors
/// (unityBlue + sunriseGold + momentumBlue) into the Material color slots
/// tmail's widgets read.
ThemeData _moydTmailTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: BrandColors.unityBlue,
      onPrimary: Colors.white,
      secondary: BrandColors.sunriseGold,
      onSecondary: BrandColors.unityBlue,
      surface: Colors.white,
      onSurface: const Color(0xFF1A1F36),
      surfaceTint: BrandColors.momentumBlue,
    ),
    // Tinted off-white: bridges the navy frame outside with the cool-off-
    // white mail surface inside. Stays light enough that all body text on
    // it passes contrast (>15:1 vs #1A1F36).
    scaffoldBackgroundColor: const Color(0xFFF6F8FB),
    appBarTheme: AppBarTheme(
      backgroundColor: BrandColors.unityBlue,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    iconTheme: const IconThemeData(color: BrandColors.unityBlue),
    primaryIconTheme: const IconThemeData(color: Colors.white),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: BrandColors.sunriseGold,
      foregroundColor: BrandColors.unityBlue,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: BrandColors.unityBlue,
        foregroundColor: Colors.white,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: BrandColors.unityBlue,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: BrandColors.unityBlue,
      textColor: Color(0xFF1A1F36),
      titleTextStyle: TextStyle(
        color: Color(0xFF1A1F36),
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      subtitleTextStyle: TextStyle(
        color: Color(0xFF55687D),
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
    ),
    // Push tighter, more deliberate body text sizing across the dashboard
    // so the inbox list rows + open-email subject line feel like the rest
    // of the CRM (which uses w600 14-15 titles + w500 13 secondary text).
    textTheme: base.textTheme.copyWith(
      titleMedium: const TextStyle(
        color: Color(0xFF1A1F36),
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      titleLarge: const TextStyle(
        color: BrandColors.unityBlue,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      bodyMedium: const TextStyle(
        color: Color(0xFF1A1F36),
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
      ),
      bodySmall: const TextStyle(
        color: Color(0xFF55687D),
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: BrandColors.momentumBlue,
    ),
    dividerColor: const Color(0xFFE5E7EB),
  );
}
