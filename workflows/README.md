# workflows

**Work that fans out and checks itself. Cheap finders in parallel, adversarial verifiers before anything is reported.**

## The problem

Ask one agent to review something and then ask the same agent whether the review is right, and it
grades its own homework. It defends what it already wrote. A single pass also has a single blind
spot: whatever the reviewer did not think to look for is simply absent from the result, and nothing
in the run flags the gap.

## The idea

Split the work into two moves that a single agent cannot do to itself.

1. **Fan out independent finders.** Several agents review in parallel, each responsible for one
   dimension (correctness, security, error handling, and so on). Independence is the point: a
   finder looking only at security is not distracted into hand-waving it the way a
   review-everything pass is, and dimensions that one reviewer would skip each get an owner.
2. **Adversarially verify what they find.** Before a finding is reported, hand it to skeptic agents
   whose instruction is to REFUTE it, not to confirm it. A finding is kept only if it survives that
   attack by majority vote. The verifier is trying to make the finding go away; the ones that
   remain are the ones it could not.

Finders are cheap and many; verifiers are expensive and few. You spend the capable model only on
the small set of candidate findings, not on the whole review.

This chapter ships one complete, self-contained example of that shape and a thin skill that runs
it. It teaches the pattern; it is not a wrapper around private production automation.

## Anatomy of the example

The example is [`examples/review-fanout.workflow.js`](examples/review-fanout.workflow.js), a
[Workflow](https://docs.claude.com/en/docs/claude-code) script. It is plain JavaScript that the
Workflow tool runs; the pieces map straight onto the idea above.

- **`export const meta`** is a pure literal at the top: a name, a description, and the two phases
  (`Find`, `Verify`). It has to be pure, because the tool reads it before running anything.
- **Find phase.** The script reads its `target` from `args`, then calls `parallel(...)` over the
  review dimensions, spawning one `agent(..., { model: 'haiku' })` per dimension. Each finder
  returns a structured list of findings validated against a JSON schema, so the shape is
  guaranteed rather than parsed out of prose.
- **Dedupe.** `dedupe(...)` merges every finder's list, collapsing findings with the same
  normalized title into one candidate and keeping the highest severity seen. The merge is
  deterministic given the finders' outputs: first appearance wins, order is preserved, and the
  dedupe step reads no clock or random source. The run as a whole is not deterministic, because the
  `agent(...)` calls that feed it are model calls; the point is that the merge adds no extra
  nondeterminism of its own.
- **Verify phase.** For each candidate the script runs three skeptic agents on the expensive tier
  (`model: 'opus'`), each prompted to refute the finding. All skeptic calls across all findings go
  out in one `parallel(...)` batch. A candidate is upheld only if at least two of its three
  skeptics could not refute it.
- **Return value.** `{ findings, upheld }`: every deduped candidate, and the subset that survived
  verification with its vote count. The survivors are what you report.

The default dimensions are correctness, security, error handling, performance, and readability;
pass `dimensions` in `args` to override them.

## Install

In Claude Code, add this repo as a plugin marketplace (skip if you already added it for another
plugin in this marketplace) and install the plugin:

```
/plugin marketplace add thiagoamaro91/warmstart
/plugin install workflows@warmstart
```

Restart Claude Code. The `fanout-review` skill is then available.

## Usage

Ask for a fan-out review of some code, a diff, or a document, for example: "run a fanout review of
`src/auth.js`". The `fanout-review` skill gathers the target, calls the Workflow tool with
`scriptPath` resolved from the plugin root and `args` set to `{ "target": "..." }`, and reports the
findings that survived verification.

You can also call the Workflow tool directly with the script path and the same `args` object.

## Honesty notes

- **The Workflow tool only runs when you opt in.** Multi-agent orchestration is not on by default;
  the workflow executes only when you explicitly invoke it (through the skill or a direct Workflow
  call). Nothing here runs behind your back.
- **Fan-out costs real tokens.** Several finder agents plus three skeptics per candidate finding is
  many model calls, and the verify phase deliberately uses the expensive tier. This buys review
  quality with tokens; use it when a single pass is not enough, not for a quick read. This README
  quotes no token, speed, or quality numbers, because none were measured for it.
- **This chapter teaches a pattern.** The example is a complete, runnable illustration of the
  fan-out-and-verify shape, not a packaging of any private production system.

## Relation to the rest of the marketplace

warmstart gives a session a warm start; dispatch guards the handoff from one agent to another. This
chapter is about a different moment: a single unit of work that spreads across many agents and
verifies itself before returning. Same thesis as its siblings, plain and legible: the primitives
are ordinary functions, the review dimensions and vote threshold are constants you can read, and
the whole workflow is one file you can open.

## Tests

The chapter has a dependency-free Node test. Run it from the repo root:

```
node workflows/tests/test-workflows-chapter.js
```

It checks that the example workflow parses (as a Workflow script, not as a bare CommonJS or ES
module, since Workflow scripts legitimately combine `export const meta` with top-level `await` and
`return`), that the `meta` block carries a name and description, that the skill frontmatter parses
with a name and description, that no file in the chapter contains a literal em-dash, and that no
disallowed private terms leak into the chapter.
