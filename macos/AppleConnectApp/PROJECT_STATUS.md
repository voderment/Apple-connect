# Fact macOS Project Status

## Current Product Shape

Fact is a native macOS 26+ app for managing App Store Connect release work.
Localized copy is the first complete workflow, and the product now also covers
localized media assets, pricing and availability, app privacy, submission setup,
and ratings/compliance readiness in the same release-prep surface.

The account flow is intentionally split:

1. Sign in with Apple/iCloud identifies the user inside Fact.
2. App Store Connect API binding grants access to App Store Connect data.
3. After the API key is validated, Fact loads the app list.

For development and review without credentials, the login and binding screens
also expose a Demo workspace backed by mock App Store Connect data. Demo saves
are local simulations and never write to App Store Connect.

Email/password App Store Connect login with 2FA is not the first integration
path. It may be researched later, but the stable automation path is App Store
Connect API keys.

## Implemented

- Native SwiftUI app shell with standard macOS window chrome.
- Login-only first screen with text, Sign in with Apple button, and a swappable
  background image slot named `LoginBackground`.
- Post-login API binding screen with Live API and Demo data-source modes.
- One-click Demo workspace that signs into a local session, loads sample apps,
  and avoids persisting fake credentials.
- Demo data includes both a clean sample app and a review-workflow sample with
  incomplete localizations, policy warnings, and URL gaps.
- One-click Demo entry automatically selects the review-workflow sample and
  opens Review Prep.
- Unified three-column NavigationSplitView workspace shell for dashboard,
  connection, model-provider, settings, app, version, and metadata surfaces.
- Review Prep workspace that aggregates release readiness, review checklist,
  validation issues, and draft-change actions with jump-back paths to localized
  copy.
- Submission Setup workspace for pre-review build and release readiness:
  - Build candidate selection and processing-state validation.
  - App Review contact fields, review notes, and optional demo-account access.
  - Release option, phased release, draft-submission item count, export
    compliance, and content-rights checks.
  - Mock demo data with realistic blockers for missing build selection,
    review-contact gaps, demo-account password, encryption compliance, and
    third-party content rights.
- Review Prep next-action summary with blocker, warning, proposed-fix, and
  draft-action metrics.
- Review Prep proposed-fix queue for deterministic safe edits, with per-fix and
  apply-all actions that update the local draft only after review.
- Localized Media workspace for managing screenshot and preview-video sets by
  locale and device family:
  - App Store display-size requirements for iPhone, iPad, and Mac mock targets.
  - Per-locale completeness, size mismatch, video-duration, and file-size
    validation.
  - Review Prep and handoff integration for localized asset blockers.
- Pricing and Availability workspace for price tier, tax category, storefront
  availability, preorder, app availability, and distribution-method checks.
- App Privacy workspace for privacy-policy URL, data type collection, linked
  purposes, tracking flags, third-party use, and review readiness.
- App list home with grid/list mode and a floating action toolbar.
- App detail shell that switches to a sidebar only after an app is selected.
- App overview surfaces release readiness with a direct action into localized
  copy editing.
- Product identity constants:
  - Product name: `Fact`
  - Bundle identifier: `com.infinity.factory.mac`
- Sidebar/workspace/navigation structure.
- Dashboard localized-copy workspace status reflects the selected version's
  release readiness instead of always reporting ready.
- Sign in with Apple UI entry point.
- App Store Connect API-key binding UI.
- App/version browser.
- Localized metadata editor for App Info and App Store Version fields.
- Field validation and publish-plan preview with before/after field summaries.
- Validation issues include concise remediation guidance.
- Review checklist in the inspector for required storefront copy, privacy and
  URL hygiene, review-sensitive language, release notes, and draft state.
- Copyable Markdown change summaries from the publish-plan preview.
- Copyable/exportable review-prep report from the inspector that combines
  release readiness, review checklist, proposed fixes, validation issues, and
  draft actions.
- Review handoff package export from Review Prep with metadata JSON, review
  report, proposed fixes, change summary, media, pricing, privacy, submission
  setup, ratings/compliance checks, and a versioned manifest.
- Copyable current metadata JSON export from the inspector, including file
  export for handoff and archival.
- Clipboard and file metadata JSON import that replaces the local draft while
  preserving the pulled baseline for change planning.
- Release readiness panel that summarizes blocking metadata issues, warnings,
  unsaved drafts, and demo/live save expectations.
- Validation rows in the inspector can focus the affected locale directly.
- Local App Review-style metadata guidance for placeholder copy, prerelease or
  internal-test wording, unsubstantiated marketing claims, and insecure
  customer-facing URLs.
- Stable validation and change row identities to reduce editor flicker.
- Add-locale flow with optional copy-from-selected-locale scaffolding.
- Locale search/filter for larger localization sets.
- Locale status filters for all, edited, issue-bearing, and incomplete
  localizations.
- Keyword normalization action for pasted keyword lists with mixed separators
  or duplicate terms.
- Bulk action to fill missing privacy, marketing, and support URL fields from
  the selected locale without overwriting existing localized URLs.
- Bulk action to fill missing non-URL copy fields from the selected locale
  without overwriting existing localized text.
- Bulk action to upgrade customer-facing App Store URL fields from `http://`
  to `https://` across all locales.
- Local metadata draft autosave and restore, keyed by app/version in
  Application Support.
- Draft-safe app/version switching and refresh behavior that secures pending
  local metadata edits before replacing the loaded workspace.
- AI-assisted metadata action grid for the selected locale, backed by the
  configured OpenAI-compatible provider:
  - Rewrite Description.
  - Suggest Keywords.
  - Draft Promo Text.
  - Draft What's New.
  - Review Polish, which uses current validation/review guidance and applies a
    structured metadata response to the selected locale.
- AI-assisted locale translation that uses structured JSON output to translate
  a source locale into the selected target locale while preserving URLs and
  normalizing keywords.
- Ratings and Compliance workspace for App Store category selection, age-rating
  questionnaire answers, Made for Kids review, regional compliance fields, and
  third-party content-rights readiness.
- Ratings and Compliance review rules currently cover missing categories,
  duplicate category choices, incomplete age questionnaire state, Made for Kids
  conflicts, unrestricted web access, user-generated content, Korea GRAC risk,
  China mainland ICP/game approval risk, and content-rights confirmation.
- Demo AI fixture generation for no-key walkthroughs in Demo mode when no
  model provider is configured; status messages clearly identify Demo AI.
- Mock App Store Connect service for explicit UI iteration.
- Live App Store Connect service skeleton with:
  - ES256 JWT generation.
  - JSON:API client and pagination.
  - App listing.
  - Version listing.
  - App Info and Version localization pull.
  - App Info and Version localization create/update publish path.
- Keychain secret store utility.
- Alibaba Cloud Model Studio / OpenAI-compatible provider configuration.
- Keychain-backed model-provider API key persistence with UserDefaults-backed
  non-secret provider settings.
- Explicit actions to forget stored App Store Connect keys and reset model
  provider settings.
- OpenAI-compatible `/chat/completions` client.
- Light, dark, and system appearance switching.
- Settings safety summary for Live saves, App Review submission boundaries,
  Demo mode, Keychain secrets, and local draft storage.
- Workspace command menu includes refresh, validation, and `Cmd+S` metadata
  save when the current plan is saveable.
- Local `Fact.app` packaging script.

## Deliberate Gaps

- API keys are persisted after successful validation, but draft key entry before
  validation is still UI-only.
- Sign-out clears the active session; credential removal is an explicit
  connection-settings action so users do not lose stored setup by accident.
- Sign in with Apple needs final signing/provisioning entitlements before it is
  reliable outside local development.
- The local release script can create a zip and optionally run Developer ID
  signing/notarization from environment variables. A DMG script creates a
  local drag-to-Applications image. Sparkle or another update mechanism is not
  wired yet.
- AI features have provider configuration, a raw chat client, first-class
  metadata-editor generation actions, and cross-locale translation. Deeper App
  Review policy checks still need product workflows.

## Useful Commands

```bash
scripts/open_xcode.sh
swift build
swift test
scripts/package_app.sh
scripts/package_release.sh
scripts/package_dmg.sh
open Build/Fact.app
```

The app now includes `Fact.xcodeproj` for Xcode development. The Swift package
still exists for command-line iteration.

## Next Good Steps

1. Add live App Store Connect API mapping for Media Assets, Pricing,
   App Privacy, Submission Setup, and Ratings/Compliance where Apple exposes
   read/write resources; keep explicit manual/offline fields for anything Apple
   does not expose.
2. Expand App Review guidance with category-specific policy checks, regional
   compliance notes, and remediation copy.
3. Add reviewable bulk edit/apply actions for repeated metadata fields that
   need explicit user selection.
4. Add visual import workflows for media assets: drag folders, inspect real
   dimensions/durations, group by locale/device, and surface replacement
   suggestions before upload.
5. Add Sparkle or another update mechanism for website distribution.
6. Add onboarding copy for permissions, Keychain storage, and demo/live mode
   differences.
