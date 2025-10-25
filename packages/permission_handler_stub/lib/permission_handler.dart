library permission_handler;

enum PermissionStatus {
  denied,
  granted,
  restricted,
  limited,
  permanentlyDenied,
  provisional,
}

extension PermissionStatusGetters on PermissionStatus {
  bool get isGranted => this == PermissionStatus.granted;
  bool get isDenied => this == PermissionStatus.denied;
  bool get isPermanentlyDenied => this == PermissionStatus.permanentlyDenied;
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

  Future<PermissionStatus> request() async => PermissionStatus.granted;
  Future<PermissionStatus> get status async => PermissionStatus.granted;
  Future<bool> get isGranted async => true;
  Future<bool> get isDenied async => false;
  Future<bool> get isPermanentlyDenied async => false;
}

extension PermissionStatusFutureGetters on Future<PermissionStatus> {
  Future<bool> get isGranted async => (await this).isGranted;
  Future<bool> get isDenied async => (await this).isDenied;
  Future<bool> get isPermanentlyDenied async => (await this).isPermanentlyDenied;
}
