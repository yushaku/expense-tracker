# Feature: Wallets

## User experience

Người dùng tạo ví tiền mặt, ngân hàng, ví điện tử hoặc thẻ tín dụng; xem số dư/nợ và lưu trữ ví không còn dùng. Currency is fixed after financial activity; changing it requires a new wallet.

Required fields are name, type, currency, and for credit cards `creditLimitMinor > 0`. Other wallets require a zero limit. Wallets with history are archived/voided, never cascade-deleted.

## Accounting

- Non-credit balance: sum of active signed ledger entries.
- Credit-card debt: active expenses posted to card minus payments posted to card.
- Available credit: `creditLimitMinor - debt`.
- Card payment is a transfer from a non-credit wallet to the card. Credit limit is not cash or an asset.
- Transfer requires different wallets, same currency in Phase 1, positive integer minor units, and two atomic ledger legs.

Phase 2 cross-currency transfer is two linked conversion operations with an immutable rate snapshot; it is never represented by unequal untraceable legs.

## Validation and acceptance

- Names are trimmed, 1–80 characters; currency is supported ISO 4217; opening amount parses exactly.
- UI labels card values “Dư nợ” and “Khả dụng”, not “Số dư tài sản”.
- Purchase, payment, refund, void, overpayment, and insufficient-funds policy tests match the ledger formulas.
- Archiving cannot orphan transactions, recurring rules, budgets, assets, or sync operations.

MCP exposure begins in Phase 3 only; wallet-scoped tools require `walletId`, write tools also require `clientRequestId` and `dryRun` support.
