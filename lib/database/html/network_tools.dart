import 'dart:async';

/// Shim for NetworkTools to allow for web compile
Future<void> configureNetworkTools(
  String directoryPath, {
  bool enableDebugging = false,
}) async {}

class HostScannerService {
  HostScannerService._();

  static final HostScannerService instance = HostScannerService._();

  Stream<ActiveHost> scanDevicesForSinglePort(
    String subnet,
    int port, {
    int firstHostId = 1,
    int lastHostId = 254,
    Duration timeout = const Duration(milliseconds: 2000),
    dynamic progressCallback,
    bool resultsInAddressAscendingOrder = true,
  }) {
    return Stream<ActiveHost>.empty();
  }
}

class HostScanner {
  /// Obtains the IPv4 address of the connected wifi network
  static Stream<ActiveHost> scanDevicesForSinglePort(
    String subnet,
    int port, {
    int firstHostId = 1,
    int lastHostId = 254,
    Duration timeout = const Duration(milliseconds: 2000),
    dynamic progressCallback,
    bool resultsInAddressAscendingOrder = true,
  }) {
    return Stream<ActiveHost>.empty();
  }
}

class ActiveHost {
  ActiveHost({this.address = ""});

  String address;
}
