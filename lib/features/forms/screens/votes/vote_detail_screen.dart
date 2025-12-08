import 'package:flutter/material.dart';
import '../../models/voting_form.dart';
import '../../services/votes_service.dart';

class VoteDetailScreen extends StatefulWidget {
  final String voteId;

  const VoteDetailScreen({Key? key, required this.voteId}) : super(key: key);

  @override
  State<VoteDetailScreen> createState() => _VoteDetailScreenState();
}

class _VoteDetailScreenState extends State<VoteDetailScreen> {
  final _votesService = VotesService();

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vote Details'),
      ),
      body: FutureBuilder<VotingForm>(
        future: _votesService.getVote(widget.voteId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final vote = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vote.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (vote.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    vote.description!,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Options',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...vote.options.map((option) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.radio_button_unchecked),
                    title: Text(option.label),
                    trailing: vote.status == 'active'
                        ? Text(
                            '${option.votes} votes',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                )),
                const SizedBox(height: 24),

                // Voting status banner
                if (vote.notStarted)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, color: Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Voting starts ${_formatDate(vote.votingStartsAt!)}',
                            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (vote.isVotingActive)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      border: Border.all(color: Colors.green),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.how_to_vote, color: Colors.green),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            vote.votingEndsAt != null
                              ? 'Voting open until ${_formatDate(vote.votingEndsAt!)}'
                              : 'Voting is now open',
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (vote.hasEnded)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_busy, color: Colors.grey),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Voting has ended',
                            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Status: ${vote.status}'),
                        Text('Options: ${vote.optionCount}'),
                        if (vote.votingStartsAt != null)
                          Text('Start: ${_formatDate(vote.votingStartsAt!)}'),
                        if (vote.votingEndsAt != null)
                          Text('End: ${_formatDate(vote.votingEndsAt!)}'),
                        if (vote.resultsPublic)
                          const Text('Results: Public')
                        else
                          const Text('Results: Private'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
