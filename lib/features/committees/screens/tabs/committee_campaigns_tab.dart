import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/features/committees/screens/tabs/campaign_detail_screen.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/subscriber.dart';

// Brand colors matching the main dashboard
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _grassrootsGreen = Color(0xFF43A047);
const _actionRed = Color(0xFFE63946);
const _sunriseGold = Color(0xFFFDB813);
const _justicePurple = Color(0xFF6A1B9A);

/// Campaigns tab for the Policy & Advocacy committee
/// Displays an overview of all advocacy campaigns with drill-down to detailed views
class CommitteeCampaignsTab extends StatefulWidget {
  /// If true, this is a member view - hide participants list and profile navigation
  final bool isMemberView;

  const CommitteeCampaignsTab({super.key, this.isMemberView = false});

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
      return Stack(
        children: [
          _buildGradientBackground(),
          Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_momentumBlue),
            ),
          ),
        ],
      );
    }

    if (_error != null) {
      return Stack(
        children: [
          _buildGradientBackground(),
          _buildErrorState(),
        ],
      );
    }

    return Stack(
      children: [
        _buildGradientBackground(),
        RefreshIndicator(
          onRefresh: _loadData,
          color: _momentumBlue,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              // Header section
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),

              // Stats cards
              SliverToBoxAdapter(
                child: _buildStatsRow(),
              ),

              // Campaigns section
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: _buildCampaignsSection(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGradientBackground() {
    return Positioned.fill(
      child: Stack(
        children: [
          Image.asset(
            'assets/images/Blue-Gradient-Background.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          Container(
            color: Colors.white.withOpacity(0.18),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Advocacy Campaigns',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_campaigns.length} campaign${_campaigns.length == 1 ? '' : 's'} active',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
            color: Colors.white,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    // Calculate totals across all campaigns
    int totalGenerated = 0;
    int totalSent = 0;
    int totalParticipants = 0;

    for (final campaign in _campaigns) {
      totalGenerated += campaign.totalGenerated;
      totalSent += campaign.totalSent;
      totalParticipants += campaign.uniqueParticipants;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 500;

          if (isNarrow) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildStatCard(
                      icon: Icons.edit_note_rounded,
                      label: 'Generated',
                      value: '$totalGenerated',
                      colors: [_momentumBlue, _unityBlue],
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard(
                      icon: Icons.send_rounded,
                      label: 'Sent',
                      value: '$totalGenerated',
                      colors: [_grassrootsGreen, _momentumBlue],
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildStatCard(
                      icon: Icons.people_rounded,
                      label: 'Participants',
                      value: '$totalParticipants',
                      colors: [_justicePurple, _momentumBlue],
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard(
                      icon: Icons.percent_rounded,
                      label: 'Send Rate',
                      value: '100%',
                      colors: [_sunriseGold, _actionRed],
                    )),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: _buildStatCard(
                icon: Icons.edit_note_rounded,
                label: 'Generated',
                value: '$totalGenerated',
                colors: [_momentumBlue, _unityBlue],
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(
                icon: Icons.send_rounded,
                label: 'Sent',
                value: '$totalGenerated',
                colors: [_grassrootsGreen, _momentumBlue],
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(
                icon: Icons.people_rounded,
                label: 'Participants',
                value: '$totalParticipants',
                colors: [_justicePurple, _momentumBlue],
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(
                icon: Icons.percent_rounded,
                label: 'Send Rate',
                value: '100%',
                colors: [_sunriseGold, _actionRed],
              )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required List<Color> colors,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignsSection() {
    if (_campaigns.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(Icons.folder_open_rounded, size: 20, color: Colors.white.withOpacity(0.8)),
              const SizedBox(width: 8),
              const Text(
                'Active Campaigns',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        ..._campaigns.map((campaign) => _buildCampaignCard(campaign)),
      ],
    );
  }

  Widget _buildCampaignCard(CampaignData campaign) {
    // Get some recent participants for preview
    final recentParticipants = campaign.participants.take(5).toList();

    return Card(
      elevation: 2,
      color: _unityBlue,
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _momentumBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.campaign, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          campaign.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          campaign.description,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white54, size: 24),
                ],
              ),
              const SizedBox(height: 16),

              // Stats row
              Row(
                children: [
                  _buildCampaignStat(
                    icon: Icons.edit_note,
                    label: 'Generated',
                    value: '${campaign.totalGenerated}',
                  ),
                  const SizedBox(width: 12),
                  _buildCampaignStat(
                    icon: Icons.send,
                    label: 'Sent',
                    value: '${campaign.totalGenerated}',
                  ),
                  const SizedBox(width: 12),
                  _buildCampaignStat(
                    icon: Icons.people,
                    label: 'Participants',
                    value: '${campaign.uniqueParticipants}',
                  ),
                ],
              ),

              // Participant preview section
              if (campaign.participants.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: widget.isMemberView
                      // Member view: show counts only
                      ? _buildParticipantCountsRow(campaign)
                      // Exec view: show avatar stack with names
                      : Row(
                          children: [
                            // Avatar stack
                            SizedBox(
                              width: 100,
                              height: 32,
                              child: Stack(
                                children: recentParticipants.asMap().entries.take(4).map((entry) {
                                  final index = entry.key;
                                  final participant = entry.value;
                                  return Positioned(
                                    left: index * 20.0,
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
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                ),
              ],

              const SizedBox(height: 14),
              // View details button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openCampaignDetail(campaign),
                  icon: const Icon(Icons.analytics, size: 18),
                  label: const Text('View Detailed Analytics'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.8), size: 16),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantCountsRow(CampaignData campaign) {
    // Count members and subscribers
    int memberCount = 0;
    int subscriberCount = 0;

    for (final participant in campaign.participants) {
      if (participant.linkedMember != null) {
        memberCount++;
      } else if (participant.linkedSubscriber != null) {
        subscriberCount++;
      } else {
        // Count as subscriber if not linked to either
        subscriberCount++;
      }
    }

    return Row(
      children: [
        // Members count
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _grassrootsGreen.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.badge, size: 16, color: _grassrootsGreen),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$memberCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Members',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          width: 1,
          height: 36,
          color: Colors.white.withOpacity(0.2),
        ),
        // Subscribers count
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _momentumBlue.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.mail_outline, size: 16, color: _momentumBlue),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$subscriberCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Subscribers',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantAvatar(CampaignParticipant participant) {
    final photoUrl = participant.profilePhotoUrl ??
        participant.linkedMember?.primaryProfilePhotoUrl;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _unityBlue, width: 2),
      ),
      child: CorsAwareAvatar(
        imageUrl: photoUrl,
        radius: 14,
        backgroundColor: _momentumBlue.withOpacity(0.3),
        fallbackText: participant.name,
        fallbackIconColor: Colors.white,
        fallbackTextColor: Colors.white,
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
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.campaign_outlined,
                size: 56,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No campaigns yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Advocacy campaigns will appear here once created',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'Error loading campaigns',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unknown error occurred',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _unityBlue,
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

  void _openCampaignDetail(CampaignData campaign) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CampaignDetailScreen(
          campaign: campaign,
          isMemberView: widget.isMemberView,
        ),
      ),
    );
  }
}
