import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/committees/services/committee_repository.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _successGreen = Color(0xFF43A047);

/// Screen for executives to configure which tools committee members can access
class CommitteeToolsConfigScreen extends StatefulWidget {
  final Committee committee;

  const CommitteeToolsConfigScreen({
    super.key,
    required this.committee,
  });

  @override
  State<CommitteeToolsConfigScreen> createState() => _CommitteeToolsConfigScreenState();
}

class _CommitteeToolsConfigScreenState extends State<CommitteeToolsConfigScreen> {
  final CommitteeRepository _repository = CommitteeRepository();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  Set<String> _enabledTools = {};
  Set<String> _originalTools = {};

  Committee get committee => widget.committee;

  bool get _hasChanges => !_enabledTools.difference(_originalTools).isEmpty ||
                           !_originalTools.difference(_enabledTools).isEmpty;

  @override
  void initState() {
    super.initState();
    _loadCurrentTools();
  }

  Future<void> _loadCurrentTools() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tools = await _repository.getCommitteeTools(committee.name);
      if (!mounted) return;
      setState(() {
        _enabledTools = tools.toSet();
        _originalTools = tools.toSet();
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
      final success = await _repository.updateCommitteeTools(
        committee.name,
        _enabledTools.toList(),
      );

      if (!mounted) return;

      if (success) {
        setState(() {
          _originalTools = Set.from(_enabledTools);
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tools configuration saved successfully'),
            backgroundColor: _successGreen,
          ),
        );
      } else {
        setState(() {
          _error = 'Failed to save changes';
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
        _enabledTools.add(slug);
      }
    });
  }

  void _resetToDefaults() {
    setState(() {
      _enabledTools = CommitteeRepository.allAvailableTools
          .where((t) => t.isDefault)
          .map((t) => t.slug)
          .toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure Member Tools'),
        backgroundColor: committee.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_hasChanges)
            TextButton.icon(
              onPressed: _isSaving ? null : _saveChanges,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(
                _isSaving ? 'Saving...' : 'Save',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _buildContent(),
    );
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
                onPressed: _loadCurrentTools,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);

    return Column(
      children: [
        // Header section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [committee.primaryColor, committee.secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Icon(committee.icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            committee.displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Configure which tools committee members can access',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Tools list
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Info card
              Card(
                color: _momentumBlue.withOpacity(0.1),
                elevation: 0,
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
                          'Toggle tools below to control what committee members see when they access this committee. Changes are saved immediately when you tap Save.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _unityBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Reset to defaults button
              Row(
                children: [
                  Text(
                    'Member Tools',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _unityBlue,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _resetToDefaults,
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text('Reset to Defaults'),
                    style: TextButton.styleFrom(
                      foregroundColor: _momentumBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tool toggles
              ...CommitteeRepository.allAvailableTools.map((tool) => _buildToolToggle(tool)),

              const SizedBox(height: 24),

              // Preview section
              Text(
                'Preview',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _unityBlue,
                ),
              ),
              const SizedBox(height: 12),
              _buildPreview(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolToggle(CommitteeTool tool) {
    final isEnabled = _enabledTools.contains(tool.slug);

    return Card(
      elevation: isEnabled ? 2 : 0,
      color: isEnabled ? Colors.white : Colors.grey.shade100,
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
                  color: isEnabled ? _momentumBlue.withOpacity(0.1) : Colors.grey.shade200,
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _successGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
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
                        color: isEnabled ? _unityBlue.withOpacity(0.7) : Colors.grey,
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
    final enabledToolsList = CommitteeRepository.allAvailableTools
        .where((t) => _enabledTools.contains(t.slug))
        .toList();

    if (enabledToolsList.isEmpty) {
      return Card(
        color: Colors.amber.shade50,
        elevation: 0,
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
      elevation: 2,
      color: _unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.visibility_outlined, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'What members will see',
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
              children: enabledToolsList.map((tool) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              )).toList(),
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
      default:
        return Icons.extension_outlined;
    }
  }
}
