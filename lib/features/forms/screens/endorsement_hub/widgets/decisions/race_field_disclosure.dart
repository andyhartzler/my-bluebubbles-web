import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../models/submission_review_model.dart';
import '../../../../theme/moyd_brand.dart';
import '../../race_field_repository.dart';
import '../headshot_avatar.dart';

/// "Other Democrats in this race": the disclosure at the foot of a ballot
/// row's expansion showing the filed Democrats who never answered the
/// questionnaire.
///
/// FIVE DISTINCT STATES, and the distinction between three of them is the
/// whole point (BUILD-SPEC C3):
///
///   * field:       1+ other filed Democrats -> collapsible list
///   * solo:        race key exists, zero others, AND this applicant is the
///                  only one -> "Only Democrat filed in this race" (the most
///                  decision-relevant fact about a solo race, at the cost of
///                  one line)
///   * no others:   race key exists, zero non-applicants, but 2+ applicants
///                  -> "No other filed Democrat beyond the applicants".
///                  MO_HOUSE-39 and MO_SEN-18 each hold two applicants and no
///                  outsider, and the solo line printed on all four of those
///                  rows, directly under a race cap reading "2 applicants".
///   * keyless:     county / statewide applicants -> "No filed-candidate list
///                  for this office" (we hold a filing list for legislative
///                  and congressional races and not for these)
///   * unavailable: the race fetch failed -> "Race field unavailable".
///                  NEVER collapsed into solo: rendering nothing on failure
///                  would silently convert every contested race into an
///                  apparent solo race, a false statement the committee could
///                  act on.
///   * not loaded:  fetch in flight -> nothing (transient).
///
/// TWO HARD RULES beyond the visuals: unvetted people are never in any
/// aggregate (SlateStats, scoreboard, copy summary, toolbar counts), and they
/// are never on the ballot. They exist only inside this expanded disclosure.
class RaceFieldDisclosure extends StatefulWidget {
  final RaceInfo? raceInfo;

  /// Non-applicant Democrats in this race, already alphabetized upstream.
  final List<RaceFieldCandidate> others;

  /// SlateController's race-load lifecycle, threaded through so this widget
  /// can tell "no opponents" apart from "we could not find out".
  final bool loaded;
  final bool failed;

  /// How many QUESTIONNAIRE APPLICANTS share this race key, this one
  /// included. [others] holds only the filed Democrats who did NOT apply, so
  /// without this the widget could not tell a genuinely solo race from a race
  /// where every filed Democrat happens to have applied.
  final int applicantsInRace;

  const RaceFieldDisclosure({
    super.key,
    required this.raceInfo,
    required this.others,
    required this.loaded,
    required this.failed,
    this.applicantsInRace = 1,
  });

  @override
  State<RaceFieldDisclosure> createState() => _RaceFieldDisclosureState();
}

class _RaceFieldDisclosureState extends State<RaceFieldDisclosure> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.loaded) return const SizedBox.shrink();
    if (widget.failed || widget.raceInfo == null) {
      // A submission the view does not cover is the same honest statement as
      // a failed fetch: we could not determine this race's field.
      return _quietLine(context, Icons.cloud_off_outlined,
          'Race field unavailable');
    }
    if (widget.raceInfo!.raceKey == null) {
      return _quietLine(context, Icons.map_outlined,
          'No filed-candidate list for this office');
    }
    if (widget.others.isEmpty) {
      // "Only Democrat filed in this race" is false the moment another
      // applicant is standing in the same race, and the race cap directly
      // above says so in the same breath.
      return widget.applicantsInRace >= 2
          ? _quietLine(context, Icons.groups_outlined,
              'No other filed Democrat beyond the applicants in this race')
          : _quietLine(context, Icons.person_outline,
              'Only Democrat filed in this race');
    }
    return _field(context);
  }

  Widget _quietLine(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Widget _field(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.groups_outlined,
                      size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Other Democrats in this race · '
                      '${widget.others.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(_open ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        // Provenance clause fulfils RaceInfo.officeSource's
                        // contract: when the race identity came only from the
                        // applicant's own questionnaire answer, say so rather
                        // than implying an SoS filing match.
                        widget.raceInfo!.officeSource == 'filed'
                            ? 'Filed Democrats who did not answer our '
                                'questionnaire, per the SoS filing list. '
                                'MOYD has not evaluated them.'
                            : 'Filed Democrats who did not answer our '
                                'questionnaire. This race was identified '
                                'from the applicant\'s own answers, not an '
                                'SoS filing. MOYD has not evaluated them.',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 6),
                      // Alphabetical only. This block never sorts, scores or
                      // ranks, so the order cannot be read as a judgment.
                      for (final c in widget.others)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: UnvettedDemocratRow(candidate: c),
                        ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// One unvetted Democrat. Visually segregated from every applicant treatment
/// on four independent axes so no single one carries the load (BUILD-SPEC
/// C2.1): a mandatory "Did not apply" pill, a dashed border no applicant
/// surface uses (with a dashed avatar ring), deliberate inertness (no
/// alignment, no stances, no DecisionChip, no vote controls, no tap-through:
/// none exists), and the verbal disclaimer above the list. The only
/// affordances are external links.
class UnvettedDemocratRow extends StatelessWidget {
  final RaceFieldCandidate candidate;
  const UnvettedDemocratRow({super.key, required this.candidate});

  /// [url] is always the output of [socialProfileUrl] / [webLinkUrl]: fully
  /// resolved, network-correct, and junk-filtered upstream. This method never
  /// composes URLs itself; the per-network routing lives beside the
  /// sanitizers in race_field_repository.dart so there is one implementation.
  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final c = candidate;

    final glanceParts = <String>[
      if (c.city != null) c.city!,
      if (c.county != null) c.county!,
      if (c.ageBand != null) c.ageBand!,
      if (c.gatedMoneyLabel != null) c.gatedMoneyLabel!,
    ];

    // Trailing external-link buttons: 20px glyphs padded to a 44px tap
    // target. Ballotpedia and the campaign website are the anchor links.
    // Fields are sanitized at parse time, so a non-null value here is
    // URL-shaped and webLinkUrl always resolves it.
    final trailing = <Widget>[
      if (c.ballotpediaUrl != null)
        _LinkTarget(
          icon: Icons.how_to_vote_outlined,
          tooltip: 'Ballotpedia',
          onTap: () => _open(webLinkUrl(c.ballotpediaUrl!)),
        ),
      if (c.campaignWebsite != null)
        _LinkTarget(
          icon: Icons.language,
          tooltip: 'Campaign website',
          onTap: () => _open(webLinkUrl(c.campaignWebsite!)),
        ),
    ];

    // Each icon resolves through ITS OWN network's base URL: the Instagram
    // icon must never open x.com/<handle>, which can be a different person.
    // A value whose network-specific resolution fails (for example a Bluesky
    // value on a non-Bluesky host) renders no icon at all: a dead or wrong
    // button next to an unvetted candidate's face is worse than no button.
    final socialSpecs = <(SocialNetwork, String?, IconData, String)>[
      (SocialNetwork.facebook, c.socialFacebook, Icons.facebook, 'Facebook'),
      (
        SocialNetwork.twitter,
        c.socialTwitter,
        Icons.alternate_email,
        'Twitter/X'
      ),
      (
        SocialNetwork.instagram,
        c.socialInstagram,
        Icons.camera_alt_outlined,
        'Instagram'
      ),
      (SocialNetwork.tiktok, c.socialTiktok, Icons.music_note, 'TikTok'),
      (
        SocialNetwork.bluesky,
        c.socialBluesky,
        Icons.cloud_outlined,
        'Bluesky'
      ),
    ];
    final socials = <Widget>[];
    for (final (network, value, icon, tooltip) in socialSpecs) {
      if (value == null) continue;
      final url = socialProfileUrl(network, value);
      if (url == null) continue;
      socials.add(_LinkTarget(
          icon: icon, tooltip: tooltip, small: true, onTap: () => _open(url)));
    }

    return CustomPaint(
      painter: _DashedBorderPainter(color: cs.outlineVariant, radius: 12),
      child: Container(
        // Background from ColorScheme so the row reads on both themes; the
        // dashed outline itself is painted, since Flutter borders have no
        // dashed style.
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _DashedRingAvatar(name: c.name, photoUrl: c.photoUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(c.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface)),
                      const _DidNotApplyPill(),
                      if (c.incumbent) const _IncumbentChip(),
                    ],
                  ),
                  if (glanceParts.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(glanceParts.join(' · '),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                  if (socials.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Wrap(spacing: 2, children: socials),
                  ],
                ],
              ),
            ),
            ...trailing,
          ],
        ),
      ),
    );
  }
}

/// The mandatory pill: on every unvetted row, always, never collapsed away on
/// narrow. neutralFg-on-neutralBg is a documented self-contained AA pair on
/// both themes, and reads as distinct from the amber baseline header and the
/// qualified amber conflict pill, so a draft chip, a conflict chip and an
/// unvetted chip are never confused.
class _DidNotApplyPill extends StatelessWidget {
  const _DidNotApplyPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: MoydBrand.neutralBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text('Did not apply',
          style: TextStyle(
              color: MoydBrand.neutralFg,
              fontSize: 10.5,
              fontWeight: FontWeight.w700)),
    );
  }
}

/// Plain factual chip; true on exactly one row in the current data (Wesley
/// Bell), so it renders as information, never as part of a badge system.
class _IncumbentChip extends StatelessWidget {
  const _IncumbentChip();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('Incumbent',
          style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 10.5,
              fontWeight: FontWeight.w700)),
    );
  }
}

/// External-link button: 20px glyph (16 when [small]) padded to a 44px (36px
/// when [small]) tap target.
class _LinkTarget extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool small;
  const _LinkTarget({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final box = small ? 36.0 : 44.0;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(box / 2),
        child: SizedBox(
          width: box,
          height: box,
          child: Icon(icon, size: small ? 16 : 20, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// 28px face inside a dashed ring (applicants get solid rings everywhere on
/// the board). Initials fallback via the shared [HeadshotAvatar].
class _DashedRingAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  const _DashedRingAvatar({required this.name, required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final file = photoUrl == null
        ? null
        : ReviewFile(url: photoUrl!, name: 'profile.jpg', mimeType: 'image/jpeg');
    return CustomPaint(
      painter: _DashedCirclePainter(color: cs.outline),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: HeadshotAvatar(file: file, name: name, size: 28),
      ),
    );
  }
}

/// Dashed rounded-rect outline (Flutter's BorderStyle has no dashed variant).
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, Radius.circular(radius)));
    canvas.drawPath(_dash(path), paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  const _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()..addOval(Offset.zero & size);
    canvas.drawPath(_dash(path, dash: 3, gap: 3), paint);
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter old) =>
      old.color != color;
}

/// Convert a closed path into a dashed copy via its path metrics.
Path _dash(Path source, {double dash = 4, double gap = 3}) {
  final out = Path();
  for (final ui.PathMetric metric in source.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final end = (distance + dash).clamp(0.0, metric.length);
      out.addPath(metric.extractPath(distance, end), Offset.zero);
      distance = end + gap;
    }
  }
  return out;
}
