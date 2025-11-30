import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/email_builder_provider.dart';

class BuilderToolbar extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onPreview;
  final VoidCallback onTemplates;
  final VoidCallback? onSendTest;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onExportHtml;
  final VoidCallback? onLoadTemplate;
  final VoidCallback? onOpenSettings;

  const BuilderToolbar({
    super.key,
    required this.onSave,
    required this.onPreview,
    required this.onTemplates,
    this.onSendTest,
    this.onUndo,
    this.onRedo,
    this.onExportHtml,
    this.onLoadTemplate,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmailBuilderProvider>();

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back to campaign',
          ),

          const SizedBox(width: 16),
          const _VerticalDivider(),
          const SizedBox(width: 16),

          // Undo/Redo
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: provider.canUndo ? onUndo : null,
            tooltip: 'Undo (Ctrl+Z)',
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: provider.canRedo ? onRedo : null,
            tooltip: 'Redo (Ctrl+Y)',
          ),

          const SizedBox(width: 16),
          const _VerticalDivider(),
          const SizedBox(width: 16),

          // Device toggle
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'mobile',
                icon: Icon(Icons.phone_android, size: 18),
                label: Text('Mobile'),
              ),
              ButtonSegment(
                value: 'desktop',
                icon: Icon(Icons.desktop_windows, size: 18),
                label: Text('Desktop'),
              ),
            ],
            selected: {provider.previewDevice},
            onSelectionChanged: (Set<String> value) {
              if (value.isNotEmpty) {
                provider.setPreviewDevice(value.first);
              }
            },
            style: ButtonStyle(
              padding: MaterialStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Zoom controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.zoom_in, size: 20),
              const SizedBox(width: 8),
              DropdownButton<double>(
                value: provider.zoomLevel,
                underline: Container(),
                items: const [
                  DropdownMenuItem(value: 0.5, child: Text('50%')),
                  DropdownMenuItem(value: 0.75, child: Text('75%')),
                  DropdownMenuItem(value: 1.0, child: Text('100%')),
                  DropdownMenuItem(value: 1.25, child: Text('125%')),
                  DropdownMenuItem(value: 1.5, child: Text('150%')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    provider.setZoomLevel(value);
                  }
                },
              ),
            ],
          ),

          const Spacer(),

          // Preview toggle
          OutlinedButton.icon(
            onPressed: onPreview,
            icon: const Icon(Icons.visibility),
            label: Text(provider.isPreviewMode ? 'Edit' : 'Preview'),
          ),

          const SizedBox(width: 12),

          // Templates
          OutlinedButton.icon(
            onPressed: onTemplates,
            icon: const Icon(Icons.layers_outlined),
            label: const Text('Templates'),
          ),

          const SizedBox(width: 12),

          // Send test
          if (onSendTest != null)
            OutlinedButton.icon(
              onPressed: onSendTest,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Send test'),
            ),

          const SizedBox(width: 12),

          // Save
          ElevatedButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save & Close'),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: Colors.grey[300],
    );
  }
}
