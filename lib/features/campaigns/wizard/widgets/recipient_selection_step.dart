import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/campaign_wizard_provider.dart';
import '../../theme/campaign_builder_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Step 3: Premium Recipient Selection
/// Stunning UI for intelligent audience targeting with deduplication
/// Features: Beautiful cards, real-time counts, smart filters
class RecipientSelectionStep extends StatefulWidget {
  const RecipientSelectionStep({super.key});

  @override
  State<RecipientSelectionStep> createState() => _RecipientSelectionStepState();
}

class _RecipientSelectionStepState extends State<RecipientSelectionStep> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CampaignWizardProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with beautiful gradient
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    CampaignBuilderTheme.moyDBlue.withOpacity(0.1),
                    CampaignBuilderTheme.brightBlue.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: CampaignBuilderTheme.moyDBlue.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [CampaignBuilderTheme.moyDBlue, CampaignBuilderTheme.brightBlue],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: CampaignBuilderTheme.moyDBlue.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.groups_rounded, size: 40, color: Colors.white),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Your Audience',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: CampaignBuilderTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose who receives this campaign with smart deduplication',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: CampaignBuilderTheme.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Segment type selector with stunning cards
            Text(
              'Choose Audience Type',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: CampaignBuilderTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),

            _buildSegmentCards(provider),

            const SizedBox(height: 32),

            // Filters section
            if (_showFilters(provider)) ...[
              _buildFiltersSection(provider),
              const SizedBox(height: 32),
            ],

            // Event selector
            if (provider.selectedSegmentType == SegmentType.eventAttendees) ...[
              _buildEventSelector(provider),
              const SizedBox(height: 32),
            ],

            // Real-time estimate card with animation
            _buildEstimateCard(provider),
          ],
        );
      },
    );
  }

  Widget _buildSegmentCards(CampaignWizardProvider provider) {
    final segments = _getSegmentOptions();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: segments.length,
      itemBuilder: (context, index) {
        final segment = segments[index];
        final isSelected = provider.selectedSegmentType == segment.type;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => provider.selectSegmentType(segment.type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          segment.color.withOpacity(0.15),
                          segment.color.withOpacity(0.05),
                        ],
                      )
                    : null,
                color: isSelected ? null : CampaignBuilderTheme.slate,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? segment.color : CampaignBuilderTheme.slateLight,
                  width: isSelected ? 3 : 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: segment.color.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: [segment.color, segment.color.withOpacity(0.7)],
                                  )
                                : null,
                            color: isSelected ? null : segment.color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            segment.icon,
                            color: isSelected ? Colors.white : segment.color,
                            size: 28,
                          ),
                        ),
                        const Spacer(),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: segment.color,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      segment.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? segment.color : CampaignBuilderTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      segment.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: CampaignBuilderTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFiltersSection(CampaignWizardProvider provider) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: CampaignBuilderTheme.slate.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CampaignBuilderTheme.slateLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CampaignBuilderTheme.brightBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: CampaignBuilderTheme.brightBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Refine Your Audience',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: CampaignBuilderTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Optional filters to narrow your reach',
                      style: TextStyle(
                        fontSize: 13,
                        color: CampaignBuilderTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (provider.selectedCongressionalDistricts.isNotEmpty ||
                  provider.selectedCounties.isNotEmpty)
                TextButton.icon(
                  onPressed: provider.clearAllFilters,
                  icon: const Icon(Icons.clear_all_rounded, size: 18),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: CampaignBuilderTheme.errorRed,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Congressional Districts
          _buildFilterCategory(
            'Congressional District',
            ['MO-1', 'MO-2', 'MO-3', 'MO-4', 'MO-5', 'MO-6', 'MO-7', 'MO-8'],
            provider.selectedCongressionalDistricts,
            (district) => provider.toggleCongressionalDistrict(district),
            CampaignBuilderTheme.moyDBlue,
          ),

          const SizedBox(height: 24),

          // Counties
          _buildFilterCategory(
            'County',
            ['Jackson', 'Clay', 'Platte', 'St. Louis', 'St. Louis City', 'Greene', 'Boone', 'Jasper', 'Cole', 'Jefferson'],
            provider.selectedCounties,
            (county) => provider.toggleCounty(county),
            CampaignBuilderTheme.brightBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCategory(
    String title,
    List<String> options,
    List<String> selected,
    Function(String) onToggle,
    Color accentColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CampaignBuilderTheme.textPrimary,
              ),
            ),
            if (selected.isNotEmpty) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withOpacity(0.4)),
                ),
                child: Text(
                  '${selected.length} selected',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: GestureDetector(
                  onTap: () => onToggle(option),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [accentColor, accentColor.withOpacity(0.8)],
                            )
                          : null,
                      color: isSelected ? null : CampaignBuilderTheme.darkNavy,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? accentColor : CampaignBuilderTheme.slateLight,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: accentColor.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        Text(
                          option,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? Colors.white : CampaignBuilderTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEventSelector(CampaignWizardProvider provider) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: CampaignBuilderTheme.slate,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CampaignBuilderTheme.slateLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CampaignBuilderTheme.warningOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.event_rounded,
                  color: CampaignBuilderTheme.warningOrange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Select Events',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: CampaignBuilderTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchRecentEvents(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: CampaignBuilderTheme.darkNavy.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: CampaignBuilderTheme.textTertiary),
                      SizedBox(width: 12),
                      Text(
                        'No recent events found',
                        style: TextStyle(color: CampaignBuilderTheme.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: snapshot.data!.map((event) {
                  final eventId = event['id'] as String;
                  final isSelected = provider.selectedEventIds.contains(eventId);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => provider.toggleEvent(eventId),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? CampaignBuilderTheme.warningOrange.withOpacity(0.1)
                                : CampaignBuilderTheme.darkNavy,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? CampaignBuilderTheme.warningOrange
                                  : CampaignBuilderTheme.slateLight,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? CampaignBuilderTheme.warningOrange
                                      : CampaignBuilderTheme.slateLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isSelected ? Icons.check_circle : Icons.event,
                                  color: isSelected
                                      ? Colors.white
                                      : CampaignBuilderTheme.textSecondary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event['title'] as String? ?? 'Untitled Event',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? CampaignBuilderTheme.warningOrange
                                            : CampaignBuilderTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${event['start_date']} • ${event['attendee_count'] ?? 0} attendees',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: CampaignBuilderTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEstimateCard(CampaignWizardProvider provider) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                CampaignBuilderTheme.moyDBlue.withOpacity(0.9 + _pulseController.value * 0.1),
                CampaignBuilderTheme.brightBlue.withOpacity(0.9 + _pulseController.value * 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: CampaignBuilderTheme.moyDBlue.withOpacity(0.4),
                blurRadius: 20 + _pulseController.value * 10,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.people_alt_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(width: 28),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estimated Recipients',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      provider.loadingEstimate
                          ? const SizedBox(
                              height: 48,
                              child: Center(
                                child: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                ),
                              ),
                            )
                          : TweenAnimationBuilder<int>(
                              tween: IntTween(begin: 0, end: provider.estimatedRecipients),
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.easeOut,
                              builder: (context, value, child) {
                                return Text(
                                  value.toString(),
                                  style: const TextStyle(
                                    fontSize: 52,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 1,
                                    letterSpacing: -1,
                                  ),
                                );
                              },
                            ),
                      const SizedBox(height: 8),
                      Text(
                        provider.hasRecipients
                            ? 'Contacts will receive this campaign'
                            : 'Select an audience to see estimate',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: provider.hasRecipients
                            ? CampaignBuilderTheme.successGreen
                            : Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        provider.hasRecipients ? Icons.check_circle : Icons.pending,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.hasRecipients ? 'Ready' : 'Pending',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _showFilters(CampaignWizardProvider provider) {
    // Only show filters for subscribers, members, and donors
    return provider.selectedSegmentType == SegmentType.allSubscribers ||
        provider.selectedSegmentType == SegmentType.allMembers ||
        provider.selectedSegmentType == SegmentType.allDonors;
  }

  List<_SegmentOption> _getSegmentOptions() {
    return [
      _SegmentOption(
        type: SegmentType.allSubscribers,
        title: 'All Subscribers',
        subtitle: 'Everyone on your email list',
        icon: Icons.mail_outline_rounded,
        color: CampaignBuilderTheme.brightBlue,
      ),
      _SegmentOption(
        type: SegmentType.allMembers,
        title: 'All Members',
        subtitle: 'Current chapter members',
        icon: Icons.card_membership_rounded,
        color: const Color(0xFF8B5CF6),
      ),
      _SegmentOption(
        type: SegmentType.allDonors,
        title: 'All Donors',
        subtitle: 'People who have donated',
        icon: Icons.volunteer_activism_rounded,
        color: CampaignBuilderTheme.successGreen,
      ),
      _SegmentOption(
        type: SegmentType.eventAttendees,
        title: 'Event Attendees',
        subtitle: 'Specific event participants',
        icon: Icons.event_available_rounded,
        color: CampaignBuilderTheme.warningOrange,
      ),
      _SegmentOption(
        type: SegmentType.everyone,
        title: 'Everyone',
        subtitle: 'All contacts (deduplicated)',
        icon: Icons.group_add_rounded,
        color: CampaignBuilderTheme.moyDBlue,
      ),
    ];
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
