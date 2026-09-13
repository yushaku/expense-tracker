# Read-only MCP access

The macOS build embeds a local `stdio` MCP server at
`MonMon.app/Contents/Helpers/MonMonMCPServer`. It lets Codex and Claude Desktop
read MonMon records and period summaries after the owner explicitly enables **Allow AI access**
in Settings. The helper can run while the MonMon window is closed or App Lock is
engaged.

This is a separate privacy boundary. App Lock hides the app UI; it does not
revoke MCP consent. An AI client may send tool results—including notes and
pending captures—to its model provider. Turning AI access off removes the
consent marker before attempting any client cleanup, so a leftover client entry
cannot read data.

## Setup

1. Turn on **Allow AI access** in Settings on Mac. MonMon registers the location and schema of its existing local
   store before granting consent.
2. Confirm replacement only if MonMon reports an existing entry with the same
   name or an old helper path.
3. Restart Codex or Claude Desktop. Both clients load local MCP configuration at
   startup.

Debug registers `monmon-dev`; Release registers `monmon`. MonMon uses
`codex mcp get --json`, `codex mcp add`, and `codex mcp remove` for Codex. For
Claude Desktop it atomically changes only the matching entry under `mcpServers`
in `claude_desktop_config.json`, preserving all other configuration.

If the app was moved after setup, Settings shows **Repair needed**. Repair writes
the current embedded-helper path. A malformed Claude configuration is never
overwritten automatically.

## Direct local-store reads

The embedded helper executes the same app binary with `--mcp-stdio`. This mode
starts only the MCP server, before SwiftUI or `MonMonApp.init`: it does not open
windows, seed data, run recurring rules, or start synchronization. The helper
therefore uses the exact same domain models as the app without duplicating them.
It remains a separate process managed by the AI client and works while MonMon
is closed.

After the app opens its store, it registers only the store URL, schema and Core
Data model hashes in the flavour's App Group defaults. Every data request checks
consent, validates that registration against the current schema and store metadata,
and opens a new `ModelContainer` with `allowsSave: false` and CloudKit disabled.
A missing store or incompatible schema fails closed rather than creating a new
store. Only the normal app initializes or upgrades data. Open the matching app
once after upgrading to register the current store. Old MCP snapshot files are
removed when the store is registered or access is disabled.

Reads include committed changes from imports, capture and other contexts without
an export step. Unsaved edits are excluded. ID and date filters run in the database;
remaining field filters, stable ordering and cursor pagination run on the selected
records in memory. No data snapshot is created after a save.

The response envelope keeps `schemaVersion: "2.0"`, `records`, `page` and `sync`.
`sync.source` is now `localStore`; `sync.readAt` is the time the request read the
store. `fresh` means a successful direct read, not an assertion about another
device. `lastSnapshotAt` remains `null` for compatibility. `disabled` and
`unavailable` describe revoked access and a store that cannot be opened.
Pagination is a live view: concurrent writes between pages can change results;
clients needing a stable report should avoid editing during the read.

The reader uses Apple's [read-only ModelConfiguration](https://developer.apple.com/documentation/swiftdata/modelconfiguration/allowssave).

## Tools

The server exposes 14 financial read tools:

- `monmon_summary`
- `monmon_data_status`
- `monmon_list_accounts`
- `monmon_list_transactions`
- `monmon_list_transfers`
- `monmon_list_categories`
- `monmon_list_recurring_rules`
- `monmon_list_budget_jars`
- `monmon_list_goals`
- `monmon_list_trips`
- `monmon_list_savings`
- `monmon_list_investments`
- `monmon_list_debts`
- `monmon_list_pending_captures`

These financial tools are annotated read-only, non-destructive, idempotent, and
closed-world. The server offers no prompts, sampling, HTTP transport, or financial
mutation tools. Separate research tools are described below.

Each successful response contains `schemaVersion`, `records`, `page`, and
`sync`, both as structured content and as a JSON text fallback. Decimal values
are exact decimal strings, dates are RFC 3339 UTC, UUIDs and enums use raw
strings, and missing values are JSON `null`. Stored JSON/Data snapshots are
decoded into objects or arrays without adding derived totals, forecasts,
progress, or financial advice.

Financial list pagination defaults to 50 records and accepts at most 200. Opaque cursors use a
stable descending business-date then UUID order. Invalid arguments and cursors
return a safe structured error; paths, stack traces, notes, and amounts are not
written to operational logs.

## Troubleshooting

- **Not installed**: install the client, return to Settings, and toggle access
  again.
- **Needs confirmation**: inspect the existing same-name entry, then approve or
  cancel replacement.
- **Repair needed**: the app or helper path changed; choose Repair and restart
  the client.
- **Store unavailable**: open the matching Dev or Release MonMon app once after
  an upgrade. If needed, turn AI access off and on to register its current store.
- **Missing changes from another device**: finish MonMon synchronization first;
  MCP reads this Mac’s committed data and does not initiate synchronization.

The helper uses the official Swift MCP SDK pinned exactly to `0.12.1`:
<https://github.com/modelcontextprotocol/swift-sdk/tree/0.12.1>.

## Research notes and investment proposals (Mac)

Settings → AI access → Research & proposals opens the local notebook. Enable
**Allow AI to create research and proposals** separately after enabling AI read
access. Both permissions are required to create drafts. Turning AI access off
also clears draft-writing consent; it does not delete the owner's notebook.

There are six additional tools (19 total):

| Tool | Purpose |
| --- | --- |
| `monmon_list_notes` | Paginated note summaries (`limit` 1–100, `cursor`) |
| `monmon_get_note` | Full note, sources and research/review times by UUID |
| `monmon_create_research_note` | Create an immutable, sourced research note |
| `monmon_list_proposals` | Paginated proposals with latest user decision |
| `monmon_get_proposal` | Full proposal, decision history and `needsReview` |
| `monmon_create_investment_proposal` | Create a draft for review, never a financial transaction |

The two create tools have `readOnlyHint: false`; all financial tools remain
read-only. There is no tool to accept a proposal, forge a user decision, trade,
transfer money or modify the financial database. Source pages are not fetched by
MonMon: research is performed by the connected agent using its own tools.

### Schemas

- **ResearchNote**: `id`, `title`, `content`, `sources` (title, HTTP(S) URL,
  accessedAt), optional `instrumentID`, `researchedAt`, `reviewAfter`, `createdAt`.
- **InvestmentProposal**: `id`, `title`, `action` (`buyFund`, `saveCash`,
  `holdCash`), `target` (fund/product/bank and term as appropriate), `amount`
  (positive exact decimal string), `currencyCode` (VND), `rationale`, `risks`,
  `assumptions`, `alternatives`, `noteIDs`, `financialDataReadAt`, `validUntil`,
  `createdAt`. Its initial status is always `draft`.
- **DecisionRecord**: `id`, `proposalID`, `decision` (`accepted`, `deferred`,
  `rejected`), `reason`, `createdAt`. Only the app's review screen appends these.
  Acceptance is intent, not execution; no transaction link is inferred.

Create requests use a UUID `requestID` which becomes the record ID. Reuse it
with identical fields after a timeout: retries return the original record.
Different content under an existing ID is rejected, including after the user
has reviewed a proposal. Corrections require a new draft. A proposal must link
to existing, unexpired research; expired proposals or research cannot be accepted.
Dates in MCP responses are ISO 8601. Source claims and `financialDataReadAt` are
agent-supplied provenance, not independent verification or a guarantee that the
owner's finances have not changed since. The app shows these times for review.

### Agent workflow

1. Read the needed financial records through the read-only tools. Retain their
   `sync.readAt` and ask the owner for missing risk tolerance, time horizon and
   liquidity needs rather than inventing them.
2. Research current product information using primary sources. Save a research
   note with actual source URLs, access times, assumptions and a review deadline.
3. Create a proposal referencing the returned note ID(s), explicitly stating
   the target product, amount, reasoning, risks and alternatives. Copy the
   financial response's `readAt` to `financialDataReadAt`.
4. The owner refreshes Research & proposals and records a reason with Accept,
   Defer or Reject. The agent can read the resulting history, but must not treat
   acceptance as permission for an external purchase or a completed transaction.

The notebook is separate from the financial SwiftData store, under the flavour's
App Group (`ResearchNotebook/notebook.json`). Writes use an atomic replacement
and a nonblocking cross-process file lock. Malformed/unknown-version files are
never overwritten by a failed read. Storage is bounded at 20 MiB; a busy writer
returns a retryable error. List pagination uses creation time and ID cursors; new drafts do not shift subsequent pages.
No content is generated automatically by MonMon and no source URLs are opened
until the owner follows a link.

This first version is local to Mac and excluded from Device Sync and financial
backups. Use **Export research** to save an ISO-8601 JSON copy of notes, proposals
and decisions. Disabling AI access preserves the local notebook for the owner.

## MCP contract v2

Refresh the client's tool list after installing this version. The server reports `2.0.0`, and financial envelopes report `schemaVersion: "2.0"`.

- `monmon_data_status` accepts only `{}`. Accounts, categories and jars accept creation-time filters, not `dateFrom`/`dateTo`. Other lists document which business date they filter; their bounds remain inclusive.
- Each tool has a distinct description and advertised enum values. All financial tools (including summary) and research read tools publish `annotations.readOnlyHint: true`; the two research create tools publish `false`. These hints do not replace MonMon's consent checks or a client's own approval policy.
- Research lists now take `cursor` instead of `offset` and return `page: {limit, nextCursor, hasMore}`. Remove `offset` and `nextOffset` usage; start with no cursor, then reuse `page.nextCursor`. Cursors belong to one tool and order by creation time descending, then ID. Pagination is live, not an immutable snapshot.

### `monmon_summary`

Required `dateFrom` (inclusive) and `dateTo` (exclusive) are ISO 8601 timestamps with timezone. For September in Vietnam, use `2026-09-01T00:00:00+07:00` through `2026-10-01T00:00:00+07:00`. Pass an earlier end instant for month-to-date. Optional filters: `accountID`, `categoryID`, `budgetJarID`; optional `groupBy`: `none` (default), `category`, `budgetJar`.

Returns one Summary record in the standard envelope. `totals` contains `{currencyCode, income, expense, net, transactionCount}` per currency. `expenseGroups` contains the same amount fields plus `groupID` and `name` for expenses only; missing categories/jars use null identifiers or names. No matching transactions yields empty arrays. Amounts are exact decimal strings; currencies are never combined or converted. Decimal overflow fails instead of returning a rounded total.

Only saved MoneyTransaction records count. Transfers, pending captures, recurring schedules, deposits, withdrawals, fund purchases and sales are excluded. Jar grouping reuses the app's transaction routing (valid trip override, category mapping, fallback jar). `budgetJarID` selects expenses only. This is transaction spending, not budget allocations, account balances, or the Budget screen's savings/investment usage.

Development certificates remain appropriate for local Dev installs. Distribution to other Macs requires a separate Developer ID signing/notarization release flow; this change does not alter signing.
