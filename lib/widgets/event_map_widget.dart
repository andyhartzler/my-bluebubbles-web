import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:js' as js;
// dart:js_interop's `.toJS` getter on Function is the modern replacement
// for allowInterop and is cross-platform-resolvable by flutter analyze.
import 'dart:js_interop';
import '../utils/mapkit_token_manager.dart';

// Shim: re-introduce an `allowInterop`-style helper that works on the new
// SDK. Returns a JSFunction; legacy `dart:js` callMethod still accepts it.
// Use a precise function type so toJS is happy under dart2js.
JSFunction _ai0(void Function() f) => f.toJS;
JSFunction _ai1(void Function(dynamic) f) => f.toJS;
JSFunction _ai2(void Function(dynamic, dynamic) f) => f.toJS;

class EventMapWidget extends StatefulWidget {
  final String location;
  final String? locationAddress;
  final String eventTitle;
  final double? height;

  const EventMapWidget({
    Key? key,
    required this.location,
    this.locationAddress,
    required this.eventTitle,
    this.height,
  }) : super(key: key);

  @override
  State<EventMapWidget> createState() => _EventMapWidgetState();
}

class _EventMapWidgetState extends State<EventMapWidget> with AutomaticKeepAliveClientMixin {
  final String _viewType = 'map-${DateTime.now().millisecondsSinceEpoch}';
  int? _actualViewId;
  bool _isLoading = true;
  String? _error;
  bool _mapInitialized = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

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

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      print('[EventMap] Platform view factory called with viewId: $viewId');

      _actualViewId = viewId;

      final containerHeight = (widget.height ?? 400).toStringAsFixed(0);

      // Create outer wrapper that clips content on mobile scroll
      // This fixes the issue where the map escapes its container when scrolling on mobile
      final outerWrapper = html.DivElement()
        ..style.width = '100%'
        ..style.height = '${containerHeight}px'
        ..style.position = 'relative'
        ..style.overflow = 'hidden'
        ..style.borderRadius = '12px'
        // clip-path ensures content is clipped even on mobile browsers
        ..style.setProperty('clip-path', 'inset(0 round 12px)')
        ..style.setProperty('-webkit-clip-path', 'inset(0 round 12px)')
        // isolation creates a new stacking context to prevent z-index bleed
        ..style.setProperty('isolation', 'isolate')
        // contain: strict prevents the element from affecting layout outside its bounds
        ..style.setProperty('contain', 'strict');

      final mapContainer = html.DivElement()
        ..id = 'mapkit-$viewId'
        ..style.width = '100%'
        ..style.height = '${containerHeight}px'
        ..style.borderRadius = '12px'
        ..style.overflow = 'hidden'
        ..style.position = 'absolute'
        ..style.top = '0'
        ..style.left = '0'
        ..style.touchAction = 'pan-x pan-y'
        ..style.transform = 'translateZ(0)'
        ..style.backfaceVisibility = 'hidden'
        ..style.setProperty('-webkit-backface-visibility', 'hidden')
        ..style.setProperty('will-change', 'transform')
        ..style.setProperty('contain', 'layout paint');

      outerWrapper.append(mapContainer);

      print('[EventMap] Created container with ID: mapkit-$viewId');
      return outerWrapper;
    });

    _waitForMapKitAndInitialize();
  }

  void _waitForMapKitAndInitialize() {
    print('[EventMap] Waiting for MapKit to load...');

    final timeout = Duration(seconds: 15);
    final startTime = DateTime.now();

    void checkAndInit() {
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

      try {
        js.context.callMethod('whenMapKitReady', [
          _ai0(() {
            print('[EventMap] MapKit is ready, initializing...');
            _initializeMapKit();
          })
        ]);
      } catch (e) {
        print('[EventMap] Error checking MapKit readiness: $e');
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
      if (token == null || token.isEmpty) {
        throw Exception(
          'MapKit token not configured for this domain — '
          'pass --dart-define=MAPKIT_TOKEN_MOYD / MAPKIT_TOKEN_NETLIFY at build time',
        );
      }
      print('[EventMap] Initializing MapKit with token: ${token.substring(0, 20)}...');

      final mapkit = js.context['mapkit'];
      if (mapkit == null) {
        throw Exception('MapKit library not loaded');
      }

      final isInitialized = js.context['_mapkitInitialized'];
      if (isInitialized != true) {
        print('[EventMap] First MapKit initialization');

        js.JsObject authCallback = js.JsObject.jsify({
          'authorizationCallback': _ai1((done) {
            print('[EventMap] Authorization callback invoked');
            js.JsFunction doneFunc = done as js.JsFunction;
            doneFunc.apply([token]);
          })
        });

        js.JsFunction initFunc = mapkit['init'] as js.JsFunction;
        initFunc.apply([authCallback]);

        js.context['_mapkitInitialized'] = true;
      } else {
        print('[EventMap] MapKit already initialized globally');
      }

      _mapInitialized = true;

      Future.delayed(Duration(milliseconds: 500), () {
        _createMap();
      });
    } catch (e, stackTrace) {
      print('[EventMap] Error initializing MapKit: $e');
      print('[EventMap] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize map';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createMap() async {
    if (_actualViewId == null) {
      print('[EventMap] Waiting for platform view to be created...');
      await Future.delayed(Duration(milliseconds: 200));
      if (_actualViewId == null) {
        print('[EventMap] Platform view still not created, aborting');
        if (mounted) {
          setState(() {
            _error = 'Map container not initialized';
            _isLoading = false;
          });
        }
        return;
      }
    }

    try {
      print('[EventMap] Creating map for ${widget.location}');
      final mapkit = js.context['mapkit'];

      final Geocoder = mapkit['Geocoder'];
      final geocoder = js.JsObject(Geocoder, [
        js.JsObject.jsify({'language': 'en-US'})
      ]);

      final addressToGeocode = widget.locationAddress ?? widget.location;
      print('[EventMap] Geocoding address: $addressToGeocode');

      geocoder.callMethod('lookup', [
        addressToGeocode,
        _ai2((error, data) {
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

          final containerId = 'mapkit-$_actualViewId';
          print('[EventMap] Looking for container with ID: $containerId');

          final mapContainer = html.document.getElementById(containerId);
          if (mapContainer == null) {
            print('[EventMap] Map container not found! Available elements:');
            html.document.querySelectorAll('[id*="mapkit"]').forEach((el) {
              print('[EventMap]   Found element: ${el.id}');
            });

            if (mounted) {
              setState(() {
                _error = 'Map container not ready';
                _isLoading = false;
              });
            }
            return;
          }

          print('[EventMap] Container found, creating map...');

          final Coordinate = mapkit['Coordinate'];
          final CoordinateSpan = mapkit['CoordinateSpan'];
          final CoordinateRegion = mapkit['CoordinateRegion'];

          final mapCoordinate = js.JsObject(Coordinate, [
            coordinate['latitude'],
            coordinate['longitude']
          ]);

          final span = js.JsObject(CoordinateSpan, [0.01, 0.01]);
          final region = js.JsObject(CoordinateRegion, [mapCoordinate, span]);

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
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    if (_error != null) {
      return Container(
        width: double.infinity,
        height: widget.height ?? 400,
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

    // Use ClipRRect with Clip.hardEdge to ensure proper clipping on mobile scroll
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Container(
            width: double.infinity,
            height: widget.height ?? 400,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.hardEdge,
            child: HtmlElementView(viewType: _viewType),
          ),
          if (_isLoading)
            Container(
              width: double.infinity,
              height: widget.height ?? 400,
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
      ),
    );
  }
}
