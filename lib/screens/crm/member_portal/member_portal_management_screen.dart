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

  String? _resourceTypeFilter;
  bool _showOnlyVisibleResources = false;
  final TextEditingController _resourceSearchController = TextEditingController();

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

  @override
  void dispose() {
    _resourceSearchController.dispose();
    super.dispose();
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
          final filteredResources = resources.where((resource) {
            final matchesType =
                _resourceTypeFilter == null || resource.resourceType == _resourceTypeFilter;
            final matchesVisibility =
                !_showOnlyVisibleResources || resource.isVisible;
            final query = _resourceSearchController.text.trim().toLowerCase();
            final matchesSearch = query.isEmpty ||
                resource.title.toLowerCase().contains(query) ||
                (resource.category ?? '').toLowerCase().contains(query);
            return matchesType && matchesVisibility && matchesSearch;
          }).toList();

          if (resources.isEmpty) {
            return const Center(child: Text('No resources available.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 260,
                            child: TextField(
                              controller: _resourceSearchController,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                labelText: 'Search resources',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Resource'),
                            onPressed: () => _openResourceEditor(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilterChip(
                            selected: _resourceTypeFilter == null,
                            label: const Text('All Types'),
                            onSelected: (_) => setState(() => _resourceTypeFilter = null),
                          ),
                          FilterChip(
                            selected: _resourceTypeFilter == 'governing_document',
                            label: const Text('Governing Documents'),
                            onSelected: (_) =>
                                setState(() => _resourceTypeFilter = 'governing_document'),
                          ),
                          FilterChip(
                            selected: _resourceTypeFilter == 'digital_toolkit',
                            label: const Text('Digital Toolkit'),
                            onSelected: (_) =>
                                setState(() => _resourceTypeFilter = 'digital_toolkit'),
                          ),
                          FilterChip(
                            selected: _showOnlyVisibleResources,
                            label: const Text('Visible Only'),
                            onSelected: (_) => setState(
                                () => _showOnlyVisibleResources = !_showOnlyVisibleResources),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (filteredResources.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text('No resources match your filters.'),
                  ),
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: filteredResources
                      .map((resource) => SizedBox(
                            width: 360,
                            child: _buildResourceCard(resource),
                          ))
                      .toList(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResourceCard(MemberPortalResource resource) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(resource.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      if (resource.description?.isNotEmpty ?? false)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            resource.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Switch.adaptive(
                      value: resource.isVisible,
                      onChanged: (value) async {
                        await _repository.savePortalResource(
                          resource.copyWith(isVisible: value),
                        );
                        await _reloadResources();
                      },
                    ),
                    Text(resource.isVisible ? 'Visible' : 'Hidden'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(
                  label: Text(resource.resourceType.replaceAll('_', ' ')),
                  avatar: const Icon(Icons.folder_open, size: 16),
                ),
                if (resource.category?.isNotEmpty ?? false)
                  Chip(
                    label: Text(resource.category!),
                    avatar: const Icon(Icons.label, size: 16),
                  ),
                if (resource.version?.isNotEmpty ?? false)
                  Chip(
                    label: Text('v${resource.version}'),
                    avatar: const Icon(Icons.verified, size: 16),
                  ),
                Chip(
                  label: Text(resource.requiresExecutiveAccess ? 'Exec only' : 'All members'),
                  avatar: Icon(
                    resource.requiresExecutiveAccess ? Icons.lock : Icons.lock_open,
                    size: 16,
                  ),
                ),
                if (resource.lastUpdatedDate != null)
                  Chip(
                    label: Text('Updated ${resource.lastUpdatedDate!.toLocal().toString().split(' ').first}'),
                    avatar: const Icon(Icons.history, size: 16),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (resource.url?.isNotEmpty ?? false)
                        Text('Link: ${resource.url}',
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis),
                      if (resource.storageUrl?.isNotEmpty ?? false)
                        Text('Storage: ${resource.storageUrl}',
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit resource',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _openResourceEditor(context, resource: resource),
                ),
                IconButton(
                  tooltip: 'Toggle exec access',
                  icon: Icon(resource.requiresExecutiveAccess ? Icons.lock : Icons.lock_open),
                  onPressed: () async {
                    await _repository.savePortalResource(
                      resource.copyWith(requiresExecutiveAccess: !resource.requiresExecutiveAccess),
                    );
                    await _reloadResources();
                  },
                ),
                IconButton(
                  tooltip: 'Delete resource',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteResource(resource),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteResource(MemberPortalResource resource) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete resource?'),
        content: Text('This will remove "${resource.title}" from the portal.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _repository.deletePortalResource(resource.id);
      await _reloadResources();
      await _reloadStats();
    }
  }

  Future<void> _openResourceEditor(BuildContext context, {MemberPortalResource? resource}) async {
    final base = resource ??
        MemberPortalResource(
          id: '',
          createdAt: DateTime.now(),
          updatedAt: null,
          title: '',
          description: '',
          resourceType: 'digital_toolkit',
          url: '',
          storageUrl: '',
          isVisible: true,
          sortOrder: 0,
          category: '',
          iconUrl: '',
          thumbnailUrl: '',
          fileSizeBytes: null,
          fileType: '',
          version: '',
          lastUpdatedDate: DateTime.now(),
          requiresExecutiveAccess: false,
        );

    final titleController = TextEditingController(text: base.title);
    final descriptionController = TextEditingController(text: base.description ?? '');
    final urlController = TextEditingController(text: base.url ?? '');
    final storageUrlController = TextEditingController(text: base.storageUrl ?? '');
    final categoryController = TextEditingController(text: base.category ?? '');
    final iconUrlController = TextEditingController(text: base.iconUrl ?? '');
    final thumbnailUrlController = TextEditingController(text: base.thumbnailUrl ?? '');
    final fileTypeController = TextEditingController(text: base.fileType ?? '');
    final versionController = TextEditingController(text: base.version ?? '');
    final sortOrderController = TextEditingController(text: base.sortOrder?.toString() ?? '');
    final fileSizeController = TextEditingController(text: base.fileSizeBytes?.toString() ?? '');
    DateTime? lastUpdatedDate = base.lastUpdatedDate;
    final lastUpdatedController = TextEditingController(
      text: lastUpdatedDate == null
          ? ''
          : lastUpdatedDate.toLocal().toString().split(' ').first,
    );
    String resourceType = base.resourceType;
    bool isVisible = base.isVisible;
    bool requiresExecutiveAccess = base.requiresExecutiveAccess;

    MemberPortalResource? result;
    try {
      result = await showModalBottomSheet<MemberPortalResource>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          resource == null ? 'Add Resource' : 'Edit Resource',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: resourceType,
                      decoration: const InputDecoration(labelText: 'Resource Type'),
                      items: const [
                        DropdownMenuItem(
                          value: 'governing_document',
                          child: Text('Governing Document'),
                        ),
                        DropdownMenuItem(
                          value: 'digital_toolkit',
                          child: Text('Digital Toolkit'),
                        ),
                      ],
                      onChanged: (value) => setModalState(() => resourceType = value ?? 'digital_toolkit'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlController,
                      decoration: const InputDecoration(labelText: 'External URL'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: storageUrlController,
                      decoration: const InputDecoration(labelText: 'Storage URL'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: iconUrlController,
                      decoration: const InputDecoration(labelText: 'Icon URL'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: thumbnailUrlController,
                      decoration: const InputDecoration(labelText: 'Thumbnail URL'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: versionController,
                            decoration: const InputDecoration(labelText: 'Version'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: fileTypeController,
                            decoration: const InputDecoration(labelText: 'File Type'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: sortOrderController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Sort Order'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: fileSizeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'File Size (bytes)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: lastUpdatedController,
                            readOnly: true,
                            decoration: const InputDecoration(labelText: 'Last Updated'),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                initialDate: lastUpdatedDate ?? DateTime.now(),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  lastUpdatedDate = picked;
                                  lastUpdatedController.text =
                                      picked.toLocal().toString().split(' ').first;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            children: [
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Visible'),
                                value: isVisible,
                                onChanged: (value) => setModalState(() => isVisible = value),
                              ),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Exec access only'),
                                value: requiresExecutiveAccess,
                                onChanged: (value) =>
                                    setModalState(() => requiresExecutiveAccess = value),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            if (titleController.text.trim().isEmpty) return;
                            final updated = base.copyWith(
                              title: titleController.text.trim(),
                              description: descriptionController.text.trim().isEmpty
                                  ? null
                                  : descriptionController.text.trim(),
                              resourceType: resourceType,
                              url: urlController.text.trim().isEmpty
                                  ? null
                                  : urlController.text.trim(),
                              storageUrl: storageUrlController.text.trim().isEmpty
                                  ? null
                                  : storageUrlController.text.trim(),
                              isVisible: isVisible,
                              sortOrder: int.tryParse(sortOrderController.text.trim()),
                              category: categoryController.text.trim().isEmpty
                                  ? null
                                  : categoryController.text.trim(),
                              iconUrl: iconUrlController.text.trim().isEmpty
                                  ? null
                                  : iconUrlController.text.trim(),
                              thumbnailUrl: thumbnailUrlController.text.trim().isEmpty
                                  ? null
                                  : thumbnailUrlController.text.trim(),
                              fileSizeBytes: int.tryParse(fileSizeController.text.trim()),
                              fileType: fileTypeController.text.trim().isEmpty
                                  ? null
                                  : fileTypeController.text.trim(),
                              version: versionController.text.trim().isEmpty
                                  ? null
                                  : versionController.text.trim(),
                              lastUpdatedDate: lastUpdatedDate,
                              requiresExecutiveAccess: requiresExecutiveAccess,
                            );

                            Navigator.pop(context, updated);
                          },
                          child: const Text('Save Resource'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              );
            },
          ),
        );
      },
      );
    } finally {
      titleController.dispose();
      descriptionController.dispose();
      urlController.dispose();
      storageUrlController.dispose();
      categoryController.dispose();
      iconUrlController.dispose();
      thumbnailUrlController.dispose();
      fileTypeController.dispose();
      versionController.dispose();
      sortOrderController.dispose();
      fileSizeController.dispose();
      lastUpdatedController.dispose();
    }

    if (result != null) {
      await _repository.savePortalResource(result);
      await _reloadResources();
      await _reloadStats();
    }
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
