#!/bin/sh
# Block Bash tool calls that redirect toolchain caches (Go build/module cache, GOPATH, pnpm store).
# Agents hitting a cache write error tend to "fix" it by pointing the cache into the repo, which
# duplicates hundreds of MB per worktree and has ended up committed before.
#   PreToolUse (Bash): exit 2 rejects the call and feeds the reason back to the model.
# Reading values (`go env GOCACHE`) is left alone.

input="$(cat)"

case "$input" in
  *GOCACHE*|*GOMODCACHE*|*GOPATH*|*store-dir*|*STORE_DIR*) ;;
  *) exit 0 ;;
esac

command -v jq >/dev/null 2>&1 || exit 0
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"

if printf '%s' "$cmd" | grep -Eq "(GOCACHE|GOMODCACHE|GOPATH|npm_config_store_dir|PNPM_STORE_DIR)=|go[[:space:]]+env[[:space:]]+-w[[:space:]]+GO(CACHE|MODCACHE|PATH)|--store-dir"; then
  echo "Blocked: do not redirect toolchain caches (GOCACHE, GOMODCACHE, GOPATH, pnpm store). The global defaults are shared across worktrees and safe for concurrent agents. If a cache write fails, stop and report the error to the user instead." >&2
  exit 2
fi

exit 0
