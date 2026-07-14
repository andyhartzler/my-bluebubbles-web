import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/submission_review_model.dart';
import '../../theme/moyd_brand.dart';
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

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MoydBrand.navy, MoydBrand.navySoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Headshot(url: model.headshot?.url, name: model.candidateName),
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
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                      Text(
                        officeLine,
                        style: const TextStyle(
                          color: MoydBrand.gold,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (model.email != null)
                          _ContactChip(
                            icon: Icons.email_outlined,
                            label: model.email!,
                            onTap: () =>
                                _copy(context, model.email!, 'Email'),
                          ),
                        if (model.phone != null)
                          _ContactChip(
                            icon: Icons.phone_outlined,
                            label: model.phone!,
                            onTap: () =>
                                _copy(context, model.phone!, 'Phone'),
                          ),
                        if (onOpenLinkedProfile != null)
                          _ContactChip(
                            icon: Icons.open_in_new,
                            label: linkedProfileLabel ?? 'View profile',
                            onTap: onOpenLinkedProfile!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Headshot extends StatelessWidget {
  final String? url;
  final String name;
  const _Headshot({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    const size = 96.0;
    final initial =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 40,
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
        border: Border.all(color: Colors.white24, width: 2),
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
    return Material(
      color: Colors.white.withOpacity(0.12),
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

/// A compact "at a glance" tile strip for the pinned header area. Tiles hide
/// when their datum is absent. Rendered on a light surface with dark text.
/// Single-line + horizontally scrollable so it can pin at a fixed height.
class AtAGlanceBar extends StatelessWidget {
  final SubmissionReviewModel model;
  const AtAGlanceBar({super.key, required this.model});

  /// Fixed pinned height used by the SliverPersistentHeader delegate.
  static const double height = 58;

  bool get hasContent =>
      model.office != null ||
      model.district != null ||
      model.raisedToDate != null ||
      model.selfFundedPct != null ||
      model.track != null ||
      model.nonDemHistory;

  static String _money(num v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '\$$buf';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final tiles = <Widget>[];
    void add(String label, String value, {Color? valueColor}) {
      tiles.add(_GlanceTile(label: label, value: value, valueColor: valueColor));
    }

    if (model.office != null) add('Office', model.office!);
    if (model.district != null) add('District', model.district!);
    if (model.raisedToDate != null) {
      add('Raised', _money(model.raisedToDate!));
    }
    if (model.selfFundedPct != null) {
      add('Self-funded', '${model.selfFundedPct!.round()}%');
    }
    if (model.track != null) add('Track', model.track!);

    if (tiles.isEmpty && !model.nonDemHistory) return const SizedBox.shrink();

    final children = <Widget>[];
    for (int i = 0; i < tiles.length; i++) {
      if (i > 0) {
        children.add(Container(
          width: 1,
          height: 26,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: cs.outlineVariant,
        ));
      }
      children.add(tiles[i]);
    }
    if (model.nonDemHistory && model.partyHistory != null) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(width: 16));
      }
      children.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: MoydBrand.amberBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flag_outlined, size: 14, color: MoydBrand.amber),
            const SizedBox(width: 5),
            Text(
              model.partyHistory!,
              style: const TextStyle(
                color: Color(0xFF6B4E00),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ));
    }

    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: children),
      ),
    );
  }
}

class _GlanceTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _GlanceTile({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            color: valueColor ?? cs.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
