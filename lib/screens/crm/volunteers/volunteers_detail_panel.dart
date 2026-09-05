import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart' show Candidate;
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/outreach_activity.dart';
import 'package:bluebubbles/providers/user_session_provider.dart';
import 'package:bluebubbles/screens/crm/candidate_detail_screen.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/candidate_member_link_repository.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';

import 'activity_detail_screen.dart';
import 'mobilize_models.dart';
import 'outreach_region_section.dart';
import 'volunteers_map_models.dart';
import 'volunteers_theme.dart';

/// Which slice of the detail panel to render.
///
/// [statewide] is the overview rail shown when nothing is selected. In the
/// desktop three-pane region view [candidates] renders the left ballot pane and
/// [members] the right selection pane; [combined] is the mobile draggable sheet
/// which stacks candidates over members in one scroll. Only the [members] /
/// [combined] panes own member-selection state.
enum VolunteersPane { statewide, candidates, members, combined }

/// Members-pane "Last contacted" filter (§5). [any] is the default no-op.
enum _LastContactedFilter { any, never, notIn30 }

/// Members-pane sort order (§5). [nameAsc] is the default.
enum _MemberSort { nameAsc, recentlyContacted, leastRecentlyContacted }

// ═══════════════════════════════════════════════════════════════
//  DETAIL PANEL: the right-hand rail (desktop) / draggable sheet body
//  (mobile). Renders a Statewide Overview when nothing is selected, or a
//  region detail (November candidates + resident members with real
//  multi-select and a pinned bulk-action bar) when a region is.
//
//  ONE widget, both surfaces: the mounting decides the box (desktop rail
//  360 to 440px; mobile DraggableScrollableSheet snapped 0.35 / 0.7 / 0.95).
//  The panel is size-agnostic and drives the sheet through [scrollController]
//  so drag-to-expand works; the pinned action bar sits below the scroll view
//  so it stays visible at every snap.
// ═══════════════════════════════════════════════════════════════

/// One "Organizing play" idea card on the front door of the rail. Computed by
/// the map from data already in memory; [onStart] hands the play's region,
/// kind, title and nominees to the Desk's PLAN section. It does NOT raise a
/// modal: planning left the map with everything else that sends or schedules.
class OrganizingPlay {
  const OrganizingPlay({
    required this.icon,
    required this.title,
    required this.rationale,
    required this.onStart,
  });

  final IconData icon;
  final String title;
  final String rationale;
  final VoidCallback onStart;
}

/// One row in the Statewide Overview "priority districts" list.
class HotRegion {
  const HotRegion({
    required this.mode,
    required this.id,
    required this.memberCount,
    required this.status,
  });

  final MapMode mode;
  final String id;
  final int memberCount;
  final RegionStatus status;
}

/// Everything the panel needs to render the selected region.
///
/// [candidateGroups] carries the office-grouped candidate rows (district modes
/// yield one group; county mode yields the crosswalk-overlap groups). Agent A
/// builds these; the panel only renders them.
class RegionDetail {
  const RegionDetail({
    required this.mode,
    required this.id,
    required this.status,
    required this.memberCount,
    required this.members,
    required this.candidateGroups,
    required this.loadingCandidates,
    required this.loadingMembers,
  });

  final MapMode mode;
  final String id;
  final RegionStatus status;
  final int memberCount;
  final List<Member> members;
  final List<CandidateDisplayGroup> candidateGroups;
  final bool loadingCandidates;
  final bool loadingMembers;
}

// ── theme palette ────────────────────────────────────────────────────────
//
// A thin wrapper over [VolunteersTheme] so this file's many `p.xxx` call sites
// keep reading cleanly. Every colour behind those tokens is now derived from
// [BrandColors], so this panel and the Slack pages are one palette rather than
// two that drift; see volunteers_theme.dart for why that indirection exists.
//
// The panel paints on the navy end of the brand gradient, so the foreground
// rules are the kit's: white primary, white70 secondary, white-20% icon tiles,
// white-10% row pills, sunriseGold for emphasis.
class _Palette {
  _Palette(this.vt);

  final VolunteersTheme vt;

  Color get surface => vt.surface;
  Color get inset => vt.inset;
  Color get text => vt.text;
  Color get secondary => vt.secondary;
  Color get divider => vt.divider;

  /// NON-TEXT only: rules, rings, strokes, spinners. momentumBlue carries
  /// white at 2.75:1 and sits at 4.55:1 on [surface] but only 3.36:1 on
  /// [inset], so a caption painted in it passes on one row fill and fails on
  /// the other. Inline links and emphasis text use [highlight] instead, which
  /// measures 7.17:1 on surface and 5.29:1 on inset.
  Color get accent => vt.accent;
  Color get accentSoft => vt.accentSoft;
  Color get onAccentSoft => vt.onAccentSoft;
  Color get highlight => vt.highlight;

  /// The emphasis pair, and the only filled pairing in this palette a control
  /// may put a LABEL or a GLYPH on: unityBlue content on a sunriseGold fill,
  /// 7.17:1 either way round.
  Color get emphasisFill => vt.emphasisFill;
  Color get onEmphasis => vt.onEmphasis;

  /// Priority-swatch colour for a region status, kept off gold: young-dem uses
  /// the highlight role, the others keep their data-vis swatch.
  Color statusSwatch(RegionStatus status) => status == RegionStatus.youngDem
      ? vt.highlight
      : MapPalette.statusSwatch(status);

  factory _Palette.of(BuildContext c) => _Palette(VolunteersTheme.of(c));
}

// ── dialog chrome ──────────────────────────────────────────────
// The dialogs this panel raises used to take their surface and their text
// colour from the ambient Material theme, so they rendered light in one theme
// and dark in the other while the panel behind them stayed navy either way.
// They now carry the same fixed navy language as activity_detail_screen and
// bulk_email's confirm sheet. Ratios measured against [_dialogSurface]:
//   _dialogTitleText (white) ............... 12.51:1
//   _dialogBodyText (white70) .............. 7.03:1
//   _dialogListTitleText (white) ........... 12.51:1
//   _dialogListSubtitleText (white60) ...... 5.58:1
//   _dialogPrimaryAction (sunriseGold) ..... 7.17:1
//   _dialogQuietAction (white70) ........... 7.03:1
//   the checkbox tick (unityBlue on gold) .. 7.17:1
//   the note field's resting border (white38)  3.20:1, which is the bar a
//     user-interface component has to clear rather than the text bar
// [SimpleDialog] has no contentTextStyle, so its children carry their own
// explicit styles rather than inheriting one.
const Color _dialogSurface = BrandColors.unityBlue;

final RoundedRectangleBorder _dialogShape =
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

const TextStyle _dialogTitleText = BrandTextStyles.title;
const TextStyle _dialogBodyText = BrandTextStyles.bodySecondary;
const TextStyle _dialogListTitleText = BrandTextStyles.body;
const TextStyle _dialogListSubtitleText = BrandTextStyles.caption;

final ButtonStyle _dialogPrimaryAction =
    TextButton.styleFrom(foregroundColor: BrandColors.sunriseGold);
final ButtonStyle _dialogQuietAction =
    TextButton.styleFrom(foregroundColor: Colors.white70);

/// Checkbox on the navy dialog surface: gold well, navy tick, white70 edge so
/// the unchecked box is visible against the surface at 7.03:1.
const Color _dialogCheckFill = BrandColors.sunriseGold;
const Color _dialogCheckMark = BrandColors.unityBlue;
const BorderSide _dialogCheckSide = BorderSide(color: Colors.white70, width: 2);

/// The kit's contrast shadow. White text sitting on the light (momentumBlue)
/// end of a gradient drops under 3:1 on its own; this is the same shadow
/// BrandedStatCard uses to hold it legible wherever the gradient lands.
const List<Shadow> _onGradient = [
  Shadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 2),
];

/// The kit's signature icon tile: a white-20% square holding a white glyph,
/// sized to sit flush with the 36px avatars in the branded feed rows.
/// [fill] and [iconColor] are only overridden for the status-coded variants.
Widget _iconTile(IconData icon, {Color? fill, Color? iconColor}) => Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: fill ?? Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: iconColor ?? Colors.white),
    );

/// Compact badge: the kit's white-15% pill at the 6px compact-badge radius.
///
/// The default fill has TWO grounds in this file and therefore two figures.
/// As `_districtChip` it sits straight on the navy panel, composites to
/// #47516B, and carries white caps at 7.90:1. As `_geoChip` it sits inside a
/// BrandedActivityFeedItem, whose pill is already white-10% over the panel,
/// so it composites one layer lighter to #5A6279 and the same caps measure
/// 6.07:1. Both clear the 4.5:1 text bar; the single 7.9:1 this comment used
/// to quote only ever described the first of them.
///
/// [fill] is overridden by the status-coded and party-coded callers, whose
/// colours are chosen elsewhere and are NOT measured here, so this carries no
/// guarantee for those.
Widget _brandBadge(String label, {Color fill = const Color(0x26FFFFFF)}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w800)),
    );

class VolunteersDetailPanel extends StatelessWidget {
  const VolunteersDetailPanel({
    super.key,
    this.detail,
    this.pane = VolunteersPane.combined,
    required this.statewideMembers,
    required this.statewideYoungDems,
    this.statewideNominees = 0,
    required this.hotRegions,
    this.upcomingActivities = const [],
    this.organizingPlays = const [],
    this.onOpenActivities,
    this.onHighlightYoungDems,
    required this.onClose,
    required this.onSelectHot,
    required this.onMobilize,
    this.scrollController,
    this.showCloseButton = true,
  });

  /// When null, the panel renders the Statewide Overview.
  final RegionDetail? detail;

  /// Which slice of the region detail to render. Ignored when [detail] is null
  /// (that always renders the statewide overview).
  final VolunteersPane pane;

  final int statewideMembers;
  final int statewideYoungDems;
  final int statewideNominees;
  final List<HotRegion> hotRegions;

  /// Next few planned activities, soonest first (already filtered by the map).
  final List<OutreachActivity> upcomingActivities;

  /// Deterministic organizing ideas for the "Organizing plays" section.
  final List<OrganizingPlay> organizingPlays;

  /// Flip the workspace shell to the Activities tab. Null when unavailable.
  final VoidCallback? onOpenActivities;

  /// Jump the map to the district geography with the most young-dem pins.
  final VoidCallback? onHighlightYoungDems;

  final VoidCallback onClose;
  final void Function(MapMode mode, String id) onSelectHot;

  /// The members pane's one outbound action. Everything that sends or
  /// schedules now leaves through here: the bar publishes the selection, the
  /// region and the intent, and the shell flips to the Desk. The panel never
  /// pushes a bulk screen or opens a sheet of its own any more.
  final void Function(MobilizeRequest request) onMobilize;

  /// Supplied on the mobile draggable sheet so the single scroll view drives
  /// drag-to-expand. Null on desktop (the rail owns its own controller).
  final ScrollController? scrollController;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);
    return Material(
      color: p.surface,
      child: detail == null
          ? _statewide(context, p)
          : _RegionDetailView(
              key: ValueKey('${detail!.mode}:${detail!.id}:${pane.name}'),
              detail: detail!,
              pane:
                  pane == VolunteersPane.statewide ? VolunteersPane.combined : pane,
              onClose: onClose,
              onMobilize: onMobilize,
              scrollController: scrollController,
              showCloseButton: showCloseButton,
            ),
    );
  }

  // ── ORGANIZING HQ (statewide rail) ─────────────────────────────
  Widget _statewide(BuildContext context, _Palette p) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        Text('MISSOURI',
            style: TextStyle(
                color: p.secondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4)),
        const SizedBox(height: 4),
        Text('Organizing HQ',
            style: TextStyle(
                color: p.text,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -0.3)),
        // The member count gets a sentence to live in before it appears as a
        // bare figure in the first stat row. Only once the district signal has
        // loaded: "across 0 priority districts" would be a false statement.
        if (hotRegions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
              '$statewideMembers member${statewideMembers == 1 ? '' : 's'} '
              'across ${hotRegions.length} priority '
              'district${hotRegions.length == 1 ? '' : 's'}',
              style: TextStyle(color: p.secondary, fontSize: 13, height: 1.3)),
        ],
        const SizedBox(height: 16),
        _statRows(p),
        const SizedBox(height: 24),
        _sectionHeader(p, 'PRIORITY DISTRICTS'),
        const SizedBox(height: 10),
        if (hotRegions.isEmpty)
          Text('Loading district signal…',
              style: TextStyle(color: p.secondary, fontSize: 13))
        else
          ...hotRegions.map((h) => _hotRow(p, h)),
        const SizedBox(height: 24),
        _thisWeek(context, p),
        if (organizingPlays.isNotEmpty) ...[
          const SizedBox(height: 24),
          _sectionHeader(p, 'ORGANIZING PLAYS'),
          const SizedBox(height: 10),
          ...organizingPlays.map((play) => _playCard(p, play)),
        ],
      ],
    );
  }

  // ── stat rows ──────────────────────────────────────────────────
  /// Three full-width rows, one per statewide figure. Three tiles across a
  /// 300 px rail were about 84 px each, which cannot hold a two-word label
  /// beside a 22 px value: the middle label ran to three lines and stretched
  /// its neighbours to match. One row per stat gives every label a single
  /// line. A Column has no unbounded cross axis inside the ListView, so the
  /// IntrinsicHeight the old Row needed is gone with it.
  Widget _statRows(_Palette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _statRow(p,
            icon: Icons.groups_outlined,
            value: '$statewideMembers',
            label: 'Members'),
        const SizedBox(height: 8),
        _statRow(p,
            icon: Icons.star_rounded,
            value: '$statewideYoungDems',
            label: 'Young Dem nominees',
            tooltip: 'Young Dems on the November ballot',
            highlight: true,
            onTap: onHighlightYoungDems),
        const SizedBox(height: 8),
        _statRow(p,
            icon: Icons.how_to_vote_outlined,
            value: '$statewideNominees',
            label: 'Democratic nominees'),
      ],
    );
  }

  /// One 56 px stat row: the kit's 36 px icon tile, the value, then the label
  /// on one line. Measured pairs, each computed from the hex values in
  /// BrandColors and reported to two places:
  ///   white value and label on the white-10% row fill, which composites to
  ///     #3D4762 over unityBlue ........................... 9.23:1
  ///   white glyph on the white-20% icon well, which is painted INSIDE that
  ///     white-10% row rather than on unityBlue, so it composites to
  ///     #646C81 ......................................... 5.25:1
  ///   unityBlue value and label on the sunriseGold row .... 7.17:1
  ///   unityBlue glyph on its unityBlue-15% well over gold, which composites
  ///     to #DDA41C ....................................... 5.60:1
  ///   unityBlue at 0.70 chevron on gold, #675B3E .......... 3.83:1, which
  ///     clears the 3:1 bar for a graphical object
  ///
  /// The icon well is the one pair here that does NOT carry the palette's
  /// documented figure. volunteers_theme.dart states onAccentSoft over
  /// accentSoft at 6.68:1, and that is white-20% over unityBlue (#525C74):
  /// the ground a tile has when it sits straight on the panel. No default
  /// tile on this rail has that ground: the plain stat rows here, and every
  /// [BrandedActivityFeedItem] leading tile below them, put it inside a
  /// white-10% fill, so the real ground is one layer lighter and the glyph
  /// measures 5.25:1. It still clears the 4.5:1 text bar and the 3:1
  /// graphical bar, so nothing here is illegible, but do not quote 6.68:1 for
  /// a tile that sits on a row. The gold row is the exception and is measured
  /// on its own ground above: its well is unityBlue-15% over gold, not white.
  ///
  /// The label is white rather than white70 on the plain rows: white70 on the
  /// same fill is 5.51:1 and passes, but the three-tile version failed on its
  /// lighter fill with exactly that ink, and one ink per role is simpler.
  ///
  /// The value hugs its digits instead of sitting in a fixed 64 px column.
  /// Roboto measured at these sizes: "Young Dem nominees" and "Democratic
  /// nominees" are both about 128 px at 13 px, and the row has 244 px inside
  /// its padding on a 300 px rail. A 64 px value column plus the chevron
  /// leaves the gold label about 100 px, so it would have been the one label
  /// that ellipsised. Hugging the value leaves it 139 px with a two digit
  /// count and 126 px with three, so the label holds one line until the Young
  /// Dem count reaches three digits, at which point the ellipsis and the
  /// tooltip take over. The tooltip carries the full phrase for the shortened
  /// label either way, on the kit's inverse surface (unityBlue on white,
  /// 12.51:1).
  Widget _statRow(_Palette p,
      {required IconData icon,
      required String value,
      required String label,
      String? tooltip,
      bool highlight = false,
      VoidCallback? onTap}) {
    final fg = highlight ? p.onEmphasis : Colors.white;
    Widget row = Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color:
            highlight ? p.emphasisFill : Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _iconTile(icon,
              fill: highlight ? p.onEmphasis.withValues(alpha: 0.15) : null,
              iconColor: fg),
          const SizedBox(width: 8),
          Text(value,
              style: TextStyle(
                  color: fg,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right,
                size: 20, color: fg.withValues(alpha: 0.70)),
        ],
      ),
    );
    if (tooltip != null) {
      row = Tooltip(
        message: tooltip,
        decoration: BoxDecoration(
          color: p.vt.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
            color: p.vt.onInverseSurface,
            fontSize: 12,
            fontWeight: FontWeight.w600),
        child: row,
      );
    }
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: row,
      ),
    );
  }

  // ── priority district row ──────────────────────────────────────
  /// The kit's activity-feed pill: white-10% row, 36px leading tile, white
  /// title over a white70 line, chevron. A young-dem district swaps the tile
  /// to filled sunriseGold so the gold still carries the signal that the old
  /// gold hairline border did.
  Widget _hotRow(_Palette p, HotRegion h) {
    final youngDem = h.status == RegionStatus.youngDem;
    final swatch = p.statusSwatch(h.status);
    return BrandedActivityFeedItem(
      leadingWidget: _iconTile(
        youngDem ? Icons.star_rounded : Icons.place_outlined,
        fill: youngDem ? p.emphasisFill : swatch.withValues(alpha: 0.28),
        iconColor: youngDem ? p.onEmphasis : Colors.white,
      ),
      primaryText: h.mode.regionTitle(h.id),
      // Prose, not a dotted joiner, and "on the ballot" rather than "running":
      // these are November nominees. Never a vote count or a percentage.
      secondaryText: '${h.memberCount} member${h.memberCount == 1 ? '' : 's'}'
          '${youngDem ? ', Young Dem on the ballot' : ''}',
      onTap: () => onSelectHot(h.mode, h.id),
    );
  }

  // ── this week ──────────────────────────────────────────────────
  Widget _thisWeek(BuildContext context, _Palette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(p, 'THIS WEEK'),
        const SizedBox(height: 10),
        if (upcomingActivities.isEmpty)
          Text('Nothing is scheduled yet. Start with an organizing play below.',
              style: TextStyle(color: p.secondary, fontSize: 12.5, height: 1.3))
        else
          ...upcomingActivities.map((a) => _activityRow(context, a)),
        if (onOpenActivities != null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onOpenActivities,
              // sunriseGold, 7.17:1 on surface. Not [accent]: momentumBlue is
              // the palette's non-text role, and 4.55:1 on this surface does
              // not buy it a text job.
              style: TextButton.styleFrom(
                foregroundColor: p.highlight,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('All activities',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _activityRow(BuildContext context, OutreachActivity a) {
    final geoChips = _activityGeoLabels(a).take(3).toList();
    final date = a.scheduledOn == null
        ? null
        : DateFormat('EEE, MMM d').format(a.scheduledOn!);
    return BrandedActivityFeedItem(
      leadingWidget: _iconTile(a.kindIcon),
      primaryText: a.title,
      secondaryText: [if (date != null) date, a.kindLabel].join(' · '),
      trailingChips: geoChips.map(_geoChip).toList(),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ActivityDetailScreen(activity: a),
      )),
    );
  }

  Widget _geoChip(String label) => _brandBadge(label);

  List<String> _activityGeoLabels(OutreachActivity a) => [
        ...a.counties,
        ...a.congressionalDistricts.map((d) => 'CD $d'),
        ...a.senateDistricts.map((d) => 'SD $d'),
        ...a.houseDistricts.map((d) => 'HD $d'),
      ];

  // ── organizing play card ───────────────────────────────────────
  /// Same feed pill as the rows above, with the call to action carried in the
  /// item's own expansion slot so the whole play stays one surface.
  Widget _playCard(_Palette p, OrganizingPlay play) {
    return BrandedActivityFeedItem(
      leadingWidget: _iconTile(play.icon),
      primaryText: play.title,
      secondaryText: play.rationale,
      showChevron: false,
      expansion: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: p.emphasisFill,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: play.onStart,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: p.onEmphasis),
                    const SizedBox(width: 6),
                    Text('Start planning',
                        style: TextStyle(
                            color: p.onEmphasis,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  REGION DETAIL: stateful so the pinned action bar and the member list
//  share one selection set. Fresh state per region (ValueKey on mode:id).
// ═══════════════════════════════════════════════════════════════
class _RegionDetailView extends StatefulWidget {
  const _RegionDetailView({
    super.key,
    required this.detail,
    required this.pane,
    required this.onClose,
    required this.onMobilize,
    required this.scrollController,
    required this.showCloseButton,
  });

  final RegionDetail detail;
  final VolunteersPane pane;
  final VoidCallback onClose;
  final void Function(MobilizeRequest request) onMobilize;
  final ScrollController? scrollController;
  final bool showCloseButton;

  @override
  State<_RegionDetailView> createState() => _RegionDetailViewState();
}

class _RegionDetailViewState extends State<_RegionDetailView> {
  static const _initialCap = 30;

  final MemberRepository _repo = MemberRepository();

  final Set<String> _selectedIds = <String>{};
  bool _seeded = false;
  bool _expanded = false;
  bool _canTextFilter = false;
  bool _canEmailFilter = false;

  // Committee multi-select. Values are loaded once from the repo and cached.
  final Set<String> _committeeFilter = <String>{};
  List<String> _committees = const [];
  bool _loadingCommittees = false;

  _LastContactedFilter _lastContacted = _LastContactedFilter.any;
  _MemberSort _sort = _MemberSort.nameAsc;

  // Session-only overrides applied by the action bar so the list and the
  // last-contacted filter reflect a mark/note write without a full reload.
  // The notes override also seeds the next append so repeated notes never
  // clobber existing notes.
  final Map<String, DateTime> _lastContactedOverride = <String, DateTime>{};
  final Map<String, String> _notesOverride = <String, String>{};

  // ── Candidate links (spec 5.5) ──────────────────────────────────
  final CandidateMemberLinkRepository _linkRepo =
      CandidateMemberLinkRepository();

  /// "n members linked" per candidate id. Absent means zero, which is what a
  /// candidate with no volunteer base looks like.
  Map<String, int> _linkCounts = const <String, int>{};

  /// The candidate ids the counts were last fetched for, joined. The candidate
  /// rows arrive after the first frame, so this is what turns "the list
  /// changed" into exactly one more fetch rather than one per rebuild.
  String _countedKey = '';

  /// The candidate a link write is in flight for, so a second tap cannot fire
  /// the same bulk insert.
  String? _linkingCandidateId;

  RegionDetail get _d => widget.detail;

  @override
  void initState() {
    super.initState();
    _loadCommittees();
    _ensureLinkCounts();
  }

  @override
  void didUpdateWidget(covariant _RegionDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureLinkCounts();
  }

  /// Candidate ids on the ballot rows that resolve to a real profile. Only
  /// those can be linked to: an unmatched result row has no candidates.id.
  List<String> get _resolvedCandidateIds {
    final ids = <String>{};
    for (final group in _d.candidateGroups) {
      for (final row in group.rows) {
        final candidate = row.candidate;
        if (candidate != null) ids.add(candidate.id);
      }
    }
    final out = ids.toList()..sort();
    return out;
  }

  void _ensureLinkCounts() {
    final ids = _resolvedCandidateIds;
    final key = ids.join(',');
    if (key.isEmpty || key == _countedKey) return;
    _countedKey = key;
    _loadLinkCounts(ids);
  }

  Future<void> _loadLinkCounts(List<String> ids) async {
    try {
      final counts = await _linkRepo.linkCountsForCandidates(ids);
      if (!mounted) return;
      setState(() => _linkCounts = counts);
    } catch (_) {
      // A missing count only costs the "n members linked" line. The card and
      // its link gesture still work, and the gesture reports for itself.
    }
  }

  /// "Link this region's members" (spec 5.4). The whole region, not the
  /// members pane's selection: the gesture is named after the region and this
  /// pane is the ballot, which owns no selection.
  Future<void> _linkRegionToCandidate(
      BuildContext context, Candidate candidate) async {
    if (_linkingCandidateId != null) return;
    final people = _d.members;
    final region = _d.mode.regionTitle(_d.id);
    final messenger = ScaffoldMessenger.of(context);

    if (people.isEmpty) {
      messenger.showSnackBar(
          SnackBar(content: Text('No members live in $region.')));
      return;
    }

    final session = context.read<UserSessionProvider>();
    final actorMemberId = session.currentMember?.id;
    final actorUserId = session.authUserId;
    if (actorMemberId == null || actorUserId == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Your session is still loading. Try again in a '
              'moment.')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _dialogSurface,
        shape: _dialogShape,
        titleTextStyle: _dialogTitleText,
        contentTextStyle: _dialogBodyText,
        title: Text('Link $region to ${candidate.name}?'),
        content: SizedBox(
          width: 380,
          child: Text(
              'All ${people.length} member${people.length == 1 ? '' : 's'} in '
              '$region join ${candidate.name}\'s volunteer base. Members who '
              'join $region later are not added on their own; use Refresh on '
              'the Desk for that.'),
        ),
        actions: [
          TextButton(
              style: _dialogQuietAction,
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          TextButton(
              style: _dialogPrimaryAction,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Link')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _linkingCandidateId = candidate.id);
    try {
      final added = await _linkRepo.linkMembers(
        candidateId: candidate.id,
        memberIds: people.map((m) => m.id).toList(),
        sourceMode: _d.mode,
        sourceRegionId: _d.id,
        actorUserId: actorUserId,
        actorMemberId: actorMemberId,
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(added == 0
            ? 'All of $region was already linked to ${candidate.name}.'
            : 'Linked $added from $region to ${candidate.name}.'),
      ));
      await _loadLinkCounts(_resolvedCandidateIds);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
          content: Text('That did not save. Please try again.')));
    } finally {
      if (mounted) setState(() => _linkingCandidateId = null);
    }
  }

  Future<void> _loadCommittees() async {
    if (_loadingCommittees) return;
    setState(() => _loadingCommittees = true);
    try {
      final committees = await _repo.getUniqueCommittees();
      if (!mounted) return;
      setState(() {
        _committees = committees;
        _loadingCommittees = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCommittees = false);
    }
  }

  bool _isSelectable(Member m) =>
      m.canContact || (m.preferredEmail ?? '').isNotEmpty;

  DateTime? _effectiveLastContacted(Member m) =>
      _lastContactedOverride[m.id] ?? m.lastContacted;

  String? _effectiveNotes(Member m) => _notesOverride[m.id] ?? m.notes;

  bool get _anyFilterActive =>
      _canTextFilter ||
      _canEmailFilter ||
      _committeeFilter.isNotEmpty ||
      _lastContacted != _LastContactedFilter.any;

  /// Seed the selection to ALL selectable members the first time they exist.
  /// Guarded so an async member load seeds once and later user changes stick.
  void _seedIfNeeded() {
    if (_seeded) return;
    final selectable = _d.members.where(_isSelectable).toList();
    if (selectable.isEmpty && _d.loadingMembers) return;
    _selectedIds
      ..clear()
      ..addAll(selectable.map((m) => m.id));
    _seeded = true;
  }

  /// Members shown in the list: the textable/emailable toggles compose as an
  /// OR group (unchanged from Phase 1), then AND with the committee and
  /// last-contacted filters, then the chosen sort is applied.
  List<Member> get _displayed {
    Iterable<Member> out = _d.members;

    if (_canTextFilter || _canEmailFilter) {
      out = out.where((m) =>
          (_canTextFilter && m.canContact) ||
          (_canEmailFilter && (m.preferredEmail ?? '').isNotEmpty));
    }

    if (_committeeFilter.isNotEmpty) {
      out = out.where((m) {
        final committees = m.committee;
        if (committees == null || committees.isEmpty) return false;
        return committees.any(_committeeFilter.contains);
      });
    }

    switch (_lastContacted) {
      case _LastContactedFilter.any:
        break;
      case _LastContactedFilter.never:
        out = out.where((m) => _effectiveLastContacted(m) == null);
        break;
      case _LastContactedFilter.notIn30:
        final cutoff = DateTime.now().subtract(const Duration(days: 30));
        out = out.where((m) {
          final lc = _effectiveLastContacted(m);
          return lc == null || lc.isBefore(cutoff);
        });
        break;
    }

    final list = out.toList();
    _sortMembers(list);
    return list;
  }

  void _sortMembers(List<Member> list) {
    int byName(Member a, Member b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    switch (_sort) {
      case _MemberSort.nameAsc:
        list.sort(byName);
        break;
      case _MemberSort.recentlyContacted:
        list.sort((a, b) {
          final la = _effectiveLastContacted(a);
          final lb = _effectiveLastContacted(b);
          if (la == null && lb == null) return byName(a, b);
          if (la == null) return 1; // never-contacted sink to the bottom
          if (lb == null) return -1;
          return lb.compareTo(la); // most recent first
        });
        break;
      case _MemberSort.leastRecentlyContacted:
        list.sort((a, b) {
          final la = _effectiveLastContacted(a);
          final lb = _effectiveLastContacted(b);
          if (la == null && lb == null) return byName(a, b);
          if (la == null) return -1; // never-contacted are the most overdue
          if (lb == null) return 1;
          return la.compareTo(lb); // oldest first
        });
        break;
    }
  }

  List<Member> get _selectedTextable => _d.members
      .where((m) => _selectedIds.contains(m.id) && m.canContact)
      .toList();

  List<Member> get _selectedEmailable => _d.members
      .where((m) =>
          _selectedIds.contains(m.id) && (m.preferredEmail ?? '').isNotEmpty)
      .toList();

  /// Every selected member, regardless of contact capability. This seeds the
  /// outreach sheet's participant roster.
  List<Member> get _selectedMembers =>
      _d.members.where((m) => _selectedIds.contains(m.id)).toList();

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);
    switch (widget.pane) {
      case VolunteersPane.candidates:
        return _buildCandidatesPane(context, p);
      case VolunteersPane.members:
        return _buildMembersPane(context, p);
      case VolunteersPane.statewide:
      case VolunteersPane.combined:
        return _buildCombined(context, p);
    }
  }

  /// Mobile draggable sheet: candidates then members in one scroll, action bar
  /// pinned below.
  Widget _buildCombined(BuildContext context, _Palette p) {
    _seedIfNeeded();
    final textCount = _selectedTextable.length;
    final emailCount = _selectedEmailable.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(p),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              _sectionHeader(p, 'ON THE NOVEMBER BALLOT'),
              const SizedBox(height: 12),
              _candidateSection(context, p),
              const SizedBox(height: 24),
              RegionOutreachSection(mode: _d.mode, regionId: _d.id),
              const SizedBox(height: 24),
              _membersSection(context, p),
            ],
          ),
        ),
        _actionBar(context, p, textCount: textCount, emailCount: emailCount),
      ],
    );
  }

  /// Desktop left pane: November nominee cards only. No member selection here.
  Widget _buildCandidatesPane(BuildContext context, _Palette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _candidatesHeader(p),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              _candidateSection(context, p),
            ],
          ),
        ),
      ],
    );
  }

  /// Desktop right pane: members list, outreach and the pinned action bar. This
  /// pane owns the member-selection state.
  Widget _buildMembersPane(BuildContext context, _Palette p) {
    _seedIfNeeded();
    final textCount = _selectedTextable.length;
    final emailCount = _selectedEmailable.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(p),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              RegionOutreachSection(mode: _d.mode, regionId: _d.id),
              const SizedBox(height: 24),
              _membersSection(context, p),
            ],
          ),
        ),
        _actionBar(context, p, textCount: textCount, emailCount: emailCount),
      ],
    );
  }

  // ── header ──────────────────────────────────────────────────────
  /// The region header is the panel's one gradient band, exactly like the
  /// Slack tab headers: navy-to-blue topLeft→bottomRight, white type carrying
  /// the kit's contrast shadow so it holds where the gradient lightens, and a
  /// sunriseGold rule under the title.
  Widget _header(_Palette p) {
    final texting = _d.members.where((m) => m.canContact).length;
    final emailing =
        _d.members.where((m) => (m.preferredEmail ?? '').isNotEmpty).length;

    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: BrandColors.getTileGradient(),
        border: Border(bottom: BorderSide(color: p.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _headerTitle(p, _d.mode.overline)),
              if (widget.showCloseButton)
                Semantics(
                  button: true,
                  label: 'Close detail panel',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onClose,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _headerStat(Icons.groups_outlined, '${_d.memberCount}',
                    _d.memberCount == 1 ? 'member' : 'members'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _headerStat(
                    Icons.sms_outlined, '$texting', 'can text'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _headerStat(
                    Icons.email_outlined, '$emailing', 'can email'),
              ),
            ],
          ),
          // Spec 2.5: mobilizing a whole region takes one press, not 41
          // check boxes. It sits with the counts because it is a statement
          // about the same number, and it stays put whether or not anything
          // is selected, so the exec never has to hunt for it after Clear.
          if (!_d.loadingMembers && _d.members.isNotEmpty) ...[
            const SizedBox(height: 12),
            _mobilizeAllAction(p),
          ],
        ],
      ),
    );
  }

  /// "Mobilize all 41". The emphasis pair is the only filled pairing this
  /// palette lets a label sit on (unityBlue on sunriseGold, 7.17:1 either way
  /// round), and it reads as the header's one action against the gradient.
  Widget _mobilizeAllAction(_Palette p) {
    final total = _d.members.length;
    return Semantics(
      button: true,
      label: 'Mobilize all $total members in ${_d.mode.regionTitle(_d.id)}',
      child: Material(
        color: p.emphasisFill,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: _mobilizeAll,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.campaign_outlined, size: 16, color: p.onEmphasis),
                const SizedBox(width: 7),
                Text('Mobilize all $total',
                    style: TextStyle(
                        color: p.onEmphasis,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The area-wide gesture (spec 2.5). Every loaded member of the region, not
  /// the selection and not the filtered view, because the label says "all".
  /// Candidates are left empty for the same reason [_mobilizeSelection] does:
  /// the map attaches them.
  void _mobilizeAll() {
    final members = _d.members;
    if (members.isEmpty) return;
    widget.onMobilize(MobilizeRequest(
      members: members,
      regionMode: _d.mode,
      regionId: _d.id,
    ));
  }

  /// Overline, region title and the gold rule, shared by both pane headers.
  Widget _headerTitle(_Palette p, String overline) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(overline,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  shadows: _onGradient)),
          const SizedBox(height: 3),
          Text(_d.mode.regionTitle(_d.id),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  shadows: _onGradient)),
          const SizedBox(height: 8),
          Container(
            width: 44,
            height: 3,
            decoration: BoxDecoration(
              color: p.highlight,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      );

  /// BrandedStatCard scaled to the header band: white-15% well, white-20%
  /// icon tile, shadowed value. Three across replaces the emoji pills, so the
  /// header reads as the same stat treatment the rest of the workspace uses.
  Widget _headerStat(IconData icon, String value, String label) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 15, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.0,
                          fontWeight: FontWeight.w800,
                          shadows: _onGradient)),
                  const SizedBox(height: 2),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                          shadows: _onGradient)),
                ],
              ),
            ),
          ],
        ),
      );

  // ── candidates-pane header (desktop left) ───────────────────────
  Widget _candidatesHeader(_Palette p) {
    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: BrandColors.getTileGradient(),
        border: Border(bottom: BorderSide(color: p.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [_headerTitle(p, 'ON THE NOVEMBER BALLOT')],
      ),
    );
  }

  // ── candidate section ───────────────────────────────────────────
  Widget _candidateSection(BuildContext context, _Palette p) {
    if (_d.loadingCandidates) {
      return _panelSpinner(p, 'Loading November candidates…');
    }
    final groups =
        _d.candidateGroups.where((g) => g.rows.isNotEmpty).toList();
    if (groups.isEmpty) {
      final noDem = _d.status == RegionStatus.noDem;
      return _emptyBox(
        p,
        // Status-coded circle for the no-Democrat case, the kit's white-20%
        // icon tile otherwise. Both carry a white glyph: a tinted accent on a
        // navy panel is what the old version had, and it was invisible.
        circle: noDem
            ? MapPalette.statusNoDem.withValues(alpha: 0.35)
            : Colors.white.withValues(alpha: 0.2),
        icon: noDem ? Icons.person_off_outlined : Icons.how_to_vote_outlined,
        iconColor: Colors.white,
        title: noDem
            ? 'No Democrat filed here'
            : _d.status == RegionStatus.notOnBallot
                ? 'This seat is not on the 2026 ballot'
                : 'No candidates on record for this race',
        body: noDem
            ? 'No Democrat advanced from the August 4 primary in this district.'
            : 'The August 4 primary results list no candidates for this area.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(height: 20),
          _candidateGroup(context, p, groups[i], showHeader: groups.length > 1),
        ],
      ],
    );
  }

  Widget _candidateGroup(
    BuildContext context,
    _Palette p,
    CandidateDisplayGroup group, {
    required bool showHeader,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) ...[
          Row(
            children: [
              Flexible(
                child: Text(group.officeTypeLabel.toUpperCase(),
                    style: TextStyle(
                        color: p.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0)),
              ),
              const SizedBox(width: 8),
              ...group.districtChips.map((c) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _districtChip(c),
                  )),
            ],
          ),
          const SizedBox(height: 10),
        ],
        for (final row in group.rows) _candidateCard(context, p, row),
      ],
    );
  }

  Widget _districtChip(String label) => _brandBadge(label);

  Widget _candidateCard(BuildContext context, _Palette p, CandidateDisplayRow row) {
    final name = row.candidate?.name ??
        row.result?.candidateName ??
        'Unknown candidate';
    final office = row.candidate?.officeDisplay ?? row.result?.officeRaw ?? '';
    final party =
        row.candidate?.partyShort ?? row.result?.partyShort ?? '?';
    final photo = row.candidate?.effectivePhotoUrl;

    void open() {
      if (!row.tappable) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CandidateDetailScreen(candidate: row.candidate!),
      ));
    }

    final card = Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        // The nominee ring is the kit's sunriseGold highlight ring; every
        // other card keeps the white-10% hairline.
        border: row.isNominee
            ? Border.all(color: p.highlight, width: 1.4)
            : Border.all(color: p.divider),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _candidateAvatar(name, photo),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _partyChip(party),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(name,
                              // Full name must show. Wrap to a second line
                              // before ellipsizing so a long name is never cut
                              // off, on desktop especially.
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: p.text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                        ),
                        if (row.isNominee) ...[
                          const SizedBox(width: 8),
                          _nomineeBadge(party),
                        ],
                      ],
                    ),
                    if (office.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(office,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.secondary, fontSize: 12.5)),
                    ],
                  ],
                ),
              ),
              if (row.tappable) _candidateMoreMenu(context, p, row.candidate!),
              if (row.tappable)
                Icon(Icons.chevron_right,
                    color: p.secondary.withValues(alpha: 0.6), size: 18),
            ],
          ),
          // Candidate-first entry point (§4.2): "Organize for {first name}".
          // Only shown when the row resolves to a real candidate profile: an
          // unmatched result row never fabricates an activity. Its onPressed
          // lives on its own InkWell so the tap never bubbles up to the card's
          // InkWell (which still one-taps to the candidate profile).
          if (row.tappable) ...[
            const SizedBox(height: 8),
            _linkCountLine(p, row.candidate!),
            const SizedBox(height: 8),
            _organizeButton(context, p, row),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: row.tappable
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: open,
                borderRadius: BorderRadius.circular(12),
                child: card,
              ),
            )
          : card,
    );
  }

  /// How big this nominee's volunteer base is (spec 5.5). It counts stored
  /// links, not everyone in the region: a link is a row somebody wrote, so the
  /// number holds still while the region's population moves under it.
  Widget _linkCountLine(_Palette p, Candidate candidate) {
    final linked = _linkCounts[candidate.id] ?? 0;
    return Row(
      children: [
        Icon(Icons.link, size: 14, color: p.secondary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            linked == 0
                ? 'No members linked yet'
                : '$linked member${linked == 1 ? '' : 's'} linked',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // white70 on the card's white-10% fill over the navy panel:
            // 5.51:1, the same pairing and the same figure the stat rows
            // quote.
            style: TextStyle(color: p.secondary, fontSize: 12),
          ),
        ),
      ],
    );
  }

  /// The nominee card's overflow (spec 5.4): the batch link gesture, without a
  /// trip through the Desk. It sits inside the card's InkWell and swallows its
  /// own taps, so opening the menu never opens the candidate profile.
  Widget _candidateMoreMenu(
      BuildContext context, _Palette p, Candidate candidate) {
    if (_linkingCandidateId == candidate.id) {
      return Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: SizedBox(
          width: 16,
          height: 16,
          child:
              CircularProgressIndicator(strokeWidth: 2, color: p.highlight),
        ),
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'More actions',
      position: PopupMenuPosition.under,
      enabled: _linkingCandidateId == null,
      onSelected: (value) {
        if (value == 'link') _linkRegionToCandidate(context, candidate);
        if (value == 'connect') _connectInDesk(candidate);
      },
      itemBuilder: (_) => [
        _moreItem('link', Icons.link, "Link this region's members"),
        _moreItem('connect', Icons.hub_outlined, 'Manage links in the Desk'),
      ],
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Icon(Icons.more_vert, size: 18, color: p.secondary),
      ),
    );
  }

  /// Compact "Organize for {first name}" action on a resolved nominee card.
  /// Filled emphasis pill: unityBlue caps on a sunriseGold fill, measured at
  /// 7.17:1. It was momentumBlue under white, which measures 2.75:1 and fails
  /// the 4.5:1 text bar. It aligns left and ellipsizes so it never crowds the
  /// card or overflows the narrow mobile [VolunteersPane.combined] width.
  Widget _organizeButton(
      BuildContext context, _Palette p, CandidateDisplayRow row) {
    final candidate = row.candidate!;
    final firstName =
        candidate.firstName.isNotEmpty ? candidate.firstName : candidate.name;
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: p.emphasisFill,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: () => _openOrganize(row),
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.campaign_outlined, size: 15, color: p.onEmphasis),
                const SizedBox(width: 6),
                Flexible(
                  child: Text('Organize for $firstName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: p.onEmphasis,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The Desk's CONNECT section, opened on this nominee with the region as the
  /// audience. The card's own menu item stays the one-tap batch link (spec
  /// 5.4); this is the way to the rest of that section, which only the Desk
  /// has room for: unlink a batch, refresh a region, attach a different
  /// nominee. It is also the only producer of [MobilizeIntent.connect].
  void _connectInDesk(Candidate candidate) {
    widget.onMobilize(MobilizeRequest(
      members: _d.members,
      candidates: <Candidate>[candidate],
      regionMode: _d.mode,
      regionId: _d.id,
      intent: MobilizeIntent.connect,
    ));
  }

  /// The nominee-first gesture. It used to raise the toolkit sheet as a modal
  /// on top of the map, which is exactly what spec 2.2 moved off it: planning
  /// is Desk work. It now hands the Desk a plan-intent request carrying this
  /// nominee, the region, and the region's members as the audience, so the
  /// PLAN section opens with the canvass already seeded and a roster to work
  /// from rather than an empty sheet.
  ///
  /// The whole region's members rather than the selection, because this button
  /// lives on the ballot pane, which owns no selection of its own.
  void _openOrganize(CandidateDisplayRow row) {
    final candidate = row.candidate!;
    widget.onMobilize(MobilizeRequest(
      members: _d.members,
      candidates: <Candidate>[candidate],
      regionMode: _d.mode,
      regionId: _d.id,
      intent: MobilizeIntent.plan,
      seedKind: 'canvass',
      seedTitle: 'Canvass for ${candidate.name}',
    ));
  }

  Widget _candidateAvatar(String name, String? url) {
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundColor: MapPalette.avatarColorFor(name),
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }
    return CircleAvatar(
      radius: 28,
      backgroundColor: MapPalette.avatarColorFor(name),
      child: Text(_initials(name),
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
    );
  }

  Widget _partyChip(String letter) => Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: MapPalette.partyChipColor(letter),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(letter,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
      );

  /// Party-coded NOMINEE pill, mirroring the shipped candidates list: white
  /// caps on the party chip colour. [partyShort] is the candidate's or result's
  /// one-letter party ('D'/'R'/'L'/…), '?' when unknown.
  Widget _nomineeBadge(String partyShort) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: MapPalette.partyChipColor(partyShort),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text('NOMINEE',
            style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4)),
      );

  // ── members section (real multi-select) ─────────────────────────
  Widget _membersSection(BuildContext context, _Palette p) {
    if (_d.loadingMembers) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(p, 'MOYD MEMBERS'),
          const SizedBox(height: 12),
          _panelSpinner(p, 'Finding members…'),
        ],
      );
    }

    if (_d.members.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(p, 'MOYD MEMBERS (0)'),
          const SizedBox(height: 12),
          _emptyBox(
            p,
            circle: Colors.white.withValues(alpha: 0.2),
            icon: Icons.group_add_outlined,
            iconColor: Colors.white,
            title: 'No members here yet',
            body: 'No MOYD members live in this area on record.',
          ),
        ],
      );
    }

    final displayed = _displayed;
    final total = _d.members.length;
    final filteredCount = displayed.length;
    final displayedSelectable = displayed.where(_isSelectable).toList();
    final selectedInDisplay = displayedSelectable
        .where((m) => _selectedIds.contains(m.id))
        .length;
    final bool? headerTri = displayedSelectable.isEmpty
        ? false
        : selectedInDisplay == 0
            ? false
            : selectedInDisplay == displayedSelectable.length
                ? true
                : null;

    final filteredTextable = displayed.where((m) => m.canContact).length;
    final filteredEmailable =
        displayed.where((m) => (m.preferredEmail ?? '').isNotEmpty).length;

    // Header count and summary reflect the currently filtered set, showing the
    // total too when it differs (e.g. "MOYD MEMBERS (12 of 41)").
    final headerCount = _anyFilterActive && filteredCount != total
        ? '$filteredCount of $total'
        : '$total';

    final selectAllLabel = _anyFilterActive
        ? 'Select all $filteredCount filtered'
        : 'Select all';

    final visible = _expanded ? displayed : displayed.take(_initialCap).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(p, 'MOYD MEMBERS ($headerCount)'),
        const SizedBox(height: 6),
        Text('$filteredTextable textable · $filteredEmailable emailable',
            style: TextStyle(color: p.secondary, fontSize: 12)),
        const SizedBox(height: 10),
        // Select-all-filtered + live selection count
        Row(
          children: [
            SizedBox(
              width: 34,
              child: Checkbox(
                value: headerTri,
                tristate: true,
                activeColor: p.emphasisFill,
                checkColor: p.onEmphasis,
                // The panel is a branded navy surface, so the unchecked box
                // needs an explicit white edge: the Material default is a
                // dark outline that disappears here.
                side: const BorderSide(color: Colors.white70, width: 1.5),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: displayedSelectable.isEmpty
                    ? null
                    : (_) => _toggleAllDisplayed(displayedSelectable),
              ),
            ),
            Flexible(
              child: Text(selectAllLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: p.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            if (_selectedIds.isNotEmpty)
              Text('${_selectedIds.length} selected',
                  style: TextStyle(
                      color: p.highlight,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        // Filter + sort chips (§5)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _filterChip(p, 'Textable', _canTextFilter,
                () => setState(() => _canTextFilter = !_canTextFilter)),
            _filterChip(p, 'Emailable', _canEmailFilter,
                () => setState(() => _canEmailFilter = !_canEmailFilter)),
            _menuChip(p, _committeeChipLabel(), _committeeFilter.isNotEmpty,
                _openCommitteeFilter),
            _menuChip(p, _lastContactedChipLabel(),
                _lastContacted != _LastContactedFilter.any,
                _openLastContactedFilter),
            _menuChip(p, _sortChipLabel(), false, _openSortMenu),
          ],
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No members match these filters.',
                style: TextStyle(color: p.secondary, fontSize: 12.5)),
          )
        else
          ...visible.map((m) => _memberRow(context, p, m)),
        if (displayed.length > _initialCap && !_expanded)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton(
              onPressed: () => setState(() => _expanded = true),
              child: Text('Show all ${displayed.length}',
                  style: TextStyle(
                      color: p.highlight,
                      fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }

  String _committeeChipLabel() {
    final n = _committeeFilter.length;
    if (n == 0) return 'Committee';
    return n == 1 ? '1 committee' : '$n committees';
  }

  String _lastContactedChipLabel() {
    switch (_lastContacted) {
      case _LastContactedFilter.any:
        return 'Last contacted';
      case _LastContactedFilter.never:
        return 'Never contacted';
      case _LastContactedFilter.notIn30:
        return 'Not in 30 days';
    }
  }

  String _sortChipLabel() {
    switch (_sort) {
      case _MemberSort.nameAsc:
        return 'Sort: Name';
      case _MemberSort.recentlyContacted:
        return 'Sort: Recent';
      case _MemberSort.leastRecentlyContacted:
        return 'Sort: Least recent';
    }
  }

  // ── filter/sort menus ───────────────────────────────────────────
  Future<void> _openCommitteeFilter() async {
    if (_committees.isEmpty && !_loadingCommittees) {
      await _loadCommittees();
    }
    if (!mounted) return;
    final temp = Set<String>.from(_committeeFilter);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _dialogSurface,
        shape: _dialogShape,
        titleTextStyle: _dialogTitleText,
        contentTextStyle: _dialogBodyText,
        title: const Text('Filter by committee'),
        content: SizedBox(
          width: double.maxFinite,
          child: _committees.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No committees on file.'))
              : StatefulBuilder(
                  builder: (context, setDialogState) => ListView(
                    shrinkWrap: true,
                    children: _committees
                        .map((c) => CheckboxListTile(
                              dense: true,
                              value: temp.contains(c),
                              activeColor: _dialogCheckFill,
                              checkColor: _dialogCheckMark,
                              side: _dialogCheckSide,
                              title: Text(c, style: _dialogListTitleText),
                              onChanged: (v) => setDialogState(() {
                                if (v == true) {
                                  temp.add(c);
                                } else {
                                  temp.remove(c);
                                }
                              }),
                            ))
                        .toList(),
                  ),
                ),
        ),
        actions: [
          if (_committeeFilter.isNotEmpty || temp.isNotEmpty)
            TextButton(
                style: _dialogQuietAction,
                onPressed: () => Navigator.pop(dialogContext, <String>{}),
                child: const Text('Clear')),
          TextButton(
              style: _dialogQuietAction,
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          TextButton(
              style: _dialogPrimaryAction,
              onPressed: () => Navigator.pop(dialogContext, temp),
              child: const Text('Apply')),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _committeeFilter
          ..clear()
          ..addAll(result);
      });
    }
  }

  Future<void> _openLastContactedFilter() async {
    final result = await showDialog<_LastContactedFilter>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: _dialogSurface,
        shape: _dialogShape,
        titleTextStyle: _dialogTitleText,
        title: const Text('Last contacted'),
        children: [
          _radioOption(dialogContext, _LastContactedFilter.any, _lastContacted,
              'Any'),
          _radioOption(dialogContext, _LastContactedFilter.never,
              _lastContacted, 'Never contacted'),
          _radioOption(dialogContext, _LastContactedFilter.notIn30,
              _lastContacted, 'Not contacted in 30 days'),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() => _lastContacted = result);
    }
  }

  Future<void> _openSortMenu() async {
    final result = await showDialog<_MemberSort>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: _dialogSurface,
        shape: _dialogShape,
        titleTextStyle: _dialogTitleText,
        title: const Text('Sort members'),
        children: [
          _radioOption(dialogContext, _MemberSort.nameAsc, _sort, 'Name (A-Z)'),
          _radioOption(dialogContext, _MemberSort.recentlyContacted, _sort,
              'Recently contacted'),
          _radioOption(dialogContext, _MemberSort.leastRecentlyContacted, _sort,
              'Least recently contacted'),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() => _sort = result);
    }
  }

  /// One row of a [SimpleDialog] sort/filter menu. Both the label and the
  /// selected tick are stated against the fixed navy dialog surface rather
  /// than inherited: white at 12.51:1 and the gold emphasis fill at 7.17:1.
  /// The tick used to be the fixed momentumBlue accent painted onto a
  /// theme-responsive surface, which measures 2.2:1 to 2.8:1 across the
  /// light-mode dialog surfaces Material picks and fails the 3:1 bar for a
  /// graphical object on every one of them.
  /// Gold also matches the filter chip, where gold already marks selection.
  Widget _radioOption<T>(
      BuildContext ctx, T value, T groupValue, String label) {
    final selected = value == groupValue;
    return ListTile(
      dense: true,
      title: Text(label, style: _dialogListTitleText),
      trailing: selected
          ? Icon(Icons.check, color: VolunteersTheme.of(ctx).emphasisFill)
          : null,
      onTap: () => Navigator.pop(ctx, value),
    );
  }

  void _toggleAllDisplayed(List<Member> displayedSelectable) {
    final anySelected =
        displayedSelectable.any((m) => _selectedIds.contains(m.id));
    setState(() {
      if (anySelected) {
        for (final m in displayedSelectable) {
          _selectedIds.remove(m.id);
        }
      } else {
        for (final m in displayedSelectable) {
          _selectedIds.add(m.id);
        }
      }
    });
  }

  /// Filter chip in the kit's selected-row idiom: white-10% at rest, the
  /// white-20% well plus a sunriseGold ring when active. Gold marks the
  /// selection rather than filling it, so the label stays white on white-20%
  /// and never drops to the low-contrast white-on-momentumBlue pairing.
  Widget _filterChip(_Palette p, String label, bool active, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? p.accentSoft : p.inset,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? p.highlight : p.divider),
          ),
          child: Text(label,
              style: TextStyle(
                  color: p.text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  /// Like [_filterChip] but carries a dropdown affordance, for chips that open
  /// a menu (Committee / Last contacted / Sort) rather than toggling.
  Widget _menuChip(_Palette p, String label, bool active, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
          decoration: BoxDecoration(
            color: active ? p.accentSoft : p.inset,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? p.highlight : p.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                      color: p.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 2),
              Icon(Icons.arrow_drop_down,
                  size: 18, color: active ? p.text : p.secondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _memberRow(BuildContext context, _Palette p, Member m) {
    final selectable = _isSelectable(m);
    final selected = _selectedIds.contains(m.id);
    final canText = m.canContact;
    final canEmail = (m.preferredEmail ?? '').isNotEmpty;
    final sub = _memberSubline(m);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Checkbox(
              value: selected,
              activeColor: p.emphasisFill,
              checkColor: p.onEmphasis,
              side: const BorderSide(color: Colors.white70, width: 1.5),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: selectable
                  ? (v) => setState(() {
                        if (v == true) {
                          _selectedIds.add(m.id);
                        } else {
                          _selectedIds.remove(m.id);
                        }
                      })
                  : null,
            ),
          ),
          // Deliberately NOT BrandedActivityFeedItem: that widget requires a
          // secondaryText, and a member with no county or district on file
          // would render a blank second line. This is the same pill by hand
          // (white-10% fill, 36px avatar, white over white70, radius 10) with
          // the subline dropped when it is empty.
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MemberDetailScreen(member: m),
                )),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected ? p.accentSoft : p.inset,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      _memberAvatar(m),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(m.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: p.text,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            if (sub.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(sub,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: p.secondary, fontSize: 13)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Always show both glyphs so contactability reads at a
                      // glance: solid when reachable, dimmed with a reason
                      // tooltip when not.
                      Tooltip(
                        message: canText ? 'Textable' : 'No phone / opted out',
                        child: Icon(Icons.sms_outlined,
                            size: 16,
                            color: p.secondary
                                .withValues(alpha: canText ? 0.9 : 0.5)),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: canEmail ? 'Emailable' : 'No email on file',
                        child: Icon(Icons.email_outlined,
                            size: 16,
                            color: p.secondary
                                .withValues(alpha: canEmail ? 0.9 : 0.5)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _memberSubline(Member m) {
    final district = _memberDistrictLabel(m);
    return [
      if ((m.county ?? '').isNotEmpty) '${m.county} County',
      if (district != null) district,
    ].join(' · ');
  }

  String? _memberDistrictLabel(Member m) {
    switch (_d.mode) {
      case MapMode.county:
      case MapMode.congressional:
        final cd = m.congressionalDistrict;
        return (cd ?? '').isNotEmpty ? cd : null;
      case MapMode.house:
        final hd = m.houseDistrict;
        return (hd ?? '').isNotEmpty ? 'HD $hd' : null;
      case MapMode.senate:
        final sd = m.senateDistrict;
        return (sd ?? '').isNotEmpty ? 'SD $sd' : null;
    }
  }

  Widget _memberAvatar(Member m) {
    final url = m.effectiveAvatarUrl;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(url,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _memberInitials(m)),
      );
    }
    return _memberInitials(m);
  }

  Widget _memberInitials(Member m) => Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: MapPalette.avatarColorFor(m.id),
          shape: BoxShape.circle,
        ),
        child: Text(_initials(m.name),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      );

  // ── pinned action bar ───────────────────────────────────────────
  /// One row plus the skip lines. Text, Email, Add-to-activity and Plan
  /// activity all left for the Desk: the line is that anything which SENDS or
  /// SCHEDULES is Desk work, and anything that annotates or exports the list in
  /// front of you stays here, which is why the (⋮) menu is untouched.
  ///
  /// Selection is seeded to every contactable member, so an empty selection
  /// means the exec pressed Clear. The footer does not disappear on them: it
  /// keeps its line and offers the inverse of Clear. It does NOT repeat
  /// MOBILIZE, because a mobilize with no audience is a lie; mobilizing the
  /// whole region is the header's "Mobilize all n" (spec 2.5), which is on
  /// screen at the same time.
  Widget _actionBar(BuildContext context, _Palette p,
      {required int textCount, required int emailCount}) {
    final selected = _selectedMembers;
    final selCount = selected.length;
    if (selCount == 0) return _emptySelectionBar(context, p);
    // Skip counts operate on the whole selection, independent of the filter.
    final cantText = selected.where((m) => !m.canContact).length;
    final cantEmail =
        selected.where((m) => (m.preferredEmail ?? '').isEmpty).length;

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$selCount selected · $textCount textable · $emailCount emailable',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: p.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() => _selectedIds.clear()),
                child: Text('Clear',
                    style: TextStyle(
                        color: p.highlight,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Skip-reason surfacing (§5.3). The counts still describe the whole
          // selection rather than a channel, because the Desk picks the
          // channel now; it repeats these against whichever one is chosen.
          if (cantText > 0)
            _skipLine(
                p,
                "$cantText of $selCount can't be texted: no phone or opted out",
                () => _showSkipDetails(context, isText: true)),
          if (cantEmail > 0)
            _skipLine(
                p,
                "$cantEmail of $selCount can't be emailed: no email on file",
                () => _showSkipDetails(context, isText: false)),
          Row(
            children: [
              // The count on the button is the SELECTION, not the textable
              // subset: the Desk decides the channel, so promising a number
              // here that only holds for one of them would be a lie.
              Expanded(
                child: _actionButton(
                  icon: Icons.campaign_outlined,
                  label: 'MOBILIZE $selCount',
                  onTap: _mobilizeSelection,
                ),
              ),
              const SizedBox(width: 10),
              _moreMenu(context, p),
            ],
          ),
        ],
      ),
    );
  }

  /// The footer with nothing selected: the counts line and "Select all", the
  /// exact inverse of Clear. Both act on the whole region rather than the
  /// filtered view, so the pair stays symmetric no matter which chips are on.
  Widget _emptySelectionBar(BuildContext context, _Palette p) {
    // Still loading, or a region nobody lives in: the list above already says
    // so and a footer restating it would only take space from it.
    if (_d.members.isEmpty) return const SizedBox.shrink();
    final selectable = _d.members.where(_isSelectable).length;

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              selectable == 0
                  ? 'No one selected · nobody here can be texted or emailed'
                  : 'No one selected',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: p.secondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600),
            ),
          ),
          if (selectable > 0) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: _selectAllContactable,
              child: Text('Select all $selectable',
                  style: TextStyle(
                      color: p.highlight,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }

  /// Re-seed the selection to every contactable member of the region, which is
  /// what Clear undid. Deliberately the same set [_seedIfNeeded] starts from,
  /// so "Clear" then "Select all" is a round trip.
  void _selectAllContactable() {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(_d.members.where(_isSelectable).map((m) => m.id));
    });
  }

  /// Publish the current selection to the Desk. Candidates are left empty on
  /// purpose: the map attaches them, because it owns the result-row-to-profile
  /// classification and two derivations of that would drift.
  void _mobilizeSelection() {
    final members = _selectedMembers;
    if (members.isEmpty) return;
    widget.onMobilize(MobilizeRequest(
      members: members,
      regionMode: _d.mode,
      regionId: _d.id,
    ));
  }

  Widget _skipLine(_Palette p, String text, VoidCallback onDetails) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: p.secondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: TextStyle(color: p.secondary, fontSize: 11.5)),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onDetails,
            child: Text('Details',
                style: TextStyle(
                    color: p.highlight,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _moreMenu(BuildContext context, _Palette p) {
    return Material(
      color: p.inset,
      borderRadius: BorderRadius.circular(12),
      child: PopupMenuButton<String>(
        tooltip: 'More actions',
        position: PopupMenuPosition.under,
        onSelected: (value) {
          switch (value) {
            case 'mark':
              _markContactedToday(context);
              break;
            case 'note':
              _recordContactNote(context);
              break;
            case 'copy':
              _copyNames(context);
              break;
            case 'csv':
              _exportCsv(context);
              break;
          }
        },
        itemBuilder: (context) => [
          _moreItem('mark', Icons.event_available_outlined,
              'Mark contacted today'),
          _moreItem('note', Icons.note_add_outlined, 'Record contact note'),
          _moreItem('copy', Icons.copy_all_outlined, 'Copy names'),
          _moreItem('csv', Icons.download_outlined, 'Export CSV'),
        ],
        child: Container(
          height: 46,
          width: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.divider),
          ),
          child: Icon(Icons.more_vert, size: 20, color: p.text),
        ),
      ),
    );
  }

  PopupMenuItem<String> _moreItem(String value, IconData icon, String label) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }

  String _textSkipReason(Member m) {
    if (m.optOut) return 'opted out';
    if ((m.phoneE164 ?? '').isEmpty) return 'no phone';
    if (m.membershipEligible != true) return 'not eligible';
    return 'cannot be texted';
  }

  Future<void> _showSkipDetails(BuildContext context,
      {required bool isText}) async {
    final skipped = isText
        ? _selectedMembers.where((m) => !m.canContact).toList()
        : _selectedMembers
            .where((m) => (m.preferredEmail ?? '').isEmpty)
            .toList();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _dialogSurface,
        shape: _dialogShape,
        titleTextStyle: _dialogTitleText,
        contentTextStyle: _dialogBodyText,
        title: Text(isText ? "Can't be texted" : "Can't be emailed"),
        content: SizedBox(
          width: double.maxFinite,
          child: skipped.isEmpty
              ? const Text('No skipped members.')
              : ListView(
                  shrinkWrap: true,
                  children: skipped
                      .map((m) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(m.name, style: _dialogListTitleText),
                            subtitle: Text(
                                isText ? _textSkipReason(m) : 'no email on file',
                                style: _dialogListSubtitleText),
                          ))
                      .toList(),
                ),
        ),
        actions: [
          TextButton(
              style: _dialogPrimaryAction,
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close')),
        ],
      ),
    );
  }

  String _todayStamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  Future<void> _markContactedToday(BuildContext context) async {
    final members = _selectedMembers;
    if (members.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    var ok = 0;
    var failed = 0;
    for (final m in members) {
      final wrote = await _repo.updateLastContacted(m.id);
      if (wrote) {
        _lastContactedOverride[m.id] = now;
        ok++;
      } else {
        failed++;
      }
    }
    if (!mounted) return;
    setState(() {});
    messenger.showSnackBar(SnackBar(
      content: Text(failed == 0
          ? 'Marked $ok as contacted today'
          : 'Marked $ok as contacted, $failed failed'),
    ));
  }

  Future<void> _recordContactNote(BuildContext context) async {
    final members = _selectedMembers;
    if (members.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    var alsoContacted = true;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _dialogSurface,
          shape: _dialogShape,
          titleTextStyle: _dialogTitleText,
          contentTextStyle: _dialogBodyText,
          title: Text(
              'Record note · ${members.length} member${members.length == 1 ? '' : 's'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                // Typed text and hint are stated against the navy surface:
                // white at 12.51:1 and white60 at 5.58:1. The field would
                // otherwise take both from the ambient theme.
                style: _dialogListTitleText,
                cursorColor: BrandColors.sunriseGold,
                decoration: const InputDecoration(
                  hintText: 'Note (appended to each member\'s existing notes)',
                  hintStyle: _dialogListSubtitleText,
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38)),
                  focusedBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: BrandColors.sunriseGold, width: 2)),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: alsoContacted,
                activeColor: _dialogCheckFill,
                checkColor: _dialogCheckMark,
                side: _dialogCheckSide,
                title: const Text('Also mark as contacted today',
                    style: _dialogListTitleText),
                onChanged: (v) =>
                    setDialogState(() => alsoContacted = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
                style: _dialogQuietAction,
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            TextButton(
                style: _dialogPrimaryAction,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );

    final entry = controller.text.trim();
    controller.dispose();
    if (save != true || entry.isEmpty || !mounted) return;

    final today = _todayStamp();
    final now = DateTime.now();
    var ok = 0;
    var failed = 0;
    for (final m in members) {
      // NEVER replace notes: append to the member's existing notes. Read the
      // current notes (override wins so repeated appends chain), then append.
      final base = (_effectiveNotes(m) ?? '').trim();
      final appended = '$base\n[$today] $entry'.trim();
      final noteWrote = await _repo.updateNotes(m.id, appended);
      if (!noteWrote) {
        failed++;
        continue;
      }
      _notesOverride[m.id] = appended;
      if (alsoContacted) {
        final contactWrote = await _repo.updateLastContacted(m.id);
        if (contactWrote) _lastContactedOverride[m.id] = now;
      }
      ok++;
    }
    if (!mounted) return;
    setState(() {});
    messenger.showSnackBar(SnackBar(
      content: Text(failed == 0
          ? 'Saved note for $ok member${ok == 1 ? '' : 's'}'
          : 'Saved note for $ok, $failed failed'),
    ));
  }

  Future<void> _copyNames(BuildContext context) async {
    final members = _selectedMembers;
    if (members.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(
        ClipboardData(text: members.map((m) => m.name).join('\n')));
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(
          'Copied ${members.length} name${members.length == 1 ? '' : 's'}'),
    ));
  }

  Future<void> _exportCsv(BuildContext context) async {
    final members = _selectedMembers;
    if (members.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    var includePii = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _dialogSurface,
          shape: _dialogShape,
          titleTextStyle: _dialogTitleText,
          contentTextStyle: _dialogBodyText,
          title: const Text('Export CSV'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Export ${members.length} selected member${members.length == 1 ? '' : 's'}.'),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: includePii,
                activeColor: _dialogCheckFill,
                checkColor: _dialogCheckMark,
                side: _dialogCheckSide,
                title: const Text('Include phone and email',
                    style: _dialogListTitleText),
                subtitle: const Text(
                    'Personal contact data will leave the system.',
                    style: _dialogListSubtitleText),
                onChanged: (v) => setDialogState(() => includePii = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
                style: _dialogQuietAction,
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            TextButton(
                style: _dialogPrimaryAction,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Export')),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final headers = <String>[
      'name',
      'county',
      'congressional_district',
      'house_district',
      'senate_district',
      'textable',
      'emailable',
    ];
    if (includePii) {
      headers
        ..add('phone_e164')
        ..add('preferred_email');
    }

    final buffer = StringBuffer();
    buffer.writeln(headers.map(_csvEscape).join(','));
    for (final m in members) {
      final row = <String>[
        m.name,
        m.county ?? '',
        m.congressionalDistrict ?? '',
        m.houseDistrict ?? '',
        m.senateDistrict ?? '',
        m.canContact ? 'yes' : 'no',
        (m.preferredEmail ?? '').isNotEmpty ? 'yes' : 'no',
      ];
      if (includePii) {
        row
          ..add(m.phoneE164 ?? '')
          ..add(m.preferredEmail ?? '');
      }
      buffer.writeln(row.map(_csvEscape).join(','));
    }

    if (!kIsWeb) {
      messenger.showSnackBar(const SnackBar(
          content: Text('CSV export is only available on the web app.')));
      return;
    }

    try {
      final blob = html.Blob([buffer.toString()], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'members-${_todayStamp()}.csv')
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
      messenger.showSnackBar(SnackBar(
        content: Text(
            'Exported ${members.length} member${members.length == 1 ? '' : 's'}'),
      ));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('CSV export failed: $e')));
    }
  }

  /// Minimal RFC-4180-ish CSV field escape: quote fields containing a comma,
  /// quote, or newline and double embedded quotes.
  String _csvEscape(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Pinned action-bar primary. Emphasis pair, unityBlue on sunriseGold at
  /// 7.17:1; it was white on momentumBlue at 2.75:1, which fails the 4.5:1
  /// text bar.
  ///
  /// The disabled state went with Text and Email. The bar itself only renders
  /// while something is selected, so its one button is never dimmed, and an
  /// always-true flag with a dead branch behind it is worse than no flag.
  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final p = _Palette.of(context);
    return Material(
      color: p.emphasisFill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: p.onEmphasis),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: p.onEmphasis,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── shared building blocks ─────────────────────────────────────────
Widget _sectionHeader(_Palette p, String label) => Row(
      children: [
        Container(
          width: 20,
          height: 3,
          decoration: BoxDecoration(
            color: p.highlight,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(label,
              style: TextStyle(
                  color: p.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1)),
        ),
      ],
    );

Widget _panelSpinner(_Palette p, String label) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: p.accent),
            ),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(color: p.secondary, fontSize: 12.5)),
          ],
        ),
      ),
    );

Widget _emptyBox(
  _Palette p, {
  required Color circle,
  required IconData icon,
  required Color iconColor,
  required String title,
  required String body,
  Widget? action,
}) {
  return Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: p.inset,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: circle, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        const SizedBox(height: 14),
        Text(title,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: p.text, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(body,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.secondary, fontSize: 12.5)),
        if (action != null) ...[
          const SizedBox(height: 16),
          action,
        ],
      ],
    ),
  );
}

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}
