# warmstart

Warm starts for Claude Code: a session-continuity system so a new session picks up
where the last one left off, instead of starting from cold every time.

> Status: v0.1 in progress. This README is a stub; the full quickstart and the
> 10-minute promise land with the v0.1 release.

## What is here

- `hooks/` - shell hooks that inject your durable context at session start and guard
  against common mistakes (destructive commands, oversized memory, banned characters).
- `templates/` - starting-point files you copy into your own workspace: a CLAUDE.md
  pattern, a context index, and workstream note shapes.
- `skills/wrapup/` - the end-of-session routine that writes state back to disk so the
  next session resumes warm.
- `docs/` - the philosophy and the mechanism behind the pattern.

## License

MIT. See [LICENSE](LICENSE).
