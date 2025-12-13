import 'package:flutter/material.dart';
import '../models/bill_note.dart';
import '../utils/bill_helpers.dart';

/// Panel for displaying and managing bill notes
class BillNotesPanel extends StatefulWidget {
  final List<BillNote> notes;
  final Function(String content, bool isInternal)? onAddNote;
  final Function(BillNote)? onDeleteNote;
  final Function(BillNote, String)? onUpdateNote;
  final bool readOnly;
  final String? currentUserId;
  final String? currentUserName;

  const BillNotesPanel({
    super.key,
    required this.notes,
    this.onAddNote,
    this.onDeleteNote,
    this.onUpdateNote,
    this.readOnly = false,
    this.currentUserId,
    this.currentUserName,
  });

  @override
  State<BillNotesPanel> createState() => _BillNotesPanelState();
}

class _BillNotesPanelState extends State<BillNotesPanel> {
  final _noteController = TextEditingController();
  bool _isInternal = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Text(
              'Notes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${widget.notes.length}',
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Add note form
        if (!widget.readOnly && widget.onAddNote != null) ...[
          _buildAddNoteForm(theme),
          const SizedBox(height: 16),
        ],

        // Notes list
        if (widget.notes.isEmpty)
          _buildEmptyState(theme)
        else
          ...widget.notes.map((note) => _buildNoteCard(theme, note)),
      ],
    );
  }

  Widget _buildAddNoteForm(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: 'Add a note...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              maxLines: 3,
              minLines: 2,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Internal toggle
                Row(
                  children: [
                    Checkbox(
                      value: _isInternal,
                      onChanged: (value) {
                        setState(() => _isInternal = value ?? false);
                      },
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _isInternal = !_isInternal),
                      child: Row(
                        children: [
                          Icon(
                            _isInternal ? Icons.lock : Icons.lock_open,
                            size: 16,
                            color: _isInternal
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Internal only',
                            style: TextStyle(
                              fontSize: 12,
                              color: _isInternal
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _isSubmitting || _noteController.text.trim().isEmpty
                      ? null
                      : _submitNote,
                  icon: _isSubmitting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.add, size: 18),
                  label: const Text('Add Note'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitNote() async {
    if (_noteController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      await widget.onAddNote?.call(_noteController.text.trim(), _isInternal);
      _noteController.clear();
      setState(() => _isInternal = false);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.note_outlined,
              size: 48,
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No notes yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (!widget.readOnly)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Add notes to track important information',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(ThemeData theme, BillNote note) {
    final isOwner = widget.currentUserId == note.createdBy;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: note.isInternal ? 1 : 0,
        color: note.isInternal
            ? theme.colorScheme.secondaryContainer.withOpacity(0.3)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  // Author avatar
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      _getInitials(note.createdByName),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.createdByName ?? 'Unknown',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          BillHelpers.formatRelativeTime(note.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Internal badge
                  if (note.isInternal)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock,
                            size: 10,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Internal',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Actions menu
                  if (!widget.readOnly && isOwner)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditDialog(context, note);
                        } else if (value == 'delete') {
                          _showDeleteConfirmation(context, note);
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Content
              Text(
                note.content,
                style: theme.textTheme.bodyMedium,
              ),
              // Updated indicator
              if (note.updatedAt != null && note.updatedAt != note.createdAt)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Edited ${BillHelpers.formatRelativeTime(note.updatedAt!)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  void _showEditDialog(BuildContext context, BillNote note) {
    final controller = TextEditingController(text: note.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Note'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          maxLines: 5,
          minLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                widget.onUpdateNote?.call(note, controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, BillNote note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              widget.onDeleteNote?.call(note);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
