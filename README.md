# Apple Connect

Apple Connect is a CLI-first toolkit for App Store Connect API workflows. The first workflow focuses on batch-managing localized App Store copy across multiple locales.

## What It Can Grow Into

- Batch create and update App Store product-page copy for many locales.
- Pull current App Store metadata into reviewable JSON/YAML files.
- Create new App Store versions and attach builds.
- Manage screenshots, previews, pricing, availability, reviews, and release settings.
- Later, wrap the same core workflows in a macOS desktop app.

## Setup

Requires Node.js 20 or newer.

```bash
npm install
cp .env.example .env
```

Fill `.env` with your App Store Connect API credentials:

```bash
ASC_KEY_ID=YOUR_KEY_ID
ASC_ISSUER_ID=YOUR_ISSUER_ID
ASC_PRIVATE_KEY_PATH=/absolute/path/to/AuthKey_YOUR_KEY_ID.p8
```

The `.env` file and `.p8` keys are ignored by git.

## Basic Commands

Check credentials:

```bash
npm exec apple-connect -- auth check
```

List apps:

```bash
npm exec apple-connect -- apps:list
npm exec apple-connect -- apps:list --bundle-id com.example.app
```

List App Store versions:

```bash
npm exec apple-connect -- versions:list --app-id 1234567890
npm exec apple-connect -- versions:list --app-id 1234567890 --platform IOS --state PREPARE_FOR_SUBMISSION
```

Create a multi-locale copy template:

```bash
npm exec apple-connect -- metadata template --locales en-US,zh-Hans,ja --out metadata/app-store-copy.yaml
```

Pull existing metadata:

```bash
npm exec apple-connect -- metadata pull --app-id 1234567890 --version-id 9876543210 --out metadata/app-store-copy.yaml
```

Validate locally:

```bash
npm exec apple-connect -- metadata validate --file metadata/app-store-copy.yaml
```

Preview API changes:

```bash
npm exec apple-connect -- metadata plan \
  --app-id 1234567890 \
  --version-id 9876543210 \
  --file metadata/app-store-copy.yaml
```

Apply changes. This command is dry-run unless `--yes` is provided:

```bash
npm exec apple-connect -- metadata apply \
  --app-id 1234567890 \
  --version-id 9876543210 \
  --file metadata/app-store-copy.yaml \
  --yes
```

## Copy File Format

```yaml
localizations:
  - locale: en-US
    appInfo:
      name: Example App
      subtitle: Calm daily planning
      privacyPolicyUrl: https://example.com/privacy
    version:
      description: |
        Example App helps you plan your day with a calm, focused workflow.
      keywords: planning,todo,calendar,notes
      promotionalText: A calmer way to plan your next day.
      supportUrl: https://example.com/support
      marketingUrl: https://example.com
      whatsNew: |
        Improved onboarding and fixed small sync issues.
```

You can also use a locale-keyed JSON/YAML object:

```yaml
en-US:
  name: Example App
  description: Example App helps you plan your day.
  keywords: planning,todo,calendar
  supportUrl: https://example.com/support
```

## Notes

- New App Store version localizations should have a matching App Info localization. The CLI can create that first when `appInfo.name` is provided.
- App Store Connect controls which fields are editable based on the app/version state. If Apple rejects an update, the CLI prints the API error payload summary.
- The CLI validates common metadata limits before making API calls: app name, subtitle, description, promotional text, keywords, and full URL fields.
