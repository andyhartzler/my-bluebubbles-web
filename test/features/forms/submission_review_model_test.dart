import 'package:flutter_test/flutter_test.dart';
import 'package:bluebubbles/features/forms/models/form_field_config.dart';
import 'package:bluebubbles/features/forms/models/form_schema.dart';
import 'package:bluebubbles/features/forms/models/form_submission.dart';
import 'package:bluebubbles/features/forms/models/submission_review_model.dart';

FormSchema _schema(
  List<Map<String, dynamic>> fields, {
  Map<String, dynamic>? scoring,
}) {
  return FormSchema(
    id: 'form-1',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    title: 'Endorsement',
    formType: 'form',
    schema: FormSchemaData(
      fields: fields.map((f) => FormFieldConfig.fromJson(f)).toList(),
      scoring: scoring,
    ),
  );
}

/// A 3-question scoring config mirroring the real `schema.scoring.fields`
/// shape (weights 0..1, 1 = fully aligned).
const _scoring = {
  'note': 'DRAFT alignment weights, tune per committee.',
  'fields': {
    'pos_medicare_for_all': {
      'yes': 1,
      'public_option': 0.75,
      'public_option_only': 0.5,
      'no': 0,
    },
    'pos_right_to_work': {'yes': 1, 'qualified': 0.5, 'no': 0},
    'pos_aipac_money': {'no': 1, 'prefer_not_to_answer': 0.5, 'yes': 0},
  },
};

FormSubmission _submission(Map<String, dynamic> data) {
  return FormSubmission(
    id: 'sub-1',
    createdAt: DateTime(2026, 2, 2),
    formId: 'form-1',
    data: data,
  );
}

void main() {
  group('SubmissionReviewModel.from', () {
    test('partitions fields into sections at section_header', () {
      final schema = _schema([
        {'id': 'sec_a', 'type': 'section_header', 'label': 'A'},
        {'id': 'q1', 'type': 'short_answer', 'label': 'Q1'},
        {'id': 'sec_b', 'type': 'section_header', 'label': 'B'},
        {'id': 'q2', 'type': 'short_answer', 'label': 'Q2'},
      ]);
      final model = SubmissionReviewModel.from(
        schema,
        _submission({'q1': 'hi', 'q2': 'yo'}),
      );
      expect(model.sections.map((s) => s.title), ['A', 'B']);
    });

    test('drops empty-value fields and empty sections (no "No response")', () {
      final schema = _schema([
        {'id': 'sec_a', 'type': 'section_header', 'label': 'A'},
        {'id': 'q1', 'type': 'short_answer', 'label': 'Q1'},
        {'id': 'sec_b', 'type': 'section_header', 'label': 'B'},
        {'id': 'q2', 'type': 'short_answer', 'label': 'Q2'},
      ]);
      final model = SubmissionReviewModel.from(
        schema,
        _submission({'q1': 'hi', 'q2': ''}),
      );
      // Section B has only an empty value -> omitted entirely.
      expect(model.sections.map((s) => s.title), ['A']);
      expect(model.sections.first.answers.length, 1);
    });

    test('hides fields whose condition is false', () {
      final schema = _schema([
        {'id': 'sec', 'type': 'section_header', 'label': 'S'},
        {'id': 'office', 'type': 'dropdown', 'label': 'Office', 'options': [
          {'value': 'us_house', 'label': 'U.S. House'},
          {'value': 'state_house', 'label': 'MO House'},
        ]},
        {
          'id': 'fec_id',
          'type': 'text',
          'label': 'FEC ID',
          'condition': {'field': 'office', 'value': 'us_house'},
        },
      ]);
      final model = SubmissionReviewModel.from(
        schema,
        _submission({'office': 'state_house', 'fec_id': 'C123'}),
      );
      final ids = model.sections.first.answers.map((a) => a.field.id).toList();
      expect(ids, contains('office'));
      expect(ids, isNot(contains('fec_id')));
    });

    test('resolveDisplay maps codes to option labels', () {
      final schema = _schema([
        {'id': 'sec', 'type': 'section_header', 'label': 'S'},
        {'id': 'guns', 'type': 'radio', 'label': 'Guns', 'options': [
          {'value': 'yes_both', 'label': 'Yes, both'},
          {'value': 'no', 'label': 'No'},
        ]},
      ]);
      final model = SubmissionReviewModel.from(
        schema,
        _submission({'guns': 'yes_both'}),
      );
      expect(model.sections.first.answers.first.displayValue, 'Yes, both');
    });

    test('joins multiselect option labels', () {
      final schema = _schema([
        {'id': 'sec', 'type': 'section_header', 'label': 'S'},
        {'id': 'agenda', 'type': 'checkbox_group', 'label': 'Agenda', 'options': [
          {'value': 'healthcare', 'label': 'Healthcare'},
          {'value': 'labor', 'label': 'Labor'},
          {'value': 'voting', 'label': 'Voting'},
        ]},
      ]);
      final model = SubmissionReviewModel.from(
        schema,
        _submission({'agenda': ['healthcare', 'voting']}),
      );
      expect(model.sections.first.answers.first.displayValue, 'Healthcare, Voting');
    });

    test('detects a policy-positions group and pairs explanations', () {
      final schema = _schema([
        {'id': 'sec', 'type': 'section_header', 'label': 'Where you stand'},
        {'id': 'pos_a', 'type': 'radio', 'label': 'A?', 'options': [
          {'value': 'yes', 'label': 'Yes'},
          {'value': 'no', 'label': 'No'},
        ]},
        {'id': 'pos_a_explain', 'type': 'textarea', 'label': 'Explain'},
        {'id': 'pos_b', 'type': 'radio', 'label': 'B?', 'options': [
          {'value': 'yes', 'label': 'Yes'},
        ]},
        {'id': 'pos_c', 'type': 'radio', 'label': 'C?', 'options': [
          {'value': 'no', 'label': 'No'},
        ]},
        {'id': 'pos_d', 'type': 'radio', 'label': 'D?', 'options': [
          {'value': 'qualified', 'label': 'Depends'},
        ]},
      ]);
      final model = SubmissionReviewModel.from(
        schema,
        _submission({
          'pos_a': 'yes',
          'pos_a_explain': 'because',
          'pos_b': 'yes',
          'pos_c': 'no',
          'pos_d': 'qualified',
        }),
      );
      final section = model.sections.single;
      expect(section.isPolicyGrid, isTrue);
      expect(section.policyPositions.length, 4);
      // Explanation is consumed, not rendered as a standalone answer.
      expect(section.answers.where((a) => a.field.id == 'pos_a_explain'), isEmpty);
      final a = section.policyPositions.firstWhere((p) => p.id == 'pos_a');
      expect(a.explanation, 'because');
      expect(a.stance, Stance.support);
      expect(section.policyPositions.firstWhere((p) => p.id == 'pos_c').stance,
          Stance.oppose);
      expect(section.policyPositions.firstWhere((p) => p.id == 'pos_d').stance,
          Stance.qualified);
    });

    test('fewer than 4 selects is NOT a policy grid', () {
      final schema = _schema([
        {'id': 'sec', 'type': 'section_header', 'label': 'Identity'},
        {'id': 'ideology', 'type': 'radio', 'label': 'Ideology', 'options': [
          {'value': 'progressive', 'label': 'Progressive'},
        ]},
        {'id': 'party', 'type': 'radio', 'label': 'Party', 'options': [
          {'value': 'always_d', 'label': 'Always D'},
        ]},
      ]);
      final model = SubmissionReviewModel.from(
        schema,
        _submission({'ideology': 'progressive', 'party': 'always_d'}),
      );
      expect(model.sections.single.isPolicyGrid, isFalse);
      expect(model.sections.single.answers.length, 2);
    });

    test('groups ref_N_* keys into ReferenceEntry, dropping empties', () {
      final schema = _schema([
        {'id': 'sec', 'type': 'section_header', 'label': 'Refs'},
        {'id': 'references_block', 'type': 'reference_block', 'label': ''},
      ]);
      final model = SubmissionReviewModel.from(
        schema,
        _submission({
          'ref_1_name': 'Jane',
          'ref_1_relationship': 'Mentor',
          'ref_2_name': '',
        }),
      );
      expect(model.references.length, 1);
      expect(model.references.first.name, 'Jane');
      expect(model.references.first.fields.length, 2);
    });

    test('normalizes headshot/budget/signature into typed files', () {
      final schema = _schema([
        {'id': 'sec', 'type': 'section_header', 'label': 'Docs'},
        {'id': 'headshot', 'type': 'file_upload', 'label': 'Headshot'},
      ]);
      final model = SubmissionReviewModel.from(
        schema,
        _submission({
          'headshot': [
            {'url': 'https://x/img.jpeg', 'name': 'img.jpeg', 'type': 'image/jpeg', 'size': 2048},
          ],
          'budget_file': [
            {'url': 'https://x/plan.pdf', 'name': 'plan.pdf', 'type': 'application/pdf'},
          ],
          'signature': 'https://x/sig.png',
        }),
      );
      expect(model.headshot, isNotNull);
      expect(model.headshot!.isImage, isTrue);
      expect(model.budgetFile!.isPdf, isTrue);
      expect(model.signatureUrl, 'https://x/sig.png');
    });

    test('curates hero fields with option resolution and non-Dem flag', () {
      final schema = _schema([
        {'id': 'sec', 'type': 'section_header', 'label': 'S'},
        {'id': 'full_name', 'type': 'short_answer', 'label': 'Name'},
        {'id': 'office_sought', 'type': 'dropdown', 'label': 'Office', 'options': [
          {'value': 'state_senate', 'label': 'Missouri State Senate'},
        ]},
        {'id': 'party_history', 'type': 'radio', 'label': 'Party', 'options': [
          {'value': 'former_r', 'label': 'Previously Republican'},
        ]},
      ]);
      final model = SubmissionReviewModel.from(
        schema,
        _submission({
          'full_name': 'Andrew Hartzler',
          'office_sought': 'state_senate',
          'district_number': 'MO SD7',
          'party_history': 'former_r',
          'raised_to_date': 167000,
          'young_dem_agenda': ['healthcare'],
        }),
      );
      expect(model.candidateName, 'Andrew Hartzler');
      expect(model.office, 'Missouri State Senate');
      expect(model.district, 'MO SD7');
      expect(model.partyHistory, 'Previously Republican');
      expect(model.nonDemHistory, isTrue);
      expect(model.raisedToDate, 167000);
      expect(model.track, 'Young Dem');
    });

    test('alignment: all-aligned answers score ~100%', () {
      final model = SubmissionReviewModel.from(
        _schema(const [], scoring: _scoring),
        _submission({
          'pos_medicare_for_all': 'yes', // 1
          'pos_right_to_work': 'yes', // 1
          'pos_aipac_money': 'no', // 1
        }),
      );
      expect(model.alignmentPct, 100);
      expect(model.scoredAnswered, 3);
      expect(model.scoredTotal, 3);
      expect(model.alignment!.strong, 3);
      expect(model.alignment!.partial, 0);
      expect(model.alignment!.oppose, 0);
    });

    test('alignment: mixed answers score lower with a breakdown', () {
      final model = SubmissionReviewModel.from(
        _schema(const [], scoring: _scoring),
        _submission({
          'pos_medicare_for_all': 'public_option', // 0.75 strong
          'pos_right_to_work': 'qualified', // 0.5 partial
          'pos_aipac_money': 'yes', // 0 oppose
        }),
      );
      // (0.75 + 0.5 + 0) / 3 * 100 = 41.67 -> 42
      expect(model.alignmentPct, 42);
      expect(model.scoredAnswered, 3);
      expect(model.alignment!.strong, 1);
      expect(model.alignment!.partial, 1);
      expect(model.alignment!.oppose, 1);
      expect(model.alignment!.breakdownLine, '1 strong / 1 partial / 1 oppose');
    });

    test('alignment: unmapped values excluded, unanswered ignored', () {
      final model = SubmissionReviewModel.from(
        _schema(const [], scoring: _scoring),
        _submission({
          'pos_medicare_for_all': 'yes', // 1, counted
          'pos_right_to_work': 'unsure', // answered but NOT in map -> excluded
          // pos_aipac_money not answered at all -> ignored
        }),
      );
      expect(model.alignmentPct, 100); // 1 / 1
      expect(model.scoredAnswered, 1); // only the mapped answer
      expect(model.scoredTotal, 2); // both answered questions
      expect(model.alignment!.mapTotal, 3);
    });

    test('alignment: null pct when no scored question has a mapped answer', () {
      final model = SubmissionReviewModel.from(
        _schema(const [], scoring: _scoring),
        _submission({'pos_housing': 'renter', 'pos_right_to_work': 'unsure'}),
      );
      expect(model.alignmentPct, isNull);
      expect(model.scoredAnswered, 0);
    });

    test('alignment: null when form carries no scoring config', () {
      final model = SubmissionReviewModel.from(
        _schema(const []),
        _submission({'pos_medicare_for_all': 'yes'}),
      );
      expect(model.alignment, isNull);
      expect(model.alignmentPct, isNull);
      expect(model.scoredAnswered, 0);
    });

    test('stanceFor covers the convention buckets', () {
      expect(SubmissionReviewModel.stanceFor('yes_full'), Stance.support);
      expect(SubmissionReviewModel.stanceFor('no'), Stance.oppose);
      expect(SubmissionReviewModel.stanceFor('qualified'), Stance.qualified);
      expect(SubmissionReviewModel.stanceFor('unsure'), Stance.unsure);
      expect(SubmissionReviewModel.stanceFor('prefer_not_to_answer'), Stance.unsure);
      expect(SubmissionReviewModel.stanceFor('supply'), Stance.neutral);
    });
  });
}
