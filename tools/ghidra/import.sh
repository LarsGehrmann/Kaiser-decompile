#!/bin/bash
# Import kaiser.exe into the Ghidra project ghidra/Kaiser.gpr and run
# auto-analysis. Re-running with -overwrite replaces the program, which
# discards manual work -- only use it to start over.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GHIDRA_HOME="${GHIDRA_HOME:-/opt/homebrew/opt/ghidra/libexec}"
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@25/libexec/openjdk.jdk/Contents/Home}"

"$GHIDRA_HOME/support/analyzeHeadless" "$ROOT/ghidra" Kaiser \
    -import "$ROOT/Kaiser/kaiser.exe" \
    -loader NeLoader \
    -processor "x86:LE:16:Protected Mode" \
    "$@"
