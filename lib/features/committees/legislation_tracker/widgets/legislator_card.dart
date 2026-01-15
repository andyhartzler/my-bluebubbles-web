import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import '../models/legislator.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);

/// Card widget displaying legislator information with Unity Blue styling
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
      color: _unityBlue,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildPartyBadge(),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Title and district
                    Text(
                      '${legislator.displayTitle} - District ${legislator.district}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),

                    // Leadership role if any
                    if (legislator.leadershipRole != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          legislator.leadershipRole!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${legislator.billsSponsoredCount}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _momentumBlue,
                        ),
                      ),
                      Text(
                        'bills',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
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
      color: _unityBlue,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
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
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildPartyBadge(small: true),
                      ],
                    ),
                    Text(
                      '${legislator.chamberName} Dist. ${legislator.district}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
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
      backgroundColor: legislator.partyColor.withOpacity(0.3),
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

  Widget _buildPartyBadge({bool small = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: legislator.partyColor.withOpacity(0.25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: legislator.partyColor.withOpacity(0.4)),
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

/// Grid tile version of legislator card with Unity Blue styling
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
      color: _unityBlue,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Photo area
            Expanded(
              flex: 3,
              child: Container(
                color: legislator.partyColor.withOpacity(0.15),
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
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: legislator.partyColor.withOpacity(0.25),
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
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    if (legislator.leadershipRole != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        legislator.leadershipRole!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.amber,
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
            color: legislator.partyColor.withOpacity(0.6),
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
  final bool darkBackground;

  const LegislatorChip({
    super.key,
    required this.legislator,
    this.onTap,
    this.isPrimary = false,
    this.darkBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = legislator.getPhotoPublicUrl();
    final textColor = darkBackground ? Colors.white : theme.colorScheme.onSurface;

    return Material(
      color: legislator.partyColor.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: legislator.partyColor.withOpacity(isPrimary ? 0.5 : 0.3),
              width: isPrimary ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Small avatar
              CorsAwareAvatar(
                imageUrl: photoUrl,
                radius: 12,
                backgroundColor: legislator.partyColor.withOpacity(0.2),
                fallbackText: legislator.initials,
                fallbackIconColor: legislator.partyColor,
                fallbackTextColor: legislator.partyColor,
              ),
              const SizedBox(width: 6),
              // Name
              Text(
                legislator.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
                  color: textColor,
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
                  color: darkBackground ? _momentumBlue : theme.colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
