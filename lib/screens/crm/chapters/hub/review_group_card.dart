import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/chapter.dart';
import 'package:bluebubbles/models/crm/chapter_hub.dart';

import 'hub_widgets.dart';

/// Rows and cards narrower than this stack their actions under the text.
const double _sideActionsWidth = 640;

/// What a reviewer can do from the hub. The screen supplies these (they
/// open routes and run the confirm-and-save flows), so the widgets here stay
/// plain views.
class ChapterReviewActions {
  final void Function(Chapter chapter) open;
  final Future<void> Function(ChapterHubEntry entry) charter;
  final Future<void> Function(ChapterHubEntry entry) archive;
  final Future<void> Function(ChapterHubEntry entry) restore;
  final void Function(CharterApplication application) viewApplication;

  const ChapterReviewActions({
    required this.open,
    required this.charter,
    required this.archive,
    required this.restore,
    required this.viewApplication,
  });
}

/// Lays out a row's text and its buttons side by side when there is room,
/// and stacked (buttons wrapping under the text) on a phone.
class _InfoWithActions extends StatelessWidget {
  final Widget info;
  final List<Widget> actions;
  const _InfoWithActions({required this.info, required this.actions});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (actions.isEmpty) return info;
      if (constraints.maxWidth >= _sideActionsWidth) {
        return Row(
          children: [
            Expanded(flex: 3, child: info),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: actions,
              ),
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          info,
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      );
    });
  }
}

/// Pending rows that name the same school or county, reviewed together.
class ReviewGroupCard extends StatefulWidget {
  final ChapterReviewGroup group;
  final ChapterReviewActions actions;

  const ReviewGroupCard({super.key, required this.group, required this.actions});

  @override
  State<ReviewGroupCard> createState() => _ReviewGroupCardState();
}

class _ReviewGroupCardState extends State<ReviewGroupCard> {
  /// Chapters with a charter or archive in flight, so a second tap waits.
  final Set<String> _busy = {};

  ChapterReviewGroup get group => widget.group;

  /// The row a reviewer most likely wants to charter: the first in the
  /// group's order (application first, then most members) that is not a
  /// non-answer and does not repeat an already chartered chapter. Null when
  /// the group has one row or no row qualifies.
  ChapterHubEntry? get _suggested {
    if (group.entries.length < 2) return null;
    for (final e in group.entries) {
      if (_looksReal(e)) return e;
    }
    return null;
  }

  static bool _looksReal(ChapterHubEntry e) =>
      !e.flags.contains(ChapterFlag.notAName) && !e.flags.contains(ChapterFlag.alreadyChartered);

  String _suggestionLabel(ChapterHubEntry suggested) {
    final others = group.entries.where((e) => !identical(e, suggested));
    if (suggested.stage == ChapterStage.applied && others.every((e) => e.stage != ChapterStage.applied)) {
      return 'Has the application';
    }
    if (others.every((e) => e.memberCount < suggested.memberCount)) return 'Most members';
    return 'Best match';
  }

  Future<void> _run(ChapterHubEntry entry, Future<void> Function(ChapterHubEntry entry) action) async {
    final id = entry.chapter.id;
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await action(entry);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = group.entries.isNotEmpty ? group.entries.first : null;
    final suggested = _suggested;
    final match = group.charteredMatch;

    return HubCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: HubToneColors.of(context, HubTone.info).background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    chapterTypeIcon(first?.chapter.chapterType),
                    size: 20,
                    color: HubToneColors.of(context, HubTone.info).foreground,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${hubCount(group.entries.length, 'entry', 'entries')} · ${hubCount(group.memberCount, 'member')}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (group.entries.length > 1) ...[
            const SizedBox(height: 8),
            Text(
              match != null
                  ? 'These name the same place as a chartered chapter. Most are likely duplicates to archive.'
                  : 'These look like the same place. Charter the real one and archive the rest.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          if (match != null) ...[
            const SizedBox(height: 12),
            _CharteredBanner(match: match, onOpen: () => widget.actions.open(match.chapter)),
          ],
          const SizedBox(height: 12),
          for (var i = 0; i < group.entries.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _ReviewEntryRow(
              entry: group.entries[i],
              inGroup: group.entries.length > 1,
              suggestion: identical(group.entries[i], suggested) ? _suggestionLabel(suggested!) : null,
              emphasizeCharter: identical(group.entries[i], suggested) ||
                  (group.entries.length == 1 && _looksReal(group.entries[i])),
              busy: _busy.contains(group.entries[i].chapter.id),
              onOpen: () => widget.actions.open(group.entries[i].chapter),
              onCharter: () => _run(group.entries[i], widget.actions.charter),
              onArchive: () => _run(group.entries[i], widget.actions.archive),
              onViewApplication: group.entries[i].application == null
                  ? null
                  : () => widget.actions.viewApplication(group.entries[i].application!),
            ),
          ],
        ],
      ),
    );
  }
}

class _CharteredBanner extends StatelessWidget {
  final ChapterHubEntry match;
  final VoidCallback onOpen;
  const _CharteredBanner({required this.match, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = HubToneColors.of(context, HubTone.success);
    final name = match.chapter.chapterName.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.verified_outlined, size: 20, color: colors.foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Already chartered: '),
                  TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
                style: theme.textTheme.bodyMedium?.copyWith(color: colors.foreground),
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colors.foreground),
            onPressed: onOpen,
            child: Semantics(label: 'Open $name', excludeSemantics: true, child: const Text('Open')),
          ),
        ],
      ),
    );
  }
}

class _ReviewEntryRow extends StatelessWidget {
  final ChapterHubEntry entry;
  final bool inGroup;
  final String? suggestion;
  final bool emphasizeCharter;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onCharter;
  final VoidCallback onArchive;
  final VoidCallback? onViewApplication;

  const _ReviewEntryRow({
    required this.entry,
    required this.inGroup,
    required this.suggestion,
    required this.emphasizeCharter,
    required this.busy,
    required this.onOpen,
    required this.onCharter,
    required this.onArchive,
    required this.onViewApplication,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = hubDisplayName(entry);
    final place = hubPlaceLine(entry);
    final created = entry.chapter.createdAt;
    final app = entry.application;
    // Inside a group, "same school as other entries" is what the group says.
    final flags = entry.flags
        .where((f) => !(inGroup && f == ChapterFlag.sharedSchool))
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final highlighted = suggestion != null;
    final attention = HubToneColors.of(context, HubTone.attention);

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            if (suggestion != null)
              HubBadge(
                label: suggestion!,
                icon: Icons.star_rounded,
                tone: HubTone.attention,
                tooltip: 'Likely the one to charter',
              ),
          ],
        ),
        if (place != null) ...[
          const SizedBox(height: 2),
          Text(
            place,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChapterStageBadge.of(entry),
            HubFact(icon: Icons.groups_outlined, label: hubCount(entry.memberCount, 'member')),
            HubFact(icon: Icons.star_outline, label: hubCount(entry.leaderCount, 'leader')),
            if (created != null) HubFact(icon: Icons.event_outlined, label: 'Added ${hubDay(created)}'),
          ],
        ),
        if (flags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final flag in flags) HubBadge(label: flag.label, icon: Icons.flag_outlined, tone: HubTone.warning),
            ],
          ),
        ],
        if (app != null && (app.contactName != null || app.contactEmail != null)) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (app.contactName != null) HubFact(icon: Icons.person_outline, label: app.contactName!),
              if (app.contactEmail != null) HubFact(icon: Icons.mail_outline, label: app.contactEmail!),
            ],
          ),
        ],
      ],
    );

    final chapterName = entry.chapter.chapterName.trim();
    final actions = <Widget>[
      if (entry.isPending)
        emphasizeCharter
            ? FilledButton.icon(
                onPressed: busy ? null : onCharter,
                icon: const Icon(Icons.verified_outlined, size: 18),
                label: Semantics(label: 'Charter $chapterName', excludeSemantics: true, child: const Text('Charter')),
              )
            : FilledButton.tonalIcon(
                onPressed: busy ? null : onCharter,
                icon: const Icon(Icons.verified_outlined, size: 18),
                label: Semantics(label: 'Charter $chapterName', excludeSemantics: true, child: const Text('Charter')),
              ),
      if (onViewApplication != null)
        OutlinedButton.icon(
          onPressed: onViewApplication,
          icon: const Icon(Icons.description_outlined, size: 18),
          label: const Text('View application'),
        ),
      TextButton.icon(
        onPressed: onOpen,
        icon: const Icon(Icons.open_in_new, size: 18),
        label: Semantics(label: 'Open $chapterName', excludeSemantics: true, child: const Text('Open')),
      ),
      if (entry.isPending)
        TextButton.icon(
          onPressed: busy ? null : onArchive,
          style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
          icon: const Icon(Icons.archive_outlined, size: 18),
          label: Semantics(label: 'Archive $chapterName', excludeSemantics: true, child: const Text('Archive')),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlighted ? attention.background.withValues(alpha: 0.35) : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted ? attention.foreground.withValues(alpha: 0.45) : scheme.outlineVariant,
        ),
      ),
      child: _InfoWithActions(info: info, actions: actions),
    );
  }
}

/// Charter applications that were started but not finished, or that do not
/// match a chapter row yet, in one card so staff can follow up.
class UnmatchedApplicationsSection extends StatelessWidget {
  final List<CharterApplication> applications;
  final void Function(CharterApplication application) onView;

  const UnmatchedApplicationsSection({super.key, required this.applications, required this.onView});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final allUnfinished = applications.every((a) => !a.isComplete);
    return HubCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HubSectionTitle(
            title: allUnfinished ? 'Started but not finished' : 'Applications to follow up',
            icon: Icons.pending_actions_outlined,
            count: applications.length,
            description: allUnfinished
                ? 'Someone began the charter application but did not submit it. A quick note from you may help.'
                : 'Charter applications that are unfinished or do not match a chapter yet.',
          ),
          for (final app in applications) ...[
            Divider(height: 32, color: scheme.outlineVariant),
            _UnmatchedApplicationRow(application: app, onView: () => onView(app)),
          ],
        ],
      ),
    );
  }
}

class _UnmatchedApplicationRow extends StatelessWidget {
  final CharterApplication application;
  final VoidCallback onView;

  const _UnmatchedApplicationRow({required this.application, required this.onView});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = application;
    final name = app.chapterName ?? 'No name yet';
    final where = [
      if (app.county != null) app.county!,
      if (app.chapterType != null) chapterTypeLabel(app.chapterType),
    ].join(' · ');
    final date = app.submittedAt;

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontStyle: app.chapterName == null ? FontStyle.italic : null,
          ),
        ),
        if (where.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(where, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            app.isComplete
                ? const HubBadge(label: 'Finished, no chapter yet', icon: Icons.link_off, tone: HubTone.info)
                : const HubBadge(label: 'Not finished', icon: Icons.hourglass_bottom, tone: HubTone.warning),
            if (date != null) HubFact(icon: Icons.event_outlined, label: 'Started ${hubDay(date)}'),
            if (app.contactName != null) HubFact(icon: Icons.person_outline, label: app.contactName!),
            if (app.contactEmail != null) HubFact(icon: Icons.mail_outline, label: app.contactEmail!),
          ],
        ),
      ],
    );

    return _InfoWithActions(
      info: info,
      actions: [
        OutlinedButton.icon(
          onPressed: onView,
          icon: const Icon(Icons.description_outlined, size: 18),
          label: Semantics(label: 'View application for $name', excludeSemantics: true, child: const Text('View')),
        ),
      ],
    );
  }
}

/// Archived entries, folded away, each with Restore.
class ArchivedSection extends StatefulWidget {
  final List<ChapterHubEntry> entries;
  final ChapterReviewActions actions;
  const ArchivedSection({super.key, required this.entries, required this.actions});

  @override
  State<ArchivedSection> createState() => _ArchivedSectionState();
}

class _ArchivedSectionState extends State<ArchivedSection> {
  final Set<String> _busy = {};

  Future<void> _restore(ChapterHubEntry entry) async {
    final id = entry.chapter.id;
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await widget.actions.restore(entry);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return HubCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(Icons.archive_outlined, color: scheme.onSurfaceVariant),
          title: Text(
            'Archived (${widget.entries.length})',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            'Hidden from review and the directory. Restore any of them at any time.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          children: [
            for (var i = 0; i < widget.entries.length; i++) ...[
              if (i > 0) Divider(height: 16, color: scheme.outlineVariant),
              _archivedRow(context, widget.entries[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _archivedRow(BuildContext context, ChapterHubEntry entry) {
    final theme = Theme.of(context);
    final name = hubDisplayName(entry);
    final place = hubPlaceLine(entry);
    final chapterName = entry.chapter.chapterName.trim();
    return _InfoWithActions(
      info: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (place != null) HubFact(icon: chapterTypeIcon(entry.chapter.chapterType), label: place),
              HubFact(icon: Icons.groups_outlined, label: hubCount(entry.memberCount, 'member')),
            ],
          ),
        ],
      ),
      actions: [
        Tooltip(
          message: chapterRestoreLabel(entry.chapter),
          excludeFromSemantics: true,
          child: OutlinedButton.icon(
            onPressed: _busy.contains(entry.chapter.id) ? null : () => _restore(entry),
            icon: const Icon(Icons.restore, size: 18),
            label: Semantics(
              label: entry.chapter.isChartered
                  ? 'Restore $chapterName as an active chapter'
                  : 'Restore $chapterName to charter review',
              excludeSemantics: true,
              child: const Text('Restore'),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () => widget.actions.open(entry.chapter),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Semantics(label: 'Open $chapterName', excludeSemantics: true, child: const Text('Open')),
        ),
      ],
    );
  }
}
