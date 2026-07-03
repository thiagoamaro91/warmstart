# The pattern

warmstart is a tiered-context system. The idea, taken from the just-in-time context pillar (see
[philosophy.md](philosophy.md)), is simple: load what a session always needs up front, keep
everything else on disk, and pull each piece in only when it becomes relevant. Three tiers of
context, three moving parts, and one loop that closes at the end of every session so the next one
starts warm.

## The three moving parts

1. **A session-start hook injects a one-page dashboard.** On the first message of a session, the
   hook reads `context_index.md` and injects it into the conversation. Claude wakes up already
   knowing the state of every workstream: what is active, what is blocked, what is next.
2. **Deep state lives in per-workstream files, loaded only when the topic comes up.** The index is
   the summary; the detail sits in `context_<workstream>.md` files that are read on demand, not
   dropped in up front. This is just-in-time context instead of context stuffing.
3. **A wrapup command writes state back at session end.** What changed, what is blocked, what is
   next, all get written to the context files and committed. The loop closes; the next session
   opens on the updated dashboard.

## The three tiers

The system is a load ladder. Each tier is loaded by a different mechanism and holds a different
kind of information.

| Tier | What | When it loads | How |
|------|------|---------------|-----|
| 1 | `CLAUDE.md` plus any memory files | Every session, always | Claude Code's own always-on mechanism |
| 2 | `context_index.md`, the cross-workstream dashboard | Once, on the first prompt | The `context-keeper` hook injects it |
| 3 | `context_<workstream>.md`, the deep state for one workstream | Only when that workstream is in play | Read on demand (the hook can inline it for a cross-cutting workstream, otherwise Claude reads it when the topic comes up) |

Tier 1 is the stable facts that never change within a session. Tier 2 is the volatile summary that
changes every session and is capped so it can never crowd out the actual work. Tier 3 is the
long-form record, as large as it needs to be, because it is only ever loaded a slice at a time.

## How the injection works: `context-keeper.sh`

The hook runs on `UserPromptSubmit`. It has two stages.

**Stage 1, the dashboard.** On the first prompt of a session it injects `context_index.md`, capped
at 16384 bytes (16KB). If the file is larger than the cap, the hook truncates the injected copy at
the `## Recently Completed` heading (or at the byte boundary if that heading is absent) and appends
a short notice that truncation happened. The file on disk is never touched; only the injected copy
is capped. Injection is gated to once per session by a marker file in the system temp directory,
keyed on the session ID, with stale markers cleaned up after 24 hours. So the dashboard arrives on
message one and does not repeat on every later message.

**Stage 2, cross-cutting reading lists.** If the current working directory sits inside a subfolder
whose `CLAUDE.md` contains a `## Required Reading at Session Start` block, the hook parses the
backtick-quoted paths out of that numbered list, resolves each one (home-relative `~/`, absolute,
or relative to the workspace), skips the files the harness already loads (the root `CLAUDE.md`, the
root `context_index.md`, and the workstream's own `CLAUDE.md`), and inlines the rest under a banner.
Stage 2 is capped at 200KB in total. This is how a workstream that genuinely spans two areas (say a
web app whose auth work also needs the research notes) gets both context files loaded automatically
when you launch from its folder.

**Root resolution.** The hook finds the workspace root from the `WARMSTART_WORKSPACE_ROOT`
environment variable, and if that is unset, by climbing up from the current directory to the
outermost `CLAUDE.md` it can find. Nothing about the location is hardcoded.

**Dependencies.** `jq`, `awk`, and standard POSIX utilities. No network calls, no authentication,
no services. It is a shell script that reads files and prints text.

## The conventions the hook relies on

The mechanism only works if a few conventions hold, and the hooks in this repo exist to keep them
true:

- **At most 8 workstreams in the index.** Beyond that, the dashboard stops being a dashboard.
- **Context files archive at roughly 500 lines or 16KB**, moving old dated entries to
  `context_<workstream>_archive.md`. This keeps tier 3 files loadable and keeps the tier 2 index
  under its cap. `guard-context-index-size` enforces the index side of this at write time.
- **The wrapup loop writes state back.** The injection is only as good as the last wrapup. If you
  never write state back, the next session injects a stale dashboard. The loop is the point.

## Repo layout: where each piece lives

```
warmstart/
  README.md                 the what, the pain, the quickstart
  LICENSE                   MIT
  docs/
    philosophy.md           the methodology and its citations
    the-pattern.md          this file: the mechanism
    glossary.md             the vocabulary
  templates/                copy these into your own workspace
    CLAUDE.md.template       the six pattern sections plus a workstream table to fill in
    context_index.md         the tier 2 dashboard skeleton, with a toy example
    context_workstream_shape-a.md   tier 3, session-log shape (diagnostic work)
    context_workstream_shape-b.md   tier 3, categorical shape (pipeline/decision work)
    crosscutting-CLAUDE.md   a workstream with a Required Reading list and a Write Boundary
  hooks/
    context-keeper.sh        the load-bearing piece: injects tier 2, inlines stage-2 reading lists
    block-destructive-bash.sh   blocks a set of dangerous shell commands
    guard-memory-size.sh        keeps memory files from growing past a cap
    guard-context-index-size.sh keeps the index under the injection cap
    block-em-dash.sh            the swap-in-your-own-rule example (blocks one banned character)
    test-guards.sh              the guard-hook test suite
    settings-snippet.json       the wiring block for your settings.json
    README.md                   what each hook does, and fail-open vs fail-closed
    tests/                      hook integration tests
  skills/
    wrapup/                  the end-of-session routine that writes state back
      SKILL.md
      references/            the agent briefs the skill dispatches
```

The two workstream template shapes are a real choice, not decoration. Shape A is a reverse-chron
session log, good for diagnostic and iterative technical work where each entry is a dated
root-cause-and-fix. Shape B is categorical (Current State, Active Decisions, In Progress, Blocked,
Recent Deliverables, Parked, Next Actions), good for pipeline and decision-heavy work. The choice is
driven by the shape of the work, not enforced by any tool.

## Common questions

### Why files instead of a database?

You pay tokens when content enters or leaves the context window, not for where the state sits on
disk in between. The same wrapup writing the same summary would cost the same whether it lands in a
markdown file or a SQL row. Database-backed memory tools are cheaper at write time for a different
reason: they skip curation. A cheap observer captures everything raw, and once you are recording
everything you need search to get any of it back, so the database follows from the choice to not
curate. warmstart pays an expensive distillation step instead, so the next session starts from
decision-grade state rather than from search hits. Two supporting facts worth knowing: `CLAUDE.md`,
the most widely adopted memory mechanism in the Claude Code ecosystem, is a plain markdown file; and
Anthropic's own API memory tool is file-based, not a vector store. Files are not the primitive
approach here, they are the deliberate one, and they buy you something a database cannot: you can
read, edit, and `git diff` your agent's memory.

### How is this different from memory MCPs or auto-capture tools like claude-mem?

They are complementary layers, not competitors. Auto-capture memory tools (claude-mem is the
friendly example) record observations automatically: a searchable log of what happened. warmstart
maintains curated working state: what matters now, injected at session start, and written back
deliberately at session end. A log versus a dashboard. Together they answer different questions,
claude-mem answers "what did we do in June", warmstart answers "where were we and what is next". The
one honest distinction to keep in mind: warmstart also writes state back through the wrapup loop, it
is not only recall. If you had to pick two of cheap, automatic, and reliable, warmstart drops
automatic on purpose: the curation is the cost and the value.

### What does it cost in tokens?

Honestly, the injection side is cheap and the write-back side is not, and it is worth being precise
about which is which.

The injection side is small and hard-capped. The tier 2 index is capped at 16KB, which is roughly
4K tokens, injected once per session. Loading only the active workstream's tier 3 file when the
topic comes up, instead of stuffing every workstream's context in up front, saves tokens rather than
spending them. This side of the ledger is a net win over both context stuffing and re-explaining the
project from scratch each session.

The write-back side, the wrapup, is the real cost. It is token-intensive: it reads the session,
distills what changed, and rewrites the context files. Three things make that honest rather than
alarming. First, wrapup runs as a single inline pass on a small session and only fans out into
parallel streams when there is genuinely more to write. Second, the cost lands at the end of a
session, where the context has already been spent on the actual work. Third, it amortizes against
the re-explanation it replaces: you pay once at session end instead of paying every time the next
session starts cold.

Rather than estimate, this project measures the wrapup cost on a real session and publishes the
number as part of the v0.1 release, on the principle that a memory tool should be able to tell you
what it costs.

Here is that measurement, taken on a real session with a large working context (over 150K tokens).
The wrapup produced about 32K output tokens and about 67K fresh input tokens, plus roughly 2.6M
cache-read tokens, the cheap scan side, since re-reading a large session is most of the work. It ran
in the two layers described above: one orchestrator pass that reads the session and decides what
changed, then two short parallel writer passes that update the context files. Wall-clock was about
eight minutes. In list-price terms that is about four US dollars. Two caveats keep the number honest.
First, this was a deliberately large session; a smaller one reads far less on the scan side and costs
proportionally less, because the cache-read total tracks how much conversation the wrapup has to
digest. Second, list-price dollars are the API-style measure: on a subscription plan the same work
draws down your quota instead of a bill. Read the tokens as the real figure and the dollars as an
illustration.
