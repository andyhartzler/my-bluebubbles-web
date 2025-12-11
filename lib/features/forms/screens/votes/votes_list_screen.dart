import 'package:flutter/material.dart';
import '../../models/voting_form.dart';
import '../../services/votes_service.dart';
import '../../widgets/vote_card.dart';
import 'vote_builder_screen.dart';
import 'vote_detail_screen.dart';

class VotesListScreen extends StatefulWidget {
  const VotesListScreen({Key? key}) : super(key: key);

  @override
  State<VotesListScreen> createState() => _VotesListScreenState();
}

class _VotesListScreenState extends State<VotesListScreen>
    with AutomaticKeepAliveClientMixin {
  final _votesService = VotesService();
  String _statusFilter = 'all';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Active', 'active'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Draft', 'draft'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Closed', 'closed'),
                ],
              ),
            ),
          ),

          // Votes List
          Expanded(
            child: StreamBuilder<List<VotingForm>>(
              stream: _votesService.watchVotes(_statusFilter),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final votes = snapshot.data ?? [];

                if (votes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.how_to_vote_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No votes yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _createNewVote,
                          icon: const Icon(Icons.add),
                          label: const Text('Create Vote'),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: votes.length,
                    itemBuilder: (context, index) {
                      final vote = votes[index];
                      return VoteCard(
                        vote: vote,
                        onTap: () => _viewVote(vote),
                        onEdit: () => _editVote(vote),
                        onDelete: () => _confirmDeleteVote(vote),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewVote,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _statusFilter = value;
        });
      },
    );
  }

  void _createNewVote() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const VoteBuilderScreen(),
      ),
    );
  }

  void _viewVote(VotingForm vote) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoteDetailScreen(voteId: vote.id),
      ),
    );
  }

  void _editVote(VotingForm vote) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoteBuilderScreen(voteId: vote.id),
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
