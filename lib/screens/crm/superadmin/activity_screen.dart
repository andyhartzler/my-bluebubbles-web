import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/providers/user_session_provider.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

import 'executives_screen.dart';
import 'widgets/audit_log_row_card.dart';
import 'widgets/before_after_diff_modal.dart';

/// Superadmin-only Activity dashboard. Surfaces every row in
/// `public.audit_log` (Phase 0 table, filled by Phase 2 triggers) with
/// filters, realtime tail, and drill-in to a before/after JSON diff.
///
/// Gated via `UserSessionProvider.isSuperadmin`. Non-superadmins see a
/// "Not authorized" centered card.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    super.key,
    this.initialActorId,
  });

  /// Optional pre-filter for a specific actor (used by ExecutivesScreen's
  /// "View Activity" row action).
  final String? initialActorId;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  // Constants
  static const _pageSize = 50;
  static const List<String> _allActions = <String>[
    'INSERT',
    'UPDATE',
    'DELETE',
    'RPC',
    'EDGE_FN',
    'AUTH',
  ];

  // Data state
  final List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _pendingRealtimeRows = <Map<String, dynamic>>[];

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _exporting = false;
  String? _errorMessage;

  // Cursor pagination state (R2 fix): track the tail of the loaded window so
  // realtime inserts at the head don't shift offsets. Both are null until the
  // first page loads.
  DateTime? _cursorOccurredAt;
  String? _cursorId;

  // Filter state
  late DateTimeRange _dateRange;
  String? _actorFilter; // member.id (== auth.uid()) or null == "all"
  Set<String> _actionFilter = <String>{};
  String? _tableFilter;

  // Source-of-truth data for dropdowns
  List<Map<String, dynamic>> _actorOptions = <Map<String, dynamic>>[];
  List<String> _tableOptions = <String>[];

  // Realtime
  RealtimeChannel? _auditChannel;

  // Scroll tracking (for the "X new events" banner and infinite scroll)
  final ScrollController _scrollController = ScrollController();
  bool _userScrolledAway = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: now.subtract(const Duration(hours: 24)),
      end: now,
    );
    _actorFilter = widget.initialActorId;

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = context.read<UserSessionProvider>();
      if (!session.isSuperadmin) {
        setState(() => _loading = false);
        return;
      }
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _unsubscribeRealtime();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _loadActorOptions(),
      _loadTableOptions(),
    ]);
    await _reload();
    _subscribeRealtime();
  }

  // ── Dropdown option loaders ───────────────────────────────────────────────

  Future<void> _loadActorOptions() async {
    try {
      final client = CRMSupabaseService().client;
      final resp = await client
          .from('members')
          .select('id, name, email')
          .eq('executive_committee', true)
          .order('name', ascending: true);
      if (!mounted) return;
      setState(() {
        _actorOptions = (resp as List)
            .map<Map<String, dynamic>>(
                (e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (e) {
      debugPrint('ActivityScreen: failed to load actor options: $e');
    }
  }

  Future<void> _loadTableOptions() async {
    // v1 cheat: pull the distinct table names from audit_log itself. For a
    // tiny 18-user dataset this is trivial; if the log grows this should move
    // to a dedicated RPC returning the enum. TODO: replace with RPC once
    // audit_log grows past ~1M rows.
    try {
      final client = CRMSupabaseService().client;
      final resp = await client
          .from('audit_log')
          .select('table_name')
          .order('table_name', ascending: true)
          .limit(500);
      final seen = <String>{};
      for (final row in (resp as List)) {
        final tn = (row as Map)['table_name']?.toString();
        if (tn != null && tn.isNotEmpty) seen.add(tn);
      }
      if (!mounted) return;
      setState(() {
        _tableOptions = seen.toList()..sort();
      });
    } catch (e) {
      debugPrint('ActivityScreen: failed to load table options: $e');
    }
  }

  // ── Query ─────────────────────────────────────────────────────────────────

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
      _rows.clear();
      _pendingRealtimeRows.clear();
      _hasMore = true;
      _cursorOccurredAt = null;
      _cursorId = null;
    });
    await _fetchPage(reset: true);
  }

  Future<void> _fetchPage({bool reset = false}) async {
    try {
      final client = CRMSupabaseService().client;
      // occurred_at is stored as timestamptz; always serialize comparison
      // values in UTC so the filter bounds match DB semantics regardless of
      // the client's local timezone (R2 fix).
      final fromDate = _dateRange.start.toUtc().toIso8601String();
      final toDate = _dateRange.end.toUtc().toIso8601String();

      var query = client
          .from('audit_log')
          .select('*')
          .gte('occurred_at', fromDate)
          .lte('occurred_at', toDate);

      if (_actorFilter != null && _actorFilter!.isNotEmpty) {
        query = query.eq('actor_id', _actorFilter!);
      }
      if (_tableFilter != null && _tableFilter!.isNotEmpty) {
        query = query.eq('table_name', _tableFilter!);
      }
      if (_actionFilter.isNotEmpty) {
        query = query.inFilter('action', _actionFilter.toList());
      }

      // Cursor pagination (R2 fix): after the first page, only fetch rows
      // strictly older than the tail cursor on (occurred_at, id). This is
      // stable under realtime inserts at the head, which the separate
      // channel prepends to the list. The composite tie-break on `id`
      // handles bursts that share a microsecond timestamp.
      if (!reset && _cursorOccurredAt != null) {
        final cursorIso = _cursorOccurredAt!.toUtc().toIso8601String();
        if (_cursorId != null) {
          query = query.or(
            'occurred_at.lt.$cursorIso,'
            'and(occurred_at.eq.$cursorIso,id.lt.${_cursorId!})',
          );
        } else {
          query = query.lt('occurred_at', cursorIso);
        }
      }

      final response = await query
          .order('occurred_at', ascending: false)
          .order('id', ascending: false)
          .limit(_pageSize);

      final list = (response as List)
          .map<Map<String, dynamic>>(
              (e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        if (reset) {
          _rows
            ..clear()
            ..addAll(list);
        } else {
          _rows.addAll(list);
        }
        // Advance the cursor to the tail of what we now have loaded.
        if (list.isNotEmpty) {
          final tail = list.last;
          final tailTs = DateTime.tryParse(
              (tail['occurred_at'] as String?) ?? '');
          if (tailTs != null) {
            _cursorOccurredAt = tailTs;
          }
          _cursorId = tail['id']?.toString();
        }
        _hasMore = list.length >= _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _errorMessage = 'Failed to load audit log: $e';
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;

    // Track whether user has scrolled away from the top (for the realtime
    // "X new events" banner UX).
    final isAtTop = pos.pixels <= 16;
    if (isAtTop && _userScrolledAway) {
      setState(() => _userScrolledAway = false);
    } else if (!isAtTop && !_userScrolledAway) {
      setState(() => _userScrolledAway = true);
    }

    // Infinite scroll: when within 400px of bottom, fetch next page.
    if (!_loadingMore &&
        _hasMore &&
        pos.pixels >= pos.maxScrollExtent - 400) {
      setState(() => _loadingMore = true);
      _fetchPage();
    }
  }

  // ── Realtime ──────────────────────────────────────────────────────────────

  void _subscribeRealtime() {
    try {
      final client = CRMSupabaseService().client;
      _auditChannel = client.channel('audit_log_activity_screen')
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'audit_log',
          callback: _onRealtimeInsert,
        )
        .subscribe();
    } catch (e) {
      debugPrint('ActivityScreen: failed to subscribe to realtime: $e');
    }
  }

  void _unsubscribeRealtime() {
    try {
      _auditChannel?.unsubscribe();
    } catch (_) {}
    _auditChannel = null;
  }

  void _onRealtimeInsert(PostgresChangePayload payload) {
    final newRow = payload.newRecord;
    if (newRow.isEmpty) return;

    if (!_rowMatchesFilters(newRow)) return;

    if (!mounted) return;

    // If the user is at the top of the list, merge new rows immediately.
    // Otherwise stash them behind the "X new events" banner so scroll
    // position is preserved.
    if (!_userScrolledAway) {
      setState(() {
        _rows.insert(0, newRow);
      });
    } else {
      setState(() {
        _pendingRealtimeRows.insert(0, newRow);
      });
    }
  }

  bool _rowMatchesFilters(Map<String, dynamic> row) {
    // occurred_at is timestamptz; DateTime.parse on an ISO-8601 with offset
    // yields a UTC DateTime. Normalize both sides to UTC before comparing so
    // the window endpoints don't drift by the local timezone offset (R2 fix).
    final occurredAt =
        DateTime.tryParse((row['occurred_at'] as String?) ?? '')?.toUtc();
    if (occurredAt == null) return false;
    final startUtc = _dateRange.start.toUtc();
    final endUtc = _dateRange.end.toUtc();
    if (occurredAt.isBefore(startUtc) || occurredAt.isAfter(endUtc)) {
      // Slight tolerance: a row that arrives RIGHT NOW but is technically
      // just past the current `end` is a realtime tail — accept it anyway
      // by letting any row within 5 minutes of "now" through.
      final tolerance =
          DateTime.now().toUtc().subtract(const Duration(minutes: 5));
      if (occurredAt.isBefore(tolerance)) return false;
    }
    if (_actorFilter != null && _actorFilter!.isNotEmpty) {
      if (row['actor_id']?.toString() != _actorFilter) return false;
    }
    if (_tableFilter != null && _tableFilter!.isNotEmpty) {
      if (row['table_name']?.toString() != _tableFilter) return false;
    }
    if (_actionFilter.isNotEmpty) {
      final action = row['action']?.toString() ?? '';
      if (!_actionFilter.contains(action)) return false;
    }
    return true;
  }

  void _mergePendingRealtimeRows() {
    if (_pendingRealtimeRows.isEmpty) return;
    setState(() {
      _rows.insertAll(0, _pendingRealtimeRows);
      _pendingRealtimeRows.clear();
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ── Filter-bar interactions ───────────────────────────────────────────────

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _dateRange = DateTimeRange(
          start: DateTime(picked.start.year, picked.start.month,
              picked.start.day, 0, 0, 0),
          end: DateTime(picked.end.year, picked.end.month, picked.end.day,
              23, 59, 59),
        );
      });
      await _reload();
    }
  }

  void _toggleActionFilter(String action) {
    setState(() {
      if (_actionFilter.contains(action)) {
        _actionFilter.remove(action);
      } else {
        _actionFilter.add(action);
      }
    });
    _reload();
  }

  void _openDiffModal(Map<String, dynamic> row) {
    showDialog<void>(
      context: context,
      builder: (_) => BeforeAfterDiffModal(
        row: row,
        onViewActorProfile: _navigateToActorProfile,
      ),
    );
  }

  /// Looks up the members row whose `id` matches the auth uid recorded as
  /// `actor_id` on the audit row, then pushes MemberDetailScreen. Shows a
  /// spinner in a modal barrier during the async lookup.
  Future<void> _navigateToActorProfile(String actorId) async {
    // Close the diff modal first so the member detail push replaces it
    // cleanly.
    Navigator.of(context, rootNavigator: true).pop();

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Show a small blocking spinner while we fetch the member row.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final client = CRMSupabaseService().client;
      final resp = await client
          .from('members')
          .select()
          .eq('id', actorId)
          .maybeSingle();

      // Dismiss the spinner dialog.
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (resp == null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
              content: Text('No member record found for this actor.')),
        );
        return;
      }

      final member = Member.fromJson(Map<String, dynamic>.from(resp));
      if (!mounted) return;
      navigator.push(
        MaterialPageRoute(builder: (_) => MemberDetailScreen(member: member)),
      );
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to open actor profile: $e')),
      );
    }
  }

  // ── CSV export ────────────────────────────────────────────────────────────

  /// Exports the currently-loaded + currently-filtered rows to a CSV file.
  /// Runs client-side (the audit_log dataset is tiny and RLS already scopes
  /// to superadmins). A server-side streaming endpoint would be needed for a
  /// full-history export; scope is deliberately "what you see."
  Future<void> _exportCsv() async {
    if (_rows.isEmpty || _exporting) return;

    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final buf = StringBuffer();
      const headers = <String>[
        'occurred_at',
        'actor_email',
        'action',
        'schema_table',
        'row_id',
        'changed_columns',
        'context',
      ];
      buf.writeln(headers.map(_csvEscape).join(','));

      for (final row in _rows) {
        final occurredAt = (row['occurred_at'] as String?) ?? '';
        final actorEmail = (row['actor_email'] as String?) ?? '';
        final action = (row['action'] as String?) ?? '';
        final schema = (row['schema_name'] as String?) ?? '';
        final table = (row['table_name'] as String?) ?? '';
        final schemaTable =
            (schema.isEmpty && table.isEmpty) ? '' : '$schema.$table';
        final rowId = row['row_id']?.toString() ?? '';
        final changedCols = row['changed_columns'];
        final ctx = row['context'];
        buf.writeln([
          _csvEscape(occurredAt),
          _csvEscape(actorEmail),
          _csvEscape(action),
          _csvEscape(schemaTable),
          _csvEscape(rowId),
          _csvEscape(
              changedCols == null ? '' : jsonEncode(changedCols)),
          _csvEscape(ctx == null ? '' : jsonEncode(ctx)),
        ].join(','));
      }

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final filename = 'audit-log-$today.csv';
      final blob = html.Blob([buf.toString()], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Exported ${_rows.length} rows to $filename')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('CSV export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Minimal RFC-4180-ish CSV field escape: if the value contains a comma,
  /// quote, or newline, wrap in quotes and double embedded quotes.
  String _csvEscape(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final session = context.watch<UserSessionProvider>();

    if (!session.isSuperadmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Activity')),
        body: const _NotAuthorizedCard(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: BrandColors.unityBlue,
        foregroundColor: Colors.white,
        title: const Text('Superadmin Activity'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.group, color: Colors.white),
            label: const Text(
              'Manage executives',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExecutivesScreen()),
            ),
          ),
          IconButton(
            icon: _exporting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.file_download_outlined),
            tooltip: 'Export CSV',
            onPressed: (_exporting || _rows.isEmpty) ? null : _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: _loading ? null : _reload,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _FiltersBar(
            dateRange: _dateRange,
            actorFilter: _actorFilter,
            actorOptions: _actorOptions,
            actionFilter: _actionFilter,
            allActions: _allActions,
            tableFilter: _tableFilter,
            tableOptions: _tableOptions,
            onPickDateRange: _pickDateRange,
            onActorChanged: (id) {
              setState(() => _actorFilter = id);
              _reload();
            },
            onToggleAction: _toggleActionFilter,
            onTableChanged: (t) {
              setState(() => _tableFilter = t);
              _reload();
            },
          ),
          if (_pendingRealtimeRows.isNotEmpty)
            _RealtimeBanner(
              count: _pendingRealtimeRows.length,
              onTap: _mergePendingRealtimeRows,
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 40, color: BrandColors.error),
              const SizedBox(height: 10),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return _EmptyState(
        dateRange: _dateRange,
        anyFilterActive: _actorFilter != null ||
            _tableFilter != null ||
            _actionFilter.isNotEmpty,
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _rows.length + (_loadingMore ? 1 : 0),
        itemBuilder: (ctx, index) {
          if (index >= _rows.length) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final row = _rows[index];
          return AuditLogRowCard(
            row: row,
            onTap: () => _openDiffModal(row),
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Filters bar
// ──────────────────────────────────────────────────────────────────────────────

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.dateRange,
    required this.actorFilter,
    required this.actorOptions,
    required this.actionFilter,
    required this.allActions,
    required this.tableFilter,
    required this.tableOptions,
    required this.onPickDateRange,
    required this.onActorChanged,
    required this.onToggleAction,
    required this.onTableChanged,
  });

  final DateTimeRange dateRange;
  final String? actorFilter;
  final List<Map<String, dynamic>> actorOptions;
  final Set<String> actionFilter;
  final List<String> allActions;
  final String? tableFilter;
  final List<String> tableOptions;

  final VoidCallback onPickDateRange;
  final ValueChanged<String?> onActorChanged;
  final ValueChanged<String> onToggleAction;
  final ValueChanged<String?> onTableChanged;

  static final _dateFormatter = DateFormat('MMM d');

  @override
  Widget build(BuildContext context) {
    // TODO: wrap in BrandedCard once design system helper lands.
    return Material(
      color: Colors.grey.shade50,
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text(
                    '${_dateFormatter.format(dateRange.start)} → ${_dateFormatter.format(dateRange.end)}',
                  ),
                  onPressed: onPickDateRange,
                ),
                _ActorDropdown(
                  value: actorFilter,
                  options: actorOptions,
                  onChanged: onActorChanged,
                ),
                _TableDropdown(
                  value: tableFilter,
                  options: tableOptions,
                  onChanged: onTableChanged,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final action in allActions)
                  FilterChip(
                    label: Text(action,
                        style: const TextStyle(fontSize: 11)),
                    selected: actionFilter.contains(action),
                    onSelected: (_) => onToggleAction(action),
                    selectedColor:
                        BrandColors.momentumBlue.withOpacity(0.25),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActorDropdown extends StatelessWidget {
  const _ActorDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String? value;
  final List<Map<String, dynamic>> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String?>(
        value: value,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Actor',
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('All actors'),
          ),
          ...options.map((m) {
            final id = m['id']?.toString() ?? '';
            final name = (m['name'] as String?) ?? '(unnamed)';
            return DropdownMenuItem<String?>(
              value: id,
              child: Text(name, overflow: TextOverflow.ellipsis),
            );
          }),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _TableDropdown extends StatelessWidget {
  const _TableDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String?>(
        value: value,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Table',
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('All tables'),
          ),
          ...options.map((t) => DropdownMenuItem<String?>(
                value: t,
                child: Text(t, overflow: TextOverflow.ellipsis),
              )),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Banners + states
// ──────────────────────────────────────────────────────────────────────────────

class _RealtimeBanner extends StatelessWidget {
  const _RealtimeBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BrandColors.momentumBlue,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.arrow_upward, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                '$count new event${count == 1 ? "" : "s"} — tap to show',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.dateRange,
    required this.anyFilterActive,
  });

  final DateTimeRange dateRange;
  final bool anyFilterActive;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note, size: 42, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              anyFilterActive
                  ? 'No audit events match your filters.'
                  : 'No audit events in this window.',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Window: ${DateFormat('MMM d, y').format(dateRange.start)} → ${DateFormat('MMM d, y').format(dateRange.end)}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
              const Text(
                'Not authorized',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Only superadmins can view the activity log.',
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

// TODO(v2): Overlay auth.audit_log_entries realtime events onto this timeline.
// Cross-schema realtime requires auth schema to be in supabase_realtime
// publication + an RLS-safe view. For v1 we only query public.audit_log.
