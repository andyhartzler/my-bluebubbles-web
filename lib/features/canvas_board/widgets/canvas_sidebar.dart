import 'package:flutter/material.dart';

import 'package:bluebubbles/features/canvas_board/models/canvas_node.dart';

/// Sidebar for the canvas board with entity addition and zoom controls
class CanvasSidebar extends StatelessWidget {
  final VoidCallback onAddMember;
  final VoidCallback onAddEvent;
  final VoidCallback onAddChapter;
  final VoidCallback onAddDonor;
  final VoidCallback onAddNote;
  final VoidCallback onAddImage;
  final VoidCallback onAddFile;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitView;
  final VoidCallback onResetView;
  final double zoomLevel;
  final bool showDonors;
  final bool showChapters;

  const CanvasSidebar({
    super.key,
    required this.onAddMember,
    required this.onAddEvent,
    required this.onAddChapter,
    required this.onAddDonor,
    required this.onAddNote,
    required this.onAddImage,
    required this.onAddFile,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitView,
    required this.onResetView,
    required this.zoomLevel,
    this.showDonors = false,
    this.showChapters = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('Add Entity'),
          _buildEntityButton(
            icon: Icons.person_add,
            label: 'Add Member',
            color: const Color(0xFF2196F3),
            onTap: onAddMember,
          ),
          _buildEntityButton(
            icon: Icons.event,
            label: 'Add Event',
            color: const Color(0xFFFF9800),
            onTap: onAddEvent,
          ),
          if (showChapters)
            _buildEntityButton(
              icon: Icons.account_tree,
              label: 'Add Chapter',
              color: const Color(0xFF4CAF50),
              onTap: onAddChapter,
            ),
          if (showDonors)
            _buildEntityButton(
              icon: Icons.volunteer_activism,
              label: 'Add Donor',
              color: const Color(0xFF9C27B0),
              onTap: onAddDonor,
            ),
          const Divider(),
          _buildSectionHeader('Add Content'),
          _buildEntityButton(
            icon: Icons.note_add,
            label: 'Add Note',
            color: const Color(0xFFFFC107),
            onTap: onAddNote,
          ),
          _buildEntityButton(
            icon: Icons.add_photo_alternate,
            label: 'Add Image',
            color: const Color(0xFF00BCD4),
            onTap: onAddImage,
          ),
          _buildEntityButton(
            icon: Icons.upload_file,
            label: 'Add File',
            color: const Color(0xFF607D8B),
            onTap: onAddFile,
          ),
          const Spacer(),
          const Divider(),
          _buildSectionHeader('View'),
          _buildZoomControls(context),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildEntityButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoomControls(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildZoomButton(
                  icon: Icons.zoom_out,
                  tooltip: 'Zoom Out',
                  onTap: onZoomOut,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${(zoomLevel * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildZoomButton(
                  icon: Icons.zoom_in,
                  tooltip: 'Zoom In',
                  onTap: onZoomIn,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildZoomButton(
                  icon: Icons.fit_screen,
                  tooltip: 'Fit View',
                  onTap: onFitView,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildZoomButton(
                  icon: Icons.center_focus_strong,
                  tooltip: 'Reset View',
                  onTap: onResetView,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZoomButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: Colors.grey[700]),
          ),
        ),
      ),
    );
  }
}
