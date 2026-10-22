#!/bin/bash
# The Homebrew ghidra formula ships without the native decompiler for
# Apple Silicon. Build it from the bundled C++ sources and drop it where
# Ghidra looks for it. Re-run after every `brew upgrade ghidra`.
set -euo pipefail
GHIDRA_HOME="${GHIDRA_HOME:-/opt/homebrew/opt/ghidra/libexec}"
SRC="$GHIDRA_HOME/Ghidra/Features/Decompiler/src/decompile/cpp"
DEST="$GHIDRA_HOME/Ghidra/Features/Decompiler/os/mac_arm_64"
BUILD="${TMPDIR:-/tmp}/ghidra-decompiler-build"

rm -rf "$BUILD"
mkdir -p "$BUILD"
cp -R "$SRC/." "$BUILD/"
cp -R "$SRC/../zlib" "$BUILD/../zlib" 2>/dev/null || true
# ghidra_opt is the decompiler process Ghidra talks to (decomp_opt is a
# standalone console tool that also needs GNU bfd)
make -C "$BUILD" -j"$(sysctl -n hw.ncpu)" ghidra_opt
make -C "$BUILD" -j"$(sysctl -n hw.ncpu)" sleigh_opt
mkdir -p "$DEST"
install -m 755 "$BUILD/ghidra_opt" "$DEST/decompile"
install -m 755 "$BUILD/sleigh_opt" "$DEST/sleigh"
echo "installed into $DEST"
