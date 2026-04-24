import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bluebubbles/models/crm/user_home_preferences.dart';
import 'package:bluebubbles/providers/user_session_provider.dart';
import 'package:bluebubbles/services/crm/user_home_preferences_service.dart';

import 'widgets/assignments_panel.dart';
import 'widgets/avatar_upload_dialog.dart';
import 'widgets/home_customize_dialog.dart';
import 'widgets/meeting_history_panel.dart';
import 'widgets/profile_header.dart';

/// The default landing screen for executive members after sign-in.
/// Composes profile header, assignments, meeting history, and (in v2)
/// an optional drag-drop metric-tiles area.
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
      // Pull a fresh member record so the header re-renders with the new url.
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final prefs = _prefs ?? UserHomePreferences.defaultsFor(authId);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 24,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (prefs.showProfileHeader) ...[
                ProfileHeader(
                  member: member,
                  session: session,
                  onEditAvatar: _editAvatar,
                ),
                const SizedBox(height: 16),
              ],
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
                _OptionalTilesPlaceholder(),
                const SizedBox(height: 16),
              ],
              Center(
                child: TextButton.icon(
                  onPressed: _customize,
                  icon: const Icon(Icons.tune),
                  label: const Text('Customize home'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// v1 placeholder for the drag-drop metric tiles area. The real tile
/// renderer lands in v2 once the multi-page Dashboard's edit mode is
/// extracted. For now we surface a CTA pointing at the Dashboard tab.
class _OptionalTilesPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.dashboard_customize,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Metric tiles',
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    'Drop dashboard metrics directly on your home screen — coming soon. Until then, build a personal Dashboard page from the Dashboard tab.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
