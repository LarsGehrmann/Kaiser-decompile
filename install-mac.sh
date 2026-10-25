#!/bin/bash
# Installs the latest Kaiser release into /Applications (or ~/Applications):
#   curl -fsSL https://raw.githubusercontent.com/LarsGehrmann/Kaiser-decompile/main/install-mac.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/LarsGehrmann/Kaiser-decompile/main/install-mac.sh | bash -s classic
# A download by curl carries no quarantine flag, so macOS opens the app
# without the "cannot check it for malicious software" refusal that a zip
# downloaded in the browser gets (the app is not notarized by Apple).
# KAISER_DEST=DIR installs elsewhere.
set -euo pipefail
REPO=LarsGehrmann/Kaiser-decompile
case "$(echo "${1:-remastered}" | tr '[:upper:]' '[:lower:]')" in
  classic) EDITION=Classic ;;
  *) EDITION=Remastered ;;
esac
if [ "$(uname -m)" != arm64 ]; then
  echo "Kaiser needs a Mac with Apple Silicon (M1 or later)." >&2
  exit 1
fi
URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" |
  grep -o "\"browser_download_url\": *\"[^\"]*/Kaiser-$EDITION-[^\"]*-macOS-arm64\.zip\"" |
  sed 's/.*"\(https[^"]*\)"$/\1/' | head -1)
if [ -z "$URL" ]; then
  echo "No macOS download of Kaiser $EDITION found in the latest release." >&2
  exit 1
fi
DEST=${KAISER_DEST:-/Applications}
if [ ! -w "$DEST" ]; then
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
echo "Downloading $(basename "$URL") ..."
curl -fL --progress-bar -o "$TMP/kaiser.zip" "$URL"
ditto -x -k "$TMP/kaiser.zip" "$TMP"
APP="Kaiser $EDITION.app"
rm -rf "${DEST:?}/$APP"
mv "$TMP/$APP" "$DEST/"
xattr -dr com.apple.quarantine "$DEST/$APP" 2>/dev/null || true
echo "Installed: $DEST/$APP"
[ -n "${KAISER_DEST:-}" ] || open "$DEST/$APP"
