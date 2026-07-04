---
name: setup
description: Use when the user asks to set up, initialize, or bootstrap a warmstart workspace, or says "/warmstart:setup". Copies the two bundled templates (CLAUDE.md.template and context_index.md) into the current workspace root, without ever overwriting a file that already exists.
---

# Warmstart Setup

Bootstraps a workspace for warmstart: copies the two bundled templates into the workspace root as
`CLAUDE.md` and `context_index.md`. Never overwrites a file that already exists.

## Steps

1. **Resolve the plugin root.** This skill lives at `skills/setup/SKILL.md`; the plugin root is two
   directories up, and it holds `templates/CLAUDE.md.template` and `templates/context_index.md`.
   - Primary: use `${CLAUDE_PLUGIN_ROOT}` if it resolves to a path where
     `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md.template` exists. This is the normal case when
     warmstart is installed as a plugin.
   - Fallback: if that path is empty or the template is not there, use two directories up from this
     skill's own directory instead: `${CLAUDE_SKILL_DIR}/../..`. This covers running from a clone,
     where the plugin-root substitution may not be populated.
   - Call the result `PLUGIN_ROOT`. Confirm both `PLUGIN_ROOT/templates/CLAUDE.md.template` and
     `PLUGIN_ROOT/templates/context_index.md` exist before continuing. If neither resolution finds
     them, stop and tell the user the templates could not be located, showing both paths tried.

2. **Determine the workspace root.** This is the current working directory, the place the user
   launched Claude Code from.

3. **Handle `CLAUDE.md` independently.**
   - If `./CLAUDE.md` already exists: change nothing. Tell the user it already exists (state the
     absolute path), give the absolute path to `PLUGIN_ROOT/templates/CLAUDE.md.template` so they
     can diff or merge it by hand, and say explicitly that nothing was changed.
   - If `./CLAUDE.md` does not exist: Read `PLUGIN_ROOT/templates/CLAUDE.md.template` in full and
     Write its exact content, unchanged, to `./CLAUDE.md`. Do not paraphrase or regenerate the
     template; copy it verbatim.

4. **Handle `context_index.md` independently.** Apply the same logic as step 3, using
   `PLUGIN_ROOT/templates/context_index.md` and `./context_index.md`. Whether `CLAUDE.md` existed
   has no bearing on this file; check and act on it separately. It is normal for one file to exist
   and the other not.

5. **Report and close.** Summarize which of the two files were created and which were left alone
   (merge guidance for the latter was already given in step 3 or 4). If at least one file was
   created, tell the user to open `CLAUDE.md` and fill in the workstream table under
   `## Workstreams`: the template ships with placeholder rows that need to become real ones.

## Guardrails

- Never overwrite an existing `CLAUDE.md` or `context_index.md`. Absence is the only condition that
  triggers a write.
- Read each template in full before writing; write its exact bytes rather than reworded content.
- Treat the two targets as independent checks, not a single pass/fail.
