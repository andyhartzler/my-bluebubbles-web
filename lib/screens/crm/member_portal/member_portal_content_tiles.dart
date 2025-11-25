import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'member_portal_text_utils.dart';

class MemberPortalContentTile extends StatelessWidget {
  const MemberPortalContentTile({
    super.key,
    required this.title,
    this.html,
  });

  final String title;
  final String? html;

  @override
  Widget build(BuildContext context) {
    final markdown = normalizeMemberPortalText(html);
    if (markdown.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final styleSheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyMedium,
      listBullet: theme.textTheme.bodyMedium,
    );

    return Card(
      color: theme.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SelectionArea(
              child: MarkdownBody(
                data: markdown,
                softLineBreak: true,
                styleSheet: styleSheet,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
