# Changelog

All notable changes to warmstart are recorded here. The format follows the Keep a Changelog
convention, and the project aims to follow semantic versioning.

## [Unreleased]

### Removed
- `hooks/block-em-dash.sh`: the em-dash guard leaves the public set, along with its wiring,
  tests, and doc references. The `perl` dependency goes with it.

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
