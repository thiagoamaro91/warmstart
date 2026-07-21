#!/bin/bash
# Smoke test for context-keeper.sh.
# Builds a throwaway workspace, feeds the hook synthetic UserPromptSubmit JSON on
# stdin, and asserts stage-1 index injection, 16KB truncation, stage-2 required
# reading, marker-gating idempotency, and the env-var / outermost-CLAUDE.md root
# resolver. Self-contained: creates and removes its own fixtures; re-runnable.

set -u

HOOK="$(cd "$(dirname "$0")/.." && pwd)/context-keeper.sh"

WS=$(mktemp -d /tmp/wstest.XXXXXX)
WS_NOOP=$(mktemp -d /tmp/wstest-noop.XXXXXX)
OUTSIDE_DIR=$(mktemp -d /tmp/wstest-outside.XXXXXX)
TILDE_HOME=$(mktemp -d /tmp/wstest-tildehome.XXXXXX)
SIDS_PREFIX="wstest-$$"
cleanup() { rm -rf "$WS" "$WS_NOOP" "$OUTSIDE_DIR" "$TILDE_HOME"; rm -f /tmp/claude-ctx-${SIDS_PREFIX}-*; }
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

# Confinement fixtures (Defect 1): a workstream whose Required Reading block
# lists an absolute path outside WORKSPACE_ROOT, a "../" escape, a legitimate
# in-workspace file, and a nonexistent file, all in one CLAUDE.md.
printf 'OUTSIDE_SECRET_MARKER: should never be inlined.\n' > "$OUTSIDE_DIR/secret.md"
mkdir -p "$WS/confine"
cat > "$WS/confine/CLAUDE.md" <<EOF
# Confine workstream

## Required Reading at Session Start
1. Read \`$OUTSIDE_DIR/secret.md\` for background.
2. Read \`../../../../../etc/hostname\` for background.
3. Read \`inside.md\` for background.
4. Read \`missing.md\` for background.

## Write Boundary
Keep deliverables in this folder.
EOF
printf 'CONFINE_INSIDE_MARKER: legit in-workspace file.\n' > "$WS/confine/inside.md"

# Tilde fixture (Defect 2): WORKSPACE_ROOT sits under a throwaway HOME so a
# "~/"-prefixed Required Reading path both exercises tilde expansion and
# stays inside WORKSPACE_ROOT (confinement would otherwise skip it).
WS_TILDE="$TILDE_HOME/workspace"
mkdir -p "$WS_TILDE/proj"
printf '# Tilde Workspace\n' > "$WS_TILDE/CLAUDE.md"
cat > "$WS_TILDE/proj/CLAUDE.md" <<'EOF'
# Tilde workstream

## Required Reading at Session Start
1. Read `~/workspace/tilde-notes.md` for background.
EOF
printf 'TILDE_NOTES_MARKER: tilde expansion works.\n' > "$WS_TILDE/tilde-notes.md"

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

# Scenario 6: silent no-op, no context_index.md anywhere up the tree
# WS_NOOP is a bare scratch dir outside WS: no CLAUDE.md and no context_index.md
# in it or in any ancestor, standing in for a project that never adopted
# warmstart (the real-world case a user-scope plugin install must stay quiet in).
unset WARMSTART_WORKSPACE_ROOT
out=$(run_hook "${SIDS_PREFIX}-s6" "$WS_NOOP")
rc=$?
assert_empty "$out" "noop: silent stdout with no context_index.md anywhere up the tree"
if [ "$rc" -eq 0 ]; then ok "noop: exit code 0"; else bad "noop: exit code 0 (got $rc)"; fi
export WARMSTART_WORKSPACE_ROOT="$WS"

# Scenario 7: path confinement (Defect 1) - absolute-outside and "../"-escape
# Required Reading paths are skipped and reported, legit/missing paths behave
# exactly as before.
out=$(run_hook "${SIDS_PREFIX}-s7" "$WS/confine")
assert_contains "$out" "[SKIPPED $OUTSIDE_DIR/secret.md: outside WORKSPACE_ROOT ($WS)" "confine: absolute path outside root is skipped and reported"
assert_absent  "$out" "OUTSIDE_SECRET_MARKER" "confine: absolute-outside file content never inlined"
assert_contains "$out" "[SKIPPED /etc/hostname: outside WORKSPACE_ROOT ($WS)" "confine: relative ../ escape is skipped and reported"
assert_contains "$out" "CONFINE_INSIDE_MARKER" "confine: legitimate in-workspace file still inlined"
assert_contains "$out" "[MISSING: $WS/confine/missing.md]" "confine: nonexistent in-workspace path still reports MISSING"

# Scenario 8: tilde expansion (Defect 2) - a "~/"-prefixed path inside
# WORKSPACE_ROOT resolves and inlines instead of reporting MISSING.
out=$(HOME="$TILDE_HOME" WARMSTART_WORKSPACE_ROOT="$WS_TILDE" run_hook "${SIDS_PREFIX}-s8" "$WS_TILDE/proj")
assert_contains "$out" "TILDE_NOTES_MARKER" "tilde: ~/-prefixed path resolves and inlines"
assert_absent  "$out" "MISSING" "tilde: no MISSING marker for the ~/-prefixed path"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
rc=0
[ "$FAIL" -eq 0 ] || rc=1
exit $rc
