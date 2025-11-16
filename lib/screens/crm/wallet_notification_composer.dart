import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/wallet_pass_member.dart';
import 'package:bluebubbles/screens/crm/wallet_notification_controller.dart';
import 'package:bluebubbles/services/crm/wallet_notification_service.dart';

class WalletNotificationComposer extends StatefulWidget {
  const WalletNotificationComposer({
    super.key,
    this.initialMemberIds,
    this.controller,
    this.embedded = false,
  });

  final List<String>? initialMemberIds;
  final WalletNotificationController? controller;
  final bool embedded;

  @override
  State<WalletNotificationComposer> createState() =>
      _WalletNotificationComposerState();
}

class _WalletNotificationComposerState
    extends State<WalletNotificationComposer> {
  late final WalletNotificationController _controller;
  late final bool _ownsController;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  static const int _titleMaxLength = 80;
  static const int _messageMaxLength = 240;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ?? WalletNotificationController(initialMemberIds: widget.initialMemberIds);
    _titleController.addListener(_onFieldChanged);
    _messageController.addListener(_onFieldChanged);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onFieldChanged() {
    setState(() {});
  }

  void _onSearchChanged() {
    _controller.updateSearch(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final body = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => _buildBody(context),
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload members',
            onPressed: _controller.isLoading ? null : _controller.refreshMembers,
          ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (!_controller.isServiceReady) {
      return _buildPlaceholder(
        context,
        icon: Icons.lock_outline,
        message:
            'Wallet notifications require Supabase credentials. Update CRMConfig to enable this tool.',
      );
    }

    if (_controller.errorMessage != null) {
      return _buildPlaceholder(
        context,
        icon: Icons.error_outline,
        message: _controller.errorMessage!,
        trailing: _controller.isLoading
            ? const SizedBox(height: 32, width: 32, child: CircularProgressIndicator())
            : ElevatedButton.icon(
                onPressed: _controller.refreshMembers,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTargetSection(context),
            const SizedBox(height: 16),
            _buildCountsRow(context),
            const SizedBox(height: 16),
            if (!isWide)
              ...[
                _buildMemberPicker(context, shrinkWrapList: true),
                const SizedBox(height: 16),
                _buildMessageEditor(context),
              ]
            else
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildMessageEditor(context)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMemberPicker(
                        context,
                        shrinkWrapList: false,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            _buildSendButton(context),
          ],
        );

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: isWide
              ? content
              : SingleChildScrollView(
                  child: content,
                ),
        );
      },
    );
  }

  Widget _buildTargetSection(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Target',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: WalletNotificationTarget.values.map((target) {
                final label = _targetLabel(target);
                return ChoiceChip(
                  label: Text(label),
                  selected: _controller.target == target,
                  onSelected: (_) => _controller.setTarget(target),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountsRow(BuildContext context) {
    final cards = [
      _CountCard(
        label: 'Total Passes',
        value: _controller.totalCount.toString(),
        icon: Icons.credit_card,
        color: Colors.blue.shade50,
      ),
      _CountCard(
        label: 'Active',
        value: _controller.activeCount.toString(),
        icon: Icons.verified,
        color: Colors.green.shade50,
      ),
      _CountCard(
        label: 'Push Registered',
        value: _controller.registeredCount.toString(),
        icon: Icons.notifications_active,
        color: Colors.orange.shade50,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 640;
        if (isWide) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i != cards.length - 1) const SizedBox(width: 12),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              cards[i],
              if (i != cards.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMemberPicker(BuildContext context, {required bool shrinkWrapList}) {
    final theme = Theme.of(context);
    final members = _controller.members;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Members (${members.length})',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: 'Select visible',
                  onPressed:
                      members.isEmpty ? null : () => _controller.selectAllVisible(),
                ),
                IconButton(
                  icon: const Icon(Icons.clear_all),
                  tooltip: 'Clear selection',
                  onPressed: _controller.selectedCount == 0
                      ? null
                      : _controller.clearSelection,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by name, email, or phone',
              ),
            ),
            const SizedBox(height: 12),
            _buildMemberList(members, shrinkWrapList: shrinkWrapList),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberList(List<WalletPassMember> members,
      {required bool shrinkWrapList}) {
    final list = _controller.isLoading
        ? const Center(child: CircularProgressIndicator())
        : members.isEmpty
            ? const Center(child: Text('No wallet pass holders found.'))
            : ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: members.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final member = members[index];
                  return _MemberTile(
                    member: member,
                    selected: _controller.isSelected(member.member.id),
                    onChanged: (_) =>
                        _controller.toggleMember(member.member.id),
                  );
                },
              );

    if (shrinkWrapList) {
      return SizedBox(height: 360, child: list);
    }

    return Expanded(child: list);
  }

  Widget _buildMessageEditor(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Message', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              maxLength: _titleMaxLength,
              decoration: InputDecoration(
                labelText: 'Title',
                counterText:
                    '${_titleController.text.length}/$_titleMaxLength',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              maxLength: _messageMaxLength,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
                counterText:
                    '${_messageController.text.length}/$_messageMaxLength',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton(BuildContext context) {
    final canSend = _controller.canSend(
      title: _titleController.text,
      message: _messageController.text,
    );
    final selectionHint = _controller.target ==
                WalletNotificationTarget.selectedMembers &&
            _controller.selectedCount == 0
        ? 'Select at least one member when targeting "Selected" recipients.'
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selectionHint != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              selectionHint,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ElevatedButton.icon(
          onPressed: canSend && !_controller.isSending ? _onSend : null,
          icon: _controller.isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: Text(
            _controller.isSending
                ? 'Sending...'
                : 'Send to ${_targetSummaryLabel()}',
          ),
        ),
      ],
    );
  }

  Future<void> _onSend() async {
    final result = await _controller.send(
      title: _titleController.text,
      message: _messageController.text,
    );
    if (!mounted) return;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final snackBar = SnackBar(
      content: Text(
        result.success
            ? 'Notification sent to ~${result.delivered} members.'
            : 'Unable to send notification: ${result.message ?? 'Unknown error'}',
      ),
      backgroundColor: result.success ? colorScheme.primary : colorScheme.error,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Widget _buildPlaceholder(
    BuildContext context, {
    required IconData icon,
    required String message,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (trailing != null) ...[
              const SizedBox(height: 16),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  String _targetLabel(WalletNotificationTarget target) {
    switch (target) {
      case WalletNotificationTarget.allPassHolders:
        return 'All pass holders';
      case WalletNotificationTarget.activePasses:
        return 'Active';
      case WalletNotificationTarget.registeredDevices:
        return 'Push registered';
      case WalletNotificationTarget.selectedMembers:
        return 'Selected (${_controller.selectedCount})';
    }
  }

  String _targetSummaryLabel() {
    switch (_controller.target) {
      case WalletNotificationTarget.allPassHolders:
        return 'all pass holders';
      case WalletNotificationTarget.activePasses:
        return 'active passes';
      case WalletNotificationTarget.registeredDevices:
        return 'push-registered members';
      case WalletNotificationTarget.selectedMembers:
        return '${_controller.selectedCount} selected';
    }
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  value,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.selected,
    required this.onChanged,
  });

  final WalletPassMember member;
  final bool selected;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final chips = _buildStatusChips(context, member);
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(8),
      child: CheckboxListTile(
        value: selected,
        onChanged: onChanged,
        title: Text(member.member.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((member.member.email ?? '').isNotEmpty)
              Text(member.member.email!),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: chips,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStatusChips(BuildContext context, WalletPassMember member) {
    final chips = <Widget>[];
    final colorScheme = Theme.of(context).colorScheme;
    if (member.isActive) {
      chips.add(_StatusChip(
        label: 'Active',
        color: colorScheme.secondaryContainer,
      ));
    } else if (member.cardStatus != null) {
      chips.add(_StatusChip(
        label: member.cardStatus!,
        color: colorScheme.surfaceVariant,
      ));
    }
    if (member.isRegistered) {
      chips.add(_StatusChip(
        label: 'Registered',
        color: colorScheme.primaryContainer,
      ));
    }
    if (member.passGeneratedAt != null) {
      chips.add(_StatusChip(
        label: 'Generated',
        color: colorScheme.tertiaryContainer,
      ));
    }
    return chips;
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
