# Glossary

Plain-language definitions for the terms used across warmstart's docs. Where a term has a longer
treatment, the entry points to it.

### ACI (agent-computer interface)

The design of the tools an AI agent uses, treated with the same care a team would spend on a human
user interface. Good tool names, argument shapes that make mistakes hard, and results written in
readable language rather than opaque IDs. See the first pillar in [philosophy.md](philosophy.md).

### Agent loop

The core way an agent works: the model uses a tool, reads the result, decides the next step, and
repeats, with no human issuing each individual step. The ground truth driving each turn comes from
the tool results, not from the model's own reasoning.

### CLAUDE.md

The instructions file Claude Code loads automatically at the start of every session. In warmstart it
is tier 1: the stable facts that are always in context. A workstream subfolder can have its own
`CLAUDE.md` too, which is how [cross-cutting](#cross-cutting-workstream) reading lists are declared.

### Compaction

Claude Code's built-in way of shrinking a conversation when it grows too long: it summarizes the
older turns to free up room. Useful, but lossy. Compaction "doesn't always pass perfectly clear
instructions to the next agent", which is why warmstart keeps durable state in files instead of
relying on the summary. See [harness](#harness).

### Context engineering

Anthropic's own name for the discipline of curating the set of tokens in the model's context window:
what to add, what to remove, across the whole session. warmstart is one concrete application of it.
The community label "loop engineering" refers to the same idea. See [philosophy.md](philosophy.md).

### Context index (`context_index.md`)

The one-page dashboard of every workstream: what is active, blocked, and next. It is tier 2, injected
once per session by the [context-keeper](#context-keeper) hook, and hard-capped so it can never crowd
out the real work. Think of it as the summary; the detail lives in the per-workstream files.

### Context tiering

Loading context in tiers instead of all at once: tier 1 is always loaded (`CLAUDE.md` and memory),
tier 2 is the index injected once per session, tier 3 is a per-workstream file loaded only when that
topic is in play. The mechanism is described in [the-pattern.md](the-pattern.md).

### context-keeper

The session-start [hook](#hook) that injects the [context index](#context-index-context_indexmd) on
the first message and, when you launch from a cross-cutting workstream folder, inlines that
workstream's Required Reading files. The load-bearing piece of the system.

### Cross-cutting workstream

A workstream whose work genuinely depends on another workstream's context (for example, a web app
whose billing work also needs the tax-research notes). Its `CLAUDE.md` carries a `## Required Reading
at Session Start` list; context-keeper reads that list and loads the named files automatically.

### Fail-open vs fail-closed

How a [guard hook](#guard-hook) behaves when it hits an internal error. Fail-open means "on error,
allow the action" (used for convenience hooks, so a bug never blocks your work). Fail-closed means
"on error, block the action" (used for safety hooks, so a bug never lets a dangerous action
through). Each hook in this repo documents which it is.

### Generator / evaluator separation

The practice of having one agent produce work and a separate, skeptical agent judge it, rather than
letting the producer grade itself. A generator grading its own work is systematically too lenient;
a standalone evaluator tuned to be skeptical is far more reliable. The fourth pillar in
[philosophy.md](philosophy.md).

### Guard hook

A [hook](#hook) whose job is to stop a mistake before it happens: blocking a destructive shell
command, an oversized memory file, or a banned character. Guard hooks are what keep warmstart's
conventions true instead of merely documented.

### Harness

The system around the model that carries a long task across many sessions: the scripts, the files
on disk, the git history, and the loop that ties them together. warmstart is a small harness. Its
persistent artifacts (the context files) survive [compaction](#compaction) because they live on
disk, not in the conversation.

### Hook

A shell script Claude Code runs automatically at a defined moment, such as when you submit a prompt
(`UserPromptSubmit`) or before a tool runs (`PreToolUse`). warmstart uses hooks to inject context and
to guard against mistakes. The wiring lives in your `settings.json`; this repo ships a snippet for it.

### Injection

Text a [hook](#hook) adds into the conversation on your behalf. warmstart injects the context index
at session start so Claude begins already oriented. The "injection window" is the budget for that
text, which is why the index is capped at 16KB.

### Just-in-time context

Loading a piece of context at the moment it becomes relevant rather than stuffing everything in up
front. Anthropic cites Claude Code itself as the canonical example: `CLAUDE.md` up front, but `glob`
and `grep` to pull in files on demand. The second pillar in [philosophy.md](philosophy.md).

### Loop engineering

A community label (coined 2026) for authoring the system that prompts your agent, instead of
hand-issuing each prompt yourself. Anthropic's own term for the underlying discipline is
[context engineering](#context-engineering). See [philosophy.md](philosophy.md) for the naming, straight.

### MCP (Model Context Protocol)

An open standard for connecting external tools and data sources to an AI agent. Mentioned here only
in passing: the ACI pillar's advice about readable tool results applies to MCP servers too.

### Persistent artifacts

State written to disk (files, git commits) so it outlives any single session. The opposite of
keeping everything in the conversation and losing it to [compaction](#compaction). warmstart's
context files are its persistent artifacts.

### Poka-yoke

A term from manufacturing for mistake-proofing: shaping a thing so the wrong action is structurally
hard to take. Applied to tools, it means designing arguments so an agent cannot easily misuse them,
rather than just documenting the pitfalls.

### Subagent

A separate agent invocation with its own clean context, dispatched to do one bounded piece of work
and report back. Used for [generator/evaluator separation](#generator--evaluator-separation) (a fresh
skeptic has no attachment to the work it is judging) and to keep the main session's context small.

### Workstream

One ongoing area of work with its own state: a project, a domain, a track. warmstart keeps at most
eight of them in the [context index](#context-index-context_indexmd), each with its own deep-state
file. The unit the whole system is organized around.

### wrapup

The end-of-session routine that writes state back to disk: what changed, what is blocked, what is
next, then commits it. wrapup is what closes the loop, so the next session's [injection](#injection)
is current. The token-heavy step, and the one that earns the warm start. `wrapup-lite` is the v0.1
version: the core loop only, without the optional enrichment steps.

### Write Boundary

A rule in a [cross-cutting workstream](#cross-cutting-workstream)'s `CLAUDE.md` that says it may read
other workstreams' context but must keep its own deliverables in its own folder, and ask before
writing into a sibling. Reading across is free; writing across needs permission.
