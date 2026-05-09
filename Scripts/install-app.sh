#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/Scripts/build-app.sh"

if [ -w "/Applications" ]; then
    INSTALL_DIR="/Applications"
else
    INSTALL_DIR="$HOME/Applications"
    mkdir -p "$INSTALL_DIR"
fi

DESTINATION="$INSTALL_DIR/VoiceType.app"
rm -rf "$DESTINATION"
cp -R "$ROOT_DIR/build/VoiceType.app" "$DESTINATION"

echo "Installed $DESTINATION"
open "$DESTINATION"
