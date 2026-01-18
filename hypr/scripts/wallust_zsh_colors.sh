#!/usr/bin/env bash
# Export ZSH segment colors derived from wallust templates
# This script is safe to source from zsh; avoid setting strict shell options

WALLUST_ROFI="$HOME/.config/wallust/templates/colors-rofi.rasi"
WALLUST_HYPR="$HOME/.config/hypr/wallust/wallust-hyprland.conf"

extract_hex() {
  local file="$1" key_regex="$2"
  if [[ -f "$file" ]]; then
    grep -oP "$key_regex" "$file" | head -n1 || true
  fi
}

# prefer color13 then color12, fallback to hard-coded
seg_bg=$(extract_hex "$WALLUST_ROFI" "color13:\s*\K#[A-Fa-f0-9]{6}")
seg_bg=${seg_bg:-$(extract_hex "$WALLUST_ROFI" "color12:\s*\K#[A-Fa-f0-9]{6}")}

if [[ -z "$seg_bg" && -f "$WALLUST_HYPR" ]]; then
  val=$(grep -oP '\$color13\s*=\s*rgb\(\K[^)]+(?=\))' "$WALLUST_HYPR" || true)
  if [[ -n "$val" ]]; then
    if [[ "$val" == *","* ]]; then
      IFS=',' read -r r g b <<<"$val"
      seg_bg=$(printf "#%02X%02X%02X" "$r" "$g" "$b")
    else
      if [[ "$val" =~ ^[A-Fa-f0-9]{6}$ ]]; then
        seg_bg="#${val}"
      fi
    fi
  fi
fi

if [[ -z "$seg_bg" ]]; then
  seg_bg="#FF79C6"
fi

# Derive a foreground color with good contrast: if bg is light, use dark fg, else white
derive_fg() {
  local hex="$1"
  # strip leading # if present
  hex="${hex#\#}"
  if [[ -z "$hex" || ${#hex} -lt 6 ]]; then
    echo "#FFFFFF"
    return
  fi
  local r=$((16#${hex:0:2}))
  local g=$((16#${hex:2:2}))
  local b=$((16#${hex:4:2}))
  # luminance approximation
  local lum
  lum=$(awk "BEGIN{print (0.2126*${r}+0.7152*${g}+0.0722*${b})/255}")
  if awk "BEGIN{exit !(${lum} > 0.6)}"; then
    echo "#1C1C1C"
  else
    echo "#FFFFFF"
  fi
}

ZSH_SEG_BG="$seg_bg"
# Force black foreground for segments for stronger contrast
ZSH_SEG_FG="#000000"

export ZSH_SEG_BG ZSH_SEG_FG
