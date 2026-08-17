# Feature: Family Sharing (Phase 3)

Family sharing uses Apple CloudKit `CKShare`; no custom backend, credentials, invitations, or ACL tables are authoritative.

## Model

An owner shares a wallet/family CloudKit zone. CKShare and participant records determine identity, role, read/write permission, invite status, and revocation. Local `ShareReference` rows cache CloudKit identifiers/status for UI and sync but never grant authority.

Shared scope includes explicitly selected wallets and their operations, ledger entries, categories, budgets, recurring rules/occurrences, receipt assets, and audit references. Private wallets and unrelated settings remain in the owner’s private zone. UI labels shared data and actor attribution in Vietnamese.

## Operations

- Owner creates a CKShare and sends the system invitation.
- Participant accepts through Apple flow; app verifies account and permission before syncing.
- Writes pass CloudKit permission checks and normal domain/idempotency rules.
- Revocation/leave stops future access, cancels pending unauthorized writes, and removes local shared projections/assets after safe confirmation/cache policy.
- Ownership transfer and deletion follow supported CloudKit semantics; the app does not emulate them.

Financial conflicts remain immutable-operation based. Transfers touching private and shared scopes require an explicit supported bridge operation or are rejected; data is never partially copied.

MCP family reads/writes require an explicit share/wallet scope. Read-only default, dry-run, durable request IDs, and audit attribution still apply.

Acceptance covers owner/read-only/read-write roles, invite/decline, offline write then revoke, account switch, asset permission, duplicate operations, private-data isolation, transfer boundary, participant removal, backup disclosure, and clean-device rebuild.
