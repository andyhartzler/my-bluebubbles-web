import 'package:flutter/material.dart';
import '../models/tracked_bill.dart';
import '../utils/bill_helpers.dart';
import 'bill_status_badge.dart';

/// Card widget displaying a tracked bill summary
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
    final theme = Theme.of(context);
    final position = BillPosition.fromString(bill.position);
    final priority = BillPriority.fromString(bill.priority);

    return Card(
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
                // Top row: Bill ID, Priority, Chamber
                Row(
                  children: [
                    // Bill identifier
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        bill.billIdentifier,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                          fontSize: compact ? 12 : 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Chamber badge
                    if (bill.chamber != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          BillHelpers.getChamberName(bill.chamber),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    const Spacer(),

                    // Priority badge
                    if (showPriority)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: priority.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: priority.color.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(priority.emoji, style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              priority.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: priority.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (showPosition) ...[
                      const SizedBox(width: 8),
                      // Position badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: position.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(position.emoji, style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              position.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: position.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: compact ? 8 : 12),

                // Title
                Text(
                  bill.title,
                  style: compact
                      ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)
                      : theme.textTheme.titleMedium,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),

                if (!compact) ...[
                  const SizedBox(height: 8),

                  // Sponsor and action info
                  Row(
                    children: [
                      if (bill.primarySponsorName != null) ...[
                        Icon(
                          Icons.person,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${bill.primarySponsorName}${bill.primarySponsorParty != null ? ' (${BillHelpers.getPartyAbbreviation(bill.primarySponsorParty)})' : ''}',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (bill.latestActionDate != null) ...[
                        Icon(
                          Icons.update,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          BillHelpers.formatRelativeTime(bill.latestActionDate),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),

                  // Latest action
                  if (bill.latestActionDescription != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.play_arrow,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              bill.latestActionDescription!,
                              style: theme.textTheme.bodySmall,
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
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: bill.categories.take(4).map((cat) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            cat,
                            style: theme.textTheme.labelSmall,
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Passage indicators
                  if (bill.passedLower || bill.passedUpper || bill.signedByGovernor || bill.vetoed) ...[
                    const SizedBox(height: 8),
                    BillStatusBadge(bill: bill),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
