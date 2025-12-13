import 'package:flutter/material.dart';
import '../models/tracked_bill.dart';
import 'bill_card.dart';

/// Widget displaying a list of tracked bills
class BillList extends StatelessWidget {
  final List<TrackedBill> bills;
  final Function(TrackedBill) onBillTap;
  final bool isLoading;
  final String? emptyMessage;
  final bool compact;
  final ScrollController? scrollController;

  const BillList({
    super.key,
    required this.bills,
    required this.onBillTap,
    this.isLoading = false,
    this.emptyMessage,
    this.compact = false,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (bills.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.all(compact ? 8 : 16),
      itemCount: bills.length,
      itemBuilder: (context, index) {
        final bill = bills[index];
        return Padding(
          padding: EdgeInsets.only(bottom: compact ? 8 : 12),
          child: BillCard(
            bill: bill,
            onTap: () => onBillTap(bill),
            compact: compact,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.gavel_outlined,
              size: 64,
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage ?? 'No bills found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or add bills to track',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Grouped bill list showing bills by position
class GroupedBillList extends StatelessWidget {
  final List<TrackedBill> supportBills;
  final List<TrackedBill> opposeBills;
  final List<TrackedBill> watchingBills;
  final List<TrackedBill> neutralBills;
  final Function(TrackedBill) onBillTap;
  final bool isLoading;

  const GroupedBillList({
    super.key,
    required this.supportBills,
    required this.opposeBills,
    required this.watchingBills,
    required this.neutralBills,
    required this.onBillTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalBills =
        supportBills.length + opposeBills.length + watchingBills.length + neutralBills.length;

    if (totalBills == 0) {
      return BillList(
        bills: const [],
        onBillTap: onBillTap,
        emptyMessage: 'No bills being tracked',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (supportBills.isNotEmpty)
          _buildPositionSection(
            context,
            title: 'Bills We Support',
            emoji: '👍',
            color: BillPosition.support.color,
            bills: supportBills,
          ),
        if (opposeBills.isNotEmpty)
          _buildPositionSection(
            context,
            title: 'Bills We Oppose',
            emoji: '👎',
            color: BillPosition.oppose.color,
            bills: opposeBills,
          ),
        if (watchingBills.isNotEmpty)
          _buildPositionSection(
            context,
            title: 'Bills We\'re Watching',
            emoji: '👀',
            color: BillPosition.watching.color,
            bills: watchingBills,
          ),
        if (neutralBills.isNotEmpty)
          _buildPositionSection(
            context,
            title: 'Neutral',
            emoji: '➖',
            color: BillPosition.neutral.color,
            bills: neutralBills,
          ),
      ],
    );
  }

  Widget _buildPositionSection(
    BuildContext context, {
    required String title,
    required String emoji,
    required Color color,
    required List<TrackedBill> bills,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${bills.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...bills.map((bill) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BillCard(
                bill: bill,
                onTap: () => onBillTap(bill),
                showPosition: false,
              ),
            )),
        const SizedBox(height: 16),
      ],
    );
  }
}
