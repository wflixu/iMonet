[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-ED523F.svg?style=flat)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-orange)](https://developer.apple.com/xcode/swiftui/)
[![macOS 15](https://img.shields.io/badge/macOS15-Compatible-green)](https://www.apple.com/macos/)

<div align="start">
   <img src="Sources/Monet/Assets.xcassets/Monet.imageset/picture@2x.png" width="256" height="256" alt="Monet Logo"/>
</div>

# Monet

An elegant image viewer for macOS, powered by SwiftUI.

## Features

### Image Browsing
- **Folder Indexing**: Automatically scans and indexes all images in the same folder
- **Persistent Permissions**: Uses security-scoped bookmarks so you only grant folder access once
- **Supported Formats**: PNG, JPEG, GIF, WebP
- **Sidebar**: Thumbnail strip for quick navigation, auto-hides with single image

### Keyboard & Mouse
- **Arrow Keys**: ←/→/↑/↓ to navigate images
- **Cmd + Scroll**: Zoom in/out centered at mouse position
- **Mouse Drag**: Pan around zoomed images
- **Click to Reveal**: Click image area to show controls, auto-hide after 5s

### Floating UI
- **Title & Toolbar**: Appear on click, auto-hide after 5 seconds; hover toolbar to keep visible
- **Image Info Panel** (right): Pixel size, file size, format, modification date
- **Dark / Light Mode**: Full adaptive theme support
- **Menu Bar Extra**: Quick access from the menu bar

## Requirements

- macOS 15.0 or later
- Swift 6.0+

## Build & Run

```bash
git clone https://github.com/yourusername/Monet.git
cd Monet
swift run
```

## Project Structure

```
Monet/
├── Sources/Monet/
│   ├── MonetApp.swift                  # App entry point, scenes, AppDelegate
│   ├── AppState.swift                  # Global app state
│   ├── ContentView.swift               # Main layout, chrome auto-hide logic
│   ├── MenuBarView.swift               # Menu bar extra view
│   ├── NavigationIdentifier.swift      # Settings navigation
│   ├── Views/
│   │   ├── ImagePreviewView.swift      # Image display with keyboard events
│   │   ├── ImageThumbnailView.swift    # Single thumbnail
│   │   ├── ThumbnailSidebar.swift      # Left thumbnail strip
│   │   ├── ImageInfoPanel.swift        # Right info panel (pixels, size, format)
│   │   ├── ToolBarView.swift           # Bottom floating toolbar
│   │   └── ZoomableImageView.swift     # Zoom & pan image view (AppKit)
│   ├── Settings/
│   │   ├── GeneralSettingsPane.swift
│   │   ├── AboutSettingsPane.swift
│   │   ├── SettingsView.swift
│   │   └── SettingsWindow.swift
│   ├── Permission/
│   │   └── PermissionsManager.swift    # File system permissions & bookmarks
│   └── Shared/
│       ├── AppLogger.swift             # @AppLog property wrapper
│       ├── Constants.swift             # App constants
│       └── Util.swift                  # ObjectAssociation
├── Tests/
└── Package.swift
```

## Dependencies

- **SDWebImageSwiftUI** — image loading
- **LaunchAtLogin-Modern** — launch at login
- **SwiftUITooltip** — tooltips

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| ← / → | Previous / Next image |
| ↑ / ↓ | Previous / Next image |
| Cmd + Scroll | Zoom in/out at mouse position |
| Mouse Drag | Pan zoomed image |

## License

GNU General Public License v3.0 - see LICENSE file for details.
