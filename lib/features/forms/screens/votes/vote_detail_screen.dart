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
                        Text('Type: ${vote.votingType}'),
                        Text('Status: ${vote.status}'),
                        if (vote.startDate != null)
                          Text('Start: ${vote.startDate}'),
                        if (vote.endDate != null)
                          Text('End: ${vote.endDate}'),
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
