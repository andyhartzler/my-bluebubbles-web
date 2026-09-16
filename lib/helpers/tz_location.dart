import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Lazy timezone-database initialization.
///
/// `initializeTimeZones()` parses a ~253 KB IANA blob synchronously on the main
/// isolate and retains ~600 `Location` objects for the process lifetime. It
/// used to run in `main()` before `runApp`, on the critical path to first
/// paint, even though the first screen is the auth gate and nothing on it
/// touches a timezone.
///
/// Every consumer now goes through [tzLocation], which pays that cost on the
/// first lookup instead. The try/catch pattern is the one
/// `auto_inferred_assignments_service.dart` already used: `getLocation` throws
/// `LocationNotFoundException` when the database is empty, so the catch branch
/// runs exactly once per process.
///
/// If you add a `tz.getLocation(...)` or a `tz.TZDateTime` anywhere, route it
/// through this helper or call `initializeTimeZones()` yourself first.
/// Otherwise it throws at render time.
/// Guarded on the timezone package's own state rather than a private flag.
///
/// A private bool would miss the direct `initializeTimeZones()` call in
/// `vote_detail_screen.dart`. If that screen ran first, this helper would
/// still think the database was empty and initialize it a second time.
/// `initializeDatabase()` ends with `setLocalLocation(_utc)`, so the second
/// run would silently reset `tz.local` to UTC and discard the real local
/// zone that `main()` had already set on Android.
void ensureTimeZonesInitialized() {
  if (tz.timeZoneDatabase.isInitialized) return;
  tzdata.initializeTimeZones();
}

/// Resolve an IANA location, initializing the timezone database on first use.
tz.Location tzLocation(String name) {
  try {
    return tz.getLocation(name);
  } on tz.LocationNotFoundException {
    ensureTimeZonesInitialized();
    return tz.getLocation(name);
  }
}
