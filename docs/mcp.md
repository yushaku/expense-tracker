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

1. Turn on **Allow AI access** in Settings on Mac. MonMon writes the first local
   snapshot before granting consent.
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

## Data source and freshness

MonMon serializes the 16 domain models into a separate SwiftData SQLite snapshot
named `MonMonMCPSnapshot` in the flavour's App Group. The app replaces that
snapshot atomically after its main model context saves and when AI access is
enabled. The helper opens the snapshot without save permission. It has no
CloudKit entitlement, imports no domain model declarations, and never opens the
app's live SwiftData store.

Every response includes `sync.source`, `sync.freshness`, and `lastSnapshotAt`.
A snapshot no more than five minutes old is reported as `fresh`; an older one is
`stale`. The timestamp is the honest boundary: when MonMon is closed, MCP keeps
serving the last snapshot and cannot see changes made on another device until
MonMon runs on this Mac and receives them. iCloud Sync remains optional for the
app and is not required by MCP.

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
- **Stale data**: open MonMon on this Mac. If the change was made on another
  device, allow the app's optional iCloud Sync to receive it first.

The helper uses the official Swift MCP SDK pinned exactly to `0.12.1`:
<https://github.com/modelcontextprotocol/swift-sdk/tree/0.12.1>.
