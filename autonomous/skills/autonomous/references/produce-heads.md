# Produce-Heads - detail for phases 5-7

Read the section for the head Triage detected. Each head is a thin adapter over
the shared skeleton: it only changes how you *produce*, how you *verify the truth
of what you produced*, and which *adversarial review* critiques it.

The pattern to keep in mind: the Verify gate is the truth gate. It is the one
step you must not fake. For every head, you advance to Critique only after you've
seen evidence the gate is met, not after you've decided it probably is.

---

## Code

**Produce.** Isolate in a git worktree first when the change spans several files.
Build test-first, and when the plan has independent tasks, hand each to a fresh
subagent so no single context carries the whole build. When you hit an unknown
API mid-build, do a scoped docs or web lookup instead of guessing, the same
lookup-not-guess reflex as recon, just later. Debug systematically on any
failure rather than patching symptoms.

**Verify gate - a real end-to-end run on real or seeded data.** Green unit tests
are necessary, not sufficient: they miss integration gaps, contract mismatches,
and one-of-N escapes. Run the actual app or CLI on realistic input and read the
output. Confirm the behavior with your own eyes before any success claim.

**Critique room.** Put the diff in front of a fresh reviewer: a subagent briefed
to refute the change, plus whatever review tooling you have (a built-in code
review command, a second-model reviewer). Re-verify any fact the code now
hardcodes (a rate, a limit, a deadline). Triage the feedback: verify each
suggestion, don't perform agreement. Fix criticals before ship.

**Ship.** Finish the branch: open a PR or merge per the project's flow.

---

## Decision

For consequential choices: which vendor, which architecture, whether to migrate,
a contract response, a budget anchor, an offer to counter. This is the
highest-stakes head, the downside of a wrong call dwarfs any code bug, so the
grounding has to be real.

**Produce.** Frame the live options as a tight comparison. For each option,
state the key facts it depends on and where each came from. Anchor any dispute in
the governing document's own terms (cite by section), and treat a named
authority's written answer as more authoritative than a generic rule, find the
source that settles it before stating a rule as fact.

**Verify gate - every option's key facts are verified, and you land on ONE clear
recommendation with rationale.** No "it depends." If the facts genuinely fork the
recommendation, name the single variable that decides it and recommend per its
likely value. Verify figures, dates, and rules against recent, primary sources
rather than second-hand summaries.

**Critique room.** Put a critical subagent (or a small panel) on the
recommendation: what fact is stale, what option was missed, what assumption is
load-bearing. Fix before recording.

**Ship.** Record the decision and its rationale to the workspace's decision log
and context notes (correct any wrong prior note you found). This is a decision
*recorded*, not an action taken. If the decision implies an outward action
(send, sign, pay), that's a separate confirmed step, never automatic.

---

## Document

For proposals, decks, reports, specs, cover emails, policy or admin letters,
playbooks.

**Produce.** Use the right generator for the format (a Word generator for
`.docx`, a slide generator for decks, a PDF generator for PDFs, plain markdown
otherwise). Write in the user's house style: **lead with the one point plus the
concrete ask up front in plain language**; heavy legal or technical scaffolding
goes in an appendix, never the body. For formal correspondence, anchor in the
governing document's own terms. When a counterpart writes in a given language,
answer in that language.

**Verify gate - it leads with point plus ask, and every external fact, figure,
or clause in it is verified.** A deliverable that opens with throat-clearing or
cites an unverified number fails the gate. Verify the facts; cross-check any
clause citation against the actual document.

**Critique room.** Put a review subagent (or a small panel matched to the format)
on the draft to attack clarity, the strength of the ask, and any unsupported
claim. Fix before ship.

**Ship - DRAFT only. Never send or publish.** Save the artifact, surface the path
at Checkpoint 2, and tell the user it's ready for their review and send. This is
a hard rule, not a default.

---

## Strategy

For "what should we build or do next", roadmap calls, positioning, competitor
response, outreach sequencing.

**Produce.** Ground first: a real research pass on competitors, market, and prior
art so the thinking sits on real signals, not vibes. Generate and weigh options
deliberately. Challenge the premise before the plan, validate that the pain is
real and impacting before designing for it.

**Verify gate - grounded in real competitor/market data AND a falsifiable next
step is named.** A strategy with no cheap test that could prove it wrong is a
vibe, not a strategy. Name the smallest experiment that would validate or kill
it, the cheapest real signal you can chase before the big build.

**Critique room.** Put a critical subagent (or a small panel) on the assumptions
and the sequencing. Stress the framing where it may not fit the actual stage of
the business or the actual audience.

**Ship.** A prioritized direction with the next concrete action, recorded to the
workspace's context notes. Not an action taken, the next step is for the user to
greenlight or for a follow-up `/autonomous` run to execute.
