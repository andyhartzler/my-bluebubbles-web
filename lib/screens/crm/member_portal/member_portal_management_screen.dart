import 'package:flutter/material.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/member_portal.dart';
import 'package:bluebubbles/services/crm/member_portal_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

class MemberPortalManagementScreen extends StatefulWidget {
  const MemberPortalManagementScreen({super.key});

  @override
  State<MemberPortalManagementScreen> createState() => _MemberPortalManagementScreenState();
}

class _MemberPortalManagementScreenState extends State<MemberPortalManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 6, vsync: this);
  final MemberPortalRepository _repository = MemberPortalRepository();
  final CRMSupabaseService _supabase = CRMSupabaseService();

  late Future<MemberPortalDashboardStats> _statsFuture;
  late Future<List<MemberPortalMeeting>> _meetingsFuture;
  late Future<List<MemberSubmittedEvent>> _eventsFuture;
  late Future<List<MemberPortalResource>> _resourcesFuture;
  late Future<List<MemberProfileChange>> _profileChangesFuture;
  late Future<List<MemberPortalFieldVisibility>> _fieldVisibilityFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _repository.fetchDashboardStats();
    _meetingsFuture = _repository.fetchPortalMeetings();
    _eventsFuture = _repository.fetchMemberSubmittedEvents(status: 'pending');
    _resourcesFuture = _repository.fetchPortalResources();
    _profileChangesFuture = _repository.fetchProfileChanges();
    _fieldVisibilityFuture = _repository.fetchFieldVisibility();
  }

  Future<void> _reloadStats() async {
    setState(() {
      _statsFuture = _repository.fetchDashboardStats();
    });
  }

  Future<void> _reloadMeetings() async {
    setState(() {
      _meetingsFuture = _repository.fetchPortalMeetings();
    });
  }

  Future<void> _reloadEvents() async {
    setState(() {
      _eventsFuture = _repository.fetchMemberSubmittedEvents(status: 'pending');
      _statsFuture = _repository.fetchDashboardStats();
    });
  }

  Future<void> _reloadResources() async {
    setState(() {
      _resourcesFuture = _repository.fetchPortalResources();
      _statsFuture = _repository.fetchDashboardStats();
    });
  }

  Future<void> _reloadProfileChanges() async {
    setState(() {
      _profileChangesFuture = _repository.fetchProfileChanges();
      _statsFuture = _repository.fetchDashboardStats();
    });
  }

  Future<void> _reloadFieldVisibility() async {
    setState(() {
      _fieldVisibilityFuture = _repository.fetchFieldVisibility();
    });
  }

  @override
  Widget build(BuildContext context) {
    final crmReady = CRMConfig.crmEnabled && _supabase.isInitialized;
    if (!crmReady) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Member Portal Management is available when the CRM connection is active.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Portal Management'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Meetings'),
            Tab(text: 'Submitted Events'),
            Tab(text: 'Resources'),
            Tab(text: 'Profile Changes'),
            Tab(text: 'Field Visibility'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildMeetingsTab(),
          _buildSubmittedEventsTab(),
          _buildResourcesTab(),
          _buildProfileChangesTab(),
          _buildFieldVisibilityTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _reloadStats,
      child: FutureBuilder<MemberPortalDashboardStats>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = snapshot.data ?? MemberPortalDashboardStats.empty;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildStatCard('Pending Profile Changes', stats.pendingProfileChanges, Icons.fact_check),
                  _buildStatCard('Pending Event Submissions', stats.pendingEventSubmissions, Icons.event_note),
                  _buildStatCard('Published Meetings', stats.publishedMeetings, Icons.video_camera_front_outlined),
                  _buildStatCard('Visible Resources', stats.visibleResources, Icons.folder_open),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Recent Activity',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Use the tabs above to approve submissions, publish meeting minutes, and manage resources.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMeetingsTab() {
    return RefreshIndicator(
      onRefresh: _reloadMeetings,
      child: FutureBuilder<List<MemberPortalMeeting>>(
        future: _meetingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final meetings = snapshot.data ?? const [];
          if (meetings.isEmpty) {
            return const Center(child: Text('No meetings found.')); 
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: meetings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final meeting = meetings[index];
              return Card(
                child: ListTile(
                  title: Text(meeting.memberTitle.isNotEmpty ? meeting.memberTitle : meeting.meetingTitle ?? 'Meeting'),
                  subtitle: Text(
                    [
                      if (meeting.meetingDate != null)
                        'Meeting Date: ${meeting.meetingDate!.toLocal().toString().split(' ').first}',
                      if (meeting.attendeeCount != null)
                        'Attendees: ${meeting.attendeeCount}',
                    ].join(' • '),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(meeting.isPublished
                          ? (meeting.visibleToAll ? 'Published (All Members)' : 'Published (Attendees)')
                          : 'Draft'),
                      Switch(
                        value: meeting.isPublished,
                        onChanged: (value) async {
                          await _repository.publishPortalMeeting(
                            meetingId: meeting.id,
                            publish: value,
                            adminId: null,
                          );
                          await _reloadMeetings();
                          await _reloadStats();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSubmittedEventsTab() {
    return RefreshIndicator(
      onRefresh: _reloadEvents,
      child: FutureBuilder<List<MemberSubmittedEvent>>(
        future: _eventsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final events = snapshot.data ?? const [];
          if (events.isEmpty) {
            return const Center(child: Text('No pending submissions.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final submission = events[index];
              return Card(
                child: ListTile(
                  title: Text(submission.title),
                  subtitle: Text(
                    'Requested for ${submission.eventDate.toLocal().toString().split(' ').first} '
                    '(${submission.eventType ?? 'unspecified'})',
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () async {
                          await _repository.approveSubmittedEvent(submissionId: submission.id);
                          await _reloadEvents();
                        },
                        child: const Text('Approve'),
                      ),
                      TextButton(
                        onPressed: () async {
                          await _repository.rejectSubmittedEvent(
                            submissionId: submission.id,
                            reason: 'Not a fit for portal',
                          );
                          await _reloadEvents();
                        },
                        child: const Text('Reject'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildResourcesTab() {
    return RefreshIndicator(
      onRefresh: _reloadResources,
      child: FutureBuilder<List<MemberPortalResource>>(
        future: _resourcesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final resources = snapshot.data ?? const [];
          if (resources.isEmpty) {
            return const Center(child: Text('No resources available.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: resources.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final resource = resources[index];
              return Card(
                child: ListTile(
                  title: Text(resource.title),
                  subtitle: Text(resource.resourceType),
                  trailing: Switch(
                    value: resource.isVisible,
                    onChanged: (value) async {
                      await _repository.savePortalResource(
                        resource.copyWith(isVisible: value),
                      );
                      await _reloadResources();
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildProfileChangesTab() {
    return RefreshIndicator(
      onRefresh: _reloadProfileChanges,
      child: FutureBuilder<List<MemberProfileChange>>(
        future: _profileChangesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final changes = snapshot.data ?? const [];
          if (changes.isEmpty) {
            return const Center(child: Text('No pending profile changes.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: changes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final change = changes[index];
              return Card(
                child: ListTile(
                  title: Text(change.displayLabel ?? change.fieldName),
                  subtitle: Text('Pending ${change.changeType} for member ${change.memberId}'),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () async {
                          await _repository.approveProfileChange(change.id);
                          await _reloadProfileChanges();
                        },
                        child: const Text('Approve'),
                      ),
                      TextButton(
                        onPressed: () async {
                          await _repository.rejectProfileChange(change.id, reason: 'Rejected by admin');
                          await _reloadProfileChanges();
                        },
                        child: const Text('Reject'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFieldVisibilityTab() {
    return RefreshIndicator(
      onRefresh: _reloadFieldVisibility,
      child: FutureBuilder<List<MemberPortalFieldVisibility>>(
        future: _fieldVisibilityFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final fields = snapshot.data ?? const [];
          if (fields.isEmpty) {
            return const Center(child: Text('No fields configured.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: fields.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final field = fields[index];
              return Card(
                child: ListTile(
                  title: Text(field.displayLabel),
                  subtitle: Text(field.fieldName),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Visible'),
                              Switch(
                                value: field.isVisible,
                                onChanged: (value) async {
                                  await _repository.saveFieldVisibility(
                                    field.copyWith(isVisible: value),
                                  );
                                  await _reloadFieldVisibility();
                                },
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Editable'),
                              Switch(
                                value: field.isEditable,
                                onChanged: (value) async {
                                  await _repository.saveFieldVisibility(
                                    field.copyWith(isEditable: value),
                                  );
                                  await _reloadFieldVisibility();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon) {
    return SizedBox(
      width: 260,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, size: 32),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyLarge),
                  Text(
                    value.toString(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
