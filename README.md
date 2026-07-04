<img width="1780" height="1112" alt="image" src="https://github.com/user-attachments/assets/8cc6395a-2e52-4f08-8a45-e3729905825e" />

# Fact - Apple Connect tool

Fact is a native macOS app for preparing App Store Connect release work. The
old Node.js metadata CLI has been retired; the active product now lives in
`macos/AppleConnectApp`.

The current app is built for release-prep workflows that need a safe local
workspace before anything is written back to App Store Connect. It includes a
Demo workspace with mock apps and Demo AI fixtures, so the product can be
reviewed without real App Store Connect credentials or model-provider keys.

## Current Scope

- Localized App Store metadata editing and validation.
- Screenshot and preview-video readiness by locale and device family.
- Pricing, availability, app privacy, submission setup, ratings, and compliance
  readiness checks.
- Review Prep with blocker/warning summaries, checklist items, proposed fixes,
  reports, and handoff export.
- Live App Store Connect API skeleton for app/version/localization pull and
  localized metadata create/update paths.
- AI-assisted copy actions and cross-locale translation through an
  OpenAI-compatible provider.
- Keychain-backed storage for App Store Connect private keys and model-provider
  API keys.
- Local draft autosave and restore for metadata work in progress.

See `macos/AppleConnectApp/PROJECT_STATUS.md` for the detailed implementation
status, deliberate gaps, and next steps.

## Repository Layout

```text
macos/AppleConnectApp/
  Sources/AppleConnectApp/App/        App entry, state model, constants, and window setup
  Sources/AppleConnectApp/Models/     Release-prep domain models
  Sources/AppleConnectApp/Services/   App Store Connect, Keychain, draft, validation, and AI services
  Sources/AppleConnectApp/Views/      SwiftUI workspaces and shared UI
  Sources/AppleConnectApp/Resources/  App icon and localized strings
  Tests/AppleConnectAppTests/         Swift tests for validation and release-prep logic
```

The Swift package remains available for command-line build and test loops, and
`Fact.xcodeproj` is included for Xcode development.

## Build And Test

```bash
cd macos/AppleConnectApp
swift test
xcodebuild -project Fact.xcodeproj -scheme Fact -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Open the app project in Xcode:

```bash
cd macos/AppleConnectApp
scripts/open_xcode.sh
```

Create a local app bundle:

```bash
cd macos/AppleConnectApp
scripts/package_app.sh
open Build/Fact.app
```

Create release artifacts:

```bash
cd macos/AppleConnectApp
scripts/package_release.sh
scripts/package_dmg.sh
```

Release signing and notarization are controlled by environment variables:
`DEVELOPER_ID_APPLICATION`, `APPLE_ID`, `APPLE_TEAM_ID`, and
`APPLE_APP_SPECIFIC_PASSWORD`.

## Credentials

No real credentials are required for Demo mode. For Live API mode, users provide
an App Store Connect key ID, issuer ID, and private key. Private key content and
LLM provider API keys are stored in Keychain; non-secret provider settings are
stored separately in user defaults.

The repository ignores common local credential files such as `.env.*`,
`AuthKey_*.p8`, certificate files, and provisioning profiles.
