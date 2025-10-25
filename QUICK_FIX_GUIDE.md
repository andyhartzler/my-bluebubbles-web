# BlueBubbles Web App - Quick Fix Guide

## Issues Found & Fixed

### Critical Issues Resolved:

#### 1. ❌ Base Href Was Wrong
**Problem:** `web/index.html` had `<base href="/web/">`
**Impact:** App would only work if deployed in a `/web/` subdirectory
**Fixed:** Changed to `<base href="/">` for root deployments

#### 2. ❌ Environment Variables Didn't Work in Production
**Problem:** Code only loaded `.env` file, which isn't included in builds
**Impact:** Production builds had no server credentials
**Fixed:** Proper `--dart-define` support at build time

#### 3. ❌ Server Version Check Blocks Access
**Problem:** Web app requires BlueBubbles server v42+
**Location:** `lib/main.dart` line 454-457
**Impact:** Won't work with servers older than v42
**Note:** This is by design, upgrade your server if needed

---

## How to Build Properly

### Local Development

**Method 1: Using .env file (Easiest)**

```bash
# 1. Create .env file
cp .env.example .env

# 2. Edit .env with your server details
nano .env  # or use your favorite editor

# Add these lines:
# NEXT_PUBLIC_BLUEBUBBLES_HOST=https://your-server.com
# NEXT_PUBLIC_BLUEBUBBLES_PASSWORD=your-password

# 3. Run the app
flutter run -d web-server
```

**Method 2: Using environment variables**

```bash
export NEXT_PUBLIC_BLUEBUBBLES_HOST=https://your-server.com
export NEXT_PUBLIC_BLUEBUBBLES_PASSWORD=your-password
flutter run -d web-server
```

### Production Build

**IMPORTANT:** For production, you MUST use `--dart-define`:

```bash
flutter build web \
  --dart-define=NEXT_PUBLIC_BLUEBUBBLES_HOST=https://your-server.com \
  --dart-define=NEXT_PUBLIC_BLUEBUBBLES_PASSWORD=your-password \
  --web-renderer auto \
  --release
```

### Why --dart-define?

Flutter web compiles to JavaScript at build time. The `.env` file is NOT included in the build output. The only way to inject environment variables into a production build is using `--dart-define` at build time.

---

## How to Deploy

### Option 1: Vercel (Recommended - Easiest)

```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
vercel

# When prompted, add environment variables:
# - NEXT_PUBLIC_BLUEBUBBLES_HOST
# - NEXT_PUBLIC_BLUEBUBBLES_PASSWORD
```

**Or use the web UI:**
1. Go to [vercel.com](https://vercel.com)
2. Import your GitHub repository
3. Add environment variables in project settings
4. Deploy!

### Option 2: GitHub Pages

1. **Enable GitHub Pages:**
   - Go to repository Settings → Pages
   - Source: "GitHub Actions"

2. **Add Secrets:**
   - Settings → Secrets and variables → Actions
   - Add `BLUEBUBBLES_HOST` and `BLUEBUBBLES_PASSWORD`

3. **Push to main branch** - auto-deploys!

4. **Access:** `https://yourusername.github.io/repository-name/`

### Option 3: Netlify

```bash
# Install Netlify CLI
npm install -g netlify-cli

# Login
netlify login

# Deploy
netlify deploy --prod

# Add environment variables in Netlify web UI:
# Site settings → Environment variables
```

### Option 4: Docker

```bash
# Build
docker-compose up -d

# Or manual:
docker build \
  --build-arg BLUEBUBBLES_HOST=https://your-server.com \
  --build-arg BLUEBUBBLES_PASSWORD=your-password \
  -t bluebubbles-web \
  -f Dockerfile.web .

docker run -d -p 8080:80 bluebubbles-web
```

---

## Testing Your Build

### Check if build includes credentials:

```bash
# Build the app
flutter build web \
  --dart-define=NEXT_PUBLIC_BLUEBUBBLES_HOST=https://test.com \
  --dart-define=NEXT_PUBLIC_BLUEBUBBLES_PASSWORD=test123 \
  --release

# Verify the build
ls -lah build/web/

# Serve locally
cd build/web
python3 -m http.server 8000

# Visit http://localhost:8000
# Open browser console and check for warnings about missing env vars
```

---

## Common Errors & Solutions

### Error: "WEB BUILD CONFIGURATION MISSING"

**Cause:** Environment variables not set
**Solution:**
- **Dev:** Create `.env` file from `.env.example`
- **Production:** Use `--dart-define` in build command

### Error: "Server version too low, please upgrade!"

**Cause:** Your BlueBubbles server is older than v42
**Solution:** Upgrade your BlueBubbles server to v0.2.0+

**Check server version:**
```bash
# On your Mac running BlueBubbles server:
# Open BlueBubbles Server → Settings → About
# Look for version number
```

### Error: "Failed to connect to server"

**Possible causes:**
1. Server URL is wrong
2. Server is not running
3. Server is not accessible from the internet
4. SSL certificate issues (if using HTTPS)

**Solution:**
```bash
# Test server accessibility
curl https://your-server.com/api/v1/server/info

# Should return JSON with server info
```

### Error: White screen or "Loading..."

**Causes:**
1. Wrong base href
2. Assets not loading
3. JavaScript errors

**Solution:**
1. Check browser console (F12) for errors
2. Verify base href in `web/index.html` matches deployment path
3. Check Network tab for failed requests

---

## Build Command Reference

### Development (with hot reload)
```bash
flutter run -d web-server --web-port 3000
```

### Production (optimized)
```bash
flutter build web \
  --dart-define=NEXT_PUBLIC_BLUEBUBBLES_HOST=https://your-server.com \
  --dart-define=NEXT_PUBLIC_BLUEBUBBLES_PASSWORD=your-password \
  --web-renderer auto \
  --release
```

### With custom base href (for subdirectory deployment)
```bash
flutter build web \
  --base-href /my-app/ \
  --dart-define=NEXT_PUBLIC_BLUEBUBBLES_HOST=https://your-server.com \
  --dart-define=NEXT_PUBLIC_BLUEBUBBLES_PASSWORD=your-password \
  --release
```

### HTML renderer (better compatibility, larger size)
```bash
flutter build web \
  --web-renderer html \
  --dart-define=NEXT_PUBLIC_BLUEBUBBLES_HOST=https://your-server.com \
  --dart-define=NEXT_PUBLIC_BLUEBUBBLES_PASSWORD=your-password \
  --release
```

### CanvasKit renderer (better performance, smaller size)
```bash
flutter build web \
  --web-renderer canvaskit \
  --dart-define=NEXT_PUBLIC_BLUEBUBBLES_HOST=https://your-server.com \
  --dart-define=NEXT_PUBLIC_BLUEBUBBLES_PASSWORD=your-password \
  --release
```

---

## What's Required

### Minimum Requirements:

✅ **BlueBubbles Server v42+** (v0.2.0+)
✅ **Flutter 3.24.0+**
✅ **Modern browser** (Chrome 87+, Firefox 78+, Safari 14+, Edge 87+)
✅ **Server must be internet-accessible** (not just localhost)

### Server Requirements:

Your BlueBubbles server must be:
- Running version 42 or higher
- Accessible via HTTPS (recommended) or HTTP
- Have a valid URL (not localhost if accessing remotely)
- Have CORS enabled for web access

---

## Checklist Before Deploying

- [ ] Server is v42 or newer
- [ ] Server is accessible via public URL
- [ ] Created `.env` file for local dev (optional)
- [ ] Tested locally with `flutter run -d web-server`
- [ ] Built with `--dart-define` for production
- [ ] Verified build output exists in `build/web/`
- [ ] Chose deployment platform (Vercel/Netlify/Pages/Docker)
- [ ] Added environment variables in deployment platform
- [ ] Deployed and tested in browser
- [ ] Checked browser console for errors (F12)

---

## Support

Still having issues?

1. **Check browser console (F12)** for JavaScript errors
2. **Check Network tab** for failed requests
3. **Verify server version** is 42+
4. **Test server URL** directly in browser
5. **Join Discord:** https://discord.gg/4F7nbf3
6. **GitHub Issues:** https://github.com/BlueBubblesApp/bluebubbles-app/issues

---

**Last Updated:** October 2025
**Status:** ✅ All critical issues fixed
