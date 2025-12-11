import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/features/committees/screens/tabs/campaign_detail_screen.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/subscriber.dart';

/// Campaigns tab for the Policy & Advocacy committee
/// Displays an overview of all advocacy campaigns with drill-down to detailed views
class CommitteeCampaignsTab extends StatefulWidget {
  const CommitteeCampaignsTab({super.key});

  @override
  State<CommitteeCampaignsTab> createState() => _CommitteeCampaignsTabState();
}

class _CommitteeCampaignsTabState extends State<CommitteeCampaignsTab> {
  final CommitteeRepository _repository = CommitteeRepository();
  List<CampaignData> _campaigns = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Load enriched campaign data
      final data = await _repository.getEnrichedCampaignData();
      if (!mounted) return;

      // Currently we only have one campaign (Hanaway), but this supports multiple
      final campaigns = <CampaignData>[];

      // Build Hanaway campaign data
      final hanaway = _buildCampaignData(
        id: 'hanaway',
        name: 'Hanaway Campaign',
        description: 'Email advocacy campaign supporting the Hanaway initiative. '
            'Participants generate and send personalized emails to their representatives.',
        data: data,
      );
      campaigns.add(hanaway);

      setState(() {
        _campaigns = campaigns;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load campaign data: $e';
        _loading = false;
      });
    }
  }

  CampaignData _buildCampaignData({
    required String id,
    required String name,
    required String description,
    required Map<String, dynamic> data,
  }) {
    final participantsRaw = data['participants'] as List<Map<String, dynamic>>? ?? [];

    // Build participant models
    final participants = participantsRaw.map((record) {
      Member? linkedMember;
      Subscriber? linkedSubscriber;

      // Parse linked member if present
      final memberJson = record['linked_member'] as Map<String, dynamic>?;
      if (memberJson != null) {
        linkedMember = Member.fromJson(memberJson);
      }

      // Parse linked subscriber if present
      final subscriberJson = record['linked_subscriber'] as Map<String, dynamic>?;
      if (subscriberJson != null) {
        linkedSubscriber = _parseSubscriber(subscriberJson);
      }

      return CampaignParticipant(
        name: record['user_name']?.toString() ?? 'Unknown',
        email: record['user_email']?.toString() ?? '',
        zipCode: record['user_zip_code']?.toString(),
        county: record['county']?.toString(),
        sentAt: _parseDateTime(record['sent_at']),
        sendMethod: record['send_method']?.toString(),
        createdAt: _parseDateTime(record['created_at']) ?? DateTime.now(),
        profilePhotoUrl: record['profile_photo_url']?.toString(),
        linkedMember: linkedMember,
        linkedSubscriber: linkedSubscriber,
      );
    }).toList();

    return CampaignData(
      id: id,
      name: name,
      description: description,
      totalGenerated: data['totalGenerated'] as int? ?? 0,
      totalSent: data['totalSent'] as int? ?? 0,
      uniqueParticipants: data['uniqueParticipants'] as int? ?? 0,
      sendMethodBreakdown: (data['sendMethodBreakdown'] as Map<String, int>?) ?? {},
      participantsByZip: (data['participantsByZip'] as Map<String, int>?) ?? {},
      participantsByCounty: (data['participantsByCounty'] as Map<String, int>?) ?? {},
      participants: participants,
    );
  }

  Subscriber _parseSubscriber(Map<String, dynamic> json) {
    return Subscriber(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? 'N/A',
      phone: json['phone'] as String?,
      zipCode: json['zip_code'] as String?,
      county: json['county'] as String?,
      state: json['state'] as String?,
      source: json['source'] as String?,
      tags: json['tags'] as String?,
    );
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildOverviewHeader(),
          const SizedBox(height: 24),
          _buildCampaignsList(),
        ],
      ),
    );
  }

  Widget _buildOverviewHeader() {
    final theme = Theme.of(context);

    // Calculate totals across all campaigns
    int totalGenerated = 0;
    int totalSent = 0;
    int totalParticipants = 0;
    int totalCampaigns = _campaigns.length;

    for (final campaign in _campaigns) {
      totalGenerated += campaign.totalGenerated;
      totalSent += campaign.totalSent;
      totalParticipants += campaign.uniqueParticipants;
    }

    final overallSendRate = totalGenerated > 0 ? (totalSent / totalGenerated * 100) : 0.0;

    // Blue gradient colors matching Policy & Advocacy committee
    const primaryBlue = Color(0xFF2B4B8C);  // royalBlue
    const secondaryBlue = Color(0xFF5A7FA3);  // slateBlue

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [primaryBlue, secondaryBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.campaign, color: Colors.white, size: 32),
                  const SizedBox(width: 12),
                  Text(
                    'Advocacy Campaigns',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Overview of all Policy & Advocacy email campaigns',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 400;
                  final cards = [
                    _buildOverviewStat(
                      icon: Icons.folder_open,
                      label: 'Campaigns',
                      value: '$totalCampaigns',
                    ),
                    _buildOverviewStat(
                      icon: Icons.edit_note,
                      label: 'Generated',
                      value: '$totalGenerated',
                    ),
                    // Per user request: sent should equal generated
                    _buildOverviewStat(
                      icon: Icons.send,
                      label: 'Sent',
                      value: '$totalGenerated',
                    ),
                    _buildOverviewStat(
                      icon: Icons.people,
                      label: 'Participants',
                      value: '$totalParticipants',
                    ),
                  ];

                  if (isWide) {
                    return Row(
                      children: cards.map((card) => Expanded(child: card)).toList(),
                    );
                  }

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: cards.map((card) => SizedBox(
                      width: (constraints.maxWidth - 12) / 2,
                      child: card,
                    )).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignsList() {
    final theme = Theme.of(context);

    if (_campaigns.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.folder_off, size: 48, color: theme.disabledColor),
              const SizedBox(height: 16),
              Text(
                'No campaigns yet',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'All Campaigns',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ..._campaigns.map((campaign) => _buildCampaignCard(campaign)),
      ],
    );
  }

  Widget _buildCampaignCard(CampaignData campaign) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, y');

    // Get some recent participants for preview
    final recentParticipants = campaign.participants.take(5).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _openCampaignDetail(campaign),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B4B8C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.campaign, color: Color(0xFF2B4B8C)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          campaign.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          campaign.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 20),

              // Stats row
              // Per user request: sent should equal generated
              Row(
                children: [
                  _buildCampaignStat(
                    icon: Icons.edit_note,
                    label: 'Generated',
                    value: '${campaign.totalGenerated}',
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 16),
                  _buildCampaignStat(
                    icon: Icons.send,
                    label: 'Sent',
                    value: '${campaign.totalGenerated}',
                    color: Colors.green,
                  ),
                  const SizedBox(width: 16),
                  _buildCampaignStat(
                    icon: Icons.people,
                    label: 'Participants',
                    value: '${campaign.uniqueParticipants}',
                    color: Colors.purple,
                  ),
                  const SizedBox(width: 16),
                  _buildCampaignStat(
                    icon: Icons.percent,
                    label: 'Send Rate',
                    value: '${campaign.totalGenerated > 0 ? '100.0' : '0.0'}%',
                    color: Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Recent participants preview
              if (recentParticipants.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.people_outline, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Recent Participants',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Avatar stack
                    SizedBox(
                      width: 120,
                      height: 40,
                      child: Stack(
                        children: recentParticipants.asMap().entries.map((entry) {
                          final index = entry.key;
                          final participant = entry.value;
                          return Positioned(
                            left: index * 24.0,
                            child: _buildParticipantAvatar(participant),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        campaign.participants.length > 5
                            ? '${recentParticipants.first.name} and ${campaign.participants.length - 1} more'
                            : recentParticipants.map((p) => p.name.split(' ').first).join(', '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),
              // View details button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openCampaignDetail(campaign),
                  icon: const Icon(Icons.analytics),
                  label: const Text('View Detailed Analytics'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple,
                    side: const BorderSide(color: Colors.purple),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCampaignStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantAvatar(CampaignParticipant participant) {
    final photoUrl = participant.profilePhotoUrl ??
        participant.linkedMember?.primaryProfilePhotoUrl;

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: CircleAvatar(
          radius: 18,
          backgroundImage: NetworkImage(photoUrl),
          onBackgroundImageError: (_, __) {},
        ),
      );
    }

    // Fallback to initials
    final initials = participant.name.isNotEmpty
        ? participant.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : '?';

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: participant.isMember
            ? Colors.blue.withOpacity(0.2)
            : participant.isSubscriber
                ? Colors.orange.withOpacity(0.2)
                : Colors.purple.withOpacity(0.2),
        child: Text(
          initials,
          style: TextStyle(
            color: participant.isMember
                ? Colors.blue
                : participant.isSubscriber
                    ? Colors.orange
                    : Colors.purple,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _openCampaignDetail(CampaignData campaign) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CampaignDetailScreen(campaign: campaign),
      ),
    );
  }
}
