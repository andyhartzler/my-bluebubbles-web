import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/forms/screens/submission_detail_screen_lazy.dart';
import 'package:bluebubbles/models/crm/chapter.dart';
import 'package:bluebubbles/models/crm/chapter_hub.dart';
import 'package:bluebubbles/services/crm/chapter_hub_service.dart';

import 'chapter_charter_actions.dart';
import 'chapter_navigation.dart';
import 'chapters_hub_screen.dart';
import 'hub/hub_widgets.dart';

/// The charter card on a chapter's page: where the chapter stands, its
/// charter application, what to check before chartering it, and the
/// charter / archive / restore actions.
class ChapterCharterPanel extends StatefulWidget {
  final Chapter chapter;

  /// Called with the saved chapter after a charter, archive or restore.
  final ValueChanged<Chapter> onChapterChanged;

  /// Called whenever the hub entry for this chapter (re)loads.
  final ValueChanged<ChapterHubEntry?>? onEntryLoaded;

  const ChapterCharterPanel({
    super.key,
    required this.chapter,
    required this.onChapterChanged,
    this.onEntryLoaded,
  });

  @override
  State<ChapterCharterPanel> createState() => _ChapterCharterPanelState();
}

enum _StepState { done, current, upcoming, skipped }

class _Step {
  final String title;
  final String subtitle;
  final _StepState state;

  const _Step(this.title, this.subtitle, this.state);
}

class _ChapterCharterPanelState extends State<ChapterCharterPanel> {
  static final _date = DateFormat('MMM d, y');

  ChapterHubSnapshot? _snapshot;
  bool _loading = true;
  bool _failed = false;
  bool _busy = false;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    ChapterHubService.instance.revision.addListener(_onRevision);
    _load(initial: true);
  }

  @override
  void dispose() {
    ChapterHubService.instance.revision.removeListener(_onRevision);
    super.dispose();
  }

  void _onRevision() => _load();

  Future<void> _load({bool refresh = false, bool initial = false}) async {
    final token = ++_loadToken;
    if (!initial && mounted) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }
    try {
      final snapshot = await ChapterHubService.instance.load(refresh: refresh);
      if (!mounted || token != _loadToken) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
      final entry = _entryIn(snapshot);
      widget.onEntryLoaded?.call(entry);
      // After a write elsewhere (an Undo in a snackbar, a change in the hub)
      // the fresh row may say something the page does not. The first load
      // can come from an older cache, so only reloads are trusted for this.
      if (!initial && entry != null && entry.chapter.id == widget.chapter.id && _charterChanged(entry.chapter)) {
        widget.onChapterChanged(entry.chapter);
      }
    } catch (e) {
      debugPrint('Chapter charter panel: hub load failed: $e');
      if (!mounted || token != _loadToken) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  bool _charterChanged(Chapter fresh) {
    final held = widget.chapter;
    return (fresh.status ?? '').trim().toLowerCase() != (held.status ?? '').trim().toLowerCase() ||
        fresh.isChartered != held.isChartered ||
        fresh.charterDate != held.charterDate;
  }

  /// This row's entry. Matched by id first: two rows can share a name apart
  /// from spacing ("Ladue Young Dems" and "Ladue Young Dems ").
  ChapterHubEntry? _entryIn(ChapterHubSnapshot snapshot) {
    for (final e in snapshot.entries) {
      if (e.chapter.id == widget.chapter.id) return e;
    }
    return snapshot.entryFor(widget.chapter.chapterName);
  }

  ChapterReviewGroup? _groupIn(ChapterHubSnapshot snapshot) {
    for (final g in snapshot.reviewGroups) {
      if (g.entries.any((e) => e.chapter.id == widget.chapter.id)) return g;
    }
    return snapshot.groupFor(widget.chapter.chapterName);
  }

  Future<void> _run(Future<Chapter?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    Chapter? updated;
    try {
      updated = await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && updated != null) widget.onChapterChanged(updated);
  }

  Future<Chapter?> _restore() async {
    final chapter = widget.chapter;
    if (!await confirmChapterRestore(context, chapter) || !mounted) return null;
    return ChapterCharterActions.restore(context, chapter);
  }

  Future<void> _open(Uri uri) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Chapter charter panel: could not open $uri: $e');
    }
    if (!ok) messenger?.showSnackBar(const SnackBar(content: Text("Couldn't open that link.")));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chapter = widget.chapter;
    final snapshot = _failed ? null : _snapshot;
    final entry = snapshot == null ? null : _entryIn(snapshot);
    final stage = chapterStageOf(chapter, entry: entry);
    final pending = stage == ChapterStage.applied || stage == ChapterStage.signup;
    final group = pending && snapshot != null ? _groupIn(snapshot) : null;
    final app = entry?.application;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final compact = width < 520;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme, stage, pending),
                const SizedBox(height: 6),
                Text(
                  _summary(chapter, stage, entry),
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (_loading) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    label: 'Loading charter details',
                    child: const LinearProgressIndicator(minHeight: 2),
                  ),
                ],
                const SizedBox(height: 20),
                if (stage == ChapterStage.archived)
                  _buildArchived(theme)
                else
                  _buildSteps(theme, _steps(chapter, stage, entry), vertical: compact),
                if (_failed) ...[
                  const SizedBox(height: 16),
                  _buildRetry(theme),
                ],
                if (snapshot != null && snapshot.applicationsFailed) ...[
                  const SizedBox(height: 16),
                  HubWarningStrip(
                    message: hubApplicationsFailedMessage,
                    onRetry: _loading ? null : () => _load(refresh: true),
                  ),
                ],
                if (app != null) ...[
                  const SizedBox(height: 24),
                  _buildApplication(theme, app, compact: compact, maxWidth: width),
                ],
                if (pending && entry != null && (entry.flags.isNotEmpty || group != null))
                  ..._buildReview(theme, chapter, entry, group, maxWidth: width),
                if (pending) ...[
                  const SizedBox(height: 24),
                  _buildPendingActions(entry),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ChapterStage stage, bool pending) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Charter', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            ChapterStageBadge(stage: stage, charterDate: widget.chapter.charterDate),
          ],
        ),
        TextButton.icon(
          style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
          icon: const Icon(Icons.account_tree_outlined, size: 18),
          label: Text(pending ? 'Back to charter review' : 'All chapters'),
          onPressed: () => ChapterNavigation.openHub(
            context,
            initialTab: pending ? ChaptersHubTab.review : ChaptersHubTab.directory,
          ),
        ),
      ],
    );
  }

  String _summary(Chapter chapter, ChapterStage stage, ChapterHubEntry? entry) {
    switch (stage) {
      case ChapterStage.chartered:
        final date = chapter.charterDate;
        return date != null
            ? 'Chartered on ${chapterCharterDay(date)}.'
            : 'Chartered. No charter date is set yet; add one with Edit.';
      case ChapterStage.applied:
        return entry?.application != null
            ? 'A charter application is in. Look it over, then charter or archive it.'
            : 'Charter documents are on file. Look them over, then charter or archive it.';
      case ChapterStage.signup:
        return 'Added when a member typed this name at sign-up. No charter application yet.';
      case ChapterStage.archived:
        return 'Out of charter review and the chapter directory. Nothing was deleted.';
    }
  }

  List<_Step> _steps(Chapter chapter, ChapterStage stage, ChapterHubEntry? entry) {
    final app = entry?.application;
    final docs = entry?.documentCount ?? 0;

    final startedAt = app?.submittedAt ?? chapter.createdAt;
    final started = _Step(
      'Started',
      startedAt == null
          ? 'Date unknown'
          : '${app != null ? 'Applied' : 'Signed up'} ${_date.format(startedAt.toLocal())}',
      _StepState.done,
    );

    final _Step application;
    final hasApplication = (app?.isComplete ?? false) || docs > 0;
    if (hasApplication) {
      application = _Step(
        'Application',
        app?.submittedAt != null && app!.isComplete
            ? 'Submitted ${_date.format(app.submittedAt!.toLocal())}'
            : 'Documents on file',
        _StepState.done,
      );
    } else if (stage == ChapterStage.chartered) {
      application = const _Step('Application', 'None on file', _StepState.skipped);
    } else if (app != null) {
      application = const _Step('Application', 'Started, not finished', _StepState.current);
    } else {
      application = const _Step('Application', 'No charter application yet', _StepState.current);
    }

    final _Step chartered;
    if (stage == ChapterStage.chartered) {
      final date = chapter.charterDate;
      chartered = _Step('Chartered', date != null ? chapterCharterDay(date) : 'Date not set', _StepState.done);
    } else if (stage == ChapterStage.applied) {
      chartered = const _Step('Chartered', 'Waiting on exec review', _StepState.current);
    } else {
      chartered = const _Step('Chartered', 'Not yet', _StepState.upcoming);
    }

    return [started, application, chartered];
  }

  Widget _buildSteps(ThemeData theme, List<_Step> steps, {required bool vertical}) {
    final scheme = theme.colorScheme;

    Color lineColor(int index) =>
        steps[index].state == _StepState.done && steps[index + 1].state == _StepState.done
            ? BrandColors.success
            : scheme.outlineVariant;

    Widget circle(int index) {
      final step = steps[index];
      final Widget child;
      final BoxDecoration decoration;
      switch (step.state) {
        case _StepState.done:
          decoration = const BoxDecoration(color: BrandColors.success, shape: BoxShape.circle);
          child = const Icon(Icons.check, size: 16, color: Colors.white);
          break;
        case _StepState.current:
          decoration = BoxDecoration(
            shape: BoxShape.circle,
            color: BrandColors.momentumBlue.withValues(alpha: 0.12),
            border: Border.all(color: BrandColors.momentumBlue, width: 2),
          );
          child = Text('${index + 1}',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface));
          break;
        case _StepState.upcoming:
          decoration = BoxDecoration(shape: BoxShape.circle, border: Border.all(color: scheme.outlineVariant, width: 2));
          child = Text('${index + 1}',
              style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant));
          break;
        case _StepState.skipped:
          decoration = BoxDecoration(shape: BoxShape.circle, border: Border.all(color: scheme.outlineVariant, width: 2));
          child = Icon(Icons.remove, size: 16, color: scheme.onSurfaceVariant);
          break;
      }
      return Container(width: 28, height: 28, alignment: Alignment.center, decoration: decoration, child: child);
    }

    String stateWord(_StepState s) {
      switch (s) {
        case _StepState.done:
          return 'done';
        case _StepState.current:
          return 'next';
        case _StepState.upcoming:
          return 'not yet';
        case _StepState.skipped:
          return 'skipped';
      }
    }

    Widget labels(_Step step, {required bool center}) {
      final muted = step.state == _StepState.upcoming || step.state == _StepState.skipped;
      return Column(
        crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            step.title,
            textAlign: center ? TextAlign.center : TextAlign.start,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: step.state == _StepState.current ? FontWeight.w700 : FontWeight.w600,
              color: muted ? scheme.onSurfaceVariant : scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            step.subtitle,
            textAlign: center ? TextAlign.center : TextAlign.start,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      );
    }

    Widget wrapSemantics(int index, Widget child) {
      final step = steps[index];
      return Semantics(
        label: 'Step ${index + 1} of ${steps.length}, ${step.title}: ${stateWord(step.state)}. ${step.subtitle}',
        excludeSemantics: true,
        child: child,
      );
    }

    if (vertical) {
      return Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            wrapSemantics(
              i,
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 28,
                      child: Column(
                        children: [
                          circle(i),
                          if (i < steps.length - 1)
                            Expanded(
                              child: Container(
                                width: 2,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                color: lineColor(i),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 3, bottom: i < steps.length - 1 ? 16 : 0),
                        child: labels(steps[i], center: false),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Expanded(
            child: wrapSemantics(
              i,
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.only(right: 6),
                          color: i == 0 ? Colors.transparent : lineColor(i - 1),
                        ),
                      ),
                      circle(i),
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.only(left: 6),
                          color: i == steps.length - 1 ? Colors.transparent : lineColor(i),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: labels(steps[i], center: true),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildArchived(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.archive_outlined, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Archived',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            icon: _busy ? _spinner() : const Icon(Icons.unarchive_outlined),
            label: Text(chapterRestoreLabel(widget.chapter)),
            onPressed: _busy ? null : () => _run(_restore),
          ),
        ],
      ),
    );
  }

  Widget _buildRetry(ThemeData theme) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        Icon(Icons.cloud_off_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
        Text(
          'Charter details did not load.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _loading ? null : () => _load(refresh: true),
          child: const Text('Try again'),
        ),
      ],
    );
  }

  Widget _subTitle(ThemeData theme, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _buildApplication(ThemeData theme, CharterApplication app, {required bool compact, required double maxWidth}) {
    final scheme = theme.colorScheme;
    final facts = <Widget>[
      if (app.submittedAt != null) _fact(theme, 'Submitted', Text(_date.format(app.submittedAt!.toLocal())), compact),
      _fact(
        theme,
        'Status',
        Align(
          alignment: Alignment.centerLeft,
          child: _statusChip(theme, app.isComplete),
        ),
        compact,
      ),
      if (app.contactName != null) _fact(theme, 'Contact', SelectableText(app.contactName!), compact),
      if (app.contactEmail != null)
        _fact(
          theme,
          'Email',
          _link(theme, app.contactEmail!, Icons.email_outlined, 'Email ${app.contactEmail}',
              () => _open(Uri(scheme: 'mailto', path: app.contactEmail!))),
          compact,
        ),
      if (app.contactPhone != null)
        _fact(
          theme,
          'Phone',
          _link(theme, app.contactPhone!, Icons.phone_outlined, 'Call ${app.contactPhone}',
              () => _open(Uri(scheme: 'tel', path: app.contactPhone!.replaceAll(RegExp(r'[^0-9+]'), '')))),
          compact,
        ),
      if (app.county != null) _fact(theme, 'County', SelectableText(app.county!), compact),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _subTitle(theme, Icons.assignment_outlined, 'Charter application'),
        const SizedBox(height: 12),
        ...facts,
        if (app.officers != null) ...[
          const SizedBox(height: 12),
          Text('Officers', style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: SelectableText(app.officers!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
          ),
        ],
        if (app.fileUrls.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Attached files', style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < app.fileUrls.length; i++) _fileChip(theme, app.fileUrls[i], i, maxWidth),
            ],
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
          icon: const Icon(Icons.open_in_new),
          label: const Text('View full application'),
          onPressed: app.formId.isEmpty
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SubmissionDetailScreenLazy(formId: app.formId, submissionId: app.id),
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _fact(ThemeData theme, String label, Widget value, bool compact) {
    final labelText = Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [labelText, const SizedBox(height: 2), value],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 120, child: labelText),
          const SizedBox(width: 12),
          Expanded(child: value),
        ],
      ),
    );
  }

  Widget _statusChip(ThemeData theme, bool complete) {
    return HubBadge(
      label: complete ? 'Complete' : 'Not finished',
      icon: complete ? Icons.check_circle_outline : Icons.hourglass_bottom,
      tone: complete ? HubTone.success : HubTone.warning,
    );
  }

  Widget _link(ThemeData theme, String text, IconData icon, String semantics, VoidCallback onTap) {
    final color = theme.colorScheme.primary;
    return Semantics(
      link: true,
      label: semantics,
      excludeSemantics: true,
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      text,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: color.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fileChip(ThemeData theme, String url, int index, double maxWidth) {
    final uri = Uri.tryParse(url);
    var name = 'File ${index + 1}';
    final segments = uri?.pathSegments.where((s) => s.isNotEmpty).toList() ?? const <String>[];
    if (segments.isNotEmpty) {
      try {
        name = Uri.decodeComponent(segments.last);
      } catch (_) {
        name = segments.last;
      }
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth.clamp(120.0, 320.0)),
      child: ActionChip(
        tooltip: 'Open $name',
        avatar: Icon(Icons.attach_file, size: 16, color: theme.colorScheme.primary),
        label: Text(name, overflow: TextOverflow.ellipsis),
        onPressed: uri == null ? null : () => _open(uri),
      ),
    );
  }

  List<Widget> _buildReview(
    ThemeData theme,
    Chapter chapter,
    ChapterHubEntry entry,
    ChapterReviewGroup? group, {
    required double maxWidth,
  }) {
    final scheme = theme.colorScheme;
    final siblings = group?.entries.where((e) => e.chapter.id != chapter.id).toList() ?? const <ChapterHubEntry>[];
    final match = group?.charteredMatch;
    if (entry.flags.isEmpty && siblings.isEmpty && match == null) return const [];
    final flagColors = HubToneColors.of(context, HubTone.warning);
    final matchColors = HubToneColors.of(context, HubTone.success);

    return [
      const SizedBox(height: 24),
      _subTitle(theme, Icons.fact_check_outlined, 'Before you charter'),
      if (entry.flags.isNotEmpty) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final flag in entry.flags)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: flagColors.background,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag_outlined, size: 16, color: flagColors.foreground),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          flag.label,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: flagColors.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
      if (match != null) ...[
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BrandColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BrandColors.success.withValues(alpha: 0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.verified, size: 18, color: matchColors.foreground),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${match.placeLabel} already has a chartered chapter:',
                      style: theme.textTheme.bodyMedium,
                    ),
                    _link(
                      theme,
                      match.chapter.chapterName.trim(),
                      Icons.account_tree_outlined,
                      'Open chapter ${match.chapter.chapterName.trim()}',
                      () => ChapterNavigation.openChapter(context, match.chapter),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      if (siblings.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(
          'Also at ${group!.title}',
          style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < siblings.length; i++) ...[
                if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
                _siblingRow(theme, siblings[i]),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  Widget _siblingRow(ThemeData theme, ChapterHubEntry e) {
    final scheme = theme.colorScheme;
    final name = e.chapter.chapterName.trim();
    final members = '${e.memberCount} ${e.memberCount == 1 ? 'member' : 'members'}';
    return Semantics(
      button: true,
      label: 'Open $name, ${e.stage.label}, $members',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => ChapterNavigation.openChapter(context, e.chapter),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Unnamed' : name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(members, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ChapterStageBadge.of(e),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingActions(ChapterHubEntry? entry) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          icon: _busy ? _spinner() : const Icon(Icons.verified),
          label: const Text('Charter this chapter'),
          onPressed: _busy ? null : () => _run(() => ChapterCharterActions.charter(context, widget.chapter)),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
          icon: const Icon(Icons.archive_outlined),
          label: const Text('Archive'),
          onPressed: _busy
              ? null
              : () => _run(() => ChapterCharterActions.archive(
                    context,
                    widget.chapter,
                    memberCount: entry?.memberCount ?? 0,
                  )),
        ),
      ],
    );
  }

  Widget _spinner() => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
}
