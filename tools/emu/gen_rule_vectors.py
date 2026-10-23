"""Generate differential test vectors for ported rule functions.

For each vector: take a real savegame, pick a player, change a few fields at
random (to reach many branches), set RandSeed, call the ORIGINAL function in
the emulator and record its return value, out parameters, the new RandSeed
and every byte it changed in the player array and the game header.

Line format (space separated key=value):
  func=NAME save=FILE p=IDX seed=S args=a,b mut=off:hex;... hmut=off:hex;...
  -> ret=V out=a,b seedout=S2 diff=off:hex;... hdiff=off:hex;...
  (ret=E<code> if the original stopped with a runtime error)
Offsets in mut/diff are relative to the start of the player array, offsets
in hmut/hdiff to the start of the game header (DS:6108).

Usage: tools/.venv/bin/python -I tools/emu/gen_rule_vectors.py FUNC[,FUNC] N [SEED]
       > port/tests/rules.vec
"""
import glob
import os
import random
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))
from kaiser_emu import KaiserEmu, EmuError  # noqa: E402
from ui_stubs import UILayer, WINDOW  # noqa: E402
import kaiser_structs as ks  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
SAVES = sorted(glob.glob(os.path.join(ROOT, 'Kaiser', '*.KSR')) +
               glob.glob(os.path.join(ROOT, 'Kaiser', '*.ksr')))
HDR_DS = 0x6108
PSIZE = ks.PLAYER_SIZE
OUT_AREA = 0xF000          # scratch offset of out parameters (after the players)
ARMY_BASE = {1: 0xfc, 2: 0x321}   # unit i of army a at ARMY_BASE[a] + i*0x3d

# Arguments (Pascal order):
#   P      far pointer to the test player       A  pointer to the player array
#   N      num_players (byte)                   I  test player index (byte)
#   J      another player index 0..num-1        Q  harvest quality 1..5
#   U      pointer to army-1 unit K (1..8, shown) of the test player
#   UJ     pointer to army-1 unit K of player J (shown: J, K)
#   NIL    nil pointer
#   F:fld  pointer to a field of the test player
#   B:lo:hi / W:lo:hi / L:lo:hi   random byte / word / longint value
#   G:e    longint of random sign and magnitude 10^U(0, e) (log-uniform)
#   R      random Real48 value                  O  out longint (reported in out=)
#   OP     out far pointer, reported as offset into the player array
#   OB:n   pointer to an n-byte out record (zeroed), reported as hex
#   PJ     pointer to another player J != test player (J shown)
#   Wnd    the parent window pointer (UI calls log it as W)
#   RI / RJ  pointer to a byte holding the test player index / J (J shown)
# Return kinds: long, word, sword (signed 16), byte, real, none.
# An address 'nSEG:OFF' is a near procedure. Functions that open dialogs
# run with the UI layer (tools/emu/ui_stubs.py); UI_SCRIPTS decides what
# the dialogs answer, the calls are recorded in ui=.
# Mutations: player fields; 'u.FIELD' = that field of a random unit (both
# armies); 'U.FIELD' = that field of the unit passed as U; 'J.FIELD' = a
# field of player J; 'h.FIELD' = a
# header field. An optional 5th SPECS entry {field: (lo, hi)} clamps
# player fields (or 'U.field') after mutating (e.g. army counts that must
# not be 0).
POP = ['population', 'grain_distributed', 'spell', 'event', 'flags_5bd_q',
       'birth_rate', 'death_rate', 'happiness', 'tax_rate', 'justice',
       'asylum_law', 'fame', 'title', 'cpu_level', 'taverns', 'army1_count',
       'army2_count']
ECON = ['population', 'markets', 'mills', 'taverns', 'smithies', 'granaries',
        'warehouses', 'land', 'land_used', 'taler', 'tax_rate', 'justice',
        'happiness', 'spell', 'salt', 'beer', 'wine', 'weapons', 'title',
        'harvest_quality', 'grain', 'palace_parts', 'cathedral_parts',
        'university_parts']
GOODS = ['salt', 'beer', 'wine', 'weapons', 'price_salt', 'price_beer',
         'price_wine', 'price_weapons', 'prokurist_min_salt',
         'prokurist_min_beer', 'prokurist_min_wine', 'prokurist_min_weapons',
         'prokurist_salt', 'prokurist_beer', 'prokurist_wine',
         'prokurist_weapons', 'taler', 'warehouses', 'h.goods_trade_enabled']
ARMY = ['army1_count', 'army2_count', 'u.type', 'u.level', 'u.ability',
        'u.attack', 'u.defence', 'u.pay', 'u.base_pay', 'spell', 'fame']
BUILD = ['land', 'land_used', 'markets', 'mills', 'palace_parts',
         'cathedral_parts', 'granaries', 'warehouses', 'university_parts',
         'taverns', 'smithies', 'fame', 'grain', 'salt', 'beer', 'wine',
         'weapons']
SABOTAGE = ['taverns', 'spell', 'title', 'taler', 'sabotage_agents',
            'sabotage_agents_returning_q', 'sabotage_budget', 'sabotage_funds']
UNITF = ['U.type', 'U.level', 'U.experience', 'U.ability', 'U.range',
         'U.max_steps', 'U.attack', 'U.defence', 'U.max_hp', 'U.pay',
         'U.hero_portrait', 'spell', 'fame']
SPECS = {
    'GrainCapacity': ('1068:0885', ['P'], 'long', ECON),
    'SmithyOutput': ('1068:0bd3', ['P'], 'long', ECON),
    'WarehouseFreeSpace': ('1068:2ce7', ['P'], 'long', ECON),
    'FreeBuildingLand': ('1068:2e4c', ['P'], 'long', ECON),
    'CreditLimit': ('1068:1df2', ['P'], 'long', ['title']),
    'TaxIncome': ('1068:1cd8', ['P'], 'long', ECON),
    'JusticeIncome': ('1068:1d60', ['P'], 'long', ECON),
    'WarehouseRent': ('1068:2da4', ['P'], 'long', ECON),
    'Interest': ('1068:290e', ['P'], 'long', ['taler']),
    'IncomeFromBuildings': ('1068:19bd', ['P'], 'long', ECON),
    'ComputeHarvest': ('1068:298f', ['P', 'Q'], 'long', ECON),
    'ImmigrationRate': ('1068:17f3', ['P'], 'real', POP),
    'EmigrationRate': ('1068:18fa', ['P'], 'real', POP),
    'UpdateBirthDeathRates': ('1068:0ee4', ['P'], 'none', POP),
    'UpdateHappiness': ('1068:13a8', ['P'], 'word', POP),
    'UpdateGrainPrice': ('1068:2a08', ['P', 'Q'], 'none', ECON),
    'UnclaimedLand': ('1068:2f86', ['A', 'N'], 'long', ['land']),
    # batch 2
    'WarehouseCapacity': ('1068:08d5', ['P'], 'long', ECON),
    'CanAffordWithCredit': ('1068:0ae8', ['P', 'L:-20000:200000'], 'byte',
                            ['taler', 'title']),
    'GrainNeedMinMax': ('1068:0b2c', ['P', 'O', 'O', 'O'], 'none',
                        ['population']),
    'ComputeScore': ('1068:12fe', ['P', 'W:0:3', 'W:0:3'], 'long',
                     ECON + ARMY),
    'TradeAgreementIncome': ('1068:1b26', ['A', 'I', 'N'], 'long',
                             ['markets', 'mills', 'trade_agreement']),
    'Prokurist': ('1068:1bf9', ['P'], 'none', GOODS),
    'ArmyPay': ('1068:27ac', ['P'], 'long', ARMY),
    'ManoeuvreCost': ('1068:2850', ['P'], 'long', ARMY),
    'AddGoodsCapped': ('1068:2d4a', ['P', 'B:1:4', 'L:-1000:30000'], 'none',
                       GOODS),
    'ReduceByFraction': ('1068:2dcc', ['F:grain', 'R'], 'none', ['grain']),
    'FameDiscount': ('1068:3003', ['L:-50:150', 'L:-1000:100000'], 'long', []),
    'GainFame': ('1068:3040', ['F:fame', 'W:-200:200'], 'none', ['fame']),
    'LoseFame': ('1068:305b', ['F:fame', 'W:-200:200'], 'none', ['fame']),
    'IsFirstKing': ('1068:31c7', ['A', 'I', 'N'], 'byte',
                    ['title', 'first_king_bonus']),
    'UpdateInitiative': ('1068:3238', ['P'], 'none',
                         ['initiative', 'fame', 'spell',
                          'h.initiative_enabled']),
    'AttackInitiativeCost': ('1068:3282', ['B:0:9', 'B:0:9'], 'byte',
                             ['h.initiative_enabled']),
    'FiefSize': ('1068:4620', ['P', 'U'], 'long', ARMY),
    'HasAnyUnits': ('1068:5c15', ['P'], 'byte', ARMY),
    'ArmyStrength': ('1068:5c3c', ['P', 'B:0:1'], 'long', ARMY),
    'HasHero': ('1068:6290', ['P'], 'byte', ARMY),
    'FindHero': ('1068:6323', ['P', 'OP', 'B:0:1'], 'byte', ARMY),
    'Army1HasAbility': ('1068:63e4', ['P', 'B:0:38'], 'byte', ARMY),
    'CountUnitsOfType': ('1068:643b', ['P', 'B:0:35'], 'byte', ARMY),
    'ArtilleryClass': ('1068:64d6', ['P', 'B:0:1'], 'byte', ARMY),
    'HasDesertableUnit': ('1068:65c2', ['P', 'B:0:1'], 'byte', ARMY),
    'MaxLong': ('1068:69f1', ['L:-100000:100000', 'L:-100000:100000'],
                'long', []),
    'MinLong': ('1068:6a2b', ['L:-100000:100000', 'L:-100000:100000'],
                'long', []),
    'Chance': ('1068:6a65', ['L:-20:120'], 'byte', []),
    'SetBit': ('1068:6eec', ['F:report_flags', 'B:0:15'], 'none',
               ['report_flags']),
    'ClearBit': ('1068:6f23', ['F:report_flags', 'B:0:15'], 'none',
                 ['report_flags']),
    'TestBit': ('1068:6f52', ['B:0:255', 'B:0:15'], 'byte', []),
    # batch 3
    'MaximizeTaxes': ('1068:1e29', ['P'], 'none', POP + ECON),
    'CanBePromoted': ('1068:3076', ['P'], 'byte',
                      POP + ECON + ARMY + ['maximize_taxes']),
    'RemoveGranaries': ('1068:0900', ['P', 'L:-2:30'], 'none',
                        ['granaries', 'mills', 'grain']),
    'RemoveWarehouses': ('1068:09b4', ['P', 'L:-2:30'], 'none',
                         ['warehouses', 'salt', 'beer', 'wine', 'weapons']),
    'ProduceGoods': ('1068:0c22', ['P'], 'byte',
                     ECON + GOODS + ['country', 'brew_beer']),
    'BuildingsLostForLand': ('1068:22c0', ['P', 'OB:44'], 'byte', BUILD),
    'UpdateMarketPrices': ('1068:2a77', ['A', 'I', 'N', 'W:0:5'], 'none',
                           BUILD + ['harvest_quality']),
    'TransferLand': ('1068:41d5', ['P', 'PJ', 'OB:44', 'L:-1000:200000',
                                   'B:0:1'], 'none', BUILD),
    'SkipTurnLosses': ('1068:438c', ['P', 'B:0:1'], 'none',
                       ['land', 'taler', 'population', 'markets', 'mills']),
    'SabotageYearlyCost': ('1068:32b2', ['A', 'I', 'N'], 'long', SABOTAGE),
    'SabotageFunding': ('1068:3386', ['A', 'I', 'N'], 'none', SABOTAGE),
    'SabotageYearsToNextOp': ('1068:35c1', ['A', 'RI', 'RJ'], 'sword',
                              SABOTAGE),
    # batch 4
    'UnitGainExperience': ('1068:4671', ['U', 'OB:32', 'B:0:30', 'B:0:12'],
                           'byte', UNITF),
    'FillWithMilitia': ('1068:4b22', ['P'], 'none',
                        ['army1_count', 'population']),
    'GenerateMarauders': ('1068:4d7c', ['P', 'W:0:100'], 'none', []),
    'GenerateLindwurm': ('1068:506a', ['P'], 'none', ['spell', 'country']),
    'ClearUnit': ('1068:50c5', ['U'], 'none', []),
    'RemoveArmy1Unit': ('1068:50e2', ['P', 'B:1:8'], 'none', ARMY,
                        {'army1_count': (1, 8)}),
    'RemoveArmy2Unit': ('1068:515e', ['P', 'B:1:8'], 'none', ARMY,
                        {'army2_count': (1, 8)}),
    'RemoveMilitia': ('1068:51da', ['P'], 'none', ARMY + ['u.type'] * 4),
    'SwapArmies': ('1068:5222', ['P'], 'none', ARMY),
    'MakeUnitName': ('1068:53a4', ['OB:40', 'B:0:35', 'B:0:12', 'B:0:9'],
                     'none', []),
    'RecruitUnit': ('1068:5439', ['P', 'B:1:2', 'B:0:35', 'B:0:2'], 'none',
                    ARMY + ['country'], {'army1_count': (0, 7),
                                         'army2_count': (0, 7)}),
    'InitAvenger': ('1068:5638', ['U'], 'none', []),
    'AvengerJoinsWeaker': ('1068:56bc', ['P', 'PJ', 'UJ'], 'word',
                           ARMY + ECON, {'army1_count': (0, 8),
                                         'army2_count': (0, 8)}),
    'AvengerLeaves': ('1068:5835', ['P', 'PJ', 'OB:61'], 'none',
                      ARMY + ['u.type'] * 3),
    'InitUnit': ('1068:598d', ['P', 'U', 'B:0:35', 'B:0:2'], 'none',
                 ['spell', 'fame', 'country']),
    'AddUnitToArmy': ('1068:5b06', ['P', 'B:1:2', 'UJ'], 'none',
                      ARMY + UNITF, {'army1_count': (0, 7),
                                     'army2_count': (0, 7)}),
    'KnightSquire': ('1068:5b8b', ['P', 'U'], 'none', ARMY + UNITF),
    'SortArmy': ('1068:5e85', ['P', 'B:1:2'], 'none', ARMY + ['u.kills'] * 2),
    'CreateHero': ('1068:5f0c', ['U', 'NIL'], 'none', []),
    'HeroRankName': ('1068:6122', ['B:0:20', 'OB:40'], 'none', []),
    'RandomMercenaryType': ('1068:6199', ['P'], 'byte', ['title']),
    # troop levels past the name table read relocated far pointers in DS,
    # which the port's raw data segment image cannot reproduce
    'UnitRankName': ('1068:61db', ['U', 'OB:40'], 'none', UNITF,
                     {'U.level': (0, 40)}),
    'RaiderVictoryReward': ('1068:66af', ['P', 'B:1:2'], 'none',
                            ['title', 'fame', 'army1_count', 'event']),
    'MakeVampire': ('1068:674b', ['OB:61', 'U'], 'none', UNITF),
    # batch 5
    'CreateComputerPlayers': ('1068:0002', ['A', 'B:1:2', 'B:0:4', 'B:0:5'],
                              'none', ['country']),
    'InitPlayers': ('1068:01c1', ['A', 'N', 'B:0:5'], 'none',
                    ['cpu_level', 'country', 'h.census_editor_enabled',
                     'h.goods_trade_enabled']),
    'InitComputerRuler': ('1068:0788', ['A', 'I'], 'none',
                          ['country', 'h.goods_trade_enabled']),
    'SabotageAction': ('1068:36ef', ['A', 'B:0:3', 'I', 'J', 'B:1:14', 'O', 'O'],
                       'byte', SABOTAGE + ['J.mills', 'J.palace_parts',
                                           'J.warehouses', 'J.flags_5bd_q',
                                           'J.title', 'J.taler', 'J.justice',
                                           'J.army1_count', 'J.army_away',
                                           'army2_count'],
                       {'J.army1_count': (0, 8)}),
    'Distance': ('1068:666b', ['W:-200:200', 'W:-200:200', 'W:-200:200',
                               'W:-200:200'], 'word', []),
    'ClearHighScores': ('1068:67c5', ['OB:2750'], 'none', []),
    'SortHighScoreTable': ('1068:67db', ['F:name'], 'none', []),
    'ClearMailboxSlot': ('1068:68b0', ['F:diplomacy_671_q'], 'none', []),
    'AddNews': ('1068:68c5', ['A', 'N', 'B:0:9', 'B:0:9', 'B:0:40'], 'none',
                ['news_count']),
    'LogSabotageReport': ('1068:696f', ['A', 'B:0:3', 'I', 'J', 'B:0:14',
                                        'L:-1000:100000'], 'none',
                          ['J.sabotage_log_count']),
    'FormatPercent': ('1068:6aa5', ['OB:40', 'G:5', 'L:-2:2000'], 'none', []),
    'FormatThousands': ('1068:6b58', ['OB:40', 'G:9'], 'none', []),
    'BuildingProgressText': ('1068:6c36', ['OB:40', 'B:0:15'], 'none', []),
    'RealmName': ('1068:6cb4', ['OB:40', 'G:6'], 'none', []),
    'FameText': ('1068:6d8b', ['OB:40', 'B:0:120'], 'none', []),
    'MagnitudeText': ('1068:6e30', ['OB:40', 'G:7'], 'none', []),
    # milestone 4: turn processing (segment 3)
    'RulerFallsIll': ('n1010:3777', ['Wnd'], 'none', []),
    'WitchChoosesSpell': ('n1010:372a', ['Wnd', 'P'], 'none', ['spell']),
    'GrantFirstHero': ('n1010:2c50', ['Wnd', 'P'], 'none', ARMY,
                       {'army1_count': (0, 7)}),
    'HarvestReport': ('n1010:288d', ['Wnd', 'P', 'R'], 'none', ['harvest_quality']),
    'Report_Population': ('1010:27c9', ['Wnd', 'P'], 'none', POP),
    'Report_Budget': ('1010:263f', ['Wnd', 'A', 'I', 'N'], 'none', ECON + SABOTAGE),
    'LandLossCheck': ('n1010:4891', ['Wnd', 'P'], 'none', BUILD),
    'SkipTurnCheck': ('n1010:5707', ['Wnd', 'A', 'I', 'N'], 'none',
                      ['skip_turn', 'skip_turn', 'flags_5bd_q', 'land', 'taler',
                       'population', 'markets', 'mills', 'news_count']),
    'RevolutionCheck': ('n1010:55bb', ['Wnd', 'P'], 'none',
                        ['happiness', 'happiness', 'title', 'fame', 'lifetime']),
    'GrainShortageWarning': ('n1010:47b1', ['Wnd', 'P'], 'none',
                             ['population', 'grain', 'grain_distributed']),
    'MarriageDowry': ('n1010:2924', ['Wnd', 'P'], 'none', ARMY + ['is_female'],
                      {'army1_count': (0, 5)}),
    'FormatPlayerTitle': ('1060:03d9', ['P', 'OB:120', 'B:0:1', 'B:0:1'], 'none',
                          ['title', 'is_female', 'spell', 'country']),
    'PromotionCheck': ('n1010:48fc', ['Wnd', 'A', 'I', 'N', 'W:0:300'], 'none',
                       POP + ECON + ARMY + ['first_king_bonus', 'army_away',
                                            'maximize_taxes', 'lifetime'],
                       {'army1_count': (0, 7), 'army2_count': (0, 7)}),
    'SabotageEnd': ('1010:192f', ['Wnd', 'A', 'I', 'N'], 'none',
                    SABOTAGE + ['cpu_level', 'cpu_level', 'justice', 'flags_5bd_q', 'event_money']),
    'ShowStartTurnDialog': ('1010:0002', ['Wnd', 'P', 'I', 'W:0:300'], 'byte',
                            ['is_female', 'title', 'h.email_game_q', 'h.last_human']),
    'OfferUnitsAtTurnStart': ('1010:22d4', ['Wnd', 'P'], 'none',
                              ARMY + ['spell', 'spell', 'spell', 'title', 'cpu_level', 'army_away'],
                              {'army1_count': (0, 7), 'army2_count': (0, 7), 'fame': (0, 100)}),
    'Bankruptcy': ('n1010:4f9f', ['Wnd', 'P'], 'none',
                   BUILD + ['taler', 'taler', 'title'],
                   dict({'taler': (-3000000, 100000)},
                        **{b: (0, 400) for b in ('markets', 'mills', 'granaries',
                                                 'warehouses', 'taverns', 'smithies')})),
}


# per function: list of (entry prefix, answer(rng) -> (ax, {offset: bytes}))
# for Execute / ExecDialog / whole UI functions; the default answers 1 (OK)
# for dialogs and 0 for functions
UI_SCRIPTS = {
    'WitchChoosesSpell': [('Execute(', lambda rng: (1, {0x38: bytes([rng.randint(0, 12)])}))],
    # 0x49 = 1: the Lindwurm instead of a hero; the name is GetText (+0x100)
    'GrainShortageWarning': [('Execute(', lambda rng: (rng.choice([1, 2]), {}))],
    'ShowStartTurnDialog': [('Email_AskPassword(', lambda rng: (rng.choice([0, 1]), {}))],
    'OfferUnitsAtTurnStart': [('Execute(', lambda rng: (rng.choice([1, 2]), {}))],
    'PromotionCheck': [('Execute(', lambda rng: (rng.choice([1, 2]),
                                                 {0x100: b'Neuheld\0'}))],
    'GrantFirstHero': [('Execute(', lambda rng: (1, {0x49: bytes([rng.choice([0, 0, 1])]),
                                                    0x100: rng.choice([b'Testheld', b'', b'Ab'])
                                                    + b'\0'}))],
}


def set_field(players, idx, name, value):
    off, typ = field_info(ks.PLAYER, name)
    if typ == 'real':
        b = r48(value)
    else:
        fmt = {'u8': '<B', 's8': '<b', 's16': '<h', 'u16': '<H', 's32': '<i'}[typ]
        b = struct.pack(fmt, value)
    players[idx * PSIZE + off:idx * PSIZE + off + len(b)] = b
    return [(idx * PSIZE + off, b)]


def preset_promotion(rng, players, p, num):
    """Half of the cases: the player meets the next title's requirements,
    often the step to Koenig (title 9)."""
    if rng.random() < 0.5:
        return []
    m = []
    title = rng.choice([8, 8, 8, rng.randint(0, 8)])
    for name, v in (('title', title), ('land', 120000), ('taler', 1500000),
                    ('population', 20000), ('palace_parts', 12),
                    ('cathedral_parts', 12), ('happiness', 1.0), ('spell', 0),
                    ('tax_rate', 0.0), ('justice', 0.0), ('asylum_law', 1.0), ('fame', 100),
                    ('grain_distributed', 200000), ('event', 0), ('flags_5bd_q', 0),
                    ('maximize_taxes', 0), ('first_king_bonus', rng.randint(0, 1) if rng.random() < 0.2 else 0),
                    ('army1_count', rng.randint(4, 7)), ('army2_count', rng.randint(0, 3))):
        m += set_field(players, p, name, v)
    for i in range(1, 8):                     # strong units, sometimes a hero
        base = p * PSIZE + ARMY_BASE[1] + i * ks.UNIT_SIZE
        unit_type = 9 if (i == 1 and rng.random() < 0.5) else rng.randint(1, 8)
        u = bytes([unit_type]) + bytes(1) + bytes([20, 20])
        players[base + 0x19:base + 0x19 + 4] = u
        m.append((base + 0x19, u))
    for j in range(num):                      # nobody else is Koenig yet (mostly)
        if j != p and rng.random() < 0.9:
            m += set_field(players, j, 'title', rng.randint(0, 8))
            m += set_field(players, j, 'first_king_bonus', 0)
    return m


def preset_sabotage_log(rng, players, p, num):
    """Random entries in the sabotage log of the test player."""
    n = rng.randint(0, 15)
    m = set_field(players, p, 'sabotage_log_count', n)
    off, _ = field_info(ks.PLAYER, 'sabotage_log')
    log = b''.join(bytes([rng.randrange(num), rng.choice([0, 0, rng.randint(1, 14)])]) +
                   struct.pack('<i', rng.randint(-100, 50000)) for _ in range(15))
    a = p * PSIZE + off
    players[a:a + 90] = log
    m.append((a, log))
    return m


# per function: called after the random mutations, returns more mutations
PRESETS = {
    'PromotionCheck': preset_promotion,
    'SabotageEnd': preset_sabotage_log,
}


def make_chooser(func, rng):
    script = UI_SCRIPTS.get(func, [])

    def chooser(entry, kind):
        for prefix, answer in script:
            if entry.startswith(prefix):
                return answer(rng)
        return (1, {}) if kind == 'method' else (0, {})
    return chooser


def field_info(fields, name):
    for off, typ, fname, _ in fields:
        if fname == name:
            return off, typ
    raise KeyError(name)


def r48(x):
    import math
    if x == 0:
        return bytes(6)
    neg = x < 0
    x = abs(x)
    e = math.floor(math.log2(x))
    m = round((x / 2 ** e - 1) * 2 ** 39)
    if m >= 2 ** 39:
        m -= 2 ** 39
        e += 1
    m |= (1 << 39) if neg else 0
    return bytes([e + 129]) + m.to_bytes(5, 'little')


def random_real(rng):
    if rng.random() < 0.1:
        return bytes(6)
    return r48(rng.choice([rng.random(), rng.random() * 1.2, rng.random() * 0.1]))


def random_value(rng, name, typ):
    if typ == 'real':
        return random_real(rng)
    if typ.startswith('raw'):
        n = int(typ[3:])
        return bytes(rng.choice([0, 0, 1, rng.randrange(256)]) for _ in range(n))
    if name in ('spell',):
        v = rng.randint(0, 12)
    elif name == 'event':
        v = rng.randint(0, 23)
    elif name == 'title':
        v = rng.randint(0, 10)
    elif name == 'harvest_quality':
        v = rng.randint(1, 5)
    elif name == 'flags_5bd_q':
        v = rng.choice([0, 0x40, 0x80, 0x100, 0x800, rng.getrandbits(16)])
    elif name in ('army1_count', 'army2_count'):
        v = rng.randint(0, 8)
    elif name in ('palace_parts', 'cathedral_parts', 'university_parts'):
        v = rng.randint(0, 12)
    elif name == 'type':
        v = rng.choice([rng.randint(0, 35), 9, 6, 0, 13, 12])
    elif name == 'level':
        v = rng.choice([rng.randint(0, 5), rng.randint(0, 12),
                        rng.randint(0, 255)]) if typ == 'u8' else 0
    elif name == 'experience':
        v = rng.randint(0, 40)
    elif name == 'range':
        v = rng.randint(0, 7)
    elif name == 'max_steps':
        v = rng.randint(0, 5)
    elif name == 'ability':
        v = rng.randint(0, 38)
    elif name == 'country':
        v = rng.randint(0, 9)          # indexes 25-byte name tables
    elif name == 'initiative':
        v = rng.randint(-10, 20)
    elif typ == 'u8' and rng.random() < 0.5:
        v = rng.randint(0, 1)          # flags
    elif typ == 's32':
        v = rng.choice([rng.randint(0, 200), rng.randint(0, 200000),
                        rng.randint(-50000, 2000000), 0,
                        rng.randint(-2 ** 31, 2 ** 31 - 1)])  # 32-bit wrap-around
    elif typ in ('s16', 'u16'):
        v = rng.randint(0, 100) if name == 'fame' else rng.randint(0, 30000)
        if rng.random() < 0.1:
            v = rng.randint(-32768, 65535)  # 16-bit wrap-around
    else:
        v = rng.randint(0, 255)
    fmt = {'u8': '<B', 's8': '<b', 's16': '<h', 'u16': '<H', 's32': '<i'}[typ]
    if typ == 's8':
        v = max(-128, min(127, v))
    if typ == 'u8':
        v &= 0xFF
    if typ == 's16':
        v = ((v + 0x8000) & 0xFFFF) - 0x8000
    if typ == 'u16':
        v &= 0xFFFF
    return struct.pack(fmt, v)


def load_save(path):
    raw = open(path, 'rb').read()
    n = raw[1]
    return (bytearray(raw[:ks.HEADER_SIZE]),
            bytearray(raw[ks.HEADER_SIZE:ks.HEADER_SIZE + n * PSIZE]), n)


def diff(a, b):
    out, i = [], 0
    while i < len(a):
        if a[i] != b[i]:
            j = i
            while j < len(a) and a[j] != b[j]:
                j += 1
            out.append(f'{i}:{bytes(b[i:j]).hex()}')
            i = j
        else:
            i += 1
    return ';'.join(out)


def make_mutations(rng, fields, p, uidx, j):
    muts, hmuts = [], []
    for _ in range(rng.randint(0, 4) if fields else 0):
        fname = rng.choice(fields)
        if fname.startswith('J.'):
            off, typ = field_info(ks.PLAYER, fname[2:])
            muts.append((j * PSIZE + off, random_value(rng, fname[2:], typ)))
        elif fname.startswith('U.'):
            off, typ = field_info(ks.UNIT, fname[2:])
            base = ARMY_BASE[1] + uidx * ks.UNIT_SIZE
            muts.append((p * PSIZE + base + off, random_value(rng, fname[2:], typ)))
        elif fname.startswith('h.'):
            off, typ = field_info(ks.HEADER, fname[2:])
            hmuts.append((off, random_value(rng, fname[2:], typ)))
        elif fname.startswith('u.'):
            off, typ = field_info(ks.UNIT, fname[2:])
            base = ARMY_BASE[rng.randint(1, 2)] + rng.randint(1, 8) * ks.UNIT_SIZE
            muts.append((p * PSIZE + base + off, random_value(rng, fname[2:], typ)))
        else:
            off, typ = field_info(ks.PLAYER, fname)
            muts.append((p * PSIZE + off, random_value(rng, fname, typ)))
    return muts, hmuts


def main():
    funcs = sys.argv[1].split(',')
    n = int(sys.argv[2])
    rng = random.Random(int(sys.argv[3]) if len(sys.argv) > 3 else 7)
    emu = KaiserEmu()
    sp = emu.scratch_para
    ui = UILayer(emu, sp, None)
    for func in funcs:
        addr, args, ret, fields = SPECS[func][:4]
        clamps = SPECS[func][4] if len(SPECS[func]) > 4 else {}
        for _ in range(n):
            save = rng.choice(SAVES)
            header, players, num = load_save(save)
            p = rng.randrange(num)
            uidx = rng.randint(1, 8)
            j = rng.choice([i for i in range(num) if i != p] or [p])
            muts, hmuts = make_mutations(rng, fields, p, uidx, j)
            for off, val in muts:
                players[off:off + len(val)] = val
            if func in PRESETS:
                muts += PRESETS[func](rng, players, p, num)
            for fname, (lo, hi) in clamps.items():
                owner = p
                if fname.startswith('U.'):
                    off, typ = field_info(ks.UNIT, fname[2:])
                    off += ARMY_BASE[1] + uidx * ks.UNIT_SIZE
                elif fname.startswith('J.'):
                    off, typ = field_info(ks.PLAYER, fname[2:])
                    owner = j
                else:
                    off, typ = field_info(ks.PLAYER, fname)
                fmt = {'u8': '<B', 's8': '<b', 's16': '<h', 'u16': '<H', 's32': '<i'}[typ]
                size = struct.calcsize(fmt)
                a = owner * PSIZE + off
                v, = struct.unpack(fmt, bytes(players[a:a + size]))
                if not lo <= v <= hi:
                    val = struct.pack(fmt, rng.randint(lo, hi))
                    muts.append((a, val))
                    players[a:a + size] = val
            for off, val in hmuts:
                header[off:off + len(val)] = val
            seed = rng.getrandbits(32)
            emu.reset_ds()
            ui.reset()
            ui.chooser = make_chooser(func, rng)
            emu.write(emu.ds_para, HDR_DS, bytes(header))
            emu.write(sp, 0, bytes(players))
            emu.write(sp, OUT_AREA, bytes(0x1000))
            # runtime country adjectives (DS:6696) as a new game sets them
            # and computer ruler names (DS:64a2): here the country names
            for c in range(10):
                emu.write(emu.ds_para, 0x6696 + 25 * c,
                          emu.read(emu.ds_para, 0x477e + 25 * (10 + c), 25))
                emu.write(emu.ds_para, 0x64a2 + 25 * c,
                          emu.read(emu.ds_para, 0x477e + 25 * c, 25))
                emu.write(emu.ds_para, 0x63a8 + 25 * c,       # runtime country names
                          emu.read(emu.ds_para, 0x477e + 25 * c, 25))
            emu.rand_seed(seed)
            call_args, shown, outs = [], [], []
            byte_refs = OUT_AREA + 0x100
            for a in args:
                kind, _, rest = a.partition(':')
                if kind == 'P':
                    call_args.append(('ptr', (sp, p * PSIZE)))
                elif kind == 'A':
                    call_args.append(('ptr', (sp, 0)))
                elif kind == 'N':
                    call_args.append(('word', num))
                    shown.append(str(num))
                elif kind == 'I':
                    call_args.append(('word', p))
                    shown.append(str(p))
                elif kind == 'J':
                    call_args.append(('word', j))
                    shown.append(str(j))
                elif kind == 'PJ':
                    call_args.append(('ptr', (sp, j * PSIZE)))
                    shown.append(str(j))
                elif kind in ('RI', 'RJ'):
                    v = p if kind == 'RI' else j
                    emu.write(sp, byte_refs, bytes([v]))
                    call_args.append(('ptr', (sp, byte_refs)))
                    byte_refs += 2
                    if kind == 'RJ':
                        shown.append(str(j))
                elif kind == 'Q':
                    q = rng.randint(1, 5)
                    call_args.append(('word', q))
                    shown.append(str(q))
                elif kind in ('U', 'UJ'):
                    owner = p if kind == 'U' else j
                    call_args.append(('ptr', (sp, owner * PSIZE + ARMY_BASE[1] + uidx * ks.UNIT_SIZE)))
                    if kind == 'UJ':
                        shown.append(str(j))
                    shown.append(str(uidx))
                elif kind == 'NIL':
                    call_args.append(('ptr', (0, 0)))
                elif kind == 'Wnd':
                    call_args.append(('ptr', WINDOW))
                elif kind == 'F':
                    off, _ = field_info(ks.PLAYER, rest)
                    call_args.append(('ptr', (sp, p * PSIZE + off)))
                elif kind == 'G':
                    v = int(10 ** rng.uniform(0, int(rest))) * rng.choice([1, 1, 1, -1])
                    call_args.append(('long', v & 0xFFFFFFFF))
                    shown.append(str(v))
                elif kind in ('B', 'W', 'L'):
                    lo, hi = (int(x) for x in rest.split(':'))
                    v = rng.randint(lo, hi)
                    call_args.append(('long' if kind == 'L' else 'word', v & 0xFFFFFFFF))
                    shown.append(str(v))
                elif kind == 'R':
                    v = random_real(rng)
                    call_args.append(('real', v))
                    shown.append(v.hex())
                elif kind in ('O', 'OP'):
                    off = OUT_AREA + 4 * len(outs)
                    outs.append((kind, off))
                    call_args.append(('ptr', (sp, off)))
                elif kind == 'OB':
                    off = OUT_AREA + 0x200
                    outs.append((int(rest), off))
                    call_args.append(('ptr', (sp, off)))
                else:
                    raise ValueError(a)
            try:
                near = addr.startswith('n')
                ax, dx = emu.call_far(addr.lstrip('n'), call_args, near=near)
                r = emu.last_regs
                if ret == 'long':
                    rv = str(struct.unpack('<i', struct.pack('<HH', ax, dx))[0])
                elif ret == 'word':
                    rv = str(ax)
                elif ret == 'sword':
                    rv = str(struct.unpack('<h', struct.pack('<H', ax))[0])
                elif ret == 'byte':
                    rv = str(ax & 0xFF)
                elif ret == 'real':
                    rv = struct.pack('<HHH', ax, r['bx'], dx).hex()
                else:
                    rv = '-'
            except EmuError:
                if emu.last_runerror is None:
                    raise
                rv = f'E{emu.last_runerror}'
            out_vals = []
            for kind, off in outs:
                v = emu.read(sp, off, 4)
                if isinstance(kind, int):
                    out_vals.append(emu.read(sp, off, kind).hex())
                elif kind == 'O':
                    out_vals.append(str(struct.unpack('<i', v)[0]))
                else:
                    o, s = struct.unpack('<HH', v)
                    out_vals.append(str(o) if s == sp else ('nil' if s == 0 and o == 0 else 'bad'))
            after = emu.read(sp, 0, len(players))
            hafter = emu.read(emu.ds_para, HDR_DS, ks.HEADER_SIZE)
            mut = ';'.join(f'{o}:{v.hex()}' for o, v in muts)
            hmut = ';'.join(f'{o}:{v.hex()}' for o, v in hmuts)
            print(f'func={func} save={os.path.basename(save)} p={p} seed={seed} '
                  f'args={",".join(shown) or "-"} mut={mut or "-"} hmut={hmut or "-"} -> '
                  f'ret={rv} out={",".join(out_vals) or "-"} '
                  f'seedout={emu.rand_seed()} diff={diff(players, after) or "-"} '
                  f'hdiff={diff(header, hafter) or "-"} '
                  f'ui={"|".join(ui.log) or "-"}')


if __name__ == '__main__':
    main()
