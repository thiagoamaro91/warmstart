#!/bin/bash
# Context-keeper hook: auto-loads context_index.md on first message of each session.
# Also auto-loads workstream-specific "Required Reading at Session Start" files when
# cwd is inside a workstream subfolder that has its own CLAUDE.md listing them.
# Runs via UserPromptSubmit hook. Uses a /tmp marker to fire only once per session.

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
SESSION_ID="${SESSION_ID//[^a-zA-Z0-9_-]/}"
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Fall back to shell pwd if JSON didn't include cwd (hook process inherits cwd from CC)
if [ -z "$CWD" ]; then
  CWD=$(pwd)
fi

if [ -z "$SESSION_ID" ]; then
  exit 0
fi

MARKER_FILE="/tmp/claude-ctx-${SESSION_ID}"

# Already loaded this session - stay silent
if [ -f "$MARKER_FILE" ]; then
  exit 0
fi

touch "$MARKER_FILE"

# Clean up markers older than 24h
find /tmp -maxdepth 1 -name "claude-ctx-*" -mtime +1 -delete 2>/dev/null

# --- Resolve the workspace root ---
# Priority 1: explicit override. Priority 2: the OUTERMOST ancestor of CWD that
# contains a CLAUDE.md (the workspace root sits above any workstream subfolder).
# If neither yields a path, the stages below no-op quietly.
WORKSPACE_ROOT="${WARMSTART_WORKSPACE_ROOT:-}"
if [ -z "$WORKSPACE_ROOT" ]; then
  SEARCH="$CWD"
  while [ -n "$SEARCH" ] && [ "$SEARCH" != "/" ]; do
    if [ -f "$SEARCH/CLAUDE.md" ]; then
      WORKSPACE_ROOT="$SEARCH"   # keep climbing; last match wins = outermost
    fi
    SEARCH=$(dirname "$SEARCH")
  done
fi

# --- 1) Workspace index (existing behaviour) ---

CONTEXT_FILE="$WORKSPACE_ROOT/context_index.md"

if [ -f "$CONTEXT_FILE" ]; then
  echo "SESSION CONTEXT (auto-loaded by context-keeper):"
  echo ""
  FSIZE=$(wc -c < "$CONTEXT_FILE")
  SOFT_CAP=16384  # ~4K tokens; a dashboard should fit well under this
  if [ "$FSIZE" -le "$SOFT_CAP" ]; then
    cat "$CONTEXT_FILE"
  else
    # Oversized dashboard: every session and every subagent pays this in
    # context. Inject only the decision-relevant top (Active Workstreams +
    # Hot Items), drop the "Recently Completed" log (auto-clears, not needed
    # for active work), and hard-cap at a line boundary. Full file stays on
    # disk untouched - read it on demand if a section is needed.
    awk -v cap="$SOFT_CAP" '
      /^## Recently Completed/ { exit }
      { b += length($0) + 1
        if (b > cap) { print "...[truncated - read context_index.md for the rest]"; exit }
        print }
    ' "$CONTEXT_FILE"
    echo ""
    echo "[context-keeper] context_index.md is ${FSIZE} bytes (cap ${SOFT_CAP}). Showing the active dashboard only; \"Recently Completed\" and any overflow were omitted. Trim/archive it during /wrapup to clear this notice and cut per-session startup cost."
  fi
  echo ""
fi

# --- 2) Workstream required reading (new) ---
# If cwd is inside a workstream subfolder and that folder's CLAUDE.md has a
# "Required Reading at Session Start" block, inline those files. This activates
# SME/specialist mode from message 1 instead of leaving it as a doc-rule the
# model has to discover and follow.

# Files the Claude Code harness already auto-loads as project instructions; skip
# them here to avoid token duplication.
ROOT_CLAUDE_MD="$WORKSPACE_ROOT/CLAUDE.md"
ROOT_INDEX="$WORKSPACE_ROOT/context_index.md"

if [ -n "$CWD" ] && [ -d "$CWD" ] && [ -n "$WORKSPACE_ROOT" ]; then
  case "$CWD" in
    "$WORKSPACE_ROOT"/*) IN_WORKSPACE=1 ;;
    *) IN_WORKSPACE=0 ;;
  esac

  if [ "$IN_WORKSPACE" = "1" ]; then
    # Walk up from cwd, looking for the deepest CLAUDE.md strictly *below* the
    # workspace root (the root CLAUDE.md is already auto-loaded).
    CURRENT="$CWD"
    WS_CLAUDE_MD=""
    while [ "$CURRENT" != "/" ] && [ "$CURRENT" != "$WORKSPACE_ROOT" ]; do
      if [ -f "$CURRENT/CLAUDE.md" ]; then
        WS_CLAUDE_MD="$CURRENT/CLAUDE.md"
        break
      fi
      CURRENT=$(dirname "$CURRENT")
    done

    if [ -n "$WS_CLAUDE_MD" ] && [ -f "$WS_CLAUDE_MD" ]; then
      WS_DIR=$(dirname "$WS_CLAUDE_MD")

      # Capture the Required Reading block: lines after "## Required Reading at
      # Session Start" until the next "## " heading.
      REQUIRED_BLOCK=$(awk '
        /^## Required Reading at Session Start/ { capture=1; next }
        capture && /^## / { exit }
        capture { print }
      ' "$WS_CLAUDE_MD")

      if [ -n "$REQUIRED_BLOCK" ]; then
        # From each numbered list line, extract the first backtick-quoted path.
        PATHS=$(echo "$REQUIRED_BLOCK" | awk '
          /^[0-9]+\.[ \t]/ {
            match($0, /`[^`]+`/)
            if (RSTART > 0) {
              p = substr($0, RSTART + 1, RLENGTH - 2)
              print p
            }
          }
        ')

        if [ -n "$PATHS" ]; then
          echo ""
          echo "=== WORKSTREAM REQUIRED READING (auto-loaded by context-keeper) ==="
          echo "Source: $WS_CLAUDE_MD"
          echo "The workstream CLAUDE.md instructed these files be read in order before responding."
          echo "Loading them as session context so specialist/SME mode is active from message 1."
          echo ""

          TOTAL_BYTES=0
          MAX_BYTES=$((200 * 1024))  # 200KB cap across all required-reading files

          while IFS= read -r p; do
            [ -z "$p" ] && continue
            # Resolve path: ~ expansion, absolute paths kept, otherwise relative to WS_DIR
            case "$p" in
              "~/"*) RESOLVED="$HOME/${p#~/}" ;;
              "/"*)  RESOLVED="$p" ;;
              "./"*) RESOLVED="$WS_DIR/${p#./}" ;;
              *)     RESOLVED="$WS_DIR/$p" ;;
            esac

            # Skip files already auto-loaded by the harness
            case "$RESOLVED" in
              "$ROOT_CLAUDE_MD"|"$ROOT_INDEX")
                echo "[SKIP: $RESOLVED - already auto-loaded as project instructions]"
                continue
                ;;
              "$WS_CLAUDE_MD")
                echo "[SKIP: $RESOLVED - workstream CLAUDE.md already auto-loaded]"
                continue
                ;;
            esac

            if [ -f "$RESOLVED" ]; then
              FILE_SIZE=$(wc -c < "$RESOLVED" 2>/dev/null | tr -d ' ')
              if [ "$((TOTAL_BYTES + FILE_SIZE))" -gt "$MAX_BYTES" ]; then
                echo "[SKIPPED $RESOLVED: would exceed 200KB cap]"
                continue
              fi
              TOTAL_BYTES=$((TOTAL_BYTES + FILE_SIZE))
              echo ""
              echo "--- FILE: $RESOLVED ---"
              cat "$RESOLVED"
              echo ""
            else
              echo "[MISSING: $RESOLVED]"
            fi
          done <<< "$PATHS"

          echo ""
          echo "=== END WORKSTREAM REQUIRED READING ==="
        fi
      fi
    fi
  fi
fi
