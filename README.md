# TextGrab

Native macOS utility for extracting text from anywhere on the screen.

**Tagline:** Instant screen-to-text for macOS.

## Core workflow

1. Press the global TextGrab shortcut.
2. Select a region of the screen.
3. TextGrab captures that region.
4. Apple Vision performs local OCR.
5. Recognized text is copied to the clipboard.

```text
Shortcut → Select → Capture → OCR → Clipboard
```

## Goals

- Native Swift/macOS implementation
- Fast screen-to-text workflow
- Local OCR; no cloud service required for the core path
- Menu-bar-first UX
- Multi-monitor support
- Minimal external dependencies
- Strong privacy defaults

## MVP

- Menu bar application
- Global shortcut
- Region selection overlay
- Single-frame screen capture
- Vision OCR
- Text ordering/cleanup
- Clipboard output
- Escape to cancel
- Screen-capture permission handling
- Multi-monitor support

## Available

- Configurable shortcut
- OCR language settings
- Fast/accurate recognition modes
- Launch at login
- Clipboard history
- Code OCR
- Table extraction
- Text-to-speech
- Optional on-device Apple Intelligence correction, summarization, and compaction

See [`docs/ROADMAP.md`](docs/ROADMAP.md) for implementation status and [`docs/RELEASE.md`](docs/RELEASE.md) for archive, signing, and notarization steps.

## Tech stack

- Swift
- SwiftUI
- AppKit
- Vision
- ScreenCaptureKit
- CoreGraphics
- Foundation

## Repository layout

```text
TextGrab/
├── TextGrab/
│   ├── App/
│   ├── Capture/
│   ├── Selection/
│   ├── OCR/
│   ├── Clipboard/
│   ├── Shortcut/
│   ├── MenuBar/
│   ├── Settings/
│   ├── Permissions/
│   └── Utilities/
├── docs/
├── README.md
├── LICENSE
└── SECURITY.md
```

## Development status

Current target: **v1.0 product build**

The complete local workflow is implemented, including configurable extraction modes, optional bounded in-memory history, speech output, notifications, launch at login, optional on-device Apple Intelligence transformations, and permission guidance. The critical path remains:

```text
⌘⇧2
  ↓
Selection overlay
  ↓
Capture selected region
  ↓
Vision OCR
  ↓
Copy text
```
