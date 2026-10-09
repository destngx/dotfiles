#!/usr/bin/env bash
# Claude Code status line: RGB gradient, dynamic emoji, cost, code velocity

input=$(cat)

# ── Colors ──
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
MAGENTA='\033[35m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Truecolor helper ──
rgb() { printf '\033[38;2;%d;%d;%dm' "$1" "$2" "$3"; }

# ── Parse JSON fields ──
model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
used=$(echo "$input" | jq -r '
  .context_window as $c
  | if ($c.current_usage and ($c.context_window_size // 0) > 0) then
      ($c.current_usage | (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)) * 100 / $c.context_window_size
    else ($c.used_percentage // empty) end')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
lines_add=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_del=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
effort=$(echo "$input" | jq -r '.effort.level // empty')
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# ── Git info ──
branch=""
repo=""
if [ -n "$cwd" ]; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  repo=$(basename "$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
fi

# ── Starship-style directory (default starship: ~ substitution, 3 components max) ──
dir="${cwd/#$HOME/~}"
if [ -n "$repo" ]; then
  # Within a repo, truncate to repo root like starship does
  top=$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)
  rel="${cwd#"$top"}"
  dir="${repo}${rel}"
fi
IFS='/' read -ra _parts <<< "$dir"
if [ "${#_parts[@]}" -gt 3 ]; then
  n=${#_parts[@]}
  dir="…/${_parts[n-3]}/${_parts[n-2]}/${_parts[n-1]}"
fi

# ── Git dirty marker ──
dirty=""
if [ -n "$branch" ] && [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
  dirty="*"
fi

# ── Context bar: RGB gradient, full blocks only ──
BAR_WIDTH=6
# Hide the gauge (keep the percentage) in narrow panes
MIN_COLS_FOR_BAR=100
cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 200)}
[ "$cols" -lt "$MIN_COLS_FOR_BAR" ] && BAR_WIDTH=0

# Window size as 200k / 1M
ctx_size_part=""
if [ -n "$ctx_size" ]; then
  if [ "$ctx_size" -ge 1000000 ] && [ $(( ctx_size % 1000000 )) -eq 0 ]; then
    ctx_size_part="${DIM}/$(( ctx_size / 1000000 ))M${RESET}"
  else
    ctx_size_part="${DIM}/$(( ctx_size / 1000 ))k${RESET}"
  fi
fi

if [ -n "$used" ]; then
  used_int=$(printf '%.0f' "$used")

  # Round to nearest block
  filled=$(( (used_int * BAR_WIDTH + 50) / 100 ))

  bar=""
  for (( i=0; i<BAR_WIDTH; i++ )); do
    pos=$(( i * 100 / (BAR_WIDTH - 1) ))

    if [ "$pos" -le 50 ]; then
      r=$(( 0 + 220 * pos / 50 ))
      g=200
      b=$(( 80 - 80 * pos / 50 ))
    else
      adj=$(( pos - 50 ))
      r=220
      g=$(( 200 - 160 * adj / 50 ))
      b=$(( 0 + 20 * adj / 50 ))
    fi

    if [ "$i" -lt "$filled" ]; then
      bar="${bar}$(rgb $r $g $b)█"
    else
      bar="${bar}\033[38;2;60;60;60m░"
    fi
  done
  [ -n "$bar" ] && bar="${bar}${RESET}"

  if [ "$used_int" -ge 90 ]; then pct_color="$RED"
  elif [ "$used_int" -ge 70 ]; then pct_color="$YELLOW"
  else pct_color="$GREEN"; fi

  ctx_part="${bar:+$bar }${pct_color}$(printf '%.1f' "$used")%${RESET}${ctx_size_part}"
else
  empty=""
  for (( i=0; i<BAR_WIDTH; i++ )); do empty="${empty}░"; done
  ctx_part="${empty:+\033[38;2;60;60;60m${empty}${RESET} }--%${ctx_size_part}"
fi

# ── Cost ──
cost_part="${YELLOW}$(printf '$%.2f' "$cost")${RESET}"

# ── Plan usage limits (shown as remaining) ──
remain_color() {
  if [ "$1" -le 10 ]; then printf '%s' "$RED"
  elif [ "$1" -le 30 ]; then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"; fi
}

limit_part() {
  local label="$1" pct="$2" reset="$3" fmt="$4" remain part
  [ -n "$pct" ] || return
  remain=$(( 100 - $(printf '%.0f' "$pct") ))
  [ "$remain" -lt 0 ] && remain=0
  part="${label:+$label }$(remain_color "$remain")${remain}% left${RESET}"
  [ -n "$reset" ] && part="${part} ${DIM}till${RESET} $(date -r "$reset" "$fmt")"
  printf '%s' "$part"
}

five_part=$(limit_part "" "$five_pct" "$five_reset" '+%H:%M')
week_part=$(limit_part "weekly" "$week_pct" "$week_reset" '+%-d %B %H:%M')

# ── Code velocity ──
velocity="${GREEN}+${lines_add}${RESET} ${RED}-${lines_del}${RESET}"

# ── Single line ──
out=""
[ -n "$dir" ] && out="${BOLD}${CYAN}${dir}${RESET}"
[ -n "$branch" ] && out="${out:+$out }${MAGENTA}${RESET} (${BOLD}${MAGENTA}${branch}${RED}${dirty}${RESET} ${velocity})"
out="${out:+$out ${DIM}|${RESET} }${ctx_part}"
[ -n "$five_part" ] && out="${out} ${DIM}|${RESET} ${five_part}"
[ -n "$week_part" ] && out="${out} ${DIM}|${RESET} ${week_part}"
out="${out} ${DIM}|${RESET} ${cost_part}"
out="${out} ${DIM}|${RESET} ${MAGENTA}${model}${RESET}"
[ -n "$effort" ] && out="${out} ${DIM}${effort}${RESET}"

printf '%b' "$out"
