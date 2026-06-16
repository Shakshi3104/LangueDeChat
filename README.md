# LangueDeChat

A small iOS app to track Japanese parcels — **Japan Post (日本郵便)**, **Yamato Transport (クロネコヤマト)**, and **Sagawa Express (佐川急便)** — on a single screen.

The name *Langue de chat* nods to Kuronekoyamato → cat → 猫の舌 → ラング・ド・シャ. The accent color is a wink at the Yokumoku **Cigare** tin (`#03C2FE`).

Built on top of [TsuiseKit](https://github.com/Shakshi3104/TsuiseKit), a Swift package that scrapes each carrier's public tracking page.

## Features

- Track parcels from Japan Post, Yamato, and Sagawa in one inset-grouped list
- Filter by delivery state: **All / In Progress / Delivered**
- Nickname, free-form notes, and an order URL per parcel
- Timeline-style event view in detail
- ETA and delivered-at pills
- Pull-to-refresh on detail view
- Light and dark mode
- All data stays on-device via SwiftData

## Requirements

- Xcode 26.5+
- iOS 26.5+ deployment target
- A free Apple ID is enough to run on your own device

## Build & Run

```sh
git clone https://github.com/Shakshi3104/LangueDeChat.git
cd LangueDeChat
open LangueDeChat.xcodeproj
```

Then in Xcode:

1. Update **Signing & Capabilities** → Team and Bundle Identifier to your own.
2. Build & Run on a simulator or your iPhone.

The TsuiseKit dependency is resolved automatically by Swift Package Manager on first build.

## Architecture

- **SwiftUI** for views, **SwiftData** for persistence (`TrackedParcel` `@Model`).
- **TsuiseKit** does the per-carrier HTML scraping. The app only talks to TsuiseKit's `TsuiseKit.fetch(carrier:trackingNumber:)`.
- An `NSAppTransportSecurity` exception for `kuronekoyamato.co.jp` lives in `Info.plist` — Yamato's tracking host negotiates `AES128-GCM-SHA256` without ECDHE, which iOS rejects under the default ATS Forward Secrecy requirement.

## Limitations

- **No notifications yet** — refresh happens when the list is shown or pull-to-refresh is triggered.
- **No Amazon Japan support** — Amazon Logistics (DA-prefixed numbers) is not exposed through a public tracking endpoint; use the Amazon app for those.
- **No widget** — yet.

## License

MIT. See `LICENSE`.
