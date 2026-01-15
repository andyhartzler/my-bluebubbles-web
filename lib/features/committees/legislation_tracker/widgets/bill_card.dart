import 'package:flutter/material.dart';
import '../models/tracked_bill.dart';
import '../utils/bill_helpers.dart';
import 'bill_status_badge.dart';

// Brand colors matching committee views
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);

/// Modern card widget displaying a tracked bill summary
class BillCard extends StatelessWidget {
  final TrackedBill bill;
  final VoidCallback? onTap;
  final bool showPosition;
  final bool showPriority;
  final bool compact;

  const BillCard({
    super.key,
    required this.bill,
    this.onTap,
    this.showPosition = true,
    this.showPriority = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final position = BillPosition.fromString(bill.position);
    final priority = BillPriority.fromString(bill.priority);

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: compact ? 8 : 12),
      color: _unityBlue,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: position.color,
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Bill ID, Chamber, Priority, Position
                Row(
                  children: [
                    // Bill identifier
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _momentumBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        bill.billIdentifier,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontSize: compact ? 12 : 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Chamber badge
                    if (bill.chamber != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          BillHelpers.getChamberName(bill.chamber),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ),
                    const Spacer(),

                    // Priority badge
                    if (showPriority)
                      _buildBadge(
                        emoji: priority.emoji,
                        label: priority.label,
                        color: priority.color,
                      ),
                    if (showPosition) ...[
                      const SizedBox(width: 8),
                      _buildBadge(
                        emoji: position.emoji,
                        label: position.label,
                        color: position.color,
                      ),
                    ],
                  ],
                ),
                SizedBox(height: compact ? 10 : 14),

                // Title
                Text(
                  bill.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 14 : 16,
                    color: Colors.white,
                    height: 1.3,
                  ),
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),

                if (!compact) ...[
                  const SizedBox(height: 12),

                  // Sponsor and action info
                  Row(
                    children: [
                      if (bill.primarySponsorName != null) ...[
                        Icon(
                          Icons.person_outline,
                          size: 16,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${bill.primarySponsorName}${bill.primarySponsorParty != null ? ' (${BillHelpers.getPartyAbbreviation(bill.primarySponsorParty)})' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (bill.latestActionDate != null) ...[
                        Icon(
                          Icons.schedule_outlined,
                          size: 16,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          BillHelpers.formatRelativeTime(bill.latestActionDate),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Latest action
                  if (bill.latestActionDescription != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: _momentumBlue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              bill.latestActionDescription!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Categories
                  if (bill.categories.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: bill.categories.take(4).map((cat) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Passage indicators
                  if (bill.passedLower || bill.passedUpper || bill.signedByGovernor || bill.vetoed) ...[
                    const SizedBox(height: 10),
                    BillStatusBadge(bill: bill, darkBackground: true),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({
    required String emoji,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
