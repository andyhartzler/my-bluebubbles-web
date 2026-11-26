import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/forms/screens/submission_detail_screen_lazy.dart';
import 'package:bluebubbles/models/crm/chapter_hub.dart';
import 'package:bluebubbles/services/crm/chapter_hub_service.dart';

import 'chapter_charter_actions.dart';
import 'chapter_navigation.dart';
import 'hub/chapter_card.dart';
import 'hub/hub_widgets.dart';
import 'hub/review_group_card.dart';

/// Which part of the hub opens first.
enum ChaptersHubTab { directory, review }

enum _StageFilter { all, chartered, pending, archived }

enum _TypeFilter { all, college, highschool, county }

extension on _TypeFilter {
  String get label {
    switch (this) {
      case _TypeFilter.all:
        return 'All';
      case _TypeFilter.college:
        return 'College';
      case _TypeFilter.highschool:
        return 'High school';
      case _TypeFilter.county:
        return 'County';
    }
  }
}

extension on _StageFilter {
  String get label {
    switch (this) {
      case _StageFilter.all:
        return 'All';
      case _StageFilter.chartered:
        return 'Chartered';
      case _StageFilter.pending:
        return 'Pending';
      case _StageFilter.archived:
        return 'Archived';
    }
  }
}

/// The Chapters page: a directory of every chapter, and the charter review
/// where pending entries (mostly sign-up answers, a few real applications)
/// are chartered or archived.
class ChaptersHubScreen extends StatefulWidget {
  /// True when shown inside the home shell's section stack (no app bar);
  /// false when pushed as its own route (shows an app bar with back).
  final bool embed;
  final ChaptersHubTab initialTab;

  const ChaptersHubScreen({
    super.key,
    this.embed = true,
    this.initialTab = ChaptersHubTab.directory,
  });

  @override
  State<ChaptersHubScreen> createState() => _ChaptersHubScreenState();
}

class _ChaptersHubScreenState extends State<ChaptersHubScreen> {
  final ChapterHubService _service = ChapterHubService.instance;
  final TextEditingController _search = TextEditingController();

  ChapterHubSnapshot? _snapshot;
  Object? _error;
  bool _loading = true;
  int _loadToken = 0;

  late ChaptersHubTab _tab = widget.initialTab;
  String _query = '';
  _StageFilter _stage = _StageFilter.all;
  _TypeFilter _type = _TypeFilter.all;

  @override
  void initState() {
    super.initState();
    _service.revision.addListener(_onRevision);
    if (widget.embed) {
      ChapterNavigation.requestedTab.addListener(_onRequestedTab);
      final requested = ChapterNavigation.requestedTab.value;
      if (requested != null) {
        _tab = requested;
        ChapterNavigation.requestedTab.value = null;
      }
    }
    _load();
  }

  /// A link elsewhere in the app asked for a tab; switch to it and clear
  /// the request so the next link starts fresh.
  void _onRequestedTab() {
    final requested = ChapterNavigation.requestedTab.value;
    if (requested == null || !mounted) return;
    ChapterNavigation.requestedTab.value = null;
    if (_tab != requested) setState(() => _tab = requested);
  }

  @override
  void didUpdateWidget(covariant ChaptersHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) _tab = widget.initialTab;
  }

  @override
  void dispose() {
    _service.revision.removeListener(_onRevision);
    ChapterNavigation.requestedTab.removeListener(_onRequestedTab);
    _search.dispose();
    super.dispose();
  }

  // The service already dropped its cache when the revision moved, so a
  // plain load fetches fresh data and shares it with any other listener.
  void _onRevision() => _load();

  late final ChapterReviewActions _actions = ChapterReviewActions(
    open: (chapter) => ChapterNavigation.openChapter(context, chapter),
    charter: (entry) => ChapterCharterActions.charter(context, entry.chapter),
    archive: (entry) => ChapterCharterActions.archive(context, entry.chapter, memberCount: entry.memberCount),
    restore: (entry) async {
      if (!await confirmChapterRestore(context, entry.chapter) || !mounted) return;
      await ChapterCharterActions.restore(context, entry.chapter);
    },
    viewApplication: (app) {
      final formId = app.formId.isNotEmpty ? app.formId : (_snapshot?.charterFormId ?? '');
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SubmissionDetailScreenLazy(formId: formId, submissionId: app.id)),
      );
    },
  );

  Future<void> _load({bool refresh = false}) async {
    final token = ++_loadToken;
    if (!_loading) setState(() => _loading = true);
    try {
      final snapshot = await _service.load(refresh: refresh);
      if (!mounted || token != _loadToken) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Chapters hub: load failed: $e');
      if (!mounted || token != _loadToken) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Directory filtering
  // ---------------------------------------------------------------------------

  bool get _filtersActive => _query.isNotEmpty || _stage != _StageFilter.all || _type != _TypeFilter.all;

  void _clearFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _stage = _StageFilter.all;
      _type = _TypeFilter.all;
    });
  }

  void _showDirectory({_StageFilter stage = _StageFilter.all}) {
    _search.clear();
    setState(() {
      _tab = ChaptersHubTab.directory;
      _query = '';
      _type = _TypeFilter.all;
      _stage = stage;
    });
  }

  void _showReview() => setState(() => _tab = ChaptersHubTab.review);

  bool _stageMatches(ChapterHubEntry e, _StageFilter stage) {
    switch (stage) {
      case _StageFilter.all:
        return e.stage != ChapterStage.archived;
      case _StageFilter.chartered:
        return e.stage == ChapterStage.chartered;
      case _StageFilter.pending:
        return e.isPending;
      case _StageFilter.archived:
        return e.stage == ChapterStage.archived;
    }
  }

  bool _typeMatches(ChapterHubEntry e, _TypeFilter type) =>
      type == _TypeFilter.all || e.chapter.chapterType.trim().toLowerCase() == type.name;

  bool _queryMatches(ChapterHubEntry e) {
    if (_query.isEmpty) return true;
    final haystack = [
      e.chapter.chapterName,
      e.chapter.schoolName,
      e.chapter.nameAbbreviation ?? '',
      e.placeLabel,
      e.application?.county ?? '',
      chapterTypeLabel(e.chapter.chapterType),
    ].join(' ').toLowerCase();
    return _query.split(RegExp(r'\s+')).every(haystack.contains);
  }

  static String _sortKey(ChapterHubEntry e) =>
      e.chapter.chapterName.trim().toLowerCase().replaceAll(RegExp(r'^[^a-z0-9]+'), '');

  static int _stageRank(ChapterStage stage) {
    switch (stage) {
      case ChapterStage.chartered:
        return 0;
      case ChapterStage.applied:
      case ChapterStage.signup:
        return 1;
      case ChapterStage.archived:
        return 2;
    }
  }

  List<ChapterHubEntry> _directoryEntries(ChapterHubSnapshot snapshot) {
    return snapshot.entries
        .where((e) => _stageMatches(e, _stage) && _typeMatches(e, _type) && _queryMatches(e))
        .toList()
      ..sort((a, b) {
        final rank = _stageRank(a.stage).compareTo(_stageRank(b.stage));
        if (rank != 0) return rank;
        return _sortKey(a).compareTo(_sortKey(b));
      });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // The branded background, as on Members and Meetings. Nothing readable
    // sits on it directly: every line of text is on a surface card, so the
    // page reads in light and dark themes alike.
    final body = Material(
      type: MaterialType.transparency,
      child: BrandedBackground(child: _buildScrollView()),
    );
    if (widget.embed) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Chapters')),
      body: body,
    );
  }

  Widget _buildScrollView() {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final compact = width < 720;
      // Content tops out at 1400 px so lines stay readable on big screens.
      final side = compact ? 12.0 : math.max(32.0, (width - 1400) / 2);
      final snapshot = _snapshot;

      final slivers = <Widget>[
        _pad(side, compact ? 12 : 24, SliverToBoxAdapter(child: _buildHeader(snapshot))),
        if (_error != null && snapshot != null) _pad(side, 16, SliverToBoxAdapter(child: _buildRefreshError())),
        if (snapshot == null && _error != null)
          _pad(side, 16, SliverToBoxAdapter(child: _buildLoadError()))
        else if (snapshot == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
          )
        else ...[
          _pad(side, 16, SliverToBoxAdapter(child: _buildStatBand(snapshot, compact))),
          _pad(side, 24, SliverToBoxAdapter(child: _buildTabs(snapshot, compact))),
          if (_tab == ChaptersHubTab.directory)
            ..._buildDirectory(snapshot, side, width)
          else
            ..._buildReview(snapshot, side),
        ],
        SliverToBoxAdapter(child: SizedBox(height: compact ? 24 : 32)),
      ];

      return RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: slivers,
        ),
      );
    });
  }

  Widget _pad(double side, double top, Widget sliver) =>
      SliverPadding(padding: EdgeInsets.fromLTRB(side, top, side, 0), sliver: sliver);

  Widget _buildHeader(ChapterHubSnapshot? snapshot) {
    final theme = Theme.of(context);
    final String summary;
    if (snapshot == null) {
      summary = _error == null ? 'Loading chapters…' : 'Chapters could not load';
    } else {
      final pending = snapshot.pending.length;
      summary = [
        '${snapshot.chartered.length} chartered',
        pending == 0 ? 'nothing waiting for review' : '$pending waiting for review',
        '${hubCount(snapshot.charteredMemberCount, 'member')} in chartered chapters',
      ].join(' · ');
    }

    return HubCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
            child: Row(
              children: [
                Container(
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: BrandColors.momentumBlue),
                  padding: const EdgeInsets.all(10),
                  child: const Icon(Icons.account_tree_outlined, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'Chapters',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        summary,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: _loading ? null : () => _load(refresh: true),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 3,
            child: _loading && snapshot != null
                ? const LinearProgressIndicator(minHeight: 3, color: BrandColors.momentumBlue)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshError() {
    return HubWarningStrip(
      message: "Couldn't refresh just now, so this may be out of date.",
      onRetry: _loading ? null : () => _load(refresh: true),
    );
  }

  Widget _buildLoadError() {
    return HubMessagePanel(
      icon: Icons.cloud_off_outlined,
      tone: HubTone.warning,
      title: 'Chapters could not load',
      message: 'Check your connection and try again.',
      action: FilledButton.icon(
        onPressed: () => _load(refresh: true),
        icon: const Icon(Icons.refresh),
        label: const Text('Try again'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Stat band
  // ---------------------------------------------------------------------------

  Widget _buildStatBand(ChapterHubSnapshot snapshot, bool compact) {
    final applications = snapshot.applicationCount;
    final signups = snapshot.signupCount;
    final listed = snapshot.entries.where((e) => e.stage != ChapterStage.archived).toList();
    final listedMembers = listed.fold<int>(0, (sum, e) => sum + e.memberCount);

    final tiles = <Widget>[
      HubStatTile(
        icon: Icons.verified_outlined,
        tone: HubTone.success,
        value: '${snapshot.chartered.length}',
        label: 'Chartered chapters',
        caption: hubCount(snapshot.charteredMemberCount, 'member'),
        semanticHint: 'Show chartered chapters',
        onTap: () => _showDirectory(stage: _StageFilter.chartered),
      ),
      HubStatTile(
        icon: Icons.assignment_turned_in_outlined,
        tone: HubTone.attention,
        value: '$applications',
        label: 'Charter applications',
        caption: applications == 0 ? 'None waiting' : 'Ready for review',
        semanticHint: 'Open charter review',
        onTap: _showReview,
      ),
      HubStatTile(
        icon: Icons.person_add_alt_outlined,
        tone: HubTone.info,
        value: '$signups',
        label: 'From sign-ups',
        caption: signups == 0 ? 'All sorted' : 'Need sorting',
        semanticHint: 'Open charter review',
        onTap: _showReview,
      ),
      HubStatTile(
        icon: Icons.groups_outlined,
        tone: HubTone.neutral,
        value: '$listedMembers',
        label: 'Members in chapters',
        caption: 'Across ${hubCount(listed.length, 'chapter')}',
        semanticHint: 'Show all chapters',
        onTap: () => _showDirectory(),
      ),
    ];

    Widget row(List<Widget> items, double gap) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(child: items[i]),
              ],
            ],
          ),
        );

    if (!compact) return row(tiles, 16);
    return Column(
      children: [
        row(tiles.sublist(0, 2), 12),
        const SizedBox(height: 12),
        row(tiles.sublist(2), 12),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tabs
  // ---------------------------------------------------------------------------

  Widget _buildTabs(ChapterHubSnapshot snapshot, bool compact) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pending = snapshot.pending.length;

    final reviewLabel = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Flexible(child: Text('Charter review', overflow: TextOverflow.ellipsis)),
        if (pending > 0) ...[
          const SizedBox(width: 6),
          Semantics(
            label: '$pending waiting',
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: BrandColors.sunriseGold,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$pending',
                style: const TextStyle(
                  color: BrandColors.unityBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );

    final button = SegmentedButton<ChaptersHubTab>(
      showSelectedIcon: false,
      expandedInsets: compact ? EdgeInsets.zero : null,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? BrandColors.unityBlue : scheme.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : scheme.onSurface,
        ),
        iconColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : scheme.onSurface,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
        minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
        textStyle: WidgetStatePropertyAll(theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
      ),
      segments: [
        ButtonSegment(
          value: ChaptersHubTab.directory,
          icon: compact ? null : const Icon(Icons.grid_view_rounded, size: 18),
          label: const Text('Directory', overflow: TextOverflow.ellipsis),
        ),
        ButtonSegment(
          value: ChaptersHubTab.review,
          icon: compact ? null : const Icon(Icons.fact_check_outlined, size: 18),
          label: reviewLabel,
        ),
      ],
      selected: {_tab},
      onSelectionChanged: (selection) => setState(() => _tab = selection.first),
    );

    if (compact) return button;
    return Align(alignment: Alignment.centerLeft, child: button);
  }

  // ---------------------------------------------------------------------------
  // Directory tab
  // ---------------------------------------------------------------------------

  List<Widget> _buildDirectory(ChapterHubSnapshot snapshot, double side, double width) {
    final entries = _directoryEntries(snapshot);
    final columns = width >= 1200 ? 3 : (width >= 720 ? 2 : 1);
    final gap = width >= 720 ? 16.0 : 12.0;
    final rows = (entries.length / columns).ceil();

    return [
      _pad(side, 16, SliverToBoxAdapter(child: _buildFilters(snapshot, entries.length))),
      if (snapshot.entries.isEmpty)
        _pad(
          side,
          16,
          const SliverToBoxAdapter(
            child: HubMessagePanel(
              icon: Icons.account_tree_outlined,
              title: 'No chapters yet',
              message:
                  'Chapters show up here once a member names one at sign-up or a charter application comes in.',
            ),
          ),
        )
      else if (entries.isEmpty)
        _pad(
          side,
          16,
          SliverToBoxAdapter(
            child: HubMessagePanel(
              icon: Icons.search_off,
              title: 'No chapters match',
              message: 'Try another search, or clear the filters to see every chapter.',
              action: OutlinedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Clear filters'),
              ),
            ),
          ),
        )
      else
        _pad(
          side,
          16,
          // Rows of cards rather than a SliverGrid: every card in a row takes
          // the tallest card's height, and nothing has a fixed aspect ratio
          // that larger text could overflow.
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, row) {
                final start = row * columns;
                return Padding(
                  padding: EdgeInsets.only(bottom: row == rows - 1 ? 0 : gap),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var c = 0; c < columns; c++) ...[
                          if (c > 0) SizedBox(width: gap),
                          Expanded(
                            child: start + c < entries.length
                                ? ChapterCard(
                                    key: ValueKey(entries[start + c].chapter.id),
                                    entry: entries[start + c],
                                    onOpen: () => _actions.open(entries[start + c].chapter),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
              childCount: rows,
            ),
          ),
        ),
    ];
  }

  Widget _buildFilters(ChapterHubSnapshot snapshot, int shown) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Each group's counts follow the other group's choice, so "College · 4"
    // means four college chapters at the stage picked, and the reverse.
    int typeCount(_TypeFilter type) =>
        snapshot.entries.where((e) => _stageMatches(e, _stage) && _typeMatches(e, type)).length;
    int stageCount(_StageFilter stage) =>
        snapshot.entries.where((e) => _stageMatches(e, stage) && _typeMatches(e, _type)).length;

    Widget group(String label, List<Widget> chips) => Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(label, style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
            ...chips,
          ],
        );

    String chipLabel(String label, int count) => '$label · $count';

    final archivedCount = snapshot.entries.where((e) => e.stage == ChapterStage.archived).length;
    final total = _stage == _StageFilter.archived
        ? archivedCount
        : snapshot.entries.where((e) => _stageMatches(e, _StageFilter.all)).length;

    return HubCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _search,
            onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search name, school, county or abbreviation',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              group('Type', [
                for (final type in _TypeFilter.values)
                  ChoiceChip(
                    label: Text(type == _TypeFilter.all ? type.label : chipLabel(type.label, typeCount(type))),
                    selected: _type == type,
                    onSelected: (_) => setState(() => _type = type),
                  ),
              ]),
              group('Stage', [
                for (final stage in _StageFilter.values)
                  if (stage != _StageFilter.archived || archivedCount > 0 || _stage == _StageFilter.archived)
                    ChoiceChip(
                      label: Text(stage == _StageFilter.all ? stage.label : chipLabel(stage.label, stageCount(stage))),
                      selected: _stage == stage,
                      onSelected: (_) => setState(() => _stage = stage),
                    ),
              ]),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _filtersActive
                      ? 'Showing $shown of ${hubCount(total, 'chapter')}'
                      : 'Chartered chapters first, then pending, A to Z.',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              if (_filtersActive)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: const Text('Clear filters'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Charter review tab
  // ---------------------------------------------------------------------------

  List<Widget> _buildReview(ChapterHubSnapshot snapshot, double side) {
    final theme = Theme.of(context);
    final groups = snapshot.reviewGroups;
    final archived = snapshot.entries.where((e) => e.stage == ChapterStage.archived).toList()
      ..sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));
    final pending = snapshot.pending.length;

    return [
      if (snapshot.applicationsFailed)
        _pad(
          side,
          16,
          SliverToBoxAdapter(
            child: HubWarningStrip(
              message: hubApplicationsFailedMessage,
              onRetry: _loading ? null : () => _load(refresh: true),
            ),
          ),
        ),
      _pad(
        side,
        16,
        SliverToBoxAdapter(
          child: HubCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HubSectionTitle(
                  title: 'Waiting for review',
                  icon: Icons.fact_check_outlined,
                  count: pending,
                  description:
                      'Most pending entries were made automatically when a member typed a new chapter name at sign-up. '
                      'Only entries marked “Application in” came through the charter application.',
                ),
                if (groups.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Entries that name the same place are grouped together. Charter the real chapter, '
                    'then archive duplicates and non-answers.',
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: HubToneColors.of(context, HubTone.attention).foreground,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'A starred entry is the likeliest one to charter.',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      if (groups.isEmpty)
        _pad(
          side,
          16,
          const SliverToBoxAdapter(
            child: HubMessagePanel(
              icon: Icons.check_circle_outline,
              tone: HubTone.success,
              title: 'Nothing waiting for review',
              message:
                  'Every chapter is chartered or archived. New sign-up names and charter applications will land here.',
            ),
          ),
        )
      else
        _pad(
          side,
          16,
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: EdgeInsets.only(bottom: index == groups.length - 1 ? 0 : 16),
                child: ReviewGroupCard(
                  key: ValueKey(groups[index].key),
                  group: groups[index],
                  actions: _actions,
                ),
              ),
              childCount: groups.length,
            ),
          ),
        ),
      if (snapshot.unmatchedApplications.isNotEmpty)
        _pad(
          side,
          24,
          SliverToBoxAdapter(
            child: UnmatchedApplicationsSection(
              applications: snapshot.unmatchedApplications,
              onView: _actions.viewApplication,
            ),
          ),
        ),
      if (archived.isNotEmpty) _pad(side, 24, SliverToBoxAdapter(child: ArchivedSection(entries: archived, actions: _actions))),
    ];
  }
}
