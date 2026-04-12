import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/call_time_list.dart';
import 'package:bluebubbles/services/crm/call_time_repository.dart';
import 'package:bluebubbles/services/crm/mec_repository.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _callStatuses = [
  'pending',
  'called',
  'no_answer',
  'left_message',
  'pledged',
  'declined',
  'skipped',
];

const _statusLabels = {
  'pending': 'Pending',
  'called': 'Called',
  'no_answer': 'No Answer',
  'left_message': 'Left Message',
  'pledged': 'Pledged',
  'declined': 'Declined',
  'skipped': 'Skipped',
};

Color _statusColor(String status) {
  switch (status) {
    case 'pending':
      return Colors.grey;
    case 'called':
      return Colors.blue;
    case 'no_answer':
      return Colors.orange;
    case 'left_message':
      return Colors.yellow.shade700;
    case 'pledged':
      return BrandColors.success;
    case 'declined':
      return Colors.red;
    case 'skipped':
      return Colors.grey.shade400;
    default:
      return Colors.grey;
  }
}

final _currencyFormat = NumberFormat.simpleCurrency();

// ---------------------------------------------------------------------------
// Party colors
// ---------------------------------------------------------------------------

const _partyOptions = ['All', 'Democrat', 'Republican', 'Progressive', 'Conservative'];

Color _partyColor(String? party) {
  if (party == null || party.isEmpty) return Colors.grey;
  final lower = party.toLowerCase();
  if (lower.contains('democrat')) return BrandColors.democratBlue;
  if (lower.contains('republican')) return BrandColors.republicanRed;
  if (lower.contains('progressive')) return const Color(0xFF10B981); // green
  if (lower.contains('conservative')) return Colors.orange;
  return Colors.grey;
}

String _partyLabel(String? party) {
  if (party == null || party.isEmpty) return '';
  final lower = party.toLowerCase();
  if (lower.contains('democrat')) return 'D';
  if (lower.contains('republican')) return 'R';
  if (lower.contains('progressive')) return 'P';
  if (lower.contains('conservative')) return 'C';
  return '?';
}

// ---------------------------------------------------------------------------
// CallTimeTab
// ---------------------------------------------------------------------------

class CallTimeTab extends StatefulWidget {
  const CallTimeTab({super.key});

  @override
  State<CallTimeTab> createState() => _CallTimeTabState();
}

class _CallTimeTabState extends State<CallTimeTab> {
  final CallTimeRepository _repo = CallTimeRepository();
  final MecRepository _mecRepo = MecRepository();

  // State
  List<CallTimeList> _lists = [];
  CallTimeList? _selectedList;
  bool _loading = false;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _loadLists() async {
    setState(() => _loading = true);
    try {
      final status = _statusFilter == 'all' ? null : _statusFilter;
      final lists = await _repo.fetchLists(status: status);
      if (mounted) {
        setState(() {
          _lists = lists;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError('Failed to load lists: $e');
      }
    }
  }

  Future<void> _loadListDetail(int listId) async {
    setState(() => _loading = true);
    try {
      final list = await _repo.fetchListWithItems(listId);
      if (mounted) {
        setState(() {
          _selectedList = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError('Failed to load list: $e');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: BrandColors.error),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: BrandColors.success),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return _selectedList != null ? _buildDetailView() : _buildListsView();
  }

  // ===========================================================================
  // LISTS VIEW
  // ===========================================================================

  Widget _buildListsView() {
    return Column(
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                'Call Time Lists',
                style: BrandTextStyles.titleLarge,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: _loadLists,
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _showCreateListDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New List'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.unityBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ),

        // Status filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Active', 'active'),
                const SizedBox(width: 8),
                _buildFilterChip('Completed', 'completed'),
                const SizedBox(width: 8),
                _buildFilterChip('Archived', 'archived'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // List content
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: BrandColors.sunriseGold,
                  ),
                )
              : _lists.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: _lists.length,
                      itemBuilder: (context, index) =>
                          _buildListCard(_lists[index]),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontSize: 13,
        ),
      ),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _statusFilter = value);
        _loadLists();
      },
      selectedColor: BrandColors.momentumBlue,
      backgroundColor: BrandColors.unityBlue.withOpacity(0.6),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? BrandColors.momentumBlue
              : Colors.white24,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_callback_outlined,
                size: 64, color: Colors.white30),
            const SizedBox(height: 16),
            Text(
              'No call time lists yet.\nCreate one to start tracking fundraising calls.',
              textAlign: TextAlign.center,
              style: BrandTextStyles.bodySecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(CallTimeList list) {
    final progress = list.progressPercent;
    final statusColor = _listStatusColor(list.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BrandedCard(
        onTap: () => _loadListDetail(list.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with status chip and delete button
            Row(
              children: [
                Expanded(
                  child: Text(list.name, style: BrandTextStyles.title),
                ),
                _buildStatusChip(list.status, statusColor),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.white70, size: 20),
                  onPressed: () => _confirmDeleteList(list),
                  tooltip: 'Delete list',
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),

            // Description
            if (list.description != null && list.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(list.description!, style: BrandTextStyles.subtitle),
            ],

            // Filter summary chips
            if (list.filters != null && list.filters!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildFilterSummary(list.filters!),
            ],

            const SizedBox(height: 12),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: BrandColors.navyBlue,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    BrandColors.sunriseGold),
                minHeight: 6,
              ),
            ),

            const SizedBox(height: 8),

            // Stats row
            Text(
              '${list.totalCalled}/${list.totalItems} called'
              ' \u2022 '
              '${_currencyFormat.format(list.totalPledged)} pledged',
              style: BrandTextStyles.bodySecondary,
            ),
          ],
        ),
      ),
    );
  }

  /// Show a compact summary of the saved filter criteria on list cards.
  Widget _buildFilterSummary(Map<String, dynamic> filters) {
    final chips = <Widget>[];

    final party = filters['party'] as String?;
    if (party != null && party.isNotEmpty && party != 'All') {
      chips.add(_buildMiniChip(party, _partyColor(party)));
    }

    final state = filters['state'] as String?;
    if (state != null && state.isNotEmpty) {
      chips.add(_buildMiniChip(state, BrandColors.momentumBlue));
    }

    final yearFrom = filters['yearFrom'];
    final yearTo = filters['yearTo'];
    if (yearFrom != null || yearTo != null) {
      final label = '${yearFrom ?? '...'}-${yearTo ?? '...'}';
      chips.add(_buildMiniChip(label, BrandColors.slateBlue));
    }

    final minTotal = filters['minTotal'];
    if (minTotal != null) {
      chips.add(_buildMiniChip(
        '\$${NumberFormat.compact().format(minTotal)}+',
        BrandColors.sunriseGold,
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: chips,
    );
  }

  Widget _buildMiniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildStatusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _listStatusColor(String status) {
    switch (status) {
      case 'active':
        return BrandColors.success;
      case 'completed':
        return Colors.blue;
      case 'archived':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // ===========================================================================
  // LIST DETAIL VIEW
  // ===========================================================================

  Widget _buildDetailView() {
    final list = _selectedList!;

    // Sort items: pending first, then by priority desc
    final sortedItems = List<CallTimeListItem>.from(list.items)
      ..sort((a, b) {
        final aPending = a.callStatus == 'pending' ? 0 : 1;
        final bPending = b.callStatus == 'pending' ? 0 : 1;
        if (aPending != bPending) return aPending.compareTo(bPending);
        return b.priority.compareTo(a.priority);
      });

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() => _selectedList = null);
                  _loadLists();
                },
              ),
              Expanded(
                child: Text(
                  list.name,
                  style: BrandTextStyles.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: () => _loadListDetail(list.id),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),

        // Stats bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              _buildStatCard('Total', list.totalItems.toString()),
              const SizedBox(width: 8),
              _buildStatCard('Called', list.totalCalled.toString()),
              const SizedBox(width: 8),
              _buildStatCard(
                  'Pledged', _currencyFormat.format(list.totalPledged)),
            ],
          ),
        ),

        // Items list
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: BrandColors.sunriseGold))
              : sortedItems.isEmpty
                  ? Center(
                      child: Text(
                        'No donors in this list yet.\nTap the button below to add donors.',
                        textAlign: TextAlign.center,
                        style: BrandTextStyles.bodySecondary,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      itemCount: sortedItems.length,
                      itemBuilder: (context, index) =>
                          _buildItemCard(sortedItems[index]),
                    ),
        ),

        // Add donors button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddDonorsDialog(list.id),
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Add Donors'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BrandColors.unityBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: BrandColors.unityBlue.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(label, style: BrandTextStyles.caption),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Item card (expandable)
  // ---------------------------------------------------------------------------

  Widget _buildItemCard(CallTimeListItem item) {
    final donor = item.mecDonor;
    final city = donor?['city'] as String? ?? '';
    final state = donor?['state'] as String? ?? '';
    final employer = donor?['employer'] as String? ?? '';
    final location =
        [city, state].where((s) => s.isNotEmpty).join(', ');

    // Extract party info from joined mec_donors data
    final party = donor?['party'] as String?;

    final statusColor = _statusColor(item.callStatus);
    final statusLabel =
        _statusLabels[item.callStatus] ?? item.callStatus;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BrandedCard(
        padding: EdgeInsets.zero,
        child: _ExpandableItemTile(
          item: item,
          location: location,
          employer: employer,
          party: party,
          statusLabel: statusLabel,
          statusColor: statusColor,
          onSave: (status, notes, pledged) =>
              _saveItem(item, status, notes, pledged),
          onCall: () => _launchCall(item),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _saveItem(
    CallTimeListItem item,
    String status,
    String? notes,
    double? pledgedAmount,
  ) async {
    try {
      await _repo.updateItem(
        item.id,
        callStatus: status,
        callNotes: notes,
        pledgedAmount: status == 'pledged' ? pledgedAmount : null,
      );
      // Refresh the counts on the list
      await _loadListDetail(_selectedList!.id);
      _showSuccess('Item updated');
    } catch (e) {
      _showError('Failed to update: $e');
    }
  }

  Future<void> _launchCall(CallTimeListItem item) async {
    final phone = item.mecDonor?['phone'] as String?;
    if (phone == null || phone.isEmpty) {
      _showError('No phone number available for this donor');
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showError('Could not launch phone dialer');
    }
  }

  // ---------------------------------------------------------------------------
  // Create list dialog (enhanced with Smart List Builder filters)
  // ---------------------------------------------------------------------------

  Future<void> _showCreateListDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    // Filter state for the dialog
    String filterParty = 'All';

    int yearFrom = DateTime.now().year - 1;
    int yearTo = DateTime.now().year;
    final minTotalController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: BrandColors.unityBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('New Call Time List',
                  style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      TextField(
                        controller: nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Name *'),
                        autofocus: true,
                      ),
                      const SizedBox(height: 12),

                      // Description
                      TextField(
                        controller: descController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Description (optional)'),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.sunriseGold,
                    foregroundColor: BrandColors.unityBlue,
                  ),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      // Build filters JSONB from the dialog state
      final filters = <String, dynamic>{};
      if (filterParty != 'All') filters['party'] = filterParty;
      filters['yearFrom'] = yearFrom;
      filters['yearTo'] = yearTo;
      final minTotal = double.tryParse(minTotalController.text);
      if (minTotal != null) filters['minTotal'] = minTotal;

      try {
        await _repo.createList(
          name: nameController.text.trim(),
          description: descController.text.trim().isEmpty
              ? null
              : descController.text.trim(),
          filters: filters.isEmpty ? null : filters,
        );
        _showSuccess('List created');
        _loadLists();
      } catch (e) {
        _showError('Failed to create list: $e');
      }
    }

    nameController.dispose();
    descController.dispose();
    minTotalController.dispose();
  }

  // ---------------------------------------------------------------------------
  // Delete list confirmation
  // ---------------------------------------------------------------------------

  Future<void> _confirmDeleteList(CallTimeList list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrandColors.unityBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Delete List?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${list.name}"? '
          'This will also remove all items in the list.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repo.deleteList(list.id);
        _showSuccess('List deleted');
        _loadLists();
      } catch (e) {
        _showError('Failed to delete list: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Add donors dialog (Smart Donor Search)
  // ---------------------------------------------------------------------------

  Future<void> _showAddDonorsDialog(int listId) async {
    // Pre-populate filters from the list's saved filters if available
    final listFilters = _selectedList?.filters;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _SmartDonorSearchDialog(
          mecRepo: _mecRepo,
          initialFilters: listFilters,
          onAdd: (donorIds, suggestedAsk) async {
            try {
              await _repo.addItems(
                listId: listId,
                donorIds: donorIds,
                suggestedAsk: suggestedAsk,
              );
              _showSuccess('${donorIds.length} donor(s) added');
              _loadListDetail(listId);
            } catch (e) {
              _showError('Failed to add donors: $e');
            }
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label.isEmpty ? null : label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: BrandColors.momentumBlue),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}

// =============================================================================
// _ExpandableItemTile -- stateful widget for individual call items
// =============================================================================

class _ExpandableItemTile extends StatefulWidget {
  final CallTimeListItem item;
  final String location;
  final String employer;
  final String? party;
  final String statusLabel;
  final Color statusColor;
  final Future<void> Function(String status, String? notes, double? pledged)
      onSave;
  final VoidCallback onCall;

  const _ExpandableItemTile({
    required this.item,
    required this.location,
    required this.employer,
    this.party,
    required this.statusLabel,
    required this.statusColor,
    required this.onSave,
    required this.onCall,
  });

  @override
  State<_ExpandableItemTile> createState() => _ExpandableItemTileState();
}

class _ExpandableItemTileState extends State<_ExpandableItemTile> {
  bool _expanded = false;
  late String _selectedStatus;
  late TextEditingController _notesController;
  late TextEditingController _pledgedController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.item.callStatus;
    _notesController =
        TextEditingController(text: widget.item.callNotes ?? '');
    _pledgedController = TextEditingController(
      text: widget.item.pledgedAmount != null
          ? widget.item.pledgedAmount!.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void didUpdateWidget(covariant _ExpandableItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _selectedStatus = widget.item.callStatus;
      _notesController.text = widget.item.callNotes ?? '';
      _pledgedController.text = widget.item.pledgedAmount != null
          ? widget.item.pledgedAmount!.toStringAsFixed(2)
          : '';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _pledgedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Party indicator dot
                if (widget.party != null && widget.party!.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 8),
                    child: _buildPartyDot(widget.party!),
                  ),
                ],
                // Left: donor info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.location.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(widget.location,
                            style: BrandTextStyles.bodySecondary),
                      ],
                      if (widget.employer.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(widget.employer,
                            style: BrandTextStyles.caption),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Right: suggested ask + status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (widget.item.suggestedAsk != null)
                      Text(
                        _currencyFormat.format(widget.item.suggestedAsk),
                        style: const TextStyle(
                          color: BrandColors.sunriseGold,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 4),
                    _buildCallStatusChip(
                        widget.statusLabel, widget.statusColor),
                  ],
                ),
              ],
            ),

            // Expanded section
            if (_expanded) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 12),

              // Status dropdown
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                dropdownColor: BrandColors.unityBlue,
                style: const TextStyle(color: Colors.white),
                decoration: _expandedInputDecoration('Call Status'),
                items: _callStatuses
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                            _statusLabels[s] ?? s,
                            style: TextStyle(color: _statusColor(s)),
                          ),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedStatus = val);
                },
              ),

              const SizedBox(height: 12),

              // Notes
              TextField(
                controller: _notesController,
                style: const TextStyle(color: Colors.white),
                decoration: _expandedInputDecoration('Notes'),
                maxLines: 2,
              ),

              // Pledged amount (only when pledged)
              if (_selectedStatus == 'pledged') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _pledgedController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _expandedInputDecoration('Pledged Amount (\$)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ],

              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _handleSave,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save, size: 18),
                      label: const Text('Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BrandColors.momentumBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: widget.onCall,
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BrandColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPartyDot(String party) {
    final color = _partyColor(party);
    final label = _partyLabel(party);
    return Tooltip(
      message: party,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: color.withOpacity(0.25),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCallStatusChip(String label, Color color) {
    final isSkipped = widget.item.callStatus == 'skipped';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isSkipped ? Colors.transparent : color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.7)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _expandedInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: BrandColors.momentumBlue),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Future<void> _handleSave() async {
    setState(() => _saving = true);
    double? pledged;
    if (_selectedStatus == 'pledged' && _pledgedController.text.isNotEmpty) {
      pledged = double.tryParse(_pledgedController.text);
    }
    await widget.onSave(
      _selectedStatus,
      _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      pledged,
    );
    if (mounted) setState(() => _saving = false);
  }
}

// =============================================================================
// _SmartDonorSearchDialog -- full-screen dialog for smart donor search
// =============================================================================

class _SmartDonorSearchDialog extends StatefulWidget {
  final MecRepository mecRepo;
  final Map<String, dynamic>? initialFilters;
  final Future<void> Function(List<int> donorIds, double? suggestedAsk) onAdd;

  const _SmartDonorSearchDialog({
    required this.mecRepo,
    this.initialFilters,
    required this.onAdd,
  });

  @override
  State<_SmartDonorSearchDialog> createState() =>
      _SmartDonorSearchDialogState();
}

class _SmartDonorSearchDialogState extends State<_SmartDonorSearchDialog> {
  // Search / filter controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _askController = TextEditingController();
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _employerController = TextEditingController();
  final TextEditingController _occupationController = TextEditingController();

  String _partyFilter = 'All';
  String? _genderFilter;
  int _yearFrom = DateTime.now().year - 1;
  int _yearTo = DateTime.now().year;
  double _ageMin = 18;
  double _ageMax = 100;
  bool _hasPhone = false;
  bool _hasEmail = false;
  bool _filtersExpanded = true;

  List<Map<String, dynamic>> _results = [];
  final Set<int> _selectedIds = {};
  bool _searching = false;
  bool _hasSearched = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Pre-populate from list's saved filters
    final f = widget.initialFilters;
    if (f != null) {
      _partyFilter = (f['party'] as String?) ?? 'All';
      final yf = f['yearFrom'];
      if (yf != null) _yearFrom = (yf as num).toInt();
      final yt = f['yearTo'];
      if (yt != null) _yearTo = (yt as num).toInt();
      final mt = f['minTotal'];
      if (mt != null) _minAmountController.text = mt.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _askController.dispose();
    _minAmountController.dispose();
    _employerController.dispose();
    _occupationController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _hasSearched = true;
    });
    try {
      final results = await widget.mecRepo.searchDonors(
        party: _partyFilter != 'All' ? _partyFilter : null,
        yearFrom: _yearFrom,
        yearTo: _yearTo,
        minTotal: double.tryParse(_minAmountController.text),
        nameQuery:
            _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
        gender: _genderFilter,
        ageMin: _ageMin > 18 ? _ageMin.round() : null,
        ageMax: _ageMax < 100 ? _ageMax.round() : null,
        employer: _employerController.text.trim().isNotEmpty
            ? _employerController.text.trim()
            : null,
        occupation: _occupationController.text.trim().isNotEmpty
            ? _occupationController.text.trim()
            : null,
        hasPhone: _hasPhone ? true : null,
        hasEmail: _hasEmail ? true : null,
        individualsOnly: true,
        limit: 100,
      );
      if (mounted) {
        setState(() {
          _results = results;
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _searching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: $e'),
            backgroundColor: BrandColors.error,
          ),
        );
      }
    }
  }

  void _onNameChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _search();
    });
  }

  InputDecoration _filterInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: BrandColors.momentumBlue),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      isDense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: EdgeInsets.only(top: topPadding + 40),
        decoration: const BoxDecoration(
          color: Color(0xFF1E2A42),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  const Icon(Icons.person_search,
                      color: BrandColors.sunriseGold, size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Smart Donor Search',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 16),

            // Content
            Expanded(
              child: Column(
                children: [
                  // Filters section (collapsible)
                  _buildFiltersSection(),

                  // Results
                  Expanded(child: _buildResults()),
                ],
              ),
            ),

            // Bottom action bar
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          // Collapsible header
          InkWell(
            onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    _filtersExpanded
                        ? Icons.filter_list
                        : Icons.filter_list_off,
                    color: BrandColors.momentumBlue,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Filters',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _filtersExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white70,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          if (_filtersExpanded) ...[
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name search
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search by donor name...',
                      hintStyle:
                          const TextStyle(color: Colors.white54, fontSize: 14),
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.white70, size: 20),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: BrandColors.momentumBlue),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    onChanged: _onNameChanged,
                  ),
                  const SizedBox(height: 10),

                  // Row 1: Party + Gender
                  Row(
                    children: [
                      // Party
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _partyFilter,
                          dropdownColor: BrandColors.unityBlue,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          decoration: _filterInputDecoration('Party'),
                          items: _partyOptions
                              .map((p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p,
                                        style: TextStyle(
                                          color: p == 'All'
                                              ? Colors.white
                                              : _partyColor(p),
                                          fontSize: 13,
                                        )),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _partyFilter = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Gender
                      SizedBox(
                        width: 110,
                        child: DropdownButtonFormField<String?>(
                          value: _genderFilter,
                          dropdownColor: BrandColors.unityBlue,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          decoration: _filterInputDecoration('Gender'),
                          items: const [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Any',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 13)),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'Male',
                              child: Text('Male',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 13)),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'Female',
                              child: Text('Female',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 13)),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() => _genderFilter = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Year range slider
                  Row(
                    children: [
                      Text('$_yearFrom', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                      Expanded(
                        child: RangeSlider(
                          values: RangeValues(_yearFrom.toDouble(), _yearTo.toDouble()),
                          min: 2002,
                          max: DateTime.now().year.toDouble(),
                          divisions: DateTime.now().year - 2002,
                          labels: RangeLabels('$_yearFrom', '$_yearTo'),
                          activeColor: BrandColors.sunriseGold,
                          inactiveColor: Colors.white24,
                          onChanged: (values) {
                            setState(() {
                              _yearFrom = values.start.round();
                              _yearTo = values.end.round();
                            });
                          },
                        ),
                      ),
                      Text('$_yearTo', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),

                  // Age range slider
                  Text(
                    'Age: ${_ageMin.round()} - ${_ageMax.round()}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  RangeSlider(
                    values: RangeValues(_ageMin, _ageMax),
                    min: 18,
                    max: 100,
                    divisions: 82,
                    labels: RangeLabels('${_ageMin.round()}', '${_ageMax.round()}'),
                    activeColor: BrandColors.momentumBlue,
                    inactiveColor: Colors.white24,
                    onChanged: (values) {
                      setState(() {
                        _ageMin = values.start;
                        _ageMax = values.end;
                      });
                    },
                  ),
                  const SizedBox(height: 6),

                  // Row: Min amount
                  TextField(
                    controller: _minAmountController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _filterInputDecoration('Min \$ Total'),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                  const SizedBox(height: 10),

                  // Row: Employer + Occupation
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _employerController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: _filterInputDecoration('Employer'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _occupationController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: _filterInputDecoration('Occupation'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Row: Has Phone + Has Email checkboxes
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _hasPhone = !_hasPhone),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _hasPhone,
                                  onChanged: (val) =>
                                      setState(() => _hasPhone = val ?? false),
                                  activeColor: BrandColors.sunriseGold,
                                  checkColor: BrandColors.unityBlue,
                                  side: const BorderSide(color: Colors.white38),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.phone, size: 14, color: Colors.white70),
                              const SizedBox(width: 4),
                              const Text('Has Phone',
                                  style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _hasEmail = !_hasEmail),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _hasEmail,
                                  onChanged: (val) =>
                                      setState(() => _hasEmail = val ?? false),
                                  activeColor: BrandColors.sunriseGold,
                                  checkColor: BrandColors.unityBlue,
                                  side: const BorderSide(color: Colors.white38),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.email, size: 14, color: Colors.white70),
                              const SizedBox(width: 4),
                              const Text('Has Email',
                                  style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Search button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _searching ? null : _search,
                      icon: _searching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.search, size: 18),
                      label: Text(_searching ? 'Searching...' : 'Search Donors'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BrandColors.momentumBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
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

  Widget _buildResults() {
    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              'Set filters and tap Search\nto find donors',
              textAlign: TextAlign.center,
              style: BrandTextStyles.bodySecondary,
            ),
          ],
        ),
      );
    }

    if (_searching) {
      return const Center(
        child: CircularProgressIndicator(color: BrandColors.sunriseGold),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(
          'No donors found matching your criteria.\nTry adjusting the filters.',
          textAlign: TextAlign.center,
          style: BrandTextStyles.bodySecondary,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                '${_results.length} donor${_results.length == 1 ? '' : 's'} found',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (_selectedIds.isNotEmpty)
                Text(
                  '${_selectedIds.length} selected',
                  style: const TextStyle(
                    color: BrandColors.sunriseGold,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(width: 8),
              // Select all / deselect all
              if (_results.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_selectedIds.length == _results.length) {
                        _selectedIds.clear();
                      } else {
                        _selectedIds.clear();
                        for (final r in _results) {
                          final id = (r['donor_id'] as num?)?.toInt();
                          if (id != null) _selectedIds.add(id);
                        }
                      }
                    });
                  },
                  child: Text(
                    _selectedIds.length == _results.length
                        ? 'Deselect All'
                        : 'Select All',
                    style: const TextStyle(
                      color: BrandColors.momentumBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Results list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: _results.length,
            itemBuilder: (ctx, index) {
              final donor = _results[index];
              return _buildDonorResultTile(donor);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDonorResultTile(Map<String, dynamic> donor) {
    final donorId = (donor['donor_id'] as num?)?.toInt();
    final name = donor['donor_name'] as String? ?? 'Unknown';
    final totalGiven = (donor['total_amount'] as num?)?.toDouble() ?? 0;
    final numContributions = (donor['contribution_count'] as num?)?.toInt() ?? 0;
    final city = donor['city'] as String? ?? '';
    final state = donor['state'] as String? ?? '';
    final location = [city, state].where((s) => s.isNotEmpty).join(', ');
    final parties = donor['parties'] as List<dynamic>? ?? [];

    // Enrichment data from search_donors_v2
    final partyLean = donor['party_lean'] as String?;
    final ageEstimate = (donor['age_estimate'] as num?)?.toInt();
    final phoneMobile = donor['phone_mobile'] as String?;
    final phoneHome = donor['phone_home'] as String?;
    final hasPhoneData = (phoneMobile != null && phoneMobile.isNotEmpty) ||
        (phoneHome != null && phoneHome.isNotEmpty);

    final isSelected = donorId != null && _selectedIds.contains(donorId);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? BrandColors.momentumBlue.withOpacity(0.15)
            : BrandColors.unityBlue.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? BrandColors.momentumBlue.withOpacity(0.5)
              : Colors.white12,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: donorId == null
            ? null
            : () {
                setState(() {
                  if (_selectedIds.contains(donorId)) {
                    _selectedIds.remove(donorId);
                  } else {
                    _selectedIds.add(donorId);
                  }
                });
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Checkbox
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: isSelected,
                  onChanged: donorId == null
                      ? null
                      : (val) {
                          setState(() {
                            if (val == true) {
                              _selectedIds.add(donorId);
                            } else {
                              _selectedIds.remove(donorId);
                            }
                          });
                        },
                  activeColor: BrandColors.sunriseGold,
                  checkColor: BrandColors.unityBlue,
                  side: const BorderSide(color: Colors.white38),
                ),
              ),
              const SizedBox(width: 10),

              // Donor info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name row with party chips
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (parties.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          ...parties.take(3).map((p) {
                            final partyStr = p.toString();
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: _buildPartyChip(partyStr),
                            );
                          }),
                        ],
                        if (partyLean != null && partyLean.isNotEmpty && parties.isEmpty) ...[
                          const SizedBox(width: 6),
                          _buildPartyChip(partyLean),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Details row with enrichment data
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            [
                              if (location.isNotEmpty) location,
                              '$numContributions contribution${numContributions == 1 ? '' : 's'}',
                              if (ageEstimate != null) 'Age ~$ageEstimate',
                            ].join(' \u2022 '),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasPhoneData)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.phone, size: 13, color: BrandColors.success),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Total amount
              Text(
                _currencyFormat.format(totalGiven),
                style: const TextStyle(
                  color: BrandColors.sunriseGold,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartyChip(String party) {
    final color = _partyColor(party);
    final label = _partyLabel(party);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1A2438),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          // Suggested ask
          Expanded(
            child: TextField(
              controller: _askController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Suggested Ask (\$)',
                labelStyle:
                    const TextStyle(color: Colors.white70, fontSize: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: BrandColors.momentumBlue),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(width: 12),

          // Add button
          ElevatedButton.icon(
            onPressed: _selectedIds.isEmpty
                ? null
                : () async {
                    final ask = double.tryParse(_askController.text);
                    Navigator.pop(context);
                    await widget.onAdd(_selectedIds.toList(), ask);
                  },
            icon: const Icon(Icons.person_add, size: 18),
            label: Text(
              _selectedIds.isEmpty
                  ? 'Add Selected'
                  : 'Add ${_selectedIds.length}',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.sunriseGold,
              foregroundColor: BrandColors.unityBlue,
              disabledBackgroundColor: Colors.white12,
              disabledForegroundColor: Colors.white38,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
