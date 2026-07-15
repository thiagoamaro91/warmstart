# autonomous

**Hand a whole task to Claude Code and get it back done. One research-grounded loop, adversarial review at both ends, and exactly two places it stops to check with you.**

## The problem

Asking an agent to "just handle this" fails two symmetric ways. It builds
confidently on a fact that was wrong or stale (garbage in), or it ships output
that is confidently wrong and nobody checked it (garbage out). A wrong tax
figure and a wrong API signature are the same bug at different altitudes: both
are an unverified input or an unverified output that no one caught before it
mattered.

The usual reactions are both bad. Either you babysit every step, which defeats
the point of delegating, or you let it run blind and inherit whatever it
guessed.

## The idea

Bookend one delivery loop with the same discipline at both ends: **research
verifies the inputs, critique verifies the outputs.** In between, the agent runs
heads-down and surfaces at exactly two checkpoints, when the plan is ready (you
can veto it) and when the work is done or blocked.

The loop is one shared skeleton with four interchangeable "heads":

- **code** - build or fix something, verified by a real end-to-end run, not just green unit tests.
- **decision** - which vendor, which architecture, whether to migrate, verified by grounding every option in a real source and landing on one clear recommendation.
- **document** - a proposal, a report, a spec, an email, a playbook, verified by leading with the point and checking every fact and figure in it.
- **strategy** - what to build or do next, verified by real market signal and a falsifiable next step.

Only three steps change between heads (how it produces, how it verifies, which
adversarial review critiques it). Everything else, the triage, the research
front-end, the two checkpoints, is identical. The skill detects the head from
your task and loads only the adapter it needs.

## What this is not

- **Not a way to skip review.** The whole design is two verification bookends and
  two human checkpoints. It runs unattended between the checkpoints, not through
  them.
- **Not an auto-sender.** Non-code work stops at a draft or a recommendation. It
  never sends the email, publishes the post, or signs the thing. That is a
  separate step you take after reading it.
- **Not infrastructure.** There is no server, no database, no background daemon.
  It is one skill file plus a per-head reference, read by the model when you
  invoke it.
- **Not a replacement for your judgment on irreversible actions.** Force-pushing,
  deleting things it did not create, anything outward-facing: it stops and
  confirms first, running heads-down or not.

## Install

In Claude Code, add this repo as a plugin marketplace (skip if you already added
it for warmstart) and install the plugin:

```
/plugin marketplace add thiagoamaro91/warmstart
/plugin install autonomous@warmstart
```

Restart Claude Code. That is the whole setup: the skill registers itself, and
there is no step three. It is a skill, not a hook, so it needs nothing on your
PATH.

## Using it

Hand off a whole task and let it run:

```
/autonomous migrate the config loader to the new schema and open a PR
```

Or describe the intent loosely; the skill triggers on a handoff even when you do
not name it ("go do X and ping me when it's ready"). It announces the head it
detected and the gate it is driving toward, stops once to show you the plan, and
stops again when it is done or blocked.

Three flags tune the run:

| Flag | Effect |
|------|--------|
| `--type code\|decision\|document\|strategy` | Force the head instead of letting Triage detect it. |
| `--deep` | Force a deeper research pass in recon. |
| `--no-research` | Skip recon entirely for a knowns-only task (max speed). |

## Relation to warmstart

warmstart (the first plugin in this marketplace) gives sessions a warm start:
durable state in markdown files. dispatch guards the handoff from one agent to
another. autonomous is the third door onto the same thesis: the work runs on
plain files and legible rules, and the discipline (verify the inputs, verify the
outputs, stop at the gates) is written down where you can read it, not hidden in
a black box. The three install independently; take any or all.
