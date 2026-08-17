# System: Security and Privacy

## Trust boundaries

- The iOS/macOS application sandbox and CloudKit identity/permissions are security boundaries.
- Face ID/Touch ID is an optional local privacy gate and convenience control, not authentication or authorization. A compromised unlocked OS account is outside what biometric UI locking can prevent.
- Phase 3 Electron renderer and MCP clients are untrusted inputs. Domain validation and repository constraints remain mandatory.

## Local data

- Store the database, managed receipt assets, and backups only in sandbox-managed directories with iOS Data Protection (`CompleteUntilFirstUserAuthentication` or stricter where compatible).
- Database/asset files are owner-only on macOS (`0600` files, `0700` directories); verify permissions at startup and after restore.
- Store keys/tokens in Keychain, never SQLite, settings JSON, environment dumps, or logs.
- Exclude temporary OCR images from broad backups; delete them after import. Managed assets use opaque IDs and sanitized generated filenames, never user-provided paths.
- SQLite uses foreign keys, parameterized statements, bounded queries, and integrity checks. Never concatenate search strings into SQL.

## Application controls

- Re-authentication may guard opening the app, revealing receipt images, exporting, restoring, or enabling MCP writes.
- Clipboard and screen content should minimize sensitive persistence; obscure protected views in app-switcher snapshots.
- Validate backup schema, hashes, sizes, paths, currency scales, and IDs before any restore mutation.
- Native OCR is on-device by default. Any future cloud OCR requires a separate opt-in and privacy review.

## CloudKit and CKShare

Use Apple private/shared databases, least-privilege CKShare roles, and explicit participant revocation. Do not treat record ownership fields sent by a client as authorization. Account changes lock pending shared writes until identity is re-established.

## Electron and MCP (Phase 3)

- Electron: context isolation and sandbox enabled, `nodeIntegration=false`, restrictive CSP, allowlisted navigation, typed/allowlisted preload IPC, signed/notarized builds.
- MCP: stdio only, no listener; read-only defaults to true; explicit opt-in for writes; bounded inputs/results/time; `clientRequestId`, dry-run, audit logging, and domain validation on all writes.
- Environment variables configure policy but are not secrets. Avoid exposing DB paths or raw arguments in diagnostics.

## Logging and retention

Logs/audit details redact money, merchant, note, OCR text, receipt content/path, backup content, CloudKit tokens, and raw MCP inputs. Financial audit records retain identifiers/action/outcome durably; diagnostic logs use a bounded retention period and user-controlled deletion.

## Security acceptance

- Permission checks pass on fresh install, upgrade, restore, and asset creation.
- Biometric cancellation never corrupts data and is never the sole access-control check.
- SQL injection, malformed backup, path traversal, oversized asset/query, IPC abuse, MCP mutation-default, and secret/log leakage tests pass.
- Threat model is reviewed at each phase boundary and before enabling sharing or MCP writes.
