# Salary calculator

Settings opens a monthly VND Gross ↔ Net calculator for resident Vietnamese employees with contracts of at least three months. 2026 rules only, selectable January–June or July–December. Inputs: salary, dependants, region, full/custom insurance salary. Show employee insurance, deductions, taxable income, tax and take-home pay. Round final amounts to whole VND.

Use the oldest VND monthly Salary income rule (creation date, UUID tie break) to prefill Net. Saving opens the existing recurring editor with Net and preserves its schedule/account; without a match, prepare a monthly Salary income draft. Nothing persists until the editor saves.

Validate progressive bracket boundaries, insurance caps in both periods, reverse conversion and recurring draft preservation. Format lint, full Mac unit suite and iOS compile are required. No device install before an explicitly requested merge.

## Sources (checked 2026-09-09)

- [TopCV calculator](https://www.topcv.vn/tinh-luong-gross-net): reference flow, employee insurance rates 8%, 1.5%, 1%.
- [Government tax brackets](https://xaydungchinhsach.chinhphu.vn/quy-dinh-moi-ve-khau-tru-thue-thu-nhap-ca-nhan-119260703150410707.htm): monthly thresholds 10/30/60/100 million; rates 5/10/20/30/35%.
- [Government deductions](https://xaydungchinhsach.chinhphu.vn/quy-dinh-giam-tru-gia-canh-119260703144038062.htm): personal 15.5 million, each dependant 6.2 million.
- [July policy](https://media.chinhphu.vn/chinh-sach-moi-co-hieu-luc-tu-thang-7-2026-102260701102217495.htm): base salary rises from 2.34 to 2.53 million. Social/health cap: 20 times base salary.
- [Regional wages](https://baohiemxahoi.gov.vn/tintuc/Pages/hoat-dong-he-thong-bao-hiem-xa-hoi.aspx?CateID=0&ItemID=25677): 5.31/4.73/4.14/3.70 million by region; unemployment cap 20 times regional wage.

Estimate excludes tax-exempt allowances, other income/deductions, foreign-worker exemptions and employer contributions. Saved recurring amounts are Net, not payroll metadata.

## Validation

Swift-format lint, the full macOS unit suite and iOS SDK compile pass. Tests cover progressive boundaries, both insurance-cap periods, custom bases and dependants, inverse calculations, rule selection and draft application without modifying generation history. Physical UI acceptance follows the next explicitly requested merge into dev.
