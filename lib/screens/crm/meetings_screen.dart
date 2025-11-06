import 'package:flutter/material.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/models/crm/meeting.dart';
import 'package:bluebubbles/screens/crm/meeting_detail_screen.dart';
import 'package:bluebubbles/services/crm/meeting_repository.dart';
import 'package:bluebubbles/services/crm/member_lookup_service.dart';

class MeetingsScreen extends StatefulWidget {
  final String? initialMeetingId;
  final String? highlightMemberId;

  const MeetingsScreen({
    Key? key,
    this.initialMeetingId,
    this.highlightMemberId,
  }) : super(key: key);

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _sunriseGold = Color(0xFFFDB813);
const _actionRed = Color(0xFFE63946);
const _justicePurple = Color(0xFF6A1B9A);
const _grassrootsGreen = Color(0xFF43A047);

enum _DateRangeFilter { all, last30, last90, upcoming }

class _MeetingsScreenState extends State<MeetingsScreen> {
  final MeetingRepository _meetingRepository = MeetingRepository();
  final CRMMemberLookupService _memberLookup = CRMMemberLookupService();

  List<Meeting> _meetings = [];
  bool _loading = true;
  String? _error;

  _DateRangeFilter _dateRangeFilter = _DateRangeFilter.all;
  String? _selectedHostFilter;
  String? _selectedChapterFilter;

  bool get _isCrmReady => _memberLookup.isReady;

  @override
  void initState() {
    super.initState();
    _loadMeetings();
  }

  Future<void> _loadMeetings() async {
    if (!_isCrmReady) {
      setState(() {
        _loading = false;
        _error = 'CRM Supabase is not configured.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final meetings = await _meetingRepository.getMeetings(includeAttendance: true);
      for (final meeting in meetings) {
        for (final attendance in meeting.attendance) {
          final member = attendance.member;
          if (member != null) {
            _memberLookup.cacheMember(member);
          }
        }
        final host = meeting.host;
        if (host != null) {
          _memberLookup.cacheMember(host);
        }
      }

      if (!mounted) return;
      setState(() {
        _meetings = meetings;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final friendly = e is FormatException
          ? 'The meeting data from Supabase could not be parsed: ${e.message}. Please verify the stored timestamps and IDs.'
          : 'Failed to load meetings: $e';
      setState(() {
        _error = friendly;
        _loading = false;
      });
    }
  }

  void _openMeetingDetail(Meeting meeting) {
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (context) => TitleBarWrapper(
          child: MeetingDetailScreen(
            initialMeeting: meeting,
            highlightMemberId: widget.highlightMemberId,
          ),
        ),
      ),
    );
  }

  List<Meeting> _filterMeetings(List<Meeting> source) {
    final now = DateTime.now();
    final filtered = source.where((meeting) {
      switch (_dateRangeFilter) {
        case _DateRangeFilter.all:
          break;
        case _DateRangeFilter.last30:
          if (meeting.meetingDate.isBefore(now.subtract(const Duration(days: 30)))) {
            return false;
          }
          break;
        case _DateRangeFilter.last90:
          if (meeting.meetingDate.isBefore(now.subtract(const Duration(days: 90)))) {
            return false;
          }
          break;
        case _DateRangeFilter.upcoming:
          if (meeting.meetingDate.isBefore(now)) {
            return false;
          }
          break;
      }

      if (_selectedHostFilter != null && _selectedHostFilter!.isNotEmpty) {
        final hostName = meeting.host?.name;
        if (hostName == null || hostName != _selectedHostFilter) {
          return false;
        }
      }

      if (_selectedChapterFilter != null && _selectedChapterFilter!.isNotEmpty) {
        final chapterName = meeting.host?.chapterName;
        if (chapterName == null || chapterName != _selectedChapterFilter) {
          return false;
        }
      }

      return true;
    }).toList();

    filtered.sort((a, b) => b.meetingDate.compareTo(a.meetingDate));
    return filtered;
  }


  String _formatDateRangeLabel(_DateRangeFilter filter) {
    switch (filter) {
      case _DateRangeFilter.all:
        return 'Any time';
      case _DateRangeFilter.last30:
        return 'Last 30 days';
      case _DateRangeFilter.last90:
        return 'Last 90 days';
      case _DateRangeFilter.upcoming:
        return 'Upcoming';
    }
  }

  void _setDateRangeFilter(_DateRangeFilter value) {
    if (_dateRangeFilter == value) return;
    setState(() {
      _dateRangeFilter = value;
    });
  }

  void _setHostFilter(String? value) {
    if (_selectedHostFilter == value) return;
    setState(() {
      _selectedHostFilter = value;
    });
  }

  void _setChapterFilter(String? value) {
    if (_selectedChapterFilter == value) return;
    setState(() {
      _selectedChapterFilter = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCrmReady) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('CRM Supabase is not configured. Configure access to view meetings.'),
        ),
      );
    }

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
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: _loadMeetings,
              ),
            ],
          ),
        ),
      );
    }

    if (_meetings.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('No meetings have been recorded yet.'),
        ),
      );
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
        Positioned.fill(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final filteredMeetings = _filterMeetings(_meetings);
        final isCompact = constraints.maxWidth < 720;
        final horizontalPadding = isCompact ? 12.0 : 32.0;
        final topPadding = 24.0;
        final bottomPadding = isCompact ? 16.0 : 32.0;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, topPadding, horizontalPadding, 0),
              sliver: SliverToBoxAdapter(
                child: _buildHeader(filteredMeetings.length),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 0),
              sliver: SliverToBoxAdapter(
                child: _buildFilterControls(isCompact),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, bottomPadding),
              sliver: _buildMeetingSliver(filteredMeetings),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(int meetingCount) {
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
                'Meetings',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                meetingCount == 0
                    ? 'No meetings match the current filters.'
                    : '$meetingCount meeting${meetingCount == 1 ? '' : 's'} ready to review',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: _loadMeetings,
        ),
      ],
    );
  }

  Widget _buildMeetingSliver(List<Meeting> meetings) {
    if (meetings.isEmpty) {
      final theme = Theme.of(context);
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: theme.colorScheme.outlineVariant ?? theme.dividerColor),
            ),
            child: Text(
              'Adjust your filters or refresh to see more meetings.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final itemCount = meetings.length * 2 - 1;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index.isOdd) {
            return const SizedBox(height: 12);
          }
          final itemIndex = index ~/ 2;
          return _buildMeetingPill(meetings[itemIndex]);
        },
        childCount: itemCount > 0 ? itemCount : 0,
      ),
    );
  }

  Widget _buildMeetingPill(Meeting meeting) {
    final theme = Theme.of(context);
    final attendeeCount = meeting.attendance.length + meeting.nonMemberAttendees.length;
    final hostName = meeting.host?.name ?? 'Host TBD';
    final durationLabel = meeting.durationMinutes != null ? '${meeting.durationMinutes} min' : 'Duration TBD';

    return Card(
      elevation: 2,
      color: _unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openMeetingDetail(meeting),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meeting.meetingTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${meeting.formattedDate} • ${meeting.formattedTime} CST',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildInfoChip(Icons.schedule, durationLabel),
                    _buildInfoChip(Icons.person_outline, hostName),
                    _buildInfoChip(Icons.groups_outlined, '$attendeeCount'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
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

  Widget _buildFilterControls(bool isCompact) {
    final hostNames = _meetings.map((m) => m.host?.name).whereType<String>().toSet().toList()..sort();
    final chapterNames = _meetings.map((m) => m.host?.chapterName).whereType<String>().toSet().toList()..sort();

    final filters = <Widget>[
      _buildFilterPill(
        icon: Icons.calendar_month_outlined,
        label: 'Date',
        child: DropdownButtonHideUnderline(
          child: DropdownButton<_DateRangeFilter>(
            value: _dateRangeFilter,
            onChanged: (value) {
              if (value != null) {
                _setDateRangeFilter(value);
              }
            },
            items: _DateRangeFilter.values
                .map(
                  (filter) => DropdownMenuItem(
                    value: filter,
                    child: Text(_formatDateRangeLabel(filter)),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    ];

    if (hostNames.isNotEmpty) {
      filters.add(
        _buildFilterPill(
          icon: Icons.person_outline,
          label: 'Host',
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedHostFilter,
              onChanged: _setHostFilter,
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('All hosts')),
                ...hostNames.map(
                  (host) => DropdownMenuItem<String?>(value: host, child: Text(host)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (chapterNames.isNotEmpty) {
      filters.add(
        _buildFilterPill(
          icon: Icons.flag_outlined,
          label: 'Chapter',
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedChapterFilter,
              onChanged: _setChapterFilter,
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('All chapters')),
                ...chapterNames.map(
                  (chapter) => DropdownMenuItem<String?>(value: chapter, child: Text(chapter)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final spacing = isCompact ? 8.0 : 12.0;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: filters,
    );
  }

  Widget _buildFilterPill({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 120),
            child: child,
          ),
        ],
      ),
    );
  }
}
