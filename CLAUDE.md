# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

warmstart gives Claude Code sessions a warm start: durable state in a few markdown files, injected
by a session-start hook, written back by a wrapup skill, with guard hooks enforcing the conventions.
The thesis is legibility: no database, no embeddings, no server, no build step. A feature that needs
infrastructure is off-thesis, however useful.

This repo is the shippable artifact itself, extracted and de-personalized from a live private
workspace; its history was built clean and publishes as-is. This CLAUDE.md is for developing
warmstart. The CLAUDE.md end users install in their own workspace is `templates/CLAUDE.md.template`.

## Everything committed here ships publicly

- No personal residue in tracked files: no private filesystem paths, no employer or client
  references, no internal task or gate identifiers.
- `docs/launch-narrative_PRIVATE.md` is a gitignored private working copy. Never commit it and
  never quote it in tracked files.
- No literal em-dash (U+2014) anywhere: the repo ships `block-em-dash.sh` and obeys its own rule.
  Test fixtures spell the character as the six-character JSON escape (backslash, u, 2014).
- No unmeasured numbers in public copy: any token, size, or timing claim comes from a measured run.
- Copy tone: no hype adjectives; say what warmstart is NOT early; auto-capture memory tools
  (claude-mem is the named, friendly example) are complementary layers, never rivals.

## Commands

No build, lint, or package manager; everything is bash, markdown, and JSON. Tests are three
self-contained scripts, each runnable alone:

```
bash hooks/test-guards.sh                       # regression suite for the four PreToolUse guards
bash hooks/tests/test-context-keeper.sh         # context-keeper smoke test (injection, caps, root resolution)
bash hooks/tests/test-crosscutting-template.sh  # cross-cutting template integration test
```

Run `test-guards.sh` via its file path, never pasted inline: its fixtures contain
destructive-looking strings, and the live `block-destructive-bash.sh` guard will (correctly) block
an inline copy. Hooks must run on macOS (BSD userland) and Linux with only bash, jq, and awk, plus
perl for the em-dash guard; no GNU-only flags.

## Architecture

The product is a tiered-context loop (full mechanism in `docs/the-pattern.md`):

1. `hooks/context-keeper.sh` (UserPromptSubmit) injects the user's `context_index.md` dashboard on
   the first prompt of a session, and inlines Required Reading files for cross-cutting workstreams.
2. Deep state lives in per-workstream context files, read on demand, never loaded up front.
3. `skills/wrapup/` writes state back at session end (inline for small sessions, parallel subagents
   for 2+ independent streams; the agent briefs live in `skills/wrapup/references/`).

Four PreToolUse guard hooks enforce the conventions; `hooks/settings-snippet.json` is the canonical
wiring. `templates/` holds the files users copy into their own workspace.

Couplings that must move together:

- The 14336-byte region cap in `guard-context-index-size.sh` is derived from `context-keeper.sh`'s
  16 KB `SOFT_CAP` minus headroom; change one, change the other.
- The wrapup skill's Config block (context file names, the 500-line/16KB archive threshold) is
  load-bearing for its steps and must match `templates/`. Guards key on exact file names
  (the workspace-root `context_index.md`, `MEMORY.md`).
- Each guard's fail-open vs fail-closed stance is deliberate and documented in `hooks/README.md`;
  don't flip one without updating the rationale there.
- `README.md`, `hooks/README.md`, and `docs/` describe the same system at different depths. A
  behavior change updates the hook or template, its test, and every doc claim about it in the same
  change; user-visible changes also get a `CHANGELOG.md` entry.

## Conventions

- Conventional commits: feat, fix, docs, test, chore, with an optional scope, e.g. `feat(hooks): ...`.
- Every adoption-ladder rung (tier 1 single guard hook, tier 2 context-keeper, tier 3 full loop)
  must stay standalone value; a feature that only pays off at full adoption breaks the ladder.
- On the author's machine `.git` is a pointer file (separate-git-dir); git commands work normally,
  and clones get a regular `.git` directory.
