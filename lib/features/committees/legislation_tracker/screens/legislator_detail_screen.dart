import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/legislator.dart';
import '../models/tracked_bill.dart';
import '../providers/legislation_provider.dart';
import '../services/legislation_service.dart';
import '../widgets/bill_card.dart';
import 'bill_detail_screen.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _grassrootsGreen = Color(0xFF43A047);
const _democratBlue = Color(0xFF3B82F6);
const _republicanRed = Color(0xFFEF4444);

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
  List<SponsoredBillInfo> _sponsoredBills = [];
  bool _isLoading = true;
  bool _isUploadingPhoto = false;
  bool _isSavingBio = false;
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
        _service.getBillsBySponsorWithType(widget.legislatorId),
      ]);

      setState(() {
        _legislator = results[0] as Legislator?;
        _sponsoredBills = results[1] as List<SponsoredBillInfo>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_isUploadingPhoto || _legislator == null) return;

    final result = await file_picker.FilePicker.platform.pickFiles(
      type: file_picker.FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'heic', 'heif', 'webp'],
      withData: true,
      withReadStream: !kIsWeb,
    );

    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    final bytes = picked.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to read selected photo')),
      );
      return;
    }

    setState(() => _isUploadingPhoto = true);

    try {
      final updated = await _service.uploadLegislatorPhoto(
        legislatorId: _legislator!.id,
        fileName: picked.name,
        fileBytes: bytes,
      );

      if (!mounted) return;
      if (updated != null) {
        setState(() => _legislator = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update photo')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading photo: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _editBiography() async {
    if (_legislator == null) return;

    final controller = TextEditingController(text: _legislator!.biography ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Biography for ${_legislator!.name}'),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: controller,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: 'Enter biography...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _isSavingBio = true);

    try {
      final updated = await _service.updateLegislatorBiography(
        legislatorId: _legislator!.id,
        biography: result,
      );

      if (!mounted) return;
      if (updated != null) {
        setState(() => _legislator = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biography updated successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update biography')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating biography: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingBio = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Legislator', style: TextStyle(color: Colors.white)),
          backgroundColor: _unityBlue,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(child: CircularProgressIndicator(color: _momentumBlue)),
      );
    }

    if (_error != null || _legislator == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Legislator', style: TextStyle(color: Colors.white)),
          backgroundColor: _unityBlue,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline, size: 48, color: Colors.red),
              ),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Legislator not found',
                style: TextStyle(color: _unityBlue),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadLegislator,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Retry', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _momentumBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final legislator = _legislator!;

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Positioned.fill(
            child: Image.asset(
              'assets/images/Blue-Gradient-Background.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.18),
            ),
          ),
          // Content
          CustomScrollView(
            slivers: [
              // App bar with photo (not sticky)
              SliverAppBar(
                expandedHeight: 300,
                pinned: false,
                backgroundColor: _unityBlue,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Material(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(12),
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildHeader(theme, legislator),
                ),
                actions: [
                  if (legislator.legislatureUrl != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Material(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () => _launchUrl(legislator.legislatureUrl!),
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.open_in_new, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // Content
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick stats pills
                    _buildQuickStatsRow(legislator),

                    // Contact section
                    _buildContactSection(theme, legislator),

                    // Biography section (always show with edit capability)
                    _buildBiographySection(theme, legislator),

                    // Bills section
                    _buildBillsSection(theme, legislator),
                  ],
                ),
              ),
            ],
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
            _unityBlue,
            _unityBlue.withOpacity(0.9),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Photo with upload overlay
              Stack(
                children: [
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
                  // Upload button overlay
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Material(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: _isUploadingPhoto
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt,
                                  size: 20,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
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

                    // Party badge and member badge
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: legislator.partyColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: legislator.partyColor.withOpacity(0.5)),
                          ),
                          child: Text(
                            legislator.party ?? 'Unknown Party',
                            style: TextStyle(
                              color: legislator.partyColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        // Member badge - shows if legislator is linked to a member
                        if (legislator.isMember)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _grassrootsGreen.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _grassrootsGreen.withOpacity(0.5)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, size: 16, color: _grassrootsGreen),
                                SizedBox(width: 4),
                                Text(
                                  'Member',
                                  style: TextStyle(
                                    color: _grassrootsGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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
                          color: Colors.amber.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          legislator.leadershipRole!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
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

  Widget _buildQuickStatsRow(Legislator legislator) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatPill(
              icon: Icons.gavel,
              value: '${legislator.billsSponsoredCount}',
              label: 'Bills Sponsored',
              color: _momentumBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatPill(
              icon: Icons.group,
              value: '${legislator.billsCosponsoredCount}',
              label: 'Co-Sponsored',
              color: _grassrootsGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _unityBlue,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _unityBlue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection(ThemeData theme, Legislator legislator) {
    final hasContact = legislator.capitolEmail != null ||
        legislator.capitolPhone != null ||
        legislator.capitolAddress != null;

    if (!hasContact) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _unityBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contact',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          // Email
          if (legislator.capitolEmail != null)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: _momentumBlue.withOpacity(0.3),
                child: Icon(Icons.email, color: _momentumBlue),
              ),
              title: Text(legislator.capitolEmail!, style: const TextStyle(color: Colors.white)),
              subtitle: Text('Capitol Email', style: TextStyle(color: Colors.white.withOpacity(0.7))),
              onTap: () => _launchUrl('mailto:${legislator.capitolEmail}'),
              contentPadding: EdgeInsets.zero,
            ),

          // Phone
          if (legislator.capitolPhone != null)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.withOpacity(0.3),
                child: const Icon(Icons.phone, color: Colors.green),
              ),
              title: Text(legislator.capitolPhone!, style: const TextStyle(color: Colors.white)),
              subtitle: Text('Capitol Phone', style: TextStyle(color: Colors.white.withOpacity(0.7))),
              onTap: () => _launchUrl('tel:${legislator.capitolPhone}'),
              contentPadding: EdgeInsets.zero,
            ),

          // Address
          if (legislator.capitolAddress != null)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange.withOpacity(0.3),
                child: const Icon(Icons.location_on, color: Colors.orange),
              ),
              title: Text(legislator.capitolAddress!, style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                legislator.room != null ? 'Room ${legislator.room}' : 'Capitol Office',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
              contentPadding: EdgeInsets.zero,
            ),

          // Social media
          if (legislator.twitter != null || legislator.facebook != null) ...[
            Divider(height: 32, color: Colors.white.withOpacity(0.2)),
            Row(
              children: [
                if (legislator.twitter != null)
                  IconButton(
                    icon: const Icon(Icons.alternate_email, color: Colors.white),
                    onPressed: () => _launchUrl('https://twitter.com/${legislator.twitter}'),
                    tooltip: 'Twitter',
                  ),
                if (legislator.facebook != null)
                  IconButton(
                    icon: const Icon(Icons.facebook, color: Colors.white),
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
    final hasBiography = legislator.biography != null && legislator.biography!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _unityBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Biography',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (_isSavingBio)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _momentumBlue),
                )
              else
                IconButton(
                  icon: Icon(hasBiography ? Icons.edit : Icons.add, color: _momentumBlue),
                  onPressed: _editBiography,
                  tooltip: hasBiography ? 'Edit biography' : 'Add biography',
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasBiography)
            Text(
              legislator.biography!,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.white.withOpacity(0.9),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 48,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No biography available',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _editBiography,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Add Biography', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _momentumBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBillsSection(ThemeData theme, Legislator legislator) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_unityBlue, _momentumBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.gavel,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Sponsored Bills',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Stats chips row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (legislator.billsSponsoredCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '${legislator.billsSponsoredCount} Primary',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (legislator.billsCosponsoredCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.group, size: 14, color: Colors.white.withOpacity(0.9)),
                        const SizedBox(width: 4),
                        Text(
                          '${legislator.billsCosponsoredCount} Co-Sponsor',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            if (_sponsoredBills.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.gavel_outlined,
                        size: 48,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No tracked bills sponsored',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bills will appear here when tracked',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._sponsoredBills.map((billInfo) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: BillCard(
                      bill: billInfo.bill,
                      onTap: () => _navigateToBillDetail(billInfo.bill),
                      compact: true,
                      isPrimarySponsor: billInfo.isPrimarySponsor,
                      onDarkBackground: true,
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  void _navigateToBillDetail(TrackedBill bill) {
    final provider = context.read<LegislationProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: provider,
          child: BillDetailScreen(
            billId: bill.id,
            committeeId: widget.committeeId,
          ),
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
