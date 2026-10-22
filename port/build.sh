#!/bin/bash
# Build the Kaiser port tools with Free Pascal. Output in port/bin/.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p bin obj
fpc -Mobjfpc -Sa -O2 -Fusrc -FUobj -FEbin tools/ksrtool.pas
fpc -Mobjfpc -Sa -O2 -Fusrc -FUobj -FEbin tests/real48test.pas
fpc -Mobjfpc -Sa -O2 -Fusrc -FUobj -FEbin tests/ruletest.pas
