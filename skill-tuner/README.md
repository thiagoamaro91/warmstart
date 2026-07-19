# skill-tuner

**An evidence-driven improvement loop for your Claude Code skills and hooks. Findings in, safe
fixes auto-applied, risky ones gated behind human review.**

## The problem

Your Claude Code setup accumulates skills and hooks over time, and nothing tells you which ones
underperform. A guard hook keeps blocking a command that was actually fine, so you learn to work
around it. A skill's description never triggers, so the work it was built for gets done by hand.
A guard misses the exact case it exists for. Each of these leaves a trace, in guard logs, in
session transcripts, in whatever memory tool you run, but the traces just pile up. Nobody reads
them, and the setup quietly drifts out of tune.

## The idea

Turn the traces into fixes on a schedule, and be honest about which fixes a machine should make on
its own.

The loop is: evidence in, findings out, safe tier auto-applied, risky tier human-gated. You hand
skill-tuner an evidence file. It derives candidate findings (a hook that fired on a legitimate
command, a skill that never triggered, a guard that missed), verifies each one against the actual
file or log line before trusting it, and then splits them two ways:

- **Safe tier, applied automatically.** Wording-only changes with zero effect on control flow: a
  skill's trigger phrasing, a clarification in a SKILL.md body, a hook's comment or the message it
  prints, a test. These get applied and committed, one commit each, capped per run.
- **Gated tier, left as a punch list.** Anything that changes behavior: a hook's match pattern or
  exit code, a `settings.json` edit, creating or retiring a skill, agent frontmatter. These are
  written up with the evidence and a ready-to-apply diff, and wait for you to walk them in review
  mode and say apply, reject, or skip.

The rule of thumb is simple: if a change could alter what the setup *does*, a human approves it. If
in doubt, it gets gated.

## Two modes

| Mode | What it does |
|------|--------------|
| `run --evidence <path> [--dry-run]` | The batch pass. Reads the evidence file, derives and verifies findings, applies the safe tier (skipped under `--dry-run`), writes a report and updates the ledger. |
| `review` | Walks the gated punch list interactively, one finding at a time: shows the evidence and the proposed diff, and you choose apply, reject, or skip. |

State lives in a `.skill-tuner/` directory at your workspace root: `ledger.md` (the finding history
and run counter), one `report-YYYY-MM-DD.md` per run, and a `.last-run-summary` one-liner.

## The evidence file

skill-tuner reasons over evidence you supply; it does not collect it. You produce an evidence file
(JSON) however suits your setup, from guard logs, session transcripts, or an auto-capture memory
tool such as claude-mem. The shape it reads:

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

Every field may be empty. `hook_fires` are guard blocks in the window; `skill_invocations` is a
per-skill call count; `transcript_blocks` are excerpts of hook errors seen mid-session;
`observations` are optional leads from a memory tool. Hand skill-tuner whichever of these you can
gather, and it reasons over what it gets.

## What it is not

- **Not an evidence collector.** The private version this was extracted from included a collector
  wired to a specific memory-tool database, a specific guard-log format, and one machine's file
  layout, plus a headless launcher and a notification integration tied to the author's own
  infrastructure. None of that is generic, so none of it ships here. You bring the evidence file;
  skill-tuner does the reasoning. Cutting the collector was deliberate: shipping a half-personal
  script that only runs on one machine would be worse than shipping none.
- **Not a config auditor.** It acts on evidence that something underperformed, not on a static read
  of your config structure.
- **Not a magic fixer.** It never edits its own files, it verifies every finding against the
  primary source before proposing it, and it gates anything that could change behavior. Evidence is
  a lead, not a verdict.

## Install

In Claude Code, add this repo as a plugin marketplace (skip if you already added it for warmstart or
dispatch) and install the plugin:

```
/plugin marketplace add thiagoamaro91/warmstart
/plugin install skill-tuner@warmstart
```

Restart Claude Code. Then run `/skill-tuner run --evidence path/to/evidence.json` for a batch pass,
or `/skill-tuner review` to walk the gated punch list.

## Tests

The chapter has a dependency-free Node test that checks the SKILL.md frontmatter parses, that no
file carries a literal em-dash, and that no personal residue survived the extraction. Run it with
Node from the repo root:

```
node skill-tuner/tests/test-skill-tuner-chapter.js
```

## Relation to warmstart

warmstart (the first plugin in this marketplace) gives sessions a warm start: durable state in
markdown files. dispatch guards the handoff from one agent to another. skill-tuner closes a third
loop: the setup improving itself from evidence of how it actually performed. Same thesis throughout,
plain files, legible rules, and a human in the loop for anything that changes behavior. The three
install independently; take any or all.
