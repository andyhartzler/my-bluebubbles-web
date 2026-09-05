import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

// ═════════════════════════════════════════════════════════════
//  MEMBER PROFILE SURFACE: the one place the profile's tokens live.
//
//  The member profile sits on BrandedBackground, which is NOT a light ground:
//  its asset runs #5BBBEB at the left edge to #465469 at the right under an
//  18 percent white scrim, and no single ink passes at both ends (measured in
//  activity_detail_screen.dart). So every piece of profile content sits on an
//  opaque white sheet, and every ink below is measured against WHITE or against
//  the one solid navy band at the top of the first sheet.
//
//  Every ratio in this file is either quoted from a measurement already in the
//  codebase (marked documented) or computed for the profile design with the
//  WCAG 2.1 relative luminance formula on the composited hex values shown
//  (marked computed). Alpha fills are composited against the named ground
//  before measuring, because an alpha fill's real contrast is unknowable
//  otherwise. Do not add a ratio here without computing it.
//
//    unityBlue on white ................................ 12.51:1 (computed)
//    unityBlue 0.70 on white (#687085) ................. 4.95:1 (documented)
//    unityBlue on unityBlue 0.06 over white (#F2F3F5) .. 11.27:1 (computed)
//    unityBlue 0.60 border on white (#7D8597) .......... 3.70:1 (computed)
//    white on unityBlue ................................ 12.51:1 (documented)
//    white70 on unityBlue .............................. 7.03:1 (documented)
//    white on white 0.15 over unityBlue (#47526B) ...... 7.81:1 (computed)
//    unityBlue on sunriseGold .......................... 7.17:1 (documented)
//    white on #B91C1C .................................. 6.47:1 (computed)
//    #B91C1C on white .................................. 6.47:1 (computed)
//    #B91C1C on error 0.12 over white (#FDE9E9) ........ 5.55:1 (computed)
//    unityBlue on #FDE9E9 .............................. 10.73:1 (computed)
//    #92400E on warning 0.14 over white (#FEF1DD) ...... 6.36:1 (computed)
//    unityBlue on #FEF1DD .............................. 11.22:1 (computed)
//
//  Forbidden here, with the measured reason: white on momentumBlue is 2.75:1
//  (documented), momentumBlue text on white is 2.75:1 (computed), sunriseGold
//  text on white is 1.74:1 (computed), and BrandColors.error as a text ground
//  puts white below 3:1. Gold is a FILL under unityBlue ink or a MARK, never a
//  text colour on white, and momentumBlue carries no text anywhere on these
//  screens.
// ═════════════════════════════════════════════════════════════
class ProfileTokens {
  ProfileTokens._();

  /// Primary ink on the white sheet. 12.51:1 (computed).
  static const Color ink = BrandColors.unityBlue;

  /// Labels, overlines, captions and the copy glyph. Composites to #687085 on
  /// white, 4.95:1 (documented in activity_detail_screen.dart), which clears
  /// the 4.5:1 normal-text bar and the 3:1 graphic bar.
  static final Color inkMuted = BrandColors.unityBlue.withValues(alpha: 0.70);

  /// Quote block and chip fill. Composites to #F2F3F5 on white; unityBlue on
  /// it is 11.27:1 (computed).
  static final Color fill = BrandColors.unityBlue.withValues(alpha: 0.06);

  /// Resting input border. Composites to #7D8597 on white, 3.70:1 (computed),
  /// which clears the 3:1 bar for a user interface component.
  static final Color border = BrandColors.unityBlue.withValues(alpha: 0.60);

  /// Hairline between sections. Decorative, no contrast requirement; 1.24:1
  /// for the record (computed).
  static final Color hairline = BrandColors.unityBlue.withValues(alpha: 0.12);

  /// The text-safe red. White on it is 6.47:1 and it on white is 6.47:1, both
  /// computed. BrandColors.error (#EF4444) is NOT used as a text ground.
  static const Color danger = Color(0xFFB91C1C);

  /// Cascade banner ink. 6.36:1 on the composited banner fill (computed).
  static const Color cascadeInk = Color(0xFF92400E);

  /// Cascade banner fill: warning at 0.14 over white, composited #FEF1DD.
  static final Color cascadeFill = BrandColors.warning.withValues(alpha: 0.14);

  /// Error banner fill: error at 0.12 over white, composited #FDE9E9.
  static final Color errorFill = BrandColors.error.withValues(alpha: 0.12);

  /// Header band and the primary Save button. White on it is 12.51:1
  /// (documented).
  static const Color band = BrandColors.unityBlue;

  /// The emphasis pair: sunriseGold fill under unityBlue ink, 7.17:1
  /// (documented). The ONLY filled pair on these screens that may carry a
  /// label.
  static const Color emphasisFill = BrandColors.sunriseGold;
  static const Color onEmphasis = BrandColors.unityBlue;

  /// Row fill on the navy band, white ink on it. Composites to #47526B; white
  /// on it is 7.81:1 (computed).
  static final Color bandRow = Colors.white.withValues(alpha: 0.15);

  static const double sheetRadius = 16;
  static const double blockRadius = 10;
  static const double chipRadius = 8;
  static const double pillRadius = 6;
  static const double maxSheetWidth = 1120;

  /// Below this inner width, fields never flow two-up.
  static const double twoUpMinWidth = 560;
}

/// Type scale for the profile sheets and the submission view. One scale, so
/// the two surfaces cannot drift apart.
class ProfileText {
  ProfileText._();

  static const TextStyle headerName = TextStyle(
    color: Colors.white,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.15,
  );

  /// White70 on unityBlue, 7.03:1 (documented).
  static const TextStyle headerLine = TextStyle(
    color: Colors.white70,
    fontSize: 14,
  );

  static final TextStyle overline = TextStyle(
    color: ProfileTokens.inkMuted,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.6,
  );

  static final TextStyle label = TextStyle(
    color: ProfileTokens.inkMuted,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
  );

  static const TextStyle value = TextStyle(
    color: ProfileTokens.ink,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  static const TextStyle longText = TextStyle(
    color: ProfileTokens.ink,
    fontSize: 14,
    height: 1.45,
  );

  static const TextStyle chip = TextStyle(
    color: ProfileTokens.ink,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle pill = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.0,
  );

  static const TextStyle button = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  static final TextStyle caption = TextStyle(
    color: ProfileTokens.inkMuted,
    fontSize: 12,
  );

  static const TextStyle link = TextStyle(
    color: ProfileTokens.ink,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  /// R1 fact value, unityBlue 13 w600, 12.51:1 (computed).
  static const TextStyle fact = TextStyle(
    color: ProfileTokens.ink,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle statValue = TextStyle(
    color: ProfileTokens.ink,
    fontSize: 22,
    fontWeight: FontWeight.w800,
  );
}

/// The opaque ground every piece of profile content sits on. White, radius 16,
/// elevation 4, clipped so the navy header band can fuse to its top edge.
/// Built the same way as outreachStateSurface in activity_detail_screen.dart
/// and for the same reason, but that helper centres a 420 px card, which is
/// wrong for a full-width sheet, so this is its own widget.
class ProfileSheet extends StatelessWidget {
  const ProfileSheet({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(ProfileTokens.sheetRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Section header: a 4 by 20 gold rule (a mark, not text: the title carries
/// the meaning), a 12 px gap, the overline title, then whatever sits at the
/// trailing edge (edit pencil or caption).
Widget profileSectionHeader({
  required String title,
  Widget? trailing,
  bool first = false,
}) {
  return Container(
    decoration: first
        ? null
        : BoxDecoration(
            border: Border(top: BorderSide(color: ProfileTokens.hairline)),
          ),
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: BrandColors.sunriseGold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title.toUpperCase(), style: ProfileText.overline),
        ),
        if (trailing != null) trailing,
      ],
    ),
  );
}

/// The pencil at the trailing end of a section header. unityBlue at 0.70,
/// 4.95:1, which clears the 3:1 graphic bar.
Widget profileEditButton({required String section, required VoidCallback? onPressed}) {
  return IconButton(
    tooltip: 'Edit $section',
    icon: Icon(Icons.edit_outlined, size: 20, color: ProfileTokens.inkMuted),
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
  );
}

/// Section body padding: 0 24 20 24.
Widget profileSectionBody({required Widget child}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
    child: child,
  );
}

/// Label over value, the shape AnswerDisplay uses in the forms feature, in the
/// profile's own inks. Copy and link affordances ride on the whole value row.
class ProfileField extends StatelessWidget {
  const ProfileField({
    super.key,
    required this.label,
    required this.value,
    this.onCopy,
    this.link,
    this.onOpenLink,
  });

  final String label;
  final String value;

  /// When set, a 16 px copy glyph sits at the value's trailing edge and the
  /// whole row is tappable.
  final VoidCallback? onCopy;

  /// When set, the value is underlined in unityBlue and opens the link.
  final Uri? link;
  final void Function(Uri)? onOpenLink;

  @override
  Widget build(BuildContext context) {
    final isLink = link != null && onOpenLink != null;
    final valueStyle = isLink
        ? ProfileText.value.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: ProfileTokens.ink,
          )
        : ProfileText.value;

    Widget valueWidget = isLink
        ? Text(value, style: valueStyle)
        : SelectableText(value, style: valueStyle);

    Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: valueWidget),
        if (onCopy != null) ...[
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.copy_outlined, size: 16, color: ProfileTokens.inkMuted),
          ),
        ],
      ],
    );

    final tap = isLink ? () => onOpenLink!(link!) : onCopy;
    if (tap != null) {
      // Material(transparent) > InkWell or the ripple is lost on the sheet.
      row = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ProfileTokens.pillRadius),
          onTap: tap,
          child: row,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: ProfileText.label),
          const SizedBox(height: 4),
          row,
        ],
      ),
    );
  }
}

/// Long answers as a quote block: unityBlue 0.06 fill, 3 px gold left border,
/// collapsed to six lines past 320 characters with a Show more link. The link
/// is unityBlue 13 w600, 12.51:1.
class ProfileLongText extends StatefulWidget {
  const ProfileLongText({super.key, this.label, required this.value});

  /// Omitted when the block sits directly under a section header that already
  /// names it (Notes).
  final String? label;
  final String value;

  static const int collapseThreshold = 320;

  @override
  State<ProfileLongText> createState() => _ProfileLongTextState();
}

class _ProfileLongTextState extends State<ProfileLongText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final collapsible = widget.value.length > ProfileLongText.collapseThreshold;
    final collapsed = collapsible && !_expanded;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label != null) ...[
            Text(widget.label!.toUpperCase(), style: ProfileText.label),
            const SizedBox(height: 6),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: ProfileTokens.fill,
              borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
              border: const Border(
                left: BorderSide(color: BrandColors.sunriseGold, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  widget.value,
                  style: ProfileText.longText,
                  maxLines: collapsed ? 6 : null,
                ),
                if (collapsible) ...[
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(ProfileTokens.pillRadius),
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Text(
                          _expanded ? 'Show less' : 'Show more',
                          style: ProfileText.link,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-mode chips: unityBlue 0.06 fill, unityBlue 12 w600 ink, radius 8.
/// Items in [locked] carry a lock glyph.
Widget profileChips(
  List<String> items, {
  required String label,
  Set<String> locked = const {},
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: ProfileText.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ProfileTokens.fill,
                  borderRadius: BorderRadius.circular(ProfileTokens.chipRadius),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (locked.contains(item)) ...[
                      const Icon(Icons.lock_outline, size: 12, color: ProfileTokens.ink),
                      const SizedBox(width: 4),
                    ],
                    Text(item, style: ProfileText.chip),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

/// One decoration for every profile input. Resting border unityBlue 0.60
/// (3.70:1, computed), focused border unityBlue 2 px (12.51:1). Gold is NOT
/// used for focus: gold on white is 1.74:1 (computed) and fails the component
/// bar.
InputDecoration profileInput(String label, {String? helper, Widget? suffixIcon}) {
  return InputDecoration(
    labelText: label,
    helperText: helper,
    helperMaxLines: 3,
    hintText: 'Not provided',
    filled: true,
    fillColor: Colors.white,
    labelStyle: TextStyle(color: ProfileTokens.inkMuted, fontSize: 12),
    floatingLabelStyle: TextStyle(color: ProfileTokens.inkMuted, fontSize: 12),
    helperStyle: TextStyle(color: ProfileTokens.inkMuted, fontSize: 12),
    hintStyle: TextStyle(color: ProfileTokens.inkMuted, fontSize: 15),
    errorStyle: const TextStyle(color: ProfileTokens.danger, fontSize: 12),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    suffixIcon: suffixIcon,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
      borderSide: BorderSide(color: ProfileTokens.border, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
      borderSide: const BorderSide(color: ProfileTokens.ink, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
      borderSide: const BorderSide(color: ProfileTokens.danger, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
      borderSide: const BorderSide(color: ProfileTokens.danger, width: 2),
    ),
  );
}

/// Text style for typed input: unityBlue 15, 12.51:1.
const TextStyle profileInputText = TextStyle(color: ProfileTokens.ink, fontSize: 15);

/// The date picker in unityBlue and white rather than the ambient theme, so
/// both directions measure 12.51:1.
ThemeData profileDatePickerTheme(BuildContext context) {
  return Theme.of(context).copyWith(
    colorScheme: const ColorScheme.light(
      primary: BrandColors.unityBlue,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: BrandColors.unityBlue,
    ),
  );
}

/// Style for the tri-state SegmentedButton. Selected: unityBlue fill, white
/// label (12.51:1). Unselected: white fill, unityBlue label, unityBlue 0.60
/// border (3.70:1). Set explicitly so no Theme colour reaches it.
ButtonStyle profileSegmentedStyle() {
  return ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      return states.contains(WidgetState.selected) ? ProfileTokens.ink : Colors.white;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      return states.contains(WidgetState.selected) ? Colors.white : ProfileTokens.ink;
    }),
    side: WidgetStatePropertyAll(BorderSide(color: ProfileTokens.border)),
    textStyle: const WidgetStatePropertyAll(ProfileText.button),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(ProfileTokens.blockRadius)),
    ),
  );
}

/// Flows a section's fields: consecutive short fields wrap two per row at
/// (width - 16) / 2 once the inner width reaches 560; a long field breaks the
/// run and takes the full width. Under 560 everything stacks. This is the
/// grouping rule SectionCard._contentBlocks uses in the forms feature.
class ProfileFieldFlow extends StatelessWidget {
  const ProfileFieldFlow({super.key, required this.items});

  final List<ProfileFlowItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final twoUp = width >= ProfileTokens.twoUpMinWidth;
        if (!twoUp) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final item in items) item.child],
          );
        }

        final halfWidth = (width - 16) / 2;
        final blocks = <Widget>[];
        var run = <Widget>[];

        void flushRun() {
          if (run.isEmpty) return;
          blocks.add(
            Wrap(
              spacing: 16,
              children: [
                for (final child in run) SizedBox(width: halfWidth, child: child),
              ],
            ),
          );
          run = <Widget>[];
        }

        for (final item in items) {
          if (item.isLong) {
            flushRun();
            blocks.add(item.child);
          } else {
            run.add(item.child);
          }
        }
        flushRun();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: blocks,
        );
      },
    );
  }
}

class ProfileFlowItem {
  const ProfileFlowItem(this.child, {this.isLong = false});

  final Widget child;
  final bool isLong;
}

/// Cascade banner above a class B or committee section's inputs: warning at
/// 0.14 over white (#FEF1DD), the word CASCADES in #92400E (6.36:1, computed),
/// the sentence in unityBlue (11.22:1, computed).
Widget profileCascadeBanner(List<String> lines) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: ProfileTokens.cascadeFill,
      borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 18, color: ProfileTokens.cascadeInk),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CASCADES',
                style: TextStyle(
                  color: ProfileTokens.cascadeInk,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              for (final line in lines)
                Text(
                  line,
                  style: const TextStyle(color: ProfileTokens.ink, fontSize: 13, height: 1.4),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Inline save failure: error at 0.12 over white (#FDE9E9), title in #B91C1C
/// 13 w700 (5.55:1, computed), the exception text in unityBlue 12 (10.73:1,
/// computed), selectable so the exec can copy it.
Widget profileErrorBanner({required String title, required String message}) {
  return Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: ProfileTokens.errorFill,
      borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, size: 18, color: ProfileTokens.danger),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: ProfileTokens.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                message,
                style: const TextStyle(color: ProfileTokens.ink, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

enum ProfilePillStyle {
  /// sunriseGold fill, unityBlue ink. 7.17:1 (documented).
  emphasis,

  /// #B91C1C fill, white ink. 6.47:1 (computed). Opaque, so the band does not
  /// matter.
  danger,

  /// white 0.15 fill over the navy band, white ink. 7.81:1 (computed).
  soft,
}

/// Status pill on the header band: 11 w800, letter spacing 1.0, radius 6,
/// padding 8 by 4.
class ProfilePill extends StatelessWidget {
  const ProfilePill({super.key, required this.label, required this.style});

  final String label;
  final ProfilePillStyle style;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color ink;
    switch (style) {
      case ProfilePillStyle.emphasis:
        fill = ProfileTokens.emphasisFill;
        ink = ProfileTokens.onEmphasis;
        break;
      case ProfilePillStyle.danger:
        fill = ProfileTokens.danger;
        ink = Colors.white;
        break;
      case ProfilePillStyle.soft:
        fill = ProfileTokens.bandRow;
        ink = Colors.white;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(ProfileTokens.pillRadius),
      ),
      child: Text(label.toUpperCase(), style: ProfileText.pill.copyWith(color: ink)),
    );
  }
}

/// Action pill on the header band: 36 px, white 0.15 fill, white icon 18 and
/// white label 13 w600, radius 10, 7.81:1 (computed). Disabled: white 0.06
/// fill, white 0.45 ink; that pair composites to 3.49:1 (computed), which is
/// below the text bar, and is acceptable only because WCAG exempts inactive
/// controls. The tooltip carries the reason so the state is never a mystery.
class ProfileActionPill extends StatelessWidget {
  const ProfileActionPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.disabledReason,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final String? disabledReason;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final ink = enabled ? Colors.white : Colors.white.withValues(alpha: 0.45);
    final fill = enabled ? ProfileTokens.bandRow : Colors.white.withValues(alpha: 0.06);

    final pill = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
        onTap: enabled ? onPressed : null,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(ink),
                  ),
                )
              else
                Icon(icon, size: 18, color: ink),
              const SizedBox(width: 8),
              Text(label, style: ProfileText.button.copyWith(color: ink)),
            ],
          ),
        ),
      ),
    );

    if (!enabled && disabledReason != null) {
      return Tooltip(message: disabledReason!, child: pill);
    }
    return pill;
  }
}

/// One "LABEL value" fact for the R1 status strip.
Widget profileFact(String label, String value) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text(label.toUpperCase(), style: ProfileText.label),
      const SizedBox(width: 6),
      Text(value, style: ProfileText.fact),
    ],
  );
}

/// The Cancel and Save pair at the foot of a section in edit mode. Cancel is a
/// TextButton in unityBlue; Save is a FilledButton in unityBlue with white
/// ink (12.51:1). Never gold for the primary button on white: gold carries no
/// readable ink on a white page except unityBlue, and the header already owns
/// the gold accent.
Widget profileEditActions({
  required VoidCallback? onCancel,
  required VoidCallback? onSave,
  required bool saving,
}) {
  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: saving ? null : onCancel,
          style: TextButton.styleFrom(
            foregroundColor: ProfileTokens.ink,
            textStyle: ProfileText.button,
          ),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: saving ? null : onSave,
          style: FilledButton.styleFrom(
            backgroundColor: ProfileTokens.ink,
            foregroundColor: Colors.white,
            disabledBackgroundColor: ProfileTokens.fill,
            disabledForegroundColor: ProfileTokens.inkMuted,
            textStyle: ProfileText.button,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
            ),
          ),
          child: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Save'),
        ),
      ],
    ),
  );
}

/// The "+ Section" chip at the foot of Sheet 1 for an omitted section. Chip
/// fill with unityBlue ink and a unityBlue 0.60 border, so it reads as a
/// control rather than a value.
Widget profileAddChip({required String title, required VoidCallback onTap}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(ProfileTokens.chipRadius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: ProfileTokens.fill,
          borderRadius: BorderRadius.circular(ProfileTokens.chipRadius),
          border: Border.all(color: ProfileTokens.border),
        ),
        child: Text('+ $title', style: ProfileText.chip),
      ),
    ),
  );
}
