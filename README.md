# BlueBubbles Web Client

A **web-only** Flutter application for accessing iMessage on any device through your browser. This project is a customized standalone version built from the BlueBubbles ecosystem, focused exclusively on web deployment.

> **Note:** This requires a Mac running the [BlueBubbles Server](https://github.com/BlueBubblesApp/BlueBubbles-Server) to function. A macOS VM can work as well.

## ✨ Features

- 💬 Send & receive texts, media, and location
- 👍 View tapbacks, reactions, stickers, and read/delivered timestamps
- 🆕 Create new chats
- 💭 View threaded replies (requires macOS 11+)
- 🔕 Mute or archive conversations
- 🎨 Customizable theming engine
- 🌐 Access iMessage from any browser
- 📱 Responsive design for mobile and desktop browsers

### Private API Features

When enabled on your BlueBubbles server:
- ⌨️ See and send typing indicators
- 👍 Send tapbacks and reactions
- 📬 Read receipts
- 🎭 Messages with effects
- 💬 Threaded replies (macOS 11+)
- ✅ Mark chats read on server
- ✏️ Rename group chats
- 👥 Add/remove group chat participants

**Private API features require additional server configuration.** [Learn more](https://docs.bluebubbles.app/helper-bundle/installation)

## 🚀 Quick Start

### Using GitHub Codespaces (Recommended)

1. Click the **Code** button → **Codespaces** → **Create codespace on main**
2. Wait for the container to build (includes Flutter SDK)
3. Set your server connection:
   ```bash
   export NEXT_PUBLIC_BLUEBUBBLES_HOST="https://your-server.com"
   export NEXT_PUBLIC_BLUEBUBBLES_PASSWORD="your-password"
   ```
4. Run the development server:
   ```bash
   scripts/run_web.sh
   ```
5. Open the forwarded port in your browser

### Local Development

**Prerequisites:**
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
- [Git](https://git-scm.com/)

**Setup:**

```bash
# Clone the repository
git clone https://github.com/andyhartzler/my-bluebubbles-web.git
cd my-bluebubbles-web

# Install dependencies
flutter pub get

# Run development server
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 3000
```

**Build for production:**

```bash
flutter build web --release
```

The built files will be in `build/web/` ready for deployment.

## 🔧 Configuration

### Environment Variables

Set these before building/running:

```bash
export NEXT_PUBLIC_BLUEBUBBLES_HOST="https://your-bluebubbles-server.com"
export NEXT_PUBLIC_BLUEBUBBLES_PASSWORD="your-server-password"

# CRM (Supabase) configuration
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_ANON_KEY="your-public-anon-key"
# Optional: if your deployment already uses NEXT_PUBLIC_* variables
# they will be picked up automatically.
export NEXT_PUBLIC_SUPABASE_URL="https://your-project.supabase.co"
export NEXT_PUBLIC_SUPABASE_ANON_KEY="your-public-anon-key"
# Never expose the service role key in a public build.
export SUPABASE_SERVICE_ROLE_KEY="your-private-service-role-key"
```

> 💡 Copy `.env.example` to `.env` for local development and fill in your
> server credentials. Keep `.env` out of version control.

### Server Setup

You need a Mac (or macOS VM) running the BlueBubbles Server:
1. Download from [BlueBubbles Server Releases](https://github.com/BlueBubblesApp/BlueBubbles-Server/releases)
2. Follow the [installation guide](https://bluebubbles.app/install/)
3. Configure your server URL and password
4. Ensure the server is accessible from your deployment location

## 📦 Deployment Options

### Static Hosting

Deploy the `build/web/` directory to any static hosting service:

- **Netlify**: Drag and drop the `build/web` folder
- **Vercel**: Use the `vercel` CLI or GitHub integration
- **GitHub Pages**: Push to `gh-pages` branch
- **Firebase Hosting**: Use `firebase deploy`
- **AWS S3 + CloudFront**: Upload and configure distribution

### Docker

```dockerfile
FROM nginx:alpine
COPY build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

Build and run:
```bash
docker build -t bluebubbles-web .
docker run -p 8080:80 bluebubbles-web
```

## 🛠️ Development

### Project Structure

```
my-bluebubbles-web/
├── lib/
│   ├── database/        # Database models and storage
│   │   ├── html/        # Web-specific implementations
│   │   └── io/          # Native implementations (unused in web)
│   ├── services/        # Business logic and services
│   ├── app/            # UI components and screens
│   └── main.dart       # Entry point
├── web/                # Web-specific files (index.html, etc.)
├── assets/             # Images, fonts, and static resources
├── scripts/            # Helper scripts (run_web.sh)
└── .devcontainer/      # GitHub Codespaces configuration
```

### Available Scripts

- `scripts/run_web.sh` - Run development server with proper configuration
- `flutter analyze` - Run static analysis
- `flutter test` - Run unit tests

### VS Code / Codespaces

The project includes a `.devcontainer` configuration with:
- ✅ Flutter SDK pre-installed
- ✅ Dart & Flutter extensions
- ✅ Git, Node.js, and development tools
- ✅ Port forwarding configured (3000, 8080, 5000)

## 🐛 Troubleshooting

### Build Fails with ObjectBox Errors

This has been fixed! The project now uses web-compatible stubs for database operations. If you still see errors:

```bash
flutter clean
flutter pub get
flutter build web
```

### Can't Connect to Server

1. Verify your server is running and accessible
2. Check firewall/network settings
3. Ensure `NEXT_PUBLIC_BLUEBUBBLES_HOST` is set correctly
4. Try accessing the server URL directly in a browser

### Port Already in Use

Change the port:
```bash
export FLUTTER_WEB_PORT=3001
scripts/run_web.sh
```

## 📝 Credits

This project is built upon the [BlueBubbles](https://bluebubbles.app) ecosystem:
- Original app: [BlueBubblesApp/bluebubbles-app](https://github.com/BlueBubblesApp/bluebubbles-app)
- Server: [BlueBubblesApp/BlueBubbles-Server](https://github.com/BlueBubblesApp/BlueBubbles-Server)

**This is a standalone customized web-only version** and is not officially maintained by the BlueBubbles team.

## 📜 License

See [LICENSE](LICENSE) file for details.

## 🔗 Links

- Original BlueBubbles: https://bluebubbles.app
- BlueBubbles Discord: https://discord.gg/4F7nbf3
- BlueBubbles Docs: https://docs.bluebubbles.app

---

**Note:** This is a web-only client. For native Android, iOS, Windows, Linux, or macOS apps, see the [official BlueBubbles repository](https://github.com/BlueBubblesApp/bluebubbles-app).
