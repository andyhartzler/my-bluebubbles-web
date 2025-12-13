import 'package:flutter/material.dart';

/// Streamlined sidebar for the canvas board with icon-only buttons
/// Matches the thin profile of the top toolbar
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
  final VoidCallback? onToggleFullscreen;
  final double zoomLevel;
  final bool showDonors;
  final bool showChapters;
  final bool isFullscreen;

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
    this.onToggleFullscreen,
    required this.zoomLevel,
    this.showDonors = false,
    this.showChapters = false,
    this.isFullscreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 52,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Add Entity Section
          _buildIconButton(
            context,
            icon: Icons.person_add,
            tooltip: 'Add Member',
            color: const Color(0xFF2196F3),
            onTap: onAddMember,
          ),
          _buildIconButton(
            context,
            icon: Icons.event,
            tooltip: 'Add Event',
            color: const Color(0xFFFF9800),
            onTap: onAddEvent,
          ),
          if (showChapters)
            _buildIconButton(
              context,
              icon: Icons.account_tree,
              tooltip: 'Add Chapter',
              color: const Color(0xFF4CAF50),
              onTap: onAddChapter,
            ),
          if (showDonors)
            _buildIconButton(
              context,
              icon: Icons.volunteer_activism,
              tooltip: 'Add Donor',
              color: const Color(0xFF9C27B0),
              onTap: onAddDonor,
            ),
          _buildDivider(isDark),
          // Add Content Section
          _buildIconButton(
            context,
            icon: Icons.note_add,
            tooltip: 'Add Note',
            color: const Color(0xFFFFC107),
            onTap: onAddNote,
          ),
          _buildIconButton(
            context,
            icon: Icons.add_photo_alternate,
            tooltip: 'Add Image',
            color: const Color(0xFF00BCD4),
            onTap: onAddImage,
          ),
          _buildIconButton(
            context,
            icon: Icons.upload_file,
            tooltip: 'Add File',
            color: const Color(0xFF607D8B),
            onTap: onAddFile,
          ),
          const Spacer(),
          _buildDivider(isDark),
          // Zoom Controls - Stacked Vertically
          _buildIconButton(
            context,
            icon: Icons.zoom_in,
            tooltip: 'Zoom In',
            onTap: onZoomIn,
          ),
          // Zoom Level Indicator
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${(zoomLevel * 100).toInt()}%',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
          _buildIconButton(
            context,
            icon: Icons.zoom_out,
            tooltip: 'Zoom Out',
            onTap: onZoomOut,
          ),
          _buildDivider(isDark),
          _buildIconButton(
            context,
            icon: Icons.fit_screen,
            tooltip: 'Fit View',
            onTap: onFitView,
          ),
          _buildIconButton(
            context,
            icon: Icons.center_focus_strong,
            tooltip: 'Reset View',
            onTap: onResetView,
          ),
          if (onToggleFullscreen != null) ...[
            _buildDivider(isDark),
            _buildIconButton(
              context,
              icon: isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
              tooltip: isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
              onTap: onToggleFullscreen!,
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 32,
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: isDark ? Colors.grey[700] : Colors.grey[300],
    );
  }

  Widget _buildIconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final defaultColor = isDark ? Colors.grey[400] : Colors.grey[700];

    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: color ?? defaultColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
