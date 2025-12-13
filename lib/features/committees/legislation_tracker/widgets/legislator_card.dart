import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/legislator.dart';

/// Card widget displaying legislator information
class LegislatorCard extends StatelessWidget {
  final Legislator legislator;
  final VoidCallback? onTap;
  final bool compact;
  final bool showBillCounts;

  const LegislatorCard({
    super.key,
    required this.legislator,
    this.onTap,
    this.compact = false,
    this.showBillCounts = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (compact) {
      return _buildCompactCard(context, theme);
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Photo
              _buildAvatar(48),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and party badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            legislator.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildPartyBadge(theme),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Title and district
                    Text(
                      '${legislator.displayTitle} - District ${legislator.district}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),

                    // Leadership role if any
                    if (legislator.leadershipRole != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          legislator.leadershipRole!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Bill count
              if (showBillCounts && legislator.billsSponsoredCount > 0) ...[
                const SizedBox(width: 12),
                Column(
                  children: [
                    Text(
                      '${legislator.billsSponsoredCount}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      'bills',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCard(BuildContext context, ThemeData theme) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              _buildAvatar(36),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            legislator.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildPartyBadge(theme, small: true),
                      ],
                    ),
                    Text(
                      '${legislator.chamberName} Dist. ${legislator.district}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(double radius) {
    final photoUrl = legislator.getPhotoPublicUrl();

    return CircleAvatar(
      radius: radius / 2,
      backgroundColor: legislator.partyColor.withOpacity(0.2),
      child: photoUrl != null
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: photoUrl,
                width: radius,
                height: radius,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildInitials(radius),
                errorWidget: (context, url, error) => _buildInitials(radius),
              ),
            )
          : _buildInitials(radius),
    );
  }

  Widget _buildInitials(double size) {
    return Text(
      legislator.initials,
      style: TextStyle(
        fontSize: size / 2.5,
        fontWeight: FontWeight.bold,
        color: legislator.partyColor,
      ),
    );
  }

  Widget _buildPartyBadge(ThemeData theme, {bool small = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: legislator.partyColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        legislator.partyAbbr,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: small ? 10 : 12,
          color: legislator.partyColor,
        ),
      ),
    );
  }
}

/// Grid tile version of legislator card
class LegislatorGridTile extends StatelessWidget {
  final Legislator legislator;
  final VoidCallback? onTap;

  const LegislatorGridTile({
    super.key,
    required this.legislator,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = legislator.getPhotoPublicUrl();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Photo area
            Expanded(
              flex: 3,
              child: Container(
                color: legislator.partyColor.withOpacity(0.1),
                child: photoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: photoUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => _buildPlaceholder(theme),
                        errorWidget: (context, url, error) => _buildPlaceholder(theme),
                      )
                    : _buildPlaceholder(theme),
              ),
            ),
            // Info area
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            legislator.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: legislator.partyColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            legislator.partyAbbr,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: legislator.partyColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${legislator.chamberName} Dist. ${legislator.district}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (legislator.leadershipRole != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        legislator.leadershipRole!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.amber.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person,
            size: 48,
            color: legislator.partyColor.withOpacity(0.5),
          ),
          const SizedBox(height: 4),
          Text(
            legislator.initials,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: legislator.partyColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip showing legislator summary (for sponsor lists)
class LegislatorChip extends StatelessWidget {
  final Legislator legislator;
  final VoidCallback? onTap;
  final bool isPrimary;

  const LegislatorChip({
    super.key,
    required this.legislator,
    this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = legislator.getPhotoPublicUrl();

    return Material(
      color: legislator.partyColor.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: legislator.partyColor.withOpacity(isPrimary ? 0.5 : 0.2),
              width: isPrimary ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Small avatar
              CircleAvatar(
                radius: 12,
                backgroundColor: legislator.partyColor.withOpacity(0.2),
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Text(
                        legislator.initials.substring(0, 1),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: legislator.partyColor,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 6),
              // Name
              Text(
                legislator.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 4),
              // Party
              Text(
                '(${legislator.partyAbbr})',
                style: TextStyle(
                  fontSize: 11,
                  color: legislator.partyColor,
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
}
