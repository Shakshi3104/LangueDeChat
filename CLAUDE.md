# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Build for a specific iOS 26.5 simulator (the iPhone 17 Pro UDID below changes per host — list with `xcrun simctl list devices "iOS 26.5"`)
SIM=7066543A-9AE7-4C52-BC04-C842C867DBAE
xcodebuild -project LangueDeChat.xcodeproj \
  -scheme LangueDeChat \
  -destination "id=$SIM" \
  -derivedDataPath /tmp/ldc-build \
  -skipMacroValidation \
  build

# Install + launch on the same simulator
APP=/tmp/ldc-build/Build/Products/Debug-iphonesimulator/LangueDeChat.app
xcrun simctl install "$SIM" "$APP"
xcrun simctl launch "$SIM" com.shakshi.LangueDeChat
```

There is no `swift test` — this is an iOS app target, not a Swift package. The parser logic lives in the upstream [TsuiseKit](https://github.com/Shakshi3104/TsuiseKit) package, which has its own offline + live test suites.

## Architecture

A single SwiftUI app target backed by SwiftData, using the TsuiseKit SPM package for the actual carrier scraping. The whole app surface is four screens:

- `ParcelListView` — inset-grouped list of `TrackedParcel`s with a filter (`All` / `In Progress` / `Delivered`) and a + floating action button. Swipe-to-delete removes the parcel immediately (no confirmation alert).
- `ParcelDetailView` — card-style header, status pills (delivered / ETA), notes, order link, and a vertical timeline of `TrackingEvent`s. Pull-to-refresh re-hits TsuiseKit. Menu has Edit / Refresh / Delete (Delete confirmed via alert).
- `AddParcelView` — form to register a new parcel; includes a `PasteButton` next to the tracking number field.
- `EditParcelView` — same fields as Add minus carrier / tracking number (those are read-only after creation, since changing them would desync `cachedInfoData`).

### `TrackedParcel` (`Models/TrackedParcel.swift` + `Models/TrackedParcel+Tracking.swift`)

The persistent type. Stored properties:

- `trackingNumber`, `carrierRaw` (raw value of `Carrier`), `nickname?`, `notes?`, `orderURL?`, `addedAt`, `lastRefreshedAt?`, `cachedInfoData?`.

**The model is split across two files on purpose.** `TrackedParcel.swift` is the bare `@Model` — every stored property is a plain value type, **no `TsuiseKit` import**. Everything that interprets a parcel (`carrier`, `cachedInfo`, `isDelivered`, `progressStep`, the `Carrier`-typed convenience init, …) lives in `TrackedParcel+Tracking.swift`, which is app-only. This is what lets the share extension compile the same `@Model` into a **shared** SwiftData store without linking TsuiseKit (see "Share extension & shared store"). Keep TsuiseKit-dependent code out of the core file.

`cachedInfoData` is a **JSON-encoded `TsuiseKit.TrackingInfo`** — events live inside that blob, not as a separate `@Model`. This is intentional: events are read in batch in the detail view and never queried in isolation, so a separate model + relationship would buy nothing and force a migration. Anything event-shaped that needs to be queryable (filter, sort, etc.) is exposed via a computed property:

- `isDelivered` — substring match against `["配達完了", "お届け済", "お届け完了", "配達済"]`.
- `deliveredAt` — first event whose `status` matches one of those markers, **derived from the cached events**, no stored field needed.

If you ever need to query events directly (e.g. "events in the last 24 hours" across all parcels), that's the inflection point to break events out into a separate `@Model` with a relationship — and it WILL need a manual `SchemaMigrationPlan`.

### Share extension & shared store

A parcel can be registered from the share sheet (e.g. a tracking mail → Add). The extension (`LangueDeChatShare/`) shows `ShareFormView` hosted in the sheet, then on Add **inserts a `TrackedParcel` straight into the shared SwiftData store** and finishes — there is no hand-off queue.

- The store lives in the **App Group container** (`SharedStore.swift`, `group.com.shakshi.LangueDeChat`), so the app and the extension open **one** store. `SharedStore.makeContainer()` is the single source of the container for the app (`LangueDeChatApp`), background refresh, and the extension's insert.
- The app's `@Query` reads the extension's insert the next time it reads (launch / foreground). No queue, no drain, no `scenePhase` import trigger, no cfprefsd cross-process cache to race — those were the fragile parts of the old UserDefaults hand-off and are gone.
- `TrackedParcel.swift` and `SharedStore.swift` are **duplicated verbatim** into `LangueDeChatShare/` because each synchronized folder belongs to a single target. Edit both copies together.
- `SharedStore.migrateExistingStoreIfNeeded()` runs once in `LangueDeChatApp.init` to move a pre-App-Group store into the container. It copies rows through **live containers**, not by copying `.store` files — a force-quit app leaves recent writes in an un-checkpointed `-wal` that a raw file copy silently drops.
- Parcels added by the extension have no Live Activity of their own; `LiveActivityManager.ensureStarted(for:)` (called after `refreshAll`) starts one once the parcel has fetched data.

### Refresh path

`ParcelRefresher` is a `@MainActor` singleton that calls `TsuiseKit.fetch(carrier:trackingNumber:)`, writes the result back into `parcel.cachedInfoData`, and stamps `lastRefreshedAt`. `refreshAll(in:)` fans out via a `TaskGroup`. The list view runs it on `.task` and on pull-to-refresh; the detail view runs it on `.task` and via the menu.

## Conventions

These are not negotiable inside this repo — match them when adding new screens / strings:

- **English UI.** Every user-facing string in this app is English, including `Carrier.displayName` (which lives in TsuiseKit). Carrier-returned data (`持ち出し中`, post office names, etc.) stays as-is since that's source data.
- **Dates: `yyyy/MM/dd`, POSIX locale, `Asia/Tokyo` timezone.** Always set both `locale` and `timeZone` on `DateFormatter`. The TZ pin matters when the user is overseas.
- **System colors only.** Use `.primary` / `.secondary` / `.tertiary` for text, `Color(.systemGroupedBackground)` / `Color(.secondarySystemGroupedBackground)` for surfaces, and `Color.accentColor` for the cyan tint. Don't hardcode `Color.white` / `Color.black` / `.preferredColorScheme(.dark)` — they break light mode.
- **Destructive actions in the detail view confirm via `.alert`, not `.confirmationDialog`.** The detail menu's Delete uses an alert with the parcel's `titleText` in the message. The list swipe-to-delete is the deliberate exception — it deletes immediately without confirmation.
- **`yyyy/MM/dd` not `MMM d`.** Matches the user's `yomy` project convention.

## Easy to miss

- **`Info.plist` lives at the project root**, not in `LangueDeChat/`. It's there because Yamato's tracking host (`kuronekoyamato.co.jp`) negotiates `AES128-GCM-SHA256` without ECDHE, so iOS's default ATS Forward Secrecy requirement rejects the connection. The `NSExceptionDomains` entry in this plist scopes the relaxation to that single domain. The `LangueDeChat/` folder is a **synchronized folder reference** (Xcode 16+ feature), so dropping an `Info.plist` into it caused a duplicate-output build error — keep it at the project root.
- **The `LangueDeChat/` directory is auto-synchronized to the target.** Anything you `Write` into it (including subdirectories) is picked up by Xcode automatically. No need to add file references to `project.pbxproj`.
- **`AppIcon.icon/` (Icon Composer bundle) supersedes `AppIcon.appiconset/`.** Both are present in the source tree; only the `.icon` bundle produces real icons. Don't delete the empty `.appiconset` blindly — it was created by Xcode at project-init time and removing it might trip the asset catalog compiler depending on Xcode version.
- **TsuiseKit is pinned via `XCRemoteSwiftPackageReference` with `upToNextMajorVersion` from `0.1.0`.** It auto-picks up minor bumps but not 1.x. The `Package.resolved` is committed under `LangueDeChat.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`. Delete + re-resolve if you need to force-pull a fresh tag.
- **`ParcelFilter` is `@State` on purpose.** It resets on app launch. If a future change wants persistence, switch to `@AppStorage` — don't add it to the SwiftData schema.
- **`Bundle Identifier = com.shakshi.LangueDeChat`, `DEVELOPMENT_TEAM = WHBF4Z49B6`.** Both are committed in `project.pbxproj`. Anyone building from a fork should expect to change them.

## Adding a feature

For schema additions, prefer optional/defaulted fields so SwiftData migrates automatically. The current `TrackedParcel` already pre-baked the common ones (`notes`, `orderURL`); add similar ones the same way and Xcode will not complain.

For UI additions:

- **List rows:** `[thumbnail] [title (lineLimit 1) + status + date]`. Date is `.footnote.monospacedDigit()` in `.tertiary`. Don't bring the date back to the right column unless asked.
- **Detail surfaces:** wrap new content in a card — `RoundedRectangle(cornerRadius: 16)` filled with `Color(.secondarySystemGroupedBackground)`, padded `16`.
- **Status indicators:** use the `Pill` (defined in `ParcelDetailView.swift`) for new colored indicators. Tints are `.green` for delivered, `.accentColor` for ETA / in-progress.
