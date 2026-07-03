#!/usr/bin/env bash
# PreToolUse guardrail: block writes/edits that introduce a banned character
# or pattern. This ships configured to block the em-dash (U+2014) as a worked
# example; swap in your own banned pattern by editing BANNED_PATTERN below
# (for example a smart-quote range, a curly apostrophe, or a forbidden word).
#
# Scans in UTF-8 mode via `perl -CSD`. Byte-mode greps silently miss multibyte
# code points like U+2014, so perl is deliberate here.
# Wire it in your settings.json for Write|Edit|MultiEdit (see settings-snippet.json).
#
# Fails OPEN if jq or perl is missing: a missing dependency must not hard-block
# every write in the session. The downside is one banned character could slip
# through if tooling is broken, which is recoverable; blocking all writes is not.

input=$(cat)

command -v jq   >/dev/null 2>&1 || { echo 'block-em-dash: jq missing, failing open'   >&2; exit 0; }
command -v perl >/dev/null 2>&1 || { echo 'block-em-dash: perl missing, failing open' >&2; exit 0; }

# The banned pattern, as a perl regex. Swap this for your own rule.
BANNED_PATTERN='\x{2014}'

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')

# Collect all text this tool would write to disk.
case "$tool" in
  Write)
    content=$(printf '%s' "$input" | jq -r '.tool_input.content // empty')
    ;;
  Edit)
    content=$(printf '%s' "$input" | jq -r '.tool_input.new_string // empty')
    ;;
  MultiEdit)
    content=$(printf '%s' "$input" | jq -r '[.tool_input.edits[]?.new_string] | join("\n")')
    ;;
  *)
    exit 0
    ;;
esac

[ -n "$content" ] || exit 0

# perl exits 1 the moment it sees U+2014, 0 if the content is clean.
if printf '%s' "$content" | BANNED_PATTERN="$BANNED_PATTERN" perl -CSD -ne 'exit 1 if /$ENV{BANNED_PATTERN}/'; then
  exit 0
fi

cat >&2 <<'EOF'
BLOCKED: this write contains an em-dash character (U+2014), banned by CLAUDE.md.
Replace it with a comma, parentheses, a colon, or a regular hyphen (-).
Re-issue the write with the em-dash removed.
EOF
exit 2
