# Apple Pay capture implementation

Status: user approved; implementation, automated verification and code review complete.
Physical Wallet acceptance remains pending with the owner after a requested dev merge.
Spec: `docs/apple-pay-capture-spec.md`. Tasks: `tasks/todo.md`.

Implement in three slices:
1. Validated Apple Pay events into the existing review/save service, with deterministic
   retry identity and in-memory persistence tests. No schema change.
2. Dedicated Shortcuts action with explicit fields/account, safe localized outcomes,
   and no foreground UI requirement. Compile metadata and test the dependency bridge.
3. Settings navigation, separate opt-in auto-save/account preferences, last result,
   concise setup and duplicate-source warning. Localize, run all gates, review and
   commit on `feat/apple-pay-capture`; stop before merge or device installation.

Risks: Wallet can omit fields or fail to deliver; never substitute guessed amounts.
Foreign/missing currency cannot be silently treated as VND. Retry identity is only
stable when the original timestamp is reused; bank-notification cross-source
deduplication is explicitly not claimed. User performs Wallet acceptance testing.

The completed P2P implementation plan below is retained for historical context.

---

# P2P sync implementation (completed)

Approved scope: one iPhone–Mac pair on the same LAN, explicit Sync and preview, union initial data, explicit record conflicts and missing-seed decisions. Financial records only; pending captures and device preferences stay local. No cloud or background sync.

Implement in order:
1. Durable seed initialization and pure three-way snapshot merge with tests.
2. SwiftData adapter, strict validation, durable session/receipts, restart recovery.
3. Bonjour + TLS PSK pairing and framed transfer; transport tests.
4. SwiftUI pairing/QR, conflict choices, preview, progress and history.
5. Integration, localization, migration/restore behavior and regression tests.

Quality gates: swift-format lint, macOS unit suite, iOS SDK compile; branch commit only. Physical iPhone testing follows an explicitly requested merge to dev.

Completed:
- Durable seed markers, stable recurring IDs, explicit duplicate/seed choices, and baseline-aware identity mapping.
- Financial snapshot adapter with shared write gate, local backups, atomic local data/receipt saves, and reconnect recovery.
- Bonjour TLS-PSK transport, QR/manual pairing, device-only Keychain trust, bounded framing, and wrong-key rejection.
- SwiftUI preview and approval on both devices, conflict details, recent history and recovery export; Vietnamese localization.
- Restore invalidates pairing; local drafts/preferences remain local and their references follow merged IDs.
- Independent bounded protocol review completed; consent bypass, mutable identity, swap-reference and seed-duplicate findings fixed.

Validation on 2026-09-06:
- `xcrun swift-format lint -r MonMon MonMonTests`: passed.
- macOS ARM64 unit suite: 1,171 passed, 0 failed, 0 skipped.
- iOS simulator SDK compile (arm64 and x86_64, no runtime launch): passed.
- Real localhost TLS tests passed, including rejection of an incorrect shared secret.
- Protocol tests cover both initiators, every interrupted boundary, receiver rejection, tampered proposals, and persistent store reopening.
- Physical iPhone UI/acceptance testing remains with the owner after an explicitly requested dev merge. No installation, merge, or push performed.
