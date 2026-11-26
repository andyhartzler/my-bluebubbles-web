import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/models/crm/chapter.dart';
import 'package:bluebubbles/services/crm/chapter_hub_service.dart';
import 'package:bluebubbles/services/crm/chapter_repository.dart';

/// The three things a reviewer does to a pending chapter, each behind a
/// confirmation, shared by the hub and the chapter page so they read the
/// same everywhere. Each returns the updated chapter, or null when the
/// reviewer backed out or the save failed (a snackbar says which).
class ChapterCharterActions {
  ChapterCharterActions._();

  static final _repository = ChapterRepository();

  static Future<Chapter?> charter(BuildContext context, Chapter chapter) async {
    DateTime date = DateTime.now();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          final theme = Theme.of(dialogContext);
          return AlertDialog(
            icon: Icon(Icons.verified_outlined, color: theme.colorScheme.primary, size: 32),
            title: Text('Charter ${chapter.chapterName.trim()}?'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'It becomes an active, chartered MOYD chapter. You can change this later from the chapter\'s Edit button.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Text('Charter date', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event_outlined),
                    label: Text(DateFormat('EEEE, MMMM d, y').format(date)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: date,
                        firstDate: DateTime(2015),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        helpText: 'Date the executive committee approved it',
                      );
                      if (picked != null) setState(() => date = picked);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.verified),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                label: const Text('Charter chapter'),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true || !context.mounted) return null;
    return _save(
      context,
      () => _repository.charterChapter(chapter, date),
      success: '${chapter.chapterName.trim()} is now chartered.',
    );
  }

  static Future<Chapter?> archive(BuildContext context, Chapter chapter, {int memberCount = 0}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          icon: Icon(Icons.archive_outlined, color: theme.colorScheme.onSurfaceVariant, size: 32),
          title: Text('Archive "${chapter.chapterName.trim()}"?'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              [
                'It leaves charter review and the chapter directory. Nothing is deleted, and you can restore it from Archived.',
                if (memberCount > 0)
                  '$memberCount ${memberCount == 1 ? 'member still lists' : 'members still list'} this name on their profile.',
              ].join('\n\n'),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.archive_outlined),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              label: const Text('Archive'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return null;
    return _save(
      context,
      () => _repository.archiveChapter(chapter),
      success: 'Archived "${chapter.chapterName.trim()}".',
      undo: (restored) => _repository.restoreChapter(restored),
    );
  }

  static Future<Chapter?> restore(BuildContext context, Chapter chapter) {
    return _save(
      context,
      () => _repository.restoreChapter(chapter),
      success: chapter.isChartered
          ? '"${chapter.chapterName.trim()}" is an active chapter again.'
          : '"${chapter.chapterName.trim()}" is back in charter review.',
    );
  }

  static Future<Chapter?> _save(
    BuildContext context,
    Future<Chapter?> Function() write, {
    required String success,
    Future<Chapter?> Function(Chapter updated)? undo,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final updated = await write();
      ChapterHubService.instance.invalidate();
      if (updated == null) {
        messenger?.showSnackBar(const SnackBar(content: Text("That change didn't save. Try again.")));
        return null;
      }
      messenger?.showSnackBar(SnackBar(
        content: Text(success),
        action: undo == null
            ? null
            : SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  try {
                    final restored = await undo(updated);
                    if (restored == null) throw StateError('not saved');
                  } catch (e) {
                    debugPrint('Undo failed: $e');
                    messenger.showSnackBar(const SnackBar(
                      content: Text("Couldn't undo that. Find it under Archived on the Chapters page and restore it there."),
                    ));
                  } finally {
                    ChapterHubService.instance.invalidate();
                  }
                },
              ),
      ));
      return updated;
    } catch (e) {
      debugPrint('Chapter change failed: $e');
      messenger?.showSnackBar(const SnackBar(
        content: Text("That change didn't save. Check your connection and try again."),
      ));
      return null;
    }
  }
}
