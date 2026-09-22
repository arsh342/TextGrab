# TextGrab

Native macOS utility for extracting text from anywhere on the screen.

**Tagline:** Instant screen-to-text for macOS.

[![GitHub Release](https://img.shields.io/github/v/release/arsh342/TextGrab?label=Latest%20Release&style=for-the-badge&logo=apple&color=success)](https://github.com/arsh342/TextGrab/releases/latest)
[![License](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey?style=for-the-badge&logo=apple)](https://www.apple.com/macos/)

[![Download Latest DMG](https://img.shields.io/badge/Download-DMG-blue?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/arsh342/TextGrab/releases/latest)

---

https://github.com/user-attachments/assets/a2b095a7-f1a2-421f-b2fb-fd32ead2211a

## Core Workflow

1. Press the global TextGrab shortcut (default: `⌘⇧2`)
2. Select a region of the screen
3. TextGrab captures that region
4. Apple Vision performs local OCR
5. Recognized text is copied to the clipboard

```text
Shortcut → Select → Capture → OCR → Clipboard
```

## Features

### Capture & OCR
- **Global shortcut** — Configurable system-wide hotkey for instant capture
- **Saved area capture** — Secondary shortcut (`⌘⌥2` by default) to re-capture the last selected region without re-selecting
- **Multi-monitor support** — Works across all connected displays
- **Three extraction modes:**
  - **Text** — General purpose text extraction with language correction (Fast or Accurate, Fast by default)
  - **Code** — Optimized for code snippets: rebuilds indentation from layout, joins OCR-split punctuation, always uses Accurate recognition
  - **Table** — Extracts tabular data as GitHub-flavored markdown: space-aligned and pipe-delimited columns, wrapped-cell and hyphen rejoining, always uses Accurate recognition
- **Smart recognition policy** — Text mode is user-configurable (Fast/Accurate); Code and Table always run Accurate automatically since Fast misses isolated digits and small cells
- **OCR robustness** — Auto-retry chain for tricky captures: Accurate retry and image inversion for white text on dark backgrounds (dark-mode IDEs, dark theme apps)
- **Pipeline timeouts** — Capture, OCR, and AI steps are race-guarded so a hung system call can never leave the app stuck
- **Multi-language OCR** — Add custom languages (e.g., `fr-FR`, `ja-JP`, `zh-Hans`)

### Clipboard & History
- **Clipboard history** — Optional history with configurable max items (10–200) that **survives app relaunches** (stored locally, bounded, wiped when disabled)
- **One-click recopy** — Click any history item to copy it again
- **Rich-text tables** — Markdown tables are also placed on the clipboard as HTML so pasting into Notes/Pages/Word preserves the table

### Text-to-Speech
- **Speak captured text** — Built-in TTS with play/stop controls in the menu bar

### Apple Intelligence (macOS 26+)
- **On-device correction** — Uses Apple Intelligence to fix OCR errors before copying (runs entirely on-device, no cloud)
- **Summarize** — Generate a concise summary of captured text with one click
- **Compact** — Create a condensed version preserving key information
- **Privacy-first** — All processing happens locally; no data leaves your Mac

### Menu Bar Interface
- Polished popover with material cards, a prominent Capture button, and hover highlights
- Custom extraction mode selector (Text/Code/Table) with live switching
- Real-time processing status and inline error reporting
- Selectable last-capture preview, window nudged away from the screen edge

### Auto-Updates
- **GitHub Releases based** — Checks the latest release once a day on launch (opt-out toggle)
- **Check Now** — Manual check in Settings with live status and semantic version comparison
- **Download & install** — Downloads the DMG and opens it for drag-to-install; no signing infrastructure required
- **Update notifications** — Notifies when a newer version is available

### Localization
- **5 languages** — English (source), Hindi (हिन्दी), French (Français), German (Deutsch), Spanish (Español)
- The UI follows the system language automatically via String Catalogs

### Privacy & Permissions
- **100% local processing** — No data sent to external servers
- **Permission management** — Built-in UI for Screen Recording
- **Relaunch helper** — One-click app restart after granting permissions (spawns a fresh instance)

### Settings
- **General** — Shortcuts, notifications, history
- **OCR** — Mode, recognition level, language correction, Apple Intelligence, languages
- **Permissions** — Grant/check Screen Recording
- **Advanced** — Updates, version info, user guide, links to source/privacy

## Goals

- Native Swift/macOS implementation
- Fast screen-to-text workflow
- Local OCR; no cloud service required for the core path
- Menu-bar-first UX
- Multi-monitor support
- Minimal external dependencies
- Strong privacy defaults

## Tech Stack

- **Language:** Swift 5.9+
- **UI:** SwiftUI + AppKit
- **Frameworks:** Vision, ScreenCaptureKit, CoreGraphics, CoreImage, Foundation, Carbon (for global shortcuts), UserNotifications, AVFoundation, ServiceManagement, FoundationModels (Apple Intelligence, macOS 26+)
- **Architecture:** MVVM with `@ObservableObject`/`@StateObject`
- **Testing:** XCTest (unit), XCUITest (UI)
- **External dependencies:** None

## Building

```bash
# Debug build
xcodebuild -project TextGrab.xcodeproj -scheme TextGrab -configuration Debug build

# Release archive + DMG (outputs build/TextGrab-1.2.0.dmg)
./scripts/build-release.sh

# Run tests (12 unit + 2 UI)
xcodebuild -project TextGrab.xcodeproj -scheme TextGrab -configuration Debug test
```

### Known Issue: Screen Recording Permission After Updates

Locally-built DMGs use ad-hoc signing. Each build gets a unique signature, so macOS treats updates as new apps and requires re-granting Screen Recording permission.

**Workaround:** In System Settings → Privacy & Security → Screen Recording, toggle TextGrab **off then on** after updating.

## License

MIT — see [LICENSE](LICENSE)

## Security

See [SECURITY.md](SECURITY.md) for vulnerability reporting.