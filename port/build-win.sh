#!/bin/bash
# Build the Windows 11 (x86_64-win64) executables of the port on macOS with
# the FPC cross compiler (docs/phase3.md, milestone 8). Output: port/bin/win64/
#   ksrtool.exe ksrsim.exe ksrbattle.exe real48test.exe ruletest.exe Kaiser.exe
# FPCWIN: the cross FPC (make crossinstall CPU_TARGET=x86_64 OS_TARGET=win64,
# default ~/kaiser-toolchain/fpc; FPC's makefiles do not take paths with spaces)
set -euo pipefail
cd "$(dirname "$0")"
FPCWIN=${FPCWIN:-$HOME/kaiser-toolchain/fpc}
PPC="$FPCWIN/lib/fpc/3.2.2/ppcrossx64"
U="$FPCWIN/lib/fpc/3.2.2/units/x86_64-win64"
OUT=bin/win64
mkdir -p "$OUT" obj/win64
cross() {
  "$PPC" -n -Twin64 -Mobjfpc -Sa -O2 -Fu"$U/*" -Fusrc -FUobj/win64 -FE"$OUT" "$@"
}
cross tools/ksrtool.pas
cross tools/ksrsim.pas
cross tools/ksrbattle.pas
cross tests/real48test.pas
cross tests/ruletest.pas
cross tests/scaletest.pas
if [ "${1:-}" != "--no-gui" ]; then
  gui/build-win.sh
fi
