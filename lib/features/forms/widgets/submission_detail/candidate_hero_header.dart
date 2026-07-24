import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/submission_review_model.dart';
import '../../theme/moyd_brand.dart';
import '../review/stance_visuals.dart';
import '../submission_status_badge.dart';

/// Solid-navy hero for the endorsement review: 96px headshot (initial
/// fallback), name + pronouns, office + district in gold, contact chips that
/// copy on tap, and a status badge. White / white70 text throughout — all
/// pairings clear 4.5:1 on the navy fill in both themes (the fill is fixed,
/// so it does not depend on the ambient theme).
class CandidateHeroHeader extends StatelessWidget {
  final SubmissionReviewModel model;
  final String status;

  /// Optional "view linked CRM profile" affordance.
  final VoidCallback? onOpenLinkedProfile;
  final String? linkedProfileLabel;

  const CandidateHeroHeader({
    super.key,
    required this.model,
    required this.status,
    this.onOpenLinkedProfile,
    this.linkedProfileLabel,
  });

  void _copy(BuildContext context, String value, String what) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$what copied'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = model.preferredName != null &&
            model.preferredName!.isNotEmpty &&
            model.preferredName != model.candidateName
        ? '${model.candidateName} (${model.preferredName})'
        : model.candidateName;

    final officeLine = [
      if (model.office != null) model.office!,
      if (model.district != null) model.district!,
    ].join('  ·  ');

    // Shared pieces ---------------------------------------------------------

    Widget officePill() => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: MoydBrand.navy,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: MoydBrand.gold.withOpacity(0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance,
                  size: 14, color: MoydBrand.gold),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  officeLine,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MoydBrand.gold,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );

    Widget contactChips() => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (model.email != null)
              _ContactChip(
                icon: Icons.email_outlined,
                label: model.email!,
                onTap: () => _copy(context, model.email!, 'Email'),
              ),
            if (model.phone != null)
              _ContactChip(
                icon: Icons.phone_outlined,
                label: model.phone!,
                onTap: () => _copy(context, model.phone!, 'Phone'),
              ),
            if (onOpenLinkedProfile != null)
              _ContactChip(
                icon: Icons.open_in_new,
                label: linkedProfileLabel ?? 'View profile',
                onTap: onOpenLinkedProfile!,
              ),
          ],
        );

    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 520;
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          // Verified navy -> royal -> deep-sky sweep (white >= 4.5:1 at every
          // stop), matching the Endorsement HQ hero.
          gradient: const LinearGradient(
            colors: [MoydBrand.navy, Color(0xFF2B4B8C), Color(0xFF1D6FA8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2B4B8C).withOpacity(0.30),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: EdgeInsets.all(narrow ? 16 : 20),
        child: narrow
            // Phone: headshot + name row up top, then badges / office /
            // contact chips stacked full-width so nothing gets squeezed.
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _Headshot(
                          url: model.headshot?.url,
                          name: model.candidateName,
                          size: 72),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            if (model.pronouns != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                model.pronouns!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (model.alignmentPct != null)
                        AlignmentBadge(pct: model.alignmentPct!, showWord: true),
                      SubmissionStatusBadge(status: status),
                    ],
                  ),
                  if (officeLine.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    officePill(),
                  ],
                  const SizedBox(height: 12),
                  contactChips(),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Headshot(
                      url: model.headshot?.url, name: model.candidateName),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (model.alignmentPct != null) ...[
                              AlignmentBadge(
                                  pct: model.alignmentPct!, showWord: true),
                              const SizedBox(width: 8),
                            ],
                            SubmissionStatusBadge(status: status),
                          ],
                        ),
                        if (model.pronouns != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            model.pronouns!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        if (officeLine.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          // Solid navy pill so the gold office line keeps its
                          // ~5.7:1 contrast regardless of the gradient stop
                          // beneath it.
                          officePill(),
                        ],
                        const SizedBox(height: 12),
                        contactChips(),
                      ],
                    ),
                  ),
                ],
              ),
      );
    });
  }
}

class _Headshot extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  const _Headshot({required this.url, required this.name, this.size = 96});

  @override
  Widget build(BuildContext context) {
    final initial =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        shape: BoxShape.circle,
        border: Border.all(color: MoydBrand.gold, width: 2.5),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (url == null || url!.isEmpty) return fallback;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: MoydBrand.gold, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}

class _ContactChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ContactChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Dark translucent fill (not white-over-gradient) so the white label
    // keeps >= 4.5:1 even at the lightest gradient stop.
    return Material(
      color: Colors.black.withOpacity(0.22),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
