# Feature: Receipt OCR (Phase 1.5)

Receipt capture is iPhone-only in Phase 1.5 and uses Apple Vision/VisionKit through a maintained Expo native module. Tesseract.js is not used in React Native. OCR runs on-device by default.

## Flow

1. User grants camera/photo permission and captures/imports a receipt.
2. App normalizes orientation/size in a protected temporary directory.
3. Vision recognizes text; deterministic parsers propose merchant, date, currency, and decimal-string amount with confidence.
4. Vietnamese confirmation screen shows image and editable suggestions.
5. Only explicit confirmation creates the expense through `packages/domain` and promotes the image to a managed `Asset.id`.
6. Temporary image/OCR text is removed.

Never auto-post based on OCR. Ambiguous totals, multiple currencies/dates, low confidence, permission denial, unsupported device, and recognition failure fall back to manual entry. Decimal text is parsed to integer minor units using currency scale; floats are forbidden.

Asset metadata stores opaque ID, generated managed name, media type, size, hash, and timestamps—not an absolute path. Full backup includes metadata and bytes; Phase 2 CloudKit sync uses CKAsset and verifies the hash.

Acceptance covers Vietnamese/English receipts, rotated/blurred images, multiple totals, malicious metadata/oversized files, cancellation, privacy cleanup, exact amount parsing, backup/restore, and asset sync failure.
