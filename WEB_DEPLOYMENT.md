# BlueBubbles Web Deployment Guide

This guide covers everything you need to know about deploying the BlueBubbles web application.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Environment Configuration](#environment-configuration)
- [Local Development](#local-development)
- [Deployment Options](#deployment-options)
  - [GitHub Pages](#github-pages)
  - [Vercel](#vercel)
  - [Netlify](#netlify)
  - [Firebase Hosting](#firebase-hosting)
  - [Docker](#docker)
- [Storage Configuration](#storage-configuration)
- [CI/CD Pipeline](#cicd-pipeline)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before deploying, ensure you have:

- Flutter SDK 3.24.0 or later
- A BlueBubbles server instance (version 42+)
- Your server's URL and password/auth key
- Git installed

## Environment Configuration

### Required Environment Variables

The web app requires two environment variables to connect to your BlueBubbles server:

```bash
NEXT_PUBLIC_BLUEBUBBLES_HOST=https://your-server-url.com
NEXT_PUBLIC_BLUEBUBBLES_PASSWORD=your-guid-auth-key
```

### Setting Environment Variables

#### Option 1: .env file (Local Development)

Create a `.env` file in the project root:

```bash
NEXT_PUBLIC_BLUEBUBBLES_HOST=https://messages.example.com
NEXT_PUBLIC_BLUEBUBBLES_PASSWORD=your-secret-password
```

**⚠️ SECURITY WARNING:** Never commit the `.env` file to version control!

#### Option 2: Build-time Variables

Pass variables during build:

```bash
flutter build web \
  --dart-define=NEXT_PUBLIC_BLUEBUBBLES_HOST=https://your-server.com \
  --dart-define=NEXT_PUBLIC_BLUEBUBBLES_PASSWORD=your-password
```

#### Option 3: Export (Unix/Linux/Mac)

```bash
export NEXT_PUBLIC_BLUEBUBBLES_HOST=https://your-server.com
export NEXT_PUBLIC_BLUEBUBBLES_PASSWORD=your-password
flutter build web
```

#### Option 4: Set (Windows)

```cmd
set NEXT_PUBLIC_BLUEBUBBLES_HOST=https://your-server.com
set NEXT_PUBLIC_BLUEBUBBLES_PASSWORD=your-password
flutter build web
```

---

## Local Development

### Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/my-bluebubbles-web.git
   cd my-bluebubbles-web
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Set environment variables** (create `.env` file or export):
   ```bash
   export NEXT_PUBLIC_BLUEBUBBLES_HOST=https://your-server.com
   export NEXT_PUBLIC_BLUEBUBBLES_PASSWORD=your-password
   ```

4. **Run the development server:**
   ```bash
   flutter run -d web-server --web-port 3000
   ```

   Or use the helper script:
   ```bash
   ./scripts/run_web.sh
   ```

5. **Open your browser:**
   Navigate to `http://localhost:3000`

### Development Tips

- **Hot reload:** Press `r` in the terminal to hot reload
- **Restart:** Press `R` to full restart
- **Quit:** Press `q` to quit

---

## Deployment Options

### GitHub Pages

GitHub Pages offers free hosting for static sites.

#### Setup Steps:

1. **Enable GitHub Pages:**
   - Go to your repository settings
   - Navigate to Pages section
   - Select "GitHub Actions" as source

2. **Configure Secrets:**
   - Go to Settings → Secrets and variables → Actions
   - Add secrets:
     - `BLUEBUBBLES_HOST`: Your server URL
     - `BLUEBUBBLES_PASSWORD`: Your auth key

3. **Push to main branch:**
   ```bash
   git push origin main
   ```

4. **Access your app:**
   The workflow will deploy to: `https://yourusername.github.io/repository-name/`

#### Manual Deployment:

```bash
# Build for GitHub Pages
flutter build web --base-href /repository-name/ --release

# Deploy using gh-pages
npm install -g gh-pages
gh-pages -d build/web
```

---

### Vercel

Vercel offers excellent performance and automatic deployments.

#### Setup Steps:

1. **Install Vercel CLI:**
   ```bash
   npm i -g vercel
   ```

2. **Login to Vercel:**
   ```bash
   vercel login
   ```

3. **Link your project:**
   ```bash
   vercel link
   ```

4. **Add environment variables:**
   ```bash
   vercel env add NEXT_PUBLIC_BLUEBUBBLES_HOST production
   vercel env add NEXT_PUBLIC_BLUEBUBBLES_PASSWORD production
   ```

5. **Deploy:**
   ```bash
   vercel --prod
   ```

#### Automatic Deployments via GitHub:

1. Import your repository on [vercel.com](https://vercel.com)
2. Configure environment variables in project settings
3. Every push to `main` will auto-deploy

#### GitHub Actions Setup:

Configure these secrets in your repository:
- `VERCEL_TOKEN`: Get from Vercel → Settings → Tokens
- `VERCEL_ORG_ID`: Found in `.vercel/project.json`
- `VERCEL_PROJECT_ID`: Found in `.vercel/project.json`

---

### Netlify

Netlify provides simple deployment with excellent CDN performance.

#### Setup Steps:

1. **Install Netlify CLI:**
   ```bash
   npm install -g netlify-cli
   ```

2. **Login to Netlify:**
   ```bash
   netlify login
   ```

3. **Initialize your site:**
   ```bash
   netlify init
   ```

4. **Add environment variables:**
   - Go to Site settings → Environment variables
   - Add:
     - `NEXT_PUBLIC_BLUEBUBBLES_HOST`
     - `NEXT_PUBLIC_BLUEBUBBLES_PASSWORD`

5. **Deploy:**
   ```bash
   netlify deploy --prod
   ```

#### Manual Build and Deploy:

```bash
flutter build web --release
netlify deploy --dir=build/web --prod
```

---

### Firebase Hosting

Firebase offers global CDN hosting with excellent performance.

#### Setup Steps:

1. **Install Firebase CLI:**
   ```bash
   npm install -g firebase-tools
   ```

2. **Login to Firebase:**
   ```bash
   firebase login
   ```

3. **Initialize Firebase:**
   ```bash
   firebase init hosting
   ```
   - Select your Firebase project
   - Set public directory to: `build/web`
   - Configure as single-page app: Yes

4. **Update `.firebaserc`:**
   ```json
   {
     "projects": {
       "default": "your-firebase-project-id"
     }
   }
   ```

5. **Build and deploy:**
   ```bash
   flutter build web --release
   firebase deploy --only hosting
   ```

---

### Docker

Deploy as a containerized application using Docker.

#### Quick Start:

1. **Build the Docker image:**
   ```bash
   docker build \
     --build-arg BLUEBUBBLES_HOST=https://your-server.com \
     --build-arg BLUEBUBBLES_PASSWORD=your-password \
     -t bluebubbles-web \
     -f Dockerfile.web .
   ```

2. **Run the container:**
   ```bash
   docker run -d \
     -p 8080:80 \
     --name bluebubbles-web \
     bluebubbles-web
   ```

3. **Access your app:**
   Navigate to `http://localhost:8080`

#### Using Docker Compose:

1. **Create `.env` file:**
   ```bash
   NEXT_PUBLIC_BLUEBUBBLES_HOST=https://your-server.com
   NEXT_PUBLIC_BLUEBUBBLES_PASSWORD=your-password
   ```

2. **Start the service:**
   ```bash
   docker-compose up -d
   ```

3. **View logs:**
   ```bash
   docker-compose logs -f
   ```

4. **Stop the service:**
   ```bash
   docker-compose down
   ```

---

## Storage Configuration

The web app uses **IndexedDB** for browser-based storage since ObjectBox is not available on web.

### Web Storage Service

The app includes a comprehensive `WebStorageService` located at:
`lib/services/backend/web_storage_service.dart`

#### Features:

- **Messages:** Cached locally for offline access
- **Chats:** Persistent chat list
- **Settings:** User preferences
- **Cache:** Temporary data with TTL support
- **Attachments:** Metadata storage

#### Usage Example:

```dart
import 'package:bluebubbles/services/backend/web_storage_service.dart';

// Initialize (happens automatically on app start)
await webStorage.init();

// Store data
await webStorage.set('key', 'value');

// Retrieve data
final value = await webStorage.get<String>('key');

// Cache with expiration (1 hour)
await webStorage.cache('temp-key', data, ttlMs: 3600000);

// Get cached data
final cached = await webStorage.getCached('temp-key');
```

#### Storage Limits:

- Chrome: ~10GB (10% of free disk space)
- Firefox: ~10GB
- Safari: ~1GB (may prompt user)

#### Clear Storage:

Users can clear all local data from Settings → Advanced → Clear Local Data

---

## CI/CD Pipeline

### GitHub Actions Workflows

The repository includes three automated workflows:

#### 1. Build and Test (`build-web.yml`)

**Triggers:** Push to main, development, or claude/* branches

**Actions:**
- Builds the Flutter web app
- Runs code analysis
- Uploads build artifacts
- Generates build report

#### 2. Deploy to GitHub Pages (`deploy-pages.yml`)

**Triggers:** Push to main branch

**Actions:**
- Builds optimized production bundle
- Deploys to GitHub Pages
- Updates deployment URL

#### 3. Deploy to Vercel (`deploy-vercel.yml`)

**Triggers:** Push to main, PRs

**Actions:**
- Builds the app
- Deploys to Vercel
- Creates preview deployments for PRs

### Required Secrets

Configure these in GitHub Settings → Secrets:

| Secret | Description | Required For |
|--------|-------------|--------------|
| `BLUEBUBBLES_HOST` | Your server URL | All deployments |
| `BLUEBUBBLES_PASSWORD` | Your auth key | All deployments |
| `VERCEL_TOKEN` | Vercel auth token | Vercel deployment |
| `VERCEL_ORG_ID` | Vercel organization ID | Vercel deployment |
| `VERCEL_PROJECT_ID` | Vercel project ID | Vercel deployment |

---

## Troubleshooting

### Build Issues

#### Issue: "Environment variables not set"

**Solution:** Ensure you've set both required environment variables:
```bash
export NEXT_PUBLIC_BLUEBUBBLES_HOST=https://your-server.com
export NEXT_PUBLIC_BLUEBUBBLES_PASSWORD=your-password
```

#### Issue: "Server version too low"

**Solution:** Update your BlueBubbles server to version 42 or higher. The web app requires server v42+.

#### Issue: "Build fails with memory error"

**Solution:** Increase Node.js memory:
```bash
export NODE_OPTIONS="--max-old-space-size=4096"
flutter build web
```

### Deployment Issues

#### Issue: "404 on refresh"

**Solution:** Ensure your hosting platform is configured for SPA routing:
- **Vercel:** Already configured in `vercel.json`
- **Netlify:** Already configured in `netlify.toml`
- **Nginx:** Use the provided `nginx.conf`

#### Issue: "White screen on load"

**Solution:**
1. Check browser console for errors
2. Verify environment variables are set correctly
3. Ensure base-href matches your deployment path
4. Check that assets are loading correctly

### Storage Issues

#### Issue: "Data not persisting"

**Solution:**
1. Check that browser allows IndexedDB
2. Verify sufficient storage quota
3. Check browser privacy settings (disable "Block all cookies" if enabled)

#### Issue: "Storage quota exceeded"

**Solution:**
```dart
// Clear old data
await webStorage.clearExpiredCache();

// Or clear all data
await webStorage.clearAllData();
```

### Connection Issues

#### Issue: "Cannot connect to server"

**Solution:**
1. Verify server URL is correct and accessible
2. Check that server is running and port is open
3. Ensure SSL certificate is valid (for HTTPS)
4. Check CORS settings on your server

---

## Performance Optimization

### 1. Enable Caching

The deployment configurations include aggressive caching for static assets:
- JavaScript/CSS: 1 year
- Assets: 1 year
- index.html: No cache

### 2. Enable Compression

All hosting platforms support Gzip/Brotli compression automatically.

### 3. Use CDN

For better performance:
- **Vercel:** Automatically uses edge network
- **Netlify:** Automatically uses global CDN
- **Firebase:** Automatically uses global CDN
- **GitHub Pages:** Uses GitHub's CDN

### 4. Web Renderers

Choose the best renderer for your use case:

```bash
# Auto (default - chooses best based on device)
flutter build web --web-renderer auto

# HTML (better compatibility, larger size)
flutter build web --web-renderer html

# CanvasKit (better performance, smaller size)
flutter build web --web-renderer canvaskit
```

---

## Security Best Practices

1. **Never commit credentials:**
   - Always use `.env` files (gitignored)
   - Use secrets management in CI/CD

2. **Use HTTPS:**
   - All deployments should use HTTPS
   - Server must support secure connections

3. **Enable security headers:**
   - Already configured in deployment configs
   - X-Frame-Options, CSP, etc.

4. **Regular updates:**
   ```bash
   flutter upgrade
   flutter pub upgrade
   ```

---

## Support

For issues or questions:

- **Documentation:** [BlueBubbles Docs](https://docs.bluebubbles.app)
- **Discord:** [Join our Discord](https://discord.gg/4F7nbf3)
- **GitHub Issues:** [Report a bug](https://github.com/BlueBubblesApp/bluebubbles-app/issues)

---

**Last Updated:** October 2025
**Version:** 1.0.0
