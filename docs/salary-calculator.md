# Salary calculator

Settings opens a monthly VND Gross ↔ Net calculator for resident Vietnamese employees with contracts of at least three months. Fixed July–December 2026 rules; there is no period selector. Inputs: salary, dependants, region, full/custom insurance salary. Show employee insurance, deductions, taxable income, tax and take-home pay. Round final amounts to whole VND.

## Personal salary profile

The SwiftData `SalaryProfile` table stores the agreed salary amount,
agreed Gross/Net basis, dependant count, calculation period, insurance region,
optional custom insurance salary and explicit recurring rule UUID. A fixed personal
UUID makes two devices' edits resolve as a normal sync conflict. Save and discard
are explicit; closing with unsaved changes asks before discarding.

No name is entered or required to save. The legacy name field is retained for
backup compatibility and defaults to `Salary` on new profiles. Salary and custom
insurance amounts use the same currency symbol, rounded font, trailing alignment
and field background as the app’s account and savings editors.

Opening any profile uses July–December 2026 rules, including profiles originally
saved for January–June. The next successful save records the current period;
backup validation can still read historical period metadata.

The calculator leads with estimated monthly take-home, groups agreed salary and
insurance inputs, and shows a separate deduction breakdown. Gross/Net describes
the employment agreement and is retained when the calculated Net is sent to a
recurring rule. Additional allowances, bonuses and payroll adjustments are not
modeled by this version.

## Recurring salary

Choose a specific monthly VND income rule, or create a new Salary rule. There is
no automatic first-rule selection. An explicit import action can copy a selected
rule's amount into the profile as Net. Saving profile changes does not update the
rule or historical transactions.

After saving the profile, review the Net update in the recurring editor. The
existing account, schedule, pause state and generation history are preserved.
The rule and profile link save together. Cancel makes no changes; save failures
restore the old link. If recording due entries fails after the rule committed,
retry edits that same rule instead of creating another. A removed or repurposed
rule is shown as unavailable and never silently replaced with another rule.

## Backup and sync

Profiles participate in financial backup, restore, reset and Device Sync. Old
backups without the new array retain their original checksums and restore with
no salary profile. Reset saves the profile in its recovery backup before removal.
Recurring UUID aliases are remapped during sync. A missing linked rule is allowed
as a weak reference so deleting a rule cannot destroy its salary profile.

Sync hello version is now 3; both devices need the updated app to sync. The store
change is additive; an on-disk migration test verifies existing accounts survive.


Validate progressive bracket boundaries, insurance caps in both periods, reverse conversion and recurring draft preservation. Format lint, full Mac unit suite and iOS compile are required. No device install before an explicitly requested merge.

## Sources (checked 2026-09-09)

- [TopCV calculator](https://www.topcv.vn/tinh-luong-gross-net): reference flow, employee insurance rates 8%, 1.5%, 1%.
- [Government tax brackets](https://xaydungchinhsach.chinhphu.vn/quy-dinh-moi-ve-khau-tru-thue-thu-nhap-ca-nhan-119260703150410707.htm): monthly thresholds 10/30/60/100 million; rates 5/10/20/30/35%.
- [Government deductions](https://xaydungchinhsach.chinhphu.vn/quy-dinh-giam-tru-gia-canh-119260703144038062.htm): personal 15.5 million, each dependant 6.2 million.
- [July policy](https://media.chinhphu.vn/chinh-sach-moi-co-hieu-luc-tu-thang-7-2026-102260701102217495.htm): base salary rises from 2.34 to 2.53 million. Social/health cap: 20 times base salary.
- [Regional wages](https://baohiemxahoi.gov.vn/tintuc/Pages/hoat-dong-he-thong-bao-hiem-xa-hoi.aspx?CateID=0&ItemID=25677): 5.31/4.73/4.14/3.70 million by region; unemployment cap 20 times regional wage.

Estimate excludes tax-exempt allowances, other income/deductions, foreign-worker exemptions and employer contributions. Saved recurring amounts are Net, not payroll metadata.

## Validation

Swift-format lint, the full macOS unit suite and iOS SDK compile pass. Tests cover progressive boundaries, both insurance-cap periods, custom bases and dependants, inverse calculations, explicit rule linkage and draft application without modifying generation history. Physical UI acceptance follows the next explicitly requested merge into dev.

Profile tests also cover agreed-basis persistence, invalid-input rejection, atomic Net/link saves, retained-model rollback, sync write locks, legacy backup checksums, reset recovery, UUID remapping and on-disk migration/reopening.

Regression coverage includes name-free save/reopen/export and current-period calculations for legacy profiles, with old metadata preserved if saving fails.
