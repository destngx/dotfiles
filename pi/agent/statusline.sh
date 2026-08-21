#!/usr/bin/env bash
# Claude Code status line: Minimal Clean edition with AI Gateway Weekly Usage

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

# ── Context (colored percent text, no icon) ──
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

# ── Resolve Provider Host ──
provider_host=""
if [ -f "$HOME/.pi/agent/models.json" ]; then
  provider_host=$(jq -r '.providers.anthropic.baseUrl // .providers.openai.baseUrl // empty' "$HOME/.pi/agent/models.json" 2>/dev/null || true)
fi
if [ -z "$provider_host" ] && [ -n "$cwd" ] && [ -f "$cwd/.pi/models.json" ]; then
  provider_host=$(jq -r '.providers.anthropic.baseUrl // .providers.openai.baseUrl // empty' "$cwd/.pi/models.json" 2>/dev/null || true)
fi
provider_host="${provider_host:-${ANTHROPIC_BASE_URL:-${OPENAI_BASE_URL:-${AI_GATEWAY_URL:-http://localhost:8080}}}}"
provider_host="${provider_host%/v1}"
provider_host="${provider_host%/}"

# ── Gateway Usage: Primary as Weekly Remaining + Reset Priority in Local Time ──
usage_part=""
usage_json=$(curl -s --max-time 1 -X 'GET' "${provider_host}/v1/usage" -H 'accept: application/json' -H 'X-AI-Provider: openai' 2>/dev/null || true)
if [ -n "$usage_json" ] && [ "$usage_json" != "null" ]; then
  pri_used=$(echo "$usage_json" | jq -r '.rate_limits.primary.used_percent // empty' 2>/dev/null || true)
  r5h=$(echo "$usage_json" | jq -r '.display["5h_reset_at"] // empty' 2>/dev/null || true)
  rWeekly=$(echo "$usage_json" | jq -r '.display["weekly_reset_at"] // empty' 2>/dev/null || true)

  if [ -n "$pri_used" ]; then
    remains_weekly=$((100 - pri_used))
    [ "$remains_weekly" -lt 0 ] && remains_weekly=0

    # Reset priority: weekly if non-empty, else 5h if non-empty
    raw_reset="${rWeekly:-$r5h}"
    reset_str=""
    if [ -n "$raw_reset" ] && [ "$raw_reset" != "null" ]; then
      local_time=$(date -jf "%Y-%m-%d %H:%M %Z" "$raw_reset" "+%-d %B %H:%M" 2>/dev/null || echo "")
      if [ -n "$local_time" ]; then
        reset_str=" ${DIM}↻${local_time}${RESET}"
      fi
    fi

    weekly_col="$GREEN"
    if [ "$remains_weekly" -le 10 ] 2>/dev/null; then weekly_col="$RED"
    elif [ "$remains_weekly" -le 30 ] 2>/dev/null; then weekly_col="$YELLOW"; fi

    usage_part="${weekly_col}${remains_weekly}% weekly${RESET}${reset_str}"
  fi
fi

# ── Code velocity inside branch ──
velocity="${GREEN}+${lines_add}${RESET} ${RED}-${lines_del}${RESET}"

# ── Assemble Single Line ──
out=""
if [ -n "$repo" ]; then
  out="${BOLD}${YELLOW} ${repo}${RESET}"
  if [ -n "$branch" ]; then
    out="${out} ${BOLD}${CYAN} (${branch}${dirty} ${velocity})${RESET}"
  fi
fi

out="${out:+$out ${DIM}|${RESET} }${ctx_part}"
if [ -n "$usage_part" ]; then
  out="${out} ${DIM}|${RESET} ${usage_part}"
fi
out="${out} ${DIM}|${RESET} ${cost_part}"
out="${out} ${DIM}|${RESET} ${MAGENTA}${model}${RESET}"

printf '%b' "$out"
