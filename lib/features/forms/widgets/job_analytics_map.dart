import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:latlong2/latlong.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/jobs_service.dart';

/// A map widget that displays job view locations with clickable pins
class JobAnalyticsMap extends StatefulWidget {
  final List<JobViewLocation> locations;
  final double height;
  final Function(JobViewLocation)? onLocationTap;

  const JobAnalyticsMap({
    super.key,
    required this.locations,
    this.height = 300,
    this.onLocationTap,
  });

  @override
  State<JobAnalyticsMap> createState() => _JobAnalyticsMapState();
}

class _JobAnalyticsMapState extends State<JobAnalyticsMap> {
  final MapController _mapController = MapController();
  final PopupController _popupController = PopupController();
  JobViewLocation? _selectedLocation;

  @override
  void dispose() {
    _mapController.dispose();
    _popupController.dispose();
    super.dispose();
  }

  LatLng _calculateCenter() {
    if (widget.locations.isEmpty) {
      return const LatLng(39.8283, -98.5795); // Center of US
    }

    double sumLat = 0;
    double sumLng = 0;
    for (final loc in widget.locations) {
      sumLat += loc.latitude;
      sumLng += loc.longitude;
    }
    return LatLng(
      sumLat / widget.locations.length,
      sumLng / widget.locations.length,
    );
  }

  double _calculateZoom() {
    if (widget.locations.isEmpty) return 4.0;
    if (widget.locations.length == 1) return 10.0;

    // Calculate bounds
    double minLat = double.infinity;
    double maxLat = double.negativeInfinity;
    double minLng = double.infinity;
    double maxLng = double.negativeInfinity;

    for (final loc in widget.locations) {
      if (loc.latitude < minLat) minLat = loc.latitude;
      if (loc.latitude > maxLat) maxLat = loc.latitude;
      if (loc.longitude < minLng) minLng = loc.longitude;
      if (loc.longitude > maxLng) maxLng = loc.longitude;
    }

    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    // Adjust zoom based on spread
    if (maxDiff < 0.5) return 10.0;
    if (maxDiff < 2) return 8.0;
    if (maxDiff < 5) return 6.0;
    if (maxDiff < 10) return 5.0;
    return 4.0;
  }

  List<Marker> _buildMarkers(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return widget.locations.map((location) {
      final isSelected = _selectedLocation == location;
      final hasMultipleMembers = location.members.length > 1;

      return Marker(
        key: ValueKey('${location.latitude}-${location.longitude}'),
        point: LatLng(location.latitude, location.longitude),
        width: isSelected ? 50 : 40,
        height: isSelected ? 50 : 40,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedLocation = location;
            });
            widget.onLocationTap?.call(location);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.primaryContainer,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: hasMultipleMembers
                  ? Text(
                      '${location.members.length}',
                      style: TextStyle(
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    )
                  : Icon(
                      Icons.person_rounded,
                      size: 18,
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onPrimaryContainer,
                    ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildPopup(BuildContext context, Marker marker) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Find the location for this marker
    final location = widget.locations.firstWhere(
      (loc) =>
          loc.latitude == marker.point.latitude &&
          loc.longitude == marker.point.longitude,
      orElse: () => widget.locations.first,
    );

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location header
            Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location.locationName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${location.viewCount} views',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Members list
            Text(
              '${location.members.length} ${location.members.length == 1 ? 'Member' : 'Members'}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),

            // Member avatars and names
            ...location.members.take(5).map((member) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    _buildMemberAvatar(member, theme),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.name ?? member.email ?? 'Unknown',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (member.email != null && member.name != null)
                            Text(
                              member.email!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            if (location.members.length > 5) ...[
              const SizedBox(height: 4),
              Text(
                '+${location.members.length - 5} more',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMemberAvatar(dynamic member, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final photoUrl = member.profilePhotos.isNotEmpty
        ? member.profilePhotos.first.publicUrl
        : null;

    if (photoUrl != null) {
      return CircleAvatar(
        radius: 14,
        backgroundImage: CachedNetworkImageProvider(photoUrl),
        backgroundColor: colorScheme.surfaceContainerHighest,
      );
    }

    final name = member.name ?? member.email ?? '';
    final initials = name.isNotEmpty
        ? name.split(' ').take(2).map((e) => e.isNotEmpty ? e[0] : '').join()
        : '?';

    return CircleAvatar(
      radius: 14,
      backgroundColor: colorScheme.primaryContainer,
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.locations.isEmpty) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.map_outlined,
                size: 48,
                color: colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                'No location data available',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Views with location will appear here',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _calculateCenter(),
              initialZoom: _calculateZoom(),
              minZoom: 2.0,
              maxZoom: 18.0,
              onTap: (_, __) {
                _popupController.hideAllPopups();
                setState(() {
                  _selectedLocation = null;
                });
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.bluebubbles.app',
              ),
              PopupMarkerLayer(
                options: PopupMarkerLayerOptions(
                  popupController: _popupController,
                  markers: _buildMarkers(theme),
                  popupDisplayOptions: PopupDisplayOptions(
                    builder: _buildPopup,
                  ),
                ),
              ),
            ],
          ),

          // Map title overlay
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.map_rounded,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'View Locations',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.locations.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Zoom controls
          Positioned(
            right: 12,
            bottom: 12,
            child: Column(
              children: [
                _buildZoomButton(
                  icon: Icons.add,
                  onTap: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      (currentZoom + 1).clamp(2.0, 18.0),
                    );
                  },
                  theme: theme,
                ),
                const SizedBox(height: 4),
                _buildZoomButton(
                  icon: Icons.remove,
                  onTap: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      (currentZoom - 1).clamp(2.0, 18.0),
                    );
                  },
                  theme: theme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomButton({
    required IconData icon,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}
