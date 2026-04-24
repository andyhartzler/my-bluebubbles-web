import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/dashboard_page.dart';
import 'package:bluebubbles/services/crm/dashboard_pages_service.dart';

/// Modal for creating a new personal dashboard page. The user picks a
/// title and a seed source (universal layout, blank, or duplicate of an
/// existing page).
class AddPageDialog extends StatefulWidget {
  final String userId;        // whose page (auth.users.id)
  final String createdBy;     // who is creating it (auth.users.id)
  final List<DashboardPage> existingPages;

  const AddPageDialog({
    super.key,
    required this.userId,
    required this.createdBy,
    required this.existingPages,
  });

  @override
  State<AddPageDialog> createState() => _AddPageDialogState();
}

class _AddPageDialogState extends State<AddPageDialog> {
  final _service = DashboardPagesService();
  final _title = TextEditingController(text: 'My Dashboard');
  String _seed = 'universal';
  String? _sourcePageId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final created = await _service.createPage(
      userId: widget.userId,
      createdBy: widget.createdBy,
      title: title,
      seed: _seed,
      sourcePageId: _seed == 'page' ? _sourcePageId : null,
    );
    if (!mounted) return;
    if (created == null) {
      setState(() {
        _saving = false;
        _error = 'Failed to create page (page cap reached or insert blocked)';
      });
      return;
    }
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a dashboard page'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Seed from', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            RadioListTile<String>(
              dense: true,
              title: const Text('Universal layout'),
              subtitle: const Text('Copy the global Dashboard'),
              value: 'universal',
              groupValue: _seed,
              onChanged: (v) => setState(() => _seed = v ?? 'universal'),
            ),
            RadioListTile<String>(
              dense: true,
              title: const Text('Blank'),
              subtitle: const Text('Empty grid'),
              value: 'blank',
              groupValue: _seed,
              onChanged: (v) => setState(() => _seed = v ?? 'universal'),
            ),
            if (widget.existingPages.isNotEmpty)
              RadioListTile<String>(
                dense: true,
                title: const Text('Duplicate existing page'),
                value: 'page',
                groupValue: _seed,
                onChanged: (v) => setState(() => _seed = v ?? 'universal'),
              ),
            if (_seed == 'page' && widget.existingPages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Source page',
                    border: OutlineInputBorder(),
                  ),
                  value: _sourcePageId ?? widget.existingPages.first.id,
                  items: widget.existingPages
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.title),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _sourcePageId = v),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
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
