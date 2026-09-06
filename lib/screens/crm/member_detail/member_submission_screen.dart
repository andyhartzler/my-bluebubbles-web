import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import 'package:bluebubbles/features/forms/models/form_schema.dart';
import 'package:bluebubbles/features/forms/models/form_submission.dart';
import 'package:bluebubbles/features/forms/models/submission_review_model.dart';
import 'package:bluebubbles/features/forms/services/forms_service.dart';
import 'package:bluebubbles/screens/crm/widgets/member_profile_sections.dart';

// ═════════════════════════════════════════════════════════════
//  ONE MEMBER'S SUBMITTED FORM, READ ONLY, IN THE PROFILE'S OWN SURFACE.
//
//  This is the membership half of the split. SubmissionDetailScreen stays the
//  ENDORSEMENT candidate review and is correct for its two endorsement
//  callers: it carries the Gemini verdict, the exec ballots and the title
//  "Candidate Review". None of that belongs on a member's own membership form,
//  which is never scored, and a member profile that pushed that screen showed
//  an exec "Not scored yet" placeholder over a member's answers. Nothing from
//  that review appears here: no verdict block, no score, no ballots.
//
//  What IS reused is the parsing. SubmissionReviewModel.from turns a schema
//  and a submission into ordered sections of answered questions, which is the
//  "formatted like the way they filled it out" reading, and it is pure model
//  code with no colour and no scoring in it. The RENDERING is the profile's,
//  built in the Slack management page's idiom that member_profile_sections.dart
//  now carries: gradient cards on BrandedBackground, a hero card with the
//  submitter as the headline, a strip of BrandedStatCards, then every section
//  as its own gradient card in a two column grid from 1100 wide. This screen
//  and the member profile read as one product rather than two.
//
//  THE EMPTY RULE. A question the member did not answer is omitted, and a
//  section whose answers are all empty is omitted entirely. That is enforced
//  in the model rather than here: SubmissionReviewModel.from filters each
//  section's fields on `!_isEmptyValue(data[f.id])` and then appends the
//  section only `if (!section.isEmpty)`. So this screen renders what it is
//  given and adds no empty-state rows of its own. A section the model
//  classified as a policy grid still carries real answers, in policyPositions
//  rather than answers, and they render here as ordinary fields, never
//  dropped.
//
//  THE ONE TEXT RULE. Every piece of text that must be read on a gradient
//  card is FULL WHITE, with hierarchy carried by size, weight and letter
//  spacing. Alpha touches only the hairline rules between field rows.
//
//  CONTRAST. Every pair on this screen is a pair member_profile_sections.dart
//  and brand_colors.dart already measure; this file introduces no colour of
//  its own and never reads a colour from Theme. Recomputed here with the WCAG
//  2.1 relative luminance formula, alpha fills composited over the real
//  parent fill before measuring:
//
//    white on unityBlue #273351 (app bar dark end, chips, icon tiles,
//        avatar initials, snackbar) ......................... 12.51:1
//    white on gradient midpoint #22587E ...................... 7.59:1
//    white on tileGradientEnd #1C7DAB (card light end) ....... 4.59:1
//    unityBlue on sunriseGold (action pills, Retry) .......... 7.17:1
//    white on #B91C1C (error banner) ......................... 6.47:1
//    white 0.15 over the card, hairline rules only ........... 1.29:1 to
//        1.60:1, decorative, nothing is read against it
//
//  sunriseGold is a fill under unityBlue ink or the 3 px avatar ring, never
//  text on the card: gold against the light end is 2.63:1.
// ═════════════════════════════════════════════════════════════

/// Read-only view of ONE form submission by ONE member, reached from the
/// member profile. Loads by id exactly as the endorsement review screen does.
class MemberSubmissionScreen extends StatefulWidget {
  const MemberSubmissionScreen({
    super.key,
    required this.formId,
    required this.submissionId,
    this.avatarUrl,
  });

  final String formId;
  final String submissionId;

  /// The submitter's photo for the hero, when the caller has one. The member
  /// profile owns the photo rule (Member.effectiveAvatarUrl is the only
  /// source), so this screen never derives a photo from the submission
  /// itself; without a URL the hero shows initials, white on unityBlue.
  final String? avatarUrl;

  @override
  State<MemberSubmissionScreen> createState() => _MemberSubmissionScreenState();
}

class _MemberSubmissionScreenState extends State<MemberSubmissionScreen> {
  final FormsService _formsService = FormsService();

  FormSubmission? _submission;
  FormSchema? _form;
  bool _loading = true;
  String? _loadError;

  /// The page and the profile share one measure so the two read as one
  /// product; the two column section grid needs 1100 to open.
  static const double _maxContentWidth = ProfileTokens.maxSheetWidth;

  /// Below this the hero stacks and centres, as the profile's does.
  static const double _wideBreakpoint = 768;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final results = await Future.wait([
        _formsService.getSubmission(widget.submissionId),
        _formsService.getForm(widget.formId),
      ]);

      final submission = results[0] as FormSubmission?;
      final form = results[1] as FormSchema;

      if (!mounted) return;
      if (submission == null) {
        setState(() {
          _loadError = 'Submission not found.';
          _loading = false;
        });
        return;
      }

      setState(() {
        _submission = submission;
        _form = form;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load this submission: $e';
        _loading = false;
      });
    }
  }

  // ── naming ────────────────────────────────────────────────────────────────

  /// Who filled it in.
  ///
  /// SubmissionReviewModel.candidateName falls back to the literal string
  /// 'Candidate' when a form carries no name field, which is endorsement
  /// vocabulary and must never reach a member's page. So the sentinel is
  /// rejected here and the submission's own display name is used instead.
  String _submitterName(SubmissionReviewModel model, FormSubmission submission,
      FormSchema form) {
    final curated = model.candidateName.trim();
    if (curated.isNotEmpty && curated != 'Candidate') return curated;
    final display = submission.displayName.trim();
    if (display.isNotEmpty && display != 'Anonymous') return display;
    return form.title;
  }

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDateTime(DateTime utc) {
    final d = utc.toLocal();
    final hour24 = d.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final meridiem = hour24 < 12 ? 'AM' : 'PM';
    return '${_months[d.month - 1]} ${d.day}, ${d.year} at $hour12:$minute $meridiem';
  }

  String _prettyStatus(String raw) => raw.replaceAll('_', ' ').trim();

  // ── value helpers ─────────────────────────────────────────────────────────

  static const Set<String> _longTypes = {'long_answer', 'textarea'};
  static const Set<String> _copyableTypes = {'email', 'phone', 'url'};
  static const Set<String> _copyableIds = {'email', 'phone', 'phone_e164'};

  bool _isLong(ReviewAnswer a) => _longTypes.contains(a.type);

  bool _isMulti(ReviewAnswer a) => a.rawValue is List;

  bool _isCopyable(ReviewAnswer a) =>
      _copyableTypes.contains(a.type) || _copyableIds.contains(a.field.id);

  /// Per-item option labels for a multi-select, so each selection becomes its
  /// own chip.
  ///
  /// DUPLICATED from AnswerDisplay._multiLabels in the forms feature, and this
  /// is the only duplication in this file. That method is private to a widget
  /// whose every colour comes from Theme.of(context) and MoydBrand, so the
  /// widget itself cannot be reused on a branded surface, and the model exposes
  /// only the JOINED display string. Six lines of option lookup is not worth a
  /// shared component.
  List<String> _multiLabels(ReviewAnswer answer) {
    String optLabel(String v) {
      final opts = answer.field.options;
      if (opts != null) {
        for (final o in opts) {
          if (o.value == v) return o.label;
        }
      }
      return v;
    }

    return (answer.rawValue as List)
        .map((e) => optLabel(e.toString()))
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Uri? _linkFor(ReviewAnswer answer) {
    if (answer.type != 'url') return null;
    final parsed = Uri.tryParse(answer.displayValue.trim());
    if (parsed == null || !parsed.hasScheme) return null;
    return parsed;
  }

  /// Every answer the member gave, across the ordinary fields and the policy
  /// grid rows, for the stat strip. Companions and explanations ride on their
  /// parent answer and are not counted twice.
  int _answerCount(SubmissionReviewModel model) {
    var count = 0;
    for (final section in model.sections) {
      count += section.answers.length + section.policyPositions.length;
    }
    return count;
  }

  // ── actions ───────────────────────────────────────────────────────────────

  Future<void> _openLink(Uri url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        _toast(messenger, 'Could not open $url');
      }
    } catch (_) {
      if (mounted) _toast(messenger, 'Could not open $url');
    }
  }

  void _copyValue(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    _toast(ScaffoldMessenger.of(context), '$label copied');
  }

  /// unityBlue ground, white ink, 12.51:1. Coloured explicitly so the toast
  /// does not take the ambient theme's snackbar colours.
  void _toast(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: ProfileTokens.band,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }

  /// Plain-text transcript of the submission.
  ///
  /// The endorsement screen has its own builder for this, private to that file
  /// and worded for a candidate review. Twenty lines of string building is not
  /// a shared component, so this is a membership-worded rewrite rather than an
  /// export: it says "Name" rather than "Candidate", carries no office,
  /// district, money or alignment line, and lists policy-grid answers as plain
  /// question and answer pairs.
  void _copyAll(SubmissionReviewModel model, FormSubmission submission,
      FormSchema form) {
    final buffer = StringBuffer()
      ..writeln('Form: ${form.title}')
      ..writeln('Name: ${_submitterName(model, submission, form)}')
      ..writeln('Submitted: ${_formatDateTime(submission.createdAt)}')
      ..writeln('Status: ${_prettyStatus(submission.status)}')
      ..writeln();

    for (final section in model.sections) {
      buffer.writeln('== ${_sectionTitle(section)} ==');
      for (final p in section.policyPositions) {
        buffer.writeln('${p.question}: ${p.answerLabel}');
        final explanation = p.explanation?.trim();
        if (explanation != null && explanation.isNotEmpty) {
          buffer.writeln('  ${p.explanationLabel}: $explanation');
        }
      }
      for (final a in section.answers) {
        buffer.writeln('${a.label}: ${a.displayValue}');
        final companion = a.companion;
        if (companion != null) {
          buffer.writeln('  ${companion.label}: ${companion.text}');
        }
      }
      buffer.writeln();
    }

    final documents = _documentRows(model);
    if (documents.isNotEmpty) {
      buffer.writeln('== Attachments ==');
      for (final doc in documents) {
        buffer.writeln('${doc.label}: ${doc.name} (${doc.url})');
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString().trimRight()));
    _toast(ScaffoldMessenger.of(context), 'Submission copied');
  }

  Future<void> _emailSubmitter(String email) {
    return _openLink(Uri(scheme: 'mailto', path: email.trim()));
  }

  // ── documents ─────────────────────────────────────────────────────────────

  /// Every uploaded file on the submission, flattened to label plus file.
  ///
  /// A membership form has none of these. It is kept because the model hoists
  /// file answers out of the sections into its own document slots, so a form
  /// that DOES carry an upload would otherwise lose it silently, which is the
  /// one thing this screen must never do.
  List<_DocumentRow> _documentRows(SubmissionReviewModel model) {
    final rows = <_DocumentRow>[];

    void addFile(String label, ReviewFile file) {
      if (file.url.isEmpty) return;
      rows.add(_DocumentRow(label: label, name: file.name, url: file.url));
    }

    final headshot = model.headshot;
    if (headshot != null) addFile('Photo', headshot);

    final budget = model.budgetFile;
    if (budget != null) addFile('Budget', budget);

    final signature = model.signatureUrl;
    if (signature != null && signature.isNotEmpty) {
      rows.add(_DocumentRow(
        label: 'Signature',
        name: signature.split('/').last,
        url: signature,
      ));
    }

    for (final answer in model.documentAnswers) {
      for (final file in ReviewFile.parse(answer.rawValue)) {
        addFile(answer.label, file);
      }
    }

    return rows;
  }

  // ── build ─────────────────────────────────────────────────────────────────

  String _sectionTitle(ReviewSection section) =>
      section.title.trim().isEmpty ? 'Responses' : section.title.trim();

  @override
  Widget build(BuildContext context) {
    final form = _form;
    final submission = _submission;

    // Bound to explicit non-nullable locals rather than leaning on promotion,
    // because the copy action captures them inside a closure.
    SubmissionReviewModel? model;
    Widget? copyAction;
    if (form != null && submission != null) {
      final FormSchema loadedForm = form;
      final FormSubmission loadedSubmission = submission;
      final built =
          SubmissionReviewModel.from(loadedForm, loadedSubmission);
      model = built;
      copyAction = IconButton(
        tooltip: 'Copy to clipboard',
        icon: const Icon(Icons.content_copy, color: Colors.white),
        onPressed: () => _copyAll(built, loadedSubmission, loadedForm),
      );
    }

    // The Slack management page's app bar: the tile gradient as the bar, white
    // 18 w700 title, white icons. White is 12.51:1 at the bar's dark end and
    // 4.59:1 at its light end.
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: BrandColors.tileGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          form?.title ?? 'Submission',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (copyAction != null) copyAction,
        ],
      ),
      body: BrandedBackground(
        child: SafeArea(
          child: _buildBody(model, submission, form),
        ),
      ),
    );
  }

  Widget _buildBody(SubmissionReviewModel? model, FormSubmission? submission,
      FormSchema? form) {
    if (_loading) {
      return _centeredCard(
        const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    final error = _loadError;
    if (error != null) {
      return _centeredCard(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            profileSectionHeader(
              title: 'Could not load',
              icon: Icons.error_outline,
            ),
            profileSectionBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  profileErrorBanner(
                    title: 'This submission did not load',
                    message: error,
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ProfileActionPill(
                      icon: Icons.refresh,
                      label: 'Retry',
                      onPressed: _load,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        padded: false,
      );
    }

    if (model == null || submission == null || form == null) {
      return _centeredCard(
        const Text('No submission data available.', style: ProfileText.value),
      );
    }

    final documents = _documentRows(model);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;
        final twoColumns = constraints.maxWidth >= ProfileTokens.gridMinWidth;
        final listPadding = wide
            ? const EdgeInsets.symmetric(horizontal: 32, vertical: 24)
            : const EdgeInsets.all(16);

        final cards = <Widget>[
          for (final section in model.sections)
            ProfileSectionCard(
              title: _sectionTitle(section),
              icon: section.isPolicyGrid
                  ? Icons.checklist_rtl_outlined
                  : Icons.article_outlined,
              child: _sectionBody(section),
            ),
          if (documents.isNotEmpty)
            ProfileSectionCard(
              title: 'Attachments',
              icon: Icons.attach_file_outlined,
              child: _documentsBody(documents),
            ),
        ];

        return ListView(
          padding: listPadding,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _heroCard(model, submission, form, wide: wide),
                    const SizedBox(height: ProfileTokens.cardGap),
                    ..._statStrip(model, documents, wide: wide),
                    _cardGrid(cards, twoColumns: twoColumns),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// One gradient card holding a single centred block, so nothing sits
  /// directly on BrandedBackground, which carries no ink that passes at both
  /// of its ends.
  Widget _centeredCard(Widget child, {bool padded = true}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ProfileTokens.cardPadding),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ProfileSheet(
            children: [
              if (padded)
                Padding(
                  padding: const EdgeInsets.all(ProfileTokens.cardPadding),
                  child: child,
                )
              else
                child,
            ],
          ),
        ),
      ),
    );
  }

  // ── the hero card ─────────────────────────────────────────────────────────

  /// The person is the headline: a 96 px avatar in a 3 px sunriseGold ring,
  /// the name at 34, one meta line naming the form and when it was submitted,
  /// the status pill, then the action pills in the emphasis pair.
  Widget _heroCard(SubmissionReviewModel model, FormSubmission submission,
      FormSchema form,
      {required bool wide}) {
    final name = _submitterName(model, submission, form);
    final meta = '${form.title} · Submitted ${_formatDateTime(submission.createdAt)}';
    final status = _prettyStatus(submission.status);
    final emailRaw = (model.email ?? submission.submitterEmail)?.trim();
    final String? email = (emailRaw == null || emailRaw.isEmpty) ? null : emailRaw;
    // A final local promotes inside the closure; a separate bool would not.
    final VoidCallback? emailAction =
        email == null ? null : () => _emailSubmitter(email);

    final avatar = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: BrandColors.sunriseGold, width: 3),
      ),
      child: CorsAwareAvatar(
        imageUrl: widget.avatarUrl,
        radius: 48,
        backgroundColor: ProfileTokens.fill,
        fallbackText: name,
        fallbackTextColor: Colors.white,
        fallbackIconColor: Colors.white,
      ),
    );

    final textColumn = Column(
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          name,
          style: ProfileText.headerName,
          textAlign: wide ? TextAlign.start : TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          meta,
          style: ProfileText.headerLine,
          textAlign: wide ? TextAlign.start : TextAlign.center,
        ),
        if (status.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: wide ? WrapAlignment.start : WrapAlignment.center,
            children: [
              ProfilePill(label: status, style: ProfilePillStyle.soft),
            ],
          ),
        ],
      ],
    );

    final actions = Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: wide ? WrapAlignment.start : WrapAlignment.center,
      children: [
        ProfileActionPill(
          icon: Icons.content_copy,
          label: 'Copy all',
          onPressed: () => _copyAll(model, submission, form),
        ),
        ProfileActionPill(
          icon: Icons.email_outlined,
          label: 'Email',
          onPressed: emailAction,
          disabledReason: emailAction == null ? 'No email on this submission' : null,
        ),
      ],
    );

    Widget content;
    if (wide) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar,
              const SizedBox(width: 24),
              Expanded(child: textColumn),
            ],
          ),
          const SizedBox(height: 24),
          actions,
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: avatar),
          const SizedBox(height: 16),
          textColumn,
          const SizedBox(height: 20),
          actions,
        ],
      );
    }

    return ProfileSheet(
      children: [
        Padding(
          padding: EdgeInsets.all(wide ? 28 : 20),
          child: content,
        ),
      ],
    );
  }

  // ── the stat strip ────────────────────────────────────────────────────────

  /// BrandedStatCards for what the submission genuinely carries: how many
  /// questions were answered, how many sections that spans, and how many
  /// files came with it. Nothing is invented and no card renders a zero it
  /// would have to explain. No subtitle is passed, because BrandedStatCard
  /// draws its subtitle at white 0.90, which is 4.04:1 on the card's light
  /// end and fails.
  List<Widget> _statStrip(SubmissionReviewModel model, List<_DocumentRow> documents,
      {required bool wide}) {
    final answers = _answerCount(model);
    final stats = <Widget>[
      if (answers > 0)
        BrandedStatCard(
          title: 'Answers',
          value: '$answers',
          icon: Icons.question_answer_outlined,
        ),
      if (model.sections.isNotEmpty)
        BrandedStatCard(
          title: 'Sections',
          value: '${model.sections.length}',
          icon: Icons.view_agenda_outlined,
        ),
      if (documents.isNotEmpty)
        BrandedStatCard(
          title: 'Attachments',
          value: '${documents.length}',
          icon: Icons.attach_file_outlined,
        ),
    ];
    if (stats.isEmpty) return const [];

    final Widget strip;
    if (wide) {
      strip = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(child: stats[i]),
          ],
        ],
      );
    } else {
      strip = LayoutBuilder(
        builder: (context, constraints) {
          final half = (constraints.maxWidth - 16) / 2;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [for (final stat in stats) SizedBox(width: half, child: stat)],
          );
        },
      );
    }
    return [strip, const SizedBox(height: ProfileTokens.cardGap)];
  }

  // ── the section grid ──────────────────────────────────────────────────────

  /// Two columns of cards filled by alternating, 24 between cards in both
  /// directions; one column below 1100. The same shape the profile uses.
  Widget _cardGrid(List<Widget> cards, {required bool twoColumns}) {
    Widget column(List<Widget> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: ProfileTokens.cardGap),
              items[i],
            ],
          ],
        );

    if (!twoColumns) return column(cards);

    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < cards.length; i++) {
      (i.isEven ? left : right).add(cards[i]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: column(left)),
        const SizedBox(width: ProfileTokens.cardGap),
        Expanded(child: column(right)),
      ],
    );
  }

  Widget _sectionBody(ReviewSection section) {
    final items = <ProfileFlowItem>[];

    // A section the model classified as a policy grid still holds real
    // answers, they just live in policyPositions rather than in answers. They
    // are rendered here as ordinary question-and-answer fields: the stance
    // pills and the grid are endorsement review furniture and have no place
    // on a member's page.
    for (final p in section.policyPositions) {
      items.add(ProfileFlowItem(
        ProfileField(label: p.question, value: p.answerLabel),
      ));
      final explanation = p.explanation?.trim();
      if (explanation != null && explanation.isNotEmpty) {
        items.add(ProfileFlowItem(
          ProfileLongText(label: p.explanationLabel, value: explanation),
          isLong: true,
        ));
      }
    }

    for (final answer in section.answers) {
      items.add(_answerItem(answer));
      final companion = answer.companion;
      if (companion != null) {
        items.add(ProfileFlowItem(
          ProfileLongText(label: companion.label, value: companion.text),
          isLong: true,
        ));
      }
    }

    return ProfileFieldFlow(items: items);
  }

  ProfileFlowItem _answerItem(ReviewAnswer answer) {
    if (_isLong(answer)) {
      return ProfileFlowItem(
        ProfileLongText(label: answer.label, value: answer.displayValue),
        isLong: true,
      );
    }

    if (_isMulti(answer)) {
      final labels = _multiLabels(answer);
      if (labels.isEmpty) {
        return ProfileFlowItem(
          ProfileField(label: answer.label, value: answer.displayValue),
        );
      }
      return ProfileFlowItem(
        profileChips(labels, label: answer.label),
        isLong: true,
      );
    }

    final link = _linkFor(answer);
    if (link != null) {
      return ProfileFlowItem(
        ProfileField(
          label: answer.label,
          value: answer.displayValue,
          link: link,
          onOpenLink: _openLink,
        ),
      );
    }

    return ProfileFlowItem(
      ProfileField(
        label: answer.label,
        value: answer.displayValue,
        onCopy: _isCopyable(answer)
            ? () => _copyValue(answer.label, answer.displayValue)
            : null,
      ),
    );
  }

  /// Attachments as field rows: label over the file name, white underlined
  /// when it opens, copyable when the stored value is not a URL. Rows are
  /// separated by ProfileFieldFlow's hairline, never by a Divider.
  Widget _documentsBody(List<_DocumentRow> documents) {
    final items = <ProfileFlowItem>[];
    for (final doc in documents) {
      final uri = Uri.tryParse(doc.url);
      final opens = uri != null && uri.hasScheme;
      items.add(ProfileFlowItem(
        ProfileField(
          label: doc.label,
          value: doc.name,
          link: opens ? uri : null,
          onOpenLink: opens ? _openLink : null,
          onCopy: opens ? null : () => _copyValue(doc.label, doc.url),
        ),
        isLong: true,
      ));
    }
    return ProfileFieldFlow(items: items);
  }
}

/// One uploaded file, flattened out of the model's typed document slots.
class _DocumentRow {
  const _DocumentRow({
    required this.label,
    required this.name,
    required this.url,
  });

  final String label;
  final String name;
  final String url;
}
