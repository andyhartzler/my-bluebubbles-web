import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/form_schema.dart';
import '../models/form_submission.dart';
import '../models/submission_review_model.dart';
import '../widgets/submission_detail/candidate_hero_header.dart';
import '../widgets/submission_detail/section_card.dart';
import '../widgets/submission_detail/policy_positions_grid.dart';
import '../widgets/submission_detail/documents_card.dart';
import '../widgets/submission_detail/references_card.dart';
import '../widgets/submission_detail/ai_alignment_card.dart';
import '../services/forms_service.dart';
import 'endorsement_hub/ai_score_repository.dart';
import '../../../models/crm/member.dart';
import '../../../models/crm/subscriber.dart';
import '../../../screens/crm/candidate_detail_screen.dart';
import '../../../screens/crm/member_detail_screen.dart';
import '../../../services/crm/candidate_repository.dart';
import '../../../services/crm/member_repository.dart';
import '../../../services/crm/subscriber_repository.dart';

/// Endorsement submission review screen. Renders a MOYD-branded candidate
/// hero, a pinned at-a-glance bar, one card per form section (with policy
/// grids where detected), documents and references, plus a collapsed
/// submission-metadata tile at the bottom.
class SubmissionDetailScreen extends StatefulWidget {
  /// Constructor with pre-loaded data
  final FormSubmission? submission;
  final FormSchema? form;

  /// Constructor with IDs to load data
  final String? formId;
  final String? submissionId;

  const SubmissionDetailScreen({
    Key? key,
    this.submission,
    this.form,
    this.formId,
    this.submissionId,
  })  : assert(
          (submission != null && form != null) ||
              (formId != null && submissionId != null),
          'Either provide submission+form or formId+submissionId',
        ),
        super(key: key);

  /// Named constructor for loading by IDs
  const SubmissionDetailScreen.byId({
    Key? key,
    required String formId,
    required String submissionId,
  }) : this(key: key, formId: formId, submissionId: submissionId);

  @override
  State<SubmissionDetailScreen> createState() => _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState extends State<SubmissionDetailScreen> {
  final EndorsementAiScoreRepository _aiScoreRepo =
      EndorsementAiScoreRepository();
  AiAlignmentScore? _aiAlignment;

  final MemberRepository _memberRepo = MemberRepository();
  final SubscriberRepository _subscriberRepo = SubscriberRepository();
  final FormsService _formsService = FormsService();

  Member? _linkedMember;
  Subscriber? _linkedSubscriber;

  // For loading by IDs
  FormSubmission? _loadedSubmission;
  FormSchema? _loadedForm;
  bool _isLoading = true;
  String? _loadError;

  FormSubmission? get submission => widget.submission ?? _loadedSubmission;
  FormSchema? get form => widget.form ?? _loadedForm;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.submission != null && widget.form != null) {
      setState(() => _isLoading = false);
      _loadLinkedPerson();
      _loadAiScore();
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final results = await Future.wait([
        _formsService.getSubmission(widget.submissionId!),
        _formsService.getForm(widget.formId!),
      ]);

      final loadedSubmission = results[0] as FormSubmission?;
      final loadedForm = results[1] as FormSchema;

      if (loadedSubmission == null) {
        setState(() {
          _loadError = 'Submission not found';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _loadedSubmission = loadedSubmission;
        _loadedForm = loadedForm;
        _isLoading = false;
      });

      _loadLinkedPerson();
      _loadAiScore();
    } catch (e) {
      setState(() {
        _loadError = 'Failed to load submission: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAiScore() async {
    final s = submission;
    if (s == null) return;
    try {
      final score = await _aiScoreRepo.loadOne(s.id);
      if (mounted && score != null) {
        setState(() => _aiAlignment = score);
      }
    } catch (e) {
      debugPrint('Error loading AI alignment score: $e');
    }
  }

  Future<void> _loadLinkedPerson() async {
    if (submission == null) return;
    if (submission!.memberId == null && submission!.subscriberId == null) {
      return;
    }

    try {
      if (submission!.memberId != null) {
        final member = await _memberRepo.getMemberById(submission!.memberId!);
        if (mounted && member != null) {
          setState(() => _linkedMember = member);
        }
      }
      if (submission!.subscriberId != null) {
        final subscriber =
            await _subscriberRepo.fetchSubscriberById(submission!.subscriberId!);
        if (mounted && subscriber != null) {
          setState(() => _linkedSubscriber = subscriber);
        }
      }
    } catch (e) {
      debugPrint('Error loading linked person: $e');
    }
  }

  void _navigateToMemberProfile() {
    if (_linkedMember != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MemberDetailScreen(member: _linkedMember!),
        ),
      );
    }
  }

  Future<void> _showSubscriberDetailSheet(Subscriber subscriber) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SubscriberDetailBottomSheet(subscriber: subscriber),
    );
  }

  /// Jump from the survey review straight to the candidate's full CRM
  /// profile (money, research, pipeline) when the submission is linked.
  Future<void> _openCandidateProfile(BuildContext context) async {
    final id = submission?.candidateId;
    if (id == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final candidate = await CandidateRepository().fetchCandidate(id);
      if (candidate == null) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Linked candidate record not found.')));
        return;
      }
      navigator.push(MaterialPageRoute(
        builder: (_) => CandidateDetailScreen(candidate: candidate),
      ));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not open candidate profile: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Candidate Review',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        // Same verified navy -> royal -> deep-sky sweep as the Endorsement HQ
        // hero (white stays >= 4.5:1 at every stop).
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF263351), Color(0xFF2B4B8C), Color(0xFF1D6FA8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          if (!_isLoading && submission?.candidateId != null)
            IconButton(
              icon: const Icon(Icons.badge_outlined, color: Colors.white),
              onPressed: () => _openCandidateProfile(context),
              tooltip: 'Open candidate profile',
            ),
          if (!_isLoading && submission != null && form != null)
            IconButton(
              icon: const Icon(Icons.content_copy, color: Colors.white),
              onPressed: () => _copySubmission(context),
              tooltip: 'Copy to clipboard',
            ),
        ],
      ),
      body: _buildBody(context, theme),
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                _loadError!,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (submission == null || form == null) {
      return const Center(child: Text('No submission data available'));
    }

    final model = SubmissionReviewModel.from(form!, submission!,
        aiAlignment: _aiAlignment);

    // Linked-profile affordance for the hero contact row.
    VoidCallback? onOpenProfile;
    String? linkedLabel;
    if (_linkedMember != null) {
      onOpenProfile = _navigateToMemberProfile;
      linkedLabel = 'Member profile';
    } else if (_linkedSubscriber != null) {
      onOpenProfile = () => _showSubscriberDetailSheet(_linkedSubscriber!);
      linkedLabel = 'Subscriber';
    }

    final glance = AtAGlanceBar(model: model);

    // Readable measure on ultrawide monitors: cap the content column.
    const maxContentWidth = 1040.0;
    Widget constrain(Widget child) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxContentWidth),
            child: child,
          ),
        );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: constrain(Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: CandidateHeroHeader(
              model: model,
              status: submission!.status,
              onOpenLinkedProfile: onOpenProfile,
              linkedProfileLabel: linkedLabel,
            ),
          )),
        ),
        if (glance.hasContent)
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedBarDelegate(child: glance, height: AtAGlanceBar.height),
          ),
        SliverToBoxAdapter(
          child: constrain(Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (model.aiAlignment != null)
                  AiAlignmentCard(
                    ai: model.aiAlignment!,
                    rulePct: model.ruleAlignmentPct,
                  ),
                for (final section in model.sections)
                  SectionCard(
                    section: section,
                    leading: section.isPolicyGrid
                        ? PolicyPositionsGrid(
                            positions: section.policyPositions)
                        : null,
                  ),
                if (model.hasDocuments) DocumentsCard(model: model),
                if (model.references.isNotEmpty)
                  ReferencesCard(references: model.references),
                _MetadataTile(submission: submission!, form: form!),
              ],
            ),
          )),
        ),
      ],
    );
  }

  void _copySubmission(BuildContext context) {
    if (submission == null || form == null) return;
    final model = SubmissionReviewModel.from(form!, submission!);

    final buffer = StringBuffer();
    buffer.writeln('Form: ${form!.title}');
    buffer.writeln('Candidate: ${model.candidateName}');
    if (model.office != null) buffer.writeln('Office: ${model.office}');
    if (model.district != null) buffer.writeln('District: ${model.district}');
    if (model.email != null) buffer.writeln('Email: ${model.email}');
    if (model.phone != null) buffer.writeln('Phone: ${model.phone}');
    buffer.writeln('Submitted: ${_formatDateTime(submission!.createdAt)}');
    buffer.writeln('');

    for (final section in model.sections) {
      if (section.title.isNotEmpty) {
        buffer.writeln('== ${section.title} ==');
      }
      for (final p in section.policyPositions) {
        buffer.write('${p.question}: ${p.answerLabel}');
        if (p.explanation != null && p.explanation!.trim().isNotEmpty) {
          buffer.write('  — ${p.explanation!.trim()}');
        }
        buffer.writeln();
      }
      for (final a in section.answers) {
        buffer.writeln('${a.label}: ${a.displayValue}');
      }
      buffer.writeln('');
    }

    if (model.references.isNotEmpty) {
      buffer.writeln('== References ==');
      for (final r in model.references) {
        buffer.writeln(
            r.fields.map((f) => '${f.key}: ${f.value}').join('  |  '));
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Submission copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.month}/${date.day}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Pinned delegate wrapper for the at-a-glance bar.
class _PinnedBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _PinnedBarDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _PinnedBarDelegate oldDelegate) =>
      oldDelegate.child != child || oldDelegate.height != height;
}

/// Collapsed submission-metadata tile (demoted from a prominent card).
class _MetadataTile extends StatelessWidget {
  final FormSubmission submission;
  final FormSchema form;

  const _MetadataTile({required this.submission, required this.form});

  String _fmt(DateTime d) =>
      '${d.month}/${d.day}/${d.year} at ${d.hour}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(label,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ),
              Expanded(
                child: SelectableText(value,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.info_outline, color: cs.onSurfaceVariant),
          title: Text('Submission info',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row('Submission ID', submission.id),
            row('Form ID', submission.formId),
            if (submission.memberId != null)
              row('Member ID', submission.memberId!),
            if (submission.candidateId != null)
              row('Candidate ID', submission.candidateId!),
            row('Submitted at', _fmt(submission.createdAt)),
            row('Status', submission.status),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for displaying subscriber details
class _SubscriberDetailBottomSheet extends StatelessWidget {
  final Subscriber subscriber;

  const _SubscriberDetailBottomSheet({required this.subscriber});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.teal.withOpacity(0.1),
                      child: Text(
                        subscriber.name.isNotEmpty
                            ? subscriber.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subscriber.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.contact_mail,
                                  size: 14, color: Colors.teal),
                              const SizedBox(width: 4),
                              Text(
                                'Subscriber',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: Colors.teal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildInfoTile(
                      context,
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: subscriber.email,
                    ),
                    if (subscriber.phoneE164 != null)
                      _buildInfoTile(
                        context,
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: subscriber.phoneE164!,
                      ),
                    if (subscriber.city != null || subscriber.state != null)
                      _buildInfoTile(
                        context,
                        icon: Icons.location_on_outlined,
                        label: 'Location',
                        value:
                            '${subscriber.city ?? ''}${subscriber.city != null && subscriber.state != null ? ', ' : ''}${subscriber.state ?? ''}',
                      ),
                    if (subscriber.zipCode != null)
                      _buildInfoTile(
                        context,
                        icon: Icons.local_post_office_outlined,
                        label: 'Zip Code',
                        value: subscriber.zipCode!,
                      ),
                    if (subscriber.county != null)
                      _buildInfoTile(
                        context,
                        icon: Icons.map_outlined,
                        label: 'County',
                        value: subscriber.county!,
                      ),
                    if (subscriber.source != null)
                      _buildInfoTile(
                        context,
                        icon: Icons.source_outlined,
                        label: 'Source',
                        value: subscriber.source!,
                      ),
                    if (subscriber.subscribed != null)
                      _buildInfoTile(
                        context,
                        icon: subscriber.subscribed!
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        label: 'Subscription Status',
                        value:
                            subscriber.subscribed! ? 'Subscribed' : 'Unsubscribed',
                        valueColor:
                            subscriber.subscribed! ? Colors.green : Colors.red,
                      ),
                    if (subscriber.donor != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Donor Information',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoTile(
                        context,
                        icon: Icons.volunteer_activism_outlined,
                        label: 'Total Donated',
                        value:
                            '\$${(subscriber.donor!.totalDonated ?? 0).toStringAsFixed(2)}',
                      ),
                      _buildInfoTile(
                        context,
                        icon: Icons.numbers,
                        label: 'Donation Count',
                        value: '${subscriber.donor!.donationCount}',
                      ),
                    ],
                    if (subscriber.notes != null &&
                        subscriber.notes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Notes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(subscriber.notes!),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
