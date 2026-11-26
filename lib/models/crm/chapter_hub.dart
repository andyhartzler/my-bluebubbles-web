import 'package:bluebubbles/models/crm/chapter.dart';

/// Where a chapter row stands on the road to a charter.
///
/// Rows reach the `chapters` table two ways: a full charter application (the
/// `chapter-chartering` form), or the `auto_create_chapter_from_member`
/// trigger, which adds a pending row whenever a new member types a chapter
/// name nobody has used before. Only the first is an application, so the hub
/// keeps them apart.
enum ChapterStage {
  /// Chartered by the executive committee.
  chartered,

  /// Pending, and a charter application is on file for it.
  applied,

  /// Pending, created from a member's sign-up answer. Not an application.
  signup,

  /// Hidden from review by staff (a duplicate or a non-answer).
  archived,
}

extension ChapterStageLabel on ChapterStage {
  String get label {
    switch (this) {
      case ChapterStage.chartered:
        return 'Chartered';
      case ChapterStage.applied:
        return 'Application in';
      case ChapterStage.signup:
        return 'From a sign-up';
      case ChapterStage.archived:
        return 'Archived';
    }
  }
}

/// Why a pending row may need a second look before anyone charters it.
enum ChapterFlag {
  /// Another row has the same name apart from case and spacing.
  duplicateName,

  /// Other rows name the same school or county.
  sharedSchool,

  /// The school or county already has a chartered chapter.
  alreadyChartered,

  /// The "name" reads like an answer to a question, not a club name.
  notAName,
}

extension ChapterFlagLabel on ChapterFlag {
  String get label {
    switch (this) {
      case ChapterFlag.duplicateName:
        return 'Same name as another entry';
      case ChapterFlag.sharedSchool:
        return 'Same school as other entries';
      case ChapterFlag.alreadyChartered:
        return 'School already has a chartered chapter';
      case ChapterFlag.notAName:
        return 'Looks like an answer, not a chapter name';
    }
  }
}

/// One charter application from the `chapter-chartering` form.
class CharterApplication {
  final String id;
  final String formId;
  final DateTime? submittedAt;
  final String status; // processed, in_progress, abandoned
  final String? chapterName;
  final String? chapterType;
  final String? contactName;
  final String? contactEmail;
  final String? contactPhone;
  final String? county;
  final String? officers;
  final List<String> fileUrls;
  final Map<String, dynamic> data;

  const CharterApplication({
    required this.id,
    required this.formId,
    required this.status,
    required this.data,
    this.submittedAt,
    this.chapterName,
    this.chapterType,
    this.contactName,
    this.contactEmail,
    this.contactPhone,
    this.county,
    this.officers,
    this.fileUrls = const [],
  });

  bool get isComplete => status == 'processed';

  factory CharterApplication.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    final data = raw is Map ? raw.map((k, dynamic v) => MapEntry(k.toString(), v)) : <String, dynamic>{};

    String? text(String key) {
      final value = data[key];
      if (value == null) return null;
      final s = value is List ? value.join(', ') : value.toString();
      final trimmed = s.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final first = text('contact_first_name');
    final last = text('contact_last_name');
    final joined = [first, last].whereType<String>().join(' ').trim();

    final files = <String>[];
    final rawFiles = json['file_urls'];
    if (rawFiles is List) {
      for (final f in rawFiles) {
        if (f != null && f.toString().trim().isNotEmpty) files.add(f.toString().trim());
      }
    }
    final docs = text('county_governing_documents');
    if (docs != null && docs.startsWith('http') && !files.contains(docs)) files.add(docs);

    return CharterApplication(
      id: json['id'] as String,
      formId: (json['form_id'] ?? '') as String,
      submittedAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      status: (json['status'] ?? '') as String,
      data: data,
      chapterName: text('chapter_name'),
      chapterType: text('chapter_type'),
      contactName: joined.isNotEmpty ? joined : (text('contact_name') ?? text('name')),
      contactEmail: text('contact_email') ?? text('email'),
      contactPhone: text('contact_phone') ?? text('phone'),
      county: text('county_selection'),
      officers: text('county_officers_list'),
      fileUrls: files,
    );
  }
}

/// A chapter with everything the hub shows about it.
class ChapterHubEntry {
  final Chapter chapter;
  final ChapterStage stage;
  final int memberCount;
  final int leaderCount;
  final int documentCount;
  final CharterApplication? application;
  final Set<ChapterFlag> flags;

  /// Key shared by rows that name the same school or county.
  final String schoolKey;

  const ChapterHubEntry({
    required this.chapter,
    required this.stage,
    required this.memberCount,
    required this.leaderCount,
    required this.documentCount,
    required this.schoolKey,
    this.application,
    this.flags = const {},
  });

  bool get isPending => stage == ChapterStage.applied || stage == ChapterStage.signup;

  /// The school or county, as people would say it.
  String get placeLabel {
    final school = chapter.schoolName.trim();
    if (chapter.chapterType == 'county') {
      return school.isNotEmpty && school != chapter.chapterName.trim() ? school : 'County chapter';
    }
    return school.isNotEmpty ? school : chapter.chapterName.trim();
  }
}

/// Pending rows that name the same school or county, reviewed together.
class ChapterReviewGroup {
  final String key;
  final String title;
  final List<ChapterHubEntry> entries;

  /// The chartered chapter at this school, when there is one.
  final ChapterHubEntry? charteredMatch;

  const ChapterReviewGroup({
    required this.key,
    required this.title,
    required this.entries,
    this.charteredMatch,
  });

  bool get hasApplication => entries.any((e) => e.stage == ChapterStage.applied);
  int get memberCount => entries.fold(0, (sum, e) => sum + e.memberCount);
}

/// Everything the Chapters hub needs, loaded in one pass.
class ChapterHubSnapshot {
  final List<ChapterHubEntry> entries;
  final List<ChapterReviewGroup> reviewGroups;

  /// Charter applications that were started but not finished, or not matched
  /// to any chapter row. Useful for follow-up.
  final List<CharterApplication> unmatchedApplications;

  final String? charterFormId;
  final DateTime loadedAt;

  /// True when charter applications could not be read. Stages then fall
  /// back to documents only, so screens should say the list may be
  /// incomplete.
  final bool applicationsFailed;

  const ChapterHubSnapshot({
    required this.entries,
    required this.reviewGroups,
    required this.unmatchedApplications,
    required this.loadedAt,
    this.charterFormId,
    this.applicationsFailed = false,
  });

  static final empty = ChapterHubSnapshot(
    entries: const [],
    reviewGroups: const [],
    unmatchedApplications: const [],
    loadedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  Iterable<ChapterHubEntry> get chartered => entries.where((e) => e.stage == ChapterStage.chartered);
  Iterable<ChapterHubEntry> get pending => entries.where((e) => e.isPending);
  int get applicationCount => entries.where((e) => e.stage == ChapterStage.applied).length;
  int get signupCount => entries.where((e) => e.stage == ChapterStage.signup).length;
  int get charteredMemberCount => chartered.fold(0, (sum, e) => sum + e.memberCount);

  ChapterHubEntry? entryFor(String chapterName) {
    for (final e in entries) {
      if (e.chapter.chapterName == chapterName) return e;
    }
    final key = ChapterHubKeys.name(chapterName);
    for (final e in entries) {
      if (ChapterHubKeys.name(e.chapter.chapterName) == key) return e;
    }
    return null;
  }

  ChapterReviewGroup? groupFor(String chapterName) {
    final key = ChapterHubKeys.name(chapterName);
    for (final g in reviewGroups) {
      if (g.entries.any((e) => ChapterHubKeys.name(e.chapter.chapterName) == key)) return g;
    }
    return null;
  }
}

/// Normalising rules shared by the hub and the screens that link into it.
class ChapterHubKeys {
  ChapterHubKeys._();

  /// Chapter names match the way members.chapter_name does: case and spacing
  /// do not matter.
  static String name(String? value) =>
      (value ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Words that never tell two schools apart.
  static const _filler = {
    'the', 'of', 'at', 'in', 'and', 'high', 'school', 'schol', 'hs', 'senior',
    'young', 'democrats', 'democrat', 'dems', 'club', 'chapter', 'mo',
    'missouri',
  };

  /// First words that many different schools share ("University of ...",
  /// "St. Louis ...", "Columbia College" vs "University of
  /// Missouri-Columbia"). A key starting with one of these takes a second
  /// word.
  static const _generic = {
    'university', 'college', 'community', 'state', 'st', 'saint', 'city',
    'north', 'south', 'east', 'west', 'northwest', 'southeast', 'central',
    'fort', 'lake', 'mount', 'columbia', 'kansas', 'new',
  };

  /// A key for "same school or county". Misspellings of one school
  /// ("Watkins", "Walkins", "Schol") share their first distinctive word, so
  /// that word is the key (two words when the first is generic). The type is
  /// left out on purpose: a county chapter and a high school row in that
  /// county ("Lafayette") land together. That over-groups a little, which is
  /// the safe direction for a review screen: people see the rows side by
  /// side and decide.
  static String school(Chapter chapter) {
    final type = chapter.chapterType;
    final source = type == 'county'
        ? chapter.chapterName
        : (chapter.schoolName.trim().isNotEmpty ? chapter.schoolName : chapter.chapterName);
    final words = source
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9 ]"), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !_filler.contains(w))
        .toList();
    if (words.isEmpty) return 'name:${name(source)}';
    if (_generic.contains(words.first) && words.length > 1) {
      return 'place:${words[0]} ${words[1]}';
    }
    return 'place:${words.first}';
  }

  static final _answerPattern = RegExp(
    r"(\?|\bi don.?t know\b|\bhaven.?t\b|\bdoes not\b|\bdoesn.?t\b|\bno chapter\b|\bnot sure\b|\bthe name of\b|^n/?a$|^none$)",
    caseSensitive: false,
  );

  /// True when a typed "chapter name" reads like an answer, not a name.
  static bool looksLikeAnswer(String value) {
    final v = value.trim();
    if (v.isEmpty) return true;
    if (_answerPattern.hasMatch(v)) return true;
    if (v.endsWith('.') && v.split(RegExp(r'\s+')).length >= 4) return true;
    return false;
  }
}
