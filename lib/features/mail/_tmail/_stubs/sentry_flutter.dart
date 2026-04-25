// Stub for sentry_flutter. We don't ship Sentry telemetry. Provides
// no-op SentryEvent / SentryFlutter / SentryFlutterOptions / Hub /
// SentryWidget so any tmail file that imports sentry_flutter resolves.
import 'package:flutter/widgets.dart';

class SentryEvent {
  String? message;
  String? level;
  SentryEvent({this.message, this.level});
}

typedef BeforeSendCallback = SentryEvent? Function(SentryEvent, dynamic);

class MaxRequestBodySize {
  static const small = MaxRequestBodySize._('small');
  static const medium = MaxRequestBodySize._('medium');
  static const always = MaxRequestBodySize._('always');
  static const never = MaxRequestBodySize._('never');
  final String _v;
  const MaxRequestBodySize._(this._v);
}

class SentryFlutterOptions {
  String? dsn;
  String? environment;
  String? release;
  bool autoSessionTracking = false;
  bool reportPackages = false;
  double tracesSampleRate = 0.0;
  double profilesSampleRate = 0.0;
  MaxRequestBodySize maxRequestBodySize = MaxRequestBodySize.medium;
  BeforeSendCallback? beforeSend;
  bool sendDefaultPii = false;
  bool attachScreenshot = false;
  bool enableAutoPerformanceTracing = false;
}

class Hub {
  static final instance = Hub();
  Future<void> captureException(Object _, {dynamic stackTrace}) async {}
  Future<void> captureMessage(String _) async {}
  void addBreadcrumb(dynamic _) {}
  Future<void> close() async {}
}

class SentryFlutter {
  static final hub = Hub.instance;
  static Future<void> init(
    void Function(SentryFlutterOptions) configure, {
    Future<void> Function()? appRunner,
  }) async {
    configure(SentryFlutterOptions());
    if (appRunner != null) await appRunner();
  }
  static Future<void> captureException(Object _, {dynamic stackTrace}) async {}
}

class SentryWidgetsFlutterBinding extends WidgetsFlutterBinding {
  static SentryWidgetsFlutterBinding ensureInitialized() {
    WidgetsFlutterBinding.ensureInitialized();
    return SentryWidgetsFlutterBinding._();
  }
  SentryWidgetsFlutterBinding._();
}

class SentryWidget extends StatelessWidget {
  final Widget child;
  const SentryWidget({super.key, required this.child});
  @override
  Widget build(BuildContext context) => child;
}

class Breadcrumb {
  final String? message;
  final String? category;
  Breadcrumb({this.message, this.category});
}

class SentryLevel {
  static const info = SentryLevel._('info');
  static const warning = SentryLevel._('warning');
  static const error = SentryLevel._('error');
  final String _v;
  const SentryLevel._(this._v);
}

// SentryManager / SentryConfig were tmail's wrappers in core/utils/sentry/.
// We stripped that dir; expose no-op shims here so existing call sites
// (app_logger, base_controller, etc.) compile without a feature rewrite.

class SentryManager {
  static final SentryManager instance = SentryManager._();
  SentryManager._();
  Future<void> initialize({
    String? dsn,
    String? environment,
    String? release,
    Map<String, dynamic>? extras,
  }) async {}
  Future<void> captureMessage(
    String message, {
    SentryLevel? level,
    Map<String, dynamic>? extras,
  }) async {}
  Future<void> captureException(
    Object exception, {
    StackTrace? stackTrace,
    String? message,
    Map<String, dynamic>? extras,
  }) async {}
  void addBreadcrumb({String? message, String? category}) {}
  Future<void> close() async {}
  Future<void> clearUser() async {}
  Future<void> setUser({String? id, String? email}) async {}
}

class SentryConfig {
  final String? dsn;
  final String? environment;
  final String? release;
  const SentryConfig({this.dsn, this.environment, this.release});
}

extension SentryManagerExt on SentryManager {
  Future<void> clearUser() async {}
  Future<void> setUser({String? id, String? email}) async {}
}
