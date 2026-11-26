import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/chapter.dart';
import 'package:bluebubbles/models/crm/chapter_hub.dart';

/// Small building blocks shared by the Chapters hub's directory and review
/// views, so both read as one page.

// ---------------------------------------------------------------------------
// Copy helpers
// ---------------------------------------------------------------------------

final DateFormat _dayFormat = DateFormat('MMM d, y');

/// "Nov 3, 2025".
String hubDay(DateTime date) => _dayFormat.format(date.toLocal());

/// A charter date, "Nov 3, 2025". Charter dates are calendar days, not
/// moments, so they are not shifted to local time. Every chapter screen
/// shows them this way.
String chapterCharterDay(DateTime date) => _dayFormat.format(date);

/// "1 member", "3 members".
String hubCount(int count, String singular, [String? plural]) =>
    '$count ${count == 1 ? singular : (plural ?? '${singular}s')}';

/// Chapter types as people say them. Accepts the database values and the
/// looser values the charter form stores.
String chapterTypeLabel(String? type) {
  final value = (type ?? '').trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
  switch (value) {
    case 'college':
      return 'College';
    case 'highschool':
      return 'High school';
    case 'county':
      return 'County';
    case '':
      return 'Chapter';
  }
  final raw = type!.trim();
  return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
}

IconData chapterTypeIcon(String? type) {
  switch ((type ?? '').trim().toLowerCase()) {
    case 'college':
      return Icons.school_outlined;
    case 'highschool':
      return Icons.backpack_outlined;
    case 'county':
      return Icons.location_city_outlined;
  }
  return Icons.account_tree_outlined;
}

/// The chapter's name, in quotes when it reads like an answer to the sign-up
/// question rather than a club name, so reviewers see it for what it is.
String hubDisplayName(ChapterHubEntry entry) {
  final name = entry.chapter.chapterName.trim();
  if (name.isEmpty) return 'No name';
  if (entry.stage != ChapterStage.chartered && ChapterHubKeys.looksLikeAnswer(name)) {
    return '“$name”';
  }
  return name;
}

/// The school or county line under a name, or null when it would only repeat
/// the name.
String? hubPlaceLine(ChapterHubEntry entry) {
  final place = entry.placeLabel.trim();
  if (place.isEmpty) return null;
  if (ChapterHubKeys.name(place) == ChapterHubKeys.name(entry.chapter.chapterName)) return null;
  return place;
}

// ---------------------------------------------------------------------------
// Tones
// ---------------------------------------------------------------------------

/// Colour roles for badges and banners. Each resolves to a pair that clears
/// 4.5:1 in both light and dark themes; brand colours are only the tint.
enum HubTone { success, attention, info, warning, neutral }

class HubToneColors {
  final Color background;
  final Color foreground;
  const HubToneColors(this.background, this.foreground);

  factory HubToneColors.of(BuildContext context, HubTone tone) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    switch (tone) {
      case HubTone.success:
        return HubToneColors(
          BrandColors.success.withValues(alpha: dark ? 0.22 : 0.14),
          dark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
        );
      case HubTone.attention:
        return HubToneColors(
          BrandColors.sunriseGold.withValues(alpha: dark ? 0.24 : 0.26),
          dark ? const Color(0xFFFCD34D) : const Color(0xFF7A4F00),
        );
      case HubTone.info:
        return HubToneColors(
          BrandColors.momentumBlue.withValues(alpha: dark ? 0.24 : 0.16),
          dark ? const Color(0xFF7DD3FC) : const Color(0xFF155E85),
        );
      case HubTone.warning:
        return HubToneColors(
          BrandColors.warning.withValues(alpha: dark ? 0.22 : 0.16),
          dark ? const Color(0xFFFDBA74) : const Color(0xFF9A3412),
        );
      case HubTone.neutral:
        return HubToneColors(scheme.surfaceContainerHighest, scheme.onSurfaceVariant);
    }
  }
}

/// A small rounded label: stage, type, flag, hint.
class HubBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final HubTone tone;
  final String? tooltip;

  const HubBadge({
    super.key,
    required this.label,
    this.icon,
    this.tone = HubTone.neutral,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colors = HubToneColors.of(context, tone);
    final text = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colors.foreground,
          fontWeight: FontWeight.w600,
        );
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: colors.foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(label, style: text, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
    if (tooltip == null) return badge;
    return Tooltip(message: tooltip!, child: badge);
  }
}

/// Where [chapter] stands, from its own fields first (so a charter or
/// archive shows at once) and the hub entry, when there is one, for whether
/// an application is in.
ChapterStage chapterStageOf(Chapter chapter, {ChapterHubEntry? entry, int documentCount = 0}) {
  if ((chapter.status ?? '').trim().toLowerCase() == 'archived') return ChapterStage.archived;
  if (chapter.isChartered) return ChapterStage.chartered;
  final app = entry?.application;
  if ((app?.isComplete ?? false) || (entry?.documentCount ?? 0) > 0 || documentCount > 0) {
    return ChapterStage.applied;
  }
  return ChapterStage.signup;
}

/// The stage of a chapter as a badge: "Chartered · Nov 3, 2025",
/// "Application in", "From a sign-up", "Archived". The one stage badge used
/// on hub cards, the chapter page and search results. [onDark] draws it for
/// the navy chapter header.
class ChapterStageBadge extends StatelessWidget {
  final ChapterStage stage;
  final DateTime? charterDate;
  final bool onDark;

  const ChapterStageBadge({super.key, required this.stage, this.charterDate, this.onDark = false});

  /// The badge for a hub entry, with its charter date.
  ChapterStageBadge.of(ChapterHubEntry entry, {Key? key, bool onDark = false})
      : this(key: key, stage: entry.stage, charterDate: entry.chapter.charterDate, onDark: onDark);

  static IconData iconFor(ChapterStage stage) {
    switch (stage) {
      case ChapterStage.chartered:
        return Icons.verified_outlined;
      case ChapterStage.applied:
        return Icons.assignment_turned_in_outlined;
      case ChapterStage.signup:
        return Icons.person_add_alt_outlined;
      case ChapterStage.archived:
        return Icons.archive_outlined;
    }
  }

  static HubTone toneFor(ChapterStage stage) {
    switch (stage) {
      case ChapterStage.chartered:
        return HubTone.success;
      case ChapterStage.applied:
        return HubTone.attention;
      case ChapterStage.signup:
      case ChapterStage.archived:
        return HubTone.neutral;
    }
  }

  static String? _tooltipFor(ChapterStage stage) {
    switch (stage) {
      case ChapterStage.applied:
        return 'A charter application is on file';
      case ChapterStage.signup:
        return 'Added automatically when a member typed this name at sign-up';
      case ChapterStage.chartered:
      case ChapterStage.archived:
        return null;
    }
  }

  String get label {
    final date = charterDate;
    if (stage == ChapterStage.chartered && date != null) return 'Chartered · ${chapterCharterDay(date)}';
    return stage.label;
  }

  @override
  Widget build(BuildContext context) {
    final text = label;
    final Widget badge;
    if (onDark) {
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconFor(stage), size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
              ),
            ),
          ],
        ),
      );
    } else {
      badge = HubBadge(label: text, icon: iconFor(stage), tone: toneFor(stage), tooltip: _tooltipFor(stage));
    }
    return Semantics(label: 'Stage: $text', excludeSemantics: true, child: badge);
  }
}

/// Icon and short text, e.g. a member count.
class HubFact extends StatelessWidget {
  final IconData icon;
  final String label;
  const HubFact({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Monogram
// ---------------------------------------------------------------------------

/// A round monogram coloured by chapter type. Ink is picked per fill so the
/// letters clear 4.5:1: navy on momentum blue and sunrise gold, white on navy.
class ChapterMonogram extends StatelessWidget {
  final ChapterHubEntry entry;
  final double size;
  const ChapterMonogram({super.key, required this.entry, this.size = 48});

  static const _filler = {
    'the', 'of', 'at', 'and', 'young', 'democrats', 'democrat', 'dems', 'club', 'chapter',
  };

  static String lettersFor(ChapterHubEntry entry) {
    final abbreviation = (entry.chapter.nameAbbreviation ?? '').replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (abbreviation.isNotEmpty) {
      return abbreviation.substring(0, abbreviation.length.clamp(0, 4)).toUpperCase();
    }
    final words = entry.chapter.chapterName
        .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final meaningful = words.where((w) => !_filler.contains(w.toLowerCase())).toList();
    final source = meaningful.isNotEmpty ? meaningful : words;
    if (source.isEmpty) return '?';
    return source.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color ink;
    switch (entry.chapter.chapterType.trim().toLowerCase()) {
      case 'college':
        fill = BrandColors.momentumBlue;
        ink = BrandColors.unityBlue;
        break;
      case 'highschool':
        fill = BrandColors.sunriseGold;
        ink = BrandColors.unityBlue;
        break;
      case 'county':
        fill = BrandColors.unityBlue;
        ink = Colors.white;
        break;
      default:
        fill = Theme.of(context).colorScheme.surfaceContainerHighest;
        ink = Theme.of(context).colorScheme.onSurfaceVariant;
    }
    final archived = entry.stage == ChapterStage.archived;
    return ExcludeSemantics(
      child: Opacity(
        opacity: archived ? 0.5 : 1,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          padding: EdgeInsets.all(size * 0.16),
          decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              lettersFor(entry),
              style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: size * 0.36, letterSpacing: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Surfaces
// ---------------------------------------------------------------------------

/// The hub's card: surface fill, outlineVariant border, radius 20, and a
/// gentle lift on hover when it is tappable.
class HubCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;
  final Color? color;

  const HubCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.semanticLabel,
    this.color,
  });

  @override
  State<HubCard> createState() => _HubCardState();
}

class _HubCardState extends State<HubCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(20);
    final tappable = widget.onTap != null;
    final content = Padding(padding: widget.padding, child: widget.child);

    Widget card = Material(
      color: widget.color ?? scheme.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      elevation: tappable && _hovered ? 6 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: tappable && _hovered ? scheme.outline : scheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: tappable
          ? InkWell(
              onTap: widget.onTap,
              onHover: (value) => setState(() => _hovered = value),
              borderRadius: radius,
              child: content,
            )
          : content,
    );

    if (widget.semanticLabel != null) {
      card = Semantics(button: tappable, label: widget.semanticLabel, child: card);
    }
    return card;
  }
}

/// Section title: icon and titleMedium w700, with an optional count and a
/// one-line description under it.
class HubSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final int? count;
  final String? description;

  const HubSectionTitle({
    super.key,
    required this.title,
    required this.icon,
    this.count,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                HubBadge(label: '$count'),
              ],
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description!,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// One tappable number in the stat band.
class HubStatTile extends StatelessWidget {
  final IconData icon;
  final HubTone tone;
  final String value;
  final String label;
  final String caption;
  final String semanticHint;
  final VoidCallback onTap;

  const HubStatTile({
    super.key,
    required this.icon,
    required this.tone,
    required this.value,
    required this.label,
    required this.caption,
    required this.semanticHint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = HubToneColors.of(context, tone);
    // The card's label already says the hint, so the tooltip is for the
    // pointer only.
    return Tooltip(
      message: semanticHint,
      excludeFromSemantics: true,
      child: HubCard(
        onTap: onTap,
        semanticLabel: '$label: $value. $caption. $semanticHint',
        padding: const EdgeInsets.all(16),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: colors.background, shape: BoxShape.circle),
                    child: Icon(icon, size: 20, color: colors.foreground),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, size: 20, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A friendly empty or error panel.
class HubMessagePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final HubTone tone;

  const HubMessagePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.tone = HubTone.info,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = HubToneColors.of(context, tone);
    return HubCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: colors.background, shape: BoxShape.circle),
            child: Icon(icon, size: 28, color: colors.foreground),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

/// A one-line warning on a tinted surface with a Retry, for data that is
/// partly missing.
class HubWarningStrip extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const HubWarningStrip({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = HubToneColors.of(context, HubTone.warning);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: Color.alphaBlend(colors.background, theme.colorScheme.surface),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 20, color: colors.foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(message, style: theme.textTheme.bodySmall?.copyWith(color: colors.foreground)),
            ),
          ),
          if (onRetry != null)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colors.foreground, minimumSize: const Size(0, 44)),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

/// Shown when charter applications could not be read.
const String hubApplicationsFailedMessage =
    "Couldn't load charter applications just now. Chapters still show, but application details may be missing.";

// ---------------------------------------------------------------------------
// Restore
// ---------------------------------------------------------------------------

/// Where a restore puts [chapter]: chartered chapters become active again,
/// the rest go back to charter review.
String chapterRestoreOutcome(Chapter chapter) =>
    chapter.isChartered ? 'It becomes an active chapter again.' : 'It goes back to charter review.';

/// "Restore to charter review" or "Restore as active chapter".
String chapterRestoreLabel(Chapter chapter) =>
    chapter.isChartered ? 'Restore as active chapter' : 'Restore to charter review';

/// Asks before a restore. True when the user confirms.
Future<bool> confirmChapterRestore(BuildContext context, Chapter chapter) async {
  final name = chapter.chapterName.trim();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(name.isEmpty ? 'Restore this chapter?' : 'Restore "$name"?'),
      content: Text(chapterRestoreOutcome(chapter)),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Restore')),
      ],
    ),
  );
  return confirmed ?? false;
}
