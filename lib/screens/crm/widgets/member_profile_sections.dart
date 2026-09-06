import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

// ═════════════════════════════════════════════════════════════
//  MEMBER PROFILE SURFACE: the one place the profile's tokens live.
//
//  The profile is built in the Slack management page's idiom. Every surface is
//  a gradient card running BrandColors.tileGradient (unityBlue #273351 to
//  tileGradientEnd #1C7DAB) top left to bottom right, radius 16, elevation 4,
//  on BrandedBackground. There are no white sheets and no navy ink.
//
//  THE ONE TEXT RULE. Any text that must be read on a gradient card is FULL
//  WHITE. White measures 12.51:1 on unityBlue, 7.59:1 at the gradient midpoint
//  (#22587E) and 4.59:1 on tileGradientEnd, so it clears 4.5:1 at every point
//  on the card. Alpha on readable text is forbidden: white at 0.90 over the
//  light end is 4.04:1 and white at 0.70 is 3.08:1, both failures. Hierarchy
//  is carried by SIZE, WEIGHT and LETTER SPACING only.
//
//  FILLS THAT CARRY TEXT ARE SOLID. A translucent white behind text fails
//  toward the light end (white on white 0.10 over tileGradientEnd is 3.87:1),
//  so every block, input, chip and pill that carries text is either solid
//  unityBlue under white (12.51:1) or solid sunriseGold under unityBlue
//  (7.17:1, the emphasis pair), and the one error red is solid #B91C1C under
//  white (6.47:1). Because the fill is solid, its ratio is a property of the
//  fill and not of where the element sits on the gradient.
//
//  GOLD IS A FILL OR A RING, NEVER TEXT ON THE CARD. sunriseGold against
//  unityBlue is 7.17:1 but against tileGradientEnd it is only 2.63:1, so gold
//  text or a lone gold rule on the card fails toward the light end. Gold is
//  used as a fill under unityBlue ink, as the avatar ring, and as the focus
//  ring around a solid unityBlue field, where it is measured against the fill
//  it encloses (7.17:1).
//
//  Every ratio in this file was computed with the WCAG 2.1 relative luminance
//  formula on the composited hex values shown. Alpha fills are composited over
//  the REAL parent fill before measuring. Do not add a ratio here without
//  computing it.
//
//    white on unityBlue (#273351) ....................... 12.51:1
//    white on gradient midpoint (#22587E) ................ 7.59:1
//    white on tileGradientEnd (#1C7DAB) .................. 4.59:1
//    unityBlue on sunriseGold ............................ 7.17:1
//    sunriseGold ring vs unityBlue field fill ............ 7.17:1
//    white on #B91C1C .................................... 6.47:1
//    white 0.70 over unityBlue (#BEC2CB) on unityBlue .... 7.01:1  (input hint,
//                                                           solid fill only)
//    white icon on white 0.20 over tileGradientEnd ....... 3.26:1  (graphic bar)
//
//  Decorative only, below every bar and used where nothing has to be read:
//
//    white 0.15 over unityBlue (#47526B) vs unityBlue .... 1.60:1  (hairline)
//    white 0.15 over tileGradientEnd (#3E90B8) vs end .... 1.29:1  (hairline)
//    white 0.12 fill under white 0.45 ink, on end ........ 1.90:1  (disabled)
//    unityBlue block edge vs tileGradientEnd ............. 2.72:1  (blocks get a
//                                                           white outline)
//
//  Forbidden here, with the measured reason: white70 and white60 on the card
//  (3.08:1 and worse at the light end), sunriseGold text on the card (2.63:1
//  at the light end), translucent white behind text (3.87:1 at the light end),
//  and BrandColors.error (#EF4444) as a text ground (white on it is under
//  4.5:1). Never Theme.of(context) for a colour on these surfaces.
// ═════════════════════════════════════════════════════════════
class ProfileTokens {
  ProfileTokens._();

  /// Primary ink on the gradient card. Full white, 12.51:1 to 4.59:1 across
  /// the card.
  static const Color ink = Colors.white;

  /// Secondary ink is ALSO full white. The name survives for consumers; the
  /// hierarchy it used to carry with alpha is now carried by size and weight.
  static const Color inkMuted = Colors.white;

  /// Solid fill under white text: blocks, inputs, chips, activity rows. White
  /// on it is 12.51:1 wherever the block sits.
  static const Color fill = BrandColors.unityBlue;

  /// Solid white outline on a unityBlue block or input, so the block keeps an
  /// edge at the top left of the card where fill and card are the same colour.
  /// 12.51:1 against the fill it encloses, 4.59:1 against the light end.
  static const Color border = Colors.white;

  /// Row separators and decorative rules. White 0.15 over the gradient,
  /// 1.60:1 to 1.29:1. Nothing is read against it.
  static final Color hairline = Colors.white.withValues(alpha: 0.15);

  /// The text-safe red. White on it is 6.47:1 (computed). Opaque, so the
  /// card position does not matter. BrandColors.error is NOT a text ground.
  static const Color danger = Color(0xFFB91C1C);

  /// Cascade banner: sunriseGold fill under unityBlue ink, 7.17:1.
  static const Color cascadeInk = BrandColors.unityBlue;
  static const Color cascadeFill = BrandColors.sunriseGold;

  /// Error banner fill, solid #B91C1C under white ink, 6.47:1.
  static const Color errorFill = danger;

  /// The submission view's header band and the primary dialog ground. White
  /// on it is 12.51:1.
  static const Color band = BrandColors.unityBlue;

  /// The emphasis pair: sunriseGold fill under unityBlue ink, 7.17:1. Action
  /// pills, edit pencils, the Save button and the active state all use it.
  static const Color emphasisFill = BrandColors.sunriseGold;
  static const Color onEmphasis = BrandColors.unityBlue;

  /// Soft pill fill. Was translucent; now solid unityBlue with a white
  /// outline, 12.51:1 under white.
  static const Color bandRow = BrandColors.unityBlue;

  /// Icon tile behind a section or stat icon. Solid unityBlue, white icon on
  /// it 12.51:1, with a hairline outline for its edge.
  static const Color tile = BrandColors.unityBlue;

  /// Disabled control fill and ink. White 0.12 under white 0.45 composites to
  /// 1.90:1 at the light end, which is below every bar and is acceptable only
  /// because WCAG exempts inactive controls. The tooltip carries the reason.
  static final Color disabledFill = Colors.white.withValues(alpha: 0.12);
  static final Color disabledInk = Colors.white.withValues(alpha: 0.45);

  static const double sheetRadius = 16;
  static const double blockRadius = 10;
  static const double tileRadius = 10;
  static const double chipRadius = 8;
  static const double pillRadius = 6;

  /// Page content width. The two-column section grid needs 1100 to open.
  static const double maxSheetWidth = 1200;

  /// Below this inner width, fields never flow two-up.
  static const double twoUpMinWidth = 560;

  /// At and above this page width the section cards run in two columns.
  static const double gridMinWidth = 1100;

  /// Card padding and the gap between cards. Let it breathe.
  static const double cardPadding = 24;
  static const double cardGap = 24;
}

/// Type scale for the profile cards and the submission view. One scale, so
/// the two surfaces cannot drift apart. Every style is full white; hierarchy
/// is size, weight and letter spacing.
class ProfileText {
  ProfileText._();

  /// The person is the headline.
  static const TextStyle headerName = TextStyle(
    color: Colors.white,
    fontSize: 34,
    fontWeight: FontWeight.w800,
    height: 1.1,
  );

  /// The one meta line under the name (joined date, county, title).
  static const TextStyle headerLine = TextStyle(
    color: Colors.white,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Section title in a card header.
  static const TextStyle sectionTitle = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  /// Kept for consumers that used the old overline; it is now the field
  /// label scale.
  static const TextStyle overline = TextStyle(
    color: Colors.white,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );

  /// Field label: 11 w700 white, uppercase by the caller, letter spacing 1.2.
  static const TextStyle label = TextStyle(
    color: Colors.white,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );

  /// Field value: 17 w500 white.
  static const TextStyle value = TextStyle(
    color: Colors.white,
    fontSize: 17,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Long answers inside a quote block.
  static const TextStyle longText = TextStyle(
    color: Colors.white,
    fontSize: 15,
    height: 1.5,
  );

  /// Chip label. The container sets the colour: white on unityBlue or
  /// unityBlue on gold.
  static const TextStyle chip = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle pill = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.0,
  );

  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  /// Body and secondary copy: 15 w400 white. No alpha.
  static const TextStyle caption = TextStyle(
    color: Colors.white,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle link = TextStyle(
    color: Colors.white,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    decoration: TextDecoration.underline,
    decorationColor: Colors.white,
  );

  /// Fact value in the status strip.
  static const TextStyle fact = TextStyle(
    color: Colors.white,
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );

  /// Big number on a stat tile, the same scale BrandedStatCard uses.
  static const TextStyle statValue = TextStyle(
    color: Colors.white,
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );
}

/// The gradient card decoration every profile surface uses.
BoxDecoration profileCardDecoration({double radius = ProfileTokens.sheetRadius}) {
  return BrandCardDecoration.brandedCard(borderRadius: radius);
}

/// The gradient card every piece of profile content sits on. Radius 16,
/// elevation 4, clipped. Children own their padding. Built on Material rather
/// than BrandedCard so it carries no InkWell of its own.
class ProfileSheet extends StatelessWidget {
  const ProfileSheet({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 4,
      borderRadius: BorderRadius.circular(ProfileTokens.sheetRadius),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: profileCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// The Slack page's signature: a square tile behind an icon. Solid unityBlue
/// (white icon on it 12.51:1) with a hairline outline so its edge survives at
/// the top left of the card.
Widget profileIconTile(IconData icon, {double size = 40, double iconSize = 22}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: ProfileTokens.tile,
      borderRadius: BorderRadius.circular(ProfileTokens.tileRadius),
      border: Border.all(color: ProfileTokens.hairline),
    ),
    alignment: Alignment.center,
    child: Icon(icon, color: Colors.white, size: iconSize),
  );
}

/// Section header in the Slack idiom: icon tile, the 18 px title, and whatever
/// sits at the trailing edge (the gold edit pencil or a caption). [first] is
/// kept for callers and ignored: every section is its own card now.
Widget profileSectionHeader({
  required String title,
  Widget? trailing,
  bool first = false,
  IconData icon = Icons.article_outlined,
}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(
      ProfileTokens.cardPadding,
      ProfileTokens.cardPadding,
      ProfileTokens.cardPadding,
      16,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        profileIconTile(icon),
        const SizedBox(width: 14),
        Expanded(
          child: Text(title, style: ProfileText.sectionTitle),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing],
      ],
    ),
  );
}

/// The edit control at the trailing end of a section header: a small
/// sunriseGold pill carrying a unityBlue pencil, 7.17:1. Disabled: white 0.12
/// fill under white 0.45 ink, exempt as an inactive control.
Widget profileEditButton({required String section, required VoidCallback? onPressed}) {
  final enabled = onPressed != null;
  return Tooltip(
    message: 'Edit $section',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: enabled ? ProfileTokens.emphasisFill : ProfileTokens.disabledFill,
            borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.edit_outlined,
            size: 20,
            color: enabled ? ProfileTokens.onEmphasis : ProfileTokens.disabledInk,
          ),
        ),
      ),
    ),
  );
}

/// Section body padding: 0 24 24 24.
Widget profileSectionBody({required Widget child}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(
      ProfileTokens.cardPadding,
      0,
      ProfileTokens.cardPadding,
      ProfileTokens.cardPadding,
    ),
    child: child,
  );
}

/// One section as its own gradient card: header idiom, optional caption, body.
class ProfileSectionCard extends StatelessWidget {
  const ProfileSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
    this.caption,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  /// One line under the header, 15 white.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return ProfileSheet(
      children: [
        profileSectionHeader(title: title, icon: icon, trailing: trailing),
        profileSectionBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (caption != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(caption!, style: ProfileText.caption),
                ),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

/// Label over value, both full white. Copy and link affordances ride on the
/// whole value row. Rows are separated by ProfileFieldFlow's hairline, not by
/// this widget.
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

  /// When set, an 18 px copy glyph sits at the value's trailing edge and the
  /// whole row is tappable.
  final VoidCallback? onCopy;

  /// When set, the value is underlined in white and opens the link.
  final Uri? link;
  final void Function(Uri)? onOpenLink;

  @override
  Widget build(BuildContext context) {
    final isLink = link != null && onOpenLink != null;
    final valueStyle = isLink
        ? ProfileText.value.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: Colors.white,
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
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.copy_outlined, size: 18, color: Colors.white),
          ),
        ],
      ],
    );

    final tap = isLink ? () => onOpenLink!(link!) : onCopy;
    if (tap != null) {
      // Material(transparent) > InkWell or the ripple is lost on the gradient.
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: ProfileText.label),
          const SizedBox(height: 6),
          row,
        ],
      ),
    );
  }
}

/// Long answers as a quote block: solid unityBlue fill with a white outline
/// and a 3 px gold left rule, white 15 text (12.51:1), collapsed to six lines
/// past 320 characters with a Show more link.
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label != null) ...[
            Text(widget.label!.toUpperCase(), style: ProfileText.label),
            const SizedBox(height: 8),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            decoration: BoxDecoration(
              color: ProfileTokens.fill,
              borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
              border: Border(
                left: const BorderSide(color: BrandColors.sunriseGold, width: 3),
                top: BorderSide(color: ProfileTokens.hairline),
                right: BorderSide(color: ProfileTokens.hairline),
                bottom: BorderSide(color: ProfileTokens.hairline),
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
                  const SizedBox(height: 10),
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

/// One solid chip. unityBlue fill, white outline, white 13 w600 (12.51:1); or
/// the emphasis pair, sunriseGold under unityBlue (7.17:1), when [emphasis].
Widget profileChip(String text, {bool emphasis = false, IconData? icon}) {
  final ink = emphasis ? ProfileTokens.onEmphasis : Colors.white;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: emphasis ? ProfileTokens.emphasisFill : ProfileTokens.fill,
      borderRadius: BorderRadius.circular(ProfileTokens.chipRadius),
      border: emphasis ? null : Border.all(color: ProfileTokens.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: ink),
          const SizedBox(width: 6),
        ],
        Text(text, style: ProfileText.chip.copyWith(color: ink)),
      ],
    ),
  );
}

/// Read-mode chips under a label. Items in [locked] render as the emphasis
/// pair with a lock glyph: they are the ones this screen never edits.
Widget profileChips(
  List<String> items, {
  required String label,
  Set<String> locked = const {},
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: ProfileText.label),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              profileChip(
                item,
                emphasis: locked.contains(item),
                icon: locked.contains(item) ? Icons.lock_outline : null,
              ),
          ],
        ),
      ],
    ),
  );
}

/// One decoration for every profile input on a gradient card. Solid unityBlue
/// fill under white 17 text (12.51:1), solid white 1 px resting border (12.51:1
/// against the fill, 4.59:1 against the light end), sunriseGold 2 px focus
/// ring measured against the fill it encloses (7.17:1). Label, helper and
/// error text sit on the card and are full white; the hint sits INSIDE the
/// solid fill and is white 0.70, which composites to #BEC2CB on unityBlue,
/// 7.01:1. The error state is the gold ring plus a white 13 w700 message.
InputDecoration profileInput(String label, {String? helper, Widget? suffixIcon}) {
  OutlineInputBorder outline(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    helperText: helper,
    helperMaxLines: 3,
    hintText: 'Not provided',
    filled: true,
    fillColor: ProfileTokens.fill,
    labelStyle: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
    floatingLabelStyle: const TextStyle(
      color: Colors.white,
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
    ),
    helperStyle: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 17),
    errorStyle: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
    errorMaxLines: 3,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    suffixIcon: suffixIcon,
    suffixIconColor: Colors.white,
    enabledBorder: outline(ProfileTokens.border, 1),
    disabledBorder: outline(ProfileTokens.hairline, 1),
    focusedBorder: outline(BrandColors.sunriseGold, 2),
    errorBorder: outline(BrandColors.sunriseGold, 2),
    focusedErrorBorder: outline(BrandColors.sunriseGold, 2.5),
  );
}

/// Text style for typed input: white 17 on the solid unityBlue fill, 12.51:1.
const TextStyle profileInputText = TextStyle(
  color: Colors.white,
  fontSize: 17,
  fontWeight: FontWeight.w500,
);

/// The date picker is a dialog, not a card: unityBlue and white, so both
/// directions measure 12.51:1.
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

/// Style for the tri-state SegmentedButton. Selected: the emphasis pair,
/// sunriseGold under unityBlue (7.17:1). Unselected: solid unityBlue under
/// white (12.51:1) with a solid white outline. Set explicitly so no Theme
/// colour reaches it.
ButtonStyle profileSegmentedStyle() {
  return ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      return states.contains(WidgetState.selected)
          ? ProfileTokens.emphasisFill
          : ProfileTokens.fill;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      return states.contains(WidgetState.selected) ? ProfileTokens.onEmphasis : Colors.white;
    }),
    side: const WidgetStatePropertyAll(BorderSide(color: ProfileTokens.border)),
    textStyle: const WidgetStatePropertyAll(ProfileText.button),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(ProfileTokens.blockRadius)),
    ),
  );
}

/// Flows a section's fields into rows separated by a hairline Border (white
/// 0.15, decorative). Consecutive short fields pair up two per row once the
/// inner width reaches 560; a long field takes a row of its own. Under 560
/// everything stacks, one field per row.
class ProfileFieldFlow extends StatelessWidget {
  const ProfileFieldFlow({super.key, required this.items});

  final List<ProfileFlowItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoUp = constraints.maxWidth >= ProfileTokens.twoUpMinWidth;
        final rows = <Widget>[];
        var run = <Widget>[];

        void flushRun() {
          if (run.isEmpty) return;
          if (!twoUp) {
            rows.addAll(run);
          } else {
            for (var i = 0; i < run.length; i += 2) {
              final left = run[i];
              final right = i + 1 < run.length ? run[i + 1] : null;
              rows.add(
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 24),
                    Expanded(child: right ?? const SizedBox.shrink()),
                  ],
                ),
              );
            }
          }
          run = <Widget>[];
        }

        for (final item in items) {
          if (item.isLong) {
            flushRun();
            rows.add(item.child);
          } else {
            run.add(item.child);
          }
        }
        flushRun();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++)
              Container(
                decoration: i == rows.length - 1
                    ? null
                    : BoxDecoration(
                        border: Border(bottom: BorderSide(color: ProfileTokens.hairline)),
                      ),
                child: rows[i],
              ),
          ],
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

/// Cascade banner above a section's inputs in edit mode: solid sunriseGold
/// under unityBlue ink, 7.17:1 for the CASCADES word and every sentence.
Widget profileCascadeBanner(List<String> lines) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: ProfileTokens.cascadeFill,
      borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 20, color: ProfileTokens.cascadeInk),
        const SizedBox(width: 12),
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
              const SizedBox(height: 6),
              for (final line in lines)
                Text(
                  line,
                  style: const TextStyle(
                    color: ProfileTokens.cascadeInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Inline failure: solid #B91C1C under white, 6.47:1 for the title (15 w700)
/// and the exception text (14), which is selectable so the exec can copy it.
/// The hairline outline gives the block an edge near the card's dark end.
Widget profileErrorBanner({required String title, required String message}) {
  return Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: ProfileTokens.errorFill,
      borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
      border: Border.all(color: ProfileTokens.hairline),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, size: 20, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

enum ProfilePillStyle {
  /// sunriseGold fill, unityBlue ink. 7.17:1.
  emphasis,

  /// #B91C1C fill, white ink. 6.47:1. Opaque, so the card does not matter.
  danger,

  /// Solid unityBlue fill with a white outline, white ink. 12.51:1.
  soft,
}

/// Status pill: 11 w800, letter spacing 1.0, radius 6, padding 10 by 5.
class ProfilePill extends StatelessWidget {
  const ProfilePill({super.key, required this.label, required this.style});

  final String label;
  final ProfilePillStyle style;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color ink;
    Border? border;
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
        border = Border.all(color: ProfileTokens.border);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(ProfileTokens.pillRadius),
        border: border,
      ),
      child: Text(label.toUpperCase(), style: ProfileText.pill.copyWith(color: ink)),
    );
  }
}

/// Action pill: 44 px, sunriseGold fill, unityBlue icon 20 and label 14 w600
/// (7.17:1), radius 10. Disabled: white 0.12 fill under white 0.45 ink, which
/// composites to 1.90:1 at the light end and is acceptable only because WCAG
/// exempts inactive controls; the tooltip carries the reason.
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
    // A pill that is busy is doing the thing you asked, so it keeps the
    // emphasis pair and its spinner reads at 7.17:1. Only a pill with nothing
    // to do reads as disabled. Tapping is blocked either way.
    final active = onPressed != null || busy;
    final tappable = onPressed != null && !busy;
    final ink = active ? ProfileTokens.onEmphasis : ProfileTokens.disabledInk;
    final fill = active ? ProfileTokens.emphasisFill : ProfileTokens.disabledFill;

    final pill = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
        onTap: tappable ? onPressed : null,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(ink),
                  ),
                )
              else
                Icon(icon, size: 20, color: ink),
              const SizedBox(width: 10),
              Text(label, style: ProfileText.button.copyWith(color: ink)),
            ],
          ),
        ),
      ),
    );

    if (!active && disabledReason != null) {
      return Tooltip(message: disabledReason!, child: pill);
    }
    return pill;
  }
}

/// Secondary action: white outline, white 14 w600 label and 18 icon, radius
/// 10, transparent fill. White clears 4.59:1 at the card's light end.
Widget profileOutlineButton({
  required String label,
  required VoidCallback? onPressed,
  IconData? icon,
}) {
  final enabled = onPressed != null;
  final ink = enabled ? Colors.white : ProfileTokens.disabledInk;
  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
      onTap: onPressed,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
          border: Border.all(color: ink, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: ink),
              const SizedBox(width: 10),
            ],
            Text(label, style: ProfileText.button.copyWith(color: ink)),
          ],
        ),
      ),
    ),
  );
}

/// One "LABEL value" fact for the status strip: label 11 w700 over value 17
/// w600, both white.
Widget profileFact(String label, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label.toUpperCase(), style: ProfileText.label),
      const SizedBox(height: 4),
      Text(value, style: ProfileText.fact),
    ],
  );
}

/// The Cancel and Save pair at the foot of a section in edit mode. Cancel is a
/// white text button on the card (4.59:1 at the light end); Save is the
/// emphasis pair, sunriseGold under unityBlue (7.17:1). Disabled Save is white
/// 0.12 under white 0.45, exempt as an inactive control.
Widget profileEditActions({
  required VoidCallback? onCancel,
  required VoidCallback? onSave,
  required bool saving,
}) {
  final canSave = onSave != null && !saving;
  return Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: saving ? null : onCancel,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            disabledForegroundColor: ProfileTokens.disabledInk,
            textStyle: ProfileText.button,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
            onTap: canSave ? onSave : null,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: canSave ? ProfileTokens.emphasisFill : ProfileTokens.disabledFill,
                borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
              ),
              alignment: Alignment.center,
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Save',
                      style: ProfileText.button.copyWith(
                        color: canSave ? ProfileTokens.onEmphasis : ProfileTokens.disabledInk,
                      ),
                    ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The "+ Section" chip for an omitted section: solid unityBlue under white
/// with a white outline, so it reads as a control and stays 12.51:1.
Widget profileAddChip({required String title, required VoidCallback onTap}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(ProfileTokens.chipRadius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: ProfileTokens.fill,
          borderRadius: BorderRadius.circular(ProfileTokens.chipRadius),
          border: Border.all(color: ProfileTokens.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(title, style: ProfileText.chip),
          ],
        ),
      ),
    ),
  );
}
