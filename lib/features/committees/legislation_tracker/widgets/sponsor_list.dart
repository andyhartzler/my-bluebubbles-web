import 'package:flutter/material.dart';
import '../models/bill_sponsor.dart';
import '../utils/bill_helpers.dart';

/// Widget displaying list of bill sponsors
class SponsorList extends StatelessWidget {
  final List<BillSponsor> sponsors;
  final bool showTitle;
  final bool compact;

  const SponsorList({
    super.key,
    required this.sponsors,
    this.showTitle = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (sponsors.isEmpty) {
      return _buildEmptyState(context, theme);
    }

    final primarySponsors = sponsors.where((s) => s.isPrimary).toList();
    final coSponsors = sponsors.where((s) => !s.isPrimary).toList();

    if (compact) {
      return _buildCompactList(context, theme, primarySponsors, coSponsors);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Sponsors',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        if (primarySponsors.isNotEmpty) ...[
          Text(
            'Primary Sponsor${primarySponsors.length > 1 ? 's' : ''}',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          ...primarySponsors.map((sponsor) => _buildSponsorTile(theme, sponsor)),
        ],
        if (coSponsors.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Co-Sponsors (${coSponsors.length})',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...coSponsors.map((sponsor) => _buildSponsorTile(theme, sponsor)),
        ],
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 48,
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No sponsors listed',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactList(
    BuildContext context,
    ThemeData theme,
    List<BillSponsor> primarySponsors,
    List<BillSponsor> coSponsors,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...primarySponsors.map((s) => _buildCompactChip(theme, s, isPrimary: true)),
        ...coSponsors.map((s) => _buildCompactChip(theme, s, isPrimary: false)),
      ],
    );
  }

  Widget _buildCompactChip(ThemeData theme, BillSponsor sponsor, {required bool isPrimary}) {
    final partyColor = BillHelpers.getPartyColor(sponsor.party);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: partyColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: partyColor.withOpacity(isPrimary ? 0.5 : 0.2),
          width: isPrimary ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: partyColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                BillHelpers.getPartyAbbreviation(sponsor.party),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: partyColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            sponsor.displayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (isPrimary) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.star,
              size: 12,
              color: theme.colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSponsorTile(ThemeData theme, BillSponsor sponsor) {
    final partyColor = BillHelpers.getPartyColor(sponsor.party);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: partyColor.withOpacity(0.2),
            child: Text(
              BillHelpers.getPartyAbbreviation(sponsor.party),
              style: TextStyle(
                color: partyColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            sponsor.displayName,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sponsor.district != null)
                Text('District ${sponsor.district}'),
              Row(
                children: [
                  if (sponsor.party != null) ...[
                    Text(
                      sponsor.party!,
                      style: TextStyle(color: partyColor),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (sponsor.classification != null)
                    Text(
                      sponsor.classification!,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ],
          ),
          trailing: sponsor.isPrimary
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Primary',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                )
              : null,
          isThreeLine: sponsor.district != null,
        ),
      ),
    );
  }
}

/// Compact sponsor summary for bill cards
class SponsorSummary extends StatelessWidget {
  final List<BillSponsor> sponsors;
  final int maxDisplay;

  const SponsorSummary({
    super.key,
    required this.sponsors,
    this.maxDisplay = 2,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (sponsors.isEmpty) {
      return Text(
        'No sponsors',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final primarySponsors = sponsors.where((s) => s.isPrimary).toList();
    final displaySponsors = primarySponsors.isNotEmpty
        ? primarySponsors.take(maxDisplay).toList()
        : sponsors.take(maxDisplay).toList();
    final remainingCount = sponsors.length - displaySponsors.length;

    return Row(
      children: [
        Icon(
          Icons.person,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            displaySponsors.map((s) => s.displayName).join(', ') +
                (remainingCount > 0 ? ' +$remainingCount' : ''),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
