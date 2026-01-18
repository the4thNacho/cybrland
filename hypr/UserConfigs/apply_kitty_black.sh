#!/usr/bin/env bash
set -euo pipefail

SNIPPET="$HOME/.config/hypr/UserConfigs/kitty-kb-black.conf"
DEST="$HOME/.config/kitty/kitty.conf"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

if [ ! -f "$SNIPPET" ]; then
  echo "Snippet not found: $SNIPPET"
  echo "Make sure the file exists in ~/.config/hypr/UserConfigs/kitty-kb-black.conf"
  exit 1
fi

mkdir -p "$HOME/.config/kitty"
if [ -f "$DEST" ]; then
  cp "$DEST" "${DEST}.bak.$TIMESTAMP"
  echo "Backed up existing kitty.conf to ${DEST}.bak.$TIMESTAMP"
fi

cp "$SNIPPET" "$DEST"
echo "Installed $SNIPPET -> $DEST"

# Try to tell kitty to reload colors if kitty remote is available
if command -v kitty >/dev/null 2>&1; then
  if kitty @ ls >/dev/null 2>&1; then
    kitty @ set-colors --all --config "$DEST" || true
    echo "Requested kitty to reload colors via kitty @ set-colors"
  else
    echo "Kitty is installed but remote control is not available. Restart kitty windows to apply colors."
  fi
else
  echo "Kitty not found in PATH; restart terminals after installing the file."
fi

echo "Done. To apply Hypr changes (opacity/blur), run: hyprctl reload"
