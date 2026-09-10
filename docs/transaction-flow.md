# Transaction flow (tasks 14 and 15)

The ordinary Add Transaction screen offers Income, Expense and Transfer tabs. Transfer displays its form inline and preserves a separate draft when switching tabs. Quick Add is removed from this form; capture processing and pending review remain available through their existing entry points. Editing, capture review and trip-specific entry stay focused on their existing record.

Transfer uses the existing editor and balance validation. Cancel closes the add screen; successful save closes it to reveal history. Save acts on the selected tab. Only an AccountTransfer is saved.

Main transaction history, day history and account history interleave transactions and transfers by occurrence date, creation date and stable typed ID. Transfer cards identify the source → destination, keep neutral unsigned amounts, and open the existing editor for editing/deletion. Transfer-only days are visible. No income/expense totals or balance calculations change.

All includes transfers. Income/Expense and category filters exclude them. Date filters apply to both kinds; account filters match either transfer endpoint. Text search matches notes, both account names, transfer labels and amount digits with existing case/diacritic folding.

Validation: format lint, full Mac unit suite and iOS SDK compile. Unit coverage includes entry boundaries, mixed chronological grouping, stable IDs, transfer-only days, neutral totals, and transfer filters/search. Physical acceptance follows an explicitly requested dev merge.

## Account management in Wealth

Wealth directly embeds individual account cards and the Add Account action. The cash allocation donut is shown only on the standalone Accounts screen. Account cards open AccountDetailView within the Wealth navigation stack. Transactions also offers an Accounts shortcut, opening a standalone screen that reuses this same account-management content. There is no dedicated Transfers section or add-transfer action in Wealth; transfers remain in the shared transaction history and Add Transaction flow. Transfer data still contributes to account balances and allocation.

## Transfer form

Account selection comes first, using full-width source and destination controls, a centered icon-only Swap button. The opposite account is disabled in each picker. The amount card labels its input and shows the existing source-balance limit when applicable, including the edit adjustment. Date and optional note follow. Scroll gestures dismiss the keyboard.

## History interactions

Transactions and internal transfers share the same row gestures: swipe left to delete with a five-second Undo, swipe right to edit, and tap to view details. Transfer details show the amount, source, destination, date and note, with Edit and confirmed Delete actions. Undo preserves transfer IDs and both statement import fingerprints. The screen owns transfer sheets and Undo so removing a row does not remove its undo action.

Transfer and transaction details reuse the same amount header, bordered information card, icon rows and Delete/Edit action bar. Both open at medium height and expand to large. Transfer account rows link to their respective account details; missing accounts remain read-only.

Account detail uses a single date filter beside Edit in the navigation header. Its selected period controls both the report and history, including internal transfers; the report card displays the active period without its own filter.

Linked Investments displays the same savings-book and grouped-position cards as Investments, in Savings, Funds/ETFs, Gold and Crypto sections. Links include funding and cash withdrawals/sale proceeds, deduplicated by parent investment; swaps do not create cash-account links. Cards retain all withdrawal/sale data for accurate balances. Fund details stay scoped to the linked account; whole-instrument bulk closure is available only from the full Investments screen.

The account report uses bars for Net, Income and Expenses, with daily or monthly buckets matching the selected period.
