import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/providers/user_session_provider.dart';

/// Top-of-screen branded gradient banner on the Personalized Home Screen.
/// Mirrors the visual language of [SlackManagementScreen]: navy →
/// momentum-blue gradient, white text, sunrise-gold accents.
class ProfileHeader extends StatelessWidget {
  final Member member;
  final UserSessionProvider session;
  final VoidCallback? onEditAvatar;
  final VoidCallback? onCustomize;

  const ProfileHeader({
    super.key,
    required this.member,
    required this.session,
    this.onEditAvatar,
    this.onCustomize,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final avatarUrl = member.effectiveAvatarUrl;
    final title = _buildTitle(member, session);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: BrandColors.tileGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 24,
            isMobile ? 16 : 20,
            isMobile ? 12 : 24,
            isMobile ? 16 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildAvatar(context, avatarUrl, isMobile),
                  SizedBox(width: isMobile ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          member.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (title != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            title,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onCustomize != null)
                    IconButton(
                      onPressed: onCustomize,
                      tooltip: 'Customize home',
                      icon: const Icon(Icons.tune, color: Colors.white),
                    ),
                ],
              ),
              if (session.userCommittees.isNotEmpty ||
                  (member.committee?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _committeeChips(context, member, session),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, String? avatarUrl, bool isMobile) {
    final radius = isMobile ? 30.0 : 38.0;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: BrandColors.sunriseGold,
              width: 2,
            ),
          ),
          padding: const EdgeInsets.all(2),
          // CorsAwareAvatar, not CircleAvatar + NetworkImage. The latter
          // renders its initials child ONLY when the url is null, so a 404,
          // an expired storage path or a CORS-blocked host left an empty
          // translucent disc plus an unhandled image-stream exception.
          // This degrades to initials on every failure instead.
          //
          // No backgroundColor is passed on purpose: the widget's default is
          // an OPAQUE unityBlue disc under white initials, 12.51:1, which
          // holds at the light end of this gradient. A translucent white-15%
          // fill measures 1.91:1 over that end.
          child: CorsAwareAvatar(
            imageUrl: avatarUrl,
            radius: radius,
            fallbackText: member.name,
          ),
        ),
        if (onEditAvatar != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: Material(
              shape: const CircleBorder(),
              color: BrandColors.sunriseGold,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onEditAvatar,
                child: const Padding(
                  padding: EdgeInsets.all(5),
                  child: Icon(
                    Icons.edit,
                    size: 12,
                    color: BrandColors.unityBlue,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String? _buildTitle(Member m, UserSessionProvider s) {
    if (m.executiveTitle != null && m.executiveTitle!.trim().isNotEmpty) {
      return m.executiveTitle;
    }
    if (m.executiveCommittee) return 'Executive Committee';
    if (s.isCommitteeMember && s.userCommittees.isNotEmpty) {
      final names = s.userCommittees.map((c) => c.name).join(', ');
      return 'Committee: $names';
    }
    return null;
  }

  List<Widget> _committeeChips(
    BuildContext context,
    Member member,
    UserSessionProvider session,
  ) {
    final names = <String>{};
    for (final c in session.userCommittees) {
      if (c.name.trim().isNotEmpty) names.add(c.name);
    }
    for (final c in (member.committee ?? const <String>[])) {
      if (c.trim().isNotEmpty) names.add(c);
    }
    return names.take(6).map((name) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.25),
            width: 1,
          ),
        ),
        child: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }).toList();
  }
}
