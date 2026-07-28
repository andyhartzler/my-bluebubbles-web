import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/form_schema.dart';
import '../../models/submission_review_model.dart';
import '../../services/forms_service.dart';
import 'ai_score_repository.dart';
import 'models/candidate_entry.dart';
import 'models/slate_stats.dart';
import 'race_field_repository.dart';
import 'widgets/decisions/district_ref.dart';

/// How the roster is sorted.
enum SlateSort {
  alignmentDesc('Alignment (high → low)'),
  name('Name (A → Z)'),
  office('Office level'),
  race('Race (district)'),
  newest('Newest first'),
  selfFunded('Self-funded %'),
  supportCount('Most support');

  const SlateSort(this.label);
  final String label;
}

/// Loads the endorsement form + submissions once, builds a [CandidateEntry] per
/// submission, and holds the roster filter / sort / selection state shared by
/// every tab of the Endorsement HQ.
class SlateController extends ChangeNotifier {
  SlateController(
      {FormsService? service,
      EndorsementAiScoreRepository? aiScores,
      EndorsementRaceRepository? races})
      : _service = service ?? FormsService(),
        _aiScores = aiScores ?? EndorsementAiScoreRepository(),
        _races = races ?? EndorsementRaceRepository();

  final FormsService _service;
  final EndorsementAiScoreRepository _aiScores;
  final EndorsementRaceRepository _races;

  /// The canonical endorsement form id. A slug fallback runs if this id 404s.
  static const String endorsementFormId =
      '945738f0-ff66-420f-8707-afb4a23ca58b';
  static const String endorsementSlug = 'endorsement-questionnaire-2026';

  bool _loading = true;
  String? _error;
  FormSchema? _form;
  List<CandidateEntry> _all = const [];

  bool get loading => _loading;
  String? get error => _error;
  FormSchema? get form => _form;
  List<CandidateEntry> get all => _all;
  bool get hasSubmissions => _all.isNotEmpty;

  // ----- race identity (side maps keyed by submission id / race key) -----
  //
  // Race identity is a fourth non-fatal fetch, the same pattern as aiScores
  // and photoFallback, but with one deliberate difference: a failure here
  // must degrade to "no clusters and no opponent field", never to a wrong
  // cluster, so the maps simply stay empty and _raceLoadFailed flips true.
  // The board reads that flag to distinguish "this race is uncontested"
  // from "we could not find out", which are different statements and only
  // one of them is safe to imply.
  Map<String, RaceInfo> _raceInfo = const {};
  Map<String, List<RaceFieldCandidate>> _raceField = const {};
  Map<String, int> _raceApplicantCounts = const {};
  bool _raceLoadFailed = false;
  bool _raceDataLoaded = false;

  /// Resolved race identity for one submission, or null when the view does
  /// not cover it (or the fetch failed).
  RaceInfo? raceInfoFor(String submissionId) => _raceInfo[submissionId];

  /// True once the race fetch has settled either way. The disclosure renders
  /// nothing before this (transient, part of load()).
  bool get raceDataLoaded => _raceDataLoaded;
  bool get raceLoadFailed => _raceLoadFailed;

  /// Non-applicant Democrats sharing [raceKey], alphabetized. Empty is the
  /// common case (43 of 59 races have no other filed Democrat).
  List<RaceFieldCandidate> raceFieldFor(String? raceKey) =>
      raceKey == null ? const [] : (_raceField[raceKey] ?? const []);

  /// How many of OUR applicants (post-dedupe board entries) share [raceKey].
  /// >= 2 means the race is contested and drives both the ballot clusters and
  /// the Browse "N applied" pill.
  int applicantsInRace(String raceKey) => _raceApplicantCounts[raceKey] ?? 0;

  /// Display name with the race view's coalesced fallback.
  ///
  /// One submission (Hope Tinker, 587c32d7) has neither data->>'name' nor
  /// data->>'full_name', so SubmissionReviewModel.candidateName is empty and
  /// the row would render nameless. v_endorsement_applicant_race coalesces
  /// the linked candidates.name; this is the only place that fallback is
  /// consulted, so every surface that needs the fallback goes through it.
  /// 'Name not provided' is a statement of fact, not a placeholder: it is
  /// what the data says when both the submission and the linked candidate
  /// row are silent.
  String displayNameFor(CandidateEntry e) {
    final n = e.name.trim();
    if (n.isNotEmpty) return n;
    final fallback = _raceInfo[e.id]?.displayName?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return 'Name not provided';
  }

  // ----- filter / sort state -----
  String _search = '';
  SlateSort _sort = SlateSort.alignmentDesc;
  final Set<OfficeLevel> _officeFilter = {};
  String _districtFilter = '';
  RangeValuesLite _alignmentRange = const RangeValuesLite(0, 100);
  bool _includeUnscored = true;
  bool _youngDemOnly = false;

  // Flag toggles (each: only-those-with-flag when true).
  bool _flagNonDem = false;
  bool _flagSelfFunded = false;
  bool _flagMissingDocs = false;
  bool _flagUncertified = false;

  String get search => _search;
  SlateSort get sort => _sort;
  Set<OfficeLevel> get officeFilter => _officeFilter;
  String get districtFilter => _districtFilter;
  RangeValuesLite get alignmentRange => _alignmentRange;
  bool get includeUnscored => _includeUnscored;
  bool get youngDemOnly => _youngDemOnly;
  bool get flagNonDem => _flagNonDem;
  bool get flagSelfFunded => _flagSelfFunded;
  bool get flagMissingDocs => _flagMissingDocs;
  bool get flagUncertified => _flagUncertified;

  bool get hasActiveFilters =>
      _search.isNotEmpty ||
      _officeFilter.isNotEmpty ||
      _districtFilter.isNotEmpty ||
      _alignmentRange.start > 0 ||
      _alignmentRange.end < 100 ||
      !_includeUnscored ||
      _youngDemOnly ||
      _flagNonDem ||
      _flagSelfFunded ||
      _flagMissingDocs ||
      _flagUncertified;

  // ----- selection (compare tray) -----
  final Set<String> _selected = {};
  Set<String> get selectedIds => _selected;
  int get selectedCount => _selected.length;
  bool isSelected(String id) => _selected.contains(id);

  List<CandidateEntry> get selectedEntries =>
      _all.where((e) => _selected.contains(e.id)).toList();

  // ==================== load ====================

  /// Ceiling on every await inside [load].
  ///
  /// There was none, and `_loading` is only ever cleared at the end of the
  /// try or in its catch: a request that never completes therefore pinned the
  /// whole Endorsement HQ on "Loading the slate…" for the rest of the
  /// session, with no error, no Retry, and no way back except a full reload
  /// of the app. A timeout converts that into the error card that already
  /// exists, which carries a Retry button.
  static const Duration slateLoadTimeout = Duration(seconds: 25);

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      FormSchema form;
      try {
        form = await _service
            .getForm(endorsementFormId)
            .timeout(slateLoadTimeout);
      } catch (_) {
        // Fallback: resolve by slug when the constant id no longer matches.
        final forms =
            await _service.fetchForms('all').timeout(slateLoadTimeout);
        form = forms.firstWhere(
          (f) => f.slug == endorsementSlug,
          orElse: () => throw StateError(
              'Endorsement form not found by id or slug "$endorsementSlug".'),
        );
      }
      final submissions =
          await _service.getSubmissions(form.id).timeout(slateLoadTimeout);
      // Gemini alignment scores (keyed by submission id). Non-fatal: an empty
      // map falls back to the rule-based score so the roster still renders.
      Map<String, AiAlignmentScore> aiScores = const {};
      try {
        aiScores =
            await _aiScores.loadBySubmission().timeout(slateLoadTimeout);
      } catch (_) {
        aiScores = const {};
      }
      // Candidate-profile photo fallback (keyed by submission id). Non-fatal:
      // an empty map just means candidates without an uploaded headshot show
      // their initials, as before.
      Map<String, String> photoFallback = const {};
      try {
        photoFallback = await _service
            .getEndorsementPhotoFallback()
            .timeout(slateLoadTimeout);
      } catch (_) {
        photoFallback = const {};
      }
      final entries = submissions
          .map((s) => CandidateEntry.build(form, s,
              aiAlignment: aiScores[s.id],
              fallbackPhotoUrl: photoFallback[s.id]))
          .toList();
      // Race identity + the unvetted-Democrat field, non-fatal (see the
      // field comments above). Until 010/011 are applied in Postgres this
      // throws, the flag flips, and the board renders exactly as before
      // plus an honest "Race field unavailable" line per expansion.
      _raceLoadFailed = false;
      try {
        _raceInfo =
            await _races.loadApplicantRaces().timeout(slateLoadTimeout);
        _raceField = await _races.loadRaceField().timeout(slateLoadTimeout);
      } catch (e) {
        debugPrint('SlateController race views load failed: $e');
        _raceInfo = const {};
        _raceField = const {};
        _raceLoadFailed = true;
      }
      _raceDataLoaded = true;
      // Applicant counts per race, over the DEDUPED board entries (not the
      // raw view rows): the Arellanes duplicate submission must not turn
      // House 121 into a fake contest.
      final counts = <String, int>{};
      for (final e in entries) {
        final k = _raceInfo[e.id]?.raceKey;
        if (k != null) counts[k] = (counts[k] ?? 0) + 1;
      }
      _raceApplicantCounts = counts;
      _form = form;
      _all = entries;
      // Drop selections that no longer exist.
      _selected.removeWhere((id) => !entries.any((e) => e.id == id));
      _loading = false;
      notifyListeners();
    } catch (e) {
      // The error card prints this verbatim, so a raw
      // "TimeoutException after 0:00:25.000000: Future not completed" would
      // be what an exec reads when the venue wifi drops.
      _error = e is TimeoutException
          ? 'The slate took too long to load. Check your connection and tap '
              'Retry.'
          : '$e';
      _loading = false;
      notifyListeners();
    }
  }

  // ==================== derived ====================

  SlateStats get stats => SlateStats(_all);

  /// The roster after filter + search, then sorted.
  List<CandidateEntry> get visible {
    Iterable<CandidateEntry> xs = _all;

    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase();
      // displayNameFor, not e.name: it falls back through the race view's
      // coalesced name, so the one nameless submission (Hope Tinker,
      // 587c32d7) is findable by the name the board actually renders.
      xs = xs.where((e) =>
          displayNameFor(e).toLowerCase().contains(q) ||
          (e.model.office?.toLowerCase().contains(q) ?? false) ||
          (e.model.district?.toLowerCase().contains(q) ?? false));
    }
    if (_officeFilter.isNotEmpty) {
      xs = xs.where((e) => _officeFilter.contains(e.officeLevel));
    }
    if (_districtFilter.trim().isNotEmpty) {
      final d = _districtFilter.toLowerCase().trim();
      xs = xs.where((e) => (e.model.district ?? '').toLowerCase().contains(d));
    }
    if (_youngDemOnly) xs = xs.where((e) => e.isYoungDem);
    if (_flagNonDem) xs = xs.where((e) => e.flags.nonDemHistory);
    if (_flagSelfFunded) xs = xs.where((e) => e.flags.selfFundedMajority);
    if (_flagMissingDocs) xs = xs.where((e) => e.flags.missingDocs);
    if (_flagUncertified) xs = xs.where((e) => e.flags.uncertified);

    // Alignment range: unscored entries pass only when _includeUnscored and
    // the range still spans the full 0..100 window (a narrowed range implies
    // the user wants scored candidates).
    xs = xs.where((e) {
      final p = e.alignmentPct;
      if (p == null) {
        return _includeUnscored &&
            _alignmentRange.start <= 0 &&
            _alignmentRange.end >= 100;
      }
      return p >= _alignmentRange.start && p <= _alignmentRange.end;
    });

    final list = xs.toList();
    _applySort(list);
    return list;
  }

  void _applySort(List<CandidateEntry> list) {
    int byName(CandidateEntry a, CandidateEntry b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());

    switch (_sort) {
      case SlateSort.alignmentDesc:
        list.sort((a, b) {
          final pa = a.alignmentPct ?? -1;
          final pb = b.alignmentPct ?? -1;
          final cmp = pb.compareTo(pa);
          return cmp != 0 ? cmp : byName(a, b);
        });
        break;
      case SlateSort.name:
        list.sort(byName);
        break;
      case SlateSort.office:
        list.sort((a, b) {
          final cmp = a.officeLevel.index.compareTo(b.officeLevel.index);
          return cmp != 0 ? cmp : byName(a, b);
        });
        break;
      case SlateSort.race:
        // Same ordering as the ballot's VoteSort.race: office rank (US
        // House, State Senate, State House, keyless rows last), then numeric
        // district, then name. View-resolved race identity first; the
        // client-side parseDistrictRef fallback covers rows the view does
        // not (it is presentation-only, so a fallback mismatch can at worst
        // misplace a row in a sort, never mis-cluster it).
        int rank(CandidateEntry e) => switch (_officeCodeFor(e)) {
              'US_HOUSE' => 0,
              'MO_SEN' => 1,
              'MO_HOUSE' => 2,
              _ => 3,
            };
        list.sort((a, b) {
          final r = rank(a).compareTo(rank(b));
          if (r != 0) return r;
          final d = _districtNumFor(a).compareTo(_districtNumFor(b));
          return d != 0 ? d : byName(a, b);
        });
        break;
      case SlateSort.newest:
        list.sort((a, b) =>
            b.submission.createdAt.compareTo(a.submission.createdAt));
        break;
      case SlateSort.selfFunded:
        list.sort((a, b) {
          final sa = a.model.selfFundedPct ?? -1;
          final sb = b.model.selfFundedPct ?? -1;
          final cmp = sb.compareTo(sa);
          return cmp != 0 ? cmp : byName(a, b);
        });
        break;
      case SlateSort.supportCount:
        list.sort((a, b) {
          final cmp = b.stanceTally.support.compareTo(a.stanceTally.support);
          return cmp != 0 ? cmp : byName(a, b);
        });
        break;
    }
  }

  /// Office code for the race sort: the view's resolved code, falling back
  /// to the client district parse for rows the view does not cover.
  String? _officeCodeFor(CandidateEntry e) {
    final code = _raceInfo[e.id]?.officeCode;
    if (code != null) return code;
    final ref =
        parseDistrictRef(office: e.model.office, district: e.model.district);
    return switch (ref?.mapOffice) {
      'US Congress' => 'US_HOUSE',
      'State Senate' => 'MO_SEN',
      'State House' => 'MO_HOUSE',
      _ => null,
    };
  }

  int _districtNumFor(CandidateEntry e) {
    final n = _raceInfo[e.id]?.districtNum;
    if (n != null) return n;
    final ref =
        parseDistrictRef(office: e.model.office, district: e.model.district);
    return int.tryParse(ref?.districtNum ?? '') ?? 1 << 20;
  }

  // ==================== mutators ====================

  void setSearch(String v) {
    if (_search == v) return;
    _search = v;
    notifyListeners();
  }

  void setSort(SlateSort v) {
    if (_sort == v) return;
    _sort = v;
    notifyListeners();
  }

  void toggleOffice(OfficeLevel level) {
    if (!_officeFilter.remove(level)) _officeFilter.add(level);
    notifyListeners();
  }

  void setDistrictFilter(String v) {
    if (_districtFilter == v) return;
    _districtFilter = v;
    notifyListeners();
  }

  void setAlignmentRange(RangeValuesLite range) {
    _alignmentRange = range;
    notifyListeners();
  }

  void setIncludeUnscored(bool v) {
    _includeUnscored = v;
    notifyListeners();
  }

  void setYoungDemOnly(bool v) {
    _youngDemOnly = v;
    notifyListeners();
  }

  void setFlagNonDem(bool v) {
    _flagNonDem = v;
    notifyListeners();
  }

  void setFlagSelfFunded(bool v) {
    _flagSelfFunded = v;
    notifyListeners();
  }

  void setFlagMissingDocs(bool v) {
    _flagMissingDocs = v;
    notifyListeners();
  }

  void setFlagUncertified(bool v) {
    _flagUncertified = v;
    notifyListeners();
  }

  void clearFilters() {
    _search = '';
    _officeFilter.clear();
    _districtFilter = '';
    _alignmentRange = const RangeValuesLite(0, 100);
    _includeUnscored = true;
    _youngDemOnly = false;
    _flagNonDem = false;
    _flagSelfFunded = false;
    _flagMissingDocs = false;
    _flagUncertified = false;
    notifyListeners();
  }

  /// Jump the roster to a specific alignment window (used by chart drill-down).
  void focusAlignmentRange(double start, double end) {
    _alignmentRange = RangeValuesLite(start, end);
    _includeUnscored = false;
    notifyListeners();
  }

  // ----- selection -----

  void toggleSelected(String id) {
    if (!_selected.remove(id)) _selected.add(id);
    notifyListeners();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }
}

/// A tiny value type mirroring Flutter's RangeValues so the controller stays
/// free of the material import.
@immutable
class RangeValuesLite {
  final double start;
  final double end;
  const RangeValuesLite(this.start, this.end);

  @override
  bool operator ==(Object other) =>
      other is RangeValuesLite && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}
