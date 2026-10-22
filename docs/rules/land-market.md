# Land, market and goods

Status: formulas from the code (constants via `tools/ghidra/disasm.py`); prices checked
against the 30 savegames (188–198 of 203 records within the formula's random range; the
rest changed stocks or land during the turn).

## Game start – InitPlayers (1068:01c1)

| | Humans | Computer players |
|---|---|---|
| title | 0 (Herr) | 0, or 7 on difficulty 4 (Absolutist) |
| taler | 1000 | 1000 (10000 on Absolutist) |
| land | 10000 ha | 10000 (30000 on Absolutist) |
| population | 1000 | 1000 (3000 on Absolutist) |
| spell | chosen (witch dialog) | Random(12) + 1 |
| other | report_flags = 0x27 | Absolutist: 25 markets, 25 mills, fame 70 |

For everyone: happiness 1.0, tax 10 %, birth/death 0.01, grain 5000, 1 granary,
1 warehouse if goods trade is enabled, 2 weapons, `land_price` 17 + Random(15),
`grain_price` 20 + Random(100), lifetime 60 + Random(20), attitude 100 towards every player
(+0x6c1, diplomacy). Finally the human players are shuffled into random order.

Cheat: with `census_editor_enabled`, a human named **Alchimisten** or **Berserker** starts as
König (title 9) with 999,000 Taler.

## Land

Every player brings 100,000 ha into the world; land nobody owns is "unclaimed".

```
UnclaimedLand    = max(0, num_players × 100000 − Σ land)                       ; 1068:2f86
FreeBuildingLand = (land − land_used) − 1000 × max(count of any building type)  ; 1068:2e4c
s = UnclaimedLand / num_players / 100000
land_price = clamp(round(1 / (s⁴ + 0.01)) + 15 − FreeBuildingLand / 2000, 17, 60) + Random(16)
```

Each building type can have one building per 1000 ha of farmland. Trading in `LANDDLG`
(`LandDlg_Trade` 1040:83c5), price per 10 Hufe:

```
sell n Hufen:  land −= n; taler += n × (land_price − 1) / 10
               (only if at least 2000 Hufen of free land remain)
buy  n Hufen:  land += n; taler −= n × land_price / 10 + 1
               (allowed into debt down to −CreditLimit = −(title + 7) × 1000)
total_land_trade (0x8f, running total) += the money
```

Afterwards `BuildingsLostForLand` (1068:22c0) removes buildings that no longer fit
(dialog `VERLUSTDLG`). Event 3 ("Erbschaft") and conquest also change land.

## Grain market

`UpdateGrainPrice` (1068:2a08), every turn:

```
grain_price = round((RandomReal × 20 + 20) × (6 − harvest_quality) / 3 + 30)
```

Quality 5 → 37–43, quality 1 → 63–97. Grain is bought and sold in `KORNDLG`; the price is
per gross ("Preis a gros" = 144 units): trading n grain costs/earns `n × grain_price / 144`,
buying adds 1 Taler, every trade is at least 1 Taler; purchases may go into debt down to
−CreditLimit. Running total: `total_grain_trade` (0x8b).

## Goods (needs `goods_trade_enabled`, header 0x13)

Stocks `salt`, `beer`, `wine`, `weapons`; space = `warehouses × 1000` (`WarehouseFreeSpace`).

### Production – ProduceGoods (1068:0c22), every turn

```
k = happiness × (1.25 with Bienenfleiß)
north (CountryProducesWine[country] = 1): salt += min(round(population / 25 × k), free space)
south (= 3):                              wine += min(round(population / (320 − 20 × harvest_quality) × k), free space)
brew_beer: beer = round(grain / 100 × k), limited via population (see code), ≤ free space;
           grain −= 100 × beer
weapons  += min(smithies, min(population div 2000, land div 20000) + 1), ≤ free space
```

North (salt): Sachsen, Holstein, Preußen, Thüringen, Westfalen, Böhmen.
South (wine): Hessen, Bayern, Baden, Franken.

### Prices – UpdateMarketPrices (1068:2a77), every turn, per player

```
price_salt    = max(10 − salt / 100, 5)                                 + Random(6)
price_beer    = max(25 + (6 − harvest_quality) × 7  − beer / 50, 25)    + Random(11)
price_wine    = max(70 + (6 − harvest_quality) × 10 − wine / 50, 70)    + Random(11)
price_weapons = max(560 − weapons × 2, 300)                             + Random(41)
```

Large own stocks depress the own selling price; bad harvests raise beer and wine prices.

### Prokurist (1068:1bf9), every turn

For each good with `prokurist_<good>` set and `price ≥ prokurist_min_<good>`:
`taler += stock × price`, `total_goods_sales += …`, stock = 0.

### Caravans – TradeCaravan (1040:08a2)

With goods trade enabled, a caravan (salt, beer, wine or weapons) visits with probability
`1 / (20 − fame / 10)` per turn and offers goods at a random price; the second and third
offer are 1 and 2 Taler cheaper per Last. Exact price formulas: `docs/functions/seg09.md`.

## Building prices (DS:5b10, longint)

market 1000, mill 2000, palace part 5000, cathedral part 9000, granary 2500,
warehouse 4000, university part 4000, tavern 2000, smithy 2500.
