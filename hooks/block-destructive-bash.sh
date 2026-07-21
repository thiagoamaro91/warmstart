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

# ${IFS}/$IFS field-splitting evades whitespace-based matching (bash expands it
# to a space at execution time regardless of how it's written here), so
# normalize it to a literal space before any of the checks below run.
CMD_NORM=${CMD//'${IFS}'/ }
CMD_NORM=${CMD_NORM//'$IFS'/ }

block() {
  echo "$(date '+%F %T') BLOCKED: $1 :: $CMD" >>"$LOG"
  echo "BLOCKED: $1" >&2
  exit 2
}

# rm with BOTH -r and -f present (any flag order, combined or separate, long
# forms), scoped to the specific rm invocation's own argument list so a flag
# on a LATER command joined by ; & | can't trigger a false block. Command-name
# detection also covers path-prefixed (/bin/rm) and quote-preceded (e.g. inside
# `sh -c '...'`) invocations; backslash-escaped (\rm) is matched separately
# since awk treats a literal backslash inside a bracket expression as an escape.
RM_NAME_RE=$'(^|[[:space:]]|[(`\'"/])rm[[:space:]]'
if printf '%s\n' "$CMD_NORM" | awk -v name_re="$RM_NAME_RE" '
    {
      n = split($0, seg, /[;&|]/)
      for (i = 1; i <= n; i++) {
        s = seg[i]
        if ((s ~ name_re) || (index(s, "\\rm ") > 0)) {
          lc = tolower(s)
          r = (lc ~ /(^|[[:space:]])-[a-z]*r/) || (lc ~ /--recursive/)
          f = (lc ~ /(^|[[:space:]])-[a-z]*f/) || (lc ~ /--force/)
          if (r && f) { found=1; exit }
        }
      }
    }
    END { exit !found }
  '; then
  block 'Use trash instead of rm -rf'
fi

# find ... -delete
if echo "$CMD_NORM" | grep -qE '(^|[;&|(`][[:space:]]*)find[[:space:]][^;&|]*[[:space:]]-delete([[:space:]]|$)'; then
  block 'Use trash instead of find -delete'
fi

# git clean -f / -fd / -fdx : force-removes untracked files, can wipe untracked
# work in your working tree or a worktree. Require both `git clean` and a force
# flag, scoped to the same command segment (see the rm check above for why).
GIT_CLEAN_NAME_RE='^[[:space:]]*git[[:space:]]+clean[[:space:]]'
if printf '%s\n' "$CMD_NORM" | awk -v name_re="$GIT_CLEAN_NAME_RE" '
    {
      n = split($0, seg, /[;&|]/)
      for (i = 1; i <= n; i++) {
        if (seg[i] ~ name_re) {
          lc = tolower(seg[i])
          f = (lc ~ /(^|[[:space:]])-[a-z]*f/) || (lc ~ /--force/)
          if (f) { found=1; exit }
        }
      }
    }
    END { exit !found }
  '; then
  block 'git clean -f removes untracked files; stage or stash instead'
fi

exit 0
