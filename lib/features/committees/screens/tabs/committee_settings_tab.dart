import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/features/committees/screens/committee_member_workspace_screen.dart';
import 'package:bluebubbles/providers/user_session_provider.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _successGreen = Color(0xFF43A047);
const _actionRed = Color(0xFFE63946);
const _grassrootsGreen = Color(0xFF57A773);

/// Tab for executives to configure workspace settings including:
/// - Workspace enabled/disabled toggle for member access
/// - Member tools configuration
class CommitteeSettingsTab extends StatefulWidget {
  final Committee committee;

  const CommitteeSettingsTab({
    super.key,
    required this.committee,
  });

  @override
  State<CommitteeSettingsTab> createState() => _CommitteeSettingsTabState();
}

class _CommitteeSettingsTabState extends State<CommitteeSettingsTab> {
  final CommitteeRepository _repository = CommitteeRepository();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  // Workspace enabled state
  bool _workspaceEnabled = false;
  bool _originalWorkspaceEnabled = false;

  // Tools state - ordered list for reordering support
  List<String> _enabledTools = [];
  List<String> _originalTools = [];

  Committee get committee => widget.committee;

  bool get _hasChanges =>
      _workspaceEnabled != _originalWorkspaceEnabled ||
      !_listEquals(_enabledTools, _originalTools);

  /// Compare two lists for equality (including order)
  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load workspace enabled status and tools in parallel
      final results = await Future.wait([
        _repository.isWorkspaceEnabled(committee.name),
        _repository.getCommitteeTools(committee.name),
      ]);

      if (!mounted) return;

      final workspaceEnabled = results[0] as bool;
      final tools = results[1] as List<String>;

      setState(() {
        _workspaceEnabled = workspaceEnabled;
        _originalWorkspaceEnabled = workspaceEnabled;
        _enabledTools = List<String>.from(tools);
        _originalTools = List<String>.from(tools);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final futures = <Future<bool>>[];

      // Save workspace enabled if changed
      if (_workspaceEnabled != _originalWorkspaceEnabled) {
        futures.add(_repository.updateWorkspaceEnabled(
          committee.name,
          _workspaceEnabled,
        ));
      }

      // Save tools if changed (including order changes)
      if (!_listEquals(_enabledTools, _originalTools)) {
        futures.add(_repository.updateCommitteeTools(
          committee.name,
          _enabledTools,
        ));
      }

      final results = await Future.wait(futures);
      final allSuccess = results.every((success) => success);

      if (!mounted) return;

      if (allSuccess) {
        setState(() {
          _originalWorkspaceEnabled = _workspaceEnabled;
          _originalTools = List<String>.from(_enabledTools);
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: _successGreen,
          ),
        );
      } else {
        setState(() {
          _error = 'Failed to save some settings';
          _isSaving = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isSaving = false;
      });
    }
  }

  void _toggleTool(String slug) {
    setState(() {
      if (_enabledTools.contains(slug)) {
        _enabledTools.remove(slug);
      } else {
        // Add at the end when enabling
        _enabledTools.add(slug);
      }
    });
  }

  void _reorderTool(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final tool = _enabledTools.removeAt(oldIndex);
      _enabledTools.insert(newIndex, tool);
    });
  }

  void _resetToolsToDefaults() {
    setState(() {
      _enabledTools = CommitteeRepository.allAvailableTools
          .where((t) => t.isDefault)
          .map((t) => t.slug)
          .toList();
    });
  }

  void _openMemberView() {
    // Create a mock UserCommitteeInfo with the currently enabled tools
    // This allows the exec to preview exactly what a member would see
    final mockCommitteeInfo = UserCommitteeInfo(
      id: committee.id,
      name: committee.name,
      slug: committee.name.toLowerCase().replaceAll(' ', '-'),
      tools: _enabledTools.toList(),
      color: committee.primaryColor.value.toRadixString(16),
      description: committee.description,
      workspaceEnabled: true,
    );

    // Navigate to the member workspace screen with the mock info
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommitteeMemberWorkspaceScreen(
          committeeInfo: mockCommitteeInfo,
          committee: committee,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildContent();
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_momentumBlue),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: _unityBlue),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadSettings,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Save button row (floating at top when changes exist)
        if (_hasChanges) ...[
          Card(
            color: _momentumBlue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'You have unsaved changes',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveChanges,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(_momentumBlue),
                            ),
                          )
                        : const Icon(Icons.save, size: 18),
                    label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _momentumBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Workspace Access Section
        _buildSectionHeader('Workspace Access', Icons.lock_outline),
        const SizedBox(height: 12),
        _buildWorkspaceToggle(),
        const SizedBox(height: 24),

        // Show preview and tools only if workspace is enabled
        if (_workspaceEnabled) ...[
          // "What members will see" preview (moved to top)
          _buildSectionHeader('What Members Will See', Icons.visibility_outlined),
          const SizedBox(height: 12),
          _buildPreview(),
          const SizedBox(height: 8),
          // View Member View button
          _buildViewMemberViewButton(),
          const SizedBox(height: 16),

          // Tab Order Section - only show if there are enabled tools
          if (_enabledTools.length > 1) ...[
            _buildTabOrderSection(),
            const SizedBox(height: 24),
          ] else
            const SizedBox(height: 8),

          // Member Tools Section
          _buildSectionHeader('Member Tools', Icons.build_outlined),
          const SizedBox(height: 8),
          _buildToolsInfoCard(),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Available Tools',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _unityBlue,
                    ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _resetToolsToDefaults,
                icon: const Icon(Icons.restore, size: 18),
                label: const Text('Reset to Defaults'),
                style: TextButton.styleFrom(
                  foregroundColor: _momentumBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...CommitteeRepository.allAvailableTools
              .map((tool) => _buildToolToggle(tool)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _momentumBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _momentumBlue, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: _unityBlue,
              ),
        ),
      ],
    );
  }

  Widget _buildWorkspaceToggle() {
    return Card(
      elevation: _workspaceEnabled ? 3 : 1,
      color: _workspaceEnabled ? Colors.white : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _workspaceEnabled ? _successGreen : Colors.grey.shade300,
          width: _workspaceEnabled ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _workspaceEnabled
                        ? _successGreen.withOpacity(0.1)
                        : _actionRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _workspaceEnabled
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: _workspaceEnabled ? _successGreen : _actionRed,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Member Workspace',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _unityBlue,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _workspaceEnabled
                            ? 'Committee members can access this workspace'
                            : 'Workspace is hidden from committee members',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _workspaceEnabled
                                  ? _successGreen
                                  : _actionRed,
                            ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _workspaceEnabled,
                  onChanged: (value) {
                    setState(() => _workspaceEnabled = value);
                  },
                  activeColor: _successGreen,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_workspaceEnabled ? _successGreen : _actionRed)
                    .withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (_workspaceEnabled ? _successGreen : _actionRed)
                      .withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: _workspaceEnabled ? _successGreen : _actionRed,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _workspaceEnabled
                          ? 'When enabled, committee members who sign in will see this workspace and can access the tools you configure below.'
                          : 'When disabled, committee members will not see this workspace when they sign in. If this is their only committee, they will be shown a message that their workspace is not yet available.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _workspaceEnabled
                                ? _successGreen.withOpacity(0.9)
                                : _actionRed.withOpacity(0.9),
                            height: 1.4,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolsInfoCard() {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _momentumBlue.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: _momentumBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Toggle tools below to control what committee members see when they access this workspace.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _unityBlue,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolToggle(CommitteeTool tool) {
    final isEnabled = _enabledTools.contains(tool.slug);

    return Card(
      elevation: isEnabled ? 2 : 1,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isEnabled ? _momentumBlue : Colors.grey.shade300,
          width: isEnabled ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _toggleTool(tool.slug),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isEnabled
                      ? _momentumBlue.withOpacity(0.1)
                      : Colors.grey.shade200,
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(
                  _getIconForSlug(tool.icon),
                  size: 20,
                  color: isEnabled ? _momentumBlue : Colors.grey,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          tool.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isEnabled ? _unityBlue : Colors.grey.shade600,
                          ),
                        ),
                        if (tool.isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _successGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _successGreen,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tool.description,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isEnabled ? _unityBlue.withOpacity(0.7) : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isEnabled,
                onChanged: (_) => _toggleTool(tool.slug),
                activeColor: _momentumBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    // Build list preserving the order in _enabledTools
    final toolMap = {for (var t in CommitteeRepository.allAvailableTools) t.slug: t};
    final enabledToolsList = _enabledTools
        .where((slug) => toolMap.containsKey(slug))
        .map((slug) => toolMap[slug]!)
        .toList();

    if (enabledToolsList.isEmpty) {
      return Card(
        color: Colors.amber.shade50,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.amber.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No tools enabled. Members will see an empty workspace. Consider enabling at least Overview and Members.',
                  style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 3,
      color: _unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.preview_outlined,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Preview of member workspace tabs',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: enabledToolsList
                  .map((tool) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getIconForSlug(tool.icon),
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              tool.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Text(
              '${enabledToolsList.length} tool${enabledToolsList.length == 1 ? '' : 's'} enabled for committee members',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabOrderSection() {
    // Build list preserving the order in _enabledTools
    final toolMap = {for (var t in CommitteeRepository.allAvailableTools) t.slug: t};
    final enabledToolsList = _enabledTools
        .where((slug) => toolMap.containsKey(slug))
        .map((slug) => toolMap[slug]!)
        .toList();

    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _momentumBlue.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _momentumBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.swap_vert,
                    color: _momentumBlue,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tab Order',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _unityBlue,
                            ),
                      ),
                      Text(
                        'Drag to reorder tabs',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _unityBlue.withOpacity(0.6),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: enabledToolsList.length,
              onReorder: _reorderTool,
              itemBuilder: (context, index) {
                final tool = enabledToolsList[index];
                return ReorderableDragStartListener(
                  key: ValueKey(tool.slug),
                  index: index,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _momentumBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _momentumBlue.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _momentumBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: _momentumBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          _getIconForSlug(tool.icon),
                          size: 18,
                          color: _unityBlue,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tool.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: _unityBlue,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.drag_handle,
                          color: Colors.grey,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewMemberViewButton() {
    return Card(
      elevation: 2,
      color: _grassrootsGreen,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: _openMemberView,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.preview_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Preview Member View',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'See exactly what members will see with current tools',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForSlug(String iconName) {
    switch (iconName) {
      case 'dashboard_outlined':
        return Icons.dashboard_outlined;
      case 'people_outline':
        return Icons.people_outline;
      case 'chat_outlined':
        return Icons.chat_outlined;
      case 'video_camera_front_outlined':
        return Icons.video_camera_front_outlined;
      case 'space_dashboard_outlined':
        return Icons.space_dashboard_outlined;
      case 'how_to_vote_outlined':
        return Icons.how_to_vote_outlined;
      case 'email_outlined':
        return Icons.email_outlined;
      case 'message_outlined':
        return Icons.message_outlined;
      case 'volunteer_activism_outlined':
        return Icons.volunteer_activism_outlined;
      case 'account_tree_outlined':
        return Icons.account_tree_outlined;
      case 'campaign_outlined':
        return Icons.campaign_outlined;
      case 'gavel_outlined':
        return Icons.gavel_outlined;
      case 'analytics_outlined':
        return Icons.analytics_outlined;
      default:
        return Icons.extension_outlined;
    }
  }
}
