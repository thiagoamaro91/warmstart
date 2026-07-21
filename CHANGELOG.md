# Changelog

All notable changes to warmstart are recorded here. The format follows the Keep a Changelog
convention, and the project aims to follow semantic versioning.

## [Unreleased]

## [0.3.0] - 2026-07-21

### Added
- Continuous integration: `.github/workflows/ci.yml` runs on every push and pull request to
  `main`. It executes all seven test suites on both Linux and macOS (the two userlands the hooks
  promise to support), lints every tracked shell script with shellcheck at warning severity,
  validates every tracked JSON file with jq, and fails on any literal em-dash in tracked files.
  The README now carries the CI status badge.
- The `skill-tuner` plugin, also distributed from the same marketplace
  (`/plugin install skill-tuner@warmstart`). It is an evidence-driven improvement loop for your
  own skills and hooks: you hand it an evidence file, it derives and verifies findings, and it
  splits them into a safe tier (wording-only changes, auto-applied and committed) and a gated tier
  (anything that changes behavior, written up with a ready-to-apply diff for human review).
  - `skill-tuner/skills/skill-tuner/SKILL.md`, the loop itself, with two modes:
    `run --evidence <path> [--dry-run]` (the batch pass) and `review` (walk the gated punch list
    interactively). State lives in a `.skill-tuner/` directory at the workspace root (ledger,
    per-run report, last-run summary).
  - A dependency-free Node test: `node skill-tuner/tests/test-skill-tuner-chapter.js`, which checks
    the SKILL.md frontmatter, that no file carries a literal em-dash, and that no personal residue
    survived extraction.
  - Extracted from a private version and cut back to what is generic. The private evidence
    collector (bound to one memory-tool database and one machine's log layout), its headless
    launcher, and a notification integration tied to the author's own infrastructure are not
    included; you supply the evidence file, skill-tuner does the reasoning.
- The `autonomous` plugin, also distributed from the same marketplace
  (`/plugin install autonomous@warmstart`). It ships the `/autonomous` skill, which
  drives a whole task end to end through one research-grounded loop with adversarial
  verification at both ends and exactly two human checkpoints:
  - `autonomous/skills/autonomous/SKILL.md`, the shared skeleton (Triage, Recon, Frame,
    Plan, Isolate, Produce, Verify, Critique, Ship, Persist) with four interchangeable
    heads (code, decision, document, strategy) and `--type`, `--deep`, `--no-research`
    flags.
  - `autonomous/skills/autonomous/references/produce-heads.md`, the per-head detail for
    the three phases that vary (Produce, Verify, Critique).
  - A dependency-free Node test: `node autonomous/tests/test-autonomous-chapter.js`,
    which checks the SKILL.md frontmatter, bans the literal em-dash, and runs a
    sanitization sweep over the chapter.
- The `dispatch` plugin, a second plugin distributed from the same marketplace
  (`/plugin install dispatch@warmstart`). It enforces subagent dispatch discipline:
  - `dispatch/hooks/guard-agent-briefing.js`, a PreToolUse guard on `Task|Agent` that blocks
    (exit 2) dispatches whose prompt is under 500 characters (200 for Explore/Plan; a literal
    `[brief-ok]` in the prompt waives the length check) and dispatches without an explicit
    `model` pin (on by default; set `DISPATCH_REQUIRE_MODEL_PIN=0` to turn the pin rule off;
    `[brief-ok]` never waives it). The block message carries the five-part briefing template so
    the model can re-issue immediately. Written in Node with no dependencies (no bash, no jq),
    so it runs on Windows as-is; the one prerequisite is a `node` executable on PATH, which
    Claude Code does not bundle.
  - `dispatch/docs/dispatch-playbook.md`, the seven-rule playbook the guard enforces rules 1-2
    of, injected as session context by a SessionStart hook so users don't edit their CLAUDE.md.
  - A fixture-driven regression suite: `node dispatch/hooks/tests/test-dispatch-hooks.js`.
- The `runbooks` plugin, also distributed from the same marketplace
  (`/plugin install runbooks@warmstart`): two pure-markdown procedure skills extracted from the
  author's live setup, no hooks and no scripts.
  - `runbooks/skills/forcing-questions/`, adversarial demand interrogation for "is this worth
    building" decisions: six forcing questions asked one at a time, explicit anti-sycophancy
    rules, and a closing verdict (build the wedge / reshape / do not build) plus one concrete
    assignment. Forked from the gstack `office-hours` skill's product diagnostic core.
  - `runbooks/skills/spec-diagram/`, specs that lead with an embedded Mermaid diagram: the
    concept-to-pattern matrix, the dual-mode warm-dark gold palette (pastel fills) with 60-30-10
    colour discipline, the
    Mermaid v11 syntax-trap list, and a validate-then-export workflow. The two Mermaid MCP
    servers it can use are optional, with a `@mermaid-js/mermaid-cli` fallback documented.
- The `workflows` plugin, also distributed from the same marketplace
  (`/plugin install workflows@warmstart`). It teaches the fan-out-and-verify multi-agent pattern:
  - `workflows/examples/review-fanout.workflow.js`, a complete, self-contained Workflow script.
    It fans out one cheap (`haiku`) finder agent per review dimension in parallel, dedupes their
    findings by normalized title, then hands each candidate to three skeptic agents on the
    expensive (`opus`) tier prompted to REFUTE it, and upholds a finding only if at least two of
    the three cannot. Deterministic: no clock or random source. `export const meta` is a pure
    literal.
  - `workflows/skills/fanout-review/SKILL.md`, a thin skill that runs the bundled script via the
    Workflow tool with `scriptPath` resolved from the plugin root.
  - A dependency-free regression test: `node workflows/tests/test-workflows-chapter.js` (parses the
    workflow script, checks the meta and skill frontmatter, and scans for em-dashes and leaked
    private terms).

### Security
- `hooks/block-destructive-bash.sh`: the `rm` guard matched only the bare token `rm`, so
  path-prefixed (`/bin/rm`), backslash-escaped (`\rm`), and quote-preceded (`sh -c 'rm ...'`)
  invocations passed unblocked; the command-name match now covers those forms. `${IFS}` and `$IFS`
  word-splitting also evaded the guard entirely, in both the fully-joined and partial forms; both
  are now normalized to a space before matching. `hooks/README.md` now documents the guard's actual
  scope: it stops accidents and offers no defense against deliberate evasion, since variable
  indirection (`X=rm; $X -rf`), `eval`, `echo | sh`, and interpreter one-liners remain out of reach
  by design, as an inherent limit of matching patterns against unexpanded command text.
- `hooks/context-keeper.sh`: Required Reading paths were resolved with no confinement, so a
  workstream CLAUDE.md could name any file the user could read and have it inlined into session
  context. Resolved paths are now normalized and skipped with a report if they fall outside the
  workspace root. Implemented in pure bash rather than with `realpath`, which errors on nonexistent
  paths and resolves symlinks in a way that breaks containment comparisons on macOS.

### Fixed
- `hooks/block-destructive-bash.sh`: the recursive and force flag checks scanned the entire command
  string rather than the `rm` invocation's own arguments, so unrelated commands sharing a line were
  falsely blocked (for example `rm notes.txt; grep -rf pattern.txt logs/`). Flags are now tested
  only against the segment where the command name matched; the same fix applies to the `git clean`
  force check.
- `hooks/context-keeper.sh`: `~/`-prefixed Required Reading paths never resolved, because the tilde
  in `${p#~/}` was expanded on the pattern side rather than the value side. They now resolve
  correctly.
- `dispatch/hooks/guard-agent-briefing.js`: the briefing length gate measured UTF-8 bytes while
  reporting and documenting characters. It now counts characters; for ASCII prompts the behavior is
  unchanged.
- `workflows/examples/review-fanout.workflow.js`: finding titles were normalized to ASCII before
  deduplication, so a title written in a non-Latin script normalized to empty and the finding was
  dropped silently. Normalization is now Unicode aware, and anything that still normalizes to empty
  is logged rather than discarded quietly.
- Regression coverage: `hooks/test-guards.sh` (37 cases), `hooks/tests/test-context-keeper.sh` (21
  cases), `hooks/tests/test-crosscutting-template.sh` (3 cases), and
  `dispatch/hooks/tests/test-dispatch-hooks.js` (24 cases) all pass, with a new case added for every
  bypass and false positive listed above and five new fixtures added for the briefing gate
  boundaries.

### Changed
- `workflows/examples/review-fanout.workflow.js`: a failed or malformed skeptic response was
  counted as a vote that a finding survived scrutiny. Skeptic outcomes are now three-way (upheld,
  refuted, invalid), invalid results count toward neither side, and the published output carries
  the effective skeptic count. This is a behavior change: a finding whose valid votes cannot reach
  the uphold threshold is now excluded as insufficiently scrutinized rather than published.

## [0.2.0] - 2026-07-04

warmstart installs as a Claude Code plugin: two commands in place of the five-step manual setup,
with the by-hand path kept intact for people who want to own their own wiring.

### Added
- Plugin manifests: `.claude-plugin/plugin.json` and a self-referencing
  `.claude-plugin/marketplace.json` (`"source": "./"`), so the repo is its own plugin marketplace.
- `hooks/hooks.json`: auto-wires the four shipped hooks on install (no `settings.json` to merge, no
  `chmod`), invoking each as `bash "${CLAUDE_PLUGIN_ROOT}/hooks/<name>.sh"`. It mirrors
  `hooks/settings-snippet.json` (the manual path) event for event and matcher for matcher.
- `skills/setup/` (`/warmstart:setup`): writes `CLAUDE.md` and `context_index.md` from the templates
  on first run, and never overwrites a file that already exists (it prints merge guidance instead).
- A no-op safety test for the injector: proves `context-keeper.sh` stays silent (empty output, exit
  0) in any project with no `context_index.md` up-tree, so a user-scope install never disturbs a
  project that did not adopt warmstart.
- Dual-door install docs: the README quickstart now leads with the two-command plugin path and keeps
  the by-hand path as "own your hooks", with a user-vs-project scope note.

### Removed
- `hooks/block-em-dash.sh`: the em-dash guard leaves the public set, along with its wiring,
  tests, and doc references. The `perl` dependency goes with it.

### Not yet included
- The full wrapup pipeline and the advanced guard hooks remain planned for a later version.

## [0.1] - 2026-07-03

First public release. warmstart is a working subset extracted from a live personal system: the core
loop (context injection, templates, guard hooks, and a lite wrapup) is here and tested.

### Added
- `hooks/context-keeper.sh`: the session-start hook. On the first prompt it injects
  `context_index.md` (the tier 2 dashboard), capped at 16KB and gated to once per session, and it
  inlines cross-cutting reading lists for workstreams that declare them.
- Templates: `CLAUDE.md.template`, `context_index.md`, two workstream shapes (a session log and a
  categorical layout), and a cross-cutting workstream example.
- Guard hooks: `block-em-dash.sh` (the swap-in-your-own-rule example), `block-destructive-bash.sh`,
  `guard-memory-size.sh`, and `guard-context-index-size.sh`, with a settings wiring snippet and a
  test suite.
- `skills/wrapup`: the lite end-of-session routine that updates the context files and commits.
- Docs: `README.md`, `docs/philosophy.md`, `docs/the-pattern.md`, and `docs/glossary.md`.

### Not yet included
- The full wrapup pipeline and the advanced guard hooks are planned for v0.2.
