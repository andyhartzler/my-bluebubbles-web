import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/canvas_board/models/canvas_node.dart';
import 'package:bluebubbles/features/canvas_board/widgets/node_widgets/base_canvas_node.dart';
import 'package:bluebubbles/models/crm/donor.dart';

/// Canvas node widget for displaying a Donor entity
class DonorCanvasNode extends StatelessWidget {
  final CanvasNode node;
  final Donor? donor;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onDelete;

  static const accentColor = Color(0xFF9C27B0); // Purple

  const DonorCanvasNode({
    super.key,
    required this.node,
    this.donor,
    this.isSelected = false,
    this.isLoading = false,
    this.onTap,
    this.onDoubleTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return BaseCanvasNode(
      node: node,
      isSelected: isSelected,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onDelete: onDelete,
      accentColor: accentColor,
      child: Container(
        width: node.width,
        height: node.height,
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NodeTypeHeader(
              label: 'Donor',
              icon: Icons.volunteer_activism,
              color: accentColor,
            ),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : donor == null
                      ? _buildErrorState()
                      : _buildDonorContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.grey[400], size: 32),
          const SizedBox(height: 8),
          Text(
            'Donor not found',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDonorContent() {
    final d = donor!;
    final donorName = d.name ?? 'Unknown';
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: accentColor.withOpacity(0.1),
                child: Text(
                  donorName.isNotEmpty ? donorName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      donorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (d.email != null)
                      Text(
                        d.email!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Donated',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    currencyFormat.format(d.totalDonated ?? 0),
                    style: const TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long, size: 12, color: accentColor),
                    const SizedBox(width: 4),
                    Text(
                      '${d.donationCount}',
                      style: const TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
