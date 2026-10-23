#!/bin/bash
# Build the GUI for Windows 11 (x86_64-win64, LCL win32 widget set) with the
# FPC cross compiler (port/build-win.sh, docs/phase3.md milestone 8). The LCL
# for win64 is built once in tools/lazarus:
#   make -C packager/registration / components/lazutils / components/freetype
#   make lcl LCL_PLATFORM=win32   (all with CPU_TARGET=x86_64 OS_TARGET=win64
#   PP=ppcrossx64 OPT="-n -Fu<units>/*")
# The LCL paths come first: FPC's Free Vision (units/*/fv) has a Menus unit
# of its own. Output: port/bin/win64/Kaiser.exe
set -euo pipefail
cd "$(dirname "$0")"
FPCWIN=${FPCWIN:-$HOME/kaiser-toolchain/fpc}
PPC="$FPCWIN/lib/fpc/3.2.2/ppcrossx64"
U="$FPCWIN/lib/fpc/3.2.2/units/x86_64-win64"
L=../../tools/lazarus
A=x86_64-win64
mkdir -p ../obj/gui-win64 ../bin/win64
"$PPC" -n -Twin64 -Mobjfpc -Sa -O2 ${GUI_FPC_OPTS:-} -dLCL -dLCLwin32 -WG \
  -Fu../src -Fu"$L/lcl/units/$A/win32" -Fu"$L/lcl/units/$A" \
  -Fu"$L/components/lazutils/lib/$A" -Fu"$L/components/freetype/lib/$A" \
  -Fu"$L/packager/units/$A" -Fu"$U/*" \
  -FU../obj/gui-win64 -FE../bin/win64 -oKaiser.exe \
  kaisergui.lpr
