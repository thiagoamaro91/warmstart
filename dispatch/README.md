# dispatch

**Agents that brief agents. A guard hook that blocks subagent dispatches too thin to succeed.**

## The problem

When Claude Code delegates work to a subagent, that subagent starts with zero conversation
context. It has not seen your request, the files already read, or the decisions already made this
session. So a one-line dispatch like "fix the tests" produces thin work: the subagent guesses at
everything the orchestrator already knew and forgot to pass along.

There is a second, quieter failure: a dispatch that does not pick a model inherits the session's
model by default. Cheap mechanical work (log scans, reformatting, checklist sweeps) silently runs
on the most expensive tier you have.

## The idea

A dispatch is a briefing, not a sentence. Every subagent prompt should carry five parts: an
OBJECTIVE, the CONTEXT (with file paths and pasted data, because "as discussed" means nothing to
an agent that was not there), the SCOPE boundaries, an OUTPUT contract, and a DONE check. And
every dispatch should pick its model deliberately instead of inheriting one.

This plugin makes those rules real the same way the rest of warmstart does: the environment
enforces what the model would otherwise forget. Two moving parts:

1. **A PreToolUse guard** (`hooks/guard-agent-briefing.js`) intercepts every subagent dispatch.
   Under-briefed or model-unpinned dispatches are blocked before they run, and the error message
   carries the five-part briefing template, so Claude re-issues a correct dispatch immediately, on
   its own.
2. **A SessionStart hook** injects the full [dispatch playbook](docs/dispatch-playbook.md) into
   the session as context. You do not edit your `CLAUDE.md`; the rules arrive with the plugin, and
   Claude gets the dispatch right on the first try instead of after a block.

The hooks are plain Node.js scripts with no dependencies: no bash, no jq, nothing to `chmod`. They
run the same on Windows, macOS, and Linux. The one thing they need is Node.js itself; see the
install notes below.

## What the guard enforces

| Check | Rule | Escape hatch |
|-------|------|--------------|
| Briefing length | At least 500 characters per dispatch (200 for the read-only Explore and Plan agents). Always on. | Put `[brief-ok]` in the prompt for a deliberately tiny dispatch. |
| Model pin | Every dispatch must pass `model:` explicitly. On by default. | None per-call; turn the rule off entirely (below). `[brief-ok]` never waives it. |

A blocked dispatch exits with the reason on stderr, so Claude sees exactly what to fix and
re-issues the call. Non-subagent tools pass through untouched, and the guard fails open on
malformed input: a broken payload must not lock delegation for the whole session.

### Turning the model-pin rule off

The briefing-length rule is the core of the plugin and stays on. The model-pin rule is a policy
choice, so it is a toggle: set the environment variable `DISPATCH_REQUIRE_MODEL_PIN` to `0`,
`false`, or `off`. The clean way is the `env` block of your Claude Code `settings.json`
(`.claude/settings.json` in your project, or `~/.claude/settings.json` for everywhere):

```json
{
  "env": {
    "DISPATCH_REQUIRE_MODEL_PIN": "0"
  }
}
```

## Install

In Claude Code, add this repo as a plugin marketplace (skip if you already added it for
warmstart) and install the plugin:

```
/plugin marketplace add thiagoamaro91/warmstart
/plugin install dispatch@warmstart
```

Restart Claude Code. That is the whole setup: the guard and the playbook injection are auto-wired,
and there is no step three.

One prerequisite: the hooks run on Node.js, and Claude Code does not bundle a `node` executable
(its official installers ship a self-contained binary). If `node --version` fails in your
terminal, install the LTS from [nodejs.org](https://nodejs.org) first. Without it the hooks
don't block anything; Claude Code reports the failed hook command and carries on.

### Never used Claude Code? Windows, from zero

1. **Install Claude Code.** Open PowerShell (press the Windows key, type `powershell`, press
   Enter) and run the official installer:

   ```powershell
   irm https://claude.ai/install.ps1 | iex
   ```

   No admin rights needed. If anything looks different on your machine, the canonical
   instructions live at [code.claude.com/docs/en/setup](https://code.claude.com/docs/en/setup).

2. **Install Node.js.** The plugin's hooks are Node scripts, and Claude Code does not include
   Node. Download the LTS installer from [nodejs.org](https://nodejs.org) and click through it;
   the defaults are fine.

3. **Start Claude Code.** Close and reopen PowerShell, go to the folder you work in (for example
   `cd Documents\my-project`), and run:

   ```powershell
   claude
   ```

   The first run walks you through logging in.

4. **Install the plugin.** Inside Claude Code, type the two `/plugin` commands from the top of
   this section, one at a time, then restart Claude Code (type `exit`, then run `claude` again).

5. **See it work.** Ask Claude something that takes real digging in a decent-sized project, like
   "search the whole project and list everything that reads configuration". When it dispatches a
   subagent for the legwork, the guard checks the dispatch; if the briefing is too thin, Claude
   gets blocked, reads the template in the error, and re-issues a proper briefing by itself. You
   will see it happen in the tool log.

If a hook ever reports that `node` is missing, step 2 was skipped: install the LTS version from
[nodejs.org](https://nodejs.org) and restart your terminal.

## The playbook

The enforced rules are 1-2 of a seven-rule playbook (agent-type choice, orchestrator stance,
context hygiene, verification, final-message discipline). The full text is
[docs/dispatch-playbook.md](docs/dispatch-playbook.md); the SessionStart hook injects it so every
session starts knowing it. It reads in two minutes and is worth stealing even if you never install
the plugin.

## Tests

The guard and the injector have a fixture-driven regression suite; each fixture is a recorded
PreToolUse payload. Run it with Node from the repo root:

```
node dispatch/hooks/tests/test-dispatch-hooks.js
```

## Relation to warmstart

warmstart (the sibling plugin in this marketplace) gives sessions a warm start: durable state in
markdown files. dispatch guards a different moment: the handoff from one agent to another. Same
thesis, though: plain files, legible rules, and hooks that enforce what prompts merely suggest.
The two install independently; take either or both.
