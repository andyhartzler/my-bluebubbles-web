# Slack Page Design Spec — reference for Donors Page overhaul

**Purpose:** Andrew said the MOYD CRM's Slack Management page look is exactly what he wants for the new Donors page and its tabs. This doc captures the visual language in enough detail that a UI-rewrite agent can mirror it without guessing.

**Source screen:** `SlackManagementScreen` (standalone + embedded) in
- `/Users/moyd/my-bluebubbles-web/lib/features/slack/screens/slack_management_screen.dart`

**How it's reached / embedded:**
- Standalone push from dashboard: `/Users/moyd/my-bluebubbles-web/lib/screens/dashboard/dashboard_screen.dart:1150-1158` → `TitleBarWrapper(child: SlackManagementScreen())`
- Embedded in main tabbed view: `/Users/moyd/my-bluebubbles-web/lib/main.dart:1021-1024` with `embed: true`

---

## 1. Key files (Slack page surface)

| File | Role |
|---|---|
| `lib/features/slack/screens/slack_management_screen.dart` | Scaffold + branded AppBar + gradient TabBar + TabBarView with `BrandedBackground`. Entrypoint. |
| `lib/features/slack/widgets/analytics_tab.dart` | The "hero" tab: gradient header card, 4 gradient stat cards, line chart, bar charts, top-N cards with progress bars, membership feed. Prime visual reference. |
| `lib/features/slack/widgets/channels_tab.dart` | Two-pane layout: 280px navy-gradient sidebar (channels) + message feed with gradient channel header + search + message bubbles. |
| `lib/features/slack/widgets/channel_sidebar.dart` | Plain-themed channel list item (used in the nested sidebar body). |
| `lib/features/slack/widgets/unmatched_users_tab.dart` | Gradient header + filter chips + gradient user cards with avatar, info chips, action buttons. |
| `lib/features/slack/widgets/ineligible_members_tab.dart` | Gradient header with red "Action Required" pill + branded empty/error states. |
| `lib/features/slack/widgets/message_bubble.dart` | Message row widget — used in channel feed and user messages dialog. |
| `lib/features/committees/theme/brand_colors.dart` | **The design system.** `BrandColors`, `BrandedCard`, `BrandedBackground`, `BrandTextStyles`. |

---

## 2. Color palette (the design system)

From `/Users/moyd/my-bluebubbles-web/lib/features/committees/theme/brand_colors.dart:10-106`:

**Primary brand (the navy gradient that defines every card):**
- `BrandColors.unityBlue` = `#273351` (deep navy — tile gradient start)
- `BrandColors.momentumBlue` = `#32A6DE` (light blue — tile gradient end)
- `BrandColors.sunriseGold` = `#FDB813` (gold accent — tab indicator, refresh buttons, chart line, "linked" highlights)

**Gradients (pre-defined at `brand_colors.dart:54-60`):**
- `BrandColors.tileGradient = [unityBlue, momentumBlue]` — used on *almost every* header/card
- `BrandColors.backgroundGradient = [momentumBlue, unityBlue]` — dialog/background fills
- `begin: Alignment.topLeft, end: Alignment.bottomRight` (universal direction)

**Per-card accent gradients (Analytics tab, `analytics_tab.dart:290-295`):**
- Messages card: `[#273351, #32A6DE]` (default navy)
- Channels card: `[#10B981, #059669]` (emerald green)
- Users card: `[#8B5CF6, #7C3AED]` (purple)
- Unmatched card: `[#F59E0B, #D97706]` (amber, only if `>0`, else grey `[shade600, shade500]`)
- "Day of Week": `[#06B6D4, #0891B2]` (cyan)
- "Hour of Day": `[#EC4899, #DB2777]` (pink)

**Semantic:**
- `success` `#10B981`, `warning` `#F59E0B`, `error` `#EF4444` (`brand_colors.dart:39-41`)

**Background:**
- Asset image `assets/images/Blue-Gradient-Background.png` with `0.18` white overlay (`BrandedBackground` at `brand_colors.dart:128-170`). Fallback is a `momentumBlue → unityBlue` linear gradient.

---

## 3. Typography (on navy cards)

From `BrandTextStyles` (`brand_colors.dart:220-266`) and literal uses across the Slack tabs:

| Purpose | Style |
|---|---|
| Page-hero title | `color: white, fontSize: 22, fontWeight: bold` (analytics hero, `analytics_tab.dart:224-228`) |
| Section card title | `color: white, fontSize: 18, fontWeight: bold` (every `_buildXxxCard` header) |
| Card subtitle / "Last updated" | `color: white70, fontSize: 13` |
| Stat card label | `color: white70, fontSize: 13, fontWeight: w500` (`analytics_tab.dart:1457-1461`) |
| Stat card value | `color: white, fontSize: 32, fontWeight: bold` (`analytics_tab.dart:1470-1474`) |
| Stat card sub-subtitle | `color: white60, fontSize: 12` |
| Tab label | `fontWeight: w600, fontSize: 13` (selected); `normal, 13` (unselected) |
| Small caption on card | `color: white60, fontSize: 11-12` |
| List item primary | `color: white, fontWeight: w500/w600` |
| List item secondary | `color: white70, fontSize: 12-13` |

`BrandTextStyles` also exposes `.title`, `.titleLarge`, `.stat`, `.statLabel`, `.subtitle`, `.body`, `.bodySecondary`, `.caption` — use these when possible instead of inlining.

---

## 4. Reusable widgets

Already built and ready to reuse for Donors:

| Widget | Import | What it does |
|---|---|---|
| `BrandedCard` | `lib/features/committees/theme/brand_colors.dart:173-217` | Rounded gradient card with `elevation: 4`, `borderRadius: 16`, optional `onTap` InkWell, `padding: EdgeInsets.all(16)` default. Takes `gradientColors` to override. **Use this everywhere.** |
| `BrandedBackground` | `brand_colors.dart:128-170` | Wraps body with the light-blue background image + 18% white overlay. |
| `BrandTextStyles` | `brand_colors.dart:220-266` | Pre-cooked text styles for navy backgrounds. |
| `_BrandedSummaryCard` | `lib/features/slack/widgets/analytics_tab.dart:1420-1487` (private — **extract/copy** for Donors) | 4-across stat tile with icon badge, title, 32px value, optional subtitle. |
| `CorsAwareAvatar` | `lib/features/committees/widgets/cors_aware_avatar.dart` | Avatar with URL fallback, handles CORS issues. |
| `SlackMessageBubble` | `lib/features/slack/widgets/message_bubble.dart` | Message row with avatar + name + text + reactions. (Not needed for donors but demonstrates the pattern.) |

**Recommendation:** promote `_BrandedSummaryCard` to a public `BrandedSummaryCard` in `brand_colors.dart` (or a sibling file) so Donors can import it directly.

---

## 5. Tab bar design (for Slack's 4 tabs)

`slack_management_screen.dart:60-95`:

```
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: BrandColors.tileGradient,   // navy→blue
      begin: topLeft, end: bottomRight,
    ),
  ),
  child: SafeArea(
    bottom: false,
    child: TabBar(
      tabs: [Tab(icon: Icon(...), text: '...'), ...],
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: BrandColors.sunriseGold,   // <-- gold underline!
      indicatorWeight: 3,
      labelStyle: TextStyle(fontWeight: w600, fontSize: 13),
      unselectedLabelStyle: TextStyle(fontWeight: normal, fontSize: 13),
    ),
  ),
),
```

**Tabs pattern:** each has an **icon + text label**. Icons used: `Icons.tag`, `Icons.person_search`, `Icons.person_off`, `Icons.analytics`.

**Gold underline on the active tab is the single most distinctive cue** — mirror this exactly on Donors.

---

## 6. Standalone AppBar (only non-embedded)

`slack_management_screen.dart:123-142`:
- `title: 'Slack Management'` — `white, fontWeight: w600`
- `elevation: 0`
- `flexibleSpace`: Container with `tileGradient` (navy→blue diagonal)
- `iconTheme: white`

For embedded mode (`embed: true`) there is **no AppBar** — the consumer provides chrome.

---

## 7. Screenshot-equivalent walkthrough (top → bottom, Analytics tab as reference)

### 7.1 Header ("hero row") — `analytics_tab.dart:201-286`
- `BrandedCard` with `tileGradient`, `padding: 20`.
- Left: 12-padded white-20% opacity square tile (radius 12) containing an `Icons.analytics` white icon (size 28).
- Center: two stacked `Text`s — page title (22/bold/white) + "Last updated: …" (13/white70).
- Right: pill-shaped `DropdownButton` (time period `30/60/90 days`) — white-15% opacity background, radius 8, `unityBlue` dropdown menu color, white text.
- Right-most: `ElevatedButton.icon` — `backgroundColor: sunriseGold, foregroundColor: unityBlue`, "Refresh" label with refresh icon.

### 7.2 Summary stat grid — `analytics_tab.dart:288-359`
- `Wrap` with `spacing: 16, runSpacing: 16`.
- Responsive: 4 columns ≥600px wide, 2 columns below.
- Each card = `_BrandedSummaryCard`:
  - Own gradient (Navy / Green / Purple / Amber)
  - Top row: 10-padded icon tile (white-20% opacity, radius 10, white icon size 22) + title (13/white70)
  - 16px spacer
  - 32px bold white value
  - Optional 12px white60 subtitle

### 7.3 Large line chart card — `analytics_tab.dart:361-528`
- `BrandedCard` with `tileGradient`, `padding: 20`.
- Header row: icon badge (Icons.trending_up) + 18/bold/white title.
- `LineChart` (fl_chart), height 200:
  - Line color = `sunriseGold`, `barWidth: 3`, curved (`isCurved: true, curveSmoothness: 0.3`).
  - Gradient fill below line: sunriseGold 0.3 → 0.05.
  - Grid lines: white-10% opacity.
  - Tooltip bg: `unityBlue`.

### 7.4 Two-up responsive row (Top Channels / Top Users) — `analytics_tab.dart:150-170, 530-793`
- `LayoutBuilder`: stack vertically below 800px, side-by-side above (with `Expanded` + 16px `SizedBox` spacer).
- Each card = `BrandedCard` with its *own* accent gradient (green for channels, purple for users).
- Inside: numbered `rank badge` (24×24, white-20% opacity, radius 6, bold white number) + name + count (right-aligned, bold white) + `LinearProgressIndicator` (min 6px height, white fill on white-20% track, radius 4, clip-rrect).
- Users have a chevron-right on each row and may show an orange `!` badge if unlinked.

### 7.5 Second two-up responsive row (Day of Week / Hourly) — `analytics_tab.dart:822-1112`
- Same responsive pattern.
- `BarChart` with 150px height.
- Day card: cyan gradient, white bars (width 24, top-rounded 6) on white-10% opacity track.
- Hour card: pink gradient, thin bars (width 8, top-rounded 3). **Work hours (9–17) are highlighted sunriseGold**, others are white-70% opacity.
- Tooltip bg: `unityBlue`.

### 7.6 Activity feed — `analytics_tab.dart:1114-1305`
- `BrandedCard` with `tileGradient`.
- Each item is a `Container` with:
  - `color: Colors.white.withOpacity(0.1)` (subtle lift on the gradient card)
  - `borderRadius: 10, padding: 12, margin-bottom: 8`
  - `InkWell` onTap → navigates to detail.
- Left: `CorsAwareAvatar` (radius 20) with a tiny circular green/red badge overlaid in the bottom-right showing `+`/`−` icon (the join/leave indicator).
- Middle: name (white/bold) + channel pill (`Icons.tag` + channel name in white70/12px).
- Right: ACTION pill (green/red with 0.8 opacity, radius 4, 10px uppercase white) + timestamp (white60/11px).
- Trailing: `Icons.chevron_right, white70`.

---

## 8. Secondary tabs patterns

### 8.1 Channels tab (`channels_tab.dart:401-511`)
- **Desktop (>800px):** `Row` with:
  - 280px fixed sidebar, solid `tileGradient` (top→bottom), containing a header ("Channels" + channel-count pill) and a `ListView` of channels.
  - Right pane: gradient channel header (Icons.tag in icon badge, "#channel-name" 18/bold/white, committee name + message count in white70, archive timestamp pill on far right) + search bar + message list.
- **Mobile (<800px):** gradient `_BrandedChannelDropdown` at top, full-width message pane below.
- The search `TextField` uses a **white rounded fill** (`momentumBlue @ 5%` opacity), with `unityBlue` text/hints and `momentumBlue` icons — the only place where the navy-on-white inversion appears (to give search a clean affordance).

### 8.2 Unmatched Users tab (`unmatched_users_tab.dart:257-370, 528-720`)
- Gradient header identical pattern: icon badge + title + subtitle ("N users need to be matched") + refresh IconButton.
- Filter chips row: `FilterChip` with white-15% transparent unselected / solid white selected (selected text = unityBlue, unselected text = white). `checkmarkColor: unityBlue`.
- User cards: navy gradient Container (radius 16, unityBlue-30% shadow offset (0,3) blur 6; increases to blur 12 when `isHighlighted` with a sunriseGold 3px border).
  - Inside: avatar (radius 28) + name (white/17/bold) + optional "Rejected" red-30% pill.
  - `Wrap` of info chips (email, date) — green chip for success, red chip for missing email, white-70% for neutral.
  - Notes block: white-10% opacity container, radius 8, momentumBlue icon.
  - Action row: "Match to Member" `ElevatedButton` with momentumBlue background + "Create Member" `OutlinedButton` (white70 border/foreground) + "Reject" `TextButton` (red300).

### 8.3 Ineligible Members tab (`ineligible_members_tab.dart:67-211`)
- Same gradient header pattern with an extra red-30% "Action Required" mini-pill inline with the subtitle.
- Uses **`BrandColors.success`/`error` color-tinted circular badges** (0.1 opacity fill) around 48px icons for empty/error states — light-mode copy is `unityBlue`.

---

## 9. Spacing / padding conventions

- **Outermost list padding:** `EdgeInsets.all(16)` (analytics scroll view, channel sidebar lists, unmatched list).
- **Card inner padding:** `EdgeInsets.all(20)` for the big cards, `EdgeInsets.all(16)` for smaller tiles, `EdgeInsets.all(12)` for in-card feed items.
- **Icon badge inside cards:** `padding: 8` (small, radius 8) or `padding: 10` (larger, radius 10) or `padding: 12` (hero only, radius 12).
- **Gap between major sections:** `SizedBox(height: 24)` between cards; `16` between related cards in a row; `12` between header row and content; `8-12` tight stacks.
- **Corner radius:** **16** for the big cards (`BrandedCard` default), **10** for in-card sub-containers, **8** for chips/pills, **6** for rank badges, **4** for tiny badges.
- **Shadows:** `BrandColors.unityBlue.withOpacity(0.3)`, `blurRadius: 6, offset: (0, 3)` on user cards. `BrandedCard` itself uses Material `elevation: 4`.

---

## 10. Empty / loading / error states

Every tab follows the same pattern (see `ineligible_members_tab.dart:174-260` and `analytics_tab.dart:1358-1407` for reference implementations):

- **Loading:** `Center(child: CircularProgressIndicator(color: BrandColors.momentumBlue))` — light-blue spinner.
- **Empty (positive):** Circular tinted badge (e.g. `success.withOpacity(0.1)`) containing a 48-64px semantic icon → 20px spacer → title (unityBlue, 18/w600) → 8px spacer → description (unityBlue 70%, 14).
- **Empty (neutral grey):** within-card variant uses `BrandedCard(gradientColors: [grey600, grey500])` with a 48px white-54% icon (`analytics_tab.dart:1358-1383`).
- **Error:** circular `error.withOpacity(0.1)` badge with 48px `Icons.error_outline` in `BrandColors.error` → message text → `ElevatedButton.icon` (Retry) with `refresh` icon.

---

## 11. Distinctive visual elements to preserve on Donors

These are the things that make the Slack page feel *Slack-page-like* — don't drop any of them:

1. **Gradient TabBar header** with gold underline indicator (`indicatorColor: sunriseGold, indicatorWeight: 3`).
2. **`BrandedBackground`** wraps all tab content (blue-gradient image w/ 18% white overlay).
3. **Everything is a gradient card** — no flat Material Cards. `BrandedCard` with navy→blue by default; per-section accent gradients for variety.
4. **White text on navy**, with `white70`/`white60` opacity steps for hierarchy.
5. **Icon-in-tile** pattern: every section header leads with a small rounded tile (`white.withOpacity(0.2)`, radius 8-12) wrapping a white icon.
6. **Sunrise-gold accents**: tab underline, refresh button fill, line-chart stroke, highlighted card border, "work hours" bars.
7. **Responsive `LayoutBuilder` rows** collapse to stacked columns below ~600-800px.
8. **Integer rank badges** (`24×24`, white-20% opacity, radius 6) paired with inline `LinearProgressIndicator` bars (min height 6, radius 4) for top-N lists.
9. **Action pills** (join/leave, rejected, "!") — small rounded rectangles with 0.8 opacity colored fills and 10px uppercase text.
10. **Inline `!` orange badges** on unlinked/problematic list items.
11. **Timestamps on the right in `white60`/11-12px**.

---

## 12. Suggested mapping for Donors page

For the Donors Page overhaul, mirror this layout:

| Slack feature | Donor equivalent |
|---|---|
| Analytics tab (hero) | Donor dashboard tab: total raised / donor count / average gift / recurring count stat cards; giving-over-time line chart; top donors/top funds; recent gifts feed. |
| Channels tab (two-pane) | Donor list with sidebar filters (campaign, chapter, segment) + main pane with selected donor detail or filtered gift list. |
| Unmatched tab | Unmatched ActBlue/MEC contributions awaiting attribution to a donor record — same gradient-card-with-action-buttons pattern. |
| Ineligible tab | Could be "Duplicate candidates" or "Flagged donors" — same red "Action Required" header treatment. |

Use `BrandedCard`, `BrandedBackground`, the 4-tab gradient TabBar, and the `_BrandedSummaryCard` stat tiles as the starting kit.

---

## 13. Quick-reference file:line anchors

- TabBar gradient + gold indicator: `lib/features/slack/screens/slack_management_screen.dart:64-95`
- Hero header card (title + dropdown + refresh): `lib/features/slack/widgets/analytics_tab.dart:201-286`
- 4-card stat grid + per-card gradient palette: `lib/features/slack/widgets/analytics_tab.dart:288-359`
- `_BrandedSummaryCard` body (32px bold value): `lib/features/slack/widgets/analytics_tab.dart:1420-1487`
- Line chart (sunrise-gold stroke + fill): `lib/features/slack/widgets/analytics_tab.dart:415-522`
- Top-N progress-bar list: `lib/features/slack/widgets/analytics_tab.dart:572-637`
- Membership feed items (pills + chevron): `lib/features/slack/widgets/analytics_tab.dart:1168-1306`
- In-card empty state (grey gradient): `lib/features/slack/widgets/analytics_tab.dart:1358-1383`
- Error state (retry button): `lib/features/slack/widgets/analytics_tab.dart:1385-1407`
- Sidebar + message pane two-column: `lib/features/slack/widgets/channels_tab.dart:401-464`
- Filter chips (white-on-navy flip): `lib/features/slack/widgets/unmatched_users_tab.dart:350-370`
- Highlighted card with gold border: `lib/features/slack/widgets/unmatched_users_tab.dart:531-550`
- `BrandedCard` definition: `lib/features/committees/theme/brand_colors.dart:173-217`
- `BrandedBackground` wrapper: `lib/features/committees/theme/brand_colors.dart:128-170`
- Full palette + gradients: `lib/features/committees/theme/brand_colors.dart:10-106`
- `BrandTextStyles` presets: `lib/features/committees/theme/brand_colors.dart:220-266`
