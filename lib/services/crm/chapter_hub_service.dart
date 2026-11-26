import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/models/crm/chapter.dart';
import 'package:bluebubbles/models/crm/chapter_hub.dart';

import 'supabase_service.dart';

/// Loads the Chapters hub: every chapter with its members, leaders,
/// documents and charter application, sorted into stages and review groups.
///
/// Read only. The writes a reviewer makes (charter, archive, restore) go
/// through [ChapterRepository].
class ChapterHubService {
  ChapterHubService._();
  static final ChapterHubService instance = ChapterHubService._();

  static const charterFormSlug = 'chapter-chartering';

  final CRMSupabaseService _supabase = CRMSupabaseService();

  SupabaseClient get _client => _supabase.client;

  /// Bumped after any write so every open hub view reloads.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// A cached snapshot older than this is reloaded on the next [load].
  static const maxAge = Duration(minutes: 3);

  ChapterHubSnapshot? _cache;
  Future<ChapterHubSnapshot>? _inflight;

  /// Bumped by every [invalidate] and forced refresh, so a slow load that
  /// started before a write can never overwrite the newer result.
  int _generation = 0;

  /// The last loaded snapshot, if any, without starting a load. For places
  /// like search that only decorate results with it.
  ChapterHubSnapshot? get cached => _cache;

  /// Drops the cache after a write and tells listeners to reload. Listeners
  /// should call [load] without `refresh`: the first one starts the reload
  /// and the rest share it.
  void invalidate() {
    _generation++;
    _cache = null;
    _inflight = null;
    revision.value++;
  }

  Future<ChapterHubSnapshot> load({bool refresh = false}) {
    if (!_supabase.isInitialized) return Future.value(ChapterHubSnapshot.empty);
    if (refresh) {
      _generation++;
      _cache = null;
      _inflight = null;
    }
    final cached = _cache;
    if (cached != null && DateTime.now().difference(cached.loadedAt) < maxAge) {
      return Future.value(cached);
    }
    final inflight = _inflight;
    if (inflight != null) return inflight;

    final generation = _generation;
    late final Future<ChapterHubSnapshot> future;
    future = _load().then((snapshot) {
      if (generation == _generation) _cache = snapshot;
      return snapshot;
    }).whenComplete(() {
      if (identical(_inflight, future)) _inflight = null;
    });
    _inflight = future;
    return future;
  }

  Future<ChapterHubSnapshot> _load() async {
    final results = await Future.wait<dynamic>([
      _client.from('chapters').select().order('chapter_name', ascending: true),
      _selectAll('members', 'chapter_name, chapter_position', notNull: 'chapter_name'),
      _selectAll('chapter_documents', 'chapter_name'),
      _loadApplications(),
    ]);

    final chapters = (results[0] as List<dynamic>)
        .map((json) => Chapter.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();

    // A member or document belongs to the row with exactly its chapter name
    // (that is how the chapter page lists them). Only a name with no exact
    // row falls back to the loose match, onto the first such row, so rows
    // that differ only by spacing ("Ladue Young Dems" and "Ladue Young
    // Dems ") never both claim the same people.
    final exactNames = {for (final c in chapters) c.chapterName};
    final looseOwner = <String, String>{};
    for (final c in chapters) {
      looseOwner.putIfAbsent(ChapterHubKeys.name(c.chapterName), () => c.chapterName);
    }
    String? ownerOf(Object? raw) {
      final value = raw?.toString();
      if (value == null || value.trim().isEmpty) return null;
      if (exactNames.contains(value)) return value;
      return looseOwner[ChapterHubKeys.name(value)];
    }

    final members = <String, int>{};
    final leaders = <String, int>{};
    for (final row in results[1] as List<Map<String, dynamic>>) {
      final owner = ownerOf(row['chapter_name']);
      if (owner == null) continue;
      members[owner] = (members[owner] ?? 0) + 1;
      final position = row['chapter_position']?.toString().trim() ?? '';
      if (position.isNotEmpty) leaders[owner] = (leaders[owner] ?? 0) + 1;
    }

    final documents = <String, int>{};
    for (final row in results[2] as List<Map<String, dynamic>>) {
      final owner = ownerOf(row['chapter_name']);
      if (owner == null) continue;
      documents[owner] = (documents[owner] ?? 0) + 1;
    }

    final (formId, applications, applicationsFailed) =
        results[3] as (String?, List<CharterApplication>, bool);

    // Newest finished application wins for a chapter name; an unfinished one
    // only counts when nothing finished exists.
    final applicationByName = <String, CharterApplication>{};
    for (final app in applications) {
      final key = ChapterHubKeys.name(app.chapterName);
      if (key.isEmpty) continue;
      final existing = applicationByName[key];
      if (existing == null || (!existing.isComplete && app.isComplete)) {
        applicationByName[key] = app;
      }
    }

    final nameCounts = <String, int>{};
    final schoolKeys = <String, String>{};
    for (final c in chapters) {
      final key = ChapterHubKeys.name(c.chapterName);
      nameCounts[key] = (nameCounts[key] ?? 0) + 1;
      schoolKeys[c.chapterName] = ChapterHubKeys.school(c);
    }

    // Same place and same type: a chartered college does not make a pending
    // high school in that town a duplicate.
    final charteredSchools = <String>{
      for (final c in chapters)
        if (c.isChartered) '${c.chapterType}|${schoolKeys[c.chapterName]!}',
    };
    final pendingPerSchool = <String, int>{};
    for (final c in chapters) {
      if (_isArchived(c) || c.isChartered) continue;
      final k = schoolKeys[c.chapterName]!;
      pendingPerSchool[k] = (pendingPerSchool[k] ?? 0) + 1;
    }

    // Every application named after an existing row is accounted for, not
    // only the one shown, so older drafts of a filed application do not show
    // up again under "Started but not finished".
    final rowKeys = {for (final c in chapters) ChapterHubKeys.name(c.chapterName)};
    final usedApplications = <String>{
      for (final a in applications)
        if (rowKeys.contains(ChapterHubKeys.name(a.chapterName))) a.id,
    };
    final entries = <ChapterHubEntry>[];
    for (final c in chapters) {
      final key = ChapterHubKeys.name(c.chapterName);
      final school = schoolKeys[c.chapterName]!;
      final app = applicationByName[key];
      final hasDocs = (documents[c.chapterName] ?? 0) > 0;

      final ChapterStage stage;
      if (_isArchived(c)) {
        stage = ChapterStage.archived;
      } else if (c.isChartered) {
        stage = ChapterStage.chartered;
      } else if ((app != null && app.isComplete) || hasDocs) {
        stage = ChapterStage.applied;
      } else {
        stage = ChapterStage.signup;
      }

      final flags = <ChapterFlag>{};
      if (stage == ChapterStage.applied || stage == ChapterStage.signup) {
        if ((nameCounts[key] ?? 0) > 1) flags.add(ChapterFlag.duplicateName);
        if ((pendingPerSchool[school] ?? 0) > 1) flags.add(ChapterFlag.sharedSchool);
        if (charteredSchools.contains('${c.chapterType}|$school')) flags.add(ChapterFlag.alreadyChartered);
        if (ChapterHubKeys.looksLikeAnswer(c.chapterName)) flags.add(ChapterFlag.notAName);
      }

      entries.add(ChapterHubEntry(
        chapter: c,
        stage: stage,
        memberCount: members[c.chapterName] ?? 0,
        leaderCount: leaders[c.chapterName] ?? 0,
        documentCount: documents[c.chapterName] ?? 0,
        application: app,
        flags: flags,
        schoolKey: school,
      ));
    }

    final groups = _buildGroups(entries);

    final unmatched = applications
        .where((a) => !usedApplications.contains(a.id) && a.status != 'abandoned' && !_isTest(a))
        .toList()
      ..sort((a, b) => (b.submittedAt ?? DateTime(0)).compareTo(a.submittedAt ?? DateTime(0)));

    return ChapterHubSnapshot(
      entries: entries,
      reviewGroups: groups,
      unmatchedApplications: unmatched,
      charterFormId: formId,
      applicationsFailed: applicationsFailed,
      loadedAt: DateTime.now(),
    );
  }

  List<ChapterReviewGroup> _buildGroups(List<ChapterHubEntry> entries) {
    final bySchool = <String, List<ChapterHubEntry>>{};
    final charteredBySchool = <String, ChapterHubEntry>{};
    for (final e in entries) {
      if (e.stage == ChapterStage.chartered) {
        // Same place and same type, as for the alreadyChartered flag.
        charteredBySchool.putIfAbsent('${e.chapter.chapterType}|${e.schoolKey}', () => e);
      }
      if (e.isPending) bySchool.putIfAbsent(e.schoolKey, () => []).add(e);
    }

    final groups = bySchool.entries.map((entry) {
      final list = entry.value
        ..sort((a, b) {
          // Applications first, then the row most members chose, then newest.
          final stage = a.stage.index.compareTo(b.stage.index);
          if (stage != 0) return stage;
          final members = b.memberCount.compareTo(a.memberCount);
          if (members != 0) return members;
          return (b.chapter.createdAt ?? DateTime(0)).compareTo(a.chapter.createdAt ?? DateTime(0));
        });
      return ChapterReviewGroup(
        key: entry.key,
        title: _groupTitle(list),
        entries: list,
        charteredMatch: list
            .map((e) => charteredBySchool['${e.chapter.chapterType}|${entry.key}'])
            .whereType<ChapterHubEntry>()
            .firstOrNull,
      );
    }).toList();

    groups.sort((a, b) {
      if (a.hasApplication != b.hasApplication) return a.hasApplication ? -1 : 1;
      final members = b.memberCount.compareTo(a.memberCount);
      if (members != 0) return members;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return groups;
  }

  /// The most common place label in the group, preferring the longest
  /// spelling on a tie (it is usually the complete school name).
  String _groupTitle(List<ChapterHubEntry> list) {
    final counts = <String, int>{};
    for (final e in list) {
      final label = e.placeLabel.trim();
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : b.key.length.compareTo(a.key.length);
      });
    return ranked.isEmpty ? 'Unnamed' : ranked.first.key;
  }

  /// Reads every row of a table, a page at a time (PostgREST caps a
  /// response at 1000 rows).
  Future<List<Map<String, dynamic>>> _selectAll(String table, String columns, {String? notNull}) async {
    const page = 1000;
    final rows = <Map<String, dynamic>>[];
    for (var from = 0;; from += page) {
      var query = _client.from(table).select(columns);
      if (notNull != null) query = query.not(notNull, 'is', null);
      final batch = await query.range(from, from + page - 1);
      rows.addAll((batch as List<dynamic>).map((r) => Map<String, dynamic>.from(r as Map)));
      if (batch.length < page) return rows;
    }
  }

  Future<(String?, List<CharterApplication>, bool)> _loadApplications() async {
    try {
      final form = await _client
          .from('form_schemas')
          .select('id')
          .eq('slug', charterFormSlug)
          .maybeSingle();
      final formId = form?['id']?.toString();
      if (formId == null) return (null, <CharterApplication>[], false);
      final rows = await _client
          .from('form_submissions')
          .select('id, form_id, created_at, status, data, file_urls')
          .eq('form_id', formId)
          .order('created_at', ascending: false);
      final apps = (rows as List<dynamic>)
          .map((r) => CharterApplication.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
      return (formId, apps, false);
    } catch (e) {
      debugPrint('Chapters hub: charter applications unavailable: $e');
      return (null, <CharterApplication>[], true);
    }
  }

  static bool _isArchived(Chapter c) => (c.status ?? '').trim().toLowerCase() == 'archived';

  static bool _isTest(CharterApplication a) {
    final name = (a.chapterName ?? '').toLowerCase();
    return name.startsWith('test ') || name == 'test' || name == 'na' || name == 'n/a';
  }
}
