import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/user_home_preferences.dart';
import 'package:bluebubbles/providers/user_session_provider.dart';
import 'package:bluebubbles/services/crm/user_home_preferences_service.dart';

import 'widgets/assignments_panel.dart';
import 'widgets/avatar_upload_dialog.dart';
import 'widgets/home_customize_dialog.dart';
import 'widgets/meeting_history_panel.dart';
import 'widgets/optional_tiles_section.dart';
import 'widgets/profile_header.dart';

/// The default landing screen for executive members after sign-in.
/// Composes a branded gradient profile banner, assignments, meeting
/// history, and an optional drag-add metric-tiles area. Mirrors the
/// visual language of [SlackManagementScreen] — navy → momentum-blue
/// gradient header, branded background, sunrise-gold accents.
class PersonalizedHomeScreen extends StatefulWidget {
  const PersonalizedHomeScreen({super.key});

  @override
  State<PersonalizedHomeScreen> createState() => _PersonalizedHomeScreenState();
}

class _PersonalizedHomeScreenState extends State<PersonalizedHomeScreen>
    with AutomaticKeepAliveClientMixin {
  final _prefsService = UserHomePreferencesService();
  UserHomePreferences? _prefs;
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final session = context.read<UserSessionProvider>();
    final authId = session.authUserId;
    if (authId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final p = await _prefsService.fetchOrDefault(authId);
    if (!mounted) return;
    setState(() {
      _prefs = p;
      _loading = false;
    });
  }

  Future<void> _customize() async {
    final current = _prefs;
    if (current == null) return;
    final updated = await showDialog<UserHomePreferences?>(
      context: context,
      builder: (_) => HomeCustomizeDialog(current: current),
    );
    if (updated != null && mounted) {
      setState(() => _prefs = updated);
    }
  }

  Future<void> _editAvatar() async {
    final session = context.read<UserSessionProvider>();
    final authId = session.authUserId;
    if (authId == null) return;
    final url = await showDialog<String?>(
      context: context,
      builder: (_) => AvatarUploadDialog(authUserId: authId),
    );
    if (url != null && session.currentMember != null) {
      session.refreshMember(session.currentMember!.copyWith(avatarUrl: url));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final session = context.watch<UserSessionProvider>();
    final member = session.currentMember;
    final authId = session.authUserId;

    if (_loading || member == null || authId == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: BrandedBackground(
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(BrandColors.unityBlue),
            ),
          ),
        ),
      );
    }

    final prefs = _prefs ?? UserHomePreferences.defaultsFor(authId);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BrandedBackground(
        child: Column(
          children: [
            if (prefs.showProfileHeader)
              ProfileHeader(
                member: member,
                session: session,
                onEditAvatar: _editAvatar,
                onCustomize: _customize,
              )
            else
              SafeArea(
                bottom: false,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: BrandColors.tileGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Home',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _customize,
                        tooltip: 'Customize home',
                        icon: const Icon(Icons.tune, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 24,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (prefs.showAssignments) ...[
                      AssignmentsPanel(
                        authUserId: authId,
                        memberId: member.id,
                        isStaff: session.isExecutive || session.isCommitteeMember,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (prefs.showMeetingHistory) ...[
                      MeetingHistoryPanel(
                        authUserId: authId,
                        memberId: member.id,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (prefs.showOptionalTiles) ...[
                      OptionalTilesSection(
                        prefs: prefs,
                        onPrefsChanged: (updated) {
                          if (mounted) setState(() => _prefs = updated);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
