#!/usr/bin/env bash
# PreToolUse guardrail: keep MEMORY.md index files under the session-load limit.
# Claude Code loads only the first 200 lines / 25KB of a MEMORY.md at session
# start; anything past that is silently dropped. This hook catches the bloat at
# WRITE time (the moment a too-long entry is added) instead of weeks later via a
# git-status warning, so it self-corrects in the session that created it.
#
# It blocks: a Write whose content exceeds a safe 24KB budget or any line over
# ~220 chars; an Edit/MultiEdit that ADDS a line over ~220 chars or that GROWS an
# already-oversized file. It never blocks a size-reducing edit, so trimming is
# always allowed. Only files literally named MEMORY.md are guarded.
#
# Fails OPEN if jq is missing (a broken dependency must not hard-block writes).
# Wired in ~/.claude/settings.json for Write|Edit|MultiEdit, like block-em-dash.

MAX_BYTES=24000
MAX_LINE=220

input=$(cat)
command -v jq >/dev/null 2>&1 || { echo 'guard-memory-size: jq missing, failing open' >&2; exit 0; }

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')
fp=$(printf '%s'   "$input" | jq -r '.tool_input.file_path // empty')

case "$(basename "$fp")" in
  MEMORY.md) ;;
  *) exit 0 ;;
esac

longest_line() { awk 'BEGIN{m=0}{if(length($0)>m)m=length($0)}END{print m+0}'; }

block() {
  cat >&2 <<EOF
BLOCKED: this write would leave $(basename "$fp") over its load limit ($1).
Claude Code loads only the first 200 lines / 25KB of MEMORY.md at session start;
content past that is silently dropped. Keep each index line under ~200 chars
(one line per memory: "- [Title](file.md) - short hook") and move detail into
the topic file, then re-issue.
EOF
  exit 2
}

case "$tool" in
  Write)
    content=$(printf '%s' "$input" | jq -r '.tool_input.content // empty')
    maxln=$(printf '%s' "$content" | longest_line)
    [ "$maxln" -gt "$MAX_LINE" ] && block "an index line is ${maxln} chars, cap ${MAX_LINE}"
    bytes=$(printf '%s' "$content" | wc -c | tr -d ' ')
    [ "$bytes" -gt "$MAX_BYTES" ] && block "total ${bytes} bytes, cap ${MAX_BYTES}"
    ;;
  Edit)
    new=$(printf '%s' "$input" | jq -r '.tool_input.new_string // empty')
    maxln=$(printf '%s' "$new" | longest_line)
    [ "$maxln" -gt "$MAX_LINE" ] && block "a new index line is ${maxln} chars, cap ${MAX_LINE}"
    if [ -f "$fp" ]; then
      cur=$(wc -c < "$fp" | tr -d ' ')
      old=$(printf '%s' "$input" | jq -r '.tool_input.old_string // empty')
      on=$(printf '%s' "$old" | wc -c | tr -d ' ')
      nn=$(printf '%s' "$new" | wc -c | tr -d ' ')
      delta=$(( nn - on )); proj=$(( cur + delta ))
      [ "$delta" -gt 0 ] && [ "$proj" -gt "$MAX_BYTES" ] && block "edit grows file to ~${proj} bytes, cap ${MAX_BYTES}"
    fi
    ;;
  MultiEdit)
    news=$(printf '%s' "$input" | jq -r '[.tool_input.edits[]?.new_string] | join("\n")')
    maxln=$(printf '%s' "$news" | longest_line)
    [ "$maxln" -gt "$MAX_LINE" ] && block "a new index line is ${maxln} chars, cap ${MAX_LINE}"
    if [ -f "$fp" ]; then
      cur=$(wc -c < "$fp" | tr -d ' ')
      olds=$(printf '%s' "$input" | jq -r '[.tool_input.edits[]?.old_string] | join("\n")')
      on=$(printf '%s' "$olds" | wc -c | tr -d ' ')
      nn=$(printf '%s' "$news" | wc -c | tr -d ' ')
      delta=$(( nn - on )); proj=$(( cur + delta ))
      [ "$delta" -gt 0 ] && [ "$proj" -gt "$MAX_BYTES" ] && block "edits grow file to ~${proj} bytes, cap ${MAX_BYTES}"
    fi
    ;;
  *) exit 0 ;;
esac
exit 0
