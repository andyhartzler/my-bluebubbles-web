import 'package:flutter/material.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/chapter.dart';
import 'package:bluebubbles/screens/crm/chapter_detail_screen.dart';
import 'package:bluebubbles/services/crm/chapter_repository.dart';

import 'chapters_hub_screen.dart';

/// The one way into chapters from anywhere in the app, so every link
/// behaves the same: a chapter name opens that chapter, "all chapters"
/// opens the Chapters section.
class ChapterNavigation {
  ChapterNavigation._();

  /// Set by the home shell while it is mounted. Switches the shell to the
  /// Chapters section and returns true, or returns false when the shell
  /// can't show it (the hub then opens as its own page instead).
  static bool Function()? showChaptersSection;

  /// The tab the next visit to the Chapters section should land on. The
  /// embedded hub reads it when it mounts and whenever it changes, then
  /// clears it.
  static final ValueNotifier<ChaptersHubTab?> requestedTab = ValueNotifier<ChaptersHubTab?>(null);

  static final Set<String> _opening = <String>{};

  /// Chapter pages open on the root navigator so a link inside a side panel
  /// or split pane still opens a full page, like the app's other profiles.
  static Future<void> openChapter(BuildContext context, Chapter chapter) {
    return Navigator.of(context, rootNavigator: true).push(
      ThemeSwitcher.buildPageRoute(
        builder: (_) => TitleBarWrapper(child: ChapterDetailScreen(chapter: chapter)),
      ),
    );
  }

  /// Opens the chapter a member typed, matching case and spacing loosely.
  /// Shows a short note when no chapter has that name, or when the lookup
  /// fails. A second tap while the first is still looking does nothing.
  static Future<void> openChapterByName(BuildContext context, String chapterName) async {
    final key = chapterName.trim().toLowerCase();
    if (key.isEmpty || !_opening.add(key)) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final Chapter? chapter;
      try {
        chapter = await ChapterRepository().getChapterByName(chapterName);
      } catch (_) {
        messenger?.showSnackBar(
          const SnackBar(content: Text("Couldn't open that chapter. Check your connection and try again.")),
        );
        return;
      }
      if (!context.mounted) return;
      if (chapter == null) {
        messenger?.showSnackBar(
          SnackBar(content: Text('No chapter named "${chapterName.trim()}" yet.')),
        );
        return;
      }
      await openChapter(context, chapter);
    } finally {
      _opening.remove(key);
    }
  }

  /// Takes the person to the Chapters section on the given tab. Inside the
  /// app this switches the main section and closes any pages stacked on top,
  /// so repeated links never pile up hub pages. Without the shell it opens
  /// the hub as a page.
  static Future<void> openHub(
    BuildContext context, {
    ChaptersHubTab initialTab = ChaptersHubTab.directory,
  }) async {
    final showSection = showChaptersSection;
    if (showSection != null) {
      final navigator = Navigator.of(context, rootNavigator: true);
      requestedTab.value = initialTab;
      if (showSection()) {
        navigator.popUntil((route) => route.isFirst);
        return;
      }
      requestedTab.value = null;
    }
    await Navigator.of(context, rootNavigator: true).push(
      ThemeSwitcher.buildPageRoute(
        builder: (_) => TitleBarWrapper(
          child: ChaptersHubScreen(embed: false, initialTab: initialTab),
        ),
      ),
    );
  }
}

/// Makes a screen's own chip, pill or label open a chapter, for places where
/// a [ChapterLink] would clash with the surface it sits on. The child keeps
/// its look; this adds the tap, a hand cursor, an "Open chapter" tooltip,
/// link semantics, keyboard focus and a hover tint drawn over the child (so
/// it shows on solid fills), and pads the hit area to [minHeight] without
/// moving the child. Pass [chapter] when the screen already has the row, to
/// skip the lookup by name.
class ChapterTapTarget extends StatefulWidget {
  final String chapterName;
  final Chapter? chapter;
  final Widget child;
  final BorderRadius borderRadius;
  final double minHeight;

  const ChapterTapTarget({
    super.key,
    required this.chapterName,
    required this.child,
    this.chapter,
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
    this.minHeight = 44,
  });

  @override
  State<ChapterTapTarget> createState() => _ChapterTapTargetState();
}

class _ChapterTapTargetState extends State<ChapterTapTarget> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  void _open() {
    final known = widget.chapter;
    if (known != null) {
      ChapterNavigation.openChapter(context, known);
    } else {
      ChapterNavigation.openChapterByName(context, widget.chapterName);
    }
  }

  /// A tint that shows on both the navy headers and the light pills: light
  /// over a dark theme, the brand navy over a light one.
  Color _tintColor(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? Colors.white.withValues(alpha: 0.16)
        : BrandColors.unityBlue.withValues(alpha: 0.10);
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.chapter?.chapterName ?? widget.chapterName).trim();
    final tint = _hovered || _pressed;
    return Semantics(
      link: true,
      label: 'Open chapter $name',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Open chapter',
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: _open,
            onHover: (v) => setState(() => _hovered = v),
            onHighlightChanged: (v) => setState(() => _pressed = v),
            onFocusChange: (v) => setState(() => _focused = v),
            borderRadius: widget.borderRadius,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: widget.minHeight),
              child: Align(
                widthFactor: 1,
                heightFactor: 1,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    color: tint ? _tintColor(context) : null,
                    borderRadius: widget.borderRadius,
                    border: _focused ? Border.all(color: BrandColors.sunriseGold, width: 2) : null,
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
