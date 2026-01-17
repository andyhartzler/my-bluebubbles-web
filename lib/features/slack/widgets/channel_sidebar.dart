import 'package:flutter/material.dart';

import 'package:bluebubbles/features/slack/models/slack_channel.dart';

/// Sidebar widget for displaying Slack channels
class ChannelSidebar extends StatelessWidget {
  const ChannelSidebar({
    super.key,
    required this.channels,
    required this.selectedChannelId,
    required this.onChannelSelected,
    this.loading = false,
  });

  final List<SlackChannel> channels;
  final String? selectedChannelId;
  final void Function(SlackChannel channel) onChannelSelected;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (channels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tag, size: 48, color: theme.disabledColor),
              const SizedBox(height: 12),
              Text(
                'No channels found',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.disabledColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        final isSelected = channel.slackChannelId == selectedChannelId;

        return _ChannelListItem(
          channel: channel,
          isSelected: isSelected,
          onTap: () => onChannelSelected(channel),
        );
      },
    );
  }
}

class _ChannelListItem extends StatelessWidget {
  const _ChannelListItem({
    required this.channel,
    required this.isSelected,
    required this.onTap,
  });

  final SlackChannel channel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(
          Icons.tag,
          size: 20,
          color: isSelected
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          channel.slackChannelName,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          channel.committeeName,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isSelected
                ? theme.colorScheme.onPrimaryContainer.withOpacity(0.7)
                : theme.colorScheme.onSurfaceVariant,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Mobile-friendly channel dropdown selector
class ChannelDropdown extends StatelessWidget {
  const ChannelDropdown({
    super.key,
    required this.channels,
    required this.selectedChannel,
    required this.onChannelSelected,
    this.loading = false,
  });

  final List<SlackChannel> channels;
  final SlackChannel? selectedChannel;
  final void Function(SlackChannel channel) onChannelSelected;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (loading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text('Loading channels...', style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    if (channels.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: theme.colorScheme.error, size: 20),
            const SizedBox(width: 12),
            Text('No channels available', style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedChannel?.slackChannelId,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          items: channels.map((channel) {
            return DropdownMenuItem<String>(
              value: channel.slackChannelId,
              child: Row(
                children: [
                  const Icon(Icons.tag, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          channel.slackChannelName,
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          channel.committeeName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (channelId) {
            if (channelId != null) {
              final channel = channels.firstWhere(
                (c) => c.slackChannelId == channelId,
              );
              onChannelSelected(channel);
            }
          },
        ),
      ),
    );
  }
}
