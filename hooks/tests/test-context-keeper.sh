#!/bin/bash
# Smoke test for context-keeper.sh.
# Builds a throwaway workspace, feeds the hook synthetic UserPromptSubmit JSON on
# stdin, and asserts stage-1 index injection, 16KB truncation, stage-2 required
# reading, marker-gating idempotency, and the env-var / outermost-CLAUDE.md root
# resolver. Self-contained: creates and removes its own fixtures; re-runnable.

set -u

HOOK="$(cd "$(dirname "$0")/.." && pwd)/context-keeper.sh"

WS=$(mktemp -d /tmp/wstest.XXXXXX)
SIDS_PREFIX="wstest-$$"
cleanup() { rm -rf "$WS"; rm -f /tmp/claude-ctx-${SIDS_PREFIX}-*; }
trap cleanup EXIT

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

assert_contains() { case "$1" in *"$2"*) ok "$3" ;; *) bad "$3 (missing: $2)" ;; esac; }
assert_absent()   { case "$1" in *"$2"*) bad "$3 (unexpected: $2)" ;; *) ok "$3" ;; esac; }
assert_empty()    { if [ -z "$1" ]; then ok "$2"; else bad "$2 (expected empty, got ${#1} bytes)"; fi; }

run_hook() {
  local sid="$1" cwd="$2"
  printf '{"session_id":"%s","cwd":"%s"}' "$sid" "$cwd" | bash "$HOOK"
}

# --- fixtures ---
printf '# Toy Workspace\n\nRoot CLAUDE.md for the smoke test.\n' > "$WS/CLAUDE.md"

mkdir -p "$WS/research"
cat > "$WS/research/CLAUDE.md" <<'EOF'
# Research workstream

## Required Reading at Session Start
1. Read `notes.md` for the current research state.

## Write Boundary
Keep deliverables in this folder.
EOF
printf 'RESEARCH_NOTES_MARKER: sample note body.\n' > "$WS/research/notes.md"

small_index() {
  cat > "$WS/context_index.md" <<'EOF'
# Context Index

Last updated: 2026-01-01 | Sessions: demo - small index example.

## Active Workstreams
| Workstream | Status | Last touched | Blockers |
|---|---|---|---|
| research | active | 2026-01-01 | none |

## Hot Items (cross-workstream)
- ACTIVE_MARKER: hot item present.

## Recently Completed
- RC_MARKER: this line is disposable.
EOF
}

large_index() {
  {
    printf '# Context Index\n\n'
    printf 'Last updated: 2026-01-01 | Sessions: demo - large index example.\n\n'
    printf '## Active Workstreams\n'
    printf 'ACTIVE_MARKER near the top.\n'
    printf '## Hot Items (cross-workstream)\n'
    i=0
    while [ "$i" -lt 500 ]; do
      printf 'padding line %03d lorem ipsum dolor sit amet consectetur adipiscing elit.\n' "$i"
      i=$((i+1))
    done
    printf '## Recently Completed\n'
    printf 'RC_MARKER must be truncated away.\n'
  } > "$WS/context_index.md"
}

export WARMSTART_WORKSPACE_ROOT="$WS"

# Scenario 1: stage-1 full inject (small index)
small_index
out=$(run_hook "${SIDS_PREFIX}-s1" "$WS")
assert_contains "$out" "SESSION CONTEXT (auto-loaded by context-keeper):" "stage1: banner present"
assert_contains "$out" "ACTIVE_MARKER" "stage1: active content injected"
assert_contains "$out" "RC_MARKER" "stage1: small index injects Recently Completed too"
assert_absent  "$out" "[context-keeper] context_index.md is" "stage1: no truncation notice for small index"

# Scenario 2: idempotency (same session_id twice)
out2=$(run_hook "${SIDS_PREFIX}-s1" "$WS")
assert_empty "$out2" "gating: second run with same session_id injects nothing"

# Scenario 3: 16KB truncation (large index)
large_index
out=$(run_hook "${SIDS_PREFIX}-s3" "$WS")
assert_contains "$out" "[context-keeper] context_index.md is" "trunc: oversize notice present"
assert_contains "$out" "...[truncated - read context_index.md for the rest]" "trunc: awk byte-cap notice present"
assert_absent  "$out" "RC_MARKER" "trunc: Recently Completed dropped past the cap"

# Scenario 4: stage-2 required reading (cwd in subfolder)
out=$(run_hook "${SIDS_PREFIX}-s4" "$WS/research")
assert_contains "$out" "WORKSTREAM REQUIRED READING" "stage2: required-reading banner present"
assert_contains "$out" "RESEARCH_NOTES_MARKER" "stage2: required file inlined"

# Scenario 5: resolver fallback (no env var; outermost CLAUDE.md)
small_index
unset WARMSTART_WORKSPACE_ROOT
out=$(run_hook "${SIDS_PREFIX}-s5" "$WS/research")
assert_contains "$out" "SESSION CONTEXT (auto-loaded by context-keeper):" "fallback: stage1 fires via outermost CLAUDE.md"
assert_contains "$out" "ACTIVE_MARKER" "fallback: index resolved from detected root"
export WARMSTART_WORKSPACE_ROOT="$WS"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
rc=0
[ "$FAIL" -eq 0 ] || rc=1
exit $rc
