#!/bin/bash
# Play games on in the port (port/bin/ksrsim) and in the emulated original
# (tools/emu/sim_original.py) and compare them turn by turn.
#
#   tools/emu/sim_compare.sh TURNS SEED OUTDIR [GAME ...]
#
# GAME is a savegame or new:HUMANS:COMPUTERS:LEVEL; default: all savegames
# in Kaiser/. Prints one line per game; the per-turn lines are kept in OUTDIR.
set -u
cd "$(dirname "$0")/../.."
TURNS=$1; SEED=$2; OUT=$3; shift 3
GAMES=("$@")
if [ ${#GAMES[@]} -eq 0 ]; then GAMES=(Kaiser/*.KSR Kaiser/*.ksr); fi
mkdir -p "$OUT"
for g in "${GAMES[@]}"; do
  b=$(basename "$g")
  port/bin/ksrsim "$g" "$TURNS" "$SEED" > "$OUT/$b.port" 2>&1
  tools/.venv/bin/python tools/emu/sim_original.py "$g" "$TURNS" "$SEED" > "$OUT/$b.orig" 2>&1
  if cmp -s "$OUT/$b.port" "$OUT/$b.orig"; then
    echo "$b: identical, $(wc -l < "$OUT/$b.orig" | tr -d ' ') turns"
  else
    echo "$b: DIFFERENT from turn $(diff "$OUT/$b.port" "$OUT/$b.orig" | head -1)"
  fi
done
