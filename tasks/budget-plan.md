# Implementation Plan: Budget Core

## Outcome

Ship the first vertical slice in `BUDGET-CAPABILITIES.md`: a current-month
Plan-vs-Actual Budget destination backed by six customisable jars and existing
MonMon financial records.

## Dependency Graph

```text
Budget jar schema + category assignment
    |
    v
Default seeding + mutation rules
    |
    v
Pure monthly forecast and actual calculations
    |
    v
Budget dashboard + jar/category configuration
    |
    v
Complete backup/restore integration
    |
    v
Review + full non-Simulator gates
```

## Increment Strategy

1. Add failing tests for the six default jars and monthly calculation contract.
2. Add the minimal SwiftData model, seeding, category assignment, and pure engine.
3. Add the root Budget destination and accessible Plan-vs-Actual cards.
4. Add jar and category configuration with protected system roles.
5. Extend complete backup/restore coverage for every new stored value.
6. Review, simplify, and run full test, format, and compile-only build gates.

## Risks and Mitigations

- Recurring generation state must not erase forecast occurrences: calculate a
  month from the rule schedule and ignore `lastGeneratedAt`.
- Editing mappings must not silently rewrite transaction history: the MVP is a
  current-plan view and intentionally applies the current map to the month.
- Custom percentages may temporarily total below 100%: show the unallocated
  percentage and reject only totals above 100%.
- New SwiftData state must not disappear from backups: extend document, validator,
  service, and round-trip tests in the same branch.
- Five root destinations are dense on iPhone: keep labels compact and use the
  native tab bar; no custom Liquid Glass treatment.

## Completion Gates

- Focused Budget tests pass after every logic increment.
- Full macOS tests pass.
- Recursive strict Swift format lint passes.
- Compile-only iPhoneOS SDK build passes without a Simulator.
- Branch is committed but not merged, pushed, or installed on the phone.

