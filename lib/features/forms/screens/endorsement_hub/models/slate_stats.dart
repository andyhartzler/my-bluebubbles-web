import '../../../models/submission_review_model.dart';
import 'candidate_entry.dart';

/// A per-question disagreement measure: how contested a policy question is
/// across the slate. Higher [disagreementIndex] = more split.
class BattlegroundQuestion {
  final String id;
  final String question;
  final Map<Stance, int> counts;
  final int answered;

  /// The stance the plurality of candidates hold.
  final Stance majorityStance;
  final int majorityCount;

  /// 1 - (largest stance share). 0 = unanimous, → 1 = evenly split.
  final double disagreementIndex;

  const BattlegroundQuestion({
    required this.id,
    required this.question,
    required this.counts,
    required this.answered,
    required this.majorityStance,
    required this.majorityCount,
    required this.disagreementIndex,
  });
}

/// One histogram bin of the alignment distribution.
class AlignmentBin {
  final int lo; // inclusive
  final int hi; // exclusive (except top bin, inclusive of 100)
  final List<CandidateEntry> entries;
  const AlignmentBin({required this.lo, required this.hi, required this.entries});

  int get count => entries.length;
  String get label => '$lo–${hi == 100 ? 100 : hi - 1}';
}

/// Pure, side-effect-free aggregate statistics over a slate of candidates.
///
/// Everything here is a static function of `List<CandidateEntry>` so the
/// analytics tab and the scoreboard can be rebuilt cheaply and tested in
/// isolation. All getters degrade gracefully on an empty slate.
class SlateStats {
  final List<CandidateEntry> entries;
  const SlateStats(this.entries);

  int get total => entries.length;

  List<double> get _scores => entries
      .map((e) => e.alignmentPct)
      .whereType<double>()
      .toList(growable: false);

  int get scoredCount => _scores.length;

  double? get meanAlignment {
    final s = _scores;
    if (s.isEmpty) return null;
    return s.reduce((a, b) => a + b) / s.length;
  }

  double? get medianAlignment => _median(_scores);

  /// Interquartile range (Q3 − Q1) of alignment scores; null when < 2 scored.
  double? get iqrAlignment {
    final s = [..._scores]..sort();
    if (s.length < 2) return null;
    final q1 = _quantile(s, 0.25);
    final q3 = _quantile(s, 0.75);
    if (q1 == null || q3 == null) return null;
    return q3 - q1;
  }

  double? get q1Alignment {
    final s = [..._scores]..sort();
    return _quantile(s, 0.25);
  }

  double? get q3Alignment {
    final s = [..._scores]..sort();
    return _quantile(s, 0.75);
  }

  /// Share (0..1) of candidates who certified the questionnaire.
  double? get certificationRate {
    if (entries.isEmpty) return null;
    final certified = entries.where((e) => e.model.certified).length;
    return certified / entries.length;
  }

  /// Share (0..1) of candidates with all three documents present.
  double? get docsCompleteRate {
    if (entries.isEmpty) return null;
    final complete = entries.where((e) => !e.flags.missingDocs).length;
    return complete / entries.length;
  }

  /// Candidates with no committee-alignment score.
  int get unscoredCount => entries.where((e) => e.flags.unscored).length;

  int get youngDemCount => entries.where((e) => e.isYoungDem).length;

  /// Alignment histogram in 10-point bins [0,10),[10,20),…,[90,100].
  List<AlignmentBin> alignmentHistogram({int binSize = 10}) {
    final bins = <AlignmentBin>[];
    for (int lo = 0; lo < 100; lo += binSize) {
      final hi = lo + binSize;
      final inBin = entries.where((e) {
        final p = e.alignmentPct;
        if (p == null) return false;
        if (hi >= 100) return p >= lo && p <= 100;
        return p >= lo && p < hi;
      }).toList();
      bins.add(AlignmentBin(lo: lo, hi: hi, entries: inBin));
    }
    return bins;
  }

  /// Per-question disagreement ranking, most contested first.
  List<BattlegroundQuestion> battlegroundQuestions() {
    final order = <String, int>{};
    final labels = <String, String>{};
    final counts = <String, Map<Stance, int>>{};

    for (final e in entries) {
      var idx = 0;
      for (final p in e.model.allPolicyPositions) {
        labels.putIfAbsent(p.id, () => p.question);
        order.putIfAbsent(p.id, () => idx);
        // Only count decisive stances toward disagreement.
        if (p.stance == Stance.support ||
            p.stance == Stance.qualified ||
            p.stance == Stance.oppose) {
          final m = counts.putIfAbsent(p.id, () => <Stance, int>{});
          m[p.stance] = (m[p.stance] ?? 0) + 1;
        }
        idx++;
      }
    }

    final out = <BattlegroundQuestion>[];
    counts.forEach((id, m) {
      final answered = m.values.fold<int>(0, (a, b) => a + b);
      if (answered == 0) return;
      Stance majStance = Stance.support;
      int majCount = -1;
      m.forEach((s, c) {
        if (c > majCount) {
          majCount = c;
          majStance = s;
        }
      });
      out.add(BattlegroundQuestion(
        id: id,
        question: labels[id] ?? id,
        counts: m,
        answered: answered,
        majorityStance: majStance,
        majorityCount: majCount,
        disagreementIndex: 1 - (majCount / answered),
      ));
    });

    out.sort((a, b) {
      final cmp = b.disagreementIndex.compareTo(a.disagreementIndex);
      if (cmp != 0) return cmp;
      return (order[a.id] ?? 1 << 30).compareTo(order[b.id] ?? 1 << 30);
    });
    return out;
  }

  /// Candidates who hold a minority (non-majority) stance on [q].
  List<CandidateEntry> minorityHolders(BattlegroundQuestion q) {
    return entries.where((e) {
      final p = e.model.allPolicyPositions
          .where((pp) => pp.id == q.id)
          .cast<PolicyPosition?>()
          .firstWhere((_) => true, orElse: () => null);
      if (p == null) return false;
      if (p.stance != Stance.support &&
          p.stance != Stance.qualified &&
          p.stance != Stance.oppose) {
        return false;
      }
      return p.stance != q.majorityStance;
    }).toList();
  }

  /// Candidates grouped by office level, each list preserving input order.
  Map<OfficeLevel, List<CandidateEntry>> byOfficeLevel() {
    final map = <OfficeLevel, List<CandidateEntry>>{};
    for (final e in entries) {
      map.putIfAbsent(e.officeLevel, () => []).add(e);
    }
    return map;
  }

  // ==================== helpers ====================

  static double? _median(List<double> xs) {
    if (xs.isEmpty) return null;
    final s = [...xs]..sort();
    final n = s.length;
    if (n.isOdd) return s[n ~/ 2];
    return (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
  }

  /// Linear-interpolation quantile over a pre-sorted list.
  static double? _quantile(List<double> sorted, double p) {
    if (sorted.isEmpty) return null;
    if (sorted.length == 1) return sorted.first;
    final pos = (sorted.length - 1) * p;
    final lo = pos.floor();
    final hi = pos.ceil();
    if (lo == hi) return sorted[lo];
    final frac = pos - lo;
    return sorted[lo] + (sorted[hi] - sorted[lo]) * frac;
  }
}
