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
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
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

# ── Starship-style git status markers ──
git_flags=""
if [ -n "$branch" ]; then
  porcelain=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)
  if [ -n "$porcelain" ]; then
    echo "$porcelain" | grep -q '^??' && git_flags="${git_flags}?"
    echo "$porcelain" | grep -q '^.[MD]' && git_flags="${git_flags}!"
    echo "$porcelain" | grep -q '^[MADRC]' && git_flags="${git_flags}+"
  fi
  [ -n "$git_flags" ] && git_flags=" [${git_flags}]"
fi

# ── Context bar: RGB gradient, full blocks only ──
BAR_WIDTH=10

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
  bar="${bar}${RESET}"

  if [ "$used_int" -ge 90 ]; then pct_color="$RED"
  elif [ "$used_int" -ge 70 ]; then pct_color="$YELLOW"
  else pct_color="$GREEN"; fi

  ctx_part="${bar} ${pct_color}${used_int}%${RESET}"
else
  ctx_part="\033[38;2;60;60;60m░░░░░░░░░░${RESET} --%"
fi

# ── Cost ──
cost_part="${YELLOW}$(printf '$%.2f' "$cost")${RESET}"

# ── Plan usage limits ──
pct_color() {
  if [ "$1" -ge 90 ]; then printf '%s' "$RED"
  elif [ "$1" -ge 70 ]; then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"; fi
}

limit_part() {
  local label="$1" pct="$2" reset="$3" fmt="$4" pct_int part
  [ -n "$pct" ] || return
  pct_int=$(printf '%.0f' "$pct")
  part="${label:+$label }$(pct_color "$pct_int")${pct_int}%${RESET}"
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
[ -n "$branch" ] && out="${out:+$out }on ${BOLD}${MAGENTA} ${branch}${RESET}${BOLD}${RED}${git_flags}${RESET}"
out="${out:+$out ${DIM}|${RESET} }${ctx_part}"
[ -n "$five_part" ] && out="${out} ${DIM}|${RESET} ${five_part}"
[ -n "$week_part" ] && out="${out} ${DIM}|${RESET} ${week_part}"
out="${out} ${DIM}|${RESET} ${cost_part}"
out="${out} ${DIM}|${RESET} ${velocity}"
out="${out} ${DIM}|${RESET} ${MAGENTA}${model}${RESET}"
[ -n "$effort" ] && out="${out} ${DIM}${effort}${RESET}"

printf '%b' "$out"
