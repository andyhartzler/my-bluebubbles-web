import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
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
    final postedAt =
        postedAtStr != null ? DateTime.tryParse(postedAtStr) : null;
    final isThreadReply = message['thread_ts'] != null &&
        message['thread_ts'] != message['slack_message_ts'];
    final slackUserId = message['slack_user_id']?.toString();
    final hasFiles = message['has_files'] == true;

    // Get user info from mappings
    final userMapping =
        slackUserId != null ? userMappings[slackUserId] : null;
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  _buildAvatar(avatarUrl, primaryColor),
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
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  decoration: canNavigate
                                      ? TextDecoration.underline
                                      : null,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (canNavigate) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.open_in_new,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                            ],
                          ],
                        ),
                        if (postedAt != null)
                          Text(
                            _timestampFormat.format(postedAt.toLocal()),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withOpacity(0.6),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isThreadReply) _buildThreadBadge(context),
                ],
              ),
              const SizedBox(height: 12),

              // Message text with parsed formatting
              _buildMessageText(context, messageText, theme),

              // File indicator
              if (hasFiles) ...[
                const SizedBox(height: 8),
                _buildFileIndicator(context),
              ],

              // Reactions
              if (message['reactions'] != null)
                _buildReactions(context, message['reactions']),
            ],
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
          color: primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.reply, size: 14, color: primaryColor),
            const SizedBox(width: 4),
            Text(
              'Thread',
              style: TextStyle(
                fontSize: 11,
                color: primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageText(
      BuildContext context, String messageText, ThemeData theme) {
    if (messageText.isEmpty) {
      return Text(
        '[No text content]',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
        ),
      );
    }

    // Use SlackMessageFormatter to parse the message
    final spans = SlackMessageFormatter.parse(
      messageText,
      baseStyle: theme.textTheme.bodyMedium ?? const TextStyle(),
      linkColor: theme.colorScheme.primary,
      mentionColor: primaryColor,
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
        style: theme.textTheme.bodyMedium,
      );
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildFileIndicator(BuildContext context) {
    // First try to use files_archived (has Supabase URLs)
    final filesArchived = message['files_archived'];
    final archivedFiles = parseArchivedFiles(filesArchived);

    if (archivedFiles.isNotEmpty) {
      return SlackFileAttachments(files: archivedFiles);
    }

    // Fallback to showing a simple indicator if only files is available
    final theme = Theme.of(context);
    final files = message['files'] as List<dynamic>?;
    final fileCount = files?.length ?? 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_file,
              size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            '$fileCount file${fileCount > 1 ? 's' : ''} attached',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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

    final theme = Theme.of(context);

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
                color: theme.colorScheme.surfaceVariant.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (count > 1) ...[
                    const SizedBox(width: 4),
                    Text(
                      '$count',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
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
              child: Text(
                ':$emojiName:',
                style: theme.textTheme.titleMedium,
              ),
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
                              .map((name) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
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
                                  ))
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

  /// Build avatar with CORS-safe image loading and fallback
  Widget _buildAvatar(String? avatarUrl, Color color) {
    const double radius = 18;

    if (avatarUrl == null || avatarUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: color.withOpacity(0.2),
        child: Icon(Icons.person, size: 20, color: color),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: avatarUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: color.withOpacity(0.2),
          child: SizedBox(
            width: radius,
            height: radius,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: color.withOpacity(0.2),
          child: Icon(Icons.person, size: 20, color: color),
        ),
      ),
    );
  }
}
