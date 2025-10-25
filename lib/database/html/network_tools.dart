import 'dart:async';

/// Shim for NetworkInfo to allow for web compile
class HostScannerService {
  HostScannerService._();

  static final HostScannerService instance = HostScannerService._();

  /// Web builds can't scan the local network, so this stub simply returns an
  /// empty stream while preserving the expected method signature.
  Stream<ActiveHost> scanDevicesForSinglePort(
    String subnet,
    int port, {
    int firstHostId = 1,
    int lastHostId = 254,
    Duration timeout = const Duration(milliseconds: 2000),
    dynamic progressCallback,
    bool resultsInAddressAscendingOrder = true,
  }) {
    final StreamController<ActiveHost> activeHostsController = StreamController<ActiveHost>();
    scheduleMicrotask(activeHostsController.close);
    return activeHostsController.stream;
  }
}

class ActiveHost {
  String address = "";
}