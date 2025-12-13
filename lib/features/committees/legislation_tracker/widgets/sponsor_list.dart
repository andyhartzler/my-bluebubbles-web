import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/bill_sponsor.dart';
import '../models/legislator.dart';
import '../utils/bill_helpers.dart';

/// Widget displaying list of bill sponsors with legislator photos
class SponsorList extends StatelessWidget {
  final List<BillSponsor> sponsors;
  final bool showTitle;
  final bool compact;
  final Function(Legislator)? onLegislatorTap;

  const SponsorList({
    super.key,
    required this.sponsors,
    this.showTitle = true,
    this.compact = false,
    this.onLegislatorTap,
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
          ...primarySponsors.map((sponsor) => _buildSponsorTile(context, theme, sponsor)),
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
          ...coSponsors.map((sponsor) => _buildSponsorTile(context, theme, sponsor)),
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
        ...primarySponsors.map((s) => _buildCompactChip(context, theme, s, isPrimary: true)),
        ...coSponsors.map((s) => _buildCompactChip(context, theme, s, isPrimary: false)),
      ],
    );
  }

  Widget _buildCompactChip(BuildContext context, ThemeData theme, BillSponsor sponsor, {required bool isPrimary}) {
    final legislator = sponsor.legislator;
    final partyColor = legislator?.partyColor ?? BillHelpers.getPartyColor(sponsor.party);
    final photoUrl = legislator?.getPhotoPublicUrl();

    return Material(
      color: partyColor.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: legislator != null && onLegislatorTap != null
            ? () => onLegislatorTap!(legislator)
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: partyColor.withOpacity(isPrimary ? 0.5 : 0.2),
              width: isPrimary ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar with photo or initials
              CircleAvatar(
                radius: 10,
                backgroundColor: partyColor.withOpacity(0.2),
                child: photoUrl != null
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: photoUrl,
                          width: 20,
                          height: 20,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => _buildInitialsAvatar(partyColor, sponsor, legislator),
                          errorWidget: (context, url, error) => _buildInitialsAvatar(partyColor, sponsor, legislator),
                        ),
                      )
                    : _buildInitialsAvatar(partyColor, sponsor, legislator),
              ),
              const SizedBox(width: 6),
              Text(
                legislator?.name ?? sponsor.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(${legislator?.partyAbbr ?? BillHelpers.getPartyAbbreviation(sponsor.party)})',
                style: TextStyle(
                  fontSize: 11,
                  color: partyColor,
                  fontWeight: FontWeight.w500,
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
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar(Color partyColor, BillSponsor sponsor, Legislator? legislator) {
    final initials = legislator?.initials ??
        (sponsor.name.isNotEmpty ? sponsor.name[0].toUpperCase() : '?');

    return Center(
      child: Text(
        initials.length > 1 ? initials.substring(0, 1) : initials,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: partyColor,
        ),
      ),
    );
  }

  Widget _buildSponsorTile(BuildContext context, ThemeData theme, BillSponsor sponsor) {
    final legislator = sponsor.legislator;
    final partyColor = legislator?.partyColor ?? BillHelpers.getPartyColor(sponsor.party);
    final photoUrl = legislator?.getPhotoPublicUrl();
    final hasPhoto = photoUrl != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        child: ListTile(
          onTap: legislator != null && onLegislatorTap != null
              ? () => onLegislatorTap!(legislator)
              : null,
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: partyColor.withOpacity(0.2),
            child: hasPhoto
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: photoUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _buildAvatarFallback(partyColor, sponsor, legislator),
                      errorWidget: (context, url, error) => _buildAvatarFallback(partyColor, sponsor, legislator),
                    ),
                  )
                : _buildAvatarFallback(partyColor, sponsor, legislator),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  legislator?.name ?? sponsor.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              // Party badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: partyColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  legislator?.partyAbbr ?? BillHelpers.getPartyAbbreviation(sponsor.party),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: partyColor,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chamber and district
              Text(
                _buildSubtitle(sponsor, legislator),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              // Leadership role
              if (legislator?.leadershipRole != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    legislator!.leadershipRole!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ),
              ],
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
          isThreeLine: legislator?.leadershipRole != null,
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(Color partyColor, BillSponsor sponsor, Legislator? legislator) {
    return Text(
      legislator?.partyAbbr ?? BillHelpers.getPartyAbbreviation(sponsor.party),
      style: TextStyle(
        color: partyColor,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  String _buildSubtitle(BillSponsor sponsor, Legislator? legislator) {
    final chamber = legislator?.chamberName ??
        (sponsor.chamber == 'lower' ? 'House' : sponsor.chamber == 'upper' ? 'Senate' : '');
    final district = legislator?.district ?? sponsor.district;

    if (district != null && chamber.isNotEmpty) {
      return '$chamber District $district';
    }
    if (chamber.isNotEmpty) {
      return chamber;
    }
    if (district != null) {
      return 'District $district';
    }
    return '';
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
        // Show small avatars for sponsors with photos
        ...displaySponsors.take(2).map((s) {
          final photoUrl = s.legislator?.getPhotoPublicUrl();
          final partyColor = s.legislator?.partyColor ?? BillHelpers.getPartyColor(s.party);

          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: CircleAvatar(
              radius: 10,
              backgroundColor: partyColor.withOpacity(0.2),
              child: photoUrl != null
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: photoUrl,
                        width: 20,
                        height: 20,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Text(
                          s.legislator?.partyAbbr ?? BillHelpers.getPartyAbbreviation(s.party),
                          style: TextStyle(fontSize: 8, color: partyColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  : Text(
                      s.legislator?.partyAbbr ?? BillHelpers.getPartyAbbreviation(s.party),
                      style: TextStyle(fontSize: 8, color: partyColor, fontWeight: FontWeight.bold),
                    ),
            ),
          );
        }),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            displaySponsors.map((s) => s.legislator?.name ?? s.name).join(', ') +
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
