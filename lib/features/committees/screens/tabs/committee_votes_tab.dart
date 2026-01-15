import 'package:flutter/material.dart';
import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/forms/models/voting_form.dart';
import 'package:bluebubbles/features/forms/services/votes_service.dart';
import 'package:bluebubbles/features/forms/widgets/vote_card.dart';
import 'package:bluebubbles/features/forms/screens/votes/vote_builder_screen.dart';
import 'package:bluebubbles/features/forms/screens/votes/vote_detail_screen.dart';

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

  const CommitteeVotesTab({
    Key? key,
    required this.committee,
    this.onNavigateToEmail,
    this.onNavigateToMessages,
    this.isMemberView = false,
  }) : super(key: key);

  @override
  State<CommitteeVotesTab> createState() => _CommitteeVotesTabState();
}

class _CommitteeVotesTabState extends State<CommitteeVotesTab>
    with AutomaticKeepAliveClientMixin {
  final _votesService = VotesService();
  String _statusFilter = 'all';

  /// Get the committee name used for database operations
  /// Uses meetingsFilterName which includes "Committee" suffix to match DB constraint
  String get _committeeDbName => widget.committee.meetingsFilterName;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
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
                      valueColor: AlwaysStoppedAnimation<Color>(_momentumBlue),
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

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  color: _momentumBlue,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: votes.length,
                    itemBuilder: (context, index) {
                      final vote = votes[index];
                      return VoteCard(
                        vote: vote,
                        onTap: () => _viewVote(vote),
                        // Members cannot edit or delete votes
                        onEdit: widget.isMemberView ? null : () => _editVote(vote),
                        onDelete: widget.isMemberView ? null : () => _confirmDeleteVote(vote),
                      );
                    },
                  ),
                );
              },
            ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _unityBlue.withOpacity(0.08),
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
            color: isSelected ? _unityBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : _unityBlue,
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
                color: _momentumBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.how_to_vote_outlined,
                size: 56,
                color: _momentumBlue.withOpacity(0.5),
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
                color: _unityBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isMemberView
                  ? 'Check back later for committee votes'
                  : 'Create a vote for ${widget.committee.displayName} members',
              style: TextStyle(
                fontSize: 14,
                color: _unityBlue.withOpacity(0.6),
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
                  backgroundColor: _momentumBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, size: 48, color: Colors.red),
            ),
            const SizedBox(height: 20),
            const Text(
              'Error loading votes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _unityBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                fontSize: 14,
                color: _unityBlue.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _momentumBlue,
                foregroundColor: Colors.white,
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

  void _createNewVote() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoteBuilderScreen(
          committee: _committeeDbName,
        ),
      ),
    );
  }

  void _viewVote(VotingForm vote) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoteDetailScreen(
          voteId: vote.id,
          onSendAsEmail: widget.onNavigateToEmail,
          onSendAsMessage: widget.onNavigateToMessages,
        ),
      ),
    );
  }

  void _editVote(VotingForm vote) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoteBuilderScreen(
          voteId: vote.id,
          committee: _committeeDbName,
        ),
      ),
    );
  }

  void _confirmDeleteVote(VotingForm vote) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vote'),
        content: Text('Are you sure you want to delete "${vote.title}"? This action cannot be undone.'),
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
}
