import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/voting_form.dart';
import '../../services/votes_service.dart';

class VoteBuilderScreen extends StatefulWidget {
  final String? voteId;

  const VoteBuilderScreen({Key? key, this.voteId}) : super(key: key);

  @override
  State<VoteBuilderScreen> createState() => _VoteBuilderScreenState();
}

class _VoteBuilderScreenState extends State<VoteBuilderScreen> {
  final _votesService = VotesService();
  final _uuid = const Uuid();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<VotingOption> _options = [];
  String _votingType = 'single';
  bool _isLoading = false;
  bool _isSaving = false;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    if (widget.voteId != null) {
      _loadVote();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadVote() async {
    setState(() => _isLoading = true);

    try {
      final vote = await _votesService.getVote(widget.voteId!);

      setState(() {
        _titleController.text = vote.title;
        _descriptionController.text = vote.description ?? '';
        _votingType = vote.votingType;
        _options = vote.options;
        _startDate = vote.startDate;
        _endDate = vote.endDate;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.voteId == null ? 'Create Vote' : 'Edit Vote'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveVote,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Vote Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _votingType,
              decoration: const InputDecoration(
                labelText: 'Voting Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'single', child: Text('Single Choice')),
                DropdownMenuItem(value: 'multiple', child: Text('Multiple Choice')),
                DropdownMenuItem(value: 'ranked', child: Text('Ranked Choice')),
              ],
              onChanged: (value) {
                setState(() => _votingType = value!);
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text(
                  'Options',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Option'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_options.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No options yet. Add at least 2 options.',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ..._options.map((option) => _buildOptionCard(option)).toList(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : _saveVote,
                    child: const Text('Save Draft'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveAndPublish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Save & Publish'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(VotingOption option) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.radio_button_checked),
        title: Text(option.label),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _deleteOption(option.id),
        ),
      ),
    );
  }

  void _addOption() {
    showDialog(
      context: context,
      builder: (context) => _AddOptionDialog(
        onAdd: (label) {
          setState(() {
            _options.add(VotingOption(
              id: _uuid.v4(),
              label: label,
            ));
          });
        },
      ),
    );
  }

  void _deleteOption(String optionId) {
    setState(() {
      _options.removeWhere((o) => o.id == optionId);
    });
  }

  Future<void> _saveVote({bool publish = false}) async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a vote title')),
      );
      return;
    }

    if (_options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least 2 options')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.voteId == null) {
        await _votesService.createVote(
          title: _titleController.text,
          description: _descriptionController.text.isEmpty
              ? null
              : _descriptionController.text,
          votingType: _votingType,
          options: _options,
          status: publish ? 'active' : 'draft',
        );
      } else {
        await _votesService.updateVote(
          widget.voteId!,
          title: _titleController.text,
          description: _descriptionController.text.isEmpty
              ? null
              : _descriptionController.text,
          options: _options,
          status: publish ? 'active' : null,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(publish ? 'Vote published!' : 'Vote saved as draft'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveAndPublish() async {
    await _saveVote(publish: true);
  }
}

class _AddOptionDialog extends StatefulWidget {
  final Function(String) onAdd;

  const _AddOptionDialog({required this.onAdd});

  @override
  State<_AddOptionDialog> createState() => _AddOptionDialogState();
}

class _AddOptionDialogState extends State<_AddOptionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Option'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Option Label',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter an option label')),
              );
              return;
            }
            widget.onAdd(_controller.text);
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
