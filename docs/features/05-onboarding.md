# Feature: Onboarding

## Flow

1. “Chào mừng” — explain offline local storage and phased sync accurately.
2. Select locale/timezone and base currency (VND at Phase 1 launch).
3. Create the first wallet; credit-card setup asks for limit and optional opening debt.
4. Choose “Bắt đầu trống” or “Thêm dữ liệu mẫu”.
5. Optionally enable Face ID as a privacy gate with a clear OS-passcode fallback explanation.

Sample wallets and transactions persist `isSample = 1` on their canonical entities and use the normal ledger/write path. “Xóa dữ liệu mẫu” voids/removes only sample-owned operations safely and reconciles the ledger; it never identifies samples by amount, date, or hard-coded IDs.

## Copy constraints

Do not promise Mac, AI/MCP, iCloud, shared databases, or family features during Phase 1. Explain that backup files are sensitive and Face ID does not replace device/account security.

## Acceptance

- Skip/resume/relaunch is deterministic and idempotent.
- Sample creation/removal cannot affect user-created data.
- Currency/timezone choices populate exact domain values and timestamp offsets.
- VoiceOver, Dynamic Type, permission denial, and biometric fallback work in Vietnamese.
