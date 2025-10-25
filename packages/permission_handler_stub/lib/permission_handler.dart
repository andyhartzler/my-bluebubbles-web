library permission_handler;

class PermissionStatus {
  final bool _granted;
  final bool _permanentlyDenied;

  const PermissionStatus._(this._granted, this._permanentlyDenied);

  bool get isGranted => _granted;
  bool get isDenied => !_granted && !_permanentlyDenied;
  bool get isPermanentlyDenied => _permanentlyDenied;
}

class PermissionRequestResult {
  final PermissionStatus status;
  const PermissionRequestResult(this.status);
}

class Permission {
  static final camera = Permission._();
  static final contacts = Permission._();
  static final storage = Permission._();
  static final photos = Permission._();
  static final notification = Permission._();
  static final phone = Permission._();
  static final scheduleExactAlarm = Permission._();

  const Permission._();

  Future<PermissionStatus> request() async => const PermissionStatus._(true, false);
  Future<PermissionStatus> get status async => const PermissionStatus._(true, false);
  Future<bool> get isGranted async => true;
  Future<bool> get isDenied async => false;
  Future<bool> get isPermanentlyDenied async => false;
}
