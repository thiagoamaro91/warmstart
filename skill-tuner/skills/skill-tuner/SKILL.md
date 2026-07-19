---
name: skill-tuner
description: Evidence-driven improvement loop for your Claude Code skills and hooks. Use when you type /skill-tuner, ask to review or apply skill-tuner findings, or pass "run" with an evidence file. Modes: "run --evidence <path> [--dry-run]" (derive findings from an evidence file, auto-apply the safe tier, write a report and ledger) and "review" (walk the gated punch list interactively). Not for one-off edits to a single skill you already know is wrong; this is for turning accumulated evidence into safe fixes.
---

# skill-tuner

Closes the loop from evidence that a skill or hook underperformed to a fix.

Your Claude Code setup accumulates skills and hooks, and nothing tells you which
ones underperform: a hook that keeps blocking legitimate commands, a skill whose
description never triggers, a guard that misses the case it exists for. This skill
reads an evidence file you supply, turns it into findings, applies the safe tier
automatically, and gates the risky tier behind your review.

State lives in a `.skill-tuner/` directory at your workspace root:

- `.skill-tuner/ledger.md` (finding history and run counter),
- `.skill-tuner/report-YYYY-MM-DD.md` (one report per run),
- `.skill-tuner/.last-run-summary` (a single line the last run wrote).

## Mode dispatch

- `run --evidence <path> [--dry-run]`: the batch pass. Derives findings from the
  evidence file, applies the safe tier (unless `--dry-run`), writes report + ledger.
- `review` (or no args, interactive): walk gated findings from the ledger one at a time.

## The evidence file

`run` mode consumes an evidence file (JSON) that you produce however you like, from
guard logs, session transcripts, or an auto-capture memory tool such as claude-mem.
skill-tuner does not collect evidence; it reasons over what you hand it. The minimum
shape it reads:

```json
{
  "generated_at_epoch": 1700000000,
  "window_from_epoch": 1699395200,
  "hook_fires":       [{ "ts": "", "reason": "", "command": "" }],
  "skill_invocations": { "<skill-name>": 3 },
  "transcript_blocks": [{ "file": "", "excerpt": "" }],
  "observations":      [{ "type": "", "title": "", "subtitle": "" }]
}
```

Any field may be empty. `hook_fires` are guard blocks in the window;
`skill_invocations` is a per-skill call count; `transcript_blocks` are excerpts of
hook errors seen mid-session; `observations` are optional leads from a memory tool.

## Iron rules (both modes)

1. NEVER edit skill-tuner's own files (this SKILL.md, its tests). Improvements to
   skill-tuner itself are reported as gated findings and applied only by a
   human-driven session, never auto-applied by this skill.
2. Evidence is a lead, not truth. A memory tool or a log can be wrong. Before a
   finding becomes a proposal, verify it against the primary source: open the actual
   skill or hook file, the guard log line, or the transcript excerpt the evidence
   names. Unverifiable findings are dropped, with a note in the report.
3. Check the ledger first. If a finding matches an existing row's target AND type with
   status `rejected`, drop it silently. If it matches a `gated-pending` row, do not
   duplicate it.
4. Caps: at most 5 auto-applied changes and 10 new gated proposals per run. Overflow
   is noted in the report and carries to the next run.
5. No em-dash (U+2014) in anything you write.
6. Commits: one commit per change, run with `git` from your workspace root. Every
   commit message starts with `skill-tuner:`.

## Safe/gated classification

SAFE (auto-applied in run mode): wording-only, zero effect on executable control
flow. Skill `description:` trigger phrasing; SKILL.md body clarifications; hook
comments and the user-facing message strings a hook prints; adding or adjusting tests.

GATED (punch list only): hook match patterns, exit codes, any logic change;
`settings.json` (hook registration, permissions, env); creating or retiring a skill or
hook; agent frontmatter (tools, model); anything under Iron Rule 1.

If in doubt, gate it.

## Finding taxonomy

| Type | Evidence pattern |
|------|------------------|
| hook-false-positive | a guard fire where the blocked command was legitimate (the user retried or worked around it) |
| hook-miss | an incident in observations or transcripts an existing hook should have caught |
| skill-trigger-failure | work matching a skill's purpose done without invoking it (compare skill invocations against transcript activity) |
| skill-content-failure | skill invoked, user corrected the output in-session |
| dead-weight | skill or hook with zero fires across 4 consecutive runs; ALWAYS gated, proposal = retire or fix the description |
| skill-tuner-internal | a defect in skill-tuner itself; ALWAYS gated per Iron Rule 1, applied only by a human-driven session |

## run mode procedure

1. Read the evidence file from `--evidence <path>`. If it is missing or not valid
   JSON, write `.skill-tuner/.last-run-summary` = "run FAILED: no evidence file" and
   stop.
2. Read `.skill-tuner/ledger.md`: collect rejected and pending rows, `runs_completed`.
3. Derive candidate findings per the taxonomy. Verify each (Iron Rule 2), then
   classify safe or gated. Assign ids `F-YYYYMMDD-N`.
4. If `--dry-run`: apply NOTHING. Skip to step 6.
5. Apply the safe tier (cap 5), one commit per change. If a change touched any hook
   file that ships with its own tests, run those tests immediately; on any FAIL,
   revert that commit (`git revert --no-edit HEAD`) and demote the finding to gated
   with a note.
6. Write the report to `.skill-tuner/report-YYYY-MM-DD.md` (template below). Append one
   ledger row per finding (`applied` or `gated-pending`), update the frontmatter:
   `last_run_epoch` = the evidence file's `generated_at_epoch`, `runs_completed`
   incremented by 1. Commit the report + ledger in one commit.
7. Write the one-line summary to `.skill-tuner/.last-run-summary`, format:
   `dry-run: true|false, applied N, gated M, dropped-unverified K`. This file is the
   LAST thing written, so an external watcher can read one line to know the run's shape.

## Report template

    ---
    type: report
    date: YYYY-MM-DD
    dry_run: true|false
    ---
    # skill-tuner report YYYY-MM-DD

    Window: <window_from_epoch> to <generated_at_epoch>. Evidence: N hook fires,
    M skill invocations, K observation leads. Truncated: yes|no.

    ## Auto-applied (safe tier)
    | id | target | change | commit |
    |----|--------|--------|--------|

    ## Gated punch list
    ### F-YYYYMMDD-1: <one-line title> (<taxonomy type>)
    - Evidence: <the specific log line / observation / transcript excerpt>
    - Verified against: <file path or log line checked on disk>
    - Proposed change:
    ```diff
    <ready-to-apply diff>
    ```

    ## Dropped (unverifiable or ledger-rejected)
    - <one line each>

## review mode procedure

1. Read the ledger's `gated-pending` rows and the reports they point to. If none: say
   so and stop.
2. Per finding, one at a time: show the evidence, the verification, and the proposed
   diff. Ask the user: apply / reject / skip (AskUserQuestion when available).
3. apply: make the change, commit per Iron Rule 6, set the ledger row to `approved`. If
   the change touched a hook that ships its own tests, run them and show the result; on
   FAIL, revert and set the row back to `gated-pending` with a note.
   reject: set the row to `rejected` (permanent). skip: leave untouched.
4. Commit the updated ledger.
