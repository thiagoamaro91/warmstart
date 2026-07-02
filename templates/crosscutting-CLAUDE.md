<!-- Template: a cross-cutting workstream's CLAUDE.md. Copy to <workstream>/CLAUDE.md
     and edit. A cross-cutting workstream intersects other workstreams, so it must pull
     their context in at session start and must not silently write into their folders. -->

# billing (cross-cutting workstream)

This workstream intersects others: billing depends on both the `webapp` and `research`
workstreams. Launching a session here loses root context by design, so the two blocks
below re-establish exactly what this work needs. Replace the example paths with your own.

## Required Reading at Session Start
Load these before responding, so cross-workstream context is active from message 1:
1. Read `../webapp/context_webapp.md` for the current application state this work depends on.
2. Read `../research/context_research.md` for the pricing research that informs it.

## Write Boundary
Keep deliverables inside this workstream's own folder. Reading across workstreams is fine,
but do not write into a sibling workstream's folder (for example `webapp/` or `research/`)
without asking first: writing needs permission.
