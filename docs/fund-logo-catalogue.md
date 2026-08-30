# Fund Logo Catalogue

Fund and ETF logos are bundled as manager-level image sets in
`MonMon/Resources/Assets.xcassets`. `FundLogoCatalogue` maps normalized fund symbols to those
assets, so an open-ended fund and an ETF managed by the same company reuse one image.

The bundled image is the first display choice. The Fmarket `logoURL` remains the fallback for
funds missing from the local mapping, followed by the existing ticker monogram.

## Asset sources

- The 26 managers present in the Fmarket fund catalogue use the corresponding `owner.avatarUrl`
  returned by the app's existing catalogue endpoint, retrieved on 2026-08-30.
- FPT Capital uses the header logo published at
  `https://fptcapital.com.vn/upload/hinhanh/1635863623_logo.png`.
- Vietnam Fortune Fund Management (VFC) uses the header logo published at
  `https://vietcat.com/Upload/banner/logo-vfc-1.png`.

## Updating the catalogue

1. Add or replace the manager's image set in `Assets.xcassets`.
2. Add its current fund and ETF symbols to `FundLogoCatalogue.managerSymbols`.
3. Run `FundLogoCatalogueTests`; it verifies normalized lookup, shared-manager reuse, unknown-symbol
   fallback, and that every referenced asset is compiled into the app bundle.
