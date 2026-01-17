import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import 'package:bluebubbles/features/slack/widgets/slack_file_attachment.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/utils/slack_message_formatter.dart';

/// A message bubble widget styled like the committee Slack tab
class SlackMessageBubble extends StatelessWidget {
  const SlackMessageBubble({
    super.key,
    required this.message,
    required this.userMappings,
    required this.memberCache,
    this.primaryColor = Colors.blue,
    this.onThreadTap,
    this.onMemberTap,
  });

  final Map<String, dynamic> message;
  final Map<String, Map<String, String>> userMappings;
  final Map<String, Member> memberCache;
  final Color primaryColor;
  final VoidCallback? onThreadTap;
  final void Function(Member member)? onMemberTap;

  static final DateFormat _timestampFormat = DateFormat('MMM d, y • h:mm a');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messageText = message['message_text']?.toString() ?? '';
    final postedAtStr = message['posted_at']?.toString();
    final postedAt = postedAtStr != null
        ? DateTime.tryParse(postedAtStr)
        : null;
    final isThreadReply =
        message['thread_ts'] != null &&
        message['thread_ts'] != message['slack_message_ts'];
    final slackUserId = message['slack_user_id']?.toString();
    final hasFiles = message['has_files'] == true;

    // Get user info from mappings
    final userMapping = slackUserId != null ? userMappings[slackUserId] : null;
    String? userName;
    String? avatarUrl;
    String? memberId = userMapping?['member_id'];
    Member? linkedMember;

    if (userMapping != null) {
      userName = userMapping['real_name']?.isNotEmpty == true
          ? userMapping['real_name']
          : userMapping['display_name'];
      avatarUrl = userMapping['avatar_url'];

      // If there's a linked member, use their profile photo instead
      if (memberId != null && memberId.isNotEmpty) {
        linkedMember = memberCache[memberId];
        if (linkedMember != null) {
          final memberPhotoUrl = linkedMember.primaryProfilePhotoUrl;
          if (memberPhotoUrl != null && memberPhotoUrl.isNotEmpty) {
            avatarUrl = memberPhotoUrl;
          }
          userName = linkedMember.name;
        }
      }
    }

    final canNavigate = linkedMember != null;

    // Use navy gradient background for message tiles
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: BrandColors.tileGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: BrandColors.unityBlue.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canNavigate && onMemberTap != null
              ? () => onMemberTap!(linkedMember!)
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    CorsAwareAvatar(
                      imageUrl: avatarUrl,
                      radius: 18,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      fallbackText: userName,
                      fallbackIconColor: Colors.white,
                      fallbackTextColor: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  userName ?? 'Unknown User',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (canNavigate) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.open_in_new,
                                  size: 14,
                                  color: Colors.white70,
                                ),
                              ],
                            ],
                          ),
                          if (postedAt != null)
                            Text(
                              _timestampFormat.format(postedAt.toLocal()),
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isThreadReply) _buildThreadBadge(context),
                  ],
                ),
                const SizedBox(height: 12),

                // Message text with parsed formatting (only show if there's text or no files)
                if (messageText.isNotEmpty || !hasFiles)
                  _buildMessageText(context, messageText, theme, hasFiles),

                // File indicator
                if (hasFiles) ...[
                  if (messageText.isNotEmpty) const SizedBox(height: 8),
                  _buildFileIndicator(context),
                ],

                // Reactions
                if (message['reactions'] != null)
                  _buildReactions(context, message['reactions']),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThreadBadge(BuildContext context) {
    return GestureDetector(
      onTap: onThreadTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.reply, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            const Text(
              'Thread',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageText(
    BuildContext context,
    String messageText,
    ThemeData theme,
    [bool hasFiles = false]
  ) {
    // Don't show "[No text content]" if the message has files
    if (messageText.isEmpty) {
      if (hasFiles) {
        return const SizedBox.shrink();
      }
      return const Text(
        '[No text content]',
        style: TextStyle(
          fontStyle: FontStyle.italic,
          color: Colors.white54,
          fontSize: 14,
        ),
      );
    }

    // Use SlackMessageFormatter to parse the message with white text
    final spans = SlackMessageFormatter.parse(
      messageText,
      baseStyle: const TextStyle(color: Colors.white, fontSize: 14),
      linkColor: BrandColors.sunriseGold,
      mentionColor: Colors.white,
      userMappings: userMappings,
      onMentionTap: (userId, memberId) {
        if (memberId != null && memberId.isNotEmpty) {
          final member = memberCache[memberId];
          if (member != null && onMemberTap != null) {
            onMemberTap!(member);
          }
        }
      },
    );

    if (spans.isEmpty) {
      return Text(
        messageText,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildFileIndicator(BuildContext context) {
    // First try to use files_archived (has Supabase URLs)
    final filesArchived = message['files_archived'];
    final archivedFiles = parseArchivedFiles(filesArchived);

    if (archivedFiles.isNotEmpty) {
      return SlackFileAttachments(files: archivedFiles, darkBackground: true);
    }

    // Fallback to showing a simple indicator if only files is available
    final files = message['files'] as List<dynamic>?;
    final fileCount = files?.length ?? 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.attach_file,
            size: 16,
            color: Colors.white70,
          ),
          const SizedBox(width: 6),
          Text(
            '$fileCount file${fileCount > 1 ? 's' : ''} attached',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactions(BuildContext context, dynamic reactions) {
    if (reactions == null) return const SizedBox.shrink();

    List<dynamic> reactionsList;
    if (reactions is List) {
      reactionsList = reactions;
    } else {
      return const SizedBox.shrink();
    }

    if (reactionsList.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: reactionsList.map<Widget>((reaction) {
          final name = reaction['name']?.toString() ?? '';
          final count = (reaction['count'] as num?)?.toInt() ?? 0;
          final users = reaction['users'] as List<dynamic>? ?? [];

          // Convert emoji name to Unicode emoji
          final emoji = SlackMessageFormatter.emojiToUnicode(name) ?? ':$name:';

          return GestureDetector(
            onTap: () => _showReactionDetails(context, name, emoji, users),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                  if (count > 1) ...[
                    const SizedBox(width: 4),
                    Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showReactionDetails(
    BuildContext context,
    String emojiName,
    String emoji,
    List<dynamic> users,
  ) {
    final theme = Theme.of(context);

    // Build list of user names who reacted
    final userNames = <String>[];
    for (final userId in users) {
      final userIdStr = userId?.toString() ?? '';
      if (userIdStr.isNotEmpty) {
        final userInfo = userMappings[userIdStr];
        if (userInfo != null) {
          final name = userInfo['real_name']?.isNotEmpty == true
              ? userInfo['real_name']!
              : (userInfo['display_name']?.isNotEmpty == true
                    ? userInfo['display_name']!
                    : userIdStr);
          userNames.add(name);
        } else {
          userNames.add(userIdStr);
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(':$emojiName:', style: theme.textTheme.titleMedium),
            ),
          ],
        ),
        content: SizedBox(
          width: 300,
          child: userNames.isEmpty
              ? Text(
                  'No reaction details available',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${userNames.length} ${userNames.length == 1 ? 'person' : 'people'} reacted:',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: userNames
                              .map(
                                (name) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.person,
                                        size: 16,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Builds an avatar with CORS-safe image loading
  Widget _buildAvatar(String? avatarUrl, Color primaryColor) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: primaryColor.withOpacity(0.2),
        child: Icon(Icons.person, size: 20, color: primaryColor),
      );
    }

    return CachedNetworkImage(
      imageUrl: avatarUrl,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: 18,
        backgroundImage: imageProvider,
        backgroundColor: primaryColor.withOpacity(0.2),
      ),
      placeholder: (context, url) => CircleAvatar(
        radius: 18,
        backgroundColor: primaryColor.withOpacity(0.2),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => CircleAvatar(
        radius: 18,
        backgroundColor: primaryColor.withOpacity(0.2),
        child: Icon(Icons.person, size: 20, color: primaryColor),
      ),
    );
  }
}
