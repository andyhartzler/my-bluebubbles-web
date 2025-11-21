import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'dart:js' as js;
import 'package:js/js_util.dart' as js_util;
import '../utils/mapkit_token_manager.dart';

class EventMapWidget extends StatefulWidget {
  final String location;
  final String? locationAddress;
  final String eventTitle;

  const EventMapWidget({
    Key? key,
    required this.location,
    this.locationAddress,
    required this.eventTitle,
  }) : super(key: key);

  @override
  State<EventMapWidget> createState() => _EventMapWidgetState();
}

class _EventMapWidgetState extends State<EventMapWidget> {
  final String _viewId = 'map-${DateTime.now().millisecondsSinceEpoch}';
  bool _isLoading = true;
  String? _error;
  bool _mapInitialized = false;

  @override
  void initState() {
    super.initState();

    // CRITICAL: Validate token before attempting to initialize
    if (!MapKitTokenManager.isTokenValid()) {
      setState(() {
        _error = 'MapKit token not configured';
        _isLoading = false;
      });
      return;
    }

    _initializeMap();
  }

  void _initializeMap() {
    print('[EventMap] Starting map initialization for ${widget.location}');

    // Register the view factory for the map container
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final mapContainer = html.DivElement()
        ..id = 'mapkit-$viewId'
        ..style.width = '100%'
        ..style.height = '400px'
        ..style.borderRadius = '12px';

      return mapContainer;
    });

    // CRITICAL: Wait for MapKit to be ready before initializing
    // This prevents "mapkit is not defined" errors
    _waitForMapKitAndInitialize();
  }

  void _waitForMapKitAndInitialize() {
    print('[EventMap] Waiting for MapKit to load...');

    // Set a timeout to prevent infinite waiting
    final timeout = Duration(seconds: 15);
    final startTime = DateTime.now();

    void checkAndInit() {
      // Check if we've exceeded timeout
      if (DateTime.now().difference(startTime) > timeout) {
        print('[EventMap] Timeout waiting for MapKit');
        if (mounted) {
          setState(() {
            _error = 'Map loading timeout';
            _isLoading = false;
          });
        }
        return;
      }

      // Use the helper function we created in index.html
      try {
        js.context.callMethod('whenMapKitReady', [
          js.allowInterop(() {
            print('[EventMap] MapKit is ready, initializing...');
            _initializeMapKit();
          })
        ]);
      } catch (e) {
        print('[EventMap] Error checking MapKit readiness: $e');
        // Retry after a delay
        Future.delayed(Duration(milliseconds: 200), checkAndInit);
      }
    }

    checkAndInit();
  }

  void _initializeMapKit() {
    if (_mapInitialized) {
      print('[EventMap] Map already initialized, skipping');
      return;
    }

    try {
      final token = MapKitTokenManager.getToken();
      print('[EventMap] Initializing MapKit with token: ${token.substring(0, 20)}...');

      // CRITICAL: Check if MapKit has already been initialized globally
      // This prevents "mapkit.init() can only be called once" errors
      final mapkit = js.context['mapkit'];
      if (mapkit == null) {
        throw Exception('MapKit library not loaded');
      }

      // Only initialize if not already initialized
      final isInitialized = js.context['_mapkitInitialized'] ?? false;
      if (!isInitialized) {
        print('[EventMap] First MapKit initialization');
        final initOptions = js_util.newObject();
        js_util.setProperty(
          initOptions,
          'authorizationCallback',
          js.allowInterop((done) {
            print('[EventMap] Authorization callback invoked');
            done(token);
          }),
        );

        mapkit.callMethod('init', [initOptions]);
        js.context['_mapkitInitialized'] = true;
      } else {
        print('[EventMap] MapKit already initialized globally');
      }

      _mapInitialized = true;

      // Small delay to ensure DOM is ready
      Future.delayed(Duration(milliseconds: 300), () {
        _createMap();
      });
    } catch (e) {
      print('[EventMap] Error initializing MapKit: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize map';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createMap() async {
    try {
      print('[EventMap] Creating map for ${widget.location}');
      final mapkit = js.context['mapkit'];

      // Ensure required MapKit libraries are loaded before use
      final importLibrary = mapkit['importLibrary'];
      if (importLibrary != null) {
        print('[EventMap] Importing MapKit libraries');
        await js_util.promiseToFuture(
          js_util.callMethod(mapkit, 'importLibrary', ['map']),
        );
        await js_util.promiseToFuture(
          js_util.callMethod(mapkit, 'importLibrary', ['annotations']),
        );
        await js_util.promiseToFuture(
          js_util.callMethod(mapkit, 'importLibrary', ['services']),
        );
      }

      // Create geocoder
      final Geocoder = mapkit['Geocoder'];
      final geocoder = js.JsObject(Geocoder, [
        js.JsObject.jsify({'language': 'en-US'})
      ]);

      // Geocode the address
      final addressToGeocode = widget.locationAddress ?? widget.location;
      print('[EventMap] Geocoding address: $addressToGeocode');

      geocoder.callMethod('lookup', [
        addressToGeocode,
        js.allowInterop((error, data) {
          if (error != null) {
            print('[EventMap] Geocoding error: $error');
            if (mounted) {
              setState(() {
                _error = 'Location not found';
                _isLoading = false;
              });
            }
            return;
          }

          // CRITICAL: Check if results exist before accessing
          final results = data['results'];
          if (results == null || results.length == 0) {
            print('[EventMap] No geocoding results found');
            if (mounted) {
              setState(() {
                _error = 'Location not found';
                _isLoading = false;
              });
            }
            return;
          }

          final place = results[0];
          final coordinate = place['coordinate'];

          print('[EventMap] Geocoded to: ${coordinate['latitude']}, ${coordinate['longitude']}');

          // Create map
          final mapContainer = html.document.getElementById('mapkit-${_viewId}');
          if (mapContainer == null) {
            print('[EventMap] Map container not found');
            if (mounted) {
              setState(() {
                _error = 'Map container not ready';
                _isLoading = false;
              });
            }
            return;
          }

          // Create coordinate region
          final Coordinate = mapkit['Coordinate'];
          final CoordinateSpan = mapkit['CoordinateSpan'];
          final CoordinateRegion = mapkit['CoordinateRegion'];

          final mapCoordinate = js.JsObject(Coordinate, [
            coordinate['latitude'],
            coordinate['longitude']
          ]);

          final span = js.JsObject(CoordinateSpan, [0.01, 0.01]);
          final region = js.JsObject(CoordinateRegion, [mapCoordinate, span]);

          // Create map instance
          final Map = mapkit['Map'];
          final ColorSchemes = mapkit['Map']['ColorSchemes'];
          final FeatureVisibility = mapkit['FeatureVisibility'];

          final map = js.JsObject(Map, [
            mapContainer,
            js.JsObject.jsify({
              'region': region,
              'showsMapTypeControl': false,
              'showsZoomControl': true,
              'showsUserLocationControl': false,
              'showsCompass': FeatureVisibility['Hidden'],
              'colorScheme': ColorSchemes['Dark'],
            })
          ]);

          // Add marker
          final MarkerAnnotation = mapkit['MarkerAnnotation'];
          final markerCoordinate = js.JsObject(Coordinate, [
            coordinate['latitude'],
            coordinate['longitude']
          ]);

          final annotation = js.JsObject(MarkerAnnotation, [
            markerCoordinate,
            js.JsObject.jsify({
              'title': widget.eventTitle,
              'subtitle': widget.location,
              'color': '#273351',
            })
          ]);

          map.callMethod('addAnnotation', [annotation]);

          print('[EventMap] Map created successfully');

          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        })
      ]);
    } catch (e) {
      print('[EventMap] Error creating map: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to create map';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        width: double.infinity,
        height: 400,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            _error!,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 400,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: HtmlElementView(viewType: _viewId),
        ),
        if (_isLoading)
          Container(
            width: double.infinity,
            height: 400,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading map...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
