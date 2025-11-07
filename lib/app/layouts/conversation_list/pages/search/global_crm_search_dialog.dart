import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/meeting.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/meeting_detail_screen.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/global_search_service.dart';
import 'package:bluebubbles/services/crm/meeting_repository.dart';
import 'package:bluebubbles/services/crm/storage_uri_resolver.dart';

class GlobalCrmSearchDialog extends StatefulWidget {
  const GlobalCrmSearchDialog({super.key});

  @override
  State<GlobalCrmSearchDialog> createState() => _GlobalCrmSearchDialogState();
}

class _GlobalCrmSearchDialogState extends State<GlobalCrmSearchDialog> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final FocusScopeNode _focusScopeNode = FocusScopeNode(debugLabel: 'GlobalCrmSearchDialog');
  final GlobalSearchService _searchService = GlobalSearchService();
  final MeetingRepository _meetingRepository = MeetingRepository();

  Timer? _debounce;
  bool _isSearching = false;
  String? _error;
  GlobalSearchResults? _results;
  GlobalSearchItemType? _selectedFacet;
  bool _initializedFocus = false;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_handleQueryChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedFocus) {
      _initializedFocus = true;
      scheduleMicrotask(() {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.removeListener(_handleQueryChanged);
    _queryController.dispose();
    _focusNode.dispose();
    _focusScopeNode.dispose();
    super.dispose();
  }

  void _handleQueryChanged() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(_queryController.text);
    });
  }

  Future<void> _performSearch(String value) async {
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      setState(() {
        _error = null;
        _results = null;
        _selectedFacet = null;
      });
      return;
    }

    if (!CRMConfig.crmEnabled || !_searchService.isReady) {
      setState(() {
        _error = 'CRM search is unavailable. Verify Supabase credentials and authentication.';
        _results = null;
        _selectedFacet = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final response = await _searchService.search(trimmed);
      if (!mounted) return;
      setState(() {
        _results = response;
        if (_selectedFacet != null &&
            (response.items(_selectedFacet!).isEmpty)) {
          _selectedFacet = null;
        }
      });
    } catch (error, stackTrace) {
      debugPrint('❌ Failed to complete CRM search: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() {
        _error = 'Unable to complete search. Please try again.';
        _results = null;
        _selectedFacet = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        color: Colors.black.withOpacity(0.35),
        child: SafeArea(
          child: Shortcuts(
            shortcuts: const <LogicalKeySet, Intent>{
              const LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),
              const LogicalKeySet(LogicalKeyboardKey.goBack): const DismissIntent(),
              const LogicalKeySet(LogicalKeyboardKey.browserBack): const DismissIntent(),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                DismissIntent: CallbackAction<DismissIntent>(
                  onInvoke: (intent) {
                    Navigator.of(context).maybePop();
                    return null;
                  },
                ),
              },
              child: FocusTraversalGroup(
                child: FocusScope(
                  node: _focusScopeNode,
                  autofocus: true,
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final bool isCompact = constraints.maxWidth < 720;
                        final double widthFactor = isCompact ? 1 : 0.85;
                        final double heightFactor = isCompact ? 1 : 0.9;
                        final BorderRadius borderRadius = isCompact
                            ? BorderRadius.zero
                            : BorderRadius.circular(24);

                        return FractionallySizedBox(
                          widthFactor: widthFactor,
                          heightFactor: heightFactor,
                          child: Padding(
                            padding: EdgeInsets.all(isCompact ? 0 : 24),
                            child: Material(
                              color: theme.colorScheme.surface,
                              elevation: isCompact ? 0 : 16,
                              borderRadius: borderRadius,
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildHeader(context, isCompact),
                                  const Divider(height: 1, thickness: 1),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        _buildFacetBar(),
                                        Expanded(
                                          child: _buildResultsBody(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isCompact) {
    final theme = Theme.of(context);
    final Color searchFieldColor = theme.colorScheme.surfaceVariant
        .withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.18);

    return Material(
      color: theme.colorScheme.surface,
      elevation: isCompact ? 0 : 2,
      child: Padding(
        padding: EdgeInsets.fromLTRB(isCompact ? 16 : 24, 16, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: searchFieldColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _queryController,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _performSearch,
                    decoration: InputDecoration(
                      hintText: 'Search members, meetings, transcripts, documents...',
                      border: InputBorder.none,
                      suffixIcon: _queryController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _queryController.clear();
                                setState(() {
                                  _results = null;
                                  _selectedFacet = null;
                                  _error = null;
                                });
                              },
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: 'Close search',
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacetBar() {
    final results = _results;
    if (results == null || results.isEmpty) {
      return const SizedBox.shrink();
    }

    final counts = results.facetCounts;
    if (counts.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = results.items().length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: Text('All ($total)'),
            selected: _selectedFacet == null,
            onSelected: (_) {
              setState(() {
                _selectedFacet = null;
              });
            },
          ),
          ...counts.entries.map((entry) {
            final type = entry.key;
            final count = entry.value;
            return ChoiceChip(
              label: Text('${_facetLabel(type)} ($count)'),
              selected: _selectedFacet == type,
              onSelected: (_) {
                setState(() {
                  _selectedFacet = type;
                });
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResultsBody() {
    if (_error != null) {
      return _buildMessageCard(_error!);
    }

    if (!_searchService.isReady || !CRMConfig.crmEnabled) {
      return _buildMessageCard(
        'CRM search requires a valid Supabase session. Sign in again to continue.',
      );
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_results == null) {
      return _buildMessageCard(
        'Start typing to search Supabase members, meetings, transcripts, and documents.',
      );
    }

    if (_results!.isEmpty) {
      return _buildMessageCard('No results found for "${_results!.query}".');
    }

    final items = _results!.items(_selectedFacet);
    if (items.isEmpty) {
      return _buildMessageCard('No ${_facetLabel(_selectedFacet!)} results for "${_results!.query}".');
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        switch (item.type) {
          case GlobalSearchItemType.member:
            return _buildMemberTile(item.payload as Member);
          case GlobalSearchItemType.meeting:
            return _buildMeetingTile(item.payload as Meeting);
          case GlobalSearchItemType.transcript:
            return _buildTranscriptTile(item.payload as GlobalSearchTranscript);
          case GlobalSearchItemType.document:
            return _buildDocumentTile(item.payload as GlobalSearchDocument);
        }
      },
    );
  }

  Widget _buildMemberTile(Member member) {
    final subtitleParts = <String>[
      if (member.chapterName != null && member.chapterName!.isNotEmpty) member.chapterName!,
      if (member.county != null && member.county!.isNotEmpty) member.county!,
      if (member.phoneE164 != null && member.phoneE164!.isNotEmpty) member.phoneE164!,
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text(member.name),
        subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' • ')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openMember(member),
      ),
    );
  }

  Widget _buildMeetingTile(Meeting meeting) {
    final formatter = DateFormat.yMMMMd().add_jm();
    final subtitleParts = <String>[
      formatter.format(meeting.meetingDate),
      if (meeting.meetingHostId != null && meeting.meetingHostId!.isNotEmpty)
        'Host: ${meeting.host?.name ?? meeting.meetingHostId}',
      if (meeting.attendanceCount != null)
        '${meeting.attendanceCount} attendees',
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.event_note)),
        title: Text(meeting.meetingTitle),
        subtitle: Text(subtitleParts.where((value) => value.isNotEmpty).join(' • ')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openMeeting(meeting),
      ),
    );
  }

  Widget _buildTranscriptTile(GlobalSearchTranscript transcript) {
    final subtitleParts = <String>[
      if (transcript.meetingTitle != null && transcript.meetingTitle!.isNotEmpty)
        transcript.meetingTitle!,
      if (transcript.createdAt != null)
        DateFormat.yMMMMd().format(transcript.createdAt!),
      if (transcript.summary != null && transcript.summary!.isNotEmpty)
        transcript.summary!,
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.note_alt_outlined)),
        title: Text(transcript.title ?? transcript.meetingTitle ?? 'Transcript'),
        subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' • ')),
        trailing: transcript.meetingId != null
            ? IconButton(
                tooltip: 'Open meeting',
                icon: const Icon(Icons.video_chat_outlined),
                onPressed: () => _openMeetingById(transcript.meetingId!),
              )
            : const Icon(Icons.file_open_outlined),
        onTap: () => _openStorageLink(transcript.storageUri),
      ),
    );
  }

  Widget _buildDocumentTile(GlobalSearchDocument document) {
    final subtitleParts = <String>[
      '${document.bucket}/${document.path}',
      if (document.sizeBytes != null) _formatBytes(document.sizeBytes!),
      if (document.updatedAt != null)
        'Updated ${DateFormat.yMMMd().format(document.updatedAt!)}',
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.insert_drive_file_outlined)),
        title: Text(document.name),
        subtitle: Text(subtitleParts.join(' • ')),
        trailing: const Icon(Icons.cloud_download_outlined),
        onTap: () => _openStorageLink(document.storageUri),
      ),
    );
  }

  Widget _buildMessageCard(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMember(Member member) async {
    await Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (_) => MemberDetailScreen(member: member),
      ),
    );
  }

  Future<void> _openMeeting(Meeting meeting) async {
    await Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (_) => MeetingDetailScreen(initialMeeting: meeting),
      ),
    );
  }

  Future<void> _openMeetingById(String meetingId) async {
    final navigator = Navigator.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final meeting = await _meetingRepository.getMeetingById(meetingId);
      if (!mounted) {
        navigator.pop();
        return;
      }
      navigator.pop();
      if (meeting == null) {
        _showSnackBar('Unable to load meeting.');
        return;
      }
      await _openMeeting(meeting);
    } catch (error) {
      if (navigator.mounted) {
        navigator.pop();
      }
      _showSnackBar('Error opening meeting: $error');
    }
  }

  Future<void> _openStorageLink(String? storageUri) async {
    if (storageUri == null || storageUri.isEmpty) {
      _showSnackBar('No download link available for this item.');
      return;
    }

    final resolved = await CRMStorageUriResolver.resolve(storageUri);
    if (resolved == null) {
      _showSnackBar('Unable to resolve download link.');
      return;
    }

    if (!await launchUrl(resolved, mode: LaunchMode.externalApplication)) {
      _showSnackBar('Could not open ${resolved.toString()}');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _facetLabel(GlobalSearchItemType type) {
    switch (type) {
      case GlobalSearchItemType.member:
        return 'Members';
      case GlobalSearchItemType.meeting:
        return 'Meetings';
      case GlobalSearchItemType.transcript:
        return 'Transcripts';
      case GlobalSearchItemType.document:
        return 'Documents';
    }
  }

  static String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(size >= 10 || size % 1 == 0 ? 0 : 1)} ${units[unitIndex]}';
  }
}
