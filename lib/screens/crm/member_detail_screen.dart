import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bluebubbles/app/layouts/chat_creator/chat_creator.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/services/services.dart';

/// Detailed view of a single member
class MemberDetailScreen extends StatefulWidget {
  final Member member;

  const MemberDetailScreen({
    Key? key,
    required this.member,
  }) : super(key: key);

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  final MemberRepository _memberRepo = MemberRepository();
  final CRMSupabaseService _supabaseService = CRMSupabaseService();
  late Member _member;
  final TextEditingController _notesController = TextEditingController();
  bool _editingNotes = false;

  bool get _crmReady => _supabaseService.isInitialized;

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    _notesController.text = _member.notes ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    if (!_crmReady) return;

    try {
      await _memberRepo.updateNotes(_member.id, _notesController.text);
      if (!mounted) return;
      setState(() {
        _member = _member.copyWith(notes: _notesController.text);
        _editingNotes = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving notes: $e')),
      );
    }
  }

  Future<void> _toggleOptOut() async {
    if (!_crmReady) return;
    final newOptOutStatus = !_member.optOut;

    try {
      await _memberRepo.updateOptOutStatus(
        _member.id,
        newOptOutStatus,
        reason: newOptOutStatus ? 'Manually opted out' : null,
      );

      if (!mounted) return;
      setState(() {
        _member = _member.copyWith(
          optOut: newOptOutStatus,
          optOutDate: newOptOutStatus ? DateTime.now() : _member.optOutDate,
          optInDate: !newOptOutStatus ? DateTime.now() : _member.optInDate,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newOptOutStatus ? 'Member opted out' : 'Member opted in'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating opt-out status: $e')),
      );
    }
  }

  void _startChat() {
    final address = _member.phoneE164 ?? _member.phone;
    if (address == null || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available')),
      );
      return;
    }

    ns.pushAndRemoveUntil(
      context,
      ChatCreator(
        initialSelected: [
          SelectedContact(
            displayName: _member.name,
            address: address,
          ),
        ],
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_member.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.message),
            onPressed: _member.canContact ? _startChat : null,
            tooltip: 'Start Chat',
          ),
        ],
      ),
      body: !_crmReady
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'CRM Supabase is not configured. View only mode.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    child: Text(
                      _member.name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _member.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: 8),
                if (_member.optOut)
                  const Center(
                    child: Chip(
                      label: Text('OPTED OUT'),
                      backgroundColor: Colors.red,
                      labelStyle: TextStyle(color: Colors.white),
                    ),
                  ),
                const SizedBox(height: 24),
                _buildSection(
                  'Contact Information',
                  [
                    if (_member.phone != null)
                      _buildInfoRow('Phone', _member.phone!,
                          trailing: IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _member.phone!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Phone copied')),
                              );
                            },
                          )),
                    if (_member.email != null)
                      _buildInfoRow('Email', _member.email!,
                          trailing: IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _member.email!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Email copied')),
                              );
                            },
                          )),
                    if (_member.address != null)
                      _buildInfoRow('Address', _member.address!),
                  ],
                ),
                _buildSection(
                  'Political Information',
                  [
                    if (_member.county != null)
                      _buildInfoRow('County', _member.county!),
                    if (_member.congressionalDistrict != null)
                      _buildInfoRow('Congressional District', 'CD-${_member.congressionalDistrict}'),
                    if (_member.committee != null && _member.committee!.isNotEmpty)
                      _buildInfoRow('Committees', _member.committeesString),
                    if (_member.registeredVoter != null)
                      _buildInfoRow('Registered Voter', _member.registeredVoter! ? 'Yes' : 'No'),
                    if (_member.politicalExperience != null)
                      _buildInfoRow('Political Experience', _member.politicalExperience!),
                    if (_member.currentInvolvement != null)
                      _buildInfoRow('Current Involvement', _member.currentInvolvement!),
                  ],
                ),
                _buildSection(
                  'Personal Information',
                  [
                    if (_member.age != null)
                      _buildInfoRow('Age', '${_member.age} years old'),
                    if (_member.preferredPronouns != null)
                      _buildInfoRow('Pronouns', _member.preferredPronouns!),
                    if (_member.genderIdentity != null)
                      _buildInfoRow('Gender Identity', _member.genderIdentity!),
                    if (_member.race != null)
                      _buildInfoRow('Race', _member.race!),
                    if (_member.hispanicLatino != null)
                      _buildInfoRow('Hispanic/Latino', _member.hispanicLatino! ? 'Yes' : 'No'),
                  ],
                ),
                _buildSection(
                  'Notes',
                  [
                    if (!_editingNotes && (_member.notes == null || _member.notes!.isEmpty))
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add notes'),
                        onPressed: () => setState(() => _editingNotes = true),
                      ),
                    if (!_editingNotes && _member.notes != null && _member.notes!.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_member.notes!),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit'),
                            onPressed: () => setState(() => _editingNotes = true),
                          ),
                        ],
                      ),
                    if (_editingNotes)
                      Column(
                        children: [
                          TextField(
                            controller: _notesController,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              hintText: 'Add notes about this member...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  _notesController.text = _member.notes ?? '';
                                  setState(() => _editingNotes = false);
                                },
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _saveNotes,
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
                _buildSection(
                  'Metadata',
                  [
                    if (_member.lastContacted != null)
                      _buildInfoRow('Last Contacted', _formatDate(_member.lastContacted!)),
                    if (_member.introSentAt != null)
                      _buildInfoRow('Intro Sent', _formatDate(_member.introSentAt!)),
                    if (_member.dateJoined != null)
                      _buildInfoRow('Date Joined', _formatDate(_member.dateJoined!)),
                    if (_member.createdAt != null)
                      _buildInfoRow('Added to System', _formatDate(_member.createdAt!)),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: Icon(_member.optOut ? Icons.check_circle : Icons.block),
                  label: Text(_member.optOut ? 'Opt In' : 'Opt Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _member.optOut ? Colors.green : Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _crmReady ? _toggleOptOut : null,
                ),
              ],
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(child: Text(value)),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
