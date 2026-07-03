# Fact macOS App

Native macOS shell for Fact.

This app is intentionally broader than localized copy. The current workspace
model covers App Store release preparation across metadata, localized media,
pricing, privacy, submission setup, ratings, compliance, and review handoff
workflows.

The repository no longer ships the earlier Node.js metadata CLI. This SwiftUI app
is the active product surface, with Demo mode for no-credential review and Live
mode for App Store Connect API-backed workflows.

## Current Scope

- Sign in with Apple account shell.
- App Store Connect API key binding shell.
- One-click Demo workspace with clean and review-workflow mock apps for no-key
  review.
- Demo entry automatically opens the review-workflow sample in Review Prep.
- Unified sidebar workspace for connection, settings, model provider, apps,
  versions, and localized copy.
- Review Prep workspace for preflight readiness, checklist, validation, and
  draft-change review.
- Review Prep next-action summary with blocker, warning, proposed-fix, and
  draft-action counts for fast scanning.
- Review Prep proposed-fix queue for deterministic safe edits such as HTTPS URL
  upgrades and keyword normalization before applying them to the draft.
- App overview release-readiness summary with a direct path into copy editing.
- App and version browser with mock data.
- Localized metadata editor.
- Localized screenshot and preview-video readiness by locale and device family.
- Pricing and availability readiness.
- App privacy readiness.
- Submission setup checks for build, review contact, demo account, release
  options, export compliance, and content rights.
- Ratings and compliance checks for categories, age questionnaire, Made for
  Kids, regional requirements, and third-party content rights.
- Add-locale flow for creating new localizations.
- Locale search and status filters for larger localization sets.
- Keyword normalization for pasted keyword lists with mixed separators or
  duplicates.
- Bulk fill actions for missing localized copy and URL fields.
- One-click HTTP-to-HTTPS cleanup for customer-facing App Store URL fields.
- Local draft autosave and restore for edited metadata.
- Draft-safe version switching and refresh behavior for local metadata edits.
- Validation with remediation guidance plus publish-plan preview with
  before/after field summaries.
- Review checklist for required copy, URL hygiene, review-sensitive language,
  release notes, and draft state.
- Copyable Markdown summaries for metadata change review.
- Copyable/exportable App Store review-prep reports that combine readiness,
  checklist, proposed fixes, validation, and draft-change sections.
- Review handoff package export with `metadata.json`, `review-report.md`,
  `change-summary.md`, and `manifest.json`.
- Copyable/file JSON export and guarded clipboard/file JSON import for the current
  metadata document.
- Release readiness panel for blocking issues, warnings, unsaved drafts, and
  demo/live save expectations.
- Clickable validation rows that focus the affected locale.
- Local App Review-style metadata guidance for common copy and URL risks.
- AI-assisted metadata actions for description, keywords, promotional text,
  What's New, and review-readiness polish.
- AI-assisted cross-locale translation for selected metadata localizations.
- Demo AI fixtures for no-key walkthroughs when the app is in Demo mode and no
  model provider is configured.
- Model provider settings with an Alibaba Cloud Model Studio preset and
  Keychain-backed API key persistence.
- Explicit forget/reset actions for stored App Store Connect and model-provider
  credentials.
- Native light, dark, and system theme switching.

## Data And Secrets

- Demo mode uses local mock App Store Connect data and never writes to App Store
  Connect.
- Live mode uses App Store Connect API keys and ES256 JWTs.
- App Store Connect private keys and model-provider API keys are stored in
  Keychain.
- Provider base URL, model, temperature, and enabled state are stored as
  non-secret settings.
- Metadata drafts are stored locally in Application Support by app/version.
- Release signing and notarization credentials are read from environment
  variables by the packaging scripts and are not stored in the repository.

## Architecture

- `App/`: app entry, shared state, and window configuration.
- `Models/`: product, metadata, validation, and provider models.
- `Services/`: service protocols, mock/live services, draft persistence,
  Keychain storage, LLM client, and metadata validation logic.
- `Views/`: SwiftUI feature views.
- `Resources/`: localized app strings.

The Live/Demo data-source mode keeps the real App Store Connect client and the
mock workspace behind the same service boundary.

## Product Identity

- Product name: `Fact`
- Bundle identifier: `com.infinity.factory.mac`

Both values live in `AppConstants` so the visible product name can change
without touching feature views.

## Build

Open in Xcode:

```bash
scripts/open_xcode.sh
```

This app currently uses Swift Package Manager as the Xcode entry point, so Xcode
opens `Fact.xcodeproj` for app development. The Swift package remains available
for command-line build and test loops.

For iteration:

```bash
swift build
swift test
xcodebuild -project Fact.xcodeproj -scheme Fact -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

For a local app bundle:

```bash
scripts/package_app.sh
open Build/Fact.app
```

The package script creates `Build/Fact.app` with `CFBundleIdentifier` set to
`com.infinity.factory.mac`.

For a release-style zip:

```bash
scripts/package_release.sh
```

Set `DEVELOPER_ID_APPLICATION` to codesign the app. Set `APPLE_ID`,
`APPLE_TEAM_ID`, and `APPLE_APP_SPECIFIC_PASSWORD` to submit the zip with
`notarytool` and staple the notarization ticket.

For a local DMG:

```bash
scripts/package_dmg.sh
```

The DMG includes `Fact.app` and an `Applications` shortcut.
