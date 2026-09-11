# Security Policy

## Reporting

Do not include screenshots, OCR output, clipboard contents, credentials, or other sensitive information in a security report.

Report security issues privately to the project maintainer.

## Security model

TextGrab is a local macOS menu-bar application. Its core workflow is:

```text
User-selected screen region -> ScreenCaptureKit -> Apple Vision OCR -> NSPasteboard
```

Screen Recording permission is required to capture pixels. Accessibility permission is optional and is used only for enhanced system keyboard integration. These permissions are controlled by macOS TCC and are associated with the installed application identity and location. Users should install TextGrab in `/Applications`, grant permissions to that copy, and relaunch after granting Screen Recording.

Local builds use an ad-hoc Hardened Runtime signature with the screen-capture entitlement embedded. This supports local permission testing but is not a distributable security identity and will not pass Gatekeeper. Production releases must use a Developer ID Application certificate and Apple notarization.

## Design principles

TextGrab should:

- keep OCR local
- avoid logging screen contents
- avoid logging clipboard contents
- minimize retained data
- avoid unnecessary network access

## Data handling

- Screenshots exist in memory only for the capture and OCR operation.
- OCR output is copied to the local pasteboard and is not uploaded.
- Clipboard history is optional, bounded, and held in memory only; disabling it clears the current history.
- Apple Intelligence correction, summarization, and compaction are optional and use the on-device macOS model when available.
- TextGrab has no telemetry, analytics, account service, or cloud OCR dependency.

## Logging rules

Logs may contain state names, counts, timings, and generic platform errors. They must never contain screenshots, OCR text, clipboard payloads, passwords, API keys, document contents, or Apple Intelligence prompts/responses.

## Release verification

Before distribution, verify:

1. Release signing uses `Developer ID Application` and Hardened Runtime.
2. The signed app contains only the required entitlements.
3. `codesign --verify --deep --strict` succeeds.
4. The DMG is notarized, stapled, and passes `spctl` on a clean Mac.
5. Screen Recording and Accessibility grants work after a clean install, revoke/regrant, and relaunch.
