import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/legislator.dart';
import '../models/tracked_bill.dart';
import '../services/legislation_service.dart';
import '../widgets/bill_card.dart';
import 'bill_detail_screen.dart';

/// Detail screen for a single legislator
class LegislatorDetailScreen extends StatefulWidget {
  final String legislatorId;
  final String committeeId;

  const LegislatorDetailScreen({
    super.key,
    required this.legislatorId,
    required this.committeeId,
  });

  @override
  State<LegislatorDetailScreen> createState() => _LegislatorDetailScreenState();
}

class _LegislatorDetailScreenState extends State<LegislatorDetailScreen> {
  final LegislationService _service = LegislationService();

  Legislator? _legislator;
  List<TrackedBill> _sponsoredBills = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLegislator();
  }

  Future<void> _loadLegislator() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _service.getLegislator(widget.legislatorId),
        _service.getBillsBySponsor(widget.legislatorId),
      ]);

      setState(() {
        _legislator = results[0] as Legislator?;
        _sponsoredBills = results[1] as List<TrackedBill>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Legislator')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _legislator == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Legislator')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(_error ?? 'Legislator not found'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadLegislator,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final legislator = _legislator!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with photo
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(theme, legislator),
            ),
            actions: [
              if (legislator.legislatureUrl != null)
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => _launchUrl(legislator.legislatureUrl!),
                  tooltip: 'View on Legislature website',
                ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Contact section
                _buildContactSection(theme, legislator),

                // Biography section
                if (legislator.biography != null && legislator.biography!.isNotEmpty)
                  _buildBiographySection(theme, legislator),

                // Bills section
                _buildBillsSection(theme, legislator),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Legislator legislator) {
    final photoUrl = legislator.getPhotoPublicUrl();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            legislator.partyColor.withOpacity(0.8),
            legislator.partyColor.withOpacity(0.4),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Photo
              Container(
                width: 120,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: photoUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => _buildPhotoPlaceholder(legislator),
                          errorWidget: (context, url, error) => _buildPhotoPlaceholder(legislator),
                        )
                      : _buildPhotoPlaceholder(legislator),
                ),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Name
                    Text(
                      legislator.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Title and district
                    Text(
                      '${legislator.displayTitle} - District ${legislator.district}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Party badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            legislator.party ?? 'Unknown Party',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Leadership role
                    if (legislator.leadershipRole != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          legislator.leadershipRole!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],

                    // Hometown
                    if (legislator.homeTown != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(
                            legislator.homeTown!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPlaceholder(Legislator legislator) {
    return Container(
      color: legislator.partyColor.withOpacity(0.1),
      child: Center(
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
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: legislator.partyColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection(ThemeData theme, Legislator legislator) {
    final hasContact = legislator.capitolEmail != null ||
        legislator.capitolPhone != null ||
        legislator.capitolAddress != null;

    if (!hasContact) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Email
          if (legislator.capitolEmail != null)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.email, color: theme.colorScheme.primary),
              ),
              title: Text(legislator.capitolEmail!),
              subtitle: const Text('Capitol Email'),
              onTap: () => _launchUrl('mailto:${legislator.capitolEmail}'),
              contentPadding: EdgeInsets.zero,
            ),

          // Phone
          if (legislator.capitolPhone != null)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: Icon(Icons.phone, color: theme.colorScheme.secondary),
              ),
              title: Text(legislator.capitolPhone!),
              subtitle: const Text('Capitol Phone'),
              onTap: () => _launchUrl('tel:${legislator.capitolPhone}'),
              contentPadding: EdgeInsets.zero,
            ),

          // Address
          if (legislator.capitolAddress != null)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.tertiaryContainer,
                child: Icon(Icons.location_on, color: theme.colorScheme.tertiary),
              ),
              title: Text(legislator.capitolAddress!),
              subtitle: Text(legislator.room != null ? 'Room ${legislator.room}' : 'Capitol Office'),
              contentPadding: EdgeInsets.zero,
            ),

          // Social media
          if (legislator.twitter != null || legislator.facebook != null) ...[
            const Divider(height: 32),
            Row(
              children: [
                if (legislator.twitter != null)
                  IconButton(
                    icon: const Icon(Icons.alternate_email),
                    onPressed: () => _launchUrl('https://twitter.com/${legislator.twitter}'),
                    tooltip: 'Twitter',
                  ),
                if (legislator.facebook != null)
                  IconButton(
                    icon: const Icon(Icons.facebook),
                    onPressed: () => _launchUrl('https://facebook.com/${legislator.facebook}'),
                    tooltip: 'Facebook',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBiographySection(ThemeData theme, Legislator legislator) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Biography',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            legislator.biography!,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillsSection(ThemeData theme, Legislator legislator) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Sponsored Bills',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Stats chips
              if (legislator.billsSponsoredCount > 0)
                Chip(
                  label: Text('${legislator.billsSponsoredCount} primary'),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              if (legislator.billsCosponsoredCount > 0) ...[
                const SizedBox(width: 8),
                Chip(
                  label: Text('${legislator.billsCosponsoredCount} co-sponsor'),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          if (_sponsoredBills.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.gavel_outlined,
                      size: 48,
                      color: theme.colorScheme.outline.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No tracked bills sponsored',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bills will appear here when tracked',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._sponsoredBills.map((bill) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BillCard(
                    bill: bill,
                    onTap: () => _navigateToBillDetail(bill),
                    compact: true,
                  ),
                )),
        ],
      ),
    );
  }

  void _navigateToBillDetail(TrackedBill bill) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BillDetailScreen(
          billId: bill.id,
          committeeId: widget.committeeId,
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
