# Latvia tax engine

## Rule set

The first immutable rule set is `LV-2026-v1`, effective for the 2026 tax year and verified on 2026-11-05. Rules store the effective period, rates, allowances, thresholds, minimum wage, social contribution ceiling, and official source URLs. Unknown tax years fail explicitly so a new year cannot silently inherit old values.

Verified values for standard employment:

- Employee state social insurance contributions: 10.50%; employer: 23.59%.
- Monthly payroll tax withholding: 25.5% of monthly taxable income.
- Monthly non-taxable minimum: EUR 550; dependent allowance: EUR 250 per eligible dependent.
- Annual PIT: 25.5% up to EUR 105,300 of annual taxable income and 33% on the excess.
- Additional annual PIT: 3% of the relevant annual income above EUR 200,000.
- 2026 minimum monthly wage: EUR 780; maximum contribution base: EUR 105,300.

Sources:

- [VID: Personal Income Tax rates](https://www.vid.gov.lv/en/personal-income-tax-rates)
- [VID: Personal Income Tax and non-taxable minimum](https://www.vid.gov.lv/en/personal-income-tax)
- [VID: VSAOI rates](https://www.vid.gov.lv/lv/valsts-socialas-apdrosinasanas-obligato-iemaksu-likmes)
- [FM: non-taxable minimum and allowances](https://www.fm.gov.lv/en/non-taxable-minimum-and-tax-allowances)
- [VSAA: minimum mandatory social insurance contributions](https://www.vsaa.gov.lv/en/minimum-mandatory-state-social-insurance-contributions)
- [Personal Income Tax Law](https://likumi.lv/ta/en/id/56880-on-personal-income-tax)

## Monthly estimate

The calculator rounds each monetary intermediate to EUR cents using `Decimal` and `NSDecimalRound(.plain)`. For standard employment it computes employee VSAOI as gross × 10.5%, subtracts that and any applicable monthly allowances from gross to form a nonnegative PIT base, withholds 25.5% of that base, and calculates net salary. Employer cost is gross plus 23.59% employer VSAOI.

The tax booklet switch controls whether this employer applies the monthly minimum and dependent allowances. With the booklet off, allowances entered in the screen are not applied by this employer. The screen is an estimate for a full ordinary monthly payroll period.

## Annual estimate boundary

`LatviaAnnualTaxCalculator` accepts an already prepared annual taxable base and a separate total-income value for the additional 3% rate. It applies marginal PIT bands and the additional rate. It does not derive the taxable base from monthly payroll records, withheld amounts, deductions, tax credits, or multiple income sources, and it does not produce a tax return or final settlement.

## Not modeled yet

The current calculator does not model retirement-age or special employee VSAOI categories, solidarity-tax reconciliation, minimum social contribution reconciliation, partial months, irregular or multiple employers, sick leave, bonuses, income above the annual VSAOI ceiling, foreign social insurance, annual tax-booklet forecasting, eligible annual expenses, historical rule sets before 2026, or persisted salary profiles/calculation history. Add each future tax rule as a dated and sourced rule-set version with boundary tests before exposing it in the UI.
