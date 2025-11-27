import 'package:flutter/material.dart';

class BuilderToolbar extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onPreview;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;

  const BuilderToolbar({
    super.key,
    required this.onSave,
    required this.onPreview,
    this.onUndo,
    this.onRedo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Undo',
          onPressed: onUndo,
          icon: const Icon(Icons.undo),
        ),
        IconButton(
          tooltip: 'Redo',
          onPressed: onRedo,
          icon: const Icon(Icons.redo),
        ),
        IconButton(
          tooltip: 'Preview',
          onPressed: onPreview,
          icon: const Icon(Icons.visibility_outlined),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: onSave,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save'),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
