import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/voting_form.dart';
import '../../services/votes_service.dart';
import '../../widgets/results/vote_results_chart.dart';

class VoteDetailScreen extends StatefulWidget {
  final String voteId;

  const VoteDetailScreen({Key? key, required this.voteId}) : super(key: key);

  @override
  State<VoteDetailScreen> createState() => _VoteDetailScreenState();
}

class _VoteDetailScreenState extends State<VoteDetailScreen>
    with SingleTickerProviderStateMixin {
  final _votesService = VotesService();
  late TabController _tabController;
  VotingForm? _vote;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      final vote = await _votesService.getVote(widget.voteId);
      setState(() {
        _vote = vote;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_vote?.title ?? 'Vote Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVote,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'share':
                  _shareVote();
                  break;
                case 'copy_link':
                  _copyVoteLink();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 12),
                    Text('Share'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy_link',
                child: Row(
                  children: [
                    Icon(Icons.link),
                    SizedBox(width: 12),
                    Text('Copy Link'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Results', icon: Icon(Icons.bar_chart)),
            Tab(text: 'Details', icon: Icon(Icons.info_outline)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState(theme, colorScheme)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildResultsTab(theme, colorScheme),
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

            // Results visualization
            if (vote.resultsPublic ||
                vote.hasEnded ||
                vote.status == 'active') ...[
              VoteResultsChart(vote: vote),
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
              Text(
                vote.description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildVotingStatusBanner(theme, colorScheme, vote),
          ],
        ),
      ),
    );
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Options list
          Card(
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
                      Icon(Icons.list_alt, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Voting Options',
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
                          '${vote.options.length} options',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ...vote.options.asMap().entries.map((entry) {
                  final index = entry.key;
                  final option = entry.value;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      option.label,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: option.description != null
                        ? Text(option.description!)
                        : null,
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

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

  void _shareVote() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share feature coming soon')),
    );
  }

  void _copyVoteLink() {
    // TODO: Copy actual vote link
    Clipboard.setData(ClipboardData(text: 'Vote ID: ${_vote?.id}'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vote ID copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
