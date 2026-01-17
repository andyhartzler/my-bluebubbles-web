import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/features/forms/models/voting_form.dart';
import 'package:bluebubbles/features/forms/models/vote_analytics.dart';
import 'package:bluebubbles/features/forms/services/votes_service.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _grassrootsGreen = Color(0xFF43A047);

// Gradient chart colors
const List<Color> _chartGradientColors = [
  Color(0xFF32A6DE), // Momentum Blue
  Color(0xFF2B4B8C), // Royal Blue
  Color(0xFF10B981), // Emerald
  Color(0xFFF59E0B), // Amber
  Color(0xFF6A1B9A), // Purple
  Color(0xFFE63946), // Action Red
  Color(0xFF14B8A6), // Teal
  Color(0xFF3B82F6), // Blue
];

/// Member view for votes - simplified single page with open/closed sections
class MemberVotesView extends StatefulWidget {
  final String committee;
  final String? memberId;

  const MemberVotesView({
    super.key,
    required this.committee,
    this.memberId,
  });

  @override
  State<MemberVotesView> createState() => _MemberVotesViewState();
}

class _MemberVotesViewState extends State<MemberVotesView> {
  final _votesService = VotesService();
  List<VotingForm> _openVotes = [];
  List<VotingForm> _closedVotes = [];
  Map<String, bool> _hasVotedMap = {};
  bool _isLoading = true;
  String? _error;

  /// Get the member ID - from widget or current authenticated user
  String get _memberId =>
      widget.memberId ??
      Supabase.instance.client.auth.currentUser?.id ??
      '';

  // Track expanded state for closed vote dropdowns
  final Map<String, bool> _expandedVotes = {};

  @override
  void initState() {
    super.initState();
    _loadVotes();
  }

  Future<void> _loadVotes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get all active and closed votes for this committee
      final activeStream = _votesService.watchVotesForCommittee(widget.committee, 'active');
      final closedStream = _votesService.watchVotesForCommittee(widget.committee, 'closed');

      // Listen to streams and update state
      activeStream.listen((votes) async {
        final openVotes = <VotingForm>[];
        for (final vote in votes) {
          if (vote.isVotingActive) {
            openVotes.add(vote);
            // Check if member has voted
            final hasVoted = await _votesService.hasVoted(_memberId, vote.id);
            _hasVotedMap[vote.id] = hasVoted;
          } else if (vote.hasEnded) {
            // Active status but ended - treat as closed
            if (!_closedVotes.any((v) => v.id == vote.id)) {
              _closedVotes.add(vote);
            }
          }
        }
        if (mounted) {
          setState(() {
            _openVotes = openVotes;
            _isLoading = false;
          });
        }
      });

      closedStream.listen((votes) {
        if (mounted) {
          setState(() {
            _closedVotes = votes;
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
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
        _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_momentumBlue),
                ),
              )
            : _error != null
                ? _buildErrorState()
                : RefreshIndicator(
                    onRefresh: _loadVotes,
                    color: _momentumBlue,
                    child: _buildContent(),
                  ),
      ],
    );
  }

  Widget _buildContent() {
    final hasOpenVotes = _openVotes.isNotEmpty;
    final hasClosedVotes = _closedVotes.isNotEmpty;

    if (!hasOpenVotes && !hasClosedVotes) {
      return _buildEmptyState();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Open Votes Section
        if (hasOpenVotes) ...[
          _buildSectionHeader('Open Votes', Icons.how_to_vote, _grassrootsGreen),
          const SizedBox(height: 12),
          ..._openVotes.map((vote) => _buildOpenVoteCard(vote)),
          const SizedBox(height: 24),
        ],

        // Closed Votes Section
        if (hasClosedVotes) ...[
          _buildSectionHeader('Closed Votes', Icons.lock, Colors.grey),
          const SizedBox(height: 12),
          ..._closedVotes.map((vote) => _buildClosedVoteCard(vote)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildOpenVoteCard(VotingForm vote) {
    final hasVoted = _hasVotedMap[vote.id] ?? false;
    final dateFormat = DateFormat('MMM d, y');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      color: _unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: hasVoted ? null : () => _openVotingScreen(vote),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      vote.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: hasVoted ? Colors.grey : _grassrootsGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      hasVoted ? 'VOTED' : 'OPEN',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (vote.description != null && vote.description!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  _stripHtml(vote.description!),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (vote.votingEndsAt != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.white.withOpacity(0.7)),
                    const SizedBox(width: 6),
                    Text(
                      'Ends: ${dateFormat.format(vote.votingEndsAt!)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ],
              if (!hasVoted) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openVotingScreen(vote),
                    icon: const Icon(Icons.how_to_vote, size: 18),
                    label: const Text('Cast Your Vote'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _grassrootsGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClosedVoteCard(VotingForm vote) {
    final isExpanded = _expandedVotes[vote.id] ?? false;
    final dateFormat = DateFormat('MMM d, y');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: _unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Header (always visible)
          InkWell(
            onTap: () {
              setState(() {
                _expandedVotes[vote.id] = !isExpanded;
              });
            },
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom: isExpanded ? Radius.zero : const Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vote.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (vote.description != null && vote.description!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            _stripHtml(vote.description!),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (vote.votingEndsAt != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Closed: ${dateFormat.format(vote.votingEndsAt!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'CLOSED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ),

          // Expanded content (results)
          if (isExpanded) _buildVoteResults(vote),
        ],
      ),
    );
  }

  Widget _buildVoteResults(VotingForm vote) {
    return FutureBuilder<VoteResultsSummary>(
      future: _votesService.getVoteResultsSummary(vote.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_momentumBlue),
                strokeWidth: 2,
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Unable to load results',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          );
        }

        final summary = snapshot.data!;

        // Filter out short_answer and long_answer questions
        final displayableQuestions = summary.questionResults
            .where((q) => q.questionType != 'short_answer' && q.questionType != 'long_answer')
            .toList();

        if (displayableQuestions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No results to display',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Supporting documents
              if (vote.supportingDocuments != null && vote.supportingDocuments!.isNotEmpty)
                _buildSupportingDocuments(vote.supportingDocuments!),

              // Question results
              ...displayableQuestions.asMap().entries.map((entry) {
                final index = entry.key;
                final question = entry.value;
                return _buildQuestionResult(question, index);
              }),

              // Participation stats
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Total Votes', '${summary.totalVotes}'),
                    _buildStatItem('Participation', '${summary.participationRate.toStringAsFixed(0)}%'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuestionResult(QuestionResultData question, int colorIndex) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question text
          Text(
            question.question,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          // Results chart and breakdown
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pie chart
              SizedBox(
                width: 120,
                height: 120,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 25,
                    sections: question.options.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final option = entry.value;
                      final color = _chartGradientColors[idx % _chartGradientColors.length];

                      return PieChartSectionData(
                        value: option.count.toDouble(),
                        title: option.percentage >= 5 ? '${option.percentage.toStringAsFixed(0)}%' : '',
                        color: color,
                        radius: 35,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Legend and percentages
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: question.options.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final option = entry.value;
                    final color = _chartGradientColors[idx % _chartGradientColors.length];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              option.label,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${option.percentage.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSupportingDocuments(List<Map<String, dynamic>> documents) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_file, size: 16, color: Colors.white.withOpacity(0.7)),
              const SizedBox(width: 6),
              Text(
                'Supporting Documents',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: documents.map((doc) {
              final name = doc['name'] as String? ?? 'Document';
              final url = doc['url'] as String?;

              return InkWell(
                onTap: url != null ? () => _openDocument(url) : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _momentumBlue.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getDocIcon(name),
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        name.length > 20 ? '${name.substring(0, 17)}...' : name,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  IconData _getDocIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _openDocument(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openVotingScreen(VotingForm vote) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemberVotingScreen(
          vote: vote,
          memberId: _memberId,
          onVoteSubmitted: () {
            setState(() {
              _hasVotedMap[vote.id] = true;
            });
          },
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
            const Text(
              'No votes available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for committee votes',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
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
              child: const Icon(Icons.error_outline, size: 48, color: Colors.white),
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
              _error ?? 'An unknown error occurred',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadVotes,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _unityBlue,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

/// Full-page voting screen for casting a vote
class MemberVotingScreen extends StatefulWidget {
  final VotingForm vote;
  final String memberId;
  final VoidCallback? onVoteSubmitted;

  const MemberVotingScreen({
    super.key,
    required this.vote,
    required this.memberId,
    this.onVoteSubmitted,
  });

  @override
  State<MemberVotingScreen> createState() => _MemberVotingScreenState();
}

class _MemberVotingScreenState extends State<MemberVotingScreen> {
  final _votesService = VotesService();
  final Map<String, dynamic> _answers = {};
  bool _isSubmitting = false;
  bool _hasInteracted = false;

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
                                backgroundColor: _grassrootsGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
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
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
      decoration: BoxDecoration(
        color: _unityBlue,
      ),
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
              Icon(Icons.attach_file, size: 18, color: Colors.white.withOpacity(0.9)),
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
            final url = doc['url'] as String?;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: url != null ? () => _openDocument(url) : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getDocIcon(name),
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
                      Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ],
                  ),
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
    final questionType = question['question_type'] as String? ?? 'multiple_choice';
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
          _buildAnswerInput(questionId, questionType, options, question),
        ],
      ),
    );
  }

  Widget _buildAnswerInput(
    String questionId,
    String questionType,
    List<dynamic> options,
    Map<String, dynamic> question,
  ) {
    switch (questionType) {
      case 'multiple_choice':
        return _buildMultipleChoice(questionId, options);
      case 'multiple_select':
        return _buildMultipleSelect(questionId, options);
      case 'yes_no':
        return _buildYesNo(questionId);
      case 'rating_scale':
        return _buildRatingScale(questionId, question);
      case 'short_answer':
        return _buildShortAnswer(questionId);
      case 'ranked_choice':
        return _buildRankedChoice(questionId, options);
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
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected ? _momentumBlue : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? _momentumBlue : Colors.white.withOpacity(0.3),
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
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                        width: 2,
                      ),
                      color: isSelected ? Colors.white : Colors.transparent,
                    ),
                    child: isSelected
                        ? Icon(Icons.check, size: 14, color: _momentumBlue)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      optionLabel,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected ? _momentumBlue : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? _momentumBlue : Colors.white.withOpacity(0.3),
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
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                        width: 2,
                      ),
                      color: isSelected ? Colors.white : Colors.transparent,
                    ),
                    child: isSelected
                        ? Icon(Icons.check, size: 14, color: _momentumBlue)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      optionLabel,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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

  Widget _buildRatingScale(String questionId, Map<String, dynamic> question) {
    final minValue = question['min_value'] as int? ?? 1;
    final maxValue = question['max_value'] as int? ?? 5;
    final currentValue = _answers[questionId] as int? ?? minValue;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _momentumBlue,
            inactiveTrackColor: Colors.white.withOpacity(0.3),
            thumbColor: _momentumBlue,
            overlayColor: _momentumBlue.withOpacity(0.2),
            valueIndicatorColor: _momentumBlue,
            valueIndicatorTextStyle: const TextStyle(color: Colors.white),
          ),
          child: Slider(
            value: currentValue.toDouble(),
            min: minValue.toDouble(),
            max: maxValue.toDouble(),
            divisions: maxValue - minValue,
            label: currentValue.toString(),
            onChanged: (value) {
              setState(() {
                _answers[questionId] = value.toInt();
                _hasInteracted = true;
              });
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$minValue',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            Text(
              'Selected: $currentValue',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$maxValue',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShortAnswer(String questionId) {
    return TextField(
      onChanged: (value) {
        setState(() {
          _answers[questionId] = value;
          _hasInteracted = true;
        });
      },
      maxLines: 4,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Enter your response...',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _momentumBlue, width: 2),
        ),
      ),
    );
  }

  Widget _buildRankedChoice(String questionId, List<dynamic> options) {
    final currentRanking = (_answers[questionId] as List<String>?) ??
        options.map((o) => (o as Map<String, dynamic>)['id'] as String? ?? '').toList();

    // Create option lookup
    final optionLabels = <String, String>{};
    for (final opt in options) {
      final option = opt as Map<String, dynamic>;
      optionLabels[option['id'] as String? ?? ''] = option['label'] as String? ?? '';
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: currentRanking.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = currentRanking.removeAt(oldIndex);
          currentRanking.insert(newIndex, item);
          _answers[questionId] = currentRanking;
          _hasInteracted = true;
        });
      },
      itemBuilder: (context, index) {
        final optionId = currentRanking[index];
        final label = optionLabels[optionId] ?? optionId;

        return Container(
          key: ValueKey(optionId),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _momentumBlue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(
                Icons.drag_handle,
                color: Colors.white.withOpacity(0.5),
              ),
            ],
          ),
        );
      },
    );
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
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, false);
              _submitVote();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _grassrootsGreen,
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

  IconData _getDocIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _openDocument(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
