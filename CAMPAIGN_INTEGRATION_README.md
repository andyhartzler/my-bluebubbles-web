# Email Campaign Integration - Implementation Summary

## Overview

This implementation integrates the email campaign builder hosted at `https://mail.moyd.app` into the MOYD Flutter CRM. The integration allows users to create, manage, send, and analyze email campaigns using iframe-based email builder alongside the existing native Flutter builder.

## Changes Made

### 1. Dependencies Added

Added `webview_flutter: ^4.4.0` to `pubspec.yaml` for iframe integration.

**Action Required:** Run `flutter pub get` to install the new dependency.

### 2. Campaign Model Enhanced (`lib/models/crm/campaign.dart`)

Added the following fields to the `Campaign` model to match the Supabase schema:

- `sentAt` - DateTime when campaign was sent
- `createdBy` - User ID who created the campaign
- `fromName` - Sender name (default: "Missouri Young Democrats")
- `fromEmail` - Sender email (default: "info@moyoungdemocrats.org")
- `replyTo` - Reply-to email address
- `totalDelivered` - Count of delivered emails
- `totalBounced` - Count of bounced emails
- `totalComplained` - Count of spam complaints
- `totalUnsubscribed` - Count of unsubscribes
- `abTestEnabled` - Boolean for A/B testing
- `abTestConfig` - JSON configuration for A/B tests

### 3. New Email Builder Iframe Widget

**File:** `lib/features/campaigns/widgets/email_builder_iframe.dart`

This widget:
- Loads `https://mail.moyd.app` in a WebView
- Handles bi-directional communication via postMessage API
- Supports loading existing designs
- Exports HTML and design JSON when saving
- Shows loading states and error handling

### 4. New Iframe Editor Screen

**File:** `lib/features/campaigns/screens/campaign_iframe_editor_screen.dart`

This screen:
- Wraps the EmailBuilderIframe widget
- Loads campaign data from Supabase
- Saves design back to Supabase
- Integrates with the CampaignService

### 5. Enhanced Campaign Editor

**File:** `lib/features/campaigns/screens/campaign_editor_screen.dart`

Updated to offer two email builder options:
- **Native Builder** - Existing Flutter-based email builder
- **Web Builder** (NEW) - iframe-based builder from mail.moyd.app

Users can now choose which builder to use based on their preferences.

## User Flow: Using the Web Builder

1. Navigate to Campaigns → Create/Edit Campaign
2. Fill in campaign details (name, subject, preview text)
3. Save the campaign draft (required before opening builder)
4. Click "Web Builder" button in the Email Content section
5. Design email in the mail.moyd.app interface
6. Click "Save Design" in the builder
7. Builder exports HTML and JSON → saved to campaign
8. Return to campaign editor with design loaded

## Integration Workflow

### Creating a Campaign with Web Builder

```dart
// 1. User creates campaign
Campaign campaign = Campaign(
  name: 'Welcome Email',
  subject: 'Welcome to MOYD!',
  fromName: 'Missouri Young Democrats',
  fromEmail: 'info@moyoungdemocrats.org',
);

// 2. Save campaign to get ID
Campaign saved = await campaignService.saveCampaign(campaign);

// 3. Open iframe editor
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => CampaignIframeEditorScreen(
      campaignId: saved.id!,
      initialCampaign: saved,
    ),
  ),
);

// 4. User designs email in mail.moyd.app
// 5. On save, HTML + JSON returned and saved to Supabase
```

### PostMessage API Contract

The iframe builder at `https://mail.moyd.app` should implement the following postMessage contract:

**Messages FROM Flutter TO Builder:**

```javascript
// Load existing design
window.postMessage({
  type: 'LOAD_DESIGN',
  design: '<JSON string>'
}, '*');

// Request save
window.postMessage({
  type: 'SAVE_DESIGN'
}, '*');

// Reset editor
window.postMessage({
  type: 'RESET_EDITOR'
}, '*');
```

**Messages FROM Builder TO Flutter:**

```javascript
// Builder is ready
window.FlutterChannel.postMessage(JSON.stringify({
  action: 'ready'
}));

// Design saved
window.FlutterChannel.postMessage(JSON.stringify({
  action: 'save',
  html: '<HTML string>',
  design: '<JSON string>'
}));

// Error occurred
window.FlutterChannel.postMessage(JSON.stringify({
  action: 'error',
  error: 'Error message'
}));
```

## Database Schema

The following Supabase tables are used (DO NOT modify schemas):

### `campaigns` Table
- `id` (uuid, primary key)
- `created_at`, `updated_at` (timestamps)
- `created_by` (uuid, user reference)
- `name`, `subject`, `preview_text` (text)
- `from_name`, `from_email`, `reply_to` (text)
- `html_content`, `text_content` (text)
- `design_json` (jsonb)
- `status` (enum: draft, scheduled, sending, sent, failed)
- `scheduled_at`, `sent_at` (timestamps)
- `segment` (jsonb, MessageFilter)
- `expected_recipients`, `sent_count`, `opened_count`, `clicked_count` (int)
- `total_delivered`, `total_bounced`, `total_complained`, `total_unsubscribed` (int)
- `ab_test_enabled` (boolean)
- `ab_test_config` (jsonb)

### `campaign_recipients` Table
- Individual recipient tracking with delivery status

### `campaign_analytics` Table
- Aggregated campaign analytics

## Existing Features Preserved

All existing campaign functionality remains intact:
- ✅ Native Flutter email builder
- ✅ Campaign list and filtering
- ✅ Segment builder for targeting
- ✅ Preview and recipient management
- ✅ Scheduling and sending
- ✅ Analytics dashboard

## Next Steps

1. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

2. **Verify mail.moyd.app Integration:**
   - Ensure the email builder is deployed at `https://mail.moyd.app`
   - Verify postMessage API is implemented correctly
   - Test loading designs and saving

3. **Test the Integration:**
   - Create a test campaign
   - Open Web Builder
   - Verify builder loads correctly
   - Design a simple email
   - Save and verify HTML/JSON is captured
   - Check Supabase for saved design

4. **Optional Enhancements:**
   - Add template library integration
   - Implement A/B testing UI
   - Add campaign duplication
   - Enhanced analytics charts

## Known Limitations

1. **Web Builder requires saved campaign** - Campaign must be saved before opening the iframe builder to ensure there's a valid campaign ID
2. **Internet connection required** - The iframe builder requires internet access to load mail.moyd.app
3. **Mobile UX** - Web builder is optimized for desktop/tablet, may have limited functionality on mobile devices

## Support

For issues related to:
- **Flutter Integration:** Check this codebase and Flutter console logs
- **Email Builder:** Check mail.moyd.app deployment and browser console
- **Supabase:** Verify RLS policies and Edge Functions

## File Structure

```
lib/
├── models/crm/
│   └── campaign.dart (UPDATED - added new fields)
├── services/crm/
│   └── campaign_service.dart (existing, works with new fields)
└── features/campaigns/
    ├── screens/
    │   ├── campaign_editor_screen.dart (UPDATED - added Web Builder option)
    │   └── campaign_iframe_editor_screen.dart (NEW)
    └── widgets/
        └── email_builder_iframe.dart (NEW)
```

## Testing Checklist

- [ ] Run `flutter pub get` successfully
- [ ] Campaign model changes don't break existing functionality
- [ ] Can create new campaign with fromName/fromEmail fields
- [ ] Native builder still works
- [ ] Web builder loads mail.moyd.app in iframe
- [ ] Can save design from Web builder
- [ ] HTML and designJson are saved to Supabase
- [ ] Can reload saved design in Web builder
- [ ] Campaign list shows updated campaigns
- [ ] Analytics work with new fields

---

**Implementation Date:** 2025-11-30
**Version:** 1.0.0
**Status:** Ready for Testing
