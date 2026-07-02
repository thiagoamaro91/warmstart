#!/bin/bash
# Integration test: the shipped cross-cutting CLAUDE.md template must parse through
# context-keeper.sh stage 2 and inline the sibling context files it lists under
# "Required Reading at Session Start". Self-contained and re-runnable.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
HOOK="$(cd "$HERE/.." && pwd)/context-keeper.sh"
TEMPLATE="$(cd "$HERE/../.." && pwd)/templates/crosscutting-CLAUDE.md"

WS=$(mktemp -d /tmp/wsxc.XXXXXX)
SID="wsxc-$$"
cleanup() { rm -rf "$WS"; rm -f /tmp/claude-ctx-${SID}*; }
trap cleanup EXIT

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }
has() { case "$1" in *"$2"*) ok "$3" ;; *) bad "$3 (missing: $2)" ;; esac; }

printf '# Root\n' > "$WS/CLAUDE.md"
printf '# Context Index\n\n## Active Workstreams\n' > "$WS/context_index.md"

mkdir -p "$WS/webapp" "$WS/research" "$WS/billing"
printf 'WEBAPP_CTX_MARKER: current app state.\n' > "$WS/webapp/context_webapp.md"
printf 'RESEARCH_CTX_MARKER: pricing research.\n' > "$WS/research/context_research.md"

cp "$TEMPLATE" "$WS/billing/CLAUDE.md"

out=$(printf '{"session_id":"%s","cwd":"%s"}' "$SID" "$WS/billing" \
  | WARMSTART_WORKSPACE_ROOT="$WS" bash "$HOOK")

has "$out" "WORKSTREAM REQUIRED READING" "stage2 banner present"
has "$out" "WEBAPP_CTX_MARKER" "sibling webapp context inlined"
has "$out" "RESEARCH_CTX_MARKER" "sibling research context inlined"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
rc=0
[ "$FAIL" -eq 0 ] || rc=1
exit $rc
