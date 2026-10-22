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
    (0x12, 'u8', 'flag_12_q', 'checked in CmBeenden before elimination test'),
]

# Player record, array at KaiserWindow+0x41, stride 0x6d5
PLAYER = [
    (0x000, 'cstr32', 'name', 'player name, zero-padded'),
    (0x019, 'u8', 'title_q', '== 10 -> victory routine in CmBeenden'),
    (0x01d, 'u8', 'flag_1d_q', 'selects one of two messages on elimination'),
    (0x01e, 'u8', 'cpu_level',
     '0 = human; 3-6 in saves for computer players (difficulty?). NextPlayer runs CpuTurn when != 0; only humans get high scores'),
    (0x020, 'u8', 'skip_turn',
     'NextPlayer skips the player once and clears it (AUSSETZDLG)'),
    (0x022, 's16', 'v22_q',
     '< 1 -> player eliminated; also the checksum salt'),
    (0x026, 's32', 'check_a', 'v22 + (v54 - vcb), recomputed on load'),
    (0x054, 's32', 'v54_q', 'probably Taler (can be negative)'),
    (0x0c7, 's32', 'check_c', '(v54 + vcb) div 1000'),
    (0x0cb, 's32', 'vcb_q', 'probably Land in ha (~100000 at start)'),
    (0x133, 's32', 'check_b', 'v22 + (vcb - v54)'),
    (0x139, 'cstr40', 'name_139_q', 'second name, e.g. a CP name'),
]

HEADER_SIZE = 0x295
PLAYER_SIZE = 0x6d5
EXTRA_SIZE = 0x192

# plain (offset, type, name) views for code that does not need evidence
HEADER_FIELDS = [(o, t, n) for o, t, n, _ in HEADER]
PLAYER_FIELDS = [(o, t, n) for o, t, n, _ in PLAYER]
