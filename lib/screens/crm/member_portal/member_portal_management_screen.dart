import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:file_picker/file_picker.dart' as file_picker;

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/models/crm/meeting.dart';
import 'package:bluebubbles/models/crm/member_portal.dart';
import 'package:bluebubbles/screens/crm/editors/member_search_sheet.dart';
import 'package:bluebubbles/screens/crm/editors/meeting_attendance_edit_sheet.dart';
import 'package:bluebubbles/screens/crm/file_picker_materializer.dart';
import 'package:bluebubbles/services/crm/meeting_repository.dart';
import 'package:bluebubbles/services/crm/member_portal_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/utils/markdown_quill_loader.dart';
import 'package:bluebubbles/utils/quill_html_converter.dart';
import 'package:mime_type/mime_type.dart';

class MemberPortalManagementScreen extends StatefulWidget {
  const MemberPortalManagementScreen({super.key});

  @override
  State<MemberPortalManagementScreen> createState() => _MemberPortalManagementScreenState();
}

class _MemberPortalManagementScreenState extends State<MemberPortalManagementScreen>
    with SingleTickerProviderStateMixin {
  static const _unityBlue = Color(0xFF273351);
  static const _momentumBlue = Color(0xFF32A6DE);

  late final TabController _tabController = TabController(length: 6, vsync: this);
  final MemberPortalRepository _repository = MemberPortalRepository();
  final MeetingRepository _meetingRepository = MeetingRepository();
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

  String? _selectedMeetingId;
  String? _editingMeetingId;
  bool _savingMeeting = false;
  bool _meetingSaveSucceeded = false;
  String? _meetingSaveError;
  bool _selectedVisibleToAll = false;
  bool _selectedVisibleToAttendeesOnly = true;
  bool _selectedVisibleToExecutives = true;
  bool _selectedIsPublished = false;
  bool _selectedShowRecording = false;
  Meeting? _selectedMeetingDetails;
  bool _loadingMeetingDetails = false;
  String? _meetingDetailsError;
  quill.QuillController? _descriptionController;
  quill.QuillController? _summaryController;
  quill.QuillController? _keyPointsController;
  quill.QuillController? _actionItemsController;

  final TextEditingController _fieldVisibilitySearchController = TextEditingController();
  final Set<String> _selectedFieldCategories = {};

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
    _disposeMeetingControllers();
    _resourceSearchController.dispose();
    _fieldVisibilitySearchController.dispose();
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
          final selectedMeeting = _resolveSelectedMeeting(meetings);

          if (selectedMeeting != null && _editingMeetingId != selectedMeeting.id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _selectMeeting(selectedMeeting);
              }
            });
          }

          if (meetings.isEmpty) {
            return const Center(child: Text('No meetings found.'));
          }

          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/Blue-Gradient-Background.png',
                  fit: BoxFit.cover,
                ),
              ),
              Positioned.fill(
                child: Container(
                  color: Colors.white.withOpacity(0.18),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMeetingManagementHeader(meetings.length),
                      const SizedBox(height: 12),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 1000;
                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    height: 320,
                                    child: _buildMeetingList(meetings, selectedMeeting),
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: selectedMeeting == null
                                        ? _buildMeetingPlaceholder()
                                        : _buildMeetingEditor(selectedMeeting),
                                  ),
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: _buildMeetingList(meetings, selectedMeeting),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 6,
                                  child: selectedMeeting == null
                                      ? _buildMeetingPlaceholder()
                                      : _buildMeetingEditor(selectedMeeting),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  MemberPortalMeeting? _resolveSelectedMeeting(List<MemberPortalMeeting> meetings) {
    if (meetings.isEmpty) return null;

    for (final meeting in meetings) {
      if (meeting.id == _selectedMeetingId) return meeting;
    }

    return meetings.first;
  }

  void _selectMeeting(MemberPortalMeeting meeting) {
    _disposeMeetingControllers();
    final descriptionDoc = _controllerFromHtml(meeting.memberDescription);
    final summaryDoc = _controllerFromHtml(meeting.memberSummary);
    final keyPointsDoc = _controllerFromHtml(meeting.memberKeyPoints);
    final actionItemsDoc = _controllerFromHtml(meeting.memberActionItems);

    setState(() {
      _editingMeetingId = meeting.id;
      _selectedMeetingId = meeting.id;
      _selectedVisibleToAll = meeting.visibleToAll;
      _selectedVisibleToAttendeesOnly = meeting.visibleToAttendeesOnly;
      _selectedVisibleToExecutives = meeting.visibleToExecutives;
      _selectedIsPublished = meeting.isPublished;
      _selectedShowRecording = meeting.showRecording ?? false;
      _meetingSaveError = null;
      _meetingSaveSucceeded = false;
      _descriptionController = descriptionDoc;
      _summaryController = summaryDoc;
      _keyPointsController = keyPointsDoc;
      _actionItemsController = actionItemsDoc;
      _meetingDetailsError = null;
    });

    _loadMeetingDetails(meeting);
  }

  quill.QuillController _controllerFromHtml(String? html) {
    final trimmed = html?.trim() ?? '';
    final document = trimmed.isEmpty
        ? quill.Document()
        : MarkdownQuillLoader.fromHtml(trimmed);

    return quill.QuillController(
      document: document,
      selection: TextSelection.collapsed(offset: document.length),
    );
  }

  Future<void> _loadMeetingDetails(MemberPortalMeeting meeting) async {
    if (meeting.meetingId.isEmpty) {
      setState(() {
        _selectedMeetingDetails = null;
        _meetingDetailsError = 'Meeting record is missing an ID.';
      });
      return;
    }

    setState(() {
      _loadingMeetingDetails = true;
      _meetingDetailsError = null;
    });

    try {
      final details = await _meetingRepository.getMeetingById(meeting.meetingId);
      if (!mounted) return;
      setState(() {
        _selectedMeetingDetails = details;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _meetingDetailsError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingMeetingDetails = false;
        });
      }
    }
  }

  void _disposeMeetingControllers() {
    _descriptionController?.dispose();
    _summaryController?.dispose();
    _keyPointsController?.dispose();
    _actionItemsController?.dispose();
    _descriptionController = null;
    _summaryController = null;
    _keyPointsController = null;
    _actionItemsController = null;
  }

  Widget _buildMeetingManagementHeader(int meetingCount) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _momentumBlue,
          ),
          padding: const EdgeInsets.all(10),
          child: const Icon(Icons.video_camera_front_outlined, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Member Portal Meetings',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                meetingCount == 1
                    ? '1 meeting ready to curate for the portal.'
                    : '$meetingCount meetings ready to curate for the portal.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: _reloadMeetings,
        ),
      ],
    );
  }

  Widget _buildMeetingList(
    List<MemberPortalMeeting> meetings,
    MemberPortalMeeting? selectedMeeting,
  ) {
    return Card(
      color: Colors.white.withOpacity(0.86),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (context, index) {
          final meeting = meetings[index];
          final isSelected = meeting.id == selectedMeeting?.id;
          return _buildMeetingCard(meeting, isSelected);
        },
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemCount: meetings.length,
      ),
    );
  }

  Widget _buildMeetingCard(MemberPortalMeeting meeting, bool isSelected) {
    final theme = Theme.of(context);
    final attendeeLabel = meeting.attendeeCount != null ? '${meeting.attendeeCount} attendees' : 'Attendance TBD';
    final meetingDateLabel = meeting.meetingDate != null
        ? '${meeting.meetingDate!.toLocal().toString().split(' ').first}'
        : 'Date TBD';

    return Card(
      color: _unityBlue,
      elevation: isSelected ? 6 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _selectMeeting(meeting),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meeting.memberTitle.isNotEmpty
                          ? meeting.memberTitle
                          : meeting.meetingTitle ?? 'Meeting',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildChip(Icons.calendar_month_outlined, meetingDateLabel),
                        _buildChip(Icons.groups_outlined, attendeeLabel),
                        _buildChip(
                          meeting.isPublished ? Icons.check_circle : Icons.drafts,
                          meeting.isPublished
                              ? (meeting.visibleToAll
                                  ? 'Published · All'
                                  : meeting.visibleToExecutives
                                      ? 'Published · Exec/Attendees'
                                      : 'Published · Attendees')
                              : 'Draft',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingPlaceholder() {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 36, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'Select a meeting to edit the minutes members see in the portal.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingEditor(MemberPortalMeeting meeting) {
    if (_descriptionController == null ||
        _summaryController == null ||
        _keyPointsController == null ||
        _actionItemsController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final statusColor = _meetingSaveSucceeded
        ? Colors.green
        : _meetingSaveError != null
            ? theme.colorScheme.error
            : theme.colorScheme.outline;
    final details = _selectedMeetingDetails;
    final meetingDate = details?.meetingDate ?? meeting.meetingDate;
    final attendance = details?.attendance ?? const <MeetingAttendance>[];
    final attendeeCount = attendance.isNotEmpty ? attendance.length : meeting.attendeeCount;
    final recordingEmbedUrl = details?.recordingEmbedUrl ?? meeting.recordingEmbedUrl;
    final recordingUrl = details?.recordingUrl ?? meeting.recordingUrl;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          child: DefaultTextStyle.merge(
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: 8),
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
                          Text(
                            meeting.memberTitle.isNotEmpty
                                ? meeting.memberTitle
                                : meeting.meetingTitle ?? 'Meeting',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            meetingDate != null
                                ? 'Meeting date: ${meetingDate.toLocal().toString().split(' ').first}'
                                : 'Meeting date TBD',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Published'),
                            Switch.adaptive(
                              value: _selectedIsPublished,
                              onChanged: (value) => setState(() => _selectedIsPublished = value),
                              activeColor: Colors.white,
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Show recording'),
                            Switch.adaptive(
                              value: _selectedShowRecording,
                              onChanged: (value) => setState(() => _selectedShowRecording = value),
                              activeColor: Colors.white,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMeetingPill(
                      icon: Icons.calendar_month_outlined,
                      label: meetingDate != null
                          ? meetingDate.toLocal().toString().split(' ').first
                          : 'Date TBD',
                    ),
                    _buildMeetingPill(
                      icon: Icons.groups_outlined,
                      label: attendeeCount != null
                          ? '$attendeeCount attendees'
                          : 'Attendance pending',
                    ),
                    _buildMeetingPill(
                      icon: meeting.isPublished ? Icons.check_circle : Icons.drafts,
                      label: meeting.isPublished
                          ? (meeting.visibleToAll
                              ? 'Published · All'
                              : meeting.visibleToExecutives
                                  ? 'Published · Exec/Attendees'
                                  : 'Published · Attendees')
                          : 'Draft',
                    ),
                    _buildMeetingPill(
                      icon: _selectedShowRecording ? Icons.play_circle : Icons.play_disabled,
                      label: _selectedShowRecording ? 'Recording visible' : 'Recording hidden',
                    ),
                  ],
                ),
                if (_meetingDetailsError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _meetingDetailsError!,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange.shade200),
                  ),
                ],
                if (_loadingMeetingDetails)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: Colors.white24,
                      color: Colors.white,
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildVisibilityCheckbox(
                      label: 'Visible to all members',
                      value: _selectedVisibleToAll,
                      onChanged: (value) => setState(() {
                        _selectedVisibleToAll = value ?? false;
                      }),
                    ),
                    _buildVisibilityCheckbox(
                      label: 'Visible to attendees only',
                      value: _selectedVisibleToAttendeesOnly,
                      onChanged: (value) => setState(() {
                        _selectedVisibleToAttendeesOnly = value ?? false;
                      }),
                    ),
                    _buildVisibilityCheckbox(
                      label: 'Visible to executives',
                      value: _selectedVisibleToExecutives,
                      onChanged: (value) => setState(() {
                        _selectedVisibleToExecutives = value ?? true;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildAttendanceSection(meeting, attendance, attendeeCount ?? 0),
                const SizedBox(height: 12),
                _buildRecordingSection(recordingEmbedUrl, recordingUrl),
                const SizedBox(height: 12),
                _buildRichTextSection(
                  title: 'Description',
                  helper: 'Shows at the top of the meeting page for members.',
                  controller: _descriptionController!,
                ),
                const SizedBox(height: 12),
                _buildRichTextSection(
                  title: 'Summary',
                  helper: 'Short recap of what happened.',
                  controller: _summaryController!,
                ),
                const SizedBox(height: 12),
                _buildRichTextSection(
                  title: 'Key Points',
                  helper: 'Bulleted discussion highlights.',
                  controller: _keyPointsController!,
                ),
                const SizedBox(height: 12),
                _buildRichTextSection(
                  title: 'Action Items',
                  helper: 'Next steps members should see.',
                  controller: _actionItemsController!,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_meetingSaveError != null || _meetingSaveSucceeded)
                      Row(
                        children: [
                          Icon(
                            _meetingSaveSucceeded ? Icons.check_circle : Icons.error_outline,
                            color: statusColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _meetingSaveSucceeded
                                ? 'Saved'
                                : 'Save failed: ${_meetingSaveError}',
                            style: theme.textTheme.bodyMedium?.copyWith(color: statusColor),
                          ),
                        ],
                      ),
                    const Spacer(),
                    ElevatedButton.icon(
                      icon: _savingMeeting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_savingMeeting ? 'Saving...' : 'Save changes'),
                      onPressed: _savingMeeting ? null : () => _saveMeeting(meeting),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _unityBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeetingPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildRecordingSection(String? recordingEmbedUrl, String? recordingUrl) {
    if (!_selectedShowRecording) {
      return Card(
        color: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: const ListTile(
          leading: Icon(Icons.play_disabled, color: Colors.white70),
          title: Text('Recording is hidden for members', style: TextStyle(color: Colors.white)),
          subtitle: Text(
            'Enable "Show recording" to surface the embed on the portal.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Card(
      color: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: const Icon(Icons.play_circle, color: Colors.white),
        title: Text(
          recordingEmbedUrl?.isNotEmpty == true
              ? 'Embed URL ready for members'
              : 'Recording embed URL missing',
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recordingEmbedUrl != null && recordingEmbedUrl.isNotEmpty)
              SelectableText(
                recordingEmbedUrl,
                style: const TextStyle(color: Colors.white70),
              )
            else
              const Text(
                'Add an embed URL to the meeting in Supabase to stream the recording.',
                style: TextStyle(color: Colors.white70),
              ),
            if (recordingUrl != null && recordingUrl.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Fallback URL: $recordingUrl',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceSection(
    MemberPortalMeeting meeting,
    List<MeetingAttendance> attendance,
    int attendeeCount,
  ) {
    return Card(
      color: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Attendance',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      attendeeCount == 1
                          ? '1 member attended'
                          : '$attendeeCount members attended',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _loadingMeetingDetails
                      ? null
                      : () => _addMemberToAttendance(meeting),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(_loadingMeetingDetails ? 'Working...' : 'Add attendee'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingMeetingDetails)
              const LinearProgressIndicator(minHeight: 3),
            if (!_loadingMeetingDetails && attendance.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, color: Colors.white54),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No attendees have been linked yet. Add members to mirror the official attendance list.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: attendance.length,
                separatorBuilder: (_, __) => const Divider(height: 8),
                itemBuilder: (context, index) {
                  final record = attendance[index];
                  return _buildAttendanceTile(record);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceTile(MeetingAttendance attendance) {
    final subtitleParts = <String>[];
    subtitleParts.add(attendance.durationSummary);
    if (attendance.joinWindow != null) subtitleParts.add(attendance.joinWindow!);
    if (attendance.zoomEmail != null && attendance.zoomEmail!.isNotEmpty) {
      subtitleParts.add(attendance.zoomEmail!);
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        backgroundColor: attendance.checkedIn == true ? _momentumBlue : Colors.grey.shade800,
        foregroundColor: Colors.white,
        child: Text(attendance.participantName.isNotEmpty
            ? attendance.participantName.substring(0, 1).toUpperCase()
            : '?'),
      ),
      title: Text(
        attendance.participantName,
        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
      ),
      subtitle: Text(subtitleParts.join(' • '), style: const TextStyle(color: Colors.white70)),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            color: Colors.white70,
            tooltip: 'Edit attendance',
            onPressed: () => _editAttendance(attendance),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: Colors.white70,
            tooltip: 'Remove attendee',
            onPressed: () => _removeAttendance(attendance),
          ),
        ],
      ),
    );
  }

  Future<void> _addMemberToAttendance(MemberPortalMeeting meeting) async {
    final member = await showMemberSearchSheet(context);
    if (member == null || meeting.meetingId.isEmpty) return;

    setState(() => _loadingMeetingDetails = true);
    try {
      final created = await _meetingRepository.upsertAttendance(
        meetingId: meeting.meetingId,
        memberId: member.id,
        zoomDisplayName: member.name,
      );
      if (created != null) {
        _updateAttendanceState(created);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.name} added to attendance.')),
        );
        setState(() {
          _meetingsFuture = _repository.fetchPortalMeetings();
        });
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to add attendee: $error')),
      );
    } finally {
      if (mounted) setState(() => _loadingMeetingDetails = false);
    }
  }

  Future<void> _editAttendance(MeetingAttendance attendance) async {
    final updated = await showModalBottomSheet<MeetingAttendance>(
      context: context,
      isScrollControlled: true,
      builder: (context) => MeetingAttendanceEditSheet(attendance: attendance),
    );

    if (updated != null) {
      _updateAttendanceState(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${updated.participantName} updated.')),
      );
    }
  }

  Future<void> _removeAttendance(MeetingAttendance attendance) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove attendee?'),
        content: Text('Remove ${attendance.participantName} from this meeting?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loadingMeetingDetails = true);
    try {
      await _meetingRepository.deleteAttendance(attendance.id);
      _updateAttendanceState(attendance, remove: true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${attendance.participantName} removed.')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to remove attendee: $error')),
      );
    } finally {
      if (mounted) setState(() => _loadingMeetingDetails = false);
    }
  }

  void _updateAttendanceState(MeetingAttendance attendance, {bool remove = false}) {
    final current = _selectedMeetingDetails;
    if (current == null) return;

    final updatedList = current.attendance.toList();
    if (remove) {
      updatedList.removeWhere((item) => item.id == attendance.id);
    } else {
      final existingIndex = updatedList.indexWhere((item) => item.id == attendance.id);
      if (existingIndex >= 0) {
        updatedList[existingIndex] = attendance;
      } else {
        updatedList.add(attendance);
      }
    }

    updatedList.sort((a, b) {
      final aDate = a.firstJoinTime ?? a.meetingDate;
      final bDate = b.firstJoinTime ?? b.meetingDate;
      if (aDate == null || bDate == null) return a.participantName.compareTo(b.participantName);
      return bDate.compareTo(aDate);
    });

    setState(() {
      _selectedMeetingDetails = current.copyWith(
        attendance: updatedList,
        attendanceCount: updatedList.length + current.nonMemberAttendees.length,
      );
    });
  }

  Widget _buildVisibilityCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: CheckboxListTile(
          value: value,
          onChanged: onChanged,
          title: Text(label),
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildRichTextSection({
    required String title,
    required String helper,
    required quill.QuillController controller,
  }) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final shared = quill.QuillSharedConfigurations(locale: locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(helper, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
            color: Colors.white,
          ),
          child: Column(
            children: [
              quill.QuillToolbar.simple(
                configurations: quill.QuillSimpleToolbarConfigurations(
                  controller: controller,
                  sharedConfigurations: shared,
                  multiRowsDisplay: false,
                  showFontSize: false,
                  showBackgroundColorButton: false,
                  showDividers: false,
                  showSearchButton: false,
                  toolbarSize: 36,
                  showAlignmentButtons: false,
                  showQuote: false,
                  showInlineCode: false,
                  showSmallButton: false,
                  showSuperscript: false,
                  showSubscript: false,
                  showDirection: false,
                ),
              ),
              const Divider(height: 1),
              SizedBox(
                height: 180,
                child: quill.QuillEditor(
                  focusNode: FocusNode(),
                  scrollController: ScrollController(),
                  configurations: quill.QuillEditorConfigurations(
                    controller: controller,
                    sharedConfigurations: shared,
                    scrollable: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    expands: false,
                    checkBoxReadOnly: false,
                    keyboardAppearance: Theme.of(context).brightness,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _saveMeeting(MemberPortalMeeting meeting) async {
    setState(() {
      _savingMeeting = true;
      _meetingSaveError = null;
      _meetingSaveSucceeded = false;
    });

    try {
      final updatedMeeting = meeting.copyWith(
        visibleToAll: _selectedVisibleToAll,
        visibleToAttendeesOnly: _selectedVisibleToAttendeesOnly,
        visibleToExecutives: _selectedVisibleToExecutives,
        isPublished: _selectedIsPublished,
        showRecording: _selectedShowRecording,
        memberDescription: _generateHtml(_descriptionController),
        memberSummary: _generateHtml(_summaryController),
        memberKeyPoints: _generateHtml(_keyPointsController),
        memberActionItems: _generateHtml(_actionItemsController),
      );

      final savedMeeting = await _repository.savePortalMeeting(updatedMeeting);
      if (savedMeeting != null) {
        setState(() {
          _meetingSaveSucceeded = true;
          _selectedMeetingId = savedMeeting.id;
          _editingMeetingId = savedMeeting.id;
          _meetingsFuture = _repository.fetchPortalMeetings();
          _statsFuture = _repository.fetchDashboardStats();
        });
      } else {
        setState(() {
          _meetingSaveError = 'Save did not return updated data.';
        });
      }
    } catch (e) {
      setState(() {
        _meetingSaveError = e.toString();
      });
    } finally {
      setState(() {
        _savingMeeting = false;
      });
    }
  }

  String _generateHtml(quill.QuillController? controller) {
    if (controller == null) return '';
    final delta = controller.document.toDelta().toJson();
    final plainText = controller.document.toPlainText();
    return QuillHtmlConverter.generateHtml(delta, plainText);
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
    PlatformFile? pendingFile;
    bool savingResource = false;
    String? errorText;

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
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: savingResource
                                ? null
                                : () async {
                                    final result = await file_picker.FilePicker.platform.pickFiles(withData: true);
                                    if (result == null || result.files.isEmpty) return;
                                    final materialized = await materializePickedPlatformFile(
                                      result.files.first,
                                      source: result,
                                    );
                                    if (materialized != null) {
                                      setModalState(() {
                                        pendingFile = materialized;
                                        fileSizeController.text = materialized.size.toString();
                                        fileTypeController.text = mime(materialized.name) ??
                                            fileTypeController.text;
                                      });
                                    }
                                  },
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: const Text('Upload to portal storage'),
                          ),
                        ),
                        if (pendingFile != null) ...[
                          const SizedBox(width: 12),
                          Chip(
                            label: Text(pendingFile!.name),
                            onDeleted: savingResource
                                ? null
                                : () => setModalState(() => pendingFile = null),
                          ),
                        ],
                      ],
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
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          errorText!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: savingResource
                              ? null
                              : () async {
                                  final title = titleController.text.trim();
                                  if (title.isEmpty) {
                                    setModalState(
                                        () => errorText = 'Title is required to save this resource.');
                                    return;
                                  }

                                  setModalState(() {
                                    savingResource = true;
                                    errorText = null;
                                  });

                                  try {
                                    Map<String, dynamic>? upload;
                                    if (pendingFile != null) {
                                      upload = await _repository.uploadResourceFile(pendingFile!);
                                    }

                                    final updated = base.copyWith(
                                      title: title,
                                      description: descriptionController.text.trim().isEmpty
                                          ? null
                                          : descriptionController.text.trim(),
                                      resourceType: resourceType,
                                      url: urlController.text.trim().isEmpty
                                          ? (upload?['url'] as String?)
                                          : urlController.text.trim(),
                                      storageUrl: upload?['storage_url'] as String? ??
                                          (storageUrlController.text.trim().isEmpty
                                              ? null
                                              : storageUrlController.text.trim()),
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
                                      fileSizeBytes:
                                          upload?['file_size_bytes'] as int? ?? int.tryParse(fileSizeController.text.trim()),
                                      fileType: upload?['file_type'] as String? ??
                                          (fileTypeController.text.trim().isEmpty
                                              ? null
                                              : fileTypeController.text.trim()),
                                      version: versionController.text.trim().isEmpty
                                          ? null
                                          : versionController.text.trim(),
                                      lastUpdatedDate: lastUpdatedDate,
                                      requiresExecutiveAccess: requiresExecutiveAccess,
                                    );

                                    if (!mounted) return;
                                    Navigator.pop(context, updated);
                                  } catch (error) {
                                    setModalState(() {
                                      errorText = 'Failed to save resource: $error';
                                      savingResource = false;
                                    });
                                  }
                                },
                          child: Text(savingResource ? 'Saving...' : 'Save Resource'),
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

          final query = _fieldVisibilitySearchController.text.trim().toLowerCase();
          final filtered = fields.where((field) {
            final categoryLabel = field.fieldCategory?.isNotEmpty == true ? field.fieldCategory! : 'Other';
            final matchesCategory =
                _selectedFieldCategories.isEmpty || _selectedFieldCategories.contains(categoryLabel);
            final matchesQuery = query.isEmpty ||
                field.displayLabel.toLowerCase().contains(query) ||
                field.fieldName.toLowerCase().contains(query);
            return matchesCategory && matchesQuery;
          }).toList();

          final categories = fields
              .map((field) => field.fieldCategory?.isNotEmpty == true ? field.fieldCategory! : 'Other')
              .toSet()
            ..removeWhere((element) => element.isEmpty);

          final grouped = <String, List<MemberPortalFieldVisibility>>{};
          for (final field in filtered) {
            final category = field.fieldCategory?.isNotEmpty == true ? field.fieldCategory! : 'Other';
            grouped.putIfAbsent(category, () => []).add(field);
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
                          Expanded(
                            child: TextField(
                              controller: _fieldVisibilitySearchController,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                labelText: 'Search fields',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: filtered.isEmpty
                                ? null
                                : () => _applyBulkVisibility(filtered, visible: true),
                            icon: const Icon(Icons.visibility),
                            label: const Text('Show all'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: filtered.isEmpty
                                ? null
                                : () => _applyBulkVisibility(filtered, visible: false),
                            icon: const Icon(Icons.visibility_off),
                            label: const Text('Hide all'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categories
                            .map(
                              (category) => FilterChip(
                                label: Text(category),
                                selected: _selectedFieldCategories.contains(category),
                                onSelected: (selected) => setState(() {
                                  if (selected) {
                                    _selectedFieldCategories.add(category);
                                  } else {
                                    _selectedFieldCategories.remove(category);
                                  }
                                }),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: Text('No fields match your filters.')),
                )
              else
                ...grouped.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildFieldVisibilityGroup(entry.key, entry.value),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFieldVisibilityGroup(
    String category,
    List<MemberPortalFieldVisibility> fields,
  ) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  category,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _applyBulkVisibility(fields, editable: true),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Mark editable'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _applyBulkVisibility(fields, editable: false),
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Lock'),
                ),
              ],
            ),
            const Divider(),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: fields
                  .map(
                    (field) => SizedBox(
                      width: 320,
                      child: _buildFieldVisibilityCard(field),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldVisibilityCard(MemberPortalFieldVisibility field) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(field.displayLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(field.fieldName, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SwitchListTile.adaptive(
                  value: field.isVisible,
                  title: const Text('Visible'),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) => _saveFieldVisibility(field.copyWith(isVisible: value)),
                ),
              ),
              Expanded(
                child: SwitchListTile.adaptive(
                  value: field.isEditable,
                  title: const Text('Editable'),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) => _saveFieldVisibility(field.copyWith(isEditable: value)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _applyBulkVisibility(
    List<MemberPortalFieldVisibility> targets, {
    bool? visible,
    bool? editable,
  }) async {
    for (final field in targets) {
      await _repository.saveFieldVisibility(
        field.copyWith(
          isVisible: visible ?? field.isVisible,
          isEditable: editable ?? field.isEditable,
        ),
      );
    }
    await _reloadFieldVisibility();
  }

  Future<void> _saveFieldVisibility(MemberPortalFieldVisibility field) async {
    await _repository.saveFieldVisibility(field);
    await _reloadFieldVisibility();
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
