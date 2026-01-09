# CloudflareStatusBar

A native macOS status bar app for monitoring your Cloudflare resources using Wrangler authentication.

## Features

- **Workers** - View all deployed Workers with usage model and compatibility info
- **Pages** - Monitor Pages projects with deployment status and history
- **KV Namespaces** - List all KV namespaces
- **R2 Buckets** - View R2 storage buckets with location info
- **D1 Databases** - Monitor databases with table counts and size
- **Queues** - Track message queues with producer/consumer counts

### Additional Features

- Auto-refresh every 5 minutes
- Deployment success/failure notifications
- Quick links to Cloudflare Dashboard
- Uses existing Wrangler OAuth credentials (no separate login required)

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/install-and-update/) installed and authenticated

## Setup

### 1. Authenticate with Wrangler

Before running the app, ensure you're logged in to Cloudflare via Wrangler:

```bash
npm install -g wrangler
wrangler login
```

This will open a browser window for OAuth authentication. The app reads credentials from `~/.wrangler/config/default.toml`.

### 2. Clone the Repository

```bash
git clone https://github.com/sushaantu/CloudflareStatusBar.git
cd CloudflareStatusBar
```

### 3. Open in Xcode

```bash
open CloudflareStatusBar.xcodeproj
```

### 4. Build and Run

1. Select your Mac as the build target
2. Press `Cmd + R` or click the Play button
3. The app will appear in your menu bar with a cloud icon

## Usage

- **Click** the cloud icon in your menu bar to open the popup
- **Tabs**: Switch between Overview, Workers, Pages, and Storage views
- **Refresh**: Click the refresh button or wait for auto-refresh (every 5 minutes)
- **Dashboard**: Click the globe icon to open Cloudflare Dashboard in browser
- **Quit**: Click the power icon to quit the app

## Project Structure

```
CloudflareStatusBar/
├── App/
│   ├── CloudflareStatusBarApp.swift   # App entry point
│   ├── AppDelegate.swift              # Menu bar setup
│   └── CloudflareViewModel.swift      # State management
├── Services/
│   ├── WranglerAuthService.swift      # Credential reading
│   ├── CloudflareAPIClient.swift      # API client
│   └── NotificationService.swift      # macOS notifications
├── Models/
│   └── Models.swift                   # Data models
├── Views/
│   ├── MenuBarView.swift              # Main UI
│   ├── WorkersView.swift
│   ├── PagesView.swift
│   └── StorageView.swift
└── Resources/
    ├── Assets.xcassets/
    ├── Info.plist
    └── CloudflareStatusBar.entitlements
```

## Configuration

The app looks for Wrangler credentials in these locations (in order):

1. `~/Library/Preferences/.wrangler/config/default.toml` (macOS default)
2. `~/.wrangler/config/default.toml`
3. `~/.config/.wrangler/config/default.toml`
4. `~/.config/wrangler/config/default.toml`
5. Environment variable: `CLOUDFLARE_API_TOKEN`

## Troubleshooting

### "Not Authenticated" message

Run `wrangler login` in your terminal and try again.

### API errors

Ensure your Cloudflare account has access to the resources you're trying to view. Some features (R2, D1, Queues) may require specific account permissions.

### App doesn't appear in menu bar

Check that `LSUIElement` is set to `YES` in Info.plist (this hides the dock icon and shows only in menu bar).

## License

MIT
