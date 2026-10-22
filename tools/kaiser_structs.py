"""Single source of truth for Kaiser's record layouts.

Used by tools/ksr.py (savegames), tools/field_index.py and the Ghidra
struct script. Each field: (offset, type, name, evidence).
Types: u8 s8 u16 s16 s32 real (6-byte Real48) cstrN rawN.
Names ending in '_q' are hypotheses that still need confirmation.
"""

# Global game record, DS:6108, 0x295 bytes (= savegame header)
HEADER = [
    (0x00, 'u8', 'magic', 'set to 0x7B before saving, checked on load'),
    (0x01, 'u8', 'num_players', 'load/save loop bound'),
    (0x02, 'u8', 'human_players',
     '2 in NILSLARS (Nils+Lars), 1 in solo saves; decremented when a human '
     'is eliminated; e-mail mode ends below 2'),
    (0x03, 'u8', 'current_player',
     'index into the player array in every menu handler'),
    (0x04, 'u8', 'census_editor_enabled',
     'Ctrl+P opens the CENSUSDLG cheat editor only when set; high scores '
     'only count when 0'),
    (0x05, 'u8', 'last_human',
     'NextPlayer stores the human who just moved; e-mail mode hands the game over when the next human differs'),
    (0x06, 'u8', 'war_target_q',
     'other player of a pending war/battle (CpuTurn, EmailGameStep)'),
    (0x07, 's16', 'year', 'CmBeenden passes year + 1400 (0x578) on'),
    (0x0a, 'u8', 'game_state',
     '1 = game running (checked by all menu handlers); 3, 5 seen too'),
    (0x0b, 'u8', 'email_game_q',
     'when set: RandSeed stored in the save, extra block, turn hand-over'),
    (0x0e, 's32', 'rand_seed', 'Random($FFFF) at save time'),
    (0x12, 'u8', 'no_ageing_q',
     'when set: no elimination by lifetime and no fortune-teller events (option?)'),
    (0x13, 'u8', 'goods_trade_enabled',
     'DS:611b: goods production, Prokurist, caravans, warehouses at start'),
    (0x14, 'u8', 'tactical_battles_q',
     'initiative points only accumulate when set (UpdateInitiative)'),
]

# Player record, array at KaiserWindow+0x41, stride 0x6d5
PLAYER = [
    (0x000, 'cstr25', 'name', 'player name, zero-padded char[25]'),
    (0x019, 'u8', 'title',
     '0..10 = Herr..Kaiser (table DS:4556); 10 -> Victory'),
    (0x01a, 's16', 'fame',
     'Ruhm 0..100: bankruptcy costs 7 (1068:305b), losing a finished '
     'palace/cathedral part 10/20, ability Glanz und Gloria +1'),
    (0x01c, 'u8', 'spell',
     'chosen spell, table DS:497c: 0 Nichts .. 7 Gaias Segen (harvest '
     'quality 3-5), 9 Heldentum (troop ranks at start), 12 Terror'),
    (0x01d, 'u8', 'flag_1d_q', 'selects one of two messages on elimination'),
    (0x01e, 'u8', 'cpu_level',
     '0 = human; 3-6 in saves for computer players (difficulty?). '
     'NextPlayer runs CpuTurn when != 0; only humans get high scores'),
    (0x01f, 'u8', 'v1f_q', 'Random(6)+1 at game start'),
    (0x020, 'u8', 'skip_turn',
     'NextPlayer skips the player once and clears it (AUSSETZDLG)'),
    (0x022, 's16', 'lifetime',
     "ruler's remaining years: -1 every PlayerTurnStart, < 1 -> player "
     'eliminated; the fortune teller (events 21/22) reads it; checksum salt'),
    (0x024, 'u8', 'event',
     "this year's event 0..23, see docs/rules/events.md (dialog 300+n)"),
    (0x025, 'u8', 'country', 'country 0..9 (DS:477e); north = salt, south = wine'),
    (0x026, 's32', 'check_a', 'lifetime + (taler - land), recomputed on load'),
    (0x02a, 's32', 'population',
     'pop + births - deaths + immigrants - emigrants, min 50'),
    (0x02e, 'real', 'birth_rate', 'births = round(pop * birth_rate)'),
    (0x034, 'real', 'death_rate', 'deaths = round(pop * death_rate)'),
    (0x03a, 'real', 'happiness',
     'Zufriedenheit 0..1: multiplies building income, drives migration'),
    (0x040, 's32', 'births', 'this year'),
    (0x044, 's32', 'deaths', 'this year'),
    (0x048, 's32', 'immigrants', 'this year, += pop * ImmigrationRate'),
    (0x04c, 's32', 'emigrants', 'this year, += pop * EmigrationRate'),
    (0x054, 's32', 'taler', 'money; += net_income every year'),
    (0x058, 'real', 'tax_rate', 'STEUERDLG slider "Steuern" / 100'),
    (0x05e, 'real', 'justice', 'STEUERDLG slider "Justiz" / 100 (gnaedig..brutal)'),
    (0x064, 'real', 'asylum_law', 'STEUERDLG slider "Asylrecht" / 100'),
    (0x06a, 'u8', 'maximize_taxes',
     'STEUERDLG checkbox "Einnahmen maximieren"; 1068:1e29 each turn'),
    (0x06b, 's32', 'income_buildings',
     '1068:19bd: markets/mills/taverns x random yield x happiness'),
    (0x06f, 's32', 'income_6f_q', '1068:1b26 (needs all players)'),
    (0x073, 's32', 'income_73_q', '1068:1cd8'),
    (0x077, 's32', 'income_77_q', '1068:1d60'),
    (0x07b, 's32', 'expenses_7b_q', '1068:27ac, subtracted'),
    (0x07f, 's32', 'balance_7f_q', '1068:2da4 + 1068:290e'),
    (0x083, 's32', 'event_money', 'gain/loss from this year\'s event'),
    (0x087, 's32', 'net_income',
     'income_buildings + 6f + 73 + 77 - expenses + 7f + event_money'),
    (0x08f, 's32', 'land_trade_money', 'this year, from LANDDLG'),
    (0x093, 's32', 'total_income_buildings', 'running total'),
    (0x097, 's32', 'total_goods_sales', 'running total (Prokurist)'),
    (0x09b, 's32', 'total_income_73_77', 'running total'),
    (0x0a3, 's32', 'total_income_6f', 'running total'),
    (0x0b3, 's32', 'total_expenses', 'running total (negative)'),
    (0x0bf, 's32', 'total_7f', 'running total'),
    (0x0c3, 's32', 'total_event_money', 'running total'),
    (0x0c7, 's32', 'check_c', '(taler + land) div 1000'),
    (0x0cb, 's32', 'land', 'Land (ha); farmland = land - land_used'),
    (0x0cf, 's32', 'land_used', 'not farmed: harvest uses land - land_used'),
    (0x0d3, 's32', 'land_price', 'per 10 Hufe, UpdateMarketPrices'),
    (0x0d7, 's32', 'markets', 'income 77+Random(155) each; price 1000'),
    (0x0db, 's32', 'mills', 'income 165+Random(330) each; stores 500 grain; price 2000'),
    (0x0df, 'u8', 'palace_parts', '12 = complete; price 5000 per part'),
    (0x0e1, 'u8', 'cathedral_parts', '12 = complete; price 9000 per part'),
    (0x0e3, 's32', 'granaries', 'stores 10000 grain; price 2500'),
    (0x0e7, 's32', 'warehouses', 'goods storage; price 4000'),
    (0x0eb, 'u8', 'university_parts', 'price 4000 per part'),
    (0x0ed, 's32', 'taverns', 'income 100+Random(200) each; price 2000'),
    (0x0f1, 's32', 'smithies', 'price 2500'),
    (0x0f5, 's32', 'salt', 'stock'),
    (0x0f9, 's32', 'beer', 'stock'),
    (0x0fd, 's32', 'wine', 'stock'),
    (0x101, 's32', 'weapons', 'stock; 2 at game start'),
    (0x105, 's32', 'price_salt', 'max(10 - salt/100, 5) + Random(6)'),
    (0x109, 's32', 'price_beer', 'max(25 + (6-q)*7 - beer/50, 25) + Random(11)'),
    (0x10d, 's32', 'price_wine', 'max(70 + (6-q)*10 - wine/50, 70) + Random(11)'),
    (0x111, 's32', 'price_weapons', 'max(560 - weapons*2, 300) + Random(41)'),
    (0x115, 's16', 'prokurist_min_salt', 'minimum price for auto-sell'),
    (0x117, 's16', 'prokurist_min_beer', ''),
    (0x119, 's16', 'prokurist_min_wine', ''),
    (0x11b, 's16', 'prokurist_min_weapons', ''),
    (0x11d, 'u8', 'prokurist_salt', 'auto-sell on'),
    (0x11e, 'u8', 'prokurist_beer', ''),
    (0x11f, 'u8', 'prokurist_wine', ''),
    (0x120, 'u8', 'prokurist_weapons', ''),
    (0x121, 's32', 'grain', 'stock: - distributed, - 5..15% loss, + harvest, capped'),
    (0x125, 's32', 'grain_distributed',
     'KORNDLG slider; need = pop*5; subtracted from grain at turn start'),
    (0x12d, 'u8', 'harvest_quality', 'Random 1..5 (3..5 with Gaias Segen)'),
    (0x12e, 's32', 'harvest', '1068:298f(harvest_quality, player)'),
    (0x129, 's32', 'grain_price', 'UpdateGrainPrice, from harvest_quality'),
    (0x132, 'u8', 'brew_beer', 'KORNDLG "Bier brauen"; default = goods trade enabled'),
    (0x133, 's32', 'check_b', 'lifetime + (land - taler)'),
    (0x137, 'u8', 'army1_count', 'units in 0x139.. (TUnit, 0x3d each)'),
    (0x138, 'u8', 'army2_count', 'units in 0x35e.. (TUnit, 0x3d each)'),
    (0x139, 'raw488', 'army1', '8 x TUnit; unit i at 0xfc + i*0x3d'),
    (0x35e, 'raw488', 'army2', '8 x TUnit; unit i at 0x321 + i*0x3d'),
    (0x583, 's8', 'initiative', 'battle initiative points, += fame/50 + 2 per turn'),
    (0x5bd, 'u16', 'flags_5bd_q',
     'temporary effects, cleared in PlayerTurnEnd (sabotage?): 0x800 grain '
     'loss + death rate, 0x40/0x80/0x100 happiness -0.18/-0.09/-0.07'),
    (0x5d1, 's16', 'deserted_units_q', '+1 when a unit deserts (event 8)'),
    (0x5f0, 'real', 'year_factor_q', 'RandomReal*1.5+0.5, set every turn'),
    (0x5f6, 'u8', 'report_flags',
     'reports opened at turn start, bit n = menu Berichte entry 701+n: '
     '0 gossip, 1 population, 2 budget, 3 intelligence, 4 goods, 5 grain, '
     '6 land, 7 buildings'),
]

# Army unit, 0x3d bytes (two arrays of 8 inside TPlayer)
UNIT = [
    (0x00, 'cstr25', 'name', 'e.g. hero name "Castor", "Holsteinische Ritter"'),
    (0x19, 'u8', 'type',
     'unit type = index into DS:4ac2 minus 10 (0 Miliz, 9 Held, ...)'),
    (0x2f, 'u8', 'ability',
     'special ability, 1-based index into DS:53f1 (21 Glanz und Gloria, '
     '24 Lehrmeister)'),
    (0x37, 'u8', 'flag_37_q', 'set to 1 for every unit at turn start'),
]
UNIT_SIZE = 0x3d

HEADER_SIZE = 0x295
PLAYER_SIZE = 0x6d5
EXTRA_SIZE = 0x192

# plain (offset, type, name) views for code that does not need evidence
HEADER_FIELDS = [(o, t, n) for o, t, n, _ in HEADER]
PLAYER_FIELDS = [(o, t, n) for o, t, n, _ in PLAYER]

# Functions whose parameter (index in Ghidra's order) is a TPlayer far *.
# apply_structs.py types and renames it 'player'.
PLAYER_PTR_PARAMS = {
    'UpdateHappiness': 0, 'UpdateBirthDeathRates': 0, 'ImmigrationRate': 0,
    'EmigrationRate': 0, 'IncomeFromBuildings': 0, 'ComputeHarvest': 1,
    'GrainCapacity': 0, 'UpdateInitiative': 0, 'MaximizeTaxes': 0,
    'Army1HasAbility': 1, 'Bankruptcy': 0, 'Do_SteuernFestsetzen': 0,
    'Do_KornVerteilen': 1,
}
