# MonMon — asset-first green product showcase

The user selected a Nexora landing-page screenshot as the style reference.
Adapt its visual language to MonMon: a white/mint background, bold sans-serif
headline with emerald emphasis, two rounded calls to action, a large tilted
dashboard, soft shadows, and floating feature cards. Keep the established short
Vietnamese copy and interactive finance diagrams. The user clarified that asset
management is the main feature; jars are a supporting planning tool.

## Design choices

- Paper `#ffffff`, ink `#17162d`, muted text `#6b687d`, primary emerald `#087f63`, bright logo-inspired mint `#32d6a0`.
- System sans-serif supports Vietnamese; display weight 760 with tight spacing.
- Desktop hero uses a 46/54 split; on mobile copy precedes the product image.
- Existing capture, jar, asset and privacy diagrams retain their meaning with
  coordinated mint accents.
- Primary action scrolls to asset management. Secondary action opens
  an accessible image dialog; Escape and the close button dismiss it and restore focus.
- No fictional customers, ratings, release claims or App Store destination.

## Feature hierarchy

1. Asset management: hero, navigation, first feature section and closing CTA.
   Show accounts, term deposits, funds/ETFs, gold and coins, with cost basis,
   investment profit/loss and historical asset changes. The featured portfolio
   uses a proportionate allocation ring, five selectable asset groups and a detail
   panel tailored to each group. Sample holdings total 125 million VND; allocation
   is 20/40/24/12/4 percent. Cash and deposits do not imply unrealized market PnL.
2. Income/expenses: categories, accounts, transfers, recurring transactions,
   search/filtering and quick capture.
3. Daily/monthly reports: switch the illustrative report period to update the
   income, expenses, net difference and expense distribution together.
4. Debts: separate borrowed/lent examples with principal, payments and remaining.
5. Budget jars and goals: smaller section after the four core capabilities.

Report figures are fictional; expenses are summed from the visible bars. The day
example spends 485,000 VND with no income; the month spends 8,500,000 VND against
20,000,000 VND of income. Debt examples use principal minus recorded payments.
No example is persisted or connected to real financial data.

## Assets and content

`assets/icon.png` is the existing MonMon icon.
`assets/dashboard-concept-green.png` is the current green version of the generated marketing concept with fictional
figures. Both the image caption and dialog explicitly identify it as an illustration,
not a real screenshot of the current application. Native screenshots remain blocked
by the computer-use provider's permissions error after the user's restart.
`assets/savings-still-life.png` retains the earlier direction for reference but is
not used by the current page. The HTML embeds all essential assets for offline use.

## Delivery

Branch: `feat/monmon-landing-page`. Implementation is in an isolated worktree;
the shared checkout's other task and existing deletions are untouched.
Browser verification: 1440, 390 and 320 px; reference comparison: 1920 × 1301 px.
See `design-qa.md` for visual and interaction verification.
No merge, push or deployment is part of this change.

## Logo-aligned color revision

The user requested green as the primary color to match the existing MonMon logo.
Actions, headline emphasis, selected states, focus rings, charts, borders and
surfaces now use emerald/mint. Dark emerald supports white button text; pale mint
keeps the layout light. Negative PnL and categorical gold/coin colors stay distinct.
The generated dashboard was recolored with ImageGen and embedded in both hero and
image dialog. Previous source assets are retained for reference.
