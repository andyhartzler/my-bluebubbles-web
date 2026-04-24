import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/providers/user_session_provider.dart';

/// Top-of-screen profile card on the Personalized Home Screen.
/// Shows the member's avatar, full name, executive title (or committee
/// affiliation), and a list of committee badges.
class ProfileHeader extends StatelessWidget {
  final Member member;
  final UserSessionProvider session;
  final VoidCallback? onEditAvatar;

  const ProfileHeader({
    super.key,
    required this.member,
    required this.session,
    this.onEditAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarUrl = member.effectiveAvatarUrl;
    final title = _buildTitle(member, session);

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: isMobile ? 32 : 40,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(
                          _initials(member.name),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                if (onEditAvatar != null)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      shape: const CircleBorder(),
                      color: theme.colorScheme.primary,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onEditAvatar,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.edit,
                            size: 14,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: isMobile ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (title != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (session.userCommittees.isNotEmpty || (member.committee?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _committeeChips(context, member, session),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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
    final theme = Theme.of(context);
    final names = <String>{};
    for (final c in session.userCommittees) {
      if (c.name.trim().isNotEmpty) names.add(c.name);
    }
    for (final c in (member.committee ?? const <String>[])) {
      if (c.trim().isNotEmpty) names.add(c);
    }
    return names.take(6).map((name) {
      return Chip(
        label: Text(name, style: const TextStyle(fontSize: 12)),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
      );
    }).toList();
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}
