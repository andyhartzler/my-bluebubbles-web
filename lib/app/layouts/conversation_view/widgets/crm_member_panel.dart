import 'package:flutter/material.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/crm_message_service.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

/// Side panel showing CRM member info in chat view
class CRMMemberPanel extends StatefulWidget {
  final String phoneNumber; // E.164 format from Handle

  const CRMMemberPanel({
    Key? key,
    required this.phoneNumber,
  }) : super(key: key);

  @override
  State<CRMMemberPanel> createState() => _CRMMemberPanelState();
}

class _CRMMemberPanelState extends State<CRMMemberPanel> {
  final CRMMessageService _messageService = CRMMessageService();
  final CRMSupabaseService _supabaseService = CRMSupabaseService();
  Member? _member;
  bool _loading = true;

  bool get _isReady => _supabaseService.isInitialized && CRMConfig.crmEnabled;

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  String? _districtLabel(String? value) => Member.formatDistrictLabel(value);

  @override
  void initState() {
    super.initState();
    _loadMember();
  }

  Future<void> _loadMember() async {
    if (!_isReady) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);

    try {
      final member = await _messageService.getMemberByPhone(widget.phoneNumber);
      if (!mounted) return;
      setState(() {
        _member = member;
        _loading = false;
      });
    } catch (e) {
      print('❌ Error loading member: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'CRM is not configured. Configure Supabase to view member details.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_member == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No CRM data for this contact'),
        ),
      );
    }

    final districtLabel = _districtLabel(_member!.congressionalDistrict);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Center(
          child: CircleAvatar(
            radius: 40,
            child: Text(_member!.name[0].toUpperCase(), style: const TextStyle(fontSize: 24)),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _member!.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (_member!.optOut)
          const Center(
            child: Chip(
              label: Text('OPTED OUT'),
              backgroundColor: Colors.red,
              labelStyle: TextStyle(color: Colors.white),
            ),
          ),
        const Divider(height: 32),
        if (_hasText(_member!.county))
          _buildInfoTile(Icons.location_on, 'County', _member!.county!.trim()),
        if (districtLabel != null)
          _buildInfoTile(Icons.account_balance, 'District', districtLabel),
        if (_member!.committee != null && _member!.committee!.isNotEmpty)
          _buildInfoTile(Icons.group, 'Committees', _member!.committeesString),
        if (_hasText(_member!.currentChapterMember))
          _buildInfoTile(Icons.groups, 'Chapter Member', _member!.currentChapterMember!.trim()),
        if (_hasText(_member!.chapterName))
          _buildInfoTile(Icons.school, 'Chapter Name', _member!.chapterName!.trim()),
        if (_hasText(_member!.graduationYear))
          _buildInfoTile(Icons.calendar_today, 'Graduation Year', _member!.graduationYear!.trim()),
        if (_member!.age != null)
          _buildInfoTile(Icons.cake, 'Age', '${_member!.age} years old'),
        if (_member!.lastContacted != null)
          _buildInfoTile(Icons.schedule, 'Last Contacted', _formatDate(_member!.lastContacted!)),
        const Divider(height: 32),
        if (_member!.notes != null && _member!.notes!.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notes',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(_member!.notes!),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value),
      dense: true,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${date.month}/${date.day}/${date.year}';
  }
}
