# System: Security

> Auth, encryption, privacy

---

## Overview

Security model for each phase.

## Phase 1 — Local Only

### Threat Model

| Threat | Mitigation |
|--------|-----------|
| Unauthorized access to device | Face ID / system auth |
| Data at rest | iOS Data Protection / macOS FileVault |
| MCP exposure | Local-only, user-configured |

### App Lock

- **iPhone:** Face ID or passcode
- **macOS:** System authentication (Touch ID or password)
- Timeout: configurable (1min, 5min, 15min, never)

### Data Protection

- iOS: `NSFileProtectionComplete` for SQLite file
- macOS: FileVault encryption
- Keychain for sensitive data (not needed Phase 1)

### MCP Security

- Server runs locally only
- No network exposure
- Configured per user (not shared)
- `EXPENSE_MCP_READONLY` for analysis-only agents

## Phase 2 — CloudKit Sync

### iCloud Account

- User authenticated via iCloud
- Private database (only user can access)
- End-to-end encrypted (CloudKit default)

### Data in Transit

- HTTPS for CloudKit communication
- Certificate pinning (CloudKit SDK handles)

## Phase 3 — Family Sharing

### Authentication

- Email/password signup
- Or Sign in with Apple
- OAuth 2.0 / OpenID Connect

### Authorization

| Role | Permissions |
|------|-------------|
| Admin | Full control, invite/delete members |
| Member | View shared, edit own |
| Viewer | Read-only access |

### Data Isolation

- Private records: only visible to owner
- Shared records: visible to family members
- Join/leave: private stays, shared remains

## Audit Log

Track all mutations:

```
AuditLog
├── id: uuid
├── userId: string (or 'agent' for MCP)
├── action: enum [create, update, void, delete]
├── entityType: string
├── entityId: string
├── changes: JSON (before/after)
├── timestamp: ISO datetime
```

## Backup & Restore

### Export

- JSON format with metadata
- Optional password encryption
- Include all entities

### Import

- Schema validation
- Conflict detection
- Dry-run option

### Encryption (Optional Phase 2)

- User-provided password
- AES-256 encryption
- PBKDF2 key derivation

## Privacy

### Phase 1-2

- No data leaves device (except CloudKit sync)
- No analytics (or opt-in only)
- No third-party tracking

### Phase 3

- Family data shared per user consent
- Leave family removes personal data
- GDPR-compliant data deletion

## Vulnerability Considerations

| Vulnerability | Prevention |
|---------------|------------|
| SQL injection | Parameterized queries |
| Timing attacks | Constant-time comparison |
| Replay attacks | Idempotency keys |
| Data leakage | Strict access controls |
| Man-in-the-middle | HTTPS / certificate pinning |
