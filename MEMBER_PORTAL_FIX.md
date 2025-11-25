# Member Portal Meetings Tab Fix

## Issue
The meetings tab on the member portal management page was throwing "An unexpected error occurred when rendering." causing the entire page to appear blank.

## Root Cause
Recent commits removed recording functionality from the `MemberPortalMeeting` model (fields: `showRecording`, `recordingUrl`, `recordingEmbedUrl`, `resolvedRecordingEmbedUrl`). The Flutter web application was running with cached/compiled code that still expected these fields to exist, causing deserialization errors and widget build failures.

## Solution
All recording-related code has been successfully removed from:
- `lib/models/crm/member_portal.dart` - Removed recording fields from model
- `lib/screens/crm/member_portal/member_portal_management_screen.dart` - Removed recording UI and controls
- `lib/services/crm/member_portal_repository.dart` - Updated queries to not fetch recording data

## How to Apply the Fix

### Option 1: Full Rebuild (Recommended)
```bash
# Run the rebuild script
./scripts/rebuild_web.sh

# Then restart your web server and do a hard refresh in browser (Ctrl+Shift+R or Cmd+Shift+R)
```

### Option 2: Manual Steps
```bash
# 1. Clean all build artifacts
flutter clean

# 2. Get dependencies
flutter pub get

# 3. Rebuild the web application
flutter build web --release

# 4. Restart web server and hard refresh browser
```

### For Development
```bash
# Stop the current dev server
# Then restart with:
flutter run -d chrome --web-port=8080

# Or for web server:
flutter run -d web-server --web-port=8080
```

## Verification
After rebuilding, the meetings tab should:
- ✅ Load without errors
- ✅ Display the list of meetings
- ✅ Allow editing meeting details
- ✅ Show NO recording-related controls or fields
- ✅ Successfully save changes

## Related Commits
- 3ffe33b - Remove member portal recording data
- 33cbe37 - Remove recording embed from member portal meetings
- 86dbdaa - Merge PR #585 removing recording functionality

## Note for Future
When removing fields from Dart models, always do a full `flutter clean` and rebuild. Hot reload does not pick up structural model changes.
