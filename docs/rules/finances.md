# Taxes and finances

Status: all budget items recovered; tax and justice income checked against the savegames
(165 of 203 records exact – the others changed the sliders after the yearly calculation).

## The yearly budget (PlayerTurnStart)

```
income_buildings  = IncomeFromBuildings                     (0x6b)  see buildings.md
trade_income      = TradeAgreementIncome                    (0x6f)
tax_income        = TaxIncome                               (0x73)
justice_income    = JusticeIncome                           (0x77)
army_pay          = ArmyPay                                 (0x7b)  subtracted
rent_and_interest = WarehouseRent + Interest                (0x7f)
event_money       = from this year's event                  (0x83)

net_income = income_buildings + trade_income + tax_income + justice_income
           − army_pay + rent_and_interest + event_money        (0x87)
taler += net_income
```

Every item is also added to a running total (0x93 … 0xc3) for the statistics dialogs.
Land trades (0x8f), goods sales (0x97) and building purchases (also in 0x93) are booked
during the turn.

## Items

```
TaxIncome     = min(round(population × (tax_rate − 0.09) × 11), population × 2)
JusticeIncome = min(round(population × (justice − 0.06) × 7), population × 3 / 2)
TradeAgreementIncome = Σ over players j with trade_agreement[j]:
                       (mills_j × 330 + markets_j × 155) / (num_players + 6)
ArmyPay       = Σ TUnit.pay over army1 and army2
WarehouseRent = WarehouseFreeSpace / 10
Interest      = taler × 0.025 if taler > 0, else taler × 0.078   (debt costs 7.8 %)
```

- Taxes below 9 % and justice below 6 % cost money (negative income).
- Taxes and justice lower happiness one to one (see population-grain.md); harsh justice
  also drives emigration.
- A trade agreement pays the more, the bigger the partner's economy – which is why the
  weaker partner profits most (manual).

## "Einnahmen maximieren" – MaximizeTaxes (1068:1e29)

If `maximize_taxes` is set, at the start of each turn the game tries every combination of
tax and justice in steps of 10 % (0 … 100 %), computes building + tax + justice income and
the resulting happiness, and keeps the best combination whose happiness is at least 0.3.

## Bankruptcy – Bankruptcy (1010:4f9f)

At the end of a turn with too much debt, buildings are seized one type after another and
sold at list price (`BuildingPrices`) until the debt is covered; fame − 7, dialog
`BANKPFANDDLG`. It is triggered when `taler ≤ −CreditLimit` (below); the exact seizure order
is not yet confirmed.
A milder variant (`BANKGNADENDLG`, "die Gläubiger … gewähren Euch noch …") gives a
grace period.

## Credit limit – CreditLimit (1068:1df2)

`CreditLimit = (title + 7) × 1000`. Grain, land and caravan purchases may push the treasury
down to −CreditLimit; bankruptcy (above) is triggered at the end of a turn when
`taler ≤ −CreditLimit`. This is the manual's "a higher title allows higher debts".
