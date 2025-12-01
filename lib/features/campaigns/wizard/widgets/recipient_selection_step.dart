import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/campaign_wizard_provider.dart';
import '../../theme/campaign_builder_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Step 3: Premium Recipient Selection
/// Two-stage selection: First choose audience type, then refine with dropdowns
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
                          'Choose your primary audience, then refine your selection',
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
              'Step 1: Choose Audience Type',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: CampaignBuilderTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),

            _buildSegmentCards(provider),

            const SizedBox(height: 32),

            // Stage 2: Filter options based on selected type
            if (provider.selectedSegmentType != null) ...[
              Text(
                'Step 2: Refine Your Selection',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: CampaignBuilderTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 20),
              _buildFilterOptions(provider),
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

  Widget _buildFilterOptions(CampaignWizardProvider provider) {
    switch (provider.selectedSegmentType!) {
      case SegmentType.subscribers:
        return _buildSubscriberFilters(provider);
      case SegmentType.donors:
        return _buildDonorFilters(provider);
      case SegmentType.members:
        return _buildMemberFilters(provider);
      case SegmentType.eventAttendees:
        return _buildEventSelector(provider);
    }
  }

  Widget _buildSubscriberFilters(CampaignWizardProvider provider) {
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
          const Text(
            'How do you want to filter subscribers?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: CampaignBuilderTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Filter mode dropdown
          DropdownButtonFormField<SubscriberFilterMode>(
            value: provider.subscriberFilterMode,
            decoration: InputDecoration(
              labelText: 'Filter Type',
              filled: true,
              fillColor: CampaignBuilderTheme.darkNavy,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: CampaignBuilderTheme.slateLight),
              ),
            ),
            dropdownColor: CampaignBuilderTheme.darkNavy,
            items: const [
              DropdownMenuItem(
                value: SubscriberFilterMode.all,
                child: Text('All Subscribers'),
              ),
              DropdownMenuItem(
                value: SubscriberFilterMode.byCongressionalDistrict,
                child: Text('By Congressional District'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                provider.setSubscriberFilterMode(value);
              }
            },
          ),

          // Show CD dropdown if filter mode is byCongressionalDistrict
          if (provider.subscriberFilterMode == SubscriberFilterMode.byCongressionalDistrict) ...[
            const SizedBox(height: 16),
            FutureBuilder<List<String>>(
              future: provider.fetchCongressionalDistricts(SegmentType.subscribers),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final districts = snapshot.data ?? [];

                return DropdownButtonFormField<String>(
                  value: provider.selectedCongressionalDistrict,
                  decoration: InputDecoration(
                    labelText: 'Congressional District',
                    filled: true,
                    fillColor: CampaignBuilderTheme.darkNavy,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: CampaignBuilderTheme.slateLight),
                    ),
                  ),
                  dropdownColor: CampaignBuilderTheme.darkNavy,
                  items: districts.map((district) {
                    return DropdownMenuItem(
                      value: district,
                      child: Text(district),
                    );
                  }).toList(),
                  onChanged: (value) {
                    provider.setSubscriberCongressionalDistrict(value);
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text(
                'Include subscribers where CD is not set',
                style: TextStyle(color: CampaignBuilderTheme.textPrimary),
              ),
              value: provider.includeNullCD,
              onChanged: (value) {
                if (value != null) {
                  provider.toggleIncludeNullCD(value);
                }
              },
              activeColor: CampaignBuilderTheme.brightBlue,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDonorFilters(CampaignWizardProvider provider) {
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
          const Text(
            'How do you want to filter donors?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: CampaignBuilderTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Filter mode dropdown
          DropdownButtonFormField<DonorFilterMode>(
            value: provider.donorFilterMode,
            decoration: InputDecoration(
              labelText: 'Filter Type',
              filled: true,
              fillColor: CampaignBuilderTheme.darkNavy,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: CampaignBuilderTheme.slateLight),
              ),
            ),
            dropdownColor: CampaignBuilderTheme.darkNavy,
            items: const [
              DropdownMenuItem(
                value: DonorFilterMode.all,
                child: Text('All Donors'),
              ),
              DropdownMenuItem(
                value: DonorFilterMode.byCounty,
                child: Text('By County'),
              ),
              DropdownMenuItem(
                value: DonorFilterMode.byCongressionalDistrict,
                child: Text('By Congressional District'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                provider.setDonorFilterMode(value);
              }
            },
          ),

          // Show county dropdown
          if (provider.donorFilterMode == DonorFilterMode.byCounty) ...[
            const SizedBox(height: 16),
            FutureBuilder<List<String>>(
              future: provider.fetchCounties(SegmentType.donors),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final counties = snapshot.data ?? [];

                return DropdownButtonFormField<String>(
                  value: provider.selectedCounty,
                  decoration: InputDecoration(
                    labelText: 'County',
                    filled: true,
                    fillColor: CampaignBuilderTheme.darkNavy,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: CampaignBuilderTheme.slateLight),
                    ),
                  ),
                  dropdownColor: CampaignBuilderTheme.darkNavy,
                  items: counties.map((county) {
                    return DropdownMenuItem(
                      value: county,
                      child: Text(county),
                    );
                  }).toList(),
                  onChanged: (value) {
                    provider.setDonorCounty(value);
                  },
                );
              },
            ),
          ],

          // Show CD dropdown
          if (provider.donorFilterMode == DonorFilterMode.byCongressionalDistrict) ...[
            const SizedBox(height: 16),
            FutureBuilder<List<String>>(
              future: provider.fetchCongressionalDistricts(SegmentType.donors),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final districts = snapshot.data ?? [];

                return DropdownButtonFormField<String>(
                  value: provider.selectedCongressionalDistrict,
                  decoration: InputDecoration(
                    labelText: 'Congressional District',
                    filled: true,
                    fillColor: CampaignBuilderTheme.darkNavy,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: CampaignBuilderTheme.slateLight),
                    ),
                  ),
                  dropdownColor: CampaignBuilderTheme.darkNavy,
                  items: districts.map((district) {
                    return DropdownMenuItem(
                      value: district,
                      child: Text(district),
                    );
                  }).toList(),
                  onChanged: (value) {
                    provider.setDonorCongressionalDistrict(value);
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberFilters(CampaignWizardProvider provider) {
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
          const Text(
            'How do you want to filter members?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: CampaignBuilderTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Filter mode dropdown
          DropdownButtonFormField<MemberFilterMode>(
            value: provider.memberFilterMode,
            decoration: InputDecoration(
              labelText: 'Filter Type',
              filled: true,
              fillColor: CampaignBuilderTheme.darkNavy,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: CampaignBuilderTheme.slateLight),
              ),
            ),
            dropdownColor: CampaignBuilderTheme.darkNavy,
            items: const [
              DropdownMenuItem(
                value: MemberFilterMode.all,
                child: Text('All Members'),
              ),
              DropdownMenuItem(
                value: MemberFilterMode.byCongressionalDistrict,
                child: Text('By Congressional District'),
              ),
              DropdownMenuItem(
                value: MemberFilterMode.byCounty,
                child: Text('By County'),
              ),
              DropdownMenuItem(
                value: MemberFilterMode.byChapter,
                child: Text('By Chapter'),
              ),
              DropdownMenuItem(
                value: MemberFilterMode.bySchool,
                child: Text('By School'),
              ),
              DropdownMenuItem(
                value: MemberFilterMode.collegeStudents,
                child: Text('All College Students'),
              ),
              DropdownMenuItem(
                value: MemberFilterMode.highSchoolStudents,
                child: Text('All High School Students'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                provider.setMemberFilterMode(value);
              }
            },
          ),

          // Show CD dropdown
          if (provider.memberFilterMode == MemberFilterMode.byCongressionalDistrict) ...[
            const SizedBox(height: 16),
            FutureBuilder<List<String>>(
              future: provider.fetchCongressionalDistricts(SegmentType.members),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final districts = snapshot.data ?? [];

                return DropdownButtonFormField<String>(
                  value: provider.selectedCongressionalDistrict,
                  decoration: InputDecoration(
                    labelText: 'Congressional District',
                    filled: true,
                    fillColor: CampaignBuilderTheme.darkNavy,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: CampaignBuilderTheme.slateLight),
                    ),
                  ),
                  dropdownColor: CampaignBuilderTheme.darkNavy,
                  items: districts.map((district) {
                    return DropdownMenuItem(
                      value: district,
                      child: Text(district),
                    );
                  }).toList(),
                  onChanged: (value) {
                    provider.setMemberCongressionalDistrict(value);
                  },
                );
              },
            ),
          ],

          // Show county dropdown
          if (provider.memberFilterMode == MemberFilterMode.byCounty) ...[
            const SizedBox(height: 16),
            FutureBuilder<List<String>>(
              future: provider.fetchCounties(SegmentType.members),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final counties = snapshot.data ?? [];

                return DropdownButtonFormField<String>(
                  value: provider.selectedCounty,
                  decoration: InputDecoration(
                    labelText: 'County',
                    filled: true,
                    fillColor: CampaignBuilderTheme.darkNavy,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: CampaignBuilderTheme.slateLight),
                    ),
                  ),
                  dropdownColor: CampaignBuilderTheme.darkNavy,
                  items: counties.map((county) {
                    return DropdownMenuItem(
                      value: county,
                      child: Text(county),
                    );
                  }).toList(),
                  onChanged: (value) {
                    provider.setMemberCounty(value);
                  },
                );
              },
            ),
          ],

          // Show chapter dropdown
          if (provider.memberFilterMode == MemberFilterMode.byChapter) ...[
            const SizedBox(height: 16),
            FutureBuilder<List<String>>(
              future: provider.fetchChapters(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final chapters = snapshot.data ?? [];

                return DropdownButtonFormField<String>(
                  value: provider.selectedChapter,
                  decoration: InputDecoration(
                    labelText: 'Chapter',
                    filled: true,
                    fillColor: CampaignBuilderTheme.darkNavy,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: CampaignBuilderTheme.slateLight),
                    ),
                  ),
                  dropdownColor: CampaignBuilderTheme.darkNavy,
                  items: chapters.map((chapter) {
                    return DropdownMenuItem(
                      value: chapter,
                      child: Text(chapter),
                    );
                  }).toList(),
                  onChanged: (value) {
                    provider.setMemberChapter(value);
                  },
                );
              },
            ),
          ],

          // Show school dropdown
          if (provider.memberFilterMode == MemberFilterMode.bySchool) ...[
            const SizedBox(height: 16),
            FutureBuilder<List<String>>(
              future: provider.fetchSchools(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final schools = snapshot.data ?? [];

                return DropdownButtonFormField<String>(
                  value: provider.selectedSchool,
                  decoration: InputDecoration(
                    labelText: 'School',
                    filled: true,
                    fillColor: CampaignBuilderTheme.darkNavy,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: CampaignBuilderTheme.slateLight),
                    ),
                  ),
                  dropdownColor: CampaignBuilderTheme.darkNavy,
                  items: schools.map((school) {
                    return DropdownMenuItem(
                      value: school,
                      child: Text(school),
                    );
                  }).toList(),
                  onChanged: (value) {
                    provider.setMemberSchool(value);
                  },
                );
              },
            ),
          ],
        ],
      ),
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
                                      '${event['event_date']} • ${event['attendee_count'] ?? 0} attendees',
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

  List<_SegmentOption> _getSegmentOptions() {
    return [
      _SegmentOption(
        type: SegmentType.subscribers,
        title: 'Subscribers',
        subtitle: 'Email list subscribers',
        icon: Icons.mail_outline_rounded,
        color: CampaignBuilderTheme.brightBlue,
      ),
      _SegmentOption(
        type: SegmentType.eventAttendees,
        title: 'Event Attendees',
        subtitle: 'Event participants',
        icon: Icons.event_available_rounded,
        color: CampaignBuilderTheme.warningOrange,
      ),
      _SegmentOption(
        type: SegmentType.donors,
        title: 'Donors',
        subtitle: 'Campaign donors',
        icon: Icons.volunteer_activism_rounded,
        color: CampaignBuilderTheme.successGreen,
      ),
      _SegmentOption(
        type: SegmentType.members,
        title: 'Members',
        subtitle: 'Organization members',
        icon: Icons.card_membership_rounded,
        color: const Color(0xFF8B5CF6),
      ),
    ];
  }

  Future<List<Map<String, dynamic>>> _fetchRecentEvents() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('events')
          .select('id, title, event_date, attendee_count')
          .order('event_date', ascending: false)
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
