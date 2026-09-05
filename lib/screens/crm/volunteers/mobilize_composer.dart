import 'dart:async';

import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/bulk_send_result.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/message_filter.dart';
import 'package:bluebubbles/models/crm/outreach_touchpoint.dart';
import 'package:bluebubbles/screens/crm/file_picker_materializer.dart';
import 'package:bluebubbles/services/crm/crm_email_service.dart';
import 'package:bluebubbles/services/crm/crm_message_service.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/touchpoint_repository.dart';
import 'package:bluebubbles/utils/markdown_quill_loader.dart';
import 'package:bluebubbles/utils/quill_html_converter.dart';

import 'candidate_volunteers_map.dart' show DeskChanges;
import 'volunteers_theme.dart';

// ═══════════════════════════════════════════════════════════════
//  THE MOBILIZE DESK COMPOSER
//
//  Before this file, "Send" on the Desk pushed BulkMessageScreen or
//  BulkEmailScreen as a full-screen route, so the words an exec wrote lived in
//  a different destination from the people they were going to, and the Desk
//  could only learn what happened from the result the route popped. The
//  composer now sits INSIDE the SEND section: the exec writes here, sends from
//  here, and the outcome replaces the composer in place.
//
//  Division of labour with MobilizeDeskScreen:
//   • The Desk owns the AUDIENCE, the nominees, the region, the acting exec
//     and the geo derivation. It hands those in. It also HOLDS the draft, as
//     a [MobilizeDraftState] that lives as long as the Desk does, because the
//     composer is a collapsible section body and the framework unmounts it
//     for reasons that have nothing to do with abandoning the message.
//   • The composer DRIVES the WORDS, the attachments and the touchpoint row's
//     lifecycle (create, debounce, flush, claim, resolve, discard) and the
//     send itself. It reads and writes them through the handed-in draft, so
//     no unmount can lose them.
//  Neither reaches into the other's half. The one place they meet is
//  [MobilizeComposer.draftBuilder], which turns the composer's content plus a
//  recipient list into the row the Desk knows how to stamp with geo.
//
//  Every colour resolves from [VolunteersTheme]. Never Theme.of(context).
//  Fields sit on vt.surface with white content, which is the palette's
//  documented 12.51:1 pair; anything filled that carries a LABEL uses
//  vt.emphasisFill / vt.onEmphasis at 7.17:1. vt.accent never carries text.
// ═══════════════════════════════════════════════════════════════

// ───────────────────────────────────────────────────────────────
//  MERGE FIELDS
//
//  Lifted verbatim in behaviour from bulk_email_screen.dart, and made PUBLIC
//  here so there is one definition rather than two that drift. The email
//  screen still carries private copies (_mergeFieldDefinitions,
//  _supportedMergeKeys, _mergeFallbacks, _unsupportedMergeTokens,
//  _buildRecipientVariables and the name-derivation helpers); those should be
//  deleted in favour of this class, which is a change to a file outside this
//  workspace and is reported rather than made here.
// ───────────────────────────────────────────────────────────────

/// One offered merge chip. [token] is what gets inserted at the cursor and is
/// also what the send guard scans for.
@immutable
class MergeFieldDefinition {
  const MergeFieldDefinition({
    required this.token,
    required this.label,
    required this.description,
  });

  final String token;
  final String label;
  final String description;
}

/// The merge contract between the composer and the send-email function.
///
/// The server substitutes only the keys it is GIVEN for a recipient, so an
/// offered chip with no per-recipient value is delivered as the literal text
/// `{{chapter_name}}`. Two rules follow, and both live here so neither can be
/// half-applied: every supported key always resolves to something (see
/// [fallbacks]), and any token that is not a supported key refuses the send
/// (see [unsupportedTokens]).
class ComposerMergeFields {
  ComposerMergeFields._();

  static const List<MergeFieldDefinition> definitions = <MergeFieldDefinition>[
    MergeFieldDefinition(
      token: '{{first_name}}',
      label: 'First name',
      description: "The member's preferred first name when we have one.",
    ),
    MergeFieldDefinition(
      token: '{{full_name}}',
      label: 'Full name',
      description: "The member's full recorded name.",
    ),
    MergeFieldDefinition(
      token: '{{email}}',
      label: 'Email',
      description: 'The address this copy is going to.',
    ),
    MergeFieldDefinition(
      token: '{{chapter_name}}',
      label: 'Chapter',
      description: "The member's chapter, if any.",
    ),
  ];

  /// The keys [variablesFor] can supply, derived from the offered chips so the
  /// two cannot drift apart.
  static final Set<String> supportedKeys = definitions
      .map((d) => d.token.replaceAll(RegExp(r'[{}\s]'), ''))
      .toSet();

  /// Only the double-brace form the server substitutes. `mergeTemplate` in
  /// send-email matches `{{\s*key\s*}}` and nothing else, so a single-brace
  /// `{foo}` is literal text. Scanning for the single-brace form would also
  /// match CSS rules inside the generated HTML and block legitimate sends.
  static final RegExp _substitutable = RegExp(r'\{\{\s*([^{}]+?)\s*\}\}');

  /// Wording used when a recipient has no value for a supported key. These
  /// read as ordinary prose so a fallback never looks like a failure: "Hi
  /// Friend," is a greeting, "Hi {{first_name}}," is a bug report.
  static const Map<String, String> fallbacks = <String, String>{
    'full_name': 'Friend',
    'first_name': 'Friend',
    'chapter_name': 'your chapter',
  };

  /// Every substitutable token in the outgoing content whose key nothing can
  /// fill, in the `{{name}}` form the exec typed, deduplicated and sorted.
  ///
  /// Supplying the variables map always resolves the SUPPORTED tokens; only
  /// refusing the send stops an unsupported one, because the server leaves a
  /// key it was not given untouched and the member reads the raw token.
  static List<String> unsupportedTokens({
    String? subject,
    String? plainText,
    String? html,
  }) {
    final unsupported = <String>{};
    for (final source in <String?>[subject, plainText, html]) {
      if (source == null || source.isEmpty) continue;
      for (final match in _substitutable.allMatches(source)) {
        final key = match.group(1)?.trim();
        if (key == null || key.isEmpty) continue;
        if (!supportedKeys.contains(key)) unsupported.add('{{$key}}');
      }
    }
    return unsupported.toList()..sort();
  }

  /// The merge map for one recipient, guaranteeing a value for every supported
  /// key.
  static Map<String, dynamic> variablesFor({
    required String email,
    Member? member,
  }) {
    final variables = <String, dynamic>{'email': email};

    void put(String key, String? value) {
      final trimmed = value?.trim();
      variables[key] = (trimmed != null && trimmed.isNotEmpty)
          ? trimmed
          : (fallbacks[key] ?? '');
    }

    final fullName = _fullName(member, email);
    put('full_name', fullName);
    put('first_name', _firstName(member, fullName, email));
    put('chapter_name', member?.chapterName);

    // If a chip is added to [definitions] without a matching put() above, this
    // catches it here instead of in a member's inbox.
    assert(
      supportedKeys.every(variables.containsKey),
      'Merge chip offered with no per-recipient value: '
      '${supportedKeys.where((k) => !variables.containsKey(k))}',
    );

    return variables;
  }

  static String? _fullName(Member? member, String email) {
    final recorded = member?.name.trim();
    if (recorded != null && recorded.isNotEmpty) return recorded;
    return _nameFromEmail(email);
  }

  static String? _firstName(Member? member, String? fullName, String email) {
    final recorded = member?.name.trim();
    final source = (recorded != null && recorded.isNotEmpty)
        ? recorded
        : (fullName ?? _nameFromEmail(email));
    if (source == null || source.trim().isEmpty) return null;
    final parts = source.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? null : _capitalize(parts.first);
  }

  /// Local parts that name a function rather than a person. Greeting a shared
  /// mailbox by its local part produces "Hi Info" in a member's inbox.
  static const Set<String> _roleAccounts = <String>{
    'admin', 'alerts', 'billing', 'board', 'chair', 'chapter', 'committee',
    'contact', 'donate', 'donations', 'events', 'exec', 'finance', 'help',
    'hello', 'hi', 'info', 'inquiries', 'mail', 'marketing', 'media', 'members',
    'membership', 'news', 'newsletter', 'noreply', 'no', 'reply', 'office',
    'outreach', 'press', 'privacy', 'sales', 'secretary', 'staff', 'support',
    'team', 'treasurer', 'volunteer', 'volunteers', 'webmaster',
  };

  /// A display name from an address local part, but only when that local part
  /// plausibly names a PERSON. A wrong name is worse than no name: these feed
  /// greetings, so a bad derivation is read and an absent one is not. The gate
  /// is biased to false negatives.
  static String? _nameFromEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return null;
    var local = email.substring(0, at);

    // RFC 5233 subaddressing: everything after '+' is routing metadata.
    final plus = local.indexOf('+');
    if (plus >= 0) local = local.substring(0, plus);

    // A digit means an account handle rather than a name, as in team2026.
    if (local.contains(RegExp(r'[0-9]'))) return null;

    final words = local
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return null;
    if (words.any((w) => _roleAccounts.contains(w.toLowerCase()))) return null;

    // A single-letter leading word is an initial, so j.smith would be greeted
    // as "Hi J".
    if (words.first.length < 2) return null;

    // A local part carries no meaningful casing, since MARY.JONES and
    // mary.jones are the same mailbox, so lowercase before capitalizing. A
    // recorded member name does assert its casing and is left alone.
    return words.map((w) => _capitalize(w.toLowerCase())).join(' ');
  }

  static String _capitalize(String word) {
    if (word.isEmpty) return word;
    if (word.length == 1) return word.toUpperCase();
    return word.substring(0, 1).toUpperCase() + word.substring(1);
  }
}

// ───────────────────────────────────────────────────────────────
//  LINKS
// ───────────────────────────────────────────────────────────────

/// The anchor scheme allowlist and the normalizer that matches it, public for
/// the same reason the merge kit is: bulk_email_screen.dart holds a private
/// copy (_allowedLinkSchemes, _normalizeLinkUrl, _linkRejectionMessage) that
/// should be deleted in favour of this one.
class ComposerLinks {
  ComposerLinks._();

  /// Schemes [QuillHtmlConverter] keeps on an anchor. Anything else is
  /// silently dropped downstream, so the dialog refuses it up front.
  static const Set<String> allowedSchemes = <String>{
    'http',
    'https',
    'mailto',
    'tel',
  };

  static const String rejectionMessage =
      'Use an http, https, mailto or tel address. Other schemes are dropped '
      'from the email, so the link would arrive as plain text.';

  /// Control and whitespace characters browsers strip before resolving a URL.
  /// Removed before the scheme check for the same reason the converter removes
  /// them: `java&#9;script:` reaches the parser as `javascript:`.
  static final RegExp _stripped = RegExp(r'[\x00-\x20\x7F]');

  /// The typed link as the HTML converter will read it, or null when the
  /// converter would drop it. A bare `moyoungdemocrats.org` has no scheme, so
  /// it is promoted to https rather than silently disappearing from the mail.
  static String? normalize(String raw) {
    final cleaned = raw.replaceAll(_stripped, '');
    if (cleaned.isEmpty) return null;

    final parsed = Uri.tryParse(cleaned);
    if (parsed == null) return null;

    if (parsed.scheme.isEmpty) {
      if (!cleaned.contains('.')) return null;
      final promoted = Uri.tryParse('https://$cleaned');
      if (promoted == null || promoted.host.isEmpty) return null;
      return 'https://$cleaned';
    }

    return allowedSchemes.contains(parsed.scheme.toLowerCase()) ? cleaned : null;
  }
}

// ───────────────────────────────────────────────────────────────
//  SKIP REPORTING
//
//  The members pane and the audience panel both need to say why somebody is
//  about to be left out. This is that copy, in one place, so the two cannot
//  give a member a different reason.
//
//  ONE COPY IS STILL OUTSIDE: volunteers_detail_panel.dart carries a private
//  _textSkipReason with the same four branches. Folding it on needs this class
//  moved into mobilize_models.dart, which both files already import, because
//  the panel should not take a dependency on a 2,000 line composer widget for
//  one static helper. That move is reported rather than made here, since it
//  crosses three files and this phase ships without an analyze pass.
// ───────────────────────────────────────────────────────────────

class ComposerSkip {
  ComposerSkip._();

  static bool eligible(Member m, BulkSendChannel channel) =>
      channel == BulkSendChannel.sms
          ? m.canContact
          : (m.preferredEmail ?? '').isNotEmpty;

  /// Why this member cannot be reached on this channel, in the member's own
  /// terms rather than the schema's.
  static String reason(Member m, BulkSendChannel channel) {
    if (channel == BulkSendChannel.email) return 'no email on file';
    if (m.optOut) return 'opted out';
    if ((m.phoneE164 ?? '').isEmpty) return 'no phone';
    if (m.membershipEligible != true) return 'not eligible';
    return 'cannot be texted';
  }

  /// The distinct reasons across [people], most common first, joined for a
  /// one-line report: "opted out, no phone".
  static String reasonSummary(
      Iterable<Member> people, BulkSendChannel channel) {
    final tally = <String, int>{};
    for (final m in people) {
      final r = reason(m, channel);
      tally[r] = (tally[r] ?? 0) + 1;
    }
    final ordered = tally.keys.toList()
      ..sort((a, b) => tally[b]!.compareTo(tally[a]!));
    return ordered.join(', ');
  }
}

/// The one-line "N can't be texted" report with its Details affordance.
class ComposerSkipLine extends StatelessWidget {
  const ComposerSkipLine({
    super.key,
    required this.text,
    this.onDetails,
  });

  final String text;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final vt = VolunteersTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: vt.secondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: TextStyle(color: vt.secondary, fontSize: 11.5)),
          ),
          if (onDetails != null) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: onDetails,
              child: Text('Details',
                  style: TextStyle(
                      color: vt.highlight,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
//  VALUE TYPES
// ───────────────────────────────────────────────────────────────

/// The acting exec's two id spaces, carried together and never merged.
/// [memberId] is a members.id and [userId] is an auth.users.id; both FKs would
/// reject a swap, but only at insert time and only with an opaque 23503, so
/// they stay named apart everywhere they travel (spec 4.1).
typedef MobilizeActor = ({String memberId, String userId});

/// What the exec has written, as the row stores it.
@immutable
class ComposerContent {
  const ComposerContent({
    required this.channel,
    this.subject,
    this.bodyText,
    this.bodyHtml,
  });

  final BulkSendChannel channel;

  /// Email only. Null on a text.
  final String? subject;

  /// The sms body, or the email plain-text part.
  final String? bodyText;

  /// Email only.
  final String? bodyHtml;

  bool get hasBody => (bodyText ?? '').trim().isNotEmpty;
  bool get hasSubject => (subject ?? '').trim().isNotEmpty;
  bool get isEmpty => !hasBody && !hasSubject;
}

/// Why a stored touchpoint is being loaded back into the composer.
enum ComposerResumeMode {
  /// Continue writing the same row. The composer takes ownership of its id, so
  /// the next save updates it rather than minting a second draft.
  continueDraft,

  /// Retry the failures of a resolved send. The original is never mutated: the
  /// composer starts with NO id, and the Desk carries `retry_of` so the row
  /// this eventually writes points back at the one it retries (spec 3.6).
  retry,
}

/// A stored touchpoint being loaded back into the composer, plus what the Desk
/// found when it re-fetched the recipients.
@immutable
class ComposerResume {
  const ComposerResume({
    required this.touchpoint,
    required this.mode,
    this.droppedCount = 0,
  });

  final OutreachTouchpoint touchpoint;
  final ComposerResumeMode mode;

  /// Recipient ids on the stored row that no longer resolve to a member at
  /// all. They are dropped and the count adjusts; a composer never renders an
  /// "Unknown member" row (spec 4.3).
  final int droppedCount;
}

// ───────────────────────────────────────────────────────────────
//  THE DURABLE DRAFT
// ───────────────────────────────────────────────────────────────

/// Everything about a draft that has to outlive any one MOUNT of
/// [MobilizeComposer].
///
/// The composer is a section body inside the Desk's scrolling section list, so
/// the framework destroys and rebuilds its element for reasons that have
/// nothing to do with the exec abandoning the message: collapsing the SEND
/// section, the audience going empty and swapping the sections for the empty
/// state, the section scrolling out of the viewport, or the window crossing a
/// layout breakpoint into a different column tree. While the words, the
/// attachments and the row id lived in the State, every one of those events
/// threw the draft away in silence, and the next keystroke minted a SECOND
/// draft row for the same message and orphaned the first.
///
/// The Desk owns exactly one of these for its whole life and hands it in. The
/// composer's State keeps only what is genuinely per-mount: focus nodes, the
/// body scroll position and the timers it cancels on the way out. Nothing the
/// exec typed and no row id lives anywhere that unmounting can reach, so the
/// loss is impossible rather than rare.
class MobilizeDraftState {
  /// The words. Owned here so a collapse cannot dispose them.
  final TextEditingController subject = TextEditingController();
  final TextEditingController text = TextEditingController();
  final quill.QuillController body = quill.QuillController.basic();

  final List<ComposerAttachment> attachments = <ComposerAttachment>[];

  /// The row the draft owns. Null until the first save, and null again the
  /// moment a send resolves or a draft is discarded, so the next send mints
  /// its own row rather than losing the compare-and-set to a spent one.
  String? touchpointId;

  bool saving = false;
  bool saveFailed = false;
  DateTime? savedAt;

  bool sending = false;
  int sent = 0;
  int sendTotal = 0;

  /// The result card that replaces the composer in place after a send.
  BulkSendResult? result;
  String? resultTouchpointId;

  /// Whether the send on the result card has already been logged as an
  /// activity. Promotion is idempotent in the database, so this only stops the
  /// card offering an action that would tell the exec nothing new.
  bool resultPromoted = false;

  /// A promotion in flight, so a double tap cannot fire two RPCs.
  bool promoting = false;

  /// The resume whose stale-recipient report still describes the audience on
  /// screen, held as the RESUME rather than as a rendered sentence so the
  /// report can be derived at build time. [staleAudienceSignature] is the
  /// audience it was taken against: the report survives the audience change
  /// the resume itself causes and dies the moment the exec moves off it.
  ComposerResume? staleResume;
  String staleAudienceSignature = '';

  /// The resume already applied, so a rebuild cannot apply it twice.
  ComposerResume? appliedResume;

  /// The Email-to-Text warning is shown once per draft, not once per flip.
  bool channelWarned = false;

  /// WHO and WHICH NOMINEES the row was last written against. Durable because
  /// both can move while the composer is unmounted, and the next mount has to
  /// notice and flush rather than let the record lag behind the audience.
  String audienceSignature = '';
  String nomineeSignature = '';

  /// Serialises saves. Two concurrent flushes that both find no row yet both
  /// call startDraft, which is a second row for the same message.
  Future<void> flushChain = Future<void>.value();

  void dispose() {
    subject.dispose();
    text.dispose();
    body.dispose();
  }
}

// ───────────────────────────────────────────────────────────────
//  THE COMPOSER
// ───────────────────────────────────────────────────────────────

class MobilizeComposer extends StatefulWidget {
  const MobilizeComposer({
    super.key,
    required this.draft,
    required this.audience,
    required this.nomineeIds,
    required this.channel,
    required this.onChannelChanged,
    required this.actor,
    required this.active,
    required this.isRetry,
    required this.resume,
    required this.onResumeConsumed,
    required this.draftBuilder,
    required this.onRowResolved,
    required this.onRetryFailures,
    required this.onLogAsActivity,
    this.onShowSkipDetails,
  });

  /// The draft itself: the words, the attachments and the row id. Owned by the
  /// Desk and passed in, so destroying this element cannot destroy the
  /// message. See [MobilizeDraftState].
  final MobilizeDraftState draft;

  /// Everyone the Desk has selected, eligible or not. The composer filters to
  /// the channel itself so the skip report and the recipient list cannot
  /// disagree.
  final List<Member> audience;

  /// Only for change detection: attaching or detaching a nominee is an
  /// immediate flush point (spec 3.4). The ids that actually get written come
  /// from [draftBuilder], which is the Desk's.
  final List<String> nomineeIds;

  final BulkSendChannel channel;
  final ValueChanged<BulkSendChannel> onChannelChanged;

  /// Null while the session is still resolving. Send stays disabled until it
  /// is non-null, so a row can never be written against half an author.
  final MobilizeActor? actor;

  /// Whether the Desk is the workspace's visible tab. Going false flushes the
  /// draft, because a tab flip is exactly when an exec walks away from it.
  final bool active;

  /// Whether the Desk is currently carrying retry lineage. Purely a caption.
  final bool isRetry;

  /// A stored row to load. Consumed once, then [onResumeConsumed] fires so the
  /// Desk can clear it and a later rebuild does not re-apply it.
  final ComposerResume? resume;
  final VoidCallback onResumeConsumed;

  /// Turns the composer's content, its recipient list and the acting exec into
  /// the row the Desk stamps with geo, nominees and retry lineage. This is the
  /// only place the two halves meet. The actor is a parameter rather than
  /// something the closure reaches for, so a row can never be built from a
  /// session that resolved to null between the guard and the write.
  final TouchpointDraft Function(
    ComposerContent content,
    List<Member> recipients,
    MobilizeActor actor,
  ) draftBuilder;

  /// The composer is done with its row: it sent, or it discarded. The Desk
  /// reloads the rail and clears the retry lineage.
  final VoidCallback onRowResolved;

  /// Load the failures of the send just made as a fresh audience. The Desk
  /// resolves the members and stamps `retry_of`; the composer keeps the words.
  final Future<void> Function(String touchpointId, List<String> failedMemberIds)
      onRetryFailures;

  /// "Log this as an activity" on the result card. The Desk owns promotion,
  /// because the rail's send card offers the same action and one of the two
  /// would otherwise be a second definition of what promoting means. Returns
  /// true when the activity was written.
  final Future<bool> Function(String touchpointId) onLogAsActivity;

  /// The audience panel's skip dialog, so the composer's skip line opens the
  /// same list rather than a second one.
  final VoidCallback? onShowSkipDetails;

  @override
  State<MobilizeComposer> createState() => _MobilizeComposerState();
}

class _MobilizeComposerState extends State<MobilizeComposer>
    with WidgetsBindingObserver {
  final TouchpointRepository _touchpoints = TouchpointRepository();
  final CRMMessageService _messages = CRMMessageService();
  final CRMEmailService _email = CRMEmailService();
  final MemberRepository _memberRepo = MemberRepository();

  // ── Per-mount only ────────────────────────────────────────────
  // Focus, scroll and timers are the only state that may die with this
  // element. Everything the exec would mourn lives on [widget.draft].

  final FocusNode _subjectFocus = FocusNode();
  final FocusNode _textFocus = FocusNode();
  final FocusNode _bodyFocus = FocusNode();
  final ScrollController _bodyScroll = ScrollController();

  Timer? _debounce;

  /// The "3 seconds after the first keystroke" creation trigger (spec 3.4).
  /// Distinct from [_debounce] because it fires once, from an empty row, and
  /// covers the case where only a subject has been typed.
  Timer? _firstKeystroke;

  /// True while a resume is writing the controllers. Their listeners fire on
  /// a programmatic set exactly as they do on a keystroke, and a resumed draft
  /// is not an edit: without this the rehydration itself would arm the
  /// creation timers and mint a row before the exec has touched anything.
  bool _rehydrating = false;

  /// Set before dispose runs its last flush. That flush is fire and forget and
  /// its first act is a caption setState, which the framework refuses on a
  /// state that is on its way out; the timers and focus listeners can also
  /// fire once more while dispose is tearing them down.
  bool _disposed = false;

  // ── The draft ─────────────────────────────────────────────────
  // Views onto the Desk-owned [MobilizeDraftState], not copies of it. Reading
  // and writing through here is what makes an unmount survivable: there is no
  // second copy that could be the newer one.

  MobilizeDraftState get _draft => widget.draft;

  TextEditingController get _subject => _draft.subject;
  TextEditingController get _text => _draft.text;
  quill.QuillController get _body => _draft.body;
  List<ComposerAttachment> get _attachments => _draft.attachments;

  String? get _touchpointId => _draft.touchpointId;
  set _touchpointId(String? value) => _draft.touchpointId = value;

  bool get _saving => _draft.saving;
  set _saving(bool value) => _draft.saving = value;

  bool get _saveFailed => _draft.saveFailed;
  set _saveFailed(bool value) => _draft.saveFailed = value;

  DateTime? get _savedAt => _draft.savedAt;
  set _savedAt(DateTime? value) => _draft.savedAt = value;

  bool get _sending => _draft.sending;
  set _sending(bool value) => _draft.sending = value;

  int get _sent => _draft.sent;
  set _sent(int value) => _draft.sent = value;

  int get _sendTotal => _draft.sendTotal;
  set _sendTotal(int value) => _draft.sendTotal = value;

  BulkSendResult? get _result => _draft.result;
  set _result(BulkSendResult? value) => _draft.result = value;

  String? get _resultTouchpointId => _draft.resultTouchpointId;
  set _resultTouchpointId(String? value) => _draft.resultTouchpointId = value;

  bool get _resultPromoted => _draft.resultPromoted;
  set _resultPromoted(bool value) => _draft.resultPromoted = value;

  bool get _promoting => _draft.promoting;
  set _promoting(bool value) => _draft.promoting = value;

  ComposerResume? get _staleResume => _draft.staleResume;
  set _staleResume(ComposerResume? value) => _draft.staleResume = value;

  String get _staleAudienceSignature => _draft.staleAudienceSignature;
  set _staleAudienceSignature(String value) =>
      _draft.staleAudienceSignature = value;

  ComposerResume? get _appliedResume => _draft.appliedResume;
  set _appliedResume(ComposerResume? value) => _draft.appliedResume = value;

  bool get _channelWarned => _draft.channelWarned;
  set _channelWarned(bool value) => _draft.channelWarned = value;

  String get _audienceSignature => _draft.audienceSignature;
  set _audienceSignature(String value) => _draft.audienceSignature = value;

  String get _nomineeSignature => _draft.nomineeSignature;
  set _nomineeSignature(String value) => _draft.nomineeSignature = value;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Attach to the Desk-owned controllers. This mount may be the first or the
    // fifth; either way the controllers already hold whatever has been typed.
    _subject.addListener(_onEdited);
    _text.addListener(_onEdited);
    _body.addListener(_onEdited);
    _subjectFocus.addListener(_onFocusChanged);
    _textFocus.addListener(_onFocusChanged);
    _bodyFocus.addListener(_onFocusChanged);
    // Deferred a frame because both of these can flush, and a flush paints its
    // caption: setState is illegal while initState is still inside build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_alive) return;
      _reconcileSignatures();
      _consumeResume();
    });
  }

  /// Catch up on WHO and WHICH NOMINEES while this composer was not mounted.
  ///
  /// A collapsed SEND section is still a live draft, and the Desk can change
  /// the audience or the nominees while it is collapsed. The row must not lag
  /// behind either (spec 3.4), so a mount compares the current signatures with
  /// the ones the draft was last written against and flushes on a difference,
  /// exactly as [didUpdateWidget] would have done had the composer been on
  /// screen for the change.
  void _reconcileSignatures() {
    final audience = _signatureOf(widget.audience);
    final nominees = widget.nomineeIds.join(',');
    final moved =
        audience != _audienceSignature || nominees != _nomineeSignature;
    if (audience != _audienceSignature) {
      _audienceSignature = audience;
      if (audience != _staleAudienceSignature) _staleResume = null;
    }
    _nomineeSignature = nominees;
    if (moved) unawaited(_flush());
  }

  @override
  void didUpdateWidget(covariant MobilizeComposer old) {
    super.didUpdateWidget(old);

    if (widget.resume != null && !identical(widget.resume, _appliedResume)) {
      _consumeResume();
    }

    // The three immediate flush points the Desk drives (spec 3.4). Each is a
    // change to WHO or HOW, which the record must not lag behind.
    if (old.channel != widget.channel) {
      _syncBodyAcrossChannels(from: old.channel, to: widget.channel);
      unawaited(_flush());
    }

    final audience = _signatureOf(widget.audience);
    if (audience != _audienceSignature) {
      _audienceSignature = audience;
      // The stale-recipient report describes the audience the RESUME brought
      // in, and a resume always arrives with a changed audience signature.
      // Clearing the report unconditionally here is what silently defeated the
      // gate on the warm path: _consumeResume set it fourteen lines above and
      // this line wiped it in the same call, so continuing a draft while the
      // Desk already held an audience reported neither opted-out nor dropped
      // recipients. It is cleared only once the exec moves the audience OFF
      // the resumed set, which is the point at which the report stops
      // describing what is on screen.
      if (audience != _staleAudienceSignature) _staleResume = null;
      unawaited(_flush());
    }

    final nominees = widget.nomineeIds.join(',');
    if (nominees != _nomineeSignature) {
      _nomineeSignature = nominees;
      unawaited(_flush());
    }

    // A tab flip is the exec walking away from the words.
    if (old.active && !widget.active) unawaited(_flush());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On the web `hidden` is the pagehide the browser fires as the tab goes
    // away, which is the last moment a draft can be saved. Fire and forget:
    // there is no frame left to await in.
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_flush());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    // Last flush before this MOUNT goes. Nothing awaits it and nothing can,
    // but the request is already on the wire by the time the element is gone,
    // and it writes through to the Desk-owned draft rather than to fields that
    // are about to disappear.
    unawaited(_flush());
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _firstKeystroke?.cancel();
    // Detach from the shared controllers; never dispose them. They belong to
    // [MobilizeDraftState] and are still holding the words. Disposing them
    // here is precisely what made collapsing the SEND section destroy the
    // message.
    _subject.removeListener(_onEdited);
    _text.removeListener(_onEdited);
    _body.removeListener(_onEdited);
    _subjectFocus.dispose();
    _textFocus.dispose();
    _bodyFocus.dispose();
    _bodyScroll.dispose();
    super.dispose();
  }

  // ── Content ───────────────────────────────────────────────────
  /// Safe to paint into: mounted AND not tearing down. dispose fires a last
  /// flush whose continuations land after the element is gone.
  bool get _alive => mounted && !_disposed;

  bool get _isText => widget.channel == BulkSendChannel.sms;

  List<Member> get _eligible => widget.audience
      .where((m) => ComposerSkip.eligible(m, widget.channel))
      .toList();

  List<Member> get _skipped => widget.audience
      .where((m) => !ComposerSkip.eligible(m, widget.channel))
      .toList();

  /// The Quill document as the three shapes the row and the relay both want.
  ({String plain, String html}) _richBody() {
    final document = _body.document;
    final deltaJson = document
        .toDelta()
        .toJson()
        .map<Map<String, dynamic>>((op) => Map<String, dynamic>.from(op as Map))
        .toList(growable: false);
    // Quill's own toPlainText() keeps the anchor TEXT and throws away the href,
    // so a plain-text reader sees "click here" pointing at nothing. The
    // converter renders links as "text (url)" for the text/plain part; the raw
    // form still drives the empty check, where appended URLs are only noise.
    final raw = document.toPlainText().trim();
    return (
      plain: QuillHtmlConverter.generatePlainText(deltaJson).trim(),
      html: QuillHtmlConverter.generateHtml(deltaJson, raw),
    );
  }

  ComposerContent _content() {
    if (_isText) {
      final body = _text.text.trim();
      return ComposerContent(
        channel: BulkSendChannel.sms,
        bodyText: body.isEmpty ? null : body,
      );
    }
    final rich = _richBody();
    final subject = _subject.text.trim();
    return ComposerContent(
      channel: BulkSendChannel.email,
      subject: subject.isEmpty ? null : subject,
      bodyText: rich.plain.isEmpty ? null : rich.plain,
      bodyHtml: rich.plain.isEmpty ? null : rich.html,
    );
  }

  /// Tokens the draft carries that no recipient variable can fill, surfaced
  /// continuously rather than only on the send attempt so the exec sees the
  /// problem while writing. Takes the content the caller already computed:
  /// each call converts the whole delta twice, so build computes it once.
  List<String> _unsupportedTokensIn(ComposerContent content) {
    if (content.channel == BulkSendChannel.sms) return const <String>[];
    return ComposerMergeFields.unsupportedTokens(
      subject: content.subject,
      plainText: content.bodyText,
      html: content.bodyHtml,
    );
  }

  /// Switching channel keeps the body (spec 6.2). A text message carries no
  /// formatting, so the crossing is plain text in both directions and the
  /// warning below says so before it happens.
  void _syncBodyAcrossChannels({
    required BulkSendChannel from,
    required BulkSendChannel to,
  }) {
    if (to == BulkSendChannel.sms) {
      final plain = _richBody().plain;
      if (plain.isNotEmpty && plain != _text.text) _text.text = plain;
      return;
    }
    final plain = _text.text.trim();
    if (plain.isEmpty) return;
    if (_richBody().plain == plain) return;
    _body.document = MarkdownQuillLoader.fromHtml(
      '<p>${plain.split('\n').join('</p><p>')}</p>',
    );
  }

  /// The channel pill's own handler, so the one-time warning fires before the
  /// Desk's state moves rather than after.
  Future<void> _requestChannel(BulkSendChannel next) async {
    if (next == widget.channel || _sending) return;

    final losingSubject =
        next == BulkSendChannel.sms && _subject.text.trim().isNotEmpty;
    if (losingSubject && !_channelWarned) {
      _channelWarned = true;
      final go = await _confirmDialog(
        title: 'Switch to a text?',
        lines: const <String>[
          'Text messages have no subject line. Your subject will not be sent.',
          'Any formatting in the body is sent as plain text.',
        ],
        confirmLabel: 'Switch to text',
      );
      if (go != true || !mounted) return;
    }
    widget.onChannelChanged(next);
  }

  // ── Draft persistence (spec 3.4, 4.3) ─────────────────────────
  void _onEdited() {
    if (_disposed || _rehydrating) return;
    if (_sending) return;
    if (_result != null) return;

    // Trigger (b): 3 seconds after the FIRST keystroke, so a subject typed
    // with no body still becomes a resumable draft.
    _firstKeystroke ??= Timer(const Duration(seconds: 3), () {
      _firstKeystroke = null;
      unawaited(_flush(create: true));
    });

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), () {
      unawaited(_flush());
    });

    // The caption, the send guard and the unsupported-token strip all move
    // with the words.
    setState(() {});
  }

  void _onFocusChanged() {
    if (_disposed) return;
    final anyFocus =
        _subjectFocus.hasFocus || _textFocus.hasFocus || _bodyFocus.hasFocus;
    if (!anyFocus) unawaited(_flush());
  }

  /// Write the composer state, creating the row if this is the first save.
  ///
  /// [create] forces the row into existence for trigger (b). Without it the
  /// row is only created once the Desk has an audience AND the body carries a
  /// non-whitespace character, which is what stops an idle visit littering the
  /// table with empty drafts.
  ///
  /// [content] and [recipients] override what the composer would read for
  /// itself at the moment the write actually runs. The send path passes the
  /// exact pair it is about to hand the relay, so the row cannot record one
  /// message and deliver another because the Desk rebuilt with a different
  /// audience while the confirm dialog was up.
  ///
  /// Returns the row id ONLY when this call persisted the state above. Null
  /// means that state is NOT in the table: either nothing was due to be
  /// written, or the write failed. It never returns an id whose row still
  /// holds older content, which is what let a failed debounced save be
  /// followed by a send that recorded the last successfully saved body and
  /// recipient list instead of the ones that went out.
  Future<String?> _flush({
    bool create = false,
    ComposerContent? content,
    List<Member>? recipients,
  }) {
    // Cancelled synchronously, before the queueing below, so a debounce armed
    // by the keystroke that triggered this call cannot fire a second write of
    // state this one already covers.
    _debounce?.cancel();
    _debounce = null;

    // One write at a time, for the whole life of the draft rather than the
    // life of this element. Two concurrent flushes that both find no row yet
    // would both call startDraft and mint two rows for one message; the send
    // path's flush racing the debounce or the focus-out flush is exactly that
    // case.
    //
    // The chain itself never carries an error, because the link below cannot
    // complete with one. A broken link would otherwise skip every write queued
    // behind it, including the send's, and leave its caller waiting forever.
    final done = Completer<String?>();
    _draft.flushChain = _draft.flushChain.then<void>((_) async {
      String? id;
      try {
        id = await _write(
          create: create,
          content: content,
          recipients: recipients,
        );
      } catch (_) {
        // Nothing reached the table, so nothing may claim to have.
        id = null;
      }
      done.complete(id);
    });
    return done.future;
  }

  /// The body of one [_flush]. Never called directly: the chain in [_flush] is
  /// what guarantees these do not overlap.
  Future<String?> _write({
    required bool create,
    ComposerContent? content,
    List<Member>? recipients,
  }) async {
    final actor = widget.actor;
    if (actor == null) return null;

    final body = content ?? _content();
    final existing = _touchpointId;

    if (existing == null) {
      if (body.isEmpty) return null;
      final ready = widget.audience.isNotEmpty && body.hasBody;
      if (!ready && !create) return null;
    }

    // What the record says would actually go out, which is the eligible set for
    // the chosen channel rather than the whole audience (spec 4.3).
    final draft = widget.draftBuilder(body, recipients ?? _eligible, actor);

    // Assigned first and painted second, in every branch below. The flags live
    // on the draft, so they stay true even when this element is already gone
    // and there is nobody left to call setState on.
    _saving = true;
    _saveFailed = false;
    if (_alive) setState(() {});

    try {
      if (existing == null) {
        final id = await _touchpoints.startDraft(draft);
        _touchpointId = id;
        _saving = false;
        _saveFailed = id == null;
        if (id != null) _savedAt = DateTime.now();
        if (_alive) setState(() {});
        return id;
      }

      await _touchpoints.saveDraft(existing, draft);
      _saving = false;
      _savedAt = DateTime.now();
      if (_alive) setState(() {});
      return existing;
    } catch (_) {
      // The row still exists and still belongs to this draft, so the id is
      // kept for the next attempt. What is NOT returned is that id, because
      // this content never reached the table. The caption is where a failed
      // save shows while typing; the send path refuses outright.
      _saving = false;
      _saveFailed = true;
      if (_alive) setState(() {});
      return null;
    }
  }

  /// Throw the draft away. It is marked discarded rather than deleted, because
  /// the trail should still show that an exec started this and chose not to
  /// send it.
  Future<void> _discard() async {
    final id = _touchpointId;
    final go = await _confirmDialog(
      title: 'Discard this draft?',
      lines: const <String>[
        'The words are cleared and the draft leaves your desk.',
        'The audience stays selected.',
      ],
      confirmLabel: 'Discard',
    );
    if (go != true) return;

    _debounce?.cancel();
    _firstKeystroke?.cancel();
    _firstKeystroke = null;
    _touchpointId = null;

    if (mounted) {
      _rehydrating = true;
      setState(() {
        _subject.clear();
        _text.clear();
        _body.document = quill.Document();
        _attachments.clear();
        _savedAt = null;
        _saveFailed = false;
        _staleResume = null;
        _result = null;
      });
      _rehydrating = false;
    }

    if (id != null) {
      try {
        await _touchpoints.discardDraft(id);
      } catch (_) {
        // A discarded row shows nowhere on the desk either way.
      }
    }
    widget.onRowResolved();
  }

  // ── Resumption (spec 4.3) ─────────────────────────────────────
  void _consumeResume() {
    final resume = widget.resume;
    if (resume == null) return;
    // Applied once per resume, for the life of the DRAFT rather than the life
    // of this element. onResumeConsumed is deferred a frame, so an unmount in
    // between leaves the Desk still holding the resume; without this guard a
    // remount would re-apply it over words the exec has since typed.
    if (identical(resume, _appliedResume)) return;
    _appliedResume = resume;
    _rehydrating = true;

    final t = resume.touchpoint;
    _debounce?.cancel();
    _firstKeystroke?.cancel();
    _firstKeystroke = null;

    setState(() {
      _result = null;
      _resultTouchpointId = null;
      _resultPromoted = false;
      _saveFailed = false;
      _savedAt = t.lastEditedAt;
      // A retry writes a NEW row (3.6), so it starts with no id and the Desk
      // carries the lineage. Continuing takes ownership of the stored one.
      _touchpointId =
          resume.mode == ComposerResumeMode.continueDraft ? t.id : null;

      _subject.text = t.subject ?? '';
      final plain = t.bodyText ?? '';
      _text.text = plain;
      final html = t.bodyHtml;
      _body.document = (html != null && html.trim().isNotEmpty)
          ? MarkdownQuillLoader.fromHtml(html)
          : (plain.isEmpty
              ? quill.Document()
              : MarkdownQuillLoader.fromHtml(
                  '<p>${plain.split('\n').join('</p><p>')}</p>'));

      // Attachments never survive a draft: PlatformFile bytes live only in the
      // browser tab that picked them.
      _attachments.clear();
      // Held as the RESUME, not as a rendered sentence. The report is derived
      // at build time from the audience and channel on screen, so nothing
      // later in this same didUpdateWidget can wipe it, and a channel flip
      // cannot leave "can no longer be emailed" standing on a text send.
      _staleResume = resume;
      _staleAudienceSignature = _signatureOf(widget.audience);
    });

    _rehydrating = false;
    // Deferred a frame on purpose. This runs from didUpdateWidget, which is
    // inside the DESK's build, and the callback clears state on the Desk: a
    // synchronous call there is a setState during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_alive) widget.onResumeConsumed();
    });
  }

  /// What continuing a draft found: recipients that no longer resolve, and
  /// recipients who can no longer be reached on this channel (spec 4.3).
  ///
  /// Derived, never stored. It used to be a string computed once inside
  /// [_consumeResume], which the audience-change branch of [didUpdateWidget]
  /// then cleared in the same call. There is no stored sentence left to wipe:
  /// the report exists exactly while [_staleResume] is set, and that is
  /// cleared only when the audience moves off the set the resume brought in.
  String? get _staleReport {
    final resume = _staleResume;
    return resume == null ? null : _staleReportFor(resume);
  }

  /// Who the stored row named that cannot be reached now, said plainly rather
  /// than quietly dropped. This is the whole point of re-fetching on resume: a
  /// member who opted out since the draft was written must be reported, not
  /// silently mailed.
  String? _staleReportFor(ComposerResume resume) {
    final stored = resume.touchpoint.recipientMemberIds.length;
    if (stored == 0) return null;

    final unreachable = _skipped;
    final parts = <String>[];

    if (unreachable.isNotEmpty) {
      final verb = widget.channel == BulkSendChannel.sms
          ? 'can no longer be texted'
          : 'can no longer be emailed';
      parts.add('${unreachable.length} of $stored $verb: '
          '${ComposerSkip.reasonSummary(unreachable, widget.channel)}.');
    }
    if (resume.droppedCount > 0) {
      parts.add(resume.droppedCount == 1
          ? '1 is no longer on file and was dropped.'
          : '${resume.droppedCount} are no longer on file and were dropped.');
    }
    if (parts.isEmpty) return null;
    parts.add('The draft records who would actually receive it.');
    return parts.join(' ');
  }

  // ── Send ──────────────────────────────────────────────────────
  List<String> _blockersFor(ComposerContent content) {
    final blockers = <String>[];
    if (widget.actor == null) {
      blockers.add('Your exec profile is still loading.');
    }
    if (_eligible.isEmpty) {
      blockers.add(_isText
          ? 'Nobody on this audience can be texted.'
          : 'Nobody on this audience has an email on file.');
    }
    if (!content.hasBody) blockers.add('The message body is empty.');
    if (!_isText && !content.hasSubject) {
      blockers.add('The subject line is empty.');
    }
    return blockers;
  }

  Future<void> _send() async {
    if (_sending) return;
    final actor = widget.actor;
    if (actor == null) return;

    final recipients = _eligible;
    final content = _content();
    if (_blockersFor(content).isNotEmpty) return;

    // Refuse while any token remains that no recipient variable can fill.
    // Checked before the confirm so the exec gets the offending names and
    // keeps a usable composer, exactly as the bulk email screen does.
    final unresolved = _unsupportedTokensIn(content);
    if (unresolved.isNotEmpty) {
      final names = unresolved.join(', ');
      final many = unresolved.length > 1;
      _snack('Cannot send: $names '
          '${many ? 'are not supported merge fields' : 'is not a supported merge field'}. '
          '${many ? 'They' : 'It'} would reach members as written. '
          'Remove ${many ? 'them' : 'it'} or pick from the merge field list.');
      return;
    }

    final go = await _confirmSend(recipients, content);
    if (go != true || !mounted) return;

    _sending = true;
    _sent = 0;
    _sendTotal = recipients.length;
    setState(() {});

    try {
      // The row is written and claimed BEFORE anything goes out, because its
      // id is the idempotency key: a second attempt loses the compare-and-set
      // instead of minting a second record (spec 3.5).
      //
      // The flush is handed the SAME content and recipient list that
      // _performSend is about to use, and _flush returns an id only when that
      // exact state reached the table. Both halves matter. Without the first,
      // a rebuild between the confirm and the write could persist a different
      // audience from the one being messaged; without the second, a failed
      // save would leave the last successfully saved body and recipients
      // standing in the row while a different message went out, and
      // retryFailures would then retry against the wrong set.
      final id = await _flush(
        create: true,
        content: content,
        recipients: recipients,
      );
      if (id == null || _saveFailed) {
        // Refused, not degraded. The table is the record of what an exec
        // actually sent, so a message that cannot be recorded is not sent.
        _snack('The draft could not be saved, so nothing was sent. '
            'The record has to match what goes out. '
            'Check your connection and send again.');
        return;
      }

      // claimForSend rethrows, and an escaping exception would tell the exec
      // nothing at all while the finally below quietly cleared "Sending".
      final TouchpointClaim claim;
      try {
        claim = await _touchpoints.claimForSend(id, recipients.length);
      } catch (_) {
        _snack('The send could not be claimed, so nothing was sent. '
            'Check your connection and send again.');
        return;
      }
      if (claim != TouchpointClaim.claimed) {
        _touchpointId = null;
        widget.onRowResolved();
        _snack(claim == TouchpointClaim.alreadyClaimed
            ? 'This send was already started somewhere else. '
                'Check MY DESK for what it did.'
            : 'The CRM is not available, so nothing was sent.');
        return;
      }

      final result = await _performSend(recipients, content);

      try {
        await _touchpoints.finishSend(
            id, TouchpointSendOutcome.fromBulkResult(result));
      } catch (_) {
        // A record that failed to write must never read as a send that failed.
        // The messages went out; the rail reloads and shows what the table has.
      }

      // Recorded on the draft first and painted second. The row is spent
      // whether or not this element survived the send, and a _touchpointId
      // still pointing at it would make the next send claim a row that is no
      // longer a draft.
      _result = result;
      _resultTouchpointId = id;
      _resultPromoted = false;
      _touchpointId = null;
      if (_alive) setState(() {});
      widget.onRowResolved();
      // The map is a sibling in the IndexedStack and stays mounted, so nothing
      // otherwise tells it a send happened and its last_contacted filters and
      // sort go stale until the exec reselects the region. This replaces the
      // reload the deleted _refreshMembersAfterContact did back when the map
      // itself pushed the bulk screens.
      DeskChanges.notifyWritten();
    } finally {
      _sending = false;
      if (_alive) setState(() {});
    }
  }

  Future<BulkSendResult> _performSend(
    List<Member> recipients,
    ComposerContent content,
  ) async {
    if (content.channel == BulkSendChannel.sms) {
      final results = await _messages.sendBulkMessages(
        // No filter: the audience is already resolved, and a filter here would
        // silently widen the send beyond what the exec confirmed.
        filter: MessageFilter(),
        messageText: content.bodyText ?? '',
        explicitMembers: recipients,
        attachments:
            _attachments.map((a) => a.picked).toList(growable: false),
        onProgress: (current, total) {
          if (!mounted) return;
          setState(() {
            _sent = current;
            _sendTotal = total;
          });
        },
      );
      return BulkSendResult.sms(results);
    }

    final addressed = <String, Member>{};
    for (final m in recipients) {
      final email = (m.preferredEmail ?? '').trim();
      if (email.isEmpty) continue;
      addressed.putIfAbsent(email.toLowerCase(), () => m);
    }
    final memberIds = addressed.values.map((m) => m.id).toList(growable: false);

    // Three outcomes, not two. Anything that throws before the provider call
    // never reached an inbox; anything that throws after it did, and recording
    // that as a failure would be a lie.
    var accepted = false;
    try {
      final attachments = <CRMEmailAttachment>[];
      for (final file in _attachments) {
        final built = await _email.buildAttachmentFromPlatformFile(file.file);
        if (built != null) attachments.add(built);
      }

      await _email.sendEmail(
        to: addressed.keys.toList(growable: false),
        subject: content.subject ?? '',
        htmlBody: content.bodyHtml,
        textBody: content.bodyText,
        fromEmail: CRMConfig.defaultSenderEmail,
        recipients: addressed.entries
            .map((e) => CRMEmailRecipientPayload(
                  email: e.key,
                  variables: ComposerMergeFields.variablesFor(
                      email: e.key, member: e.value),
                ))
            .toList(growable: false),
        attachments: attachments,
      );
      accepted = true;

      for (final m in addressed.values) {
        try {
          await _memberRepo.updateLastContacted(m.id);
        } catch (_) {
          // Bookkeeping after the relay accepted the batch. It must never turn
          // a delivered send into a recorded failure.
        }
      }
      return BulkSendResult.email(memberIds);
    } catch (error) {
      if (accepted) return BulkSendResult.email(memberIds);
      final message =
          error is CRMEmailException ? error.message : 'Failed to send: $error';
      return BulkSendResult.emailFailed(memberIds, message);
    }
  }

  /// Last stop before a few hundred phones or inboxes. It restates the two
  /// things that go wrong most often: how many, and how fast they leave.
  Future<bool?> _confirmSend(
      List<Member> recipients, ComposerContent content) {
    final n = recipients.length;
    final people = n == 1 ? 'member' : 'members';

    if (content.channel == BulkSendChannel.sms) {
      return _confirmDialog(
        title: 'Send to $n $people?',
        lines: <String>[
          'Individual messages go out at '
              '${CRMMessageService.messagesPerMinute} per minute, about '
              '${_durationLabel(CRMConfig.messageDelay * (n > 1 ? n - 1 : 0))} '
              'from now.',
          if (_attachments.isNotEmpty)
            '${_attachments.length} '
                '${_attachments.length == 1 ? 'attachment' : 'attachments'} '
                'go with every message.',
        ],
        confirmLabel: 'Send',
      );
    }

    return _confirmDialog(
      title: 'Send to $n $people?',
      lines: <String>[
        'One email each, from ${CRMConfig.defaultSenderEmail}.',
        'Subject: ${content.subject}',
        if (_attachments.isNotEmpty)
          '${_attachments.length} '
              '${_attachments.length == 1 ? 'attachment' : 'attachments'}.',
      ],
      confirmLabel: 'Send',
    );
  }

  Future<void> _retryFailures() async {
    final result = _result;
    final id = _resultTouchpointId;
    if (result == null || id == null || result.failedMemberIds.isEmpty) return;
    setState(() {
      _result = null;
      _resultTouchpointId = null;
      _resultPromoted = false;
    });
    await widget.onRetryFailures(id, result.failedMemberIds);
  }

  /// "Log this as an activity" (spec 3.1). The Desk does the work: the rail's
  /// send card offers the same action, and two implementations of it would be
  /// two chances to promote it differently.
  Future<void> _logAsActivity() async {
    final id = _resultTouchpointId;
    if (id == null || _promoting || _resultPromoted) return;
    setState(() => _promoting = true);
    try {
      final done = await widget.onLogAsActivity(id);
      if (!_alive) return;
      setState(() => _resultPromoted = done);
    } finally {
      if (_alive) setState(() => _promoting = false);
    }
  }

  /// "Start another": clears the words, keeps the audience.
  void _startAnother() {
    _rehydrating = true;
    setState(() {
      _result = null;
      _resultTouchpointId = null;
      _resultPromoted = false;
      _subject.clear();
      _text.clear();
      _body.document = quill.Document();
      _attachments.clear();
      _savedAt = null;
      _saveFailed = false;
      _staleResume = null;
      _touchpointId = null;
    });
    _rehydrating = false;
  }

  // ── Attachments ───────────────────────────────────────────────
  Future<void> _pickAttachments() async {
    if (_sending) return;
    final picked = await file_picker.FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      withReadStream: !kIsWeb,
    );
    if (picked == null || picked.files.isEmpty) return;

    final added = <ComposerAttachment>[];
    final failed = <String>[];
    for (final file in picked.files) {
      final materialized =
          await materializePickedPlatformFile(file, source: picked);
      if (materialized == null) {
        failed.add(file.name);
        continue;
      }
      added.add(ComposerAttachment(picked: file, file: materialized));
    }
    if (!mounted) return;

    setState(() {
      for (final a in added) {
        final exists = _attachments.any(
            (x) => x.file.name.toLowerCase() == a.file.name.toLowerCase());
        if (!exists) _attachments.add(a);
      }
    });

    if (failed.isNotEmpty) {
      _snack(failed.length == 1
          ? 'Could not read "${failed.first}". Please try again.'
          : 'Could not read ${failed.length} files: ${failed.join(', ')}.');
    }
  }

  // ── Dialogs and small helpers ─────────────────────────────────
  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool?> _confirmDialog({
    required String title,
    required List<String> lines,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: BrandColors.unityBlue,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: BrandTextStyles.title,
        contentTextStyle: BrandTextStyles.bodySecondary,
        title: Text(title),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in lines) ...[
                Text(line, style: BrandTextStyles.bodySecondary),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.sunriseGold,
              foregroundColor: BrandColors.unityBlue,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  static String _signatureOf(List<Member> people) =>
      people.map((m) => m.id).join(',');

  static String _durationLabel(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (minutes < 60) {
      return seconds == 0 ? '${minutes}m' : '${minutes}m ${seconds}s';
    }
    final hours = d.inHours;
    final rest = minutes % 60;
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }

  static String _clock(DateTime when) {
    final local = when.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour < 12 ? 'am' : 'pm'}';
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final vt = VolunteersTheme.of(context);
    final result = _result;
    if (result != null) return _resultCard(vt, result);

    final skipped = _skipped;
    final stale = _staleReport;
    // Computed once and threaded down: every read converts the whole Quill
    // delta to html and plain text, and three call sites would do it three
    // times a frame.
    final content = _content();
    final unsupported = _unsupportedTokensIn(content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _channelPill(vt),
        const SizedBox(height: 14),
        if (stale != null) ...[
          _notice(vt, Icons.person_off_outlined, stale, vt.highlight),
          const SizedBox(height: 12),
        ],
        if (widget.isRetry) ...[
          _notice(
            vt,
            Icons.replay,
            'This is a retry. It is recorded as its own send, linked to the '
            'one it retries.',
            vt.secondary,
          ),
          const SizedBox(height: 12),
        ],
        if (!_isText) ...[
          _subjectField(vt),
          const SizedBox(height: 10),
        ],
        _bodyField(vt),
        if (!_isText) ...[
          const SizedBox(height: 12),
          _mergeChips(vt),
        ],
        if (unsupported.isNotEmpty) ...[
          const SizedBox(height: 12),
          _notice(
            vt,
            Icons.block,
            'Sending is blocked: ${unsupported.join(', ')} '
            '${unsupported.length > 1 ? 'are not merge fields this CRM can fill' : 'is not a merge field this CRM can fill'}. '
            'Members would read the token as written.',
            BrandColors.error,
          ),
        ],
        const SizedBox(height: 14),
        _attachmentsRow(vt),
        const SizedBox(height: 14),
        if (skipped.isNotEmpty)
          ComposerSkipLine(
            text: _isText
                ? "${skipped.length} of ${widget.audience.length} can't be "
                    'texted: ${ComposerSkip.reasonSummary(skipped, widget.channel)}'
                : "${skipped.length} of ${widget.audience.length} can't be "
                    'emailed: no email on file',
            onDetails: widget.onShowSkipDetails,
          ),
        _footer(vt, content),
      ],
    );
  }

  // ── Channel ───────────────────────────────────────────────────
  /// Segmented channel control.
  ///
  /// The active segment is the emphasis pair (sunriseGold under unityBlue,
  /// 7.17:1) rather than [VolunteersTheme.accent]: white on accent measures
  /// 2.75:1, which fails the normal-text bar AND the 3:1 large-text bar, so
  /// accent never carries a label.
  Widget _channelPill(VolunteersTheme vt) {
    Widget segment(BulkSendChannel channel, IconData icon, String label) {
      final selected = widget.channel == channel;
      return Expanded(
        child: Material(
          color: selected ? vt.emphasisFill : Colors.transparent,
          child: InkWell(
            onTap: () => _requestChannel(channel),
            child: Container(
              height: 32,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 15,
                      color: selected ? vt.onEmphasis : vt.secondary),
                  const SizedBox(width: 8),
                  Text(label,
                      style: TextStyle(
                          color: selected ? vt.onEmphasis : vt.secondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 240,
        child: Container(
          decoration: BoxDecoration(
            color: vt.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: vt.divider),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              segment(BulkSendChannel.sms, Icons.sms_outlined, 'Text'),
              segment(BulkSendChannel.email, Icons.email_outlined, 'Email'),
            ],
          ),
        ),
      ),
    );
  }

  // ── Fields ────────────────────────────────────────────────────
  Widget _fieldShell(VolunteersTheme vt, Widget child) => Container(
        decoration: BoxDecoration(
          color: vt.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: vt.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );

  Widget _subjectField(VolunteersTheme vt) => _fieldShell(
        vt,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _subject,
            focusNode: _subjectFocus,
            enabled: !_sending,
            cursorColor: vt.highlight,
            style: TextStyle(
                color: vt.text, fontSize: 14.5, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              hintText: 'Subject',
              hintStyle: TextStyle(color: vt.secondary, fontSize: 14.5),
            ),
          ),
        ),
      );

  Widget _bodyField(VolunteersTheme vt) {
    if (_isText) {
      return _fieldShell(
        vt,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: _text,
            focusNode: _textFocus,
            enabled: !_sending,
            maxLines: null,
            minLines: 6,
            cursorColor: vt.highlight,
            style: TextStyle(color: vt.text, fontSize: 14.5, height: 1.45),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              hintText: 'Write the text members will read.',
              hintStyle: TextStyle(color: vt.secondary, fontSize: 14.5),
            ),
          ),
        ),
      );
    }

    _body.readOnly = _sending;
    final locale = Localizations.maybeLocaleOf(context) ?? const Locale('en');

    return _fieldShell(
      vt,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(vt),
          Container(height: 1, color: vt.divider),
          // Quill derives its text colour from the ambient DefaultTextStyle,
          // which in this app is a dark-theme white already. Pinning it here
          // is what keeps the body on the documented white-on-navy pair
          // regardless of what the app theme does later.
          DefaultTextStyle(
            style: TextStyle(color: vt.text, fontSize: 14.5, height: 1.5),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 200),
              child: quill.QuillEditor(
                focusNode: _bodyFocus,
                scrollController: _bodyScroll,
                configurations: quill.QuillEditorConfigurations(
                  controller: _body,
                  sharedConfigurations:
                      quill.QuillSharedConfigurations(locale: locale),
                  scrollable: true,
                  expands: false,
                  padding: const EdgeInsets.all(12),
                  minHeight: 190,
                  customStyles: quill.DefaultStyles(
                    link: TextStyle(
                      color: vt.highlight,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(VolunteersTheme vt) {
    final attributes = _body.getSelectionStyle().attributes;
    final listValue = attributes[quill.Attribute.list.key]?.value;

    Widget button({
      required IconData icon,
      required String tooltip,
      required bool active,
      required VoidCallback onTap,
    }) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: active ? vt.emphasisFill : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: _sending ? null : onTap,
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(icon,
                  size: 17, color: active ? vt.onEmphasis : vt.secondary),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          button(
            icon: Icons.format_bold,
            tooltip: 'Bold',
            active: attributes.containsKey(quill.Attribute.bold.key),
            onTap: () => _toggleInline(quill.Attribute.bold),
          ),
          button(
            icon: Icons.format_italic,
            tooltip: 'Italic',
            active: attributes.containsKey(quill.Attribute.italic.key),
            onTap: () => _toggleInline(quill.Attribute.italic),
          ),
          button(
            icon: Icons.format_underlined,
            tooltip: 'Underline',
            active: attributes.containsKey(quill.Attribute.underline.key),
            onTap: () => _toggleInline(quill.Attribute.underline),
          ),
          button(
            icon: Icons.title,
            tooltip: 'Heading',
            active: attributes[quill.Attribute.header.key]?.value ==
                quill.Attribute.h2.value,
            onTap: () => _toggleBlock(quill.Attribute.h2),
          ),
          button(
            icon: Icons.format_list_bulleted,
            tooltip: 'Bulleted list',
            active: listValue == quill.Attribute.ul.value,
            onTap: () => _toggleBlock(quill.Attribute.ul),
          ),
          button(
            icon: Icons.format_list_numbered,
            tooltip: 'Numbered list',
            active: listValue == quill.Attribute.ol.value,
            onTap: () => _toggleBlock(quill.Attribute.ol),
          ),
          button(
            icon: Icons.format_quote,
            tooltip: 'Quote',
            active: attributes.containsKey(quill.Attribute.blockQuote.key),
            onTap: () => _toggleBlock(quill.Attribute.blockQuote),
          ),
          button(
            icon: Icons.link,
            tooltip: 'Hyperlink',
            active: attributes.containsKey(quill.Attribute.link.key),
            onTap: _promptForLink,
          ),
        ],
      ),
    );
  }

  void _toggleInline(quill.Attribute attribute) {
    if (_sending) return;
    final selection = _body.selection;
    if (!selection.isValid) return;
    final active =
        _body.getSelectionStyle().attributes.containsKey(attribute.key);
    _body.formatSelection(
        active ? quill.Attribute.clone(attribute, null) : attribute);
    setState(() {});
  }

  /// Compared by VALUE rather than key, so tapping the heading while already
  /// on a heading clears it instead of doing nothing.
  void _toggleBlock(quill.Attribute attribute) {
    if (_sending) return;
    final current = _body.getSelectionStyle().attributes[attribute.key];
    final active = current != null && current.value == attribute.value;
    _body.formatSelection(
        active ? quill.Attribute.clone(attribute, null) : attribute);
    setState(() {});
  }

  Future<void> _promptForLink() async {
    if (_sending) return;
    final selection = _body.selection;
    if (!selection.isValid || selection.isCollapsed) {
      _snack('Select the text you want to link first.');
      return;
    }

    final existing = _body
            .getSelectionStyle()
            .attributes[quill.Attribute.link.key]
            ?.value
            ?.toString() ??
        '';
    final controller = TextEditingController(text: existing);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (_, setDialogState) {
            void apply() {
              final normalized = ComposerLinks.normalize(controller.text.trim());
              if (normalized == null) {
                setDialogState(() => error = ComposerLinks.rejectionMessage);
                return;
              }
              Navigator.pop(dialogContext, normalized);
            }

            return AlertDialog(
              backgroundColor: BrandColors.unityBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              titleTextStyle: BrandTextStyles.title,
              title: const Text('Hyperlink'),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.url,
                      cursorColor: BrandColors.sunriseGold,
                      style: const TextStyle(color: Colors.white),
                      onSubmitted: (_) => apply(),
                      decoration: InputDecoration(
                        labelText: 'Destination',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'https://moyoungdemocrats.org',
                        hintStyle: const TextStyle(color: Colors.white70),
                        errorText: error,
                        border: const OutlineInputBorder(),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white30),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide:
                              BorderSide(color: BrandColors.sunriseGold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(ComposerLinks.rejectionMessage,
                        style: BrandTextStyles.caption),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                if (existing.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: BrandColors.sunriseGold),
                    onPressed: () => Navigator.pop(dialogContext, ''),
                    icon: const Icon(Icons.link_off, size: 18),
                    label: const Text('Remove link'),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.sunriseGold,
                    foregroundColor: BrandColors.unityBlue,
                  ),
                  onPressed: apply,
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    if (result == null || !mounted) return;

    if (result.isEmpty) {
      _body.formatSelection(quill.Attribute.clone(quill.Attribute.link, null));
    } else {
      _body.formatSelection(quill.LinkAttribute(result));
    }
    setState(() {});
  }

  // ── Merge chips ───────────────────────────────────────────────
  Widget _mergeChips(VolunteersTheme vt) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('INSERT A FIELD AT THE CURSOR',
              style: TextStyle(
                  color: vt.secondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ComposerMergeFields.definitions
                .map((d) => Tooltip(
                      message: '${d.token}\n${d.description}',
                      child: Material(
                        color: vt.surface,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap:
                              _sending ? null : () => _insertMergeField(d.token),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: vt.divider),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 14, color: vt.secondary),
                                const SizedBox(width: 6),
                                Text(d.label,
                                    style: TextStyle(
                                        color: vt.text,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ))
                .toList(growable: false),
          ),
        ],
      );

  void _insertMergeField(String token) {
    if (_sending) return;
    final selection = _body.selection;
    final length = _body.document.length;
    final valid = selection.start >= 0 && selection.end >= 0;
    final start = (valid ? selection.start : length).clamp(0, length);
    final end = (valid ? selection.end : start).clamp(0, length);
    final replace = (end - start).clamp(0, length - start);

    _body.replaceText(
      start,
      replace,
      token,
      TextSelection.collapsed(offset: start + token.length),
    );
    if (!_bodyFocus.hasFocus) _bodyFocus.requestFocus();
  }

  // ── Attachments ───────────────────────────────────────────────
  Widget _attachmentsRow(VolunteersTheme vt) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: _sending ? null : _pickAttachments,
                icon: const Icon(Icons.attach_file, size: 17),
                label: Text(_attachments.isEmpty
                    ? 'Attach a file'
                    : 'Attach another file'),
                style: TextButton.styleFrom(
                  foregroundColor: vt.highlight,
                  minimumSize: const Size(0, 44),
                  textStyle: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _attachments
                  .map((a) => Container(
                        padding: const EdgeInsets.fromLTRB(10, 4, 2, 4),
                        decoration: BoxDecoration(
                          color: vt.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: vt.divider),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: 200),
                              child: Text(a.file.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: vt.text, fontSize: 12.5)),
                            ),
                            IconButton(
                              onPressed: _sending
                                  ? null
                                  : () =>
                                      setState(() => _attachments.remove(a)),
                              tooltip: 'Remove ${a.file.name}',
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                  width: 28, height: 28),
                              padding: EdgeInsets.zero,
                              icon: Icon(Icons.close,
                                  size: 14, color: vt.secondary),
                            ),
                          ],
                        ),
                      ))
                  .toList(growable: false),
            ),
            const SizedBox(height: 8),
            _notice(
              vt,
              Icons.info_outline,
              'Attachments are not saved with a draft. Re-attach before you '
              'send.',
              vt.secondary,
            ),
          ],
        ],
      );

  // ── Footer ────────────────────────────────────────────────────
  Widget _footer(VolunteersTheme vt, ComposerContent content) {
    final blockers = _blockersFor(content);
    final n = _eligible.length;
    final label = _isText ? 'Send $n' : 'Email $n';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(_saveCaption(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: vt.secondary, fontSize: 12)),
            ),
            if (_touchpointId != null && !_sending)
              TextButton(
                onPressed: _discard,
                style: TextButton.styleFrom(
                  foregroundColor: vt.secondary,
                  minimumSize: const Size(0, 44),
                  textStyle: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                child: const Text('Discard'),
              ),
            const SizedBox(width: 8),
            Flexible(
              child: _primaryButton(
                vt,
                icon: _isText ? Icons.sms_outlined : Icons.email_outlined,
                label: _sending ? 'Sending $_sent of $_sendTotal' : label,
                enabled: blockers.isEmpty && !_sending,
                onTap: _send,
              ),
            ),
          ],
        ),
        if (blockers.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(blockers.first,
              style: TextStyle(color: vt.secondary, fontSize: 12)),
        ],
      ],
    );
  }

  String _saveCaption() {
    if (_sending) return 'Sending. Do not close this tab.';
    if (_saving) return 'Saving…';
    if (_saveFailed) return 'Not saved. The last change is still only here.';
    final at = _savedAt;
    if (at != null) return 'Draft saved ${_clock(at)}';
    return 'A draft is saved as soon as you start writing.';
  }

  // ── Result card ───────────────────────────────────────────────
  /// What the send did, in place of the composer. It reports first; the three
  /// follow-ups under it are retrying the failures, logging the send as an
  /// activity, and starting another with the same audience.
  Widget _resultCard(VolunteersTheme vt, BulkSendResult result) {
    final failed = result.failedMemberIds.length;
    final headline = failed == 0
        ? 'Sent to ${result.deliveredCount} of ${result.attemptedCount}.'
        : (result.deliveredCount == 0
            ? 'Nothing went out. ${result.attemptedCount} failed.'
            : 'Sent to ${result.deliveredCount} of ${result.attemptedCount}. '
                '$failed failed.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              failed == 0
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              size: 20,
              color: failed == 0 ? vt.text : vt.highlight,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(headline,
                  style: TextStyle(
                      color: vt.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'It is on your desk and on every region it covered. '
          '${result.errorDetail ?? ''}'.trim(),
          style: TextStyle(color: vt.secondary, fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 14),
        // Wrapped, not rowed: three actions at this width will not fit one
        // line on the narrow layout, and an overflowing Row drops the last of
        // them off the edge.
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (failed > 0)
              // BOUNDED on purpose. A Wrap hands its children unbounded
              // main-axis constraints, and _primaryButton's label sits in a
              // Flexible, which throws on an infinite width. This is the cap
              // that keeps the label eliding instead.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: _primaryButton(
                  vt,
                  icon: Icons.replay,
                  label: 'Retry the $failed that failed',
                  enabled: true,
                  onTap: _retryFailures,
                ),
              ),
            // A send that reached nobody has no roster, so there is nothing to
            // log. The database refuses it too; not offering it is how the
            // exec learns that without a failed request.
            if (result.deliveredCount > 0)
              TextButton.icon(
                onPressed:
                    (_promoting || _resultPromoted) ? null : _logAsActivity,
                icon: Icon(
                    _resultPromoted
                        ? Icons.check_circle_outline
                        : Icons.event_note_outlined,
                    size: 17),
                label: Text(_resultPromoted
                    ? 'Logged as an activity'
                    : 'Log this as an activity'),
                style: TextButton.styleFrom(
                  foregroundColor: vt.highlight,
                  disabledForegroundColor: vt.secondary,
                  minimumSize: const Size(0, 46),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            TextButton.icon(
              onPressed: _startAnother,
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Start another'),
              style: TextButton.styleFrom(
                foregroundColor: vt.highlight,
                minimumSize: const Size(0, 46),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Shared bits ───────────────────────────────────────────────
  Widget _notice(
          VolunteersTheme vt, IconData icon, String text, Color accent) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: vt.secondary, fontSize: 12, height: 1.4)),
          ),
        ],
      );

  /// The workspace's one filled action: sunriseGold under unityBlue, 7.17:1.
  Widget _primaryButton(
    VolunteersTheme vt, {
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: vt.emphasisFill,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: vt.onEmphasis),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: vt.onEmphasis,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One attachment in both the shapes the two send paths need.
///
/// The sms path hands `file_picker.PlatformFile` straight to
/// [CRMMessageService.sendBulkMessages]; the email path needs the app's own
/// materialized [PlatformFile] so [CRMEmailService.buildAttachmentFromPlatformFile]
/// can read bytes that the browser only ever handed over once. Keeping both
/// avoids converting on the send path, where a conversion failure would land
/// after the row was already claimed.
@immutable
class ComposerAttachment {
  const ComposerAttachment({required this.picked, required this.file});

  final file_picker.PlatformFile picked;
  final PlatformFile file;
}
