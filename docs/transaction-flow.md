# Transaction flow (tasks 14 and 15)

The ordinary Add Transaction screen offers a prominent Transfer between accounts action alongside the Income/Expense entry tabs. Quick Add is removed from this form; capture processing and pending review remain available through their existing entry points. Editing, capture review and trip-specific entry stay focused on their existing record.

Transfer uses the existing editor and balance validation. Cancel returns to the untouched income/expense draft; successful save closes both sheets to reveal history. Only an AccountTransfer is saved.

Main transaction history, day history and account history interleave transactions and transfers by occurrence date, creation date and stable typed ID. Transfer cards identify the source → destination, keep neutral unsigned amounts, and open the existing editor for editing/deletion. Transfer-only days are visible. No income/expense totals or balance calculations change.

All includes transfers. Income/Expense and category filters exclude them. Date filters apply to both kinds; account filters match either transfer endpoint. Text search matches notes, both account names, transfer labels and amount digits with existing case/diacritic folding.

Validation: format lint, full Mac unit suite and iOS SDK compile. Unit coverage includes entry boundaries, mixed chronological grouping, stable IDs, transfer-only days, neutral totals, and transfer filters/search. Physical acceptance follows an explicitly requested dev merge.

## Account management in Wealth

Wealth directly embeds the account allocation chart, individual account cards and Add Account action. Account cards open AccountDetailView within the Wealth navigation stack. The intermediate Accounts screen and Transactions shortcut are removed. There is no dedicated Transfers section or add-transfer action in Wealth; transfers remain in the shared transaction history and Add Transaction flow. Transfer data still contributes to account balances and allocation.
