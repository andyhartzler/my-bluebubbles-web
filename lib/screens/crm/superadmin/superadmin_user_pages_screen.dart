import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bluebubbles/models/crm/dashboard_page.dart';
import 'package:bluebubbles/providers/user_session_provider.dart';
import 'package:bluebubbles/screens/crm/dashboard_shell/add_page_dialog.dart';
import 'package:bluebubbles/services/crm/dashboard_pages_service.dart';

/// Superadmin-only screen for managing one user's personal Dashboard
/// pages (rows in `public.dashboard_pages` where `user_id = <target>`).
///
/// RLS already permits superadmin reads/inserts/updates/deletes on any
/// row (`current_user_is_superadmin()` clause in `dp_*` policies). The
/// recipient sees new pages as their own personal Dashboard tabs the
/// next time they open the Dashboard.
///
/// Mounted via:
///   Navigator.push(MaterialPageRoute(
///     builder: (_) => SuperadminUserPagesScreen(
///       targetAuthUserId: <auth.users.id>,
///       targetDisplayName: <e.g. "Andrew Hartzler">,
///     ),
///   ));
class SuperadminUserPagesScreen extends StatefulWidget {
  final String targetAuthUserId;
  final String targetDisplayName;

  const SuperadminUserPagesScreen({
    super.key,
    required this.targetAuthUserId,
    required this.targetDisplayName,
  });

  @override
  State<SuperadminUserPagesScreen> createState() =>
      _SuperadminUserPagesScreenState();
}

class _SuperadminUserPagesScreenState extends State<SuperadminUserPagesScreen> {
  final _service = DashboardPagesService();
  List<DashboardPage> _pages = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pages = await _service.fetchPagesForUser(widget.targetAuthUserId);
      if (!mounted) return;
      setState(() {
        _pages = pages;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load pages: $e';
        _loading = false;
      });
    }
  }

  Future<void> _addPage() async {
    final session = context.read<UserSessionProvider>();
    final mySelfId = session.authUserId;
    if (mySelfId == null) return;
    final created = await showDialog<DashboardPage?>(
      context: context,
      builder: (_) => AddPageDialog(
        userId: widget.targetAuthUserId,
        createdBy: mySelfId,
        existingPages: _pages,
      ),
    );
    if (created == null) return;
    setState(() => _pages = [..._pages, created]);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Created "${created.title}" for ${widget.targetDisplayName}')),
    );
  }

  Future<void> _renamePage(DashboardPage p) async {
    final controller = TextEditingController(text: p.title);
    final result = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename page'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || result == p.title) return;
    final ok = await _service.renamePage(p.id, result);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _pages = _pages.map((x) => x.id == p.id ? x.copyWith(title: result) : x).toList();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rename failed')),
      );
    }
  }

  Future<void> _deletePage(DashboardPage p) async {
    final ok = await showDialog<bool?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete page?'),
        content: Text(
          'Permanently remove "${p.title}" from ${widget.targetDisplayName}\'s '
          'Dashboard. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final success = await _service.deletePage(p.id);
    if (!mounted) return;
    if (success) {
      setState(() => _pages = _pages.where((x) => x.id != p.id).toList());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delete failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<UserSessionProvider>();
    if (!session.isSuperadmin) {
      return const Scaffold(
        body: Center(child: Text('Superadmin access required')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard pages — ${widget.targetDisplayName}'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _addPage,
        icon: const Icon(Icons.add),
        label: const Text('Create page'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_pages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.dashboard_customize,
                  size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              Text(
                'No personal pages yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Create a page on ${widget.targetDisplayName}\'s behalf — '
                'they\'ll see it as a tab in their Dashboard the next time '
                'they open it.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: _pages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = _pages[i];
        final widgetCount = (p.layout.widgets).length;
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: CircleAvatar(child: Text('${p.position + 1}')),
            title: Text(p.title),
            subtitle: Text(
              '$widgetCount tile${widgetCount == 1 ? '' : 's'} • '
              'updated ${_relativeTime(p.updatedAt)}',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'rename':
                    _renamePage(p);
                    break;
                  case 'delete':
                    _deletePage(p);
                    break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}
