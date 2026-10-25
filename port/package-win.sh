#!/bin/bash
# The Windows download (run port/build-win.sh first). Needs the original game
# in Kaiser/ (not in git).
#   port/package-win.sh EDITION VERSION   e.g. Classic 1.0
#     port/bin/release/Kaiser-EDITION-VERSION-Windows-x64.zip with
#       Kaiser EDITION\Kaiser EDITION.exe   the game
#       Kaiser EDITION\Kaiser\              kaiser.exe (the resources), kaiser.mid
#       Kaiser EDITION\docs\                the help (manual.md, help-map.txt)
#   port/package-win.sh --tests
#     port/bin/Kaiser-win64-tests.zip: the test programs with their vectors,
#     the savegames from Kaiser/ and run-tests.bat, the same checks as on
#     macOS (docs/phase3.md, Running)
set -euo pipefail
cd "$(dirname "$0")/.."
TESTS="ksrtool ksrsim ksrbattle real48test ruletest"
if [ "${1:-}" = "--tests" ]; then
  OUT=port/bin/Kaiser-win64-tests
  rm -rf "$OUT" "$OUT.zip"
  mkdir -p "$OUT/tests" "$OUT/Kaiser"
  for T in $TESTS; do cp "port/bin/win64/$T.exe" "$OUT/"; done
  cp port/tests/*.vec "$OUT/tests/"
  cp Kaiser/* "$OUT/Kaiser/"
  {
    printf '@echo off\r\n'
    printf 'rem the port against the vectors of the original (docs/phase3.md)\r\n'
    printf 'cd /d "%%~dp0"\r\n'
    printf 'for %%%%f in (Kaiser\\*.KSR) do ksrtool.exe roundtrip "%%%%f"\r\n'
    printf 'real48test.exe tests\\real48.vec\r\n'
    for v in rules turn battle actions troops dialogs; do
      printf 'ruletest.exe Kaiser tests\\%s.vec\r\n' "$v"
    done
    printf 'pause\r\n'
  } > "$OUT/run-tests.bat"
  (cd port/bin && zip -qr "$(basename "$OUT").zip" "$(basename "$OUT")")
  ls -la "$OUT.zip"
  exit 0
fi
ED=${1:?edition (Classic or Remastered) or --tests}
VER=${2:?version}
for F in Kaiser/kaiser.exe Kaiser/kaiser.mid port/bin/win64/Kaiser.exe; do
  [ -f "$F" ] || { echo "missing $F" >&2; exit 1; }
done
REL=port/bin/release
DIR="Kaiser $ED"
OUT="$REL/win-$ED/$DIR"
rm -rf "$REL/win-$ED"
mkdir -p "$OUT/Kaiser" "$OUT/docs"
cp port/bin/win64/Kaiser.exe "$OUT/$DIR.exe"
cp Kaiser/kaiser.exe Kaiser/kaiser.mid "$OUT/Kaiser/"
cp docs/manual.md docs/help-map.txt "$OUT/docs/"
ZIP="Kaiser-$ED-$VER-Windows-x64.zip"
rm -f "$REL/$ZIP"
(cd "$REL/win-$ED" && zip -qr "../$ZIP" "$DIR")
ls -la "$REL/$ZIP"
