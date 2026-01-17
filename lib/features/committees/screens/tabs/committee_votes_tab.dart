import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/forms/models/voting_form.dart';
import 'package:bluebubbles/features/forms/services/votes_service.dart';
import 'package:bluebubbles/features/forms/services/form_analytics_service.dart';
import 'package:bluebubbles/features/forms/widgets/vote_card.dart';
import 'package:bluebubbles/features/forms/screens/votes/vote_builder_screen.dart';
import 'package:bluebubbles/features/forms/screens/votes/vote_detail_screen.dart';
import 'member_votes_view.dart';

// Brand colors matching the main dashboard
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);

class CommitteeVotesTab extends StatefulWidget {
  final Committee committee;

  /// Callback to navigate to the email tab
  final VoidCallback? onNavigateToEmail;

  /// Callback to navigate to the messages tab
  final VoidCallback? onNavigateToMessages;

  /// If true, this is the member view - no create/edit/delete, view results only
  final bool isMemberView;

  /// Member ID for member view (required for voting)
  final String? memberId;

  const CommitteeVotesTab({
    Key? key,
    required this.committee,
    this.onNavigateToEmail,
    this.onNavigateToMessages,
    this.isMemberView = false,
    this.memberId,
  }) : super(key: key);

  @override
  State<CommitteeVotesTab> createState() => _CommitteeVotesTabState();
}

class _CommitteeVotesTabState extends State<CommitteeVotesTab>
    with AutomaticKeepAliveClientMixin {
  final _votesService = VotesService();
  final _analyticsService = FormAnalyticsService();
  String _statusFilter = 'all';

  // Track which votes the current exec has already voted on
  final Map<String, bool> _execHasVotedMap = {};

  /// Get the exec's member ID from auth (for exec voting)
  String get _execMemberId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  /// Get the committee name used for database operations
  /// Uses meetingsFilterName which includes "Committee" suffix to match DB constraint
  String get _committeeDbName => widget.committee.meetingsFilterName;

  @override
  bool get wantKeepAlive => true;

  /// Check if exec has voted on a specific vote
  Future<void> _checkExecVoteStatus(String voteId) async {
    if (_execMemberId.isEmpty) return;
    final hasVoted = await _votesService.hasVoted(_execMemberId, voteId);
    if (mounted) {
      setState(() {
        _execHasVotedMap[voteId] = hasVoted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Use the redesigned member view for members
    if (widget.isMemberView) {
      return MemberVotesView(
        committee: _committeeDbName,
        memberId: widget.memberId,
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Gradient background
          Positioned.fill(
            child: Image.asset(
              'assets/images/Blue-Gradient-Background.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.white.withOpacity(0.18)),
          ),
          // Content
          Column(
            children: [
              // Filter tabs
              _buildFilterTabs(),

              // Votes List
              Expanded(
                child: StreamBuilder<List<VotingForm>>(
                  stream: _votesService.watchVotesForCommittee(
                    _committeeDbName,
                    _statusFilter,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _momentumBlue,
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return _buildErrorState(snapshot.error.toString());
                    }

                    final votes = snapshot.data ?? [];

                    if (votes.isEmpty) {
                      return _buildEmptyState();
                    }

                    // For exec view, check vote status for each active vote
                    if (!widget.isMemberView && _execMemberId.isNotEmpty) {
                      for (final vote in votes) {
                        if (vote.isVotingActive &&
                            !_execHasVotedMap.containsKey(vote.id)) {
                          _checkExecVoteStatus(vote.id);
                        }
                      }
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        _execHasVotedMap.clear();
                        setState(() {});
                      },
                      color: _momentumBlue,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: votes.length,
                        itemBuilder: (context, index) {
                          final vote = votes[index];
                          final canExecVote =
                              !widget.isMemberView &&
                              vote.isVotingActive &&
                              _execMemberId.isNotEmpty &&
                              _execHasVotedMap[vote.id] == false;
                          final execHasVoted =
                              !widget.isMemberView &&
                              vote.isVotingActive &&
                              _execHasVotedMap[vote.id] == true;

                          return Column(
                            children: [
                              VoteCard(
                                vote: vote,
                                onTap: () => _viewVote(vote),
                                // Members cannot edit or delete votes
                                onEdit: widget.isMemberView
                                    ? null
                                    : () => _editVote(vote),
                                onDelete: widget.isMemberView
                                    ? null
                                    : () => _confirmDeleteVote(vote),
                              ),
                              // Show voting option for exec on active votes
                              if (canExecVote || execHasVoted)
                                _buildExecVotingBar(vote, canExecVote),
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      // Members cannot create votes
      floatingActionButton: widget.isMemberView
          ? null
          : FloatingActionButton(
              onPressed: _createNewVote,
              backgroundColor: _momentumBlue,
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = widget.isMemberView
        ? ['all', 'active', 'closed']
        : ['all', 'active', 'draft', 'closed'];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: _unityBlue,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _unityBlue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: filters.map((filter) => _buildFilterTab(filter)).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterTab(String filter) {
    final isSelected = _statusFilter == filter;
    final label = filter[0].toUpperCase() + filter.substring(1);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _statusFilter = filter);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _momentumBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.how_to_vote_outlined,
                size: 56,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.isMemberView
                  ? 'There are no votes to display'
                  : _statusFilter == 'all'
                  ? 'No votes yet'
                  : 'No $_statusFilter votes',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isMemberView
                  ? 'Check back later for committee votes'
                  : 'Create a vote for ${widget.committee.displayName} members',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
            if (!widget.isMemberView) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _createNewVote,
                icon: const Icon(Icons.add),
                label: const Text('Create Vote'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _unityBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Error loading votes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _unityBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createNewVote() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoteBuilderScreen(committee: _committeeDbName),
      ),
    );
  }

  void _viewVote(VotingForm vote) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoteDetailScreen(
          voteId: vote.id,
          onSendAsEmail: widget.isMemberView ? null : widget.onNavigateToEmail,
          onSendAsMessage: widget.isMemberView
              ? null
              : widget.onNavigateToMessages,
          isMemberView: widget.isMemberView,
        ),
      ),
    );
  }

  void _editVote(VotingForm vote) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VoteBuilderScreen(voteId: vote.id, committee: _committeeDbName),
      ),
    );
  }

  void _confirmDeleteVote(VotingForm vote) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vote'),
        content: Text(
          'Are you sure you want to delete "${vote.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _votesService.deleteVote(vote.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vote deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete vote: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Build the voting bar for exec users on active votes
  Widget _buildExecVotingBar(VotingForm vote, bool canVote) {
    const grassrootsGreen = Color(0xFF43A047);

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: canVote
            ? grassrootsGreen.withOpacity(0.15)
            : Colors.grey.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border.all(
          color: canVote
              ? grassrootsGreen.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            canVote ? Icons.how_to_vote : Icons.check_circle,
            color: canVote ? grassrootsGreen : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              canVote
                  ? 'You can cast your vote as a committee leader'
                  : 'You have already voted on this',
              style: TextStyle(
                color: canVote ? grassrootsGreen : Colors.grey,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          if (canVote)
            ElevatedButton.icon(
              onPressed: () => _openExecVotingScreen(vote),
              icon: const Icon(Icons.how_to_vote, size: 16),
              label: const Text('Vote Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: grassrootsGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Open the voting screen for exec users
  void _openExecVotingScreen(VotingForm vote) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExecVotingScreen(
          vote: vote,
          memberId: _execMemberId,
          onVoteSubmitted: () {
            setState(() {
              _execHasVotedMap[vote.id] = true;
            });
          },
        ),
      ),
    );
  }
}

/// Full-page voting screen for exec users (similar to MemberVotingScreen but with exec_view source)
class ExecVotingScreen extends StatefulWidget {
  final VotingForm vote;
  final String memberId;
  final VoidCallback? onVoteSubmitted;

  const ExecVotingScreen({
    super.key,
    required this.vote,
    required this.memberId,
    this.onVoteSubmitted,
  });

  @override
  State<ExecVotingScreen> createState() => _ExecVotingScreenState();
}

class _ExecVotingScreenState extends State<ExecVotingScreen> {
  final _votesService = VotesService();
  final _analyticsService = FormAnalyticsService();
  final Map<String, dynamic> _answers = {};
  bool _isSubmitting = false;
  bool _hasInteracted = false;
  String? _sessionToken;
  bool _hasTrackedStart = false;

  @override
  void initState() {
    super.initState();
    _trackVoteView();
  }

  Future<void> _trackVoteView() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    _sessionToken = await _analyticsService.trackVoteView(
      widget.vote.id,
      userId,
      memberId: widget.memberId,
    );
  }

  void _trackFirstInteraction() {
    if (!_hasTrackedStart) {
      _hasTrackedStart = true;
      final userId = Supabase.instance.client.auth.currentUser?.id;
      _analyticsService.trackVoteStart(
        widget.vote.id,
        userId,
        memberId: widget.memberId,
        sessionToken: _sessionToken,
      );
    }
  }

  void _trackFieldInteraction(String questionId, String questionType) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    _analyticsService.trackVoteFieldInteraction(
      widget.vote.id,
      questionId,
      questionType,
      userId,
      memberId: widget.memberId,
      sessionToken: _sessionToken,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBackPress,
      child: Scaffold(
        body: Stack(
          children: [
            // Gradient background
            Positioned.fill(
              child: Image.asset(
                'assets/images/Blue-Gradient-Background.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: Container(color: Colors.white.withOpacity(0.18)),
            ),
            // Content
            SafeArea(
              child: Column(
                children: [
                  // Header
                  _buildHeader(),
                  // Questions
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Exec voting indicator
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: _momentumBlue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _momentumBlue.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.admin_panel_settings,
                                  color: _momentumBlue,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Voting as Committee Leader',
                                    style: TextStyle(
                                      color: _momentumBlue,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Description
                          if (widget.vote.description != null &&
                              widget.vote.description!.isNotEmpty)
                            _buildDescription(),

                          // Supporting documents
                          if (widget.vote.supportingDocuments != null &&
                              widget.vote.supportingDocuments!.isNotEmpty)
                            _buildDocuments(),

                          const SizedBox(height: 16),

                          // Questions
                          ...widget.vote.questions.asMap().entries.map((entry) {
                            final index = entry.key;
                            final question = entry.value;
                            return _buildQuestion(question, index);
                          }),

                          const SizedBox(height: 24),

                          // Submit button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitVote,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF43A047),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                disabledBackgroundColor: Colors.grey,
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Text(
                                      'Submit Vote',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
      decoration: const BoxDecoration(color: _unityBlue),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () async {
                  if (await _handleBackPress()) {
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.vote.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _unityBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _stripHtml(widget.vote.description!),
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildDocuments() {
    final documents = widget.vote.supportingDocuments!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _unityBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.attach_file,
                size: 18,
                color: Colors.white.withOpacity(0.9),
              ),
              const SizedBox(width: 8),
              const Text(
                'Supporting Documents',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...documents.map((doc) {
            final name = doc['name'] as String? ?? 'Document';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.insert_drive_file,
                      size: 20,
                      color: _momentumBlue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuestion(Map<String, dynamic> question, int index) {
    final questionId = question['id'] as String? ?? 'q$index';
    final questionText = question['text'] as String? ?? 'Question ${index + 1}';
    final questionType =
        question['question_type'] as String? ?? 'multiple_choice';
    final options = (question['options'] as List<dynamic>?) ?? [];
    final isRequired = question['required'] as bool? ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _unityBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _momentumBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      questionText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (isRequired)
                      Text(
                        'Required',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Answer options based on type
          _buildAnswerInput(questionId, questionType, options),
        ],
      ),
    );
  }

  Widget _buildAnswerInput(
    String questionId,
    String questionType,
    List<dynamic> options,
  ) {
    switch (questionType) {
      case 'multiple_choice':
        return _buildMultipleChoice(questionId, options);
      case 'multiple_select':
        return _buildMultipleSelect(questionId, options);
      case 'yes_no':
        return _buildYesNo(questionId);
      default:
        return _buildMultipleChoice(questionId, options);
    }
  }

  Widget _buildMultipleChoice(String questionId, List<dynamic> options) {
    final currentAnswer = _answers[questionId] as String?;

    return Column(
      children: options.map((opt) {
        final option = opt as Map<String, dynamic>;
        final optionId = option['id'] as String?;
        final optionLabel = option['label'] as String? ?? '';
        final isSelected = currentAnswer == optionId;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () {
              setState(() {
                _answers[questionId] = optionId;
                _hasInteracted = true;
              });
              _trackFirstInteraction();
              _trackFieldInteraction(questionId, 'multiple_choice');
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? _momentumBlue
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? _momentumBlue
                      : Colors.white.withOpacity(0.3),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                        width: 2,
                      ),
                      color: isSelected ? Colors.white : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            size: 14,
                            color: _momentumBlue,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      optionLabel,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMultipleSelect(String questionId, List<dynamic> options) {
    final currentAnswers = (_answers[questionId] as List<String>?) ?? [];

    return Column(
      children: options.map((opt) {
        final option = opt as Map<String, dynamic>;
        final optionId = option['id'] as String? ?? '';
        final optionLabel = option['label'] as String? ?? '';
        final isSelected = currentAnswers.contains(optionId);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () {
              setState(() {
                final newAnswers = List<String>.from(currentAnswers);
                if (isSelected) {
                  newAnswers.remove(optionId);
                } else {
                  newAnswers.add(optionId);
                }
                _answers[questionId] = newAnswers;
                _hasInteracted = true;
              });
              _trackFirstInteraction();
              _trackFieldInteraction(questionId, 'multiple_select');
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? _momentumBlue
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? _momentumBlue
                      : Colors.white.withOpacity(0.3),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                        width: 2,
                      ),
                      color: isSelected ? Colors.white : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            size: 14,
                            color: _momentumBlue,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      optionLabel,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildYesNo(String questionId) {
    return _buildMultipleChoice(questionId, [
      {'id': 'yes', 'label': 'Yes'},
      {'id': 'no', 'label': 'No'},
    ]);
  }

  Future<bool> _handleBackPress() async {
    if (!_hasInteracted) return true;

    // Check if any required questions are answered
    bool hasAnsweredRequired = false;
    for (final question in widget.vote.questions) {
      final questionId = question['id'] as String?;
      final isRequired = question['required'] as bool? ?? true;
      if (isRequired && questionId != null && _answers[questionId] != null) {
        hasAnsweredRequired = true;
        break;
      }
    }

    if (!hasAnsweredRequired) return true;

    // Show confirmation dialog
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _unityBlue,
        title: const Text(
          'Leave without submitting?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Your vote is not counted until it is submitted. Are you sure you want to leave?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Track abandonment
              final userId = Supabase.instance.client.auth.currentUser?.id;
              _analyticsService.trackVoteAbandonment(
                widget.vote.id,
                userId,
                _answers,
                memberId: widget.memberId,
                sessionToken: _sessionToken,
              );
              Navigator.pop(context, true);
            },
            child: const Text('Leave'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, false);
              _submitVote();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF43A047),
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit Vote'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _submitVote() async {
    // Validate required questions
    for (final question in widget.vote.questions) {
      final questionId = question['id'] as String?;
      final isRequired = question['required'] as bool? ?? true;

      if (isRequired && questionId != null) {
        final answer = _answers[questionId];
        if (answer == null ||
            (answer is String && answer.isEmpty) ||
            (answer is List && answer.isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please answer: ${question['text']}'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }

    setState(() => _isSubmitting = true);

    try {
      await _votesService.castVote(
        widget.vote.id,
        widget.memberId,
        _answers,
        sessionToken: _sessionToken,
        voterSource: 'exec_view',
      );

      widget.onVoteSubmitted?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your vote has been submitted!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting vote: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
