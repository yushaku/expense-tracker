# Implementation Plan: Bundled Fund Manager Logos

## Objective

Show a stable, offline fund-manager mark for known open-ended funds and ETFs.
The same manager asset is shared by every instrument it manages. Bundled assets
take precedence over provider URLs; unknown tickers retain the existing remote
logo and ticker-monogram fallbacks.

## Tech Stack and Structure

- Swift 6 and SwiftUI in `MonMon/Funds/`.
- Manager image sets named `FundManager*.imageset` in
  `MonMon/Resources/Assets.xcassets/`.
- Pure ticker-to-asset lookup beside `FundLogoView`, covered by Swift Testing in
  `MonMonTests/Funds/`.
- No SwiftData migration: the persisted optional `logoURL` remains compatible
  and serves only as the second-choice fallback.

## Code Style

```swift
if let assetName = FundLogoCatalogue.assetName(for: symbol) {
    Image(assetName)
} else if let url = logoURL.flatMap(URL.init(string:)) {
    AsyncImage(url: url) { phase in /* existing fallback */ }
}
```

Use explicit symbol groups per manager rather than guessing ownership from
ticker prefixes. Normalize lookup input by trimming and uppercasing.

## Commands

- Format: `xcrun swift-format lint -r MonMon MonMonTests`
- Focused tests: macOS `xcodebuild test` with
  `-only-testing:MonMonTests/FundLogoCatalogueTests`
- Full tests: macOS `xcodebuild test` using `/tmp/MonMonDerivedData`
- iOS compile: `xcodebuild build -sdk iphonesimulator` with signing disabled

## Testing Strategy

- RED/GREEN unit tests for representative open-ended funds, ETFs, input
  normalization, unknown tickers, and the existence of every referenced asset.
- Compile the complete iOS target graph so the asset catalogue is validated for
  the app, widget, and share extension.
- Runtime/UI acceptance remains on the physical iPhone after merge into `dev`.

## Boundaries

- Always: prefer bundled assets, keep remote and monogram fallbacks, preserve
  decorative-image accessibility behavior.
- Ask first: add a dependency, change the SwiftData schema, or replace brand
  artwork with generated approximations.
- Never: infer a manager from a broad prefix, make logo availability block fund
  import, or run UI validation in an iPhone Simulator.

## Implementation Order

1. Add and test the normalized ticker-to-manager asset catalogue.
2. Add bundled manager artwork and verify every catalogue reference resolves.
3. Prefer bundled assets in `FundLogoView` while preserving both fallbacks.
4. Run review, format, full unit-test, and iOS compile gates.

## Success Criteria

- Known open-ended funds and ETFs display their bundled manager logo offline.
- A manager's funds and ETFs resolve to the same asset.
- Unknown instruments still use their remote URL, then their monogram.
- No persistence migration or new network request is introduced.
