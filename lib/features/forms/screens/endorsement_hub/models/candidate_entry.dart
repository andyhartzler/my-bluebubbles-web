import '../../../models/form_schema.dart';
import '../../../models/form_submission.dart';
import '../../../models/submission_review_model.dart';

/// Coarse office-level bucket used by roster filters and analytics strips.
///
/// Derived from the endorsement form's `office_sought` value (falling back to a
/// keyword scan of the resolved office label so custom/"other" offices still
/// land somewhere sensible).
enum OfficeLevel {
  federal('Federal'),
  statewide('Statewide'),
  stateLegislative('State Legislative'),
  local('Local'),
  judicial('Judicial'),
  other('Other');

  const OfficeLevel(this.label);
  final String label;

  static OfficeLevel fromRaw(String? officeSoughtValue, String? resolvedLabel) {
    final v = (officeSoughtValue ?? '').toLowerCase().trim();
    switch (v) {
      case 'us_house':
      case 'us_senate':
        return OfficeLevel.federal;
      case 'statewide':
        return OfficeLevel.statewide;
      case 'state_senate':
      case 'state_house':
        return OfficeLevel.stateLegislative;
      case 'county':
      case 'municipal':
      case 'school_board':
        return OfficeLevel.local;
      case 'judicial':
        return OfficeLevel.judicial;
    }
    // Fallback: keyword scan of the resolved label.
    final l = (resolvedLabel ?? '').toLowerCase();
    if (l.isEmpty) return OfficeLevel.other;
    if (l.contains('congress') ||
        l.contains('u.s.') ||
        l.contains('us house') ||
        l.contains('us senate') ||
        l.contains('president')) {
      return OfficeLevel.federal;
    }
    if (l.contains('governor') ||
        l.contains('secretary of state') ||
        l.contains('attorney general') ||
        l.contains('treasurer') ||
        l.contains('auditor') ||
        l.contains('lieutenant')) {
      return OfficeLevel.statewide;
    }
    if (l.contains('state rep') ||
        l.contains('state house') ||
        l.contains('state senate') ||
        l.contains('assembly') ||
        l.contains('legislat')) {
      return OfficeLevel.stateLegislative;
    }
    if (l.contains('judge') || l.contains('judicial') || l.contains('court')) {
      return OfficeLevel.judicial;
    }
    if (l.contains('council') ||
        l.contains('mayor') ||
        l.contains('county') ||
        l.contains('school') ||
        l.contains('alderman') ||
        l.contains('municipal') ||
        l.contains('city')) {
      return OfficeLevel.local;
    }
    return OfficeLevel.other;
  }
}

/// The at-a-glance risk / completeness flags surfaced as chips on the roster.
class CandidateFlags {
  /// Party history is anything other than "always a Democrat".
  final bool nonDemHistory;

  /// Self-funded share of money raised is above 50%.
  final bool selfFundedMajority;

  final bool missingHeadshot;
  final bool missingBudget;
  final bool missingSignature;

  /// Did not certify the questionnaire.
  final bool uncertified;

  /// No committee-alignment score could be computed (nothing scored answered).
  final bool unscored;

  const CandidateFlags({
    required this.nonDemHistory,
    required this.selfFundedMajority,
    required this.missingHeadshot,
    required this.missingBudget,
    required this.missingSignature,
    required this.uncertified,
    required this.unscored,
  });

  /// True when any document / certification piece is missing.
  bool get missingDocs => missingHeadshot || missingBudget || missingSignature;

  bool get any =>
      nonDemHistory ||
      selfFundedMajority ||
      missingDocs ||
      uncertified ||
      unscored;
}

/// One candidate in the slate: the raw [FormSubmission] plus a prebuilt
/// [SubmissionReviewModel] and derived flags / office level.
///
/// Built once per submission by the [SlateController] so every tab (roster,
/// compare, analytics, decisions) reads the same computed values without
/// re-parsing.
class CandidateEntry {
  final FormSubmission submission;
  final SubmissionReviewModel model;
  final OfficeLevel officeLevel;
  final CandidateFlags flags;

  const CandidateEntry({
    required this.submission,
    required this.model,
    required this.officeLevel,
    required this.flags,
  });

  factory CandidateEntry.build(FormSchema form, FormSubmission submission) {
    final model = SubmissionReviewModel.from(form, submission);
    final data = submission.data;

    final officeSoughtRaw = data['office_sought']?.toString();
    final officeLevel = OfficeLevel.fromRaw(officeSoughtRaw, model.office);

    final selfPct = model.selfFundedPct;
    final flags = CandidateFlags(
      nonDemHistory: model.nonDemHistory,
      selfFundedMajority: selfPct != null && selfPct > 50,
      missingHeadshot: model.headshot == null,
      missingBudget: model.budgetFile == null,
      missingSignature:
          model.signatureUrl == null || model.signatureUrl!.trim().isEmpty,
      uncertified: !model.certified,
      unscored: model.alignmentPct == null,
    );

    return CandidateEntry(
      submission: submission,
      model: model,
      officeLevel: officeLevel,
      flags: flags,
    );
  }

  String get id => submission.id;
  String get name => model.candidateName;
  double? get alignmentPct => model.alignmentPct;
  bool get isYoungDem => model.track == 'Young Dem';

  /// "Office · District" glance line (omits empty parts).
  String get officeLine {
    final parts = <String>[];
    if (model.office != null && model.office!.isNotEmpty) parts.add(model.office!);
    if (model.district != null && model.district!.isNotEmpty) {
      parts.add('District ${model.district}');
    }
    return parts.join(' · ');
  }

  ({int support, int oppose, int qualified, int other}) get stanceTally =>
      model.stanceTally;
}
