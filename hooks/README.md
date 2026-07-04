# Hooks

Shell hooks for Claude Code. They do two jobs: inject your durable context at the start
of a session (`context-keeper.sh`), and guard against a few common, expensive mistakes at
tool-call time (the three PreToolUse guards). All are plain bash. The only runtime
dependency is `jq`.

## What each hook does

| Hook | Event | What it does |
|---|---|---|
| `context-keeper.sh` | `UserPromptSubmit` | On the first prompt of a session, injects `context_index.md` (capped at 16 KB). If the working directory is a cross-cutting workstream whose `CLAUDE.md` has a `## Required Reading at Session Start` block, it also inlines those files (capped at 200 KB total). Injector only: it never blocks a tool call. |
| `block-destructive-bash.sh` | `PreToolUse` (Bash) | Blocks bash commands that bypass the trash and can wipe work: a recursive-and-forced `rm`, a `find ... -delete`, and a forced `git clean`. Use `trash`, or stage/stash instead. Writes a line to `guard.log` on every block. |
| `guard-memory-size.sh` | `PreToolUse` (Write, Edit) | Keeps a `MEMORY.md` index under the size Claude Code loads at session start (the first ~200 lines / 25 KB). Blocks a write over ~24 KB or any single line over ~220 chars, and an edit that would grow an already-large file past the cap. Never blocks a size-reducing edit. Only files named `MEMORY.md` are guarded. |
| `guard-context-index-size.sh` | `PreToolUse` (Write, Edit) | Keeps the workspace-root `context_index.md` under the window `context-keeper.sh` actually injects: no single line over 2000 bytes, and the dashboard region above the `## Recently Completed` marker capped at 14336 bytes (`context-keeper.sh`'s 16 KB `SOFT_CAP` minus headroom - the two constants must move together). For an Edit, the resulting region size isn't knowable from a fragment, so it blocks only when the on-disk region is already over cap and the edit grows it further; a size-reducing or neutral edit never blocks. Only the injected root `context_index.md` is guarded, not a same-named file elsewhere in the tree. |

## Wiring

Two ways, same four hooks.

**As a plugin.** Installing the warmstart plugin auto-wires everything from `hooks.json`; there is
no `settings.json` to merge and no `chmod`. The plugin invokes each hook as
`bash "${CLAUDE_PLUGIN_ROOT}/hooks/<name>.sh"`, so wiring never depends on the executable bit.

**By hand.** Copy `hooks/` into your project, then merge `settings-snippet.json` into your
`.claude/settings.json`. The snippet wires each hook to its event with
`$CLAUDE_PROJECT_DIR/hooks/<name>.sh`:

- `UserPromptSubmit` -> `context-keeper.sh`
- `PreToolUse` matcher `Bash` -> `block-destructive-bash.sh`
- `PreToolUse` matcher `Write|Edit` -> `guard-memory-size.sh`, then `guard-context-index-size.sh`

Make the scripts executable (`chmod +x hooks/*.sh`) and restart Claude Code so it reloads
`settings.json`. `hooks.json` and `settings-snippet.json` wire the same four hooks the same way; if
you change one, change the other.

## Fail-open vs fail-closed

A guard has to decide what to do when its own dependency (usually `jq`) is missing. The
choice is per hook and deliberate:

| Hook | On missing dependency | Why |
|---|---|---|
| `block-destructive-bash.sh` | fail CLOSED (blocks, exit 2) | a guard that cannot parse the command must not silently allow an irreversible delete |
| `guard-memory-size.sh` | fail OPEN (allows, exit 0) | a broken dependency must not hard-block every write in the session |
| `guard-context-index-size.sh` | fail OPEN (allows, exit 0) | same reasoning: never hard-block writes because a dependency is missing |
| `context-keeper.sh` | degrades to no injection | it only adds context; the worst case is a cold start, never a blocked action |

Rule of thumb: fail closed when silently allowing the action is dangerous and rare (a
destructive delete), fail open when blocking the action is disruptive and common (any
write).

## Testing

```
bash hooks/test-guards.sh
```

runs the regression suite for the three PreToolUse guards: a syntax check plus behavioral
assertions for each (blocked and allowed cases). It changes into its own directory first,
so it works from any clone path. The `tests/` folder holds the context-keeper smoke test
and the cross-cutting-template integration test.

One quirk worth knowing: run the suite via its file path, not by pasting its contents into
an inline command. The test inputs contain destructive-looking strings on purpose, and if
they sit in a live Bash tool call, `block-destructive-bash.sh` will (correctly) block your
own command.
