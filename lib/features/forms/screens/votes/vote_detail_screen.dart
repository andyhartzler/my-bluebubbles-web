import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/features/committees/services/pending_share_content.dart';
import '../../models/voting_form.dart';
import '../../models/vote_analytics.dart';
import '../../services/votes_service.dart';
import '../../widgets/results/vote_results_chart.dart';
import '../../widgets/results/participation_card.dart';
import '../../widgets/analytics/vote_analytics_tab.dart';
import 'vote_builder_screen.dart';

class VoteDetailScreen extends StatefulWidget {
  final String voteId;
  /// Optional callback to navigate to the email tab (when opened from committee context)
  final VoidCallback? onSendAsEmail;
  /// Optional callback to navigate to the messages tab (when opened from committee context)
  final VoidCallback? onSendAsMessage;
  /// If true, this is a member view - hide voter identities and edit functionality
  final bool isMemberView;

  const VoteDetailScreen({
    Key? key,
    required this.voteId,
    this.onSendAsEmail,
    this.onSendAsMessage,
    this.isMemberView = false,
  }) : super(key: key);

  @override
  State<VoteDetailScreen> createState() => _VoteDetailScreenState();
}

class _VoteDetailScreenState extends State<VoteDetailScreen>
    with SingleTickerProviderStateMixin {
  final _votesService = VotesService();
  late TabController _tabController;
  VotingForm? _vote;
  List<Map<String, dynamic>> _voters = [];
  Map<String, Map<String, int>> _calculatedVoteCounts = {}; // question_id -> {option_id -> count}
  VoteResultsSummary? _resultsSummary;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Initialize timezone database for date formatting
    tz_data.initializeTimeZones();
    // Member view has only 2 tabs (no Analytics)
    _tabController = TabController(length: widget.isMemberView ? 2 : 3, vsync: this);
    _loadVote();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadVote() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _votesService.getVote(widget.voteId),
        _votesService.getVoters(widget.voteId),
        _votesService.getVoteResultsSummary(widget.voteId),
      ]);
      final vote = results[0] as VotingForm;
      final voters = results[1] as List<Map<String, dynamic>>;
      final resultsSummary = results[2] as VoteResultsSummary;

      // Calculate vote counts from actual votes
      final voteCounts = _calculateVoteCounts(vote, voters);

      setState(() {
        _vote = vote;
        _voters = voters;
        _calculatedVoteCounts = voteCounts;
        _resultsSummary = resultsSummary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Calculate vote counts from the actual voter data
  Map<String, Map<String, int>> _calculateVoteCounts(
    VotingForm vote,
    List<Map<String, dynamic>> voters,
  ) {
    final counts = <String, Map<String, int>>{};

    // Initialize counts for all questions and options
    for (final question in vote.questions) {
      final questionId = question['id'] as String? ?? 'default';
      counts[questionId] = <String, int>{};

      final options = question['options'] as List<dynamic>? ?? [];
      for (final option in options) {
        final optionId = (option as Map<String, dynamic>)['id'] as String?;
        if (optionId != null) {
          counts[questionId]![optionId] = 0;
        }
      }
    }

    // Count votes from each voter
    for (final voter in voters) {
      final voteData = voter['vote_data'] as Map<String, dynamic>?;
      if (voteData == null) continue;

      for (final entry in voteData.entries) {
        final questionId = entry.key;
        final answer = entry.value;

        if (counts.containsKey(questionId)) {
          if (answer is String) {
            // Single choice answer
            counts[questionId]![answer] = (counts[questionId]![answer] ?? 0) + 1;
          } else if (answer is List) {
            // Multiple select or ranked choice
            for (final item in answer) {
              if (item is String) {
                counts[questionId]![item] = (counts[questionId]![item] ?? 0) + 1;
              }
            }
          }
        }
      }
    }

    return counts;
  }

  /// Get questions with calculated vote counts
  List<Map<String, dynamic>> get _questionsWithVoteCounts {
    if (_vote == null) return [];

    return _vote!.questions.map((question) {
      final questionId = question['id'] as String? ?? 'default';
      final options = question['options'] as List<dynamic>? ?? [];
      final questionCounts = _calculatedVoteCounts[questionId] ?? {};

      // Create new options list with calculated vote counts
      final updatedOptions = options.map((opt) {
        final option = Map<String, dynamic>.from(opt as Map<String, dynamic>);
        final optionId = option['id'] as String?;
        if (optionId != null) {
          option['votes'] = questionCounts[optionId] ?? 0;
        }
        return option;
      }).toList();

      return {
        ...question,
        'options': updatedOptions,
      };
    }).toList();
  }

  String _formatDate(DateTime date) {
    // Convert to Central Time
    final central = tz.getLocation('America/Chicago');
    final centralTime = tz.TZDateTime.from(date.toUtc(), central);

    // Format as M/d/yyyy h:mm a (12-hour format with AM/PM)
    final dateFormat = DateFormat('M/d/yyyy');
    final timeFormat = DateFormat('h:mm a');

    return '${dateFormat.format(centralTime)} ${timeFormat.format(centralTime)}';
  }

  String _formatTimeRemaining(DateTime endDate) {
    final now = DateTime.now();
    final diff = endDate.difference(now);

    if (diff.isNegative) return 'Ended';

    if (diff.inDays > 0) {
      return '${diff.inDays}d ${diff.inHours % 24}h remaining';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m remaining';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m remaining';
    } else {
      return 'Ending soon';
    }
  }

  /// Extract photo URL from member data (handles various formats)
  String? _extractMemberPhotoUrl(Map<String, dynamic>? memberData) {
    if (memberData == null) return null;

    final profilePictures = memberData['profile_pictures'];
    if (profilePictures == null) return null;

    // Handle list of photos
    if (profilePictures is List && profilePictures.isNotEmpty) {
      final firstPhoto = profilePictures.first;
      return _extractPhotoUrl(firstPhoto);
    }

    // Handle single photo entry
    if (profilePictures is Map) {
      return _extractPhotoUrl(profilePictures);
    }

    // Handle string URL directly
    if (profilePictures is String && profilePictures.isNotEmpty) {
      return profilePictures;
    }

    return null;
  }

  /// Helper to extract URL from a photo entry
  String? _extractPhotoUrl(dynamic photo) {
    if (photo == null) return null;

    // If it's already a full URL string, return it
    if (photo is String && photo.isNotEmpty) {
      if (photo.startsWith('http://') || photo.startsWith('https://')) {
        return photo;
      }
      // Construct full URL from relative path
      return _buildPhotoFullUrl(photo);
    }

    if (photo is Map) {
      // Try common URL field names (camelCase and snake_case)
      final url = photo['publicUrl'] ??
                  photo['public_url'] ??
                  photo['url'];
      if (url != null && url.toString().isNotEmpty) {
        final urlStr = url.toString();
        if (urlStr.startsWith('http://') || urlStr.startsWith('https://')) {
          return urlStr;
        }
        return _buildPhotoFullUrl(urlStr);
      }

      // Try to construct URL from path
      final path = photo['path']?.toString();
      if (path != null && path.isNotEmpty) {
        // If path is already a full URL, return it
        if (path.startsWith('http://') || path.startsWith('https://')) {
          return path;
        }
        // Construct storage URL path
        final bucket = photo['bucket']?.toString() ?? 'member-photos';
        final storagePath = path.startsWith('storage/')
            ? path
            : 'storage/v1/object/public/$bucket/$path';
        return _buildPhotoFullUrl(storagePath);
      }
    }

    return null;
  }

  /// Build full URL from relative path using Supabase URL
  String? _buildPhotoFullUrl(String relativePath) {
    final supabaseUrl = CRMConfig.supabaseUrl;
    if (supabaseUrl.isEmpty) return null;

    // Ensure path starts with /
    final normalizedPath = relativePath.startsWith('/')
        ? relativePath
        : '/$relativePath';

    // Remove trailing slash from base URL if present
    final baseUrl = supabaseUrl.endsWith('/')
        ? supabaseUrl.substring(0, supabaseUrl.length - 1)
        : supabaseUrl;

    return '$baseUrl$normalizedPath';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_vote?.title ?? 'Vote Details'),
        actions: [
          if (!widget.isMemberView)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editVote,
              tooltip: 'Edit Vote',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVote,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _editVote();
                  break;
                case 'share':
                  _shareVote();
                  break;
                case 'copy_link':
                  _copyVoteLink();
                  break;
              }
            },
            itemBuilder: (context) => [
              if (!widget.isMemberView)
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 12),
                      Text('Edit Vote'),
                    ],
                  ),
                ),
              if (!widget.isMemberView) const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 12),
                    Text('Share Vote Link'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy_link',
                child: Row(
                  children: [
                    Icon(Icons.link),
                    SizedBox(width: 12),
                    Text('Copy Link to Clipboard'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Results', icon: Icon(Icons.bar_chart)),
            if (!widget.isMemberView) const Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
            const Tab(text: 'Details', icon: Icon(Icons.info_outline)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState(theme, colorScheme)
              : TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildResultsTab(theme, colorScheme),
                    if (!widget.isMemberView) VoteAnalyticsTab(formId: widget.voteId),
                    _buildDetailsTab(theme, colorScheme),
                  ],
                ),
    );
  }

  Widget _buildErrorState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading vote',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadVote,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsTab(ThemeData theme, ColorScheme colorScheme) {
    final vote = _vote!;

    return RefreshIndicator(
      onRefresh: _loadVote,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vote header
            _buildVoteHeader(theme, colorScheme, vote),
            const SizedBox(height: 24),

            // Participation card (if results summary is available)
            if (_resultsSummary != null) ...[
              ParticipationCard(results: _resultsSummary!),
              const SizedBox(height: 24),
            ],

            // Results visualization
            // Show results if: results are public, voting has ended (by date),
            // vote is active (live results), or vote is closed (finished)
            if (vote.resultsPublic ||
                vote.hasEnded ||
                vote.status == 'active' ||
                vote.status == 'closed') ...[
              VoteResultsChart(
                vote: vote,
                calculatedQuestions: _questionsWithVoteCounts,
              ),
              const SizedBox(height: 24),
              // Voters list - hidden for member view (they only see percentages)
              if (!widget.isMemberView)
                _buildVotersList(theme, colorScheme, vote),
            ] else ...[
              _buildResultsHidden(theme, colorScheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVoteHeader(
    ThemeData theme,
    ColorScheme colorScheme,
    VotingForm vote,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    vote.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(theme, vote),
              ],
            ),
            if (vote.description != null && vote.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Html(
                data: vote.description!,
                style: {
                  'body': Style(
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                    fontSize: FontSize(14),
                    color: colorScheme.onSurfaceVariant,
                  ),
                  'a': Style(
                    color: colorScheme.primary,
                    textDecoration: TextDecoration.underline,
                  ),
                },
              ),
            ],
            const SizedBox(height: 16),
            _buildVotingStatusBanner(theme, colorScheme, vote),
            const SizedBox(height: 16),
            _buildShareSection(theme, colorScheme, vote),
          ],
        ),
      ),
    );
  }

  Widget _buildShareSection(
    ThemeData theme,
    ColorScheme colorScheme,
    VotingForm vote,
  ) {
    final shareUrl = _getShareUrl();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Share with Members',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (shareUrl != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      shareUrl,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: _copyVoteLink,
                    tooltip: 'Copy Link',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _shareVote,
              icon: const Icon(Icons.share),
              label: const Text('Share Vote Link'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          // Committee-specific share options
          if (widget.onSendAsEmail != null || widget.onSendAsMessage != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (widget.onSendAsEmail != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _sendAsEmail(vote),
                      icon: const Icon(Icons.email_outlined, size: 18),
                      label: const Text('Send as Email'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                if (widget.onSendAsEmail != null && widget.onSendAsMessage != null)
                  const SizedBox(width: 8),
                if (widget.onSendAsMessage != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _sendAsMessage(vote),
                      icon: const Icon(Icons.message_outlined, size: 18),
                      label: const Text('Send as Message'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _sendAsEmail(VotingForm vote) {
    final shareUrl = _getShareUrl();
    if (shareUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to get vote link')),
      );
      return;
    }

    // Set pending email content
    PendingShareContent().setVoteEmailContent(
      voteTitle: vote.title,
      voteUrl: shareUrl,
      voteDescription: vote.description,
    );

    // Navigate back and trigger callback
    Navigator.pop(context);
    widget.onSendAsEmail?.call();
  }

  void _sendAsMessage(VotingForm vote) {
    final shareUrl = _getShareUrl();
    if (shareUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to get vote link')),
      );
      return;
    }

    // Set pending message content
    PendingShareContent().setVoteMessageContent(
      voteTitle: vote.title,
      voteUrl: shareUrl,
    );

    // Navigate back and trigger callback
    Navigator.pop(context);
    widget.onSendAsMessage?.call();
  }

  Widget _buildStatusChip(ThemeData theme, VotingForm vote) {
    Color color;
    String label;

    if (vote.notStarted) {
      color = Colors.orange;
      label = 'Pending';
    } else if (vote.isVotingActive) {
      color = Colors.green;
      label = 'Active';
    } else if (vote.hasEnded) {
      color = Colors.grey;
      label = 'Ended';
    } else {
      color = Colors.blue;
      label = vote.status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildVotingStatusBanner(
    ThemeData theme,
    ColorScheme colorScheme,
    VotingForm vote,
  ) {
    if (vote.notStarted && vote.votingStartsAt != null) {
      return _buildBanner(
        theme,
        Icons.schedule,
        'Voting starts ${_formatDate(vote.votingStartsAt!)}',
        Colors.orange,
      );
    } else if (vote.isVotingActive) {
      final message = vote.votingEndsAt != null
          ? _formatTimeRemaining(vote.votingEndsAt!)
          : 'Voting is open';
      return _buildBanner(
        theme,
        Icons.how_to_vote,
        message,
        Colors.green,
      );
    } else if (vote.hasEnded) {
      return _buildBanner(
        theme,
        Icons.check_circle,
        'Voting has ended',
        Colors.grey,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildBanner(
    ThemeData theme,
    IconData icon,
    String message,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVotersList(
    ThemeData theme,
    ColorScheme colorScheme,
    VotingForm vote,
  ) {
    if (_voters.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.people, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Individual Votes',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_voters.length} voters',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ..._voters.map((voterData) => _buildVoterTile(
                theme,
                colorScheme,
                voterData,
                vote,
              )),
        ],
      ),
    );
  }

  Widget _buildVoterTile(
    ThemeData theme,
    ColorScheme colorScheme,
    Map<String, dynamic> voterData,
    VotingForm vote,
  ) {
    final memberData = voterData['members'] as Map<String, dynamic>?;
    final voteData = voterData['vote_data'] as Map<String, dynamic>?;
    final createdAt = voterData['created_at'] != null
        ? DateTime.parse(voterData['created_at'].toString())
        : null;

    // Get member info
    final memberName = memberData?['name']?.toString() ?? 'Unknown Voter';
    final memberCity = memberData?['city']?.toString();
    final memberState = memberData?['state']?.toString();

    // Get photo URL from profile_pictures (using robust extraction like FormSubmission)
    final memberPhotoUrl = _extractMemberPhotoUrl(memberData);

    // Build location string
    String? location;
    if (memberCity != null && memberState != null) {
      location = '$memberCity, $memberState';
    } else if (memberCity != null) {
      location = memberCity;
    } else if (memberState != null) {
      location = memberState;
    }

    // Get answer summary for display
    final answerSummary = _getVoterAnswerSummary(vote, voteData);

    return ExpansionTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: colorScheme.primaryContainer,
        backgroundImage: memberPhotoUrl != null ? NetworkImage(memberPhotoUrl) : null,
        child: memberPhotoUrl == null
            ? Text(
                memberName.isNotEmpty ? memberName[0].toUpperCase() : '?',
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Text(
        memberName,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (location != null)
            Text(
              location,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          if (createdAt != null)
            Text(
              'Voted ${_formatDate(createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (answerSummary.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxWidth: 120),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                answerSummary,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more),
        ],
      ),
      children: [
        _buildVoterAnswersDetail(theme, colorScheme, vote, voteData),
        // View Profile button
        if (memberData != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: () => _viewMemberProfile(memberData),
              icon: const Icon(Icons.person, size: 18),
              label: const Text('View Profile'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ),
      ],
    );
  }

  String _getVoterAnswerSummary(VotingForm vote, Map<String, dynamic>? voteData) {
    if (voteData == null || voteData.isEmpty) return 'No response';

    final questions = vote.questions;
    if (questions.isEmpty) return 'Voted';

    // For single question, show the answer label
    if (questions.length == 1) {
      final question = questions.first;
      final questionId = question['id'] as String?;
      final options = (question['options'] as List<dynamic>?) ?? [];

      if (questionId != null && voteData.containsKey(questionId)) {
        final answer = voteData[questionId];
        // Look up the option label
        if (answer is String) {
          for (final opt in options) {
            if (opt is Map<String, dynamic> && opt['id'] == answer) {
              return opt['label']?.toString() ?? answer;
            }
          }
          return answer;
        }
        if (answer is List && answer.isNotEmpty) {
          // Get first answer's label
          final firstAns = answer.first;
          for (final opt in options) {
            if (opt is Map<String, dynamic> && opt['id'] == firstAns) {
              return opt['label']?.toString() ?? firstAns.toString();
            }
          }
          return firstAns.toString();
        }
        return answer?.toString() ?? 'Voted';
      }
      // Fallback to first value
      final firstValue = voteData.values.first;
      if (firstValue is String) {
        for (final opt in options) {
          if (opt is Map<String, dynamic> && opt['id'] == firstValue) {
            return opt['label']?.toString() ?? firstValue;
          }
        }
      }
      return firstValue?.toString() ?? 'Voted';
    }

    // For multiple questions, show count
    return '${questions.length} answers';
  }

  Widget _buildVoterAnswersDetail(
    ThemeData theme,
    ColorScheme colorScheme,
    VotingForm vote,
    Map<String, dynamic>? voteData,
  ) {
    if (voteData == null || voteData.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No responses recorded',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final questions = vote.questions;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: questions.asMap().entries.map((entry) {
          final index = entry.key;
          final question = entry.value;
          final questionId = question['id'] as String? ?? 'question_$index';
          final questionText = question['text'] as String? ?? 'Question ${index + 1}';
          final questionType = question['question_type'] as String? ?? 'multiple_choice';
          final options = (question['options'] as List<dynamic>?) ?? [];

          // Get the answer for this question
          final answer = voteData[questionId] ?? voteData['question_$index'];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Q${index + 1}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        questionText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildAnswerDisplay(theme, colorScheme, questionType, options, answer),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAnswerDisplay(
    ThemeData theme,
    ColorScheme colorScheme,
    String questionType,
    List<dynamic> options,
    dynamic answer,
  ) {
    if (answer == null) {
      return Text(
        'No answer',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    switch (questionType) {
      case 'multiple_choice':
      case 'yes_no':
        // Find the option label if answer is an ID
        String displayAnswer = answer.toString();
        for (final opt in options) {
          if ((opt as Map<String, dynamic>)['id'] == answer) {
            displayAnswer = opt['label'] as String? ?? answer.toString();
            break;
          }
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            displayAnswer,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        );

      case 'multiple_select':
        final selections = answer is List ? answer : [answer];
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: selections.map((sel) {
            String displayLabel = sel.toString();
            for (final opt in options) {
              if ((opt as Map<String, dynamic>)['id'] == sel) {
                displayLabel = opt['label'] as String? ?? sel.toString();
                break;
              }
            }
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                displayLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
            );
          }).toList(),
        );

      case 'ranked_choice':
        final rankings = answer is List ? answer : [answer];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rankings.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final item = entry.value;
            String displayLabel = item.toString();
            for (final opt in options) {
              if ((opt as Map<String, dynamic>)['id'] == item) {
                displayLabel = opt['label'] as String? ?? item.toString();
                break;
              }
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$rank',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(displayLabel, style: theme.textTheme.bodyMedium),
                ],
              ),
            );
          }).toList(),
        );

      case 'rating_scale':
        final rating = int.tryParse(answer.toString()) ?? 0;
        return Row(
          children: List.generate(5, (index) {
            return Icon(
              index < rating ? Icons.star : Icons.star_border,
              color: Colors.amber,
              size: 24,
            );
          }),
        );

      case 'short_answer':
      default:
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Text(
            answer.toString(),
            style: theme.textTheme.bodyMedium,
          ),
        );
    }
  }

  void _viewMemberProfile(Map<String, dynamic> memberData) {
    try {
      final member = Member.fromJson(memberData);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MemberDetailScreen(member: member),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load member profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editVote() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VoteBuilderScreen(voteId: widget.voteId),
      ),
    ).then((_) {
      // Reload the vote when returning from edit screen
      _loadVote();
    });
  }

  Widget _buildResultsHidden(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.visibility_off_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Results Hidden',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Results will be visible after voting ends',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab(ThemeData theme, ColorScheme colorScheme) {
    final vote = _vote!;
    final questions = vote.questions;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Questions list
          ...questions.asMap().entries.map((entry) {
            final index = entry.key;
            final question = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildQuestionCard(theme, colorScheme, question, index),
            );
          }),

          // Schedule card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Schedule',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    theme,
                    'Start',
                    vote.votingStartsAt != null
                        ? _formatDate(vote.votingStartsAt!)
                        : 'Not set',
                    Icons.play_arrow,
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    theme,
                    'End',
                    vote.votingEndsAt != null
                        ? _formatDate(vote.votingEndsAt!)
                        : 'Not set',
                    Icons.stop,
                    Colors.red,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Settings card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.settings_outlined, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Settings',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSettingRow(
                    theme,
                    'Results Visibility',
                    vote.resultsPublic ? 'Public' : 'Private',
                    vote.resultsPublic ? Icons.visibility : Icons.visibility_off,
                  ),
                  const SizedBox(height: 12),
                  _buildSettingRow(
                    theme,
                    'One Vote Per User',
                    vote.oneSubmissionPerUser ? 'Yes' : 'No',
                    vote.oneSubmissionPerUser
                        ? Icons.person
                        : Icons.people,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Metadata card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Information',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildMetadataRow(theme, 'Vote ID', vote.id),
                  const SizedBox(height: 8),
                  _buildMetadataRow(
                    theme,
                    'Created',
                    _formatDate(vote.createdAt),
                  ),
                  const SizedBox(height: 8),
                  _buildMetadataRow(
                    theme,
                    'Last Updated',
                    _formatDate(vote.updatedAt),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(
    ThemeData theme,
    ColorScheme colorScheme,
    Map<String, dynamic> question,
    int questionIndex,
  ) {
    final questionText = question['text'] as String? ?? 'Question ${questionIndex + 1}';
    final questionType = question['question_type'] as String? ?? 'multiple_choice';
    final options = (question['options'] as List<dynamic>?) ?? [];
    final required = question['required'] as bool? ?? false;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Q${questionIndex + 1}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    questionText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildQuestionTypeChip(theme, colorScheme, questionType),
              ],
            ),
          ),
          if (required)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Required',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (options.isNotEmpty) ...[
            const Divider(height: 1),
            ...options.asMap().entries.map((entry) {
              final optIndex = entry.key;
              final option = entry.value as Map<String, dynamic>;
              final label = option['label'] as String? ?? 'Option';
              final description = option['description'] as String?;

              return ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    '${optIndex + 1}',
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                title: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: description != null && description.isNotEmpty
                    ? Text(description)
                    : null,
              );
            }),
          ] else if (questionType == 'short_answer') ...[
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.text_fields, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    'Free text response',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (questionType == 'yes_no') ...[
            const Divider(height: 1),
            ListTile(
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.green.withOpacity(0.2),
                child: const Icon(Icons.check, color: Colors.green, size: 16),
              ),
              title: const Text('Yes', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
            ListTile(
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.red.withOpacity(0.2),
                child: const Icon(Icons.close, color: Colors.red, size: 16),
              ),
              title: const Text('No', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionTypeChip(
    ThemeData theme,
    ColorScheme colorScheme,
    String questionType,
  ) {
    IconData icon;
    String label;
    Color color;

    switch (questionType) {
      case 'multiple_choice':
        icon = Icons.radio_button_checked;
        label = 'Single Choice';
        color = Colors.blue;
        break;
      case 'multiple_select':
        icon = Icons.check_box;
        label = 'Multi-Select';
        color = Colors.purple;
        break;
      case 'ranked_choice':
        icon = Icons.format_list_numbered;
        label = 'Ranked';
        color = Colors.orange;
        break;
      case 'yes_no':
        icon = Icons.thumbs_up_down;
        label = 'Yes/No';
        color = Colors.green;
        break;
      case 'rating_scale':
        icon = Icons.star;
        label = 'Rating';
        color = Colors.amber;
        break;
      case 'short_answer':
        icon = Icons.short_text;
        label = 'Text';
        color = Colors.teal;
        break;
      default:
        icon = Icons.help_outline;
        label = questionType;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingRow(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
  ) {
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataRow(ThemeData theme, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              fontFamily: label == 'Vote ID' ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }

  String? _getShareUrl() {
    final vote = _vote;
    if (vote == null) return null;

    // Use the slug if available, otherwise fall back to ID
    final identifier = vote.slug ?? vote.id;
    return 'https://forms.moyoungdemocrats.org/vote/$identifier';
  }

  void _shareVote() {
    if (_vote == null) return;

    final slug = _vote!.slug;
    if (slug == null || slug.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This vote does not have a shareable link. Please save the vote first.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _showShareOptions();
  }

  void _copyVoteLink() {
    final shareUrl = _getShareUrl();
    if (shareUrl == null) return;

    Clipboard.setData(ClipboardData(text: shareUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Link copied to clipboard!'),
                  Text(
                    shareUrl,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showShareOptions() {
    final vote = _vote;
    if (vote == null) return;

    final shareUrl = _getShareUrl();
    if (shareUrl == null) return;

    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Share Vote Link',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Members can verify their membership and vote at this link:',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            // URL display with copy button
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      shareUrl,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: shareUrl));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied!')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Share buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: shareUrl));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied!')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Link'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openShareSheet();
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openShareSheet() {
    final vote = _vote;
    if (vote == null) return;

    final shareUrl = _getShareUrl();
    if (shareUrl == null) return;

    final description = vote.description;
    final shareText = '''
Vote Now: ${vote.title}

${description != null && description.isNotEmpty ? '$description\n\n' : ''}Cast your vote here: $shareUrl
''';

    Share.share(shareText, subject: 'Vote: ${vote.title}');
  }
}
