import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/committees/services/committee_repository.dart';

/// Campaigns tab for the Policy & Advocacy committee
/// Displays advocacy campaign data from hanaway_campaign_tracking
class CommitteeCampaignsTab extends StatefulWidget {
  const CommitteeCampaignsTab({super.key});

  @override
  State<CommitteeCampaignsTab> createState() => _CommitteeCampaignsTabState();
}

class _CommitteeCampaignsTabState extends State<CommitteeCampaignsTab> {
  final CommitteeRepository _repository = CommitteeRepository();
  Map<String, dynamic>? _campaignData;
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
      final data = await _repository.getAdvocacyCampaignData();
      if (!mounted) return;
      setState(() {
        _campaignData = data;
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
          _buildOverviewSection(),
          const SizedBox(height: 24),
          _buildSendMethodSection(),
          const SizedBox(height: 24),
          _buildGeographicSection(),
          const SizedBox(height: 24),
          _buildParticipantsSection(),
        ],
      ),
    );
  }

  Widget _buildOverviewSection() {
    final theme = Theme.of(context);
    final data = _campaignData!;
    final totalGenerated = data['totalGenerated'] as int? ?? 0;
    final totalSent = data['totalSent'] as int? ?? 0;
    final uniqueParticipants = data['uniqueParticipants'] as int? ?? 0;
    final sendRate = totalGenerated > 0 ? (totalSent / totalGenerated * 100) : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Hanaway Campaign Overview',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Advocacy email campaign results and participation metrics',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 400;
                final cards = [
                  _buildStatCard(
                    icon: Icons.edit_note,
                    label: 'Emails Generated',
                    value: '$totalGenerated',
                    color: Colors.blue,
                  ),
                  _buildStatCard(
                    icon: Icons.send,
                    label: 'Emails Sent',
                    value: '$totalSent',
                    color: Colors.green,
                  ),
                  _buildStatCard(
                    icon: Icons.people,
                    label: 'Participants',
                    value: '$uniqueParticipants',
                    color: Colors.purple,
                  ),
                  _buildStatCard(
                    icon: Icons.percent,
                    label: 'Send Rate',
                    value: '${sendRate.toStringAsFixed(1)}%',
                    color: Colors.orange,
                  ),
                ];

                if (isWide) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: cards.map((card) => SizedBox(
                      width: (constraints.maxWidth - 36) / 4,
                      child: card,
                    )).toList(),
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
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendMethodSection() {
    final theme = Theme.of(context);
    final data = _campaignData!;
    final sendMethodBreakdown = data['sendMethodBreakdown'] as Map<String, int>? ?? {};
    final totalSent = data['totalSent'] as int? ?? 0;

    if (sendMethodBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    final methodColors = {
      'mail_app': Colors.blue,
      'gmail': Colors.red,
      'outlook': Colors.indigo,
      'copy_paste': Colors.orange,
      'auto_shortcut': Colors.green,
      'unknown': Colors.grey,
    };

    final methodLabels = {
      'mail_app': 'Mail App',
      'gmail': 'Gmail',
      'outlook': 'Outlook',
      'copy_paste': 'Copy & Paste',
      'auto_shortcut': 'Auto Shortcut',
      'unknown': 'Unknown',
    };

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  'Send Method Analysis',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...sendMethodBreakdown.entries.map((entry) {
              final method = entry.key;
              final count = entry.value;
              final percentage = totalSent > 0 ? (count / totalSent * 100) : 0.0;
              final color = methodColors[method] ?? Colors.grey;
              final label = methodLabels[method] ?? method;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(label, style: theme.textTheme.bodyMedium),
                        Text(
                          '$count (${percentage.toStringAsFixed(1)}%)',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: color.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildGeographicSection() {
    final theme = Theme.of(context);
    final data = _campaignData!;
    final participantsByZip = data['participantsByZip'] as Map<String, int>? ?? {};

    if (participantsByZip.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort by count descending
    final sortedZips = participantsByZip.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Geographic Distribution',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Participation by ZIP code',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sortedZips.take(15).map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${entry.value}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            if (sortedZips.length > 15)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '... and ${sortedZips.length - 15} more ZIP codes',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsSection() {
    final theme = Theme.of(context);
    final data = _campaignData!;
    final participants = data['participants'] as List<Map<String, dynamic>>? ?? [];
    final dateFormat = DateFormat('MMM d, y h:mm a');

    if (participants.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.people_outline, size: 48, color: theme.disabledColor),
              const SizedBox(height: 16),
              Text(
                'No participants yet',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Recent Participants',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...participants.take(10).map((participant) {
              final name = participant['user_name']?.toString() ?? 'Unknown';
              final email = participant['user_email']?.toString() ?? '';
              final zip = participant['user_zip_code']?.toString() ?? '';
              final sentAtStr = participant['sent_at']?.toString();
              final sentAt = sentAtStr != null ? DateTime.tryParse(sentAtStr) : null;
              final sendMethod = participant['send_method']?.toString() ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.purple.withOpacity(0.2),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.purple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (email.isNotEmpty)
                                Text(
                                  email,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (sentAt != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.check, size: 16, color: Colors.green),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.pending, size: 16, color: Colors.orange),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (zip.isNotEmpty)
                          _buildSmallChip(Icons.location_on, zip, Colors.red),
                        if (sendMethod.isNotEmpty)
                          _buildSmallChip(Icons.send, sendMethod.replaceAll('_', ' '), Colors.blue),
                        if (sentAt != null)
                          _buildSmallChip(Icons.schedule, dateFormat.format(sentAt), Colors.grey),
                      ],
                    ),
                  ],
                ),
              );
            }),
            if (participants.length > 10)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '... and ${participants.length - 10} more participants',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }
}
