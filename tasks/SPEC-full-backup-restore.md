# Spec: Full Backup and Restore

Module id: `full-backup-restore`

## Objective

Let the owner export one complete, portable snapshot of MonMon and later restore
that snapshot without rebuilding accounts, history, investments, debts, or
recurring rules by hand. The backup is a versioned JSON document that the owner
chooses where to keep through the system Files interface.

Restore is authoritative replacement, not record-by-record merge. MonMon first
validates and previews the entire document, saves a private recovery snapshot of
the current local data, then makes the selected snapshot the complete local
state in one SwiftData save. No name, amount, date, or note-based duplicate
matching appears in this flow.

This capability complements iCloud synchronisation rather than claiming to
replace or control it. Export captures the records currently available on the
device. When iCloud sync is enabled, restore changes enter the existing private
CloudKit mirroring pipeline on the schedule the system controls.

### Assumptions

1. One backup represents the complete state of one MonMon data flavour at one
   moment. A Development backup cannot be restored into Production or vice
   versa.
2. JSON readability is acceptable for the first version. The UI warns that an
   exported file contains private financial data and is not password-encrypted.
3. Restore replaces the current snapshot. Selective restore, append, merge, and
   conflict-by-conflict duplicate review are outside this module.
4. Model UUIDs are portable identities and remain unchanged across a round trip.
   Existing SwiftData objects with matching UUIDs are updated in place where
   possible; this is identity preservation, not fuzzy duplicate matching.
5. Every stored field from every model in `MonMonSchema.models` is backed up,
   including pending transaction captures, recurring-generation state, and
   statement-import fingerprint provenance.
6. Logical preferences that point into the data graph are backed up. Device and
   runtime settings such as biometric lock, iCloud enablement, and last-sync
   status remain local to the destination device.
7. Staged bank-statement PDFs and their inbox manifests are not part of the
   backup. No raw statement bytes, filename, reference, or parsed session enters
   the JSON document.
8. A restore file is at most 100 MB. That limit bounds untrusted allocation while
   leaving ample room for a personal ledger containing no binary attachments.
9. The latest private pre-restore recovery snapshot is kept in Application
   Support and replaced only by the next confirmed restore. It is never synced
   or exposed through the ordinary export flow.

## Document Contract

The public file is ordinary UTF-8 JSON with a `.json` extension and `public.json`
content type. A custom `.monmonbackup` package adds no fidelity in the first
version and is deliberately deferred.

```swift
struct MonMonBackupDocument: Codable, Sendable, Equatable {
    let format: String
    let formatVersion: Int
    let exportedAt: Date
    let appVersion: String
    let flavour: BackupFlavour
    let payload: MonMonBackupPayload
    let payloadSHA256: String
}

struct MonMonBackupPayload: Codable, Sendable, Equatable {
    let accounts: [CashAccountBackup]
    let categories: [TransactionCategoryBackup]
    let transactions: [MoneyTransactionBackup]
    let pendingCaptures: [PendingTransactionCaptureBackup]
    let transfers: [AccountTransferBackup]
    let savingsDeposits: [SavingsDepositBackup]
    let savingsWithdrawals: [SavingsWithdrawalBackup]
    let fundInstruments: [FundInstrumentBackup]
    let fundHoldings: [FundHoldingBackup]
    let fundSales: [FundSaleBackup]
    let debts: [DebtBackup]
    let debtPayments: [DebtPaymentBackup]
    let recurringRules: [RecurringRuleBackup]
    let preferences: BackupPreferences
}
```

Contract rules:

- `format` is exactly `monmon-backup`.
- Version 1 reads only `formatVersion == 1`. A newer version fails before any
  write with an update-required message. Future readers migrate older DTOs into
  the current payload before validation; they never decode old JSON directly
  into SwiftData models.
- `flavour` is derived from the build configuration already separating bundle,
  App Group, and CloudKit identifiers. A mismatch is a blocking validation
  error, not a warning the owner can bypass.
- `appVersion` is display and diagnostic metadata. Compatibility is decided by
  `formatVersion`, never by comparing marketing versions.
- UUIDs are lowercase canonical strings in JSON and decode to `UUID` at the DTO
  boundary.
- Every `Decimal` is a canonical base-10 string. No amount, unit quantity, price,
  principal, or interest rate passes through `Double` or a locale formatter.
- Dates are UTC ISO 8601 strings with fractional seconds. Decoding uses one
  fixed POSIX formatter and does not read the device locale or time zone.
- Typed enum fields use their stable raw values. An unknown enum is a blocking
  compatibility error. Open string fields such as `FundInstrument.priceSource`
  remain strings and round-trip values a newer build may have written.
- Arrays are sorted deterministically by `createdAt`, then UUID. The account
  anchor and any record with equal dates still produce stable JSON.
- `payloadSHA256` is the lowercase SHA-256 of the canonical encoded payload with
  sorted keys. It detects truncation or accidental editing; it is an integrity
  check, not authentication or encryption.
- Unknown top-level keys may be ignored only within a supported format version.
  Missing required keys and malformed values fail decoding.
- Suggested filename is `MonMon-backup-YYYY-MM-DD-HHmmss.json`, formatted in the
  owner's local time for recognition. The timestamp inside the document remains
  UTC and authoritative.

### Persisted model coverage

Backup DTOs mirror stored fields, not derived presentation values:

| Model | Required coverage |
|---|---|
| `CashAccount` | id, name, kind, opening balance, currency, created date |
| `TransactionCategory` | id, name, kind, symbol, colour, created date |
| `MoneyTransaction` | all financial fields, account/category ids, recurring and import provenance |
| `PendingTransactionCapture` | raw text, parsed values, candidate ids, issue codes, dates |
| `AccountTransfer` | amount, endpoints, dates, note, currency, both import fingerprints |
| `SavingsDeposit` | principal, rate, term, opening/source account, currency, dates |
| `SavingsWithdrawal` | deposit, principal, received amount, destination, note, currency, dates |
| `FundInstrument` | identity, kind, prices, quote metadata, auto-quote flag, currency, dates |
| `FundHolding` | instrument, units, cost, source account, purchase and creation dates |
| `FundSale` | holding, units, price, proceeds account, note, currency, dates |
| `Debt` | counterparty, direction, principal, rate, account, due/open dates, note, currency |
| `DebtPayment` | debt, amount, account, note, currency, occurrence and creation dates |
| `RecurringRule` | payload, schedule, pause state, generation cursor, account/category ids, dates |

Adding a stored model or attribute to `MonMonSchema` is incomplete until the
backup DTO, encoder, decoder, validator, round-trip fixture, and version policy
are updated in the same change.

### Preference coverage

Version 1 backs up:

- app theme and language;
- default transaction account;
- default expense and income categories; and
- bank plus masked-account-suffix mappings used by statement import.

Each referenced UUID is restored only if it resolves to a compatible record in
the restored payload. A stale optional preference is cleared rather than pointed
at an unrelated fallback.

Version 1 does not back up:

- biometric-lock enablement or authentication state;
- iCloud-sync enablement, mirroring events, or last-sync date;
- seed markers, scene state, selected tabs, transient errors, or caches;
- App Group paths or bundle/container identifiers; or
- staged import-inbox files and manifests.

## Export Contract

Export performs no store mutation.

1. Flush pending edits in the source context before snapshotting.
2. Fetch every registered model through an isolated context and convert it to
   immutable backup DTOs. Never send SwiftData model objects across actors.
3. Read the approved logical preferences and construct the payload.
4. Canonically encode the payload, calculate its hash, then encode the envelope.
5. Refuse an output larger than 100 MB with no partial document presented.
6. Present the system file exporter with `public.json` and the suggested name.
7. Report success only after the exporter completes. Cancellation is not an
   error and leaves no app-owned temporary copy behind.

The Backup card says that the snapshot contains data currently present on this
device. `CloudSync.syncNow` may be offered before export, but export never claims
that private CloudKit is globally caught up because the app has no API that can
prove or force that state.

## Restore Contract

### Read and preview

1. Present a single-selection system file importer restricted to JSON.
2. Start access to the returned security-scoped URL, read at most 100 MB, and
   release access immediately after the bytes are copied.
3. Decode the envelope, verify format, version, flavour, and payload hash, then
   validate the complete payload in memory.
4. Display backup date, app version, flavour, file size, and counts for every
   record group. Also display current versus incoming total record counts.
5. Parsing, viewing, cancelling, or failing validation performs no SwiftData or
   UserDefaults write.

### Validation

Blocking validation includes:

- one unique UUID per record type in the payload;
- structurally valid UUID, date, decimal, currency, enum, and import-hash values;
- positive amounts and quantities where the current domain requires them;
- nonnegative values where zero is valid;
- different source and destination accounts for every transfer;
- every required account id resolving to an account in the payload;
- transaction/category and recurring/category kinds agreeing when a category is
  present;
- sales not exceeding their holding's units in aggregate; and
- withdrawal principal not exceeding its deposit's remaining principal in the
  same snapshot.

An optional foreign key may be absent because CloudKit-compatible models permit
that state. A non-`nil` optional id that no longer resolves is preserved only
where the current app already renders that condition safely; preview shows a
warning. Required account references and impossible financial values always
block restore.

Validation uses dedicated backup rules rather than current entry drafts. A
historical snapshot may legitimately contain values that today's create form
would reject based on current balance or today's date.

### Recovery snapshot

Before changing the store, MonMon exports the current local snapshot through the
same encoder and validator into a fixed Application Support recovery location.

- Write to a private partial file, apply platform file protection where
  available, and atomically replace the previous recovery file only after the
  new one is durable and validates.
- If recovery creation fails, the incoming restore does not begin.
- Settings exposes **Restore Previous Data** when the recovery file is valid. It
  goes through the same preview and confirmation flow as an imported document.
- Only one recovery generation is retained. It is local, not CloudKit-backed,
  and is not included inside another backup.

### Authoritative apply

The confirmation action is titled **Restore and Replace** and states that the
incoming snapshot becomes the whole local dataset. If app lock is enabled, its
existing authentication gate must succeed before the destructive action.

The restore service owns a dedicated `ModelContext` with autosave disabled. It
re-fetches current state after confirmation, revalidates the already-decoded
payload, and applies it by model UUID:

- exactly one current object with that UUID: update every stored field in place;
- no current object with that UUID: insert a new object with the backup UUID;
- multiple current objects with that UUID: retain one deterministic survivor,
  update it, and delete the duplicate physical objects; and
- current UUID absent from the backup: delete that object.

No existing record is matched by name, symbol, amount, note, or date. The apply
order follows logical parents before dependants for legibility even though the
schema stores flat UUIDs:

1. accounts, categories, instruments, deposits, holdings, debts, recurring rules;
2. transactions, pending captures, transfers; and
3. withdrawals, sales, and debt payments.

All model inserts, updates, and deletes are saved once. Any validation or save
error rolls the context back and leaves preferences unchanged. Only after the
SwiftData save succeeds does the service write validated logical preferences.
Preference writes are idempotent and stale optional values are cleared.

After success, run `StoreReconciler` and refresh query-backed screens and
pending-count surfaces. Recurring generation is not part of the restore
transaction; the normal app lifecycle decides what a restored rule owes next.

Restoring the same backup again yields the same DTO snapshot and does not append
another copy of its records.

## User Experience

The existing Settings Backup card becomes the entry point for three actions:

- **Export Backup** — creates an owner-visible JSON file;
- **Restore Backup** — selects, validates, previews, and replaces; and
- **Restore Previous Data** — visible only when a private recovery snapshot is
  available.

Export UI:

- warns before presentation that JSON is readable financial data;
- shows progress while the snapshot is built;
- disables repeat submission while work is running; and
- reports success, cancellation, or a safe error without exposing record text.

Restore UI:

- separates validation from confirmation so merely opening a file cannot write;
- shows current and incoming counts by domain, not raw record contents;
- presents format/flavour incompatibility and corruption as specific failures;
- requires a destructive confirmation immediately before apply;
- keeps the chosen preview available after a recoverable failure; and
- reports whether local restore succeeded separately from later iCloud sync.

When iCloud is enabled, confirmation advises the owner to close MonMon on other
devices, restore on this one, and allow this device to sync before reopening the
others. The app does not claim atomic replacement across devices or require the
owner to disable iCloud, because re-enabling an out-of-date cloud dataset can
bring old records back.

Every control retains a 44-point target, a VoiceOver label, and a stable
content-free accessibility identifier. Colour is never the only indication of
warning, failure, or destructive scope.

## Tech Stack

- Swift 6, SwiftUI, Observation, SwiftData, and Foundation already used by the
  project.
- `Codable` DTOs and `JSONEncoder`/`JSONDecoder` for the versioned document.
- CryptoKit SHA-256 for payload integrity.
- UniformTypeIdentifiers `UTType.json` and SwiftUI file importer/exporter.
- Existing `AppLock`, `CloudSync`, `StoreReconciler`, and preference keys.
- Application Support for one private pre-restore recovery document.
- No new package, server, background task, archive format, or encryption layer.

Apple references:

- https://developer.apple.com/documentation/swiftui/view/fileimporter%28ispresented%3Aallowedcontenttypes%3Aoncompletion%3A%29
- https://developer.apple.com/documentation/swiftui/view-presentation
- https://developer.apple.com/documentation/foundation/jsonencoder
- https://developer.apple.com/documentation/swiftdata/modelcontext
- https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices

## Commands

Run unit and in-memory persistence tests:

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test
```

Check Swift formatting:

```sh
rtk swift format lint --strict --recursive MonMon MonMonTests MonMonShareExtension
```

Compile the iOS SDK without running a Simulator:

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug \
  -sdk iphonesimulator -derivedDataPath /tmp/MonMonDerivedDataIOS \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build
```

After the implementation branch is merged into `dev`, build, install, and
launch the Development flavour on the physical phone:

```sh
rtk scripts/run-iphone.sh Yushaku
```

## Project Structure

```text
MonMon/Backup/MonMonBackupDocument.swift
    Versioned envelope, payload DTOs, canonical scalar coders, and hash contract.

MonMon/Backup/MonMonBackupValidator.swift
    Pure structural, referential, domain, version, and flavour validation.

MonMon/Backup/MonMonBackupService.swift
    Isolated snapshot fetch, deterministic export, recovery-file management,
    and authoritative restore transaction.

MonMon/Backup/BackupRestoreView.swift
    Export progress, import selection, preview, confirmation, result, and
    previous-data recovery UI.

MonMon/Settings/SettingsView.swift
    Backup card entry points and current iCloud context.

MonMonTests/Backup/MonMonBackupDocumentTests.swift
    Canonical JSON, scalar fidelity, checksum, version, and all-field coverage.

MonMonTests/Backup/MonMonBackupValidatorTests.swift
    Malformed, incompatible, referential, and domain validation cases.

MonMonTests/Backup/MonMonBackupServiceTests.swift
    Full in-memory round trip, replacement, rollback, preferences, and recovery.
```

Implementation planning may split DTO declarations by domain if one file becomes
hard to review, but the document and service contracts remain one module.

## Code Style

- SwiftData models never conform directly to `Codable`; explicit immutable DTOs
  define the portable contract.
- Centralize UUID, Decimal, Date, hash, and enum conversion. Do not let each DTO
  invent a slightly different representation.
- Use typed validation issues with stable codes. User messages map from those
  codes and never interpolate notes, raw capture text, account suffixes, or local
  paths.
- Keep document decode and validation pure. File access, model access, and UI
  state live at separate boundaries.
- Preserve exact stored values. Do not normalize names, rewrite notes, refresh
  prices, recalculate interest, or apply current form defaults during restore.
- Never pass SwiftData objects across actors or retain them in the preview.

Example scalar boundary:

```swift
struct BackupDecimal: Codable, Sendable, Equatable {
    let value: Decimal

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let value = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")) else {
            throw BackupDecodingError.invalidDecimal
        }
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(NSDecimalNumber(decimal: value).stringValue)
    }
}
```

## Testing Strategy

Use Swift Testing, temporary directories, injected UserDefaults suites, and an
in-memory `ModelContainer`. No test reads the owner's store, iCloud account, or
real statement inbox.

Required document tests:

- every stored field of all 13 models survives encode/decode exactly;
- fractional decimals, optional dates, UUIDs, booleans, and raw strings round trip;
- semantically identical payloads produce identical sorted JSON and hashes;
- one-byte payload corruption fails checksum verification;
- missing keys, malformed scalars, unknown enums, and unsupported versions fail;
- Development and Production documents cannot cross flavours; and
- encoded JSON contains no staged filename, PDF bytes, CloudKit runtime state,
  or biometric preference.

Required validation tests:

- duplicate ids within one record type fail;
- required account references must resolve;
- optional missing references produce only the explicitly supported warnings;
- category direction, transfer endpoints, positivity, aggregate sale units, and
  withdrawal principal rules are enforced;
- structurally invalid import fingerprints fail while valid hashes survive; and
- stale logical preference ids are cleared rather than reassigned.

Required service tests:

- a populated store exports all registered models and approved preferences;
- export performs no mutation and cancellation leaves no temporary artifact;
- restore into a different populated store updates matching UUIDs, inserts
  missing UUIDs, and deletes UUIDs absent from the snapshot;
- no name, symbol, amount, note, or date-based matching affects restore;
- restoring the same snapshot twice yields the same DTO snapshot and counts;
- a decode, validation, recovery-write, or SwiftData-save failure leaves the
  original store and preferences unchanged;
- the private recovery snapshot is valid, replaced atomically, retained after
  success, and can restore the previous state;
- imported and recurring provenance survives, so existing reconciliation and
  recurring deduplication still work after restore;
- restored net worth, every account balance, spending/income summaries, fund
  quantities, debt balances, and next recurring occurrence match the source;
- restore never creates, removes, or exports a statement-inbox file; and
- full existing CloudKit, import, recurring, and domain suites remain green.

Required UI/state tests:

- viewing or cancelling a preview cannot enable an accidental write;
- current and incoming counts remain visible before confirmation;
- malformed, newer-version, wrong-flavour, and checksum errors are distinct;
- destructive action is disabled during validation and apply;
- failure keeps the preview available for retry;
- successful local restore is not described as completed iCloud sync; and
- accessibility identifiers contain roles or indexes, never financial content.

The implementation must pass unit tests, strict format lint, and the non-
Simulator iOS build on its feature branch. After the user merges it into `dev`,
the agent runs build/install/launch on `Yushaku`; the owner performs hands-on
export, file inspection, destructive restore, recovery, and multi-device checks.

## Boundaries

### Always do

- Treat every imported byte and scalar as untrusted until full validation ends.
- Preserve UUIDs and all stored financial/provenance values exactly.
- Build the entire preview and recovery snapshot before touching current data.
- Save model replacement once and roll back the whole model change on failure.
- Keep Dev and Prod backup namespaces separate.
- Warn that exported JSON is readable financial data.
- Keep raw bank statements outside both public and recovery backups.
- Run the full automated gates and physical-iPhone workflow at the prescribed
  branch checkpoints.

### Ask first

- Add password encryption, compression, a custom file type, or a dependency.
- Add selective restore, merge, fuzzy duplicate handling, or CSV restore.
- Change which preferences or import provenance fields are portable.
- Allow cross-flavour restore or remove the 100 MB boundary.
- Retain more than one private recovery generation or sync recovery files.
- Add scheduled/background backup or upload a backup anywhere automatically.
- Change a SwiftData model or existing financial-domain validation rule.

### Never do

- Copy or restore the SwiftData/SQLite store file directly.
- Call `ModelContainer.deleteAllData()` as the restore implementation.
- Write any data before decode, checksum, version, flavour, and payload
  validation all succeed.
- Partially commit a restore or continue after recovery-snapshot creation fails.
- Match records by human-readable fields or silently append the snapshot.
- Export biometric state, iCloud runtime state, raw statement bytes, references,
  filenames, or App Group paths.
- Log or place financial content in errors, analytics, accessibility ids, or
  crash metadata.
- Claim CloudKit is current or that cross-device replacement is atomic.
- Use a Simulator for runtime/UI acceptance unless the user explicitly asks.

## Success Criteria

- The owner can export one readable, versioned JSON file through Files that
  contains every stored field of all registered financial models and approved
  logical preferences.
- A complete export restored into a different populated store produces the same
  DTO snapshot, model counts, UUID graph, balances, reports, asset values, debt
  state, and recurring schedule as its source.
- Restore is visibly authoritative replacement and never presents merge or
  duplicate-resolution choices.
- Corrupt, malformed, oversized, unsupported-version, or wrong-flavour input
  changes neither SwiftData nor preferences.
- A restore-time validation or save failure leaves the previous state intact.
- A valid private recovery snapshot exists before replacement and can restore
  the immediately previous state.
- Repeated restore does not append duplicates, and provenance still prevents a
  restored bank-statement row or recurring occurrence being generated twice.
- No raw statement, device-security setting, CloudKit runtime state, or local
  path leaves the app through backup.
- iCloud-enabled UI describes local completion and asynchronous mirroring
  honestly, without promising a forced sync.
- Automated gates pass; build/install/launch succeeds on `Yushaku` after merge
  into `dev`; the owner completes hands-on acceptance on the physical device.

## Out of Scope

- CSV import or CSV as a restorable format.
- Selective-domain restore, append, merge, and interactive duplicate resolution.
- Password encryption, Keychain-managed backup keys, and recovery passwords.
- Compression, attachments, custom document packages, and custom UTTypes.
- Scheduled, background, or remote backup upload.
- Raw SwiftData/SQLite file copying.
- Staged bank statements, parsed import sessions, caches, and device settings.
- A promise of transactional restore across multiple CloudKit devices.

## Open Questions

None for version 1. The owner approved full JSON snapshot replacement, all
financial domains, no merge/deduplication UI, and readable JSON on 27 August
2026. Import fingerprint provenance is included only to preserve the restored
records' existing idempotency; raw statement content remains excluded.
