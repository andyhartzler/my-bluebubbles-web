# 🔧 Quick Integration Guide

This guide shows you **exactly** what code changes to make to use the new Mailchimp-level features.

---

## Step 1: Update Email Builder Screen

Find your `email_builder_screen.dart` file and make these changes:

### A. Update Imports

```dart
// AT THE TOP OF THE FILE

// OLD - Comment out or remove these:
// import 'widgets/component_palette.dart';
// import 'widgets/properties_panel.dart';

// NEW - Add these:
import 'widgets/enhanced_content_blocks_library.dart';
import 'widgets/enhanced_properties_panel.dart';
import 'widgets/send_test_dialog.dart';
import 'services/html_exporter.dart';
```

### B. Update Widget Usage

Find where you build the layout (probably in a `Row` with 3 panels), and replace:

```dart
// OLD
Row(
  children: [
    // Left panel
    SizedBox(
      width: 280,
      child: ComponentPalette(),  // ← REPLACE THIS
    ),

    // Center panel (canvas) - NO CHANGES NEEDED
    Expanded(
      child: CanvasArea(),
    ),

    // Right panel
    SizedBox(
      width: 320,
      child: PropertiesPanel(),  // ← REPLACE THIS
    ),
  ],
)

// NEW
Row(
  children: [
    // Left panel
    const EnhancedContentBlocksLibrary(),  // ← NEW! (has its own width)

    // Center panel (canvas) - NO CHANGES NEEDED
    Expanded(
      child: CanvasArea(),
    ),

    // Right panel
    const EnhancedPropertiesPanel(),  // ← NEW! (has its own width)
  ],
)
```

### C. Update Toolbar

Find your `BuilderToolbar` widget and add the `onSendTest` callback:

```dart
// OLD
BuilderToolbar(
  onSave: _handleSave,
  onPreview: () {
    provider.togglePreviewMode();
  },
  onUndo: provider.canUndo ? () => provider.undo() : null,
  onRedo: provider.canRedo ? () => provider.redo() : null,
)

// NEW - Add onSendTest
BuilderToolbar(
  onSave: _handleSave,
  onPreview: () {
    provider.togglePreviewMode();
  },
  onUndo: provider.canUndo ? () => provider.undo() : null,
  onRedo: provider.canRedo ? () => provider.redo() : null,
  onSendTest: () => _handleSendTest(context),  // ← ADD THIS
)
```

### D. Add Send Test Method

Add this new method to your screen's state class:

```dart
Future<void> _handleSendTest(BuildContext context) async {
  final provider = context.read<EmailBuilderProvider>();

  // Export current design to HTML
  final html = HtmlExporter().export(provider.document);

  // Show send test dialog
  await showDialog(
    context: context,
    builder: (context) => SendTestDialog(
      campaignId: widget.campaignId ?? 'preview',
      htmlContent: html,
    ),
  );
}
```

---

## Step 2: Deploy Supabase Edge Function

### A. Verify Function Exists

Check that this file exists:
```
supabase/functions/send-test-email/index.ts
```

✅ It does! (We created it)

### B. Deploy to Supabase

```bash
# From your project root
supabase functions deploy send-test-email
```

### C. Set Environment Variables (if needed)

```bash
# If you have AWS SES configured
supabase secrets set AWS_SES_ACCESS_KEY_ID=your_key
supabase secrets set AWS_SES_SECRET_ACCESS_KEY=your_secret
supabase secrets set FROM_EMAIL=info@moyoungdemocrats.org

# For development (function will work without these)
# The function will return success but not actually send
```

---

## Step 3: Test Everything

### Test Checklist

1. **Open Builder**
   ```
   ✅ Toolbar shows: Back, Undo/Redo, Mobile/Desktop toggle, Zoom, Preview, Send Test, Save
   ✅ Left sidebar shows: Content Blocks with categories (Basic, Layout, Media)
   ✅ Right sidebar shows: Properties panel
   ```

2. **Test Content Blocks**
   ```
   ✅ Can search for blocks
   ✅ Can switch between categories
   ✅ Can drag blocks to canvas
   ✅ Can click blocks to add them
   ```

3. **Test Section Layouts**
   ```
   ✅ Click "Add Section" button
   ✅ See 5 layout options with visual previews
   ✅ Select layout → section is added
   ```

4. **Test Properties Panel**
   ```
   ✅ Select a text component
   ✅ See "Content" and "Style" tabs
   ✅ Can insert merge tags (button appears)
   ✅ Can apply style presets (H1, H2, etc.)
   ```

5. **Test Merge Tags**
   ```
   ✅ Click "Insert Merge Tag" button
   ✅ Search dialog appears
   ✅ Can search for tags
   ✅ Select tag → inserted into text
   ```

6. **Test Send Test**
   ```
   ✅ Click "Send test" in toolbar
   ✅ Dialog appears
   ✅ Enter email address
   ✅ Click "Send Test"
   ✅ See success message (or dev message if AWS not configured)
   ```

7. **Test Zoom & Preview**
   ```
   ✅ Change zoom level (50%, 75%, 100%, 125%, 150%)
   ✅ Canvas scales correctly
   ✅ Toggle Mobile/Desktop
   ✅ Canvas width changes (375px vs 600px)
   ```

8. **Test HTML Export**
   ```
   ✅ Add text with merge tags like "Hello {{first_name}}"
   ✅ Save campaign
   ✅ Check htmlContent in database
   ✅ Verify merge tags converted to *|FIRST_NAME|*
   ✅ Verify mobile-responsive CSS is present
   ```

---

## Step 4: Optional Enhancements

### A. Customize Merge Tags

Edit `lib/features/campaigns/email_builder/widgets/merge_tag_picker_dialog.dart`:

```dart
// Find the _mergeTags list and add your own:
final List<MergeTag> _mergeTags = [
  // ... existing tags ...

  // Add your custom tags here:
  MergeTag(
    tag: 'custom_field',
    label: 'Custom Field',
    category: 'Custom',
    example: 'Example value',
    fallback: 'Default value',
  ),
];
```

### B. Customize Style Presets

Edit `lib/features/campaigns/email_builder/widgets/enhanced_properties_panel.dart`:

```dart
// Find the _applyPreset method and modify presets:
case 'h1':
  newStyle = component.style.copyWith(
    fontSize: 32,  // ← Change these
    bold: true,
    lineHeight: 1.2,
  );
  break;
```

### C. Add More Content Blocks

Edit `lib/features/campaigns/email_builder/widgets/enhanced_content_blocks_library.dart`:

```dart
// Find _blocksByCategory map and add to any category:
'Basic': [
  // ... existing blocks ...

  // Add new block:
  BlockDefinition(
    id: 'my-custom-block',
    name: 'My Block',
    icon: Icons.star,
    description: 'My custom block',
    builder: () => EmailComponent.text(
      id: const Uuid().v4(),
      content: 'Custom content',
    ),
  ),
],
```

---

## Common Issues & Solutions

### Issue: "Import not found"
**Solution**: Make sure the new files are in the correct directories:
- `lib/features/campaigns/email_builder/widgets/enhanced_*.dart`
- `supabase/functions/send-test-email/index.ts`

### Issue: "Provider not found"
**Solution**: Make sure the screen is wrapped with the provider:
```dart
ChangeNotifierProvider(
  create: (_) => EmailBuilderProvider(),
  child: EmailBuilderScreen(),
)
```

### Issue: "Send test doesn't work"
**Solution**:
1. Check Supabase function is deployed: `supabase functions list`
2. Check function logs: `supabase functions logs send-test-email`
3. Verify CORS headers are returned

### Issue: "Merge tags not converting"
**Solution**: The conversion happens in `HtmlExporter.export()`. Make sure you're calling it when saving:
```dart
final html = HtmlExporter().export(provider.document);
// Use 'html' for the campaign's htmlContent field
```

---

## File Structure Overview

After integration, your structure should look like:

```
lib/features/campaigns/email_builder/
├── models/
│   ├── email_component.dart (existing)
│   └── email_document.dart (existing)
├── providers/
│   └── email_builder_provider.dart (modified)
├── services/
│   └── html_exporter.dart (modified)
├── screens/
│   └── email_builder_screen.dart (YOUR CHANGES)
└── widgets/
    ├── builder_toolbar.dart (replaced)
    ├── canvas_area.dart (modified)
    ├── enhanced_content_blocks_library.dart (NEW)
    ├── enhanced_properties_panel.dart (NEW)
    ├── merge_tag_picker_dialog.dart (NEW)
    ├── send_test_dialog.dart (NEW)
    ├── component_palette.dart (OLD - can keep for reference)
    ├── properties_panel.dart (OLD - can keep for reference)
    └── ... other existing widgets

supabase/functions/
└── send-test-email/
    └── index.ts (NEW)
```

---

## Verification Script

Run this to verify all files are in place:

```bash
# Check Flutter files exist
ls lib/features/campaigns/email_builder/widgets/enhanced_content_blocks_library.dart
ls lib/features/campaigns/email_builder/widgets/enhanced_properties_panel.dart
ls lib/features/campaigns/email_builder/widgets/merge_tag_picker_dialog.dart
ls lib/features/campaigns/email_builder/widgets/send_test_dialog.dart
ls lib/features/campaigns/email_builder/widgets/builder_toolbar.dart

# Check Supabase function exists
ls supabase/functions/send-test-email/index.ts

# All should show "file exists" - if any show "No such file", check the path
```

---

## Performance Tips

1. **Lazy Loading**: Content blocks library only renders visible items
2. **Debounce**: Text inputs auto-save but consider debouncing for large emails
3. **Zoom**: Transform.scale is performant but avoid 200%+ zoom on complex emails
4. **History**: Limited to 50 items automatically - no action needed

---

## That's It!

You're ready to use your new Mailchimp-level email builder! 🎉

**Next**: Test each feature, gather user feedback, and iterate.

**Questions?** Check `IMPLEMENTATION_COMPLETE_SUMMARY.md` for detailed feature documentation.

**Happy Building!** 📧✨
