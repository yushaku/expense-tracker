# Read-only MCP access

The macOS build embeds a local `stdio` MCP server at
`MonMon.app/Contents/Helpers/MonMonMCPServer`. It lets Codex and Claude Desktop
read raw MonMon records after the owner explicitly enables **Allow AI access**
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

The response envelope keeps `schemaVersion: "1.0"`, `records`, `page` and `sync`.
`sync.source` is now `localStore`; `sync.readAt` is the time the request read the
store. `fresh` means a successful direct read, not an assertion about another
device. `lastSnapshotAt` remains `null` for compatibility. `disabled` and
`unavailable` describe revoked access and a store that cannot be opened.
Pagination is a live view: concurrent writes between pages can change results;
clients needing a stable report should avoid editing during the read.

The reader uses Apple's [read-only ModelConfiguration](https://developer.apple.com/documentation/swiftdata/modelconfiguration/allowssave).

## Tools

The server exposes exactly 13 tools:

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

All are annotated read-only, non-destructive, idempotent, and closed-world. The
server offers no prompts, sampling, HTTP transport, or mutation tools.

Each successful response contains `schemaVersion`, `records`, `page`, and
`sync`, both as structured content and as a JSON text fallback. Decimal values
are exact decimal strings, dates are RFC 3339 UTC, UUIDs and enums use raw
strings, and missing values are JSON `null`. Stored JSON/Data snapshots are
decoded into objects or arrays without adding derived totals, forecasts,
progress, or financial advice.

Pagination defaults to 50 records and accepts at most 200. Opaque cursors use a
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
