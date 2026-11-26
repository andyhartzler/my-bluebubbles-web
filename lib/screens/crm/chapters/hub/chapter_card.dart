import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/chapter_hub.dart';

import 'hub_widgets.dart';

/// One chapter in the directory: monogram, name, place, type, stage and
/// counts. The whole card opens the chapter.
class ChapterCard extends StatelessWidget {
  final ChapterHubEntry entry;
  final VoidCallback onOpen;

  const ChapterCard({super.key, required this.entry, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = hubDisplayName(entry);
    final place = hubPlaceLine(entry);
    final type = entry.chapter.chapterType;
    final flags = entry.flags.toList()..sort((a, b) => a.index.compareTo(b.index));
    final email = (entry.chapter.contactEmail ?? '').trim();
    final stageBadge = ChapterStageBadge.of(entry);

    return HubCard(
      onTap: onOpen,
      semanticLabel: [
        name,
        if (place != null) place,
        chapterTypeLabel(type),
        stageBadge.label,
        hubCount(entry.memberCount, 'member'),
        hubCount(entry.leaderCount, 'leader'),
        if (email.isNotEmpty) 'Contact $email',
        if (flags.isNotEmpty) 'Needs a look: ${flags.map((f) => f.label).join('; ')}',
        'Open chapter',
      ].join(', '),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChapterMonogram(entry: entry),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.25),
                      ),
                      if (place != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                if (flags.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: flags.map((f) => f.label).join('\n'),
                    child: Icon(
                      Icons.flag_outlined,
                      size: 20,
                      color: HubToneColors.of(context, HubTone.warning).foreground,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                HubBadge(label: chapterTypeLabel(type), icon: chapterTypeIcon(type)),
                stageBadge,
              ],
            ),
            const Spacer(),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                HubFact(icon: Icons.groups_outlined, label: hubCount(entry.memberCount, 'member')),
                HubFact(icon: Icons.star_outline, label: hubCount(entry.leaderCount, 'leader')),
                if (email.isNotEmpty) HubFact(icon: Icons.mail_outline, label: email),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
