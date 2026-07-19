---
name: autonomous
description: >-
  Drive a task end to end autonomously with research grounding and adversarial
  review, across code OR decisions OR documents OR strategy. Use when the user
  says "/autonomous", "run this autonomously", "do this autonomously", "take
  this to done", "drive this to done", "handle this end to end", "just
  build/decide/draft this and surface when done", or otherwise hands off a whole
  task to run heads-down. Trigger even when the intent is described loosely
  ("can you take care of this whole thing", "go do X and ping me when it's
  ready") rather than by name. Covers far more than code: a high-stakes decision
  (which vendor, which architecture, whether to migrate), a deliverable (a spec,
  a report, a proposal, an email, a playbook), or a strategy call (what to build
  next) all run through the same engine. Do NOT trigger for a quick one-shot
  answer the user wants inline right now, or when they explicitly want to stay
  in the loop at every step.
---

# Autonomous Delivery Engine

One research-grounded loop, four produce-heads, adversarial verification at both
ends. You drive it heads-down and surface at exactly two checkpoints.

## Why this exists

Autonomous work fails two symmetric ways: you build confidently on wrong or
stale facts (garbage in), or you ship confidently-wrong output (garbage out). A
wrong tax assumption and a wrong API signature are the same bug class at
different altitudes. So this engine bookends one delivery loop with the same
adversarial-verification discipline at both ends: **research verifies the
inputs, critique verifies the outputs.** Code is just one head; the skeleton is
identical for a decision, a document, or a strategy call.

## The autonomy contract (read first)

The point of this skill is to run end to end without asking permission at every
phase. That is trust, not a blank cheque:

- **Self-confirm before irreversible or outward-facing actions**: sending email,
  force-pushing, deleting things you did not create, posting publicly, touching
  data you were told is sensitive. Running heads-down changes the cadence, not
  your judgment.
- **Non-code heads stop at a draft or recommendation for review. They never
  auto-send or auto-publish.** Drive all the way to the artifact, then stop at
  the doorstep.
- Any safety hooks the workspace has configured (destructive-command guards,
  write-boundary guards, and the like) still fire. Don't fight them; if one
  blocks you, that's the signal to stop and surface.

## Start every run by laying down the rails

The phases below are not a suggestion you hold in your head across a long run.
**Create one TodoWrite item per phase you'll actually run** (skip phases a head
doesn't use, e.g. Isolate for non-code). This is what keeps the loop from
quietly losing a step on a long run. Then announce: the detected head, whether
research will fire, and the acceptance gate you're driving toward.

## Shared skeleton

```
0 Triage      head + knowns-vs-unknowns; read the project's own notes/docs FIRST
1 Recon       lean-by-default research (gated); cache the brief to a notes file
2 Frame       shape the options, seeded by the brief
3 Plan        head-specific plan
              -- CHECKPOINT 1: show the plan, allow veto --
4 Isolate     git worktree (code only)
5 Produce     head-specific engine
6 Verify      head-specific truth gate
7 Critique    head-specific adversarial review -> fix criticals
8 Ship        code: PR/merge - others: draft/recommendation for review
9 Persist     write findings back to notes/docs
              -- CHECKPOINT 2: done / blocked --
```

Steps 0-4 and 8-9 are the same for every head. Only 5-7 vary. The per-head
detail for 5-7 lives in `references/produce-heads.md` - read it once you know the
head, so you load only the adapter you need.

## Phase 0 - Triage

**Detect the head** from the working directory and the task verbs (override with
`--type`):

- a code repo + verbs build/fix/refactor/implement/debug -> **code**
- "should I / which / X vs Y / is it worth / decide" -> **decision**
- "draft / write / email / spec / deck / report / post / letter / playbook" -> **document**
- "what to build/do next / roadmap / competitor / positioning / strategy" -> **strategy**
- genuinely ambiguous on consequential work -> ask once, don't guess.

**Classify unknowns.** A task is *knowns-only* (skip research) when it's a
bugfix/refactor in familiar code, or a deliverable where every fact is already
in hand. It *has unknowns* when it touches a new library/API, a version
migration, an open "best way" question, or any external constant (rate, date,
price, limit, clause) that would be wrong if you guessed.

**Always check what's already known first:** read the project's own notes, docs,
and any prior research the workspace has captured. Re-researching something that
was already verified is waste and risks contradicting a hard-won correction.

## Phase 1 - Recon (only if unknowns, or `--deep`)

Lean by default. After Triage classifies the unknowns, resolve them with
research subagents so the controller context stays clean:

- **2+ unknowns -> fan out.** Dispatch one research subagent per unknown (or a
  small batch), each briefed with the single question, the kind of source that
  settles it (a primary spec, a current price page, a benchmark), and an
  instruction to return only the finding plus its source. Facts want a
  fact-checking pass; a library/API question wants the current docs; an open
  "best approach" question wants a wider search.
- **1 unknown -> inline.** Resolve it yourself with a single focused search.

Either way you now hold a small brief: for each unknown, a `finding`, a
`source`, and a `confidence`. Write the brief to a notes file so Frame and Plan
cite verified facts instead of memory. If an unknown stays unresolved, decide
per unknown: re-run deeper, proceed while noting the gap, or stop.
`--no-research` skips this phase entirely.

## Phases 2-3 - Frame and Plan

Frame the approach seeded by the brief: for code, the shape of the change; for a
decision, the live options; for a document or strategy, the outline. Then build
the head-specific plan (see references): a task-by-task plan for code, an
option-set for a decision, an outline for a document or strategy. For risky or
expensive designs, pressure-test the plan with a critical subagent before the
checkpoint.

**CHECKPOINT 1.** Surface the plan for a cheap veto (see Checkpoints below), then
go heads-down.

## Phases 4-8 - Isolate, Produce, Verify, Critique, Ship

Read `references/produce-heads.md` for the detail of your head. The
non-negotiable across all heads is the **Verify gate**: do not advance to
Critique until the head's truth gate is actually met and you've seen the
evidence (a real run, a verified fact set), not assumed it. For code, isolate in
a git worktree first when the change touches several files.

## Phase 9 - Persist

Write the durable findings back where the next session will find them: research
findings and corrected facts into the project's notes, decisions into a decision
log, and workstream state into whatever context file the workspace keeps. If you
found a wrong assumption during the run, correct it at the source so it doesn't
mislead the next run.

## Checkpoints (exactly two)

1. **Plan ready** - the user can veto the approach.
2. **Done or blocked** - merged / draft-ready / decided, or stopped with the
   reason and what you need.

Each checkpoint surfaces an in-session message. If the workspace has an optional
notification step wired up (a message to the user through whatever channel they
configured, with no specific vendor assumed), fire it best-effort at each
checkpoint; never block the run on it, and fall back to the in-session message
if it isn't available.

Do not add a third checkpoint. The whole point is heads-down between these two.
If you feel the urge to check in mid-build, that's usually a sign the plan was
underspecified - fix the plan next time, don't add interrupts.

## Flags

- `--type code|decision|document|strategy` - force the head
- `--deep` - force deeper research in recon
- `--no-research` - skip recon (knowns-only, max speed)

## Red flags (stop and correct)

| Thought | Reality |
|---------|---------|
| "I'll just build on what I remember" | If it's an external fact, verify it. That's the front bookend. |
| "Tests pass, I'm done" (code) | The gate is a real end-to-end run, not green units. |
| "It's obviously the right call" (decision) | Verify each option's facts before recommending. No "it depends". |
| "I'll send the email to save a step" | Non-code ships as a draft. Never auto-send. |
| "Let me check in real quick" | Two checkpoints only. Underspecified plan, not a new interrupt. |
| "Research first, always" | Triage gates it. Knowns-only tasks skip recon. |
