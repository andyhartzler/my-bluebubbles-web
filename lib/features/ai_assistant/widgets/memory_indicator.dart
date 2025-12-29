import 'package:flutter/material.dart';

// Brand colors matching dashboard theme
const _justicePurple = Color(0xFF6A1B9A);

class MemoryIndicator extends StatelessWidget {
  final int sessionMemories;
  final int userMemories;
  final int orgMemories;

  const MemoryIndicator({
    super.key,
    required this.sessionMemories,
    required this.userMemories,
    required this.orgMemories,
  });

  int get totalMemories => sessionMemories + userMemories + orgMemories;

  @override
  Widget build(BuildContext context) {
    if (totalMemories == 0) return const SizedBox.shrink();

    return Tooltip(
      message: _buildTooltipMessage(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _justicePurple.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _justicePurple.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.psychology,
              size: 14,
              color: _justicePurple,
            ),
            const SizedBox(width: 6),
            Text(
              '$totalMemories ${totalMemories == 1 ? 'memory' : 'memories'}',
              style: TextStyle(
                fontSize: 11,
                color: _justicePurple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildTooltipMessage() {
    final parts = <String>[];
    if (sessionMemories > 0) {
      parts.add('$sessionMemories from this conversation');
    }
    if (userMemories > 0) {
      parts.add('$userMemories from your history');
    }
    if (orgMemories > 0) {
      parts.add('$orgMemories organizational');
    }
    return 'Using ${parts.join(', ')}';
  }
}
