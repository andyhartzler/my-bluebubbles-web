library mobile_scanner;

import 'package:flutter/widgets.dart';

class Barcode {
  final String? rawValue;

  const Barcode({this.rawValue});
}

class BarcodeCapture {
  final List<Barcode> barcodes;

  const BarcodeCapture({this.barcodes = const []});
}

typedef MobileScannerCallback = void Function(BarcodeCapture capture);

class MobileScanner extends StatelessWidget {
  final MobileScannerCallback? onDetect;

  const MobileScanner({super.key, this.onDetect});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
