import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import 'package:bluebubbles/features/slack/services/slack_management_repository.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/slack_activity.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/utils/slack_message_formatter.dart';

/// Tab displaying unmatched Slack users for manual matching
class UnmatchedUsersTab extends StatefulWidget {
  const UnmatchedUsersTab({super.key, this.highlightUserId});

  /// Optional Slack user ID to highlight/scroll to
  final String? highlightUserId;

  @override
  State<UnmatchedUsersTab> createState() => _UnmatchedUsersTabState();
}

class _UnmatchedUsersTabState extends State<UnmatchedUsersTab> {
  final SlackManagementRepository _repository = SlackManagementRepository();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _userKeys = {};

  List<SlackUnmatchedUser> _users = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all'; // 'all', 'has_email', 'no_email', 'rejected'

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Scroll to the highlighted user after loading
  void _scrollToHighlightedUser() {
    if (widget.highlightUserId == null) return;

    final key = _userKeys[widget.highlightUserId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
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

      // Create keys for each user
      _userKeys.clear();
      for (final user in users) {
        _userKeys[user.slackUserId] = GlobalKey();
      }

      setState(() {
        _users = users;
        _loading = false;
      });

      // Scroll to highlighted user after the frame is rendered
      if (widget.highlightUserId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToHighlightedUser();
        });
      }
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
          SnackBar(
            content: Text('Matched ${user.primaryLabel} to ${result.name}'),
          ),
        );
        _loadUsers();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to match user')));
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
            Text('Are you sure you want to reject "${user.primaryLabel}"?'),
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
        gradient: LinearGradient(
          colors: BrandColors.tileGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_search,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Unmatched Slack Users',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_users.length} users need to be matched',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loadUsers,
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              _buildBrandedFilterChip('All', 'all'),
              _buildBrandedFilterChip('Has Email', 'has_email'),
              _buildBrandedFilterChip('No Email', 'no_email'),
              _buildBrandedFilterChip('Rejected', 'rejected'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrandedFilterChip(String label, String value) {
    final isSelected = _filter == value;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? BrandColors.unityBlue : Colors.white,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => _setFilter(value),
      backgroundColor: Colors.white.withOpacity(0.15),
      selectedColor: Colors.white,
      checkmarkColor: BrandColors.unityBlue,
      side: BorderSide(
        color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
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
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          final isHighlighted = widget.highlightUserId == user.slackUserId;
          return _UnmatchedUserCard(
            key: _userKeys[user.slackUserId],
            user: user,
            isHighlighted: isHighlighted,
            onMatch: () => _showMatchDialog(user),
            onCreateMember: () => _showCreateMemberDialog(user),
            onReject: () => _showRejectDialog(user),
            onEditNotes: () => _showNotesDialog(user),
            onViewActivity: () => _showUserActivityDialog(user),
          );
        },
      ),
    );
  }

  /// Show the detailed activity dialog for an unmatched user
  Future<void> _showUserActivityDialog(SlackUnmatchedUser user) async {
    await showDialog(
      context: context,
      builder: (context) => _UnmatchedUserActivityDialog(
        user: user,
        repository: _repository,
        onMatched: _loadUsers,
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: BrandColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 64,
              color: BrandColors.success,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              color: BrandColors.unityBlue,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BrandColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: BrandColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: BrandColors.unityBlue,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadUsers,
              style: ElevatedButton.styleFrom(
                backgroundColor: BrandColors.unityBlue,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card widget for displaying an unmatched user with navy gradient design
class _UnmatchedUserCard extends StatelessWidget {
  const _UnmatchedUserCard({
    super.key,
    required this.user,
    required this.onMatch,
    required this.onCreateMember,
    required this.onReject,
    required this.onEditNotes,
    required this.onViewActivity,
    this.isHighlighted = false,
  });

  final SlackUnmatchedUser user;
  final VoidCallback onMatch;
  final VoidCallback onCreateMember;
  final VoidCallback onReject;
  final VoidCallback onEditNotes;
  final VoidCallback onViewActivity;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, y');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: BrandColors.tileGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: isHighlighted
            ? Border.all(color: BrandColors.sunriseGold, width: 3)
            : null,
        boxShadow: [
          BoxShadow(
            color: BrandColors.unityBlue.withOpacity(0.3),
            blurRadius: isHighlighted ? 12 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onViewActivity,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CorsAwareAvatar(
                      imageUrl: user.avatarUrl,
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      fallbackText: user.primaryLabel,
                      fallbackTextColor: Colors.white,
                      fallbackIconColor: Colors.white,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  user.primaryLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (user.manuallyRejected)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Rejected',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (user.usernameDisplay != null)
                            Text(
                              user.usernameDisplay!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
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
                        const Color(0xFF4ADE80), // Green for success
                      )
                    else
                      _buildInfoChip(
                        context,
                        Icons.email_outlined,
                        'No email',
                        const Color(0xFFF87171), // Red for warning
                      ),
                    if (user.createdAt != null)
                      _buildInfoChip(
                        context,
                        Icons.calendar_today,
                        'Added ${dateFormat.format(user.createdAt!)}',
                        Colors.white70,
                      ),
                  ],
                ),
                if (user.notes != null && user.notes!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notes,
                          size: 16,
                          color: BrandColors.momentumBlue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            user.notes!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                // Action buttons
                if (!user.manuallyRejected)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: onMatch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BrandColors.momentumBlue,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.link, size: 18),
                        label: const Text('Match to Member'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onCreateMember,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                        ),
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Create Member'),
                      ),
                      TextButton.icon(
                        onPressed: onReject,
                        icon: Icon(
                          Icons.block,
                          size: 18,
                          color: Colors.red.shade300,
                        ),
                        label: Text(
                          'Reject',
                          style: TextStyle(color: Colors.red.shade300),
                        ),
                      ),
                      IconButton(
                        onPressed: onEditNotes,
                        icon: const Icon(
                          Icons.edit_note,
                          color: Colors.white70,
                        ),
                        tooltip: 'Add/Edit Notes',
                      ),
                    ],
                  )
                else
                  TextButton.icon(
                    onPressed: onEditNotes,
                    icon: const Icon(Icons.edit_note, color: Colors.white70),
                    label: const Text(
                      'Edit Notes',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
              ],
            ),
          ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
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
              Text('Match to Member', style: theme.textTheme.headlineSmall),
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
      return CircleAvatar(child: Text(initial));
    }

    return CachedNetworkImage(
      imageUrl: photoUrl,
      imageBuilder: (context, imageProvider) =>
          CircleAvatar(backgroundImage: imageProvider),
      placeholder: (context, url) => CircleAvatar(
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => CircleAvatar(child: Text(initial)),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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

/// Comprehensive activity dialog showing all details and messages for an unmatched Slack user
/// Uses brand colors with light blue gradient background and navy gradient tiles
class _UnmatchedUserActivityDialog extends StatefulWidget {
  const _UnmatchedUserActivityDialog({
    required this.user,
    required this.repository,
    this.onMatched,
  });

  final SlackUnmatchedUser user;
  final SlackManagementRepository repository;
  final VoidCallback? onMatched;

  @override
  State<_UnmatchedUserActivityDialog> createState() =>
      _UnmatchedUserActivityDialogState();
}

class _UnmatchedUserActivityDialogState
    extends State<_UnmatchedUserActivityDialog> {
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _channelMembership = [];
  Map<String, Map<String, String>> _userMappings = {};
  Map<String, String> _channelNames = {};
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final results = await Future.wait([
        widget.repository.getMessagesBySlackUserId(
          widget.user.slackUserId,
          limit: _pageSize,
        ),
        widget.repository.getSlackUserMappings(),
        _loadChannelMembership(),
        _loadChannelNames(),
      ]);

      if (!mounted) return;

      setState(() {
        _messages = results[0] as List<Map<String, dynamic>>;
        _userMappings = results[1] as Map<String, Map<String, String>>;
        _channelMembership = results[2] as List<Map<String, dynamic>>;
        _channelNames = results[3] as Map<String, String>;
        _offset = _messages.length;
        _hasMore = _messages.length >= _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadChannelMembership() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('slack_channel_membership_log')
          .select(
            '*, slack_channel_committee_mapping!slack_channel_id(slack_channel_name)',
          )
          .eq('slack_user_id', widget.user.slackUserId)
          .order('created_at', ascending: false)
          .limit(50);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error loading channel membership: $e');
      return [];
    }
  }

  Future<Map<String, String>> _loadChannelNames() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('slack_channel_committee_mapping')
          .select('slack_channel_id, slack_channel_name');
      final Map<String, String> names = {};
      for (final item in (response as List)) {
        final id = item['slack_channel_id']?.toString();
        final name = item['slack_channel_name']?.toString();
        if (id != null && name != null) {
          names[id] = name;
        }
      }
      return names;
    } catch (e) {
      debugPrint('Error loading channel names: $e');
      return {};
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;

    setState(() => _loadingMore = true);

    try {
      final newMessages = await widget.repository.getMessagesBySlackUserId(
        widget.user.slackUserId,
        limit: _pageSize,
        offset: _offset,
      );

      if (!mounted) return;

      setState(() {
        _messages.addAll(newMessages);
        _offset = _messages.length;
        _hasMore = newMessages.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _showMatchDialog() async {
    final result = await showDialog<Member>(
      context: context,
      builder: (context) => _MemberSearchDialog(user: widget.user),
    );

    if (result != null && mounted) {
      final success = await widget.repository.matchUserToMember(
        slackUserId: widget.user.slackUserId,
        memberId: result.id,
        slackEmail: widget.user.email,
        slackDisplayName: widget.user.displayName,
        slackRealName: widget.user.realName,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Matched ${widget.user.primaryLabel} to ${result.name}',
            ),
          ),
        );
        widget.onMatched?.call();
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dateFormat = DateFormat('MMM d, y • h:mm a');

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: screenSize.height * 0.9,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: BrandColors.backgroundGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with navy gradient
            _buildHeader(dateFormat),
            // Content
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: BrandColors.momentumBlue,
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // User Info Card
                          _buildUserInfoCard(),
                          const SizedBox(height: 20),
                          // Channel Membership
                          _buildChannelMembershipSection(dateFormat),
                          const SizedBox(height: 20),
                          // Messages
                          _buildMessagesSection(dateFormat),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(DateFormat dateFormat) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: BrandColors.tileGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          CorsAwareAvatar(
            imageUrl: widget.user.avatarUrl,
            radius: 32,
            backgroundColor: Colors.white.withOpacity(0.2),
            fallbackText: widget.user.primaryLabel,
            fallbackTextColor: Colors.white,
            fallbackIconColor: Colors.white,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user.primaryLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.user.usernameDisplay != null)
                  Text(
                    widget.user.usernameDisplay!,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: BrandColors.sunriseGold.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Unmatched Slack User',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _showMatchDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.sunriseGold,
              foregroundColor: BrandColors.unityBlue,
            ),
            icon: const Icon(Icons.link, size: 18),
            label: const Text('Link to Member'),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: BrandColors.tileGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person, color: Colors.white70, size: 20),
              SizedBox(width: 8),
              Text(
                'User Information',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _buildInfoItem(
                Icons.badge,
                'Display Name',
                widget.user.displayName ?? 'Not set',
              ),
              _buildInfoItem(
                Icons.person,
                'Real Name',
                widget.user.realName ?? 'Not set',
              ),
              _buildInfoItem(
                Icons.email,
                'Email',
                widget.user.email ?? 'Not available',
              ),
              _buildInfoItem(
                Icons.key,
                'Slack User ID',
                widget.user.slackUserId,
              ),
              if (widget.user.createdAt != null)
                _buildInfoItem(
                  Icons.calendar_today,
                  'First Seen',
                  DateFormat('MMM d, y').format(widget.user.createdAt!),
                ),
            ],
          ),
          if (widget.user.notes != null && widget.user.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes, size: 18, color: Colors.white70),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.user.notes!,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return SizedBox(
      width: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: BrandColors.sunriseGold),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelMembershipSection(DateFormat dateFormat) {
    // Group by channel and get unique channels
    final channelSet = <String>{};
    for (final msg in _messages) {
      final channelId = msg['slack_channel_id']?.toString();
      if (channelId != null) channelSet.add(channelId);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: BrandColors.tileGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tag, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Channel Activity',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${channelSet.length} channels',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (channelSet.isEmpty)
            const Text(
              'No channel activity recorded',
              style: TextStyle(color: Colors.white70),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: channelSet.map((channelId) {
                final channelName = _channelNames[channelId] ?? channelId;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tag, size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        channelName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          if (_channelMembership.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Membership History',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ...(_channelMembership.take(10).map((change) {
              final action = change['action']?.toString() ?? '';
              final channelId = change['slack_channel_id']?.toString() ?? '';
              final channelMapping =
                  change['slack_channel_committee_mapping'];
              String? channelName;
              if (channelMapping is Map<String, dynamic>) {
                channelName = channelMapping['slack_channel_name']
                    ?.toString();
              }
              channelName ??= _channelNames[channelId] ?? channelId;
              final createdAt = change['created_at'] != null
                  ? DateTime.tryParse(change['created_at'].toString())
                  : null;
              final isJoin = action == 'joined' || action == 'invited';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      isJoin ? Icons.add_circle : Icons.remove_circle,
                      size: 16,
                      color: isJoin ? Colors.green[300] : Colors.red[300],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${action.toUpperCase()} #$channelName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (createdAt != null)
                      Text(
                        dateFormat.format(createdAt.toLocal()),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              );
            })),
          ],
        ],
      ),
    );
  }

  Widget _buildMessagesSection(DateFormat dateFormat) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: BrandColors.tileGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.message, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Messages',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${_messages.length}${_hasMore ? '+' : ''} messages',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_messages.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No messages found',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            )
          else
            ...(_messages.map((message) {
              final text = message['message_text']?.toString() ?? '';
              final channelId = message['slack_channel_id']?.toString() ?? '';
              final channelName = _channelNames[channelId] ?? channelId;
              final postedAt = message['posted_at'] != null
                  ? DateTime.tryParse(message['posted_at'].toString())
                  : null;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tag, size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          channelName,
                          style: TextStyle(
                            color: BrandColors.sunriseGold,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        if (postedAt != null)
                          Text(
                            dateFormat.format(postedAt.toLocal()),
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Parse Slack formatting for messages
                    _buildFormattedMessage(text),
                  ],
                ),
              );
            })),
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: ElevatedButton(
                  onPressed: _loadingMore ? null : _loadMore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.sunriseGold,
                    foregroundColor: BrandColors.unityBlue,
                  ),
                  child: _loadingMore
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: BrandColors.unityBlue,
                          ),
                        )
                      : const Text('Load More Messages'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormattedMessage(String text) {
    if (text.isEmpty) {
      return const Text(
        '[No text content]',
        style: TextStyle(
          color: Colors.white54,
          fontStyle: FontStyle.italic,
          fontSize: 13,
        ),
      );
    }

    // Use SlackMessageFormatter to parse the message
    final spans = SlackMessageFormatter.parse(
      text,
      baseStyle: const TextStyle(color: Colors.white, fontSize: 14),
      linkColor: BrandColors.sunriseGold,
      mentionColor: Colors.white,
      userMappings: _userMappings,
    );

    if (spans.isEmpty) {
      return Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }
}
