import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/campaign_wizard_provider.dart';
import '../../theme/campaign_builder_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Step 3: Recipient Selection
/// Intelligent audience targeting with deduplication
/// Features: Multi-source selection, filters, real-time count estimation
class RecipientSelectionStep extends StatefulWidget {
  const RecipientSelectionStep({super.key});

  @override
  State<RecipientSelectionStep> createState() => _RecipientSelectionStepState();
}

class _RecipientSelectionStepState extends State<RecipientSelectionStep> {
  @override
  Widget build(BuildContext context) {
    return Consumer<CampaignWizardProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Select Recipients',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: CampaignBuilderTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose your audience with intelligent targeting and automatic deduplication',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: CampaignBuilderTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 32),

            // Segment type selector
            _buildSegmentSelector(provider),

            const SizedBox(height: 24),

            // Filters (if applicable)
            if (_showFilters(provider)) _buildFilters(provider),

            // Event selector (if event attendees selected)
            if (provider.selectedSegmentType == SegmentType.eventAttendees)
              _buildEventSelector(provider),

            const SizedBox(height: 32),

            // Estimated recipients card
            _buildEstimateCard(provider),
          ],
        );
      },
    );
  }

  Widget _buildSegmentSelector(CampaignWizardProvider provider) {
    final segments = [
      _SegmentOption(
        type: SegmentType.allSubscribers,
        title: 'All Subscribers',
        subtitle: 'Everyone subscribed to your email list',
        icon: Icons.email_outlined,
        color: CampaignBuilderTheme.brightBlue,
      ),
      _SegmentOption(
        type: SegmentType.allMembers,
        title: 'All Members',
        subtitle: 'Current chapter members only',
        icon: Icons.card_membership_outlined,
        color: const Color(0xFF8B5CF6),
      ),
      _SegmentOption(
        type: SegmentType.allDonors,
        title: 'All Donors',
        subtitle: 'Anyone who has made a donation',
        icon: Icons.volunteer_activism_outlined,
        color: CampaignBuilderTheme.successGreen,
      ),
      _SegmentOption(
        type: SegmentType.eventAttendees,
        title: 'Event Attendees',
        subtitle: 'People who attended specific events',
        icon: Icons.event_outlined,
        color: CampaignBuilderTheme.warningOrange,
      ),
      _SegmentOption(
        type: SegmentType.everyone,
        title: 'Everyone in Database',
        subtitle: 'All contacts across all tables (deduplicated)',
        icon: Icons.groups_outlined,
        color: CampaignBuilderTheme.moyDBlue,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Audience',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: CampaignBuilderTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: segments.map((segment) {
              final isSelected = provider.selectedSegmentType == segment.type;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => provider.selectSegmentType(segment.type),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? segment.color.withOpacity(0.1)
                          : CampaignBuilderTheme.slate,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? segment.color : CampaignBuilderTheme.slateLight,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: segment.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(segment.icon, color: segment.color, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                segment.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected ? segment.color : CampaignBuilderTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                segment.subtitle,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: CampaignBuilderTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle, color: segment.color, size: 28),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  bool _showFilters(CampaignWizardProvider provider) {
    return provider.selectedSegmentType != null &&
        provider.selectedSegmentType != SegmentType.eventAttendees;
  }

  Widget _buildFilters(CampaignWizardProvider provider) {
    final districts = ['MO-1', 'MO-2', 'MO-3', 'MO-4', 'MO-5', 'MO-6', 'MO-7', 'MO-8'];
    final counties = [
      'Jackson',
      'Clay',
      'Platte',
      'St. Louis',
      'St. Louis City',
      'Greene',
      'Boone',
      'Jasper',
      'Cole',
      'Jefferson',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: CampaignBuilderTheme.slate,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CampaignBuilderTheme.slateLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.filter_list, size: 20, color: CampaignBuilderTheme.brightBlue),
                  const SizedBox(width: 8),
                  const Text(
                    'Additional Filters (Optional)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CampaignBuilderTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (provider.selectedCongressionalDistricts.isNotEmpty ||
                      provider.selectedCounties.isNotEmpty)
                    TextButton.icon(
                      onPressed: provider.clearAllFilters,
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Clear all'),
                      style: TextButton.styleFrom(
                        foregroundColor: CampaignBuilderTheme.errorRed,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Congressional Districts
              const Text(
                'Congressional District',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CampaignBuilderTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: districts.map((district) {
                  final isSelected = provider.selectedCongressionalDistricts.contains(district);
                  return FilterChip(
                    label: Text(district),
                    selected: isSelected,
                    onSelected: (_) => provider.toggleCongressionalDistrict(district),
                    selectedColor: CampaignBuilderTheme.moyDBlue.withOpacity(0.3),
                    checkmarkColor: CampaignBuilderTheme.moyDBlue,
                    backgroundColor: CampaignBuilderTheme.darkNavy,
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Counties
              const Text(
                'County',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CampaignBuilderTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: counties.map((county) {
                  final isSelected = provider.selectedCounties.contains(county);
                  return FilterChip(
                    label: Text(county),
                    selected: isSelected,
                    onSelected: (_) => provider.toggleCounty(county),
                    selectedColor: CampaignBuilderTheme.moyDBlue.withOpacity(0.3),
                    checkmarkColor: CampaignBuilderTheme.moyDBlue,
                    backgroundColor: CampaignBuilderTheme.darkNavy,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildEventSelector(CampaignWizardProvider provider) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: CampaignBuilderTheme.slate,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CampaignBuilderTheme.slateLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Events',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: CampaignBuilderTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchRecentEvents(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text(
                      'No recent events found',
                      style: TextStyle(color: CampaignBuilderTheme.textTertiary),
                    );
                  }

                  return Column(
                    children: snapshot.data!.map((event) {
                      final eventId = event['id'] as String;
                      final isSelected = provider.selectedEventIds.contains(eventId);

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (_) => provider.toggleEvent(eventId),
                        title: Text(event['title'] as String? ?? 'Untitled Event'),
                        subtitle: Text(
                          'Date: ${event['start_date']} • ${event['attendee_count'] ?? 0} attendees',
                          style: const TextStyle(fontSize: 12),
                        ),
                        activeColor: CampaignBuilderTheme.moyDBlue,
                        contentPadding: EdgeInsets.zero,
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildEstimateCard(CampaignWizardProvider provider) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: CampaignBuilderTheme.premiumGradientDecoration,
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.people_outline,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated Recipients',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                provider.loadingEstimate
                    ? const SizedBox(
                        height: 40,
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        provider.estimatedRecipients.toString(),
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
              ],
            ),
          ),
          Column(
            children: [
              Icon(
                Icons.check_circle,
                color: provider.hasRecipients
                    ? CampaignBuilderTheme.successGreen
                    : Colors.white.withOpacity(0.3),
                size: 32,
              ),
              const SizedBox(height: 4),
              Text(
                provider.hasRecipients ? 'Ready' : 'Select audience',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRecentEvents() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('events')
          .select('id, title, start_date, attendee_count')
          .order('start_date', ascending: false)
          .limit(10);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching events: $e');
      return [];
    }
  }
}

class _SegmentOption {
  final SegmentType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  _SegmentOption({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
