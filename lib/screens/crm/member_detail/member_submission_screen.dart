import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
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
//  an exec "Not scored yet" placeholder over a member's answers.
//
//  What IS reused is the parsing. SubmissionReviewModel.from turns a schema
//  and a submission into ordered sections of answered questions, which is the
//  "formatted like the way they filled it out" reading, and it is pure model
//  code with no colour and no scoring in it. The RENDERING is the profile's:
//  ProfileSheet, profileSectionHeader, ProfileField, ProfileLongText,
//  profileChips and ProfileFieldFlow, so this screen and the member profile
//  read as one product rather than two.
//
//  THE EMPTY RULE. A question the member did not answer is omitted, and a
//  section whose answers are all empty is omitted entirely. That is enforced
//  in the model rather than here: SubmissionReviewModel.from filters each
//  section's fields on `!_isEmptyValue(data[f.id])` and then appends the
//  section only `if (!section.isEmpty)`. So this screen renders what it is
//  given and adds no empty-state rows of its own.
//
//  CONTRAST. Every pair on this screen is a pair member_profile_sections.dart
//  already measures; this file introduces no new colour of its own and never
//  reads a colour from Theme.
//
//    white on unityBlue (app bar, header name) ......... 12.51:1 (documented)
//    white70 on unityBlue (submitted line) ............. 7.03:1  (documented)
//    white on white 0.15 over unityBlue (#47526B) ...... 7.81:1  (computed,
//        member_profile_sections.dart) for the status pill
//    unityBlue on white (values, links, spinner) ....... 12.51:1 (computed)
//    unityBlue 0.70 on white (#687085) labels/captions .. 4.95:1 (documented)
//    unityBlue on unityBlue 0.06 over white (#F2F3F5) ... 11.27:1 (computed)
//        for the quote block and the chip fill
//    white on unityBlue (Retry button) ................. 12.51:1 (documented)
//
//  sunriseGold appears only as a MARK, the 4 by 20 section rule and the 3 px
//  quote border, never under text. momentumBlue carries no text anywhere here:
//  white on it is 2.75:1 and fails even the 3:1 large-text floor.
// ═════════════════════════════════════════════════════════════

/// Read-only view of ONE form submission by ONE member, reached from the
/// member profile. Loads by id exactly as the endorsement review screen does.
class MemberSubmissionScreen extends StatefulWidget {
  const MemberSubmissionScreen({
    super.key,
    required this.formId,
    required this.submissionId,
  });

  final String formId;
  final String submissionId;

  @override
  State<MemberSubmissionScreen> createState() => _MemberSubmissionScreenState();
}

class _MemberSubmissionScreenState extends State<MemberSubmissionScreen> {
  final FormsService _formsService = FormsService();

  FormSubmission? _submission;
  FormSchema? _form;
  bool _loading = true;
  String? _loadError;

  /// Readable measure on a wide monitor. Wide enough that ProfileFieldFlow's
  /// 560 px two-up threshold engages inside the sheet.
  static const double _maxContentWidth = 960;

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
        backgroundColor: ProfileTokens.ink,
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: ProfileTokens.band,
        elevation: 0,
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
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: _maxContentWidth),
              child: _buildBody(model, submission, form),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(SubmissionReviewModel? model, FormSubmission? submission,
      FormSchema? form) {
    if (_loading) {
      return _centeredSheet(
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(ProfileTokens.ink),
          ),
        ),
      );
    }

    final error = _loadError;
    if (error != null) {
      return _centeredSheet(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Could not load', style: ProfileText.value),
            const SizedBox(height: 6),
            SelectableText(error, style: ProfileText.longText),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _load,
                style: FilledButton.styleFrom(
                  backgroundColor: ProfileTokens.ink,
                  foregroundColor: Colors.white,
                  textStyle: ProfileText.button,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(ProfileTokens.blockRadius),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      );
    }

    if (model == null || submission == null || form == null) {
      return _centeredSheet(
        const Text('No submission data available.', style: ProfileText.value),
      );
    }

    final documents = _documentRows(model);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: ProfileSheet(
        children: [
          _headerBand(model, submission, form),
          for (int i = 0; i < model.sections.length; i++) ...[
            profileSectionHeader(
              title: _sectionTitle(model.sections[i]),
              // The navy band already separates the first section; a hairline
              // directly under it would be a second divider on one seam.
              first: i == 0,
            ),
            profileSectionBody(child: _sectionBody(model.sections[i])),
          ],
          if (documents.isNotEmpty) ...[
            profileSectionHeader(title: 'Attachments'),
            profileSectionBody(child: _documentsBody(documents)),
          ],
        ],
      ),
    );
  }

  /// White sheet holding a single centred block, so nothing sits directly on
  /// BrandedBackground, which carries no ink that passes at both of its ends.
  Widget _centeredSheet(Widget child) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ProfileSheet(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  /// Solid unityBlue band fused to the top of the sheet: who filled it in,
  /// when, and the submission's status.
  Widget _headerBand(SubmissionReviewModel model, FormSubmission submission,
      FormSchema form) {
    return Container(
      width: double.infinity,
      color: ProfileTokens.band,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _submitterName(model, submission, form),
            style: ProfileText.headerName,
          ),
          const SizedBox(height: 6),
          Text(
            'Submitted ${_formatDateTime(submission.createdAt)}',
            style: ProfileText.headerLine,
          ),
          if (submission.status.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ProfilePill(
                label: _prettyStatus(submission.status),
                style: ProfilePillStyle.soft,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionBody(ReviewSection section) {
    final items = <ProfileFlowItem>[];

    // A section the model classified as a policy grid still holds real
    // answers, they just live in policyPositions rather than in answers. They
    // are rendered here as ordinary question-and-answer fields: the stance
    // pills and the grid are endorsement review furniture and their colours
    // are not measured for this surface.
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

  Widget _documentsBody(List<_DocumentRow> documents) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final doc in documents)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.label.toUpperCase(), style: ProfileText.label),
                const SizedBox(height: 4),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(ProfileTokens.pillRadius),
                    onTap: () {
                      final uri = Uri.tryParse(doc.url);
                      if (uri != null && uri.hasScheme) {
                        _openLink(uri);
                      } else {
                        _copyValue(doc.label, doc.url);
                      }
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            doc.name,
                            style: ProfileText.value.copyWith(
                              decoration: TextDecoration.underline,
                              decorationColor: ProfileTokens.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.open_in_new,
                            size: 16,
                            color: ProfileTokens.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
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
