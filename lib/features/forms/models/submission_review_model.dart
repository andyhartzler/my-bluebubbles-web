import 'form_field_config.dart';
import 'form_schema.dart';
import 'form_submission.dart';

/// How a candidate answered a support/oppose-style policy question.
enum Stance { support, oppose, qualified, unsure, neutral }

/// A normalized uploaded file (headshot, budget, generic attachment).
class ReviewFile {
  final String url;
  final String name;
  final String? mimeType;
  final int? sizeBytes;

  const ReviewFile({
    required this.url,
    required this.name,
    this.mimeType,
    this.sizeBytes,
  });

  bool get isImage {
    final m = mimeType ?? '';
    if (m.startsWith('image/')) return true;
    final n = name.toLowerCase();
    return n.endsWith('.png') ||
        n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.gif') ||
        n.endsWith('.webp');
  }

  bool get isPdf =>
      (mimeType ?? '') == 'application/pdf' || name.toLowerCase().endsWith('.pdf');

  /// Human-readable size, e.g. "1.7 MB". Null when size is unknown.
  String? get prettySize {
    final b = sizeBytes;
    if (b == null || b <= 0) return null;
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Parse the polymorphic file value moydforms stores: a list of
  /// {url,name,type,size} objects, a single such object, or a bare url string.
  static List<ReviewFile> parse(dynamic value) {
    final out = <ReviewFile>[];
    void addMap(Map raw) {
      final url = raw['url']?.toString() ?? '';
      if (url.isEmpty) return;
      final rawName = raw['name']?.toString();
      out.add(ReviewFile(
        url: url,
        name: (rawName != null && rawName.isNotEmpty)
            ? rawName
            : url.split('/').last,
        mimeType: raw['type']?.toString(),
        sizeBytes: (raw['size'] is num) ? (raw['size'] as num).toInt() : null,
      ));
    }

    if (value is List) {
      for (final v in value) {
        if (v is Map) {
          addMap(v);
        } else if (v is String && v.isNotEmpty) {
          out.add(ReviewFile(url: v, name: v.split('/').last));
        }
      }
    } else if (value is Map) {
      addMap(value);
    } else if (value is String && value.isNotEmpty) {
      out.add(ReviewFile(url: value, name: value.split('/').last));
    }
    return out;
  }
}

/// One reference (stored under flat ref_N_* keys, not schema field ids).
class ReferenceEntry {
  final int index;
  final String? name;
  final String? relationship;
  final String? phone;
  final String? email;

  const ReferenceEntry({
    required this.index,
    this.name,
    this.relationship,
    this.phone,
    this.email,
  });

  bool get isEmpty =>
      (name == null || name!.isEmpty) &&
      (relationship == null || relationship!.isEmpty) &&
      (phone == null || phone!.isEmpty) &&
      (email == null || email!.isEmpty);

  /// Ordered (label,value) pairs, skipping empties — for display.
  List<MapEntry<String, String>> get fields {
    final f = <MapEntry<String, String>>[];
    void add(String label, String? v) {
      if (v != null && v.trim().isNotEmpty) f.add(MapEntry(label, v.trim()));
    }

    add('Name', name);
    add('Relationship', relationship);
    add('Phone', phone);
    add('Email', email);
    return f;
  }
}

/// Committee-alignment score for one submission, computed from the schema's
/// `scoring` config (`schema.scoring.fields`: fieldId -> {answerValue: weight}).
///
/// Weights are 0..1 (1 = fully aligned). Only scored questions the candidate
/// answered with a *mapped* value count toward [pct]; a question answered with
/// a value absent from its map (e.g. "unsure") is excluded from the score
/// (never counted as 0). Questions absent from the map (e.g. pos_housing) are
/// ignored entirely.
class AlignmentScore {
  /// Rounded 0..100 alignment percentage, or null when no scored question was
  /// answered with a mapped value.
  final double? pct;

  /// Scored questions answered with a mapped value (the [pct] denominator).
  final int scoredAnswered;

  /// Scored questions the candidate answered at all (mapped or not).
  final int scoredTotal;

  /// Total scored questions defined in the map (draft weight coverage).
  final int mapTotal;

  /// Breakdown across the [scoredAnswered] set.
  final int strong; // weight >= 0.75
  final int partial; // 0 < weight < 0.75
  final int oppose; // weight == 0

  const AlignmentScore({
    required this.pct,
    required this.scoredAnswered,
    required this.scoredTotal,
    required this.mapTotal,
    required this.strong,
    required this.partial,
    required this.oppose,
  });

  bool get hasScore => pct != null;

  /// "11 strong / 2 partial / 0 oppose".
  String get breakdownLine =>
      '$strong strong / $partial partial / $oppose oppose';

  /// Parse [scoring] + [data] into a score. Returns null when the form carries
  /// no scoring config.
  static AlignmentScore? compute(
    Map<String, dynamic>? scoring,
    Map<String, dynamic> data,
  ) {
    if (scoring == null) return null;
    final fieldsMap = scoring['fields'];
    if (fieldsMap is! Map) return null;

    double weightSum = 0;
    int answeredMapped = 0;
    int answeredAny = 0;
    int strong = 0, partial = 0, oppose = 0;

    fieldsMap.forEach((fieldId, weights) {
      if (weights is! Map) return;
      final raw = data[fieldId.toString()];
      if (SubmissionReviewModel._isEmptyValue(raw)) {
        return; // question not answered
      }
      answeredAny++;
      final w = weights[raw.toString()];
      if (w is! num) return; // answer value not in the map -> excluded
      final weight = w.toDouble();
      weightSum += weight;
      answeredMapped++;
      if (weight >= 0.75) {
        strong++;
      } else if (weight > 0) {
        partial++;
      } else {
        oppose++;
      }
    });

    final pct = answeredMapped > 0
        ? (weightSum / answeredMapped * 100).round().toDouble()
        : null;

    return AlignmentScore(
      pct: pct,
      scoredAnswered: answeredMapped,
      scoredTotal: answeredAny,
      mapTotal: fieldsMap.length,
      strong: strong,
      partial: partial,
      oppose: oppose,
    );
  }
}

/// One issue inside a [AiAlignmentScore]: Gemini's 0..100 judgment of the
/// candidate's alignment on a single policy question, with a short rationale.
class AiIssueScore {
  final String id;
  final String label;
  final int score; // 0..100
  final String stance; // aligned / mostly_aligned / mixed / misaligned / unclear
  final String rationale;

  const AiIssueScore({
    required this.id,
    required this.label,
    required this.score,
    required this.stance,
    required this.rationale,
  });

  static AiIssueScore? fromJson(dynamic j) {
    if (j is! Map) return null;
    final rawScore = j['score'];
    final s = rawScore is num
        ? rawScore.round()
        : int.tryParse('${rawScore ?? ''}') ?? 0;
    return AiIssueScore(
      id: (j['id'] ?? '').toString(),
      label: (j['label'] ?? '').toString(),
      score: s.clamp(0, 100),
      stance: (j['stance'] ?? '').toString(),
      rationale: (j['rationale'] ?? '').toString(),
    );
  }
}

/// One core-value break inside an [AiAlignmentScore]: the issue, the position
/// the candidate took, their own words, and why it disqualifies.
class AiDisqualifier {
  final String issueId;
  final String position;
  final String quote;
  final String whyDisqualifying;

  const AiDisqualifier({
    required this.issueId,
    required this.position,
    required this.quote,
    required this.whyDisqualifying,
  });

  static AiDisqualifier? fromJson(dynamic j) {
    if (j is! Map) return null;
    return AiDisqualifier(
      issueId: (j['issue_id'] ?? '').toString(),
      position: (j['position'] ?? '').toString(),
      quote: (j['quote'] ?? '').toString(),
      whyDisqualifying: (j['why_disqualifying'] ?? '').toString(),
    );
  }
}

/// One itemized deduction inside an [AiAlignmentScore]: which issue cost
/// points, how many, and the candidate's own words that cost them.
class AiDeduction {
  final String issueId;
  final String label;
  final int pointsLost;
  final String quote;
  final String explanation;

  const AiDeduction({
    required this.issueId,
    required this.label,
    required this.pointsLost,
    required this.quote,
    required this.explanation,
  });

  static AiDeduction? fromJson(dynamic j) {
    if (j is! Map) return null;
    final rawPoints = j['points_lost'];
    final p = rawPoints is num
        ? rawPoints.round()
        : int.tryParse('${rawPoints ?? ''}') ?? 0;
    return AiDeduction(
      issueId: (j['issue_id'] ?? '').toString(),
      label: (j['label'] ?? '').toString(),
      pointsLost: p.clamp(0, 100),
      quote: (j['quote'] ?? '').toString(),
      explanation: (j['explanation'] ?? '').toString(),
    );
  }
}

/// A Gemini-judged alignment score for one submission, loaded from
/// `public.endorsement_ai_scores`. Gemini reads the candidate's FULL answers
/// (selected option AND written explanation) against the MOYD platform through
/// MOYD's progressive lens; positions that break core platform values mark the
/// submission [disqualified] (score capped at 25) with each break itemized in
/// [disqualifiers]. When present it supersedes the rigid rule-based
/// [AlignmentScore] as the alignment number shown across the endorsement hub.
class AiAlignmentScore {
  /// Overall 0..100 holistic alignment.
  final int overallScore;

  /// Overall rationale (2-4 sentences).
  final String rationale;

  /// Per-issue breakdown.
  final List<AiIssueScore> perIssue;

  /// True when any answer broke a core MOYD value; the overall score is
  /// hard-capped at 25 by the scoring pipeline.
  final bool disqualified;

  /// The itemized core-value breaks (empty when [disqualified] is false).
  final List<AiDisqualifier> disqualifiers;

  /// Itemized "where the points went" deductions for sub-100 scores. Empty
  /// for 100-scorers and for rows scored before the deductions column
  /// existed — every consumer keys off [deductions.isNotEmpty].
  final List<AiDeduction> deductions;

  final String? model;
  final DateTime? scoredAt;

  const AiAlignmentScore({
    required this.overallScore,
    required this.rationale,
    required this.perIssue,
    this.disqualified = false,
    this.disqualifiers = const [],
    this.deductions = const [],
    this.model,
    this.scoredAt,
  });

  double get pct => overallScore.toDouble();

  /// Build from a `endorsement_ai_scores` row.
  static AiAlignmentScore? fromRow(Map<String, dynamic> row) {
    final raw = row['overall_score'];
    if (raw == null) return null;
    final overall =
        raw is num ? raw.round() : int.tryParse(raw.toString()) ?? 0;

    final issues = <AiIssueScore>[];
    final pi = row['per_issue'];
    if (pi is List) {
      for (final e in pi) {
        final parsed = AiIssueScore.fromJson(e);
        if (parsed != null) issues.add(parsed);
      }
    }

    DateTime? scoredAt;
    final sa = row['scored_at'];
    if (sa != null) scoredAt = DateTime.tryParse(sa.toString());

    final dqs = <AiDisqualifier>[];
    final rawDqs = row['disqualifiers'];
    if (rawDqs is List) {
      for (final e in rawDqs) {
        final parsed = AiDisqualifier.fromJson(e);
        if (parsed != null) dqs.add(parsed);
      }
    }

    final deds = <AiDeduction>[];
    final rawDeds = row['deductions'];
    if (rawDeds is List) {
      for (final e in rawDeds) {
        final parsed = AiDeduction.fromJson(e);
        if (parsed != null) deds.add(parsed);
      }
    }

    return AiAlignmentScore(
      overallScore: overall.clamp(0, 100),
      rationale: (row['rationale'] ?? '').toString(),
      perIssue: issues,
      disqualified: row['disqualified'] == true || dqs.isNotEmpty,
      disqualifiers: dqs,
      deductions: deds,
      model: row['model']?.toString(),
      scoredAt: scoredAt,
    );
  }
}

/// A single stance question inside a policy-positions grid.
class PolicyPosition {
  final String id;
  final String question; // field label
  final String answerLabel; // resolved option label
  final Stance stance;
  final String? explanation;

  const PolicyPosition({
    required this.id,
    required this.question,
    required this.answerLabel,
    required this.stance,
    this.explanation,
  });
}

/// A normal (non-policy) answered field, with its value already resolved to
/// display text where that makes sense (option labels, joined multiselects).
class ReviewAnswer {
  final FormFieldConfig field;
  final dynamic rawValue;
  final String displayValue;

  const ReviewAnswer({
    required this.field,
    required this.rawValue,
    required this.displayValue,
  });

  String get type => field.type;
  String get label => field.label;
}

/// A section of the form (delimited by section_header fields), holding either
/// normal answers, a policy grid, or both.
class ReviewSection {
  final String id;
  final String title;
  final List<ReviewAnswer> answers;
  final List<PolicyPosition> policyPositions;

  const ReviewSection({
    required this.id,
    required this.title,
    required this.answers,
    required this.policyPositions,
  });

  bool get isPolicyGrid => policyPositions.isNotEmpty;
  bool get isEmpty => answers.isEmpty && policyPositions.isEmpty;
}

/// The full view-model for the submission-review screen. Generic-first:
/// sectioning, visibility, option-label resolution and file normalization
/// apply to every form. The curated "candidate" getters degrade to null when
/// a form lacks those field ids, so nothing is hardcoded to one form.
class SubmissionReviewModel {
  final List<ReviewSection> sections;

  // Curated glance/hero fields (null when the form has no such field).
  final String candidateName;
  final String? preferredName;
  final String? pronouns;
  final String? email;
  final String? phone;
  final String? office; // resolved label
  final String? district;
  final String? ideology; // resolved label
  final String? partyHistory; // resolved label
  final bool nonDemHistory;
  final num? raisedToDate;
  final num? selfFundedPct;
  final String? track; // "Young Dem" / "Partner Candidate"
  final String? topPriority;

  // Documents.
  final ReviewFile? headshot;
  final ReviewFile? budgetFile;
  final String? signatureUrl;
  final bool certified;

  /// Any other file/signature answers not already hoisted into the typed
  /// document slots above (keeps generic forms' uploads visible).
  final List<ReviewAnswer> documentAnswers;

  final List<ReferenceEntry> references;

  /// Rule-based committee-alignment score, or null when the form has no scoring
  /// config. Kept for reference / fallback; superseded by [aiAlignment] for
  /// display when a Gemini score exists.
  final AlignmentScore? alignment;

  /// Gemini-judged alignment score (from `public.endorsement_ai_scores`), or
  /// null when the submission has not been AI-scored. When present it is the
  /// authoritative alignment number.
  final AiAlignmentScore? aiAlignment;

  const SubmissionReviewModel({
    required this.sections,
    required this.candidateName,
    this.preferredName,
    this.pronouns,
    this.email,
    this.phone,
    this.office,
    this.district,
    this.ideology,
    this.partyHistory,
    this.nonDemHistory = false,
    this.raisedToDate,
    this.selfFundedPct,
    this.track,
    this.topPriority,
    this.headshot,
    this.budgetFile,
    this.signatureUrl,
    this.certified = false,
    this.documentAnswers = const [],
    this.references = const [],
    this.alignment,
    this.aiAlignment,
  });

  /// All policy positions across every section, flattened.
  List<PolicyPosition> get allPolicyPositions =>
      sections.expand((s) => s.policyPositions).toList();

  /// Rounded 0..100 alignment percentage shown across the endorsement hub.
  /// Prefers the Gemini ([aiAlignment]) score; falls back to the rule-based
  /// [AlignmentScore] when the submission has not been AI-scored yet. Null when
  /// neither exists.
  double? get alignmentPct => aiAlignment?.pct ?? alignment?.pct;

  /// The rule-based score alone (for labeled side-by-side display), or null.
  double? get ruleAlignmentPct => alignment?.pct;

  /// True when [alignmentPct] comes from Gemini rather than the rule engine.
  bool get isAiScored => aiAlignment != null;

  /// Scored questions answered with a mapped value (the [alignmentPct]
  /// denominator).
  int get scoredAnswered => alignment?.scoredAnswered ?? 0;

  /// Scored questions the candidate answered at all (mapped or not).
  int get scoredTotal => alignment?.scoredTotal ?? 0;

  /// True when there is anything to show in the DocumentsCard.
  bool get hasDocuments =>
      headshot != null ||
      budgetFile != null ||
      (signatureUrl != null && signatureUrl!.isNotEmpty) ||
      documentAnswers.isNotEmpty;

  /// support/oppose/qualified tallies across all policy positions.
  ({int support, int oppose, int qualified, int other}) get stanceTally {
    var s = 0, o = 0, q = 0, other = 0;
    for (final p in allPolicyPositions) {
      switch (p.stance) {
        case Stance.support:
          s++;
          break;
        case Stance.oppose:
          o++;
          break;
        case Stance.qualified:
          q++;
          break;
        case Stance.unsure:
        case Stance.neutral:
          other++;
          break;
      }
    }
    return (support: s, oppose: o, qualified: q, other: other);
  }

  // ==================== construction ====================

  static const Set<String> _displayOnly = {'section_header', 'reference_block'};
  static const Set<String> _singleSelectTypes = {
    'radio',
    'dropdown',
    'choice_chips',
  };

  /// File-ish types that are surfaced in the DocumentsCard rather than as
  /// inline section rows.
  static const Set<String> _documentTypes = {
    'file_upload',
    'file_picker',
    'image_picker',
    'signature_pad',
  };

  /// Field ids whose values are surfaced elsewhere (hero/documents) and must
  /// not also render as an ordinary section row.
  static const Set<String> _hoistedIds = {
    'headshot',
    'budget_file',
    'signature',
    'certify',
  };

  static bool _isEmptyValue(dynamic v) {
    if (v == null) return true;
    if (v is String) return v.trim().isEmpty;
    if (v is Iterable) return v.isEmpty;
    if (v is Map) return v.isEmpty;
    return false;
  }

  /// Map a raw stored value to its display string using the field's options
  /// (single or multi select) and light formatting for dates/numbers.
  static String resolveDisplay(FormFieldConfig field, dynamic value) {
    if (value == null) return '';

    String optLabel(String v) {
      final opts = field.options;
      if (opts != null) {
        for (final o in opts) {
          if (o.value == v) return o.label;
        }
      }
      return v;
    }

    if (value is List) {
      return value
          .map((e) => optLabel(e.toString()))
          .where((s) => s.isNotEmpty)
          .join(', ');
    }

    if (_singleSelectTypes.contains(field.type)) {
      return optLabel(value.toString());
    }

    if (field.type == 'date_picker') {
      final d = DateTime.tryParse(value.toString());
      if (d != null) return '${d.month}/${d.day}/${d.year}';
    }

    return value.toString();
  }

  /// Classify a single-select value into a support/oppose-style stance.
  /// Convention-based (yes*/no/qualified/unsure), not form-specific.
  static Stance stanceFor(String value) {
    final v = value.toLowerCase().trim();
    if (v.isEmpty) return Stance.neutral;
    if (v == 'unsure' ||
        v.startsWith('prefer_not') ||
        v == 'didnt_vote' ||
        v == 'no_disclose') {
      return Stance.unsure;
    }
    if (v.startsWith('yes')) return Stance.support;
    if (v == 'no') return Stance.oppose;
    const qualified = {
      'qualified',
      'partial',
      'public_option',
      'public_option_only',
      'bg_only',
      'red_flag_only',
    };
    if (qualified.contains(v)) return Stance.qualified;
    return Stance.neutral;
  }

  static SubmissionReviewModel from(
    FormSchema form,
    FormSubmission submission, {
    AiAlignmentScore? aiAlignment,
  }) {
    final data = submission.data;
    final fields = form.schema.fields;

    // 1. Partition fields into sections at each section_header.
    //    Pre-walk once to know each section's fields, so we can detect policy
    //    grids and consume explanation fields.
    final List<_SectionBucket> buckets = [];
    _SectionBucket current = _SectionBucket(id: '_intro', title: '');
    buckets.add(current);
    for (final f in fields) {
      if (f.type == 'section_header') {
        current = _SectionBucket(id: f.id, title: f.label);
        buckets.add(current);
      } else {
        current.fields.add(f);
      }
    }

    final sections = <ReviewSection>[];
    final documentAnswers = <ReviewAnswer>[];
    for (final bucket in buckets) {
      // Which fields in this bucket are visible & non-empty?
      final visible = bucket.fields.where((f) {
        if (_displayOnly.contains(f.type)) return false;
        if (!f.isVisibleFor(data)) return false;
        return !_isEmptyValue(data[f.id]);
      }).toList();

      // Hoist file/signature answers into the DocumentsCard (unless already
      // captured in a typed slot), and drop hero/cert fields from rows.
      visible.removeWhere((f) {
        if (_documentTypes.contains(f.type)) {
          if (!_hoistedIds.contains(f.id)) {
            documentAnswers.add(ReviewAnswer(
              field: f,
              rawValue: data[f.id],
              displayValue: resolveDisplay(f, data[f.id]),
            ));
          }
          return true;
        }
        return _hoistedIds.contains(f.id);
      });

      // Policy-grid detection: >= 4 single-select fields in one section.
      final selects =
          visible.where((f) => _singleSelectTypes.contains(f.type)).toList();
      final isPolicyGrid = selects.length >= 4;

      final policyPositions = <PolicyPosition>[];
      final consumed = <String>{};

      if (isPolicyGrid) {
        for (final f in selects) {
          // Pair with an explanation field: <id>_explain or <id>_detail.
          String? explanation;
          for (final suffix in const ['_explain', '_detail']) {
            final key = '${f.id}$suffix';
            final ev = data[key];
            if (!_isEmptyValue(ev)) {
              explanation = ev.toString();
              consumed.add(key);
              break;
            }
            // Even when empty, consume so it never renders as a lone row.
            if (bucket.fields.any((bf) => bf.id == key)) consumed.add(key);
          }
          final raw = data[f.id];
          policyPositions.add(PolicyPosition(
            id: f.id,
            question: f.label,
            answerLabel: resolveDisplay(f, raw),
            stance: stanceFor(raw.toString()),
            explanation: explanation,
          ));
          consumed.add(f.id);
        }
      }

      final answers = <ReviewAnswer>[];
      for (final f in visible) {
        if (consumed.contains(f.id)) continue;
        final raw = data[f.id];
        answers.add(ReviewAnswer(
          field: f,
          rawValue: raw,
          displayValue: resolveDisplay(f, raw),
        ));
      }

      final section = ReviewSection(
        id: bucket.id,
        title: bucket.title,
        answers: answers,
        policyPositions: policyPositions,
      );
      if (!section.isEmpty) sections.add(section);
    }

    // 2. References (flat ref_N_* keys).
    final references = <ReferenceEntry>[];
    for (int i = 1; i <= 5; i++) {
      String? g(String key) {
        final v = data['ref_${i}_$key'];
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }

      final entry = ReferenceEntry(
        index: i,
        name: g('name'),
        relationship: g('relationship'),
        phone: g('phone'),
        email: g('email'),
      );
      if (!entry.isEmpty) references.add(entry);
    }

    // 3. Curated hero / glance fields.
    FormFieldConfig? fieldById(String id) {
      for (final f in fields) {
        if (f.id == id) return f;
      }
      return null;
    }

    String? str(String id) {
      final v = data[id];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    String? resolved(String id) {
      final f = fieldById(id);
      final v = data[id];
      if (f == null || _isEmptyValue(v)) return null;
      final r = resolveDisplay(f, v);
      return r.isEmpty ? null : r;
    }

    num? number(String id) {
      final v = data[id];
      if (v is num) return v;
      if (v is String) return num.tryParse(v);
      return null;
    }

    final name = str('full_name') ??
        str('name') ??
        (submission.submitterName?.isNotEmpty == true
            ? submission.submitterName
            : null) ??
        'Candidate';

    // Office: resolve the "other" free-text when office_sought == other.
    String? office = resolved('office_sought');
    if (office != null && (str('office_sought') == 'other')) {
      office = str('office_sought_other') ?? office;
    }

    final partyRaw = str('party_history');
    final nonDem = partyRaw != null && partyRaw != 'always_d';

    String? track;
    if (!_isEmptyValue(data['young_dem_agenda']) ||
        !_isEmptyValue(data['generational_case'])) {
      track = 'Young Dem';
    } else if (!_isEmptyValue(data['partner_young_staff']) ||
        !_isEmptyValue(data['partner_youth_agenda']) ||
        !_isEmptyValue(data['partner_succession'])) {
      track = 'Partner Candidate';
    }

    final headshots = ReviewFile.parse(data['headshot']);
    final budgets = ReviewFile.parse(data['budget_file']);

    final alignment = AlignmentScore.compute(form.schema.scoring, data);

    return SubmissionReviewModel(
      sections: sections,
      candidateName: name,
      preferredName: str('preferred_name'),
      pronouns: str('pronouns'),
      email: str('email') ?? submission.submitterEmail,
      phone: str('phone') ?? submission.submitterPhone,
      office: office,
      district: str('district_number'),
      ideology: resolved('ideology'),
      partyHistory: resolved('party_history'),
      nonDemHistory: nonDem,
      raisedToDate: number('raised_to_date'),
      selfFundedPct: number('self_funded_amount'),
      track: track,
      topPriority: str('pos_top_priority'),
      headshot: headshots.isNotEmpty ? headshots.first : null,
      budgetFile: budgets.isNotEmpty ? budgets.first : null,
      signatureUrl: str('signature'),
      certified: (str('certify') ?? '').toLowerCase() == 'yes',
      documentAnswers: documentAnswers,
      references: references,
      alignment: alignment,
      aiAlignment: aiAlignment,
    );
  }
}

class _SectionBucket {
  final String id;
  final String title;
  final List<FormFieldConfig> fields = [];
  _SectionBucket({required this.id, required this.title});
}
