# Changelog

All notable changes to warmstart are recorded here. The format follows the Keep a Changelog
convention, and the project aims to follow semantic versioning.

## [Unreleased]

### Added
- The `skill-tuner` plugin, a third plugin distributed from the same marketplace
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
- The `autonomous` plugin, a third plugin distributed from the same marketplace
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
- The `runbooks` plugin, a third plugin distributed from the same marketplace
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
