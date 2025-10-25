# Web-Only Cleanup Guide

This document outlines directories and files that can be safely removed since this is now a **web-only** project.

## 📋 Safe to Remove

These directories/files are only needed for native mobile/desktop platforms:

### Platform Directories (Can Delete)
```
android/          # Android-specific code and build files
ios/              # iOS-specific code and build files
linux/            # Linux desktop-specific code
macos/            # macOS desktop-specific code
windows/          # Windows desktop-specific code
snap/             # Snapcraft packaging (Linux)
```

### Native Screenshots (Can Delete)
```
screenshots/      # Contains mobile device screenshots
```

### Native Package Dependencies (Consider Removing)
The following can be removed from `pubspec.yaml` since they're mobile/desktop-only:

**Android/iOS Only:**
```yaml
fast_contacts
flutter_displaymode
flutter_local_notifications
google_ml_kit
mobile_scanner
permission_handler
photo_manager
receive_intent
```

**Desktop Only:**
```yaml
bitsdojo_window
desktop_webview_auth
flutter_acrylic
launch_at_startup
local_notifier
screen_retriever
system_tray
tray_manager
window_manager
windows_taskbar
msix  # Windows packaging
```

**Native File System (FFI-based):**
```yaml
objectbox
objectbox_flutter_libs
objectbox_generator
```

## ✅ Must Keep

These are needed for web functionality:

### Core Web Support
```
web/              # Web-specific files (index.html, manifest.json, etc.)
lib/              # Application code
assets/           # Images, fonts, icons
scripts/          # Helper scripts like run_web.sh
.devcontainer/    # GitHub Codespaces configuration
```

### Web-Compatible Dependencies
Keep these packages - they have web support:
- `flutter` (core framework)
- `adaptive_theme`
- `animations`
- `dio` (HTTP client)
- `firebase_dart`
- `flutter_dotenv`
- `google_fonts`
- `google_sign_in`
- `shared_preferences`
- `url_launcher`
- `universal_html`
- `universal_io`
- etc.

## 🔧 Recommended Actions

### Option 1: Gradual Cleanup (Recommended)
Keep the directories for now but ignore them. They won't affect web builds and you can remove them later if needed.

**Update `.gitignore`:**
```gitignore
# Ignore native platform directories (web-only project)
/android/
/ios/
/linux/
/macos/
/windows/
/snap/
/screenshots/
```

**Benefits:**
- ✅ No risk of breaking existing code
- ✅ Easy to test web builds first
- ✅ Can restore if needed
- ✅ Smaller Git diffs

### Option 2: Complete Removal (Advanced)
Physically delete the directories and clean up `pubspec.yaml`.

```bash
# Remove native platform directories
rm -rf android ios linux macos windows snap screenshots

# Clean up dependencies
# Edit pubspec.yaml manually to remove mobile/desktop-only packages

# Test the build
flutter clean
flutter pub get
flutter build web
```

**Benefits:**
- ✅ Cleaner repository
- ✅ Faster dependency installation
- ✅ Smaller codebase
- ⚠️ **Cannot be easily reversed**

## 🎯 Current State vs. Web-Only

### Current Structure
```
my-bluebubbles-web/
├── android/          ❌ Not needed for web
├── ios/              ❌ Not needed for web
├── linux/            ❌ Not needed for web
├── macos/            ❌ Not needed for web
├── windows/          ❌ Not needed for web
├── snap/             ❌ Not needed for web
├── screenshots/      ❌ Mobile screenshots
├── web/              ✅ KEEP - Web files
├── lib/              ✅ KEEP - App code
├── assets/           ✅ KEEP - Resources
├── scripts/          ✅ KEEP - Helper scripts
├── .devcontainer/    ✅ KEEP - Codespaces config
└── pubspec.yaml      ⚠️  Cleanup recommended
```

### Ideal Web-Only Structure
```
my-bluebubbles-web/
├── web/              ✅ Web-specific files
├── lib/              ✅ Application code
│   ├── database/
│   │   └── html/     ✅ Web implementations only
│   ├── services/
│   └── app/
├── assets/           ✅ Static resources
├── scripts/          ✅ run_web.sh
├── .devcontainer/    ✅ Development container
├── .gitignore        ✅ Updated for web-only
├── pubspec.yaml      ✅ Cleaned dependencies
└── README.md         ✅ Web-focused docs
```

## 📝 Decision Matrix

| Directory | Size Impact | Break Risk | Recommendation |
|-----------|-------------|------------|----------------|
| `android/` | Large | Low | Add to .gitignore or delete |
| `ios/` | Large | Low | Add to .gitignore or delete |
| `linux/` | Medium | Low | Add to .gitignore or delete |
| `macos/` | Medium | Low | Add to .gitignore or delete |
| `windows/` | Medium | Low | Add to .gitignore or delete |
| `snap/` | Small | None | Safe to delete |
| `screenshots/` | Medium | None | Safe to delete |
| `lib/database/io/` | Small | **High** | **KEEP** (used conditionally) |
| `packages/` | Medium | **High** | **KEEP** (contains custom packages) |

## ⚡ Quick Start (Recommended Path)

**Step 1:** Update `.gitignore` to ignore native directories
```bash
echo "# Web-only project - ignore native platforms" >> .gitignore
echo "/android/" >> .gitignore
echo "/ios/" >> .gitignore
echo "/linux/" >> .gitignore
echo "/macos/" >> .gitignore
echo "/windows/" >> .gitignore
echo "/snap/" >> .gitignore
```

**Step 2:** Test web build works
```bash
flutter clean
flutter pub get
flutter build web
```

**Step 3:** Delete screenshots (optional)
```bash
rm -rf screenshots/
```

**Step 4:** Future cleanup
- Remove native platform directories once confident
- Clean up `pubspec.yaml` dependencies
- Remove unused native code from `lib/database/io/`

---

**Questions?** Test your web build first before removing anything!
