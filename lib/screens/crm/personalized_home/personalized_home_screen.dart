import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/committees/widgets/member_calendar_widget.dart';
import 'package:bluebubbles/models/crm/user_home_preferences.dart';
import 'package:bluebubbles/providers/user_session_provider.dart';
import 'package:bluebubbles/services/crm/user_home_preferences_service.dart';

import 'widgets/activity_panel.dart';
import 'widgets/assignments_panel.dart';
import 'widgets/avatar_upload_dialog.dart';
import 'package:bluebubbles/screens/crm/county_outreach_screen.dart';

import 'widgets/branded_panel.dart';
import 'widgets/home_customize_dialog.dart';
import 'widgets/profile_header.dart';

/// The default landing screen for executive members after sign-in.
/// Composes a branded gradient profile banner, an Assignments panel
/// (category-tabbed), an Activity panel (Meetings + Events), and the
/// org-wide Calendar shared with the Committees first page. All
/// surfaces use the navy → momentum-blue brand language with white
/// text and sunrise-gold accents.
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
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final isWide = width >= 960;

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
                    // Wide desktop: Assignments + Activity sit side-by-side
                    // in a 50/50 row above the full-width Calendar.
                    if (prefs.showAssignments &&
                        prefs.showMeetingHistory &&
                        isWide) ...[
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: AssignmentsPanel(
                                authUserId: authId,
                                memberId: member.id,
                                isStaff: session.isExecutive ||
                                    session.isCommitteeMember,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ActivityPanel(
                                authUserId: authId,
                                memberId: member.id,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      if (prefs.showAssignments) ...[
                        AssignmentsPanel(
                          authUserId: authId,
                          memberId: member.id,
                          isStaff: session.isExecutive ||
                              session.isCommitteeMember,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (prefs.showMeetingHistory) ...[
                        ActivityPanel(
                          authUserId: authId,
                          memberId: member.id,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                    // A single line under Assignments that opens County
                    // Outreach (the Candidate Volunteers page). The rich
                    // county view now lives on that page, not the home screen.
                    if (session.isExecutive) ...[
                      const _CountyOutreachLink(),
                      const SizedBox(height: 16),
                    ],
                    // Calendar — shared with the Committees first page,
                    // wrapped in a BrandedPanel so it matches the rest
                    // of the home surface visually.
                    BrandedPanel(
                      title: 'Calendar',
                      icon: Icons.calendar_month,
                      body: const Padding(
                        padding: EdgeInsets.all(8),
                        child: MemberCalendarWidget(),
                      ),
                    ),
                    const SizedBox(height: 16),
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

/// One compact line under Assignments on the home screen. Opens County
/// Outreach — the Candidate Volunteers page — where the real county work lives.
class _CountyOutreachLink extends StatelessWidget {
  const _CountyOutreachLink();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Candidate Volunteers')),
              body: const CountyOutreachScreen(),
            ),
          ),
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: BrandColors.tileGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.campaign_outlined, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('County Outreach',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('Text or email members by county',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Colors.white.withOpacity(0.7), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
