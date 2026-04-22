import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/donor_enrichment_record.dart';
import 'package:bluebubbles/screens/crm/candidate_ui_helpers.dart';

/// Card surfacing the populated donor_enrichment columns.
///
/// If the record has zero populated fields, this returns `SizedBox.shrink()`.
/// Callers may alternatively check `record.hasData` themselves before
/// including this widget — both paths render nothing for empty data.
class DonorEnrichmentCard extends StatefulWidget {
  final DonorEnrichmentRecord record;
  final int collapseThreshold;

  const DonorEnrichmentCard({
    super.key,
    required this.record,
    this.collapseThreshold = 8,
  });

  @override
  State<DonorEnrichmentCard> createState() => _DonorEnrichmentCardState();
}

class _DonorEnrichmentCardState extends State<DonorEnrichmentCard> {
  bool _expanded = false;

  // Labels that live together in the UI — used to group the linear list of
  // populated fields into sections.
  static const _identityLabels = {
    'Gender',
    'Age (est.)',
    'Generation',
    'Ethnicity',
  };
  static const _geographyLabels = {
    'Street',
    'Street 2',
    'Current City',
    'Current State',
    'Current Zip',
    'Current County',
    'Congressional District',
  };
  static const _politicsLabels = {
    'Party Lean',
    'Lean Confidence',
  };
  static const _givingLabels = {
    'Total Political Giving',
    'Gift Count',
    'Average Gift',
    'Giving Frequency',
    'Giving Capacity',
  };
  static const _contactLabels = {
    'Mobile',
    'Home Phone',
    'Email',
    'Social Profiles',
  };
  static const _employmentLabels = {
    'Employer',
    'Job Title',
    'Est. Income',
  };
  static const _wealthLabels = {
    'Homeowner',
    'Wealth Score',
    'Engagement Score',
  };

  String _sectionFor(String label) {
    if (_identityLabels.contains(label)) return 'Identity';
    if (_contactLabels.contains(label)) return 'Contact';
    if (_geographyLabels.contains(label)) return 'Geography';
    if (_employmentLabels.contains(label)) return 'Employment';
    if (_politicsLabels.contains(label)) return 'Politics';
    if (_givingLabels.contains(label)) return 'Giving';
    if (_wealthLabels.contains(label)) return 'Wealth';
    return 'Other';
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.record.populatedFields;
    if (fields.isEmpty) return const SizedBox.shrink();

    // Group into sections preserving populatedFields order inside each group.
    final grouped = <String, List<({String label, String value})>>{};
    for (final f in fields) {
      grouped.putIfAbsent(_sectionFor(f.label), () => []).add(f);
    }

    final sectionOrder = [
      'Identity',
      'Contact',
      'Geography',
      'Employment',
      'Politics',
      'Giving',
      'Wealth',
      'Other',
    ];
    final ordered = [
      for (final s in sectionOrder)
        if (grouped[s] != null && grouped[s]!.isNotEmpty) MapEntry(s, grouped[s]!),
    ];

    final overThreshold = fields.length > widget.collapseThreshold;
    final visibleCount = (overThreshold && !_expanded)
        ? widget.collapseThreshold
        : fields.length;

    // Render, stopping at `visibleCount` total rows across sections.
    // Pre-compute which sections will contribute at least one row so we never
    // emit an orphan header (header + spacer with zero fields under it).
    int rendered = 0;
    final children = <Widget>[];
    for (final entry in ordered) {
      if (rendered >= visibleCount) break;
      final sectionFields = <Widget>[];
      for (final f in entry.value) {
        if (rendered >= visibleCount) break;
        sectionFields.add(_fieldRow(f.label, f.value));
        rendered++;
      }
      if (sectionFields.isEmpty) continue;
      children.add(_sectionHeader(entry.key));
      children.addAll(sectionFields);
      children.add(const SizedBox(height: 8));
    }

    if (overThreshold) {
      children.add(
        TextButton(
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => setState(() => _expanded = !_expanded),
          child: Text(
            _expanded ? 'Show fewer' : 'Show ${fields.length - widget.collapseThreshold} more',
            style: const TextStyle(
              color: BrandColors.steelBlue,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return CandidateUI.card(
      'Donor Enrichment',
      Icons.insights,
      BrandColors.steelBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      );

  Widget _fieldRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
}
