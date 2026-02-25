import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/call_time_list.dart';
import 'package:bluebubbles/models/crm/mec_contribution.dart';
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
                      color: Colors.white54, size: 20),
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
  // Create list dialog
  // ---------------------------------------------------------------------------

  Future<void> _showCreateListDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: BrandColors.unityBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('New Call Time List',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Name *'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Description (optional)'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white70)),
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

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        await _repo.createList(
          name: nameController.text.trim(),
          description: descController.text.trim().isEmpty
              ? null
              : descController.text.trim(),
        );
        _showSuccess('List created');
        _loadLists();
      } catch (e) {
        _showError('Failed to create list: $e');
      }
    }

    nameController.dispose();
    descController.dispose();
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
  // Add donors dialog
  // ---------------------------------------------------------------------------

  Future<void> _showAddDonorsDialog(int listId) async {
    await showDialog(
      context: context,
      builder: (ctx) => _AddDonorsDialog(
        mecRepo: _mecRepo,
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
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: BrandColors.momentumBlue),
      ),
    );
  }
}

// =============================================================================
// _ExpandableItemTile — stateful widget for individual call items
// =============================================================================

class _ExpandableItemTile extends StatefulWidget {
  final CallTimeListItem item;
  final String location;
  final String employer;
  final String statusLabel;
  final Color statusColor;
  final Future<void> Function(String status, String? notes, double? pledged)
      onSave;
  final VoidCallback onCall;

  const _ExpandableItemTile({
    required this.item,
    required this.location,
    required this.employer,
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
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
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
// _AddDonorsDialog — search MEC contributions and add donors to a list
// =============================================================================

class _AddDonorsDialog extends StatefulWidget {
  final MecRepository mecRepo;
  final Future<void> Function(List<int> donorIds, double? suggestedAsk) onAdd;

  const _AddDonorsDialog({
    required this.mecRepo,
    required this.onAdd,
  });

  @override
  State<_AddDonorsDialog> createState() => _AddDonorsDialogState();
}

class _AddDonorsDialogState extends State<_AddDonorsDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _askController = TextEditingController();

  List<MecContribution> _results = [];
  final Set<int> _selectedIds = {};
  bool _searching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _askController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await widget.mecRepo.searchContributions(
        query: query.trim(),
        limit: 50,
      );
      if (mounted) {
        setState(() {
          _results = results;
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: BrandColors.unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Add Donors', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(
          children: [
            // Search field
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by name, company, or committee...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white54),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: BrandColors.sunriseGold,
                          ),
                        ),
                      )
                    : null,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: BrandColors.momentumBlue),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 8),

            // Suggested ask field
            TextField(
              controller: _askController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Suggested Ask (\$, optional)',
                labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: BrandColors.momentumBlue),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8),

            // Results
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? 'Type to search MEC donors'
                            : 'No results found',
                        style: BrandTextStyles.bodySecondary,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (ctx, index) {
                        final c = _results[index];
                        final isSelected = _selectedIds.contains(c.id);
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedIds.add(c.id);
                              } else {
                                _selectedIds.remove(c.id);
                              }
                            });
                          },
                          activeColor: BrandColors.sunriseGold,
                          checkColor: BrandColors.unityBlue,
                          title: Text(
                            c.contributorDisplayName,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                          ),
                          subtitle: Text(
                            [
                              if (c.city != null) c.city,
                              if (c.state != null) c.state,
                              if (c.contributionAmount != null)
                                c.formattedAmount,
                            ].join(' \u2022 '),
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                          ),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: _selectedIds.isEmpty
              ? null
              : () async {
                  final ask = double.tryParse(_askController.text);
                  Navigator.pop(context);
                  await widget.onAdd(_selectedIds.toList(), ask);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: BrandColors.sunriseGold,
            foregroundColor: BrandColors.unityBlue,
            disabledBackgroundColor: Colors.white12,
            disabledForegroundColor: Colors.white38,
          ),
          child: Text(
            _selectedIds.isEmpty
                ? 'Add Selected'
                : 'Add Selected (${_selectedIds.length})',
          ),
        ),
      ],
    );
  }
}
