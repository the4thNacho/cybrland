#!/usr/bin/env bash
# Wrapper to run fastfetch with wallust-derived magenta/accent color
set -euo pipefail

# Possible sources (prefer rofi template if present)
WALLUST_ROFI="$HOME/.config/wallust/templates/colors-rofi.rasi"
WALLUST_HYPR="$HOME/.config/hypr/wallust/wallust-hyprland.conf"

extract_hex() {
  local file="$1" key_regex="$2"
  if [[ -f "$file" ]]; then
    grep -oP "$key_regex" "$file" | head -n1 || true
  fi
}

# Try rofi template color13 then color12
magenta_hex=""
magenta_hex=$(extract_hex "$WALLUST_ROFI" "color13:\s*\K#[A-Fa-f0-9]{6}")
magenta_hex=${magenta_hex:-$(extract_hex "$WALLUST_ROFI" "color12:\s*\K#[A-Fa-f0-9]{6}")}

# fall back to hyprland wallust template variables like $color13 = rgb(7AA2F7) or rgb(10,20,30)
if [[ -z "$magenta_hex" && -f "$WALLUST_HYPR" ]]; then
  val=$(grep -oP '\$color13\s*=\s*rgb\(\K[^)]+(?=\))' "$WALLUST_HYPR" || true)
  if [[ -n "$val" ]]; then
    # If val is comma-separated numbers (R,G,B) convert decimals to hex
    if [[ "$val" == *","* ]]; then
      IFS=',' read -r r g b <<<"$val"
      r_hex=$(printf "%02X" "$r")
      g_hex=$(printf "%02X" "$g")
      b_hex=$(printf "%02X" "$b")
      magenta_hex="#${r_hex}${g_hex}${b_hex}"
    else
      # If val is a 6-char hex like 7AA2F7 (no #), just prefix
      if [[ "$val" =~ ^[A-Fa-f0-9]{6}$ ]]; then
        magenta_hex="#${val}"
      fi
    fi
  fi
fi

# final fallback
if [[ -z "$magenta_hex" ]]; then
  magenta_hex="#C678DD"
fi

# Allow manual override via FASTFETCH_ACCENT env var (example: FASTFETCH_ACCENT="#FF79C6")
if [[ -n "${FASTFETCH_ACCENT:-}" ]]; then
  # normalize: ensure leading #
  if [[ "${FASTFETCH_ACCENT#\#}" == "${FASTFETCH_ACCENT}" ]]; then
    accent_hex="#${FASTFETCH_ACCENT}"
  else
    accent_hex="${FASTFETCH_ACCENT}"
  fi
else
  # Compute a softened variant (blend with white) for a pastel/soft look if requested
  # Set FASTFETCH_SOFTEN=1 to enable soft pastel accent; default uses original magenta
  accent_hex="$magenta_hex"
  if [[ "${FASTFETCH_SOFTEN:-0}" == "1" ]]; then
  soften_ratio=0.4
  if command -v python3 >/dev/null 2>&1; then
    soft_hex=$(python3 - "$magenta_hex" "$soften_ratio" <<'PY'
import sys
h=sys.argv[1].lstrip('#')
p=float(sys.argv[2])
try:
    r=int(h[0:2],16); g=int(h[2:4],16); b=int(h[4:6],16)
except Exception:
    print(h)
    sys.exit(0)
wr=int(round(r*(1-p)+255*p))
wg=int(round(g*(1-p)+255*p))
wb=int(round(b*(1-p)+255*p))
print('#{:02X}{:02X}{:02X}'.format(wr,wg,wb))
PY
    )
    accent_hex="$soft_hex"
    fi
  fi
fi

# Export for fastfetch or pass as env var; some fastfetch builds accept --accent-color
export FASTFETCH_ACCENT="$accent_hex"

ASCII_FILE="$HOME/.config/hypr/UserConfigs/fast.txt"

# Send OSC 4 mapping for ANSI color index 5 so the ASCII uses the accent
# Send OSC mapping for ANSI color 5 using softened accent
if [[ -n "$accent_hex" ]]; then
  printf '\033]4;5;%s\033\\' "$accent_hex"
fi

# Read and expand ASCII file (interpret literal \033 sequences)
ascii_raw=""
if [[ -f "$ASCII_FILE" ]]; then
  ascii_raw=$(<"$ASCII_FILE")
fi

# Capture fastfetch output (forward args). Use fallback text if not installed.
if command -v fastfetch >/dev/null 2>&1; then
  if fastfetch --help 2>&1 | grep -qi "accent"; then
    info_output=$(fastfetch --accent-color "$accent_hex" "$@")
  else
    info_output=$(fastfetch "$@")
  fi
else
  info_output="fastfetch not found"
fi

tmp_ascii=$(mktemp)
tmp_info=$(mktemp)
trap 'rm -f "$tmp_ascii" "$tmp_info"' EXIT

printf '%b\n' "$ascii_raw" >"$tmp_ascii"
printf '%s\n' "$info_output" >"$tmp_info"

if command -v python3 >/dev/null 2>&1; then
  python3 - <<'PY' "$tmp_ascii" "$tmp_info"
import sys, re, unicodedata

ansi_re = re.compile(r'\x1B\[[0-9;]*[A-Za-z]')

def strip_ansi(s):
    return ansi_re.sub('', s)

def wcswidth(s):
    w = 0
    for ch in s:
        if unicodedata.category(ch) == 'Mn':
            continue
        ea = unicodedata.east_asian_width(ch)
        if ea in ('F','W'):
            w += 2
        else:
            w += 1
    return w

ascii_file = sys.argv[1]
info_file = sys.argv[2]
with open(ascii_file, 'r', encoding='utf-8', errors='replace') as f:
    ascii_lines = [line.rstrip('\n') for line in f]
with open(info_file, 'r', encoding='utf-8', errors='replace') as f:
    info_lines = [line.rstrip('\n') for line in f]

max_width = 0
for line in ascii_lines:
    stripped = strip_ansi(line)
    w = wcswidth(stripped)
    if w > max_width:
        max_width = w

lines = max(len(ascii_lines), len(info_lines))
for i in range(lines):
    a = ascii_lines[i] if i < len(ascii_lines) else ''
    b = info_lines[i] if i < len(info_lines) else ''
    stripped = strip_ansi(a)
    pad = max_width - wcswidth(stripped)
    # print a (with ANSI), then padding spaces, two spaces, then b
    sys.stdout.write(a)
    if pad > 0:
        sys.stdout.write(' ' * pad)
    sys.stdout.write('  ' + b + '\n')
PY
else
  # Fallback: basic paste-style output if python3 not available
  paste -d '  ' "$tmp_ascii" "$tmp_info" || (cat "$tmp_ascii"; echo; cat "$tmp_info")
fi

rm -f "$tmp_ascii" "$tmp_info"
