import 'dart:async';

import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/slack_activity.dart';
import 'package:bluebubbles/services/crm/slack_activity_service.dart';

class SlackUserSearchScreen extends StatefulWidget {
  const SlackUserSearchScreen({super.key, required this.member});

  final Member member;

  @override
  State<SlackUserSearchScreen> createState() => _SlackUserSearchScreenState();
}

class _SlackUserSearchScreenState extends State<SlackUserSearchScreen> {
  final SlackActivityService _slackService = SlackActivityService.instance;
  final TextEditingController _searchController = TextEditingController();
  final List<SlackUnmatchedUser> _results = [];

  Timer? _searchDebounce;
  bool _isLoading = true;
  String? _error;
  String? _linkingSlackId;

  @override
  void initState() {
    super.initState();
    _loadUnmatched();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUnmatched({String? query}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final users = await _slackService.fetchUnmatchedSlackUsers(searchQuery: query);
      if (!mounted) return;
      setState(() {
        _results
          ..clear()
          ..addAll(users);
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

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _loadUnmatched(query: value.trim().isEmpty ? null : value.trim());
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  Future<void> _handleUserSelected(SlackUnmatchedUser user) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Link Slack account'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Member: ${widget.member.name}'),
                const SizedBox(height: 8),
                Text('Slack user: ${user.primaryLabel}'),
                if (user.usernameDisplay != null) ...[
                  const SizedBox(height: 4),
                  Text('Username: ${user.usernameDisplay}'),
                ],
                const SizedBox(height: 8),
                const Text('This will link the member to the selected Slack user.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Link Account'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() => _linkingSlackId = user.slackUserId);

    try {
      await _slackService.linkMemberToSlack(
        memberId: widget.member.id,
        slackUser: user,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Linked ${widget.member.name} to ${user.primaryLabel}')),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error linking Slack user: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _linkingSlackId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Slack Account'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select the Slack user that matches ${widget.member.name}.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search by name or email',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ],
            ),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                'Unable to load unmatched Slack users.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadUnmatched(query: _searchController.text),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.inbox_outlined, size: 48),
              SizedBox(height: 12),
              Text('No unmatched Slack users found.'),
              SizedBox(height: 8),
              Text(
                'Try searching with a different name or email.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final user = _results[index];
        final isLinking = _linkingSlackId == user.slackUserId;
        final email = user.email?.isNotEmpty == true ? user.email! : 'No email';

        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(user.primaryLabel),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (user.usernameDisplay != null)
                Text(user.usernameDisplay!, style: Theme.of(context).textTheme.bodyMedium),
              Text(email),
              if (user.notes != null && user.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    'Notes: ${user.notes!}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
          trailing: isLinking
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: isLinking ? null : () => _handleUserSelected(user),
        );
      },
    );
  }
}
