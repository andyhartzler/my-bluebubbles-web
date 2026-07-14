import 'package:flutter_test/flutter_test.dart';
import 'package:bluebubbles/features/forms/models/form_field_config.dart';
import 'package:bluebubbles/features/forms/models/form_schema.dart';
import 'package:bluebubbles/features/forms/models/form_submission.dart';
import 'package:bluebubbles/features/forms/models/submission_review_model.dart';

FormSchema _schema(List<Map<String, dynamic>> fields) {
  return FormSchema(
    id: 'form-1',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    title: 'Endorsement',
    formType: 'form',
    schema: FormSchemaData(
      fields: fields.map((f) => FormFieldConfig.fromJson(f)).toList(),
    ),
  );
}

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
