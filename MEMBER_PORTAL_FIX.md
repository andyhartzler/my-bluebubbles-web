# Member Portal Meetings Tab Fix

## Issue
The meetings tab on the member portal management page was throwing "An unexpected error occurred when rendering." causing the entire page to appear blank. Initially, the page would load for about one second showing the meetings list, then flash and crash to a grey error screen. After the initial fix, the meetings tab loaded successfully, but clicking on any meeting tile to view details caused the same crash.

## Root Cause

### Issue #1: Auto-selection during build
The code was attempting to auto-select the first meeting using `WidgetsBinding.instance.addPostFrameCallback()` in the build method. This triggered `_selectMeeting()` which called multiple `setState()` operations during the render cycle, causing a Flutter rendering error.

### Issue #2: Multiple synchronous setState calls on meeting selection
When a user clicked on a meeting tile, `_selectMeeting()` would:
1. Call `setState()` to update the meeting state (line 460)
2. Immediately call `_loadMeetingDetails(meeting)` synchronously (line 480)
3. `_loadMeetingDetails()` would immediately call `setState()` again (line 504)
4. Multiple synchronous `setState()` calls caused rendering crash

Additionally, if HTML parsing in `_controllerFromHtml()` threw an exception, it would crash the entire widget without any error handling.

## Solution

### Fix #1: Remove auto-selection during build
Removed the problematic auto-selection logic in `lib/screens/crm/member_portal/member_portal_management_screen.dart`:

1. **Removed** the `postFrameCallback` that was auto-selecting the first meeting (lines 331-337)
2. **Removed** the `_resolveSelectedMeeting()` helper function that was no longer needed
3. **Changed** selectedMeeting logic to only select a meeting when explicitly set by user interaction

### Fix #2: Refactor meeting selection to avoid synchronous setState calls
Refactored `_selectMeeting()` and `_loadMeetingDetails()` methods:

1. **Added** try-catch around HTML parsing to handle malformed HTML gracefully
2. **Moved** `_loadMeetingDetails()` call into a `postFrameCallback` to run after the current frame
3. **Consolidated** loading state into the initial `setState()` call
4. **Simplified** `_loadMeetingDetails()` to only update state when async operations complete

Now the meetings tab will:
- Load and display all meetings successfully
- Show a placeholder message prompting user to select a meeting
- Load meeting details when a user clicks on a meeting card without crashing
- Handle HTML parsing errors gracefully with empty editors
- Properly schedule async operations to avoid setState conflicts

## How to Apply the Fix

### Full Rebuild and Restart
```bash
# 1. Pull the latest changes
git pull origin claude/fix-meetings-tab-error-01AzojhyEjSSRUtw2hYrzcsj

# 2. Clean and rebuild
flutter clean
flutter pub get

# 3. Restart your dev server
flutter run -d chrome
# Or for production build:
flutter build web --release

# 4. Hard refresh your browser (Ctrl+Shift+R or Cmd+Shift+R)
```

## Verification
After applying the fix, the meetings tab should:
- ✅ Load without errors and display the list of meetings on the left
- ✅ Show a placeholder on the right prompting "Select a meeting to edit"
- ✅ Load meeting details when user clicks on a meeting card
- ✅ Allow editing meeting details (description, summary, key points, etc.)
- ✅ Successfully save changes without crashes
- ✅ No longer auto-select meetings on page load

## Code Changes
**File:** `lib/screens/crm/member_portal/member_portal_management_screen.dart`

### Change #1: Remove auto-selection during build
**Lines 328-337:** Replaced auto-selection postFrameCallback with explicit selection logic
```dart
// Before: Auto-selected first meeting causing setState during build
final selectedMeeting = _resolveSelectedMeeting(meetings);
if (selectedMeeting != null && _editingMeetingId != selectedMeeting.id) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      _selectMeeting(selectedMeeting);  // ❌ Caused crash
    }
  });
}

// After: Only select if explicitly chosen by user
final selectedMeeting = _selectedMeetingId != null
    ? meetings.cast<MemberPortalMeeting?>().firstWhere(
        (m) => m?.id == _selectedMeetingId,
        orElse: () => null,
      )
    : null;  // ✅ No automatic selection
```

**Lines 413-423:** Removed unused `_resolveSelectedMeeting()` function

### Change #2: Fix meeting selection to avoid synchronous setState
**In `_selectMeeting()`:**
- Added try-catch around `_controllerFromHtml()` calls
- Set `_loadingMeetingDetails = true` in the initial setState
- Moved `_loadMeetingDetails()` call into postFrameCallback

**In `_loadMeetingDetails()`:**
- Removed the initial setState that was causing synchronous setState conflicts
- Consolidated loading state updates into async completion handlers

## Related Commits
- Current fix (part 2) - Fix meeting selection crash with proper setState scheduling
- 23f0b7e - Fix member portal meetings tab rendering crash (part 1)
- 796a1e4 - Add rebuild instructions for member portal meetings tab fix
- 3ffe33b - Remove member portal recording data
- 33cbe37 - Remove recording embed from member portal meetings
- 86dbdaa - Merge PR #585 removing recording functionality

## Technical Notes
This is a common Flutter anti-pattern: calling `setState()` during the build phase. Even when wrapped in `postFrameCallback`, triggering multiple state changes and async operations can cause rendering errors. The fix ensures state changes only happen in response to explicit user actions (tapping a meeting card).
