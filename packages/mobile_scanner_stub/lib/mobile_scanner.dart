library mobile_scanner;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum DetectionSpeed {
  normal,
}

enum CameraFacing {
  back,
  front,
}

enum TorchState {
  off,
  on,
  unavailable,
}

class Barcode {
  final String? rawValue;

  const Barcode({this.rawValue});
}

class BarcodeCapture {
  final List<Barcode> barcodes;

  const BarcodeCapture({this.barcodes = const []});
}

class MobileScannerController {
  final ValueNotifier<TorchState> torchState;
  final ValueNotifier<CameraFacing> cameraFacingState;

  MobileScannerController({
    DetectionSpeed detectionSpeed = DetectionSpeed.normal,
    CameraFacing facing = CameraFacing.back,
  })  : torchState = ValueNotifier<TorchState>(TorchState.off),
        cameraFacingState = ValueNotifier<CameraFacing>(facing);

  Future<void> toggleTorch() async {
    if (torchState.value == TorchState.unavailable) return;
    torchState.value =
        torchState.value == TorchState.on ? TorchState.off : TorchState.on;
  }

  Future<void> switchCamera() async {
    cameraFacingState.value = cameraFacingState.value == CameraFacing.back
        ? CameraFacing.front
        : CameraFacing.back;
  }

  void dispose() {
    torchState.dispose();
    cameraFacingState.dispose();
  }
}

typedef MobileScannerCallback = void Function(BarcodeCapture capture);

class MobileScanner extends StatelessWidget {
  final MobileScannerCallback? onDetect;
  final MobileScannerController? controller;

  const MobileScanner({super.key, this.onDetect, this.controller});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
