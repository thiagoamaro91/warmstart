#!/usr/bin/env bash
# PreToolUse guardrail (Bash): block destructive commands that bypass trash/git.
# Extracted from the inline settings.json hook (2026-06-14) to add: fail-closed
# behaviour on missing jq, a block audit log, and `git clean -f` coverage.
#
# Fails CLOSED if jq is missing: a guard that cannot parse the command must not
# silently allow it (contrast the write guards, which fail open).
# Covers: rm with -r and -f (any order/case), find ... -delete, git clean -f.
# Use `trash` for deletes; stage or stash instead of `git clean`.

LOG="$HOME/.claude/hooks/guard.log"

if ! command -v jq >/dev/null 2>&1; then
  echo "$(date '+%F %T') block-destructive-bash: jq missing, failing closed" >>"$LOG"
  echo 'BLOCKED: jq missing, cannot verify command safely (failing closed)' >&2
  exit 2
fi

CMD=$(jq -r '.tool_input.command // empty')
[ -n "$CMD" ] || exit 0

block() {
  echo "$(date '+%F %T') BLOCKED: $1 :: $CMD" >>"$LOG"
  echo "BLOCKED: $1" >&2
  exit 2
}

# rm with BOTH -r and -f present (any flag order, combined or separate, long forms).
# Regexes preserved verbatim from the original proven inline hook.
if echo "$CMD" | grep -qE '(^|[[:space:]]|[;&|(`])rm[[:space:]]' \
   && echo "$CMD" | grep -qiE '(^|[[:space:]])-[a-zA-Z]*[rR]|--recursive' \
   && echo "$CMD" | grep -qiE '(^|[[:space:]])-[a-zA-Z]*[fF]|--force'; then
  block 'Use trash instead of rm -rf'
fi

# find ... -delete
if echo "$CMD" | grep -qE '(^|[;&|(`][[:space:]]*)find[[:space:]][^;&|]*[[:space:]]-delete([[:space:]]|$)'; then
  block 'Use trash instead of find -delete'
fi

# git clean -f / -fd / -fdx : force-removes untracked files, can wipe untracked
# work in your working tree or a worktree. Require both `git clean` and a force flag.
if echo "$CMD" | grep -qE '(^|[;&|(`][[:space:]]*)git[[:space:]]+clean[[:space:]]' \
   && echo "$CMD" | grep -qiE '(^|[[:space:]])-[a-zA-Z]*[fF]|--force'; then
  block 'git clean -f removes untracked files; stage or stash instead'
fi

exit 0
