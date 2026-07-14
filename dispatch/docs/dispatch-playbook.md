# Dispatch Playbook

How to dispatch subagents so the work that comes back is usable. Rules 1-2 are
mechanically enforced by the dispatch plugin's PreToolUse guard
(`hooks/guard-agent-briefing.js`): it blocks the dispatch and echoes the fix.

## 1. Every dispatch is a briefing, not a sentence

Subagents start with ZERO conversation context: they have not seen the user's
request, prior tool results, or decisions made this session. Write every Agent
prompt as a self-contained briefing with these five parts:

1. **OBJECTIVE**: one verifiable goal.
2. **CONTEXT**: why the task exists, what was already decided or ruled out this
   session, exact file paths, and PASTED snippets/data the agent needs. Never
   write "as discussed" or "the file mentioned above"; the agent cannot see it.
3. **SCOPE**: what NOT to touch (write boundaries, sibling workstreams, files to
   leave alone).
4. **OUTPUT CONTRACT**: the agent's final message is the ONLY thing that comes
   back. Specify its exact shape, e.g. "return a markdown table of path:line +
   one-line finding, no prose intro". Tell the agent to return raw data, not a
   narrative of its process.
5. **DONE CHECK**: how the agent verifies its own work before returning (run the
   test, curl the endpoint, re-grep the tree).

Minimum 500 chars for general-purpose dispatches, 200 for Explore/Plan.
Deliberate tiny dispatch: include `[brief-ok]` in the prompt.

## 2. Pick the model per dispatch, never inherit by default

Pass `model` explicitly on every dispatch:

- `haiku`: mechanical work (extraction, reformatting, log scans, checklist sweeps).
- `sonnet`: DEFAULT executor for code and standard multi-step tasks.
- `opus` (or the session tier): only for adversarial verification, judging other
  agents' outputs, and architecture decisions.

Never set `CLAUDE_CODE_SUBAGENT_MODEL` in settings; it silently overrides every
per-call model pin.

## 3. Pick the agent type deliberately

- Read-only search, multi-file recon, "where is X" questions: **Explore**, never
  general-purpose.
- Implementation planning: **Plan**.
- A domain agent fits (a project-specific specialist defined in your workspace):
  use it; domain agents carry their own model and tool limits.
- **general-purpose** only when the task needs edits plus multi-step tool use
  and no specialist fits.

## 4. Orchestrator stance

In multi-step work the main session conducts: decompose, dispatch, judge,
integrate. Executors write the code and content.

- Independent dispatches go in ONE message so they run in parallel.
- To continue a prior agent with its context intact, message it; a fresh
  Agent call starts blank. An idle agent with no result is pending, not lost;
  re-ping it instead of respawning.
- Once a search is delegated, do not redo it in the main thread; wait.
- Scale the fan-out to the task: one focused agent for a one-file question,
  a fleet only when coverage genuinely needs it.
- Act on settled decisions; do not re-litigate or re-ask what the session
  already answered.

## 5. Context hygiene in the main thread

Main-thread context is for decisions, not raw material.

- Answering a question that needs 3+ files read: delegate to Explore and keep
  only the conclusion.
- Read partial files (offset/limit) when the region is known.
- Never pull bulk file dumps or long logs into the orchestrator; have the
  subagent summarize to the output contract.

## 6. Verify before reporting

- For findings that matter, spawn one skeptic subagent prompted to REFUTE the
  claim; drop whatever does not survive. Verifiers get the expensive model;
  finders get the cheap one.
- Claim "done" only after running the actual verification command (test,
  build, curl) and reading its real output. Never infer success.

## 7. Final-message discipline

Everything the user needs from a turn must be in the turn's final message:
outcome first, supporting detail after. Mid-turn notes may never be seen.
The same rule cascades to subagents via the output contract in rule 1.
