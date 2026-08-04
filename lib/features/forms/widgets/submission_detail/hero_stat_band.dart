import 'package:flutter/material.dart';

import '../../models/submission_review_model.dart';
import '../../theme/moyd_brand.dart';
import '../review/stance_visuals.dart';

/// Navy stat band rendered by the review body directly beneath the hero
/// (or at the top of the questionnaire tab, which has no hero): Office /
/// District / Raised / Self-funded / Track tiles plus the non-Democrat
/// party-history flag chip. Replaces the retired at-a-glance strip minus its
/// alignment tile (alignment lives in the hero badge and the verdict ring).
///
/// Solid [MoydBrand.navy] fill (fixed, never opacity-over-unknown), so every
/// pairing holds in both themes without branching: white values > 8:1, gold
/// labels ~6.5:1, and the flag chip is the shipped self-contained
/// amberBg/dark-amber pair (~7.3:1).
class HeroStatBand extends StatelessWidget {
  final SubmissionReviewModel model;

  const HeroStatBand({super.key, required this.model});

  /// Mirrors [build]'s render conditions exactly (the flag chip needs
  /// [SubmissionReviewModel.partyHistory] text, not just the boolean) so the
  /// body never reserves padding for a band that renders empty.
  bool get hasContent =>
      model.office != null ||
      model.district != null ||
      model.raisedToDate != null ||
      model.selfFundedPct != null ||
      model.track != null ||
      model.youngDemByDob ||
      (model.nonDemHistory && model.partyHistory != null);

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];
    void add(String label, String value) {
      tiles.add(_StatTile(label: label, value: value));
    }

    if (model.office != null) add('OFFICE', model.office!);
    if (model.district != null) add('DISTRICT', model.district!);
    if (model.raisedToDate != null) {
      add('RAISED', ReviewFormat.currency(model.raisedToDate!));
    }
    if (model.selfFundedPct != null) {
      add('SELF-FUNDED', '${model.selfFundedPct!.round()}%');
    }
    if (model.track != null) add('TRACK', model.track!);

    // Both flags are self-contained light pills on the fixed navy fill, which
    // is the same treatment the party-history flag already ships with.
    final flags = <Widget>[
      if (model.nonDemHistory && model.partyHistory != null)
        _chip(Icons.flag_outlined, model.partyHistory!),
      // dob_is_young_dem is derived off-schema, stored as a string, and true
      // on 9 of the 67 submissions that carry it. Real eligibility data that
      // used to render nowhere at all.
      if (model.youngDemByDob)
        _chip(Icons.cake_outlined, 'Young Dem by DOB'),
    ];

    if (tiles.isEmpty && flags.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MoydBrand.navy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 560;
        if (wide) {
          return Wrap(
            spacing: 24,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (int i = 0; i < tiles.length; i++) ...[
                if (i > 0) _divider(),
                tiles[i],
              ],
              ...flags,
            ],
          );
        }
        // Phone width: one horizontally scrollable line, no wrap jitter.
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < tiles.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _divider(),
                  ),
                tiles[i],
              ],
              for (int i = 0; i < flags.length; i++) ...[
                if (i > 0 || tiles.isNotEmpty) const SizedBox(width: 12),
                flags[i],
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _divider() => Container(width: 1, height: 26, color: Colors.white24);

  /// A flag chip on the navy band: the shipped self-contained light pill
  /// (dark amber text on amberBg, ~7.3:1) reads as a deliberate tag rather
  /// than as part of the band's own type.
  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: MoydBrand.amberBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: MoydBrand.amber),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B4E00),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// One gold-label / white-value stat inside the navy band.
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: MoydBrand.gold,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
