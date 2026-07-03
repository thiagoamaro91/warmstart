---
name: wrapup
description: Use when the user says "wrap up", "wrapup", "save context", "done for now", "end session", or when the conversation is winding down after state-changing events (decisions, deliverables, blockers resolved)
---

# Session Wrapup

End-of-session skill. Scans conversation in the main thread, then either updates files inline (small saves) or dispatches parallel subagents (2+ independent update streams) to balance main-context token usage against wall-clock latency.

## Config

This skill depends on one convention: durable session state lives in plain-text context files at the workspace root.

- `context_index.md`: one row per workstream, plus hot items and recently completed. Lives at the workspace root.
- `context_[workstream].md`: one file per workstream (e.g. `context_webapp.md`), holding current state, in progress, blocked, and next actions. Created on demand.
- **Archive threshold**: when a `context_[workstream].md` exceeds 500 lines or 16KB (whichever comes first), move old decisions (>60d) and deliverables (>30d) out to `context_[workstream]_archive.md`.

Both file naming and the archive threshold are load-bearing for Step 2 below; adjust this block if your workspace uses different names or thresholds.

## Checklist

Follow these steps in order. Do not skip any unless the step says to.

### Step 1: Scan Conversation (main thread)

Review the entire conversation and produce a **FINDINGS** block with:

1. **Decisions**: what was decided and why (rationale matters)
2. **Deliverables**: files created or significantly modified, with paths
3. **Status changes**: blockers resolved, new blockers, state transitions
4. **Next actions**: what should happen next session
5. **Workstream**: infer from file paths touched and topics discussed. Match against workstreams in `context_index.md`.
6. **Project**: detect from file paths (e.g., `projects/research-tool/` = research-tool). Note the project root path and list any `docs/` files found there.

If nothing was found (read-only session, no decisions, no changes), output "Nothing to wrap up, session was read-only." and stop.

Write the FINDINGS block as a structured text blob. This is the only input the subagents receive, so make it complete and self-contained.

### Step 2: Apply Updates

First decide **inline vs. fan-out**. Count how many independent update streams the FINDINGS actually need:

- **Context update**: always needed (2a).
- **Doc update**: only if a project was detected (2b).

**If only 2a is needed (1 stream): do it inline in the main thread.** Read and edit the context files yourself. A single cold-start subagent costs more wall-clock time than the few file edits it would do, and the token saving for one file is marginal. Skip the Agent tool entirely.

**If both streams are needed: dispatch them as parallel subagents** (the original design). The fan-out only pays off when there is genuinely independent heavy work to parallelize.

When dispatching, launch the needed subagents simultaneously using the Agent tool. Each receives the FINDINGS blob from Step 1.

**Important:** Use `mode: "auto"` for all subagents so they can write files without prompting.

#### 2a: Context Updater Agent

Prompt the agent with the FINDINGS and these instructions:
- Read `context_[workstream].md` and update: current state, in progress, blocked, next actions
- Read `context_index.md` and update: workstream row (status, last-touched, blockers), hot items, recently completed
- Auto-clear "Recently Completed" items older than 14 days from today
- If context file exceeds 500 lines or 16KB (whichever comes first), archive old decisions (>60d) and deliverables (>30d) to `context_[workstream]_archive.md`
- If no `context_[workstream].md` exists, create it with standard sections

See `references/agent-context-updater.md` for full agent brief.

#### 2b: Doc Writer Agent

Only dispatch if a project was detected in FINDINGS.

Prompt the agent with the FINDINGS and these instructions:
- Find and update stale status lines in project docs (NEXT-STEPS.md, CODE-REVIEW-FINDINGS.md, etc.)
- Append to CHANGELOG.md (create if missing) with `## [YYYY-MM-DD]` format
- Preserve existing structure and style

See `references/agent-doc-writer.md` for full agent brief.

### Step 3: Commit (main thread)

After all updates complete:

0. **Git availability gate.** Run `git rev-parse --is-inside-work-tree` once. If it fails or errors for any reason (broken gitdir, deadlock, not a repo), **skip Step 3 entirely**: do not retry, do not attempt to diagnose or repair git, do not loop. Note in the Step 4 summary "changes saved to disk but not committed (git unavailable)" and proceed. Repairing git is out of scope for wrapup.
1. `git status` to see what was modified
2. Stage ONLY files modified by Step 2 (context, project docs, changelog). Never stage unrelated working changes.
3. Commit:

```bash
git commit -m "$(cat <<'EOF'
chore: session wrap-up - [brief summary of session]

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Step 4: Summary (main thread)

**Quick save** (fewer than 3 file updates): one-line confirmation.

**Full save** (3+ file updates):
- **Done**: what was accomplished this session
- **Decisions**: key decisions with rationale
- **Next session**: actionable items to pick up

3-5 lines max. This is a confirmation, not a debriefing.

## Guardrails

- **Only commit session management files**, never stage unrelated working changes
- **Don't duplicate**: check existing changelog before appending
- **No destructive changes**: never delete or overwrite user content
- **Graceful degradation**: create missing files as needed, skip agents with nothing to do
- **Subagent prompts must be self-contained**: include the FINDINGS blob, today's date, file paths, and all instructions. The agent has zero conversation context.
