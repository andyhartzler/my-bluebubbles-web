import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import 'package:bluebubbles/features/slack/services/slack_management_repository.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/slack_activity.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';

/// Tab displaying unmatched Slack users for manual matching
class UnmatchedUsersTab extends StatefulWidget {
  const UnmatchedUsersTab({super.key});

  @override
  State<UnmatchedUsersTab> createState() => _UnmatchedUsersTabState();
}

class _UnmatchedUsersTabState extends State<UnmatchedUsersTab> {
  final SlackManagementRepository _repository = SlackManagementRepository();

  List<SlackUnmatchedUser> _users = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all'; // 'all', 'has_email', 'no_email', 'rejected'

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final users = await _repository.getUnmatchedUsers(
        includeRejected: _filter == 'rejected',
        filter: _filter == 'all' ? null : _filter,
      );

      if (!mounted) return;

      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load unmatched users: $e';
        _loading = false;
      });
    }
  }

  void _setFilter(String filter) {
    if (_filter == filter) return;
    setState(() => _filter = filter);
    _loadUsers();
  }

  Future<void> _showMatchDialog(SlackUnmatchedUser user) async {
    final result = await showDialog<Member>(
      context: context,
      builder: (context) => _MemberSearchDialog(user: user),
    );

    if (result != null && mounted) {
      final success = await _repository.matchUserToMember(
        slackUserId: user.slackUserId,
        memberId: result.id,
        slackEmail: user.email,
        slackDisplayName: user.displayName,
        slackRealName: user.realName,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Matched ${user.primaryLabel} to ${result.name}')),
        );
        _loadUsers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to match user')),
        );
      }
    }
  }

  Future<void> _showCreateMemberDialog(SlackUnmatchedUser user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _CreateMemberDialog(user: user),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created member from ${user.primaryLabel}')),
      );
      _loadUsers();
    }
  }

  Future<void> _showRejectDialog(SlackUnmatchedUser user) async {
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to reject "${user.primaryLabel}"?',
            ),
            const SizedBox(height: 8),
            Text(
              'Rejected users are typically bots, external guests, or accounts that shouldn\'t be in the member database.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g., Bot account, External guest',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await _repository.rejectSlackUser(
        user.slackUserId,
        notes: notesController.text.isNotEmpty ? notesController.text : null,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rejected ${user.primaryLabel}')),
        );
        _loadUsers();
      }
    }

    notesController.dispose();
  }

  Future<void> _showNotesDialog(SlackUnmatchedUser user) async {
    final notesController = TextEditingController(text: user.notes ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Notes'),
        content: TextField(
          controller: notesController,
          decoration: const InputDecoration(
            labelText: 'Notes',
            hintText: 'Add notes about this user...',
          ),
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      await _repository.updateUnmatchedUserNotes(
        user.slackUserId,
        notesController.text,
      );
      _loadUsers();
    }

    notesController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Header with count and filters
        _buildHeader(theme),
        // User list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildErrorState(theme)
                  : _users.isEmpty
                      ? _buildEmptyState(theme)
                      : _buildUserList(),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_search, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unmatched Slack Users',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${_users.length} users need to be matched to members',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loadUsers,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _buildFilterChip('All', 'all'),
              _buildFilterChip('Has Email', 'has_email'),
              _buildFilterChip('No Email', 'no_email'),
              _buildFilterChip('Rejected', 'rejected'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    final theme = Theme.of(context);

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _setFilter(value),
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.onPrimaryContainer,
    );
  }

  Widget _buildUserList() {
    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          return _UnmatchedUserCard(
            user: _users[index],
            onMatch: () => _showMatchDialog(_users[index]),
            onCreateMember: () => _showCreateMemberDialog(_users[index]),
            onReject: () => _showRejectDialog(_users[index]),
            onEditNotes: () => _showNotesDialog(_users[index]),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final message = _filter == 'rejected'
        ? 'No rejected users'
        : _filter == 'has_email'
            ? 'No unmatched users with email'
            : _filter == 'no_email'
                ? 'No unmatched users without email'
                : 'All Slack users are matched!';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(_error ?? 'An error occurred', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadUsers,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card widget for displaying an unmatched user
class _UnmatchedUserCard extends StatelessWidget {
  const _UnmatchedUserCard({
    required this.user,
    required this.onMatch,
    required this.onCreateMember,
    required this.onReject,
    required this.onEditNotes,
  });

  final SlackUnmatchedUser user;
  final VoidCallback onMatch;
  final VoidCallback onCreateMember;
  final VoidCallback onReject;
  final VoidCallback onEditNotes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, y');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    user.primaryLabel.isNotEmpty
                        ? user.primaryLabel[0].toUpperCase()
                        : '?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.primaryLabel,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (user.manuallyRejected)
                            Chip(
                              label: const Text('Rejected'),
                              backgroundColor: theme.colorScheme.errorContainer,
                              labelStyle: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                                fontSize: 11,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      if (user.usernameDisplay != null)
                        Text(
                          user.usernameDisplay!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Info row
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (user.email != null && user.email!.isNotEmpty)
                  _buildInfoChip(
                    context,
                    Icons.email,
                    user.email!,
                    Colors.green,
                  )
                else
                  _buildInfoChip(
                    context,
                    Icons.email_outlined,
                    'No email',
                    theme.colorScheme.error,
                  ),
                if (user.createdAt != null)
                  _buildInfoChip(
                    context,
                    Icons.calendar_today,
                    'Added ${dateFormat.format(user.createdAt!)}',
                    theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
            if (user.notes != null && user.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.notes,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        user.notes!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Action buttons
            if (!user.manuallyRejected)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: onMatch,
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('Match to Member'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onCreateMember,
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Create Member'),
                  ),
                  TextButton.icon(
                    onPressed: onReject,
                    icon: Icon(Icons.block, size: 18, color: theme.colorScheme.error),
                    label: Text('Reject', style: TextStyle(color: theme.colorScheme.error)),
                  ),
                  IconButton(
                    onPressed: onEditNotes,
                    icon: const Icon(Icons.edit_note),
                    tooltip: 'Add/Edit Notes',
                  ),
                ],
              )
            else
              TextButton.icon(
                onPressed: onEditNotes,
                icon: const Icon(Icons.edit_note),
                label: const Text('Edit Notes'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Dialog for searching and selecting a member to match
class _MemberSearchDialog extends StatefulWidget {
  const _MemberSearchDialog({required this.user});

  final SlackUnmatchedUser user;

  @override
  State<_MemberSearchDialog> createState() => _MemberSearchDialogState();
}

class _MemberSearchDialogState extends State<_MemberSearchDialog> {
  final SlackManagementRepository _repository = SlackManagementRepository();
  final TextEditingController _searchController = TextEditingController();

  List<Member> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with user's name if available
    if (widget.user.realName != null && widget.user.realName!.isNotEmpty) {
      _searchController.text = widget.user.realName!;
      _search(widget.user.realName!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() => _results = []);
      return;
    }

    setState(() => _loading = true);

    try {
      final results = await _repository.searchMembers(query, limit: 20);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Match to Member',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Matching: ${widget.user.primaryLabel}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: _search,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? Center(
                            child: Text(
                              _searchController.text.length < 2
                                  ? 'Type to search members...'
                                  : 'No members found',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final member = _results[index];
                              return ListTile(
                                leading: CorsAwareAvatar(
                                  imageUrl: member.primaryProfilePhotoUrl,
                                  radius: 20,
                                  fallbackText: member.name,
                                ),
                                title: Text(member.name),
                                subtitle: Text(
                                  member.email ?? 'No email',
                                  style: theme.textTheme.bodySmall,
                                ),
                                onTap: () => Navigator.pop(context, member),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberAvatar(Member member) {
    final photoUrl = member.primaryProfilePhotoUrl;
    final initial = member.name.isNotEmpty ? member.name[0].toUpperCase() : '?';

    if (photoUrl == null) {
      return CircleAvatar(
        child: Text(initial),
      );
    }

    return CachedNetworkImage(
      imageUrl: photoUrl,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        backgroundImage: imageProvider,
      ),
      placeholder: (context, url) => CircleAvatar(
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => CircleAvatar(
        child: Text(initial),
      ),
    );
  }
}

/// Dialog for creating a new member from Slack user data
class _CreateMemberDialog extends StatefulWidget {
  const _CreateMemberDialog({required this.user});

  final SlackUnmatchedUser user;

  @override
  State<_CreateMemberDialog> createState() => _CreateMemberDialogState();
}

class _CreateMemberDialogState extends State<_CreateMemberDialog> {
  final SlackManagementRepository _repository = SlackManagementRepository();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.user.realName ?? widget.user.displayName ?? '',
    );
    _emailController = TextEditingController(text: widget.user.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final memberId = await _repository.createMemberFromSlackUser(
        slackUserId: widget.user.slackUserId,
        name: _nameController.text.trim(),
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
      );

      if (!mounted) return;

      if (memberId != null) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create member')),
        );
        setState(() => _saving = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Create Member'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Create a new member from this Slack user:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

/// Avatar widget that handles CORS errors gracefully for external image URLs
class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({
    required this.photoUrl,
    required this.name,
    this.radius = 20,
  });

  final String? photoUrl;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    if (photoUrl == null || photoUrl!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          initials,
          style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: photoUrl!,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: SizedBox(
            width: radius,
            height: radius,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            initials,
            style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
          ),
        ),
      ),
    );
  }
}
