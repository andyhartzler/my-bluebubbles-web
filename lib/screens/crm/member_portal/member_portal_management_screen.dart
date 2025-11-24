import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:characters/characters.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/models/crm/meeting.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/member_portal.dart';
import 'package:bluebubbles/screens/crm/editors/member_search_sheet.dart';
import 'package:bluebubbles/screens/crm/editors/meeting_attendance_edit_sheet.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/screens/crm/meeting_detail_screen.dart' show MeetingRecordingEmbed;
import 'package:bluebubbles/screens/crm/file_picker_materializer.dart';
import 'package:bluebubbles/services/crm/meeting_repository.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
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

enum _MeetingSwitchAction { save, discard, cancel }

class _MemberPortalManagementScreenState extends State<MemberPortalManagementScreen>
    with SingleTickerProviderStateMixin {
  static const _unityBlue = Color(0xFF273351);
  static const _momentumBlue = Color(0xFF32A6DE);

  late final TabController _tabController = TabController(length: 6, vsync: this);
  final MemberPortalRepository _repository = MemberPortalRepository();
  final MeetingRepository _meetingRepository = MeetingRepository();
  final MemberRepository _memberRepository = MemberRepository();
  final CRMSupabaseService _supabase = CRMSupabaseService();
  final DateFormat _signInFormat = DateFormat('MMM d, y • h:mm a');

  late Future<MemberPortalDashboardStats> _statsFuture;
  late Future<List<MemberPortalRecentSignIn>> _recentSignInsFuture;
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
  MemberPortalMeeting? _currentMeeting;
  bool _savingMeeting = false;
  bool _meetingSaveSucceeded = false;
  String? _meetingSaveError;
  bool _meetingHasUnsavedChanges = false;
  bool _selectedVisibleToAll = false;
  bool _selectedVisibleToAttendeesOnly = true;
  bool _selectedVisibleToExecutives = true;
  bool _selectedIsPublished = false;
  bool _selectedShowRecording = false;
  bool _recordingExpanded = false;
  Meeting? _selectedMeetingDetails;
  bool _loadingMeetingDetails = false;
  String? _meetingDetailsError;
  quill.QuillController? _descriptionController;
  quill.QuillController? _summaryController;
  quill.QuillController? _keyPointsController;
  quill.QuillController? _actionItemsController;

  final TextEditingController _fieldVisibilitySearchController = TextEditingController();
  final Set<String> _selectedFieldCategories = {};
  String _profileChangeStatus = 'pending';
  String? _profileChangesError;

  @override
  void initState() {
    super.initState();
    _statsFuture = _repository.fetchDashboardStats();
    _recentSignInsFuture = _repository.fetchRecentSignIns();
    _meetingsFuture = _repository.fetchPortalMeetings();
    _eventsFuture = _repository.fetchMemberSubmittedEvents(status: 'pending');
    _resourcesFuture = _repository.fetchPortalResources();
    _profileChangesFuture = _repository.fetchProfileChanges(status: _profileChangeStatus);
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
      _recentSignInsFuture = _repository.fetchRecentSignIns();
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
      _profileChangesError = null;
      _profileChangesFuture = _repository.fetchProfileChanges(
        status: _profileChangeStatus == 'all' ? null : _profileChangeStatus,
      );
      _statsFuture = _repository.fetchDashboardStats();
    });
  }

  Future<void> _reloadFieldVisibility() async {
    setState(() {
      _fieldVisibilityFuture = _repository.fetchFieldVisibility();
    });
  }

  void _markMeetingDirty() {
    if (_meetingHasUnsavedChanges) return;
    setState(() {
      _meetingHasUnsavedChanges = true;
      _meetingSaveSucceeded = false;
    });
  }

  void _attachEditorListeners() {
    _descriptionController?.addListener(_markMeetingDirty);
    _summaryController?.addListener(_markMeetingDirty);
    _keyPointsController?.addListener(_markMeetingDirty);
    _actionItemsController?.addListener(_markMeetingDirty);
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
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _reloadStats,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B2336), Color(0xFF0F1624)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: ListView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.all(24),
              children: [
                FutureBuilder<MemberPortalDashboardStats>(
                  future: _statsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final stats = snapshot.data ?? MemberPortalDashboardStats.empty;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF273351), Color(0xFF32A6DE)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Member Portal Dashboard',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Monitor portal activity and keep members up to date.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: [
                                  _buildStatCard('Pending Profile Changes', stats.pendingProfileChanges, Icons.fact_check),
                                  _buildStatCard('Pending Event Submissions', stats.pendingEventSubmissions, Icons.event_note),
                                  _buildStatCard('Published Meetings', stats.publishedMeetings,
                                      Icons.video_camera_front_outlined),
                                  _buildStatCard('Visible Resources', stats.visibleResources, Icons.folder_open),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildRecentSignInsCard(),
                        const SizedBox(height: 24),
                        Text(
                          'Use the tabs above to approve submissions, publish meeting minutes, and manage resources.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
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

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Failed to load meetings: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
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

  Future<_MeetingSwitchAction?> _promptForUnsavedChanges() {
    return showDialog<_MeetingSwitchAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save changes?'),
        content:
            const Text('You have unsaved edits for this meeting. What would you like to do?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_MeetingSwitchAction.discard),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_MeetingSwitchAction.cancel),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_MeetingSwitchAction.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _onMeetingTapped(MemberPortalMeeting meeting) async {
    if (_currentMeeting != null &&
        _meetingHasUnsavedChanges &&
        meeting.id != _currentMeeting!.id) {
      final action = await _promptForUnsavedChanges();
      if (action == null || action == _MeetingSwitchAction.cancel) return;
      if (action == _MeetingSwitchAction.save) {
        await _saveMeeting(_currentMeeting!);
      }
    }

    if (!mounted) return;
    _selectMeeting(meeting);
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
      _recordingExpanded = false;
      _meetingSaveError = null;
      _meetingSaveSucceeded = false;
      _meetingHasUnsavedChanges = false;
      _currentMeeting = meeting;
      _descriptionController = descriptionDoc;
      _summaryController = summaryDoc;
      _keyPointsController = keyPointsDoc;
      _actionItemsController = actionItemsDoc;
      _meetingDetailsError = null;
    });

    _attachEditorListeners();

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
    _descriptionController?.removeListener(_markMeetingDirty);
    _summaryController?.removeListener(_markMeetingDirty);
    _keyPointsController?.removeListener(_markMeetingDirty);
    _actionItemsController?.removeListener(_markMeetingDirty);
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
      color: Colors.black.withOpacity(0.25),
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
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
    final selectedDetails = _selectedMeetingDetails;
    final effectiveAttendeeCount = meeting.attendeeCount ??
        (selectedDetails != null && selectedDetails.id == meeting.meetingId
            ? selectedDetails.attendanceCount
            : null);
    final attendeeLabel = effectiveAttendeeCount != null
        ? '$effectiveAttendeeCount attendee${effectiveAttendeeCount == 1 ? '' : 's'}'
        : 'Attendance TBD';
    final effectiveDate = meeting.meetingDate ??
        (selectedDetails != null && selectedDetails.id == meeting.meetingId
            ? selectedDetails.meetingDate
            : null) ??
        meeting.createdAt;
    final meetingDateLabel = DateFormat('MMM d, y').format(effectiveDate.toLocal());

    return Card(
      color: _unityBlue,
      elevation: isSelected ? 6 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _onMeetingTapped(meeting),
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
                                  onChanged: (value) => setState(() {
                                    _selectedIsPublished = value;
                                    _markMeetingDirty();
                                  }),
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
                                  onChanged: (value) => setState(() {
                                    _selectedShowRecording = value;
                                    _markMeetingDirty();
                                  }),
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (_meetingHasUnsavedChanges)
                          Row(
                            children: [
                              const Icon(Icons.edit, color: Colors.amberAccent),
                              const SizedBox(width: 6),
                              Text(
                                'Unsaved changes',
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.amberAccent),
                              ),
                            ],
                          )
                        else if (_meetingSaveError != null || _meetingSaveSucceeded)
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
                            _markMeetingDirty();
                          }),
                        ),
                        _buildVisibilityCheckbox(
                          label: 'Visible to attendees only',
                          value: _selectedVisibleToAttendeesOnly,
                          onChanged: (value) => setState(() {
                            _selectedVisibleToAttendeesOnly = value ?? false;
                            _markMeetingDirty();
                          }),
                        ),
                        _buildVisibilityCheckbox(
                          label: 'Visible to executives',
                          value: _selectedVisibleToExecutives,
                          onChanged: (value) => setState(() {
                            _selectedVisibleToExecutives = value ?? true;
                            _markMeetingDirty();
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
                  ],
                ),
              ),
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
    final hasEmbed = recordingEmbedUrl?.isNotEmpty == true;
    final embedUri = hasEmbed ? Uri.tryParse(recordingEmbedUrl!) : null;

    return Card(
      color: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        initiallyExpanded: _recordingExpanded && hasEmbed,
        onExpansionChanged: (expanded) => setState(() => _recordingExpanded = expanded),
        leading: Icon(
          _selectedShowRecording ? Icons.play_circle : Icons.play_disabled,
          color: Colors.white,
        ),
        title: Text(
          !_selectedShowRecording
              ? 'Recording is hidden for members'
              : hasEmbed
                  ? 'Recording embed ready'
                  : 'Recording embed URL missing',
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          !_selectedShowRecording
              ? 'Enable "Show recording" to surface the embed on the portal.'
              : hasEmbed
                  ? 'Tap to preview the embedded player.'
                  : 'Add an embed URL in Supabase to stream the recording.',
          style: const TextStyle(color: Colors.white70),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (_selectedShowRecording && hasEmbed && embedUri != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 320,
                child: MeetingRecordingEmbed(uri: embedUri),
              ),
            )
          else if (_selectedShowRecording)
            const Text(
              'No valid embed URL was provided.',
              style: TextStyle(color: Colors.white70),
            ),
          if (recordingUrl != null && recordingUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            SelectableText(
              'Fallback URL: $recordingUrl',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ],
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
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: CheckboxListTile(
          value: value,
          onChanged: onChanged,
          title: Text(
            label,
            style: const TextStyle(color: Colors.white),
          ),
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: _momentumBlue,
          checkColor: Colors.white,
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
        Text(helper, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
            color: Colors.grey.shade900,
          ),
          child: Column(
            children: [
              Theme(
                data: theme.copyWith(
                  iconTheme: const IconThemeData(color: Colors.white),
                  tooltipTheme: theme.tooltipTheme.copyWith(textStyle: const TextStyle(color: Colors.white)),
                ),
                child: quill.QuillToolbar.simple(
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
                    buttonOptions: quill.QuillSimpleToolbarButtonOptions(
                      base: quill.QuillToolbarBaseButtonOptions(
                        iconTheme: quill.QuillIconTheme(
                          iconButtonUnselectedData: const quill.IconButtonData(
                            color: Colors.white70,
                          ),
                          iconButtonSelectedData: quill.IconButtonData(
                            color: Colors.white,
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF273351),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              SizedBox(
                height: 180,
                child: DefaultTextStyle.merge(
                  style: const TextStyle(color: Colors.white),
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
          _meetingHasUnsavedChanges = false;
          _currentMeeting = savedMeeting;
        });
        _selectMeeting(savedMeeting);
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

  String _formatRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    if (difference.inDays < 30) return '${(difference.inDays / 7).floor()}w ago';
    return '${(difference.inDays / 30).floor()}mo ago';
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
    const statuses = ['pending', 'approved', 'rejected', 'all'];

    return RefreshIndicator(
      onRefresh: _reloadProfileChanges,
      child: FutureBuilder<List<MemberProfileChange>>(
        future: _profileChangesFuture,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          _profileChangesError = snapshot.error?.toString();
          final changes = snapshot.data ?? const [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: statuses
                    .map(
                      (status) => ChoiceChip(
                        label: Text(status[0].toUpperCase() + status.substring(1)),
                        selected: _profileChangeStatus == status,
                        onSelected: (selected) {
                          if (!selected) return;
                          setState(() {
                            _profileChangeStatus = status;
                          });
                          _reloadProfileChanges();
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              if (isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else if (_profileChangesError != null)
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text('Unable to load profile changes: $_profileChangesError'),
                )
              else if (changes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('No profile changes found for this status.'),
                )
              else
                ...changes.map(_buildProfileChangeCard),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileChangeCard(MemberProfileChange change) {
    final statusColor = switch (change.status) {
      'approved' => Colors.green,
      'rejected' => Colors.red,
      _ => Colors.amber,
    };

    final displayName = (change.memberName?.trim().isNotEmpty == true)
        ? change.memberName!.trim()
        : 'Member';
    final avatarSeed = displayName.isNotEmpty ? displayName : change.memberId;
    final avatarLetter = avatarSeed.isNotEmpty ? avatarSeed.characters.first.toUpperCase() : 'M';
    final primaryPhoto = change.profilePhotos.firstWhere(
      (photo) => photo.isPrimary,
      orElse: () => change.profilePhotos.isNotEmpty
          ? change.profilePhotos.first
          : MemberProfilePhoto(path: ''),
    );
    final avatarUrl = primaryPhoto.publicUrl;

    String valueDelta;
    if ((change.oldValue ?? '').isEmpty && (change.newValue ?? '').isNotEmpty) {
      valueDelta = 'Set to: ${change.newValue}';
    } else if ((change.newValue ?? '').isEmpty && (change.oldValue ?? '').isNotEmpty) {
      valueDelta = 'Cleared value (was ${change.oldValue})';
    } else {
      valueDelta = '"${change.oldValue ?? ''}" → "${change.newValue ?? ''}"';
    }

    return Card(
      elevation: 3,
      child: ListTile(
        onTap: () => _openMemberProfile(change.memberId),
        leading: avatarUrl != null && avatarUrl.isNotEmpty
            ? CircleAvatar(backgroundImage: NetworkImage(avatarUrl))
            : CircleAvatar(
                backgroundColor: Colors.blueGrey.shade100,
                child: Text(avatarLetter),
              ),
        title: Text(displayName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(change.displayLabel ?? change.fieldName, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(valueDelta),
            const SizedBox(height: 4),
            Text('Requested ${_signInFormat.format(change.createdAt.toLocal())}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.6)),
              ),
              child: Text(change.status.toUpperCase(), style: TextStyle(color: statusColor)),
            ),
            if (change.status == 'pending')
              Row(
                mainAxisSize: MainAxisSize.min,
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
            if (change.status == 'rejected' && change.rejectionReason != null)
              Text('Reason: ${change.rejectionReason}', textAlign: TextAlign.right),
          ],
        ),
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

  Widget _buildRecentSignInsCard() {
    final theme = Theme.of(context);
    return FutureBuilder<List<MemberPortalRecentSignIn>>(
      future: _recentSignInsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            padding: const EdgeInsets.all(16),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.red.shade900.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade200.withOpacity(0.5)),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Unable to load recent sign-ins. Please try again.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }

        final signIns = snapshot.data ?? const [];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF43A047),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.login, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Recent Sign-Ins',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (signIns.isEmpty)
                Text(
                  'No recent sign-ins',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: signIns
                        .map(
                          (signIn) => Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 320, maxWidth: 420),
                              child: Card(
                                elevation: 2,
                                color: _unityBlue,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => _openMemberProfile(signIn.id),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        _buildAvatar(signIn),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                signIn.name,
                                                style: theme.textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (signIn.chapterName != null && signIn.chapterName!.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2.0),
                                                  child: Text(
                                                    signIn.chapterName!,
                                                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4.0),
                                                child: Text(
                                                  _formatCentralSignIn(signIn.lastSignInAt),
                                                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white70),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar(MemberPortalRecentSignIn signIn) {
    final primaryPhoto = signIn.profilePictures.firstWhere(
      (photo) => photo.isPrimary,
      orElse: () => signIn.profilePictures.isNotEmpty ? signIn.profilePictures.first : MemberProfilePhoto(path: ''),
    );

    final imageUrl = primaryPhoto.publicUrl;
    final initials = signIn.name.isNotEmpty ? signIn.name.trim()[0].toUpperCase() : '?';

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(imageUrl),
        backgroundColor: Colors.white,
      );
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.white.withOpacity(0.1),
      foregroundColor: Colors.white,
      child: Text(initials),
    );
  }

  String _formatCentralSignIn(DateTime lastSignIn) {
    try {
      final location = tz.getLocation('America/Chicago');
      final centralTime = tz.TZDateTime.from(lastSignIn.toUtc(), location);
      return '${_signInFormat.format(centralTime)} CT';
    } catch (_) {
      return _signInFormat.format(lastSignIn.toLocal());
    }
  }

  Future<void> _openMemberProfile(String memberId) async {
    if (!_supabase.isInitialized) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final member = await _memberRepository.getMemberById(memberId);
      if (!mounted) return;

      Navigator.of(context).pop();

      if (member == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load member profile')),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MemberDetailScreen(member: member)),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open member profile: $e')),
        );
      }
    }
  }

  Widget _buildStatCard(String title, int value, IconData icon) {
    return SizedBox(
      width: 260,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(10),
              child: Icon(icon, size: 24, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                Text(
                  value.toString(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
