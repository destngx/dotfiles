#!/usr/bin/env bash
# Claude Code status line: adaptive text & numbers

input=$(cat)

# ── Colors ──
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
MAGENTA='\033[35m'
BLUE='\033[34m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Parse JSON fields ──
model=$(echo "$input" | jq -r '.model.display_name // .model.name // .model.id // .model // "Unknown"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // .used_percentage // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // .cost.total // .cost // 0')
lines_add=$(echo "$input" | jq -r '.cost.total_lines_added // .lines_added // 0')
lines_del=$(echo "$input" | jq -r '.cost.total_lines_removed // .lines_removed // 0')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')

# ── Git info ──
branch=""
repo=""
dirty=""
if [ -n "$cwd" ]; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  repo=$(basename "$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
  if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain -unormal 2>/dev/null)" ]; then
    dirty="${RED}*${RESET}"
  fi
fi

# ── Context (pure text & numbers) ──
if [ -n "$used" ]; then
  used_int=$(printf '%.1f' "$used")
  if (( $(echo "$used >= 90" | bc -l 2>/dev/null || echo 0) )); then pct_color="$RED"
  elif (( $(echo "$used >= 70" | bc -l 2>/dev/null || echo 0) )); then pct_color="$YELLOW"
  else pct_color="$GREEN"; fi
  ctx_part="${pct_color}${used_int}%${RESET}"
else
  ctx_part="--%"
fi

# ── Cost ──
cost_part="${YELLOW}$(printf '$%.3f' "$cost")${RESET}"

# ── Code velocity inside branch ──
velocity="${GREEN}+${lines_add}${RESET} ${RED}-${lines_del}${RESET}"

# ── Single line (clean, no icons) ──
out=""
if [ -n "$repo" ]; then
  out="${BOLD}${YELLOW}${repo}${RESET}"
  if [ -n "$branch" ]; then
    out="${out} ${BOLD}${CYAN}(${branch}${dirty} ${velocity})${RESET}"
  fi
fi

out="${out:+$out ${DIM}|${RESET} }${ctx_part}"
out="${out} ${DIM}|${RESET} ${cost_part}"
out="${out} ${DIM}|${RESET} ${MAGENTA}${model}${RESET}"

printf '%b' "$out"
