#!/usr/bin/env bash
# PreToolUse guardrail: keep the workspace-root context_index.md under the
# injection window context-keeper.sh actually loads. context-keeper.sh injects
# context_index.md at session start, hard-capped at SOFT_CAP=16384 bytes and
# truncated at the first "## Recently Completed" line: content above that
# marker is the live dashboard, content below (or past the cap) is silently
# dropped. If the dashboard region above the marker outgrows the cap, every
# session starts on a truncated, stale dashboard. This hook catches that
# bloat at write time, in the session that creates it.
#
# The two real-world bloat vectors are both single-physical-line growth: a
# table cell or a one-line session narrative that keeps absorbing history
# instead of getting trimmed. Two independent checks, either one blocks:
#   - LINE_MAX: no single line in the new content may exceed this many bytes
#   - REGION_CAP: the dashboard region (content above the marker) may not
#     exceed this many bytes
#
# LINE_MAX/REGION_CAP/REGION_MARKER must move together with context-keeper.sh's
# SOFT_CAP and its "## Recently Completed" truncation anchor.
#
# Fails OPEN if jq is missing, same as guard-memory-size.
# Wired in settings.json for Write|Edit (see settings-snippet.json).

LINE_MAX=2000                              # bytes; normal dashboard rows run 200-1100 bytes, pathological cases hit 15K+ on one line
REGION_CAP=14336                           # bytes; context-keeper.sh SOFT_CAP (16384) minus 2KB headroom
REGION_MARKER='^## Recently Completed'     # must match context-keeper.sh's truncation anchor

input=$(cat)
command -v jq >/dev/null 2>&1 || { echo 'guard-context-index-size: jq missing, failing open' >&2; exit 0; }

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')
fp=$(printf '%s'   "$input" | jq -r '.tool_input.file_path // empty')

[ "$(basename "$fp")" = "context_index.md" ] || exit 0

# --- Resolve the workspace root: explicit override, else the OUTERMOST
# ancestor of the FILE's own directory that contains a CLAUDE.md. Climbs from
# the file's directory, not cwd, since the hook may run from anywhere.
ROOT="${WARMSTART_WORKSPACE_ROOT:-}"
if [ -z "$ROOT" ]; then
  search=$(dirname "$fp")
  while [ -n "$search" ] && [ "$search" != "/" ] && [ "$search" != "." ]; do  # "." stops a relative path from looping forever
    if [ -f "$search/CLAUDE.md" ]; then
      ROOT="$search"   # keep climbing; last match wins = outermost
    fi
    search=$(dirname "$search")
  done
fi

# Only the injected root index is guarded; a context_index.md living in some
# other folder has no session-start injection contract to protect.
[ -n "$ROOT" ] && [ "$fp" = "$ROOT/context_index.md" ] || exit 0

longest_line() { LC_ALL=C awk 'BEGIN{m=0}{if(length($0)>m)m=length($0)}END{print m+0}'; }

region_bytes() { # bytes above the first REGION_MARKER line; whole input if the marker is absent
  LC_ALL=C awk -v marker="$REGION_MARKER" '
    $0 ~ marker { exit }
    { b += length($0) + 1 }
    END { print b+0 }
  '
}

block() {
  cat >&2 <<EOF
BLOCKED: this write would leave context_index.md over its injection window ($1).
context-keeper.sh injects this file at session start, hard-capped at 16KB and
truncated at "## Recently Completed": content above that line is the live
dashboard, content past the cap is silently dropped. Fix: move history into an
archive file under docs/, keep the Sessions narrative to 1-2 entries, and keep
table rows to a few hundred bytes. Shrinking edits are always allowed, so trim
first and re-issue.
EOF
  exit 2
}

case "$tool" in
  Write)
    content=$(printf '%s' "$input" | jq -r '.tool_input.content // empty')
    maxln=$(printf '%s' "$content" | longest_line)
    [ "$maxln" -gt "$LINE_MAX" ] && block "a line is ${maxln} bytes, cap ${LINE_MAX}"
    region=$(printf '%s' "$content" | region_bytes)
    [ "$region" -gt "$REGION_CAP" ] && block "dashboard region is ${region} bytes, cap ${REGION_CAP}"
    ;;
  Edit)
    new=$(printf '%s' "$input" | jq -r '.tool_input.new_string // empty')
    maxln=$(printf '%s' "$new" | longest_line)
    [ "$maxln" -gt "$LINE_MAX" ] && block "a new line is ${maxln} bytes, cap ${LINE_MAX}"
    if [ -f "$fp" ]; then
      cur=$(region_bytes < "$fp")
      old=$(printf '%s' "$input" | jq -r '.tool_input.old_string // empty')
      on=$(printf '%s' "$old" | wc -c | tr -d ' ')
      nn=$(printf '%s' "$new" | wc -c | tr -d ' ')
      delta=$(( nn - on ))
      # The resulting region size isn't knowable from an edit fragment alone, so
      # (like guard-memory-size) fall back to a disk+growth heuristic: block only
      # when the on-disk region is ALREADY over cap and this edit grows it
      # further. A size-reducing or neutral edit never blocks - that asymmetry is
      # the escape hatch the trim/archive flow depends on.
      [ "$cur" -gt "$REGION_CAP" ] && [ "$delta" -gt 0 ] && block "dashboard region is already ${cur} bytes (cap ${REGION_CAP}) and this edit grows it"
    fi
    ;;
  MultiEdit)
    news=$(printf '%s' "$input" | jq -r '[.tool_input.edits[]?.new_string] | join("\n")')
    maxln=$(printf '%s' "$news" | longest_line)
    [ "$maxln" -gt "$LINE_MAX" ] && block "a new line is ${maxln} bytes, cap ${LINE_MAX}"
    if [ -f "$fp" ]; then
      cur=$(region_bytes < "$fp")
      olds=$(printf '%s' "$input" | jq -r '[.tool_input.edits[]?.old_string] | join("\n")')
      on=$(printf '%s' "$olds" | wc -c | tr -d ' ')
      nn=$(printf '%s' "$news" | wc -c | tr -d ' ')
      delta=$(( nn - on ))
      [ "$cur" -gt "$REGION_CAP" ] && [ "$delta" -gt 0 ] && block "dashboard region is already ${cur} bytes (cap ${REGION_CAP}) and these edits grow it"
    fi
    ;;
  *) exit 0 ;;
esac
exit 0
