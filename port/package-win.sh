#!/bin/bash
# A folder (and zip) to copy to a Windows 11 machine: the port's GUI, the
# test programs with their vectors and a batch file that runs them, the help
# texts, and the original game (kaiser.exe for the resources, the
# savegames for the tests) from Kaiser/. Run port/build-win.sh first.
# Output: port/bin/Kaiser-win64/ and port/bin/Kaiser-win64.zip
#   KaiserPort.exe     the game (Windows ignores case: not next to kaiser.exe
#                      under the name Kaiser.exe)
#   Kaiser\            the original files
#   run-tests.bat      the same checks as on macOS (docs/phase3.md, Running)
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=port/bin/Kaiser-win64
rm -rf "$OUT" port/bin/Kaiser-win64.zip
mkdir -p "$OUT/tests" "$OUT/docs" "$OUT/extracted/help" "$OUT/Kaiser"
cp port/bin/win64/Kaiser.exe "$OUT/KaiserPort.exe"
cp port/bin/win64/{ksrtool,ksrsim,ksrbattle,real48test,ruletest}.exe "$OUT/"
cp port/tests/*.vec "$OUT/tests/"
cp docs/manual.md "$OUT/docs/"
cp extracted/help/KAISER.hpj "$OUT/extracted/help/"
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
(cd port/bin && zip -qr Kaiser-win64.zip Kaiser-win64)
ls -la port/bin/Kaiser-win64.zip
