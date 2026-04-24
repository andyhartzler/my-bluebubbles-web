import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bluebubbles/models/crm/dashboard_page.dart';
import 'package:bluebubbles/providers/user_session_provider.dart';
import 'package:bluebubbles/screens/dashboard/dashboard_screen.dart';
import 'package:bluebubbles/services/crm/dashboard_pages_service.dart';

import 'add_page_dialog.dart';
import 'personal_dashboard_page_view.dart';

/// Tabbed wrapper around the existing global Dashboard.
///   Tab 0: 'Universal' = unmodified `DashboardScreen()`.
///   Tabs 1..N: per-user pages from `public.dashboard_pages`.
///   Tab N+1: '+' button → `AddPageDialog`.
///
/// The existing `DashboardScreen` is rendered verbatim so its drag-drop
/// edit / persistence to `crm_dashboard_metrics.dashboard_layout` keep
/// working exactly as before.
class DashboardShellScreen extends StatefulWidget {
  const DashboardShellScreen({super.key});

  @override
  State<DashboardShellScreen> createState() => _DashboardShellScreenState();
}

class _DashboardShellScreenState extends State<DashboardShellScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _service = DashboardPagesService();
  List<DashboardPage> _pages = const [];
  bool _loading = true;
  TabController? _tabs;
  int _selectedIndex = 0;
  String? _loadedForAuthId;
  bool _addingPage = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // IndexedStack mounts every section eagerly, so the auth id may be
    // null on the first frame and only resolve once UserSessionProvider
    // finishes loading. Triggering load from didChangeDependencies lets
    // us pick up the auth id whenever the provider notifies a change.
    final authId = context.read<UserSessionProvider>().authUserId;
    if (authId != null && _loadedForAuthId != authId) {
      _loadedForAuthId = authId;
      _load(authId);
    }
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  Future<void> _load(String authId) async {
    setState(() => _loading = true);
    final pages = await _service.fetchPagesForUser(authId);
    if (!mounted) return;
    setState(() {
      _pages = pages;
      _loading = false;
    });
    _rebuildTabs();
  }

  void _rebuildTabs() {
    // Total tab count: 1 (universal) + N (personal) + 1 (+ button)
    final length = 1 + _pages.length + 1;
    _tabs?.dispose();
    _tabs = TabController(
      length: length,
      vsync: this,
      initialIndex: _selectedIndex.clamp(0, length - 1),
    );
    _tabs!.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabs == null) return;
    if (_tabs!.indexIsChanging) return;
    final i = _tabs!.index;
    // The last tab is the "+" trigger — handle it then snap back.
    if (i == _tabs!.length - 1) {
      _tabs!.index = _selectedIndex;
      _addPage();
      return;
    }
    setState(() => _selectedIndex = i);
  }

  Future<void> _addPage() async {
    if (_addingPage) return;
    _addingPage = true;
    try {
      final session = context.read<UserSessionProvider>();
      final authId = session.authUserId;
      if (authId == null) return;
      final created = await showDialog<DashboardPage?>(
        context: context,
        builder: (_) => AddPageDialog(
          userId: authId,
          createdBy: authId,
          existingPages: _pages,
        ),
      );
      if (created == null) return;
      setState(() {
        _pages = [..._pages, created];
        _selectedIndex = _pages.length; // jump to new page (universal=0, pages start at 1)
      });
      _rebuildTabs();
    } finally {
      _addingPage = false;
    }
  }

  Future<void> _renamePage(DashboardPage page) async {
    final controller = TextEditingController(text: page.title);
    final result = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename page'),
        content: TextField(
          controller: controller,
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
    if (result == null || result.isEmpty || result == page.title) return;
    final ok = await _service.renamePage(page.id, result);
    if (ok) {
      setState(() {
        _pages = _pages.map((p) => p.id == page.id ? p.copyWith(title: result) : p).toList();
      });
    }
  }

  Future<void> _deletePage(DashboardPage page) async {
    final confirm = await showDialog<bool?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete page?'),
        content: Text('Permanently remove "${page.title}"?'),
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
    if (confirm != true) return;
    final ok = await _service.deletePage(page.id);
    if (ok) {
      setState(() {
        _pages = _pages.where((p) => p.id != page.id).toList();
        // After removing a page, the universal tab is at index 0 still.
        if (_selectedIndex > _pages.length) {
          _selectedIndex = _pages.length;
        }
      });
      _rebuildTabs();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tabs = _tabs;
    if (_loading || tabs == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: tabs,
              isScrollable: true,
              tabs: [
                const Tab(text: 'Universal'),
                ..._pages.map((p) => Tab(
                      child: GestureDetector(
                        onLongPress: () => _showTabMenu(p),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(p.title),
                          ],
                        ),
                      ),
                    )),
                const Tab(icon: Icon(Icons.add)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: tabs,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                const DashboardScreen(),
                ..._pages.map((p) => PersonalDashboardPageView(page: p)),
                // "+" tab — never reached because the tab listener intercepts it.
                const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTabMenu(DashboardPage page) async {
    final action = await showModalBottomSheet<String?>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () => Navigator.of(context).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    switch (action) {
      case 'rename':
        await _renamePage(page);
        break;
      case 'delete':
        await _deletePage(page);
        break;
    }
  }
}
