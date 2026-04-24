import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/providers/user_session_provider.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

import 'activity_screen.dart';
import 'widgets/invite_executive_dialog.dart';

/// Superadmin-only screen that lists every `members` row with
/// `executive_committee = true` and provides invite / revoke / drill-in to
/// the Activity screen actions.
///
/// Gated by `UserSessionProvider.isSuperadmin`. Non-superadmins see a
/// "Not authorized" placeholder instead of the actual data.
class ExecutivesScreen extends StatefulWidget {
  const ExecutivesScreen({super.key});

  @override
  State<ExecutivesScreen> createState() => _ExecutivesScreenState();
}

class _ExecutivesScreenState extends State<ExecutivesScreen> {
  static const _pageTitle = 'Executive Committee';

  List<Map<String, dynamic>> _execs = [];
  bool _loading = true;
  String? _errorMessage;

  // Cached set of member ids currently having a revoke request in-flight, so
  // we can show a spinner on just the affected row rather than disabling the
  // whole page.
  final Set<String> _revokingIds = <String>{};

  @override
  void initState() {
    super.initState();
    // Defer the initial load until after first frame — gives Provider a chance
    // to settle and lets us bail early for non-superadmins without wasting a
    // query.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = context.read<UserSessionProvider>();
      if (session.isSuperadmin) {
        _load();
      } else {
        setState(() => _loading = false);
      }
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final client = CRMSupabaseService().client;
      final response = await client
          .from('members')
          .select(
              'id, name, email, executive_title, executive_role, last_sign_in_at, executive_committee')
          .eq('executive_committee', true)
          .order('name', ascending: true);

      final list = (response as List)
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        _execs = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Failed to load executives: $e';
      });
    }
  }

  Future<void> _openInviteDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const InviteExecutiveDialog(),
    );
    if (result == true) {
      await _load();
    }
  }

  Future<void> _revoke(Map<String, dynamic> member) async {
    final memberId = member['id']?.toString();
    if (memberId == null || memberId.isEmpty) return;

    final name = (member['name'] as String?) ?? '(unknown)';
    final email = (member['email'] as String?) ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Revoke executive access?'),
        content: Text(
          'This will end every active session for $name ($email) and remove '
          'them from the executive committee. They will be signed out within a '
          'few seconds and cannot sign back in unless re-invited.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BrandColors.error),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() {
      _revokingIds.add(memberId);
    });

    try {
      final client = CRMSupabaseService().client;
      await client.functions.invoke(
        'revoke-executive-session',
        body: {'target_user_id': memberId},
      );

      if (!mounted) return;
      setState(() {
        _execs.removeWhere((m) => m['id']?.toString() == memberId);
        _revokingIds.remove(memberId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Revoked access for $name')),
      );
    } on FunctionException catch (e) {
      if (!mounted) return;
      setState(() => _revokingIds.remove(memberId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: BrandColors.error,
          content: Text(
              'Revoke failed: ${e.details ?? e.reasonPhrase ?? "unknown error"}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _revokingIds.remove(memberId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: BrandColors.error,
          content: Text('Revoke failed: $e'),
        ),
      );
    }
  }

  void _viewActivityFor(Map<String, dynamic> member) {
    final memberId = member['id']?.toString();
    if (memberId == null || memberId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivityScreen(initialActorId: memberId),
      ),
    );
  }

  String _formatLastSeen(String? iso) {
    if (iso == null || iso.isEmpty) return 'Never';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return 'Never';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, y').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<UserSessionProvider>();

    if (!session.isSuperadmin) {
      return Scaffold(
        appBar: AppBar(title: const Text(_pageTitle)),
        body: const _NotAuthorizedCard(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(_pageTitle),
        backgroundColor: BrandColors.unityBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Activity log',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ActivityScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: BrandColors.sunriseGold,
                foregroundColor: BrandColors.unityBlue,
              ),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Invite'),
              onPressed: _openInviteDialog,
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _ErrorState(message: _errorMessage!, onRetry: _load);
    }
    if (_execs.isEmpty) {
      return const _EmptyState();
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final wide = constraints.maxWidth >= 860;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderBanner(count: _execs.length),
              const SizedBox(height: 12),
              if (wide)
                _ExecTable(
                  execs: _execs,
                  revokingIds: _revokingIds,
                  onRevoke: _revoke,
                  onViewActivity: _viewActivityFor,
                  formatLastSeen: _formatLastSeen,
                )
              else
                ..._execs.map((m) => _ExecCard(
                      exec: m,
                      revoking:
                          _revokingIds.contains(m['id']?.toString() ?? ''),
                      onRevoke: () => _revoke(m),
                      onViewActivity: () => _viewActivityFor(m),
                      formatLastSeen: _formatLastSeen,
                    )),
            ],
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Subviews
// ──────────────────────────────────────────────────────────────────────────────

class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    // TODO: wrap in BrandedCard once design system helper lands.
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BrandColors.unityBlue,
            BrandColors.royalBlue,
          ],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_moon, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count executive${count == 1 ? "" : "s"}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Anyone here can access every tab of the CRM. Invites and '
                  'revocations are tracked in the audit log.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecTable extends StatelessWidget {
  const _ExecTable({
    required this.execs,
    required this.revokingIds,
    required this.onRevoke,
    required this.onViewActivity,
    required this.formatLastSeen,
  });

  final List<Map<String, dynamic>> execs;
  final Set<String> revokingIds;
  final void Function(Map<String, dynamic>) onRevoke;
  final void Function(Map<String, dynamic>) onViewActivity;
  final String Function(String?) formatLastSeen;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(Colors.grey.shade100),
        columns: const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Title')),
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('Last sign-in')),
          DataColumn(label: Text('Actions')),
        ],
        rows: execs.map((exec) {
          final id = exec['id']?.toString() ?? '';
          final revoking = revokingIds.contains(id);
          return DataRow(
            cells: [
              DataCell(Text(
                (exec['name'] as String?) ?? '(unnamed)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              )),
              DataCell(Text((exec['email'] as String?) ?? '')),
              DataCell(Text((exec['executive_title'] as String?) ?? '—')),
              DataCell(Text((exec['executive_role'] as String?) ?? '—')),
              DataCell(Text(formatLastSeen(exec['last_sign_in_at'] as String?))),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.history, size: 18),
                    tooltip: 'View activity',
                    onPressed: revoking ? null : () => onViewActivity(exec),
                  ),
                  if (revoking)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton(
                      icon: Icon(Icons.block,
                          size: 18, color: BrandColors.error),
                      tooltip: 'Revoke access',
                      onPressed: () => onRevoke(exec),
                    ),
                ],
              )),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _ExecCard extends StatelessWidget {
  const _ExecCard({
    required this.exec,
    required this.revoking,
    required this.onRevoke,
    required this.onViewActivity,
    required this.formatLastSeen,
  });

  final Map<String, dynamic> exec;
  final bool revoking;
  final VoidCallback onRevoke;
  final VoidCallback onViewActivity;
  final String Function(String?) formatLastSeen;

  @override
  Widget build(BuildContext context) {
    final name = (exec['name'] as String?) ?? '(unnamed)';
    final email = (exec['email'] as String?) ?? '';
    final title = (exec['executive_title'] as String?) ?? '';
    final role = (exec['executive_role'] as String?) ?? '';
    final lastSeen = formatLastSeen(exec['last_sign_in_at'] as String?);

    // TODO: wrap in BrandedCard once design system helper lands.
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: BrandColors.unityBlue,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(email,
                          style: TextStyle(
                              color: Colors.grey.shade700, fontSize: 12)),
                    ],
                  ),
                ),
                if (revoking)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) {
                      if (v == 'activity') onViewActivity();
                      if (v == 'revoke') onRevoke();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'activity',
                        child: Row(
                          children: [
                            Icon(Icons.history, size: 16),
                            SizedBox(width: 8),
                            Text('View activity'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'revoke',
                        child: Row(
                          children: [
                            Icon(Icons.block,
                                size: 16, color: BrandColors.error),
                            const SizedBox(width: 8),
                            Text('Revoke',
                                style: TextStyle(color: BrandColors.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (title.isNotEmpty) _chip(Icons.work_outline, title),
                if (role.isNotEmpty) _chip(Icons.shield_outlined, role),
                _chip(Icons.access_time, 'Last sign-in: $lastSeen'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade700),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(color: Colors.grey.shade800, fontSize: 12)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_off, size: 48, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            const Text('No executive committee members yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Use the Invite button to grant access.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: BrandColors.error),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotAuthorizedCard extends StatelessWidget {
  const _NotAuthorizedCard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 42, color: BrandColors.error),
              const SizedBox(height: 12),
              const Text('Not authorized',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'Only superadmins can manage the executive committee.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
